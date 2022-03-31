extends Area2D

export var item_name = "<fill>"
export var cost = 2

func _ready():
	$AnimationPlayer.play("idle")

# body is always the player
func _on_ShopItem_body_entered(body):
	print(body)
	body.set_current_selected_item(self)

func _on_ShopItem_body_exited(body):
	body.reset_current_selected_item()

func was_bought():
	$AnimationPlayer.stop(true)
	$AnimationPlayer.play("hide")
	$CollisionShape2D.disabled = true

func _on_Player_died():
	$AnimationPlayer.stop(true)
	show()
	self.modulate = Color(1.0, 1.0, 1.0, 1.0)
	$AnimationPlayer.play("idle")
	$CollisionShape2D.disabled = false
