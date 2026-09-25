class_name Minimap
extends Control
## GTA V style radar: a rotating rectangle with the player low in it (more road ahead), roads,
## blips clamped to the edge, police search area and GPS route.

var tex: Texture2D
var zoom := 1.4
var route := PackedVector3Array()
var _route_t := 0.0
var _mask: Control
var _content: Control
var _overlay: Control
var _redraw_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex = MapImage.texture
	_mask = _Mask.new()
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_mask)
	_content = _Content.new()
	_content.mm = self
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.add_child(_content)
	_overlay = _Overlay.new()
	_overlay.mm = self
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


func _process(delta: float) -> void:
	var p := Game.player
	if p == null:
		return
	var spd: float = p.vehicle.linear_velocity.length() if p.vehicle and is_instance_valid(p.vehicle) else 0.0
	zoom = lerpf(zoom, clampf(1.8 - spd / 30.0, 0.8, 1.8), delta * 2.0)
	_route_t -= delta
	if _route_t <= 0.0:
		_route_t = 1.0
		if Game.has_meta("waypoint"):
			var wp: Vector3 = Game.get_meta("waypoint")
			if Game.player_pos().distance_to(wp) < 25.0:
				Game.remove_meta("waypoint")
				route = PackedVector3Array()
				Game.msg("Has llegado a tu destino", 2.0)
			else:
				route = Game.city.find_path(Game.player_pos(), wp)
				route.append(wp)
		else:
			route = PackedVector3Array()
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 1.0 / 30.0
		_content.queue_redraw()
		_overlay.queue_redraw()


func yaw() -> float:
	return Game.camera_rig.yaw if Game.camera_rig else 0.0


## Where the player sits in the radar (lower than the middle, like GTA V).
func center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.62)


func inside(s: Vector2, margin := 4.0) -> bool:
	return s.x > margin and s.y > margin and s.x < size.x - margin and s.y < size.y - margin


## Pushes a point outside the radar onto its border (along the line from the player).
func clamp_edge(s: Vector2, margin := 10.0) -> Vector2:
	var c := center()
	var d := s - c
	if d.length() < 0.01:
		return s
	var tx := INF
	var ty := INF
	if absf(d.x) > 0.001:
		tx = ((size.x - margin - c.x) if d.x > 0.0 else (margin - c.x)) / d.x
	if absf(d.y) > 0.001:
		ty = ((size.y - margin - c.y) if d.y > 0.0 else (margin - c.y)) / d.y
	return c + d * minf(1.0, minf(tx, ty))


func to_screen(world: Vector3) -> Vector2:
	var c := center()
	var pp := MapImage.world_to_px(Game.player_pos())
	var wp := MapImage.world_to_px(world)
	return c + (wp - pp).rotated(yaw()) * zoom


class _Mask extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)


class _Content extends Control:
	var mm: Minimap

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if mm.tex == null or Game.player == null:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.3, 0.4))
			return
		var c := mm.center()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.38, 0.52))
		var pp := MapImage.world_to_px(Game.player_pos())
		draw_set_transform(c, mm.yaw(), Vector2(mm.zoom, mm.zoom))
		draw_texture(mm.tex, -pp)
		# wanted search area
		if Game.wanted and Game.wanted.stars > 0:
			var lp := MapImage.world_to_px(Game.wanted.last_seen) - pp
			var r: float = Game.wanted.search_radius() / MapImage.MPP
			var col := Color(1, 0.2, 0.2, 0.18) if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else Color(0.2, 0.4, 1, 0.18)
			draw_circle(lp, r, col)
		# GPS route
		if mm.route.size() > 1:
			var pts := PackedVector2Array()
			for w in mm.route:
				pts.append(MapImage.world_to_px(w) - pp)
			draw_polyline(pts, Color(0.75, 0.35, 1.0), 5.0 / mm.zoom)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		# blips (inside)
		for h in Game.humanoids():
			if not is_instance_valid(h) or h == Game.player or h.dead:
				continue
			var col := Color.TRANSPARENT
			if h.team == "police" and Game.get_wanted() > 0:
				col = Color(1, 0.2, 0.2) if fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0 else Color(0.3, 0.5, 1)
			elif h.team == "player":
				col = Color(1, 0.5, 0.8)
			elif h.brain and "state" in h.brain and h.brain.state == PedBrain.S.FIGHT and h.brain.threat == Game.player:
				col = Color(1, 0.15, 0.15)
			if col.a > 0.0:
				var s := mm.to_screen(h.global_position)
				if mm.inside(s):
					draw_circle(s, 4.5, col)
		# police cars and helicopters as bigger blips while wanted
		if Game.wanted and Game.get_wanted() > 0:
			var flash := fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0
			for u in Game.wanted.units + Game.wanted.helis:
				if u != null and is_instance_valid(u) and not u.destroyed:
					var s := mm.to_screen(u.global_position)
					if mm.inside(s):
						draw_circle(s, 6.5, Color(0, 0, 0, 0.7))
						draw_circle(s, 5.0, Color(1, 0.2, 0.2) if flash else Color(0.3, 0.5, 1))


class _Overlay extends Control:
	var mm: Minimap

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := mm.center()
		var r := size.x * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), false, 4.0)
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(1, 1, 1, 0.18), false, 1.5)
		# north marker on the border
		var n := Vector2(0, -1).rotated(mm.yaw())
		var np := mm.clamp_edge(c + n * 1000.0, 12.0)
		draw_circle(np, 9.0, Color(0.1, 0.1, 0.1, 0.9))
		draw_string(get_theme_default_font(), np + Vector2(-5, 5), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		# locations (clamped to the edge)
		var loc = Game.get_meta("locations") if Game.has_meta("locations") else null
		if loc:
			for p in loc.places:
				var s := mm.to_screen(p.pos)
				var d := s.distance_to(c)
				if d > r * 2.2:
					continue
				if not mm.inside(s, 10.0):
					if p.kind in ["safe", "gun", "hospital"]:
						s = mm.clamp_edge(s)
					else:
						continue
				var b: Array = Locations.BLIP.get(p.kind, ["•", Color.WHITE])
				draw_circle(s, 9.0, Color(0, 0, 0, 0.75))
				draw_string(get_theme_default_font(), s + Vector2(-6, 6), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, b[1])
		# waypoint
		if Game.has_meta("waypoint"):
			var s := mm.to_screen(Game.get_meta("waypoint"))
			if not mm.inside(s, 8.0):
				s = mm.clamp_edge(s, 8.0)
			draw_circle(s, 7.0, Color(0.8, 0.4, 1.0))
		# player arrow
		var heading := Game.player.global_rotation.y
		if Game.player.vehicle and is_instance_valid(Game.player.vehicle):
			heading = Game.player.vehicle.global_rotation.y
		var ang := mm.yaw() - heading
		var fwd := Vector2(0, -1).rotated(ang)
		var right := Vector2(fwd.y * -1, fwd.x)
		var tri := PackedVector2Array([c + fwd * 10, c - fwd * 7 + right * 7, c - fwd * 3, c - fwd * 7 - right * 7])
		draw_colored_polygon(tri, Color.WHITE)
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0), 1.5)
