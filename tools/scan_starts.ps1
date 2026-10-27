# Research helper: print the event that enables each boss's AI (its fight start) with its wait conditions.
param([string]$EventJs = "$PSScriptRoot\..\work\event_js")

$bosses = @(
    @('Morgott', 'm11_00_00_00', 11000800), @('Hoarah Loux', 'm11_05_00_00', 11050800),
    @('Astel', 'm12_04_00_00', 12040800), @('Mohg', 'm12_05_00_00', 12050800),
    @('Maliketh', 'm13_00_00_00', 13000800), @('Malenia', 'm15_00_00_00', 15000800),
    @('Regal Ancestor', 'm12_09_00_00', 12090800), @('Dancing Lion', 'm20_00_00_00', 20000800),
    @('Radahn Consort', 'm20_01_00_00', 20010800), @('Messmer', 'm21_01_00_00', 21010800),
    @('Putrescent Knight', 'm22_00_00_00', 22000800), @('Metyr', 'm25_00_00_00', 25000800),
    @('Midra', 'm28_00_00_00', 28000800), @('Romina', 'm61_44_45_00', 2044450800),
    @('Scadutree Avatar', 'm61_50_48_00', 2050480800), @('Gaius', 'm61_49_48_00', 2049480800),
    @('Rellana', 'm61_48_44_00', 2048440800)
)

foreach ($b in $bosses) {
    $name, $map, $chr = $b
    $lines = Get-Content "$EventJs\$map.emevd.dcx.js" -Encoding utf8
    "===== $name ($map)"
    $seen = @{}
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch "EnableCharacterAI\($chr\)|DisplayBossHealthBar\(Enabled, $chr,") { continue }
        $s = $i; while ($s -gt 0 -and $lines[$s] -notmatch '^\$Event\(') { $s-- }
        if ($seen[$s]) { continue }; $seen[$s] = $true
        $e = $i; while ($e -lt $lines.Count - 1 -and $lines[$e] -ne '});') { $e++ }
        "  $($lines[$s])"
        $lines[($s + 1)..$e] | ? { $_ -match 'WaitFor|&=|\|=|EndIf|InArea|EventFlag\(\d+\)|PlayCutscene|EnableCharacterAI|DisplayBossHealthBar|ForceAnimation' } |
            Select-Object -First 18 | % { "      $($_.Trim())" }
    }
}
