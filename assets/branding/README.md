# 健康档案 · 应用图标

| 文件 | 说明 |
|---|---|
| `app-icon-source.png` | 原始效果图（1024，近白底 + 投影 + 居中圆角方块）。只作源图，不直接当图标用 |
| `app-icon-fullbleed.png` | 由脚本生成：只取圆角方块内部、四角补色后的全出血方图，1024 |

所有平台图标都由 `scripts/generate_app_icon.py` 从源图生成，**不要手改生成物**：

- Android 旧版图标：`mipmap-*/ic_launcher.png`（48–192，自带圆角）
- Android 8+ 自适应图标：`mipmap-*/ic_launcher_foreground.png`（108dp 画布，全出血图占 76dp）
  + `mipmap-anydpi-v26/ic_launcher.xml` + `values/ic_launcher_colors.xml`
- iOS：`ios/Runner/Assets.xcassets/AppIcon.appiconset/` 全部尺寸（不带透明、不自绘圆角）

换源图后要重新量圆角方块的位置与圆角半径，改脚本顶部的 `BOX_*` 与
`CORNER_RADIUS`，再运行：

```bash
python3 scripts/generate_app_icon.py
```

源图图案几乎顶到边，脚本会把整张图缩到 `CONTENT_SCALE`（当前 0.78）放在中间，
四周用它自己的边缘像素向外延伸并模糊填满。嫌满或嫌空就改这个数重新生成。

已知限制：源图只有约 670px 的有效区域，iOS 1024 尺寸是放大得到的，略软。
