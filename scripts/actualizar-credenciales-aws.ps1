<#
.SYNOPSIS
  Copia las credenciales del AWS Academy Learner Lab a los secretos de la organizacion en GitHub.

.DESCRIPTION
  Las credenciales del Learner Lab caducan cada 4 horas. Antes de correr un pipeline que use AWS:
    1. En el Learner Lab: Start Lab -> AWS Details -> AWS CLI: Show -> copiar TODO el bloque
       ([default] aws_access_key_id=... aws_secret_access_key=... aws_session_token=...).
    2. Ejecutar este script: lee el portapapeles y actualiza AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY y
       AWS_SESSION_TOKEN en la organizacion con la CLI de GitHub (gh). Requiere "gh auth login" como owner.

.EXAMPLE
  .\scripts\actualizar-credenciales-aws.ps1 -Organizacion Caso-Bodega
#>
param([string]$Organizacion = "Caso-Bodega")
$ErrorActionPreference = 'Stop'

$texto = Get-Clipboard -Raw
if (-not $texto) { throw "El portapapeles esta vacio: copia el bloque 'AWS CLI' del Learner Lab." }

$valores = @{}
foreach ($linea in ($texto -split "`r?`n")) {
    if ($linea -match '^\s*(aws_access_key_id|aws_secret_access_key|aws_session_token)\s*=\s*(\S+)\s*$') {
        $valores[$Matches[1]] = $Matches[2]
    }
}
foreach ($clave in 'aws_access_key_id', 'aws_secret_access_key', 'aws_session_token') {
    if (-not $valores.ContainsKey($clave)) { throw "No encontre $clave en el portapapeles." }
}

$secretos = [ordered]@{
    AWS_ACCESS_KEY_ID     = $valores['aws_access_key_id']
    AWS_SECRET_ACCESS_KEY = $valores['aws_secret_access_key']
    AWS_SESSION_TOKEN     = $valores['aws_session_token']
}
foreach ($nombre in $secretos.Keys) {
    $secretos[$nombre] | gh secret set $nombre --org $Organizacion --visibility all
    if ($LASTEXITCODE -ne 0) { throw "No se pudo actualizar $nombre" }
    Write-Host "Actualizado $nombre" -ForegroundColor Green
}
Write-Host "Listo. Las credenciales sirven por 4 horas; despues hay que repetir." -ForegroundColor Cyan
