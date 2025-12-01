# farm_plot.gd
# 농장 시설 스크립트 (밀 생산)
extends Node2D

# 생산 관련 변수
var current_growth_timer: float = 0.0
var assigned_ratkins: Array = []

# 🆕 타일 기반 배정 시스템
var all_tiles: Array[Vector2] = []  # 모든 타일의 글로벌 좌표
var occupied_tiles: Dictionary = {}  # {tile_index: ratkin}

func _ready() -> void:
	# 🆕 타일맵에서 경작된 흙(TileDirt) 위치 찾기
	var dirt_layer = get_tree().root.get_node_or_null("Main/TileMap/GameTileMap/TileDirt")
	if dirt_layer:
		var used_cells = dirt_layer.get_used_cells()
		all_tiles.clear()
		
		# 모든 타일의 글로벌 좌표 저장
		for cell in used_cells:
			var local_pos = dirt_layer.map_to_local(cell)
			var global_pos = dirt_layer.to_global(local_pos)
			all_tiles.append(global_pos)
		
		# 최대 인원 = 타일 수
		GameManager.max_worker_count = all_tiles.size()
		print("🌾 농장 초기화: 경작 타일 %d개 발견 -> 최대 일꾼 %d명" % [all_tiles.size(), GameManager.max_worker_count])
	else:
		print("⚠️ 경작된 흙(TileDirt) 레이어를 찾을 수 없습니다!")

func _process(delta: float) -> void:
	# 낮에만 작물이 자람
	if GameManager.is_daytime():
		current_growth_timer += delta
		
		# 수확 시기 도달
		if current_growth_timer >= GameManager.wheat_growth_time:
			# 작업자가 있어야 수확 가능
			if assigned_ratkins.size() > 0:
				harvest()

func harvest() -> void:
	# 수확량 계산
	var worker_count = assigned_ratkins.size()
	var efficiency = GameManager.calculate_efficiency()
	var total_yield = (GameManager.wheat_base_yield * worker_count) * efficiency * GameManager.worker_efficiency_multiplier
	
	GameManager.wheat += total_yield
	print("🌾 밀 수확! +%.1f (일꾼: %d, 효율: %.0f%%)" % [total_yield, worker_count, efficiency * 100])
	
	# 재파종 (타이머 리셋)
	current_growth_timer = 0.0

# 🆕 일꾼 배정 함수 (거리 기반)
func assign_worker(ratkin: Node2D) -> bool:
	if assigned_ratkins.size() >= all_tiles.size():
		print("농장이 가득 찼습니다!")
		return false
	
	# 일꾼 위치에서 가장 가까운 빈 타일 찾기
	var worker_pos = ratkin.position
	var best_tile_index = -1
	var best_distance = INF
	
	for i in range(all_tiles.size()):
		# 이미 배정된 타일은 건너뛰기
		if occupied_tiles.has(i):
			continue
		
		var distance = worker_pos.distance_to(all_tiles[i])
		if distance < best_distance:
			best_distance = distance
			best_tile_index = i
	
	if best_tile_index == -1:
		print("⚠️ 사용 가능한 타일을 찾을 수 없습니다!")
		return false
	
	# 배정
	assigned_ratkins.append(ratkin)
	occupied_tiles[best_tile_index] = ratkin
	ratkin.assigned_plot = self
	
	# 타일 중심으로 이동하도록 설정
	# target_position = 타일 글로벌 좌표 - Farm 노드 글로벌 좌표
	ratkin.target_position = all_tiles[best_tile_index] - global_position
	
	print("농장에 일꾼 배정됨. 타일 인덱스: %d, 현재 인원: %d/%d" % [best_tile_index, assigned_ratkins.size(), all_tiles.size()])
	return true

# 일꾼 해제 함수
func remove_worker(ratkin: Node2D) -> void:
	if ratkin in assigned_ratkins:
		assigned_ratkins.erase(ratkin)
		
		# occupied_tiles에서 제거
		for tile_index in occupied_tiles.keys():
			if occupied_tiles[tile_index] == ratkin:
				occupied_tiles.erase(tile_index)
				break
		
		ratkin.assigned_plot = null
		ratkin.target_position = Vector2.ZERO
		print("일꾼 배정 해제됨. 현재 인원: %d/%d" % [assigned_ratkins.size(), all_tiles.size()])
