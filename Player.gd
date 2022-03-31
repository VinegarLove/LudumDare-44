extends KinematicBody2D

export var MOVE_SPEED = 150
export var JUMP_FORCE = 350
export var GRAVITY_VEC = Vector2(0.0, 900)
export var FLOOR_NORMAL = Vector2(0.0, -1)
export var MAX_FALL_SPEED = 200
export var MIN_ONAIR_TIME = 0.1
export var SMOOTHING_SPEED_HORIZONTAL = 0.2
export (NodePath) var respawnPointPath
onready var respawnPoint = get_node(respawnPointPath)

export (NodePath) var music0path
onready var music0 = get_node(music0path)
export (NodePath) var music1path
onready var music1 = get_node(music1path)
export (NodePath) var music2path
onready var music2 = get_node(music2path)
export (NodePath) var music3path
onready var music3 = get_node(music3path)

onready var anim_player = $AnimationPlayer
onready var sprite = $Sprite

onready var jump_sounds = get_tree().get_nodes_in_group("jumpsound")

var facing_right = false
var linear_vel = Vector2()
var onair_time = 0
var on_floor = false
var next_teleport_position = Vector2()
var key_picked_up

# shop stuff
export var has_lance = false
export var has_doublejump = false
var current_item_selected = ""

# player life stuff
export var max_life = 5
export var current_life = 3
onready var starting_life = current_life
export var double_jump_modifier = 0.75
export var limit_doublejump = 75.0
export var cooldown_move_time = 0.25
var can_doublejump = false
var is_dead = false
var cannot_move_time = 0.0

# attacking stuff
onready var attacking_distance = 25.0
var is_attacking = false

signal died

func _ready():
	attacking_distance *= attacking_distance
	print("ready: ", name)

func _physics_process(delta):
	# gravity
	onair_time += delta
	cannot_move_time += delta

	if $Particles2D.amount != max(0, current_life):
		$Particles2D.amount = max(0, current_life)

	onair_time = min(onair_time, 1000.0)
	cannot_move_time = min(cannot_move_time, 1000.0)

	linear_vel += delta * GRAVITY_VEC
	# move
	linear_vel = move_and_slide(linear_vel, FLOOR_NORMAL)

	# jump
	if is_on_floor():
		onair_time = 0
		can_doublejump = true

	on_floor = onair_time < MIN_ONAIR_TIME
	if !is_dead and (on_floor or (has_doublejump and can_doublejump and linear_vel.y >= limit_doublejump)) and Input.is_action_just_pressed("jump"):
		# ho saltato con il double jump, lo disattivo
		var s = randi() % (jump_sounds.size() - 1)
		jump_sounds[s].play()

		if not on_floor:
			can_doublejump = false
			linear_vel.y = -JUMP_FORCE * double_jump_modifier
		else:
			linear_vel.y = -JUMP_FORCE

	# fix sliding infinite while standing still
	if on_floor and linear_vel.y >= 0:
		linear_vel.y = 5

	# slow down the fall
	if linear_vel.y > (MAX_FALL_SPEED):
		linear_vel.y = MAX_FALL_SPEED

	# cannot move in this case
	if is_dead or cannot_move_time < cooldown_move_time:
		return

	# controls
	var move_dir = 0
	if Input.is_action_pressed("move_right"):
		move_dir = 1
	if Input.is_action_pressed("move_left"):
		move_dir = -1
	var speed = move_dir * MOVE_SPEED
	linear_vel.x = lerp(linear_vel.x, speed, SMOOTHING_SPEED_HORIZONTAL)

	# animations
	if facing_right and move_dir < 0:
		flip()
	if !facing_right and move_dir > 0:
		flip()

	if !is_attacking and has_lance and Input.is_action_just_pressed("attack"):
		player_attack_sequence()

	if !is_attacking:
		if on_floor:
			if move_dir == 0:
				play_anim("idle")
			else:
				play_anim("walk")
		else:
			play_anim("jump")

	if Input.is_action_just_released("interact"):
		interact_with_portal()
		interact_with_shop()

func _process(delta):
	if !is_dead and current_life <= 0:
		death_player_sequence()

func player_attack_sequence():
	is_attacking = true
	anim_player.play("attack")
	yield(anim_player, "animation_finished")
	print("attack_finished")
	is_attacking = false

func flip():
	facing_right = !facing_right
	sprite.flip_h = !sprite.flip_h

func play_anim(anim_name):
	if anim_player.is_playing() and anim_player.current_animation == anim_name:
		return
	anim_player.play(anim_name)

func interact_with_portal():
	if next_teleport_position:
		position = next_teleport_position
		$PortalPlayer.play()


func interact_with_shop():
	if current_item_selected:
		buy_item()

func set_teleport_position(destination):
	next_teleport_position = destination

func reset_teleport_position():
	next_teleport_position = null

func death_player_sequence():
	is_dead = true
	linear_vel = Vector2.ZERO
	anim_player.stop(true)
	anim_player.play("death")
	yield(anim_player, "animation_finished")
	emit_signal("died")

# quando muore e' lanciato il segnale a questa funzione
func _on_death():
	current_life = starting_life
	is_dead = false
	reset_player_inventory()
	refresh_player_inventory_graphics()
	reset_music()
	is_attacking = false
	can_doublejump = false
	position = respawnPoint.position
	modulate = Color(1.0, 1.0, 1.0, 1.0)

# shop stuff
func set_current_selected_item(item):
	current_item_selected = item

func reset_current_selected_item():
	current_item_selected = null

func buy_item():
	play_next_music()
	current_life -= current_item_selected.cost
	current_item_selected.was_bought()
	if current_item_selected.item_name == "lance":
		has_lance = true
	elif current_item_selected.item_name == "doublejump":
		has_doublejump = true
	refresh_player_inventory_graphics()

func reset_player_inventory():
	has_lance = false
	has_doublejump = false

func refresh_player_inventory_graphics():
	pass

func check_collision_with_enemies():
	print("player checking collision with enemies")
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.is_dead() or e.is_dying:
			continue

		var dis_squared = global_position.distance_squared_to(e.global_position)
		if global_position.distance_squared_to(e.global_position) <= attacking_distance:
			print(e.global_position)
			print(global_position)
			print("distance squared")
			print(dis_squared)
			e.process_damage_from_player()
			current_life += 2
			return

# callback from damage
func hit_damage():
	current_life -= 1
	play_anim("hit_damage")
	cannot_move_time = 0.0


func play_next_music():
	if music1.volume_db != 0.0:
		music0.volume_db = -80.0
		music1.volume_db = 0.0
	#elif music2.volume_db != 0.0:
	#	music1.volume_db = -80.0
	#	music2.volume_db = 0.0
	elif music3.volume_db != 0.0:
		music0.volume_db = -80.0
		music1.volume_db = -80.0
		music2.volume_db = -80.0
		music3.volume_db = 0.0

func reset_music():
	music0.volume_db = 0.0
	music1.volume_db = -80.0
	music2.volume_db = -80.0
	music3.volume_db = -80.0

func has_key():
	return key_picked_up

func set_key_picked():
	key_picked_up = true