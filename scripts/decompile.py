# /// script
# dependencies = []
# requires-python = ">=3.10"
# ///
"""
PZ 本體 Java 反編譯管線（Vineflower + Python wrapper）

用途：定期反編譯 Project Zomboid 本體 jar，協助 MOD 開發時查詢 Java 層方法、
      找出硬編碼英文字串（如 setName / setDisplayName），再以 _Flx.lua 事件式修補。

使用方式：uv run scripts/decompile.py [命令]

命令：
  setup              - 首次：下載 vineflower.jar 並建立產物目錄
  build --version X  - 反編譯 PZ 本體到 snapshots/X-YYYYMMDD/
  status             - 列出所有快照
  verify X           - 用 VehicleKey 錨點 smoke test 驗證快照可用
  clean X            - 移除指定版本的快照
  where              - 顯示產物根目錄絕對路徑

產物結構：
  ../pz-decompiled-reference/            （專案同層，沿用 translation-reference 模式）
    tools/vineflower-{version}.jar
    snapshots/{pz_build}-{YYYYMMDD}/
      VERSION.txt
      pz/**/*.java

環境變數：
  PZ_PATH             PZ 安裝路徑（預設 D:\\SteamLibrary\\steamapps\\common\\ProjectZomboid）
  DECOMPILE_ROOT      產物根目錄（預設 ../pz-decompiled-reference/）
"""
from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# ============================================================
# 設定
# ============================================================
PROJECT_ROOT = Path(__file__).resolve().parent.parent

PZ_PATH = Path(
    os.environ.get("PZ_PATH")
    or r"D:\SteamLibrary\steamapps\common\ProjectZomboid"
)

VINEFLOWER_VERSION = "1.11.1"
VINEFLOWER_URL = (
    f"https://github.com/Vineflower/vineflower/releases/download/"
    f"{VINEFLOWER_VERSION}/vineflower-{VINEFLOWER_VERSION}.jar"
)

# ============================================================
# 顏色輸出（Windows Terminal / modern terminals）
# ============================================================
_COLORS = {
    "red": "\033[31m",
    "green": "\033[32m",
    "yellow": "\033[33m",
    "cyan": "\033[36m",
    "gray": "\033[90m",
    "reset": "\033[0m",
}


def log(msg: str, *, tag: str = "INFO", color: str | None = None) -> None:
    prefix = f"[{tag}]"
    if color and color in _COLORS:
        print(f"{_COLORS[color]}{prefix} {msg}{_COLORS['reset']}")
    else:
        print(f"{prefix} {msg}")


# ============================================================
# 路徑推算
# ============================================================
def get_decompile_root() -> Path:
    """產物根目錄（預設專案同層 ../pz-decompiled-reference/）"""
    override = os.environ.get("DECOMPILE_ROOT")
    if override:
        return Path(override).resolve()
    return (PROJECT_ROOT.parent / "pz-decompiled-reference").resolve()


def vineflower_jar() -> Path:
    return get_decompile_root() / "tools" / f"vineflower-{VINEFLOWER_VERSION}.jar"


def find_pz_jar() -> Path:
    """找 PZ 本體 jar（projectzomboid.jar）"""
    for name in ("projectzomboid.jar", "ProjectZomboid.jar"):
        candidate = PZ_PATH / name
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"找不到 projectzomboid.jar 於 {PZ_PATH}")


def find_java_executable() -> Path:
    """優先用 PZ 自帶 jre64/bin/java.exe，fallback 到 PATH"""
    bundled = PZ_PATH / "jre64" / "bin" / "java.exe"
    if bundled.exists():
        return bundled
    for exe in ("java.exe", "java"):
        found = shutil.which(exe)
        if found:
            return Path(found)
    raise FileNotFoundError(
        f"找不到 java 執行檔（預期在 {bundled} 或 PATH 中）"
    )


def file_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def grep_count(root: Path, pattern: str) -> int:
    regex = re.compile(pattern)
    count = 0
    for f in root.rglob("*.java"):
        try:
            count += len(regex.findall(f.read_text(encoding="utf-8", errors="ignore")))
        except OSError:
            pass
    return count


