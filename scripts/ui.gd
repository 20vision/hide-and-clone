class_name UI extends RefCounted
## Small helpers so every screen looks the same.
static var font: Font
static func _f() -> Font:
	if font == null: font = load("res://fonts/future.ttf")
	return font

static func style(c: Color, r := 16, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func label(text: String, size := 18, color := Color.WHITE, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title: l.add_theme_font_override("font", _f())
	return l

static func button(text: String, color := Color("5e8bff"), size := 18, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", _f())
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.15)))
	b.add_theme_stylebox_override("focus", style(color.lightened(0.1), 16, Color.WHITE, 3))
	if cb.is_valid(): b.pressed.connect(cb)
	return b

static func panel(c := Color(0.09, 0.11, 0.2, 0.92)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(c, 20))
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
	return e

static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c

static func center(c: Control) -> CenterContainer:
	var w := CenterContainer.new()
	full(w)
	w.add_child(c)
	return w
