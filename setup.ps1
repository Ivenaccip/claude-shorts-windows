# setup.ps1 — instalador idempotente de claude-shorts-windows
#
# Hace TODO en una sola pasada y se puede correr las veces que sea:
#   1. Verifica dependencias de sistema (ffmpeg, jq) y sugiere winget si faltan
#   2. Crea el venv en %USERPROFILE%\.shorts-skill e instala requirements pinneados
#   3. Instala torch (CUDA si hay nvidia-smi, CPU si no)
#   4. npm ci en remotion/ (solo si package-lock.json cambió)
#   5. Escribe la config central %APPDATA%\claude-shorts\env.json
#   6. Instala la skill como JUNCTION (~/.claude/skills/shorts -> este repo)
#
# Uso:  powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }

# --- 1. Dependencias de sistema (auto-instala con winget) ------------------
Step "Dependencias de sistema"

# Tras un winget install, el PATH nuevo no existe en este proceso: refrescarlo
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}

# winget deja ffmpeg bajo WinGet\Links en el PATH de usuario; algunos paquetes
# (Python, Node) requieren ademas sus rutas propias que ya vienen en el PATH.
$deps = @(
    @{ cmd = 'ffmpeg'; id = 'Gyan.FFmpeg' },
    @{ cmd = 'jq';     id = 'jqlang.jq' },
    @{ cmd = 'python'; id = 'Python.Python.3.10' },
    @{ cmd = 'node';   id = 'OpenJS.NodeJS.LTS' }
)

$missing = @()
foreach ($dep in $deps) {
    if (Get-Command $dep.cmd -ErrorAction SilentlyContinue) {
        Ok "$($dep.cmd) en PATH"
        continue
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Warn "Falta $($dep.cmd) y no hay winget. Instalalo a mano: $($dep.id)"
        $missing += $dep.cmd
        continue
    }
    Write-Host "  Falta $($dep.cmd) - instalando con winget ($($dep.id))..."
    winget install --id $dep.id --accept-source-agreements --accept-package-agreements --silent
    Refresh-Path
    if (Get-Command $dep.cmd -ErrorAction SilentlyContinue) {
        Ok "$($dep.cmd) instalado"
    } else {
        Warn "$($dep.cmd) instalado pero no visible en este proceso."
        $missing += $dep.cmd
    }
}

if ($missing.Count -gt 0) {
    Warn "Cierra esta terminal, abre una nueva y vuelve a correr setup.ps1"
    Warn "(el PATH nuevo solo aparece en terminales nuevas). Pendientes: $($missing -join ', ')"
    exit 1
}

# --- 2. Venv de Python -----------------------------------------------------
Step "Venv de Python"
$Venv = Join-Path $env:USERPROFILE '.shorts-skill'
$Python = Join-Path $Venv 'Scripts\python.exe'

if (Test-Path $Python) {
    Ok "Venv existente: $Venv"
} else {
    Write-Host "  Creando venv en $Venv ..."
    python -m venv $Venv
    Ok "Venv creado"
}

Write-Host "  Instalando requirements pinneados (no-op si ya estan)..."
& $Python -m pip install --quiet --upgrade pip
& $Python -m pip install --quiet -r (Join-Path $RepoRoot 'requirements.txt')
Ok "requirements.txt instalado"

# --- 3. PyTorch segun GPU --------------------------------------------------
Step "PyTorch"
$HasGpu = [bool](Get-Command nvidia-smi -ErrorAction SilentlyContinue)
$TorchInstalled = $false
try {
    & $Python -c "import torch" 2>$null
    if ($LASTEXITCODE -eq 0) { $TorchInstalled = $true }
} catch {}

if ($TorchInstalled) {
    Ok "torch ya instalado"
} elseif ($HasGpu) {
    Write-Host "  GPU NVIDIA detectada - instalando torch CUDA (cu128)..."
    & $Python -m pip install --quiet torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    Ok "torch CUDA instalado"
} else {
    Write-Host "  Sin GPU NVIDIA - instalando torch CPU..."
    & $Python -m pip install --quiet torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
    Ok "torch CPU instalado"
}

