# ui.gd
# UI 요소들을 제어하는 스크립트

extends Control

# ========================================
# 노드 참조 변수
# ========================================
# 기존 UI
@onready var money_label: Label = $TopLeftInfo/VBoxContainer/MoneyLabel
@onready var income_label: Label = $TopLeftInfo/VBoxContainer/IncomeLabel # 재활용: 자원 정보 표시

@onready var buy_worker_button: Button = $BottomCenterButtons/HBoxContainer/WorkerPanel/BuyWorkerButton
@onready var buy_priest_button: Button = $BottomCenterButtons/HBoxContainer/PriestPanel/BuyPriestButton
@onready var upgrade_worker_button: Button = $BottomCenterButtons/HBoxContainer/WorkerPanel/UpgradeWorkerButton
@onready var upgrade_priest_button: Button = $BottomCenterButtons/HBoxContainer/PriestPanel/UpgradePriestButton
@onready var buy_cook_button: Button = $BottomCenterButtons/HBoxContainer/CookPanel/BuyCookButton
@onready var upgrade_cook_button: Button = $BottomCenterButtons/HBoxContainer/CookPanel/UpgradeCookButton

# 🆕 새로운 UI 요소들
@onready var efficiency_label: Label = $TopLeftInfo/VBoxContainer/EfficiencyLabel

@onready var hunger_label: Label = $TopLeftInfo/VBoxContainer/HungerContainer/HungerLabel
@onready var hunger_bar: ProgressBar = $TopLeftInfo/VBoxContainer/HungerContainer/HungerBar

@onready var fun_label: Label = $TopLeftInfo/VBoxContainer/FunContainer/FunLabel
@onready var fun_bar: ProgressBar = $TopLeftInfo/VBoxContainer/FunContainer/FunBar

# 버튼 재활용 (이름은 그대로 두고 기능만 변경)
@onready var buy_food_button: Button = $TopLeftInfo/VBoxContainer/BuyFoodButton # -> 밀 판매 버튼
@onready var buy_entertainment_button: Button = $TopLeftInfo/VBoxContainer/BuyEntertainmentButton # -> 빵 판매 버튼

# 설정 버튼 및 팝업
@onready var settings_button: Button = $SettingsButton
@onready var settings_popup: Panel = $SettingsPopup
@onready var save_and_quit_button: Button = $SettingsPopup/VBoxContainer/MarginContainer/VBox/SaveAndQuitButton

# 🆕 낮/밤 토글 버튼 (임시 테스트용)
var day_night_toggle_button: Button

# ========================================
# 초기화
# ========================================
func _ready() -> void:
	# 🆕 낮/밤 토글 버튼 생성
	day_night_toggle_button = Button.new()
	day_night_toggle_button.text = "🌞 낮/밤 전환 (테스트)"
	day_night_toggle_button.position = Vector2(10, 10)
	day_night_toggle_button.size = Vector2(200, 40)
	add_child(day_night_toggle_button)
	day_night_toggle_button.pressed.connect(_on_day_night_toggle_pressed)
	
	# 버튼 시그널 연결
	buy_worker_button.pressed.connect(_on_buy_worker_button_pressed)
	buy_priest_button.pressed.connect(_on_buy_priest_button_pressed)
	upgrade_worker_button.pressed.connect(_on_upgrade_worker_button_pressed)
	upgrade_priest_button.pressed.connect(_on_upgrade_priest_button_pressed)
	buy_cook_button.pressed.connect(_on_buy_cook_button_pressed)
	upgrade_cook_button.pressed.connect(_on_upgrade_cook_button_pressed)
	
	# 🆕 기능 변경된 버튼 연결
	buy_food_button.pressed.connect(_on_sell_wheat_button_pressed)
	buy_entertainment_button.pressed.connect(_on_sell_bread_button_pressed)
	
	# 설정 버튼 시그널 연결
	settings_button.pressed.connect(_on_settings_button_pressed)
	save_and_quit_button.pressed.connect(_on_save_and_quit_button_pressed)
	
	print("UI 초기화 완료!")

