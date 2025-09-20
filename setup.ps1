# Permisos para el proceso
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# === Edita esta ruta si pusiste los dotfiles en otro lado ===
$BackupRoot = "$HOME\dotfiles"

# 1) Winget & apps (incluye PowerShell 7, Oh-My-Posh, etc. si estaban exportadas)
if (Test-Path (Join-Path $BackupRoot "winget.json")) {
    winget import -i (Join-Path $BackupRoot "winget.json") --accept-package-agreements --accept-source-agreements
}

# 2) Asegurar PowerShell 7 y Oh-My-Posh (por si no venían en winget.json)
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
winget install --id JanDeDobbeleer.OhMyPosh -e --accept-package-agreements --accept-source-agreements

# 3) Instalar una Nerd Font común (ajústalo a tu preferida si anotaste otra)
# Algunas opciones típicas (descomenta una):
# winget install --id NerdFonts.CaskaydiaCove -e
# winget install --id NerdFonts.FiraCode -e
# winget install --id NerdFonts.JetBrainsMono -e

# 4) Restaurar perfiles de PowerShell
$pwshDest = Join-Path $HOME "Documents\PowerShell"
$null = New-Item -ItemType Directory -Force -Path $pwshDest
$pwshSrc  = Join-Path $BackupRoot "PowerShell"
if (Test-Path $pwshSrc) { Copy-Item "$pwshSrc\*" -Destination $pwshDest -Force }

# 5) Restaurar Windows Terminal settings.json (si usas WT)
$wtSrc = Join-Path $BackupRoot "WindowsTerminal"
if (Test-Path $wtSrc) {
    $targets = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal"
    )
    foreach ($t in $targets) {
        if (Test-Path $t) {
            Copy-Item "$wtSrc\settings.json" -Destination (Join-Path $t "settings.json") -Force -ErrorAction SilentlyContinue
        }
    }
}

# 6) Restaurar Oh-My-Posh (si respaldaste su carpeta)
$ompSrc = Join-Path $BackupRoot "oh-my-posh"
if (Test-Path $ompSrc) {
    $ompDst = "$env:LOCALAPPDATA\Programs\oh-my-posh"
    $null = New-Item -ItemType Directory -Force -Path $ompDst
    Copy-Item $ompSrc\* $ompDst -Recurse -Force
}

# 7) Reinstalar módulos típicos para tu prompt (ajusta a tu gusto)
$modules = @(
    'PSReadLine',
    'Terminal-Icons',
    'z'               # o 'zoxide' si prefieres
)
foreach ($m in $modules) {
    try { Install-Module $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop } catch { }
}

Write-Host "`n🎉 Entorno restaurado. Abre una nueva ventana de PowerShell/Windows Terminal."
