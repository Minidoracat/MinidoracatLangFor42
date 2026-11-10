# /// script
# requires-python = ">=3.10"
# dependencies = ["Pillow>=10.0", "numpy", "opencv-python-headless", "rapidocr-onnxruntime"]
# ///
"""出生點底圖的 OCR 輔助：建標籤時找字的位置，做完後查有沒有英文沒抹掉。

  uv run scripts/spawnmap/ocr.py scan official -o temp/spawnmap/off_ocr.json     # 官方底圖
  uv run scripts/spawnmap/ocr.py scan <某份 pyramid zip> -o out.json
  uv run scripts/spawnmap/ocr.py list temp/spawnmap/off_ocr.json --box x0,y0,x1,y1
  uv run scripts/spawnmap/ocr.py latin out.json        # 列出還含英文字母的辨識結果（殘留檢查）

OCR 會漏字、認錯字（旋轉字、藝術字、很淡的浮水印尤其容易漏），結果只當線索，最後一律目視。
"""
import argparse
import json
import math
import os
import re
import sys
import zipfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def scan(args):
    from PIL import Image
    from rapidocr_onnxruntime import RapidOCR
    import build
    z = zipfile.ZipFile(build.OFFICIAL if args.src == "official" else args.src)
    img = Image.fromarray(build.load_level(z, 0)[0][..., :3])
    ocr = RapidOCR()
    out = []
    for scale in (1.0, 0.3):  # 0.3 倍那輪抓 1024 px 切塊裝不下的大字
        im = img if scale == 1.0 else img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
        arr = np.asarray(im)[:, :, ::-1]
        for y in range(0, arr.shape[0], 768):
            for x in range(0, arr.shape[1], 768):
                res, _ = ocr(np.ascontiguousarray(arr[y:y + 1024, x:x + 1024]))
                for box, text, conf in res or []:
                    out.append({"scale": scale, "box": [[(px + x) / scale, (py + y) / scale] for px, py in box], "text": text, "conf": float(conf)})
        print(f"{scale} 倍：累計 {len(out)} 筆", flush=True)
    json.dump(out, open(args.out, "w", encoding="utf-8"), ensure_ascii=False)


def bbox(o):
    p = np.array(o["box"])
    return p[:, 0].min(), p[:, 1].min(), p[:, 0].max(), p[:, 1].max()


def dedup(items):
    """切塊重疊會重複辨識：框重疊超過三成的只留信心最高的。"""
    keep = []
    for o in sorted(items, key=lambda o: -o["conf"]):
        a = bbox(o)
        for k in keep:
            b = bbox(k)
            w, h = min(a[2], b[2]) - max(a[0], b[0]), min(a[3], b[3]) - max(a[1], b[1])
            if w > 0 and h > 0 and w * h > 0.3 * min((a[2] - a[0]) * (a[3] - a[1]), (b[2] - b[0]) * (b[3] - b[1])):
                break
        else:
            keep.append(o)
    return keep


def show(items):
    for o in sorted(items, key=lambda o: (round(bbox(o)[1] / 40), bbox(o)[0])):
        p = np.array(o["box"])
        cx, cy = p.mean(0)
        w, h = np.linalg.norm(p[1] - p[0]), np.linalg.norm(p[3] - p[0])
        ang = -math.degrees(math.atan2(p[1][1] - p[0][1], p[1][0] - p[0][0]))
        print(f"中心({cx:.0f},{cy:.0f}) 寬{w:.0f} 高{h:.0f} 角{ang:+.0f} 信心{o['conf']:.2f} x{o['scale']}  {o['text']}")


def list_(args):
    x0, y0, x1, y1 = (int(v) for v in args.box.split(","))
    items = json.load(open(args.json, encoding="utf-8"))
    show(dedup([o for o in items if x0 <= np.mean([p[0] for p in o["box"]]) <= x1 and y0 <= np.mean([p[1] for p in o["box"]]) <= y1]))


def latin(args):
    show(dedup([o for o in json.load(open(args.json, encoding="utf-8")) if re.search(r"[A-Za-z]{3,}", o["text"])]))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("scan")
    p.add_argument("src")
    p.add_argument("-o", "--out", required=True)
    p.set_defaults(fn=scan)
    p = sub.add_parser("list")
    p.add_argument("json")
    p.add_argument("--box", required=True)
    p.set_defaults(fn=list_)
    p = sub.add_parser("latin")
    p.add_argument("json")
    p.set_defaults(fn=latin)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
