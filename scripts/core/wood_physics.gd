class_name WoodPhysics
extends RefCounted
## 木工物理模型：所有「為什麼會這樣」的數學都集中在這裡，方便調整手感。
## 單位一律為公釐 (mm)、分鐘 (遊戲時間)。

const FSP := 28.0          ## 纖維飽和點：高於此含水率木材不會再收縮
const KERF := 0.6          ## 日式鋸路寬 (mm)

## 加工速度倍率（遊戲節奏設定，F2 切換）。1 = 真實速度。
## 鋸、砂、磨刀完整套用；刨與鑿套用一半（避免一刨/一敲的量大到失去手感）。
const WORK_SPEEDS := [1.0, 2.0, 3.0, 5.0]
static var work_speed: float = 3.0

static func speed_full() -> float:
	return work_speed

static func speed_half() -> float:
	return 1.0 + (work_speed - 1.0) * 0.5

# ---------------------------------------------------------------- 含水率
## 木料與工坊平衡含水率 (EMC) 趨近的時間常數（遊戲小時）。厚度平方律：厚兩倍，乾燥慢四倍。
static func moisture_tau_hours(thick_mm: float) -> float:
	return 8.0 * pow(thick_mm / 25.0, 2.0)

## 含水率變化 -> 尺寸變化倍率（只計算 FSP 以下的部分）
static func movement_factor(coef_pct: float, mc_from: float, mc_to: float) -> float:
	var a := minf(mc_from, FSP)
	var b := minf(mc_to, FSP)
	return 1.0 + coef_pct / 100.0 * (b - a)

# ---------------------------------------------------------------- 鋸
## saw_mode: 0 = 縱切齒（順纖維），1 = 橫切齒（斷纖維）
static func saw_efficiency(saw_mode: int, kind: String) -> float:
	var rip_job := kind == "rip"
	if saw_mode == 0:
		return 1.0 if rip_job else 0.45
	return 0.35 if rip_job else 1.0

## 每 1 px 拉鋸行程可前進的深度 (mm)。鋸路越長（料越寬）越慢。
static func saw_rate(h: float, eff: float, sharp: float, kerf_len: float) -> float:
	return 0.022 * eff * pow(sharp, 0.7) / (maxf(h, 0.2) * pow(maxf(kerf_len, 10.0) / 50.0, 0.7)) * speed_full()

## 鋸切偏移靈敏度：鋸路尚未建立 (前 2mm) 時，鋸子很容易跑偏，也容易修正。
static func saw_steer(depth_done: float) -> float:
	return 0.012 if depth_done < 2.0 else 0.003

# ---------------------------------------------------------------- 刨
## 超過此吃刀深度，刨刀會卡住/顫刀
static func plane_max_depth(h: float, sharp: float) -> float:
	return 0.12 + 0.30 * sharp / sqrt(maxf(h, 0.2))

## 逆紋撕裂機率（每一段）
static func tearout_chance(tear: float, runout_deg: float, depth: float, sharp: float, uphill: bool) -> float:
	var p := tear * clampf(absf(runout_deg) / 6.0, 0.1, 1.5) * clampf(depth / 0.1, 0.3, 4.0) * (1.25 - sharp) * 0.35
	if not uphill:
		p *= 0.08
	return clampf(p, 0.0, 0.95)

# ---------------------------------------------------------------- 鑿
## 一次木槌敲擊鑿入深度
static func chisel_depth(force: float, sharp: float, h: float, chips: int) -> float:
	var d := force * 3.2 * sharp / maxf(h, 0.2) * speed_half()
	if chips >= 3:
		d *= 0.25   # 木屑塞住，鑿不下去
	return d

# ---------------------------------------------------------------- 配合
## delta = 榫眼寬 - 榫頭厚（mm）。正值代表鬆。
static func fit_grade(delta: float) -> Dictionary:
	if delta < -0.30:
		return {"grade": "過緊", "score": 0.2, "can": false,
			"msg": "太緊：硬敲會把榫眼撐裂。用鑿子修薄榫頭頰面。"}
	if delta < -0.08:
		return {"grade": "緊", "score": 0.75, "can": true,
			"msg": "偏緊：需木槌敲入，膠會被刮掉、木料有撐裂風險。"}
	if delta <= 0.08:
		return {"grade": "剛好", "score": 1.0, "can": true,
			"msg": "手壓可推入、不晃動——理想的配合。"}
	if delta <= 0.25:
		return {"grade": "略鬆", "score": 0.65, "can": true,
			"msg": "略鬆：可以晃動。PVA 白膠不能填縫，強度下降。"}
	return {"grade": "鬆垮", "score": 0.25, "can": true,
		"msg": "鬆垮：榫頭在眼內晃動，只能靠膠，強度很差。"}

## 膠合強度係數 0~1
## amount: 上膠量 0~1；pressure: 夾具壓力 0~1；clamp_min: 夾持分鐘；open_min: 上膠到組裝經過的分鐘；gap: 配合間隙
static func glue_factor(amount: float, pressure: float, clamp_min: float, open_min: float, gap: float) -> Dictionary:
	var f := 1.0
	var notes: Array[String] = []
	if amount < 0.3:
		f *= 0.45 + amount
		notes.append("上膠不足（缺膠接合）")
	elif amount > 0.8:
		notes.append("上膠過多，擠出膠需清理")
	if pressure < 0.25:
		f *= 0.7
		notes.append("夾持壓力不足")
	elif pressure > 0.85:
		f *= 0.8
		notes.append("夾太緊把膠擠光了")
	if open_min > 10.0:
		f *= 0.6
		notes.append("超過開放時間 (10 分鐘)，膠已結皮")
	if clamp_min < 45.0:
		f *= clampf(clamp_min / 45.0, 0.1, 1.0)
		notes.append("夾持時間不足 45 分鐘就拆夾")
	if gap > 0.15:
		f *= clampf(1.0 - (gap - 0.15) * 2.0, 0.3, 1.0)
		notes.append("配合間隙太大，PVA 無法填縫")
	return {"factor": f, "notes": notes}

# ---------------------------------------------------------------- 砂磨
const GRITS := [80, 120, 180, 240, 320]
## 各號砂紙留下的刮痕深度（遊戲化的 mm 值）
static func grit_scratch(grit: int) -> float:
	match grit:
		80: return 0.20
		120: return 0.12
		180: return 0.07
		240: return 0.045
		_: return 0.03

## 研削力：粗砂紙去料快
static func grit_power(grit: int) -> float:
	return grit_scratch(grit) * 2.0
