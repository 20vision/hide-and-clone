extends Node3D
## Rounds, players, wand and sync. The host decides; everyone else follows.
signal left_game(msg: String)

const COLORS: Array[Color] = [Color("ff5d8f"), Color("4cc9f0"), Color("ffd166"), Color("7ae582"), Color("b388ff"), Color("ff9f43"), Color("00d4b1"), Color("f15bb5"), Color("9bde45"), Color("5e8bff"), Color("ff6b6b"), Color("c9f0ff")]
const DEFAULTS := {
	"hide_time": 20, "seek_time": 120, "hider_speed": 96, "visibility": 12, "hits": 2,
	"cooldown": 0.5, "decoys": 2, "seekers": 1, "bots": 5, "max_players": 12, "public": true, "autostart": true,
}
const BOT_NAMES: Array[String] = ["Bot Pip", "Bot Mo", "Bot Dot", "Bot Bean", "Bot Zip", "Bot Lux", "Bot Nib", "Bot Ody", "Bot Tam", "Bot Rue", "Bot Kit"]

var active := false
var settings: Dictionary = DEFAULTS.duplicate()
var map: Dictionary = {}
var phase := "lobby"
var time_left := 0.0
var players: Dictionary = {}
var nodes: Dictionary = {}
var decoys: Dictionary = {}
var round_no := 0
var my_name := "Clone"
var result: Dictionary = {}
var ai_mode := false
var force_role := ""
var debug := false
var _dbg_t := 0.0

var world: Node3D
var hud: Node
var rig: Node3D
var arm: SpringArm3D
var cam: Camera3D
var _yaw := 0.0
var _pitch := -0.2
var sens := 0.0026
var _pending_props := 0
var _map_ready := false
var _world_token := 0
var _props: Array[Vector3] = []
var _chunks: Array[PackedByteArray] = []
var _chunks_total := 0
var _pose_t := 0.0
var _info_t := 0.0
var _cool := 0.0
var _host_cool: Dictionary = {}
var _next_decoy := -1
var _start_at := -1.0
var _spec_idx := 0
var _shots: Array[Dictionary] = []
var _last_sec := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer)
	multiplayer.peer_disconnected.connect(_on_peer_gone)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.server_disconnected.connect(func() -> void:
		if active and not _is_host(): _quit("The host left the game."))
	Net.host_gone.connect(func() -> void:
		if active: _quit("The host left the game."))
	rig = Node3D.new()
	add_child(rig)
	arm = SpringArm3D.new()
	arm.spring_length = 4.6
	arm.collision_mask = 1
	var sph := SphereShape3D.new()
	sph.radius = 0.2
	arm.shape = sph
	arm.position = Vector3(0.0, 1.5, 0.0)
	rig.add_child(arm)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.far = 500.0
	arm.add_child(cam)
	set_process(false)
	set_physics_process(false)

func _is_host() -> bool: return multiplayer.is_server()
func me() -> Clone: return nodes.get(multiplayer.get_unique_id()) as Clone
func visibility() -> float: return clampf(float(settings.get("visibility", 12)) / 100.0, 0.0, 1.0)

func is_hiding_look(c: Clone) -> bool:
	return (phase == "hide" or phase == "seek") and not c.seeker

func show_label(c: Clone) -> bool:
	if c.mode == Clone.LOCAL: return false
	if c.mode == Clone.DECOY: return false
	if phase == "lobby" or phase == "end": return true
	var m := me()
	if c.seeker: return true
	return m != null and not m.seeker

# ---------- start / stop ---------------------------------------------------
func host_game(m: Dictionary, s: Dictionary, name_: String) -> void:
	my_name = name_
	settings = DEFAULTS.duplicate()
	settings.merge(s, true)
	map = Maps.remember(m, str(m.get("src", "played")))
	Net.host(_lobby_info())
	_enter()
	var id := multiplayer.get_unique_id()
	players.clear()
	players[id] = _new_player(id, my_name, false)
	for i in int(settings["bots"]): _add_bot(i)
	phase = "lobby"
	_build_world()
	players[id]["ready"] = true
	_push_state()
	if hud: hud.set_map_name(str(map.get("name", "")))

