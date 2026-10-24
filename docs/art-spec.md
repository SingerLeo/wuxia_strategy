# 美术规格（给画师 / AI 绘图工具）

> 游戏现在的画面全部由代码绘制（见 `src/ui/widgets/map_art.gd`、`ui_skin.gd`、`shaders/`）。
> 这份文档规定：**把图片放在哪、叫什么、多大**，游戏启动时就会自动用它们替换程序画的版本。
> **没有的图不会出错**，继续用程序画的；所以可以一张一张地换。图片放进 `assets/art/` 后重启游戏即可（开发时直接读 PNG，不需要先在 Godot 里导入）。

## 0. 总体风格建议
- 题材：中国武侠，山门（门派）。俯视略带斜角（约 45°～60° 的"斜俯视"），光从左上来、影子落向右下。
- 色调：偏沉稳的暗色调，和现在界面的"墨色 + 金色"协调；建筑以青瓦、粉墙、朱红柱、木色为主。
- **同一套图风格要统一**（同一个画师或同一组提示词/种子）。建筑、地图、界面混着不同风格会很出戏。
- 所有带透明的图用 **PNG（RGBA）**。

## 1. 山门地图底图（最能提升观感）
- 文件：`assets/art/map/ground.png`
- 内容：整个山门的地面、河流、山、树（**不含建筑**，建筑是单独的图）。
- 尺寸：地图是 **12 × 8 格**，每格 64 像素 → 游戏内 768 × 512。**推荐出 2 倍大小：1536 × 1024**（引擎会缩放）。比例必须是 3 : 2。
- **必须和格子对上**：哪些格子是山、哪些是河，由 `src/core/catalog.gd` 的 `MAP` 决定（山和河上不能建房）。请以参考图为准：
  - 参考图：`docs/art/map_guide.png`（1536 × 1024，绿 = 可建空地，灰褐 = 山，蓝 = 河，白线 = 格子）。
  - 重新导出参考图（改了地图之后）：`godot_console --headless -s tools/export_map_guide.gd -- --out=docs/art/map_guide.png --cell=128`
- 有这张图时，游戏不再用着色器画地形，也不再画程序生成的山和树。

## 2. 建筑精灵
- 目录：`assets/art/buildings/`
- 命名：`<建筑id>.png`；想区分等级则用 `<建筑id>_lv<等级>.png`（等级 1～5）。找图的顺序：`<id>_lv<等级>.png` → `<id>.png`。
- **旋转**：建筑在游戏里可以旋转 90°（占地宽高对调）。可以额外提供旋转版 `<id>_r.png` / `<id>_lv<等级>_r.png`；没有旋转版就把同一张图缩放到新的占地宽度。
- 摆放规则：**图片宽度 = 占地宽度**，**图片底边 = 占地底边**，高度按图片比例，**可以向上超出占地**（高屋顶、塔楼）。图片之外的地方保持透明。

| 建筑 id | 名称 | 占地（格） | 占地像素（1 倍） | 推荐出图（2 倍） | 说明 |
|---|---|---|---|---|---|
| `dojo` | 练武场 | 3 × 3 | 192 × 192 | 384 × 384（可更高） | 北面一间厅堂 + 南面石板演武场，兵器架、木人桩 |
| `clinic` | 药庐 | 2 × 2 | 128 × 128 | 256 × 256（可更高） | 小屋，门前晾药的竹匾，药香氛围 |
| `library` | 藏经阁 | 2 × 3 | 128 × 192 | 256 × 384（可更高） | 两层重檐楼阁，书卷气 |
| `kitchen` | 伙房 | 2 × 2 | 128 × 128 | 256 × 256（可更高） | 带烟囱的厨房，炊烟 |

- 等级表现建议：1 级朴素；3 级起加金色脊饰、石狮、幡旗；5 级气派、有围墙与牌坊。只出 1 张就够用。
- 右下角的等级牌由引擎绘制，**不要画在图上**。

## 3. 界面皮肤（九宫格）
- 目录：`assets/art/ui/`。都是**九宫格**贴图：四角不拉伸，边和中间拉伸。
- 下表的"边距"是四角保留的像素，**画的时候四角装饰要落在这个范围内**，中间部分要能被拉伸。

| 文件 | 用途 | 尺寸 | 边距 |
|---|---|---|---|
| `panel_plain.png` | 普通面板（导航、顶栏、卡片、日志栏） | 64 × 64 | 12 |
| `panel_ornate.png` | 重要面板（菜单、存档、覆灭提示），可带角饰 | 88 × 88 | 24 |
| `button_normal_normal.png` / `_hover` / `_pressed` / `_disabled` | 普通按钮四个状态 | 48 × 36 | 12 |
| `button_nav_normal.png` / `_hover` / `_pressed` / `_disabled` | 左侧导航按钮 | 48 × 36 | 12 |
| `button_primary_normal.png` / `_hover` / `_pressed` / `_disabled` | 主操作按钮（结束本旬、招收、升级） | 48 × 36 | 12 |
| `background.png` | 整个窗口的背景 | 1920 × 1080 | — |

- 文件名里的 `button_<种类>_<状态>` 与 `src/ui/ui_skin.gd` 一致。
- 尺寸不是死的（引擎会按边距拉伸），但**边距必须和上表一致**，否则四角会变形。想改边距请告诉我，我改代码。
- `background.png` 会铺满窗口（保持比例并裁切），页面里大部分区域是透明的，它会透出来。

## 4. 用 AI 绘图工具出图的小技巧
1. **先定风格再批量出**：用同一段"风格提示词"开头，再接具体内容。例如：
   - 风格：`top-down 3/4 view, hand-painted Chinese ink and watercolor game asset, wuxia sect compound, blue-gray tile roofs, whitewashed walls, red pillars, soft shadow to the lower right, clean edges, transparent background`
   - 内容：`a training hall with a paved martial arts courtyard, weapon racks and wooden dummies, a taiji emblem on the floor`
2. **地图底图**：把 `docs/art/map_guide.png` 作为"构图参考/ControlNet/图生图"输入，提示词写 `river flowing from the top to the right edge, mountains at the left and bottom, grassy plain`，这样山和河会落在对的格子上。
3. **建筑**：每次只画一座，背景要求透明或纯色（纯色后期抠掉）；先出 1 级，满意后再用同一风格出高等级。
4. **检查**：放进目录、重启游戏，进"建筑"页看摆放效果；位置不对就调整图片的留白。
5. 注意**版权**：用 AI 工具出图请确认该工具的商用条款；购买或委托的图请保留授权证明。

## 5. 当前由程序绘制的部分（有图就会被替换）
| 内容 | 程序绘制位置 | 外部图片 |
|---|---|---|
| 地面、河流 | `shaders/terrain.gdshader`、`widgets/terrain_layer.gd` | `map/ground.png` |
| 山、树、竹 | `widgets/map_art.gd` | 包含在 `map/ground.png` 里 |
| 建筑 | `widgets/map_art.gd` 的 `draw_house` | `buildings/*.png` |
| 面板、按钮 | `ui_skin.gd` | `ui/*.png` |
| 窗口背景 | `shaders/background.gdshader` | `ui/background.png` |

## 6. 还没有接入的（以后可以加）
头像（弟子、候选人）、图标（资源、属性）、各页面的标题装饰、字体（现在用系统中文字体，建议换成带书法感的开源字体，如思源宋体，需要单独下载并确认许可）。
