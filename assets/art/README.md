# assets/art

把外部美术放在这里，游戏启动时会自动用它们替换程序绘制的画面；没有图的地方照常用程序画的。

```
assets/art/
  map/ground.png            整张山门地图的底图（3:2，推荐 1536×1024）
  buildings/<id>.png        建筑精灵，id：dojo / clinic / library / kitchen
  buildings/<id>_lv3.png    指定等级的版本（可选）
  buildings/<id>_r.png      旋转 90° 的版本（可选）
  ui/panel_plain.png ...    界面皮肤（九宫格）
  ui/background.png         窗口背景
```

规格、尺寸、命名、AI 出图提示词见 `docs/art-spec.md`。
地图参考图：`docs/art/map_guide.png`。
