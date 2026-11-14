extends Node3D
## Single-player Godot scene for the four-tower tightrope course.

const Rules := preload("res://scripts/tightrope_rules.gd")
const HudScene := preload("res://scripts/game_hud.gd")
const FEET_Y := 45.0
const ROPE_Y := 44.87
const STATIC_SAG := 0.25
const LOAD_SAG := 0.9
const ROPE_SEGMENTS := 26
const ROPE_COLOR := Color("ecd6ac")
const HOT_COLOR := Color("ff5c46")
const POLE_WAIST_Y := 1.15
const POLE_FRONT_Z := -0.42
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
var walker_model: Node3D
var walker_animation: AnimationPlayer
var kenney_decor_count := 0
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
var last_step_foot := ""
var fall_elapsed := 0.0
var intro_elapsed := 0.0
var outro_elapsed := 0.0
var mode := "intro"
var paused := false
var best_time := INF
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
		if _step_pressed() and intro_elapsed >= 2.0 or intro_elapsed >= 9.2:
			mode = "walking"
			hud.show_caption("")
			_announce_tower()
	elif mode == "outro":
		outro_elapsed += dt
		if _step_pressed() and outro_elapsed >= 2.0 or outro_elapsed >= 13.0:
			mode = "stargaze"
			hud.show_caption("The stars kept their promise.")
	elif mode == "walking":
		if Input.is_action_just_pressed("step_left"):
			_step("left")
		elif Input.is_action_just_pressed("step_right"):
			_step("right")
		elif Input.is_action_just_pressed("step"):
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
						if walker_animation != null and walker_animation.has_animation("die"):
							walker_animation.play("die")
		if rules.state == "falling":
			fall_elapsed += dt
			if fall_elapsed >= 1.7:
				rules.respawn()
				visual_z = Rules.step_z(rules.tower, 0)
				_play_walker_animation("idle")
				_announce_tower("Try again")
	_update_step(dt)
	_update_walker(dt)
	_update_birds()
	_update_ropes()
	_update_camera(dt)
	snow.position = camera.position + Vector3(0.0, 16.0, -18.0)
	_update_hud()


func _step(foot: String = "") -> void:
	if mode != "walking" or paused or step_duration > 0.0 or rules.state != "walking":
		return
	var result := rules.try_step()
	if result == "blocked" or result == "cooldown":
		return
	if foot.is_empty():
		foot = "right" if last_step_foot == "left" else "left"
	last_step_foot = foot
	step_from = visual_z
	step_to = Rules.step_z(rules.tower, rules.step)
	if result == "won":
		step_to = Rules.step_z(Rules.TOWER_COUNT, Rules.STEPS_PER_TOWER)
	step_duration = 0.6 if absf(step_to - step_from) > 8.0 else 0.4
	step_elapsed = 0.0
	step_result = result
	_play_walker_animation("walk")
	if walker_animation != null and walker_animation.has_animation("walk"):
		var walk := walker_animation.get_animation("walk")
		walker_animation.seek(walk.length * (0.5 if foot == "right" else 0.0), true)


func _release() -> void:
	if mode == "walking" and not paused and rules.release() == "released":
		hud.show_toast("Tension released")


func _restart() -> void:
	paused = false
	mode = "walking"
	rules = Rules.new()
	visual_z = Rules.step_z(1, 0)
	last_step_foot = ""
	_play_walker_animation("idle")
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
	return Input.get_axis("lean_left", "lean_right")


func _step_pressed() -> bool:
	return Input.is_action_just_pressed("step_left") or Input.is_action_just_pressed("step_right") or Input.is_action_just_pressed("step")


