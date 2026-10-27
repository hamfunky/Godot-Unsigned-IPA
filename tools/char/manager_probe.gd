extends SceneTree
## Steps every look x idle loop through idle -> ability -> idle at 60 fps and prints any frame where an
## elbow or wrist jumps (moves much more than its hand target did that frame).
const Rig = preload("res://scripts/manager_rig.gd")
const Anim = preload("res://scripts/manager_anim.gd")

func _init() -> void:
	var worst := 0.0
	var count := 0
	for li in Rig.P.LOOKS.size():
		for idle in 4:
			var a := Anim.new(li, idle, li * 0.37 + idle)
			var prev := {}
			var prev_hand := {}
			var lk := Rig.look(li)
			for f in 60 * 12:
				var t := f / 60.0
				a.active = t > 2.0 and t < 7.0
				a.update(1.0 / 60.0)
				var pose: Dictionary = a.pose()
				var arms := Rig.solve_arms(lk, pose, a.mem, float(pose["breathe"]))
				for s in ["l", "r"]:
					var hand: Vector2 = pose["hand_" + s]
					for j in ["el", "wr"]:
						var key: String = s + j
						var p: Vector2 = arms[s][j]
						if prev.has(key):
							var dj: float = p.distance_to(prev[key])
							var dh: float = hand.distance_to(prev_hand[s])
							if dj > 7.0 and dj > dh * 2.5:
								count += 1
								worst = maxf(worst, dj)
								if count < 40:
									print("JUMP look %d idle %d t=%.2f blend=%.2f %s moved %.1f (hand %.1f)" % [li, idle, t, a.blend, key, dj, dh])
						prev[key] = p
					prev_hand[s] = hand
	print("JUMPS: %d  worst %.1f units/frame" % [count, worst])
	quit()
