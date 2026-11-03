class_name WoodSpecies
extends RefCounted
## 木材物種資料。數值為木材手冊（USDA Wood Handbook 等）的近似值。
## janka_n   : Janka 硬度（牛頓），決定鋸、刨、鑿的阻力與刃口磨耗
## density   : 氣乾密度 kg/m³
## shrink_t  : 含水率每變化 1% 的弦向（板寬方向）尺寸變化率 %
## shrink_r  : 含水率每變化 1% 的徑向（板厚方向）尺寸變化率 %
## split     : 劈裂傾向 0~1（鑿榫眼靠近端部、硬敲過緊的榫頭時）
## tearout   : 逆紋撕裂傾向 0~1（刨削逆紋時）
## texture   : 可選的 GPT 生成木紋貼圖路徑（不存在時改用程序化木紋）

const DATA := {
	"white_pine": {
		"name": "東部白松", "latin": "Pinus strobus",
		"density": 400.0, "janka_n": 1690.0,
		"shrink_t": 0.212, "shrink_r": 0.071,
		"split": 0.30, "tearout": 0.30,
		"early": Color(0.89, 0.76, 0.56), "late": Color(0.74, 0.55, 0.34),
		"ring_freq": 120.0, "price": 1.0,
		"texture": "res://assets/textures/wood_white_pine.png",
		"note": "軟、好鋸好刨，但容易壓傷，端面纖維易撕裂。",
	},
	"hinoki": {
		"name": "台灣扁柏（檜木）", "latin": "Chamaecyparis obtusa var. formosana",
		"density": 470.0, "janka_n": 2400.0,
		"shrink_t": 0.200, "shrink_r": 0.100,
		"split": 0.35, "tearout": 0.20,
		"early": Color(0.93, 0.80, 0.60), "late": Color(0.82, 0.64, 0.42),
		"ring_freq": 260.0, "price": 4.0,
		"texture": "res://assets/textures/wood_hinoki.png",
		"note": "紋理通直細緻，刨面如絲，是手刨的最佳練習材。",
	},
	"black_walnut": {
		"name": "黑胡桃", "latin": "Juglans nigra",
		"density": 610.0, "janka_n": 4490.0,
		"shrink_t": 0.274, "shrink_r": 0.190,
		"split": 0.35, "tearout": 0.35,
		"early": Color(0.45, 0.31, 0.21), "late": Color(0.30, 0.19, 0.12),
		"ring_freq": 180.0, "price": 5.0,
		"texture": "res://assets/textures/wood_black_walnut.png",
		"note": "中等硬度，加工手感極佳，上油後顏色深沉。",
	},
	"white_oak": {
		"name": "白橡木", "latin": "Quercus alba",
		"density": 755.0, "janka_n": 5990.0,
		"shrink_t": 0.365, "shrink_r": 0.180,
		"split": 0.50, "tearout": 0.50,
		"early": Color(0.78, 0.62, 0.42), "late": Color(0.60, 0.44, 0.27),
		"ring_freq": 220.0, "price": 3.0,
		"texture": "res://assets/textures/wood_white_oak.png",
		"note": "硬而韌、收縮大。榫卯結構強，但鑿榫眼很費力。",
	},
	"hard_maple": {
		"name": "硬楓", "latin": "Acer saccharum",
		"density": 705.0, "janka_n": 6450.0,
		"shrink_t": 0.353, "shrink_r": 0.165,
		"split": 0.45, "tearout": 0.70,
		"early": Color(0.93, 0.84, 0.69), "late": Color(0.84, 0.72, 0.55),
		"ring_freq": 200.0, "price": 3.0,
		"texture": "res://assets/textures/wood_hard_maple.png",
		"note": "非常硬，紋理常有交錯，刨削極易逆紋撕裂。",
	},
}

## 木料來源：決定進場時的含水率
const STOCK_SOURCES := [
	{"id": "kiln", "name": "窯乾材", "mc": 8.0, "note": "含水率約 8%，可直接加工。"},
	{"id": "air", "name": "風乾材", "mc": 15.0, "note": "含水率約 15%，須先在工坊放置適應，否則加工後會變形。"},
	{"id": "green", "name": "生材", "mc": 30.0, "note": "剛鋸下的濕材，需要很長時間乾燥。"},
]

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["white_pine"])

## 以 4000 N 為 1.0 的相對硬度
static func hardness(id: String) -> float:
	return float(get_data(id)["janka_n"]) / 4000.0

static func ids() -> Array:
	return DATA.keys()
