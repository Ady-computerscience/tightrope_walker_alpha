class_name WireTensionGauge
extends Control
## Three-zone wire tension dial built over a CC0 semicircular HUD asset.

const BASE := preload("res://assets/ui/wire_gauge_base.svg")
const GREEN := Color("7ee8ac")
const YELLOW := Color("ffca62")
const RED := Color("ff6a58")
const NEEDLE := Color("fff4e4")
const CENTER := Vector2(93.0, 85.0)
const ARC_RADIUS := 73.0
const GREEN_END := 0.55
const YELLOW_END := 0.80

var tension := 0.0
var displayed_tension := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(186.0, 134.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	displayed_tension = move_toward(displayed_tension, tension, delta * 1.8)
	queue_redraw()


func set_tension(value: float) -> void:
	tension = clampf(value, 0.0, 1.0)
	if not is_visible_in_tree():
		displayed_tension = tension
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(BASE, Rect2(Vector2(0.0, -8.0), Vector2(186.0, 186.0)), false)
	_draw_zone(0.0, GREEN_END, GREEN)
	_draw_zone(GREEN_END, YELLOW_END, YELLOW)
	_draw_zone(YELLOW_END, 1.0, RED)
	var needle_angle := PI + PI * displayed_tension
	var tip := CENTER + Vector2(cos(needle_angle), sin(needle_angle)) * 59.0
	draw_line(CENTER + Vector2(0.0, 1.0), tip + Vector2(0.0, 1.0), Color("090d1f"), 6.0, true)
	draw_line(CENTER, tip, NEEDLE, 3.0, true)
	draw_circle(CENTER, 6.0, Color("293248"), true)
	draw_circle(CENTER, 2.5, NEEDLE, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(13.0, 119.0), "WIRE TENSION", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, NEEDLE)
	draw_string(font, Vector2(142.0, 119.0), "%d%%" % roundi(displayed_tension * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 31, 12, RED if displayed_tension >= YELLOW_END else (YELLOW if displayed_tension >= GREEN_END else GREEN))


func _draw_zone(from_fraction: float, to_fraction: float, color: Color) -> void:
	var start := PI + PI * from_fraction + 0.025
	var finish := PI + PI * to_fraction - 0.025
	draw_arc(CENTER, ARC_RADIUS, start, finish, 28, color, 13.0, true)
