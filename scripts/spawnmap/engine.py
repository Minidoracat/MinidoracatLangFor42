"""出生點底圖的去字與排字引擎（由 build.py 呼叫；座標一律是第 0 層像素）。

一筆標籤（labels/*.json 的一個物件，先套 styles.json 的 "style" 再用自己的欄位覆寫）：
  en / note   原文與備註，引擎不讀
  clone, to   先把矩形 clone=[x0,y0,x1,y1] 複製到左上角 to=[x,y]（補被字蓋掉的鐵軌、線條）
  erase       要抹字的區域清單：[x0,y0,x1,y1] 矩形、[cx,cy,w,h,角度] 旋轉矩形（角度逆時針）或點列
  mode, thr, sat, grow, min_diff, bg_k, fill, fill_sigma, ink   抹字參數，見 erase()
  ch / cn     要排的字（\\n 換行）；沒有就只抹不排
  at | box    文字塊中心 [x,y]，或文字框 [x0,y0,x1,y1]（align=l/r 時貼齊框邊，否則置中）
  path        折線點列：每個字沿線等距排、依切線旋轉（彎曲的河名、森林名）
  family(sans|serif), weight, size(字身 px), tracking(字距 px), leading(行高倍數), italic(斜切量),
  angle(逆時針度數), align(l|c|r), wrap(折行寬 px), justify, scale_x(字寬倍數)
  color [r,g,b]（不給就用被抹掉的字的顏色）, opacity, worn, outline [間隙,線寬]
"""
import functools
import os

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT_DIR = os.path.join(ROOT, "temp", "fonts")
SS = 4  # 文字超取樣倍率
_paper = np.ones((1, 1, 3), np.float32)


def set_paper(patch):
    """patch：底圖上一塊乾淨紙面（RGB）。取「原圖 ÷ 模糊圖」當紙紋，鏡像平鋪，補字洞與上字時乘回去。"""
    global _paper
    p = patch.astype(np.float32)
    r = p / cv2.GaussianBlur(p, (0, 0), 3)
    r = np.concatenate([r, r[:, ::-1]], 1)
    _paper = np.concatenate([r, r[::-1]], 0)


def paper(x0, y0, x1, y1):
    return _paper[(np.arange(y0, y1) % _paper.shape[0])[:, None], (np.arange(x0, x1) % _paper.shape[1])[None, :]]


@functools.lru_cache(maxsize=None)
def font(family, lang, weight, px):
    name = f"Noto{'Sans' if family == 'sans' else 'Serif'}{'TC' if lang == 'ch' else 'SC'}[wght].ttf"
    f = ImageFont.truetype(os.path.join(FONT_DIR, name), px)
    f.set_variation_by_axes([weight])
    return f


def to_poly(p):
    if not isinstance(p[0], (list, tuple)):
        if len(p) == 4:
            x0, y0, x1, y1 = p
            return np.array([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], np.float64)
        cx, cy, w, h, ang = p
        a = np.radians(-ang)
        r = np.array([[np.cos(a), -np.sin(a)], [np.sin(a), np.cos(a)]])
        return np.array([[-w, -h], [w, -h], [w, h], [-w, h]], np.float64) / 2 @ r.T + [cx, cy]
    return np.array(p, np.float64)


