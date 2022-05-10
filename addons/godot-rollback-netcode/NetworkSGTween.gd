extends SGTween
class_name NetworkSGTween

var tick_time := SGFixed.div(SGFixed.ONE, SGFixed.from_int(ProjectSettings.get_setting("physics/common/physics_fps")))

func _ready() -> void:
	playback_process_mode = SGTween.TWEEN_PROCESS_MANUAL
	add_to_group('network_sync')
	duration_before_remove = SGFixed.mul(SGFixed.from_int(ProjectSettings.get_setting("network/rollback/max_buffer_size")), tick_time)

func _network_prepare_for_reuse() -> void:
	clear_all()

func _network_process(input: Dictionary) -> void:
	if is_active():
		advance(tick_time)

func _save_state() -> Dictionary:
	return save_state()

func _load_state(state: Dictionary) -> void:
	var translated_load_type: = SGTween.ROLLBACK
	if SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_BACKWARD:
		translated_load_type = SGTween.INTERPOLATION_BACKWARD
	elif SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_FORWARD:
		translated_load_type = SGTween.INTERPOLATION_FORWARD
	load_state(state, translated_load_type)
	if SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_FORWARD:
		should_load_forward = false

func _interpolate_state(state_before: Dictionary, state_after: Dictionary, weight: float) -> void:
	interpolate_state(state_before, state_after, weight)