# ========================================
# 매 프레임 업데이트
# ========================================
func _process(_delta: float) -> void:
	update_ui()

# ========================================
# UI 업데이트 함수
# ========================================
func update_ui() -> void:
	# 화폐 표시
	money_label.text = "💰 돈: %.0f" % GameManager.get_money()
	
	# 🆕 자원 및 시간 표시 (IncomeLabel 재활용)
	var time_str = "낮 ☀️" if GameManager.is_daytime() else "밤 🌙"
	income_label.text = "🌾 밀: %.0f | 🍞 빵: %.0f | 시간: %s" % [GameManager.wheat, GameManager.bread, time_str]
	
	# 효율 표시
	var efficiency = GameManager.get_efficiency()
	var efficiency_percent = efficiency * 100.0
	efficiency_label.text = "⚡ 효율: %.0f%%" % efficiency_percent
	
	# 효율 색상
	if efficiency >= 0.8:
		efficiency_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	elif efficiency >= 0.5:
		efficiency_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	else:
		efficiency_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	
	# 배고픔 게이지
	var hunger = GameManager.get_hunger()
	hunger_label.text = "🍚 배고픔: %.0f/100" % hunger
	hunger_bar.value = hunger
	
	# 재미 게이지
	var fun = GameManager.get_fun()
	fun_label.text = "😊 재미: %.0f/100" % fun
	fun_bar.value = fun
	
	# 🆕 밀 판매 버튼 (구 음식 구매 버튼)
	buy_food_button.text = "🌾 밀 판매 (+1G)"
	if GameManager.wheat < 1.0:
		buy_food_button.disabled = true
	else:
		buy_food_button.disabled = false
	
	# 🆕 빵 판매 버튼 (구 오락 구매 버튼)
	buy_entertainment_button.text = "🍞 빵 판매 (+5G)"
	if GameManager.bread < 1.0:
		buy_entertainment_button.disabled = true
	else:
		buy_entertainment_button.disabled = false
	
	# 일꾼 랫킨 고용 버튼
	var w_cost = GameManager.worker_cost
	if GameManager.ratkin_count == 0:
		w_cost = 0 # 첫 고용 무료 표시
	
	if GameManager.worker_count >= GameManager.max_worker_count:
		buy_worker_button.text = "🐭 일꾼 고용 (MAX) [%d/%d]" % [GameManager.worker_count, GameManager.max_worker_count]
		buy_worker_button.disabled = true
	else:
		buy_worker_button.text = "🐭 일꾼 고용 (비용: %.0f) [%d/%d]" % [w_cost, GameManager.worker_count, GameManager.max_worker_count]
		if GameManager.get_money() < w_cost:
			buy_worker_button.disabled = true
		else:
			buy_worker_button.disabled = false
	
	# 일꾼 업그레이드 버튼
	upgrade_worker_button.text = "⬆️ 일꾼 업그레이드 Lv.%d (비용: %.0f)" % [GameManager.worker_level, GameManager.worker_upgrade_cost]
	if GameManager.get_money() < GameManager.worker_upgrade_cost or GameManager.worker_count == 0:
		upgrade_worker_button.disabled = true
	else:
		upgrade_worker_button.disabled = false
	
	# 수녀 랫킨 버튼
	var p_cost = GameManager.priest_cost
	if GameManager.ratkin_count == 0:
		p_cost = 0
		
	if GameManager.priest_count >= GameManager.max_priest_count:
		buy_priest_button.text = "🙏 수녀 고용 (MAX) [%d/%d]" % [GameManager.priest_count, GameManager.max_priest_count]
		buy_priest_button.disabled = true
	else:
		buy_priest_button.text = "🙏 수녀 고용 (비용: %.0f) [%d/%d]" % [p_cost, GameManager.priest_count, GameManager.max_priest_count]
		if GameManager.get_money() < p_cost:
			buy_priest_button.disabled = true
		else:
			buy_priest_button.disabled = false
	
	# 수녀 업그레이드 버튼
	upgrade_priest_button.text = "⬆️ 수녀 업그레이드 Lv.%d (비용: %.0f)" % [GameManager.priest_level, GameManager.priest_upgrade_cost]
	if GameManager.get_money() < GameManager.priest_upgrade_cost or GameManager.priest_count == 0:
		upgrade_priest_button.disabled = true
	else:
		upgrade_priest_button.disabled = false
	
	# 요리사 고용 버튼
	var c_cost = GameManager.cook_cost
	if GameManager.ratkin_count == 0:
		c_cost = 0
		
	if GameManager.cook_count >= GameManager.max_cook_count:
		buy_cook_button.text = "🍳 요리사 고용 (MAX) [%d/%d]" % [GameManager.cook_count, GameManager.max_cook_count]
		buy_cook_button.disabled = true
	else:
		buy_cook_button.text = "🍳 요리사 고용 (비용: %.0f) [%d/%d]" % [c_cost, GameManager.cook_count, GameManager.max_cook_count]
		if GameManager.get_money() < c_cost:
			buy_cook_button.disabled = true
		else:
			buy_cook_button.disabled = false
	
	# 요리사 업그레이드 버튼
	upgrade_cook_button.text = "⬆️ 요리사 업그레이드 Lv.%d (비용: %.0f)" % [GameManager.cook_level, GameManager.cook_upgrade_cost]
	if GameManager.get_money() < GameManager.cook_upgrade_cost or GameManager.cook_count == 0:
		upgrade_cook_button.disabled = true
	else:
		upgrade_cook_button.disabled = false

