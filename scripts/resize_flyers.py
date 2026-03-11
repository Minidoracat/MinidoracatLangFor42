# /// script
# requires-python = ">=3.10"
# dependencies = ["Pillow>=10.0"]
# ///
"""
批量縮小 FlyerPics 傳單圖片 — 以原版遊戲尺寸為基準，可額外縮放。

用法：
    uv run scripts/resize_flyers.py --dry-run            # 預覽（不修改）
    uv run scripts/resize_flyers.py                       # 執行縮小（預設 90% 原版尺寸）
    uv run scripts/resize_flyers.py --scale 1.0           # 對齊原版尺寸
    uv run scripts/resize_flyers.py --scale 0.8           # 原版的 80%
"""
import argparse
import os
import sys
from pathlib import Path

from PIL import Image

# 路徑設定
MOD_FLYERS = Path(
    "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42"
    "/42/media/textures/printMedia/FlyerPics"
)
VANILLA_FLYERS = Path(
    "D:/SteamLibrary/steamapps/common/ProjectZomboid"
    "/media/textures/printMedia/FlyerPics"
)

# 沒有原版對照時的預設縮小比例
DEFAULT_SCALE = 0.72


def get_vanilla_sizes() -> dict[str, tuple[int, int]]:
    """讀取原版遊戲所有傳單圖片尺寸。"""
    sizes: dict[str, tuple[int, int]] = {}
    if not VANILLA_FLYERS.exists():
        print(f"⚠ 原版目錄不存在：{VANILLA_FLYERS}")
        return sizes
    for f in VANILLA_FLYERS.iterdir():
        if f.suffix.lower() == ".png":
            with Image.open(f) as img:
                sizes[f.name] = img.size
    return sizes


def resize_image(path: Path, target_size: tuple[int, int], dry_run: bool) -> tuple[int, int]:
    """縮小單張圖片，回傳 (原始大小bytes, 新大小bytes)。"""
    original_bytes = path.stat().st_size

    if dry_run:
        # 估算：按面積比例粗估
        with Image.open(path) as img:
            orig_pixels = img.width * img.height
        new_pixels = target_size[0] * target_size[1]
        ratio = new_pixels / orig_pixels
        estimated = int(original_bytes * ratio * 0.9)  # PNG 壓縮效率略好
        return original_bytes, estimated

    with Image.open(path) as img:
        if img.size == target_size:
            return original_bytes, original_bytes  # 無需縮小

        resized = img.resize(target_size, Image.LANCZOS)
        # PNG 最大壓縮，optimize=True
        resized.save(path, "PNG", optimize=True, compress_level=9)

    new_bytes = path.stat().st_size
    return original_bytes, new_bytes


def main() -> None:
    parser = argparse.ArgumentParser(description="批量縮小 FlyerPics 傳單圖片")
    parser.add_argument("--dry-run", action="store_true", help="預覽模式（不修改檔案）")
    parser.add_argument("--scale", type=float, default=0.9,
                        help="相對於原版尺寸的縮放比例（預設 0.9 = 90%%）")
    args = parser.parse_args()

    # 定位 MOD 目錄（從專案根目錄執行）
    project_root = Path(__file__).resolve().parent.parent
    mod_dir = project_root / MOD_FLYERS
    if not mod_dir.exists():
        print(f"✗ MOD 目錄不存在：{mod_dir}")
        sys.exit(1)

    # 讀取原版尺寸
    vanilla_sizes = get_vanilla_sizes()
    print(f"原版參考圖片：{len(vanilla_sizes)} 張")

    # 收集 MOD 圖片
    mod_files = sorted(f for f in mod_dir.iterdir() if f.suffix.lower() == ".png")
    print(f"MOD 圖片：{len(mod_files)} 張")

    if args.dry_run:
        print("\n🔍 預覽模式（不修改檔案）\n")
    else:
        print("\n🔧 執行縮小...\n")

    total_original = 0
    total_new = 0
    skipped = 0
    resized_count = 0
    no_vanilla = 0

    for f in mod_files:
        with Image.open(f) as img:
            current_size = img.size

        if f.name in vanilla_sizes:
            van_size = vanilla_sizes[f.name]
            target_size = (round(van_size[0] * args.scale), round(van_size[1] * args.scale))
            source = f"原版×{args.scale}"
            source = "原版"
        else:
            # 無原版對照，按比例縮小
            fallback = DEFAULT_SCALE * args.scale
            target_w = round(current_size[0] * fallback)
            target_h = round(current_size[1] * fallback)
            target_size = (target_w, target_h)
            source = f"縮小{int(fallback*100)}%"
            no_vanilla += 1

        if current_size == target_size:
            orig_bytes = f.stat().st_size
            total_original += orig_bytes
            total_new += orig_bytes
            skipped += 1
            continue

        orig_bytes, new_bytes = resize_image(f, target_size, args.dry_run)
        total_original += orig_bytes
        total_new += new_bytes
        resized_count += 1

        reduction = (1 - new_bytes / orig_bytes) * 100 if orig_bytes > 0 else 0
        tag = "預估" if args.dry_run else "完成"
        print(
            f"  [{tag}] {f.name}: {current_size[0]}×{current_size[1]} → "
            f"{target_size[0]}×{target_size[1]} ({source}) | "
            f"{orig_bytes//1024}KB → {new_bytes//1024}KB (-{reduction:.0f}%)"
        )

    print(f"\n{'═' * 60}")
    print(f"  處理：{resized_count} 張 | 跳過：{skipped} 張 | 無原版對照：{no_vanilla} 張")
    print(
        f"  總大小：{total_original//1024//1024}MB → {total_new//1024//1024}MB "
        f"(-{(1 - total_new/total_original)*100:.0f}%)"
    )
    if args.dry_run:
        print("\n💡 移除 --dry-run 以執行實際縮小")


if __name__ == "__main__":
    main()
