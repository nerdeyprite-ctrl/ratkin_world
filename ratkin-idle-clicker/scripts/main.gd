# main.gd
# 메인 씬 관리 스크립트

extends Node2D

# 프리팹
var ratkin_scene = preload("res://scenes/ratkin.tscn")
var farm_scene = preload("res://scenes/farm.tscn")
var bakery_scene = preload("res://scenes/bakery.tscn")
var background_scene = preload("res://scenes/test_scene_tilemap.tscn")

# 랫킨 배열
var ratkins: Array = []

# 현재 화면의 랫킨 수
var current_ratkin_count: int = 0

# 🆕 카메라 이동
var camera: Camera2D
var camera_speed: float = 450.0  # 300 * 1.5

func _ready() -> void:
	print("Main 씬 초기화!")
	GameManager.ratkin_spawned.connect(_on_ratkin_spawned)
	
	# 🆕 카메라 설정
	camera = Camera2D.new()
	add_child(camera)
	camera.enabled = true
	
	# 🆕 인프라(농장, 제과점, 배경) 자동 설치
	setup_infrastructure()
	
	# 저장된 랫킨 복원
	restore_ratkins()
	
	# 🆕 [테스트용] 임의 배정 실행
	call_deferred("_test_assign_workers")

func _process(delta: float) -> void:
	# 🆕 카메라 이동 (WASD, 방향키)
	var camera_move = Vector2.ZERO
	
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		camera_move.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		camera_move.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		camera_move.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		camera_move.y += 1
	
	if camera_move.length() > 0:
		var new_pos = camera.position + camera_move.normalized() * camera_speed * delta
		
		# 🆕 타일맵 경계 체크 (대략적인 범위)
		# 타일맵 크기를 추정 (타일 크기 * 스케일 * 타일 수)
		# test_scene_tilemap은 대략 50x50 타일, 스케일 4배
		var tilemap_bounds = Rect2(-500, -500, 3000, 3000)
		new_pos.x = clamp(new_pos.x, tilemap_bounds.position.x, tilemap_bounds.position.x + tilemap_bounds.size.x)
		new_pos.y = clamp(new_pos.y, tilemap_bounds.position.y, tilemap_bounds.position.y + tilemap_bounds.size.y)
		
		camera.position = new_pos

# 🆕 인프라 자동 설치 함수
func setup_infrastructure() -> void:
	var screen_size = get_viewport_rect().size
	
	# 0. 배경 (TileMap) 설치
	var background = get_node_or_null("TileMap") # 이름이 TileMap이라고 가정
	if not background:
		print("배경(TileMap)이 없어 자동으로 생성합니다.")
		background = background_scene.instantiate()
		background.name = "TileMap"
		add_child(background)
		move_child(background, 0) # 맨 뒤로 보내기
	
	# 1. 농장 (Farm) 확인 및 생성
	var farm = get_node_or_null("Farm")
	if not farm:
		print("Farm 노드가 없어 자동으로 생성합니다.")
		farm = farm_scene.instantiate()
		farm.name = "Farm" # 이름 중요! (찾을 때 씀)
		add_child(farm)
		# 위치 설정 (화면 왼쪽)
		farm.position = Vector2(screen_size.x * 0.25, screen_size.y * 0.5)
	
	# 2. 제과점 (Bakery) 확인 및 생성
	var bakery = get_node_or_null("Bakery")
	if not bakery:
		print("Bakery 노드가 없어 자동으로 생성합니다.")
		bakery = bakery_scene.instantiate()
		bakery.name = "Bakery" # 이름 중요!
		add_child(bakery)
		# 위치 설정 (화면 오른쪽)
		bakery.position = Vector2(screen_size.x * 0.75, screen_size.y * 0.5)
	
	# 🆕 3. 통합 네비게이션 설정
	call_deferred("_setup_unified_navigation")

func _input(event: InputEvent) -> void:
	# ESC 키로 메뉴로 돌아가기
	if event.is_action_pressed("ui_cancel"):
		GameManager.save_game()
		get_tree().change_scene_to_file("res://scenes/menu.tscn")

func restore_ratkins() -> void:
	# 저장된 랫킨 수만큼 생성
	for i in range(GameManager.worker_count):
		spawn_ratkin(GameManager.RatkinJob.WORKER)
	for i in range(GameManager.priest_count):
		spawn_ratkin(GameManager.RatkinJob.PRIEST)
	for i in range(GameManager.cook_count):
		spawn_ratkin(GameManager.RatkinJob.COOK)
	
	print("랫킨 복원 완료: 총 %d마리" % (GameManager.worker_count + GameManager.priest_count + GameManager.cook_count))

func _on_ratkin_spawned(job: int) -> void:
	spawn_ratkin(job)
	current_ratkin_count += 1

