$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$logDir = Join-Path $root 'project_evidence\fpga\W2\pre\vivado'
New-Item -ItemType Directory -Force $logDir | Out-Null
$vivado = Get-Command vivado.bat -ErrorAction Stop
& $vivado.Source -mode batch -source (Join-Path $root 'FPGA\tools\build_w2_vivado.tcl') -log (Join-Path $logDir 'vivado_w2.log') -journal (Join-Path $logDir 'vivado_w2.jou')
if ($LASTEXITCODE -ne 0) { throw "Vivado W2 build failed with exit code $LASTEXITCODE" }
