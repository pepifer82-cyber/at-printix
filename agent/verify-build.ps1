# Verifica que instalador y EXE comparten version y genera SHA256SUMS.txt.
# En CI sin certificado privado de A&T, NotSigned es aceptado y se informa con claridad.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$expected = '0.5.4'
$installer = Join-Path $root 'Instalar_ATPrinterAgent_v0.5.4.exe'
$x64 = Join-Path $root 'publish-x64\ATPrinterAgent.exe'
$x86 = Join-Path $root 'publish-x86\ATPrinterAgent.exe'

foreach ($file in @($installer, $x64, $x86)) {
    if (-not (Test-Path $file)) { Write-Host "FALTA: $file"; exit 1 }
}

function Get-Version($path) { (Get-Item $path).VersionInfo.ProductVersion }

$fail = $false
$iv = Get-Version $installer
$v64 = Get-Version $x64
$v86 = Get-Version $x86
Write-Host "Instalador: $iv | EXE x64: $v64 | EXE x86: $v86"
foreach ($v in @($iv, $v64, $v86)) {
    if (-not $v.StartsWith($expected)) { Write-Host "VERSION INCORRECTA: $v (esperado $expected)"; $fail = $true }
}

foreach ($file in @($installer, $x64, $x86)) {
    $status = (Get-AuthenticodeSignature $file).Status
    Write-Host "Firma $(Split-Path -Leaf $file): $status"
    if ($status -notin @('Valid', 'NotSigned')) {
        Write-Host 'FIRMA INVALIDA'; $fail = $true
    }
}

$sums = Join-Path $root 'SHA256SUMS.txt'
$name = Split-Path -Leaf $installer
$hash = (Get-FileHash $installer -Algorithm SHA256).Hash.ToLower()
"$hash  $name" | Set-Content $sums -Encoding ASCII
Write-Host "SHA256SUMS.txt: $hash  $name"

if ($fail) { exit 1 }
Write-Host 'VERIFICACION OK (si el estado es NotSigned, el runner no tenia el certificado privado de A&T)'
exit 0
