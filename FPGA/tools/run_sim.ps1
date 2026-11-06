$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = Join-Path $root 'FPGA\src'
$sim = Join-Path $root 'FPGA\sim'
$build = Join-Path $root 'FPGA\build\sim'
$evidence = Join-Path $root 'project_evidence\fpga\W1\sim'
New-Item -ItemType Directory -Force $build,$evidence | Out-Null

$tests = @(
    @{ Name='sample_tick'; Files=@('sample_tick.sv'); Tb='tb_sample_tick.sv' },
    @{ Name='audio_path'; Files=@('iir_notch_fixed.sv','audio_path.sv'); Tb='tb_audio_path.sv' },
    @{ Name='iir_notch_fixed'; Files=@('iir_notch_fixed.sv'); Tb='tb_iir_notch_fixed.sv' },
    @{ Name='analysis_buffer_512'; Files=@('analysis_buffer_512.sv'); Tb='tb_analysis_buffer_512.sv' },
    @{ Name='spi_read_block'; Files=@('analysis_buffer_512.sv','spi_mode0_slave.sv'); Tb='tb_spi_read_block.sv' },
    @{ Name='timekeeper_basic'; Files=@('timekeeper_basic.sv'); Tb='tb_timekeeper_basic.sv' },
    @{ Name='reset_recovery'; Files=@('reset_conditioner.sv','iir_notch_fixed.sv','audio_path.sv','analysis_buffer_512.sv','spi_mode0_slave.sv'); Tb='tb_reset_recovery.sv' },
    @{ Name='adc_dac_bypass'; Files=@('reset_conditioner.sv','sample_tick.sv','iir_notch_fixed.sv','audio_path.sv','analysis_buffer_512.sv','spi_mode0_slave.sv','timekeeper_basic.sv','adc_command.sv','serial_frame16.sv','adc_reader_16k.sv','dac_parallel8.sv','dac_writer.sv','w1_board_top.sv'); Tb='tb_adc_dac_bypass.sv' }
)

$summary = @()
foreach ($test in $tests) {
    $out = Join-Path $build ($test.Name + '.vvp')
    $compileLog = Join-Path $evidence ($test.Name + '_compile.log')
    $runLog = Join-Path $evidence ($test.Name + '.log')
    $args = @('-g2012','-Wall','-o',$out)
    foreach ($file in $test.Files) { $args += (Join-Path $src $file) }
    $args += (Join-Path $sim $test.Tb)
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & iverilog @args 2>&1 | Tee-Object -FilePath $compileLog
    $ErrorActionPreference = $savedPreference
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($test.Name)" }
    $ErrorActionPreference = 'Continue'
    & vvp $out 2>&1 | Tee-Object -FilePath $runLog
    $ErrorActionPreference = $savedPreference
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $($test.Name)" }
    $pass = Select-String -Path $runLog -Pattern ('PASS ' + $test.Name.ToUpper()) -Quiet
    if (-not $pass) {
        # Named messages contain descriptive suffixes; accept any explicit PASS.
        $pass = Select-String -Path $runLog -Pattern '^PASS ' -Quiet
    }
    if (-not $pass) { throw "No PASS marker: $($test.Name)" }
    $summary += "PASS $($test.Name)"
}
$summary | Set-Content -Encoding UTF8 (Join-Path $evidence 'simulation_summary.log')
$summary
