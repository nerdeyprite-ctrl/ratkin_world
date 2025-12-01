# bakery_plot.gd
# 제과점 시설 스크립트 (빵 생산)
extends Node2D

# 생산 관련 변수
var current_bake_timer: float = 0.0
var assigned_ratkins: Array = []

# 슬롯 위치
var slot_positions: Array[Vector2] = [
	Vector2(-30, 0),
	Vector2(30, 0)
]

# 필요 재료
var wheat_needed: float = 2.0 # 빵 1개당 밀 2개 소모 (밸런스 조절 가능)

func _process(delta: float) -> void:
	# 낮에만, 작업자가 있을 때만, 재료가 있을 때만 작동
	if GameManager.is_daytime() and assigned_ratkins.size() > 0:
		# 재료 확인 (굽기 시작 조건)
		# 이미 굽고 있는 중이라면 재료가 확보된 것으로 간주할 수도 있지만,
		# 여기서는 굽는 시간 동안 계속 재료가 필요한 게 아니라, 완료 시점에 소모하거나 시작 시점에 소모해야 함.
		# 계획서: "Check if GameManager.wheat >= (needed amount)... Only if Wheat exists: Increment timer."
		# "Consume Inventory... Reset timer." (완료 시 소모)
		
		# 완료 시점에 소모하면 굽는 도중에 재료를 팔아버릴 수 있는 문제가 있음.
		# 하지만 간단하게 구현하기 위해 계획서대로 진행: 재료가 있어야 타이머가 감.
		
		if GameManager.wheat >= wheat_needed:
			current_bake_timer += delta
			
			if current_bake_timer >= GameManager.bread_bake_time:
				bake_bread()
		else:
			# 재료 부족 시 타이머 멈춤 (또는 리셋? 보통은 멈춤)
			pass

func bake_bread() -> void:
	# 재료 소모
	if GameManager.wheat >= wheat_needed:
		GameManager.wheat -= wheat_needed
		
		# 생산량 계산
		var cook_count = assigned_ratkins.size()
		var efficiency = GameManager.calculate_efficiency()
		
		# 요리사 업그레이드? GameManager에는 cook_hunger_restore 업그레이드만 있음.
		# 요리사 효율 배수는 따로 없으나, 필요하다면 추가 가능. 일단 기본 효율만 적용.
		var total_yield = (GameManager.bread_base_yield * cook_count) * efficiency
		
		GameManager.bread += total_yield
		print("🍞 빵 굽기 완료! +%.1f (요리사: %d, 소모 밀: %.1f)" % [total_yield, cook_count, wheat_needed])
		
		# 타이머 리셋
		current_bake_timer = 0.0

# 요리사 배정 함수
func assign_worker(ratkin: Node2D) -> bool:
	if assigned_ratkins.size() < slot_positions.size():
		assigned_ratkins.append(ratkin)
		ratkin.assigned_plot = self
		
		# 빈 슬롯 위치 할당
		var slot_index = assigned_ratkins.size() - 1
		ratkin.target_position = slot_positions[slot_index]
		
		print("제과점에 요리사 배정됨. 현재 인원: %d" % assigned_ratkins.size())
		return true
	else:
		print("제과점이 가득 찼습니다!")
		return false

func remove_worker(ratkin: Node2D) -> void:
	if ratkin in assigned_ratkins:
		assigned_ratkins.erase(ratkin)
		ratkin.assigned_plot = null
		ratkin.target_position = Vector2.ZERO
		reassign_slots()

func reassign_slots() -> void:
	for i in range(assigned_ratkins.size()):
		assigned_ratkins[i].target_position = slot_positions[i]
