# Research helper: arena details for each remembrance boss (fog event, BGM event, health bar,
# post-cutscene warp regions, AI enable), straight from the decompiled map events.
param([string]$EventJs = "$PSScriptRoot\..\work\event_js")

# name, map file, boss entity, defeat flag
$bosses = @(
    @('Godrick', 'm10_00_00_00', 10000800, 10000800), @('Morgott', 'm11_00_00_00', 11000800, 11000800),
    @('Hoarah Loux', 'm11_05_00_00', 11050800, 11050800), @('Astel', 'm12_04_00_00', 12040800, 12040800),
    @('Fortissax', 'm12_03_00_00', 12030850, 12030850), @('Mohg', 'm12_05_00_00', 12050800, 12050800),
    @('Placidusax', 'm13_00_00_00', 13000830, 13000830), @('Maliketh', 'm13_00_00_00', 13000800, 13000800),
    @('Rennala', 'm14_00_00_00', 14000800, 14000800), @('Malenia', 'm15_00_00_00', 15000800, 15000800),
    @('Rykard', 'm16_00_00_00', 16000800, 16000800), @('Elden Beast', 'm19_00_00_00', 19000800, 19000800),
    @('Radahn', 'm60_52_38_00', 1052380800, 1252380800), @('Fire Giant', 'm60_52_52_00', 1052520800, 1252520800),
    @('Regal Ancestor', 'm12_09_00_00', 12090800, 12090800), @('Dancing Lion', 'm20_00_00_00', 20000800, 20000800),
    @('Radahn Consort', 'm20_01_00_00', 20010800, 20010800), @('Messmer', 'm21_01_00_00', 21010800, 21010800),
    @('Putrescent Knight', 'm22_00_00_00', 22000800, 22000800), @('Metyr', 'm25_00_00_00', 25000800, 25000800),
    @('Midra', 'm28_00_00_00', 28000800, 28000800), @('Romina', 'm61_44_45_00', 2044450800, 2044450800),
    @('Scadutree Avatar', 'm61_50_48_00', 2050480800, 2050480800), @('Gaius', 'm61_49_48_00', 2049480800, 2049480800),
    @('Rellana', 'm61_48_44_00', 2048440800, 2048440800)
)

foreach ($b in $bosses) {
    $name, $map, $chr, $flag = $b
    $path = "$EventJs\$map.emevd.dcx.js"
    "===== $name  map=$map  chr=$chr  defeat=$flag"
    $lines = Get-Content $path -Encoding utf8
    $lines | ? { $_ -match "InitializeCommonEvent\(\d+, 900580[0-9], $flag," -or $_ -match "InitializeCommonEvent\(\d+, 900582\d, $flag," } | % { "  common: $($_.Trim())" }
    $lines | ? { $_ -match "DisplayBossHealthBar\(Enabled, $chr," } | Select-Object -Unique | % { "  hpbar: $($_.Trim())" }
    $lines | ? { $_ -match "EnableCharacterAI\($chr\)" } | Select-Object -First 2 | % { "  ai: $($_.Trim())" }
    $lines | ? { $_ -match 'PlayCutsceneToPlayerAndWarp' } | Select-Object -First 4 | % { "  cutscene: $($_.Trim())" }
    $lines | ? { $_ -match '&= EventFlag\(\d+\) && InArea\(10000, \d+\)' } | Select-Object -First 3 | % { "  start: $($_.Trim())" }
}
