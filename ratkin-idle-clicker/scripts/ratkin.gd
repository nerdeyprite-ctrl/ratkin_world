# ratkin.gd
# 랫킨 캐릭터 스크립트

extends CharacterBody2D

# 노드 참조
@onready var worker_sprite: AnimatedSprite2D = $Worker
@onready var priest_sprite: AnimatedSprite2D = $Priest
@onready var cook_sprite: AnimatedSprite2D = $Cook
@onready var area: Area2D = $Area2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D  # 🆕 네비게이션

# 🆕 현재 활성화된 스프라이트를 추적할 변수
var current_sprite: AnimatedSprite2D = null

# 기본 직업 일반 랫킨
var job: int = GameManager.RatkinJob.WORKER

# ========================================
# 🆕 작업 및 스케줄 관련 변수
# ========================================
var assigned_plot: Node2D = null # 배정된 작업장
var target_position: Vector2 = Vector2.ZERO # 작업장 내 목표 위치 (로컬)
var dorm_position: Vector2 = Vector2.ZERO # 숙소 위치 (화면 하단 중앙)

# 이동 관련
# velocity는 CharacterBody2D에 내장되어 있으므로 선언 불필요
var speed: float = 80.0 # 속도를 천천히 (150 -> 80)
var direction: int = 1  # 1: 오른쪽, -1: 왼쪽

# 화면 경계
var screen_size: Vector2
var sprite_size: Vector2

# 메시지
var bubble_scene = preload("res://scenes/bubble.tscn")
var current_bubble = null  # 현재 말풍선 추적
var random_speech_timer: float = 0.0  # 랜덤 대사 타이머

# 갇힘 방지
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var stuck_threshold: float = 5.0

# 🆕 이동 딜레이 및 상태 추적
var move_delay_timer: float = 0.0
var was_daytime: bool = true # 이전 프레임의 낮/밤 상태

# 메시지 데이터
var worker_messages = ["찍찍! 🐭", "일하는 중... 💼", "총총총...", "배고파요 🍚"]
var priest_messages = ["기도 중... 🙏", "축복을! 🌟", "감사합니다... 🕯️"]
var cook_messages = ["요리 중... 🍳", "맛있는 빵! 🍞", "냠냠냠... 🍴", "오늘의 메뉴는? 🥘"]

func _ready() -> void:
	# 화면 크기 가져오기
	scale = Vector2(2, 2)
	screen_size = get_viewport_rect().size
	
	# 🆕 숙소 위치 설정 (화면 하단 중앙)
	dorm_position = Vector2(screen_size.x / 2, screen_size.y - 100)
	
	sprite_size = Vector2(48, 48) * scale
	
	# 🆕 NavigationAgent2D 설정 (다음 프레임에 설정)
	if nav_agent:
		# NavigationServer가 준비될 때까지 기다림
		call_deferred("_setup_navigation")
	else:
		print("⚠️ NavigationAgent2D가 없습니다. 직선 이동을 사용합니다.")

