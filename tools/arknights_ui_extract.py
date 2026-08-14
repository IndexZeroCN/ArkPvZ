#!/usr/bin/env python3
"""从 arknights-ui-master 的 css/styles.css 提取 UI_HOME.png 雪碧图区域，并复制主菜单素材到 ArkPvZ 项目。

用法: python tools/arknights_ui_extract.py
输出: E:/Projects/ArkPvZ/assets/image/arknights_ui/
"""
import os
import shutil
from PIL import Image

SRC = r"E:\Projects\arknights-ui-master\img"
DST = r"E:\Projects\ArkPvZ\assets\image\arknights_ui"

IMG_W, IMG_H = 1024, 2048  # UI_HOME.png 尺寸

# (名称, 元素宽, 元素高, bg-position x, bg-position y, size模式(H=auto H% / W=W% auto), size值)
SPRITES = [
    ("level_logo",         172, 196,   494,  828, "H", 3650),
    ("user_level",         172,  34,   -20, -238, "H", 3650),
    ("chart_bg",           115, 115,     0, -295, "H", 1103),
    ("chart_pr",           115, 115,   488, -398, "H", 1103),
    ("friends_icon",        35,  35,   -69,  -26, "H", 1800),
    ("information_icon",    35,  35,  -195, -897, "H", 1750),
    ("battery",             34,  20,     0,  -34, "H", 4500),
    ("money_icon",          80,  50, -1225, -355, "H", 6600),
    ("jasper_icon",         50,  50,  -446,-1103, "H", 5300),
    ("stone_icon",          50,  50, -1040, -464, "H", 5200),
    ("more",                36,  36,  -732, -595, "H", 5800),
    ("intellect_icon",     140, 140,  -588, -751, "H", 1600),
    ("figure",             195, 130,     0, -531, "H", 1257),
    ("team_icon",           80,  80,   354, -330, "H", 1500),
    ("member_icon",         80,  80,   296, -477, "H", 1500),
    ("shop_icon",           93,  80,   284, -360, "H", 2000),
    ("gamble_top_icon",     20,  20,   -84, -138, "H", 2000),
    ("gamble_left_icon",    50,  50,   276, -172, "H", 1600),
    ("gamble_right_icon",   50,  50,   188, -228, "H", 1650),
    ("task_icon",           72,  80,    -1,  -90, "H", 1800),
    ("infrastructure_icon", 80,  80,   -69,  -61, "H", 1700),
    ("beta",                40,   9,   -20,  -34, "W", 1700),
    ("warehouse_icon",      50,  50,    86, -472, "H", 1700),
    ("activity_title",     140,  24,  -147, 1913, "H", 6000),
]

COPY_FILES = [
    "UI_HOME_FRONT_BKG.png",
    "char_010_chen_2b_merged.png",
    "char_180_amgoat_2_merged_271.png",
    "UI_HOME_ACTIVITY_BANNER_ZONE.png",
    "avg_2_1.png",
]


def scaled_dims(ew, eh, mode, val):
    if mode == "H":
        sh = eh * val / 100.0
        sw = sh * IMG_W / IMG_H
    else:
        sw = ew * val / 100.0
        sh = sw * IMG_H / IMG_W
    return sw, sh


def region_of(ew, eh, px, py, sw, sh):
    """标准公式：可见区域在缩放图坐标 = (-px, -py, ew, eh)。"""
    sx, sy = -px * IMG_W / sw, -py * IMG_H / sh
    w, h = ew * IMG_W / sw, eh * IMG_H / sh
    return (round(sx), round(sy), round(w), round(h))


def region_alt(ew, eh, px, py, sw, sh):
    """备选公式：把正数坐标当作图标在缩放图中的左上角。"""
    sx, sy = px * IMG_W / sw, py * IMG_H / sh
    w, h = ew * IMG_W / sw, eh * IMG_H / sh
    return (round(sx), round(sy), round(w), round(h))


def coverage(img, box):
    """区域内不透明像素占比（判断是否为有效图标）。"""
    x, y, w, h = box
    if x < 0 or y < 0 or x + w > img.width or y + h > img.height:
        return -1.0
    crop = img.crop((x, y, x + w, y + h))
    if crop.mode in ("RGBA", "LA"):
        alpha = crop.getchannel("A")
        return sum(1 for v in alpha.getdata() if v > 16) / (w * h)
    return 1.0


def main():
    os.makedirs(DST, exist_ok=True)
    sheet = Image.open(os.path.join(SRC, "UI_HOME.png"))
    for name, ew, eh, px, py, mode, val in SPRITES:
        sw, sh = scaled_dims(ew, eh, mode, val)
        box = region_of(ew, eh, px, py, sw, sh)
        cov = coverage(sheet, box)
        if cov < 0.3:  # 标准公式没取到有效内容，尝试备选公式
            box2 = region_alt(ew, eh, px, py, sw, sh)
            cov2 = coverage(sheet, box2)
            if cov2 > cov:
                box, cov = box2, cov2
        # 钳制到图内
        x, y, w, h = box
        x = max(0, min(x, sheet.width - 1))
        y = max(0, min(y, sheet.height - 1))
        w = max(1, min(w, sheet.width - x))
        h = max(1, min(h, sheet.height - y))
        crop = sheet.crop((x, y, x + w, y + h))
        crop.save(os.path.join(DST, name + ".png"))
        print(f"{name:22s} region=({x},{y},{w},{h})  coverage={cov:.2f}")

    for f in COPY_FILES:
        shutil.copy2(os.path.join(SRC, f), os.path.join(DST, f))
        print(f"copied {f}")
    print("done ->", DST)


if __name__ == "__main__":
    main()
