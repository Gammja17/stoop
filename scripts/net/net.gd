extends Node
## 함께 날기(멀티, 베타·웹 전용).
## 방 코드 교환만 PeerJS 공개 시그널링 서버를 쓰고, 비행 데이터는 WebRTC로 플레이어끼리 직접 주고받는다.
## 방장(1번)이 모든 참가자와 연결되고, 참가자끼리의 데이터는 방장이 중계한다(Godot 서버 릴레이).

signal changed

const ICE := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"]}]}
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const MAX_PEERS := 7
const SEND_HZ := 10.0

var main
var sig: SignalClient
var rtc: WebRTCMultiplayerPeer
var room := ""
var hosting := false
var active := false
var my_pid := 0
var status_key := "mp_idle"
var peers := {}          # pid -> {conn, sig}
var remotes := {}        # pid -> RemoteFalcon
var _send_t := 0.0
var _pending_join := ""  # 주소의 ?room= 으로 들어온 방
var _pending_host := ""  # 주소의 ?host= 로 정한 코드로 방을 연다


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(func(): _set_status("mp_host_left"); leave(false))
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING:
			for kv in str(q).trim_prefix("?").split("&"):
				var p := kv.split("=")
				if p.size() == 2 and p[0] == "room":
					_pending_join = p[1].to_upper().left(4)
				elif p.size() == 2 and p[0] == "host":
					_pending_host = p[1].to_upper().left(4)


static func supported() -> bool:
	return OS.has_feature("web")


func count() -> int:
	return remotes.size() + (1 if active else 0)


func _set_status(key: String) -> void:
	status_key = key
	changed.emit()


func status_text() -> String:
	var t := Loc.t(status_key)
	if t.contains("%s"):
		t = t % room
	return t


func share_link() -> String:
	return "https://gammja17.github.io/stoop/?room=" + room


## 게임이 시작되면 주소로 받은 방에 자동으로 들어간다
func on_game_started() -> void:
	if _pending_host.length() == 4 and not active and supported():
		var hc := _pending_host
		_pending_host = ""
		host(hc)
		return
	if _pending_join != "" and not active and supported():
		var code := _pending_join
		_pending_join = ""
		join(code)


func host(code: String = "") -> void:
	if active or not supported():
		return
	room = code
	if room.length() != 4:
		room = ""
		for i in 4:
			room += CODE_CHARS[randi() % CODE_CHARS.length()]
	hosting = true
	my_pid = 1
	rtc = WebRTCMultiplayerPeer.new()
	rtc.create_server()
	multiplayer.multiplayer_peer = rtc
	_start_signal("stoop" + room)
	_set_status("mp_connecting")


func join(code: String) -> void:
	if active or not supported():
		return
	room = code.strip_edges().to_upper()
	if room.length() != 4:
		_set_status("mp_bad_code")
		return
	hosting = false
	my_pid = randi_range(2, 2000000000)
	rtc = WebRTCMultiplayerPeer.new()
	rtc.create_client(my_pid)
	multiplayer.multiplayer_peer = rtc
	_start_signal("stoopc%d" % my_pid)
	_set_status("mp_connecting")


func _start_signal(id: String) -> void:
	active = true
	sig = SignalClient.new()
	sig.opened.connect(_on_sig_open)
	sig.failed.connect(_on_sig_failed)
	sig.message.connect(_on_sig_message)
	sig.connect_as(id)


func leave(notify := true) -> void:
	if sig:
		sig.close()
	sig = null
	for pid in peers:
		var c: WebRTCPeerConnection = peers[pid].conn
		c.close()
	peers.clear()
	for pid in remotes:
		if is_instance_valid(remotes[pid]):
			remotes[pid].queue_free()
	remotes.clear()
	if rtc:
		rtc.close()
	rtc = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false
	hosting = false
	if notify:
		_set_status("mp_idle")
	changed.emit()


# ---------- 시그널링 ----------

func _on_sig_open() -> void:
	print("[net] signal open room=", room, " host=", hosting)
	if hosting:
		_set_status("mp_hosting")
	else:
		_make_conn(1, "stoop" + room).create_offer()
		_set_status("mp_joining")


func _on_sig_failed(reason: String) -> void:
	if reason == "id_taken" and hosting:
		# 같은 코드의 방이 이미 있다 → 새 코드로 다시
		leave(false)
		host()
		return
	if peers.is_empty() or reason != "closed":
		_set_status("mp_failed")


func _make_conn(pid: int, sig_id: String) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize(ICE)
	c.session_description_created.connect(_on_desc.bind(pid))
	c.ice_candidate_created.connect(_on_ice.bind(pid))
	rtc.add_peer(c, pid)
	peers[pid] = {"conn": c, "sig": sig_id}
	return c


func _pid_by_sig(src: String) -> int:
	for pid in peers:
		if peers[pid].sig == src:
			return pid
	return -1


func _on_desc(type: String, sdp: String, pid: int) -> void:
	if not peers.has(pid):
		return
	var c: WebRTCPeerConnection = peers[pid].conn
	c.set_local_description(type, sdp)
	# PeerJS 서버는 PeerJS 모양의 메시지만 중계하므로 그 틀에 담는다
	var payload := {"sdp": {"type": type, "sdp": sdp}, "type": "data", "connectionId": "dc_%d" % my_pid, "label": "dc_%d" % my_pid, "reliable": true, "serialization": "binary", "browser": "chrome", "metadata": {"pid": my_pid, "room": room}}
	sig.send("OFFER" if type == "offer" else "ANSWER", peers[pid].sig, payload)