func join_game(code: String, name_: String) -> void:
	my_name = name_
	Net.join(code)

func _enter() -> void:
	active = true
	set_process(true)
	set_physics_process(true)
	cam.current = true
	result = {}
	round_no = 0
	if hud: hud.show_game(true)

func _quit(msg: String) -> void:
	leave()
	left_game.emit(msg)

func leave() -> void:
	active = false
	Net.leave()
	set_process(false)
	set_physics_process(false)
	for n: Node in nodes.values(): n.queue_free()
	nodes.clear()
	for n: Node in decoys.values(): n.queue_free()
	decoys.clear()
	players.clear()
	if world:
		world.queue_free()
		world = null
	if hud: hud.show_game(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _lobby_info() -> Dictionary:
	var humans := 0
	for p: Dictionary in players.values():
		if not p["bot"]: humans += 1
	return {"name": my_name + "'s game", "map": str(map.get("name", "")), "players": maxi(humans, 1), "max": int(settings["max_players"]), "phase": phase, "public": bool(settings["public"]), "v": 1}

func _new_player(id: int, n: String, bot: bool) -> Dictionary:
	var idx := players.size() % COLORS.size()
	return {"id": id, "name": n.substr(0, 16), "bot": bot, "color": idx, "alive": false, "seeker": false, "hp": 0, "decoys": 0, "ready": bot, "tags": 0, "out_at": -1.0, "spawn": [0.0, 1.0, 0.0], "in_round": false}

func _add_bot(i: int) -> void:
	var id := 100000 + i
	players[id] = _new_player(id, BOT_NAMES[i % BOT_NAMES.size()], true)

# ---------- networking: joining --------------------------------------------
func _on_connected() -> void:
	Net.connected_to_host()
	hello.rpc_id(1, my_name)

func _on_peer(_id: int) -> void: pass

func _on_peer_gone(id: int) -> void:
	if not _is_host() or not players.has(id): return
	players.erase(id)
	if nodes.has(id):
		(nodes[id] as Node).queue_free()
		nodes.erase(id)
	if phase == "hide" or phase == "seek": _check_end()
	_push_state()
	Net.update(_lobby_info())

@rpc("any_peer", "reliable")
func hello(n: String) -> void:
	if not _is_host(): return
	var id := multiplayer.get_remote_sender_id()
	var clean_name := n.strip_edges().substr(0, 16)
	if clean_name == "": clean_name = "Clone"
	# A real player takes the seat of a bot.
	for k: int in players.keys():
		if players[k]["bot"] and _humans() + _bot_count() >= int(settings["max_players"]):
			players.erase(k)
			if nodes.has(k):
				(nodes[k] as Node).queue_free()
				nodes.erase(k)
			break
	players[id] = _new_player(id, clean_name, false)
	var raw := JSON.stringify(map).to_utf8_buffer()
	var gz := raw.compress(FileAccess.COMPRESSION_GZIP)
	var total: int = int(ceil(gz.size() / 8000.0))
	map_begin.rpc_id(id, maxi(total, 1), raw.size())
	for i in maxi(total, 1):
		map_chunk.rpc_id(id, gz.slice(i * 8000, mini((i + 1) * 8000, gz.size())))
	Net.update(_lobby_info())

func _humans() -> int:
	var n := 0
	for p: Dictionary in players.values():
		if not p["bot"]: n += 1
	return n

func _bot_count() -> int: return players.size() - _humans()

var _raw_size := 0
@rpc("authority", "reliable")
func map_begin(total: int, raw_size: int) -> void:
	_chunks.clear()
	_chunks_total = total
	_raw_size = raw_size

@rpc("authority", "reliable")
func map_chunk(b: PackedByteArray) -> void:
	_chunks.append(b)
	if _chunks.size() < _chunks_total: return
	var all := PackedByteArray()
	for c in _chunks: all.append_array(c)
	_chunks.clear()
	var raw := all.decompress(mini(_raw_size, 2000000), FileAccess.COMPRESSION_GZIP)
	map = Maps.remember(JSON.parse_string(raw.get_string_from_utf8()), "played")
	_enter()
	if hud: hud.set_map_name(str(map.get("name", "")))
	_build_world()

@rpc("any_peer", "reliable")
func map_loaded() -> void:
	if not _is_host(): return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id]["ready"] = true
		_push_state()

