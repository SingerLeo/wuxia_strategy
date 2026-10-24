extends GutTest
## 美术管线：没有外部图时返回 null（程序绘制顶上）、有图时按规则找到；界面皮肤贴图与主题。

const TMP := "user://art_test/"


func before_each() -> void:
	ArtLibrary.set_root(TMP)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "buildings"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP + "ui"))


func after_each() -> void:
	for dir in ["buildings", "ui", "map"]:
		var path := ProjectSettings.globalize_path(TMP + dir)
		var d := DirAccess.open(path)
		if d != null:
			for f in d.get_files():
				DirAccess.remove_absolute(path + "/" + f)
	ArtLibrary.set_root(ArtLibrary.DEFAULT_ROOT)


func _write_png(rel: String, w: int, h: int, col: Color) -> void:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	img.save_png(ProjectSettings.globalize_path(TMP + rel))
	ArtLibrary.clear_cache()


# --- ArtLibrary ---

func test_missing_art_returns_null() -> void:
	assert_null(ArtLibrary.load_png("nope/missing.png"))
	assert_null(ArtLibrary.building_texture(&"dojo", 1))
	assert_null(ArtLibrary.map_background())
	assert_null(ArtLibrary.window_background())
	assert_null(ArtLibrary.ui_texture("panel_ornate"))


func test_loads_a_png_from_the_art_folder() -> void:
	_write_png("ui/panel_plain.png", 20, 10, Color.RED)
	var tex := ArtLibrary.ui_texture("panel_plain")
	assert_not_null(tex)
	assert_eq(tex.get_width(), 20)
	assert_eq(tex.get_height(), 10)


func test_building_lookup_prefers_level_then_generic() -> void:
	_write_png("buildings/dojo.png", 8, 8, Color.BLUE)
	assert_eq(ArtLibrary.building_texture(&"dojo", 3).get_width(), 8, "没有 lv3 就用通用的")
	_write_png("buildings/dojo_lv3.png", 16, 16, Color.GREEN)
	assert_eq(ArtLibrary.building_texture(&"dojo", 3).get_width(), 16, "有 lv3 就用 lv3")
	assert_eq(ArtLibrary.building_texture(&"dojo", 1).get_width(), 8, "其他等级仍用通用的")


func test_building_lookup_prefers_the_rotated_variant_when_rotated() -> void:
	_write_png("buildings/library.png", 8, 12, Color.BLUE)
	assert_eq(ArtLibrary.building_texture(&"library", 1, 1).get_width(), 8, "没有旋转版就退回普通版")
	_write_png("buildings/library_r.png", 12, 8, Color.GREEN)
	assert_eq(ArtLibrary.building_texture(&"library", 1, 1).get_width(), 12, "旋转时用旋转版")
	assert_eq(ArtLibrary.building_texture(&"library", 1, 0).get_width(), 8, "不旋转仍用普通版")


func test_results_are_cached_until_reload() -> void:
	assert_null(ArtLibrary.ui_texture("panel_plain"))
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.save_png(ProjectSettings.globalize_path(TMP + "ui/panel_plain.png"))
	assert_null(ArtLibrary.ui_texture("panel_plain"), "缓存了'没有'，不会马上看到新文件")
	ArtLibrary.clear_cache()
	assert_not_null(ArtLibrary.ui_texture("panel_plain"))


# --- 界面皮肤 ---

func test_skin_panels_are_nine_patch_styleboxes() -> void:
	var plain := UiSkin.panel(false)
	var ornate := UiSkin.panel(true)
	assert_not_null(plain.texture)
	assert_not_null(ornate.texture)
	assert_eq(plain.texture_margin_left, 12)
	assert_eq(ornate.texture_margin_left, 24)
	assert_gt(ornate.texture.get_width(), ornate.texture_margin_left * 2, "中间要留出可拉伸的部分")


func test_skin_has_every_button_variant_and_state() -> void:
	for variant in ["normal", "nav", "primary"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var s := UiSkin.button(variant, state)
			assert_not_null(s.texture, "%s_%s" % [variant, state])
			assert_gt(s.texture.get_width(), s.texture_margin_left * 2)


func test_skin_corners_are_transparent_and_center_is_opaque() -> void:
	var img := UiSkin.button("normal", "normal").texture.get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "圆角之外透明")
	assert_gt(img.get_pixel(img.get_width() / 2, img.get_height() / 2).a, 0.9, "中心不透明")


func test_ornate_panel_has_gold_corner_ornaments() -> void:
	var img := UiSkin.panel(true).texture.get_image()
	var found_gold := false
	for y in 16:
		for x in 16:
			var c := img.get_pixel(x, y)
			if c.a > 0.9 and c.r > 0.65 and c.g > 0.5 and c.b < 0.5:
				found_gold = true
	assert_true(found_gold, "左上角应有金色的折角或菱形")


func test_theme_uses_the_skin() -> void:
	var t := ThemeBuilder.build()
	assert_true(t.get_stylebox("panel", "PanelContainer") is StyleBoxTexture)
	assert_true(t.get_stylebox("panel", "OrnatePanel") is StyleBoxTexture)
	assert_eq(t.get_type_variation_base(&"OrnatePanel"), &"PanelContainer")
	assert_true(t.get_stylebox("normal", "PrimaryButton") is StyleBoxTexture)
	assert_true(t.get_stylebox("pressed", "NavButton") is StyleBoxTexture)


func test_background_material_has_the_shader() -> void:
	var m := ThemeBuilder.background_material()
	assert_not_null(m)
	assert_not_null(m.shader)