func spawn_ratkin(job: int) -> void:
	var ratkin = ratkin_scene.instantiate()
	add_child(ratkin)
	ratkin.set_job(job)  # 🆕 직업 설정
	ratkins.append(ratkin)
	print("랫킨 생성! 직업: %d, 총 %d마리" % [job, ratkins.size()])
	
	# 🆕 생성되자마자 자동 배정 시도 (선택 사항)
	_try_auto_assign(ratkin)

# 🆕 [테스트용] 임의 배정 함수
# 사용자가 "레디에서 임의로 배정해보고 싶다"고 하셔서 추가한 함수입니다.
func _test_assign_workers() -> void:
	print("--- 임의 배정 테스트 시작 ---")
	
	# 1. 씬에서 농장과 제과점 노드를 찾습니다.
	# 주의: 에디터 씬 트리에 "Farm"과 "Bakery"라는 이름의 노드가 있어야 합니다.
	var farm = get_node_or_null("Farm")
	var bakery = get_node_or_null("Bakery")
	
	if not farm:
		print("⚠️ 경고: 'Farm' 노드를 찾을 수 없습니다. 에디터에서 만들어주세요.")
	if not bakery:
		print("⚠️ 경고: 'Bakery' 노드를 찾을 수 없습니다. 에디터에서 만들어주세요.")
	
	# 2. 현재 있는 모든 랫킨을 확인하며 배정합니다.
	for ratkin in ratkins:
		# 이미 배정된 랫킨은 패스
		if ratkin.assigned_plot != null:
			continue
			
		if ratkin.job == GameManager.RatkinJob.WORKER:
			if farm and farm.has_method("assign_worker"):
				var success = farm.assign_worker(ratkin)
				if success:
					print(" -> 일꾼을 농장에 배정했습니다.")
				else:
					print(" -> 농장이 꽉 찼습니다.")
					
		elif ratkin.job == GameManager.RatkinJob.COOK:
			if bakery and bakery.has_method("assign_worker"):
				var success = bakery.assign_worker(ratkin)
				if success:
					print(" -> 요리사를 제과점에 배정했습니다.")
				else:
					print(" -> 제과점이 꽉 찼습니다.")

# 🆕 개별 랫킨 자동 배정 시도
func _try_auto_assign(ratkin: Node2D) -> void:
	# 씬 트리가 완전히 준비된 후 실행하기 위해 call_deferred 사용 가능하지만,
	# 여기서는 간단히 노드 검색 시도
	var farm = get_node_or_null("Farm")
	var bakery = get_node_or_null("Bakery")
	
	if ratkin.job == GameManager.RatkinJob.WORKER and farm:
		farm.assign_worker(ratkin)
	elif ratkin.job == GameManager.RatkinJob.COOK and bakery:
		bakery.assign_worker(ratkin)