func _setup_navigation() -> void:
	if nav_agent:
		nav_agent.path_desired_distance = 10.0
		nav_agent.target_desired_distance = 20.0
		nav_agent.max_speed = speed
		nav_agent.avoidance_enabled = false  # 일단 비활성화
		nav_agent.debug_enabled = true  # 디버그 활성화
		print("✅ NavigationAgent2D 설정 완료")
	
	# 직업 스프라이트 초기화
	_initialize_sprite_by_job()
	
	# 랜덤 위치 (초기 스폰) - 물 위가 아닌 곳 찾기
	var safe_pos = Vector2.ZERO
	var max_attempts = 50
	var found_safe_pos = false
	
	for i in range(max_attempts):
		var random_pos = Vector2(
			randf_range(sprite_size.x / 2, screen_size.x - sprite_size.x / 2),
			randf_range(screen_size.y * 0.6, screen_size.y - sprite_size.y / 2)
		)
		
		if _is_walkable(random_pos):
			safe_pos = random_pos
			found_safe_pos = true
			break
	
	if found_safe_pos:
		position = safe_pos
	else:
		print("⚠️ 안전한 스폰 위치를 찾지 못했습니다. 기본 위치로 설정합니다.")
		position = Vector2(screen_size.x / 2, screen_size.y * 0.8)
	
	set_random_direction()
	current_sprite.play("walk")
	
	# 초기 낮/밤 상태 설정
	was_daytime = GameManager.is_daytime()
	
	# 시그널 연결
	if not area.input_event.is_connected(_on_area_input_event):
		area.input_event.connect(_on_area_input_event)
	if not area.area_entered.is_connected(_on_area_entered):
		area.area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	# 🆕 낮/밤 상태 변화 감지
	var is_day = GameManager.is_daytime()
	if is_day != was_daytime:
		was_daytime = is_day
		# 상태가 바뀌면 랜덤 딜레이 설정 (0 ~ 3초)
		# 한 명씩 나가는 느낌을 주기 위해 넉넉하게 설정
		move_delay_timer = randf_range(0.0, 3.0)
		
		# 밤이 되면(일하러 가다가 퇴근) 혹은 낮이 되면(자다가 출근) 말풍선 띄우기
		if not is_day:
			_show_emote("퇴근이다! 🏠")
		else:
			_show_emote("일하러 가자! ☀️")

	# 딜레이 중이면 대기
	if move_delay_timer > 0.0:
		move_delay_timer -= delta
		if move_delay_timer <= 0.0:
			move_delay_timer = 0.0
		else:
			# 대기 중에는 idle
			current_sprite.play("idle")
			return

	# 🆕 상태 머신 로직
	var target_pos_global = position # 기본값은 현재 위치
	var is_moving_to_target = false
	
	if not is_day:
		# [밤] 집 안에서 자유롭게 배회
		# 집 안에 있는지 확인
		if _is_inside_house(position):
			# 이미 집 안에 있으면 자유롭게 배회
			_wander_in_house(delta)
			return
		else:
			# 집 밖에 있으면 집으로 이동
			var house_pos = _get_nearest_house_floor_position()
			if house_pos != Vector2.ZERO:
				# 집까지의 거리 확인
				var distance_to_house = position.distance_to(house_pos)
				
				# 매우 가까우면 텔레포트 (문 통과 시뮬레이션)
				if distance_to_house < 50.0:
					position = house_pos
					velocity = Vector2.ZERO
					return
				
				# 🆕 NavigationAgent2D에 목표 설정
				if nav_agent:
					nav_agent.target_position = house_pos
				target_pos_global = house_pos
				is_moving_to_target = true
			else:
				# 집을 못 찾으면 그냥 배회
				_wander_logic(delta)
				return
			
	elif assigned_plot != null:
		# [낮 & 배정됨] 작업장으로 이동
		target_pos_global = assigned_plot.global_position + target_position
		
		# 🆕 NavigationAgent2D에 목표 설정
		if nav_agent:
			nav_agent.target_position = target_pos_global
		is_moving_to_target = true
		
		# 도착 확인
		if position.distance_to(target_pos_global) < 10.0:
			# 도착했으면 작업 애니메이션
			if job == GameManager.RatkinJob.COOK:
				if current_sprite.sprite_frames.has_animation("cook"):
					current_sprite.play("cook")
				else:
					current_sprite.play("idle")
			else:
				if current_sprite.sprite_frames.has_animation("work"):
					current_sprite.play("work")
				else:
					current_sprite.play("idle")
			
			velocity = Vector2.ZERO
			return

	# 이동 로직 처리
	if is_moving_to_target:
		# 🆕 추가 떨림 방지: 목표와 매우 가까우면 강제 정지
		if position.distance_to(target_pos_global) < 5.0:
			velocity = Vector2.ZERO
			current_sprite.play("idle")
			is_moving_to_target = false
		# 🆕 NavigationAgent2D 사용 (있으면)
		elif nav_agent and nav_agent.is_inside_tree():
			# 경로가 있는지 확인
			if nav_agent.is_target_reachable():
				if not nav_agent.is_navigation_finished():
					var next_path_position = nav_agent.get_next_path_position()
					var direction_vector = (next_path_position - position).normalized()
					velocity = direction_vector * speed
					
					# 방향 전환 (Deadzone 추가)
					if abs(velocity.x) > 1.0:
						if velocity.x > 0:
							direction = 1
							current_sprite.flip_h = false
						elif velocity.x < 0:
							direction = -1
							current_sprite.flip_h = true
					
					current_sprite.play("walk")
					move_and_slide()
				else:
					# 목표 도착
					velocity = Vector2.ZERO
					current_sprite.play("idle")
					is_moving_to_target = false
			else:
				# 경로를 찾을 수 없음 - 직선 이동으로 폴백
				# print("⚠️ 경로를 찾을 수 없음: ", position, " -> ", target_pos_global)
				# 너무 자주 출력되면 성능 저하되므로 주석 처리하거나 빈도를 줄임
				var direction_vector = (target_pos_global - position).normalized()
				velocity = direction_vector * speed
				
				if abs(velocity.x) > 1.0:
					if velocity.x > 0:
						direction = 1
						current_sprite.flip_h = false
					elif velocity.x < 0:
						direction = -1
						current_sprite.flip_h = true
				
				current_sprite.play("walk")
				move_and_slide()
		else:
			# NavigationAgent2D 없으면 직선 이동
			var direction_vector = (target_pos_global - position).normalized()
			velocity = direction_vector * speed
			
			# 방향 전환
			if abs(velocity.x) > 1.0:
				if velocity.x > 0:
					direction = 1
					current_sprite.flip_h = false
				elif velocity.x < 0:
					direction = -1
					current_sprite.flip_h = true
			
			current_sprite.play("walk")
			move_and_slide()
		
	else:
		# [낮 & 배정 안 됨] 랜덤 배회 (기존 로직)
		_wander_logic(delta)

