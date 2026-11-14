extends Node3D
## Single-player Godot scene for the four-tower tightrope course.

const Rules := preload("res://scripts/tightrope_rules.gd")
const HudScene := preload("res://scripts/game_hud.gd")
const FEET_Y := 5.0
const ROPE_Y := 4.87
const STATIC_SAG := 0.25
const LOAD_SAG := 0.9
const ROPE_SEGMENTS := 26
const ROPE_COLOR := Color("ecd6ac")
const HOT_COLOR := Color("ff5c46")
const STORIES := [
	"The wind has turned everyone back. Not tonight.",
	"Even the birds doubt you. Let them watch you prove them wrong.",
	"Halfway across. The rope knows your weight now.",
	"One last sway. The stars are leaning in to see.",
]

var rules: TightropeRules
var hud: GameHUD
var camera: Camera3D
var walker: Node3D
var pole: MeshInstance3D
var ropes: Array = []
var birds: Array[MeshInstance3D] = []
var snow: CPUParticles3D
var visual_z := -4.0
var step_from := -4.0
var step_to := -4.0
var step_elapsed := 0.0
var step_duration := 0.0
var step_result := ""
var fall_elapsed := 0.0
var intro_elapsed := 0.0
var outro_elapsed := 0.0
var mode := "intro"
var paused := false
var touch_left := false
var touch_right := false
var best_time := INF
var imported_art_count := 0
var camera_position := Vector3.ZERO
var camera_look := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_install_input_actions()
	rules = Rules.new()
	visual_z = Rules.step_z(1, 0)
	_build_world()
	hud = HudScene.new()
	add_child(hud)
	hud.lean_left.connect(func(value: bool) -> void: touch_left = value)
	hud.lean_right.connect(func(value: bool) -> void: touch_right = value)
	hud.step_requested.connect(_step)
	hud.release_requested.connect(_release)
	hud.replay_requested.connect(_restart)
	hud.stargaze_requested.connect(_stargaze)
	hud.pause_requested.connect(_toggle_pause)
	hud.show_caption("Beyond the horizon, the stars gather every night.")


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	if Input.is_action_just_pressed("pause_run"):
		_toggle_pause()
	if Input.is_action_just_pressed("restart_run"):
		_restart()
	if paused:
		return
	if mode == "intro":
		intro_elapsed += dt
		if Input.is_action_just_pressed("step") and intro_elapsed >= 2.0 or intro_elapsed >= 9.2:
			mode = "walking"
			hud.show_caption("")
			_announce_tower()
	elif mode == "outro":
		outro_elapsed += dt
		if Input.is_action_just_pressed("step") and outro_elapsed >= 2.0 or outro_elapsed >= 13.0:
			mode = "stargaze"
			hud.show_caption("The stars kept their promise.")
	elif mode == "walking":
		if Input.is_action_just_pressed("step"):
			_step()
		if Input.is_action_just_pressed("release"):
			_release()
		if rules.state == "walking":
			for event in rules.update(dt, _lean_input()):
				match event["type"]:
					"birds": hud.show_toast("Birds! Lean toward the middle bird")
					"birds_pass": hud.show_toast("Birds passed")
					"gust": hud.show_toast("Wind changes direction")
					"fall":
						fall_elapsed = 0.0
						step_duration = 0.0
						hud.show_toast("You fell: %s" % event["reason"])
			if rules.state == "falling":
				fall_elapsed += dt
				if fall_elapsed >= 1.7:
					rules.respawn()
					visual_z = Rules.step_z(rules.tower, 0)
					_announce_tower("Try again")
	_update_step(dt)
	_update_walker(dt)
	_update_birds()
	_update_ropes()
	_update_camera(dt)
	snow.position = camera.position + Vector3(0.0, 16.0, -18.0)
	_update_hud()


func _step() -> void:
	if mode != "walking" or paused or step_duration > 0.0 or rules.state != "walking":
		return
	var result := rules.try_step()
	if result == "blocked" or result == "cooldown":
		return
	step_from = visual_z
	step_to = Rules.step_z(rules.tower, rules.step)
	if result == "won":
		step_to = Rules.step_z(Rules.TOWER_COUNT, Rules.STEPS_PER_TOWER)
	step_duration = 0.6 if absf(step_to - step_from) > 8.0 else 0.4
	step_elapsed = 0.0
	step_result = result


