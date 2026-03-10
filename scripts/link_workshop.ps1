# MinidoracatLangFor42 Workshop 符號連結管理
# 用途：將開發目錄連結到 Zomboid Workshop 和 mods 目錄，方便本地測試和 Workshop 上傳

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================
# 路徑偵測（支援 bat 啟動器和直接執行兩種模式）
# ============================================
if ($env:PROJECT_ROOT) {
    # 從 bat 啟動器呼叫，使用傳入的專案根目錄
    $ProjectRoot = $env:PROJECT_ROOT.TrimEnd('\\')
} elseif ($PSScriptRoot) {
    # 直接執行 ps1，使用腳本所在目錄推算
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
} else {
    # Fallback：使用目前工作目錄
    $ProjectRoot = (Get-Location).Path
}
$ModSource = Join-Path $ProjectRoot "MOD\MinidoracatLangFor42"
$ModContent = Join-Path $ModSource "Contents\mods\MinidoracatLangFor42"

# Workshop 符號連結（用於上傳）
$WorkshopDir = Join-Path $env:UserProfile "Zomboid\Workshop"
$WorkshopLink = Join-Path $WorkshopDir "MinidoracatLangFor42"

# Mods 符號連結（用於遊戲載入，PZ 優先從此處讀取）
$ModsDir = Join-Path $env:UserProfile "Zomboid\mods"
$ModsLink = Join-Path $ModsDir "CatLangFor42"

# 驗證 MOD 來源目錄
if (-not (Test-Path (Join-Path $ModSource "workshop.txt"))) {
    Write-Host ""
    Write-Host "[錯誤] 找不到 MOD 來源目錄:" -ForegroundColor Red
    Write-Host "  $ModSource" -ForegroundColor Red
    Write-Host ""
    Write-Host "請確認此腳本位於專案的 scripts/ 目錄下。"
    Read-Host "按 Enter 結束"
    exit 1
}

# ============================================
# 功能函式
# ============================================

function Test-IsSymlink {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
    return ($null -ne $item.LinkType)
}

