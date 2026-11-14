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
	game.set("mode", "walking")
	game.call("_step")
	if game.get("rules").step != 1 or game.get("walker_animation").current_animation != "walk":
		printerr("FAIL: scene step input did not advance rules")
		quit(1)
		return true
	print("PASS: main scene initializes and step action works")
	quit(0)
	return true
