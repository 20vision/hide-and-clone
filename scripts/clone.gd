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
uniform int pattern = 0;
uniform bool face = false;
uniform float camo = 0.0;
uniform float rim = 0.0;
varying vec3 lp;
varying vec3 wn;
void vertex() {
	lp = VERTEX;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 col = tint;
	if (face) {
		if (pattern == 1) col = mix(tint, tint2, step(0.5, fract(lp.y * 3.6)));
		else if (pattern == 2) { vec2 q = fract(vec2(atan(lp.x, lp.z) * 2.6, lp.y * 5.2)) - 0.5; col = mix(tint, tint2, smoothstep(0.26, 0.22, length(q))); }
		else if (pattern == 3) col = mix(tint2, tint, smoothstep(0.86, 0.9, lp.y));
		float belly = smoothstep(0.42, 0.2, length(vec2(lp.x * 1.05, (lp.y - 0.56) * 0.9))) * step(lp.z, 0.0);
		col = mix(col, mix(col, vec3(1.0), 0.55), belly);
		vec2 m = vec2(lp.x, lp.y - 1.07);
		float arc = smoothstep(0.02, 0.008, abs(length(m) - 0.1)) * step(m.y, -0.025) * step(lp.z, 0.0);
		float blush = smoothstep(0.1, 0.03, length(vec2(abs(lp.x) - 0.25, lp.y - 1.03))) * step(lp.z, 0.0) * 0.55;
		col = mix(col, vec3(1.0, 0.42, 0.5), blush);
		col = mix(col, vec3(0.13, 0.05, 0.12), arc);
	}
	vec3 n = normalize(wn);
	vec3 L = normalize(vec3(0.45, 0.8, 0.4));
	float w = dot(n, L) * 0.5 + 0.5;
	float soft = smoothstep(0.12, 0.8, w);
	vec3 shadow = col * vec3(0.5, 0.48, 0.68);
	vec3 solid = mix(shadow, col * 1.04, soft);
	float nv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - nv, 3.0);
	vec3 vL = normalize((VIEW_MATRIX * vec4(L, 0.0)).xyz);
	vec3 h = normalize(vL + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), 42.0);
	solid += vec3(1.0) * spec * 0.32 + vec3(0.72, 0.88, 1.0) * fres * 0.34;
	if (face) solid *= mix(0.72, 1.0, smoothstep(0.0, 0.3, lp.y));
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
var _feet: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []
var _label: Label3D
var _wand: Node3D
var _crown: Node3D
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
	m.set_shader_parameter("tint2", tint.lightened(0.45))
	m.set_shader_parameter("pattern", _pattern)
	m.set_shader_parameter("face", is_body)
	_body_mats.append(m)
	return m

