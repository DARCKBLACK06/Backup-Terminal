# --- Prompt (oh-my-posh) ---
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\atomic.omp.json" | Invoke-Expression

# --- Iconos en ls (no romper si no está instalado) ---
Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue

# --- Hook de Conda para PowerShell (necesario para 'conda activate') ---
$CondaRoot = "C:\ProgramData\miniconda3"   # ⚠️ ajusta si lo tienes en otro sitio
$CondaHook = Join-Path $CondaRoot "shell\condabin\conda-hook.ps1"
$CondaMod  = Join-Path $CondaRoot "shell\condabin\Conda.psm1"
if (Test-Path $CondaHook) { & $CondaHook }
if (Test-Path $CondaMod)  { Import-Module $CondaMod -ErrorAction SilentlyContinue }

# ============================ OPTIMIZACIONES ============================
# Cache de IP pública (para no pedirla siempre)
$script:_PublicIPCache = $null
function Get-PublicIPv4 {
  if ($script:_PublicIPCache) { return $script:_PublicIPCache }
  try {
    $script:_PublicIPCache = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 1 -ErrorAction Stop).ToString().Trim()
  } catch { $script:_PublicIPCache = '—' }
  return $script:_PublicIPCache
}

# ======================= Caja del banner (ASCII puro) ==================
function Show-AsciiBox {
    param(
        [Parameter(Mandatory)][string]$Text,
        [int]$HPadding = 3, [int]$VPadding = 2,
        [int]$SideThickness = 2, [char]$BorderChar = '░',
        [ConsoleColor]$BorderColor = 'Cyan', [ConsoleColor]$TextColor = 'Cyan'
    )
    $lines   = $Text -split "`r?`n"
    $maxLine = ($lines | Measure-Object Length -Maximum).Maximum

    $termW   = $Host.UI.RawUI.WindowSize.Width
    if (-not $termW -or $termW -lt 20) { $termW = 120 }
    $safeW   = [Math]::Max(20, $termW - 1)

    $maxContentByTerm = $safeW - (2 * $SideThickness) - (2 * $HPadding)
    $contentW = [Math]::Min($maxLine, [Math]::Max(5, $maxContentByTerm))
    $innerW   = (2 * $HPadding) + $contentW
    $fullW    = (2 * $SideThickness) + $innerW
    $topBot   = ($BorderChar.ToString() * $fullW)

    $safeLines = $lines | ForEach-Object {
        if ($_.Length -gt $contentW) { $_.Substring(0, $contentW) } else { $_.PadRight($contentW) }
    }
    $blankInner = (" " * $innerW)

    Write-Host $topBot -ForegroundColor $BorderColor
    1..$VPadding | ForEach-Object {
        Write-Host ($BorderChar.ToString() * $SideThickness) -ForegroundColor $BorderColor -NoNewline
        Write-Host $blankInner -NoNewline
        Write-Host ($BorderChar.ToString() * $SideThickness) -ForegroundColor $BorderColor
    }
    foreach ($l in $safeLines) {
        Write-Host ($BorderChar.ToString() * $SideThickness) -ForegroundColor $BorderColor -NoNewline
        Write-Host ((" " * $HPadding) + $l + (" " * $HPadding)) -ForegroundColor $TextColor -NoNewline
        Write-Host ($BorderChar.ToString() * $SideThickness) -ForegroundColor $BorderColor
    }
    1..$VPadding | ForEach-Object {
        Write-Host ($BorderChar.ToString() * $SideThickness) -ForegroundColor $BorderColor -NoNewline
        Write-Host $blankInner -NoNewline
        Write-Host ($BorderChar.ToString() * $SideThickness) -ForegroundColor $BorderColor
    }
    Write-Host $topBot -ForegroundColor $BorderColor
}

# ============================ Helpers rápidos ==========================
function Get-WidthSafe {
  $w = $Host.UI.RawUI.WindowSize.Width
  if (-not $w -or $w -lt 40) { $w = 120 }
  [Math]::Max(40, $w - 1)
}

function Get-LocalIPv4 {
  try {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
      Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq 'Up' } |
      Select-Object -First 1
    if ($cfg -and $cfg.IPv4Address) { return $cfg.IPv4Address.IPAddress }
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
      Select-Object -First 1 -ExpandProperty IPAddress
    return ($ip ? $ip : '—')
  } catch { '—' }
}

