# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""jev_scan.py 的非平凡邏輯回歸測試（stub 回應，不打網路）。

守三件事：
  1. batch 模式的題名前綴要正確配回原鍵（配錯＝整份報告張冠李戴）。
  2. 缺官方 CH 時不得問 `worse_than_official`（該欄留空）。
  3. 輸出檔名不得被 `Path.with_suffix` 吃掉時間戳。
  4. EN 為 Placeholder 的鍵要被跳過；分句文本與官方 CH 去標點空白後相同時只問用字兩題。

執行：uv run scripts/test_jev_scan.py（或 pytest）
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import jev_scan  # noqa: E402

ITEMS = [
    {"file": "UI.json", "key": "A", "en": "Dry", "official_ch": "乾燥", "ours_ch": "幹燥"},
    {"file": "UI.json", "key": "B", "en": "Open", "official_ch": "", "ours_ch": "開啟"},
]

STUB_ANSWERS = {
    "k1.s2t_error": {"noul": 0.9}, "k1.prc_wording": {"noul": 0.2},
    "k1.meaning_mismatch": {"noul": 0.3}, "k1.worse_than_official": {"noul": 0.7},
    "k2.s2t_error": {"noul": 0.1}, "k2.prc_wording": {"noul": 0.2},
    "k2.meaning_mismatch": {"noul": 0.3},
}


def _stub_call(payload, url, api_key, retries=2):  # noqa: ARG001
    return {"model": "stub-1", "answers": STUB_ANSWERS,
            "usage": {"input_tokens": 100, "output_tokens": 10, "cost": 0.001}}


def test_questions_scoped_to_official() -> None:
    assert "worse_than_official" in jev_scan.questions_for(True)
    assert "worse_than_official" not in jev_scan.questions_for(False)


def test_batch_request_shape() -> None:
    payload, prefixes = jev_scan.build_request(ITEMS, "m")
    assert prefixes == ["k1", "k2"]
    assert set(payload["state"]["items"]) == {"k1", "k2"}
    # k1 有官方 CH（4 題）、k2 沒有（3 題）
    assert set(payload["questions"]) == set(STUB_ANSWERS)


def test_batch_prefix_roundtrip() -> None:
    real = jev_scan.call_jev
    jev_scan.call_jev = _stub_call
    try:
        rows = jev_scan.scan_batch(ITEMS, "http://stub", "key", "m")
    finally:
        jev_scan.call_jev = real
    by_key = {r["key"]: r for r in rows}
    # 機率必須跟著自己的前綴回到自己的鍵，不得錯位
    assert by_key["A"]["s2t_error"] == 0.9
    assert by_key["A"]["worse_than_official"] == 0.7
    assert by_key["B"]["s2t_error"] == 0.1
    assert by_key["B"]["worse_than_official"] is None
    assert by_key["A"]["max_prob"] == 0.9
    # usage 平均攤到每列，總和等於整批用量
    assert sum(r["input_tokens"] for r in rows) == 100


def test_sidecar_keeps_timestamp() -> None:
    prefix = Path("reports/jev_scan.20260919-215649")
    assert jev_scan.sidecar(prefix, ".jsonl").name == "jev_scan.20260919-215649.jsonl"


def test_placeholder_en_skipped() -> None:
    assert jev_scan.is_placeholder_en("Placeholder")
    assert jev_scan.is_placeholder_en(" placeholder. ")
    assert not jev_scan.is_placeholder_en("Bitters (Placeholder)")
    assert not jev_scan.is_placeholder_en("Dry")


def test_sentence_same_as_official_asks_wording_only() -> None:
    same = {"file": "RadioData.json", "key": "R1", "en": "Nine.",
            "official_ch": "九。", "ours_ch": "九."}
    other_file = dict(same, file="UI.json")
    differs = dict(same, ours_ch="十.")
    assert jev_scan.same_as_official(same)
    assert not jev_scan.same_as_official(other_file)
    assert not jev_scan.same_as_official(differs)
    payload, _ = jev_scan.build_request([same, differs], "m")
    assert set(payload["questions"]) == {
        "k1.s2t_error", "k1.prc_wording",
        "k2.s2t_error", "k2.prc_wording", "k2.meaning_mismatch", "k2.worse_than_official",
    }
    # 沒問的題在報告裡留空，不得被當成 0 拉低 max_prob 或計入「有問」
    real = jev_scan.call_jev
    jev_scan.call_jev = lambda payload, url, api_key, retries=2: {  # noqa: ARG005
        "answers": {"k1.s2t_error": {"noul": 0.4}, "k1.prc_wording": {"noul": 0.6}},
        "usage": {}}
    try:
        row = jev_scan.scan_batch([same, differs], "http://stub", "key", "m")[0]
    finally:
        jev_scan.call_jev = real
    assert row["meaning_mismatch"] is None and row["worse_than_official"] is None
    assert row["max_prob"] == 0.6


def main() -> int:
    test_questions_scoped_to_official()
    test_batch_request_shape()
    test_batch_prefix_roundtrip()
    test_sidecar_keeps_timestamp()
    test_placeholder_en_skipped()
    test_sentence_same_as_official_asks_wording_only()
    print("OK — jev_scan 回歸測試全數通過")
    return 0


if __name__ == "__main__":
    sys.exit(main())
