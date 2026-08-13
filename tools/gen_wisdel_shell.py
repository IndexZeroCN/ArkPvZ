#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成维什戴尔炮弹贴图 wisdel_03.png(256x256, 透明背景)

样式: 亮红橙色发光弹头(头部朝右, +X 方向, 子弹节点按 direction.angle() 旋转)。
**只含弹头本体, 不含烘焙拖尾** —— 拖尾由 TrailComet 动态亮带组件单独承担,
炮弹与拖尾分离(避免贴图尾迹与动态亮带叠加/颜色打架)。
纯标准库实现(无 PIL/numpy 依赖), 2x 超采样渲染后盒式降采样
"""
import zlib, struct, math, os, sys

W = H = 256          # 输出尺寸
SS = 2               # 超采样倍数
SW, SH = W * SS, H * SS

# ---- 布局参数(超采样坐标系) ----
HEAD_X, HEAD_Y = 232 * SS, 128 * SS   # 弹头中心(靠右, 视觉大小与原 128 版一致)

# ---- 颜色 ----
C_HOT = (255, 244, 214)    # 弹头高温核心(近白黄)
C_MID = (255, 128, 48)     # 弹头橙
C_GLOW = (255, 56, 32)     # 弹头红外辉光

# ---- 弹头辉光: 三层径向衰减(近白核心/橙/红外晕), 向尾部略拉伸 ----
buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(SW * SH)]

def _over(px, color, alpha):
    if alpha <= 0.0:
        return
    a = min(1.0, alpha)
    inv = 1.0 - a
    px[0] = color[0] * a + px[0] * inv
    px[1] = color[1] * a + px[1] * inv
    px[2] = color[2] * a + px[2] * inv
    px[3] = a + px[3] * inv

def draw_head():
    layers = [
        (7.5 * SS, C_HOT, 1.00),
        (14.0 * SS, C_MID, 0.85),
        (26.0 * SS, C_GLOW, 0.42),
    ]
    R = int(30 * SS)
    for y in range(HEAD_Y - R, HEAD_Y + R):
        for x in range(HEAD_X - R, HEAD_X + R):
            if not (0 <= x < SW and 0 <= y < SH):
                continue
            dx, dy = x - HEAD_X, y - HEAD_Y
            # 尾部方向(左)略拉伸辉光(与拖尾衔接处更宽, 拖尾由动态亮带补上)
            sx = dx * (0.85 if dx < 0 else 1.0)
            r = math.sqrt(sx * sx + dy * dy)
            i = y * SW + x
            for sigma, col, amax in layers:
                g = math.exp(-(r / sigma) ** 2)
                _over(buf[i], col, g * amax)

def encode_png(path, w, h, rgba):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        raw += rgba[y * w * 4:(y + 1) * w * 4]
    def chunk(ctype, data):
        c = struct.pack('>I', len(data)) + ctype + data
        return c + struct.pack('>I', zlib.crc32(ctype + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)

def main():
    draw_head()
    # 盒式降采样到 256x256
    out = bytearray(W * H * 4)
    for y in range(H):
        for x in range(W):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sy in range(SS):
                for sx in range(SS):
                    p = buf[(y * SS + sy) * SW + (x * SS + sx)]
                    for k in range(4):
                        acc[k] += p[k]
            o = (y * W + x) * 4
            for k in range(3):
                out[o + k] = max(0, min(255, int(acc[k] / (SS * SS) + 0.5)))
            # alpha 通道是 0~1 浮点, 需放大到 0~255
            out[o + 3] = max(0, min(255, int(acc[3] / (SS * SS) * 255.0 + 0.5)))
    dst = sys.argv[1] if len(sys.argv) > 1 else \
        os.path.join(os.path.dirname(__file__), '..', 'assets', 'image', 'operator', 'wisdel', 'bullet', 'wisdel_03.png')
    dst = os.path.abspath(dst)
    encode_png(dst, W, H, bytes(out))
    print('已生成:', dst)

if __name__ == '__main__':
    main()
