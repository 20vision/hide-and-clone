class_name Sfx extends RefCounted
## Tiny sounds generated in code, so no audio files are needed.
static var _cache: Dictionary = {}
static var muted := false

static func _make(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.2
	match kind:
		"zap": dur = 0.18
		"pop": dur = 0.14
		"out": dur = 0.45
		"tick": dur = 0.06
		"win": dur = 0.7
		"poof": dur = 0.22
	var n := int(rate * dur)
	var d := PackedByteArray()
	d.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var f := 440.0
		var noise := 0.0
		match kind:
			"zap": f = lerpf(1500.0, 300.0, t)
			"pop": f = lerpf(300.0, 900.0, t)
			"out": f = lerpf(700.0, 90.0, t)
			"tick": f = 1000.0
			"win": f = [523.0, 659.0, 784.0, 1047.0][mini(int(t * 4.0), 3)]
			"poof":
				f = 200.0
				noise = randf_range(-0.6, 0.6)
		ph += TAU * f / rate
		var v := (sin(ph) * (1.0 - absf(noise)) + noise) * (1.0 - t) * 0.5
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.data = d
	return s

static func play(parent: Node, kind: String, vol := 0.0) -> void:
	if muted or parent == null or not parent.is_inside_tree(): return
	if not _cache.has(kind): _cache[kind] = _make(kind)
	var p := AudioStreamPlayer.new()
	p.stream = _cache[kind]
	p.volume_db = vol
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
