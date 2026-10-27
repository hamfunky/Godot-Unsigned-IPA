extends Control
## v0.17g (Hamza): the ground under the "Build Bay" strip, all the way down to the last bay slot, so you
## can see how deep the shop goes. Plain dirt, plus a boarded-up band where each renovation still waits.

const UiTheme = preload("res://scripts/ui_theme.gd")
const BuildRow = preload("res://scripts/build_row.gd")
const Data = preload("res://scripts/game_data.gd")

const BayCard = preload("res://scripts/bay_card.gd")
const SLOT_H := BayCard.HEIGHT   # same height as a bay strip

var _sig := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var sig := "%s|%d|%d" % [GameState.active_city, GameState.bays.size(), GameState.reno_done()]
	if sig != _sig:
		_sig = sig
		custom_minimum_size = Vector2(0, _slots() * SLOT_H)
		queue_redraw()


## Bay slots still to come under the build strip.
func _slots() -> int:
	var cap := GameState.ht_cap() if GameState.is_hometown() else Data.MAX_BAYS
	return maxi(0, cap - GameState.bays.size() - 1)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if h <= 0.0:
		return
	draw_rect(Rect2(0, 0, w, h), Color("8a6a4a"))
	# pebbles + a few darker layers, deterministic so they don't jump around
	for layer in int(h / 300.0) + 1:
		draw_rect(Rect2(0, layer * 300.0 + 140.0, w, 10), Color(0, 0, 0, 0.06))
	var n := int(h / 9.0)
	for k in n:
		var px := fposmod(k * 97.0 + 13.0, w)
		var py := fposmod(k * 61.0, h - 10.0) + 5.0
		var r := 2.5 + (k % 4)
		draw_circle(Vector2(px, py + 1), r, Color("5e4630"))
		draw_circle(Vector2(px, py), r, Color("a5825c") if k % 3 else Color("9a9a9a"))
	# renovations still ahead, at the top of the slot they unlock
	var built := GameState.bays.size()
	var rb: Array = GameState.reno_bays()
	for k in rb.size():
		var b: int = rb[k]
		if GameState.reno_done() >= k + 1 or b <= built + 1:
			continue   # done, or it's the build strip's job right now
		var y := (b - built - 2) * SLOT_H
		_draw_barrier(Rect2(0, y, w, 46), k + 1)


## Boarded band with hazard tape and a small padlock: "RENOVATION 2".
func _draw_barrier(r: Rect2, k: int) -> void:
	var w := r.size.x
	draw_rect(r, Color("4e3b2a"))
	for x in range(0, int(w), 64):
		draw_rect(Rect2(x + 4, r.position.y + 6, 56, r.size.y - 12), Color("6d5440"))
	for x in range(0, int(w), 40):
		var y0 := r.position.y
		draw_colored_polygon(PackedVector2Array([Vector2(x, y0), Vector2(x + 20, y0), Vector2(x + 10, y0 + 8), Vector2(x - 10, y0 + 8)]), Color("ffcc00"))
		var y1 := r.end.y - 8
		draw_colored_polygon(PackedVector2Array([Vector2(x, y1), Vector2(x + 20, y1), Vector2(x + 10, y1 + 8), Vector2(x - 10, y1 + 8)]), Color("ffcc00"))
	var pill := Rect2(w * 0.5 - 130, r.position.y + 8, 260, 30)
	UiTheme.rounded(self, pill, Color(0, 0, 0, 0.55), 15, 2, UiTheme.INK)
	BuildRow.draw_padlock(self, Vector2(pill.position.x + 24, pill.position.y + 13), 16.0, 0.0)
	UiTheme.text(self, Vector2(pill.position.x + 40, pill.position.y + 22), "RENOVATION %d" % k, 18, Color("ffcc80"),
		HORIZONTAL_ALIGNMENT_CENTER, pill.size.x - 50, 4, UiTheme.DISPLAY_FONT)
