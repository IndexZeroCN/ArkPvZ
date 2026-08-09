#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""探测明日方舟加密 skel: 从加密头后各偏移尝试标准 Spine 3.8 解析, 找到有效数据起点"""
import struct, sys

class Reader:
    def __init__(self, data, pos=0):
        self.d = data; self.p = pos
    def read_byte(self):
        v = self.d[self.p]; self.p += 1
        return v
    def read_bool(self):
        return self.read_byte() != 0
    def read_varint(self):
        b = self.read_byte()
        v = b & 0x7f
        if b & 0x80:
            b = self.read_byte()
            v |= (b & 0x7f) << 7
            if b & 0x80:
                b = self.read_byte()
                v |= (b & 0x7f) << 14
                if b & 0x80:
                    b = self.read_byte()
                    v |= (b & 0x7f) << 21
                    if b & 0x80:
                        v |= (self.read_byte() & 0x7f) << 28
        return v
    def read_float(self):
        v = struct.unpack_from('<f', self.d, self.p)[0]; self.p += 4
        return v
    def read_string(self):
        n = self.read_varint()
        if n <= 1:
            return "" if n == 0 else None
        s = self.d[self.p:self.p+n].decode('utf-8', errors='replace')
        self.p += n
        return s

def try_parse(data, offset, max_depth=200):
    """从 offset 按标准 3.8 解析, 返回 (成功, bones数, slots数, anims, 错误位置)"""
    try:
        r = Reader(data, offset)
        name = r.read_string()
        version = r.read_string()
        hash_ = r.read_string()
        width = r.read_float(); height = r.read_float()
        if version not in ("3.8.99", "3.8.90", "3.8.0"):
            return False, f"version={version}"
        images = r.read_varint()
        if images == 0:
            r.read_byte()
        for _ in range(images):
            r.read_string()
        skin_count = r.read_varint()
        if skin_count == 0:
            r.read_byte()
        for _ in range(skin_count):
            r.read_string()
            sc = r.read_varint()
            for _ in range(sc):
                r.read_varint()
                ac = r.read_varint()
                for _ in range(ac):
                    r.read_string()
                    t = r.read_byte()
                    if t == 0:
                        r.read_string(); r.read_string()
                        for _ in range(7): r.read_float()
                        if r.read_bool(): r.read_string()
                    elif t in (2, 3):
                        r.read_string()
                        vn = r.read_varint()
                        for _ in range(vn*2): r.read_float()
                        uv = r.read_varint()
                        for _ in range(uv*2): r.read_float()
                        tn = r.read_varint()
                        for _ in range(tn*3): r.read_short()
                        r.read_varint()
                        e = r.read_varint()
                        for _ in range(e): r.read_varint()
                        if t == 3: r.read_string()
                        if r.read_bool(): r.read_string()
                    elif t == 1:
                        vn = r.read_varint()
                        for _ in range(vn*2): r.read_float()
                        if r.read_bool(): r.read_string()
                    else:
                        return False, f"attachment type={t} @{r.p}"
        bone_count = r.read_varint()
        for _ in range(bone_count):
            r.read_string(); r.read_varint()
            r.read_float()
            for _ in range(7): r.read_float()
            r.read_byte()
            if r.read_bool(): r.read_string()
        slot_count = r.read_varint()
        for _ in range(slot_count):
            r.read_string(); r.read_varint(); r.read_varint()
            if r.read_bool(): r.read_string()
            if r.read_bool(): r.read_string()
        # ik/transform/path/deform/events 粗略跳过(只统计)
        ik = r.read_varint()
        for _ in range(ik):
            r.read_string(); r.read_varint(); r.read_varint()
            for _ in range(3): r.read_float()
        tr = r.read_varint()
        for _ in range(tr):
            r.read_string(); r.read_varint(); r.read_varint()
            for _ in range(10): r.read_float()
            r.read_byte()
        pa = r.read_varint()
        for _ in range(pa):
            r.read_string(); r.read_varint(); r.read_varint()
            for _ in range(9): r.read_float()
            r.read_byte()
            for _ in range(3): r.read_float()
            r.read_byte()
        ds = r.read_varint()
        for _ in range(ds): r.read_varint()
        ev = r.read_varint()
        for _ in range(ev):
            r.read_string()
            for _ in range(3): r.read_float()
            if r.read_bool(): r.read_string()
            if r.read_bool(): r.read_string()
            if r.read_bool(): r.read_string()
        anims = r.read_varint()
        return True, f"offset={offset} name={name} width={width} height={height} bones={bone_count} slots={slot_count} ik={ik} anims={anims} pos={r.p}"
    except Exception as e:
        return False, f"exception {e}"

def main(path):
    data = open(path, 'rb').read()
    # 找加密头结束: 1c + random + 07 + version + 00
    idx_07 = data.find(b'\x07', 1)
    if idx_07 == -1:
        print("未找到 0x07")
        return
    # 版本字符串(到 00)
    end = data.find(b'\x00', idx_07)
    version = data[idx_07+1:end].decode(errors='replace')
    print("加密头: 1c@0, 07@", idx_07, "版本:", version, "加密头结束@", end)
    # 从 end 后各偏移尝试
    for off in range(0, 40):
        ok, msg = try_parse(data, end + off)
        if ok:
            print("  [成功]", msg)
        else:
            pass  # print("  [失败]", off, msg)
    # 也尝试从 idx_07 前找其他可能
    print("---")

if __name__ == '__main__':
    main(sys.argv[1])
