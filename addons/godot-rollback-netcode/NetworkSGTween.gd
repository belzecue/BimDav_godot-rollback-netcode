extends SGTween
class_name NetworkSGTween

var tick_time := SGFixed.div(SGFixed.ONE, SGFixed.from_int(ProjectSettings.get_setting("physics/common/physics_fps")))

func _ready() -> void:
	playback_process_mode = SGTween.TWEEN_PROCESS_MANUAL
	add_to_group('network_sync')
	duration_before_remove = SGFixed.mul(SGFixed.from_int(ProjectSettings.get_setting("network/rollback/max_buffer_size") + 2), tick_time)

func _network_prepare_for_reuse() -> void:
	clear_all()

func _network_process(input: Dictionary) -> void:
	if is_active():
		advance(tick_time)

func _save_state() -> Dictionary:
	return save_state()

func interpolate_property(object: Object, property: NodePath, initial_val, final_val, duration: int, trans_type: int = 0, ease_type: int = 2, delay: int = 0) -> bool:
	SyncManager.register_event(self, {
		type = "interpolate_property",
		object_path = object.get_path(),
		args = [property, initial_val, final_val, duration, trans_type, ease_type, delay],
	})
	return .interpolate_property(object, property, initial_val, final_val, duration, trans_type, ease_type, delay)

func _load_state(state: Dictionary) -> void:
	var translated_load_type: = SGTween.ROLLBACK
	if SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_BACKWARD:
		translated_load_type = SGTween.INTERPOLATION_BACKWARD
	elif SyncManager.load_type == SyncManager.LoadType.INTERPOLATION_FORWARD:
		translated_load_type = SGTween.INTERPOLATION_FORWARD
	load_state(state, translated_load_type)

func _interpolate_state(state_before: Dictionary, state_after: Dictionary, weight: float) -> void:
	interpolate_state(state_before, state_after, weight)

func _load_state_forward(state: Dictionary, events: Dictionary) -> void:
	clear_all()
	SyncManager.disable_event_registration = true
	for e in events.values():
		if e.type == "interpolate_property":
			var args = e.args.duplicate()
			args.push_front(get_node(e.object_path))
			callv("interpolate_property", args)
	SyncManager.disable_event_registration = false
	_load_state(state)

static func _prepare_events_up_to_tick(tick_number: int, events: Dictionary) -> Dictionary:
	var ind: = 0
	var final_contents := {}
	for t in events.keys():
		# Only load up to the asked tick
		if t > tick_number:
			break
		var new_event = events[t]
		for e in new_event:
			final_contents[ind] = e
			ind += 1
	return final_contents
