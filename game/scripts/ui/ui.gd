class_name UI
extends RefCounted
## Small UI helpers.


## Anchors a control with a preset and positions it with offsets relative to that anchor.
static func place(c: Control, preset: int, pos: Vector2, size: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = pos.x
	c.offset_top = pos.y
	c.offset_right = pos.x + size.x
	c.offset_bottom = pos.y + size.y
