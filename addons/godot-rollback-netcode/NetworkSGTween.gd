extends SGTween
class_name NetworkSGTween

var tick_time := SGFixed.div(SGFixed.ONE, SGFixed.from_int(Engine.get_iterations_per_second()))

func _ready() -> void:
	playback_process_mode = SGTween.TWEEN_PROCESS_MANUAL
	add_to_group('network_sync')
	wait_before_remove = SGFixed.mul(SGFixed.from_int(ProjectSettings.get_setting("network/rollback/max_buffer_size")), tick_time)

func _network_despawn() -> void:
	remove_all()

func _network_process(input: Dictionary) -> void:
	if is_active():
		advance(tick_time)

func _save_state() -> Dictionary:
	return save_state()

func _load_state(state: Dictionary) -> void:
	load_state(state)
