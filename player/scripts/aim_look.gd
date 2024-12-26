extends CharacterBody3D


## Resolution and FPS independent camera controller made by YoSoyFreeman.

## Head node.
@export var head : Node3D

@export_category("Settings")
@export_group("Camera")

## Max camera pitch in degrees.
@export_range(-90, 90, 0.1, "degrees") var max_pitch: float = 90

## Min camera pitch in degrees.
@export_range(-90, 90, 0.1, "degrees") var min_pitch: float = -90

@export_subgroup("Mouse", "mouse_")

## How many degrees the camera rotates by each unit reported by the mouse.
## This should be an small value and depends on your intended exposed [member sensitivity]. [br][br]
## The default value is meant to work with a sensitivity of [b]5[/b], in a range of [b]0 - 10[/b].
@export_range(0.01, 0.01, 0.01, "hide_slider", "or_greater", "degrees") var mouse_degrees_per_unit: float = 0.01

## The sensitivity the user is meant to adjust.[br] [br]If [member mouse_degrees_per_unit] is [b]0.5[/b]
## and this value is set to [b]2[/b] the final result will be [b]1[/b] degree of rotation by each unit.
@export_range(0.1, 10, 0.05, "or_greater") var mouse_sensitivity: float = 5

@export_subgroup("joystick", "joystick_")

## How many degrees per second the camera will rotate when the Joystick is fully tilted. [br][br]
## The default value is meant to work with a sensitivity of [b]5[/b], in a range of [b]0 - 10[/b].
@export_range(0.001, 10, 0.001, "hide_slider", "or_greater", "degrees") var joystick_degrees_per_second: float = 36

## Exponent to which the joystick input will be raised to.[br][br]
## Smaller values are more reactive, while bigger ones allow for finer movement when the tilting is subtle.
@export_exp_easing("positive_only") var joystick_exp: float = 2

## The sensitivity the user is meant to adjust. [br][br] If [member joystick_degrees_per_second] is [b]180[/b]
## and this value is set to [b]2[/b] the final result will be [b]360[/b] degrees of rotation per second.
@export_range(0.1, 10, 0.01, "or_greater") var joystick_sensitivity: float = 5

@export_group("Movement")

## The jump speed along the [member up_direction].
@export var jump_speed: float = 5
@export_subgroup("Acceleration")

## Ground acceleration.
@export var ground_acceleration: float = 250

## Air acceleration.
@export var air_acceleration: float = 0
@export_subgroup("Friction")

## Determines if the velocity along the [member up_direction] will be taken
## into account while calculating friction.
@export var apply_vertical_friction: bool = false

## Decay factor for friction.
@export_range(0, 50) var ground_friction: float = 25

## Decay factor for air friction.
@export_range(0, 50) var air_friction: float = 0



func _ready():
	Input.set_use_accumulated_input(false)


func _unhandled_input(event)->void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventKey:
			if event.is_action_pressed("ui_cancel"):
				get_tree().quit()

		if event is InputEventMouseButton:
			if event.button_index == 1:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		return

	if event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		return

	if event is InputEventMouseMotion:
		mouse_look(event)


func _physics_process(delta: float) -> void:
	joystick_look(delta)
	handle_gravity(delta)
	handle_jump()
	handle_acceleration(delta)
	handle_friction(delta)
	move_and_slide()


func joystick_look(delta) -> void:

	## ATTENTION: Add the following inputs to your project or replace the following line with your own ones.
	var motion: Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up")

	if joystick_exp != 1:
		motion = motion.normalized() * pow(motion.length(), joystick_exp)

	motion *= joystick_degrees_per_second
	motion *= joystick_sensitivity
	motion *= delta

	add_yaw(motion.x)
	add_pitch(-motion.y)
	clamp_pitch()


## Handles aim look with the mouse.
func mouse_look(event: InputEventMouseMotion)-> void:
	var motion: Vector2 = event.screen_relative

	motion *= mouse_degrees_per_unit
	motion *= mouse_sensitivity

	add_yaw(motion.x)
	add_pitch(motion.y)
	clamp_pitch()


## Rotates the character around the local Y axis by a given amount (In degrees) to achieve yaw.
func add_yaw(amount)->void:
	if is_zero_approx(amount):
		return

	rotate_object_local(Vector3.DOWN, deg_to_rad(amount))
	orthonormalize()


## Rotates the head around the local x axis by a given amount (In degrees) to achieve pitch.
func add_pitch(amount)->void:
	if is_zero_approx(amount):
		return

	head.rotate_object_local(Vector3.LEFT, deg_to_rad(amount))
	head.orthonormalize()


## Clamps the pitch between min_pitch and max_pitch.
func clamp_pitch()->void:
	if head.rotation.x > deg_to_rad(min_pitch) and head.rotation.x < deg_to_rad(max_pitch):
		return

	head.rotation.x = clamp(head.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	head.orthonormalize()


## Accelerates the character using linear acceleration.
func handle_acceleration(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_backwards", "move_forward")
	var input_direction: Vector3 = transform.basis.orthonormalized() * Vector3(input_vector.x, 0, -input_vector.y)
	var accel: float = ground_acceleration if is_on_floor() else air_acceleration
	
	velocity += input_direction * accel  * delta


## Applies gravity to the body.
func handle_gravity(delta: float):
	if is_on_floor():
		return
	
	velocity += get_gravity() * delta


## Handles jump.
func handle_jump():
	if !is_on_floor():
		return
	
	if !Input.is_action_just_pressed("ui_accept"):
		return
	
	velocity += up_direction * jump_speed - velocity.project(up_direction)


## Aplies friction to the body using fps independent exponential decay.
func handle_friction(delta: float):
	var friction: float = ground_friction if is_on_floor() else air_friction
	
	if friction == 0:
		return
	
	if apply_vertical_friction:
		velocity = velocity * exp(-friction * delta)
		return
	
	var vertical_velocity: Vector3 = velocity.project(up_direction)
	var horizontal_velocity: Vector3 = velocity - vertical_velocity
	
	horizontal_velocity = horizontal_velocity * exp(-friction * delta)
	velocity = horizontal_velocity + vertical_velocity
	
	# Freya Holmer's exponential decay formula:
	# b + (a - b) * exp(-decay * delta)
	# For friction we always decay towards zero, so we can simplify to:
	# (a) * exp(-decay * delta)
	# Use the original formula in order to decay towards non zero velocities (for custom moving platforms, for example)
