# /// script
# dependencies = []
# requires-python = ">=3.10"
# ///

from __future__ import annotations

import argparse
import sys
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Literal, cast


PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))


from scripts.pz_translate import (
    SKIP_FILES,
    parse_city_directory,
    read_translation,
    txt_to_json_filename,
    write_translation_json,
)


MOD_BASE = (
    PROJECT_ROOT
    / "MOD"
    / "MinidoracatLangFor42"
    / "Contents"
    / "mods"
    / "MinidoracatLangFor42"
    / "42"
    / "media"
)
TRANSLATE_BASE = MOD_BASE / "lua" / "shared" / "Translate"
LANG_DIRS = {
    "CH": TRANSLATE_BASE / "CH",
    "CN": TRANSLATE_BASE / "CN",
}


@dataclass
class ConvertStats:
    json_files: int = 0
    city_json_files: int = 0
    failures: int = 0


LangOption = Literal["CH", "CN", "all"]


@dataclass(frozen=True)
class CliArgs:
    dry_run: bool
    lang: LangOption
    delete_old: bool


class RawArgs(argparse.Namespace):
    dry_run: bool = False
    lang: str = "all"
    delete_old: bool = False


def parse_args() -> CliArgs:
    parser = argparse.ArgumentParser(
        description="PZ 翻譯檔格式轉換工具（.txt → .json）",
    )
    _ = parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只顯示將執行的轉換，不寫入任何檔案",
    )
    _ = parser.add_argument(
        "--lang",
        choices=["CH", "CN", "all"],
        default="all",
        help="只處理 CH、CN 或全部（預設：all）",
    )
    _ = parser.add_argument(
        "--delete-old",
        action="store_true",
        help="成功轉換後刪除舊 .txt 檔案與空城市目錄",
    )

    parsed = parser.parse_args(namespace=RawArgs())
    lang = cast(LangOption, str(parsed.lang))

    return CliArgs(
        dry_run=bool(parsed.dry_run),
        lang=lang,
        delete_old=bool(parsed.delete_old),
    )


def format_warning_info(messages: list[str]) -> str:
    if not messages:
        return ""
    if len(messages) == 1:
        return f"1 warning: {messages[0]}"
    return f"{len(messages)} warnings: {messages[0]}"


def convert_language(lang: str, lang_dir: Path, dry_run: bool, delete_old: bool) -> ConvertStats:
    stats = ConvertStats()
    converted_txt: list[Path] = []
    converted_city_dirs: list[Path] = []

    print(f"\n📁 處理 {lang} 目錄")

    txt_files = sorted((path for path in lang_dir.glob("*.txt")), key=lambda p: p.name.lower())
    for txt_path in txt_files:
        if txt_path.name in SKIP_FILES:
            print(f"  ⏭️ 跳過: {txt_path.name} (保留 .txt 格式)")
            continue

        out_name = txt_to_json_filename(txt_path.name)
        out_path = lang_dir / out_name

        try:
            with warnings.catch_warnings(record=True) as caught:
                warnings.simplefilter("always")
                data = read_translation(txt_path)

            warning_messages = [str(item.message) for item in caught]

            if not dry_run:
                write_translation_json(data, out_path)

            stats.json_files += 1
            converted_txt.append(txt_path)

            if warning_messages:
                warning_info = format_warning_info(warning_messages)
                print(f"  ⚠️ {txt_path.name} → {out_name} ({len(data)} keys, {warning_info})")
            else:
                print(f"  ✅ {txt_path.name} → {out_name} ({len(data)} keys)")
        except Exception as exc:
            stats.failures += 1
            print(f"  ❌ {txt_path.name} 轉換失敗: {exc}")

    city_dirs = sorted((path for path in lang_dir.iterdir() if path.is_dir()), key=lambda p: p.name.lower())
    for city_dir in city_dirs:
        title_path = city_dir / "title.txt"
        description_path = city_dir / "description.txt"
        if not title_path.exists() or not description_path.exists():
            continue

        out_name = f"{city_dir.name}.json"
        out_path = lang_dir / out_name

        try:
            data = parse_city_directory(city_dir)
            if not dry_run:
                write_translation_json(data, out_path)

            stats.city_json_files += 1
            converted_city_dirs.append(city_dir)
            print(f"  ✅ {city_dir.name}/ → {out_name} ({len(data)} keys)")
        except Exception as exc:
            stats.failures += 1
            print(f"  ❌ {city_dir.name}/ 轉換失敗: {exc}")

    if delete_old:
        if dry_run:
            print("  🧪 dry-run 模式：不刪除舊檔案")
        else:
            for txt_path in converted_txt:
                txt_path.unlink(missing_ok=False)

            removed_city_dirs = 0
            for city_dir in converted_city_dirs:
                for old_name in ("title.txt", "description.txt"):
                    old_path = city_dir / old_name
                    if old_path.exists():
                        old_path.unlink(missing_ok=False)

                try:
                    city_dir.rmdir()
                    removed_city_dirs += 1
                except OSError:
                    pass

            print(f"  🧹 已刪除 {len(converted_txt)} 個舊 .txt 檔")
            print(f"  🧹 已刪除 {removed_city_dirs} 個空城市目錄")

    return stats


def main() -> int:
    args = parse_args()

    print("PZ 翻譯格式轉換 (.txt → .json)")
    print("================================================================")
    if args.dry_run:
        print("模式：dry-run（不寫入檔案）")

    if args.lang == "all":
        languages = ["CH", "CN"]
    else:
        languages = [args.lang]

    summary: dict[str, ConvertStats] = {}
    for lang in languages:
        lang_dir = LANG_DIRS[lang]
        if not lang_dir.exists():
            print(f"\n📁 處理 {lang} 目錄")
            print(f"  ❌ 找不到目錄: {lang_dir}")
            summary[lang] = ConvertStats(failures=1)
            continue

        summary[lang] = convert_language(
            lang=lang,
            lang_dir=lang_dir,
            dry_run=args.dry_run,
            delete_old=args.delete_old,
        )

    parts: list[str] = []
    total_failures = 0
    for lang in languages:
        stats = summary.get(lang, ConvertStats())
        parts.append(f"{lang} = {stats.json_files} 個 JSON + {stats.city_json_files} 個城市 JSON")
        total_failures += stats.failures

    print(f"\n完成：{', '.join(parts)}")

    if total_failures > 0:
        print(f"警告：共有 {total_failures} 個項目轉換失敗")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
