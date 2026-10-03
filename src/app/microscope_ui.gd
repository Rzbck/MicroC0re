extends CanvasLayer

signal resume_requested
signal fit_requested
signal reset_requested
signal new_seed_requested
signal quit_requested
signal inspector_close_requested

var root_control: Control
var menu_overlay: ColorRect
var inspector_panel: PanelContainer
var inspector_title: Label
var inspector_body: RichTextLabel


func _init() -> void:
	layer = 30
	_build_root()
	_build_menu()
	_build_inspector()


func _build_root() -> void:
	root_control = Control.new()
	root_control.name = "UIRoot"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)


func _panel_style(alpha: float = 0.86) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.020, 0.024, alpha)
	style.border_color = Color(0.18, 0.34, 0.32, 0.70)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(210.0, 28.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 11)
	return button


func _build_menu() -> void:
	menu_overlay = ColorRect.new()
	menu_overlay.name = "PauseMenuOverlay"
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.color = Color(0.0, 0.0, 0.0, 0.64)
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_overlay.visible = false
	root_control.add_child(menu_overlay)

	var panel := PanelContainer.new()
	panel.name = "PauseMenu"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -128.0
	panel.offset_top = -145.0
	panel.offset_right = 128.0
	panel.offset_bottom = 145.0
	panel.add_theme_stylebox_override("panel", _panel_style(0.98))
	menu_overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "MICROC0RE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.70, 0.96, 0.85))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MICROSCOPE PAUSED"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 8)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.66, 0.62))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1.0, 6.0)
	box.add_child(spacer)

	var resume := _make_button("RESUME")
	resume.pressed.connect(_emit_resume)
	box.add_child(resume)

	var fit := _make_button("FIT MICROSCOPE")
	fit.pressed.connect(_emit_fit)
	box.add_child(fit)

	var reset := _make_button("RESET SAME SEED")
	reset.pressed.connect(_emit_reset)
	box.add_child(reset)

	var new_seed := _make_button("NEW SEED")
	new_seed.pressed.connect(_emit_new_seed)
	box.add_child(new_seed)

	var quit := _make_button("QUIT")
	quit.pressed.connect(_emit_quit)
	box.add_child(quit)


func _build_inspector() -> void:
	# The viewport is authored at 640x360 and then scaled to the desktop window.
	# Keep this card intentionally tiny in internal pixels so it stays discreet
	# at 1280x720, 1440p and ultrawide desktop scales.
	inspector_panel = PanelContainer.new()
	inspector_panel.name = "OrganismInspector"
	inspector_panel.anchor_left = 0.0
	inspector_panel.anchor_top = 0.0
	inspector_panel.anchor_right = 0.0
	inspector_panel.anchor_bottom = 0.0
	inspector_panel.offset_left = 3.0
	inspector_panel.offset_top = 3.0
	inspector_panel.offset_right = 108.0
	inspector_panel.offset_bottom = 70.0
	inspector_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	inspector_panel.add_theme_stylebox_override("panel", _panel_style(0.76))
	inspector_panel.visible = false
	root_control.add_child(inspector_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	inspector_panel.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	box.add_child(header)

	inspector_title = Label.new()
	inspector_title.text = "ORGANISM"
	inspector_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_title.clip_text = true
	inspector_title.add_theme_font_size_override("font_size", 6)
	inspector_title.add_theme_color_override("font_color", Color(0.75, 0.96, 0.88))
	header.add_child(inspector_title)

	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(12.0, 12.0)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 6)
	close.pressed.connect(_emit_inspector_close)
	header.add_child(close)

	inspector_body = RichTextLabel.new()
	inspector_body.bbcode_enabled = false
	inspector_body.fit_content = false
	inspector_body.scroll_active = false
	inspector_body.selection_enabled = false
	inspector_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_body.add_theme_font_size_override("normal_font_size", 5)
	inspector_body.add_theme_color_override("default_color", Color(0.76, 0.84, 0.82))
	box.add_child(inspector_body)


func show_menu() -> void:
	menu_overlay.visible = true


func hide_menu() -> void:
	menu_overlay.visible = false


func is_menu_open() -> bool:
	return menu_overlay.visible


func show_inspector(title_text: String, body_text: String) -> void:
	inspector_title.text = title_text
	inspector_body.text = body_text
	inspector_panel.visible = true


func update_inspector(title_text: String, body_text: String) -> void:
	if not inspector_panel.visible:
		return
	inspector_title.text = title_text
	inspector_body.text = body_text


func hide_inspector() -> void:
	inspector_panel.visible = false


func is_inspector_open() -> bool:
	return inspector_panel.visible


func _emit_resume() -> void:
	resume_requested.emit()


func _emit_fit() -> void:
	fit_requested.emit()


func _emit_reset() -> void:
	reset_requested.emit()


func _emit_new_seed() -> void:
	new_seed_requested.emit()


func _emit_quit() -> void:
	quit_requested.emit()


func _emit_inspector_close() -> void:
	inspector_close_requested.emit()
