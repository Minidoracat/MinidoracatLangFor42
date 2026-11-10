# /// script
# requires-python = ">=3.10"
# dependencies = ["Pillow>=10.0", "numpy", "opencv-python-headless"]
# ///
"""出生點中文底圖：以官方英文底圖為底，照 labels/*.json 抹掉英文、排上中文。

  uv run scripts/spawnmap/build.py preview --lang ch --box x0,y0,x1,y1 [--only 檔名,...] [--scale 0.5] [-o out.png]
  uv run scripts/spawnmap/build.py build --lang ch     # 寫 MOD 的 spawnSelectImagePyramid_CH.zip（cn 寫無後綴那份）
  uv run scripts/spawnmap/build.py probe --box x0,y0,x1,y1   # 量官方圖一小框的字色與底色
  uv run scripts/spawnmap/build.py check               # 閘門（PZ 升版必跑）：MOD 的兩份底圖還是照官方現行底圖做的嗎；無官方檔 exit 2

底圖讀官方 Muldraugh, KY/spawnSelectImagePyramid.zip（環境變數 PZ_PATH 可改安裝路徑）。
沒被標籤動到的像素與 tile 原封不動沿用官方（tile 位元組直接複製），條目順序、pyramid.txt 與格線同官方。
字型放 temp/fonts/（gitignored）：NotoSans{TC,SC}[wght].ttf、NotoSerif{TC,SC}[wght].ttf，
從 https://github.com/google/fonts/tree/main/ofl 下載。標籤欄位見 engine.py 檔頭。
"""
import argparse
import glob
import io
import json
import os
import re
import sys
import zipfile

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PZ_PATH = os.environ.get("PZ_PATH", r"D:\SteamLibrary\steamapps\common\ProjectZomboid")
OFFICIAL = os.path.join(PZ_PATH, "media", "maps", "Muldraugh, KY", "spawnSelectImagePyramid.zip")
OUT_DIR = os.path.join(engine.ROOT, "MOD/MinidoracatLangFor42/Contents/mods/MinidoracatLangFor42/42/media/maps/Riverside, KY")
OUT_NAME = {"ch": "spawnSelectImagePyramid_CH.zip", "cn": "spawnSelectImagePyramid.zip"}
TILE = 256
PAPER_BOX = (7456, 3384, 7712, 3640)  # 官方圖上最乾淨的一塊紙面（第 0 層），紙紋取樣用


def load_level(z, level, tx0=0, ty0=0, tx1=None, ty1=None):
    """把某層 [tx0,tx1)×[ty0,ty1) 的 tile 拼成 RGBA 陣列；回傳 (陣列, {(tx,ty): 原始位元組})。"""
    names = {}
    for n in z.namelist():
        m = re.fullmatch(rf"{level}/tile(\d+)x(\d+)\.png", n)
        if m:
            names[(int(m[1]), int(m[2]))] = n
    tx1 = tx1 if tx1 is not None else max(x for x, _ in names) + 1
    ty1 = ty1 if ty1 is not None else max(y for _, y in names) + 1
    img = np.zeros(((ty1 - ty0) * TILE, (tx1 - tx0) * TILE, 4), np.uint8)
    raw = {}
    for (tx, ty), n in names.items():
        if tx0 <= tx < tx1 and ty0 <= ty < ty1:
            raw[(tx, ty)] = z.read(n)
            img[(ty - ty0) * TILE:(ty - ty0 + 1) * TILE, (tx - tx0) * TILE:(tx - tx0 + 1) * TILE] = np.asarray(Image.open(io.BytesIO(raw[(tx, ty)])).convert("RGBA"))
    return img, raw


def load_labels(only=None):
    styles = json.load(open(os.path.join(HERE, "styles.json"), encoding="utf-8"))
    labels = []
    for path in sorted(glob.glob(os.path.join(HERE, "labels", "*.json"))):
        name = os.path.splitext(os.path.basename(path))[0]
        if only and name not in only:
            continue
        labels += json.load(open(path, encoding="utf-8"))["labels"]
    return styles, labels


