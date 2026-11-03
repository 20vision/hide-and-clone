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

static var _theme: Theme
const INK := Color("1f1d52")
const MUTED := Color("6d6b96")
const VIOLET := Color("7c4dff")

## Global look for dropdowns, sliders, checkboxes, scrollbars and tooltips.
static func theme() -> Theme:
	if _theme: return _theme
	var t := Theme.new()
	t.default_font = body_font()
	var field := style(Color(1, 1, 1, 0.97), 14)
	var field_h := style(Color(1, 1, 1), 14, VIOLET, 3)
	for k: String in ["normal", "pressed", "disabled"]: t.set_stylebox(k, "OptionButton", field)
	t.set_stylebox("hover", "OptionButton", field_h)
	t.set_stylebox("focus", "OptionButton", field_h)
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: t.set_color(k, "OptionButton", INK)
	var pop := style(Color(1, 1, 1), 16)
	pop.shadow_color = Color(0.02, 0.02, 0.2, 0.4)
	pop.shadow_size = 12
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", style(Color("e6dcff"), 10))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_font_size("font_size", "PopupMenu", 16)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.11, 0.32, 0.12)
	track.set_corner_radius_all(6)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	var fill := StyleBoxFlat.new()
	fill.bg_color = VIOLET
	fill.set_corner_radius_all(6)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var fs := StyleBoxFlat.new()
	fs.draw_center = false
	fs.set_border_width_all(2)
	fs.border_color = VIOLET
	fs.set_corner_radius_all(10)
	fs.set_expand_margin_all(5)
	t.set_stylebox("focus", "HSlider", fs)
	t.set_icon("grabber", "HSlider", _dot(22, VIOLET))
	t.set_icon("grabber_highlight", "HSlider", _dot(24, Color("ff4f8b")))
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", VIOLET)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_focus_color", "CheckBox", VIOLET)
	t.set_font_size("font_size", "CheckBox", 16)
	var thin := StyleBoxFlat.new()
	thin.bg_color = Color(0.12, 0.11, 0.32, 0.06)
	thin.set_corner_radius_all(6)
	thin.content_margin_left = 5
	thin.content_margin_right = 5
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.12, 0.11, 0.32, 0.3)
	grab.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", thin)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	var tip := style(Color("1b1a6b"), 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Color.WHITE)
	_theme = t
	return t

static func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

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

static func _soft(c: Color, glow: float, press := 0) -> StyleBoxFlat:
	var s := style(c, 16)
	s.content_margin_top = 11.0 + press
	s.content_margin_bottom = 11.0 - press
	s.shadow_color = Color(c.r, c.g, c.b, glow)
	s.shadow_size = 12 if glow > 0.0 else 0
	s.shadow_offset = Vector2(0, 5)
	return s

static func label(text: String, size := 18, color := INK, title := false) -> Label:
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
	b.add_theme_stylebox_override("normal", _soft(color, 0.28))
	b.add_theme_stylebox_override("hover", _soft(color.lightened(0.1), 0.42))
	b.add_theme_stylebox_override("pressed", _soft(color.darkened(0.08), 0.1, 2))
	b.add_theme_stylebox_override("disabled", _soft(Color(color.r, color.g, color.b, 0.4), 0.0))
	var fo := _soft(color.lightened(0.06), 0.5)
	fo.border_color = INK
	fo.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", fo)
	if cb.is_valid(): b.pressed.connect(cb)
	return b

## One row of the main menu: white at rest, fills with its colour when selected.
static func menu_item(text: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 62)
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_font_override("font", title_font())
	b.add_theme_color_override("font_color", INK)
	for k: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]: b.add_theme_color_override(k, Color.WHITE)
	var rest := style(Color(1, 1, 1, 0.88), 18)
	rest.content_margin_left = 26
	rest.border_width_left = 8
	rest.border_color = color
	rest.shadow_color = Color(0.3, 0.22, 0.6, 0.12)
	rest.shadow_size = 8
	rest.shadow_offset = Vector2(0, 3)
	b.add_theme_stylebox_override("normal", rest)
	var on := style(color, 18)
	on.content_margin_left = 38
	on.shadow_color = Color(color.r, color.g, color.b, 0.5)
	on.shadow_size = 16
	on.shadow_offset = Vector2(0, 6)
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("focus", on)
	var pr := on.duplicate() as StyleBoxFlat
	pr.bg_color = color.darkened(0.1)
	b.add_theme_stylebox_override("pressed", pr)
	b.pressed.connect(cb)
	return b

## Soft moving colour wash used behind every menu screen.
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	full(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
vec3 blob(vec3 base, vec3 c, vec2 uv, vec2 p, float r){ return mix(base, c, smoothstep(r, 0.0, distance(uv, p)) * 0.85); }
void fragment(){
	float t = TIME * 0.12;
	vec2 uv = UV * vec2(1.7, 1.0);
	vec3 col = vec3(0.97, 0.96, 1.0);
	col = blob(col, vec3(1.0, 0.76, 0.86), uv, vec2(0.25 + sin(t) * 0.12, 0.15 + cos(t * 1.3) * 0.1), 0.85);
	col = blob(col, vec3(0.68, 0.84, 1.0), uv, vec2(1.45 + cos(t * 0.8) * 0.14, 0.2 + sin(t) * 0.12), 0.9);
	col = blob(col, vec3(1.0, 0.92, 0.62), uv, vec2(0.3 + cos(t * 0.9) * 0.15, 1.0 + sin(t * 1.1) * 0.08), 0.7);
	col = blob(col, vec3(0.72, 0.96, 0.84), uv, vec2(1.35 + sin(t * 1.2) * 0.15, 1.0 + cos(t) * 0.08), 0.75);
	COLOR = vec4(col, 1.0);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return r

static func panel(c := Color(1, 1, 1, 0.97)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := style(c, 28)
	s.shadow_color = Color(0.3, 0.22, 0.6, 0.22)
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
	e.add_theme_stylebox_override("normal", style(Color(1, 1, 1, 0.96), 14, Color(0.12, 0.11, 0.32, 0.14), 2))
	e.add_theme_stylebox_override("focus", style(Color(1, 1, 1), 14, VIOLET, 3))
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color(0.1, 0.1, 0.35, 0.5))
	e.add_theme_color_override("caret_color", VIOLET)
	return e

static func full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c

static func center(c: Control) -> CenterContainer:
	var w := CenterContainer.new()
	full(w)
	w.add_child(c)
	return w