function Get-NetworkKind {
  try {
    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
      Where-Object { $_.IPv4Address -and $_.NetAdapter.Status -eq 'Up' } |
      Select-Object -First 1
    if (-not $cfg) { return 'Disconnected' }
    $alias = $cfg.InterfaceAlias
    $kind  = if ($alias -match 'wi-?fi|wireless|wlan') { 'Wi-Fi' } else { 'Ethernet' }
    "$kind ($alias)"
  } catch { 'Unknown' }
}

function Get-GitSummary {
  try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
      $root = git rev-parse --show-toplevel 2>$null
      if ($LASTEXITCODE -ne 0 -or -not $root) { return $null }
      $branch = (git rev-parse --abbrev-ref HEAD).Trim()
      return @{ Branch = $branch; Root = $root }
      # Nota: no hacemos 'git status' aquí (es lento). Lo hacemos solo en modo completo.
    }
  } catch { }
  $null
}

function Get-GitStatusFast {
  # Llamar solo cuando quieras estado verdadero (puede ser costoso)
  try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
      git status --porcelain | Out-Null
      return (if ($LASTEXITCODE -eq 0 -and $LASTEXITCODE -ne $null -and ($?)) { if ($LASTEXITCODE -eq 0) { 'unknown' } else { 'unknown' } })
    }
  } catch { }
  '—'
}

function Get-CondaStatus {
  $exists = Get-Command conda -ErrorAction SilentlyContinue
  if (-not $exists) { return @{ State='Not found'; Env='—'; Python='—'; Path='—' } }
  $envName = $env:CONDA_DEFAULT_ENV
  $envPath = if ($env:CONDA_PREFIX) { $env:CONDA_PREFIX } else { '—' }
  $pyVer   = try { (& python --version) 2>&1 } catch { '—' }
  if ([string]::IsNullOrWhiteSpace($pyVer)) { $pyVer = '—' }
  if ($envName) { @{ State='Active';   Env=$envName; Python=$pyVer; Path=$envPath } }
  else          { @{ State='Inactive'; Env='—';     Python=$pyVer; Path=$envPath } }
}

# ====================== Dibujado dashboard alineado ====================
function Pad-Fixed([string]$s, [int]$w) {
  if ($null -eq $s) { $s = '' }
  if ($s.Length -gt $w) { return $s.Substring(0, [Math]::Max(0,$w)) }
  $s.PadRight($w)
}
function Draw-Row3 {
  param([string]$A,[string]$B,[string]$C,[int]$W1,[int]$W2,[int]$W3)
  "║ " + (Pad-Fixed $A $W1) + " │ " + (Pad-Fixed $B $W2) + " │ " + (Pad-Fixed $C $W3) + " ║"
}
function Draw-HRule3 {
  param([int]$W1,[int]$W2,[int]$W3,[string]$Left='╟',[string]$Mid='┼',[string]$Right='╢')
  $s1 = '─' * ($W1 + 2); $s2 = '─' * ($W2 + 2); $s3 = '─' * ($W3 + 2)
  "$Left$s1$Mid$s2$Mid$s3$Right"
}