def points(lab, source=False):
    """標籤會畫到的座標點（判斷它落在哪）；source=True 時加上 clone 的來源矩形（preview 要一起載入）。"""
    pts = [engine.to_poly(p) for p in lab.get("erase", [])]
    if "at" in lab:
        pts.append(np.array([lab["at"]], np.float64))
    if "box" in lab:
        pts.append(engine.to_poly(lab["box"]))
    if "path" in lab:
        pts.append(np.array(lab["path"], np.float64))
    if "clone" in lab:
        x0, y0, x1, y1 = lab["clone"]
        dx, dy = lab["to"]
        pts.append(engine.to_poly([dx, dy, dx + x1 - x0, dy + y1 - y0]))
        if source:
            pts.append(engine.to_poly(lab["clone"]))
    return np.concatenate(pts)


def shifted(lab, ox, oy):
    """把標籤座標平移到局部圖（preview 只載入一部分 tile）。"""
    lab = dict(lab)
    mv = lambda p: (engine.to_poly(p) - [ox, oy]).tolist()
    if "erase" in lab:
        lab["erase"] = [mv(p) for p in lab["erase"]]
    if "path" in lab:
        lab["path"] = mv(lab["path"])
    if "at" in lab:
        lab["at"] = [lab["at"][0] - ox, lab["at"][1] - oy]
    if "box" in lab:
        x0, y0, x1, y1 = lab["box"]
        lab["box"] = [x0 - ox, y0 - oy, x1 - ox, y1 - oy]
    if "clone" in lab:
        x0, y0, x1, y1 = lab["clone"]
        lab["clone"] = [x0 - ox, y0 - oy, x1 - ox, y1 - oy]
        lab["to"] = [lab["to"][0] - ox, lab["to"][1] - oy]
    return lab


