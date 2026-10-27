extends SceneTree
## Debug: run a detailer through polish jobs and report frame-to-frame jumps of both elbows + wrists.
const Rig = preload("res://scripts/detailer_rig.gd")
const Anim = preload("res://scripts/detailer_anim.gd")

func _init() -> void:
	var a = Anim.new(1)
	var car_t := 9.0
	var p := 0.0
	var prev := {}
	var dt := 1.0 / 30.0
	for f in 600:
		if not a.flexing():
			p += dt / car_t
		if p >= 1.0:
			p -= 1.0
			a.celebrate()
		a.set_job(p, car_t, 2)
		a.update(dt)
		var pose: Dictionary = a.pose
		var tx := Rig.torso_xf(pose)
		for near in [true, false]:
			var sh := tx * Rig.shoulder(near, 0)
			var tg: Vector2 = pose.get("hand_n" if near else "hand_f", sh)
			var vw := int(pose.get("view", 0))
			sh = tx * Rig.shoulder(near, vw)
			var bd := float(pose.get("bend_n" if near else "bend_f", 1.0 if vw == 0 else (-1.0 if near else 1.0)))
			var j := Rig.ik(sh, tg, 46.0, 40.0, bd)
			var key := "n" if near else "f"
			if prev.has(key):
				var de: float = (j[0] - prev[key][0]).length()
				var dw: float = (j[1] - prev[key][1]).length()
				if de > 6.0 or dw > 6.0:
					print("frame %d p=%.3f state=%s flex=%s arm=%s elbow jump %.1f wrist jump %.1f  dist=%.1f tool=%s" % [f, p, a.state, a.flexing(), key, de, dw, sh.distance_to(tg), str(pose.get("tool",""))])
			prev[key] = j
	quit()
