# === Ruta destino de tus dotfiles (puedes cambiarla) ===
$BackupRoot = Join-Path $HOME "dotfiles"
$null = New-Item -ItemType Directory -Force -Path $BackupRoot

# 1) Perfiles de PowerShell (Store/PowerShell 7 y consola)
$profilesToCopy = @(
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.CurrentUserCurrentHost
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$pwshDir = Join-Path $BackupRoot "PowerShell"
$null = New-Item -ItemType Directory -Force -Path $pwshDir
foreach ($p in $profilesToCopy) {
    Copy-Item $p -Destination $pwshDir -Force
}

# 2) Settings de Windows Terminal
$wtPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"  # instalación MSIX no-tienda
) | Where-Object { Test-Path $_ }

if ($wtPaths) {
    $wtDir = Join-Path $BackupRoot "WindowsTerminal"
    $null = New-Item -ItemType Directory -Force -Path $wtDir
    foreach ($w in $wtPaths) { Copy-Item $w -Destination $wtDir -Force }
}

# 3) Lista de módulos (PowerShellGet) que tienes instalados explícitamente
try {
    Get-InstalledModule | Select-Object Name,Version,Repository |
        Export-Csv (Join-Path $BackupRoot "modules.csv") -NoTypeInformation -Encoding UTF8
} catch { }

# 4) Export de apps (winget)
try {
    winget export -o (Join-Path $BackupRoot "winget.json") --include-versions | Out-Null
} catch { }

# 5) Oh-My-Posh: intenta guardar tu config/tema
$ompDir = $null
# Rutas típicas de OMP
$ompCandidates = @(
    "$env:LOCALAPPDATA\Programs\oh-my-posh",
    "$env:LOCALAPPDATA\oh-my-posh"
) | Where-Object { Test-Path $_ }
if ($ompCandidates) {
    $ompDir = Join-Path $BackupRoot "oh-my-posh"
    Copy-Item $ompCandidates[0] -Destination $ompDir -Recurse -Force
}

# 6) Anota la fuente Nerd Font activa (si la declaraste en tu perfil)
$fontNote = Join-Path $BackupRoot "nerd-font.txt"
$fontName = $null
if (Test-Path $PROFILE.CurrentUserAllHosts) {
    $fontName = (Get-Content $PROFILE.CurrentUserAllHosts) -match 'Nerd|Fira|Cascadia|JetBrains'
    Set-Content -Path $fontNote -Value ($fontName -join "`r`n")
}

"Backup listo en: $BackupRoot"
