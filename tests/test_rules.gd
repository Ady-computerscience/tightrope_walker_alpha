extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_rules.gd

const Rules := preload("res://scripts/tightrope_rules.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_test_path()
	_test_safe_checkpoints()
	_test_steps_and_checkpoints()
	_test_checkpoint_respawn()
	_test_wind_disabled()
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


func _test_safe_checkpoints() -> void:
	for tower_number in range(1, Rules.TOWER_COUNT + 1):
		var run := Rules.new(100 + tower_number)
		run.tower = tower_number
		run.tilt = 0.99
		run.tilt_vel = 2.0
		run.bird_timer = 0.0
		run.tension = 0.99
		var events := run.update(0.1, 1.0)
		_check(events.is_empty() and run.state == "walking" and not run.on_rope and is_zero_approx(run.tilt) and is_zero_approx(run.stage_time), "tower %d checkpoint ignores balance and interruptions" % tower_number)
		_check(run.try_step() == "ok" and run.step == 1 and not run.on_rope, "tower %d first step begins from rooftop" % tower_number)
		for tick in 4:
			events = run.update(0.1, 1.0)
			_check(events.is_empty() and run.state == "walking" and is_zero_approx(run.stage_time), "tower %d first step stays safe until it reaches the rope" % tower_number)
		run.tension = 0.0
		run.reach_rope()
		run.update(1.0 / 60.0, 0.0)
		_check(run.on_rope and run.stage_time > 0.0, "tower %d activates rules after reaching the rope" % tower_number)


func _test_steps_and_checkpoints() -> void:
	var run := Rules.new(1)
	_check(not run.on_rope, "start tower begins off the rope")
	_check(run.try_step() == "ok", "first press steps")
	_check(run.try_step() == "cooldown" and run.step == 1, "rapid second press is ignored")
	run.time += 0.5
	_check(run.try_step() == "blocked" and not run.on_rope, "second step waits for the first step to reach the rope")
	run.reach_rope()
	_check(run.on_rope, "first completed step activates balance")
	for index in 8:
		run.time += 0.5
		run.tilt = 0.0
		var result := run.try_step()
		if index == 7:
			_check(result == "tower" and run.tower == 2 and run.step == 0, "nine steps reach tower two")
	run.tower = 3
	run.checkpoint_tower = 3
	run.time += 0.5
	_check(run.try_step() == "ok", "checkpoint first step begins")
	run.reach_rope()
	run.tilt = 0.99
	run.tilt_vel = 2.0
	var events := run.update(1.0 / 60.0, 0.0)
	_check(run.state == "falling" and events.back().get("type") == "fall", "balance fall fires event")
	run.respawn()
	_check(run.state == "walking" and run.tower == 3 and run.step == 0 and not run.on_rope, "fall restarts safely on same tower")


func _test_checkpoint_respawn() -> void:
	var run := Rules.new(13)
	for reached in range(1, Rules.TOWER_COUNT + 1):
		_check(run.tower == reached and run.checkpoint_tower == reached and not run.on_rope, "tower %d is a safe checkpoint" % reached)
		run.time += 0.5
		_check(run.try_step() == "ok", "tower %d first step begins" % reached)
		run.reach_rope()
		_force_balance_fall(run)
		run.respawn()
		_check(run.tower == reached and run.step == 0 and not run.on_rope, "fall before next tower respawns safely at tower %d" % reached)
		if reached == Rules.TOWER_COUNT:
			break
		for step_number in Rules.STEPS_PER_TOWER:
			run.time += 0.5
			var result := run.try_step()
			if step_number == 0:
				_check(not run.on_rope, "tower %d first step is safe until landing on rope" % reached)
				run.reach_rope()
			if step_number == Rules.STEPS_PER_TOWER - 1:
				_check(result == "tower" and run.tower == reached + 1 and not run.on_rope, "tower %d landing begins safely" % reached)
		_check(run.checkpoint_tower == reached, "checkpoint waits for landing on tower %d" % (reached + 1))
		run.tilt = 0.99
		run.tilt_vel = 2.0
		_check(run.update(1.0 / 60.0, 0.0).is_empty() and run.state == "walking" and is_zero_approx(run.tilt), "balance cannot fail during tower landing")
		run.reach_tower()
		_check(run.checkpoint_tower == reached + 1, "landing saves tower %d checkpoint" % (reached + 1))


func _force_balance_fall(run: TightropeRules) -> void:
	run.tilt = 0.99
	run.tilt_vel = 2.0
	var events := run.update(1.0 / 60.0, 0.0)
	_check(run.state == "falling" and events.back().get("type") == "fall", "balance fall triggers for checkpoint test")


func _enter_rope(run: TightropeRules) -> void:
	_check(run.try_step() == "ok", "first step onto rope begins")
	run.reach_rope()
	_check(run.on_rope, "first step onto rope completes")


func _test_wind_disabled() -> void:
	var run := Rules.new(8)
	_check(run.stage_kind() == "Balance", "tower one uses balance while wind is disabled")
	_enter_rope(run)
	for tick in 120:
		for event in run.update(0.1, 0.0):
			_check(event["type"] != "gust", "disabled wind emitted a gust at tick %d" % tick)
		if run.state == "falling":
			run.respawn()
			_enter_rope(run)
		_check(is_zero_approx(run.wind_ramp) and is_equal_approx(run.wind_timer, 0.6), "disabled wind changed its timer or ramp at tick %d" % tick)


func _test_birds() -> void:
	var run := Rules.new(4)
	run.tower = 2
	_enter_rope(run)
	run.bird_timer = 0.0
	var events := run.update(1.0 / 60.0, 0.0)
	_check(events.size() == 1 and events[0]["type"] == "birds" and run.bird_phase == "approach", "birds approach before warning")
	_check(run.bird_entry_side == -1 or run.bird_entry_side == 1, "birds enter from a side")
	_check(Rules.BIRD_PATTERNS.has(run.bird_dirs) and run.bird_dir == run.bird_dirs[1], "bird pattern is valid and the center sets the response")
	run.bird_timer = Rules.BIRD_APPROACH * 0.5
	events = run.update(1.0 / 60.0, 0.0)
	_check(run.bird_phase == "approach" and events.is_empty() and is_zero_approx(run.bird_gust_timer), "gust does not trigger during approach")
	run.bird_timer = 0.0
	events = run.update(1.0 / 60.0, 0.0)
	_check(run.bird_phase == "warn" and is_equal_approx(run.bird_timer, 1.0) and events.size() == 1 and events[0]["type"] == "birds_arrived", "one-second reaction countdown starts when birds arrive")
	run.bird_timer = 0.5
	run.tilt_vel = 0.0
	events = run.update(1.0 / 60.0, -float(run.bird_dir))
	_check(run.bird_response == -run.bird_dir and run.bird_phase == "rest" and is_equal_approx(run.bird_timer, Rules.BIRD_REST), "wrong response ends and resets countdown immediately")
	_check(run.state == "falling" and run.fall_dir == -run.bird_dir and events.back().get("reason") == "birds", "wrong lean falls in gust direction")
	_check(events.any(func(event: Dictionary) -> bool: return event["type"] == "bird_gust" and event["dir"] == -run.bird_dir), "gust triggers immediately on wrong response")
	_check(run.tilt_vel * run.bird_dir < 0.0, "bird gust pushes opposite the center bird")
	var correct := Rules.new(5)
	correct.tower = 2
	_enter_rope(correct)
	correct.bird_phase = "warn"
	correct.bird_timer = Rules.BIRD_WARN
	correct.bird_dir = 1
	for tick in 5:
		correct.update(0.1, 0.0)
	_check(correct.bird_phase == "warn" and is_equal_approx(correct.bird_timer, 0.5) and is_zero_approx(correct.bird_gust_timer), "no gust before a half-second response")
	correct.tilt_vel = 0.4
	events = correct.update(1.0 / 60.0, 1.0)
	_check(correct.bird_response == 1 and correct.state == "walking" and correct.bird_phase == "rest" and is_equal_approx(correct.bird_timer, Rules.BIRD_REST) and correct.bird_gust_timer > 0.0 and correct.tilt_vel < 0.0, "half-second response resets countdown and survives immediate gust")
	_check(events.any(func(event: Dictionary) -> bool: return event["type"] == "birds_pass") and events.any(func(event: Dictionary) -> bool: return event["type"] == "bird_gust" and event["dir"] == -1), "success emits pass and gust events")
	var last_frame := Rules.new(7)
	last_frame.tower = 2
	_enter_rope(last_frame)
	last_frame.bird_phase = "warn"
	last_frame.bird_timer = 0.01
	last_frame.bird_dir = -1
	last_frame.update(1.0 / 60.0, -1.0)
	_check(last_frame.state == "walking" and last_frame.bird_response == -1 and last_frame.bird_gust_timer > 0.0, "lean registered in the final countdown frame triggers the gust")
	correct.update(1.0 / 60.0, 1.0)
	_check(correct.push < 0.0 and correct.bird_gust_timer < Rules.BIRD_GUST_DURATION, "bird gust continues briefly after countdown")
	var idle := Rules.new(6)
	idle.tower = 2
	_enter_rope(idle)
	idle.bird_phase = "warn"
	idle.bird_timer = 0.0
	idle.update(1.0 / 60.0, 0.0)
	_check(idle.state == "falling" and idle.fall_dir == -idle.bird_dir, "missing response fails in gust direction")
	var saw_left := false
	var saw_right := false
	var seen_patterns: Array = []
	for seed_value in range(1, 101):
		var flock := Rules.new(seed_value)
		flock.tower = 2
		_enter_rope(flock)
		flock.bird_timer = 0.0
		flock.update(1.0 / 60.0, 0.0)
		saw_left = saw_left or flock.bird_entry_side == -1
		saw_right = saw_right or flock.bird_entry_side == 1
		if not seen_patterns.has(flock.bird_dirs):
			seen_patterns.append(flock.bird_dirs.duplicate())
	_check(saw_left and saw_right, "bird entry side varies across seeded rounds")
	_check(seen_patterns.size() == 4 and seen_patterns.has([-1, -1, -1]) and seen_patterns.has([1, 1, 1]) and seen_patterns.has([-1, 1, -1]) and seen_patterns.has([1, -1, 1]), "all congruent and incongruent bird conditions occur")
	_check(Rules.bird_check(1, 1) and Rules.bird_check(-1, -1), "correct bird lean passes")
	_check(not Rules.bird_check(0, 1) and not Rules.bird_check(-1, 1), "missing or wrong bird lean fails")


func _test_tension() -> void:
	var run := Rules.new(5)
	run.tower = 3
	_check(run.release() == "none", "tension cannot be released on checkpoint")
	_enter_rope(run)
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
	_check(run.try_step() == "ok" and run.step == 1, "first step is safe from sway")
	run.reach_rope()
	run.time += 0.5
	_check(run.try_step() == "shove" and run.step == 2, "unsafe sway shoves after entering rope")
	var safe := Rules.new(6)
	safe.tower = 4
	safe.sway = 0.05
	_enter_rope(safe)
	safe.time += 0.5
	_check(safe.try_step() == "ok", "safe sway allows step")


func _test_determinism() -> void:
	var first := Rules.new(42)
	var second := Rules.new(42)
	_enter_rope(first)
	_enter_rope(second)
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
			if run.step == 1 and not run.on_rope:
				run.reach_rope()
			if result == "tower":
				run.reach_tower()
			if result == "won":
				_check(run.state == "won" and run.tower == 4, "seed %d win state" % seed_value)
				return
	_check(false, "seed %d could not complete course" % seed_value)
