# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""術語引擎：取代 OpenCC s2twp 隱式詞庫的顯式真相表執行器。

規則檔 scripts/terminology.json，三模式（codex 2026-07-30 共識 schema）：
  replace  確定安全的機械替換（literal 或 regex；regex 必附 tests.apply/tests.skip）
  select   語境敏感，禁自動改——命中即回報 needs_selection，除非 key 命中已裁定的 cases
  lint     僅提示（例：語料一致性巡檢），禁自動改

執行規則：
  - 只套 status=approved 的規則
  - 固定階段 charfix → terminology(replace) → exact-key（exact-key 由呼叫端的覆寫層負責）
  - 同一 span 被兩條 replace 規則命中 → 直接 fail（不設模糊 priority）
  - 生產端零 OpenCC 依賴；等價驗證 harness（test_terminology_equivalence.py）才允許 import opencc

用途：
  1) 凍結後新鍵匯入：官方 CH 底稿 → convert() → 人工簽核入庫
  2) 凍結語料 lint：scan() 對現有 CH 值巡檢 select/lint 詞
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

TERMINOLOGY_JSON = Path(__file__).resolve().parent / "terminology.json"


@dataclass
class Issue:
    kind: str          # needs_selection | lint | collision
    rule: str          # 規則識別（A→B 或 rule id）
    span: tuple[int, int]
    excerpt: str
    note: str = ""


@dataclass
class Engine:
    charfix: dict[str, str]
    replaces: list[dict]           # {pair, pattern(compiled), repl, note}
    selects: list[dict]            # {pair, pattern(compiled), cases: {key: repl}, note}
    lints: list[dict]              # {pair, pattern(compiled), note}
    meta: dict = field(default_factory=dict)

    def _apply_charfix(self, text: str) -> str:
        cf = self.charfix
        return "".join(cf[c] if c in cf else c for c in text)

    # ---- 轉換（新鍵匯入用）----
    def convert(self, text: str, *, key: str | None = None) -> tuple[str, list[Issue]]:
        issues: list[Issue] = []
        out = self._apply_charfix(text)

        # replace：先收集全部命中，檢測同 span 衝突，再一次套用（由後往前替換避免位移）
        hits: list[tuple[int, int, str, str]] = []  # (start, end, repl, pair)
        for r in self.replaces:
            for m in r["pattern"].finditer(out):
                hits.append((m.start(), m.end(), m.expand(r["repl"]), r["pair"]))
        hits.sort()
        for (s1, e1, _, p1), (s2, e2, _, p2) in zip(hits, hits[1:]):
            if s2 < e1:  # 重疊
                raise ValueError(
                    f"terminology 同 span 衝突：{p1} 與 {p2} 於 …{out[max(0,s1-10):e2+10]}…"
                )
        for s, e, repl, _ in reversed(hits):
            out = out[:s] + repl + out[e:]

        # select：key 命中已裁定 cases 才套，否則回報
        for r in self.selects:
            case_repl = r["cases"].get(key) if key else None
            if case_repl is not None:
                # lambda 回傳字面值：case 值含 \n、\1 時不得被 re.sub 當跳脫解讀
                out = r["pattern"].sub(lambda _m, _v=case_repl: _v, out)
                continue
            for m in r["pattern"].finditer(out):
                issues.append(Issue("needs_selection", r["pair"], m.span(),
                                    out[max(0, m.start() - 15):m.end() + 15], r["note"]))
        issues += self._lint(out, self.lints)
        return out, issues

    @staticmethod
    def _lint(text: str, rules: list[dict], kind: str = "lint") -> list[Issue]:
        issues: list[Issue] = []
        for r in rules:
            for m in r["pattern"].finditer(text):
                issues.append(Issue(kind, r["pair"], m.span(),
                                    text[max(0, m.start() - 15):m.end() + 15], r["note"]))
        return issues

    # ---- 巡檢（凍結語料 lint 用，不改文本）----
    def scan(self, text: str) -> list[Issue]:
        return self._lint(text, self.selects, "needs_selection") + self._lint(text, self.lints)

    # ---- 自我測試：pattern 正反例＋端對端 convert()（codex review：只測 search 不夠）----
    def selftest(self) -> list[str]:
        failures: list[str] = []
        for r in self.replaces:
            tgt = r["repl"]
            for ex in r.get("tests_apply", []):
                fixed = self._apply_charfix(ex)
                if not r["pattern"].search(fixed):
                    failures.append(f"{r['pair']}: apply 例未命中: {ex!r}")
                    continue
                # 端對端：整個引擎跑完，替換結果必須真的出現（也連帶偵測規則間 collision）
                try:
                    out, _ = self.convert(ex)
                except ValueError as exc:
                    failures.append(f"{r['pair']}: apply 例觸發 collision: {ex!r} ({exc})")
                    continue
                if tgt not in out:
                    failures.append(f"{r['pair']}: convert() 未產出 {tgt!r}: {ex!r} → {out!r}")
            for ex in r.get("tests_skip", []):
                if r["pattern"].search(self._apply_charfix(ex)):
                    failures.append(f"{r['pair']}: skip 例被誤命中: {ex!r}")
                    continue
                try:
                    self.convert(ex)
                except ValueError as exc:
                    failures.append(f"{r['pair']}: skip 例觸發 collision: {ex!r} ({exc})")
        return failures


def load(path: Path = TERMINOLOGY_JSON) -> Engine:
    data = json.loads(path.read_text(encoding="utf-8"))
    charfix = {k: v for k, v in data["charfix"].items() if not k.startswith("_")}
    for k, v in charfix.items():
        if len(k) != 1 or len(v) != 1:
            raise ValueError(f"charfix 僅收單字對：{k}→{v}")
    replaces, selects, lints = [], [], []
    for rule in data["rules"]:
        if rule.get("status") != "approved" or rule.get("_comment"):
            continue
        pair = rule["pair"]
        mode = rule["mode"]
        match = rule["match"]
        pat = re.compile(match["value"]) if match["type"] == "regex" else re.compile(re.escape(match["value"]))
        if mode == "replace":
            if match["type"] == "regex" and not (rule.get("tests", {}).get("apply") and rule.get("tests", {}).get("skip")):
                raise ValueError(f"regex replace 規則必附 tests.apply 與 tests.skip：{pair}")
            replaces.append({"pair": pair, "pattern": pat, "repl": rule["replace"],
                             "tests_apply": rule.get("tests", {}).get("apply", []),
                             "tests_skip": rule.get("tests", {}).get("skip", []),
                             "note": rule.get("note", "")})
        elif mode == "select":
            selects.append({"pair": pair, "pattern": pat,
                            "cases": rule.get("cases", {}), "note": rule.get("note", "")})
        elif mode == "lint":
            lints.append({"pair": pair, "pattern": pat, "note": rule.get("note", "")})
        else:
            raise ValueError(f"未知 mode：{mode}（{pair}）")
    eng = Engine(charfix, replaces, selects, lints, data.get("_meta", {}))
    fails = eng.selftest()
    if fails:
        raise ValueError("terminology selftest 失敗：\n  " + "\n  ".join(fails))
    return eng


if __name__ == "__main__":
    eng = load()
    print(f"terminology.json 載入成功：charfix {len(eng.charfix)} / "
          f"replace {len(eng.replaces)} / select {len(eng.selects)} / lint {len(eng.lints)}")
    print("selftest 通過")
    if len(sys.argv) > 1:  # 快速試轉
        out, issues = eng.convert(sys.argv[1])
        print("→", out)
        for i in issues:
            print("  ", i.kind, i.rule, i.excerpt)
