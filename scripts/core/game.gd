extends Node
## 全域遊戲狀態（autoload 名稱：Game）：金錢、庫存、作品、市集、訂單、木料行情、評價、存檔。
## 市集是虛構的手作平台「拾木市集」（Pinkoi 式的手作市集風格）。

signal changed
signal message(text: String)

const SAVE_PATH := "user://save.json"
const PLATFORM_FEE := 0.15        ## 平台抽成
const BUYER_EMC := 13.0           ## 台灣一般家庭的平衡含水率（濕度高）
const START_MONEY := 3000

## 木料規格：寬板做砧板、層板；角料做榫卯
const LUMBER_SIZES := [
	{"id": "wide", "name": "寬板", "length": 600.0, "width": 200.0, "thickness": 26.0, "factor": 1.0},
	{"id": "narrow", "name": "角料", "length": 520.0, "width": 60.0, "thickness": 28.0, "factor": 0.35},
]
## 寬板（窯乾）基準價 NT$
const BASE_PRICE := {"white_pine": 180.0, "hinoki": 650.0, "black_walnut": 1100.0, "white_oak": 600.0, "hard_maple": 650.0}
const SOURCE_FACTOR := {"kiln": 1.0, "air": 0.7, "green": 0.45}

const CLIENTS := ["陳小姐", "林先生", "王太太", "張阿姨", "黃先生", "咖啡廳「森日」", "李小姐", "早午餐店「慢慢」", "吳先生", "蔡小姐", "露營用品店「野趣」", "周太太"]
const OCCASIONS := ["送朋友的新居禮物", "自己家裡用", "想放在店裡切麵包", "結婚紀念日的禮物", "露營時要用", "給媽媽的生日禮物", "擺盤拍照用"]

var money: int = START_MONEY
var day: int = 1
var reputation: float = 0.0
var review_count: int = 0
var followers: int = 0
var inventory: Array = []       ## 木料：{uid, species, source, length, width, thickness, mc, kind, piece?}
var products: Array = []        ## 作品
var orders: Array = []          ## 客戶訂單
var reviews: Array = []
var pending_reviews: Array = []
var ledger: Array = []          ## 收支紀錄 {day, text, amount}
var market := {}                ## 樹種 -> 行情倍率
var market_prev := {}
var trend_species: String = ""
var bench: Dictionary = {}      ## 工作台上的進行中工作（存檔用）
var game_minutes: float = 8.0 * 60.0
var _uid: int = 0

# ================================================================ 開新遊戲 / 存讀檔
func new_game() -> void:
	money = START_MONEY
	day = 1
	reputation = 0.0
	review_count = 0
	followers = 0
	inventory.clear()
	products.clear()
	orders.clear()
	reviews.clear()
	pending_reviews.clear()
	ledger.clear()
	bench = {}
	game_minutes = 8.0 * 60.0
	for sid in BASE_PRICE.keys():
		market[sid] = randf_range(0.9, 1.1)
		market_prev[sid] = market[sid]
	trend_species = BASE_PRICE.keys().pick_random()
	# 初始材料：幾塊便宜的松木與一塊檜木練習
	add_board("white_pine", "kiln", "wide")
	add_board("white_pine", "kiln", "wide")
	add_board("hinoki", "kiln", "wide")
	add_board("white_oak", "kiln", "narrow")
	add_board("white_pine", "air", "narrow")
	_add_ledger("開業資金", START_MONEY)
	# 第一張訂單：鄰居的松木砧板（教學用）
	orders.append({"uid": _next_uid(), "client": "隔壁的張阿姨", "type": "cutting_board", "species": "white_pine",
		"length": 300.0, "width_min": 150.0, "thickness": 20.0, "reward": 650, "deadline": day + 4, "status": "new",
		"message": "聽說你開了木工房！可以幫我做一塊松木砧板嗎？30 公分長左右就好，厚 2 公分。", "expires": day + 3})
	changed.emit()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	var d := {"money": money, "day": day, "reputation": reputation, "review_count": review_count, "followers": followers,
		"inventory": inventory, "products": products, "orders": orders, "reviews": reviews, "pending_reviews": pending_reviews,
		"ledger": ledger, "market": market, "market_prev": market_prev, "trend": trend_species, "bench": bench,
		"game_minutes": game_minutes, "uid": _uid}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	money = int(d["money"])
	day = int(d["day"])
	reputation = float(d["reputation"])
	review_count = int(d["review_count"])
	followers = int(d.get("followers", 0))
	inventory = d["inventory"]
	products = d["products"]
	orders = d["orders"]
	reviews = d["reviews"]
	pending_reviews = d["pending_reviews"]
	ledger = d["ledger"]
	market = d["market"]
	market_prev = d["market_prev"]
	trend_species = d["trend"]
	bench = d["bench"]
	game_minutes = float(d["game_minutes"])
	_uid = int(d["uid"])
	changed.emit()
	return true

