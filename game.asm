#####################################################################
#
# CSC258 Summer 2021 Assembly Final Project
# University of Toronto
#
# Student: Nealon Soltanpour, 1005456757, soltanp3
# Student: Adam Tran, 1006172525, tranadam
#
# Bitmap Display Configuration:
# -Unit width in pixels: 8 
# -Unit height in pixels: 8 
# -Display width in pixels: 256 
# -Display height in pixels: 256
# -Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# -Milestone 3
#
# Which approved features have been implemented for milestone 3?
# 1. Scoring
# 2. Difficulty
# 3. Shooting lasers to destroy objects
# 4. Pickups
#
# Link to video demonstration for final submission:
# -https://www.youtube.com/watch?v=795IPmiPRQs
#
# Are you OK with us sharing the video with people outside course staff?
# -yes
#
#####################################################################

.eqv BASE_ADDRESS 0x10008000
.eqv LIGHT_GREY 0xd3d3d3
.eqv BLACK 0x000000
.eqv BROWN 0x563d2d
.eqv RED 0xff0000
.eqv GREEN 0x00ff00
.eqv PINK 0xff10f0
.eqv PURPLE 0x6a0dad


.data
	ship_location: .word 10, 10 	# x and y position of the back pixel of the ship
	enemy1_location: .word 0, 31	# temporary x and y position of enemy1
	enemy2_location: .word 0, 31 	# temporary x and y position of enemy2
	enemy3_location: .word 0, 31	# temporary x and y position of enemy 3
	laser_location: .word 0, 0		# temporary x and y position of the laser
	laser_active: .word 0			# 0 if inactive and 1 if active
	count_object: .word 0			# to change how fast the object is updated
	count_laser: .word 0			# to change how fast the laser is updated
	health: .word 4					# decremented by 1 each time player takes damage
	gametime: .word 0
	score: .word 0					# incremented every second player is alive
	difficulty: .word 0				# amount to reduce object_update_rate. Increased every 10 seconds
	pickup_location: .word 0, 31    # temporary x and y position of pickup
	laser_update_rate: .word 200	# updated every 200 loops of main. Note that a lower number is a faster fire rate
	object_update_rate: .word 250	# same as laser_update_rate but for the objects


