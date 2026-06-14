extends Node
## Autoload singleton: shared state across scenes + global config.

var final_score: float = 0.0
var won: bool = false

## The playable notebook area, in world coordinates (viewport is 1280x720).
var sheet_rect: Rect2 = Rect2(48, 48, 1184, 624)

## When true, the gameplay scene resolves win/lose WITHOUT changing scenes.
## Used only by the headless test harness; always false in normal play.
var testing: bool = false

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
