extends Node
## Autoload singleton: shared state across scenes + global config.

var final_score: float = 0.0
var won: bool = false

## The playable notebook area, in world coordinates (viewport is 1280x720).
var sheet_rect: Rect2 = Rect2(48, 48, 1184, 624)

## When true, the gameplay scene resolves win/lose WITHOUT changing scenes.
## Used only by the headless test harness; always false in normal play.
var testing: bool = false
