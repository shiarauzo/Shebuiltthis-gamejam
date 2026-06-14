extends Node
## Autoload singleton: shared state across scenes + global config.

var final_score: float = 0.0
var won: bool = false

## The playable notebook area, in world coordinates (viewport is 1280x720).
## Full-screen: the graph paper fills the whole window (HUD draws on top).
var sheet_rect: Rect2 = Rect2(0, 0, 1280, 720)

## When true, the gameplay scene resolves win/lose WITHOUT changing scenes.
## Used only by the headless test harness; always false in normal play.
var testing: bool = false

## Accessibility: when true, disables line-boil jitter (and, elsewhere, shake).
var reduce_motion: bool = false

# --- Line boil -------------------------------------------------------------
# Every procedural _draw() routes its vertices through boil_jitter(), and
# re-rolls the offset a few times a second, so all the hand-drawn art "boils"
# like a living doodle. Visual nodes connect to `boil_tick` to redraw in step.
signal boil_tick

var boil_seed: int = 0
var _boil_t: float = 0.0
const BOIL_INTERVAL := 0.085

func _process(delta: float) -> void:
	if reduce_motion:
		return
	_boil_t += delta
	if _boil_t >= BOIL_INTERVAL:
		_boil_t = 0.0
		boil_seed += 1
		boil_tick.emit()

## Deterministic hand-drawn wobble for a single vertex (stable within a boil tick).
func boil_jitter(p: Vector2, amp: float = 1.6) -> Vector2:
	if reduce_motion:
		return p
	return p + Vector2(_bn(p.x, p.y, boil_seed), _bn(p.y, p.x, boil_seed + 7)) * amp

func _bn(a: float, b: float, c: int) -> float:
	var s: float = sin(a * 12.9898 + b * 78.233 + float(c) * 37.719) * 43758.5453
	return (s - floor(s)) * 2.0 - 1.0

## Web-only: publish a live state snapshot to `window.__AWAKE` so browser-based
## e2e tests can assert real outcomes. No-op on native/headless.
func web_report(state: Dictionary) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__AWAKE=" + JSON.stringify(state) + ";", true)

## Web-only: read a truthy JS global (e.g. a test flag set before the game loads).
func web_flag(name: String) -> bool:
	if OS.has_feature("web"):
		return int(JavaScriptBridge.eval("window." + name + " ? 1 : 0", true)) == 1
	return false
