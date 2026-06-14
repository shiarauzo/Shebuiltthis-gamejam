extends SceneTree
## One-off: keys the white background out of the hand-drawn doodle-run frames
## (alpha = how dark the pixel is) and tints the ink to the game's line colour,
## so the doodle sits on the notebook with clean anti-aliased edges.
## Run:  Godot --headless --path . --script res://tools/process_doodle.gd

func _init() -> void:
	var ink := Color(0.12, 0.12, 0.18)
	var out_dir := "res://assets/sprites/doodle_run/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for i in range(7):
		var img := Image.new()
		if img.load("res://doodle-run/frame%04d.png" % i) != OK:
			printerr("could not load frame ", i)
			continue
		img.convert(Image.FORMAT_RGBA8)
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var c := img.get_pixel(x, y)
				var lum := (c.r + c.g + c.b) / 3.0
				# Alpha = how dark the pixel is, but never resurrect already-
				# transparent pixels (source may have a transparent background
				# with arbitrary RGB underneath).
				var a := pow(clampf(1.0 - lum, 0.0, 1.0), 1.1) * c.a
				img.set_pixel(x, y, Color(ink.r, ink.g, ink.b, a))
		img.save_png(out_dir + "run_%d.png" % i)
		print("wrote run_%d.png" % i)
	quit()