# ---------- world ----------------------------------------------------------
func _build_world() -> void:
	if world: world.queue_free()
	_world_token += 1
	var token := _world_token
	world = Node3D.new()
	add_child(world)
	_props.clear()
	_map_ready = false
	World.make_ground(world, map)
	var o: Array = map.get("o", [])
	var want := {}
	for e: Array in o: want[e[0]] = true
	var waiting := {}
	for id: String in want:
		if Cat.loaded(id) or Cat.failed(id): continue
		waiting[id] = true
		Cat.need(id)
	if hud: hud.set_loading(want.size() - waiting.size(), want.size())
	while not waiting.is_empty():
		var got: String = await Cat.item_ready
		if token != _world_token: return
		waiting.erase(got)
		if hud: hud.set_loading(want.size() - waiting.size(), want.size())
	for e: Array in o:
		var b := Cat.prop(e[0], e[5])
		if b:
			b.position = Vector3(e[1], e[2], e[3])
			b.rotation.y = e[4]
			world.add_child(b)
			_props.append(b.position)
	_map_ready = true
	if hud: hud.set_loading(1, 1)
	for id: int in nodes:
		var c: Clone = nodes[id]
		if c.mode != Clone.REMOTE: c.teleport(_spawn_spot(5.0), randf() * TAU)
	if not _is_host(): map_loaded.rpc_id(1)
	print("[hc] world ready props=%d" % _props.size())

func _spawn_spot(radius := 7.0) -> Vector3:
	var space := get_world_3d().direct_space_state
	var half: float = float(map.get("size", 40)) * 0.5 - 2.0
	for i in 40:
		var r := minf(radius + i * 0.5, half)
		var p := Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.5
		cap.height = 1.6
		q.shape = cap
		q.transform = Transform3D(Basis(), p + Vector3(0, 0.95, 0))
		q.collision_mask = 1
		if space.intersect_shape(q, 1).is_empty(): return p + Vector3(0, 0.1, 0)
	return Vector3(0, 12, 0)

func random_spot() -> Vector3: return _spawn_spot(float(map.get("size", 40)) * 0.45)

func random_prop_spot() -> Vector3:
	if _props.is_empty(): return random_spot()
	var p: Vector3 = _props[randi() % _props.size()]
	return p + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))

# ---------- rounds (host) ---------------------------------------------------
func request_start() -> void:
	if _is_host(): _start_round()

func request_start_lobby() -> void:
	if _is_host() and phase == "lobby": _start_round()

func _start_round() -> void:
	var ids: Array = []
	for id: int in players:
		if players[id]["ready"]: ids.append(id)
	if ids.size() < 2: return
	ids.shuffle()
	var n := clampi(int(settings["seekers"]), 1, maxi(ids.size() - 1, 1))
	round_no += 1
	for id: int in players:
		var p: Dictionary = players[id]
		var in_round: bool = ids.has(id)
		p["in_round"] = in_round
		p["alive"] = in_round
		p["seeker"] = false
		p["hp"] = int(settings["hits"])
		p["decoys"] = int(settings["decoys"])
		p["tags"] = 0
		p["out_at"] = -1.0
	for i in n: players[ids[i]]["seeker"] = true
	if force_role != "":
		for id: int in ids: players[id]["seeker"] = (id == 1) == (force_role == "seeker")
	for id: int in ids:
		var sp := _spawn_spot()
		players[id]["spawn"] = [sp.x, sp.y, sp.z]
	phase = "hide"
	time_left = float(settings["hide_time"])
	_start_at = -1.0
	result = {}
	_clear_decoys.rpc()
	_push_state(true)
	Net.update(_lobby_info())
	get_parent().track("clone_round_start", {"players": ids.size(), "humans": _humans(), "round": round_no})
	print("[hc] round %d start players=%d" % [round_no, ids.size()])

