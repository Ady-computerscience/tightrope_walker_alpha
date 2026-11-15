extends SceneTree
## Smoke test for scene construction, HUD, and gameplay wiring.

const Rules := preload("res://scripts/tightrope_rules.gd")
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
	var bird_models: Array = game.get("birds")
	if bird_models.size() != 3:
		printerr("FAIL: three bird models were not created")
		quit(1)
		return true
	for bird in bird_models:
		var bird_animation := bird.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if bird_animation == null or not bird_animation.has_animation("australasian_swamphen_fly") or bird_animation.current_animation != "australasian_swamphen_fly" or bird_animation.get_animation("australasian_swamphen_fly").loop_mode != Animation.LOOP_LINEAR:
			printerr("FAIL: bird model is missing its playing flight animation")
			quit(1)
			return true
	var bird_rules: TightropeRules = game.get("rules")
	bird_rules.tower = 2
	bird_rules.bird_phase = "approach"
	bird_rules.bird_timer = Rules.BIRD_APPROACH
	bird_rules.bird_entry_side = 1
	bird_rules.bird_dir = 1
	bird_rules.bird_dirs = [-1, 1, -1]
	game.call("_update_birds")
	var center_bird: Node3D = bird_models[1]
	var hover_position: Vector3 = game.get("walker").position + Vector3(0.0, 2.0, -5.0)
	var camera: Camera3D = game.get("camera")
	var entry_offset := center_bird.position - hover_position
	if entry_offset.dot(camera.global_transform.basis.x) < 23.0 or entry_offset.dot(camera.global_transform.basis.y) < 12.0 or not is_equal_approx(-center_bird.transform.basis.z.normalized().x, -1.0):
		printerr("FAIL: birds did not enter from the upper right corner")
		quit(1)
		return true
	bird_rules.bird_entry_side = -1
	game.call("_update_birds")
	entry_offset = center_bird.position - hover_position
	if entry_offset.dot(camera.global_transform.basis.x) > -23.0 or entry_offset.dot(camera.global_transform.basis.y) < 12.0 or not is_equal_approx(-center_bird.transform.basis.z.normalized().x, 1.0):
		printerr("FAIL: birds did not enter from the upper left corner")
		quit(1)
		return true
	bird_rules.bird_timer = Rules.BIRD_APPROACH * 0.5
	game.call("_update_birds")
	if center_bird.position.distance_to(hover_position) >= entry_offset.length():
		printerr("FAIL: birds did not fly toward the hover position")
		quit(1)
		return true
	bird_rules.bird_phase = "warn"
	bird_rules.bird_timer = Rules.BIRD_WARN
	game.call("_update_birds")
	if not center_bird.position.is_equal_approx(hover_position):
		printerr("FAIL: birds did not hover at their arrival position")
		quit(1)
		return true
	for index in bird_models.size():
		var bird: Node3D = bird_models[index]
		if not bird.visible or not is_equal_approx(-bird.transform.basis.z.normalized().x, float(bird_rules.bird_dirs[index])):
			printerr("FAIL: bird model does not face its assigned left/right direction")
			quit(1)
			return true
	bird_rules.bird_phase = "rest"
	game.call("_update_birds")
	for bird in bird_models:
		if bird.visible:
			printerr("FAIL: bird model remained visible after the warning")
			quit(1)
			return true
	game.set("visual_z", Rules.step_z(2, 1))
	bird_rules.tilt = -0.25
	game.call("_update_walker", 0.0)
	var loaded_rope: Dictionary = Rules.rope_at(game.get("visual_z"))
	var rope_point: Vector3 = game.call("_rope_point", 2, loaded_rope["progress"], loaded_rope)
	if game.get("walker").position.x >= 0.0 or rope_point.x >= 0.0:
		printerr("FAIL: opposite-direction gust would move the walker or rope the wrong way")
		quit(1)
		return true
	game.set("visual_z", Rules.step_z(1, 0))
	bird_rules.tilt = 0.0
	game.call("_update_walker", 0.0)
	bird_rules.tower = 1
	if not _has_key_action("step_left", KEY_W) or not _has_key_action("step_right", KEY_O) or not _has_key_action("lean_left", KEY_Q) or not _has_key_action("lean_right", KEY_P):
		printerr("FAIL: W/O step or Q/P lean bindings are missing")
		quit(1)
		return true
	var hud: GameHUD = game.get("hud")
	var hint: PanelContainer = hud.get("_control_hint")
	if hint == null or not hint.visible or not is_equal_approx(hint.anchor_top, 1.0):
		printerr("FAIL: control hint is not visible at the bottom on startup")
		quit(1)
		return true
	hud.call("_process", 30.0)
	if not hint.visible:
		printerr("FAIL: startup control hint expired before the first step")
		quit(1)
		return true
	if not _has_key_action("skip_intro", KEY_SPACE) or not _has_key_action("release", KEY_SPACE):
		printerr("FAIL: Space is not mapped to intro skip and in-game release")
		quit(1)
		return true
	var intro_camera_position := camera.position
	var start_view_position: Vector3 = game.get("walker").position + Vector3(7.0, 6.5, 15.0)
	game.call("_start_intro_skip")
	if game.get("mode") != "intro_skip" or not camera.position.is_equal_approx(intro_camera_position):
		printerr("FAIL: intro skip did not start from the current camera view")
		quit(1)
		return true
	game.call("_process", 0.1)
	if camera.position.is_equal_approx(intro_camera_position) or camera.position.is_equal_approx(start_view_position):
		printerr("FAIL: intro skip camera did not pan through an intermediate view")
		quit(1)
		return true
	for tick in 7:
		game.call("_process", 0.1)
	if game.get("mode") != "walking" or not camera.position.is_equal_approx(start_view_position) or game.get("rules").step != 0 or game.get("has_taken_first_step"):
		printerr("FAIL: intro skip did not land at the start without taking a step")
		quit(1)
		return true
	var startup_rules: TightropeRules = game.get("rules")
	startup_rules.last_step_at = startup_rules.time
	game.call("_step", "left")
	if game.get("has_taken_first_step"):
		printerr("FAIL: cooldown press started control hint countdown")
		quit(1)
		return true
	startup_rules.last_step_at = -10.0
	game.call("_step", "left")
	if not game.get("has_taken_first_step") or startup_rules.step != 1:
		printerr("FAIL: first successful step did not start control hint countdown")
		quit(1)
		return true
	hud.call("_process", 9.9)
	if not hint.visible:
		printerr("FAIL: control hint hid before ten seconds after first step")
		quit(1)
		return true
	hud.call("_process", 0.2)
	if hint.visible:
		printerr("FAIL: control hint did not hide after ten seconds from first step")
		quit(1)
		return true
	hud.call("_process", 30.0)
	if hint.visible:
		printerr("FAIL: control hint reappeared without a restart")
		quit(1)
		return true
	game.call("_restart")
	hud.call("_process", 11.0)
	if not hint.visible or game.get("has_taken_first_step"):
		printerr("FAIL: restarted round did not wait for its first step")
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
	var model: Node3D = game.get("walker_model")
	if model.transform.basis.z.dot(Vector3.FORWARD) < 0.99:
		printerr("FAIL: walker does not face the next tower")
		quit(1)
		return true
	var pole: MeshInstance3D = game.get("pole")
	if pole == null or not is_equal_approx(pole.position.y, 1.15) or not is_equal_approx(pole.position.z, -0.42) or absf(pole.transform.basis.y.x) < 0.95:
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
	game.call("_restart")
	if not hint.visible or game.get("has_taken_first_step"):
		printerr("FAIL: control hint did not reset after restart")
		quit(1)
		return true
	var run: TightropeRules = game.get("rules")
	run.step = Rules.STEPS_PER_TOWER - 1
	game.call("_step", "left")
	if run.tower != 2 or run.checkpoint_tower != 1:
		printerr("FAIL: next tower became checkpoint before landing")
		quit(1)
		return true
	hud.call("_process", 10.1)
	if hint.visible:
		printerr("FAIL: restarted control hint did not expire after its first step")
		quit(1)
		return true
	game.call("_update_step", 1.0)
	if run.checkpoint_tower != 2:
		printerr("FAIL: landing did not save tower two checkpoint")
		quit(1)
		return true
	run.tilt = 0.99
	run.tilt_vel = 2.0
	run.update(1.0 / 60.0, 0.0)
	if run.state != "falling":
		printerr("FAIL: checkpoint test did not trigger a fall")
		quit(1)
		return true
	for tick in 18:
		game.call("_process", 0.1)
	if run.state != "walking" or run.tower != 2 or not is_equal_approx(game.get("visual_z"), Rules.step_z(2, 0)):
		printerr("FAIL: fall did not respawn on last reached rooftop: state=%s tower=%d z=%f elapsed=%f" % [run.state, run.tower, game.get("visual_z"), game.get("fall_elapsed")])
		quit(1)
		return true
	hud.call("_process", 11.0)
	if hint.visible or not game.get("has_taken_first_step"):
		printerr("FAIL: control hint reappeared after fall respawn")
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
