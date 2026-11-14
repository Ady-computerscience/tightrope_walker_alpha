class_name GameHUD
extends CanvasLayer
## On-screen status and menus for keyboard and gamepad players.

signal replay_requested
signal stargaze_requested
signal pause_requested

const CREAM := Color("fff4e4")
const GOLD := Color("ffca62")
const CORAL := Color("ff6a58")
const MINT := Color("7ee8ac")
const PANEL := Color("2c182e")

var _progress: Label
var _stage: Label
var _cue: Label
var _balance: ProgressBar
var _caption: Label
var _toast: Label
var _win: PanelContainer
var _win_text: Label
var _paused: PanelContainer


func _ready() -> void:
	_build()


func show_status(tower: int, step: int, steps: int, kind: String, tilt: float, cue: String) -> void:
	_progress.text = "TOWER %d / 4     STEP %d / %d" % [tower, step, steps]
	_stage.text = kind.to_upper()
	_cue.text = cue
	_balance.value = clampf((tilt + 1.0) * 50.0, 0.0, 100.0)


func show_toast(message: String) -> void:
	_toast.text = message
	_toast.visible = true
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_toast) and _toast.text == message:
			_toast.visible = false
	)


func show_caption(message: String) -> void:
	_caption.text = message
	_caption.visible = not message.is_empty()


func show_win(seconds: float, falls: int, best_time: float) -> void:
	_win_text.text = "YOU CROSSED THE SKY\n\nTime: %.1f s    Falls: %d\nBest: %.1f s" % [seconds, falls, best_time]
	_win.visible = true


func hide_win() -> void:
	_win.visible = false


func set_paused(value: bool) -> void:
	_paused.visible = value


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 134.0
	top.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top.add_child(top_box)
	_progress = _label("TOWER 1 / 4", 21, GOLD)
	top_box.add_child(_progress)
	_stage = _label("WIND", 17, MINT)
	top_box.add_child(_stage)
	_balance = ProgressBar.new()
	_balance.min_value = 0.0
	_balance.max_value = 100.0
	_balance.value = 50.0
	_balance.show_percentage = false
	_balance.custom_minimum_size = Vector2(0, 12)
	top_box.add_child(_balance)
	top_box.add_child(_label("W / O: left / right foot   •   Q / P: lean left / right", 14, CREAM))
	_cue = _label("Space: release tension", 14, CREAM)
	top_box.add_child(_cue)

	_caption = _label("", 22, CREAM)
	_caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_top = 124.0
	_caption.offset_left = -320.0
	_caption.offset_right = 320.0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.visible = false
	root.add_child(_caption)

	_toast = _label("", 22, GOLD)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 184.0
	_toast.offset_left = -280.0
	_toast.offset_right = 280.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	root.add_child(_toast)

	_win = PanelContainer.new()
	_win.set_anchors_preset(Control.PRESET_CENTER)
	_win.offset_left = -200.0
	_win.offset_right = 200.0
	_win.offset_top = -130.0
	_win.offset_bottom = 130.0
	_win.add_theme_stylebox_override("panel", _panel_style())
	_win.visible = false
	root.add_child(_win)
	var win_box := VBoxContainer.new()
	_win.add_child(win_box)
	_win_text = _label("", 23, GOLD)
	_win_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_box.add_child(_win_text)
	var replay := _button("PLAY AGAIN")
	win_box.add_child(replay)
	replay.pressed.connect(func() -> void: replay_requested.emit())
	var stargaze := _button("STARGAZE")
	win_box.add_child(stargaze)
	stargaze.pressed.connect(func() -> void: stargaze_requested.emit())

	_paused = PanelContainer.new()
	_paused.set_anchors_preset(Control.PRESET_CENTER)
	_paused.offset_left = -160.0
	_paused.offset_right = 160.0
	_paused.offset_top = -80.0
	_paused.offset_bottom = 80.0
	_paused.add_theme_stylebox_override("panel", _panel_style())
	_paused.visible = false
	root.add_child(_paused)
	var pause_box := VBoxContainer.new()
	_paused.add_child(pause_box)
	pause_box.add_child(_label("PAUSED", 28, GOLD))
	var resume := _button("RESUME")
	pause_box.add_child(resume)
	resume.pressed.connect(func() -> void: pause_requested.emit())
	var restart := _button("RESTART")
	pause_box.add_child(restart)
	restart.pressed.connect(func() -> void: replay_requested.emit())


func _label(message: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = message
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


func _button(message: String) -> Button:
	var node := Button.new()
	node.text = message
	node.custom_minimum_size = Vector2(100, 50)
	node.add_theme_font_size_override("font_size", 18)
	return node


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	return style
