class_name UI extends RefCounted
## Chunky, friendly UI style used by every screen.
static var _title: Font
static var _body: FontVariation

static func title_font() -> Font:
	if _title == null: _title = load("res://fonts/titan.ttf")
	return _title

static func body_font() -> Font:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = load("res://fonts/nunito.ttf")
		_body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	return _body

static func style(c: Color, r := 18, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	s.anti_aliasing = true
	return s

static func _chunky(c: Color, depth: int, offset := 0) -> StyleBoxFlat:
	var s := style(c, 18)
	s.border_color = c.darkened(0.32)
	s.border_width_bottom = depth
	s.content_margin_bottom = 9.0 + depth - offset
	s.content_margin_top = 9.0 + offset
	s.shadow_color = Color(0.03, 0.03, 0.2, 0.28)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

static func label(text: String, size := 18, color := Color.WHITE, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", title_font() if title else body_font())
	return l

static func outlined(l: Label, width := 8, c := Color(0.07, 0.06, 0.28, 0.9)) -> Label:
	l.add_theme_constant_override("outline_size", width)
	l.add_theme_color_override("font_outline_color", c)
	return l

static func button(text: String, color := Color("3d7bff"), size := 18, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", title_font())
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	var depth := 6 if size >= 18 else 4
	b.add_theme_stylebox_override("normal", _chunky(color, depth))
	b.add_theme_stylebox_override("hover", _chunky(color.lightened(0.12), depth))
	b.add_theme_stylebox_override("pressed", _chunky(color.darkened(0.08), 1, depth - 1))
	b.add_theme_stylebox_override("disabled", _chunky(color.darkened(0.35), depth))
	var fo := _chunky(color.lightened(0.1), depth)
	fo.border_color = Color.WHITE
	fo.set_border_width_all(3)
	fo.border_width_bottom = depth
	b.add_theme_stylebox_override("focus", fo)
	if cb.is_valid(): b.pressed.connect(cb)
	return b

static func panel(c := Color(0.1, 0.11, 0.38, 0.95)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(c, 28, Color(1, 1, 1, 0.16), 2)
	s.shadow_color = Color(0.02, 0.02, 0.18, 0.45)
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 8)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 20
	s.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", s)
	return p

static func pill(c := Color(0.08, 0.09, 0.32, 0.82)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(c, 22)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func input(placeholder: String, text := "", size := 18) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.add_theme_font_size_override("font_size", size)
	e.add_theme_font_override("font", body_font())
	e.add_theme_stylebox_override("normal", style(Color(1, 1, 1, 0.96), 14))
	e.add_theme_stylebox_override("focus", style(Color(1, 1, 1), 14, Color("ffc928"), 3))
	e.add_theme_color_override("font_color", Color("1a1b55"))
	e.add_theme_color_override("font_placeholder_color", Color(0.1, 0.1, 0.35, 0.5))
	e.add_theme_color_override("caret_color", Color("ff4f8b"))
	return e

static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c

static func center(c: Control) -> CenterContainer:
	var w := CenterContainer.new()
	full(w)
	w.add_child(c)
	return w
