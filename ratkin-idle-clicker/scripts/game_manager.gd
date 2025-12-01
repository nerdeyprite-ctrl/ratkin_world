# game_manager.gd
# 게임의 핵심 데이터를 관리하는 스크립트
extends Node

# 시그널 선언 (extends Node 아래)
signal ratkin_spawned(job: int)

enum RatkinJob { WORKER, PRIEST, COOK }

# ========================================
# 변수 선언부
# ========================================

# 게임 자원들
var money: float = 600.0  # 화폐
var wheat: float = 0.0    # 밀
var bread: float = 0.0    # 빵

# 시간 시스템
var time: float = 0.0
const DAY_LENGTH: float = 120.0

# 랫킨 관련
var ratkin_count: int = 0  # 현재 랫킨 수 (총합)
var worker_count: int = 0  # 일꾼 수
var priest_count: int = 0  # 수녀 수
var cook_count: int = 0  # 요리사 수

# 고용 비용
var worker_cost: float = 10.0  # 일꾼 1마리 구매 비용
var priest_cost: float = 50.0  # 수녀 1마리 구매 비용
var cook_cost: float = 30.0    # 요리사 1마리 구매 비용 (초기값 수정됨)

# 🆕 최대 고용 가능 인원 (인프라 슬롯 제한)
# 농장 슬롯 3개, 제과점 슬롯 2개에 맞춤 (나중에 인프라 업그레이드 시 증가 가능)
var max_worker_count: int = 3
var max_cook_count: int = 2
# 수녀는 일단 제한 없음 (또는 적절히 설정)
var max_priest_count: int = 0

# 생산 밸런스 상수
var wheat_growth_time: float = 5.0 # 성장 시간 (초)
var wheat_base_yield: float = 1.0  # 일꾼당 기본 수확량
var bread_bake_time: float = 8.0   # 굽는 시간 (초)
var bread_base_yield: float = 1.0  # 요리사당 기본 생산량

# 업그레이드 시스템
var worker_level: int = 1  # 일꾼 업그레이드 레벨
var priest_level: int = 1  # 수녀 업그레이드 레벨
var cook_level: int = 1  # 요리사 업그레이드 레벨
var worker_upgrade_cost: float = 100.0  # 일꾼 업그레이드 비용
var priest_upgrade_cost: float = 500.0  # 수녀 업그레이드 비용
var cook_upgrade_cost: float = 300.0  # 요리사 업그레이드 비용
var worker_efficiency_multiplier: float = 1.0  # 일꾼 효율 배수
var priest_efficiency_multiplier: float = 1.0  # 수녀 효율 배수
var cook_hunger_restore: float = 5.0  # 요리사 10초당 배고픔 회복량 (기존 로직 유지 여부 확인 필요하나 일단 유지)

# ========================================
# 🆕 배고픔/재미 시스템
# ========================================
var hunger: float = 100.0  # 배고픔 (0~100, 100이 배부름)
var fun: float = 100.0  # 재미 (0~100, 100이 즐거움)

# 감소 속도 (초당)
var hunger_decay_rate: float = 2.0  # 초당 2씩 감소
var fun_decay_rate: float = 1.5  # 초당 1.5씩 감소

# 임계값 (이 값 아래로 떨어지면 효율 감소 시작)
var hunger_threshold: float = 30.0  # 배고픔 30 이하
var fun_threshold: float = 30.0  # 재미 30 이하

# 최소 효율 (아무리 낮아도 이 값 이상 유지)
var min_efficiency: float = 0.1  # 10% (거의 일 안함)

# 음식/오락 관련 (판매/소비 로직으로 변경됨에 따라 일부 미사용 될 수 있음)
var food_restore: float = 30.0  # 밀 섭취 시 회복량
var bread_restore: float = 50.0 # 빵 섭취 시 회복량 (재미도 증가)
var entertainment_restore: float = 25.0  # 오락 회복량

# ========================================
# 🆕 타이머 변수
# ========================================
# income_timer 삭제됨
var cook_timer: float = 0.0  # 요리사 배고픔 회복 타이머 (기존 로직 유지용)

# ========================================
# 저장/불러오기 시스템
# ========================================
const SAVE_PATH = "user://savegame.dat"

# ========================================
# 초기화
# ========================================
func _ready() -> void:
	print("GameManager 초기화 완료!")
	print("초기 돈: ", money)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 게임 종료 시 자동 저장
		save_game()
		print("게임 자동 저장 완료")