func _host_tick(delta: float) -> void:
	if phase == "lobby":
		var ready_n := 0
		for p: Dictionary in players.values():
			if p["ready"]: ready_n += 1
		if bool(settings["autostart"]) and ready_n >= 2:
			if _start_at < 0.0:
				_start_at = 30.0 if round_no == 0 else 8.0
				_push_state()
			_start_at -= delta
			if _start_at <= 0.0: _start_round()
		elif _start_at >= 0.0 and not bool(settings["autostart"]):
			_start_at = -1.0
		return
	time_left -= delta
	if time_left > 0.0: return
	if phase == "hide":
		phase = "seek"
		time_left = float(settings["seek_time"])
		_push_state()
		print("[hc] seek phase")
	elif phase == "seek":
		_finish("hiders")
	elif phase == "end":
		phase = "lobby"
		_start_at = -1.0
		_clear_decoys.rpc()
		_push_state(false, true)
		Net.update(_lobby_info())

func _check_end() -> void:
	if phase != "hide" and phase != "seek": return
	var hiders := 0
	var seekers := 0
	for p: Dictionary in players.values():
		if not p["in_round"]: continue
		if p["seeker"]: seekers += 1
		elif p["alive"]: hiders += 1
	if hiders == 0: _finish("seekers")
	elif seekers == 0: _finish("hiders")

func _finish(side: String) -> void:
	var winners: Array = []
	var out: Array = []
	for p: Dictionary in players.values():
		if not p["in_round"]: continue
		if p["seeker"]:
			if side == "seekers": winners.append(p["name"])
			else: out.append(p["name"] + " (Original)")
		elif p["alive"]:
			winners.append(p["name"])
		else:
			out.append(p["name"])
	phase = "end"
	time_left = 9.0
	result = {"side": side, "winners": winners, "out": out}
	_push_state()
	Net.update(_lobby_info())
	get_parent().track("clone_round_end", {"side": side, "players": players.size(), "humans": _humans()})
	print("[hc] round over side=%s winners=%d out=%d" % [side, winners.size(), out.size()])

func _push_state(new_round := false, to_lobby := false) -> void:
	apply_state.rpc({"players": players, "phase": phase, "time": time_left, "settings": settings, "new_round": new_round, "to_lobby": to_lobby, "round": round_no, "result": result, "start_at": _start_at})

@rpc("authority", "call_local", "reliable")
func apply_state(s: Dictionary) -> void:
	var prev_phase := phase
	players = s["players"]
	phase = s["phase"]
	time_left = s["time"]
	settings = s["settings"]
	round_no = s["round"]
	result = s["result"]
	_start_at = s["start_at"]
	_sync_nodes()
	var my_id := multiplayer.get_unique_id()
	for id: int in players:
		var p: Dictionary = players[id]
		var c: Clone = nodes.get(id)
		if c == null: continue
		c.set_role(p["seeker"] and phase != "lobby")
		if phase == "lobby" or (p["in_round"] and p["alive"]): c.set_alive(true)
		elif p["in_round"] or phase != "lobby": c.set_alive(p["alive"])
		c.speed_mult = 1.0 if p["seeker"] else float(settings["hider_speed"]) / 100.0
		if phase == "lobby": c.speed_mult = 1.0
		c.frozen = phase == "hide" and p["seeker"]
		if s["new_round"]:
			var sp: Array = p["spawn"]
			if p["in_round"]: c.teleport(Vector3(sp[0], sp[1], sp[2]), randf() * TAU)
		if s["to_lobby"] and id == my_id:
			c.set_alive(true)
	if s["new_round"]: _cool = 0.0
	if prev_phase != "end" and phase == "end": Sfx.play(self, "win", -4.0)
	if hud: hud.on_state(prev_phase, phase)

