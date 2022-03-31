extends Area2D




func _on_Area2D_body_entered(body):
	body.set_key_picked()
	modulate = Color(0.0, 0.0, 0.0, 0.0)
	$AudioStreamPlayer.play()
