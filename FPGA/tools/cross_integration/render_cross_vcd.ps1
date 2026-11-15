[CmdletBinding()]
param(
    [string]$VcdPath = 'project_evidence/fpga/W2/pre/cross_integration/tb_stm32_fpga_cross.vcd',
    [string]$OutputDirectory = 'project_evidence/fpga/W2/pre/cross_integration/captures',
    [string]$SimulationLog = 'project_evidence/fpga/W2/pre/cross_integration/cross_integration.log'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

$wanted = @(
    'test_phase', 'spi_cs_n', 'spi_sck', 'spi_mosi', 'spi_miso', 'dsp_mode',
    'coeff_update_valid', 'coeff_update_seq', 'filter_coeff_valid',
    'filter_coeff_applied', 'filter_applied_seq', 'filter_sample_valid',
    'filter_sample_in', 'filter_sample_out_valid', 'filter_sample_out',
    'notch_frequency', 'block_valid', 'block_id', 'block_consume_valid',
    'ready_debug', 'active_b0', 'active_b1', 'active_b2', 'active_a1', 'active_a2'
)

$idToName = @{}
$widths = @{}
$events = @{}
$currentTime = [long]0
$lastTime = [long]0
$simulationText = Get-Content -LiteralPath $SimulationLog -Raw
if ($simulationText -notmatch 'METRIC NOTCH frequency=1000Hz.*gain_db=([-+0-9.]+)') {
    throw '1000 Hz metric missing from simulation log'
}
$gain1000 = [double]$matches[1]
if ($simulationText -notmatch 'METRIC NOTCH frequency=500Hz.*gain_db=([-+0-9.]+)') {
    throw '500 Hz metric missing from simulation log'
}
$gain500 = [double]$matches[1]

foreach ($line in [IO.File]::ReadLines((Resolve-Path $VcdPath))) {
    if ($line -match '^\$var\s+\S+\s+(\d+)\s+(\S+)\s+(\S+)') {
        $width = [int]$matches[1]
        $id = $matches[2]
        $name = $matches[3]
        if ($wanted -contains $name) {
            $idToName[$id] = $name
            $widths[$name] = $width
            $events[$name] = [Collections.Generic.List[object]]::new()
        }
        continue
    }
    if ($line.Length -eq 0) { continue }
    if ($line[0] -eq '#') {
        $currentTime = [long]$line.Substring(1)
        $lastTime = $currentTime
        continue
    }
    if ($line -match '^([01xXzZ])(\S+)$') {
        $scalar = $matches[1]
        $id = $matches[2]
        if ($idToName.ContainsKey($id)) {
            $value = if ($scalar -eq '1') { 1 } elseif ($scalar -eq '0') { 0 } else { -1 }
            $events[$idToName[$id]].Add([pscustomobject]@{ T = $currentTime; V = [long]$value })
        }
        continue
    }
    if ($line -match '^b([01xXzZ]+)\s+(\S+)$') {
        $id = $matches[2]
        if ($idToName.ContainsKey($id)) {
            $bits = $matches[1]
            $value = if ($bits -match '[xXzZ]') { -1L } else { [Convert]::ToInt64($bits, 2) }
            $events[$idToName[$id]].Add([pscustomobject]@{ T = $currentTime; V = $value })
        }
    }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

Write-Output ("VCD events: sck={0} cs={1} phase={2} sample_in={3} sample_out={4}" -f `
    $events['spi_sck'].Count, $events['spi_cs_n'].Count, $events['test_phase'].Count, `
    $events['filter_sample_in'].Count, $events['filter_sample_out'].Count)

$font = [Drawing.Font]::new('Consolas', 14)
$smallFont = [Drawing.Font]::new('Consolas', 11)
$titleFont = [Drawing.Font]::new('Segoe UI', 20, [Drawing.FontStyle]::Bold)
$labelBrush = [Drawing.Brushes]::Black
$gridPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(225, 225, 225), 1)
$wavePen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(25, 85, 170), 3)
$busPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(120, 55, 160), 3)
$eventPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(210, 70, 35), 3)

function Get-ValueAt([string]$Name, [long]$Time) {
    $value = -1L
    foreach ($event in $events[$Name]) {
        if ($event.T -gt $Time) { break }
        $value = $event.V
    }
    return $value
}

