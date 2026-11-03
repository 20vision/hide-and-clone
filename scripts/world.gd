class_name World extends RefCounted
## Ground, sky, light and scenery shared by game, menu and map builder.
const FLOORS := {
	"lab": [Color("c7d3df"), Color("b7c6d4"), 1, Color("3f97f0"), Color("d5edff"), Color("9db3c5")],
	"grass": [Color("6fbf4a"), Color("5daf3f"), 0, Color("3f9df5"), Color("d6f0ff"), Color("5f9f47")],
	"wood": [Color("c69363"), Color("b58255"), 2, Color("4ea5f0"), Color("ffe9d0"), Color("8ba85a")],
	"sand": [Color("e4cd92"), Color("d6bc7f"), 3, Color("35a5ee"), Color("e4f6ff"), Color("d2b878")],
	"snow": [Color("e5eef6"), Color("d3e0ec"), 3, Color("6cb4ee"), Color("edf7ff"), Color("c9d9e6")],
	"studio": [Color("bdb7d4"), Color("b9b3d0"), 3, Color("8f8aa8"), Color("c3bedb"), Color("c3bedb")],
	"night": [Color("3c4670"), Color("323b62"), 1, Color("0d1238"), Color("3c3f86"), Color("232a50")],
}
const FLOOR_SHADER := """
shader_type spatial;
uniform vec3 a : source_color; uniform vec3 b : source_color; uniform int style = 0;
varying vec3 wp;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
float fbm(vec2 p){ return n(p)*0.5 + n(p*2.1+3.1)*0.3 + n(p*4.3+7.7)*0.2; }
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
	vec2 p = wp.xz;
	vec3 c;
	if (style == 0) {
		float patch_ = smoothstep(0.32, 0.68, fbm(p * 0.16));
		float stripe = step(0.5, fract(p.x / 7.0)) * 0.035;
		c = mix(a, b, patch_) + stripe + (n(p * 7.0) - 0.5) * 0.05;
	} else if (style == 1) {
		vec2 t = abs(fract(p / 3.0) - 0.5);
		float grout = smoothstep(0.482, 0.492, max(t.x, t.y));
		float k = mod(floor(p.x / 3.0) + floor(p.y / 3.0), 2.0);
		c = mix(mix(a, b, k), a * 0.62, grout) + (fbm(p * 0.4) - 0.5) * 0.04;
	} else if (style == 2) {
		float row = floor(p.y / 0.9);
		float off = h(vec2(row, 3.0)) * 4.0;
		float seam = smoothstep(0.47, 0.49, abs(fract(p.y / 0.9) - 0.5)) + smoothstep(0.494, 0.498, abs(fract((p.x + off) / 4.0) - 0.5));
		float grain = n(vec2(p.x * 0.8 + off, p.y * 14.0));
		c = mix(a, b, h(vec2(row, floor((p.x + off) / 4.0)))) + (grain - 0.5) * 0.07;
		c = mix(c, a * 0.55, clamp(seam, 0.0, 1.0));
	} else {
		c = mix(a, b, smoothstep(0.3, 0.7, fbm(p * 0.22 + vec2(sin(p.y * 0.2), 0.0)))) + (n(p * 9.0) - 0.5) * 0.03;
	}
	ALBEDO = c * 0.86;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
"""
const OUTER_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 c : source_color;
void fragment(){ ALBEDO = c; }
"""

static func make_ground(parent: Node3D, map: Dictionary) -> void:
	var size: float = float(map.get("size", 40))
	var kind := str(map.get("floor", "lab"))
	var f: Array = FLOORS.get(kind, FLOORS["lab"])
	var ground := StaticBody3D.new()
	ground.collision_layer = 4
	ground.collision_mask = 0
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var sh := Shader.new()
	sh.code = FLOOR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("a", f[0])
	mat.set_shader_parameter("b", f[1])
	mat.set_shader_parameter("style", f[2])
	mi.material_override = mat
	ground.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size, 2.0, size)
	cs.shape = box
	cs.position.y = -1.0
	ground.add_child(cs)
	for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(1.0 if d.x != 0.0 else size + 2.0, 60.0, 1.0 if d.z != 0.0 else size + 2.0)
		wall.shape = wb
		wall.position = d * (size * 0.5 + 0.5) + Vector3.UP * 30.0
		ground.add_child(wall)
	parent.add_child(ground)
	if kind != "studio":
		_rim(parent, size)
		_scenery(parent, size, f)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 0.5 if kind != "night" else 0.28
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.72
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	parent.add_child(sun)
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = f[3]
	sky_mat.sky_horizon_color = f[4]
	sky_mat.ground_horizon_color = f[4]
	sky_mat.ground_bottom_color = f[5]
	sky_mat.sun_angle_max = 8.0
	sky_mat.sky_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.88, 1.0)
	env.ambient_light_energy = 0.3 if kind != "night" else 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = kind != "studio"
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = f[4]
	env.fog_density = 0.0028
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

## Padded bumper around the arena so the edge of the map reads as a real wall.
static func _rim(parent: Node3D, size: float) -> void:
	var seg := 4.0
	var count := int(ceil(size / seg))
	var mats: Array[StandardMaterial3D] = [_unshaded(Color("ff4f8b")), _unshaded(Color("ffffff")), _unshaded(Color("2db8f5")), _unshaded(Color("ffffff"))]
	var cap := CapsuleMesh.new()
	cap.radius = 0.42
	cap.height = seg + 0.84
	cap.radial_segments = 12
	cap.rings = 4
	var half := size * 0.5 + 0.3
	for side in 4:
		for i in count:
			var mi := MeshInstance3D.new()
			mi.mesh = cap
			mi.material_override = mats[i % 4]
			var t := -size * 0.5 + seg * (i + 0.5)
			match side:
				0:
					mi.position = Vector3(t, 0.32, -half)
					mi.rotation.z = PI * 0.5
				1:
					mi.position = Vector3(t, 0.32, half)
					mi.rotation.z = PI * 0.5
				2:
					mi.position = Vector3(-half, 0.32, t)
					mi.rotation.x = PI * 0.5
				3:
					mi.position = Vector3(half, 0.32, t)
					mi.rotation.x = PI * 0.5
			parent.add_child(mi)

## Distant hills and clouds, so the map sits in a world instead of a void.
static func _scenery(parent: Node3D, size: float, f: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var outer := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1800)
	outer.mesh = plane
	outer.position.y = -0.25
	var om := StandardMaterial3D.new()
	om.albedo_color = (f[5] as Color)
	om.roughness = 1.0
	outer.material_override = om
	parent.add_child(outer)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 10
	var hill := StandardMaterial3D.new()
	hill.albedo_color = (f[5] as Color).darkened(0.08)
	hill.roughness = 1.0
	var hill2 := StandardMaterial3D.new()
	hill2.albedo_color = (f[5] as Color).lightened(0.08)
	hill2.roughness = 1.0
	for i in 26:
		var a := TAU * i / 26.0 + rng.randf() * 0.2
		var r := size * 0.5 + rng.randf_range(70.0, 170.0)
		var mi := MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = hill if i % 2 == 0 else hill2
		mi.position = Vector3(cos(a) * r, -2.0, sin(a) * r)
		mi.scale = Vector3(rng.randf_range(70.0, 150.0), rng.randf_range(18.0, 52.0), rng.randf_range(70.0, 150.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(1, 1, 1)
	cloud.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cloud2 := StandardMaterial3D.new()
	cloud2.albedo_color = Color(0.9, 0.94, 1.0)
	cloud2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 11:
		var a := rng.randf() * TAU
		var r := size * 0.5 + rng.randf_range(50.0, 230.0)
		var c := Vector3(cos(a) * r, rng.randf_range(42.0, 88.0), sin(a) * r)
		for j in 4:
			var mi := MeshInstance3D.new()
			mi.mesh = sphere
			mi.material_override = cloud2 if j == 0 else cloud
			var w := rng.randf_range(10.0, 20.0)
			mi.position = c + Vector3((j - 2) * 11.0, (0.0 if j == 0 else 3.0) + rng.randf_range(-2.0, 2.0), rng.randf_range(-7.0, 7.0))
			mi.scale = Vector3(w, w * 0.5, w * 0.8)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