func _next_uid() -> int:
	_uid += 1
	return _uid

func _add_ledger(text: String, amount: int) -> void:
	ledger.append({"day": day, "text": text, "amount": amount})
	if ledger.size() > 60:
		ledger.pop_front()

# ================================================================ 木料
func lumber_price(species: String, source: String, size_id: String) -> int:
	var size: Dictionary = LUMBER_SIZES[0]
	for s in LUMBER_SIZES:
		if s["id"] == size_id:
			size = s
	return int(round(float(BASE_PRICE[species]) * float(size["factor"]) * float(SOURCE_FACTOR[source]) * float(market.get(species, 1.0)) / 10.0) * 10)

func add_board(species: String, source: String, size_id: String) -> Dictionary:
	var size: Dictionary = LUMBER_SIZES[0]
	for s in LUMBER_SIZES:
		if s["id"] == size_id:
			size = s
	var mc := 8.0
	for s in WoodSpecies.STOCK_SOURCES:
		if s["id"] == source:
			mc = float(s["mc"])
	var item := {"uid": _next_uid(), "species": species, "source": source, "size": size_id, "kind": "board",
		"length": size["length"], "width": float(size["width"]) + randf_range(-1.0, 1.0),
		"thickness": size["thickness"], "mc": mc + randf_range(-0.8, 0.8), "since": game_minutes}
	inventory.append(item)
	changed.emit()
	return item

func buy_board(species: String, source: String, size_id: String) -> bool:
	var price := lumber_price(species, source, size_id)
	if money < price:
		message.emit("錢不夠買這塊料。")
		return false
	money -= price
	add_board(species, source, size_id)
	_add_ledger("購買木料：%s" % WoodSpecies.get_data(species)["name"], -price)
	message.emit("買了一塊%s %s（NT$ %d），送到木料架上了。" % [WoodSpecies.get_data(species)["name"], _size_name(size_id), price])
	changed.emit()
	return true

func _size_name(size_id: String) -> String:
	for s in LUMBER_SIZES:
		if s["id"] == size_id:
			return s["name"]
	return ""

## 放在木料架上的料也會慢慢趨近工坊濕度
func age_inventory(minutes: float, emc: float) -> void:
	for it in inventory:
		var tau := WoodPhysics.moisture_tau_hours(float(it["thickness"]))
		it["mc"] = float(it["mc"]) + (emc - float(it["mc"])) * (1.0 - exp(-minutes / 60.0 / tau))

# ================================================================ 作品定價
## 作品的參考價：材料價值 + 工時價值
func reference_price(p: Dictionary) -> float:
	var vol := float(p["length"]) * float(p["width"]) * float(p["thickness"])
	var board_vol := 600.0 * 200.0 * 26.0
	var material := float(BASE_PRICE.get(p["species"], 300.0)) * vol / board_vol
	return material * 1.8 + 450.0

func quality_factor(score: float) -> float:
	return 0.4 + 1.2 * pow(clampf(score, 0.0, 100.0) / 100.0, 1.5)

func reputation_factor() -> float:
	if review_count == 0:
		return 0.9
	return 0.8 + 0.08 * reputation

## 買家心中的合理價
func expected_price(p: Dictionary) -> float:
	var e := reference_price(p) * quality_factor(float(p["score"])) * reputation_factor()
	if p["species"] == trend_species:
		e *= 1.2
	return e

func suggested_price(p: Dictionary) -> int:
	return int(round(expected_price(p) / 10.0) * 10)

func add_product(p: Dictionary) -> void:
	p["uid"] = _next_uid()
	p["status"] = "stock"
	p["price"] = suggested_price(p)
	p["likes"] = 0
	p["views"] = 0
	p["listed_day"] = 0
	p["made_day"] = day
	products.append(p)
	changed.emit()

func set_listed(p: Dictionary, listed: bool, price: int) -> void:
	p["price"] = price
	p["status"] = "listed" if listed else "stock"
	if listed:
		p["listed_day"] = day
	changed.emit()