func _on_ice(mid: String, index: int, sdp: String, pid: int) -> void:
	if not peers.has(pid) or sig == null:
		return
	sig.send("CANDIDATE", peers[pid].sig, {"candidate": {"candidate": sdp, "sdpMLineIndex": index, "sdpMid": mid}, "type": "data", "connectionId": "dc_%d" % my_pid})


func _on_sig_message(type: String, src: String, pl: Dictionary) -> void:
	match type:
		"OFFER":
			print("[net] offer from ", src)
			if not hosting:
				return
			var meta: Dictionary = pl.get("metadata", {})
			var pid := int(meta.get("pid", 0))
			if str(meta.get("room", "")) != room or pid < 2 or peers.has(pid) or peers.size() >= MAX_PEERS:
				return
			var c := _make_conn(pid, src)
			c.set_remote_description("offer", str(pl.sdp.sdp))
		"ANSWER":
			var pid2 := _pid_by_sig(src)
			if pid2 > 0:
				(peers[pid2].conn as WebRTCPeerConnection).set_remote_description("answer", str(pl.sdp.sdp))
		"CANDIDATE":
			var pid3 := _pid_by_sig(src)
			var cand: Dictionary = pl.get("candidate", {})
			if pid3 > 0 and not cand.is_empty():
				(peers[pid3].conn as WebRTCPeerConnection).add_ice_candidate(str(cand.get("sdpMid", "0")), int(cand.get("sdpMLineIndex", 0)), str(cand.get("candidate", "")))
		"LEAVE", "EXPIRE":
			if not hosting and src == "stoop" + room:
				_set_status("mp_no_room")


# ---------- 연결 ----------

func _on_peer_connected(pid: int) -> void:
	print("[net] peer connected ", pid)
	if not hosting and pid == 1:
		_set_status("mp_joined")
		Records.unlock("together")
	if hosting:
		_set_status("mp_hosting")
		Records.unlock("together")
	GameState.say(Loc.t("mp_someone_joined"), "gold")
	changed.emit()


func _on_peer_disconnected(pid: int) -> void:
	if remotes.has(pid):
		if is_instance_valid(remotes[pid]):
			remotes[pid].queue_free()
		remotes.erase(pid)
	if hosting and peers.has(pid):
		peers.erase(pid)
	GameState.say(Loc.t("mp_someone_left"), "info")
	changed.emit()


# ---------- 매 상태 주고받기 ----------

func _process(delta: float) -> void:
	if sig:
		sig.poll(delta)
	if not active or main == null or rtc == null:
		return
	if multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty():
		return
	_send_t -= delta
	if _send_t <= 0.0 and main.playing:
		_send_t = 1.0 / SEND_HZ
		var f: Falcon = main.falcon
		var m := f.model
		var fs := Growth.falcon_spec()
		_st.rpc(f.global_position, f.global_basis.get_rotation_quaternion(), f.velocity, f.tuck, m.flap_amp if m else 0.0, f.state == Falcon.State.PERCHED, str(GameState.falcon().get("name", "?")), str(fs[0]))
	# 오래 소식이 없는 매는 지운다
	var now := Time.get_ticks_msec() / 1000.0
	for pid in remotes.keys():
		var r: RemoteFalcon = remotes[pid]
		if is_instance_valid(r) and now - r.last_seen > 6.0:
			r.visible = false


@rpc("any_peer", "unreliable_ordered")
func _st(pos: Vector3, rot: Quaternion, vel: Vector3, tuck: float, flap_amp: float, perched: bool, p_name: String, p_spec: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if main == null:
		return
	var r: RemoteFalcon = remotes.get(pid)
	if r == null or not is_instance_valid(r):
		r = RemoteFalcon.new().setup(pid)
		main.add_child(r)
		remotes[pid] = r
		changed.emit()
	if not r.visible or r.label.text == "":
		print("[net] state from ", pid, " at ", pos)
	r.visible = true
	r.apply_state(pos, rot, vel, tuck, flap_amp, perched, p_name.left(12), p_spec)


## 명중·울음 같은 순간을 다른 사람 화면에도 보여 준다
func send_fx(kind: String, pos: Vector3) -> void:
	if active and not multiplayer.get_peers().is_empty():
		_fx.rpc(kind, pos)


@rpc("any_peer", "reliable")
func _fx(kind: String, pos: Vector3) -> void:
	if main == null:
		return
	match kind:
		"strike":
			Fx.feathers(main.fx_root, pos, Vector3.DOWN, Color(0.6, 0.62, 0.66), Color(0.9, 0.9, 0.9), 40, 0.9)
			Sfx.play_at("hit", pos, 0.0, 1.0, 800.0)
		"call":
			Sfx.play_at("call", pos, 2.0, randf_range(0.95, 1.05), 900.0)


func markers() -> Array:
	var out := []
	for pid in remotes:
		var r: RemoteFalcon = remotes[pid]
		if is_instance_valid(r) and r.visible:
			out.append({"pos": r.global_position + Vector3(0, 2, 0), "color": Color(0.55, 0.85, 1.0), "label": r.label.text})
	return out


func objective() -> Dictionary:
	if not active:
		return {}
	return {"text": Loc.t("mp_obj") % [room, count()]}
