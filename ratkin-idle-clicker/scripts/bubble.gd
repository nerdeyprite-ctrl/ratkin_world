extends Node2D

@onready var label: Label = $PanelContainer/MarginContainer/Label
@onready var panel: PanelContainer = $PanelContainer

# 최대 너비 설정 (이 값을 넘으면 줄바꿈)
const MAX_WIDTH = 200.0

func _ready() -> void:
	print("Bubble: _ready 호출됨")
	# 2초 후 자동 삭제
	await get_tree().create_timer(2.0).timeout
	
	# 페이드 아웃 효과
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func set_message(msg: String) -> void:
	print("Bubble: set_message 호출됨. 메시지: ", msg)
	# 1. 먼저 텍스트 설정
	label.text = msg
	
	# 2. 초기화: 줄바꿈 끄고 최소 너비 해제
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 0
	
	# 3. 텍스트 너비 계산 (안전하게 처리)
	var text_width = 0.0
	var font = label.get_theme_font("font")
	var font_size = label.get_theme_font_size("font_size")
	
	if font:
		text_width = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	else:
		# 폰트를 못 가져올 경우 대략적인 계산 (글자당 10px 가정)
		text_width = msg.length() * 10.0
	
	# 4. 너비 체크 및 설정
	if text_width > MAX_WIDTH:
		# 최대 너비 초과 시: 줄바꿈 켜고 너비 제한
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = MAX_WIDTH
	
	# 5. 위치 조정 (중앙 정렬을 위해 PanelContainer 위치 재조정)
	# 텍스트 설정 후 레이아웃이 갱신될 때까지 기다려야 정확한 크기를 알 수 있음
	await get_tree().process_frame
	_update_position()

func _update_position() -> void:
	# 패널의 크기만큼 위로, 왼쪽으로 이동하여 중앙 정렬 맞춤
	if panel:
		# 앵커 프리셋이 Node2D 아래에서는 의도대로 동작하지 않을 수 있으므로 직접 위치 보정
		panel.position.x = -panel.size.x / 2
		panel.position.y = -panel.size.y