# ========================================
# 매 프레임 업데이트
# ========================================
func _process(delta: float) -> void:
	# 시간 흐름 (낮/밤 주기)
	time += delta
	if time >= DAY_LENGTH:
		time = 0.0
		print("🌞 새로운 하루가 시작되었습니다!")

	# 배고픔/재미 감소 (부드럽게 매 프레임)
	update_needs(delta)
	
	# 🆕 10초마다 요리사가 배고픔 회복 (기존 로직 유지 - 빵 생산과는 별개로 보너스 개념으로 둘지 고민 필요하지만 일단 유지)
	if cook_count > 0:
		cook_timer += delta
		if cook_timer >= 10.0:
			cook_timer -= 10.0
			var total_restore = cook_count * cook_hunger_restore
			hunger += total_restore
			hunger = clamp(hunger, 0.0, 100.0)
			# print("🍳 요리사가 간식을 만들었습니다! 배고픔 +%.1f" % total_restore)

# ========================================
# 시간 시스템 함수
# ========================================
func is_daytime() -> bool:
	return time < (DAY_LENGTH / 2.0)

# ========================================
# 배고픔/재미 업데이트
# ========================================
func update_needs(delta: float) -> void:
	# 랫킨이 있을 때만 감소
	if ratkin_count > 0:
		# 배고픔 감소 (랫킨 수에 비례)
		hunger -= hunger_decay_rate * ratkin_count * delta * 0.01
		hunger = clamp(hunger, 0.0, 100.0)
		
		# 재미 감소 (랫킨 수에 비례)
		fun -= fun_decay_rate * ratkin_count * delta * 0.01
		fun = clamp(fun, 0.0, 100.0)

# ========================================
# 효율 계산 (0.0 ~ 1.0)
# ========================================
func calculate_efficiency() -> float:
	# 랫킨이 없으면 효율 0
	if ratkin_count == 0:
		return 0.0
	
	# 배고픔 효율 계산
	var hunger_eff = 1.0
	if hunger < hunger_threshold:
		hunger_eff = lerp(min_efficiency, 1.0, hunger / hunger_threshold)
	
	# 재미 효율 계산
	var fun_eff = 1.0
	if fun < fun_threshold:
		fun_eff = lerp(min_efficiency, 1.0, fun / fun_threshold)
	
	# 두 효율의 평균
	var total_eff = (hunger_eff + fun_eff) / 2.0
	
	return total_eff

# ========================================
# 랫킨 추가 함수 (첫 고용 무료 로직 적용)
# ========================================
# 일꾼
func add_worker() -> bool:
	# 🆕 최대 인원 체크
	if worker_count >= max_worker_count:
		print("일꾼 고용 불가: 농장 슬롯이 가득 찼습니다! (%d/%d)" % [worker_count, max_worker_count])
		return false

	var current_cost = worker_cost
	if ratkin_count == 0:
		current_cost = 0.0
		
	if money >= current_cost:
		money -= current_cost
		ratkin_count += 1
		worker_count += 1
		
		# 비용 증가 (첫 고용이 무료였어도 다음 비용은 증가된 상태로 적용할지, 아니면 원래 비용부터 시작할지? 
		# 여기서는 일단 원래 비용 로직을 따르되, 무료일 때는 비용 차감만 안함)
		
		# 기본 비용 증가
		worker_cost *= 1.15
		
		# 5명 단위 비용 점프 (5, 10, 15, ...)
		if worker_count % 5 == 0:
			worker_cost *= 3.0
			print("⚠️ 일꾼 %d명 도달! 다음 고용 비용 대폭 증가!" % worker_count)
		
		# WORKER 직업으로 시그널 발송
		ratkin_spawned.emit(GameManager.RatkinJob.WORKER) 
		
		print("일반 랫킨 추가! (총 %d명)" % worker_count)
		return true
	else:
		print("돈이 부족합니다!")
		return false

