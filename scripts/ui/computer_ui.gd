class_name ComputerUI
extends PanelContainer
## 工作室電腦：「拾木市集」手作平台（虛構，Pinkoi 式的溫暖手作市集風格）。
## 分頁：我的店舖（上架作品）／客戶訂單／木料行（行情波動）／帳戶與評價

const C_BG := Color("#f6f0e6")
const C_CARD := Color("#fffaf3")
const C_TEXT := Color("#4a3b2e")
const C_SUB := Color("#8a7a68")
const C_ACCENT := Color("#d9775f")
const C_GREEN := Color("#5f8f6e")
const C_LINE := Color("#e5d8c6")

var tabs: TabContainer
var _shop: VBoxContainer
var _orders: VBoxContainer
var _lumber: VBoxContainer
var _account: VBoxContainer
var _header: RichTextLabel
var _tex_cache := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 90
	offset_right = -90
	offset_top = 50
	offset_bottom = -50
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(0)
	sb.shadow_size = 18
	sb.shadow_color = Color(0, 0, 0, 0.45)
	add_theme_stylebox_override("panel", sb)
	var th := Theme.new()
	th.default_font_size = 17
	th.set_color("font_color", "Label", C_TEXT)
	th.set_color("default_color", "RichTextLabel", C_TEXT)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))
	for st in ["normal", "hover", "pressed", "disabled"]:
		var b := StyleBoxFlat.new()
		b.bg_color = {"normal": C_ACCENT, "hover": C_ACCENT.lightened(0.12), "pressed": C_ACCENT.darkened(0.15), "disabled": Color("#c9b8a6")}[st]
		b.set_corner_radius_all(16)
		b.content_margin_left = 14
		b.content_margin_right = 14
		b.content_margin_top = 5
		b.content_margin_bottom = 5
		th.set_stylebox(st, "Button", b)
	th.set_color("font_selected_color", "TabContainer", C_ACCENT)
	th.set_color("font_unselected_color", "TabContainer", C_SUB)
	th.set_color("font_hovered_color", "TabContainer", C_TEXT)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = C_BG
	tab_sel.border_color = C_ACCENT
	tab_sel.border_width_bottom = 3
	tab_sel.set_content_margin_all(10)
	var tab_un := tab_sel.duplicate()
	tab_un.border_width_bottom = 0
	th.set_stylebox("tab_selected", "TabContainer", tab_sel)
	th.set_stylebox("tab_unselected", "TabContainer", tab_un)
	th.set_stylebox("tab_hovered", "TabContainer", tab_un)
	var pnl := StyleBoxFlat.new()
	pnl.bg_color = C_BG
	pnl.set_content_margin_all(14)
	th.set_stylebox("panel", "TabContainer", pnl)
	theme = th

	var vb := VBoxContainer.new()
	add_child(vb)
	# 瀏覽器頂欄
	var bar := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#e9dfd0")
	bsb.corner_radius_top_left = 12
	bsb.corner_radius_top_right = 12
	bsb.set_content_margin_all(8)
	bar.add_theme_stylebox_override("panel", bsb)
	vb.add_child(bar)
	var bl := RichTextLabel.new()
	bl.bbcode_enabled = true
	bl.fit_content = true
	bl.text = "[color=#c0504d]●[/color] [color=#d9a441]●[/color] [color=#6a9a5b]●[/color]　　[color=#8a7a68]https://shimu-market.tw/shop/my-workshop[/color]　　[color=#8a7a68]（P 或 Esc 關閉電腦）[/color]"
	bar.add_child(bl)
	_header = RichTextLabel.new()
	_header.bbcode_enabled = true
	_header.fit_content = true
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 18)
	hm.add_theme_constant_override("margin_top", 10)
	hm.add_child(_header)
	vb.add_child(hm)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)
	_shop = _tab("我的店舖")
	_orders = _tab("客戶訂單")
	_lumber = _tab("木料行")
	_account = _tab("帳戶與評價")
	Game.changed.connect(func(): if visible: refresh())
	visibility_changed.connect(func(): if visible: refresh())

