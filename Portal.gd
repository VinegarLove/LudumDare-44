extends Area2D

export (NodePath) var destinationPath
export var need_key = false
onready var destination = get_node(destinationPath)

# body is always the player
func _on_Portal1_body_entered(body):
	if need_key and !body.has_key():
		return
	body.set_teleport_position(destination.global_position)

func _on_Portal1_body_exited(body):
	body.reset_teleport_position()
