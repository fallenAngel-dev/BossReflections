# Research helper: map data for the standard fog-arena bosses (entry region, post-cutscene warp regions,
# boss position, existing player spawn points) from MsbDump outputs in work\msb.
param([string]$MsbDir = "$PSScriptRoot\..\work\msb")

# name, map, boss entity, entry region, cutscene warp regions
$bosses = @(
    @('Godrick', 'm10_00_00_00', 10000800, 10002800, @(10002810)),
    @('Morgott', 'm11_00_00_00', 11000800, 11002800, @(11002812)),
    @('Hoarah Loux', 'm11_05_00_00', 11050800, 11052800, @(11052811)),
    @('Astel', 'm12_04_00_00', 12040800, 12042800, @()),
    @('Mohg', 'm12_05_00_00', 12050800, 12052800, @(12052805)),
    @('Maliketh', 'm13_00_00_00', 13000800, 13002800, @(13002820)),
    @('Malenia', 'm15_00_00_00', 15000800, 15002800, @(15002811)),
    @('Regal Ancestor', 'm12_09_00_00', 12090800, 12092800, @()),
    @('Fire Giant', 'm60_52_52_00', 1052520800, 1052532800, @(1052522810)),
    @('Dancing Lion', 'm20_00_00_00', 20000800, 20002800, @(20002811)),
    @('Radahn Consort', 'm20_01_00_00', 20010800, 20012800, @(20012811)),
    @('Messmer', 'm21_01_00_00', 21010800, 21012800, @(21012811)),
    @('Putrescent Knight', 'm22_00_00_00', 22000800, 22002800, @()),
    @('Metyr', 'm25_00_00_00', 25000800, 25002800, @()),
    @('Midra', 'm28_00_00_00', 28000800, 28002800, @(28002810)),
    @('Romina', 'm61_44_45_00', 2044450800, 2044452800, @()),
    @('Scadutree Avatar', 'm61_50_48_00', 2050480800, 2050482800, @()),
    @('Gaius', 'm61_49_48_00', 2049480800, 2049482800, @()),
    @('Rellana', 'm61_48_44_00', 2048440800, 2048442800, @())
)

foreach ($b in $bosses) {
    $name, $map, $chr, $entry, $cuts = $b
    $lines = Get-Content "$MsbDir\$map.txt" -Encoding utf8
    "===== $name ($map)"
    $lines | ? { $_ -match "^$entry\t" } | % { "  entry:   $_" }
    foreach ($c in $cuts) { $lines | ? { $_ -match "^$c\t" } | % { "  cut:     $_" } }
    $lines | ? { $_ -match "^$chr\t" } | % { "  boss:    $_" }
    $players = $lines | ? { $_ -match '^\d+\tc0000_' -and $_ -notmatch '^0\t' }
    "  players: $($players.Count) with entity ids, e.g. " + (($players | Select-Object -First 3 | % { ($_ -split "`t")[0] }) -join ', ')
}
