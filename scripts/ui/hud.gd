class_name Hud
extends CanvasLayer
## 介面。全部以程式建立，方便之後替換成 GPT 生成的 UI 美術（見 docs/ART_PROMPTS.md）。

signal new_game_pressed
signal continue_pressed
signal finish_pressed

var status_label: RichTextLabel
var steps_label: RichTextLabel
var tool_label: RichTextLabel
var measure_label: RichTextLabel
var log_label: RichTextLabel
var select_panel: PanelContainer
var result_panel: PanelContainer
var result_label: RichTextLabel
var help_panel: PanelContainer
var tool_icon: TextureRect
var _logs: Array[String] = []
var continue_button: Button
var finish_button: Button
var rack: RackUI
var computer: ComputerUI

func _ready() -> void:
	var font_path := "res://assets/fonts/NotoSansTC-Regular.ttf"
	var theme := Theme.new()
	if ResourceLoader.exists(font_path):
		theme.default_font = load(font_path)
	theme.default_font_size = 17
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	status_label = _panel(root, Vector2(16, 16), Vector2(430, 0))
	steps_label = _panel(root, Vector2(-436, 16), Vector2(420, 0), true)
	measure_label = _panel(root, Vector2(-436, 430), Vector2(420, 0), true)
	tool_label = _panel(root, Vector2(16, -250), Vector2(640, 0), false, true)
	log_label = _panel(root, Vector2(-760, -250), Vector2(744, 0), true, true)

	tool_icon = TextureRect.new()
	tool_icon.custom_minimum_size = Vector2(72, 72)
	tool_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tool_icon.position = Vector2(462, 16)
	tool_icon.size = Vector2(72, 72)
	root.add_child(tool_icon)

	rack = RackUI.new()
	rack.visible = false
	root.add_child(rack)
	computer = ComputerUI.new()
	computer.visible = false
	root.add_child(computer)
	_build_title(root)
	_build_result(root)
	_build_help(root)