function Get-WindowEvents([string]$Name, [long]$Start, [long]$End) {
    $list = [Collections.Generic.List[object]]::new()
    $list.Add([pscustomobject]@{ T = $Start; V = (Get-ValueAt $Name $Start) })
    foreach ($event in $events[$Name]) {
        if ($event.T -le $Start) { continue }
        if ($event.T -gt $End) { break }
        $list.Add($event)
    }
    return $list
}

function Find-ValueTime([string]$Name, [long]$Value) {
    foreach ($event in $events[$Name]) {
        if ($event.V -eq $Value) { return [long]$event.T }
    }
    throw "Value $Value not found on $Name"
}

function Format-BusValue([long]$Value, [int]$Width) {
    if ($Value -lt 0) { return 'X' }
    $digits = [Math]::Max(1, [int][Math]::Ceiling($Width / 4.0))
    return ('0x{0:X' + $digits + '}') -f $Value
}

function Draw-Axes($graphics, [long]$Start, [long]$End, [string]$Unit, [double]$Scale, [int]$Left, [int]$Right, [int]$Top, [int]$Bottom, [int]$Width, [int]$Height) {
    for ($tick = 0; $tick -le 10; $tick++) {
        $x = $Left + ($Width - $Left - $Right) * $tick / 10.0
        $graphics.DrawLine($gridPen, [single]$x, [single]$Top, [single]$x, [single]($Height - $Bottom))
        $time = ($Start + ($End - $Start) * $tick / 10.0) / $Scale
        $text = if ($Unit -eq 'ms') { '{0:0.000}' -f $time } elseif ($Unit -eq 'us') { '{0:0.0}' -f $time } else { '{0:0}' -f $time }
        $graphics.DrawString("$text $Unit", $smallFont, $labelBrush, [single]($x - 35), [single]($Height - $Bottom + 8))
    }
}

function Draw-WaveformImage([string]$Path, [string]$Title, [long]$Start, [long]$End, [string]$Unit, [double]$Scale, [object[]]$Rows) {
    $width = 1900
    $left = 285
    $right = 40
    $top = 105
    $bottom = 70
    $rowHeight = 78
    $height = $top + $bottom + $rowHeight * $Rows.Count
    $bitmap = [Drawing.Bitmap]::new($width, $height)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::White)
    $graphics.DrawString($Title, $titleFont, $labelBrush, 24, 18)
    $graphics.DrawString('Source: Icarus VCD, exact timestamps (timescale 1 ps)', $smallFont, [Drawing.Brushes]::DimGray, 28, 58)
    Draw-Axes $graphics $Start $End $Unit $Scale $left $right $top $bottom $width $height

    for ($rowIndex = 0; $rowIndex -lt $Rows.Count; $rowIndex++) {
        $row = $Rows[$rowIndex]
        $yTop = $top + $rowIndex * $rowHeight
        $yLow = $yTop + 54
        $yHigh = $yTop + 15
        $graphics.DrawString($row.Label, $font, $labelBrush, 20, [single]($yTop + 18))
        $windowEvents = @(Get-WindowEvents $row.Name $Start $End)
        if ($row.Kind -eq 'digital') {
            for ($i = 0; $i -lt $windowEvents.Count; $i++) {
                $event = $windowEvents[$i]
                $nextTime = if ($i + 1 -lt $windowEvents.Count) { $windowEvents[$i + 1].T } else { $End }
                $x1 = $left + ($width - $left - $right) * (($event.T - $Start) / [double]($End - $Start))
                $x2 = $left + ($width - $left - $right) * (($nextTime - $Start) / [double]($End - $Start))
                $y = if ($event.V -eq 1) { $yHigh } else { $yLow }
                $pen = if ($row.Name -match 'applied|update|consume') { $eventPen } else { $wavePen }
                $graphics.DrawLine($pen, [single]$x1, [single]$y, [single]$x2, [single]$y)
                if ($i + 1 -lt $windowEvents.Count) {
                    $nextY = if ($windowEvents[$i + 1].V -eq 1) { $yHigh } else { $yLow }
                    $graphics.DrawLine($pen, [single]$x2, [single]$y, [single]$x2, [single]$nextY)
                }
            }
        } else {
            $y = $yTop + 35
            for ($i = 0; $i -lt $windowEvents.Count; $i++) {
                $event = $windowEvents[$i]
                $nextTime = if ($i + 1 -lt $windowEvents.Count) { $windowEvents[$i + 1].T } else { $End }
                $x1 = $left + ($width - $left - $right) * (($event.T - $Start) / [double]($End - $Start))
                $x2 = $left + ($width - $left - $right) * (($nextTime - $Start) / [double]($End - $Start))
                $graphics.DrawLine($busPen, [single]$x1, [single]$y, [single]$x2, [single]$y)
                $graphics.DrawLine($busPen, [single]$x1, [single]($y - 9), [single]$x1, [single]($y + 9))
                if ($x2 - $x1 -gt 42) {
                    $text = Format-BusValue $event.V $row.Width
                    $graphics.DrawString($text, $smallFont, [Drawing.Brushes]::DarkMagenta, [single]($x1 + 4), [single]($y - 28))
                }
            }
        }
        $graphics.DrawLine([Drawing.Pens]::LightGray, $left, [single]($yTop + $rowHeight - 2), $width - $right, [single]($yTop + $rowHeight - 2))
    }
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