func _release() -> void:
	if mode == "walking" and not paused and rules.release() == "released":
		hud.show_toast("Tension released")


func _restart() -> void:
	paused = false
	mode = "walking"
	rules = Rules.new()
	visual_z = Rules.step_z(1, 0)
	step_duration = 0.0
	fall_elapsed = 0.0
	hud.set_paused(false)
	hud.hide_win()
	hud.show_caption("")
	_announce_tower()


func _stargaze() -> void:
	if rules.state != "won":
		return
	mode = "outro"
	outro_elapsed = 0.0
	hud.hide_win()
	hud.show_caption("You made it. Four towers, one night, no looking back.")


func _toggle_pause() -> void:
	if mode != "walking" or rules.state == "falling":
		return
	paused = not paused
	hud.set_paused(paused)


func _lean_input() -> float:
	var keyboard := Input.get_axis("lean_left", "lean_right")
	var touch := float(int(touch_right) - int(touch_left))
	return clampf(keyboard + touch, -1.0, 1.0)


func _update_step(dt: float) -> void:
	if step_duration <= 0.0:
		return
	step_elapsed += dt
	var progress := clampf(step_elapsed / step_duration, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	visual_z = lerpf(step_from, step_to, eased)
	if progress >= 1.0:
		step_duration = 0.0
		if step_result == "tower":
			_announce_tower()
		elif step_result == "won":
			best_time = minf(best_time, rules.finish_time)
			hud.show_win(rules.finish_time, rules.falls, best_time)


func _update_walker(_dt: float) -> void:
	var rope := Rules.rope_at(visual_z)
	var feet := Vector3(0.0, FEET_Y, visual_z)
	if not rope.is_empty() and rules.state != "falling":
		var s: float = rope["progress"]
		var sag := STATIC_SAG * 4.0 * s * (1.0 - s)
		var load_sag := LOAD_SAG * 4.0 * s * (1.0 - s) * (1.0 - 0.55 * rules.tension)
		feet.y -= sag + load_sag
		feet.x = -rules.tilt * 0.35
		if rules.stage_kind() == "Sway":
			feet.x += rules.sway * 1.6 * sin(PI * s)
	if rules.state == "falling":
		feet.y -= minf(8.0, fall_elapsed * fall_elapsed * 11.0)
		feet.x += rules.fall_dir * fall_elapsed * 3.0
	walker.position = feet
	walker.rotation.z = -rules.tilt * deg_to_rad(30.0)
	pole.rotation.z = rules.tilt * deg_to_rad(12.0)


func _update_birds() -> void:
	var active := rules.stage_kind() == "Birds" and rules.bird_phase == "warn" and rules.state == "walking"
	for index in birds.size():
		var bird := birds[index]
		bird.visible = active
		if active:
			var approach := rules.bird_timer / Rules.BIRD_WARN
			bird.position = walker.position + Vector3((index - 1) * 2.8 + rules.bird_dir * (1.0 - approach), 2.0, -5.0 - approach * 14.0)
			var material: StandardMaterial3D = bird.material_override
			material.albedo_color = Color("ffca62") if index == 1 else Color("d7dded")


func _update_ropes() -> void:
	var current := Rules.rope_at(visual_z)
	for index in range(Rules.TOWER_COUNT):
		var active: bool = index + 1 == rules.tower or (not current.is_empty() and index + 1 == current["tower"])
		if not active:
			continue
		var segments: Array = ropes[index]
		var previous := _rope_point(index + 1, 0.0, current)
		for part in range(ROPE_SEGMENTS):
			var s := float(part + 1) / ROPE_SEGMENTS
			var next := _rope_point(index + 1, s, current)
			var segment: MeshInstance3D = segments[part]
			var direction := next - previous
			segment.position = (next + previous) * 0.5
			segment.quaternion = Quaternion(Vector3.UP, direction.normalized())
			var cylinder: CylinderMesh = segment.mesh
			cylinder.height = direction.length() + 0.06
			var material: StandardMaterial3D = segment.material_override
			material.albedo_color = ROPE_COLOR.lerp(HOT_COLOR, rules.tension * rules.tension if index + 1 == rules.tower else 0.0)
			previous = next


func _rope_point(tower_number: int, s: float, current: Dictionary) -> Vector3:
	var y := ROPE_Y - STATIC_SAG * 4.0 * s * (1.0 - s)
	var x := 0.0
	if tower_number == rules.tower and rules.stage_kind() == "Sway":
		x += rules.sway * 1.6 * sin(PI * s)
	if not current.is_empty() and tower_number == current["tower"]:
		var load: float = current["progress"]
		var triangle := s / load if s <= load and load > 0.0 else ((1.0 - s) / (1.0 - load) if s > load and load < 1.0 else 0.0)
		y -= LOAD_SAG * 4.0 * load * (1.0 - load) * triangle * (1.0 - 0.55 * rules.tension)
		x -= rules.tilt * 0.35 * triangle
	return Vector3(x, y, Rules.tower_z(tower_number) - Rules.ROPE_START_OFFSET - s * Rules.ROPE_LENGTH)


func _update_camera(dt: float) -> void:
	var focus := walker.position
	var desired_position := focus + Vector3(7.0, 6.5, 15.0)
	var desired_look := focus + Vector3(0.0, 1.0, -12.0)
	if mode == "intro":
		var progress := clampf(intro_elapsed / 9.2, 0.0, 1.0)
		desired_position = Vector3(18.0, 24.0, -250.0).lerp(desired_position, progress)
		desired_look = Vector3(0.0, 12.0, -270.0).lerp(desired_look, progress)
	elif mode == "outro" or mode == "stargaze":
		var progress := clampf(outro_elapsed / 13.0, 0.0, 1.0)
		desired_position = focus.lerp(Vector3(0.0, 38.0, -260.0), progress)
		desired_look = focus.lerp(Vector3(0.0, 70.0, -300.0), progress)
	var amount := 1.0 - exp(-dt * 3.5)
	camera_position = camera_position.lerp(desired_position, amount)
	camera_look = camera_look.lerp(desired_look, amount)
	camera.position = camera_position
	camera.look_at(camera_look)


func _update_hud() -> void:
	var cue := "A / D lean  •  W step  •  Space release"
	match rules.stage_kind():
		"Wind": cue = "Wind: %s  %.0f%%" % ["RIGHT" if rules.wind_dir > 0 else "LEFT", rules.wind_ramp * 100.0]
		"Birds": cue = "Birds: lean %s" % ["RIGHT" if rules.bird_dir > 0 else "LEFT"] if rules.bird_phase == "warn" else "Watch for the birds"
		"Tension": cue = "Tension: %.0f%%  •  Space to release" % [rules.tension * 100.0]
		"Sway": cue = "Sway: %.0f%%  •  Step near center" % [rules.sway * 100.0]
	hud.show_status(rules.tower, rules.step, Rules.STEPS_PER_TOWER, rules.stage_kind(), rules.tilt, cue)


func _announce_tower(subtitle: String = "") -> void:
	var text: String = subtitle if not subtitle.is_empty() else STORIES[rules.tower - 1]
	hud.show_toast("Tower %d: %s" % [rules.tower, text])


func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = Color("12122c")
	resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	resource.ambient_light_color = Color("5c5c9c")
	resource.ambient_light_energy = 0.65
	environment.environment = resource
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -20.0, 0.0)
	light.light_color = Color("b5bbff")
	light.light_energy = 1.2
	add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 68.0
	add_child(camera)
	var imported_world := _load_imported_world()
	if not imported_world:
		_build_fallback_towers()
	for number in range(1, Rules.TOWER_COUNT + 1):
		var pieces: Array = []
		for segment_number in ROPE_SEGMENTS:
			var segment := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.16
			mesh.bottom_radius = 0.16
			mesh.height = 2.0
			segment.mesh = mesh
			segment.material_override = _material(ROPE_COLOR)
			add_child(segment)
			pieces.append(segment)
		ropes.append(pieces)
	if not imported_world:
		var floor_mesh := _add_box(Vector3(0.0, -11.0, -124.0), Vector3(400.0, 1.0, 400.0), Color("281f35"))
		floor_mesh.name = "Safety Ground"
	walker = Node3D.new()
	add_child(walker)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.65
	capsule.height = 3.0
	body.mesh = capsule
	body.material_override = _material(Color("ffca62"))
	body.position.y = 1.5
	walker.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	head.mesh = sphere
	head.material_override = _material(Color("ffe2bd"))
	head.position.y = 3.2
	walker.add_child(head)
	pole = MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 13.0
	pole.mesh = pole_mesh
	pole.material_override = _material(Color("966038"))
	pole.rotation_degrees.z = 90.0
	pole.position.y = 2.1
	walker.add_child(pole)
	for bird_number in 3:
		var bird := MeshInstance3D.new()
		var bird_mesh := SphereMesh.new()
		bird_mesh.radius = 0.55
		bird_mesh.height = 0.6
		bird.mesh = bird_mesh
		bird.material_override = _material(Color("d7dded"))
		bird.visible = false
		add_child(bird)
		birds.append(bird)
	snow = CPUParticles3D.new()
	snow.amount = 120
	snow.lifetime = 8.0
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	snow.emission_box_extents = Vector3(22.0, 2.0, 24.0)
	snow.direction = Vector3(0.2, -1.0, 0.0)
	snow.gravity = Vector3(1.8, -2.0, 0.4)
	snow.initial_velocity_min = 2.0
	snow.initial_velocity_max = 4.0
	var flake := SphereMesh.new()
	flake.radius = 0.07
	flake.height = 0.14
	snow.mesh = flake
	add_child(snow)
	for star_number in 120:
		var star := MeshInstance3D.new()
		var star_mesh := SphereMesh.new()
		star_mesh.radius = 0.13
		star_mesh.height = 0.26
		star.mesh = star_mesh
		star.material_override = _material(Color("fff4d8"), true)
		star.position = Vector3(_rng.randf_range(-180.0, 180.0), _rng.randf_range(28.0, 90.0), _rng.randf_range(-340.0, 60.0))
		add_child(star)