.text
	jal fill_black
	# load display
	li $t0, BASE_ADDRESS
	
	
	main:
	# Get initial time
	li $v0, 30
	syscall
	move $t1, $a0
	
	# check for key pressed
	li $t9, 0xffff0000
	lw $t8, 0($t9)
	beq $t8, 1, keypress_happened
	la $a0, LIGHT_GREY		# set color of ship
	jal draw_ship
	
	jal draw_health_bar
	

	lw $t4, count_object	# $t4 = count_object
	addi $t4, $t4, 1		# $t4 = $t4 + 1
	sw $t4, count_object	# store updated value of count_object
	
	lw $t5, count_laser		# $t5 = count_laser
	addi $t5, $t5, 1		# $t5 = $t5 + 1
	sw $t5, count_laser		# store updated value of count_laser
	
	lw $t5, object_update_rate
	lw $t3, difficulty
	sub $t5, $t5, $t3				# $t5 = object_update_rate - difficulty
	bne $t4, $t5, check_laser		# check if count_object != object_update_rate - difficulty
	
	
	sw $zero, count_object	# reset count_object to 0
	la $a0, BROWN			# set color of enemy

	jal check_collision
	jal update_enemy1	# update enemy every object_update_rate - difficulty loops of main
	jal update_enemy2
	jal update_enemy3
	jal update_pickup
	
	check_laser:
	lw $t5, count_laser
	lw $t4, laser_update_rate
	bne $t5, $t4, loop			# laser fire rate
	sw $zero, count_laser		# reset count_laser to 0
	# update laser every 200 loops of main
	lw $t5, laser_active
	beqz $t5, loop		# loop main if laser_inactive, else update laser
	jal update_laser
	jal check_collision
	
	loop:
	# Get final time
	li $v0, 30
	syscall
	sub $t1, $a0, $t1	# final time - initial time
	
	lw $t4, gametime
	add $t4, $t4, $t1	# gametime += looptime
	sw $t4, gametime	# store the new gametime
	blt $t4, 1000, main	# if gametime is less than 1 second loop main, otherwise increase score
	
	lw $t5, score
	addi $t5, $t5, 1	# increase score by 1
	sw $t5, score
	
	sub $t4, $t4, 1000	# gametime -= 1000
	sw $t4, gametime	# store new value of gametime
	
	
	# increase difficulty every 10 seconds
	# if score % 10 == 0, then increase difficulty
	lw $t4, score
	li $t3, 10
	div $t4, $t3
	mfhi $t3				# $t3 = score % 10
	bnez $t3, main			# if score % 10 != 0, then goto main
	# Reduce object_update_rate by 30 to make objects faster
	lw $t4, object_update_rate
	ble, $t4, 50, main				# if object_update_rate <= 50, then goto main
	lw $t4, difficulty				# $t4 = difficulty
	addi $t4, $t4, 30				# difficulty += 30
	sw $t4, difficulty				# store new value of difficulty
	sw $zero, count_object			# reset count_object to 0
	
	j main
	
	
	check_collision:
	# check each pixel of the objects to see if the ship hit it.
	
	# Check collision for object 1
	la $t4, enemy1_location	# $t4 = enemy1_location
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x

	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	
	# Check if object 1 collided with the ship

	la $a0, LIGHT_GREY
	
	lw $t4, 0($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -12($t5)
	beq $a0, $t4, object1_collision
	lw $t4, 124($t5)
	beq $a0, $t4, object1_collision
	lw $t4, 120($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -140($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -128($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -264($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -260($t5)
	beq $a0, $t4, object1_collision
	
	# Check if object 1 collided with the laser
	la $a0, PINK
	lw $t4, 0($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -12($t5)
	beq $a0, $t4, object1_collision
	lw $t4, 124($t5)
	beq $a0, $t4, object1_collision
	lw $t4, 120($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -140($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -128($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -264($t5)
	beq $a0, $t4, object1_collision
	lw $t4, -260($t5)
	beq $a0, $t4, object1_collision
	
	# Check collision for object 2
	la $t4, enemy2_location	# $t4 = enemy2_location
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x

	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	# Check if object 2 collided with the ship
	la $a0, LIGHT_GREY
	
	lw $t4, 0($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -12($t5)
	beq $a0, $t4, object2_collision
	lw $t4, 124($t5)
	beq $a0, $t4, object2_collision
	lw $t4, 120($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -140($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -128($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -264($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -260($t5)
	beq $a0, $t4, object2_collision
	
	# Check if object 2 collided with the laser
	la $a0, PINK
	
	lw $t4, 0($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -12($t5)
	beq $a0, $t4, object2_collision
	lw $t4, 124($t5)
	beq $a0, $t4, object2_collision
	lw $t4, 120($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -140($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -128($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -264($t5)
	beq $a0, $t4, object2_collision
	lw $t4, -260($t5)
	beq $a0, $t4, object2_collision
	
	# Check collision for object 3
	la $t4, enemy3_location	# $t4 = enemy3_location
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x

	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	# Check if object 3 collided with the ship
	la $a0, LIGHT_GREY
	
	lw $t4, 0($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -12($t5)
	beq $a0, $t4, object3_collision
	lw $t4, 124($t5)
	beq $a0, $t4, object3_collision
	lw $t4, 120($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -140($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -128($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -264($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -260($t5)
	beq $a0, $t4, object3_collision
	
	# Check if object 3 collided with the laser
	la $a0, PINK
	
	lw $t4, 0($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -12($t5)
	beq $a0, $t4, object3_collision
	lw $t4, 124($t5)
	beq $a0, $t4, object3_collision
	lw $t4, 120($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -140($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -128($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -264($t5)
	beq $a0, $t4, object3_collision
	lw $t4, -260($t5)
	beq $a0, $t4, object3_collision
	
	
	# Check collision for pickup
	la $t4, pickup_location	# $t4 = pickup_location
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x

	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	
	# Check if the pickup collided with the ship

	la $a0, LIGHT_GREY
	
	lw $t4, 0($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, -12($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, 124($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, 120($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, -140($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, -128($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, -264($t5)
	beq $a0, $t4, pickup_collision
	lw $t4, -260($t5)
	beq $a0, $t4, pickup_collision
	
	jr $ra

	
	object1_collision:
	move $t3, $a0			# store the color that it collided with in $t3
	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	# First reset object by painting it black
	la $a0, BLACK
	jal draw_enemy1
	la $t4, enemy1_location
	li $t5, 31
	sw $t5, 0($t4)			# set x to 31
	# get random number in range 0 - 31 for y
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# set y to a random integer in range 0-31
	

	
	
	la $t5, PINK
	beq $t3, $t5, object1_hit_laser
	# paint ship RED because it took damage
	la $a0, RED
	jal draw_ship
	li $v0, 32
	li $a0, 300		# sleep 0.3 seconds
	syscall
	# reduce health by 1
	lw $t4, health
	addi $t4, $t4, -1
	sw $t4, health
	
	object1_hit_laser:
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	
	jr $ra					# return


	object2_collision:
	move $t3, $a0			# store the color that it collided with in $t3
	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	# First reset object by painting it black
	la $a0, BLACK
	jal draw_enemy2
	la $t4, enemy2_location
	li $t5, 31
	sw $t5, 0($t4)			# set x to 31
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# reset y to a random integer in range 0-31
	
	la $t5, PINK
	beq $t3, $t5, object2_hit_laser
	# paint ship RED because it took damage
	la $a0, RED
	jal draw_ship
	li $v0, 32
	li $a0, 300		# sleep 0.3 seconds
	syscall
	# reduce health by 1
	lw $t4, health
	addi $t4, $t4, -1
	sw $t4, health
	
	object2_hit_laser:
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	
	jr $ra					# return
	
	object3_collision:
	move $t3, $a0			# store the color that it collided with in $t3
	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	# First reset object by painting it black
	la $a0, BLACK
	jal draw_enemy3
	la $t4, enemy3_location
	li $t5, 31
	sw $t5, 0($t4)			# set x to 31
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# reset y to a random integer in range 0-31
	
	la $t5, PINK
	beq $t3, $t5, object3_hit_laser
	# paint ship RED because it took damage
	la $a0, RED
	jal draw_ship
	li $v0, 32
	li $a0, 300		# sleep 0.3 seconds
	syscall
	# reduce health by 1
	lw $t4, health
	addi $t4, $t4, -1
	sw $t4, health
	
	object3_hit_laser:
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	
	jr $ra					# return
	
	pickup_collision:
	move $t3, $a0			# store the color that it collided with in $t3
	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	# First reset object by painting it black
	la $a0, BLACK
	jal draw_pickup
	la $t4, pickup_location
	sw $zero, 0($t4)		# set x to 0
	
	# restore health completely
	
	li $t4, 4
	sw $t4, health

	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	
	jr $ra					# return
	
	draw_health_bar:
	li $t6, 8		# x location for the start of the health bar
	li $t5, 31		# y location for the start of the health bar
	
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t6, RED
	la $t7, GREEN
	
	# check how much health is left
	lw $t4, health
	beq $t4, 3, health3
	beq $t4, 2, health2
	beq $t4, 1, health1
	beq $t4, 0, game_over
	
	sw $t7, 0($t5)
	sw $t7, 4($t5)
	sw $t7, 8($t5)
	sw $t7, 12($t5)
	sw $t7, 16($t5)
	sw $t7, 20($t5)
	sw $t7, 24($t5)
	sw $t7, 28($t5)
	sw $t7, 32($t5)
	sw $t7, 36($t5)
	sw $t7, 40($t5)
	sw $t7, 44($t5)
	sw $t7, 48($t5)
	sw $t7, 52($t5)
	sw $t7, 56($t5)
	
	jr $ra
	
	health3:
	sw $t7, 0($t5)
	sw $t7, 4($t5)
	sw $t7, 8($t5)
	sw $t7, 12($t5)
	sw $t7, 16($t5)
	sw $t7, 20($t5)
	sw $t7, 24($t5)
	sw $t7, 28($t5)
	sw $t7, 32($t5)
	sw $t7, 36($t5)
	sw $t7, 40($t5)
	sw $t6, 44($t5)
	sw $t6, 48($t5)
	sw $t6, 52($t5)
	sw $t6, 56($t5)
	
	jr $ra
	
	health2:
	sw $t7, 0($t5)
	sw $t7, 4($t5)
	sw $t7, 8($t5)
	sw $t7, 12($t5)
	sw $t7, 16($t5)
	sw $t7, 20($t5)
	sw $t7, 24($t5)
	sw $t6, 28($t5)
	sw $t6, 32($t5)
	sw $t6, 36($t5)
	sw $t6, 40($t5)
	sw $t6, 44($t5)
	sw $t6, 48($t5)
	sw $t6, 52($t5)
	sw $t6, 56($t5)
	
	jr $ra
	
	health1:
	sw $t7, 0($t5)
	sw $t7, 4($t5)
	sw $t7, 8($t5)
	sw $t6, 12($t5)
	sw $t6, 16($t5)
	sw $t6, 20($t5)
	sw $t6, 24($t5)
	sw $t6, 28($t5)
	sw $t6, 32($t5)
	sw $t6, 36($t5)
	sw $t6, 40($t5)
	sw $t6, 44($t5)
	sw $t6, 48($t5)
	sw $t6, 52($t5)
	sw $t6, 56($t5)
	
	jr $ra
	
	
	draw_ship:
	# set pointer to x,y position of back pixel of ship
	la $t4, ship_location	# $t4 = ship_location
	lw $t5, 4($t4)			# $t5 = y
	sll $t5, $t5, 5			# $t5 = y * 32
	lw $t6, 0($t4)			# $t6 = x
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	# draw ship (relative to back pixel)
	sw $a0, 0($t5)
	sw $a0, 4($t5)
	sw $a0, 8($t5)
	sw $a0, 12($t5)
	sw $a0, 16($t5)
	sw $a0, 20($t5)
	sw $a0, 32($t5)
	sw $a0, 36($t5)
	sw $a0, -124($t5)
	sw $a0, -120($t5)
	sw $a0, -116($t5)
	sw $a0, -112($t5)
	sw $a0, -108($t5)
	sw $a0, -104($t5)
	sw $a0, -100($t5)
	sw $a0, -96($t5)
	sw $a0, -248($t5)
	sw $a0, -244($t5)
	sw $a0, -380($t5)
	sw $a0, -376($t5)
	sw $a0, -372($t5)
	sw $a0, -368($t5)
	sw $a0, 132($t5)
	sw $a0, 136($t5)
	sw $a0, 140($t5)
	sw $a0, 144($t5)
	sw $a0, 148($t5)
	sw $a0, 152($t5)
	sw $a0, 156($t5)
	sw $a0, 160($t5)
	sw $a0, 264($t5)
	sw $a0, 268($t5)
	sw $a0, 400($t5)
	sw $a0, 396($t5)
	sw $a0, 392($t5)
	sw $a0, 388($t5)
	
	
	jr $ra


	
	keypress_happened:
	lw $t7, 4($t9)
	beq $t7, 0x61, respond_to_a		# ascii value of 'a' is 0x61
	beq $t7, 0x64, respond_to_d		# ascii value of 'd' is 0x64
	beq $t7, 0x73, respond_to_s		# ascii value of 's' is 0x73
	beq $t7, 0x77, respond_to_w		# ascii value of 'w' is 0x77
	beq $t7, 0x70, respond_to_p		# ascii value of 'p' is 0x70
	beq $t7, 0x20, respond_to_space # ascii value of ' ' is 0x20
	j main
	
	respond_to_a:
	# First check if location is valid
	la $t4, ship_location	# $t4 = ship_location
	lw $t6, 0($t4)			# $t6 = x
	beqz $t6, main			# if x == 0, then goto main (can't move left)
	
	# Erase ship by painting it black
	la $a0, BLACK
	jal draw_ship	# paint ship black
	# draw ship at new location
	addi $t6, $t6, -1		# $t6 = x - 1
	sw $t6, 0($t4)			# store new x value
	la $a0, LIGHT_GREY		# set color of ship
	jal draw_ship
	j main
	
	respond_to_d:
	# First check if location is valid
	la $t4, ship_location	# $t4 = ship_location
	lw $t6, 0($t4)			# $t6 = x
	addi $t6, $t6, 9		# $t6 = x + 9
	beq $t6, 31, main		# if x + 9 == 31, then goto main (can't move right)
	
	# Erase ship by painting it black
	la $a0, BLACK
	jal draw_ship
	# draw ship at new location
	lw $t6, 0($t4)			# $t6 = x
	addi $t6, $t6, 1		# $t6 = x + 1
	sw $t6, 0($t4)			# store new x value
	la $a0, LIGHT_GREY		# set color of ship
	jal draw_ship
	j main
	
	respond_to_s:
	# First check if location is valid
	la $t4, ship_location	# $t4 = ship_location
	lw $t6, 4($t4)			# $t6 = y
	addi $t6, $t6, 3		# $t6 = y + 3
	beq $t6, 31, main		# if y + 3 == 31, then goto main
	
	# Erase ship by painting it black
	la $a0, BLACK
	jal draw_ship
	# draw ship at new location
	lw $t6, 4($t4)			# $t6 = y
	addi $t6, $t6, 1		# $t6 = y + 1
	sw $t6, 4($t4)			# store new y value
	la $a0, LIGHT_GREY		# set color of ship
	jal draw_ship
	j main
	
	respond_to_w:
	# First check if location is valid
	la $t4, ship_location	# $t4 = ship_location
	lw $t6, 4($t4)			# $t6 = y
	addi $t6, $t6, -3		# $t6 = y - 3
	beqz $t6, main			# if y - 3 == 0, then goto main
	
	# Erase ship by painting it black
	la $a0, BLACK
	jal draw_ship
	# draw ship at new location
	lw $t6, 4($t4)			# $t6 = y
	addi $t6, $t6, -1		# $t6 = y - 1
	sw $t6, 4($t4)			# store new y value
	la $a0, LIGHT_GREY		# set color of ship
	jal draw_ship
	j main
	
	respond_to_space:
	lw $t4, laser_active
	beq $t4, 1, main		# if laser is already active, then goto main
	# set laser location
	la $t4, ship_location	# $t4 = ship_location
	lw $t5, 0($t4)			# $t5 = x
	addi $t5, $t5, 11		# $t5 = x + 11
	lw $t6, 4($t4)			# $t6 = y
	la $t7, laser_location
	sw $t5, 0($t7)			# set x location of laser
	sw $t6, 4($t7)			# set y location of laser
	
	
	lw $t4, laser_active
	addi $t4, $t4, 1
	sw $t4, laser_active
	j main
	
	respond_to_p:
	# Reset everything
	jal fill_black
	
	# Reset ship location to 10, 10
	li $t3, 10
	la $t4, ship_location
	sw $t3, 0($t4)
	sw $t3, 4($t4)
	
	# Reset enemy 1 location to 0, 31
	la $t4, enemy1_location 
	li $t3, 31
	sw $zero, 0($t4)
	sw $t3, 4($t4)
	
	# Reset enemy 2 location to 0, 31
	la $t4, enemy2_location 
	li $t3, 31
	sw $zero, 0($t4)
	sw $t3, 4($t4)
	
	# Reset enemy 3 location to 0, 31
	la $t4, enemy3_location
	li $t3, 31
	sw $zero, 0($t4)
	sw $t3, 4($t4)
	
	# Reset pickup location to 0, 31
	la $t4, pickup_location
	li $t3, 31
	sw $zero, 0($t4)
	sw $t3, 4($t4)
	
	# Reset laser location to 0, 0
	la $t4, laser_location
	sw $zero, 0($t4)
	sw $zero, 4($t4)
	
	# Deactivate laser
	sw $zero, laser_active
	
	# Reset count, gametime, score, difficulty to 0
	sw $zero, count_object
	sw $zero, count_laser
	sw $zero, gametime
	sw $zero, score
	sw $zero, difficulty
	
	# Reset health to 4
	li $t3, 4
	sw $t3, health
	
	j main
	
	
	draw_laser:
	la $t4, laser_location
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	# set colors
	sw $a0, 0($t5)
	sw $a0, 4($t5)
	sw $a0, 8($t5)
	sw $a0, 12($t5)
	
	jr $ra
	
	update_laser:
	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	
	
	# First erase laser by coloring black
	la $a0, BLACK
	jal draw_laser
	
	la $t4, laser_location
	# set x = x + 1 and redraw
	lw $t5, 0($t4)			# $t5 = x
	beq $t5, 28, deactivate_laser	# if x == 28, then deactivate laser
	
	addi $t5, $t5, 1		# $t5 = x + 1
	sw $t5, 0($t4)			# save the new x value
	la $a0, PINK
	jal draw_laser			# redraw

	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	jr $ra					# return
	
	deactivate_laser:
	sw $zero, laser_active	# set laser_active to 0
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	jr $ra					# return
	
	
	draw_enemy1:
	la $t7, ($a0)			# store color bc $a0 is used for random number
	la $t4, enemy1_location
	lw $t6, 0($t4)			# $t6 = x
	# if x == 0, then set random y val and reset x to 31
	bnez $t6, Else1
	# get random number in range 0 - 31 for y
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# store new y value
	lw $t5, 4($t4)			# $t5 = y
	li $t6, 31				# $t6 = 31
	sw $t6, 0($t4)			# set x to 31
	
	
	Else1:
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x
	# draw enemy1 at the x, y location
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	sw $t7, 0($t5)
	sw $t7, -4($t5)
	sw $t7, -8($t5)
	sw $t7, -12($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, -140($t5)
	sw $t7, -136($t5)
	sw $t7, -132($t5)
	sw $t7, -128($t5)
	sw $t7, -264($t5)
	sw $t7, -260($t5)
	
	jr $ra
	
	
	
	
	update_enemy1:

	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	
	la $t4, enemy1_location
	# First erase by drawing it black
	la $a0, BLACK
	jal draw_enemy1
	# set x = x - 1 and redraw
	lw $t6, 0($t4)			# $t6 = x
	beqz $t6, main			# if x == 0, then goto main
	addi $t6, $t6, -1		# $t6 = x - 1
	sw $t6, 0($t4)			# store the new x value
	la $a0, BROWN			# set color of enemy
	jal draw_enemy1			# draw enemy1 at new location
	
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	jr $ra					# return

	
	
	draw_enemy2:
	la $t7, ($a0)			# store color bc $a0 is used for random number
	la $t4, enemy2_location
	lw $t6, 0($t4)			# $t6 = x
	# if x == 0, then set random y val and reset x to 31
	bnez $t6, Else2
	# get random number in range 0 - 31 for y
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# store new y value
	lw $t5, 4($t4)			# $t5 = y
	li $t6, 31				# $t6 = 31
	sw $t6, 0($t4)			# set x to 31
	
	
	Else2:
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x
	# draw enemy2 at the x, y location
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	sw $t7, 0($t5)
	sw $t7, -4($t5)
	sw $t7, -8($t5)
	sw $t7, -12($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, -140($t5)
	sw $t7, -136($t5)
	sw $t7, -132($t5)
	sw $t7, -128($t5)
	sw $t7, -264($t5)
	sw $t7, -260($t5)
	
	jr $ra
	
	
	update_enemy2:

	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	
	la $t4, enemy2_location
	# First erase by drawing it black
	la $a0, BLACK
	jal draw_enemy2
	# set x = x - 1 and redraw
	lw $t6, 0($t4)			# $t6 = x
	beqz $t6, main			# if x == 0, then goto main
	addi $t6, $t6, -1		# $t6 = x - 1
	sw $t6, 0($t4)			# store the new x value
	la $a0, BROWN			# set color of enemy
	jal draw_enemy2			# draw enemy2 at new location
	
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	jr $ra					# return
	
	draw_enemy3:
	la $t7, ($a0)			# store color bc $a0 is used for random number
	la $t4, enemy3_location
	lw $t6, 0($t4)			# $t6 = x
	# if x == 0, then set random y val and reset x to 31
	bnez $t6, Else3
	# get random number in range 0 - 31 for y
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# store new y value
	lw $t5, 4($t4)			# $t5 = y
	li $t6, 31				# $t6 = 31
	sw $t6, 0($t4)			# set x to 31
	
	Else3:
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x
	# draw enemy2 at the x, y location
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	sw $t7, 0($t5)
	sw $t7, -4($t5)
	sw $t7, -8($t5)
	sw $t7, -12($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, -140($t5)
	sw $t7, -136($t5)
	sw $t7, -132($t5)
	sw $t7, -128($t5)
	sw $t7, -264($t5)
	sw $t7, -260($t5)
	
	jr $ra
	
	
	update_enemy3:

	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	
	la $t4, enemy3_location
	# First erase by drawing it black
	la $a0, BLACK
	jal draw_enemy3
	# set x = x - 1 and redraw
	lw $t6, 0($t4)			# $t6 = x
	beqz $t6, main			# if x == 0, then goto main
	addi $t6, $t6, -1		# $t6 = x - 1
	sw $t6, 0($t4)			# store the new x value
	la $a0, BROWN			# set color of enemy
	jal draw_enemy3			# draw enemy2 at new location
	
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	jr $ra					# return
	
	
	
	
	draw_pickup:
	la $t7, ($a0)			# store color bc $a0 is used for random number
	la $t4, pickup_location
	lw $t6, 0($t4)			# $t6 = x
	# if x == 0, then set random y val and reset x to 31
	bnez $t6, Else4
	# get random number in range 0 - 31 for y
	li $v0, 42				# service 42
	li $a0, 0
	li $a1, 32
	syscall
	sw $a0, 4($t4)			# store new y value
	lw $t5, 4($t4)			# $t5 = y
	li $t6, 31				# $t6 = 31
	sw $t6, 0($t4)			# set x to 31
	
	
	Else4:
	lw $t5, 4($t4)			# $t5 = y
	lw $t6, 0($t4)			# $t6 = x
	# draw pickup at the x, y location
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $t6		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	sw $t7, 0($t5)
	sw $t7, -4($t5)
	sw $t7, -8($t5)
	sw $t7, 124($t5)
	sw $t7, -132($t5)
	
	jr $ra
	
	
	update_pickup:

	addiu $sp, $sp, -4		# allocate 1 word on the stack
	sw $ra, 0($sp)			# save $ra from caller
	
	la $t4, pickup_location
	# First erase by drawing it black
	la $a0, BLACK
	jal draw_pickup
	# set x = x - 1 and redraw
	lw $t6, 0($t4)			# $t6 = x
	beqz $t6, main			# if x == 0, then goto main
	addi $t6, $t6, -1		# $t6 = x - 1
	sw $t6, 0($t4)			# store the new x value
	la $a0, PURPLE			# set color of pickup
	jal draw_pickup			# draw pickup at new location
	
	# return back to original main call
	lw $ra, 0($sp)			# restore $ra to return to caller
	addiu $sp, $sp, 4		# restore $sp
	jr $ra					# return
	

	fill_black:
	la $t4, BASE_ADDRESS
	la $t5, BLACK
	la $t6, BASE_ADDRESS
	addi $t6, $t6, 4092		# max address
	
	fill_black_loop:
	sw $t5, 0($t4)
	beq $t4, $t6, End		# Return when $t4 reaches max address
	addi $t4, $t4, 4		# $t4 += 4
	j fill_black_loop
	
	End:
	jr $ra
		
				
	
	game_over:

	jal fill_black		# paint the screen black
	
	# Draw Game over text
	# Draw G
	la $t4, BASE_ADDRESS
	la $t5, LIGHT_GREY
	sw $t5, 136($t4)
	sw $t5, 140($t4)
	sw $t5, 144($t4)
	sw $t5, 148($t4)
	sw $t5, 264($t4)
	sw $t5, 392($t4)
	sw $t5, 520($t4)
	sw $t5, 648($t4)
	sw $t5, 652($t4)
	sw $t5, 656($t4)
	sw $t5, 660($t4)
	sw $t5, 532($t4)
	sw $t5, 404($t4)
	sw $t5, 400($t4)
	
	# Draw a
	sw $t5, 160($t4)
	sw $t5, 164($t4)
	sw $t5, 168($t4)
	sw $t5, 172($t4)
	sw $t5, 288($t4)
	sw $t5, 416($t4)
	sw $t5, 544($t4)
	sw $t5, 672($t4)
	sw $t5, 676($t4)
	sw $t5, 680($t4)
	sw $t5, 684($t4)
	sw $t5, 300($t4)
	sw $t5, 428($t4)
	sw $t5, 556($t4)
	sw $t5, 684($t4)
	sw $t5, 812($t4)

	# Draw m
	sw $t5, 184($t4)
	sw $t5, 312($t4)
	sw $t5, 440($t4)
	sw $t5, 568($t4)
	sw $t5, 696($t4)
	sw $t5, 316($t4)
	sw $t5, 320($t4)
	sw $t5, 324($t4)
	sw $t5, 328($t4)
	sw $t5, 332($t4)
	sw $t5, 336($t4)
	sw $t5, 464($t4)
	sw $t5, 592($t4)
	sw $t5, 720($t4)
	sw $t5, 452($t4)
	sw $t5, 580($t4)
	sw $t5, 708($t4)
	
	# Draw E
	sw $t5, 220($t4)
	sw $t5, 224($t4)
	sw $t5, 228($t4)
	sw $t5, 232($t4)
	sw $t5, 348($t4)
	sw $t5, 476($t4)
	sw $t5, 604($t4)
	sw $t5, 732($t4)
	sw $t5, 480($t4)
	sw $t5, 484($t4)
	sw $t5, 488($t4)
	sw $t5, 736($t4)
	sw $t5, 740($t4)
	sw $t5, 744($t4)

	# Draw O
	sw $t5, 1160($t4)
	sw $t5, 1164($t4)
	sw $t5, 1168($t4)
	sw $t5, 1172($t4)
	sw $t5, 1300($t4)
	sw $t5, 1428($t4)
	sw $t5, 1556($t4)
	sw $t5, 1684($t4)
	sw $t5, 1288($t4)
	sw $t5, 1416($t4)
	sw $t5, 1544($t4)
	sw $t5, 1672($t4)
	sw $t5, 1676($t4)
	sw $t5, 1680($t4)
	
	# Draw V
	sw $t5, 1184($t4)
	sw $t5, 1312($t4)
	sw $t5, 1440($t4)
	sw $t5, 1572($t4)
	sw $t5, 1704($t4)
	sw $t5, 1580($t4)
	sw $t5, 1456($t4)
	sw $t5, 1328($t4)
	sw $t5, 1200($t4)
	
	# Draw E
	sw $t5, 1212($t4)
	sw $t5, 1216($t4)
	sw $t5, 1220($t4)
	sw $t5, 1224($t4)
	sw $t5, 1340($t4)
	sw $t5, 1468($t4)
	sw $t5, 1596($t4)
	sw $t5, 1724($t4)
	sw $t5, 1728($t4)
	sw $t5, 1732($t4)
	sw $t5, 1736($t4)
	sw $t5, 1472($t4)
	sw $t5, 1476($t4)
	sw $t5, 1480($t4)
	
	# Draw R
	sw $t5, 1236($t4)
	sw $t5, 1240($t4)
	sw $t5, 1244($t4)
	sw $t5, 1248($t4)
	sw $t5, 1364($t4)
	sw $t5, 1492($t4)
	sw $t5, 1620($t4)
	sw $t5, 1748($t4)
	sw $t5, 1496($t4)
	sw $t5, 1500($t4)
	sw $t5, 1504($t4)
	sw $t5, 1376($t4)
	sw $t5, 1628($t4)
	sw $t5, 1760($t4)
	
	# Draw S
	sw $t5, 2440($t4)
	sw $t5, 2444($t4)
	sw $t5, 2448($t4)
	sw $t5, 2568($t4)
	sw $t5, 2696($t4)
	sw $t5, 2700($t4)
	sw $t5, 2704($t4)
	sw $t5, 2832($t4)
	sw $t5, 2960($t4)
	sw $t5, 2956($t4)
	sw $t5, 2952($t4)
	
	# Draw C
	sw $t5, 2460($t4)
	sw $t5, 2464($t4)
	sw $t5, 2468($t4)
	sw $t5, 2588($t4)
	sw $t5, 2716($t4)
	sw $t5, 2844($t4)
	sw $t5, 2972($t4)
	sw $t5, 2976($t4)
	sw $t5, 2980($t4)
	
	# Draw O
	sw $t5, 2480($t4)
	sw $t5, 2484($t4)
	sw $t5, 2488($t4)
	sw $t5, 2492($t4)
	sw $t5, 2608($t4)
	sw $t5, 2736($t4)
	sw $t5, 2864($t4)
	sw $t5, 2992($t4)
	sw $t5, 2996($t4)
	sw $t5, 3000($t4)
	sw $t5, 3004($t4)
	sw $t5, 2876($t4)
	sw $t5, 2748($t4)
	sw $t5, 2620($t4)
	
	# Draw R
	sw $t5, 2504($t4)
	sw $t5, 2508($t4)
	sw $t5, 2512($t4)
	sw $t5, 2632($t4)
	sw $t5, 2760($t4)
	sw $t5, 2888($t4)
	sw $t5, 3016($t4)
	sw $t5, 2764($t4)
	sw $t5, 2768($t4)
	sw $t5, 2640($t4)
	sw $t5, 2892($t4)
	sw $t5, 3024($t4)
	
	# Draw E
	sw $t5, 2524($t4)
	sw $t5, 2528($t4)
	sw $t5, 2532($t4)
	sw $t5, 2536($t4)
	sw $t5, 2652($t4)
	sw $t5, 2780($t4)
	sw $t5, 2784($t4)
	sw $t5, 2788($t4)
	sw $t5, 2792($t4)
	sw $t5, 2908($t4)
	sw $t5, 3036($t4)
	sw $t5, 3040($t4)
	sw $t5, 3044($t4)
	sw $t5, 3048($t4)
	
	
	# Get each digit of the score to print on bitmap display
	lw $t3, score
	li $t2, 10
	li $a0, 22					# print digit starting at x = 22
	
	beq $t3, $zero, draw_0		# handle case where score is zero
	
	get_digits:
	beq $t3, $zero, Exit		# if $t3 == 0 goto Exit
	div $t3, $t2
	mflo $t3					# $t3 = $t3 // 10
	mfhi $t5					# $t5 = $t3 % 10

	
	beq $t5, $zero, draw_0
	beq $t5, 1, draw_1
	beq $t5, 2, draw_2
	beq $t5, 3, draw_3
	beq $t5, 4, draw_4
	beq $t5, 5, draw_5
	beq $t5, 6, draw_6
	beq $t5, 7, draw_7
	beq $t5, 8, draw_8
	beq $t5, 9, draw_9



	Exit:
	# check for key pressed
	li $t9, 0xffff0000
	lw $t8, 0($t9)
	beq $t8, 1, check_for_p
	
	j Exit
	
	check_for_p:
	lw $t7, 4($t9)
	beq $t7, 0x70, respond_to_p		# ascii value of 'p' is 0x70
	j Exit
	
	
	draw_0:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 640($t5)
	sw $t7, 636($t5)
	sw $t7, 632($t5)
	sw $t7, 628($t5)
	sw $t7, 512($t5)
	sw $t7, 384($t5)
	sw $t7, 256($t5)
	sw $t7, 128($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, 116($t5)
	sw $t7, 244($t5)
	sw $t7, 372($t5)
	sw $t7, 500($t5)
	
	addi $a0, $a0, -6		# x -= 6
	
	j get_digits
	
	draw_1:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	# Draw a 1 at $a0, 25
	la $t7, GREEN
	sw $t7, 128($t5)
	sw $t7, 256($t5)
	sw $t7, 384($t5)
	sw $t7, 512($t5)
	sw $t7, 640($t5)
	
	addi $a0, $a0, -3		# x -= 3
	
	j get_digits
	
	draw_2:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 640($t5)
	sw $t7, 636($t5)
	sw $t7, 632($t5)
	sw $t7, 628($t5)
	sw $t7, 500($t5)
	sw $t7, 372($t5)
	sw $t7, 376($t5)
	sw $t7, 380($t5)
	sw $t7, 384($t5)
	sw $t7, 256($t5)
	sw $t7, 128($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, 116($t5)
	
	addi $a0, $a0, -6		# x -= 6
	
	j get_digits
	
	draw_3:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	
	sw $t7, 640($t5)
	sw $t7, 636($t5)
	sw $t7, 632($t5)
	sw $t7, 628($t5)
	sw $t7, 512($t5)
	sw $t7, 384($t5)
	sw $t7, 380($t5)
	sw $t7, 376($t5)
	sw $t7, 372($t5)
	sw $t7, 256($t5)
	sw $t7, 128($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, 116($t5)
	
	addi $a0, $a0, -6		# x -= 6
	
	j get_digits
	
	draw_4:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	
	sw $t7, 384($t5)
	sw $t7, 376($t5)
	sw $t7, 372($t5)
	sw $t7, 244($t5)
	sw $t7, 116($t5)
	sw $t7, 636($t5)
	sw $t7, 508($t5)
	sw $t7, 380($t5)
	sw $t7, 252($t5)
	sw $t7, 124($t5)
	
	addi $a0, $a0, -6		# x -= 6

	j get_digits
	
	draw_5:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 640($t5)
	sw $t7, 636($t5)
	sw $t7, 632($t5)
	sw $t7, 628($t5)
	sw $t7, 512($t5)
	sw $t7, 384($t5)
	sw $t7, 380($t5)
	sw $t7, 376($t5)
	sw $t7, 372($t5)
	sw $t7, 244($t5)
	sw $t7, 116($t5)
	sw $t7, 120($t5)
	sw $t7, 124($t5)
	sw $t7, 128($t5)
	
	addi $a0, $a0, -6		# x -= 6
	
	j get_digits
	
	draw_6:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 640($t5)
	sw $t7, 636($t5)
	sw $t7, 632($t5)
	sw $t7, 628($t5)
	sw $t7, 512($t5)
	sw $t7, 384($t5)
	sw $t7, 380($t5)
	sw $t7, 376($t5)
	sw $t7, 372($t5)
	sw $t7, 500($t5)
	sw $t7, 244($t5)
	sw $t7, 116($t5)
	sw $t7, 120($t5)
	sw $t7, 124($t5)
	sw $t7, 128($t5)
	
	addi $a0, $a0, -6		# x -= 6
	
	j get_digits
	
	draw_7:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 640($t5)
	sw $t7, 512($t5)
	sw $t7, 384($t5)
	sw $t7, 256($t5)
	sw $t7, 128($t5)
	sw $t7, 124($t5)
	sw $t7, 120($t5)
	sw $t7, 116($t5)
	
	addi $a0, $a0, -6		# x -= 6
	
	j get_digits
	
	draw_8:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 380($t5)
	sw $t7, 376($t5)

	j draw_0
	
	draw_9:
	# Get pixel at x = $a0 and y = 25
	li $t5, 25				# y= $t5 = 25
	sll $t5, $t5, 5			# $t5 = y * 32
	add $t5, $t5, $a0		# $t5 = y * 32 + x
	sll $t5, $t5, 2			# $t5 = (y * 32 + x) * 4
	add $t5, $t5, $t0		# $t5 = (y * 32 + x) * 4 + BASE_ADDRESS
	
	la $t7, GREEN
	sw $t7, 244($t5)
	sw $t7, 372($t5)
	sw $t7, 376($t5)
	sw $t7, 380($t5)
	
	j draw_7
