# Builds the Boss Reflections mod into .\mod from the vanilla game files and src\:
#   - event\common.emevd.dcx           vanilla common events + src\event\reflections.js + one init per boss
#   - event\<map>.emevd.dcx            boss maps: vanilla events + a "map loaded" marker event per boss
#   - map\mapstudio\<map>.msb.dcx       boss maps: player spawn point inside the boss fog
#   - script\talk\m00_00_00_00.talkesdbnd.dcx   site of grace menu entry + boss list
#   - msg\<lang>\menu*.msgbnd.dcx       menu texts
#   - regulation.bin                    vanilla params + src\param\SpEffectParam.rows.xml
# Bosses come from src\bosses.json.
param(
    [string]$Game = 'D:\SteamLibrary\steamapps\common\ELDEN RING\Game'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$darkscript = 'D:\mods\EldenRing\bin\DarkScript3\DarkScript3.exe'
$esdutil = Join-Path $root 'tools\EsdUtil\out\EsdUtil.exe'
$msbtool = Join-Path $root 'tools\MsbDump\out\MsbDump.exe'
$bossesJson = Join-Path $root 'src\bosses.json'
$mod = Join-Path $root 'mod'
$tmp = Join-Path $root 'work\build'
$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = New-Object Text.UTF8Encoding $false

function Invoke-Tool($exe, [string[]]$arguments) {
    $p = Start-Process $exe -ArgumentList $arguments -WorkingDirectory (Split-Path $exe) -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput "$tmp\out.txt" -RedirectStandardError "$tmp\err.txt"
    $out = Get-Content "$tmp\out.txt", "$tmp\err.txt" -Encoding utf8 -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) { throw "$(Split-Path $exe -Leaf) failed ($($p.ExitCode)):`n$($out -join "`n")" }
    $out
}

$bosses = @((Get-Content $bossesJson -Raw -Encoding utf8 | ConvertFrom-Json).bosses)

Remove-Item $tmp, $mod -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $tmp | Out-Null

# A game installed without Shadow of the Erdtree has no DLC maps: leave those bosses out of the build
# (all tools then use the filtered table). With the DLC installed, the menu still shows DLC bosses only
# when the game reports the DLC as owned (EsdUtil patch-grace).
$missing = @($bosses | ? { -not (Test-Path "$Game\map\mapstudio\$($_.map).msb.dcx") })
if ($missing) {
    Write-Host "Not installed, left out: $(($missing | % key) -join ', ')"
    $bosses = @($bosses | ? { Test-Path "$Game\map\mapstudio\$($_.map).msb.dcx" })
    $bossesJson = "$tmp\bosses.json"
    [IO.File]::WriteAllText($bossesJson, ([ordered]@{ bosses = $bosses } | ConvertTo-Json -Depth 8), $utf8)
}
Write-Host "$($bosses.Count) bosses: $(($bosses | % key) -join ', ')"
New-Item -ItemType Directory -Force "$tmp\emevd", "$tmp\js", "$tmp\compiled", "$tmp\markers\js", "$tmp\markers\compiled",
    "$mod\event", "$mod\script\talk", "$mod\msg", "$mod\map\mapstudio" | Out-Null

# 1. Common events: decompile vanilla common.emevd, add our events and one init line per boss and event.
Copy-Item "$Game\event\common.emevd.dcx" "$tmp\emevd\"
Invoke-Tool $darkscript @('/cmd', '-decompile', '-game', 'er', '-indir', "`"$tmp\emevd`"", '-outdir', "`"$tmp\js`"", '-silent') | Out-Null

$hideSlot = 0; $extraSlot = 0
$init = for ($i = 0; $i -lt $bosses.Count; $i++) {
    $b = $bosses[$i]; $f = $b.flags; $m = $b.mapId -join ', '
    # The spawn point may be in another map than the boss (spawn.map: Fire Giant's entrance fog).
    $sm = if ($b.spawn.map) { ($b.spawn.map.Substring(1) -split '_' | % { [int]$_ }) -join ', ' } else { $m }
    "    // $($b.key)"
    $phase = if ($b.finalPhaseFlag) { $b.finalPhaseFlag } else { $f.active }
    $radius = if ($b.radius) { $b.radius } else { 200 }
    # No fog flag (fight starts on proximity): set our own "loaded" flag instead, which is harmless.
    $fog = if ($b.fogFlag) { $b.fogFlag } else { $f.loaded }
    $delay = if ($b.presenceDelay) { $b.presenceDelay } else { 2 }
    # 7980001 only needs to know there is a prep phase: 1 when it has no fog asset (Metyr, Fortissax).
    $prepAsset = if ($b.prepFog) { if ($b.prepFog.asset) { $b.prepFog.asset } else { 1 } } else { 0 }
    $reset = @($b.resetFlags) + @(0, 0) | ? { $_ -ne $null } | Select-Object -First 2
    "    `$InitializeEvent($i, 7980000, $($f.request), $($f.active), $($f.warping), $($f.loaded), $($f.wasDefeated), $($b.defeatFlag), $($b.finalPhaseFlag), $([int64]$b.clearFlag), $sm, $($b.spawn.entity));"
    "    `$InitializeEvent($i, 7980001, $($f.active), $($f.warping), $($f.loaded), $($f.wasDefeated), $($b.defeatFlag), $($b.anchorEntity), $($b.bossEntity), $($b.nameId), $fog, $([int][bool]$b.fallbackAi), $radius, $delay, $prepAsset);"
    "    `$InitializeEvent($i, 7980002, $($f.active), $($b.defeatFlag));"
    "    `$InitializeEvent($i, 7980003, $($f.active), $($f.warping), $($f.wasDefeated), $($b.defeatFlag), $($b.anchorEntity), $($b.bossEntity), $radius, $m, $($b.exitSpawn));"
    "    `$InitializeEvent($i, 7980004, $($f.active), $($f.warping), $($f.wasDefeated), $($b.defeatFlag));"
    # realDeath: an already defeated boss dies for real (protected victory skipped while wasDefeated is on);
    # otherwise pass requestFlag, which is always off during a reflection.
    $realDeathFlag = if ($b.realDeath) { $f.wasDefeated } else { $f.request }
    "    `$InitializeEvent($i, 7980005, $($f.active), $($f.warping), $($f.wasDefeated), $($b.defeatFlag), $realDeathFlag, $($b.anchorEntity), $($b.bossEntity), $radius, $phase, $($b.banner), $([int]$b.deathAnim), $m, $($b.exitSpawn));"
    "    `$InitializeEvent($i, 7980006, $($f.active), $($f.wasDefeated), $($reset[0]), $($reset[1]));"
    foreach ($e in @($b.hide.characters) | ? { $_ }) { "    `$InitializeEvent($hideSlot, 7980007, $($f.active), $($f.warping), $e);"; $hideSlot++ }
    foreach ($e in @($b.hide.assets) | ? { $_ }) { "    `$InitializeEvent($hideSlot, 7980008, $($f.active), $($f.warping), $e);"; $hideSlot++ }
    foreach ($t in @($b.tempOff) | ? { $_ }) { "    `$InitializeEvent($extraSlot, 7980009, $($f.active), $($t.flag), $($t.value), $($t.saved));"; $extraSlot++ }
    if ($b.giveWeapon) { "    `$InitializeEvent($extraSlot, 7980010, $($f.active), $($f.warping), $($b.giveWeapon.id), $($b.giveWeapon.itemLot), $($b.giveWeapon.given));"; $extraSlot++ }
    foreach ($w in @($b.fogWalls) | ? { $_ }) { "    `$InitializeEvent($extraSlot, 7980011, $($f.active), $($f.warping), $fog, $($w.early), $($w.asset), $($w.sfx));"; $extraSlot++ }
    if ($b.prepFog) { "    `$InitializeEvent($extraSlot, 7980012, $($f.active), $($f.warping), $($f.wasDefeated), $($b.defeatFlag), $fog, $($b.prepFog.region), $([int64]$b.prepFog.arena));"; $extraSlot++ }
    if ($b.prepFog.trigger) { "    `$InitializeEvent($extraSlot, 7980013, $($f.active), $($f.warping), $fog, $($b.prepFog.trigger.entity));"; $extraSlot++ }
}
. (Join-Path $root 'tools\scaling_events.ps1')
$scalingEvents = Get-ScalingEvents $bosses $root
$init += $scalingEvents.init
# TEMPORARY DEBUG: src\event\debug_damage.js (x25 player damage in reflections), included only while it exists.
$debugJs = Join-Path $root 'src\event\debug_damage.js'
$debug = Test-Path $debugJs
if ($debug) {
    Write-Host 'DEBUG: player damage x25 in reflections (src\event\debug_damage.js)'
    $init += for ($i = 0; $i -lt $bosses.Count; $i++) { "    `$InitializeEvent($i, 7980090, $($bosses[$i].flags.active), $($bosses[$i].flags.warping));" }
}
$js = [IO.File]::ReadAllText("$tmp\js\common.emevd.dcx.js")
$anchor = '$Event(0, Default, function() {'
if (-not $js.Contains($anchor)) { throw 'common.emevd: event 0 not found' }
$js = $js.Replace($anchor, $anchor + "`n" + ($init -join "`n"))
$js = $js.TrimEnd() + "`n`n" + [IO.File]::ReadAllText((Join-Path $root 'src\event\reflections.js')) + "`n" + $scalingEvents.js + "`n" + $(if ($debug) { [IO.File]::ReadAllText($debugJs) } else { '' })
[IO.File]::WriteAllText("$tmp\js\common.emevd.dcx.js", $js, $utf8)
Invoke-Tool $darkscript @('/cmd', '-compile', '-game', 'er', '-indir', "`"$tmp\js`"", '-outdir', "`"$tmp\compiled`"") | Out-Null
Copy-Item "$tmp\compiled\common.emevd.dcx" "$mod\event\"
Write-Host "common.emevd: $(@($init | ? { $_ -match 'InitializeEvent' }).Count) init lines"

# 2. Boss maps: "map loaded" marker events (see reflections.js, loadedFlag), merged into the vanilla
#    map emevd without recompiling it. Every variant of the map (e.g. m61_44_45_10) gets them too.
$header = @('// ==EMEVD==', '// @docs    er-common.emedf.json', '// @compress    DCX_KRAK', '// @game    Sekiro',
            '// @string    ""', '// @linked    []', '// @version    3.6.3', '// ==/EMEVD==', '')
$byMap = @{}
for ($i = 0; $i -lt $bosses.Count; $i++) {
    # The boss map, and the spawn point's map if that's another one (whichever loads first marks it).
    $tiles = @($bosses[$i].map.Substring(0, 9)) + @($bosses[$i].spawn.map | ? { $_ } | % { $_.Substring(0, 9) }) | Select-Object -Unique
    foreach ($ev in $tiles | % { Get-ChildItem "$Game\event" -Filter "$_*.emevd.dcx" }) {
        $name = $ev.Name -replace '\.emevd\.dcx$', ''
        # ContainsKey, not -not $byMap[$name]: @(0) (only boss index 0 so far) is falsy and would be reset.
        if (-not $byMap.ContainsKey($name)) { $byMap[$name] = @() }
        $byMap[$name] += $i
    }
}
foreach ($name in $byMap.Keys | Sort-Object) {
    $inits = $byMap[$name] | % { "    `$InitializeEvent(0, $(7989000 + $_));" }
    $events = $byMap[$name] | % {
        "// $($bosses[$_].key): the map's events have started"
        "`$Event($(7989000 + $_), Restart, function() {"
        "    SetEventFlagID($($bosses[$_].flags.loaded), ON);"
        "});"
        ""
    }
    $tjs = ($header + @('$Event(0, Default, function() {') + $inits + @('});', '') + $events) -join "`n"
    Remove-Item "$tmp\markers\js\*", "$tmp\markers\compiled\*" -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText("$tmp\markers\js\$name.emevd.dcx.js", $tjs, $utf8)
    Invoke-Tool $darkscript @('/cmd', '-compile', '-game', 'er', '-indir', "`"$tmp\markers\js`"", '-outdir', "`"$tmp\markers\compiled`"") | Out-Null
    Invoke-Tool $esdutil @('emevd-merge', "`"$Game\event\$name.emevd.dcx`"", "`"$tmp\markers\compiled\$name.emevd.dcx`"",
        "`"$mod\event\$name.emevd.dcx`"") | % { Write-Host "  $_" }
}

# 3. Site of grace menu: one per game language (boss list in that language's alphabetical order) in
#    mod\lang\<lang>; select_language.ps1 (run by the launcher) copies the game's current one into place.
foreach ($lang in Get-ChildItem "$Game\msg" -Directory | ? { $_.Name.Length -eq 5 } | % Name) {
    New-Item -ItemType Directory -Force "$mod\lang\$lang" | Out-Null
    Invoke-Tool $esdutil @('patch-grace', "`"$Game\script\talk\m00_00_00_00.talkesdbnd.dcx`"",
        "`"$mod\lang\$lang\m00_00_00_00.talkesdbnd.dcx`"", "`"$bossesJson`"", "`"$Game\msg`"", $lang) |
        Select-String 'verified|menu order (engus|rusru)' | % { Write-Host $_.Line }
}
& "$root\select_language.ps1" -Game $Game

# 4. Menu texts.
Invoke-Tool $esdutil @('patch-msg', "`"$Game\msg`"", "`"$mod\msg`"", "`"$bossesJson`"") | Select-String 'rusru|engus' | % { Write-Host $_.Line }

# 5. Maps: arena spawn points, and for map variants without the boss (bosses.json "variants") the boss's
#    entities copied from the boss map first. Several changes to one map are applied one after another.
function Get-MapInput($map) {
    $out = "$mod\map\mapstudio\$map.msb.dcx"
    if (-not (Test-Path $out)) { return "$Game\map\mapstudio\$map.msb.dcx" }
    $in = "$tmp\$map.msb.dcx"; Move-Item $out $in -Force; $in
}
foreach ($b in $bosses) {
    $s = $b.spawn
    if ($s.existing) { Write-Host "  $($b.map): uses existing spawn point $($s.entity)"; continue }
    $targets = @($(if ($s.map) { $s.map } else { $b.map })) + @($b.variants | ? { $_ } | % { $_.map })
    foreach ($map in $targets) {
        $variant = $b.variants | ? { $_.map -eq $map }
        if ($variant) {
            $in = Get-MapInput $map
            $r = Invoke-Tool $msbtool (@('copy-entities', "`"$Game\map\mapstudio\$($b.map).msb.dcx`"", "`"$in`"", "`"$mod\map\mapstudio\$map.msb.dcx`"") + @($variant.copy | % { "$_" }))
            if (-not ($r | Select-String 'verified')) { throw "copy into $map for $($b.key): $r" }
            Write-Host "  ${map}: copied $($variant.copy.Count) entities of $($b.key) from $($b.map)"
        }
        $in = Get-MapInput $map
        $out = "$mod\map\mapstudio\$map.msb.dcx"
        # spawn.cloneMap: the map has no player spawn point to copy (Radahn's m60_51_38).
        $cloneFrom = if ($s.cloneMap) { @("`"$Game\map\mapstudio\$($s.cloneMap).msb.dcx`"") } else { @() }
        $r = Invoke-Tool $msbtool (@('add-player', "`"$in`"", "`"$out`"", $s.clone, $s.entity,
            ([double]$s.x).ToString($inv), ([double]$s.y).ToString($inv), ([double]$s.z).ToString($inv), ([double]$s.rotY).ToString($inv)) + $cloneFrom)
        if (-not ($r | Select-String 'verified')) { throw "spawn for $($b.key) in ${map}: $r" }
        Write-Host "  ${map}: $(($r | Select-String 'added').Line)"
        # Spawn in front of the fog: the "still at the fog" region around it (event 7980012).
        if ($b.prepFog) {
            $in = Get-MapInput $map
            # Centred on the spawn, or on prepFog.center (Radagon: the middle of the way to him).
            $c = if ($b.prepFog.center) { $b.prepFog.center } else { @($s.x, $s.y, $s.z) }
            $r = Invoke-Tool $msbtool (@('add-region', "`"$in`"", "`"$out`"", $b.prepFog.clone, $b.prepFog.region,
                ([double]$c[0]).ToString($inv), ([double]$c[1]).ToString($inv), ([double]$c[2]).ToString($inv), ([double]$b.prepFog.radius).ToString($inv)) +
                @($b.prepFog.height | ? { $_ } | % { ([double]$_).ToString($inv) }))
            if (-not ($r | Select-String 'verified')) { throw "prep region for $($b.key) in ${map}: $r" }
            Write-Host "  ${map}: $(($r | Select-String 'added').Line)"
            # The "begin the battle" asset (event 7980013).
            if ($b.prepFog.trigger) {
                $tr = $b.prepFog.trigger
                $in = Get-MapInput $map
                $r = Invoke-Tool $msbtool @('add-asset', "`"$in`"", "`"$out`"", $tr.clone, $tr.entity,
                    ([double]$tr.x).ToString($inv), ([double]$tr.y).ToString($inv), ([double]$tr.z).ToString($inv))
                if (-not ($r | Select-String 'verified')) { throw "trigger asset for $($b.key) in ${map}: $r" }
                Write-Host "  ${map}: $(($r | Select-String 'added').Line)"
            }
        }
    }
}

# Every changed map: region / player ids must stay unique (a duplicate RegionID crashed Midra's map).
foreach ($f in Get-ChildItem "$mod\map\mapstudio" -Filter *.msb.dcx) {
    $r = Invoke-Tool $msbtool @('check-ids', "`"$($f.FullName)`"")
    if (-not ($r | Select-String 'ids ok')) { throw "$($f.Name): $($r -join "`n")" }
}

# 6. Params: our rows (src\param\<ParamName>.rows.xml) added to the vanilla regulation.bin one param after
#    another (the tool checks vanilla rows stay identical).
$defs = 'D:\mods\EldenRing\bin\WitchyBND\Assets\Paramdex\ER\Defs'
$paramDef = @{ SpEffectParam = 'SpEffect.xml'; ItemLotParam_map = 'ItemLotParam.xml'; ActionButtonParam = 'ActionButtonParam.xml' }
$regIn = "$Game\regulation.bin"
foreach ($rows in Get-ChildItem "$root\src\param" -Filter *.rows.xml) {
    $name = ($rows.Name -split '\.')[0]
    if (-not $paramDef[$name]) { throw "no paramdef known for $name" }
    $regOut = "$tmp\regulation.$($rows.BaseName).bin"
    Invoke-Tool $msbtool @('reg-add-rows', "`"$regIn`"", "`"$regOut`"", $name, "`"$defs\$($paramDef[$name])`"", "`"$($rows.FullName)`"") |
        % { Write-Host "regulation.bin: $_" }
    $regIn = $regOut
}
Copy-Item $regIn "$mod\regulation.bin"

Write-Host "`nBuilt into $mod ($((Get-ChildItem $mod -Recurse -File).Count) files)"
