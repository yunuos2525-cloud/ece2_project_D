param(
    [Parameter(Mandatory=$true)][string]$Output
)
$fs = 16000.0
$radius = 0.95
$targets = @(930,1370,1830,2460)
function Convert-Q214([double]$Value) {
    return [int][Math]::Round($Value * 16384.0, 0, [MidpointRounding]::AwayFromZero)
}
function Get-ResponseDb($Coeff, [double]$Frequency) {
    $angle = -2.0 * [Math]::PI * $Frequency / $fs
    $z = [System.Numerics.Complex]::FromPolarCoordinates(1.0, $angle)
    $b0=$Coeff[0]/16384.0; $b1=$Coeff[1]/16384.0; $b2=$Coeff[2]/16384.0
    $a1=$Coeff[3]/16384.0; $a2=$Coeff[4]/16384.0
    $h = ($b0 + $b1*$z + $b2*$z*$z) / (1.0 + $a1*$z + $a2*$z*$z)
    return 20.0 * [Math]::Log10([Math]::Max($h.Magnitude,1e-15))
}
$rows = foreach($target in $targets) {
    $w = 2.0 * [Math]::PI * $target / $fs
    $gain = (1.0-2.0*$radius*[Math]::Cos($w)+$radius*$radius)/(2.0-2.0*[Math]::Cos($w))
    $c = @(
        (Convert-Q214 $gain),
        (Convert-Q214 (-2.0*$gain*[Math]::Cos($w))),
        (Convert-Q214 $gain),
        (Convert-Q214 (-2.0*$radius*[Math]::Cos($w))),
        (Convert-Q214 ($radius*$radius))
    )
    $targetDb=Get-ResponseDb $c $target
    $passDb=Get-ResponseDb $c 500
    Write-Host ("MODEL target={0} coeff=({1}) target_db={2:F3} pass500_db={3:F3}" -f $target,($c -join ','),$targetDb,$passDb)
    [pscustomobject]@{target_hz=$target;b0_q214=$c[0];b1_q214=$c[1];b2_q214=$c[2];a1_q214=$c[3];a2_q214=$c[4];model_target_db=$targetDb;model_500hz_db=$passDb;pole_radius=$radius}
}
$parent = Split-Path -Parent $Output
if($parent){New-Item -ItemType Directory -Force $parent|Out-Null}
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 -LiteralPath $Output
