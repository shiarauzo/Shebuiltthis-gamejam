extends Area2D
class_name EscapeEdge
## The right edge of the page. Opens (glows + becomes reachable) when the eraser
## appears. Touching it = escape = win.

signal reached

var active := false

func _ready() -> void:
	z_index = 4
	visible = false
	monitoring = false
	collision_layer = 0
	collision_mask = 1
	var r: Rect2 = Game.sheet_rect
	# Place the node at the edge center; collision is centered on the node, so
	# this stays correct even if the node is ever repositioned/animated.
	position = Vector2(r.position.x + r.size.x - 20.0, r.position.y + r.size.y / 2.0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, r.size.y)
	cs.shape = rect
	add_child(cs)
	body_entered.connect(_on_body_entered)

func open() -> void:
	active = true
	visible = true
	monitoring = true
	queue_redraw()

func _on_body_entered(body: Node) -> void:
	if active and body.is_in_group("player"):
		reached.emit()

func _draw() -> void:
	# The edge is intentionally invisible now — the doodle discovers that the path
	# continues (a page-1 hint nudges them right). Kept as a node so the win
	# collision still works if ever wired up.
	pass