func _update_step(dt: float) -> void:
	if step_duration <= 0.0:
		return
	step_elapsed += dt
	var progress := clampf(step_elapsed / step_duration, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	visual_z = lerpf(step_from, step_to, eased)
	if progress >= 1.0:
		step_duration = 0.0
		_play_walker_animation("idle")
		if step_result == "tower":
			rules.reach_tower()
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
	pole.rotation.z = PI * 0.5 + rules.tilt * deg_to_rad(12.0)


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
		desired_position = Vector3(18.0, 64.0, -250.0).lerp(desired_position, progress)
		desired_look = Vector3(0.0, 52.0, -270.0).lerp(desired_look, progress)
	elif mode == "outro" or mode == "stargaze":
		var progress := clampf(outro_elapsed / 13.0, 0.0, 1.0)
		desired_position = focus.lerp(Vector3(0.0, 78.0, -260.0), progress)
		desired_look = focus.lerp(Vector3(0.0, 110.0, -300.0), progress)
	var amount := 1.0 - exp(-dt * 3.5)
	camera_position = camera_position.lerp(desired_position, amount)
	camera_look = camera_look.lerp(desired_look, amount)
	camera.position = camera_position
	camera.look_at(camera_look)


func _update_hud() -> void:
	var cue := "Space: release tension"
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
	_build_rooftop_skyscrapers()
	_build_cityscape()
	_build_city_ground()
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
	walker = Node3D.new()
	add_child(walker)
	_build_walker_visual()
	_place_kenney_decor()
	pole = MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 13.0
	pole.mesh = pole_mesh
	pole.material_override = _material(Color("966038"))
	pole.rotation.z = PI * 0.5
	pole.position = Vector3(0.0, POLE_WAIST_Y, POLE_FRONT_Z)
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
		star.position = Vector3(_rng.randf_range(-180.0, 180.0), _rng.randf_range(68.0, 130.0), _rng.randf_range(-340.0, 60.0))
		add_child(star)


func _build_walker_visual() -> void:
	var path := "res://assets/kenney/blocky_characters/character-a.glb"
	if ResourceLoader.exists(path):
		var scene := load(path) as PackedScene
		if scene != null:
			walker_model = scene.instantiate() as Node3D
			if walker_model != null:
				walker.add_child(walker_model)
				walker_model.rotation.y = PI
				walker_animation = walker_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				_play_walker_animation("idle")
				return
	# Keep a visible walker if an asset is missing from a development checkout.
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


func _play_walker_animation(animation_name: StringName) -> void:
	if walker_animation != null and walker_animation.has_animation(animation_name):
		walker_animation.play(animation_name)


func _place_kenney_decor() -> void:
	var decorations := Node3D.new()
	decorations.name = "Kenney Holiday Decorations"
	add_child(decorations)
	for tower_number in range(1, Rules.TOWER_COUNT + 2):
		var z := Rules.tower_z(tower_number)
		_add_kenney_model(decorations, "lantern", Vector3(-4.0, FEET_Y - 0.7, z - 7.0), 1.1)
	_add_kenney_model(decorations, "bench", Vector3(-3.8, FEET_Y - 0.7, Rules.tower_z(5) - 4.0), 1.7)
	for x in [-2.8, 2.8]:
		_add_kenney_model(decorations, "present-a-cube", Vector3(x, FEET_Y - 0.7, Rules.tower_z(5) - 5.5), 1.3)


func _add_kenney_model(parent: Node3D, model_name: String, at: Vector3, model_scale: float) -> void:
	var path := "res://assets/kenney/holiday_kit/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return
	instance.position = at
	instance.scale = Vector3.ONE * model_scale
	parent.add_child(instance)
	kenney_decor_count += 1


func _build_rooftop_skyscrapers() -> void:
	var towers := Node3D.new()
	towers.name = "Rooftop Skyscrapers"
	add_child(towers)
	var facade_colors := [Color("303149"), Color("292d46"), Color("36364d"), Color("252942"), Color("303149")]
	var glass_colors := [Color("a5bfd5"), Color("f7ca76"), Color("e8a96b"), Color("596c8c")]
	var roof_y := FEET_Y - 0.5
	var height := roof_y + 12.0
	for number in range(1, Rules.TOWER_COUNT + 2):
		var tower := Node3D.new()
		tower.name = "Skyscraper %d" % number
		tower.position.z = Rules.tower_z(number) - 4.0
		towers.add_child(tower)
		var facade: Color = facade_colors[number - 1]
		var trim := facade.lightened(0.25)
		_city_box(tower, Vector3(0.0, -12.0 + height * 0.5, 0.0), Vector3(17.0, height, 20.0), facade)
		var roof := _city_box(tower, Vector3(0.0, roof_y - 0.2, 0.0), Vector3(19.0, 0.4, 24.0), Color("55586c"))
		roof.name = "Walkable Roof"
		for side in [-1.0, 1.0]:
			_city_box(tower, Vector3(side * 9.2, roof_y + 0.45, 0.0), Vector3(0.5, 1.3, 24.0), trim)
			_city_box(tower, Vector3(side * 8.55, 15.0, 0.0), Vector3(0.25, 49.0, 0.35), trim)
			for column in 3:
				_city_box(tower, Vector3(side * 8.56, 16.0, (float(column) - 1.0) * 6.0), Vector3(0.16, 45.0, 0.16), trim)
			_city_box(tower, Vector3(side * 6.0, roof_y + 0.75, 1.0), Vector3(2.4, 1.5, 2.8), Color("41485c"))
		for floor_number in 11:
			var y := -7.0 + floor_number * 4.5
			if floor_number % 3 == 0:
				_city_box(tower, Vector3(0.0, y - 1.9, 0.0), Vector3(17.5, 0.25, 20.5), trim)
			for column in 3:
				var offset := (float(column) - 1.0) * 5.0
				var glass: Color = glass_colors[(number + floor_number + column) % glass_colors.size()]
				for side in [-1.0, 1.0]:
					_city_box(tower, Vector3(offset, y, side * 10.04), Vector3(2.8, 2.2, 0.12), glass, true)
					_city_box(tower, Vector3(side * 8.54, y, offset * 1.25), Vector3(0.12, 2.2, 2.8), glass, true)
		if number == Rules.TOWER_COUNT + 1:
			_city_box(tower, Vector3(6.5, roof_y + 3.0, 6.5), Vector3(0.3, 6.0, 0.3), Color("a5bfd5"))


func _build_cityscape() -> void:
	var city := Node3D.new()
	city.name = "Cityscape"
	add_child(city)
	var skyline_rng := RandomNumberGenerator.new()
	skyline_rng.seed = 49021
	var walls := [Color("252942"), Color("303149"), Color("36364d"), Color("292d46")]
	var windows := [Color("f7ca76"), Color("e8a96b"), Color("a5bfd5")]
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		for row in 2:
			var distance := 49.0 + row * 28.0
			for index in 25:
				var z := 39.0 - index * 17.0 - row * 7.0
				var height := skyline_rng.randf_range(22.0, 56.0) + row * 8.0
				var width := skyline_rng.randf_range(12.0, 18.0)
				var depth := skyline_rng.randf_range(11.0, 17.0)
				var x := side * (distance + skyline_rng.randf_range(-4.0, 4.0))
				var building := _city_box(city, Vector3(x, -12.0 + height * 0.5, z), Vector3(width, height, depth), walls[skyline_rng.randi_range(0, walls.size() - 1)])
				building.name = "Building %d %d %d" % [int(side), row, index]
				var inner_face := x - side * (width * 0.5 + 0.04)
				for floor_number in range(2, int(height / 5.0)):
					if skyline_rng.randf() < 0.28:
						continue
					for column in 2:
						var pane_z := z + (float(column) - 0.5) * depth * 0.38
						_city_box(city, Vector3(inner_face, -12.0 + floor_number * 5.0, pane_z), Vector3(0.12, 1.55, 1.2), windows[skyline_rng.randi_range(0, windows.size() - 1)], true)
				if skyline_rng.randf() < 0.3:
					_city_box(city, Vector3(x, -12.0 + height + 2.5, z), Vector3(0.25, 5.0, 0.25), Color("7c829e"))


func _build_city_ground() -> void:
	var ground := Node3D.new()
	ground.name = "City Ground"
	add_child(ground)
	var street := _city_box(ground, Vector3(0.0, -12.5, -190.0), Vector3(78.0, 1.0, 500.0), Color("252a39"))
	street.name = "Asphalt Street"
	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var sidewalk := _city_box(ground, Vector3(side * 42.0, -12.25, -190.0), Vector3(8.0, 1.5, 500.0), Color("51566b"))
		sidewalk.name = "Sidewalk %d" % side_index
		_city_box(ground, Vector3(side * 38.0, -11.7, -190.0), Vector3(0.6, 0.3, 500.0), Color("9a9bae"))
		for index in 27:
			var z := 49.0 - index * 18.0
			_city_box(ground, Vector3(side * 13.0, -11.97, z), Vector3(0.35, 0.06, 7.0), Color("d4b77b"), true)


func _city_box(parent: Node3D, at: Vector3, size: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = _material(color, unshaded)
	node.position = at
	parent.add_child(node)
	return node


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _install_input_actions() -> void:
	_add_key("lean_left", KEY_Q)
	_add_key("lean_right", KEY_P)
	_add_key("step_left", KEY_W)
	_add_key("step_right", KEY_O)
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
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _add_joy_axis(action: StringName, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action, event)
