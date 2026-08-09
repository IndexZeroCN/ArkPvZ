#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Spine 3.8 二进制 .skel 结构解析器(仅统计, 用于评估烘焙范围)"""
import struct, sys

class Reader:
    def __init__(self, data):
        self.d = data
        self.p = 0
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
    def read_svarint(self):
        b = self.read_byte()
        v = b & 0x3f
        neg = b & 0x40
        if b & 0x80:
            b = self.read_byte()
            v |= (b & 0x7f) << 6
            if b & 0x80:
                b = self.read_byte()
                v |= (b & 0x7f) << 13
                if b & 0x80:
                    b = self.read_byte()
                    v |= (b & 0x7f) << 20
                    if b & 0x80:
                        v |= (self.read_byte() & 0x7f) << 27
        return -v if neg else v
    def read_float(self):
        v = struct.unpack_from('<f', self.d, self.p)[0]; self.p += 4
        return v
    def read_short(self):
        v = struct.unpack_from('<h', self.d, self.p)[0]; self.p += 2
        return v
    def read_string(self):
        n = self.read_varint()
        if n == 0:
            return ""
        s = self.d[self.p:self.p+n].decode('utf-8', errors='replace')
        self.p += n
        return s
    def read_utf8_short(self):
        end = self.d.index(b'\x00', self.p)
        s = self.d[self.p:end].decode('utf-8', errors='replace')
        self.p = end + 1
        return s

def parse(path):
    r = Reader(open(path, 'rb').read())
    assert r.read_byte() == 0x0A  # \n
    name = r.read_utf8_short()
    version = r.read_utf8_short()
    hash_ = r.read_utf8_short()
    width = r.read_float(); height = r.read_float()
    print("骨骼名:", name, " 版本:", version, " 尺寸:", width, "x", height)
    r.read_varint()  # images
    skin_count = r.read_varint()
    if skin_count == 0:
        r.read_byte()
    skins = []
    for _ in range(skin_count):
        sname = r.read_string()
        slot_count = r.read_varint()
        for _ in range(slot_count):
            slot_idx = r.read_varint()
            attach_count = r.read_varint()
            for _ in range(attach_count):
                aname = r.read_string()
                atype = r.read_byte()
                if atype == 0:
                    r.read_string(); r.read_string()
                    for _ in range(7): r.read_float()
                    if r.read_bool(): r.read_string()
                elif atype == 1:
                    vn = r.read_varint()
                    for _ in range(vn*2): r.read_float()
                    if r.read_bool(): r.read_string()
                elif atype == 2:
                    r.read_string()
                    vn = r.read_varint()
                    for _ in range(vn*2): r.read_float()
                    uv = r.read_varint()
                    for _ in range(uv*2): r.read_float()
                    tn = r.read_varint()
                    for _ in range(tn*3): r.read_short()
                    r.read_varint()  # hull
                    edges = r.read_varint()
                    for _ in range(edges): r.read_varint()
                    if r.read_bool(): r.read_string()
                elif atype == 3:
                    r.read_string()
                    vn = r.read_varint()
                    for _ in range(vn*2): r.read_float()
                    uv = r.read_varint()
                    for _ in range(uv*2): r.read_float()
                    tn = r.read_varint()
                    for _ in range(tn*3): r.read_short()
                    r.read_varint()
                    edges = r.read_varint()
                    for _ in range(edges): r.read_varint()
                    r.read_string()
                    if r.read_bool(): r.read_string()
                elif atype == 4:
                    r.read_string(); r.read_string()
                    r.read_varint()
                    vn = r.read_varint()
                    for _ in range(vn*2): r.read_float()
                    if r.read_bool(): r.read_string()
                elif atype == 5:
                    r.read_string()
                    r.read_float(); r.read_float(); r.read_float()
                    if r.read_bool(): r.read_string()
                elif atype == 6:
                    r.read_string()
                    r.read_float(); r.read_float()
                    if r.read_bool(): r.read_string()
                skins.append((sname, slot_idx, aname, atype))
    print("skin 附件:", len(skins), " 类型分布:", {t: sum(1 for s in skins if s[3]==t) for t in range(7)})
    bone_count = r.read_varint()
    bones = []
    for _ in range(bone_count):
        bname = r.read_string()
        parent = r.read_varint() - 1
        length = r.read_float()
        rot = r.read_float(); x = r.read_float(); y = r.read_float()
        sx = r.read_float(); sy = r.read_float()
        shearx = r.read_float(); sheary = r.read_float()
        r.read_byte()
        if r.read_bool(): r.read_string()
        bones.append((bname, parent, length))
    print("骨骼:", bone_count, "个")
    for b in bones:
        print("  -", b)
    slot_count = r.read_varint()
    slots = []
    for _ in range(slot_count):
        sname = r.read_string()
        bone_idx = r.read_varint()
        r.read_varint()
        if r.read_bool(): r.read_string()
        if r.read_bool(): r.read_string()
        slots.append((sname, bone_idx))
    print("插槽:", slot_count, "个:", [s[0] for s in slots])
    ik_count = r.read_varint()
    for _ in range(ik_count):
        r.read_string(); r.read_varint(); r.read_varint()
        r.read_float(); r.read_float(); r.read_float()
    print("IK 约束:", ik_count)
    tr_count = r.read_varint()
    for _ in range(tr_count):
        r.read_string(); r.read_varint(); r.read_varint()
        for _ in range(6): r.read_float()
        for _ in range(4): r.read_float()
        r.read_byte()
    print("Transform 约束:", tr_count)
    path_count = r.read_varint()
    for _ in range(path_count):
        r.read_string(); r.read_varint(); r.read_varint()
        for _ in range(5): r.read_float()
        for _ in range(4): r.read_float()
        r.read_byte()
        for _ in range(3): r.read_float()
        r.read_byte()
    print("Path 约束:", path_count)
    def_slot_count = r.read_varint()
    for _ in range(def_slot_count):
        r.read_varint()
    event_count = r.read_varint()
    for _ in range(event_count):
        r.read_string()
        r.read_float(); r.read_float(); r.read_float()
        if r.read_bool(): r.read_string()
        if r.read_bool(): r.read_string()
        if r.read_bool(): r.read_string()
    print("事件:", event_count)
    anim_count = r.read_varint()
    print("动画:", anim_count)
    for a in range(anim_count):
        aname = r.read_string()
        timeline_types = {}
        while True:
            t = r.read_byte()
            if t == 0:
                r.read_varint()
                break
            count = r.read_varint()
            timeline_types.setdefault(t, 0)
            timeline_types[t] += count
            break
        print("  动画[", aname, "] timeline类型:", timeline_types)
    print("解析完成(仅结构统计, 动画timeline未完整解析)")

if __name__ == '__main__':
    parse(sys.argv[1])