function Show-Status {
    Write-Host ""
    Write-Host "=== MOD 來源 ===" -ForegroundColor Cyan
    Write-Host "路徑: $ModSource"

    $checks = @(
        @{ File = "workshop.txt"; Desc = "workshop.txt" }
        @{ File = "preview.png";  Desc = "preview.png" }
        @{ File = "Contents";     Desc = "Contents/" }
    )
    foreach ($c in $checks) {
        $p = Join-Path $ModSource $c.File
        if (Test-Path $p) {
            Write-Host "  [OK] $($c.Desc)" -ForegroundColor Green
        } else {
            Write-Host "  [缺少] $($c.Desc)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "=== 連結狀態 ===" -ForegroundColor Cyan

    # Workshop 連結
    Write-Host "  [Workshop] " -NoNewline
    if (-not (Test-Path $WorkshopLink)) {
        Write-Host "未掛載" -ForegroundColor DarkGray
    } elseif (Test-IsSymlink $WorkshopLink) {
        $target = (Get-Item $WorkshopLink -Force).Target
        Write-Host "已掛載 -> $target" -ForegroundColor Green
    } else {
        Write-Host "實體資料夾（非符號連結）" -ForegroundColor Yellow
    }

    # Mods 連結
    Write-Host "  [Mods]     " -NoNewline
    if (-not (Test-Path $ModsLink)) {
        Write-Host "未掛載" -ForegroundColor DarkGray
    } elseif (Test-IsSymlink $ModsLink) {
        $target = (Get-Item $ModsLink -Force).Target
        Write-Host "已掛載 -> $target" -ForegroundColor Green
    } else {
        Write-Host "實體資料夾（Steam 快取？）" -ForegroundColor Yellow
    }
    Write-Host ""
}

function New-SymlinkSafe {
    param([string]$LinkPath, [string]$Target, [string]$Label)

    if (Test-Path $LinkPath) {
        if (Test-IsSymlink $LinkPath) {
            $existing = (Get-Item $LinkPath -Force).Target
            Write-Host "  [$Label] 已掛載 -> $existing" -ForegroundColor Green
            return
        }
        # 實體資料夾（可能是 Steam 快取）—— 自動重新命名
        $bakPath = "$LinkPath.bak"
        if (Test-Path $bakPath) {
            Remove-Item $bakPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        Rename-Item $LinkPath $bakPath -Force
        Write-Host "  [$Label] 已將舊資料夾重新命名為 .bak" -ForegroundColor Yellow
    }

    # 確保父目錄存在
    $parentDir = Split-Path -Parent $LinkPath
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # 嘗試建立符號連結
    try {
        New-Item -ItemType SymbolicLink -Path $LinkPath -Target $Target -ErrorAction Stop | Out-Null
        Write-Host "  [$Label] 建立成功" -ForegroundColor Green
        Write-Host "           $LinkPath" -ForegroundColor DarkGray
        Write-Host "           -> $Target" -ForegroundColor DarkGray
        return $true
    } catch {
        return $false
    }
}

function New-SymlinkElevated {
    param([string]$LinkPath, [string]$Target, [string]$Label)
    try {
        Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            "New-Item -ItemType SymbolicLink -Path '$LinkPath' -Target '$Target' -ErrorAction Stop | Out-Null"
        )
        if (Test-IsSymlink $LinkPath) {
            Write-Host "  [$Label] 建立成功（UAC）" -ForegroundColor Green
            return $true
        }
    } catch {}
    Write-Host "  [$Label] 建立失敗" -ForegroundColor Red
    return $false
}

function Mount-Workshop {
    Write-Host ""
    Write-Host "正在建立符號連結..." -ForegroundColor Cyan
    Write-Host ""

    # 嘗試不需提權建立兩個連結
    $ws = New-SymlinkSafe -LinkPath $WorkshopLink -Target $ModSource -Label "Workshop"
    $md = New-SymlinkSafe -LinkPath $ModsLink -Target $ModContent -Label "Mods"

    # 如果任一個失敗，嘗試 UAC 提權
    $needElevate = @()
    if ($ws -eq $false) { $needElevate += @{ Link=$WorkshopLink; Target=$ModSource; Label="Workshop" } }
    if ($md -eq $false) { $needElevate += @{ Link=$ModsLink; Target=$ModContent; Label="Mods" } }

    if ($needElevate.Count -gt 0) {
        Write-Host ""
        Write-Host "[提示] 需要管理員權限，正在請求提升..." -ForegroundColor Yellow
        foreach ($item in $needElevate) {
            New-SymlinkElevated -LinkPath $item.Link -Target $item.Target -Label $item.Label
        }
    }

    Write-Host ""
    if ((Test-IsSymlink $WorkshopLink) -and (Test-IsSymlink $ModsLink)) {
        Write-Host "[全部完成] 現在可以在 PZ 遊戲中測試此 MOD。" -ForegroundColor Green
    } else {
        Write-Host "[部分完成] 請檢查上方狀態。" -ForegroundColor Yellow
        Write-Host "替代方案：啟用 Windows 開發人員模式後即可免管理員建立連結：" -ForegroundColor Yellow
        Write-Host "  設定 -> 系統 -> 開發人員專用 -> 開發人員模式" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Remove-SymlinkSafe {
    param([string]$LinkPath, [string]$Label)

    if (-not (Test-Path $LinkPath)) {
        Write-Host "  [$Label] 不存在，跳過" -ForegroundColor DarkGray
        return
    }

    if (-not (Test-IsSymlink $LinkPath)) {
        Write-Host "  [$Label] 是實體資料夾，跳過（請手動處理）" -ForegroundColor Yellow
        return
    }

    try {
        (Get-Item $LinkPath -Force).Delete()
        Write-Host "  [$Label] 已移除" -ForegroundColor Green
    } catch {
        Write-Host "  [$Label] 需要提權移除..." -ForegroundColor Yellow
        try {
            Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-Command",
                "(Get-Item '$LinkPath' -Force).Delete()"
            )
            if (-not (Test-Path $LinkPath)) {
                Write-Host "  [$Label] 已移除（UAC）" -ForegroundColor Green
            } else {
                Write-Host "  [$Label] 移除失敗" -ForegroundColor Red
            }
        } catch {
            Write-Host "  [$Label] 移除失敗: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Dismount-Workshop {
    Write-Host ""
    Write-Host "正在移除符號連結..." -ForegroundColor Cyan
    Write-Host ""
    Remove-SymlinkSafe -LinkPath $WorkshopLink -Label "Workshop"
    Remove-SymlinkSafe -LinkPath $ModsLink -Label "Mods"
    Write-Host ""
}

# ============================================
# 主選單
# ============================================
$Host.UI.RawUI.WindowTitle = "MinidoracatLangFor42 Workshop 連結管理"

while ($true) {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  MinidoracatLangFor42 符號連結管理" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Workshop: $WorkshopLink"
    Write-Host "  Mods:     $ModsLink"
    Write-Host ""
    Write-Host "  [1] 掛載 - 建立符號連結（Workshop + Mods）"
    Write-Host "  [2] 卸載 - 移除符號連結（Workshop + Mods）"
    Write-Host "  [3] 查看目前狀態"
    Write-Host ""
    Write-Host "  [Q] 離開"
    Write-Host ""
    $choice = Read-Host "請選擇"

    switch ($choice.ToUpper()) {
        "1" { Mount-Workshop; Read-Host "按 Enter 繼續" }
        "2" { Dismount-Workshop; Read-Host "按 Enter 繼續" }
        "3" { Show-Status; Read-Host "按 Enter 繼續" }
        "Q" { Write-Host ""; Write-Host "再見！"; exit 0 }
    }
}
