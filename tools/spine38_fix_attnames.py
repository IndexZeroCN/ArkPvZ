#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把转换后的 Spine JSON 中的附件名 B_* 映射为 atlas region 名 F_* (含后缀特例)
用法: python spine38_fix_attnames.py <in.json> <out.json>
"""
import json, sys, re

# B_* -> F_* 映射规则(基于实际素材验证)
def map_name(name):
    if not name or name == 'null':
        return name
    n = name[2:] if name.startswith('B_') else name
    if n == 'HairB1':
        return 'F_Hair2'
    if n.endswith('1') and n != 'Hair1':
        n = n[:-1] + '2'
    return 'F_' + n

def fix(obj):
    """递归替换 JSON 中所有附件名"""
    if isinstance(obj, dict):
        new = {}
        for k, v in obj.items():
            new[k] = fix(v)
        # skins.attachments: {slot: {att_name: att}}
        # 这里处理 attachments 字典的 key
        return new
    elif isinstance(obj, list):
        return [fix(i) for i in obj]
    return obj

def main():
    src, dst = sys.argv[1], sys.argv[2]
    d = json.load(open(src, encoding='utf-8'))
    # 1. skins attachments: key 是附件名
    for skin in d.get('skins', []):
        atts = skin.get('attachments', {})
        for slot_name in list(atts.keys()):
            slot_atts = atts[slot_name]
            new_slot_atts = {}
            for att_name, att in slot_atts.items():
                new_name = map_name(att_name)
                new_slot_atts[new_name] = att
                # region/mesh 附件的 path 字段(若有)也映射
                if isinstance(att, dict) and att.get('path'):
                    att['path'] = map_name(att['path'])
            atts[slot_name] = new_slot_atts
    # 2. slots 默认 attachment
    for s in d.get('slots', []):
        if s.get('attachment'):
            s['attachment'] = map_name(s['attachment'])
    # 3. animations 里 attachment timeline 的 name + deform 的 key
    anims = d.get('animations', {})
    if isinstance(anims, dict):
        for anim in anims.values():
            slots_anim = anim.get('slots', {})
            for slot_name, timelines in slots_anim.items():
                tl = timelines.get('attachment')
                if tl:
                    for frame in tl:
                        if frame.get('name'):
                            frame['name'] = map_name(frame['name'])
            deform = anim.get('deform', {})
            if deform:
                new_deform = {}
                for slot_name, atts in deform.items():
                    new_atts = {}
                    for att_name, frames in atts.items():
                        new_atts[map_name(att_name)] = frames
                    new_deform[slot_name] = new_atts
                anim['deform'] = new_deform
    json.dump(d, open(dst, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('已映射附件名并写出:', dst)

if __name__ == '__main__':
    main()
