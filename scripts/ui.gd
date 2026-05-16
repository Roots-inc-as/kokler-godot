extends CanvasLayer

@onready var hp_label: Label = $HPLabel
@onready var key_label: Label = $KeyLabel
@onready var dash_label: Label = $DashLabel
@onready var message_label: Label = $MessageLabel
@onready var victory_panel: ColorRect = $VictoryPanel
@onready var victory_label: Label = $VictoryPanel/VictoryLabel

var message_token := 0


func _ready() -> void:
	add_to_group("ui_2_5d")
	# ... gerisi aynı kalır
	set_hp(5, 5)
	set_key_status(false)
	set_dash_ready(true, 0.0)
	message_label.visible = false
	victory_panel.visible = false


func set_hp(current_hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [current_hp, max_hp]


func set_key_status(has_key: bool) -> void:
	key_label.text = "Anahtar: Alındı" if has_key else "Anahtar: Yok"


func set_dash_ready(is_ready: bool, remaining: float) -> void:
	dash_label.text = "Dash: Hazır" if is_ready else "Dash: %.1f" % remaining


func show_message(text: String, duration := 3.0) -> void:
	message_token += 1
	var token := message_token
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(duration).timeout
	if token == message_token and not victory_panel.visible:
		message_label.visible = false


func show_victory(text: String) -> void:
	message_token += 1
	victory_label.text = text
	victory_panel.visible = true
	message_label.visible = false


func show_death(text: String) -> void:
	show_message(text, 1.0)

# ─── HIT FLASH ───
@onready var hit_flash: ColorRect = %HitFlash

func flash_damage() -> void:
	if hit_flash == null:
		return
	hit_flash.color = Color(1.0, 0.0, 0.0, 0.15)
	var tween := create_tween()
	tween.tween_property(hit_flash, "color:a", 0.0, 0.5)