func _show_emote(msg: String) -> void:
	if current_bubble:
		current_bubble.queue_free()
	var bubble = bubble_scene.instantiate()
	add_child(bubble)
	bubble.position = Vector2(0, -50)
	bubble.set_message(msg)
	current_bubble = bubble

# 🆕 이동 가능 여부 확인 (물 타일 체크)
func _is_walkable(pos: Vector2) -> bool:
	# 메인 씬의 TileMap 구조: Main -> TileMap -> GameTileMap -> Layers (Water, Grass, TileDirt, etc.)
	# 주의: GameTileMap은 Node2D이고, 그 자식들이 TileMapLayer임.
	var game_tilemap = get_tree().root.get_node_or_null("Main/TileMap/GameTileMap")
	if not game_tilemap:
		return true
	
	# 레이어 노드 찾기
	var water_layer = game_tilemap.get_node_or_null("Water")
	var grass_layer = game_tilemap.get_node_or_null("Grass")
	var dirt_layer = game_tilemap.get_node_or_null("TileDirt")
	
	# 좌표 변환을 위해 기준 레이어 하나 선택 (보통 Water나 Grass)
	var ref_layer = water_layer
	if not ref_layer:
		ref_layer = grass_layer
	if not ref_layer:
		return true # 레이어가 없으면 이동 가능
		
	# 월드 좌표 -> 레이어 로컬 좌표 -> 그리드 좌표
	var local_pos = ref_layer.to_local(pos)
	var grid_pos = ref_layer.local_to_map(local_pos)
	
	# 1. 물 위에 있으면 이동 불가
	if water_layer:
		# Water 레이어에 타일이 있으면 물임
		if water_layer.get_cell_source_id(grid_pos) != -1:
			return false
			
	# 2. 땅(풀, 흙) 위에 있으면 이동 가능
	if grass_layer:
		if grass_layer.get_cell_source_id(grid_pos) != -1:
			return true
			
	if dirt_layer:
		if dirt_layer.get_cell_source_id(grid_pos) != -1:
			return true
			
	# 3. 아무 타일도 없으면 이동 불가 (허공)
	return false

# 🆕 집 안에 있는지 확인
func _is_inside_house(pos: Vector2) -> bool:
	# WorkerHouse 노드 찾기
	var worker_houses = get_tree().get_nodes_in_group("worker_house")
	var worker_house = worker_houses[0] if worker_houses.size() > 0 else null
	if not worker_house:
		return false
	
	var house_tilemap = worker_house.get_node_or_null("HouseTilemap")
	if not house_tilemap:
		return false
	
	var floor_layer = house_tilemap.get_node_or_null("Floor")
	if not floor_layer:
		return false
	
	var local_pos = floor_layer.to_local(pos)
	var grid_pos = floor_layer.local_to_map(local_pos)
	
	return floor_layer.get_cell_source_id(grid_pos) != -1

# 🆕 가장 가까운 집 바닥 위치 찾기
func _get_nearest_house_floor_position() -> Vector2:
	var worker_houses = get_tree().get_nodes_in_group("worker_house")
	var worker_house = worker_houses[0] if worker_houses.size() > 0 else null
	if not worker_house:
		return Vector2.ZERO
	
	var house_tilemap = worker_house.get_node_or_null("HouseTilemap")
	if not house_tilemap:
		return Vector2.ZERO
	
	var floor_layer = house_tilemap.get_node_or_null("Floor")
	if not floor_layer:
		return Vector2.ZERO
	
	var floor_tiles = floor_layer.get_used_cells()
	if floor_tiles.is_empty():
		return Vector2.ZERO
	
	# 가장 가까운 타일 찾기
	var nearest_tile = floor_tiles[0]
	var nearest_distance = INF
	
	for tile in floor_tiles:
		var local_pos = floor_layer.map_to_local(tile)
		var global_pos = floor_layer.to_global(local_pos)
		var distance = position.distance_to(global_pos)
		
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_tile = tile
	
	var local_pos = floor_layer.map_to_local(nearest_tile)
	return floor_layer.to_global(local_pos)