func _sync_nodes() -> void:
	var my_id := multiplayer.get_unique_id()
	for id: int in nodes.keys():
		if not players.has(id):
			(nodes[id] as Node).queue_free()
			nodes.erase(id)
	for id: int in players:
		if nodes.has(id): continue
		var p: Dictionary = players[id]
		var c := Clone.new()
		var m := Clone.REMOTE
		if id == my_id: m = Clone.LOCAL
		elif p["bot"] and _is_host(): m = Clone.BOT
		c.setup(id, m, self, COLORS[int(p["color"]) % COLORS.size()], p["name"])
		c.ai = ai_mode and id == my_id
		add_child(c)
		var sp := _spawn_spot(5.0) if _map_ready else Vector3(0, 1, 0)
		c.teleport(sp, randf() * TAU)
		nodes[id] = c

# ---------- wand ------------------------------------------------------------
func _aim_ray() -> Dictionary:
	var m := me()
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 120.0, 1 | 2 | 4)
	if m: q.exclude = [m.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var to: Vector3 = hit["position"] if hit else from + dir * 120.0
	return {"to": to, "body": hit.get("collider")}

func local_fire() -> void:
	var m := me()
	if m == null or not m.seeker or not m.alive or phase != "seek" or _cool > 0.0: return
	_cool = float(settings["cooldown"])
	var r := _aim_ray()
	var body: Variant = r["body"]
	var target := 0
	if body is Clone: target = (body as Clone).pid
	var hand: Vector3 = m.global_position + Vector3(0, 1.2, 0)
	shot.rpc_id(1, hand, r["to"], target)

func ai_fire(c: Clone, tgt: Clone) -> void:
	if phase != "seek": return
	var from := c.global_position + Vector3.UP * 1.2
	var to := tgt.global_position + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if get_world_3d().direct_space_state.intersect_ray(q): return
	if c.mode == Clone.LOCAL: shot.rpc_id(1, from, to, tgt.pid)
	else: _apply_shot(c.pid, from, to, tgt.pid)

@rpc("any_peer", "call_local", "reliable")
func shot(from: Vector3, to: Vector3, target: int) -> void:
	if not _is_host(): return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0: sender = 1
	_apply_shot(sender, from, to, target)

func _apply_shot(shooter: int, from: Vector3, to: Vector3, target: int) -> void:
	if phase != "seek" or not players.has(shooter): return
	var s: Dictionary = players[shooter]
	if not s["seeker"] or not s["alive"]: return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_host_cool.get(shooter, 0.0)) < float(settings["cooldown"]) * 0.7: return
	_host_cool[shooter] = now
	fx_shot.rpc(from, to)
	if debug: print("[hc] shot by %d at %d" % [shooter, target])
	if target < 0 and decoys.has(target):
		decoy_pop.rpc(target)
		return
	if not players.has(target): return
	var t: Dictionary = players[target]
	if t["seeker"] or not t["alive"]: return
	t["hp"] = int(t["hp"]) - 1
	if int(t["hp"]) <= 0:
		t["alive"] = false
		t["out_at"] = time_left
		s["tags"] = int(s["tags"]) + 1
		fx_elim.rpc(target, str(s["name"]))
		print("[hc] eliminated %s" % t["name"])
		_push_state()
		_check_end()
	else:
		fx_hit.rpc(target)
		_push_state()

@rpc("authority", "call_local", "reliable")
func fx_shot(from: Vector3, to: Vector3) -> void:
	FX.beam(self, from, to)
	Sfx.play(self, "zap", -8.0)

@rpc("authority", "call_local", "reliable")
func fx_hit(id: int) -> void:
	var c: Clone = nodes.get(id)
	if c:
		FX.splash(self, c.global_position + Vector3.UP * 0.8, COLORS[int(players[id]["color"]) % COLORS.size()], 12)
		Sfx.play(self, "pop", -4.0)
		if id == multiplayer.get_unique_id() and hud: hud.flash_hit()