def set_paper(z):
    x0, y0, x1, y1 = PAPER_BOX
    img, _ = load_level(z, 0, x0 // TILE, y0 // TILE, (x1 - 1) // TILE + 1, (y1 - 1) // TILE + 1)
    ox, oy = x0 // TILE * TILE, y0 // TILE * TILE
    engine.set_paper(img[y0 - oy:y1 - oy, x0 - ox:x1 - ox, :3])


def preview(args):
    z = zipfile.ZipFile(OFFICIAL)
    set_paper(z)
    x0, y0, x1, y1 = (int(v) for v in args.box.split(","))
    styles, labels = load_labels(args.only.split(",") if args.only else None)
    hit = []
    for lab in labels:
        p = points(lab)
        if p[:, 0].max() >= x0 and p[:, 0].min() <= x1 and p[:, 1].max() >= y0 and p[:, 1].min() <= y1:
            hit.append(lab)
    # 載入範圍＝框＋命中標籤用到的所有點（含 clone 來源），外加一圈 tile 給抹字取背景
    allp = np.concatenate([np.array([[x0, y0], [x1, y1]], np.float64)] + [points(lab, source=True) for lab in hit])
    tx0, ty0 = (np.maximum(allp.min(0), 0) // TILE - 1).clip(0).astype(int)
    tx1, ty1 = (allp.max(0) // TILE + 2).astype(int)
    img, _ = load_level(z, 0, tx0, ty0, tx1, ty1)
    ox, oy = tx0 * TILE, ty0 * TILE
    for lab in hit:
        engine.apply_label(img, shifted(lab, ox, oy), styles, args.lang)
    n = len(hit)
    out = Image.fromarray(img[y0 - oy:y1 - oy, x0 - ox:x1 - ox, :3])
    if args.scale != 1.0:
        out = out.resize((round(out.width * args.scale), round(out.height * args.scale)), Image.LANCZOS)
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    out.save(args.out)
    print(f"{n} 筆標籤 → {args.out}")


def probe(args):
    """量官方圖某個小框的顏色：框裡較暗的一成五像素（通常是字）與較亮的一半（通常是底）。"""
    x0, y0, x1, y1 = (int(v) for v in args.box.split(","))
    img, _ = load_level(zipfile.ZipFile(OFFICIAL), 0, x0 // TILE, y0 // TILE, x1 // TILE + 1, y1 // TILE + 1)
    px = img[y0 % TILE:y0 % TILE + y1 - y0, x0 % TILE:x0 % TILE + x1 - x0, :3].reshape(-1, 3).astype(int)
    lum = px.mean(1)
    for name, sel in (("暗 15%", lum <= np.percentile(lum, 15)), ("亮 50%", lum >= np.percentile(lum, 50))):
        print(name, np.median(px[sel], axis=0).astype(int).tolist())


def build(args):
    z = zipfile.ZipFile(OFFICIAL)
    set_paper(z)
    styles, labels = load_labels()
    official, raws = load_level(z, 0)
    img = official.copy()
    for lab in labels:
        engine.apply_label(img, lab, styles, args.lang)
    changed = (img != official).any(2)
    out = {}  # 條目名 → 位元組
    reused = 0
    for level in range(5):
        if level:  # 下一層＝上一層 2×2 平均；只把被改到的像素換掉，其他沿用官方該層
            official, raws = load_level(z, level)
            h, w = img.shape[0] // 2, img.shape[1] // 2
            small = cv2.resize(img, (w, h), interpolation=cv2.INTER_AREA)
            changed = cv2.resize(changed.astype(np.uint8), (w, h), interpolation=cv2.INTER_AREA) > 0
            img = official.copy()
            img[:h, :w][changed] = small[changed]
            changed = np.pad(changed, ((0, img.shape[0] - h), (0, img.shape[1] - w)))
        for (tx, ty), raw in raws.items():
            ys, xs = slice(ty * TILE, (ty + 1) * TILE), slice(tx * TILE, (tx + 1) * TILE)
            if changed[ys, xs].any():
                buf = io.BytesIO()
                Image.fromarray(img[ys, xs]).save(buf, "PNG", optimize=True)
                raw = buf.getvalue()
            else:
                reused += 1
            out[f"{level}/tile{tx}x{ty}.png"] = raw
    path = os.path.join(args.out_dir, OUT_NAME[args.lang])
    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as zo:
        for info in z.infolist():  # 條目順序、目錄條目、時間都照官方，輸出才可重現
            zi = zipfile.ZipInfo(info.filename, info.date_time)
            zi.external_attr = info.external_attr
            zo.writestr(zi, out.get(info.filename) or z.read(info.filename))
    print(f"{len(labels)} 筆標籤；{len(z.infolist())} 條目（{reused} 個 tile 沿用官方）→ {path}（{os.path.getsize(path) / 1e6:.1f} MB）")


def check(args):
    """官方重畫底圖時（42.22 就重畫過）本包的圖會過時而沒人發現：比 tile 的 CRC，沿用官方的 tile 不再相同就 FAIL。"""
    if not os.path.exists(OFFICIAL):
        print(f"SKIP: 官方檔不存在（{OFFICIAL}）；設 PZ_PATH 後重跑")
        return 2
    z = zipfile.ZipFile(OFFICIAL)
    official = {i.filename: i.CRC for i in z.infolist()}
    fails = []
    for name in OUT_NAME.values():
        zo = zipfile.ZipFile(os.path.join(args.out_dir, name))
        infos = zo.infolist()
        if [i.filename for i in infos] != list(official):
            fails.append(f"{name}：條目清單或順序和官方不同")
        elif zo.read("pyramid.txt") != z.read("pyramid.txt"):
            fails.append(f"{name}：pyramid.txt 和官方不同")
        level0 = [i for i in infos if i.filename.startswith("0/tile")]
        same = sum(official.get(i.filename) == i.CRC for i in level0)
        print(f"{name}：{len(infos)} 條目，第 0 層 {same}/{len(level0)} 個 tile 與官方相同")
        if same < 0.15 * len(level0):  # 重做後沒有字的 tile（約一半）都沿用官方；官方一重畫就會掉到接近 0
            fails.append(f"{name}：和官方相同的 tile 太少，官方底圖可能改版了，照 lang-dev assets.md 重做")
    for f in fails:
        print("FAIL:", f)
    print("PASS" if not fails else f"FAIL（{len(fails)} 項）")
    return 1 if fails else 0


def main():
    Image.MAX_IMAGE_PIXELS = None
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("preview")
    p.add_argument("--lang", choices=("ch", "cn"), default="ch")
    p.add_argument("--box", required=True)
    p.add_argument("--only")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("-o", "--out", default=os.path.join(engine.ROOT, "temp", "spawnmap", "preview.png"))
    p.set_defaults(fn=preview)
    b = sub.add_parser("build")
    b.add_argument("--lang", choices=("ch", "cn"), required=True)
    b.add_argument("--out-dir", default=OUT_DIR)
    b.set_defaults(fn=build)
    q = sub.add_parser("probe")
    q.add_argument("--box", required=True)
    q.set_defaults(fn=probe)
    c = sub.add_parser("check")
    c.add_argument("--out-dir", default=OUT_DIR)
    c.set_defaults(fn=check)
    args = ap.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