# ============================================================
# 子命令：setup
# ============================================================
def cmd_setup(_args: argparse.Namespace) -> int:
    del _args
    root = get_decompile_root()
    log(f"產物根目錄：{root}", tag="SETUP", color="cyan")

    (root / "tools").mkdir(parents=True, exist_ok=True)
    (root / "snapshots").mkdir(parents=True, exist_ok=True)

    jar = vineflower_jar()
    if jar.exists():
        log(f"vineflower 已存在：{jar.name}", tag="SETUP", color="green")
    else:
        log(f"下載 {VINEFLOWER_URL}", tag="SETUP", color="cyan")
        try:
            urllib.request.urlretrieve(VINEFLOWER_URL, jar)
            log(f"已下載 → {jar}", tag="OK", color="green")
        except Exception as exc:
            log(f"下載失敗：{exc}", tag="ERROR", color="red")
            log(f"請手動下載：{VINEFLOWER_URL}", tag="HINT", color="yellow")
            log(f"並放到：{jar}", tag="HINT", color="yellow")
            return 1

    try:
        java = find_java_executable()
        log(f"Java：{java}", tag="SETUP", color="green")
    except FileNotFoundError as exc:
        log(str(exc), tag="ERROR", color="red")
        return 1

    readme = root / "README.md"
    if not readme.exists():
        readme.write_text(
            "# pz-decompiled-reference\n\n"
            "Project Zomboid 本體反編譯產物參考倉庫。\n\n"
            "由 `MinidoracatLangFor42/scripts/decompile.py` 自動管理。\n\n"
            "## 結構\n\n"
            "- `tools/vineflower-*.jar` — 反編譯器\n"
            "- `snapshots/{pz_build}-{YYYYMMDD}/pz/` — 反編譯產物\n"
            "- `snapshots/{pz_build}-{YYYYMMDD}/VERSION.txt` — 快照元資料\n\n"
            "## 用途\n\n"
            "本機閱讀、grep 硬編碼字串、輔助 MOD 開發。\n",
            encoding="utf-8",
        )
        log("建立 README.md", tag="SETUP", color="green")

    gitignore = root / ".gitignore"
    if not gitignore.exists():
        gitignore.write_text(
            "# 反編譯產物不進 git tracking\n*\n!.gitignore\n!README.md\n",
            encoding="utf-8",
        )

    log("Setup 完成", tag="OK", color="green")
    log("下一步：uv run scripts/decompile.py build --version 42.16.1", tag="HINT", color="yellow")
    return 0


# ============================================================
# 子命令：build
# ============================================================
def cmd_build(args: argparse.Namespace) -> int:
    version: str = args.version

    jar = vineflower_jar()
    if not jar.exists():
        log("vineflower.jar 未安裝，請先執行 setup", tag="ERROR", color="red")
        return 1

    try:
        pz_jar = find_pz_jar()
        java = find_java_executable()
    except FileNotFoundError as exc:
        log(str(exc), tag="ERROR", color="red")
        return 1

    date = datetime.now().strftime("%Y%m%d")
    snapshot_dir = get_decompile_root() / "snapshots" / f"{version}-{date}"
    output_dir = snapshot_dir / "pz"

    if output_dir.exists() and not args.force:
        log(f"快照已存在：{snapshot_dir}", tag="SKIP", color="yellow")
        log("加上 --force 強制重跑", tag="HINT", color="yellow")
        return 0

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    log(f"計算 {pz_jar.name} sha256 ...", tag="BUILD", color="cyan")
    pz_jar_sha = file_sha256(pz_jar)

    log(f"反編譯 → {output_dir}", tag="BUILD", color="cyan")
    log("（首次約 5-15 分鐘，視 CPU 速度）", tag="BUILD", color="gray")

    cmd = [
        str(java),
        "-jar",
        str(jar),
        "--synthetic-not-set=true",
        "--verify-variable-merges=true",
        "--decompile-generics=true",
        str(pz_jar),
        str(output_dir),
    ]

    try:
        result = subprocess.run(cmd, check=False)
    except KeyboardInterrupt:
        log("使用者中斷", tag="ABORT", color="yellow")
        return 130

    if result.returncode != 0:
        log(f"vineflower 返回錯誤碼 {result.returncode}", tag="ERROR", color="red")
        return 1

    java_files = list(output_dir.rglob("*.java"))
    file_count = len(java_files)

    version_file = snapshot_dir / "VERSION.txt"
    version_file.write_text(
        (
            "# Decompilation Snapshot Metadata\n"
            f"pz_build={version}\n"
            f"pz_jar_sha256={pz_jar_sha}\n"
            f"pz_jar_path={pz_jar}\n"
            f"decompile_date={datetime.now(timezone.utc).astimezone().isoformat()}\n"
            "tool=vineflower\n"
            f"tool_version={VINEFLOWER_VERSION}\n"
            f"file_count={file_count}\n"
        ),
        encoding="utf-8",
    )

    log(f"完成：{file_count} 個 .java 檔", tag="OK", color="green")
    log(f"位置：{snapshot_dir}", tag="OK", color="green")
    log(f"建議驗證：uv run scripts/decompile.py verify {version}", tag="HINT", color="yellow")
    return 0


