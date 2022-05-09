extends Reference
class_name NetworkSpawnedNode

var spawned_node: Node
var _spawn_manager: Node

func _init(p_spawned_node: Node, p_spawn_manager: Node) -> void:
	spawned_node = p_spawned_node
	_spawn_manager = p_spawn_manager

func set(property_name: String, value) -> void:
	SyncManager.register_event(_spawn_manager, {
		type = "set",
		caller = str(spawned_node.get_path()),
		property_name = property_name,
		value = value,
	})
	spawned_node.set(property_name, value)

func callv(method_name: String, args: Array):
	SyncManager.register_event(_spawn_manager, {
		type = "callv",
		caller = str(spawned_node.get_path()),
		method_name = method_name,
		args = args,
	})
	return spawned_node.callv(method_name, args)

func connect(signal_name: String, target: Object, method: String, binds: Array = [  ], flags: int = 0) -> int:
	return callv("connect", [signal_name, target, method, binds, flags])
