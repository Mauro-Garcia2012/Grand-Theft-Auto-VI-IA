extends Node
var mode := ""
var t := 0.0
func _process(d):
	t += d
	if t > 1.0:
		var h = Game.hud
		print("HUD size=", h.size, " global=", h.get_global_rect(), " viewport=", get_viewport().get_visible_rect())
		for c in [h._radio_label, h._big_title, h._big_sub, h._zone_label, h.minimap, h._prompt]:
			print("  ", c.name, " rect=", c.get_global_rect(), " anchors=", Vector4(c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom), " offsets=", Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom))
		get_tree().quit()
