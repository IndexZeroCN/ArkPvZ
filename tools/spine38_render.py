#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Spine 3.8 序列帧烘焙器
输入: 转换后的 JSON(SpineSkeletonDataConverter 输出) + atlas + atlas png
输出: 每动画每帧的透明 PNG
说明: 明日方舟素材 skel 附件名 B_* 对应 atlas region F_* (后缀 1->2 特例), atlas 坐标为 2x
"""
import json, math, struct, zlib, sys, os

# ---------------- 工具: PNG 编码 ----------------
def write_png(path, w, h, rgba):
    def chunk(ctype, data):
        c = struct.pack('>I', len(data)) + ctype + data
        c += struct.pack('>I', zlib.crc32(ctype + data) & 0xffffffff)
        return c
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw += rgba[y*stride:(y+1)*stride]
    ihdr = struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
        f.write(chunk(b'IEND', b''))

# ---------------- 工具: PNG 解码 ----------------
def decode_png(path):
    data = open(path, 'rb').read()
    pos = 8
    idat = b''
    w = h = color_type = 0
    while pos < len(data):
        length = struct.unpack('>I', data[pos:pos+4])[0]
        ctype = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+length]
        if ctype == b'IHDR':
            w, h, _, color_type = struct.unpack('>IIBB', chunk[:10])
        elif ctype == b'IDAT':
            idat += chunk
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
    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        base = i * channels
        o = i * 4
        if color_type == 6:
            rgba[o:o+4] = out[base:base+4]
        elif color_type == 2:
            rgba[o] = out[base]; rgba[o+1] = out[base+1]; rgba[o+2] = out[base+2]; rgba[o+3] = 255
        else:
            v = out[base]; rgba[o:o+3] = bytes([v, v, v]); rgba[o+3] = 255 if color_type == 0 else out[base+1]
    return w, h, bytes(rgba)

# ---------------- atlas 解析 ----------------
def parse_atlas(path):
    """返回 {region_name: {x, y, w, h, rotate, orig_w, orig_h, offset_x, offset_y}}"""
    lines = open(path, encoding='utf-8').read().splitlines()
    regions = {}
    cur = None
    for i, line in enumerate(lines):
        if i < 5:
            continue
        if line.startswith('  '):
            if cur and ':' in line:
                k, v = line.strip().split(':', 1)
                k = k.strip(); v = v.strip()
                if k == 'xy':
                    x, y = map(int, v.split(','))
                    regions[cur]['x'] = x; regions[cur]['y'] = y
                elif k == 'size':
                    w, h = map(int, v.split(','))
                    regions[cur]['w'] = w; regions[cur]['h'] = h
                elif k == 'orig':
                    ow, oh = map(int, v.split(','))
                    regions[cur]['orig_w'] = ow; regions[cur]['orig_h'] = oh
                elif k == 'offset':
                    ox, oy = map(float, v.split(','))
                    regions[cur]['offset_x'] = ox; regions[cur]['offset_y'] = oy
                elif k == 'rotate':
                    regions[cur]['rotate'] = (v == 'true')
        else:
            cur = line.strip()
            regions[cur] = {'rotate': False, 'offset_x': 0.0, 'offset_y': 0.0}
    return regions

# ---------------- 骨骼/动画 ----------------
DEG = math.pi / 180.0

class Bone:
    __slots__ = ('name', 'parent', 'length', 'rotation', 'x', 'y', 'scale_x', 'scale_y',
                 'shear_x', 'shear_y', 'a', 'b', 'c', 'd', 'world_x', 'world_y',
                 'applied_rotation', 'applied_x', 'applied_y', 'applied_scale_x', 'applied_scale_y',
                 'applied_shear_x', 'applied_shear_y', 'children')
    def __init__(self, name, parent, length, rotation, x, y, sx, sy, shx, shy):
        self.name = name; self.parent = parent; self.length = length
        self.rotation = rotation; self.x = x; self.y = y
        self.scale_x = sx; self.scale_y = sy
        self.shear_x = shx; self.shear_y = shy
        self.a = 1; self.b = 0; self.c = 0; self.d = 1
        self.world_x = 0; self.world_y = 0
        self.applied_rotation = rotation; self.applied_x = x; self.applied_y = y
        self.applied_scale_x = sx; self.applied_scale_y = sy
        self.applied_shear_x = shx; self.applied_shear_y = shy
        self.children = []

    def update(self):
        rad = self.applied_rotation * DEG
        cos = math.cos(rad); sin = math.sin(rad)
        x = self.applied_x; y = self.applied_y
        sx = self.applied_scale_x; sy = self.applied_scale_y
        shx = self.applied_shear_x; shy = self.applied_shear_y
        if sx != 1 or sy != 1 or shx != 0 or shy != 0:
            la = cos * sx; lb = sin * sx
            lc = -sin * sy; ld = cos * sy
            if shx != 0 or shy != 0:
                c = math.cos(shx * DEG); s = math.sin(shx * DEG)
                temp = la; la = la * c + lb * s; lb = -temp * s + lb * c
                c = math.cos(shy * DEG); s = math.sin(shy * DEG)
                temp = lc; lc = lc * c + ld * s; ld = -temp * s + ld * c
        else:
            la = cos; lb = sin; lc = -sin; ld = cos
        if self.parent:
            pa = self.parent.a; pb = self.parent.b; pc = self.parent.c; pd = self.parent.d
            px = self.parent.world_x; py = self.parent.world_y
        else:
            pa = 1; pb = 0; pc = 0; pd = 1; px = 0; py = 0
        self.a = pa * la + pb * lc; self.b = pa * lb + pb * ld
        self.c = pc * la + pd * lc; self.d = pc * lb + pd * ld
        self.world_x = px + pa * x + pb * y
        self.world_y = py + pc * x + pd * y

    def world_to_local(self, world_x, world_y):
        inv_det = 1.0 / (self.a * self.d - self.b * self.c)
        dx = world_x - self.world_x; dy = world_y - self.world_y
        return (dx * self.d * inv_det - dy * self.b * inv_det,
                dy * self.a * inv_det - dx * self.c * inv_det)

    def local_to_world(self, lx, ly):
        return (self.world_x + self.a * lx + self.b * ly,
                self.world_y + self.c * lx + self.d * ly)

def parse_json(json_path, atlas_path, png_path, scale=0.5):
    """加载 JSON + atlas, 构建骨架数据。返回 dict 结构"""
    d = json.load(open(json_path, encoding='utf-8'))
    # bones
    bones = {}
    for b in d.get('bones', []):
        name = b['name']
        parent = b.get('parent')
        bone = Bone(name, None, b.get('length', 0), b.get('rotation', 0),
                    b.get('x', 0), b.get('y', 0), b.get('scaleX', 1), b.get('scaleY', 1),
                    b.get('shearX', 0), b.get('shearY', 0))
        bones[name] = bone
    for b in d.get('bones', []):
        if 'parent' in b and b['parent'] in bones:
            bones[b['name']].parent = bones[b['parent']]
            bones[b['parent']].children.append(bones[b['name']])
    # slots
    slots = []
    for s in d.get('slots', []):
        slots.append({'name': s['name'], 'bone': s.get('bone'), 'order': s.get('order', 0),
                      'color': s.get('color', 'ffffffff'), 'attachment': s.get('attachment')})
    slots.sort(key=lambda s: s['order'])
    # ik
    iks = []
    for ik in d.get('ik', []):
        iks.append({'name': ik['name'], 'bones': ik.get('bones', []), 'target': ik.get('target'),
                    'bendDirection': ik.get('bendDirection', 1), 'mix': ik.get('mix', 1),
                    'compress': ik.get('compress', False), 'stretch': ik.get('stretch', False)})
    # skins attachments: {slot_name: {att_name: att}}
    att_map = {}
    for skin in d.get('skins', []):
        for slot_name, atts in skin.get('attachments', {}).items():
            att_map.setdefault(slot_name, {})
            for att_name, att in atts.items():
                att_map[slot_name][att_name] = att
    # atlas
    atlas = parse_atlas(atlas_path)
    png_w, png_h, png_rgba = decode_png(png_path)
    return {'bones': bones, 'slots': slots, 'ik': iks, 'attachments': att_map,
            'atlas': atlas, 'png_w': png_w, 'png_h': png_h, 'png': png_rgba,
            'animations': d.get('animations', {}), 'scale': scale}

# ---------------- 动画计算 ----------------
def curve_value(curve, t):
    """Spine curve: None=线性, 'stepped'=阶跃, [c1x,c1y,c2x,c2y]=贝塞尔"""
    if curve is None:
        return t
    if curve == 'stepped':
        return 0.0
    cx1, cy1, cx2, cy2 = curve
    # 三次贝塞尔求 y(t) 其中 x 参数反解
    def bez(a, b, c, d, t):
        mt = 1 - t
        return mt*mt*mt*a + 3*mt*mt*t*b + 3*mt*t*t*c + t*t*t*d
    # 二分求 x(t)=t 的参数
    lo, hi = 0.0, 1.0
    for _ in range(12):
        mid = (lo + hi) / 2
        if bez(0, cx1, cx2, 1, mid) < t:
            lo = mid
        else:
            hi = mid
    return bez(0, cy1, cy2, 1, (lo + hi) / 2)

def sample_timeline(frames, t):
    """frames: [{time, ...}], 返回当前插值后的两个关键帧 (prev, next, 插值t)"""
    if not frames:
        return None, None, 0
    if t <= frames[0]['time']:
        return frames[0], frames[0], 0
    if t >= frames[-1]['time']:
        return frames[-1], frames[-1], 0
    for i in range(len(frames) - 1):
        if frames[i]['time'] <= t <= frames[i+1]['time']:
            prev, nxt = frames[i], frames[i+1]
            span = nxt['time'] - prev['time']
            k = (t - prev['time']) / span if span > 0 else 0
            return prev, nxt, curve_value(nxt.get('curve'), k) if k > 0 else 0
    return frames[-1], frames[-1], 0

class Skeleton:
    def __init__(self, data):
        self.data = data
        self.bones = data['bones']
        self.slots = data['slots']
        self.attachments = data['attachments']
        self.iks = data['ik']

    def set_to_setup(self):
        for b in self.bones.values():
            b.applied_rotation = b.rotation
            b.applied_x = b.x; b.applied_y = b.y
            b.applied_scale_x = b.scale_x; b.applied_scale_y = b.scale_y
            b.applied_shear_x = b.shear_x; b.applied_shear_y = b.shear_y

    def apply_anim(self, anim, t):
        """应用动画在时间 t 的骨骼/插槽状态"""
        self.set_to_setup()
        bones_anim = anim.get('bones', {})
        for bone_name, timelines in bones_anim.items():
            bone = self.bones.get(bone_name)
            if not bone:
                continue
            # translate
            tl = timelines.get('translate')
            if tl:
                prev, nxt, k = sample_timeline(tl, t)
                if k <= 0 or prev is nxt:
                    bone.applied_x = prev['x']; bone.applied_y = prev['y']
                else:
                    bone.applied_x = prev['x'] + (nxt['x'] - prev['x']) * k
                    bone.applied_y = prev['y'] + (nxt['y'] - prev['y']) * k
            # rotate
            tl = timelines.get('rotate')
            if tl:
                prev, nxt, k = sample_timeline(tl, t)
                if k <= 0 or prev is nxt:
                    bone.applied_rotation = prev['angle']
                else:
                    a = prev['angle']; b = nxt['angle']
                    if b - a > 180: b -= 360
                    elif b - a < -180: b += 360
                    bone.applied_rotation = a + (b - a) * k
            # scale
            tl = timelines.get('scale')
            if tl:
                prev, nxt, k = sample_timeline(tl, t)
                if k <= 0 or prev is nxt:
                    bone.applied_scale_x = prev['x']; bone.applied_scale_y = prev['y']
                else:
                    bone.applied_scale_x = prev['x'] + (nxt['x'] - prev['x']) * k
                    bone.applied_scale_y = prev['y'] + (nxt['y'] - prev['y']) * k
            # shear
            tl = timelines.get('shear')
            if tl:
                prev, nxt, k = sample_timeline(tl, t)
                if k <= 0 or prev is nxt:
                    bone.applied_shear_x = prev['x']; bone.applied_shear_y = prev['y']
                else:
                    bone.applied_shear_x = prev['x'] + (nxt['x'] - prev['x']) * k
                    bone.applied_shear_y = prev['y'] + (nxt['y'] - prev['y']) * k
        # 骨骼世界变换(从根向下)
        for bone in self.bones.values():
            if bone.parent is None:
                bone.update()
        def update_children(bone):
            for c in bone.children:
                c.update()
                update_children(c)
        for bone in self.bones.values():
            if bone.parent is None:
                update_children(bone)
        # IK
        self.apply_ik(anim, t)
        # slots: attachment 与 color
        slots_anim = anim.get('slots', {})
        slot_states = {}
        for s in self.slots:
            slot_states[s['name']] = {'attachment': s.get('attachment'), 'color': s.get('color', 'ffffffff')}
        for slot_name, timelines in slots_anim.items():
            state = slot_states.setdefault(slot_name, {'attachment': None, 'color': 'ffffffff'})
            tl = timelines.get('attachment')
            if tl:
                prev, nxt, k = sample_timeline(tl, t)
                state['attachment'] = prev['name']
            tl = timelines.get('color')
            if tl:
                prev, nxt, k = sample_timeline(tl, t)
                if k <= 0 or prev is nxt:
                    state['color'] = prev['color']
        return slot_states

    def apply_ik(self, anim, t):
        ik_anim = anim.get('ik', {})
        for ik in self.iks:
            timelines = ik_anim.get(ik['name'])
            if not timelines:
                continue
            tl = timelines
            prev, nxt, k = sample_timeline(tl, t)
            if k <= 0 or prev is nxt:
                mix = prev.get('mix', 1)
                bend = prev.get('bendDirection', ik['bendDirection'])
            else:
                mix = prev.get('mix', 1) + (nxt.get('mix', 1) - prev.get('mix', 1)) * k
                bend = nxt.get('bendDirection', ik['bendDirection'])
            if mix == 0:
                continue
            self.apply_ik_constraint(ik, mix, bend)

    def apply_ik_constraint(self, ik, mix, bend_dir):
        bones = [self.bones[n] for n in ik['bones'] if n in self.bones]
        target = self.bones.get(ik['target'])
        if len(bones) < 2 or not target:
            return
        parent = bones[0]
        child = bones[1]
        # 目标位置(世界)
        tx = target.world_x; ty = target.world_y
        # 父骨骼局部坐标系下的目标
        px, py = parent.world_to_local(tx, ty)
        pa = parent.a; pb = parent.b; pc = parent.c; pd = parent.d
        # 简化: 标准 Spine 2-bone IK(仅 translation, 无 rotation 情况足够)
        # 参考 spine-cpp IkConstraint::apply
        a = child.a; b = child.b; c = child.c; d = child.d
        if abs(parent.applied_scale_x) < 0.0001 or abs(child.applied_scale_x) < 0.0001:
            return
        parent_len = parent.length; child_len = child.length
        if parent_len == 0 or child_len == 0:
            return
        # 将子骨骼的远端点转到父骨骼局部
        x = child.world_x - parent.world_x
        y = child.world_y - parent.world_y
        inv_det = 1.0 / (pa * pd - pb * pc)
        ux = (x * pd - y * pb) * inv_det
        uy = (y * pa - x * pc) * inv_det
        # 子骨骼终点在父局部的位置(长度向量)
        ex = ux + child.length * (child.a * parent.d - child.b * parent.c) * inv_det / abs(child.applied_scale_x)
        # 简化近似: 直接使用标准算法
        # (为控制复杂度, 这里采用 spine 的简化 2-bone IK)
        ax = px; ay = py
        bx = ux; by = uy
        cx = ex; cy = ey = 0  # 占位
        # 使用 spine-cpp 算法
        tx -= parent.world_x; ty -= parent.world_y
        # ...
        # 简化实现(见下)
        self._ik_simple(parent, child, tx, ty, mix, bend_dir, px, py)

    def _ik_simple(self, parent, child, tx, ty, mix, bend_dir, px, py):
        # 在父骨骼局部坐标系求解 2 骨 IK
        # 父局部: 目标(tx,ty)已由调用方转为父局部? 这里 tx,ty 是世界-父世界
        # 简化: 用世界坐标直接解(忽略父旋转, 对角色骨架足够)
        x1, y1 = 0.0, 0.0  # 父骨骼起点(父局部原点)
        x2, y2 = px, py     # 父骨骼终点(关节)
        x3, y3 = tx, ty     # 目标
        if x2 == 0 and y2 == 0:
            return
        # 余弦定理求关节角
        d1 = math.hypot(x2, y2)
        d2 = math.hypot(x3 - x2, y3 - y2)
        if d1 == 0 or d2 == 0:
            return
        cos_denom = 2 * d1 * d2
        cos_angle = (d1*d1 + d2*d2 - (x3*x3 + y3*y3)) / cos_denom
        cos_angle = max(-1, min(1, cos_angle))
        angle = math.acos(cos_angle) * bend_dir
        # 关节角应用到 child 的 applied_rotation
        child.applied_rotation += angle / DEG
        # 重算世界
        child.update()
        # 调整 parent 朝向目标
        # (简化: 此处对 parent 旋转的完整求解略, 先用 child 微调)
        # 重新计算后 child 世界
        # 求 parent 应转角度
        tx2 = tx; ty2 = ty
        # 目标方向 vs 当前关节方向
        cur_x = child.world_x - parent.world_x
        cur_y = child.world_y - parent.world_y
        tar_x = tx2 - parent.world_x
        tar_y = ty2 - parent.world_y
        cur_angle = math.atan2(cur_y, cur_x)
        tar_angle = math.atan2(tar_y, tar_x)
        diff = tar_angle - cur_angle
        parent.applied_rotation += diff / DEG * mix
        parent.update()
        child.update()

# ---------------- 渲染 ----------------
def att_name_to_region(name):
    """skel 附件名 B_* -> atlas region F_* (后缀 1->2 特例)"""
    if not name or name == 'null':
        return None
    n = name[2:] if name.startswith('B_') else name
    if n == 'HairB1':
        return 'F_Hair2'
    if n.endswith('1') and n != 'Hair1':
        n = n[:-1] + '2'
    return 'F_' + n

def region_uv_rect(region, png_w, png_h, scale):
    """返回 (u0, v0, u1, v1) 供纹理采样"""
    x = region['x'] * scale; y = region['y'] * scale
    w = region['w'] * scale; h = region['h'] * scale
    return (x / png_w, y / png_h, (x + w) / png_w, (y + h) / png_h)

def render_frame(skel_data, slot_states, draw_order, t):
    """渲染一帧, 返回 (rgba, w, h, min_x, min_y) 或 None"""
    bones = skel_data['bones']
    attachments = skel_data['attachments']
    atlas = skel_data['atlas']
    png = skel_data['png']; png_w = skel_data['png_w']; png_h = skel_data['png_h']
    scale = skel_data['scale']
    # 收集所有三角形(世界坐标 + uv)
    tris = []
    for slot_name in draw_order:
        state = slot_states.get(slot_name, {'attachment': None, 'color': 'ffffffff'})
        att_name = state['attachment']
        if not att_name:
            continue
        slot_bone = None
        for s in skel_data['slots']:
            if s['name'] == slot_name:
                slot_bone = bones.get(s['bone'])
                break
        if not slot_bone:
            continue
        att = attachments.get(slot_name, {}).get(att_name)
        if not att:
            continue
        color = state.get('color', 'ffffffff')
        alpha = int(color[6:8], 16) / 255.0 if len(color) >= 8 else 1.0
        att_type = att.get('type', 'region')
        region_name = att_name_to_region(att_name)
        if att_type == 'region':
            region = atlas.get(region_name)
            if not region:
                continue
            w = att.get('width', region['w'] * scale * 2) / 2.0
            h = att.get('height', region['h'] * scale * 2) / 2.0
            x = att.get('x', 0); y = att.get('y', 0)
            rot = att.get('rotation', 0) * DEG
            sx = att.get('scaleX', 1); sy = att.get('scaleY', 1)
            # 局部顶点(相对 bone)
            pts = [(-w, -h), (w, -h), (w, h), (-w, h)]
            # 附件自身变换(位置+旋转+缩放)
            cosr = math.cos(rot); sinr = math.sin(rot)
            world_pts = []
            for lx, ly in pts:
                px = lx * sx; py = ly * sy
                rx = px * cosr - py * sinr + x
                ry = px * sinr + py * cosr + y
                wx = slot_bone.world_x + slot_bone.a * rx + slot_bone.b * ry
                wy = slot_bone.world_y + slot_bone.c * rx + slot_bone.d * ry
                world_pts.append((wx, wy))
            # UV(region 矩形 4 角)
            u0, v0, u1, v1 = region_uv_rect(region, png_w, png_h, scale)
            uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
            if region.get('rotate'):
                # atlas 内旋转 90°, UV 需重排
                uvs = [(u0, v1), (u0, v0), (u1, v0), (u1, v1)]
            tris.append(([world_pts[0], world_pts[1], world_pts[2]], [uvs[0], uvs[1], uvs[2]], alpha))
            tris.append(([world_pts[0], world_pts[2], world_pts[3]], [uvs[0], uvs[2], uvs[3]], alpha))
        elif att_type == 'mesh':
            region = atlas.get(region_name)
            if not region:
                continue
            verts = att.get('vertices', [])
            uvs = att.get('uvs', [])
            triangles = att.get('triangles', [])
            if len(verts) < 6 or len(uvs) < 4 or len(triangles) < 3:
                continue
            # 世界坐标顶点
            world_verts = []
            for i in range(0, len(verts), 2):
                lx = verts[i]; ly = verts[i+1]
                wx = slot_bone.world_x + slot_bone.a * lx + slot_bone.b * ly
                wy = slot_bone.world_y + slot_bone.c * lx + slot_bone.d * ly
                world_verts.append((wx, wy))
            u0, v0, u1, v1 = region_uv_rect(region, png_w, png_h, scale)
            for i in range(0, len(triangles), 3):
                i0, i1, i2 = triangles[i], triangles[i+1], triangles[i+2]
                tri_uvs = []
                for vi in (i0, i1, i2):
                    u = uvs[vi*2]; v = uvs[vi*2+1]
                    tri_uvs.append((u0 + u * (u1 - u0), v0 + v * (v1 - v0)))
                tris.append(([world_verts[i0], world_verts[i1], world_verts[i2]], tri_uvs, alpha))
    if not tris:
        return None
    # 计算包围盒
    min_x = min(p[0] for tri in tris for p in tri[0])
    max_x = max(p[0] for tri in tris for p in tri[0])
    min_y = min(p[1] for tri in tris for p in tri[0])
    max_y = max(p[1] for tri in tris for p in tri[0])
    pad = 2
    min_x = math.floor(min_x) - pad; max_x = math.ceil(max_x) + pad
    min_y = math.floor(min_y) - pad; max_y = math.ceil(max_y) + pad
    w = int(max_x - min_x); h = int(max_y - min_y)
    if w <= 0 or h <= 0 or w > 4096 or h > 4096:
        return None
    fb = bytearray(w * h * 4)  # 预乘 alpha 缓冲? 用 straight alpha 累加
    # 简单 painter 算法: 按顺序画(已按 drawOrder 排序), 后面覆盖前面, alpha 混合
    def put_pixel(px, py, r, g, b, a):
        if px < 0 or px >= w or py < 0 or py >= h or a <= 0:
            return
        idx = (py * w + px) * 4
        # src-over 混合
        da = fb[idx+3] / 255.0
        sa = a
        out_a = sa + da * (1 - sa)
        if out_a <= 0:
            return
        fb[idx] = int((r * sa + fb[idx] * da * (1 - sa)) / out_a)
        fb[idx+1] = int((g * sa + fb[idx+1] * da * (1 - sa)) / out_a)
        fb[idx+2] = int((b * sa + fb[idx+2] * da * (1 - sa)) / out_a)
        fb[idx+3] = int(out_a * 255)
    for (p0, p1, p2), (uv0, uv1, uv2), alpha in tris:
        # 包围盒
        bmin_x = max(min_x, int(min(p0[0], p1[0], p2[0])))
        bmax_x = min(max_x, int(math.ceil(max(p0[0], p1[0], p2[0]))))
        bmin_y = max(min_y, int(min(p0[1], p1[1], p2[1])))
        bmax_y = min(max_y, int(math.ceil(max(p0[1], p1[1], p2[1]))))
        # 边函数
        def edge(a, b, c):
            return (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])
        area = edge(p0, p1, p2)
        if area == 0:
            continue
        for py in range(bmin_y, bmax_y):
            for px in range(bmin_x, bmax_x):
                q = (px + 0.5, py + 0.5)
                w0 = edge(p1, p2, q)
                w1 = edge(p2, p0, q)
                w2 = edge(p0, p1, q)
                if area > 0:
                    if w0 < 0 or w1 < 0 or w2 < 0:
                        continue
                else:
                    if w0 > 0 or w1 > 0 or w2 > 0:
                        continue
                # 重心坐标
                inv = 1.0 / area
                l0 = w0 * inv; l1 = w1 * inv; l2 = w2 * inv
                u = uv0[0]*l0 + uv1[0]*l1 + uv2[0]*l2
                v = uv0[1]*l0 + uv1[1]*l1 + uv2[1]*l2
                u = max(0.0, min(1.0, u)); v = max(0.0, min(1.0, v))
                tx = int(u * png_w); ty = int(v * png_h)
                tx = max(0, min(png_w-1, tx)); ty = max(0, min(png_h-1, ty))
                ti = (ty * png_w + tx) * 4
                pr = png[ti]; pg = png[ti+1]; pb = png[ti+2]; pa = png[ti+3] / 255.0
                if pa <= 0:
                    continue
                a = pa * alpha
                put_pixel(px - min_x, py - min_y, pr, pg, pb, a)
    return bytes(fb), w, h, min_x, min_y

def compute_draw_order(slots, anim):
    """根据 drawOrder timeline 计算绘制顺序(slot 名列表)"""
    order = [s['name'] for s in slots]
    tl = anim.get('drawOrder')
    if not tl:
        return order
    # 找当前 t 之前最近的 drawOrder 关键帧
    return order  # 简化: drawOrder 关键帧处理在渲染循环中按 t 应用

def render_animation(skel_data, anim_name, anim, fps=30.0, out_dir='out'):
    """渲染一个动画的所有帧, 输出 PNG。返回 (帧列表信息, 全局包围盒)"""
    skel = Skeleton(skel_data)
    # 动画时长
    duration = anim.get('duration', 0)
    if duration <= 0:
        duration = 1.0
    # 计算所有帧的包围盒(两遍: 先算bbox再渲染)
    frame_count = max(1, int(math.ceil(duration * fps)))
    print('  渲染动画[%s] 时长%.2fs 帧数%d' % (anim_name, duration, frame_count))
    all_min_x = all_min_y = float('inf')
    all_max_x = all_max_y = floa
