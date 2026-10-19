# 武侠门派策略游戏

Godot 4.7（GDScript）。设计文档见 `docs/design.md`。

## 目录约定
- `src/core/` 纯游戏逻辑（弟子、武学、战斗、经济），不依赖 Node 与场景，便于无界面测试
- `src/ui/`、`scenes/` 界面与场景
- `data/` 数据驱动内容（弟子模板、武学树、事件），JSON/Resource
- `tests/` GUT 测试，文件名 `test_*.gd`
- `scripts/` 环境安装与检查脚本
- `addons/gut/` 测试框架（已提交，勿手改）

## 常用命令（Windows，用 console 版以便看到输出）
首次或资源变动后导入：
```
godot_console --headless --import
```
运行全部测试：
```
godot_console --headless -s addons/gut/gut_cmdln.gd -gexit
```

数值模拟报告（调平衡时用）：
```
godot_console --headless -s tools/sim_report.gd -- --n=500 --years=20 --seed=1
```

## 约定
- 游戏逻辑必须能在 `--headless` 下测试；随机数通过可注入的 RandomNumberGenerator，便于固定种子复现
- 含中文的 `.ps1` 文件必须保存为带 BOM 的 UTF-8
- `git push` 只在用户明确说「push」时执行；平时的改动只做到本地 commit
- 每完成一次改动，重新启动游戏窗口（`godot.exe --path .`）让用户能立即看到最新版；启动前先确认旧进程已关闭
