extends CharacterBody2D

# Movement constants
const SPEED = 200.0
const JUMP_VELOCITY = -200.0
const DASH_SPEED = 400.0
const DASH_DURATION = 0.2

# State variables
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var is_using_skill = false
var is_dead = false
var dash_timer = 0.0
var dash_direction = 1

# Coyote time for better jump feel
var coyote_time = 0.1
var coyote_timer = 0.0

# References
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Kết nối signal khi animation kết thúc
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	# Nếu đang chết thì không làm gì
	if is_dead:
		return
	
	# Xử lý dash timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	
	# Apply gravity (trừ khi đang dash hoặc fly)
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta
	
	# Coyote time - cho phép nhảy ngay sau khi rời platform
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	
	# Không xử lý input khi đang attack hoặc skill
	if is_attacking or is_using_skill:
		move_and_slide()
		return
	
	# === INPUT HANDLING ===
	
	# Attack (Press J)
	if Input.is_key_pressed(KEY_J):
		attack()
		return
	
	# Skill (Press K)
	if Input.is_key_pressed(KEY_K):
		use_skill()
		return
	
	# Dash (Press Shift + Direction)
	if Input.is_key_pressed(KEY_SHIFT):
		var direction_axis = Input.get_axis("ui_left", "ui_right")
		if direction_axis != 0 and not is_dashing:
			start_dash(direction_axis)
			return
	
	# Jump (Press W or Space)
	if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE)) and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		animated_sprite.play("fly")
	
	# Get horizontal input (A and D keys)
	var direction := 0
	if Input.is_key_pressed(KEY_A):
		direction = -1
	elif Input.is_key_pressed(KEY_D):
		direction = 1
	
	# Handle horizontal movement
	if is_dashing:
		velocity.x = dash_direction * DASH_SPEED
	elif direction != 0:
		velocity.x = direction * SPEED
		# Flip sprite
		animated_sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	# Apply movement
	move_and_slide()
	
	# Update animation
	update_animation(direction)

func update_animation(direction):
	# Đang dash
	if is_dashing:
		animated_sprite.play("dash")
		return
	
	# Đang bay/nhảy (không chạm đất)
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("fly")
		else:
			animated_sprite.play("stop_flying")
		return
	
	# Đang di chuyển trên mặt đất
	if direction != 0:
		if animated_sprite.animation != "run" and animated_sprite.animation != "stop_running":
			animated_sprite.play("run")
	else:
		# Đứng yên
		if animated_sprite.animation == "run":
			animated_sprite.play("stop_running")
		elif animated_sprite.animation != "stop_running":
			animated_sprite.play("idle")

func attack():
	if is_attacking or is_using_skill or is_dashing:
		return
	
	is_attacking = true
	velocity.x = 0  # Dừng di chuyển khi attack
	animated_sprite.play("attack")

func use_skill():
	if is_attacking or is_using_skill or is_dashing:
		return
	
	is_using_skill = true
	velocity.x = 0  # Dừng di chuyển khi dùng skill
	animated_sprite.play("skill")

func start_dash(direction):
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_direction = direction
	velocity.y = 0  # Reset vertical velocity
	
	# Flip sprite theo hướng dash
	animated_sprite.flip_h = direction < 0
	animated_sprite.play("dash")

func die():
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	animated_sprite.play("death")
	set_physics_process(false)

# ===== Helper: xác định hướng đang giữ phím =====
func _current_dir() -> int:
	var d := 0
	if Input.is_key_pressed(KEY_A):
		d = -1
	elif Input.is_key_pressed(KEY_D):
		d = 1
	return d

# Callback khi animation kết thúc
func _on_animation_finished():
	var anim_name = animated_sprite.animation
	
	match anim_name:
		"attack":
			is_attacking = false
			# Sau attack: nếu đang giữ hướng hoặc còn trôi -> run, ngược lại idle
			var dir := _current_dir()
			if dir != 0 or abs(velocity.x) > 5:
				animated_sprite.play("run")
			else:
				animated_sprite.play("idle")
		
		"skill":
			is_using_skill = false
			animated_sprite.play("stop_skill")
		
		"stop_skill":
			animated_sprite.play("idle")
		
		"stop_running":
			# yêu cầu: luôn về idle sau stop_running
			animated_sprite.play("idle")
		
		"stop_flying":
			if is_on_floor():
				animated_sprite.play("idle")
		
		"death":
			pass