def erase(img, polys, mode="dark", thr=100, sat=45, grow=2, min_diff=14, bg_k=41, fill="telea", fill_sigma=10, ink=None, pad=24):
    """把區域內的字抹掉並補回底圖。回傳被抹掉的字的代表色（RGB），沒抹到東西回傳 None。

    mode=dark：亮度低於 thr、彩度（max-min）低於 sat 的像素是字（道路、鐵軌是彩色，不會被當成字）。
    mode=light：深底淺字，亮度高於 thr 的像素是字。
    mode=diff：和局部背景（bg_k 中值濾波）色差超過 thr 的像素都是字（彩色字）。
    mode=color：和指定字色 ink=[r,g,b] 的色差小於 thr 的像素是字（河面、森林上的淡色浮水印大字；
      旁邊的河岸線、圖示顏色不同，不會被抹）。字色用 build.py probe 量。
    字的邊緣向外收 grow px，只收和背景差 min_diff 以上的像素。
    fill=telea：沿周圍結構補（細字、壓在線條上的字）；fill=smooth：用周圍顏色加權平均補（面板上的大字）。
    """
    polys = [to_poly(p) for p in polys]
    pts = np.concatenate(polys)
    x0, y0 = np.maximum(np.floor(pts.min(0)).astype(int) - pad, 0)
    x1, y1 = np.minimum(np.ceil(pts.max(0)).astype(int) + pad, [img.shape[1], img.shape[0]])
    roi = img[y0:y1, x0:x1, :3]
    region = np.zeros(roi.shape[:2], np.uint8)
    for p in polys:
        cv2.fillPoly(region, [np.round(p - [x0, y0]).astype(np.int32)], 1)
    lum = cv2.cvtColor(roi, cv2.COLOR_RGB2GRAY).astype(np.int16)
    bg = cv2.medianBlur(roi, bg_k)
    bg_lum = cv2.cvtColor(bg, cv2.COLOR_RGB2GRAY).astype(np.int16)
    chroma = roi.max(2).astype(np.int16) - roi.min(2)
    if mode == "dark":
        core = (lum < thr) & (chroma < sat)
        edge = ((bg_lum - lum) > min_diff) & (chroma < sat + 25)
    elif mode == "light":
        core = lum > thr
        edge = (lum - bg_lum) > min_diff
    else:
        d = np.abs(roi.astype(np.int16) - bg.astype(np.int16)).max(2)
        core = d > thr if mode == "diff" else np.abs(roi.astype(np.int16) - np.array(ink, np.int16)).max(2) < thr
        edge = d > min_diff
    core = (core & (region > 0)).astype(np.uint8)
    if not core.any():
        return None
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * grow + 1, 2 * grow + 1))
    mask = ((cv2.dilate(core, k) > 0) & (edge | (core > 0))).astype(np.uint8)
    found = np.median(roi[core > 0], axis=0)
    if fill == "telea":
        low = cv2.inpaint(roi, mask * 255, 4, cv2.INPAINT_TELEA).astype(np.float32)
    else:  # 洞大於模糊半徑時權重趨近 0，改用更大半徑的結果兜底
        keep = (cv2.dilate(mask, np.ones((5, 5), np.uint8)) == 0).astype(np.float32)
        low = np.zeros(roi.shape, np.float32)
        done = np.zeros(roi.shape[:2], bool)
        for s in (fill_sigma, fill_sigma * 3, fill_sigma * 9):
            den = cv2.GaussianBlur(keep, (0, 0), s)
            cur = cv2.GaussianBlur(roi * keep[..., None], (0, 0), s) / np.maximum(den, 1e-6)[..., None]
            use = ~done & (den > 0.15)
            low[use] = cur[use]
            done |= use
        low[~done] = cur[~done]
    out = np.clip(low * paper(x0, y0, x1, y1), 0, 255)
    roi[:] = np.where(mask[..., None] > 0, out, roi).astype(np.uint8)
    return tuple(int(v) for v in found)


def wrap_lines(text, fnt, max_w, tracking):
    """CJK 逐字折行；行首不放收尾標點。"""
    no_head = "，。、；：！？）」』》…—"
    lines = []
    for para in text.split("\n"):
        cur, w = "", 0.0
        for ch in para:
            cw = fnt.getlength(ch) + tracking
            if cur and w + cw > max_w and ch not in no_head:
                lines.append(cur)
                cur, w = "", 0.0
            cur += ch
            w += cw
        lines.append(cur)
    return lines


