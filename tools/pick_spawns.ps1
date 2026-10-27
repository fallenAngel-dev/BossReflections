# Research helper: pick an arena spawn point per standard boss. Prefers the vanilla post-intro-cutscene
# player position when it lies inside the fight start region, else the start region's center, facing the boss.
param([string]$MsbDir = "$PSScriptRoot\..\work\msb", [string]$Game = 'D:\SteamLibrary\steamapps\common\ELDEN RING\Game')
$msbtool = "$PSScriptRoot\MsbDump\out\MsbDump.exe"
$inv = [Globalization.CultureInfo]::InvariantCulture

# name, map, boss entity, start region, cutscene region (0 = none)
$bosses = @(
    @('Godrick', 'm10_00_00_00', 10000800, 10002800, 10002810), @('Morgott', 'm11_00_00_00', 11000800, 11002800, 11002812),
    @('Hoarah Loux', 'm11_05_00_00', 11050800, 11052800, 11052811), @('Astel', 'm12_04_00_00', 12040800, 12042800, 0),
    @('Mohg', 'm12_05_00_00', 12050800, 12052800, 12052805), @('Maliketh', 'm13_00_00_00', 13000800, 13002800, 0),
    @('Malenia', 'm15_00_00_00', 15000800, 15002800, 15002811), @('Regal Ancestor', 'm12_09_00_00', 12090800, 12092800, 0),
    @('Dancing Lion', 'm20_00_00_00', 20000800, 20002800, 20002811), @('Radahn Consort', 'm20_01_00_00', 20010800, 20012800, 20012811),
    @('Messmer', 'm21_01_00_00', 21010800, 21012800, 21012811), @('Putrescent Knight', 'm22_00_00_00', 22000800, 22002802, 0),
    @('Metyr', 'm25_00_00_00', 25000800, 25002800, 0), @('Midra', 'm28_00_00_00', 28000800, 28002800, 28002810),
    @('Romina', 'm61_44_45_00', 2044450800, 2044452800, 0), @('Scadutree Avatar', 'm61_50_48_00', 2050480800, 2050482800, 0),
    @('Gaius', 'm61_49_48_00', 2049480800, 2049482800, 0), @('Rellana', 'm61_48_44_00', 2048440800, 2048442800, 0)
)

function Get-Pos($lines, $id) {
    $l = $lines | ? { $_ -match "^$id\t" } | Select-Object -First 1
    if (-not $l) { return $null }
    $m = [regex]::Match($l, 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)(?: rot=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\))?')
    [pscustomobject]@{ X = [double]$m.Groups[1].Value; Y = [double]$m.Groups[2].Value; Z = [double]$m.Groups[3].Value; RotY = if ($m.Groups[5].Success) { [double]$m.Groups[5].Value } else { 0 } }
}

Push-Location (Split-Path $msbtool)
foreach ($b in $bosses) {
    $name, $map, $chr, $start, $cut = $b
    $lines = Get-Content "$MsbDir\$map.txt" -Encoding utf8
    $boss = Get-Pos $lines $chr
    $msb = "$Game\map\mapstudio\$map.msb.dcx"
    $pick = $null
    if ($cut) {
        $c = Get-Pos $lines $cut
        $inside = & .\MsbDump.exe inside $msb $start $c.X.ToString($inv) $c.Y.ToString($inv) $c.Z.ToString($inv) | Select-String 'INSIDE'
        if ($inside) { $pick = [pscustomobject]@{ X = $c.X; Y = $c.Y; Z = $c.Z; RotY = $c.RotY; From = "cutscene $cut" } }
    }
    if (-not $pick) {
        $s = Get-Pos $lines $start
        $rot = [math]::Round([math]::Atan2(-($boss.X - $s.X), -($boss.Z - $s.Z)) * 180 / [math]::PI, 2)
        $pick = [pscustomobject]@{ X = $s.X; Y = [math]::Round($s.Y + 0.5, 2); Z = $s.Z; RotY = $rot; From = "start region center" }
    }
    $check = & .\MsbDump.exe inside $msb $start $pick.X.ToString($inv) $pick.Y.ToString($inv) $pick.Z.ToString($inv) | Select-String 'INSIDE|outside' | Select-Object -Last 1
    $dist = [math]::Round([math]::Sqrt(($boss.X - $pick.X) * ($boss.X - $pick.X) + ($boss.Z - $pick.Z) * ($boss.Z - $pick.Z)), 1)
    "{0,-18} {1}  spawn=({2}, {3}, {4}) rotY={5}  from {6}  boss {7} m away  [{8}]" -f $name, $map, $pick.X, $pick.Y, $pick.Z, $pick.RotY, $pick.From, $dist, ($check.Line -replace '.*-> ', '')
}
Pop-Location
