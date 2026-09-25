class_name SignalClient
extends RefCounted
## PeerJS 공개 시그널링 서버(0.peerjs.com)에 붙어서 WebRTC 연결 정보(offer/answer/candidate)만 주고받는다.
## 계정이 필요 없다. 게임 데이터는 이 서버를 거치지 않는다(WebRTC로 직접).

signal opened
signal failed(reason: String)
signal message(type: String, src: String, payload: Dictionary)

const HOST := "wss://0.peerjs.com/peerjs"

var id := ""
var ws := WebSocketPeer.new()
var is_open := false
var _beat := 0.0
var _was_open := false
var debug := false


func connect_as(peer_id: String) -> void:
	id = peer_id
	var token := str(randi())
	var url := "%s?key=peerjs&id=%s&token=%s&version=1.5.4" % [HOST, peer_id, token]
	var err := ws.connect_to_url(url)
	if err != OK:
		failed.emit("connect error %d" % err)


func close() -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
	is_open = false


func send(type: String, dst: String, payload: Dictionary) -> void:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send_text(JSON.stringify({"type": type, "dst": dst, "payload": payload}))


func poll(delta: float) -> void:
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		_was_open = true
		_beat -= delta
		if _beat <= 0.0:
			_beat = 5.0
			ws.send_text(JSON.stringify({"type": "HEARTBEAT"}))
		while ws.get_available_packet_count() > 0:
			var txt := ws.get_packet().get_string_from_utf8()
			if debug:
				print("[sig] ", id, " <- ", txt.left(200))
			var msg = JSON.parse_string(txt)
			if typeof(msg) != TYPE_DICTIONARY:
				continue
			var t: String = str(msg.get("type", ""))
			match t:
				"OPEN":
					is_open = true
					opened.emit()
				"ID-TAKEN":
					failed.emit("id_taken")
				"ERROR":
					failed.emit(str(msg.get("payload", {}).get("msg", "error")))
				_:
					var pl = msg.get("payload", {})
					message.emit(t, str(msg.get("src", "")), pl if typeof(pl) == TYPE_DICTIONARY else {})
	elif st == WebSocketPeer.STATE_CLOSED and _was_open:
		if debug:
			print("[sig] ", id, " closed code=", ws.get_close_code(), " reason=", ws.get_close_reason())
		_was_open = false
		is_open = false
		failed.emit("closed")
