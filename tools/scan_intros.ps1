# Research helper: for each boss, the fight start event's first-encounter branch ("if (!EventFlag(N))")
# that plays an intro cutscene: the intro flag N and what that branch waits for.
param([string]$EventJs = "$PSScriptRoot\..\work\event_js", [string]$BossesJson = "$PSScriptRoot\..\src\bosses.json")

$bosses = (Get-Content $BossesJson -Raw -Encoding utf8 | ConvertFrom-Json).bosses
foreach ($b in $bosses) {
    $found = $false
    foreach ($f in Get-ChildItem $EventJs -Filter "$($b.map.Substring(0, 9))*.emevd.dcx.js") {
        $l = Get-Content $f.FullName -Encoding utf8
        for ($i = 0; $i -lt $l.Count; $i++) {
            if ($l[$i] -notmatch '^\$Event\(') { continue }
            $e = $i; while ($e -lt $l.Count - 1 -and $l[$e] -ne '});') { $e++ }
            $body = $l[$i..$e]
            # Fight start events: enable the anchor/boss AI (or group AI) and play a cutscene.
            if (-not ($body -match 'PlayCutsceneToPlayerAndWarp')) { continue }
            if (-not ($body -match "DisableCharacterAI\(($($b.anchorEntity)|$($b.bossEntity)|\d+5800|\d+5850)\)")) { continue }
            $branch = $body | Select-String -Pattern 'if \(!EventFlag\((\d+)\)\) \{' | Select-Object -First 1
            if (-not $branch) { continue }
            $flag = $branch.Matches[0].Groups[1].Value
            $start = $branch.LineNumber
            $waits = $body[($start)..([Math]::Min($start + 25, $body.Count - 1))] | ? { $_ -match 'WaitFor|InArea|EntityInRadius|PlayCutscene' } | Select-Object -First 5 | % { $_.Trim() }
            ("{0,-20} {1} intro={2}  " -f $b.key, $f.Name.Substring(0, 12), $flag) + $l[$i].Trim()
            $waits | % { "      $_" }
            $found = $true
        }
    }
    if (-not $found) { "{0,-20} (no intro cutscene branch found)" -f $b.key }
}
