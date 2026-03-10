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


def _parse_value_token(value_token: str, line_number: int, key: str) -> str:
    token = value_token.strip()
    if not token:
        return ""

    if token.startswith('"'):
        quote_index = _find_unescaped_quote(token)
        if quote_index != -1:
            quoted = token[1:quote_index]
            return _unescape_lua_string(quoted)

        _warn_missing_quotes(line_number, key)
        token = token[1:]
        return token.rstrip(",").strip()

    _warn_missing_quotes(line_number, key)
    return token.rstrip(",").strip()


def _parse_assignment_line(line: str, line_number: int) -> tuple[str, str] | None:
    sep = line.find("=")
    if sep == -1:
        return None

    key = line[:sep].strip()
    if not key:
        return None

    value_token = line[sep + 1 :].strip()
    value = _parse_value_token(value_token, line_number, key)
    return key, value


def detect_category(filename: str) -> str:
    name = Path(filename).name
    if name.lower().endswith(".txt"):
        name = name[:-4]

    if name.endswith("_CH") or name.endswith("_CN"):
        return name[:-3]

    return name


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

    for line_number in range(2, end + 1):
        raw_line = lines[line_number - 1]
        stripped = raw_line.strip()

        if not stripped:
            continue
        if stripped == "-- Additional Translation --":
            continue
        if stripped.startswith("--"):
            continue

        parsed_line = _parse_assignment_line(stripped, line_number)
        if parsed_line is None:
            continue

        key, value = parsed_line
        if prefix and key.startswith(prefix):
            key = key[len(prefix) :]
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

        key, value = parsed_line
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
