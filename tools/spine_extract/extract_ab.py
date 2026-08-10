#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extract Spine assets from Arknights AssetBundle (custom LZ4 "LZHAM")."""
import io
import os
import sys

import UnityPy
from UnityPy.enums import CompressionFlags
from UnityPy.helpers import CompressionHelper


def ak_fix_lz4(compressed_data, uncompressed_size):
    """Arknights custom scheme: token nibbles swapped + offset bytes swapped, then plain LZ4.

    Reverse-engineered by Kengxxiao:
    https://github.com/MooncellWiki/UnityPy/commit/781badde6d636f101279fef76f461bb8dd0e1ffc
    """
    data = bytearray(compressed_data)
    ip = 0
    op = 0
    while True:
        token = data[ip]
        literal_length = token & 0x0F
        match_length = (token >> 4) & 0x0F
        data[ip] = ((literal_length << 4) | match_length) & 0xFF
        ip += 1
        if literal_length == 15:
            while True:
                b = data[ip]
                ip += 1
                literal_length += b
                if b != 255:
                    break
        op += literal_length
        ip += literal_length
        if uncompressed_size - op < 12:  # MFLIMIT end of block
            break
        # swap offset bytes
        data[ip], data[ip + 1] = data[ip + 1], data[ip]
        ip += 2
        if match_length == 15:
            while True:
                b = data[ip]
                ip += 1
                match_length += b
                if b != 255:
                    break
        match_length += 4  # MINMATCH
        op += match_length
    return CompressionHelper.decompress_lz4(bytes(data), uncompressed_size)


# Patch UnityPy: treat LZHAM flag as the Arknights custom compression
CompressionHelper.DECOMPRESSION_MAP[CompressionFlags.LZHAM] = ak_fix_lz4


def main():
    ab_path = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    env = UnityPy.load(ab_path)
    print(f"objects: {len(env.objects)}")
    for obj in env.objects:
        t = obj.type.name
        if t not in ("TextAsset", "Texture2D", "Sprite", "Mesh"):
            continue
        try:
            d = obj.read()
            name = getattr(d, "m_Name", "") or getattr(d, "name", "")
        except Exception as e:
            print(f"  !! {obj.path_id} {t}: read failed: {e}")
            continue
        print(f"  [{obj.path_id}] {t:<10} {name}")

        if t == "TextAsset":
            raw = d.m_Script.encode("utf-8", errors="surrogateescape")  # recover raw bytes
            safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in name) or f"text_{obj.path_id}"
            try:
                raw.decode("utf-8")
                is_text = True
            except UnicodeDecodeError:
                is_text = False
            ext = ".txt" if is_text else ".skel"
            path = os.path.join(out_dir, safe + ext)
            with open(path, "wb") as f:
                f.write(raw)
            print(f"      -> {path} ({len(raw)} bytes, text={is_text})")
        elif t == "Texture2D":
            try:
                img = d.image
            except Exception as e:
                print(f"      !! image decode failed: {e}")
                continue
            safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in name) or f"tex_{obj.path_id}"
            path = os.path.join(out_dir, safe + ".png")
            if isinstance(img, bytes):
                with open(path, "wb") as f:
                    f.write(img)
            else:
                img.save(path)
            print(f"      -> {path} ({d.m_Width}x{d.m_Height})")
        elif t == "Sprite":
            safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in name) or f"spr_{obj.path_id}"
            path = os.path.join(out_dir, safe + ".png")
            d.image.save(path)
            print(f"      -> {path}")
        elif t == "Mesh":
            safe = "".join(c if c.isalnum() or c in "._-" else "_" for c in name) or f"mesh_{obj.path_id}"
            print(f"      (mesh skipped: {safe})")


if __name__ == "__main__":
    main()
