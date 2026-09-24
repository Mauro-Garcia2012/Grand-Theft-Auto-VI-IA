class_name Combat
extends RefCounted
## Static combat helpers: hitscan bullets, rockets, grenades and explosions.


static func apply_spread(dir: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return dir
	var r := deg_to_rad(degrees)
	var right := dir.cross(Vector3.UP)
	if right.length() < 0.01:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(dir).normalized()
	var a := randf() * TAU
	var m := sqrt(randf()) * r
	return (dir + right * cos(a) * tan(m) + up * sin(a) * tan(m)).normalized()


static func raycast(from: Vector3, to: Vector3, exclude: Array = [], mask := Game.MASK_BULLET) -> Dictionary:
	var space := Game.world.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	var ex: Array[RID] = []
	for e in exclude:
		if e is CollisionObject3D:
			ex.append(e.get_rid())
	q.exclude = ex
	q.collide_with_areas = false
	return space.intersect_ray(q)


static func fire_bullet(from: Vector3, dir: Vector3, max_range: float, damage: float, shooter: Node) -> void:
	var exclude: Array = [shooter]
	if shooter is Humanoid and shooter.vehicle:
		exclude.append(shooter.vehicle)
	var to := from + dir * max_range
	var hit := raycast(from, to, exclude)
	var end := to
	if not hit.is_empty():
		end = hit.position
		var col: Object = hit.collider
		# falloff with distance
		var dist := from.distance_to(end)
		var dmg := damage * clampf(1.2 - dist / max_range, 0.35, 1.0)
		if col is Humanoid:
			col.take_damage(dmg, shooter, end, dir, "bullet")
		elif col is Vehicle or col is Boat or col is Aircraft:
			if _hit_occupant(col, from, dir, from.distance_to(end), dmg, shooter):
				col.take_damage(dmg * 0.2, shooter, end)
				Game.effects.impact(end, hit.normal, "glass")
			else:
				col.take_damage(dmg * 0.6, shooter, end)
				Game.effects.impact(end, hit.normal, "metal")
		else:
			Game.effects.impact(end, hit.normal, "concrete")
			if col.has_method("on_bullet_hit"):
				col.on_bullet_hit(end, dir, shooter)
			if col is RigidBody3D:
				col.apply_impulse(dir * 3.0, end - col.global_position)
		# bullets passing near pedestrians scare them
	Game.effects.tracer(from, end)
	if Game.population:
		Game.population.bullet_whiz(from, end, shooter)


## A bullet that hits a vehicle carries on through the glass into the cabin: if its line passes
## through someone sitting inside (head or chest), they take the hit.
static func _hit_occupant(v: Node, from: Vector3, dir: Vector3, hit_dist: float, dmg: float, shooter: Node) -> bool:
	if not "occupants" in v:
		return false
	var up: Vector3 = v.global_basis.y
	# how far inside the vehicle the bullet may still reach someone (wings, long cabins)
	var reach := 2.6
	if "body_size" in v:
		reach = maxf(reach, v.body_size.x * 0.6)
	var best: Humanoid = null
	var best_d := INF
	var head := false
	for o in v.occupants:
		if o == null or not is_instance_valid(o) or o == shooter or not o is Humanoid:
			continue
		# [height above the seat, radius, is head]
		for part in [[0.98, 0.2, true], [0.62, 0.3, false]]:
			var c: Vector3 = o.global_position + up * part[0]
			var t := clampf((c - from).dot(dir), hit_dist - 0.2, hit_dist + reach)
			var d := (from + dir * t - c).length()
			if d < part[1] and d < best_d:
				best = o
				best_d = d
				head = part[2]
	if best == null:
		return false
	if best.dead:
		return true
	var p := from + dir * hit_dist
	best.take_damage(dmg * (3.0 if head else 1.0), shooter, p + dir * 0.5, dir, "bullet")
	Sfx.play_at("glass", p, -4.0, randf_range(0.9, 1.2))
	return true


static func fire_rocket(from: Vector3, dir: Vector3, shooter: Node) -> void:
	var r := Rocket.new()
	r.shooter = shooter
	r.velocity = dir * 60.0
	Game.world.add_child(r)
	r.global_position = from + dir * 0.6
	r.look_at(from + dir * 10.0, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)


## Grenade launcher: an explosive shell on a ballistic arc that goes off on impact.
static func fire_shell(from: Vector3, dir: Vector3, shooter: Node) -> void:
	var g := Grenade.new()
	g.kind = "shell"
	g.shooter = shooter
	Game.world.add_child(g)
	g.global_position = from + dir * 0.5
	g.linear_velocity = dir * 42.0 + Vector3.UP * 2.0


static func throw_grenade(from: Vector3, target: Vector3, shooter: Node, kind := "frag") -> void:
	var g := Grenade.new()
	g.kind = kind
	g.shooter = shooter
	Game.world.add_child(g)
	g.global_position = from
	var to := target - from
	var flat := Vector3(to.x, 0, to.z)
	var d := clampf(flat.length(), 3.0, 30.0)
	var dir := flat.normalized() if flat.length() > 0.1 else -Game.player.global_basis.z
	# ballistic-ish launch
	var speed := sqrt(d * 18.0 / sin(deg_to_rad(80.0))) * 0.75
	var v := dir * speed * cos(deg_to_rad(38.0)) + Vector3.UP * speed * sin(deg_to_rad(38.0))
	g.linear_velocity = v
	g.angular_velocity = Vector3(randf() * 10, randf() * 10, 0)


static func explosion(pos: Vector3, radius: float, damage: float, source: Node = null) -> void:
	Game.effects.explosion(pos, radius)
	Sfx.play_at("explosion", pos, 6.0)
	if Game.camera_rig:
		var d := Game.camera_rig.global_position.distance_to(pos)
		Game.camera_rig.shake(clampf(1.4 - d / 80.0, 0.0, 1.2))
	for h in Game.world.get_tree().get_nodes_in_group("humanoids"):
		if h.dead:
			continue
		var dist: float = h.global_position.distance_to(pos)
		if dist < radius:
			var f := 1.0 - dist / radius
			var dir: Vector3 = (h.global_position - pos).normalized()
			h.take_damage(damage * f * f + 10.0, source, h.global_position + Vector3.UP, dir, "explosion")
			if not h.dead:
				h.knockdown(dir * 8.0 * f + Vector3.UP * 5.0 * f)
			elif h.vehicle == null:
				h.velocity = dir * 9.0 * f + Vector3.UP * 7.0 * f
	for v in Game.world.get_tree().get_nodes_in_group("vehicles"):
		var dist: float = v.global_position.distance_to(pos)
		if v is Aircraft:
			# big airframes: measure roughly from the skin, not from the centre
			dist = maxf(0.0, dist - v.body_size.x * 0.4)
		if dist < radius * 1.3:
			var f := 1.0 - dist / (radius * 1.3)
			# aircraft are fragile: one rocket brings a plane or helicopter down
			v.take_damage(damage * 3.0 * f * (8.0 if v is Aircraft else 1.0), source)
			if v is RigidBody3D:
				v.apply_impulse((v.global_position - pos).normalized() * v.mass * 7.0 * f + Vector3.UP * v.mass * 4.0 * f, Vector3(randf() - 0.5, 0.3, randf() - 0.5))
	if Game.population:
		Game.population.panic_at(pos, 80.0, source)
	if source == Game.player:
		Game.report_crime(pos, 2.0, "explosion")
