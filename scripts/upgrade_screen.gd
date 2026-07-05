extends CanvasLayer

signal upgrade_chosen(id: String)

const UPGRADES := {
	"hp_up": {"title": "Sağlam Kökler", "desc": "Maksimum can +3", "rarity": "common"},
	"damage_up": {"title": "Keskin Kenar", "desc": "Tüm hasar +1", "rarity": "common"},
	"speed_up": {"title": "Hızlı Ayak", "desc": "Hareket hızı +0.6", "rarity": "common"},
	"dash_cd": {"title": "Çevik Beden", "desc": "Dash bekleme -0.2sn", "rarity": "common"},
	"attack_speed": {"title": "Hızlı Vuruş", "desc": "Saldırı hızı artar", "rarity": "common"},
	"rat_slayer": {"title": "Fare Avcısı", "desc": "Kör farelere +2 hasar", "rarity": "common"},
	"mushroom_slayer": {"title": "Mantar Kesici", "desc": "Mantar adamlara +2 hasar", "rarity": "common"},
	"hp_up_big": {"title": "Kadim Dayanıklılık", "desc": "Maksimum can +6", "rarity": "rare"},
	"damage_up_big": {"title": "Yıkıcı Güç", "desc": "Tüm hasar +3", "rarity": "rare"},
	"crit": {"title": "Ölümcül İsabet", "desc": "%20 kritik vuruş şansı (x2 hasar)", "rarity": "rare"},
	"lifesteal": {"title": "Kök Emici", "desc": "Her vuruşta 1 can çal", "rarity": "rare"},
	"guard_slayer": {"title": "Taş Kırıcı", "desc": "Taş muhafızlara +3 hasar", "rarity": "rare"},
	"charged_master": {"title": "Yüklü Usta", "desc": "Charged saldırı hasarı artar", "rarity": "rare"},
}

var _choices: Array = []

const RARE_CHANCE := 0.18


func setup(_unused := "") -> void:
	var commons: Array = []
	var rares: Array = []
	for id in UPGRADES:
		if UPGRADES[id]["rarity"] == "rare":
			rares.append(id)
		else:
			commons.append(id)
	commons.shuffle()
	rares.shuffle()

	_choices = []
	var used := {}
	var ci := 0
	var ri := 0
	while _choices.size() < 3 and (ci < commons.size() or ri < rares.size()):
		var pick_rare: bool = randf() < RARE_CHANCE and ri < rares.size()
		var id: String = ""
		if pick_rare:
			id = rares[ri]
			ri += 1
		elif ci < commons.size():
			id = commons[ci]
			ci += 1
		elif ri < rares.size():
			id = rares[ri]
			ri += 1
		if id != "" and not used.has(id):
			used[id] = true
			_choices.append(id)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root_control := Control.new()
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root_control)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.02, 0.04, 0.82)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	root_control.add_child(bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	root_control.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Bir Yol Seç"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	vbox.add_child(title)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 20)
	vbox.add_child(cards_row)

	for id in _choices:
		cards_row.add_child(_make_card(id))


func _make_card(id: String) -> Control:
	var data: Dictionary = UPGRADES[id]
	var is_rare: bool = data["rarity"] == "rare"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 280)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14) if is_rare else Color(0.10, 0.11, 0.10)
	style.border_color = Color(0.85, 0.65, 0.25) if is_rare else Color(0.4, 0.45, 0.4)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var rarity_label := Label.new()
	rarity_label.text = "NADİR" if is_rare else "YAYGIN"
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.3) if is_rare else Color(0.6, 0.65, 0.6))
	vb.add_child(rarity_label)

	var name_label := Label.new()
	name_label.text = String(data["title"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	vb.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = String(data["desc"])
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.78, 0.75))
	vb.add_child(desc_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)

	var pick_button := Button.new()
	pick_button.text = "Seç"
	pick_button.custom_minimum_size = Vector2(0, 44)
	pick_button.pressed.connect(_on_card_picked.bind(id))
	vb.add_child(pick_button)

	return panel


func _on_card_picked(id: String) -> void:
	upgrade_chosen.emit(id)
	queue_free()
