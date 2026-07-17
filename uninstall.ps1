# uninstall.ps1 — desinstala claude-shorts-windows
#
# Borra SOLO el junction de la skill y la config central.
# El repo (con el venv y node_modules) queda intacto: para reinstalar
# basta volver a correr setup.ps1.
#
# Uso:  powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = 'Stop'

Write-Host "=== Desinstalando claude-shorts ===" -ForegroundColor Cyan

# --- Junction de la skill ---
$SkillLink = Join-Path $env:USERPROFILE '.claude\skills\shorts'
$item = Get-Item $SkillLink -ErrorAction SilentlyContinue
if ($null -eq $item) {
    Write-Host "  Skill no instalada ($SkillLink no existe)"
} elseif ($item.LinkType -eq 'Junction') {
    # rmdir sobre un junction elimina el enlace SIN tocar el destino.
    # (Remove-Item -Recurse seguiria el junction y borraria el repo.)
    cmd /c rmdir "$SkillLink"
    Write-Host "  Junction eliminado: $SkillLink" -ForegroundColor Green
} else {
    Write-Host "  ATENCION: $SkillLink es un directorio real, no un junction." -ForegroundColor Yellow
    Write-Host "  No lo borro automaticamente para no destruir datos. Revisalo a mano." -ForegroundColor Yellow
}

# --- Config central ---
$ConfigDir = Join-Path $env:APPDATA 'claude-shorts'
if (Test-Path $ConfigDir) {
    Remove-Item $ConfigDir -Recurse -Force -Confirm:$false
    Write-Host "  Config eliminada: $ConfigDir" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Listo ===" -ForegroundColor Cyan
Write-Host "El repo, el venv (~/.shorts-skill) y node_modules quedan intactos."
Write-Host "Para quitar tambien el venv:  Remove-Item -Recurse -Force `"$env:USERPROFILE\.shorts-skill`""
