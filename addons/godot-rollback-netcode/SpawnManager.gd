extends Node

const REUSE_DESPAWNED_NODES_SETTING := 'network/rollback/spawn_manager/reuse_despawned_nodes'

var spawn_records := {}
var spawned_nodes := {}
var retired_nodes := {}
var interpolation_nodes := {}
var counter := {}
var waiting_before_remove: = {}
var ticks_before_remove: = 20

var reuse_despawned_nodes := false

func _ready() -> void:
	if ProjectSettings.has_setting(REUSE_DESPAWNED_NODES_SETTING):
		reuse_despawned_nodes = ProjectSettings.get_setting(REUSE_DESPAWNED_NODES_SETTING)
	ticks_before_remove = ProjectSettings.get_setting("network/rollback/max_buffer_size")
	
	add_to_group('network_sync')

func reset() -> void:
	spawn_records.clear()
	counter.clear()
	waiting_before_remove.clear()
	
	for node in spawned_nodes.values():
		node.queue_free()
	spawned_nodes.clear()
	
	interpolation_nodes.clear()
	
	for nodes in retired_nodes.values():
		for node in nodes:
			node.queue_free()
	retired_nodes.clear()

func _rename_node(name: String) -> String:
	if not counter.has(name):
		counter[name] = 0
	counter[name] += 1
	return name + str(counter[name])

func _remove_colliding_node(name: String, parent: Node) -> void:
	var existing_node = parent.get_node_or_null(name)
	if existing_node:
		push_warning("Removing node %s which is in the way of new spawn" % existing_node)
		parent.remove_child(existing_node)
		existing_node.queue_free()

static func _node_name_sort_callback(a: Node, b: Node) -> bool:
	return a.name.casecmp_to(b.name) == -1

func _alphabetize_children(parent: Node) -> void:
	var children = parent.get_children()
	children.sort_custom(self, '_node_name_sort_callback')
	for index in range(children.size()):
		var child = children[index]
		parent.move_child(child, index)

func _instance_scene(scene: PackedScene) -> Node:
	var resource_path: = scene.resource_path
	if retired_nodes.has(resource_path):
		var nodes: Array = retired_nodes[resource_path]
		var node: Node

		while nodes.size() > 0:
			node = retired_nodes[resource_path].pop_front()
			if is_instance_valid(node) and not node.is_queued_for_deletion():
				break
			else:
				node = null

		if nodes.size() == 0:
			retired_nodes.erase(resource_path)

		if node:
			#print ("Reusing %s" % resource_path)
			return node

	#print ("Instancing new %s" % resource_path)
	return scene.instance()

func spawn(name: String, parent: Node, scene: PackedScene, rename: bool = true) -> NetworkSpawnedNode:
	var spawned_node = _instance_scene(scene)
	if rename:
		name = _rename_node(name)
	_remove_colliding_node(name, parent)
	spawned_node.name = name
	parent.add_child(spawned_node)
	_alphabetize_children(parent)
	var spawn_record := {
		name = spawned_node.name,
		parent = parent.get_path(),
		scene = scene.resource_path,
	}

	var node_path = str(spawned_node.get_path())
	spawn_records[node_path] = spawn_record
	spawned_nodes[node_path] = spawned_node

	#print ("[%s] spawned: %s" % [SyncManager.current_tick, spawned_node.name])

	return NetworkSpawnedNode.new(spawned_node, self)

func despawn(node: Node) -> void:
	if node.has_signal("despawned"):
		node.emit_signal("despawned")
	
	var node_path: = str(node.get_path())
	if node.get_parent():
		node.get_parent().remove_child(node)
	
	waiting_before_remove[node_path] = 0

func _network_process(_data: Dictionary) -> void:
	var to_remove: = []
	for key in waiting_before_remove.keys():
		waiting_before_remove[key] += 1
		if waiting_before_remove[key] > ticks_before_remove:
			to_remove.append(key)
	for remove_node_path in to_remove:
		_delete_node(remove_node_path)

