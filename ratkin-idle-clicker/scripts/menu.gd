# menu.gd
# 메인 메뉴 스크립트

extends Control

@onready var new_game_button: Button = $CenterContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	# 버튼 시그널 연결
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 저장 파일 존재 여부 확인
	if FileAccess.file_exists(GameManager.SAVE_PATH):
		continue_button.disabled = false
		print("저장 파일 발견! 이어하기 가능")
	else:
		continue_button.disabled = true
		print("저장 파일 없음. 이어하기 불가")

func _on_new_game_pressed() -> void:
	print("새로 시작 클릭")
	# 게임 리셋
	GameManager.reset_game()
	# 메인 게임 씬으로 전환
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_continue_pressed() -> void:
	print("이어하기 클릭")
	# 게임 불러오기
	if GameManager.load_game():
		# 메인 게임 씬으로 전환
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		print("게임 불러오기 실패!")

func _on_quit_pressed() -> void:
	print("게임 종료 클릭")
	get_tree().quit()
