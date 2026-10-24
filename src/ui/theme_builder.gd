class_name ThemeBuilder
extends RefCounted
## 全局主题：暗色水墨 + 金色点缀。改外观只改这里。
## 类型变体：Heading / Subheading / Muted（Label）、NavButton / PrimaryButton（Button）

const BG := Color("#171512")
const PANEL := Color("#211f1b")
const PANEL_ALT := Color("#2a2722")
const BORDER := Color("#3d382f")
const TEXT := Color("#e8dfcc")
const MUTED := Color("#8f8774")
const GOLD := Color("#c9a45c")
const GOLD_DARK := Color("#5a4a2b")
const WARN := Color("#d1704f")

const FONT_SIZE := 18


static func box(bg: Color, border: Color = BORDER, radius: int = 4, border_w: int = 1, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_SIZE

	# 文字
	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation(&"Heading", &"Label")
	t.set_font_size("font_size", "Heading", 28)
	t.set_color("font_color", "Heading", GOLD)
	t.set_type_variation(&"Subheading", &"Label")
	t.set_font_size("font_size", "Subheading", 20)
	t.set_color("font_color", "Subheading", GOLD)
	t.set_type_variation(&"Muted", &"Label")
	t.set_color("font_color", "Muted", MUTED)
	t.set_color("default_color", "RichTextLabel", TEXT)

	# 面板：默认是低调的漆面板；OrnatePanel 带金色内描线和角饰，用于菜单、对话框等重要面板
	t.set_stylebox("panel", "PanelContainer", UiSkin.panel(false))
	t.set_type_variation(&"OrnatePanel", &"PanelContainer")
	t.set_stylebox("panel", "OrnatePanel", UiSkin.panel(true))

	# 普通按钮
	t.set_stylebox("normal", "Button", UiSkin.button("normal", "normal"))
	t.set_stylebox("hover", "Button", UiSkin.button("normal", "hover"))
	t.set_stylebox("pressed", "Button", UiSkin.button("normal", "pressed"))
	t.set_stylebox("disabled", "Button", UiSkin.button("normal", "disabled"))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)

	# 导航按钮
	t.set_type_variation(&"NavButton", &"Button")
	t.set_stylebox("normal", "NavButton", UiSkin.button("nav", "normal"))
	t.set_stylebox("hover", "NavButton", UiSkin.button("nav", "hover"))
	t.set_stylebox("pressed", "NavButton", UiSkin.button("nav", "pressed"))
	t.set_stylebox("hover_pressed", "NavButton", UiSkin.button("nav", "pressed"))
	t.set_stylebox("disabled", "NavButton", UiSkin.button("nav", "disabled"))

	# 主操作按钮
	t.set_type_variation(&"PrimaryButton", &"Button")
	t.set_stylebox("normal", "PrimaryButton", UiSkin.button("primary", "normal"))
	t.set_stylebox("hover", "PrimaryButton", UiSkin.button("primary", "hover"))
	t.set_stylebox("pressed", "PrimaryButton", UiSkin.button("primary", "pressed"))
	t.set_stylebox("disabled", "PrimaryButton", UiSkin.button("primary", "disabled"))

	# 下拉框弹出菜单
	t.set_stylebox("panel", "PopupMenu", box(PANEL_ALT, GOLD_DARK))
	t.set_stylebox("hover", "PopupMenu", box(GOLD_DARK, GOLD_DARK, 2, 0, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)

	# 进度条
	t.set_stylebox("background", "ProgressBar", box(BG, BORDER, 3, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, GOLD, 3, 0, 0))

	# 列表 / 表格
	t.set_stylebox("panel", "Tree", box(PANEL, BORDER, 4, 1, 4))
	t.set_stylebox("selected", "Tree", box(GOLD_DARK, GOLD_DARK, 2, 0, 2))
	t.set_stylebox("selected_focus", "Tree", box(GOLD_DARK, GOLD, 2, 1, 2))
	t.set_stylebox("title_button_normal", "Tree", box(PANEL_ALT, BORDER, 0, 1, 6))
	t.set_stylebox("title_button_hover", "Tree", box(PANEL_ALT, BORDER, 0, 1, 6))
	t.set_stylebox("title_button_pressed", "Tree", box(PANEL_ALT, BORDER, 0, 1, 6))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_selected_color", "Tree", TEXT)
	t.set_color("title_button_color", "Tree", GOLD)
	t.set_color("guide_color", "Tree", BORDER)
	t.set_constant("v_separation", "Tree", 6)

	return t

## 窗口背景：暗色宣纸 + 水墨远山（着色器）。若 assets/art/ui/background.png 存在则由调用方改用图片。
static func background_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://src/ui/shaders/background.gdshader")
	return m