function Show-DevDashboardUnified {
  param(
    [string[]]$Shortcuts = @('notion','obsidian','code .'),
    [switch]$Fast   # ⚡ Fast: no IP pública y sin 'git status'
  )

  # Data
  $session = @{
    Started = (Get-Date -Format 'yyyy-MM-dd HH:mm')
    Shell   = "PowerShell $($PSVersionTable.PSVersion)"
    Path    = (Get-Location).Path
  }
  $system = @{
    OS   = (Get-CimInstance Win32_OperatingSystem).Caption
    User = $env:USERNAME
    Host = $env:COMPUTERNAME
  }
  $netLocal = Get-LocalIPv4
  $netKind  = Get-NetworkKind
  $netPublic = if ($Fast) { '—' } else { Get-PublicIPv4 }

  $conda = Get-CondaStatus
  $git   = Get-GitSummary
  $gitBranch = if ($git) { "Branch : $($git.Branch)" } else { "Branch : —" }
  $gitRoot   = if ($git) { "Root   : $($git.Root)"   } else { "Root   : —" }
  $gitStatus = if ($Fast -or -not $git) { "Status : —" } else { 
      $dirty = git status --porcelain
      if ($dirty) { "Status : changes" } else { "Status : clean" }
    }

  # Layout (alineado perfecto)
  $w = Get-WidthSafe
  $inside = $w - 4
  $sepCost = 3 * 2
  $usable  = $inside - $sepCost
  $col     = [int]([Math]::Floor($usable/3))
  $w1 = $col; $w2 = $col; $w3 = $usable - $w1 - $w2

  # Shortcuts (texto plano)
  $sc1 = if ($Shortcuts.Count -ge 1) { "- $($Shortcuts[0])" } else { "-" }
  $sc2 = if ($Shortcuts.Count -ge 2) { "- $($Shortcuts[1])" } else { "-" }
  $sc3 = if ($Shortcuts.Count -ge 3) { "- $($Shortcuts[2])" } else { "-" }

  # Conda state (ASCII)
  $stateGlyph = switch ($conda.State) {
    'Active'   { '[ACTIVE]' }
    'Inactive' { '[INACTIVE]' }
    default    { '[NOT FOUND]' }
  }

  # Top
  Write-Host ("╔" + ("═" * $inside) + "╗")
  # Row 1 titles
  Write-Host (Draw-Row3 "Session Info" "System Info" "Shortcuts" $w1 $w2 $w3)
  Write-Host (Draw-HRule3 $w1 $w2 $w3 '║' '┼' '║')
  # Row 1
  Write-Host (Draw-Row3 ("Started : $($session.Started)") ("OS    : $($system.OS)")   $sc1 $w1 $w2 $w3)
  Write-Host (Draw-Row3 ("Shell   : $($session.Shell)")  ("User  : $($system.User)") $sc2 $w1 $w2 $w3)
  Write-Host (Draw-Row3 ("Path    : $($session.Path)")   ("Host  : $($system.Host)") $sc3 $w1 $w2 $w3)
  # Divider
  Write-Host (Draw-HRule3 $w1 $w2 $w3)
  # Row 2 titles
  Write-Host (Draw-Row3 "Networking" "Conda" "Git" $w1 $w2 $w3)
  Write-Host (Draw-HRule3 $w1 $w2 $w3 '║' '┼' '║')
  # Row 2
  Write-Host (Draw-Row3 ("Local IP : $netLocal")    ("State  : $stateGlyph")     $gitBranch $w1 $w2 $w3)
  Write-Host (Draw-Row3 ("Public IP: $netPublic")   ("Python : $($conda.Python)") $gitStatus $w1 $w2 $w3)
  Write-Host (Draw-Row3 ("Network  : $netKind")     ("Env    : $($conda.Env)")    $gitRoot   $w1 $w2 $w3)
  # Bottom
  Write-Host ("╚" + ("═" * $inside) + "╝")
}

# ========================== Banner de bienvenida ======================
function Show-DevWelcome {
$banner = @"
██████╗  █████╗ ██████╗  ██████╗██╗  ██╗██████╗ ██╗      █████╗  ██████╗██╗  ██╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██║     ██╔══██╗██╔════╝██║ ██╔╝
██║  ██║███████║██████╔╝██║     █████╔╝ ██████╔╝██║     ███████║██║     █████╔╝ 
██║  ██║██╔══██║██╔══██╗██║     ██╔═██╗ ██╔══██╗██║     ██╔══██║██║     ██╔═██╗ 
██████╔╝██║  ██║██║  ██║╚██████╗██║  ██╗██████╔╝███████╗██║  ██║╚██████╗██║  ██╗
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝
"@
    Clear-Host
    Show-AsciiBox -Text $banner -HPadding 3 -VPadding 2 -SideThickness 2 -BorderChar '░' -BorderColor Cyan -TextColor Cyan

    Write-Host ""
    Write-Host "Bienvenido, $env:USERNAME" -ForegroundColor Magenta
    Write-Host "PowerShell $($PSVersionTable.PSVersion) | $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
    Write-Host ""

    # ⚡ Modo rápido: sin IP pública y sin git status (para arrancar veloz)
    Show-DevDashboardUnified -Shortcuts @('notion','obsidian','code .') -Fast
}

# =================== Comandos rápidos para refrescar ===================
function Refresh-Dashboard { Show-DevDashboardUnified -Shortcuts @('notion','obsidian','code .') }
function Refresh-Welcome  { Clear-Host; Show-DevWelcome }
Set-Alias refresh Refresh-Dashboard
Set-Alias welcome Refresh-Welcome

# Mostrar al iniciar
Show-DevWelcome
