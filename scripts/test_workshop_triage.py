# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""workshop_triage 的非平凡邏輯回歸測試（不打網路，用 stub 回應）。

執行：uv run scripts/test_workshop_triage.py
不依賴測試框架，assert 失敗即測試失敗（exit code != 0）。

只測三件會默默出錯的事：
  1. Jev 回應攤平（noul/score/choice 三種型別的取值位置不同，弄錯不會報錯只會全 0）
  2. priority = urgency × needs_reply 的排序（急但沒人等 vs 不急但有人等）
  3. TSV 欄位逃逸（留言常含換行與 tab，沒逃逸會把整份報告的欄位錯開）
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import scripts.workshop_triage as wt  # noqa: E402


def resp(kind: str, kind_p: float, reply: float, urgency: float, specific: float = 0.5) -> dict:
    return {
        "model": "typesafe/jev-test",
        "answers": {
            "kind": {"type": "choice", "choice": kind,
                     "probabilities": {kind: kind_p, "other": 1 - kind_p}, "confidence": 0.8},
            "needs_reply": {"type": "noul", "noul": reply},
            "urgency": {"type": "score", "score": urgency,
                        "probabilities": {"0": 0.1, "1": 0.2, "2": 0.7}, "confidence": 0.7},
            "mentions_specific_text": {"type": "noul", "noul": specific},
        },
        "usage": {"input_tokens": 600, "output_tokens": 100, "cost": 2.5e-05},
    }


SRC = {"workshop_id": "3386633401", "mod": "本體翻譯 MOD"}

# ── 1. 攤平 ──
row = wt.to_row(
    {"id": "1", "author": "玩家A", "author_url": "https://steamcommunity.com/id/playerA",
     "posted_at": "1 Jan, 2026", "posted_ts": 1, "text": "字體疊字了"},
    SRC, resp("translation_error", 0.9, 0.8, 1.6),
)
assert row["kind"] == "translation_error" and row["kind_prob"] == 0.9, row
assert row["needs_reply"] == 0.8 and row["urgency"] == 1.6, row
assert row["mentions_specific_text"] == 0.5, row
assert row["priority"] == round(1.6 * 0.8, 4), row
assert row["by_mod_author"] is False, row
assert row["input_tokens"] == 600 and row["error"] is None, row

# 失敗的留言仍要留一列，且錯誤訊息不能被吞掉
bad = wt.to_row({"id": "2", "author": "玩家B", "text": "x"}, SRC, {"error": "HTTP 500"})
assert bad["error"] == "HTTP 500" and bad["kind"] is None and bad["priority"] == 0.0, bad

# 作者本人：顯示名稱或個人頁連結任一命中都算
assert wt.by_mod_author({"author": "Minidoracat", "author_url": ""})
assert wt.by_mod_author({"author": "如一", "author_url": "https://steamcommunity.com/id/minidoracat"})
assert not wt.by_mod_author({"author": "MiniFan", "author_url": "https://steamcommunity.com/id/someone"})

# ── 2. 排序：急但沒人等 < 中等但有人等 ──
rows = [
    wt.to_row({"id": "urgent_nobody", "text": "a"}, SRC, resp("other", 0.9, 0.05, 2.0)),
    wt.to_row({"id": "mid_waiting", "text": "b"}, SRC, resp("bug", 0.9, 0.95, 1.8)),
    wt.to_row({"id": "praise", "text": "c"}, SRC, resp("praise", 0.99, 0.02, 0.1)),
]
rows.sort(key=lambda r: (r["priority"], r["urgency"], r["needs_reply"]), reverse=True)
assert [r["comment_id"] for r in rows] == ["mid_waiting", "urgent_nobody", "praise"], rows

# ── 3. TSV 逃逸與欄數 ──
assert wt.tsv_cell("第一行\n第二行\tX") == "第一行\\n第二行 X"
assert wt.tsv_cell(None) == ""
with tempfile.TemporaryDirectory() as tmp:
    messy = wt.to_row(
        {"id": "3", "author": "玩\t家", "posted_at": "1 Jan", "text": "壞掉了\n附圖\thttps://x"},
        SRC, resp("bug", 0.9, 0.9, 2.0),
    )
    jsonl, tsv = wt.write_reports([messy], Path(tmp), "test")
    lines = tsv.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 2, lines
    assert all(len(line.split("\t")) == len(wt.TSV_COLS) for line in lines), lines
    # JSONL 保留原始換行（給人看的真相檔），TSV 才逃逸
    assert json.loads(jsonl.read_text(encoding="utf-8"))["text"] == "壞掉了\n附圖\thttps://x"

print("workshop_triage 測試全部通過")