def text_mask(text, lang, family="sans", weight=400, size=24, tracking=0.0, leading=1.25,
              italic=0.0, angle=0.0, align="c", wrap=None, scale_x=1.0, justify=False):
    """回傳文字塊的 alpha 遮罩（float32，0..1）。"""
    fnt = font(family, lang, weight, size * SS)
    tr = tracking * SS
    target = wrap * SS / scale_x if wrap else 0  # 折行寬；行首禁則擠出去的行用負字距收回來
    lines = wrap_lines(text, fnt, target, tr) if wrap else text.split("\n")
    widths = [sum(fnt.getlength(c) + tr for c in ln) - tr if ln else 0 for ln in lines]
    lh = size * SS * leading
    bw = int(target or max(widths)) + 4 * SS
    bh = int(lh * (len(lines) - 1) + size * SS * 1.3) + 4 * SS
    im = Image.new("L", (bw, bh), 0)
    d = ImageDraw.Draw(im)
    for i, (ln, w) in enumerate(zip(lines, widths)):
        extra = 0.0
        if wrap and len(ln) > 1 and (w > target or (justify and i < len(lines) - 1 and w > 0.8 * target)):
            extra = (target - w) / (len(ln) - 1)
            w = target
        x = {"l": 2 * SS, "c": (bw - w) / 2, "r": bw - 2 * SS - w}[align]
        y = 2 * SS + i * lh + size * SS * 1.03  # 基線：Noto CJK 字身頂往下 0.88 em，上方留 0.15 em
        for c in ln:
            d.text((x, y), c, font=fnt, fill=255, anchor="ls")
            x += fnt.getlength(c) + tr + extra
    if scale_x != 1.0:
        im = im.resize((max(1, int(bw * scale_x)), bh), Image.LANCZOS)
    if italic:
        w, h = im.size
        im = im.transform((int(w + italic * h), h), Image.AFFINE, (1, italic, -italic * h, 0, 1, 0), Image.BICUBIC)
    if angle:
        im = im.rotate(angle, Image.BICUBIC, expand=True)
    im = im.resize((max(1, round(im.width / SS)), max(1, round(im.height / SS))), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


def outlined(mask, gap, width):
    """字外圍加一圈輪廓線（離字 gap px、線寬 width px），標題藝術字用。"""
    m = np.pad(mask, int(gap + width + 2))
    hard = (m > 0.5).astype(np.uint8)
    disk = lambda r: cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    ring = cv2.dilate(hard, disk(int(gap + width))) - cv2.dilate(hard, disk(int(gap)))
    return np.maximum(m, cv2.GaussianBlur(ring.astype(np.float32), (0, 0), 0.7))


def composite(img, mask, center, color, opacity=1.0, worn=False):
    """worn：底圖越亮（摺痕磨出的白斑）字越淡，讓新字和原字一樣被摺痕磨到。"""
    h, w = mask.shape
    x0 = int(round(center[0] - w / 2))
    y0 = int(round(center[1] - h / 2))
    sx0, sy0 = max(0, -x0), max(0, -y0)
    x0, y0 = max(x0, 0), max(y0, 0)
    x1, y1 = min(x0 + w - sx0, img.shape[1]), min(y0 + h - sy0, img.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    a = (mask[sy0:sy0 + y1 - y0, sx0:sx0 + x1 - x0] * opacity)[..., None]
    roi = img[y0:y1, x0:x1, :3].astype(np.float32)
    if worn:
        a = a * np.clip((228 - roi.mean(2, keepdims=True)) / 30, 0.15, 1)
    ink = np.array(color, np.float32) * paper(x0, y0, x1, y1)
    img[y0:y1, x0:x1, :3] = np.clip(roi * (1 - a) + ink * a + 0.5, 0, 255).astype(np.uint8)


ERASE_KEYS = ("mode", "thr", "sat", "grow", "min_diff", "bg_k", "fill", "fill_sigma", "ink")
TEXT_KEYS = ("family", "weight", "size", "tracking", "leading", "italic", "angle", "align", "wrap", "scale_x", "justify")


def apply_label(img, lab, styles, lang):
    st = {**styles.get(lab.get("style", ""), {}), **lab}
    if "clone" in st:
        x0, y0, x1, y1 = st["clone"]
        dx, dy = st["to"]
        img[dy:dy + y1 - y0, dx:dx + x1 - x0, :3] = img[y0:y1, x0:x1, :3].copy()
    ink = None
    if st.get("erase"):
        ink = erase(img, st["erase"], **{k: st[k] for k in ERASE_KEYS if k in st})
    text = st.get(lang)
    if not text:
        return
    color = st.get("color") or ink or (30, 30, 30)
    kw = {k: st[k] for k in TEXT_KEYS if k in st}
    comp = {"opacity": st.get("opacity", 1.0), "worn": st.get("worn", False)}
    if "path" in st:
        pts = np.array(st["path"], np.float64)
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        cum = np.concatenate([[0], np.cumsum(seg)])
        for i, c in enumerate(text):
            t = cum[-1] * (i + 0.5) / len(text)
            j = min(np.searchsorted(cum, t, side="right") - 1, len(seg) - 1)
            p = pts[j] + (pts[j + 1] - pts[j]) * ((t - cum[j]) / seg[j])
            dx, dy = pts[j + 1] - pts[j]
            composite(img, text_mask(c, lang, **{**kw, "angle": -np.degrees(np.arctan2(dy, dx))}), p, color, **comp)
        return
    m = text_mask(text, lang, **kw)
    if "outline" in st:
        m = outlined(m, *st["outline"])
    if "at" in st:
        cx, cy = st["at"]
    else:
        x0, y0, x1, y1 = st["box"]
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        if st.get("align", "c") != "c" and not st.get("angle"):
            cx = x0 + m.shape[1] / 2 if st["align"] == "l" else x1 - m.shape[1] / 2
    composite(img, m, (cx, cy), color, **comp)