function Draw-AnalogPanel($graphics, [long]$Start, [long]$End, [int]$Left, [int]$Top, [int]$Width, [int]$Height, [string]$Caption) {
    $graphics.DrawString($Caption, $font, $labelBrush, $Left, $Top - 30)
    $graphics.DrawRectangle([Drawing.Pens]::Gray, $Left, $Top, $Width, $Height)
    for ($value = 0; $value -le 255; $value += 64) {
        $y = $Top + $Height - $value * $Height / 255.0
        $graphics.DrawLine($gridPen, $Left, [single]$y, $Left + $Width, [single]$y)
        $graphics.DrawString("$value", $smallFont, $labelBrush, $Left - 42, [single]($y - 8))
    }
    foreach ($entry in @(@{ Name = 'filter_sample_in'; Pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(45, 100, 190), 2) },
                         @{ Name = 'filter_sample_out'; Pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(210, 65, 35), 2) })) {
        $windowEvents = @(Get-WindowEvents $entry.Name $Start $End)
        $previous = $null
        foreach ($event in $windowEvents) {
            if ($event.V -lt 0) { continue }
            $x = $Left + $Width * (($event.T - $Start) / [double]($End - $Start))
            $y = $Top + $Height - $event.V * $Height / 255.0
            if ($null -ne $previous) {
                $graphics.DrawLine($entry.Pen, [single]$previous.X, [single]$previous.Y, [single]$x, [single]$y)
            }
            $previous = [pscustomobject]@{ X = $x; Y = $y }
        }
        $entry.Pen.Dispose()
    }
}

