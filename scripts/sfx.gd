extends Node
## Autoload "Sfx": sound effects, background music + phone vibration.
##   Sfx.play("cash")    Sfx.buzz(30)
## Each sound SLOT can have several versions (v0.17g): the soft mid-low "pop" sounds made in code
## (tools/audio_synth.py) are the default where the old Kenney ones were shrill; the originals are still
## there to pick in the Sound board (Shop > Settings). Picks are saved in settings["sfx_pick"].
## Each sound has a minimum gap so 10 bays finishing at once don't make a racket.
## Music: every .ogg in assets/game/music, shuffled, one after another. Drop real tracks in there later.

const DIR := "res://assets/game/sfx/"
const MUSIC_DIR := "res://assets/game/music/"
## slot -> versions: [name, [files], volume dB]. The first version is the default.
const SOUNDS := {
	"click": [["Soft pop", ["pop_click"], -7.0], ["Original click", ["click"], -8.0]],
	"tap": [["Bloop", ["pop_tap"], -5.0], ["Original tap", ["tap"], -6.0]],
	"open": [["Soft pop up", ["pop_open"], -10.0], ["Original swish", ["open"], -12.0]],
	"close": [["Soft pop down", ["pop_close"], -10.0], ["Original swish", ["close"], -12.0]],
	"toggle": [["Double pop", ["pop_toggle"], -7.0], ["Original toggle", ["toggle"], 0.0]],
	"cash": [["Coin pop", ["pop_cash"], -6.0], ["Original chips", ["cash_1", "cash_2", "cash_3"], -9.0]],
	"level_up": [["Pop up", ["pop_level"], -6.0], ["Original level up", ["level_up"], 0.0]],
	"hire": [["Marimba chime", ["pop_hire"], -5.0], ["Original hire", ["hire"], 0.0]],
	"error": [["Low bonk", ["pop_error"], -6.0], ["Original error", ["error"], 0.0]],
	"cat": [["Mrrp", ["pop_mrrp"], -9.0], ["Bloop", ["pop_tap"], -5.0]],   # v0.19t: petting Suds
	"boost": [["Boost", ["boost"], 0.0]],
	"build_bay": [["Build bay", ["build_bay"], 0.0]],
	"reno_start": [["Renovation start", ["reno_start"], 0.0]],
	"unlock": [["Unlock", ["unlock"], 0.0]],
	"big_win": [["Big win", ["big_win"], 0.0]],
	"vip_arrive": [["Rare car arrives", ["vip_arrive"], 0.0]],
	"vip_done": [["Rare car done", ["vip_done"], 0.0]],
	"car_done": [["Car done", ["car_done"], -16.0]],
	"valet_drop": [["Valet drop", ["valet_drop"], -14.0]],
	"new_car": [["New car", ["new_car"], -6.0]],
}
const MIN_GAP := {"car_done": 0.3, "cash": 0.2, "valet_drop": 0.4, "new_car": 0.6, "level_up": 0.06, "click": 0.05}
const PLAYERS := 10
const BASE_PITCH := 0.97      # everything a touch lower (Hamza: shrill sounds are the worst)
const MUSIC_DB_AT_FULL := -8.0

var _streams := {}            # slot -> Array of versions, each an Array of streams
var _players: Array[AudioStreamPlayer] = []
var _last := {}
var _next := 0
var _chain := 0.0             # quick repeated level-ups climb a little in pitch
var _music: AudioStreamPlayer
var _tracks: Array = []
var _track := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS.keys():
		var versions := []
		for v in SOUNDS[key]:
			var list := []
			for f in v[1]:
				var path: String = DIR + f + ".ogg"
				if ResourceLoader.exists(path):
					list.append(load(path))
			versions.append(list)
		_streams[key] = versions
	for k in PLAYERS:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(_next_track)
	_find_tracks()
	_start_music.call_deferred()


# ---------------------------------------------------------------- effects

func pick(key: String) -> int:
	var picks: Dictionary = GameState.settings.get("sfx_pick", {})
	return clampi(int(picks.get(key, 0)), 0, SOUNDS.get(key, [[]]).size() - 1)


func set_pick(key: String, i: int) -> void:
	var picks: Dictionary = GameState.settings.get("sfx_pick", {}).duplicate()
	picks[key] = i
	GameState.set_setting("sfx_pick", picks)


func play(key: String, pitch_jitter: float = 0.04) -> void:
	if not GameState.settings.get("sound", true):
		return
	var t := Time.get_ticks_msec() * 0.001
	if t - float(_last.get(key, -10.0)) < float(MIN_GAP.get(key, 0.0)):
		return
	var pitch := BASE_PITCH
	if key == "level_up":
		# buying several levels in a row climbs a little (never shrill: at most +9%)
		_chain = minf(_chain + 0.03, 0.09) if t - float(_last.get(key, -10.0)) < 0.6 else 0.0
		pitch += _chain
	_last[key] = t
	play_version(key, pick(key), pitch + randf_range(-pitch_jitter, pitch_jitter))


## Stops every sound effect that's playing (the Sound board cuts the button click before a preview).
func stop_effects() -> void:
	for p in _players:
		p.stop()


## Plays one specific version of a slot (the Sound board previews with this).
func play_version(key: String, i: int, pitch: float = BASE_PITCH) -> void:
	var versions: Array = _streams.get(key, [])
	if i >= versions.size() or versions[i].is_empty():
		return
	var p: AudioStreamPlayer = null
	for q in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _players[_next]
		_next = (_next + 1) % _players.size()
	p.stream = versions[i].pick_random()
	p.volume_db = float(SOUNDS[key][i][2])
	p.pitch_scale = pitch
	p.play()


## Short vibration on phones (Android browsers / app). ms: 10 tap, 30 buy, 100+ big moments.
func buzz(ms: int) -> void:
	if GameState.settings.get("vibration", true):
		Input.vibrate_handheld(ms)


# ---------------------------------------------------------------- music

func _find_tracks() -> void:
	_tracks = []
	var names: PackedStringArray = ResourceLoader.list_directory(MUSIC_DIR)
	for n in names:
		var f := n.trim_suffix(".import").trim_suffix(".remap")
		if (f.ends_with(".ogg") or f.ends_with(".mp3") or f.ends_with(".wav")) and not _tracks.has(MUSIC_DIR + f):
			_tracks.append(MUSIC_DIR + f)
	_tracks.shuffle()


func music_on() -> bool:
	return bool(GameState.settings.get("music", true))


func music_volume() -> float:
	return clampf(float(GameState.settings.get("music_volume", 0.6)), 0.0, 1.0)


func _start_music() -> void:
	if music_on() and not _tracks.is_empty() and not _music.playing:
		_next_track()


func _next_track() -> void:
	if not music_on() or _tracks.is_empty():
		return
	_track = (_track + 1) % _tracks.size()
	var s = load(_tracks[_track])
	if s == null:
		return
	if "loop" in s:
		s.loop = false   # one after another, not one forever
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", _music_db(), 2.5)


func _music_db() -> float:
	var v := music_volume()
	return linear_to_db(maxf(v, 0.001)) + MUSIC_DB_AT_FULL


## Settings changed (music on/off or its volume).
func refresh_music() -> void:
	if not music_on():
		_music.stop()
		return
	if not _music.playing:
		_next_track()
	else:
		_music.volume_db = _music_db()


func track_name() -> String:
	if _track < 0 or _track >= _tracks.size():
		return "-"
	return _tracks[_track].get_file().get_basename().replace("_", " ")
