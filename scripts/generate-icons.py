#!/usr/bin/env python3
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "DiegoMusic/Resources/Assets.xcassets/AppIcon.appiconset"
OUTPUT.mkdir(parents=True, exist_ok=True)

INK = (23, 21, 18, 255)
CREAM = (242, 226, 199, 255)
RED = (225, 56, 43, 255)
YELLOW = (245, 186, 31, 255)
BLUE = (20, 89, 179, 255)


def inside_circle(x, y, cx, cy, radius):
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


def pixel(size, x, y):
    u, v = x / size, y / size
    color = CREAM
    if 0.08 < u < 0.92 and 0.08 < v < 0.92:
        color = INK
    if inside_circle(u, v, 0.34, 0.38, 0.22):
        color = RED
    if 0.52 < u < 0.84 and 0.18 < v < 0.50:
        color = BLUE
    if inside_circle(u, v, 0.63, 0.66, 0.20) and not inside_circle(u, v, 0.63, 0.66, 0.105):
        color = YELLOW
    if inside_circle(u, v, 0.63, 0.66, 0.035):
        color = CREAM
    return color


def write_png(path, size):
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            row.extend(pixel(size, x, y))
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


for dimension in (16, 32, 64, 128, 256, 512, 1024):
    write_png(OUTPUT / f"AppIcon-{dimension}.png", dimension)
