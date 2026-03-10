# MinidoracatLangFor42 Workshop 符號連結管理
# 用途：將開發目錄連結到 Zomboid Workshop 目錄，方便本地測試和 Workshop 上傳

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
$WorkshopDir = Join-Path $env:UserProfile "Zomboid\Workshop"
$LinkTarget = Join-Path $WorkshopDir "MinidoracatLangFor42"

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
    Write-Host "=== Workshop 目錄 ===" -ForegroundColor Cyan
    Write-Host "路徑: $WorkshopDir"
    if (Test-Path $WorkshopDir) {
        Write-Host "  [OK] 目錄存在" -ForegroundColor Green
    } else {
        Write-Host "  [--] 目錄不存在（掛載時會自動建立）" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "=== 連結狀態 ===" -ForegroundColor Cyan
    if (-not (Test-Path $LinkTarget)) {
        Write-Host "  [未掛載] 連結不存在" -ForegroundColor DarkGray
    } elseif (Test-IsSymlink $LinkTarget) {
        $target = (Get-Item $LinkTarget -Force).Target
        Write-Host "  [已掛載] $LinkTarget" -ForegroundColor Green
        Write-Host "           -> $target" -ForegroundColor Green
    } else {
        Write-Host "  [注意] $LinkTarget 存在但為實體資料夾" -ForegroundColor Yellow
    }
    Write-Host ""
}

function Mount-Workshop {
    Write-Host ""

    # 檢查是否已存在
    if (Test-Path $LinkTarget) {
        if (Test-IsSymlink $LinkTarget) {
            $target = (Get-Item $LinkTarget -Force).Target
            Write-Host "[已掛載] 符號連結已存在:" -ForegroundColor Green
            Write-Host "  $LinkTarget" -ForegroundColor Green
            Write-Host "  -> $target" -ForegroundColor Green
            Write-Host ""
            return
        }
        Write-Host "[警告] 目標位置已存在實體資料夾:" -ForegroundColor Yellow
        Write-Host "  $LinkTarget" -ForegroundColor Yellow
        Write-Host "請手動處理後再試。"
        Write-Host ""
        return
    }

    # 確保 Workshop 目錄存在
    if (-not (Test-Path $WorkshopDir)) {
        New-Item -ItemType Directory -Path $WorkshopDir -Force | Out-Null
        Write-Host "[建立] Workshop 目錄: $WorkshopDir" -ForegroundColor Cyan
    }

    # 嘗試建立符號連結（不需管理員——開發者模式或已有權限）
    try {
        New-Item -ItemType SymbolicLink -Path $LinkTarget -Target $ModSource -ErrorAction Stop | Out-Null
        Write-Host "[成功] 符號連結已建立！" -ForegroundColor Green
        Write-Host ""
        Write-Host "  $LinkTarget"
        Write-Host "  -> $ModSource"
        Write-Host ""
        Write-Host "現在可以在 PZ 遊戲中看到此 MOD 並進行本地測試。" -ForegroundColor Cyan
        Write-Host "也可以透過遊戲內建 Workshop 工具直接上傳。" -ForegroundColor Cyan
    } catch {
        # 權限不足，自動透過 UAC 提升執行
        Write-Host "[提示] 需要管理員權限，正在請求提升..." -ForegroundColor Yellow
        try {
            Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-Command",
                "New-Item -ItemType SymbolicLink -Path '$LinkTarget' -Target '$ModSource' -ErrorAction Stop | Out-Null"
            )
            # 驗證是否成功
            if (Test-IsSymlink $LinkTarget) {
                Write-Host "[成功] 符號連結已建立！" -ForegroundColor Green
                Write-Host ""
                Write-Host "  $LinkTarget"
                Write-Host "  -> $ModSource"
                Write-Host ""
                Write-Host "現在可以在 PZ 遊戲中看到此 MOD 並進行本地測試。" -ForegroundColor Cyan
            } else {
                Write-Host "[失敗] UAC 已取消或建立失敗。" -ForegroundColor Red
            }
        } catch {
            Write-Host "[失敗] 無法建立符號連結。" -ForegroundColor Red
            Write-Host ""
            Write-Host "替代方案：啟用 Windows 開發人員模式後即可免管理員建立連結：" -ForegroundColor Yellow
            Write-Host "  設定 -> 系統 -> 開發人員專用 -> 開發人員模式" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "錯誤訊息: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

function Dismount-Workshop {
    Write-Host ""

    if (-not (Test-Path $LinkTarget)) {
        Write-Host "[提示] 連結不存在: $LinkTarget" -ForegroundColor DarkGray
        Write-Host "目前未掛載。"
        Write-Host ""
        return
    }

    if (-not (Test-IsSymlink $LinkTarget)) {
        Write-Host "[警告] $LinkTarget 不是符號連結，為安全起見不會刪除。" -ForegroundColor Yellow
        Write-Host "如需移除請手動處理。"
        Write-Host ""
        return
    }

    # 嘗試移除
    try {
        (Get-Item $LinkTarget -Force).Delete()
        Write-Host "[成功] 符號連結已移除。" -ForegroundColor Green
    } catch {
        # 權限不足，自動提升
        Write-Host "[提示] 需要管理員權限，正在請求提升..." -ForegroundColor Yellow
        try {
            Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-Command",
                "(Get-Item '$LinkTarget' -Force).Delete()"
            )
            if (-not (Test-Path $LinkTarget)) {
                Write-Host "[成功] 符號連結已移除。" -ForegroundColor Green
            } else {
                Write-Host "[失敗] UAC 已取消或移除失敗。" -ForegroundColor Red
            }
        } catch {
            Write-Host "[失敗] 無法移除符號連結。" -ForegroundColor Red
            Write-Host "錯誤訊息: $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

# ============================================
# 主選單
# ============================================
$Host.UI.RawUI.WindowTitle = "MinidoracatLangFor42 Workshop 連結管理"

while ($true) {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  MinidoracatLangFor42 Workshop 連結管理" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  來源: $ModSource"
    Write-Host "  目標: $LinkTarget"
    Write-Host ""
    Write-Host "  [1] 掛載 - 建立 Workshop 符號連結"
    Write-Host "  [2] 卸載 - 移除 Workshop 符號連結"
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