# 🆕 통합 네비게이션 설정 (최적화됨)
func _setup_unified_navigation() -> void:
	print("\n========================================")
	print("🗺️ 통합 네비게이션 설정 시작 (Greedy Meshing)...")
	print("========================================")
	
	# NavigationRegion2D 찾기 또는 생성
	var nav_region = get_node_or_null("NavigationRegion2D")
	if not nav_region:
		nav_region = NavigationRegion2D.new()
		nav_region.name = "NavigationRegion2D"
		add_child(nav_region)
		print("  ✅ NavigationRegion2D 생성")
	
	# NavigationPolygon 생성
	var nav_poly = NavigationPolygon.new()
	
	# 🆕 모든 이동 가능한 타일 좌표 수집 (Set 역할의 Dictionary 사용)
	var walkable_tiles = {}
	
	# 🆕 먼저 벽 타일 위치를 수집 (제외할 영역)
	print("\n[1단계] 집 영역 계산 (바운딩 박스)")
	print("─────────────────────────")
	var house_bounding_box: Rect2 = Rect2()
	var has_house = false
	var worker_houses = get_tree().get_nodes_in_group("worker_house")
	print("  🔍 worker_house 그룹에서 찾은 집: ", worker_houses.size(), "개")
	
	if worker_houses.size() > 0:
		var worker_house = worker_houses[0]
		print("  📍 WorkerHouse 위치: ", worker_house.global_position)
		print("  📍 WorkerHouse 스케일: ", worker_house.scale)
		
		var house_tilemap = worker_house.get_node_or_null("HouseTilemap")
		if house_tilemap:
			print("  ✅ HouseTilemap 찾음")
			
			var wall_layer = house_tilemap.get_node_or_null("Walls")
			if wall_layer:
				var wall_cells = wall_layer.get_used_cells()
				print("  ✅ Walls 레이어 찾음")
				print("  🔢 벽 타일 개수: ", wall_cells.size())
				
				if wall_cells.size() > 0:
					# 모든 벽 타일의 바운딩 박스 계산
					var min_x = INF
					var min_y = INF
					var max_x = -INF
					var max_y = -INF
					
					for cell in wall_cells:
						var local_pos = wall_layer.map_to_local(cell)
						var global_pos = wall_layer.to_global(local_pos)
						
						# 타일 크기 고려 (16 * 1.5 = 24, 양쪽으로 12씩)
						var tile_half_size = 12.0
						min_x = min(min_x, global_pos.x - tile_half_size)
						min_y = min(min_y, global_pos.y - tile_half_size)
						max_x = max(max_x, global_pos.x + tile_half_size)
						max_y = max(max_y, global_pos.y + tile_half_size)
					
					# 약간의 마진 추가 (타일 1개 크기)
					var margin = 64.0
					house_bounding_box = Rect2(
						min_x - margin,
						min_y - margin,
						(max_x - min_x) + margin * 2,
						(max_y - min_y) + margin * 2
					)
					has_house = true
					
					print("  ✅ 집 바운딩 박스 계산 완료:")
					print("    위치: (", house_bounding_box.position.x, ", ", house_bounding_box.position.y, ")")
					print("    크기: (", house_bounding_box.size.x, ", ", house_bounding_box.size.y, ")")
					print("    범위: X[", min_x, " ~ ", max_x, "], Y[", min_y, " ~ ", max_y, "]")
			else:
				print("  ❌ Walls 레이어를 찾을 수 없음!")
		else:
			print("  ❌ HouseTilemap을 찾을 수 없음!")
	else:
		print("  ❌ worker_house 그룹에 집이 없음!")
	
	# 1. 배경 타일맵의 Grass, TileDirt 수집 (집 영역 제외)
	print("\n[2단계] Grass/Dirt 타일 수집 (집 영역 제외)")
	print("─────────────────────────")
	var tilemap = get_node_or_null("TileMap/GameTileMap")
	if tilemap:
		print("  ✅ GameTileMap 찾음")
		var grass_layer = tilemap.get_node_or_null("Grass")
		var dirt_layer = tilemap.get_node_or_null("TileDirt")
		
		# 좌표 변환을 위해 글로벌 좌표 기준으로 수집
		if grass_layer:
			print("\n  [Grass 레이어]")
			print("  📍 글로벌 위치: ", grass_layer.global_position)
			print("  📍 스케일: ", grass_layer.scale)
			var before_count = walkable_tiles.size()
			_collect_tiles_excluding_house(grass_layer, walkable_tiles, house_bounding_box, has_house)
			var after_count = walkable_tiles.size()
			print("  ✅ Grass 타일 수집 완료 (추가된 타일: ", after_count - before_count, "개)")
		
		if dirt_layer:
			print("\n  [TileDirt 레이어]")
			print("  📍 글로벌 위치: ", dirt_layer.global_position)
			print("  📍 스케일: ", dirt_layer.scale)
			var before_count = walkable_tiles.size()
			_collect_tiles_excluding_house(dirt_layer, walkable_tiles, house_bounding_box, has_house)
			var after_count = walkable_tiles.size()
			print("  ✅ TileDirt 타일 수집 완료 (추가된 타일: ", after_count - before_count, "개)")
	else:
		print("  ❌ GameTileMap을 찾을 수 없음!")
	
	# 2. 집의 Floor 타일 수집
	print("\n[3단계] House Floor 타일 수집")
	print("─────────────────────────")
	if worker_houses.size() > 0:
		var worker_house = worker_houses[0]
		var house_tilemap = worker_house.get_node_or_null("HouseTilemap")
		if house_tilemap:
			var floor_layer = house_tilemap.get_node_or_null("Floor")
			if floor_layer:
				print("  ✅ Floor 레이어 찾음")
				var before_count = walkable_tiles.size()
				_collect_tiles(floor_layer, walkable_tiles)
				var after_count = walkable_tiles.size()
				print("  ✅ House Floor 타일 수집 완료 (추가된 타일: ", after_count - before_count, "개)")
			else:
				print("  ❌ Floor 레이어를 찾을 수 없음!")
	
	print("\n[4단계] 최종 통계")
	print("─────────────────────────")
	print("  📊 총 이동 가능 타일: ", walkable_tiles.size(), "개")
	if has_house:
		print("  📊 집 영역 제외됨: ", house_bounding_box)
	
	# 3. Greedy Meshing으로 최적화된 폴리곤 생성
	print("\n[5단계] Greedy Meshing 실행")
	print("─────────────────────────")
	_generate_optimized_mesh(walkable_tiles, nav_poly)
	
	# NavigationPolygon 적용 및 베이킹
	nav_region.navigation_polygon = nav_poly
	nav_region.bake_navigation_polygon()
	
	print("\n========================================")
	print("🗺️ 통합 네비게이션 설정 완료! (최적화됨)")
	print("========================================\n")

