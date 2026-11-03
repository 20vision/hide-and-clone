extends Node
## Finds lobbies and sets up direct WebRTC links. The host's game runs the match.
signal lobbies(list: Array)
signal hosted(code: String)
signal failed(msg: String)
signal status(msg: String)
signal host_gone

var url := "wss://lobby.desk.myclawn.com"
var ws: WebSocketPeer = null
var rtc: WebRTCMultiplayerPeer = null
var conns: Dictionary = {}
var code := ""
var is_host := false
var _open := false
var _pending: Array = []
var _ping := 0.0
var _join_deadline := 0.0
var _graveyard: Array = []

const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}

func _ready() -> void:
	if OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('lobby')||''"))
		if q != "": url = q
	else:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--lobby="): url = a.substr(8)

func _ensure_ws() -> void:
	if ws != null: return
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 262144
	ws.outbound_buffer_size = 262144
	_open = false
	if ws.connect_to_url(url) != OK:
		ws = null

func _send(o: Dictionary) -> void:
	_ensure_ws()
	if ws == null:
		failed.emit("offline")
		return
	if _open: ws.send_text(JSON.stringify(o))
	else: _pending.append(o)

func request_list() -> void: _send({"t": "list"})

func host(info: Dictionary) -> void:
	leave()
	is_host = true
	var d := info.duplicate()
	d["t"] = "host"
	_send(d)
	if OS.has_feature("web") or ClassDB.class_exists("WebRTCLibPeerConnection"):
		rtc = WebRTCMultiplayerPeer.new()
		rtc.create_server()
		multiplayer.multiplayer_peer = rtc
	else:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func update(info: Dictionary) -> void:
	if not is_host or code == "": return
	var d := info.duplicate()
	d["t"] = "update"
	_send(d)

func join(c: String) -> void:
	leave()
	is_host = false
	_join_deadline = Time.get_ticks_msec() / 1000.0 + 20.0
	status.emit("Connecting…")
	_send({"t": "join", "code": c.strip_edges().to_upper()})

func leave() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if rtc:
		# Browser events can still arrive after closing, so keep these alive for a while.
		var old_rtc := rtc
		var old_conns := conns
		old_rtc.close()
		_graveyard.append([old_rtc, old_conns])
		get_tree().create_timer(20.0).timeout.connect(func() -> void: _graveyard.pop_front())
	conns = {}
	rtc = null
	code = ""
	is_host = false
	_join_deadline = 0.0
	if ws:
		ws.close()
		ws = null
	_open = false
	_pending.clear()

func connected_to_host() -> void: _join_deadline = 0.0

func _process(delta: float) -> void:
	if _join_deadline > 0.0 and Time.get_ticks_msec() / 1000.0 > _join_deadline:
		_join_deadline = 0.0
		leave()
		failed.emit("no_link")
	if ws == null: return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _open:
			_open = true
			for o: Dictionary in _pending: ws.send_text(JSON.stringify(o))
			_pending.clear()
		while ws != null and ws.get_available_packet_count() > 0:
			var m: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if m is Dictionary: _on_msg(m)
		_ping += delta
		if _ping > 25.0 and ws != null:
			_ping = 0.0
			ws.send_text('{"t":"ping"}')
	elif st == WebSocketPeer.STATE_CLOSED:
		var was_open := _open
		ws = null
		_open = false
		_pending.clear()
		if not was_open: failed.emit("offline")

func _on_msg(m: Dictionary) -> void:
	match str(m.get("t", "")):
		"lobbies": lobbies.emit(m.get("list", []))
		"hosted":
			code = str(m["code"])
			hosted.emit(code)
		"error": failed.emit(str(m.get("msg", "error")))
		"joined":
			code = str(m["code"])
			rtc = WebRTCMultiplayerPeer.new()
			rtc.create_client(int(m["id"]))
			multiplayer.multiplayer_peer = rtc
			_link(1, false)
		"peer": _link(int(m["id"]), true)
		"peer_left":
			var id := int(m["id"])
			if conns.has(id):
				if rtc and rtc.has_peer(id): rtc.remove_peer(id)
				conns.erase(id)
		"host_left": host_gone.emit()
		"sdp":
			var c: WebRTCPeerConnection = conns.get(int(m["from"]))
			if c: c.set_remote_description(str(m["type"]), str(m["sdp"]))
		"ice":
			var c: WebRTCPeerConnection = conns.get(int(m["from"]))
			if c: c.add_ice_candidate(str(m["mid"]), int(m["idx"]), str(m["cand"]))

func _link(id: int, offer: bool) -> void:
	var c := WebRTCPeerConnection.new()
	if c.initialize(ICE) != OK:
		failed.emit("no_webrtc")
		return
	c.session_description_created.connect(func(type: String, sdp: String) -> void:
		c.set_local_description(type, sdp)
		_send({"t": "sdp", "to": id, "type": type, "sdp": sdp}))
	c.ice_candidate_created.connect(func(mid: String, idx: int, cand: String) -> void:
		_send({"t": "ice", "to": id, "mid": mid, "idx": idx, "cand": cand}))
	rtc.add_peer(c, id)
	conns[id] = c
	if offer: c.create_offer()
