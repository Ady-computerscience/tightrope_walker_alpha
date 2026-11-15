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
	if game.get("rules").on_rope or not Rules.rope_at(game.get("visual_z")).is_empty():
		printerr("FAIL: stuntman did not start safely on the rooftop")
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
	var hover_position: Vector3 = game.get("walker").position + Vector3(0.0, 3.5, -5.0)
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
	var saved_camera_transform := camera.global_transform
	camera.position = game.get("walker").position + Vector3(7.0, 6.5, 15.0)
	camera.look_at(game.get("walker").position + Vector3(0.0, 1.0, -12.0))
	var bird_hud: GameHUD = game.get("hud")
	var timer_track: Panel = bird_hud.get("_countdown_track")
	var timer_fill: Panel = bird_hud.get("_countdown_fill")
	game.call("_update_reaction_timer")
	var projected_bird := camera.unproject_position(center_bird.global_position)
	var projected_left := camera.unproject_position(bird_models[0].global_position)
	var projected_right := camera.unproject_position(bird_models[2].global_position)
	var projected_walker := camera.unproject_position(game.get("walker").global_position + Vector3(0.0, 1.15, 0.0))
	var expected_width := absf(projected_right.x - projected_left.x) * 0.5
	var projected_center_x := (projected_left.x + projected_right.x) * 0.5
	var timer_style := timer_track.get_theme_stylebox("panel") as StyleBoxFlat
	var fill_style := timer_fill.get_theme_stylebox("panel") as StyleBoxFlat
	if not timer_track.visible or timer_track.position.y <= projected_bird.y or timer_track.position.y > projected_bird.y + 8.0 or timer_track.position.y + timer_track.size.y >= projected_walker.y or not is_equal_approx(timer_track.size.x, expected_width) or not is_equal_approx(timer_track.position.x + timer_track.size.x * 0.5, projected_center_x) or not is_equal_approx(timer_fill.size.x, expected_width) or timer_track.size.y != 4.0 or timer_fill.size.y != 4.0 or timer_style == null or timer_style.border_width_left != 0 or timer_style.corner_radius_top_left != 2 or fill_style == null or fill_style.corner_radius_top_left != 2:
		printerr("FAIL: borderless bird countdown is not centered at half the flock width")
		quit(1)
		return true
	bird_rules.bird_timer = Rules.BIRD_WARN * 0.5
	game.call("_update_reaction_timer")
	if not is_equal_approx(timer_fill.size.x, expected_width * 0.5) or fill_style.bg_color != GameHUD.GOLD:
		printerr("FAIL: bird countdown did not shrink at half time")
		quit(1)
		return true
	bird_rules.bird_timer = Rules.BIRD_WARN * 0.25
	game.call("_update_reaction_timer")
	if not is_equal_approx(timer_fill.size.x, expected_width * 0.25) or fill_style.bg_color != GameHUD.WARNING_RED:
		printerr("FAIL: bird countdown did not turn red at 75 percent elapsed")
		quit(1)
		return true
	bird_rules.bird_timer = 0.0
	game.call("_update_reaction_timer")
	if timer_track.visible:
		printerr("FAIL: bird countdown remained visible when time ran out")
		quit(1)
		return true
	bird_rules.bird_phase = "rest"
	game.call("_update_birds")
	game.call("_update_reaction_timer")
	camera.global_transform = saved_camera_transform
	if timer_track.visible:
		printerr("FAIL: bird countdown remained visible after the warning")
		quit(1)
		return true
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
	if not _has_key_action("skip_intro", KEY_SPACE) or not _has_key_action("skip_fall", KEY_SPACE) or not _has_key_action("release", KEY_SPACE):
		printerr("FAIL: Space is not mapped to intro skip, fall skip, and in-game release")
		quit(1)
		return true
	var intro_camera_position := camera.position
	var start_view_position: Vector3 = game.get("walker").position + Vector3(7.0, 5.5, 15.0)
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
	var gust_flag: Node3D = game.get("gust_flag")
	if gust_flag == null or gust_flag.get_parent() != camera or gust_flag.get_child_count() == 0 or gust_flag.visible or not is_equal_approx(gust_flag.scale.y, 0.7):
		printerr("FAIL: imported gust flag is missing or visible before the cue")
		quit(1)
		return true
	var gust_flag_mesh := gust_flag.find_child("Flag", true, false) as MeshInstance3D
	if gust_flag_mesh == null or gust_flag_mesh.mesh.get_surface_count() != 2 or gust_flag_mesh.get_surface_override_material(0).albedo_color != Color("7c829e") or gust_flag_mesh.get_surface_override_material(1).albedo_color != Color("ff6a58"):
		printerr("FAIL: Quaternius flag did not use the city palette")
		quit(1)
		return true
	startup_rules.on_rope = true
	startup_rules.wind_phase = "cue"
	startup_rules.wind_timer = Rules.WIND_CUE_DURATION - 0.05
	startup_rules.wind_flag_side = -1
	game.call("_update_gust_visual")
	game.call("_update_reaction_timer")
	game.call("_update_snowfall")
	game.call("_update_camera", 0.1)
	var snowfall: CPUParticles3D = game.get("snow")
	var gust_snow: CPUParticles3D = game.get("gust_snow")
	if not gust_flag.visible or gust_flag.position.x >= 0.0 or timer_track.visible or snowfall.local_coords or not is_zero_approx(snowfall.gravity.x) or gust_snow.visible or not is_zero_approx(game.get("camera_wind_sway")):
		printerr("FAIL: gust flag did not appear on the left during the cue")
		quit(1)
		return true
	startup_rules.wind_timer = Rules.WIND_CUE_DURATION - 0.12
	game.call("_update_gust_visual")
	if not gust_flag.visible:
		printerr("FAIL: gust flag blinked off during the cue")
		quit(1)
		return true
	startup_rules.wind_flag_side = 1
	game.call("_update_gust_visual")
	if not gust_flag.visible or gust_flag.position.x <= 0.0:
		printerr("FAIL: gust flag did not appear on the right during the cue")
		quit(1)
		return true
	startup_rules.wind_phase = "react"
	startup_rules.wind_dir = 1
	startup_rules.wind_flag_side = -1
	startup_rules.wind_timer = Rules.WIND_RESPONSE_TIME
	startup_rules.wind_ramp = 0.5
	game.call("_update_gust_visual")
	game.call("_update_reaction_timer")
	game.call("_update_snowfall")
	game.call("_update_camera", 0.1)
	if not is_zero_approx(snowfall.gravity.x) or not is_zero_approx(snowfall.direction.x) or gust_snow.visible or not is_zero_approx(game.get("camera_wind_sway")):
		printerr("FAIL: snowfall burst started before the reaction countdown ended")
		quit(1)
		return true
	startup_rules.wind_dir = -1
	game.call("_update_snowfall")
	if not is_zero_approx(snowfall.gravity.x) or gust_snow.visible:
		printerr("FAIL: changing the cue direction started a burst during the countdown")
		quit(1)
		return true
	startup_rules.wind_dir = 1
	game.call("_update_hud")
	var gust_caption: Label = hud.get("_caption")
	var gust_status: Label = hud.get("_cue")
	var projected_flag := camera.unproject_position(gust_flag.global_position)
	if not gust_flag.visible or gust_caption.visible or gust_status.text.contains("Gust from") or not timer_track.visible or not is_equal_approx(timer_track.position.x + timer_track.size.x * 0.5, projected_flag.x) or not is_equal_approx(timer_track.position.y, projected_flag.y + 8.0) or not is_equal_approx(timer_track.size.x, 100.0) or not is_equal_approx(timer_fill.size.x, 100.0):
		printerr("FAIL: gust warning showed direction text or misplaced the flag countdown")
		quit(1)
		return true
	startup_rules.wind_timer = Rules.WIND_RESPONSE_TIME * 0.5
	game.call("_update_reaction_timer")
	if not is_equal_approx(timer_fill.size.x, 50.0) or fill_style.bg_color != GameHUD.GOLD:
		printerr("FAIL: gust countdown did not shrink at half time")
		quit(1)
		return true
	startup_rules.wind_timer = Rules.WIND_RESPONSE_TIME * 0.25
	game.call("_update_reaction_timer")
	if not is_equal_approx(timer_fill.size.x, 25.0) or fill_style.bg_color != GameHUD.WARNING_RED:
		printerr("FAIL: gust countdown did not turn red at 75 percent elapsed")
		quit(1)
		return true
	startup_rules.wind_phase = "blow"
	game.call("_update_gust_visual")
	game.call("_update_reaction_timer")
	game.call("_update_snowfall")
	if timer_track.visible or gust_flag.visible or snowfall.gravity.x < 10.0 or snowfall.direction.x <= 0.0 or not gust_snow.visible or not gust_snow.emitting or gust_snow.direction.x <= 0.0 or not get_root().get_visible_rect().has_point(camera.unproject_position(gust_snow.global_position)):
		printerr("FAIL: snowfall burst did not begin when the countdown ended")
		quit(1)
		return true
	game.call("_update_camera", 0.1)
	if game.get("camera_wind_sway") <= 0.0 or camera.position.x <= game.get("camera_position").x:
		printerr("FAIL: camera did not sway with the active wind gust")
		quit(1)
		return true
	startup_rules.on_rope = false
	startup_rules.wind_phase = "rest"
	startup_rules.wind_timer = 2.5
	startup_rules.wind_ramp = 0.0
	game.call("_update_gust_visual")
	game.call("_update_snowfall")
	game.call("_update_camera", 0.1)
	if not is_zero_approx(snowfall.gravity.x) or not is_zero_approx(snowfall.direction.x) or not is_zero_approx(game.get("camera_wind_sway")):
		printerr("FAIL: snowfall did not return to calm after the gust")
		quit(1)
		return true
	startup_rules.last_step_at = startup_rules.time
	game.call("_step", "left")
	if game.get("has_taken_first_step"):
		printerr("FAIL: cooldown press started control hint countdown")
		quit(1)
		return true
	startup_rules.last_step_at = -10.0
	game.call("_step", "left")
	if not game.get("has_taken_first_step") or startup_rules.step != 1 or startup_rules.on_rope:
		printerr("FAIL: first successful step did not start control hint countdown")
		quit(1)
		return true
	game.call("_update_step", 0.2)
	startup_rules.tilt = 0.99
	startup_rules.tilt_vel = 2.0
	if not startup_rules.update(1.0 / 60.0, 1.0).is_empty() or startup_rules.state != "walking" or startup_rules.on_rope or not is_zero_approx(startup_rules.tilt):
		printerr("FAIL: balance registered before the first step reached the rope")
		quit(1)
		return true
	game.call("_update_step", 0.2)
	if not startup_rules.on_rope or not is_equal_approx(game.get("visual_z"), Rules.step_z(1, 1)):
		printerr("FAIL: first step did not put the stuntman on the rope")
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
	var bird_snow_rules: TightropeRules = game.get("rules")
	bird_snow_rules.tower = 2
	bird_snow_rules.on_rope = true
	bird_snow_rules.wind_timer = 5.0
	bird_snow_rules.bird_phase = "warn"
	bird_snow_rules.bird_timer = 0.5
	bird_snow_rules.bird_dir = 1
	game.call("_update_snowfall")
	game.call("_update_camera", 0.1)
	if gust_snow.visible or not is_zero_approx(snowfall.gravity.x) or not is_zero_approx(game.get("camera_wind_sway")):
		printerr("FAIL: bird snow burst appeared during the reaction countdown")
		quit(1)
		return true
	Input.action_press("lean_right")
	game.call("_process", 1.0 / 60.0)
	Input.action_release("lean_right")
	if bird_snow_rules.bird_phase != "rest" or not gust_snow.visible or gust_snow.direction.x >= 0.0 or snowfall.gravity.x >= 0.0 or game.get("camera_wind_sway") >= 0.0:
		printerr("FAIL: successful bird trial did not burst snow opposite the center bird")
		quit(1)
		return true
	game.call("_restart")
	var missed_bird_rules: TightropeRules = game.get("rules")
	missed_bird_rules.tower = 2
	missed_bird_rules.on_rope = true
	missed_bird_rules.wind_timer = 5.0
	missed_bird_rules.bird_phase = "warn"
	missed_bird_rules.bird_timer = 0.5
	missed_bird_rules.bird_dir = -1
	Input.action_press("lean_right")
	game.call("_process", 1.0 / 60.0)
	Input.action_release("lean_right")
	if missed_bird_rules.state != "falling" or not gust_snow.visible or gust_snow.direction.x <= 0.0 or snowfall.gravity.x <= 0.0 or game.get("camera_wind_sway") <= 0.0:
		printerr("FAIL: failed bird trial did not burst snow before the fall")
		quit(1)
		return true
	game.call("_update_camera", Rules.BIRD_GUST_DURATION)
	game.call("_update_camera", 0.1)
	if not is_zero_approx(game.get("camera_wind_sway")) or not is_zero_approx(game.get("camera_bird_gust_remaining")):
		printerr("FAIL: bird camera sway continued after its gust ended")
		quit(1)
		return true
	game.call("_update_snowfall", 1.0)
	game.call("_update_snowfall")
	if not is_zero_approx(snowfall.gravity.x):
		printerr("FAIL: bird snow drift did not end after the burst")
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
		var facade_body := tower.get_node_or_null("Facade") as MeshInstance3D
		var roof := tower.get_node_or_null("Walkable Roof") as MeshInstance3D
		if facade_body == null or roof == null or tower.get_child_count() < 100:
			printerr("FAIL: skyscraper roof or facade detail is missing")
			quit(1)
			return true
		var facade_mesh := facade_body.mesh as BoxMesh
		var roof_mesh := roof.mesh as BoxMesh
		var facade_top := facade_body.position.y + facade_mesh.size.y * 0.5
		var roof_top := roof.position.y + roof_mesh.size.y * 0.5
		var roof_bottom := roof.position.y - roof_mesh.size.y * 0.5
		var tower_number := tower.get_index() + 1
		if tower_number <= Rules.TOWER_COUNT:
			var front_edge := roof.global_position.z - roof_mesh.size.z * 0.5
			var start_z := Rules.step_z(tower_number, 0)
			var first_step_z := Rules.step_z(tower_number, 1)
			if start_z <= front_edge or start_z > front_edge + 2.0 or first_step_z >= front_edge:
				printerr("FAIL: tower %d does not start just inside the roof edge and step off it" % tower_number)
				quit(1)
				return true
			var back_edge := roof.global_position.z + roof_mesh.size.z * 0.5
			var roof_anchor: Vector3 = game.call("_roof_anchor_point", tower_number)
			var edge_loaded_rope := Rules.rope_at(first_step_z)
			var edge_anchor: Vector3 = game.call("_rope_point", tower_number, 0.0, edge_loaded_rope)
			var roof_mount := game.get_node_or_null("Roof Rope Anchor %d" % tower_number) as MeshInstance3D
			var edge_mount := game.get_node_or_null("Edge Rope Anchor %d" % tower_number) as MeshInstance3D
			var rope_segments: Array = game.get("ropes")[tower_number - 1]
			if not is_equal_approx(roof_anchor.z, lerpf(back_edge, front_edge, 0.75)) or not is_equal_approx(edge_anchor.z, front_edge) or not is_equal_approx(roof_anchor.y, edge_anchor.y) or roof_mount == null or edge_mount == null or not is_equal_approx(roof_mount.position.z, roof_anchor.z) or not is_equal_approx(edge_mount.position.z, edge_anchor.z) or rope_segments.size() != 27:
				printerr("FAIL: roof and edge rope anchors are not connected on tower %d" % tower_number)
				quit(1)
				return true
			var parked_rope := Rules.rope_at(start_z)
			var walking_rope := Rules.rope_at(Rules.step_z(tower_number, 4))
			var parked_midpoint: Vector3 = game.call("_rope_point", tower_number, 0.5, parked_rope)
			var loaded_midpoint: Vector3 = game.call("_rope_point", tower_number, 0.5, walking_rope)
			if not parked_rope.is_empty() or not is_equal_approx(parked_midpoint.y, roof_anchor.y) or loaded_midpoint.y >= parked_midpoint.y:
				printerr("FAIL: rope load sag began before the walker passed the edge anchor on tower %d" % tower_number)
				quit(1)
				return true
			var near_edge_z := front_edge - 1.0
			var near_edge_progress := (Rules.tower_z(tower_number) - Rules.ROPE_START_OFFSET - near_edge_z) / Rules.ROPE_LENGTH
			var near_edge_point: Vector3 = game.call("_rope_point", tower_number, near_edge_progress, edge_loaded_rope)
			if near_edge_point.y - 0.16 <= roof.global_position.y + roof_mesh.size.y * 0.5:
				printerr("FAIL: loaded rope clips the roof edge on tower %d" % tower_number)
				quit(1)
				return true
		if facade_top >= roof_top - 0.1 or facade_top <= roof_bottom + 0.1:
			printerr("FAIL: skyscraper facade top overlaps the visible roof top or leaves a gap")
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
	var street_lights := game.get_node_or_null("Street Lights")
	var traffic := game.get_node_or_null("Street Traffic")
	var cars: Array = game.get("traffic_lights")
	if street_lights == null or street_lights.get_child_count() < 10 or traffic == null or cars.size() != 10:
		printerr("FAIL: street lights or traffic were not built")
		quit(1)
		return true
	var first_car_z: float = cars[0].position.z
	game.call("_update_traffic", 0.25)
	if cars[0].position.z <= first_car_z:
		printerr("FAIL: traffic lights did not move along the street")
		quit(1)
		return true
	var decorations := game.get_node_or_null("Kenney Holiday Decorations")
	if game.get("walker_model") == null or game.get("walker_animation") == null or game.get("kenney_decor_count") != 3 or decorations == null or decorations.get_child_count() != 3:
		printerr("FAIL: Kenney character or remaining rooftop decorations did not load")
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
	game.call("_update_step", 1.0)
	if not game.get("rules").on_rope:
		printerr("FAIL: first step did not activate rope balance after restart")
		quit(1)
		return true
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
	run.step = 1
	run.reach_rope()
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
	game.call("_update_step", 1.3)
	if run.checkpoint_tower != 2 or run.on_rope:
		printerr("FAIL: landing did not save tower two checkpoint")
		quit(1)
		return true
	run.tilt = 0.99
	run.tilt_vel = 2.0
	if not run.update(1.0 / 60.0, 0.0).is_empty() or run.state != "walking" or not is_zero_approx(run.tilt):
		printerr("FAIL: balance registered on tower two checkpoint")
		quit(1)
		return true
	run.time += 0.5
	game.call("_step", "left")
	if run.step != 1 or run.on_rope:
		printerr("FAIL: tower two first step was not safe until reaching the rope")
		quit(1)
		return true
	game.call("_update_step", 1.0)
	if not run.on_rope:
		printerr("FAIL: tower two first step did not activate balance")
		quit(1)
		return true
	run.tilt = 0.99
	run.tilt_vel = 2.0
	run.update(1.0 / 60.0, 0.0)
	if run.state != "falling":
		printerr("FAIL: checkpoint test did not trigger a fall")
		quit(1)
		return true
	for tick in 12:
		game.call("_process", 0.1)
	var falling_walker: Node3D = game.get("walker")
	if run.state != "falling" or falling_walker.position.y >= 37.0:
		printerr("FAIL: stuntman stopped falling high above the street")
		quit(1)
		return true
	for tick in 30:
		if game.get("fall_ready_to_respawn"):
			break
		game.call("_process", 0.1)
	var street_mesh := game.get_node("City Ground/Asphalt Street") as MeshInstance3D
	var street_top: float = street_mesh.position.y + (street_mesh.mesh as BoxMesh).size.y * 0.5
	if run.state != "falling" or not game.get("fall_ready_to_respawn") or falling_walker.position.y <= street_top or falling_walker.position.y > street_top + 1.0:
		printerr("FAIL: stuntman did not reach just above the street before respawn: state=%s ready=%s feet=%f street=%f" % [run.state, game.get("fall_ready_to_respawn"), falling_walker.position.y, street_top])
		quit(1)
		return true
	game.call("_process", 0.1)
	if run.state != "walking" or run.tower != 2 or run.on_rope or not is_equal_approx(game.get("visual_z"), Rules.step_z(2, 0)):
		printerr("FAIL: fall did not respawn on last reached rooftop: state=%s tower=%d z=%f elapsed=%f" % [run.state, run.tower, game.get("visual_z"), game.get("fall_elapsed")])
		quit(1)
		return true
	run.step = 1
	run.reach_rope()
	run.tilt = 0.99
	run.tilt_vel = 2.0
	run.update(1.0 / 60.0, 0.0)
	game.call("_process", 0.1)
	if run.state != "falling" or game.get("fall_ready_to_respawn"):
		printerr("FAIL: second fall was not active before the Space shortcut")
		quit(1)
		return true
	Input.action_press("skip_fall")
	game.call("_process", 0.1)
	Input.action_release("skip_fall")
	if run.state != "walking" or run.tower != 2 or run.on_rope or not is_equal_approx(game.get("visual_z"), Rules.step_z(2, 0)) or not is_equal_approx(falling_walker.position.y, 45.0):
		printerr("FAIL: Space did not immediately respawn at the checkpoint")
		quit(1)
		return true
	hud.call("_process", 11.0)
	if hint.visible or not game.get("has_taken_first_step"):
		printerr("FAIL: control hint reappeared after fall respawn")
		quit(1)
		return true
	hud.show_win(25.0, 1, 25.0)
	var win_text: Label = hud.get("_win_text")
	if not win_text.text.contains("Time: 25.0 s") or not win_text.text.contains("Falls: 1") or win_text.text.contains("Gust"):
		printerr("FAIL: win card contains gust result text or omits time and falls")
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
