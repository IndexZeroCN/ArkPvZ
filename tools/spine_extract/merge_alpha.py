#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""合并明日方舟分离的 alpha 纹理: 主纹理(RGB, 常为不透明 DXT1) + [alpha] 纹理(灰度) -> RGBA PNG
用法: python merge_alpha.py <main.png> <alpha.png> [out.png]
说明: 方舟 chararts 战斗模型把 alpha 单独存放在 '<名>[alpha]' 纹理中;
      基建模型(B C7)通常自带 alpha, 无需此步骤。"""
import sys
from PIL import Image

def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    main_path, alpha_path = sys.argv[1], sys.argv[2]
    out_path = sys.argv[3] if len(sys.argv) > 3 else main_path
    main_img = Image.open(main_path).convert("RGB")
    alpha_img = Image.open(alpha_path).convert("L")
    if main_img.size != alpha_img.size:
        print(f"尺寸不一致: {main_img.size} vs {alpha_img.size}，请检查配对", file=sys.stderr)
        sys.exit(2)
    out = main_img.copy()
    out.putalpha(alpha_img)
    out.save(out_path)
    trans = sum(1 for p in out.getdata() if p[3] == 0)
    total = out.size[0] * out.size[1]
    print(f"OK: {out_path} ({out.size[0]}x{out.size[1]}, 透明像素 {trans/total:.0%})")

if __name__ == "__main__":
    main()
