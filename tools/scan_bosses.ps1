# Research helper: for every remembrance boss, find the map event that sets its global "defeated"
# flag (91xx, the one that awards the remembrance) and print the useful lines of that event.
param([string]$EventJs = "$PSScriptRoot\..\work\event_js")

$global = [ordered]@{
    9101 = 'Godrick'; 9104 = 'Morgott'; 9107 = 'Hoarah Loux'; 9108 = 'Astel'; 9111 = 'Fortissax'
    9112 = 'Mohg'; 9115 = 'Placidusax'; 9116 = 'Maliketh'; 9118 = 'Rennala'; 9120 = 'Malenia'
    9122 = 'Rykard'; 9123 = 'Elden Beast'; 9130 = 'Radahn'; 9131 = 'Fire Giant'; 9133 = 'Regal Ancestor'
    9140 = 'Dancing Lion'; 9143 = 'Radahn Consort'; 9146 = 'Messmer'; 9148 = 'Putrescent Knight'
    9155 = 'Metyr'; 9156 = 'Midra'; 9160 = 'Romina'; 9162 = 'Scadutree Avatar'; 9164 = 'Gaius'; 9190 = 'Rellana'
}

$files = Get-ChildItem $EventJs -Filter 'm*.js'
foreach ($flag in $global.Keys) {
    "===== $flag $($global[$flag])"
    foreach ($f in $files) {
        $lines = Get-Content $f.FullName -Encoding utf8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch "SetEventFlagID\($flag, ON\)|SetNetworkconnectedEventFlagID\($flag, ON\)") { continue }
            # Walk back to the start of the enclosing event.
            $s = $i; while ($s -gt 0 -and $lines[$s] -notmatch '^\$Event\(') { $s-- }
            $e = $i; while ($e -lt $lines.Count - 1 -and $lines[$e] -ne '});') { $e++ }
            "  $($f.Name):$($s + 1) $($lines[$s])"
            $lines[$s..$e] | ? { $_ -match 'HandleBossDefeat|EventFlag(ID)?\(\d+, ON\)|WaitFor\(|HPRatio|CharacterDead' } | % { "      $($_.Trim())" }
        }
    }
}