# ================================================================ 訂單
func accept_order(o: Dictionary) -> void:
	o["status"] = "accepted"
	message.emit("接下了%s的訂單，交期第 %d 天。" % [o["client"], o["deadline"]])
	changed.emit()

func decline_order(o: Dictionary) -> void:
	o["status"] = "declined"
	changed.emit()

## 作品是否符合訂單規格。回傳 "" 代表符合，否則為原因
func order_mismatch(o: Dictionary, p: Dictionary) -> String:
	if p["type"] != o["type"]:
		return "品項不同"
	if o["species"] != "any" and p["species"] != o["species"]:
		return "樹種不對（要%s）" % WoodSpecies.get_data(o["species"])["name"]
	if absf(float(p["length"]) - float(o["length"])) > 8.0:
		return "長度差太多（要約 %.0f mm）" % o["length"]
	if float(p["width"]) < float(o["width_min"]) - 1.0:
		return "寬度不足（至少 %.0f mm）" % o["width_min"]
	if absf(float(p["thickness"]) - float(o["thickness"])) > 1.5:
		return "厚度不符（要約 %.0f mm）" % o["thickness"]
	return ""

func deliver_order(o: Dictionary, p: Dictionary) -> void:
	var pay := int(float(o["reward"]) * clampf(0.6 + float(p["score"]) / 250.0, 0.6, 1.0))
	money += pay
	_add_ledger("訂單交貨：%s" % o["client"], pay)
	o["status"] = "done"
	p["status"] = "delivered"
	p["price"] = pay
	p["sold_day"] = day
	pending_reviews.append({"due": day + randi_range(1, 3), "product": p.duplicate(), "client": o["client"], "price": pay, "expected": o["reward"]})
	message.emit("交貨給%s，收到 NT$ %d。" % [o["client"], pay])
	changed.emit()

func _new_order() -> void:
	var sp: String = BASE_PRICE.keys().pick_random() if randf() < 0.7 else "any"
	var L: float = [250.0, 300.0, 350.0].pick_random()
	var W: float = [150.0, 170.0, 180.0].pick_random()
	var T: float = [18.0, 20.0, 22.0].pick_random()
	var proto := {"type": "cutting_board", "species": sp if sp != "any" else "white_pine", "length": L, "width": W + 10.0, "thickness": T, "score": 80.0}
	var reward := int(round(expected_price(proto) * 1.25 / 10.0) * 10)
	var client: String = CLIENTS.pick_random()
	var sp_name: String = "木頭" if sp == "any" else WoodSpecies.get_data(sp)["name"]
	var msg := "想訂一塊%s砧板，%s。尺寸大約 %.0f × %.0f 公分、厚 %.0f mm。" % [sp_name, OCCASIONS.pick_random(), L / 10.0, W / 10.0, T]
	orders.append({"uid": _next_uid(), "client": client, "type": "cutting_board", "species": sp, "length": L,
		"width_min": W, "thickness": T, "reward": reward, "deadline": day + randi_range(3, 6), "status": "new",
		"message": msg, "expires": day + 2})

