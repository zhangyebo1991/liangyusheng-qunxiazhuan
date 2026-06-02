"""程序生成 jiangnan_town 底图 — 2560x1920，草地 + 土路 + 水域格局。

用法: python scripts/generate_town_bg.py

因为 Godot CLI 不可用，此脚本用 Pillow 复刻 map_background_generator.gd 的算法。
"""

import math
import os
from PIL import Image

WIDTH = 2560
HEIGHT = 1920
OUTPUT_DIR = "assets/maps/jiangnan_town"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "background.png")


def generate():
    img = Image.new("RGBA", (WIDTH, HEIGHT))
    pixels = img.load()

    # ── 基础草地（带噪声变化） ──
    for y in range(HEIGHT):
        for x in range(WIDTH):
            noise = (math.sin(x * 0.03) * math.cos(y * 0.03) + 1.0) / 2.0
            green = int(130 + noise * 40)
            red = int(80 + noise * 30)
            pixels[x, y] = (red, green, 55, 255)

    # ── 水平主路 ──
    road_y_center = int(HEIGHT * 0.42)
    for y in range(road_y_center - 24, road_y_center + 24):
        for x in range(WIDTH):
            pixels[x, y] = (209, 191, 153, 255)  # Color(0.82, 0.75, 0.60)

    # ── 垂直路（右侧） ──
    road_x_center = int(WIDTH * 0.75)
    for x in range(road_x_center - 20, road_x_center + 20):
        for y in range(0, road_y_center):
            pixels[x, y] = (209, 191, 153, 255)  # Color(0.82, 0.75, 0.60)

    # ── 水域（左下） ──
    water_start_y = int(HEIGHT * 0.65)
    water_end_x = int(WIDTH * 0.35)
    for y in range(water_start_y, HEIGHT):
        for x in range(0, water_end_x):
            pixels[x, y] = (64, 115, 179, 255)  # Color(0.25, 0.45, 0.70)

    # ── 水域波纹（lightened 近似） ──
    for y in range(water_start_y, HEIGHT):
        for x in range(0, water_end_x):
            ripple = math.sin(x * 0.2 + y * 0.1) * 0.05
            r, g, b, a = pixels[x, y]
            # lightened: lerp toward white
            factor = ripple
            r = int(r + (255 - r) * factor * 0.5)
            g = int(g + (255 - g) * factor * 0.5)
            b = int(b + (255 - b) * factor * 0.5)
            pixels[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), a)

    # ── 保存 ──
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    img.save(OUTPUT_FILE)
    print(f"底图已生成: {OUTPUT_FILE}  ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    generate()
