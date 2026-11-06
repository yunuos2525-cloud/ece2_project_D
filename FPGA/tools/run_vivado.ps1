$ErrorActionPreference = 'Continue'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$evidence = Join-Path $root 'project_evidence\fpga\W1\sim\vivado_build.log'
$tcl = Join-Path $root 'FPGA\tools\build_vivado.tcl'
& vivado.bat -mode batch -nolog -nojournal -source $tcl 2>&1 | Tee-Object -FilePath $evidence
if ($LASTEXITCODE -ne 0) { throw "Vivado failed with exit code $LASTEXITCODE" }