# 성직자
func add_priest() -> bool:
	# 🆕 최대 인원 체크
	if priest_count >= max_priest_count:
		print("수녀 고용 불가: 최대 인원 도달! (%d/%d)" % [priest_count, max_priest_count])
		return false

	var current_cost = priest_cost
	if ratkin_count == 0:
		current_cost = 0.0

	if money >= current_cost:
		money -= current_cost
		ratkin_count += 1
		priest_count += 1
		
		# 기본 비용 증가
		priest_cost *= 1.3
		
		# 5명 단위 비용 점프
		if priest_count % 5 == 0:
			priest_cost *= 3.0
			print("⚠️ 수녀 %d명 도달! 다음 고용 비용 대폭 증가!" % priest_count)
		
		# PRIEST 직업으로 시그널 발송
		ratkin_spawned.emit(GameManager.RatkinJob.PRIEST)
		
		print("성직자 랫킨 추가! (총 %d명)" % priest_count)
		return true
	else:
		print("돈이 부족합니다!")
		return false

# 요리사
func add_cook() -> bool:
	# 🆕 최대 인원 체크
	if cook_count >= max_cook_count:
		print("요리사 고용 불가: 제과점 슬롯이 가득 찼습니다! (%d/%d)" % [cook_count, max_cook_count])
		return false

	var current_cost = cook_cost
	if ratkin_count == 0:
		current_cost = 0.0

	if money >= current_cost:
		money -= current_cost
		ratkin_count += 1
		cook_count += 1
		
		# 기본 비용 증가 (요리사는 더 빠르게 증가)
		cook_cost *= 1.5
		
		# 5명 단위 비용 점프
		if cook_count % 5 == 0:
			cook_cost *= 3.0
			print("⚠️ 요리사 %d명 도달! 다음 고용 비용 대폭 증가!" % cook_count)
		
		# COOK 직업으로 시그널 발송
		ratkin_spawned.emit(GameManager.RatkinJob.COOK)
		
		print("요리사 랫킨 추가! (총 %d명)" % cook_count)
		return true
	else:
		print("돈이 부족합니다!")
		return false

# ========================================
# 경제 함수 (판매/소비)
# ========================================
func sell_wheat(amount: float = 1.0) -> bool:
	if wheat >= amount:
		wheat -= amount
		money += 1.0 * amount # 밀 1개당 1골드
		print("밀 판매: +%.0fG" % (1.0 * amount))
		return true
	return false

func sell_bread(amount: float = 1.0) -> bool:
	if bread >= amount:
		bread -= amount
		money += 5.0 * amount # 빵 1개당 5골드
		print("빵 판매: +%.0fG" % (5.0 * amount))
		return true
	return false

func consume_food(type: String) -> bool:
	if type == "wheat":
		if wheat >= 1.0:
			wheat -= 1.0
			hunger += food_restore
			fun -= 5.0 # 생밀을 먹으면 재미 감소
			hunger = clamp(hunger, 0.0, 100.0)
			fun = clamp(fun, 0.0, 100.0)
			print("밀 섭취: 배고픔 회복, 재미 감소")
			return true
	elif type == "bread":
		if bread >= 1.0:
			bread -= 1.0
			hunger += bread_restore
			fun += 10.0 # 빵을 먹으면 재미 증가
			hunger = clamp(hunger, 0.0, 100.0)
			fun = clamp(fun, 0.0, 100.0)
			print("빵 섭취: 배고픔 대폭 회복, 재미 증가")
			return true
	return false

# ========================================
# 업그레이드 함수
# ========================================
func upgrade_worker() -> bool:
	if money >= worker_upgrade_cost:
		money -= worker_upgrade_cost
		worker_level += 1
		worker_efficiency_multiplier = 1.0 + (worker_level - 1) * 0.5  # 레벨당 +50%
		worker_upgrade_cost *= 2.0  # 업그레이드 비용 2배 증가
		
		print("일꾼 업그레이드! 레벨: %d, 효율: %.1f%%" % [worker_level, worker_efficiency_multiplier * 100])
		return true
	else:
		print("돈이 부족합니다!")
		return false

func upgrade_priest() -> bool:
	if money >= priest_upgrade_cost:
		money -= priest_upgrade_cost
		priest_level += 1
		priest_efficiency_multiplier = 1.0 + (priest_level - 1) * 0.5  # 레벨당 +50%
		priest_upgrade_cost *= 2.0  # 업그레이드 비용 2배 증가
		
		print("수녀 업그레이드! 레벨: %d, 효율: %.1f%%" % [priest_level, priest_efficiency_multiplier * 100])
		return true
	else:
		print("돈이 부족합니다!")
		return false

