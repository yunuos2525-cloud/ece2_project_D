[CmdletBinding()]
param(
    [string]$Commit = '91a1a077fabd8a4c83a0ea8f5b9237c45b87b70b'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$evidence = Join-Path $repo 'project_evidence\fpga\W2\pre\cross_integration'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$temp = Join-Path $tempRoot ('w2_stm32_cross_' + [guid]::NewGuid().ToString('N'))
$vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'

if (-not (Test-Path -LiteralPath $vcvars)) {
    throw "Visual Studio C environment not found: $vcvars"
}

Push-Location $repo
try {
    git cat-file -e "$Commit^{commit}"
    if ($LASTEXITCODE -ne 0) { throw "Missing STM32 source commit $Commit" }

    New-Item -ItemType Directory -Force -Path $evidence | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $evidence 'captures') | Out-Null
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp 'STM32\src') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $temp 'STM32\include') | Out-Null

    function Export-GitText([string]$Spec, [string]$Destination) {
        $lines = @(& git show $Spec)
        if ($LASTEXITCODE -ne 0) { throw "git show failed: $Spec" }
        [IO.File]::WriteAllLines($Destination, $lines, [Text.UTF8Encoding]::new($false))
    }

    Export-GitText "$Commit`:STM32/src/fpga_link.c" (Join-Path $temp 'STM32\src\fpga_link.c')
    Export-GitText "$Commit`:STM32/src/audio_dsp.c" (Join-Path $temp 'STM32\src\audio_dsp.c')
    Export-GitText "$Commit`:STM32/include/fpga_link.h" (Join-Path $temp 'STM32\include\fpga_link.h')
    Export-GitText "$Commit`:STM32/include/audio_dsp.h" (Join-Path $temp 'STM32\include\audio_dsp.h')

    $generatorSource = Join-Path $repo 'FPGA\tools\cross_integration\stm32_frame_generator.c'
    $generatorExe = Join-Path $temp 'stm32_frame_generator.exe'
    $buildCmd = Join-Path $temp 'build_generator.cmd'
    $buildLines = @(
        '@echo off',
        "call `"$vcvars`" >nul",
        "cl.exe /nologo /std:c11 /W4 /I`"$(Join-Path $temp 'STM32\include')`" `"$generatorSource`" `"$(Join-Path $temp 'STM32\src\fpga_link.c')`" `"$(Join-Path $temp 'STM32\src\audio_dsp.c')`" /Fe:`"$generatorExe`""
    )
    [IO.File]::WriteAllLines($buildCmd, $buildLines, [Text.ASCIIEncoding]::new())
    $cCompileLog = Join-Path $evidence 'stm32_host_compile.log'
    & cmd.exe /d /c $buildCmd 2>&1 | Tee-Object -FilePath $cCompileLog
    if ($LASTEXITCODE -ne 0) { throw "STM32 host C compilation failed: exit $LASTEXITCODE" }

    $frameHex = Join-Path $evidence 'stm32_frames.hex'
    $generationLog = Join-Path $evidence 'stm32_frame_generation.log'
    $hostRunLog = Join-Path $evidence 'stm32_host_run.log'
    & $generatorExe $frameHex $generationLog 2>&1 | Tee-Object -FilePath $hostRunLog
    if ($LASTEXITCODE -ne 0) { throw "STM32 frame generator failed: exit $LASTEXITCODE" }

    $vvpImage = Join-Path $temp 'tb_stm32_fpga_cross.vvp'
    $hdlCompileLog = Join-Path $evidence 'cross_tb_compile.log'
    [IO.File]::WriteAllText($hdlCompileLog, "", [Text.UTF8Encoding]::new($false))
    & iverilog -g2012 -s tb_stm32_fpga_cross -o $vvpImage `
        (Join-Path $repo 'FPGA\src\analysis_buffer_512.sv') `
        (Join-Path $repo 'FPGA\src\spi_mode0_slave_w2.sv') `
        (Join-Path $repo 'FPGA\src\iir_notch_variable.sv') `
        (Join-Path $repo 'FPGA\sim\tb_stm32_fpga_cross.sv') 2>&1 | Tee-Object -FilePath $hdlCompileLog -Append
    if ($LASTEXITCODE -ne 0) { throw "Cross TB compilation failed: exit $LASTEXITCODE" }
    Add-Content -LiteralPath $hdlCompileLog -Value 'PASS IVERILOG_COMPILE exit=0'

    $vcd = Join-Path $evidence 'tb_stm32_fpga_cross.vcd'
    $byteLog = Join-Path $evidence 'cross_spi_bytes.log'
    $simulationLog = Join-Path $evidence 'cross_integration.log'
    $frameArg = $frameHex.Replace('\', '/')
    $vcdArg = $vcd.Replace('\', '/')
    $byteArg = $byteLog.Replace('\', '/')
    & vvp $vvpImage "+FRAME_HEX=$frameArg" "+VCD=$vcdArg" "+BYTE_LOG=$byteArg" 2>&1 |
        Tee-Object -FilePath $simulationLog
    if ($LASTEXITCODE -ne 0) { throw "Cross TB simulation failed: exit $LASTEXITCODE" }

    $sourceFiles = @(
        (Join-Path $temp 'STM32\src\fpga_link.c'),
        (Join-Path $temp 'STM32\src\audio_dsp.c'),
        (Join-Path $temp 'STM32\include\fpga_link.h'),
        (Join-Path $temp 'STM32\include\audio_dsp.h')
    )
    $provenance = Join-Path $evidence 'STM32_FRAME_PROVENANCE.md'
    $provenanceLines = @(
        '# STM32 frame provenance',
        '',
        "- Git commit: ``$Commit``",
        '- Execution: Microsoft Visual C host executable with virtual SPI callbacks.',
        '- Important: these are bytes produced by the STM32 C implementation on a PC; they are not a physical-board SPI capture.',
        '- C sources are exported directly from the named Git object at test time and are not edited.',
        '- `fpga_link.c` performs the actual command serialization and response deserialization.',
        '- `audio_dsp.c` generates the 1 kHz, radius 0.98 Q2.14 coefficients passed to `fpga_set_coeff`.',
        '',
        '## Exported source SHA-256',
        ''
    )
    foreach ($source in $sourceFiles) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
        $provenanceLines += "- ``$hash`` - ``$([IO.Path]::GetFileName($source))``"
    }
    $provenanceLines += ''
    $provenanceLines += '## Git blob object IDs'
    $provenanceLines += ''
    foreach ($gitPath in @('STM32/src/fpga_link.c', 'STM32/src/audio_dsp.c', 'STM32/include/fpga_link.h', 'STM32/include/audio_dsp.h')) {
        $blob = (& git rev-parse "$Commit`:$gitPath").Trim()
        if ($LASTEXITCODE -ne 0) { throw "Cannot resolve blob: $gitPath" }
        $provenanceLines += "- ``$blob`` - ``$gitPath``"
    }
    $provenanceLines += ''
    $provenanceLines += 'The exported files are temporary compilation inputs and are not copied into the repository evidence.'
    [IO.File]::WriteAllLines($provenance, $provenanceLines, [Text.UTF8Encoding]::new($false))

    $renderer = Join-Path $repo 'FPGA\tools\cross_integration\render_cross_vcd.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $renderer -VcdPath $vcd `
        -OutputDirectory (Join-Path $evidence 'captures') -SimulationLog $simulationLog
    if ($LASTEXITCODE -ne 0) { throw "VCD rendering failed: exit $LASTEXITCODE" }

    $manifest = Join-Path $evidence 'CROSS_INTEGRATION_HASHES.sha256'
    $manifestFiles = Get-ChildItem -LiteralPath $evidence -Recurse -File |
        Where-Object { $_.FullName -ne $manifest } | Sort-Object FullName
    $manifestLines = foreach ($file in $manifestFiles) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        $relative = $file.FullName.Substring($evidence.Length + 1).Replace('\', '/')
        "$hash  $relative"
    }
    [IO.File]::WriteAllLines($manifest, $manifestLines, [Text.UTF8Encoding]::new($false))

    Write-Output "Cross integration simulation completed: $simulationLog"
}
finally {
    Pop-Location
    if (Test-Path -LiteralPath $temp) {
        $resolvedTemp = [IO.Path]::GetFullPath($temp)
        if (-not $resolvedTemp.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($resolvedTemp) -notlike 'w2_stm32_cross_*') {
            throw "Refusing to remove unexpected temporary path: $resolvedTemp"
        }
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
