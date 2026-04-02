extends Node2D

func _draw() -> void:
	var enemy = get_parent()
	if not is_instance_valid(enemy):
		return
	if not enemy.has_method("can_see"):
		return

	var dir = enemy.facing
	var view_range = enemy.VIEW_RANGE
	var view_angle = enemy.VIEW_ANGLE
	var is_chasing = (enemy.current_state == enemy.CHASE)

	var base_color: Color
	var edge_color: Color
	var line_color: Color
	if is_chasing:
		base_color = Color(1.0, 0.1, 0.05, 0.25)
		edge_color = Color(1.0, 0.2, 0.1, 0.15)
		line_color = Color(1.0, 0.15, 0.05, 0.5)
	else:
		base_color = Color(1.0, 0.3, 0.2, 0.12)
		edge_color = Color(1.0, 0.4, 0.2, 0.06)
		line_color = Color(1.0, 0.4, 0.2, 0.3)

	var forward_angle = 0.0 if dir > 0 else PI
	var half_rad = deg_to_rad(view_angle)
	var segments = 16
	var center = Vector2.ZERO

	for i in range(segments):
		var t0 = float(i) / segments
		var t1 = float(i + 1) / segments
		var a0 = forward_angle - half_rad + t0 * half_rad * 2.0
		var a1 = forward_angle - half_rad + t1 * half_rad * 2.0
		var p0 = Vector2(cos(a0), sin(a0)) * view_range
		var p1 = Vector2(cos(a1), sin(a1)) * view_range
		draw_polygon(
			PackedVector2Array([center, p0, p1]),
			PackedColorArray([base_color, edge_color, edge_color])
		)

	var left_angle = forward_angle - half_rad
	var right_angle = forward_angle + half_rad
	draw_line(center, Vector2(cos(left_angle), sin(left_angle)) * view_range, line_color, 1.0)
	draw_line(center, Vector2(cos(right_angle), sin(right_angle)) * view_range, line_color, 1.0)

	for i in range(segments):
		var t0 = float(i) / segments
		var t1 = float(i + 1) / segments
		var a0 = forward_angle - half_rad + t0 * half_rad * 2.0
		var a1 = forward_angle - half_rad + t1 * half_rad * 2.0
		var p0 = Vector2(cos(a0), sin(a0)) * view_range
		var p1 = Vector2(cos(a1), sin(a1)) * view_range
		draw_line(p0, p1, line_color, 1.0)
