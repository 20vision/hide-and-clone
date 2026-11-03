class_name Clone extends CharacterBody3D
## A clone: a glossy little robot. Local player, remote player, bot or frozen decoy.
## The body is six solid parts moved by hand-written animation with spring follow-through.
enum {LOCAL, REMOTE, BOT, DECOY}
const SPEED := 6.2
const JUMP := 7.2
const GRAV := 20.0
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D screen_tex: hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 glow : source_color = vec3(0.3, 0.6, 1.0);
uniform vec3 pivot = vec3(0.0);
uniform int part = 0;
uniform int eye_mode = 0;
uniform float eye_open = 1.0;
uniform vec2 eye_look = vec2(0.0);
uniform float camo = 0.0;
uniform float rim = 0.0;
uniform float eye_vis = 1.0;
varying vec3 rp;
varying vec3 wn;
varying float occ;
float seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a; vec2 ba = b - a; return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0)); }
float arc(vec2 p, float r) { float a = atan(p.x, p.y); float lim = 1.25; if (abs(a) < lim) return abs(length(p) - r); return length(vec2(abs(p.x), p.y) - r * vec2(sin(lim), cos(lim))); }
void vertex() {
	rp = VERTEX + pivot;
	occ = UV.x;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 alb = vec3(0.84, 0.82, 0.95);
	float dark = 0.0;
	float gloss = 0.0;
	vec3 emit = vec3(0.0);
	float eyes = 0.0;
	vec3 hot = mix(glow, vec3(1.0), 0.82);
	float ax = abs(rp.x);
	if (part == 0) {
		vec2 q = vec2(rp.x, rp.y - 1.328);
		float r = pow(pow(abs(q.x) / 0.425, 3.0) + pow(abs(q.y) / 0.3, 3.0), 1.0 / 3.0);
		float front = step(rp.z, 0.0);
		float vis = smoothstep(1.0, 0.975, r) * front;
		if (vis > 0.0) {
			vec2 ep = vec2(ax - 0.175 - eye_look.x * sign(rp.x), q.y + 0.005 - eye_look.y);
			ep.y /= max(eye_open, 0.08);
			float d = 10.0;
			if (eye_mode == 0) d = arc(ep + vec2(0.0, 0.065), 0.118);
			else if (eye_mode == 1) d = seg(ep, vec2(-0.09, 0.055), vec2(0.09, -0.03));
			else if (eye_mode == 2) d = min(seg(ep, vec2(-0.06, -0.06), vec2(0.06, 0.06)), seg(ep, vec2(-0.06, 0.06), vec2(0.06, -0.06)));
			else d = abs(length(ep) - 0.07);
			vec3 ec = eye_mode == 1 ? vec3(1.0, 0.16, 0.08) : glow;
			float core = smoothstep(0.036, 0.026, d);
			float halo = exp(-d * 15.0) * 0.8;
			emit += mix(ec * halo, mix(ec, vec3(1.0), 0.84), core) * vis;
			eyes = max(core, halo * 0.7) * vis;
		}
		alb = mix(alb, vec3(0.006, 0.005, 0.016), vis);
		gloss = vis;
		float lip = smoothstep(1.11, 1.02, r) * smoothstep(0.97, 1.0, r) * front;
		alb = mix(alb, alb * vec3(0.6, 0.52, 0.86), lip);
		if (rp.z > 0.0) {
			float seam = smoothstep(0.012, 0.005, abs(rp.y - 1.2 + rp.z * 0.08)) * step(ax, 0.5);
			alb = mix(alb, vec3(0.2, 0.15, 0.38), seam);
			vec2 bp = vec2(rp.x, rp.y - 1.42);
			float slot = length(vec2(max(abs(bp.x) - 0.1, 0.0), bp.y));
			float line = smoothstep(0.024, 0.014, slot);
			alb = mix(alb, vec3(0.02, 0.016, 0.05), smoothstep(0.05, 0.04, slot));
			emit += mix(glow * exp(-slot * 22.0) * 0.5, hot, line);
			eyes = max(eyes, line);
		}
		if (ax > 0.5) {
			float cup = smoothstep(0.5, 0.515, ax);
			dark = cup;
			float rr = length(vec2(rp.y - 1.33, rp.z));
			float ring = smoothstep(0.022, 0.012, abs(rr - 0.135)) * smoothstep(0.585, 0.6, ax);
			float rh = exp(-abs(rr - 0.135) * 26.0) * smoothstep(0.56, 0.6, ax);
			emit += mix(glow * rh * 0.8, hot, ring);
			eyes = max(eyes, ring);
		}
	} else if (part == 1) {
		dark = max(smoothstep(0.915, 0.93, rp.y), smoothstep(0.405, 0.42, rp.y) * smoothstep(0.47, 0.455, rp.y));
		if (rp.z > 0.0) {
			vec2 bq = vec2(rp.x, rp.y - 0.7);
			vec2 hb = abs(bq) - vec2(0.13, 0.11);
			float box = length(max(hb, 0.0)) + min(max(hb.x, hb.y), 0.0) - 0.035;
			float panel = smoothstep(0.004, -0.004, box);
			dark = max(dark, panel);
			float bar = smoothstep(0.02, 0.012, length(vec2(max(abs(bq.x) - 0.075, 0.0), abs(abs(bq.y) - 0.045))));
			emit += hot * bar * panel + glow * exp(-abs(box) * 24.0) * 0.1;
			eyes = max(eyes, bar * panel);
		}
	} else if (part == 2) {
		vec2 sh = vec2(0.36, 0.86);
		vec2 el = vec2(0.52, 0.62);
		float t = dot(vec2(ax, rp.y) - sh, el - sh) / dot(el - sh, el - sh);
		dark = smoothstep(0.5, 0.54, t) * smoothstep(0.84, 0.8, t);
	} else if (part == 3) {
		dark = smoothstep(0.268, 0.28, rp.y) * smoothstep(0.34, 0.328, rp.y);
		alb = mix(alb, vec3(0.8, 0.86, 1.0), smoothstep(0.26, 0.04, rp.y));
	}
	alb = mix(alb, vec3(0.022, 0.016, 0.05), dark);
	vec3 n = normalize(wn);
	vec3 L = normalize(vec3(0.34, 0.86, 0.48));
	float nl = dot(n, L);
	vec3 shadow = vec3(0.47, 0.37, 0.86);
	vec3 key = mix(shadow, vec3(1.02, 0.99, 1.03), smoothstep(-0.12, 0.8, nl));
	float o = mix(0.58, 1.0, smoothstep(0.1, 0.9, occ));
	vec3 tint = mix(vec3(1.0), vec3(0.55, 0.42, 0.95), (1.0 - o) * 1.1);
	vec3 solid = alb * key * o * tint;
	solid += alb * vec3(0.1, 0.24, 0.62) * max(-n.y + 0.12, 0.0) * 0.85 * (1.0 - dark);
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float f = pow(1.0 - nv, 3.2);
	solid += mix(glow, vec3(0.78, 0.68, 1.0), 0.45) * f * 0.42 * o * (1.0 - gloss * 0.6);
	vec3 vL = normalize((VIEW_MATRIX * vec4(L, 0.0)).xyz);
	vec3 h = normalize(vL + VIEW);
	float nh = clamp(dot(NORMAL, h), 0.0, 1.0);
	solid += vec3(1.0) * pow(nh, 18.0) * 0.1 * o * (1.0 - dark * 0.6) * (1.0 - gloss);
	if (gloss > 0.0) {
		vec3 rf = reflect(-VIEW, NORMAL);
		float sky = smoothstep(0.1, 0.75, rf.y);
		solid += vec3(0.46, 0.4, 0.72) * sky * 0.3 * gloss + vec3(1.0) * pow(nh, 90.0) * 0.55 * gloss + vec3(0.42, 0.35, 0.9) * f * 0.5 * gloss;
	}
	if (dark > 0.0) solid += vec3(0.5, 0.42, 0.9) * pow(nh, 40.0) * 0.32 * dark + vec3(0.32, 0.24, 0.72) * f * 0.5 * dark;
	if (part == 1) {
		float spill = smoothstep(0.35, 0.0, length(vec2(rp.x, rp.y - 0.68))) * step(rp.z, 0.0);
		solid += glow * spill * 0.1;
	}
	if (part == 0) solid += glow * exp(-abs(ax - 0.56) * 7.0) * 0.14 * (1.0 - dark);
	vec2 uv = SCREEN_UV + NORMAL.xy * vec2(-0.016, 0.016) * (0.35 + pow(1.0 - nv, 2.5));
	vec3 bg = texture(screen_tex, uv).rgb;
	vec3 glass = bg + vec3(1.0) * pow(1.0 - nv, 2.5) * rim;
	ALBEDO = mix(solid + emit, glass + emit * eye_vis, camo);
}
"""
const HALO := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 glow : source_color = vec3(0.3, 0.6, 1.0);
uniform float power = 0.4;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(1.0);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = glow;
	ALPHA = pow(clamp(1.0 - d, 0.0, 1.0), 2.2) * power;
}
"""
const FLOOR_GLOW := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;
uniform vec3 glow : source_color = vec3(0.3, 0.6, 1.0);
uniform float power = 0.3;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = glow;
	ALPHA = pow(clamp(1.0 - d, 0.0, 1.0), 1.6) * power;
}
"""
static var _shader: Shader
static var _halo_shader: Shader
static var _floor_shader: Shader
static var _shadow_shader: Shader
static var _meshes: Dictionary = {}
static var _star_mesh: ArrayMesh
var pid := 0
var mode := REMOTE
var game: Node = null
var tint := Color.WHITE
var seeker := false
var alive := true
var frozen := false
var speed_mult := 1.0
var move_input := Vector2.ZERO
var want_jump := false
var yaw_target := 0.0
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var ai := false
var aim_pitch := 0.0
var wave_mode := false
var _skin := 0
var _visual: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _mats: Array[ShaderMaterial] = []
var _halos: Array[ShaderMaterial] = []
var _label: Label3D
var _chest: Label3D
var _wand: Node3D
var _tip: Node3D
var _flash: MeshInstance3D
var _near := false
var _near_t := 0.0
var _camo := 0.0
var _t := randf() * 10.0
var _speed2d := 0.0
var _phase := randf() * 6.0
var _last_pos := Vector3.ZERO
var _prev_y := 0.0
var _vy := 0.0
var _air := 0.0
var _prev_yaw := 0.0
var _bank := 0.0
var _kick := 0.0
var _hit := 0.0
var _land := 0.0
var _land_v := 0.0
var _head_lag := Vector3.ZERO
var _head_v := Vector3.ZERO
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _look_t := 0.0
var _blink := randf() * 4.0
var _fidget := 0.0
var _fidget_t := 2.0 + randf() * 5.0
var _eye_mode := -1
var _bot_goal := Vector3.ZERO
var _bot_t := 0.0
var _bot_fire := 0.0

func setup(id: int, m: int, g: Node, color: Color, shown_name: String, skin := 0) -> void:
	_skin = skin
	pid = id
	mode = m
	game = g
	tint = color
	collision_layer = 2
	collision_mask = 5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.78
	cs.shape = cap
	cs.position.y = 0.89
	add_child(cs)
	_build(shown_name)

static func _load_parts(path: String) -> Dictionary:
	var d := FileAccess.get_file_as_bytes(path)
	var names: Array[String] = ["head", "torso", "armL", "armR", "legL", "legR"]
	var at := 4
	var out := {}
	for n in names:
		var nv := d.decode_u32(at)
		var ni := d.decode_u32(at + 4)
		at += 8
		var fl := d.slice(at, at + nv * 28).to_float32_array()
		at += nv * 28
		var idx := d.slice(at, at + ni * 4).to_int32_array()
		at += ni * 4
		var v := PackedVector3Array()
		var nr := PackedVector3Array()
		var uv := PackedVector2Array()
		v.resize(nv)
		nr.resize(nv)
		uv.resize(nv)
		var piv: Vector3 = PIVOTS[n]
		for i in nv:
			var k := i * 7
			v[i] = Vector3(fl[k], fl[k + 1], fl[k + 2]) - piv
			nr[i] = Vector3(fl[k + 3], fl[k + 4], fl[k + 5])
			uv[i] = Vector2(fl[k + 6], 0.0)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = nr
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out[n] = mesh
	return out

const PIVOTS := {"head": Vector3(0, 0.98, 0), "torso": Vector3(0, 0.48, 0), "armL": Vector3(-0.36, 0.86, 0), "armR": Vector3(0.36, 0.86, 0), "legL": Vector3(-0.175, 0.4, 0), "legR": Vector3(0.175, 0.4, 0)}
const PART_ID := {"head": 0, "torso": 1, "armL": 2, "armR": 2, "legL": 3, "legR": 3}

func _mat(part_name: String) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("glow", tint)
	m.set_shader_parameter("part", PART_ID[part_name])
	m.set_shader_parameter("pivot", PIVOTS[part_name])
	_mats.append(m)
	return m

func _piece(part_name: String, parent: Node3D) -> Node3D:
	if _meshes.is_empty():
		_meshes = {"hi": _load_parts("res://robot.bin"), "lo": _load_parts("res://robot_lo.bin")}
	var n := Node3D.new()
	n.name = part_name
	parent.add_child(n)
	var m := _mat(part_name)
	var hi := MeshInstance3D.new()
	hi.mesh = _meshes["hi"][part_name]
	hi.material_override = m
	hi.visibility_range_end = 15.0
	n.add_child(hi)
	var lo := MeshInstance3D.new()
	lo.mesh = _meshes["lo"][part_name]
	lo.material_override = m
	lo.visibility_range_begin = 15.0
	n.add_child(lo)
	return n

func _halo(parent: Node3D, pos: Vector3, size: float, power: float) -> void:
	if _halo_shader == null:
		_halo_shader = Shader.new()
		_halo_shader.code = HALO
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = _halo_shader
	m.set_shader_parameter("glow", tint)
	m.set_shader_parameter("power", power)
	m.set_meta("power", power)
	mi.material_override = m
	_halos.append(m)
	parent.add_child(mi)

func _floor_quad(code: String, size: float, power: float, y: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("glow", tint)
	m.set_shader_parameter("power", power)
	var mi := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(size, size)
	mi.mesh = p
	mi.position.y = y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = m
	add_child(mi)
	return m

func _build(shown_name: String) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_torso = _piece("torso", _visual)
	_torso.position = PIVOTS["torso"]
	_head = _piece("head", _torso)
	_head.position = PIVOTS["head"] - PIVOTS["torso"]
	_arm_l = _piece("armL", _torso)
	_arm_l.position = PIVOTS["armL"] - PIVOTS["torso"]
	_arm_r = _piece("armR", _torso)
	_arm_r.position = PIVOTS["armR"] - PIVOTS["torso"]
	_leg_l = _piece("legL", _visual)
	_leg_l.position = PIVOTS["legL"]
	_leg_r = _piece("legR", _visual)
	_leg_r.position = PIVOTS["legR"]
	_halo(_head, Vector3(0, 0.34, -0.5), 1.0, 0.13)
	_halo(_head, Vector3(-0.66, 0.35, 0), 0.72, 0.42)
	_halo(_head, Vector3(0.66, 0.35, 0), 0.72, 0.42)
	_halo(_torso, Vector3(0, 0.2, -0.3), 0.7, 0.14)
	var fg := _floor_quad(FLOOR_GLOW, 2.0, 0.24, 0.016)
	_halos.append(fg)
	var sm := _contact_shadow()
	var smi := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(1.7, 1.7)
	smi.mesh = sp
	smi.position.y = 0.012
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smi.material_override = sm
	add_child(smi)
	_chest = Label3D.new()
	_chest.text = shown_name.substr(0, 9)
	_chest.font = UI.title_font()
	_chest.font_size = 64
	_chest.pixel_size = 0.0028
	_chest.outline_size = 0
	_chest.modulate = tint
	_chest.position = Vector3(0, 0.2, -0.305)
	_chest.rotation.y = PI
	_chest.double_sided = false
	_chest.shaded = false
	_chest.no_depth_test = false
	_torso.add_child(_chest)
	_label = Label3D.new()
	_label.text = shown_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.1
	_label.font_size = 42
	_label.pixel_size = 0.0055
	_label.font = UI.body_font()
	_label.outline_size = 10
	add_child(_label)
	_build_wand()
	set_role(false)

func _build_wand() -> void:
	_wand = Node3D.new()
	_wand.position = Vector3(0.23, -0.37, -0.03)
	_arm_r.add_child(_wand)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.028
	stick.bottom_radius = 0.046
	stick.height = 1.12
	stick.radial_segments = 14
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("241a52")
	smat.roughness = 0.3
	var sm := MeshInstance3D.new()
	sm.mesh = stick
	sm.material_override = smat
	sm.position.y = 0.5
	_wand.add_child(sm)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("fff0a0")
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var star := MeshInstance3D.new()
	star.mesh = _star()
	star.material_override = gmat
	star.position.y = 1.16
	star.scale = Vector3.ONE * 2.0
	_wand.add_child(star)
	_tip = star
	var halo := QuadMesh.new()
	halo.size = Vector2(1.0, 1.0)
	if _halo_shader == null:
		_halo_shader = Shader.new()
		_halo_shader.code = HALO
	var hm := ShaderMaterial.new()
	hm.shader = _halo_shader
	hm.set_shader_parameter("glow", Color("ffb52e"))
	hm.set_shader_parameter("power", 0.75)
	_flash = MeshInstance3D.new()
	_flash.mesh = halo
	_flash.material_override = hm
	_flash.position.y = 1.16
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wand.add_child(_flash)

static func _star() -> ArrayMesh:
	if _star_mesh: return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth := 0.05
	var pts: Array[Vector3] = []
	for i in 10:
		var a := PI * 0.5 + TAU * i / 10.0
		var r := 0.17 if i % 2 == 0 else 0.075
		pts.append(Vector3(cos(a) * r, sin(a) * r, 0))
	for i in 10:
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[(i + 1) % 10]
		for tri: Array in [[Vector3(0, 0, depth), p, q], [Vector3(0, 0, -depth), q, p]]:
			for v: Vector3 in tri: st.add_vertex(v)
	st.generate_normals()
	_star_mesh = st.commit()
	return _star_mesh

func _contact_shadow() -> ShaderMaterial:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = "shader_type spatial;render_mode unshaded,shadows_disabled,depth_draw_never;uniform float a=0.5;void fragment(){float d=length(UV-vec2(0.5))*2.0;ALBEDO=vec3(0.09,0.05,0.24);ALPHA=a*pow(clamp(1.0-d,0.0,1.0),1.3);}"
	var m := ShaderMaterial.new()
	m.shader = _shadow_shader
	return m

## Wand recoil, called whenever this clone fires.
func kick() -> void:
	_kick = 1.0

## Flinch when hit.
func hit_react() -> void:
	_hit = 1.0
	_head_v += Vector3(5.0, 0.0, randf_range(-5.0, 5.0))

func wand_tip() -> Vector3:
	return _tip.global_position if _tip else global_position + Vector3.UP * 1.4

func camo_amount() -> float: return _camo

func wand_ready() -> bool: return _wand != null and _wand.visible

func set_role(is_seeker: bool) -> void:
	seeker = is_seeker
	if _wand: _wand.visible = is_seeker

func set_alive(on: bool) -> void:
	alive = on
	visible = on
	collision_layer = 2 if on else 0
	collision_mask = 5 if on else 0

func teleport(p: Vector3, yaw: float) -> void:
	global_position = p
	net_pos = p
	net_yaw = yaw
	yaw_target = yaw
	rotation.y = yaw
	velocity = Vector3.ZERO
	_last_pos = p

func _physics_process(delta: float) -> void:
	if game == null: return
	match mode:
		LOCAL:
			if ai: _brain(delta)
			_walk(delta)
		BOT:
			_brain(delta)
			_walk(delta)
		REMOTE:
			global_position = global_position.lerp(net_pos, clampf(delta * 14.0, 0.0, 1.0))
			rotation.y = lerp_angle(rotation.y, net_yaw, clampf(delta * 14.0, 0.0, 1.0))
		DECOY: pass

func _walk(delta: float) -> void:
	if not alive: return
	if not is_on_floor(): velocity.y -= GRAV * delta
	var dir := Vector3.ZERO
	if not frozen:
		dir = (Basis(Vector3.UP, yaw_target) * Vector3(move_input.x, 0, move_input.y))
		if dir.length() > 1.0: dir = dir.normalized()
		if want_jump and is_on_floor(): velocity.y = JUMP
	want_jump = false
	var v := dir * SPEED * speed_mult
	velocity.x = lerpf(velocity.x, v.x, clampf(delta * 12.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, v.z, clampf(delta * 12.0, 0.0, 1.0))
	move_and_slide()
	if mode == LOCAL and wand_ready() and not ai:
		rotation.y = lerp_angle(rotation.y, yaw_target, clampf(delta * 18.0, 0.0, 1.0))
	elif dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 12.0, 0.0, 1.0))
	if global_position.y < -20.0: global_position = Vector3(0, 3, 0)

func _spring(x: Vector3, v: Vector3, target: Vector3, k: float, damp: float, dt: float) -> Array:
	var nv := v + ((target - x) * k - v * damp) * dt
	return [x + nv * dt, nv]

## All character motion lives here: run, idle, jump, land, aim, fire, flinch and cheer.
func _process(delta: float) -> void:
	if game == null or _visual == null: return
	var dt := minf(delta, 0.05)
	_t += dt
	var moved := (global_position - _last_pos) * Vector3(1, 0, 1)
	_last_pos = global_position
	_speed2d = lerpf(_speed2d, moved.length() / maxf(delta, 0.001), clampf(dt * 10.0, 0.0, 1.0))
	var w := clampf(_speed2d / SPEED, 0.0, 1.0)
	var run := smoothstep(0.03, 0.4, w)
	_phase += dt * (_speed2d * 2.35 + 0.0)
	var s := sin(_phase)
	var c := cos(_phase)
	_vy = lerpf(_vy, (global_position.y - _prev_y) / maxf(delta, 0.001), clampf(dt * 16.0, 0.0, 1.0))
	_prev_y = global_position.y
	var was_air := _air > 0.5
	var in_air := absf(_vy) > 1.0
	_air = move_toward(_air, 1.0 if in_air else 0.0, dt * 9.0)
	if was_air and not in_air:
		_land_v -= 4.5 + absf(_vy) * 0.3
		_head_v.x += 3.0
	# landing spring
	_land_v += (-_land * 170.0 - _land_v * 15.0) * dt
	_land += _land_v * dt
	# banking into turns
	var yaw_d := wrapf(rotation.y - _prev_yaw, -PI, PI) / maxf(dt, 0.001)
	_prev_yaw = rotation.y
	_bank = lerpf(_bank, clampf(yaw_d * 0.05, -0.32, 0.32) * run, clampf(dt * 8.0, 0.0, 1.0))
	_kick = move_toward(_kick, 0.0, dt * 4.2)
	_hit = move_toward(_hit, 0.0, dt * 2.0)
	var back := _kick * _kick
	var celebrating: bool = alive and game.phase == "end" and not wave_mode
	# fidgets when standing around
	_fidget_t -= dt
	if _fidget_t < 0.0 and run < 0.1:
		_fidget_t = 4.0 + randf() * 7.0
		_fidget = 1.0
	_fidget = move_toward(_fidget, 0.0, dt * 0.9)
	var hop := sin(_fidget * PI)
	# whole body
	var breathe := sin(_t * 2.1)
	var bob := absf(c) * 0.095 * run
	var squash := clampf(_land * 1.0, -0.26, 0.26) + clampf(_vy * 0.012, -0.1, 0.12) * _air
	var cheer := 0.0
	if celebrating:
		cheer = absf(sin(_t * 5.2))
		bob += cheer * 0.42
	_visual.position = Vector3(s * 0.035 * run + sin(_t * 0.9) * 0.012 * (1.0 - run), bob + _land * 0.25, 0.0)
	_visual.scale = Vector3(1.0 - squash * 0.65, 1.0 + squash, 1.0 - squash * 0.65)
	_visual.rotation = Vector3(0.0, 0.0, _bank)
	# torso leads the motion
	var lean := -0.25 * run - 0.1 * _air * signf(_vy + 0.001) * 0.0
	_torso.rotation = Vector3(lean + back * 0.2 + _hit * 0.3 + breathe * 0.012, c * 0.2 * run, s * 0.065 * run + sin(_t * 0.9) * 0.02 * (1.0 - run))
	_torso.scale = Vector3.ONE * (1.0 + breathe * 0.01 * (1.0 - run))
	# legs
	var stride := 0.98 * run
	var ll := s * stride
	var lr := -s * stride
	var tuck := _air * (0.45 if _vy > 0.0 else 0.2)
	_leg_l.rotation = Vector3(ll + tuck * 1.1, 0.0, -0.07 - 0.05 * _air - sin(_t * 0.9) * 0.012)
	_leg_r.rotation = Vector3(lr - tuck * 0.55, 0.0, 0.07 + 0.05 * _air - sin(_t * 0.9) * 0.012)
	_leg_l.position.y = PIVOTS["legL"].y + maxf(-s, 0.0) * 0.07 * run
	_leg_r.position.y = PIVOTS["legR"].y + maxf(s, 0.0) * 0.07 * run
	# arms swing against the legs, fly up in the air
	var arm_up := _air * (1.25 if _vy > 0.0 else 0.85)
	var a_l := Vector3(-s * 1.05 * run + breathe * 0.025, 0.0, -0.05 - arm_up - sin(_t * 1.3) * 0.02)
	var a_r := Vector3(s * 1.05 * run + breathe * 0.025, 0.0, 0.05 + arm_up + sin(_t * 1.3) * 0.02)
	if _fidget > 0.0 and run < 0.2:
		if _skin % 2 == 0: a_r = a_r.lerp(Vector3(0.0, 0.0, 2.35 + sin(_t * 15.0) * 0.28), hop)
		else: a_l = a_l.lerp(Vector3(0.3, 0.0, -1.1), hop)
	if wave_mode:
		a_r = Vector3(0.0, 0.0, 2.3 + sin(_t * 7.0) * 0.32)
	if celebrating:
		a_l = Vector3(0.0, 0.0, -2.4 - sin(_t * 10.4) * 0.3)
		a_r = Vector3(0.0, 0.0, 2.4 + sin(_t * 10.4) * 0.3)
	if wand_ready():
		a_r = Vector3(1.15 + aim_pitch * 0.75 + back * 0.85, 0.0, 0.08)
		var want := Basis.from_euler(Vector3(deg_to_rad(-48.0 + aim_pitch * 30.0 + back * 40.0), 0.0, deg_to_rad(-15.0)))
		_wand.basis = Basis.from_euler(a_r).inverse() * want
		_flash.scale = Vector3.ONE * (0.62 + back * 2.8 + sin(_t * 9.0) * 0.05)
		_tip.scale = Vector3.ONE * (2.0 + back * 1.5)
		_tip.rotation.y += dt * (2.2 + back * 28.0)
	_arm_l.rotation = a_l
	_arm_r.rotation = a_r
	# head follows late, like it has weight
	var head_target := Vector3(-lean * 0.75 + c * 0.03 * run, 0.0, -s * 0.05 * run)
	_look_t -= dt
	if _look_t < 0.0:
		_look_t = 1.5 + randf() * 3.5
		_look_target = Vector2(randf_range(-0.5, 0.5), randf_range(-0.12, 0.12)) * (1.0 - run)
	_look = _look.lerp(_look_target, clampf(dt * 5.0, 0.0, 1.0))
	head_target.y += _look.x * 0.75
	head_target.x += _look.y
	var sp := _spring(_head_lag, _head_v, head_target, 95.0, 11.0, dt)
	_head_lag = sp[0]
	_head_v = sp[1]
	_head.rotation = _head_lag
	# eyes
	_blink -= dt
	if _blink < 0.0: _blink = 2.2 + randf() * 3.8
	var open := smoothstep(0.0, 0.05, absf(_blink - 0.07) - 0.02)
	var mode_now := 0
	if _hit > 0.15: mode_now = 2
	elif seeker and game.phase != "lobby" and game.phase != "end": mode_now = 1
	elif _speed2d > 5.0 and _kick <= 0.0 and false: mode_now = 3
	if mode_now != _eye_mode:
		_eye_mode = mode_now
		for m in _mats: m.set_shader_parameter("eye_mode", mode_now)
	var eye_shift := _look * Vector2(0.05, 0.04)
	for m in _mats:
		m.set_shader_parameter("eye_open", open)
		m.set_shader_parameter("eye_look", eye_shift)
	_update_look(dt)

## The chameleon part: near things and standing still you turn to glass.
func _update_look(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var hiding: bool = game.is_hiding_look(self)
	var target := 0.0
	var eye_alpha := 1.0
	_near_t -= delta
	if _near_t <= 0.0 and hiding:
		_near_t = 0.25 + randf() * 0.1
		_near = _check_near()
	if hiding:
		var base: float = game.visibility()
		var moving := _speed2d > 1.0
		var factor := 1.0
		if _near and moving: factor = 1.8
		elif not _near and not moving: factor = 2.0
		elif not _near and moving: factor = 3.2
		var v := clampf(base * factor, 0.0, 1.0)
		var dist := cam.global_position.distance_to(global_position) if cam else 50.0
		v = clampf(v + clampf(1.0 - dist / 5.0, 0.0, 1.0) * 0.14 * minf(base * 5.0, 1.0), 0.0, 1.0)
		var me: bool = (mode == LOCAL)
		if me: v = maxf(v, 0.35)
		target = 1.0 - v
		eye_alpha = clampf(0.03 + base * 0.6 + clampf(1.0 - dist / 7.0, 0.0, 1.0) * 0.75, 0.0, 1.0)
		if me: eye_alpha = 1.0
	_camo = lerpf(_camo, target, clampf(delta * 5.0, 0.0, 1.0))
	for m in _mats:
		m.set_shader_parameter("camo", _camo)
		m.set_shader_parameter("rim", (1.0 - _camo) * 0.5 + 0.02)
		m.set_shader_parameter("eye_vis", eye_alpha)
	var halo_mult := 1.0 - _camo * (1.0 - eye_alpha * 0.4)
	for h in _halos:
		if h.has_meta("power"): h.set_shader_parameter("power", float(h.get_meta("power")) * halo_mult)
	_chest.modulate.a = 1.0 - _camo * (1.0 - eye_alpha * 0.25)
	_label.visible = game.show_label(self)

func _check_near() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.5
	q.shape = sp
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * 0.8)
	q.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

# --- simple bot brain -----------------------------------------------------
func _brain(delta: float) -> void:
	_bot_t -= delta
	_bot_fire -= delta
	if frozen or not alive:
		move_input = Vector2.ZERO
		return
	var goal_near := Vector2(global_position.x - _bot_goal.x, global_position.z - _bot_goal.z).length() < 1.0
	if seeker and game.phase == "seek":
		var tgt: Clone = game.nearest_hider(self, 13.0)
		if tgt:
			_bot_goal = tgt.global_position
			_bot_t = 1.0
			if _bot_fire <= 0.0:
				_bot_fire = 1.1 + randf() * 0.9
				game.ai_fire(self, tgt)
		elif goal_near or _bot_t <= 0.0:
			_bot_goal = game.random_spot()
			_bot_t = 5.0
	else:
		var threat: Clone = game.nearest_seeker(self, 6.0) if game.phase == "seek" else null
		if threat:
			_bot_goal = global_position + (global_position - threat.global_position).normalized() * 6.0
			_bot_t = 0.8
		elif game.phase == "lobby":
			if goal_near or _bot_t <= 0.0:
				_bot_goal = game.random_spot()
				_bot_t = 4.0 + randf() * 3.0
		elif _bot_t <= 0.0 and not _near:
			_bot_goal = game.random_prop_spot()
			_bot_t = 6.0
		elif goal_near:
			move_input = Vector2.ZERO
			return
	var to := _bot_goal - global_position
	to.y = 0.0
	if to.length() < 0.5:
		move_input = Vector2.ZERO
		return
	yaw_target = 0.0
	var d := to.normalized()
	move_input = Vector2(d.x, d.z)
	if is_on_wall() and randf() < 0.05: want_jump = true
