extends KinematicBody2D

export var max_life = 1
export var looking_time = 0.75
export var distance_difference_allowed = Vector2(15.0, 10.0)
export var aggro_distance_allowed = Vector2(100.0, 15.0)
export var charge_speed_closeup = 200
export var chasing_max_time = 1.0
export var GRAVITY_VEC = Vector2(0.0, 900)
export var FLOOR_NORMAL = Vector2(0.0, -1)
export var SMOOTHING_SPEED_HORIZONTAL = 0.1

onready var aniplayer = $AnimationPlayer
onready var sprite = $Sprite
onready var collision_shape = $CollisionShape2D
onready var player = get_tree().get_nodes_in_group("player").front()
onready var current_life = max_life

var is_attacking = false
var is_dying = false
var is_going_back = false
var exited_area = false
var facing_right = false
var linear_vel = Vector2()
var target_position = Vector2()
var initial_target = Vector2()
var chasing_time = 0.0

# attack collision checking
var is_attack_collision_enable = false
export var distance_attack_allowed = Vector2(15.0, 5.0)

signal death

func _ready():
	print("ready: ", name)
	add_to_group("enemies")
	player.connect("died", self, "_on_player_death")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	chasing_time += delta
	linear_vel += delta * GRAVITY_VEC
	linear_vel = move_and_slide(linear_vel, FLOOR_NORMAL)

	if !is_dying and is_dead():
		death_sequence()

	if is_dead():
		return

	if !is_attacking and !is_going_back and is_out_of_area():
		print("executing going back sequence")
		go_back_to_start_sequence()

	if !is_attacking and !is_going_back and is_player_inside_aggro_range():
		print("executing attack sequence")
		attack_player_sequence()

	var mov_dir = 0
	# movement if has a target position
	if target_position:
		var position_to_move = target_position - global_position
		mov_dir = round(clamp(position_to_move.x, -1.0, 1.0))
		var speed = mov_dir * charge_speed_closeup
		linear_vel.x = lerp(linear_vel.x, speed, SMOOTHING_SPEED_HORIZONTAL)

	# animations
	if facing_right and mov_dir < 0:
		face_left()
	if !facing_right and mov_dir > 0:
		face_right()

func flip():
	facing_right = !facing_right
	sprite.flip_h = !sprite.flip_h

func face_right():
	facing_right = true
	sprite.flip_h = true

func face_left():
	facing_right = false
	sprite.flip_h = false

func attack_player_sequence():
	is_attacking = true
	print("looking")
	yield(look_at_player(), "completed")
	print("charging")
	yield(charge_player(), "completed")
	print("attacking")
	yield(attack_player(), "completed")
	print("finished sequence")
	reset_attack_player_sequence()

func reset_attack_player_sequence():
	print("resetting attack")
	target_position = Vector2.ZERO
	is_attacking = false

func death_sequence():
	is_dying = true
	aniplayer.stop(true)
	aniplayer.play("death")
	yield(aniplayer, "animation_finished")
	hide()
	set_process(false)
	set_physics_process(false)
	collision_shape.disabled = true
	is_dying = false

func is_dead():
	return current_life <= 0

func is_alive():
	return not is_dead()

func look_at_player():
	if is_dead():
		reset_attack_player_sequence()
		return yield()

	if player.global_position.x > global_position.x:
		face_right()
	else:
		face_left()

	aniplayer.play("looking_player")
	yield(get_tree().create_timer(looking_time), "timeout")

func charge_player():
	if is_dead():
		reset_attack_player_sequence()
		return yield(get_tree(), "physics_frame")

	chasing_time = 0.0
	initial_target = Vector2(player.global_position.x, global_position.y)
	target_position = player.global_position
	while(is_alive() and not (has_reached_initial_target() or has_reached_player() or is_chasing_time_out())):
		yield(get_tree(), "physics_frame")

	yield(get_tree(), "physics_frame")

func is_player_inside_aggro_range():
	return is_vector_in_correct_distance(global_position, player.global_position, aggro_distance_allowed)

func has_reached_player():
	return global_position.distance_to(player.global_position) <= distance_difference_allowed.x

func has_reached_initial_target():
	var distance = global_position.distance_to(initial_target)
	return distance <= 5.0

func is_vector_in_correct_distance(pos1, pos2, v_distance):
	return (abs(abs(pos1.x) - abs(pos2.x)) <= v_distance.x and (abs(abs(pos1.y) - abs(pos2.y)) <= v_distance.y))

func is_chasing_time_out():
	return chasing_time > chasing_max_time

func attack_player():
	var did_reach_player = has_reached_player()
	linear_vel = Vector2.ZERO
	target_position = Vector2.ZERO
	if is_dead():
		reset_attack_player_sequence()
		return yield(get_tree(), "physics_frame")

	if did_reach_player:
		aniplayer.stop(true)
		aniplayer.play("attack")
		return yield(aniplayer, "animation_finished")
	yield(get_tree(), "physics_frame")

func go_back_to_start_sequence():
	print("going back to start")
	is_going_back = true
	linear_vel = Vector2.ZERO
	aniplayer.play("go_back_to_start")
	yield(aniplayer, "animation_finished")
	position = Vector2.ZERO
	linear_vel = Vector2.ZERO
	exited_area = false
	is_going_back = false

func is_out_of_area():
	return exited_area

func _on_exit_chase_area(body):
	if body == self:
		exited_area = true

func _on_enter_chase_area(body):
	if body == self:
		exited_area = false

# animation callbacks
func check_attacking_collission():
	print("checking collission with player")
	print(global_position)
	print(player.global_position)
	if is_vector_in_correct_distance(global_position, player.global_position, distance_attack_allowed):
		print("player took damage")
		player.hit_damage()

func process_damage_from_player():
	print("processing damage from player...")
	current_life -= 1

func _on_player_death():
	self.modulate = Color(1.0, 1.0, 1.0, 1.0)
	show()
	set_process(true)
	set_physics_process(true)
	collision_shape.disabled = false
	current_life = max_life
