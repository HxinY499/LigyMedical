#!/usr/bin/env python3
"""从一张「圆角方块图标」的效果图生成 Android / iOS 全套启动图标。

源图（assets/branding/app-icon-source.png）是一张 1024 的效果图：近白底 + 投影 +
居中的圆角方块。直接拿去当图标，系统会再套一层遮罩，变成「图标里套图标」。所以：

1. 只取圆角方块内部，裁成正方形；
2. 四个圆角外露出的白底，用沿半径方向向外延伸的边缘色填满——系统遮罩会把角切掉，
   这里只要保证不露白；
3. 图案整体缩小、四周留白（见 shrink_content），背景渐变仍然铺满；
4. 由这张全出血的方图生成各尺寸。

依赖 Pillow 与 NumPy：`python3 -m pip install pillow numpy`
用法：`python3 scripts/generate_app_icon.py`
"""

import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/branding/app-icon-source.png"
FULL_BLEED = ROOT / "assets/branding/app-icon-fullbleed.png"
RES = ROOT / "android/app/src/main/res"
IOS_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"

# 源图里圆角方块的几何（像素），由扫描源图得出。换源图时要重新量。
BOX_LEFT, BOX_TOP, BOX_RIGHT, BOX_BOTTOM = 174, 169, 849, 873
CORNER_RADIUS = 155
# 往里收几像素，避开方块边缘的抗锯齿与描边高光。
INSET = 4

# 图案缩到原来的多少。源图图案几乎顶到边，桌面上显得太满。
CONTENT_SCALE = 0.78

# 自适应图标：前景画布 108dp，系统只露出中间 72dp。全出血图放到 76dp，
# 比可见区略大一点，避免遮罩边缘露出前景的直边。
ADAPTIVE_ART_RATIO = 76 / 108

LEGACY_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE_SIZES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def crop_full_bleed(src: Image.Image) -> Image.Image:
    """裁出圆角方块内部的正方形，并把四角的白底换成延伸出来的边缘色。"""
    width = BOX_RIGHT - BOX_LEFT + 1 - 2 * INSET
    height = BOX_BOTTOM - BOX_TOP + 1 - 2 * INSET
    side = min(width, height)
    left = BOX_LEFT + INSET + (width - side) // 2
    top = BOX_TOP + INSET + (height - side) // 2
    art = src.crop((left, top, left + side, top + side)).convert("RGB")
    pixels = art.load()

    # 四个圆角的圆心，换算到裁剪后的坐标系。
    r = CORNER_RADIUS
    centers = {
        "tl": (BOX_LEFT + r - left, BOX_TOP + r - top),
        "tr": (BOX_RIGHT - r - left, BOX_TOP + r - top),
        "bl": (BOX_LEFT + r - left, BOX_BOTTOM - r - top),
        "br": (BOX_RIGHT - r - left, BOX_BOTTOM - r - top),
    }
    # 原图圆角内侧有一圈抗锯齿与高光，替换带要越过它，否则母图四角会留一道浅色弧线。
    replace_from = r - 18
    sample_radius = r - 26
    for y in range(side):
        for x in range(side):
            for key, (cx, cy) in centers.items():
                in_corner = (
                    (key[0] == "t" and y < cy or key[0] == "b" and y > cy)
                    and (key[1] == "l" and x < cx or key[1] == "r" and x > cx)
                )
                if not in_corner:
                    continue
                dx, dy = x - cx, y - cy
                dist = math.hypot(dx, dy)
                if dist <= replace_from:
                    continue
                sx = int(round(cx + dx / dist * sample_radius))
                sy = int(round(cy + dy / dist * sample_radius))
                sx = min(max(sx, 0), side - 1)
                sy = min(max(sy, 0), side - 1)
                pixels[x, y] = pixels[sx, sy]
    return art