@rpc("authority", "call_local", "reliable")
func fx_elim(id: int, by: String) -> void:
	var c: Clone = nodes.get(id)
	var n: String = str(players[id]["name"]) if players.has(id) else "A clone"
	if c: FX.splash(self, c.global_position + Vector3.UP * 0.7, COLORS[int(players[id]["color"]) % COLORS.size()], 40)
	Sfx.play(self, "out", -3.0)
	if hud: hud.toast("%s was un-cloned by %s" % [n, by])

# ---------- decoy clones ------------------------------------------------------
func local_decoy() -> void:
	var m := me()
	if m == null or m.seeker or not m.alive: return
	if phase != "hide" and phase != "seek": return
	decoy_req.rpc_id(1, m.global_position, m.rotation.y)

@rpc("any_peer", "call_local", "reliable")
func decoy_req(p: Vector3, yaw: float) -> void:
	if not _is_host(): return
	var id := multiplayer.get_remote_sender_id()
	if id == 0: id = 1
	if not players.has(id): return
	var pl: Dictionary = players[id]
	if pl["seeker"] or not pl["alive"] or int(pl["decoys"]) <= 0: return
	pl["decoys"] = int(pl["decoys"]) - 1
	_next_decoy -= 1
	decoy_spawn.rpc(_next_decoy, p, yaw, int(pl["color"]))
	if debug: print("[hc] decoy by %d" % id)
	_push_state()

@rpc("authority", "call_local", "reliable")
func decoy_spawn(id: int, p: Vector3, yaw: float, color: int) -> void:
	var c := Clone.new()
	c.setup(id, Clone.DECOY, self, COLORS[color % COLORS.size()], "")
	add_child(c)
	c.teleport(p, yaw)
	decoys[id] = c
	FX.splash(self, p + Vector3.UP * 0.6, Color(0.7, 0.95, 1.0), 10)
	Sfx.play(self, "poof", -6.0)

@rpc("authority", "call_local", "reliable")
func decoy_pop(id: int) -> void:
	var c: Clone = decoys.get(id)
	if c:
		FX.splash(self, c.global_position + Vector3.UP * 0.7, Color(0.7, 0.95, 1.0), 26)
		Sfx.play(self, "poof", -3.0)
		if hud: hud.toast("That was just a decoy clone!")
		c.queue_free()
		decoys.erase(id)

@rpc("authority", "call_local", "reliable")
func _clear_decoys() -> void:
	for c: Node in decoys.values(): c.queue_free()
	decoys.clear()

# ---------- helpers for bots -------------------------------------------------
func nearest_hider(c: Clone, r: float) -> Clone:
	var best: Clone = null
	var bd := r
	for id: int in players:
		var p: Dictionary = players[id]
		var n: Clone = nodes.get(id)
		if n == null or p["seeker"] or not p["alive"] or not p["in_round"]: continue
		var d := n.global_position.distance_to(c.global_position)
		if d < bd and d < r * (1.0 - 0.7 * n.camo_amount()):
			bd = d
			best = n
	return best

func nearest_seeker(c: Clone, r: float) -> Clone:
	for id: int in players:
		var n: Clone = nodes.get(id)
		if n and players[id]["seeker"] and n.global_position.distance_to(c.global_position) < r: return n
	return null

# ---------- every frame -------------------------------------------------------
func _process(delta: float) -> void:
	if not active: return
	if _is_host(): _host_tick(delta)
	elif phase != "lobby": time_left = maxf(time_left - delta, 0.0)
	_cool = maxf(_cool - delta, 0.0)
	if debug:
		_dbg_t -= delta
		if _dbg_t <= 0.0 and me():
			_dbg_t = 1.0
			print("[hc] pos %.1f %.1f %.1f speed %.2f phase %s mouse %d" % [me().global_position.x, me().global_position.y, me().global_position.z, me().speed_mult, phase, Input.mouse_mode])
	_input_tick()
	_camera_tick(delta)
	_pose_t -= delta
	if _pose_t <= 0.0:
		_pose_t = 0.066
		_send_poses()
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 10.0
		if _is_host(): Net.update(_lobby_info())
	if (phase == "hide" or phase == "seek") and time_left < 5.5:
		var sec := int(ceil(time_left))
		if sec != _last_sec and sec > 0: Sfx.play(self, "tick", -10.0)
		_last_sec = sec
	if hud: hud.tick(delta)