func upgrade_cook() -> bool:
	if money >= cook_upgrade_cost:
		money -= cook_upgrade_cost
		cook_level += 1
		cook_hunger_restore = 5.0 + (cook_level - 1) * 1.0  # 레벨당 +1 회복량
		cook_upgrade_cost *= 2.0  # 업그레이드 비용 2배 증가
		
		print("요리사 업그레이드! 레벨: %d, 10초당 회복량: %.1f" % [cook_level, cook_hunger_restore])
		return true
	else:
		print("돈이 부족합니다!")
		return false

# ========================================
# Getter 함수들
# ========================================
func get_money() -> float:
	return money

func get_money_per_second() -> float:
	# 더 이상 자동 수입이 없으므로 0 반환하거나, 예상 생산 가치를 반환할 수도 있음.
	# UI 호환성을 위해 0 반환.
	return 0.0

func get_actual_income() -> float:
	return 0.0

func get_hunger() -> float:
	return hunger

func get_fun() -> float:
	return fun

func get_efficiency() -> float:
	return calculate_efficiency()

# ========================================
# 저장/불러오기 함수
# ========================================
func save_game() -> void:
	var save_data = {
		"money": money,
		"wheat": wheat,
		"bread": bread,
		"time": time,
		"worker_count": worker_count,
		"priest_count": priest_count,
		"cook_count": cook_count,
		"worker_level": worker_level,
		"priest_level": priest_level,
		"cook_level": cook_level,
		"worker_cost": worker_cost,
		"priest_cost": priest_cost,
		"cook_cost": cook_cost,
		"worker_upgrade_cost": worker_upgrade_cost,
		"priest_upgrade_cost": priest_upgrade_cost,
		"cook_upgrade_cost": cook_upgrade_cost,
		"worker_efficiency_multiplier": worker_efficiency_multiplier,
		"priest_efficiency_multiplier": priest_efficiency_multiplier,
		"cook_hunger_restore": cook_hunger_restore,
		"hunger": hunger,
		"fun": fun
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(save_data)
		file.store_string(json_string)
		file.close()
		print("게임 저장 성공: ", SAVE_PATH)
	else:
		print("저장 실패!")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("저장 파일이 없습니다.")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		print("파일 읽기 실패!")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("저장 파일 파싱 실패!")
		return false
	
	var save_data = json.data
	
	# 데이터 복원 (없는 키는 기본값 사용)
	money = save_data.get("money", 600.0)
	wheat = save_data.get("wheat", 0.0)
	bread = save_data.get("bread", 0.0)
	time = save_data.get("time", 0.0)
	
	worker_count = save_data.get("worker_count", 0)
	priest_count = save_data.get("priest_count", 0)
	cook_count = save_data.get("cook_count", 0)
	ratkin_count = worker_count + priest_count + cook_count
	
	worker_level = save_data.get("worker_level", 1)
	priest_level = save_data.get("priest_level", 1)
	cook_level = save_data.get("cook_level", 1)
	
	worker_cost = save_data.get("worker_cost", 10.0)
	priest_cost = save_data.get("priest_cost", 50.0)
	cook_cost = save_data.get("cook_cost", 30.0)
	
	worker_upgrade_cost = save_data.get("worker_upgrade_cost", 100.0)
	priest_upgrade_cost = save_data.get("priest_upgrade_cost", 500.0)
	cook_upgrade_cost = save_data.get("cook_upgrade_cost", 300.0)
	
	worker_efficiency_multiplier = save_data.get("worker_efficiency_multiplier", 1.0)
	priest_efficiency_multiplier = save_data.get("priest_efficiency_multiplier", 1.0)
	cook_hunger_restore = save_data.get("cook_hunger_restore", 5.0)
	
	hunger = save_data.get("hunger", 100.0)
	fun = save_data.get("fun", 100.0)
	
	print("게임 불러오기 성공!")
	return true

func reset_game() -> void:
	# 모든 변수를 초기값으로 리셋
	money = 600.0
	wheat = 0.0
	bread = 0.0
	time = 0.0
	
	worker_count = 0
	priest_count = 0
	cook_count = 0
	ratkin_count = 0
	
	worker_level = 1
	priest_level = 1
	cook_level = 1
	
	worker_cost = 10.0
	priest_cost = 50.0
	cook_cost = 30.0
	
	worker_upgrade_cost = 100.0
	priest_upgrade_cost = 500.0
	cook_upgrade_cost = 300.0
	
	worker_efficiency_multiplier = 1.0
	priest_efficiency_multiplier = 1.0
	cook_hunger_restore = 5.0
	
	hunger = 100.0
	fun = 100.0
	
	print("게임 리셋 완료!")