# 🆕 집 안에서 배회
func _wander_in_house(delta: float) -> void:
	current_sprite.play("walk")
	
	# velocity가 0이면 랜덤 방향 설정
	if velocity.length() < 1.0:
		set_random_direction()
		# 집 안에서는 속도 절반
		velocity *= 0.5
	
	# 집 안에서는 느리게 이동
	var house_speed = speed * 0.5
	velocity = velocity.normalized() * house_speed
	
	# 집 밖으로 나가려고 하면 방향 전환
	var next_position = position + velocity * delta
	if not _is_inside_house(next_position):
		velocity *= -1
		direction *= -1
		current_sprite.flip_h = (direction == -1)
		return
	
	move_and_slide()  # 🆕 CharacterBody2D의 충돌 처리
	
	# 랜덤 대사
	random_speech_timer += delta
	if random_speech_timer >= 1.0:
		random_speech_timer -= 1.0
		if randf() < 0.01:
			say_hello()

# 기존 랜덤 배회 로직 분리
func _wander_logic(delta: float) -> void:
	current_sprite.play("walk")
	
	# 🆕 이동할 위치 미리 계산
	var next_position = position + velocity * delta
	
	# 갈 수 없는 곳(물)이면 방향 전환
	if not _is_walkable(next_position):
		velocity *= -1 # 뒤로 돌아!
		direction *= -1
		current_sprite.flip_h = (direction == -1)
		return

	move_and_slide()  # 🆕 CharacterBody2D의 충돌 처리
	
	# 🆕 화면 경계 체크 제거 - 타일맵 안에서 자유롭게 이동
	
	# 갇힘 감지
	var movement = (position - last_position).length()
	if movement < 1.0:
		stuck_timer += delta
		if stuck_timer >= stuck_threshold:
			# 갇혔을 때 처리
			if not GameManager.is_daytime() and not _is_inside_house(position):
				# 밤이고 집 밖에서 갇혔으면 집으로 강제 소환
				print("⚠️ 밤에 갇힘 감지 -> 집으로 강제 이동")
				var house_pos = _get_nearest_house_floor_position()
				if house_pos != Vector2.ZERO:
					position = house_pos
				velocity = Vector2.ZERO
				if nav_agent:
					nav_agent.target_position = position
			else:
				# 그 외의 경우 (낮이거나 집 안에서 갇힘) 랜덤 방향 전환
				set_random_direction()
			
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
	last_position = position
	
	# 랜덤 대사
	random_speech_timer += delta
	if random_speech_timer >= 1.0:
		random_speech_timer -= 1.0
		if randf() < 0.01:
			say_hello()

func set_random_direction() -> void:
	var angle = randf_range(-PI/4, PI/4)
	velocity = Vector2(cos(angle), sin(angle)) * speed
	if velocity.x > 0:
		direction = 1
		current_sprite.flip_h = false
	else:
		direction = -1
		current_sprite.flip_h = true

func _initialize_sprite_by_job() -> void:
	worker_sprite.hide()
	priest_sprite.hide()
	cook_sprite.hide()

	if job == GameManager.RatkinJob.PRIEST:
		current_sprite = priest_sprite
	elif job == GameManager.RatkinJob.WORKER:
		current_sprite = worker_sprite
	elif job == GameManager.RatkinJob.COOK:
		current_sprite = cook_sprite
	else:
		current_sprite = worker_sprite 
		
	current_sprite.show()
	current_sprite.play("walk")

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			say_hello()

func _on_area_entered(other_area: Area2D) -> void:
	var other_ratkin = other_area.get_parent()
	if other_ratkin and other_ratkin.has_method("get_position"):
		var push_direction = (position - other_ratkin.position).normalized()
		if push_direction.length() < 0.1:
			push_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		# 배정된 상태나 밤에는 서로 밀지 않게 하거나 약하게 밀게 할 수 있음
		# 일단 기존 로직 유지하되, 이동 중일 때는 영향 덜 받도록?
		# 여기서는 단순화를 위해 기존 로직 유지
		velocity = push_direction * 50.0
		
		if abs(velocity.x) > 1.0:
			if velocity.x > 0:
				direction = 1
				current_sprite.flip_h = false
			elif velocity.x < 0:
				direction = -1
				current_sprite.flip_h = true

func say_hello() -> void:
	if current_bubble:
		current_bubble.queue_free()
	
	var bubble = bubble_scene.instantiate()
	add_child(bubble)
	bubble.position = Vector2(0, -50)
	
	var msg_list = worker_messages
	if job == GameManager.RatkinJob.PRIEST:
		msg_list = priest_messages
	elif job == GameManager.RatkinJob.COOK:
		msg_list = cook_messages
	
	bubble.set_message(msg_list.pick_random())
	current_bubble = bubble

func set_job(new_job: int) -> void:
	job = new_job
	_initialize_sprite_by_job()