func _delete_node(node_path: String) -> void:
	# This node was already deleted and we are rolling back, just erase remaining state
	if not spawned_nodes.has(node_path):
		spawn_records.erase(node_path)
		waiting_before_remove.erase(node_path)
		return
	
	var node: Node = spawned_nodes[node_path]
	if node.get_parent():
		node.get_parent().remove_child(node)
	
	if reuse_despawned_nodes and is_instance_valid(node) and not node.is_queued_for_deletion():
		if node.has_method('_network_prepare_for_reuse'):
			node._network_prepare_for_reuse()
		var scene_path
		if interpolation_nodes.has(node_path):
			scene_path = interpolation_nodes[node_path]
		else:
			scene_path = spawn_records[node_path].scene
		if not retired_nodes.has(scene_path):
			retired_nodes[scene_path] = []
		retired_nodes[scene_path].append(node)
	else:
		node.queue_free()

	spawn_records.erase(node_path)
	spawned_nodes.erase(node_path)
	waiting_before_remove.erase(node_path)

func _save_state() -> Dictionary:
	return {
		spawn_records = spawn_records.duplicate(),
		counter = counter.duplicate(),
		waiting_before_remove = waiting_before_remove.duplicate()
	}

func _load_state(state: Dictionary) -> void:
	if SyncManager.load_type == SyncManager.LoadType.ROLLBACK:
		# clear interpolation data
		for node_path in interpolation_nodes.keys():
			if interpolation_nodes[node_path].type == "unspawn":
				_delete_node(node_path)
		interpolation_nodes.clear()
	
	for node_path in spawned_nodes.keys():
		if state.spawn_records.has(node_path):
			if waiting_before_remove.has(node_path) and not state.waiting_before_remove.has(node_path):
				# Node that is absent before load but should be added
				var node: Node = spawned_nodes[node_path]
				var parent: Node = get_node(state.spawn_records[node_path].parent)
				parent.add_child(node)
				_alphabetize_children(parent)
				if SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_BACKWARD:
					interpolation_nodes[node_path] = {
						type = "undespawn",
						scene = spawn_records[node_path].scene,
					}
			elif SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_FORWARD and interpolation_nodes.has(node_path):
				if interpolation_nodes[node_path].type == "unspawn":
					# unspawn is cancelled, node is restored
					var node: Node = spawned_nodes[node_path]
					var parent: Node = get_node(state.spawn_records[node_path].parent)
					parent.add_child(node)
					_alphabetize_children(parent)
					interpolation_nodes.erase(node_path)
				elif interpolation_nodes[node_path].type == "undespawn":
					# undespawn is cancelled, remove node
					var node: Node = spawned_nodes[node_path]
					if node.get_parent():
						node.get_parent().remove_child(node)
		else:
			if SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_BACKWARD:
				# keep this node, it will be used in interpolation_forward
				interpolation_nodes[node_path] = {
					type = "unspawn",
					scene = spawn_records[node_path].scene,
				}
				var node: Node = spawned_nodes[node_path]
				if node.get_parent():
					node.get_parent().remove_child(node)
			else:
				# This node's spawn was cancelled, we can remove it completely
				_delete_node(node_path)
	
	spawn_records = state['spawn_records'].duplicate()
	counter = state['counter'].duplicate()
	waiting_before_remove = state['waiting_before_remove'].duplicate()

func _load_state_forward(state: Dictionary, events: Dictionary) -> void:
	for node_path in state.spawn_records.keys():
		if not spawned_nodes.has(node_path):
			var spawn_record = state.spawn_records[node_path]
			var spawned_node = _instance_scene(load(spawn_record.scene))
			var name = spawn_record.name
			var parent = get_node(spawn_record.parent)
			_remove_colliding_node(name, parent)
			spawned_node.name = name
			spawned_nodes[node_path] = spawned_node
			parent.add_child(spawned_node)
			_alphabetize_children(parent)
	_load_events(events)
	_load_state(state)

func _load_events(events: Dictionary) -> void:
	for path in events.keys():
		var node = get_node_or_null(path)
		if node:
			for e in events[path]:
				if e['type'] == "callv":
					node.callv(e['method_name'], e['args'])
				elif e['type'] == "set":
					node.set(e['property_name'], e['value'])

static func _prepare_events_up_to_tick(tick_number: int, events: Dictionary) -> Dictionary:
	# only keep the last tick for each node
	var prepared_events := {}
	for t in events.keys():
		# Only load up to the asked tick
		if t > tick_number:
			break
		var new_event = events[t]
		for e in new_event:
			var path = e['caller']
			prepared_events[path] = []
		for e in new_event:
			var path = e['caller']
			prepared_events[path].append(e)
	return prepared_events