# ============================================================
# 子命令：status
# ============================================================
def cmd_status(_args: argparse.Namespace) -> int:
    del _args
    root = get_decompile_root()
    log(f"產物根目錄：{root}", tag="STATUS", color="cyan")

    snapshots_dir = root / "snapshots"
    if not snapshots_dir.exists():
        log("尚無快照（先跑 setup 再 build）", tag="EMPTY", color="gray")
        return 0

    snapshots = sorted(p for p in snapshots_dir.iterdir() if p.is_dir())
    if not snapshots:
        log("尚無快照（先跑 build）", tag="EMPTY", color="gray")
        return 0

    for snap in snapshots:
        version_file = snap / "VERSION.txt"
        if version_file.exists():
            meta: dict[str, str] = {}
            for line in version_file.read_text(encoding="utf-8").splitlines():
                if "=" in line and not line.lstrip().startswith("#"):
                    key, value = line.split("=", 1)
                    meta[key.strip()] = value.strip()
            log(
                f"{snap.name}  build={meta.get('pz_build', '?')}  "
                f"files={meta.get('file_count', '?')}",
                tag="SNAP",
                color="green",
            )
        else:
            log(f"{snap.name}  (無 VERSION.txt，可能未完成)", tag="WARN", color="yellow")
    return 0


# ============================================================
# 子命令：verify（VehicleKey smoke test）
# ============================================================
def cmd_verify(args: argparse.Namespace) -> int:
    version: str = args.version
    snapshots_dir = get_decompile_root() / "snapshots"
    matching = sorted(snapshots_dir.glob(f"{version}-*"))
    if not matching:
        log(f"找不到 {version} 的快照（先跑 build）", tag="ERROR", color="red")
        return 1

    snapshot = matching[-1]
    pz_src = snapshot / "pz"
    if not pz_src.exists():
        log(f"{pz_src} 不存在", tag="ERROR", color="red")
        return 1

    log(f"驗證快照：{snapshot.name}", tag="VERIFY", color="cyan")

    hits_method = grep_count(pz_src, r"keyNamerVehicle")
    if hits_method < 1:
        log("FAIL: keyNamerVehicle 方法未命中（反編譯可能不完整）", tag="ERROR", color="red")
        return 2
    log(f"keyNamerVehicle 命中 {hits_method} 處", tag="PASS", color="green")

    hits_old = grep_count(pz_src, r'"Vehicle Key')
    hits_new = grep_count(pz_src, r'"IGUI_VehicleName"')
    if hits_old < 1 and hits_new < 1:
        log('FAIL: 舊版 "Vehicle Key" 或新版 "IGUI_VehicleName" 字串皆未命中', tag="ERROR", color="red")
        return 3
    if hits_old > 0:
        log(f'舊版 "Vehicle Key" 硬編碼命中 {hits_old} 處（42.16.1 以下 pattern）', tag="PASS", color="green")
    if hits_new > 0:
        log(f'新版 "IGUI_VehicleName" 翻譯鍵命中 {hits_new} 處（42.17.0+ pattern）', tag="PASS", color="green")

    log("Smoke test 通過，快照可用", tag="OK", color="green")
    return 0


# ============================================================
# 子命令：clean
# ============================================================
def cmd_clean(args: argparse.Namespace) -> int:
    version: str = args.version
    snapshots_dir = get_decompile_root() / "snapshots"
    matching = [p for p in snapshots_dir.glob(f"{version}-*") if p.is_dir()]
    if not matching:
        log(f"找不到 {version} 的快照", tag="EMPTY", color="gray")
        return 0

    for snap in matching:
        log(f"移除：{snap}", tag="CLEAN", color="yellow")
        shutil.rmtree(snap)
    log(f"已移除 {len(matching)} 個快照", tag="OK", color="green")
    return 0


# ============================================================
# 子命令：where
# ============================================================
def cmd_where(_args: argparse.Namespace) -> int:
    del _args
    print(get_decompile_root())
    return 0


# ============================================================
# Main
# ============================================================
def main() -> int:
    parser = argparse.ArgumentParser(
        prog="decompile.py",
        description="PZ Build 42 Java 反編譯管線（Vineflower + Python wrapper）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_setup = sub.add_parser("setup", help="下載 vineflower.jar 並建立產物目錄")
    p_setup.set_defaults(func=cmd_setup)

    p_build = sub.add_parser("build", help="反編譯 PZ 本體")
    p_build.add_argument("--version", required=True, help="PZ build 版本（如 42.16.1）")
    p_build.add_argument("--force", action="store_true", help="強制重跑已存在的快照")
    p_build.set_defaults(func=cmd_build)

    p_status = sub.add_parser("status", help="列出所有快照")
    p_status.set_defaults(func=cmd_status)

    p_verify = sub.add_parser("verify", help="VehicleKey smoke test")
    p_verify.add_argument("version", help="PZ build 版本")
    p_verify.set_defaults(func=cmd_verify)

    p_clean = sub.add_parser("clean", help="移除指定版本快照")
    p_clean.add_argument("version", help="PZ build 版本")
    p_clean.set_defaults(func=cmd_clean)

    p_where = sub.add_parser("where", help="顯示產物根目錄絕對路徑")
    p_where.set_defaults(func=cmd_where)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