func _panel(root: Control, pos: Vector2, sz: Vector2, right := false, bottom := false) -> RichTextLabel:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.04, 0.78)
	sb.border_color = Color(0.55, 0.40, 0.22, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right:
		pc.anchor_left = 1.0
		pc.anchor_right = 1.0
	if bottom:
		pc.anchor_top = 1.0
		pc.anchor_bottom = 1.0
		pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.offset_left = pos.x
	pc.offset_top = pos.y if not bottom else -16.0
	pc.offset_right = pos.x + sz.x
	pc.offset_bottom = pos.y if not bottom else -16.0
	pc.custom_minimum_size = Vector2(sz.x, 0)
	if bottom:
		pc.offset_top = -16.0
	root.add_child(pc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.custom_minimum_size = Vector2(sz.x - 20, 0)
	rt.add_theme_color_override("default_color", Color(0.95, 0.90, 0.80))
	pc.add_child(rt)
	return rt

# ---------------------------------------------------------------- 標題畫面
func _build_title(root: Control) -> void:
	select_panel = PanelContainer.new()
	select_panel.set_anchors_preset(Control.PRESET_CENTER)
	select_panel.custom_minimum_size = Vector2(620, 0)
	select_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	select_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	select_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(select_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	select_panel.add_child(vb)
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.text = """[center][font_size=38][b]木匠工坊[/b][/font_size]
[color=#c8b89a]在自己的小工作室做木工，把作品放到網路上販售，
賺錢買更好的工具、把工作室整理得更舒服。[/color][/center]"""
	vb.add_child(title)
	continue_button = Button.new()
	continue_button.text = "繼續"
	continue_button.custom_minimum_size = Vector2(0, 48)
	continue_button.pressed.connect(func(): continue_pressed.emit())
	vb.add_child(continue_button)
	var b := Button.new()
	b.text = "新遊戲"
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(func(): new_game_pressed.emit())
	vb.add_child(b)

func hide_select() -> void:
	select_panel.visible = false

# ---------------------------------------------------------------- 評分
func _build_result(root: Control) -> void:
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_panel.custom_minimum_size = Vector2(900, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.05, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	result_panel.add_theme_stylebox_override("panel", sb)
	result_panel.visible = false
	root.add_child(result_panel)
	var vb := VBoxContainer.new()
	result_panel.add_child(vb)
	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_label.custom_minimum_size = Vector2(850, 0)
	vb.add_child(result_label)
	finish_button = Button.new()
	finish_button.custom_minimum_size = Vector2(0, 44)
	finish_button.pressed.connect(func(): finish_pressed.emit())
	vb.add_child(finish_button)

## finish_label 為空字串時不顯示「完成作品」按鈕
func show_result(text: String, finish_label := "") -> void:
	result_label.text = text + "\n\n[i]Enter 關閉[/i]"
	finish_button.visible = finish_label != ""
	finish_button.text = finish_label
	result_panel.visible = not result_panel.visible

func menu_open() -> bool:
	return select_panel.visible or result_panel.visible or help_panel.visible or rack.visible or computer.visible

# ---------------------------------------------------------------- 說明
func _build_help(root: Control) -> void:
	help_panel = PanelContainer.new()
	help_panel.set_anchors_preset(Control.PRESET_CENTER)
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	help_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.05, 0.96)
	sb.set_content_margin_all(24)
	sb.set_corner_radius_all(10)
	help_panel.add_theme_stylebox_override("panel", sb)
	help_panel.visible = false
	root.add_child(help_panel)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(760, 0)
	rt.text = """[font_size=24][b]操作說明[/b][/font_size]
[b]視角[/b]　按住右鍵轉頭、WASD 移動、Q/E 升降
[b]工具[/b]　1 手刨　2 劃線　3 鋸　4 鑿　5 砂紙　6 膠與夾具　7 塗裝　8 磨刀石
[b]通用[/b]　左鍵 使用工具　滾輪 調整主要數值　Shift+滾輪 次要數值　R 切換模式
[b]工作室[/b]　L 木料架（取料、開始作品）　P 電腦（市集、訂單、買木料）　Z 睡覺到隔天早上
[b]其他[/b]　Tab 切換工作中的木料　M 游標卡尺／水分計量測（1 分鐘）
　　　F 試裝／組裝　E 撬木屑　K 劃線規對準鑿子　T 等 10 分鐘（Shift+T 1 小時）
　　　B 清掃工作台　Enter 作品評鑑　H 本說明

[b]寫實要點[/b]
・木頭會「動」：含水率跟工坊不平衡就加工，之後會收縮翹曲，榫頭變鬆。
・刨刀只削高點：長鉋台刨直、短鉋台跟著起伏走。看清順紋方向。
・鋸路有寬度：鋸在線的廢料側。起鋸最容易跑偏。
・鑿榫眼靠端部太近會劈裂；木屑要撬出來。
・刃口會鈍：鈍刀撕裂多、卡刀、鑿不動。磨刀是木工的一半。
・膠有開放時間、夾具有時間；砂紙要依序換號；塗裝會讓所有瑕疵現形。"""
	help_panel.add_child(rt)

func toggle_help() -> void:
	help_panel.visible = not help_panel.visible

# ---------------------------------------------------------------- 更新
func add_log(msg: String) -> void:
	_logs.append(msg)
	while _logs.size() > 8:
		_logs.pop_front()
	log_label.text = "\n".join(_logs)

func set_status(t: String) -> void:
	status_label.text = t

func set_steps(t: String) -> void:
	steps_label.text = t

func set_tool(t: String, icon_id: String) -> void:
	tool_label.text = t
	var path := "res://assets/icons/tool_%s.png" % icon_id
	tool_icon.texture = load(path) if ResourceLoader.exists(path) else null

func set_measure(t: String) -> void:
	measure_label.text = t