def shrink_content(art: Image.Image, scale: float, size: int = 1024) -> Image.Image:
    """把图案整体缩小、四周留白，背景仍然铺满。

    源图图案几乎顶到方块边缘，桌面上显得太满。源图是不分层的平面图，不能单独挪
    图案，所以把整张图缩小放在中间，四周用它自己的边缘像素向外延伸再高斯模糊填满。

    不用「拟合一个渐变当背景」：源图背景不是线性渐变（左上偏亮，底边是文件夹的
    投影一直压到边），拟合出来的颜色在边上对不齐，缩小后的方图四周会显出一圈方框。
    边缘延伸在交界处与原图逐像素相同，接缝无从产生。
    """
    art_px = round(size * scale)
    piece = art.resize((art_px, art_px), Image.LANCZOS).convert("RGB")
    offset = (size - art_px) // 2
    pad_after = size - art_px - offset
    arr = np.asarray(piece, dtype=np.uint8)
    padded = np.pad(arr, ((offset, pad_after), (offset, pad_after), (0, 0)), mode="edge")
    # 延伸出来的是一道道与边垂直的条纹，模糊把它们抹成平滑的色场。
    blurred = np.asarray(
        Image.fromarray(padded, "RGB").filter(ImageFilter.GaussianBlur(radius=size * 0.03)),
        dtype=np.float64,
    )

    # 原图区域内保持清晰，只在最外 3% 由清晰过渡到模糊，避免模糊带切出一道硬边。
    yy, xx = np.mgrid[0:size, 0:size]
    inner = np.minimum.reduce([xx - offset, yy - offset,
                               offset + art_px - 1 - xx, offset + art_px - 1 - yy])
    ramp = art_px * 0.03
    alpha = np.clip(inner / ramp, 0, 1)
    alpha = (alpha * alpha * (3 - 2 * alpha))[..., None]
    out = blurred * (1 - alpha) + padded.astype(np.float64) * alpha
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def rounded(img: Image.Image, size: int, radius_ratio: float = 0.2237) -> Image.Image:
    out = img.resize((size, size), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * radius_ratio), fill=255
    )
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def edge_color(img: Image.Image) -> str:
    """全出血图四条边中段的平均色，作自适应图标的背景色兜底。"""
    w, h = img.size
    samples = []
    for t in range(w // 4, w * 3 // 4):
        samples += [img.getpixel((t, 2)), img.getpixel((t, h - 3)),
                    img.getpixel((2, t)), img.getpixel((w - 3, t))]
    r, g, b = (sum(c[i] for c in samples) // len(samples) for i in range(3))
    return f"#{r:02X}{g:02X}{b:02X}"


def main() -> None:
    src = Image.open(SOURCE)
    art = crop_full_bleed(src)
    master = shrink_content(art, CONTENT_SCALE)
    master.save(FULL_BLEED)

    for density, size in LEGACY_SIZES.items():
        rounded(master, size).save(RES / f"mipmap-{density}/ic_launcher.png")

    for density, size in ADAPTIVE_SIZES.items():
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        art_size = round(size * ADAPTIVE_ART_RATIO)
        piece = master.resize((art_size, art_size), Image.LANCZOS).convert("RGBA")
        offset = (size - art_size) // 2
        canvas.paste(piece, (offset, offset))
        canvas.save(RES / f"mipmap-{density}/ic_launcher_foreground.png")

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )
    (RES / "values/ic_launcher_colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        "    <!-- 自适应图标背景：前景比可见区略大，正常情况下看不到这层。"
        "由 scripts/generate_app_icon.py 生成。 -->\n"
        f'    <color name="ic_launcher_background">{edge_color(master)}</color>\n'
        "</resources>\n"
    )

    contents = json.loads((IOS_SET / "Contents.json").read_text())
    rgb = master.convert("RGB")
    for item in contents["images"]:
        points = float(item["size"].split("x")[0])
        scale = int(item["scale"].rstrip("x"))
        px = round(points * scale)
        rgb.resize((px, px), Image.LANCZOS).save(IOS_SET / item["filename"])

    print(f"full-bleed: {FULL_BLEED.relative_to(ROOT)}")
    print("android: legacy + adaptive written")
    print(f"ios: {len(contents['images'])} images written")


if __name__ == "__main__":
    sys.exit(main())