# ========================================
# 버튼 클릭 이벤트 처리
# ========================================
func _on_buy_worker_button_pressed() -> void:
	var success = GameManager.add_worker()
	if success:
		print("UI: 일꾼 구매 성공!")

func _on_buy_priest_button_pressed() -> void:
	var success = GameManager.add_priest()
	if success:
		print("UI: 수녀 구매 성공!")

func _on_upgrade_worker_button_pressed() -> void:
	var success = GameManager.upgrade_worker()
	if success:
		print("UI: 일꾼 업그레이드 성공!")

func _on_upgrade_priest_button_pressed() -> void:
	var success = GameManager.upgrade_priest()
	if success:
		print("UI: 수녀 업그레이드 성공!")

func _on_buy_cook_button_pressed() -> void:
	var success = GameManager.add_cook()
	if success:
		print("UI: 요리사 구매 성공!")

func _on_upgrade_cook_button_pressed() -> void:
	var success = GameManager.upgrade_cook()
	if success:
		print("UI: 요리사 업그레이드 성공!")

# 🆕 밀 판매
func _on_sell_wheat_button_pressed() -> void:
	var success = GameManager.sell_wheat()
	if success:
		print("UI: 밀 판매 성공!")

# 🆕 빵 판매
func _on_sell_bread_button_pressed() -> void:
	var success = GameManager.sell_bread()
	if success:
		print("UI: 빵 판매 성공!")

# 🆕 낮/밤 토글 (테스트용)
func _on_day_night_toggle_pressed() -> void:
	# 낮이면 밤으로, 밤이면 낮으로 전환
	if GameManager.is_daytime():
		GameManager.time = GameManager.DAY_LENGTH / 2.0 + 1.0  # 밤으로
		print("🌙 밤으로 전환")
	else:
		GameManager.time = 0.0  # 낮으로
		print("🌞 낮으로 전환")

func _on_settings_button_pressed() -> void:
	settings_popup.visible = not settings_popup.visible

func _on_save_and_quit_button_pressed() -> void:
	print("저장 후 나가기 클릭")
	GameManager.save_game()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