# ================================================================ 每日結算
## 每過一天呼叫一次：市場行情、商品銷售、評價、新訂單、訂單逾期
func new_day() -> Array[String]:
	day += 1
	var news: Array[String] = []
	# 木料行情：均值回歸的隨機漫步
	for sid in market.keys():
		market_prev[sid] = market[sid]
		var m: float = market[sid]
		m += (1.0 - m) * 0.15 + randfn(0.0, 0.05)
		market[sid] = clampf(m, 0.7, 1.4)
	if day % 7 == 1:
		trend_species = BASE_PRICE.keys().pick_random()
		news.append("市集本週熱門：%s 作品" % WoodSpecies.get_data(trend_species)["name"])
	# 上架商品
	for p in products:
		if p["status"] != "listed":
			continue
		var exp_p := expected_price(p)
		var r := float(p["price"]) / exp_p
		var days_on := day - int(p["listed_day"])
		p["views"] = int(p["views"]) + randi_range(3, 15) + int(reputation * 3.0)
		if randf() < clampf(0.5 - (r - 1.0), 0.05, 0.8):
			p["likes"] = int(p["likes"]) + randi_range(1, 3)
		var chance := clampf(0.55 * exp(-3.0 * (r - 1.0)), 0.02, 0.9) * clampf(1.0 + int(p["likes"]) * 0.02, 1.0, 1.3) * clampf(1.0 - days_on * 0.03, 0.6, 1.0)
		if randf() < chance:
			var income := int(float(p["price"]) * (1.0 - PLATFORM_FEE))
			money += income
			p["status"] = "sold"
			p["sold_day"] = day
			var buyer: String = CLIENTS.pick_random()
			_add_ledger("售出：%s（扣平台抽成 %d%%）" % [p["name"], int(PLATFORM_FEE * 100)], income)
			news.append("[color=lime]%s 買下了「%s」！入帳 NT$ %d[/color]" % [buyer, p["name"], income])
			pending_reviews.append({"due": day + randi_range(2, 4), "product": p.duplicate(), "client": buyer, "price": p["price"], "expected": exp_p})
			followers += randi_range(0, 2)
	# 評價（作品到買家手上幾天後，物理狀態決定評價）
	var keep := []
	for pr in pending_reviews:
		if int(pr["due"]) <= day:
			var rv := _make_review(pr)
			reviews.push_front(rv)
			review_count += 1
			reputation = (reputation * (review_count - 1) + float(rv["stars"])) / review_count
			news.append("%s 給了 %s：「%s」" % [rv["client"], "★".repeat(int(rv["stars"])), rv["text"]])
		else:
			keep.append(pr)
	pending_reviews = keep
	# 訂單：逾期與新訂單
	for o in orders:
		if o["status"] == "new" and day > int(o["expires"]):
			o["status"] = "expired"
		elif o["status"] == "accepted" and day > int(o["deadline"]):
			o["status"] = "failed"
			review_count += 1
			reputation = (reputation * (review_count - 1) + 1.0) / review_count
			reviews.push_front({"day": day, "client": o["client"], "stars": 1, "text": "說好的交期過了還沒收到，很失望。", "product": "（未交貨）"})
			news.append("[color=red]%s 的訂單逾期了，留下一星負評。[/color]" % o["client"])
	var n_new := 0
	if randf() < 0.45 + reputation * 0.08:
		n_new += 1
	if randf() < reputation * 0.06:
		n_new += 1
	for i in n_new:
		_new_order()
	if n_new > 0:
		news.append("收到 %d 張新的客戶訂單（到電腦上查看）" % n_new)
	changed.emit()
	return news

func _make_review(pr: Dictionary) -> Dictionary:
	var p: Dictionary = pr["product"]
	var score := float(p["score"])
	var stars := 5 if score >= 85.0 else (4 if score >= 70.0 else (3 if score >= 50.0 else (2 if score >= 30.0 else 1)))
	var notes: Array[String] = []
	# 延遲後果：含水率不平衡 -> 到買家家裡（台灣潮濕）變形
	var mc_gap := absf(float(p.get("built_mc", 10.0)) - BUYER_EMC)
	if mc_gap > 5.0:
		stars -= 2
		notes.append("收到一週後板子翹起來了，放在桌上會晃")
	elif mc_gap > 3.5 and randf() < 0.5:
		stars -= 1
		notes.append("用了幾天有一點點翹")
	if p["type"] == "cutting_board" and p.get("finish", "") != "food_oil":
		stars -= 2
		notes.append("砧板上的塗料不是食品級的，不敢拿來切食物")
	var defects: Array = p.get("defects", [])
	if defects.size() > 0 and randf() < 0.7:
		notes.append("表面有些瑕疵（%s）" % defects[0])
	var r := float(pr["price"]) / maxf(float(pr["expected"]), 1.0)
	if r > 1.3:
		stars -= 1
		notes.append("以這個品質來說價格偏高")
	elif r < 0.8 and stars >= 4:
		notes.append("這個價格非常超值")
	stars = clampi(stars, 1, 5)
	var praise := ["做工很細緻，摸起來好舒服！", "木紋好漂亮，家人都很喜歡。", "包裝用心，砧板很穩。", "看得出來是手作的溫度。", "已經推薦給朋友了。"]
	var meh := ["還可以，跟照片差不多。", "堪用。", "普普通通。"]
	var text := ""
	if stars >= 4:
		text = praise.pick_random()
	elif stars == 3:
		text = meh.pick_random()
	else:
		text = "有點失望。"
	if notes.size() > 0:
		text += "不過" + "，".join(notes) + "。" if stars >= 4 else "，".join(notes) + "。"
	return {"day": day, "client": pr["client"], "stars": stars, "text": text, "product": p["name"]}

func clock_day(minutes: float) -> int:
	return int(minutes / 1440.0) + 1
