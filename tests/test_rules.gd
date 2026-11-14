extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_rules.gd

const Rules := preload("res://scripts/tightrope_rules.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_test_path()
	_test_steps_and_checkpoints()
	_test_birds()
	_test_tension()
	_test_sway()
	_test_determinism()
	_test_full_run(11)
	_test_full_run(29)
	if failures.is_empty():
		print("PASS: all tightrope rule tests")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)


func _test_path() -> void:
	for tower in range(1, Rules.TOWER_COUNT):
		_check(is_equal_approx(Rules.step_z(tower, Rules.STEPS_PER_TOWER), Rules.step_z(tower + 1, 0)), "tower %d path continuity" % tower)
	for tower in range(1, Rules.TOWER_COUNT + 1):
		_check(Rules.rope_at(Rules.step_z(tower, 0)).is_empty(), "tower %d start is on deck" % tower)
		for step in range(1, Rules.STEPS_PER_TOWER):
			_check(Rules.rope_at(Rules.step_z(tower, step)).get("tower", -1) == tower, "tower %d step %d is on rope" % [tower, step])


func _test_steps_and_checkpoints() -> void:
	var run := Rules.new(1)
	_check(run.try_step() == "ok", "first press steps")
	_check(run.try_step() == "cooldown" and run.step == 1, "rapid second press is ignored")
	for index in 8:
		run.time += 0.5
		run.tilt = 0.0
		var result := run.try_step()
		if index == 7:
			_check(result == "tower" and run.tower == 2 and run.step == 0, "nine steps reach tower two")
	run.tower = 3
	run.tilt = 0.99
	run.tilt_vel = 2.0
	var events := run.update(1.0 / 60.0, 0.0)
	_check(run.state == "falling" and events.back().get("type") == "fall", "balance fall fires event")
	run.respawn()
	_check(run.state == "walking" and run.tower == 3 and run.step == 0, "fall restarts same tower")


func _test_birds() -> void:
	var run := Rules.new(4)
	run.tower = 2
	run.bird_timer = 0.0
	var events := run.update(1.0 / 60.0, 0.0)
	_check(events.size() == 1 and events[0]["type"] == "birds", "birds warn before attack")
	_check(run.bird_dirs[1] == run.bird_dir, "middle bird indicates target lean")
	run.tilt = -0.3 * run.bird_dir
	run.bird_timer = 0.0
	events = run.update(1.0 / 60.0, 0.0)
	_check(run.state == "falling" and events.back().get("reason") == "birds", "wrong lean falls")
	_check(Rules.bird_check(0.3, 1) and Rules.bird_check(-0.3, -1), "correct bird lean passes")
	_check(not Rules.bird_check(0.02, 1), "small bird lean fails")


func _test_tension() -> void:
	var run := Rules.new(5)
	run.tower = 3
	run.tension = 0.7
	_check(run.release() == "released" and run.tension == 0.0, "release resets tension")
	_check(run.release() == "cooldown", "release has cooldown")
	run.tension = 0.995
	var events := run.update(0.1, 0.0)
	_check(run.state == "falling" and events.back().get("reason") == "snap", "full tension snaps rope")


func _test_sway() -> void:
	var run := Rules.new(6)
	run.tower = 4
	run.sway = 0.9
	_check(run.try_step() == "shove" and run.step == 1, "unsafe sway shoves but still advances")
	var safe := Rules.new(6)
	safe.tower = 4
	safe.sway = 0.05
	_check(safe.try_step() == "ok", "safe sway allows step")


func _test_determinism() -> void:
	var first := Rules.new(42)
	var second := Rules.new(42)
	for tick in 180:
		var lean := sin(float(tick) * 0.12)
		first.update(1.0 / 60.0, lean)
		second.update(1.0 / 60.0, lean)
		_check(first.wind_dir == second.wind_dir and is_equal_approx(first.tilt, second.tilt), "seeded run diverges at tick %d" % tick)


func _test_full_run(seed_value: int) -> void:
	var run := Rules.new(seed_value)
	var since_step := 0.0
	for tick in 60 * 400:
		var target := 0.0
		if run.stage_kind() == "Birds" and run.bird_phase == "warn":
			target = 0.3 * run.bird_dir
		var lean: float = clampf(-((run.tilt - target) * 2.5 + run.tilt_vel * 1.4) - (run.push + run.tilt * Rules.INSTABILITY) / Rules.LEAN_POWER, -1.0, 1.0)
		var events := run.update(1.0 / 60.0, lean)
		for event in events:
			if event["type"] == "fall":
				run.respawn()
		if run.stage_kind() == "Tension" and run.tension > 0.6:
			run.release()
		since_step += 1.0 / 60.0
		var can_step := since_step > 0.5 and absf(run.tilt) < 0.35
		if run.stage_kind() == "Sway":
			can_step = can_step and absf(run.sway) < 0.2
		if run.stage_kind() == "Birds" and run.bird_phase == "warn":
			can_step = false
		if can_step:
			var result := run.try_step()
			if result != "cooldown":
				since_step = 0.0
			if result == "won":
				_check(run.state == "won" and run.tower == 4, "seed %d win state" % seed_value)
				return
	_check(false, "seed %d could not complete course" % seed_value)
