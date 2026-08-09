#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PNG 完整解码(RGBA) - 供 Spine 渲染器复用"""
import zlib, struct

def decode_png(path):
    """返回 (width, height, rgba_bytes)"""
    data = open(path, 'rb').read()
    pos = 8
    idat = b''
    w = h = color_type = bit_depth = 0
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos+4])[0]
        ctype = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+length]
        if ctype == b'IHDR':
            w, h, bit_depth, color_type = struct.unpack('>IIBB', chunk[:10])
        elif ctype == b'IDAT':
            idat += chunk
        elif ctype == b'PLTE':
            pass
        pos += 12 + length
    raw = zlib.decompress(idat)
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    stride = w * channels
    out = bytearray()
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i-channels]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i-channels] if i >= channels else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i-channels] if i >= channels else 0
                b = prev[i]
                c = prev[i-channels] if i >= channels else 0
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out += line
        prev = line
    # 转 RGBA
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        base = i * channels
        o = i * 4
        if color_type == 6:  # RGBA
            rgba[o:o+4] = out[base:base+4]
        elif color_type == 2:  # RGB
            rgba[o] = out[base]; rgba[o+1] = out[base+1]; rgba[o+2] = out[base+2]; rgba[o+3] = 255
        elif color_type == 0:  # gray
            v = out[base]; rgba[o:o+3] = bytes([v, v, v]); rgba[o+3] = 255
        elif color_type == 4:  # gray+alpha
            rgba[o] = out[base]; rgba[o+1] = out[base]; rgba[o+2] = out[base]; rgba[o+3] = out[base+1]
        elif color_type == 3:  # palette(简化为不处理, 本素材用不到)
            rgba[o] = out[base]; rgba[o+1] = out[base]; rgba[o+2] = out[base]; rgba[o+3] = 255
    return w, h, bytes(rgba)

if __name__ == '__main__':
    import sys
    w, h, rgba = decode_png(sys.argv[1])
    print('解码:', w, 'x', h, '字节:', len(rgba))