# --- 4. Remotion (npm ci solo si cambio el lockfile) -----------------------
Step "Motor Remotion"
$RemotionDir = Join-Path $RepoRoot 'remotion'
$LockFile = Join-Path $RemotionDir 'package-lock.json'
$Marker = Join-Path $RemotionDir 'node_modules\.setup-lock-hash'
if (-not (Test-Path $LockFile)) { throw "No existe remotion/package-lock.json - repo incompleto" }

$LockHash = (Get-FileHash $LockFile -Algorithm SHA256).Hash
$NeedInstall = $true
if ((Test-Path $Marker) -and ((Get-Content $Marker -TotalCount 1) -eq $LockHash)) {
    $NeedInstall = $false
}

if ($NeedInstall) {
    Write-Host "  Ejecutando npm ci (lockfile nuevo o node_modules ausente)..."
    Push-Location $RemotionDir
    try {
        npm ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw "npm ci fallo (exit $LASTEXITCODE)" }
    } finally { Pop-Location }
    Set-Content -Path $Marker -Value $LockHash -Encoding ascii
    Ok "Remotion instalado (npm ci)"
} else {
    Ok "node_modules al dia (lockfile sin cambios)"
}

# --- 5. Config central env.json --------------------------------------------
Step "Config central"
$ConfigDir = Join-Path $env:APPDATA 'claude-shorts'
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null }
$ConfigFile = Join-Path $ConfigDir 'env.json'

# Rutas siempre con forward-slashes: son seguras de interpolar en bash y Python
function FwdSlash($p) { return $p.Replace('\', '/') }

$WhisperModel = 'small'
if ($HasGpu) { $WhisperModel = 'large-v3' }

$config = [ordered]@{
    root          = FwdSlash $RepoRoot
    venv          = FwdSlash $Venv
    python        = FwdSlash $Python
    remotion      = FwdSlash $RemotionDir
    tmp           = FwdSlash (Join-Path $env:TEMP 'claude-shorts')
    whisper_model = $WhisperModel
}
# UTF-8 SIN BOM: jq y json.load se atragantan con el BOM que agrega Out-File en PS 5.1
$json = ($config | ConvertTo-Json) + "`n"
[System.IO.File]::WriteAllText($ConfigFile, $json, (New-Object System.Text.UTF8Encoding $false))
Ok "Config escrita: $ConfigFile (whisper_model=$WhisperModel)"

# --- 6. Skill como junction -------------------------------------------------
Step "Instalacion de la skill (junction)"
$SkillsDir = Join-Path $env:USERPROFILE '.claude\skills'
if (-not (Test-Path $SkillsDir)) { New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null }
$SkillLink = Join-Path $SkillsDir 'shorts'

$item = Get-Item $SkillLink -ErrorAction SilentlyContinue
if ($null -ne $item -and $item.LinkType -eq 'Junction') {
    $target = $item.Target
    if ($target -is [array]) { $target = $target[0] }
    if ($target -eq $RepoRoot) {
        Ok "Junction ya apunta a este repo"
    } else {
        Write-Host "  Junction apuntaba a '$target' - recreando hacia este repo..."
        Remove-Item $SkillLink -Force -Confirm:$false
        New-Item -ItemType Junction -Path $SkillLink -Target $RepoRoot | Out-Null
        Ok "Junction actualizado"
    }
} elseif ($null -ne $item) {
    # Directorio real (instalacion vieja por copia): apartarlo, no destruirlo
    $backup = "$SkillLink.old-copy"
    Write-Host "  Existe una instalacion por copia - renombrando a shorts.old-copy..."
    if (Test-Path $backup) { Remove-Item $backup -Recurse -Force -Confirm:$false }
    Rename-Item $SkillLink $backup
    New-Item -ItemType Junction -Path $SkillLink -Target $RepoRoot | Out-Null
    Ok "Junction creado (copia vieja en shorts.old-copy)"
} else {
    New-Item -ItemType Junction -Path $SkillLink -Target $RepoRoot | Out-Null
    Ok "Junction creado: $SkillLink -> $RepoRoot"
}

# --- Resumen ----------------------------------------------------------------
Step "Setup completo"
Write-Host "  Repo:     $RepoRoot"
Write-Host "  Venv:     $Venv"
Write-Host "  Config:   $ConfigFile"
Write-Host "  Skill:    $SkillLink (junction)"
Write-Host ""
Write-Host "  Actualizar la skill = git pull en el repo. Nada mas."
