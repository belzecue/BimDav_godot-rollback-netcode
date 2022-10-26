extends PropertyManager


func _ready() -> void:
	initialize(ProjectSettings.get_setting("network/rollback/max_buffer_size") + 2)


func _network_process(_data: Dictionary) -> void:
	if SyncManager._logger:
		SyncManager._logger.start_timing("property_manager_np")
	var events = network_process(SyncManager.current_tick)
	for e in events:
		SyncManager.register_event(self, e)
	if SyncManager._logger:
		SyncManager._logger.stop_timing("property_manager_np")


func _save_state() -> Array:
	return save_state()


func _load_state(state: Array) -> void:
	if SyncManager._logger:
		SyncManager._logger.start_timing("property_manager")
	load_state(state, SyncManager.load_type)
	if SyncManager._logger:
		SyncManager._logger.stop_timing("property_manager", true)


func _interpolate_state(state_before: Array, state_after: Array, weight: float) -> void:
	interpolate_state(state_before, state_after, weight)


func _load_state_forward(state: Array, events: Array) -> void:
	load_state_forward(state, events)


static func _prepare_events_up_to_tick(tick_number: int, events: Dictionary, state: Array) -> Array:
	# only keep the last tick for each node
	var prepared_events := []
	for t in events.keys():
		# Only load up to the asked tick
		if t > tick_number:
			break
		var new_event = events[t]
		for e in new_event:
			prepared_events.append(e)
	return prepared_events
