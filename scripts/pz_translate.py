from __future__ import annotations

import json
import warnings
from collections import OrderedDict
from pathlib import Path
from typing import cast


PREFIX_STRIP_CATEGORIES = {"ItemName", "EvolvedRecipeName"}
SKIP_FILES = {"language.txt", "credits.txt", "streets.txt"}


def _find_unescaped_quote(token: str) -> int:
    escaped = False
    for index in range(1, len(token)):
        char = token[index]
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = True
            continue
        if char == '"':
            return index
    return -1


def _unescape_lua_string(value: str) -> str:
    chars: list[str] = []
    index = 0

    while index < len(value):
        char = value[index]
        if char != "\\" or index + 1 >= len(value):
            chars.append(char)
            index += 1
            continue

        nxt = value[index + 1]
        if nxt == "n":
            chars.append("\n")
        elif nxt == "r":
            chars.append("\r")
        elif nxt == "t":
            chars.append("\t")
        elif nxt == '"':
            chars.append('"')
        elif nxt == "\\":
            chars.append("\\")
        else:
            chars.append("\\")
            chars.append(nxt)

        index += 2

    return "".join(chars)


def _warn_missing_quotes(line_number: int, key: str) -> None:
    warnings.warn(
        f"missing quotes at line {line_number} for key {key}",
        UserWarning,
        stacklevel=3,
    )


def _extract_quoted_segment(token: str) -> tuple[str, bool]:
    """從 PZ Lua 翻譯值的引號段落中提取內容。

    PZ 翻譯檔中可能包含嵌套引號（如 getTexture("...")），
    不能用標準 Lua 引號匹配。改用右端模式匹配：
      末尾 "..  → 有續行，去掉右側 ".. 和左側 "
      末尾 ",  → 最後一段
      末尾 "   → 最後一段（無逗號）
    """
    if not token.startswith('"'):
        return token.rstrip(",").strip(), False

    # 從右端判斷模式
    if token.endswith('"..'):
        # 有續行：去掉開頭 " 和結尾 "..
        inner = token[1:-3]
        return inner, True
    elif token.endswith('",'):
        # 最後一段（逗號結尾）：去掉開頭 " 和結尾 ",
        inner = token[1:-2]
        return inner, False
    elif token.endswith('"'):
        # 最後一段（無逗號）：去掉首尾 "
        inner = token[1:-1]
        return inner, False
    else:
        # fallback：嘗試用舊方法
        quote_index = _find_unescaped_quote(token)
        if quote_index != -1:
            quoted = token[1:quote_index]
            after_quote = token[quote_index + 1:].strip()
            continues = after_quote.startswith('..')
            return quoted, continues
        return token[1:].rstrip(',').strip(), False


def _parse_value_token(value_token: str, line_number: int, key: str) -> tuple[str, bool]:
    """解析值片段，回傳 (解析後的值, 是否有 .. 續行)。"""
    token = value_token.strip()
    if not token:
        return "", False

    if token.startswith('"'):
        inner, continues = _extract_quoted_segment(token)
        return inner, continues

    _warn_missing_quotes(line_number, key)
    return token.rstrip(",").strip(), False

def _parse_assignment_line(line: str, line_number: int) -> tuple[str, str, bool] | None:
    """解析 key = value 行，回傳 (key, value, continues)。"""
    sep = line.find("=")
    if sep == -1:
        return None

    key = line[:sep].strip()
    if not key:
        return None

    value_token = line[sep + 1 :].strip()
    value, continues = _parse_value_token(value_token, line_number, key)
    return key, value, continues


def detect_category(filename: str) -> str:
    name = Path(filename).name
    if name.lower().endswith(".txt"):
        name = name[:-4]

    if name.endswith("_CH") or name.endswith("_CN"):
        return name[:-3]

    return name


def _extract_continuation_value(line: str) -> tuple[str, bool]:
    """從 Lua .. 續行中提取引號內的字串內容。"""
    token = line.strip()
    if not token.startswith('"'):
        return "", False
    return _extract_quoted_segment(token)


def parse_lua_translation(content: str, category: str) -> OrderedDict[str, str]:
    lines = content.splitlines()
    parsed: OrderedDict[str, str] = OrderedDict()

    if not lines:
        return parsed

    end = len(lines)
    while end > 1 and not lines[end - 1].strip():
        end -= 1
    if end > 1 and lines[end - 1].strip() == "}":
        end -= 1

    prefix = f"{category}_" if category in PREFIX_STRIP_CATEGORIES else ""

    idx = 1  # 從第 2 行開始（跳過表頭），使用 0-based index
    while idx < end:
        raw_line = lines[idx]
        line_number = idx + 1  # 1-based 行號
        stripped = raw_line.strip()
        idx += 1

        if not stripped:
            continue
        if stripped == "-- Additional Translation --":
            continue
        if stripped.startswith("--"):
            continue

        parsed_line = _parse_assignment_line(stripped, line_number)
        if parsed_line is None:
            continue

        key, value, continues = parsed_line

        # 處理 Lua .. 多行字串串接
        while continues and idx < end:
            cont_line = lines[idx].strip()
            idx += 1
            if not cont_line:
                continue
            part, continues = _extract_continuation_value(cont_line)
            value += part

        if prefix and key.startswith(prefix):
            key = key[len(prefix):]
        parsed[key] = value

    return parsed


def parse_recorded_media(content: str) -> OrderedDict[str, str]:
    parsed: OrderedDict[str, str] = OrderedDict()

    for line_number, raw_line in enumerate(content.splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped:
            continue
        if stripped.startswith("//"):
            continue

        parsed_line = _parse_assignment_line(stripped, line_number)
        if parsed_line is None:
            continue

        key, value, _continues = parsed_line
        parsed[key] = value

    return parsed


def parse_city_directory(dir_path: Path) -> OrderedDict[str, str]:
    title = (dir_path / "title.txt").read_text(encoding="utf-8").rstrip()
    description = (dir_path / "description.txt").read_text(encoding="utf-8").rstrip()

    return OrderedDict([
        ("title", title),
        ("description", description),
    ])


def read_translation(path: Path) -> OrderedDict[str, str]:
    if path.is_dir():
        return parse_city_directory(path)

    if path.suffix.lower() == ".json":
        text = path.read_text(encoding="utf-8")
        return cast(OrderedDict[str, str], json.loads(text, object_pairs_hook=OrderedDict))

    text = path.read_text(encoding="utf-8")

    if path.name.startswith("Recorded_Media") and path.suffix.lower() == ".txt":
        return parse_recorded_media(text)

    category = detect_category(path.name)
    return parse_lua_translation(text, category)


def write_translation_json(data: OrderedDict[str, str], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, indent=4) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")


def txt_to_json_filename(txt_name: str) -> str:
    if txt_name in SKIP_FILES:
        return txt_name

    if not txt_name.lower().endswith(".txt"):
        return txt_name

    stem = txt_name[:-4]
    if stem.endswith("_CH") or stem.endswith("_CN"):
        stem = stem[:-3]

    return f"{stem}.json"