func _tab(name: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v

func refresh() -> void:
	var stars := "尚無評價" if Game.review_count == 0 else "%s %.1f（%d 則評價）" % ["★".repeat(int(round(Game.reputation))), Game.reputation, Game.review_count]
	_header.text = "[font_size=26][b]我的木作所[/b][/font_size]　[color=#d9775f]%s[/color]　[color=#8a7a68]粉絲 %d　｜　第 %d 天[/color]\n[font_size=20]帳戶餘額　[b]NT$ %s[/b][/font_size]" % [stars, Game.followers, Game.day, _fmt(Game.money)]
	_build_shop()
	_build_orders()
	_build_lumber()
	_build_account()

static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _clear(v: Control) -> void:
	for c in v.get_children():
		c.queue_free()

func _card() -> HBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.border_color = C_LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	pc.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pc.add_child(hb)
	pc.set_meta("hb", hb)
	return hb

func _add_card(parent: Control) -> HBoxContainer:
	var hb := _card()
	parent.add_child(hb.get_parent())
	return hb

func _rt(text: String, min_w := 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.text = text
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(min_w, 0)
	return r

func _title(parent: Control, text: String) -> void:
	parent.add_child(_rt("[font_size=21][b]%s[/b][/font_size]" % text))

func _photo(path: String) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(120, 120)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if path != "":
		if not _tex_cache.has(path) and FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img:
				_tex_cache[path] = ImageTexture.create_from_image(img)
		tr.texture = _tex_cache.get(path)
	return tr

# ---------------------------------------------------------------- 我的店舖
func _build_shop() -> void:
	_clear(_shop)
	_title(_shop, "庫存與上架中的作品")
	_shop.add_child(_rt("[color=#8a7a68]建議售價依作品評分、材料、店舖評價與市場熱度計算。訂價越高，賣出得越慢。平台抽成 %d%%。本週熱門：[b]%s[/b][/color]" % [int(Game.PLATFORM_FEE * 100), WoodSpecies.get_data(Game.trend_species)["name"]]))
	var any := false
	for p in Game.products:
		if p["status"] != "stock" and p["status"] != "listed":
			continue
		any = true
		var hb := _add_card(_shop)
		hb.add_child(_photo(p.get("photo", "")))
		var listed: bool = p["status"] == "listed"
		var info := "[font_size=19][b]%s[/b][/font_size]　%s\n" % [p["name"], "[color=#5f8f6e]● 上架中[/color]" if listed else "[color=#8a7a68]○ 未上架[/color]"]
		info += "[color=#8a7a68]%.0f × %.0f × %.1f mm　評分 %.0f　塗裝：%s[/color]\n" % [p["length"], p["width"], p["thickness"], p["score"], _finish_name(p.get("finish", ""))]
		info += "建議售價 [b]NT$ %d[/b]" % Game.suggested_price(p)
		if listed:
			info += "　　♥ %d　瀏覽 %d　上架 %d 天" % [p["likes"], p["views"], Game.day - int(p["listed_day"])]
		hb.add_child(_rt(info, 360))
		var col := VBoxContainer.new()
		var sp := SpinBox.new()
		sp.min_value = 50
		sp.max_value = 99990
		sp.step = 10
		sp.value = p["price"]
		sp.prefix = "NT$"
		sp.custom_minimum_size = Vector2(150, 0)
		col.add_child(sp)
		var b := Button.new()
		b.text = "下架" if listed else "上架販售"
		b.pressed.connect(func(): Game.set_listed(p, not listed, int(sp.value)))
		col.add_child(b)
		if listed:
			var b2 := Button.new()
			b2.text = "更新售價"
			b2.pressed.connect(func(): Game.set_listed(p, true, int(sp.value)))
			col.add_child(b2)
		hb.add_child(col)
	if not any:
		_shop.add_child(_rt("[color=#8a7a68]目前沒有作品。到工作台完成一件可販售的作品（例如砧板），按 Enter 評鑑後就能收進庫存。[/color]"))
	_title(_shop, "已售出")
	var sold := 0
	for i in range(Game.products.size() - 1, -1, -1):
		var p: Dictionary = Game.products[i]
		if p["status"] == "sold" or p["status"] == "delivered":
			sold += 1
			if sold <= 8:
				_shop.add_child(_rt("[color=#8a7a68]第 %d 天　%s　NT$ %d（%s）[/color]" % [int(p.get("sold_day", p["made_day"])), p["name"], p["price"], "訂單交貨" if p["status"] == "delivered" else "市集售出"]))
	if sold == 0:
		_shop.add_child(_rt("[color=#8a7a68]還沒有賣出的作品。[/color]"))

static func _finish_name(f: String) -> String:
	match f:
		"food_oil": return "食品級油"
		"oil": return "木蠟油"
		"varnish": return "亮光漆"
	return "無"

# ---------------------------------------------------------------- 訂單
func _build_orders() -> void:
	_clear(_orders)
	_title(_orders, "客戶訂單")
	_orders.add_child(_rt("[color=#8a7a68]接單後要在交期內交貨，逾期會收到一星負評。報酬會依作品評分調整（評分越高拿越多）。[/color]"))
	var any := false
	for o in Game.orders:
		if not (o["status"] in ["new", "accepted"]):
			continue
		any = true
		var hb := _add_card(_orders)
		var sp_name: String = "不限樹種" if o["species"] == "any" else WoodSpecies.get_data(o["species"])["name"]
		var t := "[font_size=19][b]%s[/b][/font_size]　%s\n" % [o["client"], "[color=#5f8f6e]● 已接單[/color]" if o["status"] == "accepted" else "[color=#d9775f]新訂單[/color]"]
		t += "「%s」\n" % o["message"]
		t += "[color=#8a7a68]砧板｜%s｜長 %.0f±8　寬 ≥ %.0f　厚 %.0f±1.5 mm｜食品級塗裝[/color]\n" % [sp_name, o["length"], o["width_min"], o["thickness"]]
		t += "報酬最高 [b]NT$ %d[/b]　交期：第 %d 天（剩 %d 天）" % [o["reward"], o["deadline"], int(o["deadline"]) - Game.day]
		if o["status"] == "new":
			t += "　[color=#8a7a68]（第 %d 天前要回覆）[/color]" % o["expires"]
		hb.add_child(_rt(t, 480))
		var col := VBoxContainer.new()
		hb.add_child(col)
		if o["status"] == "new":
			var b := Button.new()
			b.text = "接單"
			b.pressed.connect(func(): Game.accept_order(o))
			col.add_child(b)
			var b2 := Button.new()
			b2.text = "婉拒"
			b2.pressed.connect(func(): Game.decline_order(o))
			col.add_child(b2)
		else:
			var ob := OptionButton.new()
			var cands := []
			for p in Game.products:
				if p["status"] == "stock" or p["status"] == "listed":
					var why := Game.order_mismatch(o, p)
					ob.add_item("%s（評分 %.0f）%s" % [p["name"], p["score"], "" if why == "" else " ✗ " + why])
					ob.set_item_disabled(ob.item_count - 1, why != "")
					cands.append(p)
			if cands.is_empty():
				ob.add_item("庫存沒有作品")
				ob.disabled = true
			col.add_child(ob)
			var b3 := Button.new()
			b3.text = "交貨"
			b3.disabled = cands.is_empty()
			b3.pressed.connect(func():
				var i := ob.selected
				if i >= 0 and i < cands.size() and not ob.is_item_disabled(i):
					Game.deliver_order(o, cands[i])
				else:
					Game.message.emit("請選一件符合規格的作品。"))
			col.add_child(b3)
	if not any:
		_orders.add_child(_rt("[color=#8a7a68]目前沒有訂單。店舖評價越好，訂單越多。每天早上會收到新的詢問。[/color]"))

# ---------------------------------------------------------------- 木料行
func _build_lumber() -> void:
	_clear(_lumber)
	_title(_lumber, "今日木料行情")
	_lumber.add_child(_rt("[color=#8a7a68]價格每天隨市場波動（指數 100 = 一般行情，▲▼ = 比昨天漲／跌）。寬板 600×200×26 mm 適合砧板；角料 520×60×28 mm 適合榫卯。窯乾材可以直接用，風乾材便宜但要放著等它乾。買的料會送到木料架（L）。[/color]"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	_lumber.add_child(grid)
	for h in ["樹種", "行情", "寬板 窯乾", "寬板 風乾", "角料 窯乾", "角料 風乾"]:
		grid.add_child(_rt("[b]%s[/b]" % h, 110))
	for sid in Game.BASE_PRICE.keys():
		var d := WoodSpecies.get_data(sid)
		grid.add_child(_rt("[b]%s[/b]" % d["name"], 150))
		var m: float = Game.market.get(sid, 1.0)
		var prev: float = Game.market_prev.get(sid, m)
		var arrow := "[color=#c0504d]▲[/color]" if m > prev + 0.005 else ("[color=#5f8f6e]▼[/color]" if m < prev - 0.005 else "－")
		grid.add_child(_rt("指數 %d　%s" % [int(round(m * 100.0)), arrow], 90))
		for combo in [["wide", "kiln"], ["wide", "air"], ["narrow", "kiln"], ["narrow", "air"]]:
			var b := Button.new()
			var price := Game.lumber_price(sid, combo[1], combo[0])
			b.text = "NT$ %d" % price
			b.disabled = Game.money < price
			var s_id: String = sid
			var sz: String = combo[0]
			var src: String = combo[1]
			b.pressed.connect(func(): Game.buy_board(s_id, src, sz))
			grid.add_child(b)
	_title(_lumber, "木料架上的庫存（%d 塊）" % Game.inventory.size())
	for it in Game.inventory:
		_lumber.add_child(_rt("[color=#8a7a68]・%s[/color]" % RackUI.item_text(it)))

# ---------------------------------------------------------------- 帳戶
func _build_account() -> void:
	_clear(_account)
	_title(_account, "買家評價")
	if Game.reviews.is_empty():
		_account.add_child(_rt("[color=#8a7a68]還沒有評價。作品賣出或交貨幾天後，買家會留下評價。[/color]"))
	for rv in Game.reviews.slice(0, 12):
		var hb := _add_card(_account)
		hb.add_child(_rt("[color=#d9775f]%s[/color][color=#e5d8c6]%s[/color]　[b]%s[/b]　[color=#8a7a68]第 %d 天・%s[/color]\n%s" % ["★".repeat(int(rv["stars"])), "★".repeat(5 - int(rv["stars"])), rv["client"], rv["day"], rv["product"], rv["text"]]))
	_title(_account, "收支紀錄")
	for i in range(Game.ledger.size() - 1, maxi(-1, Game.ledger.size() - 16), -1):
		var l: Dictionary = Game.ledger[i]
		var amt: int = l["amount"]
		_account.add_child(_rt("第 %d 天　%s　[color=%s]%s NT$ %s[/color]" % [l["day"], l["text"], "#5f8f6e" if amt >= 0 else "#c0504d", "+" if amt >= 0 else "－", _fmt(absi(amt))]))
