$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = Join-Path $root 'FPGA\src'
$sim = Join-Path $root 'FPGA\sim'
$build = Join-Path $root 'FPGA\build\sim_w2'
$pre = Join-Path $root 'project_evidence\fpga\W2\pre'
New-Item -ItemType Directory -Force $build | Out-Null

$tests = @(
    @{ Name='audio_path_w2'; Area='dsp'; Files=@('iir_notch_fixed.sv','iir_notch_variable.sv','audio_path_w2.sv'); Tb='tb_audio_path_w2.sv' },
    @{ Name='iir_notch_variable'; Area='dsp'; Files=@('iir_notch_variable.sv'); Tb='tb_iir_notch_variable.sv' },
    @{ Name='spi_w2'; Area='spi'; Files=@('analysis_buffer_512.sv','spi_mode0_slave_w2.sv'); Tb='tb_spi_w2.sv' },
    @{ Name='stopwatch'; Area='stopwatch'; Files=@('input_conditioner.sv','stopwatch.sv'); Tb='tb_stopwatch.sv' },
    @{ Name='calendar_clock'; Area='clock'; Files=@('calendar_clock.sv'); Tb='tb_calendar_clock.sv' },
    @{ Name='lcd_status_display'; Area='lcd'; Files=@('lcd_status_display.sv'); Tb='tb_lcd_status_display.sv' },
    @{ Name='w2_integration'; Area='integration'; Files=@('iir_notch_fixed.sv','iir_notch_variable.sv','audio_path_w2.sv','spi_mode0_slave_w2.sv','stopwatch.sv','calendar_clock.sv','lcd_status_display.sv'); Tb='tb_w2_integration.sv' }
)

$summary = @()
foreach ($test in $tests) {
    $area = Join-Path $pre $test.Area
    New-Item -ItemType Directory -Force $area | Out-Null
    $out = Join-Path $build ($test.Name + '.vvp')
    $compileLog = Join-Path $area ($test.Name + '_compile.log')
    $runLog = Join-Path $area ($test.Name + '.log')
    $args = @('-g2012','-Wall','-o',$out)
    foreach ($file in $test.Files) { $args += (Join-Path $src $file) }
    $args += (Join-Path $sim $test.Tb)
    $saved = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & iverilog @args 2>&1 | Tee-Object -FilePath $compileLog
    $compileExit = $LASTEXITCODE
    $ErrorActionPreference = $saved
    if ($compileExit -ne 0) { throw "Compile failed: $($test.Name)" }
    $saved = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    & vvp $out 2>&1 | Tee-Object -FilePath $runLog
    $runExit = $LASTEXITCODE
    $ErrorActionPreference = $saved
    if ($runExit -ne 0) { throw "Simulation failed: $($test.Name)" }
    if (-not (Select-String -Path $runLog -Pattern '^PASS ' -Quiet)) { throw "No PASS marker: $($test.Name)" }
    $summary += "PASS $($test.Name)"
}
$summaryPath = Join-Path $pre 'simulation_summary.log'
$summary | Set-Content -Encoding UTF8 $summaryPath
$summary