## Smooth jelly-bean body, wider at the bottom, built once and shared.
static func _bean() -> ArrayMesh:
	if _bean_mesh: return _bean_mesh
	const RINGS := 30
	const SEG := 40
	const H := 1.62
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in RINGS + 1:
		var a := PI * float(r) / RINGS
		var y := H * 0.5 * (1.0 - cos(a))
		var k := y / H
		var bottom := 0.56
		var top := 0.44
		var rad := lerpf(bottom, top, smoothstep(0.2, 0.92, k)) * pow(sin(a), 0.72)
		if k < 0.08: y = lerpf(y, 0.04, 0.35)
		for i in SEG:
			var t := TAU * float(i) / SEG
			st.add_vertex(Vector3(cos(t) * rad, y, sin(t) * rad * 0.9))
	for r in RINGS:
		for i in SEG:
			var a := r * SEG + i
			var b := r * SEG + (i + 1) % SEG
			var c := (r + 1) * SEG + i
			var d := (r + 1) * SEG + (i + 1) % SEG
			for v: int in [a, b, c, b, d, c]: st.add_index(v)
	st.generate_normals()
	_bean_mesh = st.commit()
	return _bean_mesh

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
	var limb_mat := _glass()
	_body = _part(_bean(), _glass(true), Vector3.ZERO)
	if _limb_mesh == null:
		_limb_mesh = CapsuleMesh.new()
		_limb_mesh.radius = 0.1
		_limb_mesh.height = 0.5
		_limb_mesh.radial_segments = 14
		_limb_mesh.rings = 6
		_leg_mesh = CapsuleMesh.new()
		_leg_mesh.radius = 0.15
		_leg_mesh.height = 0.42
		_leg_mesh.radial_segments = 14
		_leg_mesh.rings = 6
	for x: float in [-0.25, 0.25]:
		var p := _pivot(Vector3(x, 0.26, 0.0))
		_part(_leg_mesh, limb_mat, Vector3(0, -0.14, 0), p)
		_leg_pivots.append(p)
	for x: float in [-0.5, 0.5]:
		var p := _pivot(Vector3(x, 0.82, 0.0))
		p.rotation.z = 0.32 * signf(x)
		_part(_limb_mesh, limb_mat, Vector3(0, -0.2, 0), p)
		_arm_pivots.append(p)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color.WHITE
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pupil_mat = StandardMaterial3D.new()
	_pupil_mat.albedo_color = Color(0.04, 0.03, 0.09)
	_pupil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pupil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ew := SphereMesh.new()
	ew.radius = 0.135
	ew.height = 0.27
	ew.radial_segments = 20
	ew.rings = 10
	var ep := SphereMesh.new()
	ep.radius = 0.085
	ep.height = 0.17
	ep.radial_segments = 14
	ep.rings = 7
	var eh := SphereMesh.new()
	eh.radius = 0.028
	eh.height = 0.056
	eh.radial_segments = 8
	eh.rings = 4
	for x: float in [-0.14, 0.14]:
		var e := _part(ew, _eye_mat, Vector3(x, 1.25, -0.335))
		e.scale = Vector3(1.0, 1.22, 0.55)
		var pu := _part(ep, _pupil_mat, Vector3(0, 0, -0.095), e)
		pu.scale = Vector3(1, 1, 0.5)
		_pupils.append(pu)
		_part(eh, _eye_mat, Vector3(-0.032, 0.04, -0.075), pu)
		_eyes.append(e)
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
	_wand.position = Vector3(0.05, -0.38, -0.05)
	_wand.rotation = Vector3(-1.45, 0.0, -0.32)
	_arm_pivots[1].add_child(_wand)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.022
	stick.bottom_radius = 0.034
	stick.height = 0.7
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color("3a1f7a")
	smat.roughness = 0.35
	_part(stick, smat, Vector3(0, 0.3, 0), _wand)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("ffe34d")
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var st := _part(_star(), gmat, Vector3(0, 0.74, 0), _wand)
	st.rotation.x = PI * 0.5
	_crown = Node3D.new()
	_crown.position = Vector3(0, 1.57, 0)
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

func camo_amount() -> float: return _camo

func wand_ready() -> bool: return _wand != null and _wand.visible

func set_role(is_seeker: bool) -> void:
	seeker = is_seeker
	if _wand: _wand.visible = is_seeker
	if _crown: _crown.visible = is_seeker

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
	if dir.length() > 0.1:
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
	if _leg_pivots.size() == 2:
		var air_pose := 0.55 if in_air else 0.0
		_leg_pivots[0].rotation.x = s * 0.85 * w + air_pose
		_leg_pivots[1].rotation.x = -s * 0.85 * w - air_pose
		_arm_pivots[0].rotation.x = -s * 0.8 * w
		var aim := -1.2 if seeker and wand_ready() else s * 0.8 * w
		_arm_pivots[1].rotation.x = aim
		var flap := 0.55 if in_air else 0.0
		_arm_pivots[0].rotation.z = -0.32 - flap
		_arm_pivots[1].rotation.z = 0.32 + flap
	_blink -= delta
	if _blink < 0.0: _blink = 2.0 + randf() * 3.5
	var open := 0.08 if _blink < 0.11 else 1.22
	for e in _eyes: e.scale.y = open
	var look := Vector3(sin(_t * 0.7) * 0.022, sin(_t * 1.1) * 0.012, -0.095)
	for pu in _pupils: pu.position = look
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