func _input_tick() -> void:
	var m := me()
	if m == null or m.ai: return
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	if Input.is_physical_key_pressed(KEY_SPACE): m.want_jump = true
	v += Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)) * (1.0 if Input.get_connected_joypads().size() > 0 else 0.0)
	if absf(v.x) < 0.15: v.x = 0.0
	if absf(v.y) < 0.15: v.y = 0.0
	m.move_input = v
	m.yaw_target = _yaw
	var pads := Input.get_connected_joypads().size() > 0
	if pads:
		var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(rx) > 0.15: _yaw -= rx * 0.045
		if absf(ry) > 0.15: _pitch = clampf(_pitch - ry * 0.03, -1.2, 0.6)
		if Input.is_joy_button_pressed(0, JOY_BUTTON_A): m.want_jump = true
		if Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.5: local_fire()

func _unhandled_input(e: InputEvent) -> void:
	if not active: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= (e as InputEventMouseMotion).relative.x * sens
		_pitch = clampf(_pitch - (e as InputEventMouseMotion).relative.y * sens, -1.2, 0.6)
	elif e is InputEventMouseButton and e.is_pressed() and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var m := me()
		if m and not m.alive: _spec_idx += 1
		else: local_fire()
	elif e is InputEventKey and e.is_pressed() and not e.is_echo():
		match (e as InputEventKey).physical_keycode:
			KEY_E: local_decoy()
			KEY_ENTER: request_start_lobby()
			KEY_ESCAPE: if hud: hud.toggle_pause()
	elif e is InputEventJoypadButton and e.is_pressed():
		match (e as InputEventJoypadButton).button_index:
			JOY_BUTTON_X: local_decoy()
			JOY_BUTTON_Y: request_start_lobby()
			JOY_BUTTON_START: if hud: hud.toggle_pause()

func _camera_tick(delta: float) -> void:
	var m := me()
	var focus: Clone = m
	if m and not m.alive and phase != "lobby":
		var alive_list: Array[Clone] = []
		for id: int in players:
			if players[id]["alive"] and nodes.has(id): alive_list.append(nodes[id])
		if not alive_list.is_empty(): focus = alive_list[_spec_idx % alive_list.size()]
	if focus: rig.global_position = rig.global_position.lerp(focus.global_position, clampf(delta * 18.0, 0.0, 1.0))
	rig.rotation.y = _yaw
	arm.rotation.x = _pitch
	cam.position.x = 0.55
	if m: arm.clear_excluded_objects()
	if m: arm.add_excluded_object(m.get_rid())

func _send_poses() -> void:
	var m := me()
	if _is_host():
		if multiplayer.get_peers().is_empty(): return
		var arr := PackedFloat32Array()
		for id: int in nodes:
			var c: Clone = nodes[id]
			if c.mode == Clone.REMOTE and not c.alive: continue
			arr.append_array([float(id), c.global_position.x, c.global_position.y, c.global_position.z, c.rotation.y])
		poses.rpc(arr)
	elif m and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		pose.rpc_id(1, m.global_position, m.rotation.y)

@rpc("any_peer", "unreliable_ordered")
func pose(p: Vector3, yaw: float) -> void:
	var c: Clone = nodes.get(multiplayer.get_remote_sender_id())
	if c:
		c.net_pos = p
		c.net_yaw = yaw

@rpc("authority", "unreliable_ordered")
func poses(a: PackedFloat32Array) -> void:
	var my_id := multiplayer.get_unique_id()
	for i in range(0, a.size(), 5):
		var id := int(a[i])
		if id == my_id: continue
		var c: Clone = nodes.get(id)
		if c:
			c.net_pos = Vector3(a[i + 1], a[i + 2], a[i + 3])
			c.net_yaw = a[i + 4]
