#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成维什戴尔魂灵之影攻击射线特效贴图(透明背景)

参照明日方舟游戏内魂灵之影攻击射线全过程:
  1. 射线从魂灵之影射出, 亮红核心线 + 深红辉光, 前端(伸展端)更亮
  2. 命中目标瞬间爆发白红四芒星闪光
  3. 闪光转为暗红近黑的碎片爆发, 伴随一枚蓝色小电火花, 射线同步淡出
输出 4 张贴图到 assets/image/operator/wisdel/beam/:
  beam.png  256x24  射线本体(宽度约10px的等宽线段, 原点端在左, 沿 +X 伸展)
  star.png  96x96   命中四芒星闪光
  burst.png 128x128 暗红碎片爆发
  spark.png 64x64   蓝色小电火花
纯标准库实现, 2x 超采样渲染后盒式降采样
"""
import zlib, struct, math, random, os

SS = 2
OUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'image', 'operator', 'wisdel', 'beam')

random.seed(20250812)

# ---- 通用小工具 ----
def _smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

def _mix(c1, c2, t):
    return tuple(c1[i] + (c2[i] - c1[i]) * t for i in range(3))

class Canvas:
    """浮点 RGBA 帧缓冲(直筒 alpha 叠加)"""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]
        # 值噪声网格
        self._gw, self._gh = w // 8 + 3, h // 8 + 3
        self._grid = [[random.random() for _ in range(self._gw)] for _ in range(self._gh)]

    def noise(self, x, y):
        gx = (x / 8.0) % (self._gw - 2)
        gy = (y / 8.0) % (self._gh - 2)
        x0, y0 = int(gx), int(gy)
        fx, fy = gx - x0, gy - y0
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        g = self._grid
        v00, v10 = g[y0][x0], g[y0][x0 + 1]
        v01, v11 = g[y0 + 1][x0], g[y0 + 1][x0 + 1]
        return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy

    def fbm(self, x, y):
        return 0.65 * self.noise(x, y) + 0.35 * self.noise(x * 2.13, y * 2.13)

    def over(self, x, y, color, alpha):
        if alpha <= 0.0 or not (0 <= x < self.w and 0 <= y < self.h):
            return
        px = self.buf[y * self.w + x]
        a = min(1.0, alpha)
        inv = 1.0 - a
        px[0] = color[0] * a + px[0] * inv
        px[1] = color[1] * a + px[1] * inv
        px[2] = color[2] * a + px[2] * inv
        px[3] = a + px[3] * inv

    def save(self, path):
        ow, oh = self.w // SS, self.h // SS
        out = bytearray(ow * oh * 4)
        for y in range(oh):
            for x in range(ow):
                acc = [0.0, 0.0, 0.0, 0.0]
                for sy in range(SS):
                    for sx in range(SS):
                        p = self.buf[(y * SS + sy) * self.w + (x * SS + sx)]
                        for k in range(4):
                            acc[k] += p[k]
                o = (y * ow + x) * 4
                for k in range(3):
                    out[o + k] = max(0, min(255, int(acc[k] / (SS * SS) + 0.5)))
                out[o + 3] = max(0, min(255, int(acc[3] / (SS * SS) * 255.0 + 0.5)))
        encode_png(path, ow, oh, bytes(out))

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
    print('已生成:', os.path.abspath(path))

# ---- 1. 射线本体: 宽度约10px的等宽线段(亮核心+红辉光), 两端圆角, 前端略亮 ----
def gen_beam():
    W, H = 256 * SS, 24 * SS
    cv = Canvas(W, H)
    cy = H // 2
    C_CORE = (255, 240, 230)
    C_INNER = (255, 54, 36)
    C_MID = (200, 18, 24)
    C_OUTER = (90, 8, 16)
    CAP = 4 * SS  # 端部圆角半径
    for x in range(W):
        t = x / W
        # 前端(伸展端)略亮, 宽度全程不变
        tip_boost = 1.0 + 0.45 * _smooth((t - 0.88) / 0.12)
        # 两端圆角: 超出主体段的水平距离并入垂直距离
        dx_cap = max(0.0, float(CAP - x), float(x - (W - CAP))) / SS
        for y in range(H):
            d = math.sqrt((abs(y - cy) / SS) ** 2 + dx_cap * dx_cap)
            n = 0.80 + 0.20 * cv.fbm(x * 1.9, y * 1.9)
            a_core = _smooth(1.0 - d / 2.2) * 0.95
            a_inner = _smooth(1.0 - d / 4.2) * 0.85
            a_mid = _smooth(1.0 - d / 5.5) * 0.50
            a_outer = _smooth(1.0 - d / 8.0) * 0.30
            for col, a in ((C_OUTER, a_outer), (C_MID, a_mid), (C_INNER, a_inner), (C_CORE, a_core)):
                cv.over(x, y, col, min(1.0, a * tip_boost) * n)
    cv.save(os.path.join(OUT_DIR, 'beam.png'))

# ---- 2. 四芒星闪光: 白核心 + 细锐四星芒 + 红晕 ----
def gen_star():
    W = H = 96 * SS
    cv = Canvas(W, H)
    cx = cy = W // 2
    SPIKE = 44 * SS
    for y in range(H):
        for x in range(W):
            dx, dy = x - cx, y - cy
            r = math.sqrt(dx * dx + dy * dy)
            if r >= SPIKE:
                continue
            theta = math.atan2(dy, dx)
            # 四芒星半径函数: |cos(2θ)| 高次幂 -> 细锐星芒
            spike_r = SPIKE * (abs(math.cos(2 * theta)) ** 6)
            in_spike = r < spike_r
            # 白核心
            a = _smooth(1.0 - r / (9.0 * SS))
            cv.over(x, y, (255, 252, 248), a)
            # 星芒: 根部近白 -> 尖端亮红
            if in_spike:
                t = r / max(spike_r, 1.0)
                col = _mix((255, 224, 205), (255, 48, 30), t)
                cv.over(x, y, col, _smooth(1.0 - t) * 0.95)
            # 红色光晕
            cv.over(x, y, (255, 60, 36), _smooth(1.0 - r / (30.0 * SS)) * 0.30)
    cv.save(os.path.join(OUT_DIR, 'star.png'))

# ---- 3. 暗红碎片爆发: 中心暗核 + 放射状尖锐碎片(外端近黑) ----
def gen_burst():
    W = H = 128 * SS
    cv = Canvas(W, H)
    cx = cy = W // 2
    # 预生成碎片参数: (方向角, 长度, 半宽)
    shards = []
    for i in range(11):
        ang = i * (2 * math.pi / 11) + random.uniform(-0.22, 0.22)
        shards.append((ang, random.uniform(30, 56) * SS, random.uniform(3.5, 7.0) * SS))
    for y in range(H):
        for x in range(W):
            dx, dy = x - cx, y - cy
            r = math.sqrt(dx * dx + dy * dy)
            if r >= 60 * SS:
                continue
            # 中心暗核 + 红晕
            cv.over(x, y, (150, 16, 22), _smooth(1.0 - r / (20.0 * SS)) * 0.55)
            cv.over(x, y, (42, 5, 10), _smooth(1.0 - r / (13.0 * SS)) * 0.9)
            # 碎片
            for ang, slen, sw in shards:
                ux, uy = math.cos(ang), math.sin(ang)
                t = dx * ux + dy * uy
                if t < 0 or t > slen:
                    continue
                perp = abs(dx * uy - dy * ux)
                w_here = sw * (1.0 - t / slen) + 0.8 * SS
                if perp >= w_here:
                    continue
                k = t / slen
                n = 0.55 + 0.45 * cv.fbm(x * 2.7, y * 2.7)
                col = _mix((120, 14, 20), (16, 3, 6), k)   # 根部暗红 -> 尖端近黑
                a = _smooth(1.0 - perp / w_here) * (1.0 - 0.55 * k) * n * 0.95
                cv.over(x, y, col, a)
    cv.save(os.path.join(OUT_DIR, 'burst.png'))

# ---- 4. 蓝色小电火花: 两条锯齿折线闪电 ----
def gen_spark():
    W = H = 64 * SS
    cv = Canvas(W, H)
    C_CORE = (215, 242, 255)
    C_GLOW = (85, 184, 255)
    C_OUTER = (26, 95, 168)
    # 折线顶点: 左上 -> 右下 随机锯齿
    for x0, y0, x1, y1 in ((10, 14, 52, 46), (18, 50, 46, 16)):
        pts = [(x0 * SS, y0 * SS)]
        segs = 6
        for i in range(1, segs):
            t = i / segs
            px = (x0 + (x1 - x0) * t) * SS + random.uniform(-6, 6) * SS
            py = (y0 + (y1 - y0) * t) * SS + random.uniform(-6, 6) * SS
            pts.append((px, py))
        pts.append((x1 * SS, y1 * SS))
        # 对每条线段周围像素按距离上色
        for i in range(len(pts) - 1):
            ax, ay = pts[i]
            bx, by = pts[i + 1]
            minx, maxx = int(min(ax, bx)) - 10 * SS, int(max(ax, bx)) + 10 * SS
            miny, maxy = int(min(ay, by)) - 10 * SS, int(max(ay, by)) + 10 * SS
            vx, vy = bx - ax, by - ay
            vv = vx * vx + vy * vy
            for y in range(max(0, miny), min(H, maxy)):
                for x in range(max(0, minx), min(W, maxx)):
                    t = ((x - ax) * vx + (y - ay) * vy) / vv if vv else 0.0
                    t = max(0.0, min(1.0, t))
                    d = math.sqrt((x - ax - t * vx) ** 2 + (y - ay - t * vy) ** 2) / SS
                    cv.over(x, y, C_OUTER, _smooth(1.0 - d / 5.0) * 0.25)
                    cv.over(x, y, C_GLOW, _smooth(1.0 - d / 2.6) * 0.55)
                    cv.over(x, y, C_CORE, _smooth(1.0 - d / 1.1) * 0.95)
    cv.save(os.path.join(OUT_DIR, 'spark.png'))

if __name__ == '__main__':
    os.makedirs(OUT_DIR, exist_ok=True)
    gen_beam()
    gen_star()
    gen_burst()
    gen_spark()
