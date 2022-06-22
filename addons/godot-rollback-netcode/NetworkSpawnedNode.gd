extends Reference
class_name NetworkSpawnedNode

var spawned_node: Node
var _spawn_manager: Node

func _init(p_spawned_node: Node, p_spawn_manager: Node) -> void:
	spawned_node = p_spawned_node
	_spawn_manager = p_spawn_manager
	yield(Engine.get_main_loop(), "idle_frame")
	spawned_node = null
	_spawn_manager = null


func initialize(args) -> void:
	if not _spawn_manager:
		push_error("A spawned node can only be initialized on the same frame it was spawned")
		return
	var processed_data = args
	if spawned_node.has_method("_network_spawn_preprocess"):
		processed_data = spawned_node.callv("_network_spawn_preprocess", args) if args is Array \
			else spawned_node._network_spawn_preprocess(args)
	SyncManager.register_event(_spawn_manager, {
			type = "init",
			data = processed_data,
		})
	# Disable event registration because registering the call is enough
	SyncManager.disable_event_registration = true
	if spawned_node.has_method("_network_spawn"):
		if processed_data is Array:
			spawned_node.callv("_network_spawn", processed_data)
		else:
			spawned_node._network_spawn(processed_data)
	else:
		push_error("Node %s does not implement _network_spawn()" % spawned_node.name)
	SyncManager.disable_event_registration = false


func connect_signal(signal_name: String, target_path: NodePath, method: String, binds: Array = [  ], flags: int = 0) -> void:
	if not _spawn_manager:
		push_error("A spawned node can only be initialized on the same frame it was spawned")
		return
	SyncManager.register_event(_spawn_manager, {
			type = "connect",
			data = [signal_name, target_path, method, binds, flags],
		})
	var target = Engine.get_main_loop().root.get_node(target_path)
	spawned_node.connect(signal_name, target, method, binds, flags)