# 타일 레이어의 타일들을 글로벌 그리드 좌표로 수집
func _collect_tiles(layer: TileMapLayer, collection: Dictionary) -> void:
	var used_cells = layer.get_used_cells()
	var tile_size = 64.0 # 16 * 4
	
	for cell in used_cells:
		# 로컬 -> 글로벌 좌표 변환
		var local_pos = layer.map_to_local(cell)
		var global_pos = layer.to_global(local_pos)
		
		# 글로벌 좌표를 가상의 64x64 그리드 좌표로 변환 (반올림하여 정수화)
		var grid_x = int(round(global_pos.x / tile_size))
		var grid_y = int(round(global_pos.y / tile_size))
		
		var key = Vector2i(grid_x, grid_y)
		collection[key] = true

# 🆕 집 영역을 제외하고 타일 수집 (바운딩 박스 사용)
func _collect_tiles_excluding_house(layer: TileMapLayer, collection: Dictionary, house_box: Rect2, has_house_box: bool) -> void:
	var used_cells = layer.get_used_cells()
	var tile_size = 64.0 # 16 * 4
	
	var excluded_count = 0
	for cell in used_cells:
		# 로컬 -> 글로벌 좌표 변환
		var local_pos = layer.map_to_local(cell)
		var global_pos = layer.to_global(local_pos)
		
		# 글로벌 좌표를 가상의 64x64 그리드 좌표로 변환 (반올림하여 정수화)
		var grid_x = int(round(global_pos.x / tile_size))
		var grid_y = int(round(global_pos.y / tile_size))
		
		var key = Vector2i(grid_x, grid_y)
		
		# 집 바운딩 박스 안에 있는지 확인
		var is_in_house = false
		if has_house_box:
			is_in_house = house_box.has_point(global_pos)
		
		# 집 영역이 아닌 경우에만 추가
		if not is_in_house:
			collection[key] = true
		else:
			excluded_count += 1
			if excluded_count <= 5:  # 처음 5개만 출력
				print("    🚫 집 영역과 겹침 - 제외: ", key, " (글로벌: ", global_pos, ")")
	
	if excluded_count > 0:
		print("    📊 총 ", excluded_count, "개 타일 제외됨")


# Greedy Meshing 알고리즘 구현
func _generate_optimized_mesh(tiles: Dictionary, nav_poly: NavigationPolygon) -> void:
	var tile_size = 64.0
	var visited = {}
	
	# 타일 키들을 정렬 (순차적 처리를 위해)
	var keys = tiles.keys()
	# Vector2i는 직접 정렬이 안될 수 있으므로 x, y 순으로 정렬
	keys.sort_custom(func(a, b):
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	
	for key in keys:
		if visited.has(key):
			continue
			
		# 새로운 사각형 시작
		var start_x = key.x
		var start_y = key.y
		var width = 1
		var height = 1
		
		visited[key] = true
		
		# 1. 가로로 최대한 확장
		while tiles.has(Vector2i(start_x + width, start_y)) and not visited.has(Vector2i(start_x + width, start_y)):
			visited[Vector2i(start_x + width, start_y)] = true
			width += 1
			
		# 2. 세로로 최대한 확장 (가로 너비 유지)
		var can_expand_height = true
		while can_expand_height:
			var next_y = start_y + height
			# 다음 줄의 width만큼의 타일이 모두 존재하고 방문하지 않았는지 확인
			for x in range(start_x, start_x + width):
				if not tiles.has(Vector2i(x, next_y)) or visited.has(Vector2i(x, next_y)):
					can_expand_height = false
					break
			
			if can_expand_height:
				# 방문 처리
				for x in range(start_x, start_x + width):
					visited[Vector2i(x, next_y)] = true
				height += 1
		
		# 3. 사각형 폴리곤 추가
		# grid 좌표는 타일 중심점을 나타냄
		# 예: grid (0, 0) = 월드 좌표 (0, 0)의 타일 중심
		# 사각형은 start_x부터 start_x + width - 1까지의 타일을 포함
		
		# 첫 번째 타일의 중심
		var first_tile_center = Vector2(start_x * tile_size, start_y * tile_size)
		# 마지막 타일의 중심
		var last_tile_center = Vector2((start_x + width - 1) * tile_size, (start_y + height - 1) * tile_size)
		
		# 사각형의 경계 (타일 중심에서 ±32)
		var min_x = first_tile_center.x - tile_size / 2.0
		var min_y = first_tile_center.y - tile_size / 2.0
		var max_x = last_tile_center.x + tile_size / 2.0
		var max_y = last_tile_center.y + tile_size / 2.0
		
		var outline = PackedVector2Array([
			Vector2(min_x, min_y),
			Vector2(max_x, min_y),
			Vector2(max_x, max_y),
			Vector2(min_x, max_y)
		])
		
		nav_poly.add_outline(outline)
