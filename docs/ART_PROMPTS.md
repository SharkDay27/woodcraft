# GPT 美術素材提示詞清單

遊戲已經預留好素材掛載點：**檔案放到指定路徑就會自動套用**，不必改程式。
沒有放的素材，遊戲會用程序化的佔位圖（木紋 shader、純色方塊）。

建議用 GPT 的圖像生成（GPT-Image / DALL·E）。每張圖都附上英文提示詞（生成品質較穩定），可以直接複製。

---

## 1. 木紋貼圖（優先度最高）

| 檔案路徑 | 規格 |
|---|---|
| `assets/textures/wood_white_pine.png` | 1024×1024，可無縫拼接 |
| `assets/textures/wood_hinoki.png` | 同上 |
| `assets/textures/wood_black_walnut.png` | 同上 |
| `assets/textures/wood_white_oak.png` | 同上 |
| `assets/textures/wood_hard_maple.png` | 同上 |

> 規則：**纖維必須水平走向**（左右），一張圖代表約 50 × 50 cm 的板面。

**共用提示詞範本**（把 `{SPECIES}` 和 `{DETAILS}` 換掉）：

```
Seamless tileable texture, top-down orthographic photo of freshly hand-planed {SPECIES} board surface,
flat-sawn, wood grain running perfectly horizontal left to right, {DETAILS},
even diffuse lighting, no shadows, no vignette, no knots near edges, no text, photorealistic, 1024x1024
```

| 樹種 | `{SPECIES}` | `{DETAILS}` |
|---|---|---|
| 東部白松 | eastern white pine | pale cream color, soft wide growth rings, subtle resin lines, occasional small tight knot |
| 台灣扁柏 | Taiwanese hinoki cypress | very fine straight tight grain, pale golden-honey color, silky satin sheen |
| 黑胡桃 | American black walnut | deep chocolate brown with purple tint, gentle cathedral grain, fine open pores |
| 白橡木 | white oak | light tan-brown, pronounced cathedral grain, visible ray flecks, open pores |
| 硬楓 | hard maple | creamy white, very fine closed grain, faint subtle figure |

進階（之後加）：同一張的 *roughness map*、*normal map*，以及上油後版本 `wood_<id>_oiled.png`。

---

## 2. 工具圖示（HUD 左上角）

| 檔案路徑 | 內容 |
|---|---|
| `assets/icons/tool_plane.png` | 日式鉋刀（鉋台） |
| `assets/icons/tool_marking.png` | 劃線規 + 直角尺 |
| `assets/icons/tool_saw.png` | 兩刃鋸（Ryoba） |
| `assets/icons/tool_chisel.png` | 追入鑿 + 木槌 |
| `assets/icons/tool_sand.png` | 砂紙包木塊 |
| `assets/icons/tool_glue.png` | 白膠瓶 + F 夾 |
| `assets/icons/tool_finish.png` | 木蠟油罐 + 擦拭布 |
| `assets/icons/tool_whetstone.png` | 磨刀石（雙面） |

規格：256×256，透明背景 PNG。

```
Game UI icon of a {TOOL}, realistic painted style, slight 3/4 view,
warm workshop color palette, soft rim light, clean silhouette,
transparent background, centered, no text, 256x256
```

`{TOOL}` 範例：`traditional Japanese kanna hand plane with oak body and steel blade`、`Japanese ryoba double-edged pull saw`、`Japanese oire-nomi chisel with a wooden mallet`、`two-sided combination whetstone, orange 1000 grit and white 6000 grit`。

---

## 3. 工坊環境（之後換掉場景裡的純色方塊）

規格：2048×2048，可無縫拼接。

- 工作台面：`Seamless texture of an old beech workbench top, scratches, glue spots, pencil marks, dents, top-down, even lighting`
- 地板：`Seamless texture of a workshop concrete floor with fine sawdust and wood shavings, top-down, even lighting`
- 牆面：`Seamless texture of whitewashed timber plank wall in a traditional woodworking shop, even lighting`
- 工具牆參考圖：`Concept art of a traditional Japanese-Western woodworking shop, pegboard wall with hand planes, saws and chisels, warm window light, realistic`（拿來當 3D 建模參考）

---

## 3-1. 窗外景色

| 檔案路徑 | 規格 |
|---|---|
| `assets/textures/window_day.png` | 1920×1152，白天窗景 |
| `assets/textures/window_night.png` | 同上，同一個構圖的夜晚版本 |

兩張都要放，遊戲會依時段混合；沒有放的話用程序化窗景（天空、日月、屋頂剪影）。

```
View through a small workshop window onto a quiet old town street, low-rise houses with tiled roofs,
power lines, a tree, cozy lo-fi illustration style, soft warm daylight, no window frame, no people, no text, 1920x1152
```
夜晚版本把 `soft warm daylight` 換成 `night, deep blue sky with stars, warm lights glowing in house windows`，並在 GPT 裡要求「保持與上一張完全相同的構圖」。

---

## 4. UI 外框

- 面板底圖（9-slice）：`Game UI panel frame, dark walnut wood with brass corner fittings, empty center, flat front view, 512x512, transparent background`
- 委託單：`Old paper work order sheet for a woodworking commission, hand-drawn joinery sketch of a mortise and tenon, empty fields, top-down`

---

## 5. 音效（可選）

音效是程序化合成的，不需要素材。想換成真實錄音（例如 freesound.org 上 CC0 授權的錄音）時，依名稱放到 `assets/sfx/`（.wav 或 .ogg）就會自動取代：
`mallet`、`crack`、`chatter`、`saw_jump`、`clunk`、`offcut`、`tap`、`clamp`、`squeeze`、`wipe`、`scribe`、`pare`、`lever`、`sweep`、`pickup`

---

## 6. 字型

GPT 不負責字型。請下載 **Noto Sans TC**（Google Fonts，免費商用），把 `NotoSansTC-Regular.ttf` 放到 `assets/fonts/`，遊戲會自動套用。（沒有放的話會用系統字型顯示中文）

---

## 3D 模型怎麼辦？

GPT 只能產生 2D 圖片。3D 工具與家具模型的建議做法：
1. 先用 GPT 產生**三視圖參考圖**：`Orthographic turnaround reference sheet of a {TOOL}: front, side, top views, plain white background, technical, no perspective`
2. 再用圖轉 3D 的服務（Meshy、Tripo、Rodin 等）產生 `.glb`，或在 Blender 依參考圖建模
3. 放到 `assets/models/`，匯入 Godot 後掛到工具上
