#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""根据音效文件名推测用途备注, 写入 data/sfx_notes.json
规则: 前缀(类型) + 主词(音效对象) + 后缀(动作), 组合成中文备注
空备注(不在现有备注表里的)才填推测值
"""
import os, json, re, sys

SFX_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio', 'SFX', 'operator_pick')
OUT_PATH = os.path.join(os.path.dirname(__file__), '..', 'data', 'sfx_notes.json')
USER_NOTES = os.path.expandvars(r'%APPDATA%\Godot\app_userdata\ArkPvZ\sfx_notes.json')

## 前缀 -> 类型
PREFIX = [
    ('p_atk_', '攻击'), ('p_imp_', '受击/命中'), ('p_skill_', '技能'),
    ('p_aoe_', '范围攻击'), ('b_char_', '角色状态'), ('v_bat_', '战斗人声'),
    ('v_building_', '基建人声'), ('v_', '人声'), ('g_', '通用'),
]

## 主词 -> 中文
MAIN_WORDS = [
    ('arrow', '箭矢'), ('birdarrow', '鸟矢'), ('bigbow', '大弓'), ('penarrow', '笔矢'),
    ('lunaarrow', '月矢'), ('crossbow', '弩'), ('krossbow', '弩'), ('militaryxbow', '军用弩'),
    ('revxbow', '猎弩'), ('pencrossbow', '笔弩'), ('bow', '弓'), ('harpbow', '竖琴弓'),
    ('MHPurebow', '纯弓'), ('mechaxbow', '机械弓'),
    ('blackcannon', '黑炮'), ('cannon', '炮'), ('chngun', '铳枪'), ('nailgun', '钉枪'),
    ('shotgun', '霰弹枪'), ('energygun', '能量枪'), ('silncrgun', '消音枪'),
    ('sndshotgun', '消音霰弹'), ('gun', '枪'),
    ('grenade', '手雷'), ('bomb', '炸弹'), ('explo', '爆炸'), ('blast', '爆裂'),
    ('rocket', '火箭'), ('missile', '导弹'), ('shell', '炮弹'), ('boom', '爆响'),
    ('burst', '爆发'), ('throw', '投掷'), ('axethrow', '斧投掷'),
    ('flamethrower', '火焰喷射'), ('fire', '火焰'), ('mag', '法术'), ('ice', '冰'),
    ('elec', '雷电'), ('wind', '风'), ('shield', '护盾'), ('heal', '治疗'),
    ('buff', '增益'), ('boost', '增益'), ('atk', '攻击'), ('snipe', '狙击'),
    ('shoot', '射击'), ('cast', '施放'), ('aerolite', '陨石'),
    ('blizzard', '暴风雪'), ('dead', '死亡'), ('smoke', '烟雾'), ('spark', '电火花'),
    ('sound', '音效'), ('se', '音效'),
]

## 后缀 -> 动作
SUFFIX = [
    ('_overload', '过载'), ('_charge', '充能'), ('_powercoating', '涂装'),
    ('_shining', '闪光'), ('_loop', '循环'), ('_cast', '施放'), ('_pre', '预备'),
    ('_end', '结束'), ('_phase2', '阶段2'), ('_n', '发射/普通'), ('_h', '命中'),
    ('_s', '技能/射击'), ('_d', '死亡/销毁'), ('_1', '其一'), ('_2', '其二'),
]

def guess_note(name: str) -> str:
    """name = 去扩展名的文件名"""
    prefix_cn = ''
    for pre, cn in PREFIX:
        if name.startswith(pre):
            prefix_cn = cn
            break
    main_cn = ''
    for word, cn in MAIN_WORDS:
        if word in name:
            main_cn = cn
            break
    suffix_cn = ''
    for suf, cn in SUFFIX:
        if name.endswith(suf):
            suffix_cn = cn
            break
    note = ''.join([p for p in [prefix_cn, main_cn, suffix_cn] if p])
    return note if note else name

def load_json(path):
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}

def main():
    files = sorted(f for f in os.listdir(SFX_DIR) if f.endswith('.wav') or f.endswith('.ogg'))
    ## 现有备注: 项目 data + 用户 user 合并(用户优先)
    notes = load_json(OUT_PATH)
    user_notes = load_json(USER_NOTES)
    notes.update(user_notes)
    filled = 0
    for f in files:
        if f in notes and notes[f].strip():
            continue
        notes[f] = guess_note(f[:-4])
        filled += 1
    with open(OUT_PATH, 'w', encoding='utf-8') as out:
        json.dump(notes, out, ensure_ascii=False, indent='\t')
    print('共 %d 个音效, 推测填充 %d 个空备注' % (len(files), filled))
    print('写入: %s' % os.path.abspath(OUT_PATH))

if __name__ == '__main__':
    main()
