# /// script
# requires-python = ">=3.10"
# dependencies = ["Pillow>=10.0", "fonttools>=4.40"]
# ///
"""
以 Noto Sans（OFL）重新產生中文點陣字型圖集（AngelCode BMFont 文字格式）。

輸出：
  media/fonts/CH/{1x..4x}/zomboid{Small,Medium,Large}CN.*   Noto Sans TC 優先
  media/fonts/CN/{1x..4x}/...                              Noto Sans SC 優先
  media/fonts/zomboid*CN.*                                 CH/1x 副本（EN fallback，見 AGENTS.md）

字集 = 現有 CH/1x 圖集字元 ∪ CH/CN 翻譯檔用字；主字型沒有的字依序由其他 Noto CJK 補，
拉丁擴充／希臘／西里爾字母最後由 Noto Sans 補。
lineHeight/base 沿用舊圖集，避免 UI 版面位移。

用法：
    uv run scripts/gen_fonts.py

字型檔放 temp/fonts/（gitignored），從 https://github.com/google/fonts/tree/main/ofl 下載：
NotoSans{TC,SC,HK,JP}[wght].ttf、NotoSans[wdth,wght].ttf
"""
import glob
import os
import shutil
import sys
from concurrent.futures import ProcessPoolExecutor

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_OUT = os.path.join(ROOT, "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/fonts")
TRANSLATE = os.path.join(ROOT, "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/lua/shared/Translate")
SRC = os.path.join(ROOT, "temp/fonts")
WEIGHT = 500  # Medium：小字級清楚又不糊
PAGE = 1024
FALLBACK = {"CH": ["TC", "HK", "SC", "JP", "Latin"], "CN": ["SC", "TC", "HK", "JP", "Latin"]}
TAGS = FALLBACK["CH"]
# (dpi, 名稱) -> (像素字級, lineHeight, base)，沿用舊圖集數值
SIZES = {
    ("1x", "Small"): (16, 20, 15), ("1x", "Medium"): (20, 25, 19), ("1x", "Large"): (24, 30, 23),
    ("2x", "Small"): (20, 25, 19), ("2x", "Medium"): (24, 30, 23), ("2x", "Large"): (28, 34, 27),
    ("3x", "Small"): (24, 30, 23), ("3x", "Medium"): (28, 34, 27), ("3x", "Large"): (32, 39, 31),
    ("4x", "Small"): (28, 34, 27), ("4x", "Medium"): (32, 39, 31), ("4x", "Large"): (36, 44, 35),
}


def font_path(tag):
    if tag == "Latin":
        return os.path.join(SRC, "NotoSans[wdth,wght].ttf")
    return os.path.join(SRC, f"NotoSans{tag}[wght].ttf")


def load_font(tag, px):
    f = ImageFont.truetype(font_path(tag), px)
    f.set_variation_by_axes([WEIGHT if a["name"] in (b"Weight", "Weight") else a["default"] for a in f.get_variation_axes()])
    return f


def charset():
    ids = set()
    with open(os.path.join(FONTS_OUT, "CH/1x/zomboidMediumCN.fnt"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("char id="):
                ids.add(int(line.split()[1][3:]))
    for p in glob.glob(os.path.join(TRANSLATE, "C[HN]/*.json")):
        with open(p, encoding="utf-8") as f:
            ids |= {ord(c) for c in f.read() if ord(c) >= 32}
    ids |= set(range(32, 127))
    return ids


def build(job):
    lang, dpi, name, chars, cmaps = job
    px, line_h, base = SIZES[(dpi, name)]
    fonts = {tag: load_font(tag, px) for tag in FALLBACK[lang]}

    glyphs = []  # (cp, img|None, xoff, yoff, adv)
    for cp in sorted(chars):
        ch = chr(cp)
        tag = next((t for t in FALLBACK[lang] if cp in cmaps[t]), None)
        if tag is None:
            continue
        f = fonts[tag]
        adv = round(f.getlength(ch))
        l, t, r, b = f.getbbox(ch, anchor="ls")
        if r <= l or b <= t:
            glyphs.append((cp, None, 0, 0, adv))
            continue
        img = Image.new("L", (r - l, b - t))
        ImageDraw.Draw(img).text((-l, -t), ch, font=f, fill=255, anchor="ls")
        glyphs.append((cp, img, l, base + t, adv))

    # shelf packing，1px 間距
    pages, placed = [], {}
    order = sorted((g for g in glyphs if g[1] is not None), key=lambda g: -g[1].height)
    x = y = shelf = 0
    page = Image.new("L", (PAGE, PAGE))
    for cp, img, *_ in order:
        w, h = img.size
        if x + w > PAGE:
            x, y, shelf = 0, y + shelf + 1, 0
        if y + h > PAGE:
            pages.append(page)
            page, x, y, shelf = Image.new("L", (PAGE, PAGE)), 0, 0, 0
        page.paste(img, (x, y))
        placed[cp] = (x, y, len(pages))
        x += w + 1
        shelf = max(shelf, h)
    pages.append(page)

    out = os.path.join(FONTS_OUT, lang, dpi)
    stem = f"zomboid{name}CN"
    for old in glob.glob(os.path.join(out, f"{stem}_*.png")):
        os.remove(old)
    white = Image.new("L", (PAGE, PAGE), 255)
    for i, p in enumerate(pages):
        Image.merge("RGBA", (white, white, white, p)).save(os.path.join(out, f"{stem}_{i:02d}.png"), optimize=True)

    face = "Noto Sans " + FALLBACK[lang][0]
    lines = [
        f'info face="{face}" size=-{px} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={line_h} base={base} scaleW={PAGE} scaleH={PAGE} pages={len(pages)} packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
    ]
    lines += [f'page id={i} file="{stem}_{i:02d}.png"' for i in range(len(pages))]
    lines.append(f"chars count={len(glyphs)}")
    for cp, img, xo, yo, adv in glyphs:
        px_, py_, pg = placed.get(cp, (0, 0, 0))
        w, h = img.size if img else (0, 0)
        lines.append(f"char id={cp} x={px_} y={py_} width={w} height={h} xoffset={xo} yoffset={yo} xadvance={adv} page={pg} chnl=15")
    with open(os.path.join(out, f"{stem}.fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return f"{lang}/{dpi}/{stem}: {len(glyphs)} 字, {len(pages)} 頁"


def main():
    missing = [t for t in TAGS if not os.path.exists(font_path(t))]
    if missing:
        sys.exit(f"缺字型檔：{', '.join(font_path(t) for t in missing)}")
    cmaps = {t: set(TTFont(font_path(t), lazy=True).getBestCmap()) for t in TAGS}
    chars = charset()
    lost = sorted(cp for cp in chars if not any(cp in c for c in cmaps.values()))
    print(f"字集 {len(chars)} 字；Noto 皆無而略過 {len(lost)} 字：{''.join(map(chr, lost))[:200]}")
    jobs = [(lang, dpi, name, chars, cmaps) for lang in ("CH", "CN") for dpi, name in SIZES]
    with ProcessPoolExecutor() as ex:
        for msg in ex.map(build, jobs):
            print(msg)
    for p in glob.glob(os.path.join(FONTS_OUT, "zomboid*CN*")):
        os.remove(p)
    for p in glob.glob(os.path.join(FONTS_OUT, "CH/1x/zomboid*CN*")):
        shutil.copy2(p, FONTS_OUT)
    print("根層已同步 CH/1x（EN fallback）")


if __name__ == "__main__":
    main()