func _load_imported_world() -> bool:
	var loaded := false
	for index in range(1, 22):
		var path := "res://assets/world/HighwireHorizon_%02d.obj" % index
		if not ResourceLoader.exists(path):
			continue
		var mesh := load(path) as Mesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position.y = -50.38
		add_child(visual)
		imported_art_count += 1
		loaded = true
	for name in ["Terrain", "DesertFloor", "Mountain"]:
		var path := "res://assets/world/%s.obj" % name
		if not ResourceLoader.exists(path):
			continue
		var mesh := load(path) as Mesh
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.position.y = -50.38
		add_child(visual)
		imported_art_count += 1
	return loaded


func _build_fallback_towers() -> void:
	for number in range(1, Rules.TOWER_COUNT + 2):
		var z := Rules.tower_z(number)
		_add_box(Vector3(0.0, -1.5, z - 4.0), Vector3(10.0, 12.0, 10.0), Color("6b3e40"))
		_add_box(Vector3(0.0, FEET_Y - 0.4, z - 4.0), Vector3(13.0, 0.8, 12.0), Color("c78b5e"))
		for x in [-5.0, 5.0]:
			_add_box(Vector3(x, FEET_Y + 1.5, z - 4.0), Vector3(0.5, 3.5, 0.5), Color("f3c877"))


func _add_box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color)
	node.position = at
	add_child(node)
	return node


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _install_input_actions() -> void:
	_add_key("lean_left", KEY_A)
	_add_key("lean_left", KEY_LEFT)
	_add_key("lean_right", KEY_D)
	_add_key("lean_right", KEY_RIGHT)
	_add_key("step", KEY_W)
	_add_key("step", KEY_UP)
	_add_key("release", KEY_SPACE)
	_add_key("release", KEY_E)
	_add_key("pause_run", KEY_ESCAPE)
	_add_key("restart_run", KEY_R)
	_add_joy_button("step", JOY_BUTTON_A)
	_add_joy_button("release", JOY_BUTTON_X)
	_add_joy_button("pause_run", JOY_BUTTON_START)
	_add_joy_axis("lean_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("lean_right", JOY_AXIS_LEFT_X, 1.0)


func _add_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


func _add_joy_button(action: StringName, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
