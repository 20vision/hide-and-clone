class_name Clone extends CharacterBody3D
## A clone: cute glass bean. Local player, remote player, bot or frozen decoy.
enum {LOCAL, REMOTE, BOT, DECOY}
const SPEED := 6.2
const JUMP := 7.2
const GRAV := 20.0
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D screen_tex: hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 tint2 : source_color = vec3(1.0);
uniform vec3 accent : source_color = vec3(1.0);
uniform int pattern = 0;
uniform bool skinned = false;
uniform vec2 arm_l = vec2(0.0);
uniform vec2 arm_r = vec2(0.0);
uniform vec2 leg_l = vec2(0.0);
uniform vec2 leg_r = vec2(0.0);
uniform float camo = 0.0;
uniform float rim = 0.0;
varying vec3 lp;
varying vec3 wn;
varying float bake;
vec3 rot(vec3 v, vec2 a) {
	float c = cos(a.x); float s = sin(a.x);
	v = vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
	c = cos(a.y); s = sin(a.y);
	return vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}
void limb(inout vec3 p, inout vec3 n, float w, vec3 piv, vec2 a) {
	if (w <= 0.001) return;
	p = mix(p, rot(p - piv, a) + piv, w);
	n = normalize(mix(n, rot(n, a), w));
}
void vertex() {
	lp = VERTEX;
	bake = 1.0;
	if (skinned) {
		bake = UV.x;
		limb(VERTEX, NORMAL, COLOR.r, vec3(-0.42, 1.02, 0.0), arm_l);
		limb(VERTEX, NORMAL, COLOR.g, vec3(0.42, 1.02, 0.0), arm_r);
		limb(VERTEX, NORMAL, COLOR.b, vec3(-0.2, 0.4, 0.0), leg_l);
		limb(VERTEX, NORMAL, COLOR.a, vec3(0.2, 0.4, 0.0), leg_r);
	}
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 col = tint;
	if (skinned) {
		float ax = abs(lp.x);
		if (pattern == 1) col = mix(tint, tint2, smoothstep(0.235, 0.255, abs(fract(lp.y * 2.3) - 0.5)));
		else if (pattern == 2) col = mix(tint, tint2, smoothstep(0.82, 0.85, lp.y));
		else if (pattern == 3) { vec2 q = fract(vec2(atan(lp.x, lp.z) * 2.2, lp.y * 4.4)) - 0.5; col = mix(tint, tint2, smoothstep(0.27, 0.24, length(q))); }
		float glove = smoothstep(0.195, 0.185, length(vec3(ax - 0.625, lp.y - 0.61, lp.z + 0.08))) * step(0.5, ax);
		float boot = smoothstep(0.235, 0.225, lp.y) * step(0.03, ax);
		col = mix(col, accent, max(glove, boot));
		float e = length(vec2(lp.x / 0.3, (lp.y - 1.24) / 0.25));
		float front = step(lp.z, -0.05);
		float edge = smoothstep(1.17, 1.15, e) * front;
		col = mix(col, accent, edge);
		float inner = smoothstep(0.99, 0.97, e) * front;
		vec3 skin = vec3(1.0, 0.86, 0.72);
		float blush = smoothstep(0.075, 0.02, length(vec2(ax - 0.19, lp.y - 1.14))) * 0.5;
		skin = mix(skin, vec3(1.0, 0.36, 0.3), blush);
		vec2 m = vec2(lp.x, lp.y - 1.2);
		float smile = smoothstep(0.016, 0.008, abs(length(m) - 0.085)) * step(m.y, -0.03);
		skin = mix(skin, vec3(0.1, 0.02, 0.05), smile);
		col = mix(col, skin, inner);
	}
	vec3 n = normalize(wn);
	vec3 L = normalize(vec3(0.45, 0.8, 0.4));
	float nl = dot(n, L);
	float sun = clamp((nl + 0.22) / 1.22, 0.0, 1.0);
	sun = sun * sun * (3.0 - 2.0 * sun);
	float occ = bake;
	vec3 sky = mix(vec3(0.62, 0.52, 0.72), vec3(0.86, 0.92, 1.0), n.y * 0.5 + 0.5);
	vec3 light = sky * mix(0.42, 0.98, occ) + vec3(1.0, 0.95, 0.84) * sun * 0.72 * mix(0.6, 1.0, occ);
	vec3 solid = col * light;
	float band = clamp(1.0 - abs(nl + 0.05) * 3.2, 0.0, 1.0);
	solid += col * col * band * 0.1 * occ;
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, 4.0);
	vec3 vL = normalize((VIEW_MATRIX * vec4(L, 0.0)).xyz);
	vec3 h = normalize(vL + VIEW);
	float nh = clamp(dot(NORMAL, h), 0.0, 1.0);
	solid += vec3(1.0) * (pow(nh, 70.0) * 0.5 + pow(nh, 14.0) * 0.13) * occ;
	solid += vec3(0.75, 0.86, 1.0) * fres * 0.3 * occ;
	vec2 uv = SCREEN_UV + NORMAL.xy * vec2(-0.016, 0.016) * (0.35 + pow(1.0 - nv, 2.5));
	vec3 bg = texture(screen_tex, uv).rgb;
	vec3 glass = bg + vec3(1.0) * pow(1.0 - nv, 2.5) * rim;
	ALBEDO = mix(solid, glass, camo);
}
"""
static var _shader: Shader
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
var _visual: Node3D
var _body_mats: Array[ShaderMaterial] = []
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _pupil_mat: StandardMaterial3D
var _label: Label3D
var _wand: Node3D
var _crown: Node3D
var _skin_mat: ShaderMaterial
var _antenna: Node3D
var _kick := 0.0
var _tip: Node3D
var _flash: MeshInstance3D
var aim_pitch := 0.0
var _arm_pivots: Array[Node3D] = []
var _leg_pivots: Array[Node3D] = []
var _body: MeshInstance3D
var _pattern := 0
var _squash := 0.0
var _air := false
var _prev_y := 0.0
var _vy := 0.0
var _pupils: Array[MeshInstance3D] = []
static var _bean_mesh: ArrayMesh
static var _bean_lo: ArrayMesh
static var _shadow_shader: Shader
static var _star_mesh: ArrayMesh
static var _limb_mesh: CapsuleMesh
static var _leg_mesh: CapsuleMesh
var _near := false
var _near_t := 0.0
var _camo := 0.0
var _t := randf() * 10.0
var _speed2d := 0.0
var _blink := randf() * 4.0
var _last_pos := Vector3.ZERO
# bot brain
var _bot_goal := Vector3.ZERO
var _bot_t := 0.0
var _bot_fire := 0.0
var ai := false

func setup(id: int, m: int, g: Node, color: Color, shown_name: String, skin := 0) -> void:
	_pattern = skin % 4
	pid = id
	mode = m
	game = g
	tint = color
	collision_layer = 2
	collision_mask = 5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.46
	cap.height = 1.62
	cs.shape = cap
	cs.position.y = 0.81
	add_child(cs)
	_build(shown_name)

func _part(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	(parent if parent else _visual).add_child(mi)
	return mi

func _glass(is_body := false) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("tint2", tint.lightened(0.38))
	m.set_shader_parameter("accent", Color("fff3e4"))
	m.set_shader_parameter("pattern", _pattern)
	m.set_shader_parameter("skinned", is_body)
	_body_mats.append(m)
	return m

## One sculpted mesh (tools/bake_clone.mjs): smooth body, arms, legs and face.
static func _bean() -> ArrayMesh:
	if _bean_mesh: return _bean_mesh
	_bean_mesh = _load_mesh("res://clone_mesh.bin")
	_bean_lo = _load_mesh("res://clone_mesh_lo.bin")
	return _bean_mesh

static func _load_mesh(path: String) -> ArrayMesh:
	var d := FileAccess.get_file_as_bytes(path)
	var nv := d.decode_u32(0)
	var ni := d.decode_u32(4)
	var fl := d.slice(8, 8 + nv * 44).to_float32_array()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nv)
	norms.resize(nv)
	cols.resize(nv)
	uvs.resize(nv)
	for i in nv:
		var k := i * 11
		verts[i] = Vector3(fl[k], fl[k + 1], fl[k + 2])
		norms[i] = Vector3(fl[k + 3], fl[k + 4], fl[k + 5])
		cols[i] = Color(fl[k + 6], fl[k + 7], fl[k + 8], fl[k + 9])
		uvs[i] = Vector2(fl[k + 10], 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = d.slice(8 + nv * 44, 8 + nv * 44 + ni * 4).to_int32_array()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(-1.2, -0.3, -1.2), Vector3(2.4, 2.6, 2.4))
	return mesh

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

func _pivot(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	_visual.add_child(n)
	return n

func _build(shown_name: String) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_skin_mat = _glass(true)
	_body = _part(_bean(), _skin_mat, Vector3.ZERO)
	_body.visibility_range_end = 16.0
	var far_body := _part(_bean_lo, _skin_mat, Vector3.ZERO)
	far_body.visibility_range_begin = 16.0
	for x: float in [-0.2, 0.2]:
		_leg_pivots.append(_pivot(Vector3(x, 0.4, 0.0)))
	for x: float in [-0.42, 0.42]:
		_arm_pivots.append(_pivot(Vector3(x, 1.02, 0.0)))
	# Lab antenna: every clone has one, it is what makes them clones.
	_antenna = Node3D.new()
	_antenna.position = Vector3(0, 1.7, 0)
	_visual.add_child(_antenna)
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.013
	stalk.bottom_radius = 0.022
	stalk.height = 0.2
	stalk.radial_segments = 8
	var limb_mat := _glass()
	_part(stalk, limb_mat, Vector3(0, 0.09, 0), _antenna)
	var bulb := SphereMesh.new()
	bulb.radius = 0.052
	bulb.height = 0.104
	bulb.radial_segments = 14
	bulb.rings = 7
	var bm := _glass()
	bm.set_shader_parameter("tint", Color("ffe34d"))
	_part(bulb, bm, Vector3(0, 0.215, 0), _antenna)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color.WHITE
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pupil_mat = StandardMaterial3D.new()
	_pupil_mat.albedo_color = Color(0.03, 0.02, 0.06)
	_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pupil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ew := SphereMesh.new()
	ew.radius = 0.068
	ew.height = 0.136
	ew.radial_segments = 18
	ew.rings = 9
	var eh := SphereMesh.new()
	eh.radius = 0.018
	eh.height = 0.036
	eh.radial_segments = 8
	eh.rings = 4
	for x: float in [-0.095, 0.095]:
		var e := _part(ew, _pupil_mat, Vector3(x, 1.285, -0.352))
		e.scale = Vector3(0.95, 1.4, 0.42)
		_eyes.append(e)
		var hi := _part(eh, _eye_mat, Vector3(-0.022, 0.03, -0.052), e)
		hi.scale = Vector3(1.0, 0.72, 1.0)
		_pupils.append(hi)
	var shadow := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.5, 1.5)
	shadow.mesh = quad
	shadow.position.y = 0.012
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.material_override = _contact_shadow()
	add_child(shadow)
	_label = Label3D.new()
	_label.text = shown_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.1
	_label.font_size = 42
	_label.pixel_size = 0.0055
	_label.font = UI.body_font()
	_label.outline_size = 10
	_label.no_depth_test = false
	add_child(_label)
	_wand = Node3D.new()
	_wand.position = Vector3(0.2, -0.42, -0.08)
	_arm_pivots[1].add_child(_wand)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.03
	stick.bottom_radius = 0.048
	stick.height = 1.12
	stick.radial_segments = 12
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("3a1f7a")
	smat.roughness = 0.35
	_part(stick, smat, Vector3(0, 0.5, 0), _wand)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("ffe34d")
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tip = _part(_star(), gmat, Vector3(0, 1.16, 0), _wand)
	_tip.scale = Vector3.ONE * 2.0
	var halo := SphereMesh.new()
	halo.radius = 0.24
	halo.height = 0.48
	halo.radial_segments = 16
	halo.rings = 8
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(1.0, 0.85, 0.25, 0.28)
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash = _part(halo, hm, Vector3(0, 1.16, 0), _wand)
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crown = Node3D.new()
	_crown.position = Vector3(0, 1.66, 0)
	_visual.add_child(_crown)
	var band := CylinderMesh.new()
	band.top_radius = 0.235
	band.bottom_radius = 0.21
	band.height = 0.13
	band.radial_segments = 20
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color("ffc21a")
	cmat.roughness = 0.3
	_part(band, cmat, Vector3.ZERO, _crown)
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.075
	spike.height = 0.2
	spike.radial_segments = 8
	var gem := SphereMesh.new()
	gem.radius = 0.035
	gem.height = 0.07
	var gemm := StandardMaterial3D.new()
	gemm.albedo_color = Color("ff3d7f")
	gemm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 5:
		var a := TAU * i / 5.0
		var dir := Vector3(cos(a), 0, sin(a))
		_part(spike, cmat, dir * 0.195 + Vector3.UP * 0.15, _crown)
		_part(gem, gemm, dir * 0.205 + Vector3.UP * 0.03, _crown)
	set_role(false)

## Soft dark spot under the feet so the figure sits on the ground.
func _contact_shadow() -> ShaderMaterial:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = "shader_type spatial;render_mode unshaded,shadows_disabled,depth_draw_never;uniform float a=0.42;void fragment(){float d=length(UV-vec2(0.5))*2.0;ALBEDO=vec3(0.1,0.07,0.22);ALPHA=a*pow(clamp(1.0-d,0.0,1.0),1.4);}"
	var m := ShaderMaterial.new()
	m.shader = _shadow_shader
	return m

## Wand recoil, called whenever this clone fires.
func kick() -> void:
	_kick = 1.0

func wand_tip() -> Vector3:
	return _tip.global_position if _tip else global_position + Vector3.UP * 1.2

func camo_amount() -> float: return _camo

func wand_ready() -> bool: return _wand != null and _wand.visible

func set_role(is_seeker: bool) -> void:
	seeker = is_seeker
	if _wand: _wand.visible = is_seeker
	if _crown: _crown.visible = is_seeker
	if _antenna: _antenna.visible = not is_seeker

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

func _process(delta: float) -> void:
	if game == null or _visual == null: return
	_t += delta
	var moved := (global_position - _last_pos) * Vector3(1, 0, 1)
	_last_pos = global_position
	_speed2d = lerpf(_speed2d, moved.length() / maxf(delta, 0.001), clampf(delta * 8.0, 0.0, 1.0))
	var w := clampf(_speed2d / SPEED, 0.0, 1.0)
	var s := sin(_t * 12.5)
	var breathe := sin(_t * 2.2) * 0.012 * (1.0 - w)
	_vy = lerpf(_vy, (global_position.y - _prev_y) / maxf(delta, 0.001), clampf(delta * 14.0, 0.0, 1.0))
	_prev_y = global_position.y
	var in_air := absf(_vy) > 0.9
	if _air and not in_air: _squash = 1.0
	_air = in_air
	_squash = move_toward(_squash, 0.0, delta * 4.5)
	var st := 0.0
	if in_air: st = clampf(absf(_vy) / 8.0, 0.0, 0.14)
	var sq := sin(_squash * PI) * 0.2
	_visual.scale = Vector3(1.0 + sq * 0.7 - st * 0.5 - breathe, 1.0 - sq + st + breathe, 1.0 + sq * 0.7 - st * 0.5 - breathe)
	_visual.rotation.z = s * 0.075 * w
	_visual.rotation.x = -0.17 * w
	_visual.position.y = absf(s) * 0.07 * w
	_kick = move_toward(_kick, 0.0, delta * 5.0)
	if _leg_pivots.size() == 2:
		var air_pose := 0.6 if in_air else 0.0
		var ll := s * 0.8 * w + air_pose
		var lr := -s * 0.8 * w - air_pose
		var flap := 0.75 if in_air else 0.0
		var arm_l := Vector2(-s * 0.75 * w, -flap)
		var arm_r := Vector2(s * 0.75 * w, flap)
		if wand_ready():
			var back := _kick * _kick
			arm_r = Vector2(1.1 + aim_pitch * 0.7 + back * 0.75, 0.2)
			_flash.scale = Vector3.ONE * (0.6 + back * 3.0 + sin(_t * 9.0) * 0.06)
			_tip.scale = Vector3.ONE * (2.0 + back * 1.6)
			_tip.rotation.y += delta * (2.5 + back * 30.0)
			# Wand points up and out so it stays in view; firing snaps it upward.
			var want := Basis.from_euler(Vector3(deg_to_rad(-52.0 + aim_pitch * 30.0 + back * 34.0), 0.0, deg_to_rad(-16.0)))
			_wand.basis = Basis.from_euler(Vector3(arm_r.x, 0.0, arm_r.y)).inverse() * want
		_arm_pivots[1].rotation = Vector3(arm_r.x, 0, arm_r.y)
		_skin_mat.set_shader_parameter("leg_l", Vector2(ll, 0.0))
		_skin_mat.set_shader_parameter("leg_r", Vector2(lr, 0.0))
		_skin_mat.set_shader_parameter("arm_l", arm_l)
		_skin_mat.set_shader_parameter("arm_r", arm_r)
		if _antenna: _antenna.rotation.x = -0.12 * w + sin(_t * 8.0) * 0.1 * w
	_blink -= delta
	if _blink < 0.0: _blink = 2.0 + randf() * 3.5
	var open := 0.1 if _blink < 0.11 else 1.4
	for e in _eyes: e.scale.y = open
	_update_look(delta)

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
		eye_alpha = clampf(0.05 + base + clampf(1.0 - dist / 7.0, 0.0, 1.0) * 0.8, 0.0, 1.0)
		if me: eye_alpha = 1.0
	_camo = lerpf(_camo, target, clampf(delta * 5.0, 0.0, 1.0))
	for m in _body_mats:
		m.set_shader_parameter("camo", _camo)
		m.set_shader_parameter("rim", (1.0 - _camo) * 0.5 + 0.02)
	_eye_mat.albedo_color.a = eye_alpha
	_pupil_mat.albedo_color.a = eye_alpha
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
