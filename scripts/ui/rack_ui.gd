class_name RackUI
extends PanelContainer
## 木料架：從庫存挑料、選擇要做的作品，拿到工作台開始工作；或把工作台上的料收回來。

signal start_work(item_uid: int, project_id: String, params: Dictionary)
signal return_bench

var ws
var _list: VBoxContainer
var _project: OptionButton
var _size: OptionButton
var _info: RichTextLabel
var _selected_uid: int = -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 330
	offset_right = -330
	offset_top = 110
	offset_bottom = -110
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.96)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	add_theme_stylebox_override("panel", sb)
	visibility_changed.connect(func(): if visible: refresh())

func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	vb.add_child(_rt("[font_size=26][b]木料架[/b][/font_size]　[color=#a89070]（L 或 Esc 關閉）[/color]"))
	if ws.pieces.size() > 0:
		vb.add_child(_rt("工作台上正在做：[b]%s[/b]（%d 塊料）\n一次只能做一件作品。可以把料收回木料架，加工狀態都會保留（已組裝的不能收）。" % [ws.workflow.title if ws.workflow else "", ws.pieces.size()]))
		var b := Button.new()
		b.text = "把工作台上的料收回木料架"
		b.disabled = ws.assembly["assembled"]
		b.pressed.connect(func(): return_bench.emit())
		vb.add_child(b)
		return
	vb.add_child(_rt("選一塊料，再選要做的作品："))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var group := ButtonGroup.new()
	for it in Game.inventory:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = item_text(it)
		var uid: int = it["uid"]
		b.pressed.connect(func():
			_selected_uid = uid
			_update_info())
		_list.add_child(b)
	if Game.inventory.is_empty():
		_list.add_child(_rt("[color=#a89070]木料架是空的。到電腦（P）的木料行買料。[/color]"))
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	hb.add_child(_rt("作品：", 60))
	_project = OptionButton.new()
	for pr in Workflow.PROJECTS:
		_project.add_item(pr["name"])
	_project.item_selected.connect(func(_i): _fill_sizes(); _update_info())
	hb.add_child(_project)
	_size = OptionButton.new()
	hb.add_child(_size)
	_size.item_selected.connect(func(_i): _update_info())
	_fill_sizes()
	_info = _rt("")
	vb.add_child(_info)
	var go := Button.new()
	go.text = "拿到工作台，開始製作"
	go.pressed.connect(_on_go)
	vb.add_child(go)
	_selected_uid = -1
	_update_info()

func _fill_sizes() -> void:
	_size.clear()
	for s in Workflow.PROJECTS[_project.selected]["sizes"]:
		_size.add_item(s["name"])

func _item(uid: int) -> Dictionary:
	for it in Game.inventory:
		if int(it["uid"]) == uid:
			return it
	return {}

func _problem() -> String:
	var it := _item(_selected_uid)
	if it.is_empty():
		return "還沒選料。"
	var pr: Dictionary = Workflow.PROJECTS[_project.selected]
	var sz: Dictionary = pr["sizes"][_size.selected]
	if it.has("piece"):
		return ""
	if pr["id"] == "cutting_board":
		if float(it["width"]) < 140.0:
			return "這塊料太窄了，砧板要用寬板。"
		if float(it["length"]) < float(sz["length"]) + 20.0:
			return "這塊料不夠長（要比成品長，兩端才能鋸齊）。"
		if float(it["thickness"]) < float(sz["thickness"]) + 1.0:
			return "這塊料太薄，刨不出這個厚度。"
	else:
		if float(it["length"]) < 500.0 or float(it["thickness"]) < 25.0:
			return "這個練習需要 500 mm 以上、25 mm 厚的角料。"
	return ""

func _update_info() -> void:
	if _info == null:
		return
	var pr: Dictionary = Workflow.PROJECTS[_project.selected]
	var t := "[color=#c8b89a]%s[/color]" % pr["desc"]
	var prob := _problem()
	if prob != "":
		t += "\n[color=orange]%s[/color]" % prob
	_info.text = t

func _on_go() -> void:
	if _problem() != "":
		return
	var pr: Dictionary = Workflow.PROJECTS[_project.selected]
	start_work.emit(_selected_uid, pr["id"], (pr["sizes"][_size.selected] as Dictionary).duplicate())

static func item_text(it: Dictionary) -> String:
	var d := WoodSpecies.get_data(it["species"])
	var src := "窯乾" if it["source"] == "kiln" else ("風乾" if it["source"] == "air" else "生材")
	var kind := "（加工中的料）" if it.has("piece") else ("" if it["kind"] == "board" else "（餘料）")
	return "%s　%.0f × %.0f × %.0f mm　%s%s" % [d["name"], it["length"], it["width"], it["thickness"], src, kind]

func _rt(text: String, min_w := 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = text
	r.custom_minimum_size = Vector2(min_w, 0)
	r.add_theme_color_override("default_color", Color(0.95, 0.90, 0.80))
	return r
