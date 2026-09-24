class_name SocialFeed
extends Control
## GTA VI style social media: when the player does something big (a police chase, a plane shot
## down, a robbery, a killing spree, a car blown up) a post about it goes viral and slides in on the
## right of the screen, with a user, the text, the place and the likes.

const POSTS := {
	"chase": [["@vicecity_live", "Persecución EN DIRECTO por %s 🚔🚔🚔 ¿Quién es este loco?"],
		["@leonida_news", "La VCPD pide a los vecinos de %s que no salgan de casa"],
		["@florida_man_daily", "Otro día normal en %s: medio cuerpo de policía persiguiendo a una sola persona"]],
	"army": [["@leonida_news", "ÚLTIMA HORA: el ejército despliega blindados en %s"],
		["@conspiraciones_vc", "Os lo dije. Helicópteros militares sobre %s. Despertad 👁️"]],
	"plane": [["@spotters_vice", "¡¡ACABAN DE DERRIBAR UN AVIÓN SOBRE %s!! 😱✈️🔥"],
		["@leonida_news", "Un avión se estrella en %s. Las autoridades investigan"]],
	"robbery": [["@barrio_vice", "Han atracado la tienda de %s a punta de pistola 😳"],
		["@el_cubano_305", "Otra vez el 24h de %s... ya ni me sorprende"]],
	"spree": [["@vicecity_live", "Tiroteo en %s, la gente corre por todas partes 🏃‍♀️💨"],
		["@leonida_news", "Varios heridos en %s. La policía busca a un sospechoso armado"]],
	"explosion": [["@vice_drift_club", "Un coche acaba de volar por los aires en %s 💥 grabado en 4K"],
		["@florida_man_daily", "Florida man hace explotar un coche en %s «por aburrimiento»"]],
	"shootdown_heli": [["@vicecity_live", "¡Han derribado el helicóptero de la policía en %s! 🚁🔥"]],
}
const COLORS := [Color(1, 0.35, 0.6), Color(0.3, 0.75, 1), Color(1, 0.7, 0.2), Color(0.5, 1, 0.5), Color(0.8, 0.5, 1)]

var _queue: Array = []
var _card: Dictionary = {}       # {user, text, place, likes, col, t}
var _cooldown := {}
var _font: Font
var _bold: Font
var _kills: Array = []           # times of the player's recent kills


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(self, Control.PRESET_TOP_RIGHT, Vector2(-440, 230), Vector2(420, 130))
	_font = ThemeDB.fallback_font
	_bold = _font
	Game.set_meta("social_feed", self)
	Game.wanted_changed.connect(_on_wanted)


## Something happened that people would post about.
static func event(kind: String) -> void:
	if Game.has_meta("social_feed"):
		(Game.get_meta("social_feed") as SocialFeed)._post(kind)


func on_player_kill() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_kills.append(now)
	while not _kills.is_empty() and now - _kills[0] > 25.0:
		_kills.pop_front()
	if _kills.size() >= 4:
		_kills.clear()
		_post("spree")


func _on_wanted(stars: int) -> void:
	if stars >= 5:
		_post("army")
	elif stars >= 3:
		_post("chase")


func _post(kind: String) -> void:
	if not POSTS.has(kind) or Game.player == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _cooldown.get(kind, 0.0):
		return
	_cooldown[kind] = now + 90.0
	var pp := Game.player_pos()
	var place: String = Game.city.district_info(Game.city.district_at(pp.x, pp.z)).name if Game.city else "Vice City"
	var p: Array = POSTS[kind].pick_random()
	var likes := randi_range(800, 250000)
	_queue.append({"user": p[0], "text": p[1] % place, "place": place, "likes": likes, "col": COLORS.pick_random(), "t": 0.0})


func _process(delta: float) -> void:
	if _card.is_empty():
		if _queue.is_empty():
			return
		_card = _queue.pop_front()
		Sfx.play("beep", -12.0, 1.6)
	_card.t += delta
	# likes keep going up while it is on screen
	_card.likes += int(delta * _card.likes * 0.15)
	if _card.t > 7.0:
		_card = {}
	queue_redraw()


func _draw() -> void:
	if _card.is_empty():
		return
	var t: float = _card.t
	var slide := clampf(t / 0.35, 0.0, 1.0) * clampf((7.0 - t) / 0.35, 0.0, 1.0)
	var x := (1.0 - slide) * 460.0
	var r := Rect2(x, 0, size.x, size.y)
	draw_rect(r, Color(0.05, 0.04, 0.08, 0.85 * slide))
	draw_rect(Rect2(x, 0, 5, size.y), _card.col * Color(1, 1, 1, slide))
	# avatar
	var av := Vector2(x + 36, 34)
	draw_circle(av, 20, _card.col * Color(1, 1, 1, slide))
	var ini: String = str(_card.user).substr(1, 1).to_upper()
	draw_string(_bold, av + Vector2(-7, 8), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, slide))
	draw_string(_bold, Vector2(x + 66, 30), _card.user, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, slide))
	draw_string(_font, Vector2(x + 66, 50), "ViceFeed · %s · ahora" % _card.place, HORIZONTAL_ALIGNMENT_LEFT, 340, 13, Color(0.75, 0.75, 0.8, slide))
	draw_multiline_string(_font, Vector2(x + 16, 78), _card.text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, 16, 2, Color(1, 1, 1, slide))
	var likes: int = _card.likes
	var ls := ("%.1f mil" % (likes / 1000.0)) if likes >= 1000 else str(likes)
	draw_string(_font, Vector2(x + 16, size.y - 10), "♥ %s   ⟲ %d   💬 %d" % [ls, likes / 7, likes / 20], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.45, 0.6, slide))
