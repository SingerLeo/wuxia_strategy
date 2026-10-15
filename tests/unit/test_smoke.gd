extends GutTest
## 冒烟测试：确认 Godot 与 GUT 能一起工作。


func test_engine_runs() -> void:
	assert_eq(1 + 1, 2, "基本算术应当成立")


func test_engine_version_is_4() -> void:
	assert_eq(Engine.get_version_info().major, 4, "应当运行在 Godot 4 上")