function Draw-NotchImage([string]$Path) {
    $f1000Start = Find-ValueTime 'notch_frequency' 1000
    $f500Start = Find-ValueTime 'notch_frequency' 500
    $phase9 = Find-ValueTime 'test_phase' 9
    $firstEnd = $f500Start
    $secondEnd = $phase9
    $firstStart = [Math]::Max($f1000Start, $firstEnd - 2000000L)
    $secondStart = [Math]::Max($f500Start, $secondEnd - 3000000L)
    $bitmap = [Drawing.Bitmap]::new(1900, 980)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::White)
    $graphics.DrawString('STM32 r=0.98 coefficients on FPGA IIR RTL', $titleFont, $labelBrush, 24, 18)
    $graphics.DrawString('Blue=input, red=output. Source: exact VCD sample values.', $smallFont, [Drawing.Brushes]::DimGray, 28, 58)
    Draw-AnalogPanel $graphics $firstStart $firstEnd 105 145 1725 300 ("1000 Hz notch window - measured gain {0:+0.000;-0.000;0.000} dB" -f $gain1000)
    Draw-AnalogPanel $graphics $secondStart $secondEnd 105 585 1725 300 ("500 Hz passband window - measured gain {0:+0.000;-0.000;0.000} dB" -f $gain500)
    $graphics.DrawLine([Drawing.Pen]::new([Drawing.Color]::FromArgb(45, 100, 190), 4), 120, 930, 180, 930)
    $graphics.DrawString('filter_sample_in[7:0]', $smallFont, $labelBrush, 190, 918)
    $graphics.DrawLine([Drawing.Pen]::new([Drawing.Color]::FromArgb(210, 65, 35), 4), 460, 930, 520, 930)
    $graphics.DrawString('filter_sample_out[7:0]', $smallFont, $labelBrush, 530, 918)
    $bitmap.Save($Path, [Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}

$phase4Start = Find-ValueTime 'test_phase' 4
$phase5Start = Find-ValueTime 'test_phase' 5
$phase7Start = Find-ValueTime 'test_phase' 7

Draw-WaveformImage (Join-Path $OutputDirectory 'W2_STM32_cross_overview.png') `
    'STM32 C frames replayed into FPGA W2 - overview' 0 $lastTime 'ms' 1000000000.0 @(
        @{ Name = 'test_phase'; Kind = 'bus'; Width = 8; Label = 'test_phase[7:0]' },
        @{ Name = 'dsp_mode'; Kind = 'bus'; Width = 8; Label = 'dsp_mode[7:0]' },
        @{ Name = 'block_valid'; Kind = 'digital'; Label = 'block_valid' },
        @{ Name = 'block_consume_valid'; Kind = 'digital'; Label = 'block_consume_valid' },
        @{ Name = 'coeff_update_valid'; Kind = 'digital'; Label = 'coeff_update_valid' },
        @{ Name = 'filter_coeff_applied'; Kind = 'digital'; Label = 'filter_coeff_applied' },
        @{ Name = 'filter_coeff_valid'; Kind = 'digital'; Label = 'filter_coeff_valid' },
        @{ Name = 'filter_applied_seq'; Kind = 'bus'; Width = 8; Label = 'applied_seq[7:0]' }
    )

Draw-WaveformImage (Join-Path $OutputDirectory 'W2_STM32_read_block_split.png') `
    'READ_BLOCK: one CS frame, two STM32 transfers, deliberate SCK gap' $phase4Start ($phase4Start + 80000000L) 'us' 1000000.0 @(
        @{ Name = 'spi_cs_n'; Kind = 'digital'; Label = 'spi_cs_n' },
        @{ Name = 'spi_sck'; Kind = 'digital'; Label = 'spi_sck (500 kHz)' },
        @{ Name = 'spi_mosi'; Kind = 'digital'; Label = 'spi_mosi' },
        @{ Name = 'spi_miso'; Kind = 'digital'; Label = 'spi_miso' },
        @{ Name = 'block_valid'; Kind = 'digital'; Label = 'block_valid' },
        @{ Name = 'block_id'; Kind = 'bus'; Width = 16; Label = 'block_id[15:0]' }
    )

Draw-WaveformImage (Join-Path $OutputDirectory 'W2_STM32_coeff_apply_and_state.png') `
    'SET_COEFF CRC acceptance, sample-edge apply, READ_STATE confirmation' $phase5Start $phase7Start 'us' 1000000.0 @(
        @{ Name = 'spi_cs_n'; Kind = 'digital'; Label = 'spi_cs_n' },
        @{ Name = 'spi_sck'; Kind = 'digital'; Label = 'spi_sck (500 kHz)' },
        @{ Name = 'spi_mosi'; Kind = 'digital'; Label = 'spi_mosi' },
        @{ Name = 'spi_miso'; Kind = 'digital'; Label = 'spi_miso' },
        @{ Name = 'coeff_update_valid'; Kind = 'digital'; Label = 'coeff_update_valid' },
        @{ Name = 'filter_coeff_applied'; Kind = 'digital'; Label = 'coeff_applied' },
        @{ Name = 'filter_coeff_valid'; Kind = 'digital'; Label = 'coeff_valid' },
        @{ Name = 'filter_applied_seq'; Kind = 'bus'; Width = 8; Label = 'applied_seq[7:0]' }
    )

Draw-NotchImage (Join-Path $OutputDirectory 'W2_STM32_notch_r098_response.png')

Write-Output "PASS VCD_RENDER images=4 source=$VcdPath"
