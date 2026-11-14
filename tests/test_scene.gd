extends SceneTree
## Smoke test for scene construction, HUD, and gameplay wiring.

var frames := 0


func _initialize() -> void:
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		printerr("FAIL: main scene cannot be loaded")
		quit(1)


func _process(_delta: float) -> bool:
	frames += 1
	if frames < 3:
		return false
	var game := current_scene
	if game == null or game.get("rules") == null or game.get("hud") == null:
		printerr("FAIL: game scene did not initialize")
		quit(1)
		return true
	if not _has_key_action("step_left", KEY_W) or not _has_key_action("step_right", KEY_O) or not _has_key_action("lean_left", KEY_Q) or not _has_key_action("lean_right", KEY_P):
		printerr("FAIL: W/O step or Q/P lean bindings are missing")
		quit(1)
		return true
	var towers := game.get_node_or_null("Rooftop Skyscrapers")
	if towers == null or towers.get_child_count() != 5:
		printerr("FAIL: five rooftop skyscrapers were not built")
		quit(1)
		return true
	for tower in towers.get_children():
		if tower.get_node_or_null("Walkable Roof") == null or tower.get_child_count() < 100:
			printerr("FAIL: skyscraper roof or facade detail is missing")
			quit(1)
			return true
	var cityscape := game.get_node_or_null("Cityscape")
	if cityscape == null or cityscape.get_child_count() < 100:
		printerr("FAIL: cityscape background was not built")
		quit(1)
		return true
	var city_ground := game.get_node_or_null("City Ground")
	if city_ground == null or city_ground.get_node_or_null("Asphalt Street") == null or city_ground.get_child_count() < 50:
		printerr("FAIL: city street and sidewalks were not built")
		quit(1)
		return true
	if game.get("walker_model") == null or game.get("walker_animation") == null or game.get("kenney_decor_count") != 8:
		printerr("FAIL: Kenney character or holiday decoration did not load")
		quit(1)
		return true
	var pole: MeshInstance3D = game.get("pole")
	if pole == null or not is_equal_approx(pole.position.y, 1.15) or not is_equal_approx(pole.position.z, 0.42) or absf(pole.transform.basis.y.x) < 0.95:
		printerr("FAIL: balance pole is not horizontal in front of the waist")
		quit(1)
		return true
	game.get("rules").tilt = 0.4
	game.call("_update_walker", 0.0)
	if absf(pole.transform.basis.y.x) < 0.95:
		printerr("FAIL: balance update turned the pole upright")
		quit(1)
		return true
	game.set("mode", "walking")
	game.call("_step", "left")
	if game.get("rules").step != 1 or game.get("last_step_foot") != "left" or game.get("walker_animation").current_animation != "walk":
		printerr("FAIL: left foot step did not advance rules")
		quit(1)
		return true
	game.set("step_duration", 0.0)
	game.get("rules").time += 0.5
	game.call("_step", "right")
	if game.get("rules").step != 2 or game.get("last_step_foot") != "right" or game.get("walker_animation").current_animation_position < 0.25:
		printerr("FAIL: right foot step did not advance rules")
		quit(1)
		return true
	game.set("step_duration", 0.0)
	game.get("rules").time += 0.5
	game.call("_step")
	if game.get("rules").step != 3 or game.get("last_step_foot") != "left":
		printerr("FAIL: generic step did not alternate feet")
		quit(1)
		return true
	print("PASS: main scene initializes and step action works")
	quit(0)
	return true


func _has_key_action(action: StringName, key: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false
