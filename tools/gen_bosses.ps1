# One-off generator for src\bosses.json from the research data (scan_*.ps1 / pick_spawns.ps1 / map dumps).
# After generation bosses.json is the source of truth; rerun only to regenerate from scratch.
# Needs MsbDump outputs for every boss map in work\msb and the decompiled vanilla events in work\event_js.
param([string]$MsbDir = "$PSScriptRoot\..\work\msb", [string]$EventJs = "$PSScriptRoot\..\work\event_js",
      [string]$Out = "$PSScriptRoot\..\src\bosses.json")

# Menu order = this order (base game roughly by progression, then the DLC).
# key, map, boss entity (last phase), defeat flag, health bar / menu name id, fog flag (0 = none: the fight
# starts on proximity), start region (0 = none), spawn (x, y, z, rotY), fallback AI (also enable the boss
# AI ourselves; only single-entity bosses whose start region alone starts the fight)
$data = @(
    @('godrick', 'm10_00_00_00', 10000800, 10000800, 904750000, 10002805, 10002800, @(-205.17, 82, 316.64, 141.26), $true),
    @('rennala', 'm14_00_00_00', 14000800, 14000800, 902030000, 14002805, 14002800, @(89.27, 154.41, -43.63, 112.42), $false),
    @('radahn', 'm60_52_38_00', 1052380800, 1252380800, 904730000, 1052382805, 0, @(-44.11, 33.66, -43.94, -163.04), $false),
    @('rykard', 'm16_00_00_00', 16000800, 16000800, 904710001, 16002805, 16002801, @(94.68, -439.0, -80.97, 1.5), $false),
    @('morgott', 'm11_00_00_00', 11000800, 11000800, 902130002, 11002805, 11002800, @(6.24, 65.28, -375.89, -37.72), $false),
    @('fire_giant', 'm60_52_52_00', 1052520800, 1252520800, 904760000, 1252522805, 0, @(80.95, 1850.11, 70.03, -44.86), $false),
    @('regal_ancestor', 'm12_09_00_00', 12090800, 12090800, 904670001, 12092805, 12092800, @(1214.64, -1537.9, 1820.89, 161.27), $true),
    @('astel', 'm12_04_00_00', 12040800, 12040800, 904620001, 12042805, 12042800, @(-104.06, -105.98, -239.64, -177.12), $true),
    @('mohg', 'm12_05_00_00', 12050800, 12050800, 904800000, 12052805, 12052800, @(1610.67, -507.73, 1207.29, 114.78), $true),
    @('fortissax', 'm12_03_00_00', 12030850, 12030850, 904510000, 12032859, 0, @(-472.48, 149.89, -323.53, 210), $false),
    @('maliketh', 'm13_00_00_00', 13000800, 13000800, 902110001, 13002805, 13002800, @(137.45, -32.54, 394.07, -71.85), $false),
    @('placidusax', 'm13_00_00_00', 13000830, 13000830, 904520000, 0, 13002831, @(-95.37, 1009.76, 295.76, -107.84), $false),
    @('hoarah_loux', 'm11_05_00_00', 11050800, 11050800, 904720001, 11052805, 11052800, @(6.86, 65.28, -376.37, -33.58), $false),
    @('malenia', 'm15_00_00_00', 15000800, 15000800, 902120000, 15002805, 15002800, @(42.38, 53.12, 518.06, 49.83), $false),
    @('radagon_elden_beast', 'm19_00_00_00', 19000800, 19000800, 902200000, 19002801, 19002800, @(182.43, 102.81, -618.7, -72.33), $false),
    # Radagon alone: the win counts on Radagon (19000810), so his death (and the Elden Beast) never comes.
    @('radagon', 'm19_00_00_00', 19000810, 19000800, 902190000, 19002801, 19002800, @(182.43, 102.81, -618.7, -72.33), $false),
    # Elden Beast alone: spawn on the lower platform; the "fog flag" is "Radagon defeated" (19002802), which
    # makes the vanilla events play the transition cutscene and start the Elden Beast.
    @('elden_beast', 'm19_00_00_00', 19000800, 19000800, 902200000, 19002802, 0, @(206.03, -719.49, -670.68, -25.83), $false),
    @('margit', 'm10_00_00_00', 10000850, 10000850, 902130000, 10002855, 10002850, @(18.22, -6.8, -12.03, 81.8), $false),
    @('godskin_duo', 'm13_00_00_00', 13000850, 13000850, 903575000, 13002855, 13002850, @(-1.24, -38.58, 390.85, -123.8), $false),
    # Loretta: the fog region 15002850 is a thin strip inside the fog wall, below ground level; spawn in
    # the first-fight region 15002851 instead (clearFlag below makes vanilla use that branch).
    @('loretta', 'm15_00_00_00', 15000850, 15000850, 903252000, 15002855, 15002851, @(149.06, 432.3, 221.24, -163.7), $false),
    @('dancing_lion', 'm20_00_00_00', 20000800, 20000800, 905210000, 20002805, 20002800, @(-56.23, 118.12, 292.08, -162.6), $true),
    @('rellana', 'm61_48_44_00', 2048440800, 2048440800, 905300000, 2048442805, 2048442800, @(-57.93, 427.24, 17.65, -175.34), $true),
    @('gaius', 'm61_49_48_00', 2049480800, 2049480800, 905000000, 2049482805, 2049482800, @(49.33, 583.52, -44.44, -148.39), $false),
    @('scadutree_avatar', 'm61_50_48_00', 2050480800, 2050480800, 905230000, 2050482805, 2050482800, @(-75.95, 190.63, 19.17, 87.63), $false),
    # Putrescent Knight: the start region is a 100 m cylinder whose base is ~5 m below the arena floor;
    # spawn on the patrol point 22002803 (patrol points sit on the ground), facing the knight.
    @('putrescent_knight', 'm22_00_00_00', 22000800, 22000800, 905020000, 22002805, 22002802, @(-65.65, -294.27, 110.3, 59.4), $false),
    @('romina', 'm61_44_45_00', 2044450800, 2044450800, 905030000, 2044452805, 2044452800, @(-48.05, 625.46, 170.58, 10.13), $true),
    @('messmer', 'm21_01_00_00', 21010800, 21010800, 905130000, 21012805, 21012800, @(95.59, 351.77, 323.67, 165.45), $false),
    @('midra', 'm28_00_00_00', 28000800, 28000800, 905051000, 28002805, 28002800, @(-9.19, 16.21, -73.2, -4.44), $false),
    # Metyr: the start region is a 61 m sphere around her; spawn ~30 m away (towards the vanilla arrival point).
    @('metyr', 'm25_00_00_00', 25000800, 25000800, 905200000, 25002805, 25002800, @(35.0, 0.52, -0.6, 86.6), $true),
    @('bayle', 'm61_54_39_00', 2054390800, 2054390800, 905120000, 2054392805, 2054392800, @(84.43, 954.21, 75.02, -37.61), $false),
    @('radahn_consort', 'm20_01_00_00', 20010800, 20010800, 905220000, 20012805, 20012800, @(-211.79, 299.33, -180.81, 119.18), $false)
)

# Character present from the start of the fight (phase-one character for bosses whose last-phase
# character only appears later); used with bossEntity for "player is at the boss" checks.
$anchors = @{ rennala = 14000801; rykard = 16000801; fire_giant = 1052520801; maliketh = 13000801
              hoarah_loux = 11050801; radagon_elden_beast = 19000810; radahn_consort = 20010801; messmer = 21010801
              midra = 28000801; scadutree_avatar = 2050480802; godskin_duo = 13000851 }

# Menu text instead of the boss's health bar name; other languages: the NpcName texts of menuNameIds joined
# with " & " (Radagon of the Golden Order & Elden Beast).
$menuNameIds = @{ radagon_elden_beast = @(902190000, 902200000) }
$menuText = @{ radagon_elden_beast = [ordered]@{ engus = 'Radagon and the Elden Beast'; rusru = 'Радагон и Зверь Элдена' } }

# Banner for bosses without a vanilla defeat banner of their own.
$bannerOverride = @{ radagon = 27 }

# No boss dies for real any more (bosses.json realDeath false for all): a real death awards the boss's
# runes even with our "no runes" SpEffect (Godrick), and some vanilla defeat events set the respawn point /
# warp (Rennala, Morgott), play a cutscene with a warp (Fortissax), award items (Regal Ancestor), start the
# Elden Beast (Radagon) or the ending (Elden Beast). Every boss gets the protected victory.

# Vanilla flags turned off for the duration of the reflection and put back to their previous state after
# (event 7980009). Intro cutscene "already seen" flags, so the intro plays in every reflection. Messmer:
# his intro plays when the door to his chamber is opened (ObjAct 21013542; 21018542 = door already opened). Elden Beast: "ending reached" (19000804), which
# with the player on the lower platform makes the map replay the ending and set the respawn point there.
$tempOff = @{
    godrick = @(10000801); rennala = @(14000801); morgott = @(11000801); mohg = @(12050801)
    hoarah_loux = @(11050801); malenia = @(15000801); margit = @(10000851); dancing_lion = @(20000801)
    radahn_consort = @(20010801); messmer = @(21010801, 21018542); elden_beast = @(19000804); radagon_elden_beast = @(19000804, 19002801); radagon = @(19002801)
}

# Weapon given for the reflection if the player doesn't have it, taken back afterwards (event 7980010).
# Rykard: the Serpent-Hunter (its corpse in the arena only gives it once).
$giveWeapon = @{ rykard = @(17030000, 7980000) }   # weapon id, our item lot (src\param\ItemLotParam_map.rows.xml)

# Map variants the game may load instead of the boss map, and the entities to copy into them from the
# boss map (they lack the boss). Romina: depending on the world state the game loads m61_44_45_10, which
# has the same events but not Romina, her fogs, her start region and helper objects.
$variants = @{
    romina = @([ordered]@{ map = 'm61_44_45_10'; copy = @(2044450800, 2044450820, 2044451800, 2044451801, 2044451820, 2044452800, 2044452820) })
}

# Vanilla "fight already started once" flag cleared before the warp, so the fight starts from the spawn
# point's region (Loretta: otherwise the fight waits for the player inside the fog region).
$clearFlag = @{ loretta = 15000851 }

# Death animation for the protected victory: the first of these the boss model has (FromSoft's death
# animations are a000_0060xx); 0 when it has none (playing 0 just interrupts the current attack).
$esdutil = "$PSScriptRoot\EsdUtil\out\EsdUtil.exe"
$chrDir = 'D:\SteamLibrary\steamapps\common\ELDEN RING\Game\chr'
function Get-DeathAnim($chr) {
    $line = Get-ChildItem $MsbDir -Filter *.txt | Select-String -Pattern "^$chr\t.*model=(c\d{4})" | Select-Object -First 1
    if (-not $line) { return 0 }
    $files = @(Get-ChildItem $chrDir -Filter "$($line.Matches[0].Groups[1].Value)*.anibnd.dcx" | % FullName)
    $have = (& $esdutil anims '_006\d{3}$' @files) -replace '^[^:]+: ?', '' -split ' ' | ? { $_ } | % { [int]$_.Substring(5) }
    foreach ($a in 6001, 6002, 6000, 6003) { if ($have -contains $a) { return $a } }
    0
}

# Flag that is only on in the boss's last phase, for bosses whose last-phase character drops to 1 HP
# before that (Malenia: phase one ends at 1 HP, then flag 15002802).
$finalPhase = @{ malenia = 15002802 }

# Existing vanilla player spawn points used as the arena spawn (no new one added to the map):
# Radahn: the battlefield's return point.
$existingSpawn = @{}

# Radius of the "player is at the boss" checks (default 200 m). Radahn flies far over his battlefield.
$radius = @{ radahn = 600; fire_giant = 300; putrescent_knight = 600; radagon = 300; radagon_elden_beast = 300 }

# Seconds the arrival waits for the boss to show up (default 2). Fortissax appears after the dream cutscene.
$presenceDelay = @{ fortissax = 60; elden_beast = 60 }

# Vanilla progress flags the reflection turns on that must go back off afterwards if the boss wasn't
# defeated in the world (Fortissax: "in Fia's dream" and "fight started").
$resetFlags = @{ fortissax = @(12032859, 12032858) }

# Characters / assets to hide during the reflection besides the map's graces (which are found below):
# things vanilla shows for a defeated boss through flags the reflection doesn't touch.
# Rennala: her NPC form (respec), shown on the global defeat flag 9118.
# Elden Beast: Marika's broken body and the ending choice interaction points, shown on the ending flag.
$hideExtra = @{
    rennala = @{ characters = @(14000700, 14000701) }
    radagon_elden_beast = @{ characters = @(19000700, 19000710, 19000130); assets = @(19001100, 19001101, 19001110, 19001120, 19001130) }
    radagon = @{ characters = @(19000700, 19000710, 19000130); assets = @(19001100, 19001101, 19001110, 19001120, 19001130) }
    elden_beast = @{ characters = @(19000700, 19000710, 19000130); assets = @(19001100, 19001101, 19001110, 19001120, 19001130) }
    # Radahn: the warp point back to Redmane Castle (common_func 90005646, shown after his defeat).
    radahn = @{ assets = @(1052381690) }
}

# Fog walls forced on after arrival (event 7980011), because vanilla (common_func 9005811) shows some only
# with other flags on (Morgott: 11000501; Scadutree Avatar: "first fight started" 2050480801; intro
# flags): every 9005811 fog wall of the boss's defeat flag, plus any 9005811 on its entry fog asset.
$fogInits = foreach ($f in Get-ChildItem $EventJs -Filter 'm*.emevd.dcx.js') {
    foreach ($m in (Select-String $f.FullName -Pattern 'InitializeCommonEvent\(\d+, 9005811, (\d+), (\d+), (\d+), (\d+)\)').Matches) {
        [pscustomobject]@{ map = $f.Name.Substring(0, 9); flag = [int64]$m.Groups[1].Value; asset = [int64]$m.Groups[2].Value; sfx = [int]$m.Groups[3].Value }
    }
}

# Spare flags for event 7980009/7980010 state: x960..x969 of the boss's defeat flag block, skipping any
# number the vanilla event scripts use.
$vanillaNumbers = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($f in Get-ChildItem $EventJs -Filter *.js) {
    foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), '\b\d{7,10}\b')) { [void]$vanillaNumbers.Add($m.Value) }
}
$spareUsed = @{}
function New-SpareFlag($defeat) {
    $base = [int64]$defeat - ([int64]$defeat % 1000)
    foreach ($o in 960..969) {
        $id = $base + $o
        if (-not $vanillaNumbers.Contains("$id") -and -not $spareUsed["$id"]) { $spareUsed["$id"] = $true; return $id }
    }
    throw "no spare flag left in block $base"
}

# The boss map's graces (common_func 9005810: flag, bonfire flag, grace character, grace asset). Some
# arena graces depend on other flags than the boss's (Radahn: 310), so all of them are hidden.
function Get-Graces($map) {
    $c = @(); $a = @()
    foreach ($f in Get-ChildItem $EventJs -Filter "$($map.Substring(0, 9))*.emevd.dcx.js") {
        foreach ($m in (Select-String $f.FullName -Pattern 'InitializeCommonEvent\(\d+, 9005810, -?\d+, -?\d+, (\d+), (\d+),').Matches) {
            $c += [int64]$m.Groups[1].Value; $a += [int64]$m.Groups[2].Value
        }
    }
    @{ characters = @($c | Select-Object -Unique); assets = @($a | Select-Object -Unique) }
}

# Banner of the vanilla defeat event (HandleBossDefeatAndDisplayBanner), shown on a protected win.
$bannerValues = @{ LegendFelled = 15; DemigodFelled = 16; GreatEnemyFelled = 17; EnemyFelled = 18; GodSlain = 27 }
function Get-Banner($map, $chr) {
    $l = Select-String "$EventJs\$map.emevd.dcx.js" -Pattern "HandleBossDefeatAndDisplayBanner\($chr, TextBannerType\.(\w+)\)" | Select-Object -First 1
    if (-not $l) { throw "no defeat banner for $chr in $map" }
    $bannerValues[$l.Matches[0].Groups[1].Value]
}

# Bosses that keep their arena spawn although they have a fog wall: the Elden Beast alone starts on the
# lower platform, far from the fog.
$insideSpawn = @('elden_beast')

# Region giving the "into the arena" direction from the fog instead of the 9005800 one (Loretta's is a
# thin strip inside the fog wall itself).
$fogDirRegion = @{ loretta = 15002851 }

# Fog walls not forced on (vanilla shows them itself at the right moment): the Putrescent Knight walks
# out through 22001801 on his entrance, vanilla enables it after that. Radagon: the player starts inside the
# tree past the fog, vanilla closes it when the fight starts.
$noFogWalls = @('putrescent_knight', 'radagon', 'radagon_elden_beast')

# Map events that are copies of 9005800 (the fog entry), per boss.
$fogEventCopy = @{ rykard = 16002846 }

# Fog entries that set the fog flag only once the player walked up to the boss after the fog (Rykard's copy:
# within 40 m of him, ~80 m from the fog): their prep region spans the way to the boss, like a first-time start.
$walkToBoss = @('rykard')

# Spawn in front of a fog wall that is in another map than the boss (the generic code above only looks in
# the boss map): map, spawn (x, y, z, rotY in that map), fog asset, region to clone for the prep region,
# entity id base of that map. Fire Giant: the fight's entrance fog 1052531800 and its region 1052532800
# are in m60_52_53_00 (the fog's position from the big tile m60_13_13_02, (-364.87, 1809.44, -144.15),
# minus the tile offset (-384, -128)); 2.5 m in front of it, facing it, ~200 m from the giant (the fight
# starts on its own within 120 m).
# Hand-placed spawns (the generic fog code above doesn't apply), all keys optional except sp:
#   map, entityBase   another map than the boss's, and the entity id base there
#   cloneMap, clone   player spawn point to copy when that map has none
#   fog               prep: the fog wall the player walks through (0 = none: the fight starts on its own
#                     when the player walks in); with prep the arrival doesn't start the fight
#   regionClone, radius  the prep region (leaving it before the fight started ends the reflection),
#   regionCenter      centred there instead of on the spawn
#   regionHeight      a vertical cylinder of that height (regionCenter = its base) instead of a sphere
#   arenaRegion       reaching it before the fight started starts it (sets fogFlag; event 7980012)
#   triggerAsset      prep: an asset added to the map (copy of clone, at x/y/z) the player "examines" (our
#                     action button) to start the fight (sets fogFlag)
# Radahn: the vanilla arrival from Redmane Castle's waygate (region 1051382300 in m60_51_38, a map without
#   player spawn points), ~205 m from him; vanilla starts the fight right on arrival (fogFlag 1052382805).
# Metyr: the vanilla arrival point (region 25002600), ~77 m away, outside the 61 m start sphere.
# Fortissax: vanilla enters the dream through Fia's dialogue; here a "Begin the battle" prompt on an asset
#   we add 23 m from the Prince of Death's throne starts the dream (flag 12032859). Not closer: entering the
#   15 m sphere 12032801 around the throne starts Fia's champions' fight if they're not beaten; the prep
#   radius is 8 m to keep the player out of it.
# Putrescent Knight: after the top fog (22001800) vanilla walks ~85 m to the drop and the fight starts on
#   landing in the arena 490 m below (fogFlag && region 22002802). Spawn 2.5 m before the top fog (tested
#   to be on the ground; regions 22002800/22002801 put the player in the rock / over the void). Prep: the
#   fight counts as started once vanilla sets fogFlag (passing the top fog, or reaching the drop region
#   22002801 on a first fight); before that, leaving a 55 m cylinder around the way from the spawn to the
#   drop ends the reflection. The cylinder reaches from the arena floor (y -320) up past the spawn
#   (+560 m), so the jump itself never leaves it. Radius 600 covers the fall for the other checks.
# Radagon (alone and with the Elden Beast): the fog 19001800 stands where m19 meets Leyndell (m11_05),
#   whose floor isn't loaded when warping into m19 (the fog-front spawn was inside the geometry). Spawn
#   on the vanilla player point before the tree (84.16, 79.06, -477.32), ~190 m before Radagon. The fight
#   starts within 20 m of him (vanilla sets 19002801 then): that's the "fog flag" for these entries (so
#   the arrival doesn't set the real one, which started the boss music), turned off for the reflection
#   (tempOff) so it marks this fight's start. Prep region: a 110 m sphere around the middle of the way
#   to Radagon (regionCenter) instead of around the spawn.
$prepElsewhere = @{
    fire_giant = @{ map = 'm60_52_53_00'; sp = @(17.29, 1809.94, -14.45, -47.2); fog = 1052531800; regionClone = 1052532800; radius = 12; entityBase = 1052530000 }
    radahn = @{ map = 'm60_51_38_00'; sp = @(20.59, 13.7, -110.18, -116.34); entityBase = 1051380000; cloneMap = 'm60_52_53_00'; clone = 1052530980 }
    metyr = @{ sp = @(85.22, 0.52, 4.02, 85.5); fog = 0; regionClone = 25002800; radius = 25 }
    fortissax = @{ sp = @(-374.63, 149.88, -180.93, -11.3); fog = 0; regionClone = 12032805; radius = 8
                   triggerAsset = @{ clone = 12031810; x = -374.14; y = 149.38; z = -183.38 } }
    putrescent_knight = @{ sp = @(-19.3, 215.82, 213.35, 26.64); fog = 0; regionClone = 22002800; radius = 55; regionCenter = @(-37.0, -320, 172.6); regionHeight = 560; arenaRegion = 22002802 }
    radagon = @{ sp = @(84.16, 79.56, -477.32, -36.32); fog = 0; regionClone = 19002800; radius = 110; regionCenter = @(140.85, 90.91, -551.59) }
    radagon_elden_beast = @{ sp = @(84.16, 79.56, -477.32, -36.32); fog = 0; regionClone = 19002800; radius = 110; regionCenter = @(140.85, 90.91, -551.59) }
}

# Position (x, y, z) of a part or region in a map dump, $null if absent.
function Get-Pos($lines, $id) {
    $l = $lines | ? { $_ -match "^$id\t.*pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)" } | Select-Object -First 1
    if (-not $l) { return $null }
    $null = $l -match 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)'
    @([double]$matches[1], [double]$matches[2], [double]$matches[3])
}

function Get-Section($lines, $name) {
    $i = [array]::IndexOf($lines, "== $name")
    $j = $i + 1; while ($j -lt $lines.Count -and $lines[$j] -notlike '== *') { $j++ }
    if ($i -lt 0) { @() } else { $lines[($i + 1)..($j - 1)] }
}

$usedEntities = @{}
$flagBlocks = @{}
$bosses = foreach ($d in $data) {
    $key, $map, $chr, $defeat, $nameId, $fog, $start, $sp, $ai = $d
    $lines = Get-Content "$MsbDir\$map.txt" -Encoding utf8
    $ids = @{}
    $all = Get-Section $lines 'AllEntityIDs'
    if (-not $all) { throw "$map dump has no AllEntityIDs section; rerun MsbDump" }
    $all -split ' ' | % { $ids[$_] = $true }
    # Existing player spawn points (Players section, entity id set); prefer x9xx (grace spawns) over x7xx.
    $playerLines = @(Get-Section $lines 'Players' | ? { $_ -notmatch '^0\t' })
    $players = @($playerLines | % { [int64](($_ -split "`t")[0]) } |
        Sort-Object { if ($_ % 1000 -ge 900) { 0 } else { 1 } }, { -($_ % 1000) })
    # Fallback exit: the existing player spawn point closest to the arena spawn.
    $exit = $playerLines | Sort-Object {
        $m = [regex]::Match($_, 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)')
        [math]::Pow([double]$m.Groups[1].Value - $sp[0], 2) + [math]::Pow([double]$m.Groups[2].Value - $sp[1], 2) + [math]::Pow([double]$m.Groups[3].Value - $sp[2], 2)
    } | Select-Object -First 1 | % { [int64](($_ -split "`t")[0]) }
    if (-not $exit) { throw "$map has no player spawn point with an entity id" }

    # Region positions are their base, which can be below the floor: never spawn lower than 0.5 m above
    # the boss's fog asset when that is near (it stands on the floor at the arena entrance).
    # 9005800(defeat, fog asset, region the fog leads into, fog flag, boss, action button, first-time flag, area)
    $fogEvent = Select-String "$EventJs\$map.emevd.dcx.js" -Pattern "InitializeCommonEvent\(\d+, 9005800, $defeat, (\d+), (\d+), \d+, \d+, \d+, (-?\d+)," | Select-Object -First 1
    # Some maps use their own copy of 9005800 with the same parameters (Rykard: event 16002846).
    if (-not $fogEvent -and $fogEventCopy[$key]) {
        $fogEvent = Select-String "$EventJs\$map.emevd.dcx.js" -Pattern "InitializeEvent\(\d+, $($fogEventCopy[$key]), $defeat, (\d+), (\d+), \d+, \d+, \d+, (-?\d+)," | Select-Object -First 1
    }
    if ($fogEvent -and -not $existingSpawn[$key]) {
        $fogLine = $lines | ? { $_ -match "^$($fogEvent.Matches[0].Groups[1].Value)\t.*pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)" } | Select-Object -First 1
        if ($fogLine -and $fogLine -match 'pos=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)') {
            $fx = [double]$matches[1]; $fy = [double]$matches[2]; $fz = [double]$matches[3]
            if ([math]::Sqrt(($fx - $sp[0]) * ($fx - $sp[0]) + ($fz - $sp[2]) * ($fz - $sp[2])) -lt 25 -and $sp[1] -lt $fy + 0.5) {
                $sp = @($sp[0], [math]::Round($fy + 0.5, 2), $sp[2], $sp[3])
            }
        }
    }

    # Spawn in front of the boss's fog wall (common_func 9005800: fog asset, region the fog leads into), so the
    # player can buff before walking through it (resting at the grace to open the menu removes buffs): 2.5 m
    # from the fog on the side away from that region, facing the fog. Bosses without a fog wall keep the
    # arena spawn above.
    $prepFog = 0
    if ($fogEvent -and $fogEvent.Matches[0].Groups[1].Value -ne '0' -and -not $existingSpawn[$key] -and -not ($insideSpawn -contains $key) -and -not $prepElsewhere[$key]) {
        $fogId = $fogEvent.Matches[0].Groups[1].Value
        $regionId = if ($fogDirRegion[$key]) { $fogDirRegion[$key] } else { $fogEvent.Matches[0].Groups[2].Value }
        $pf = Get-Pos $lines $fogId; $pr = Get-Pos $lines $regionId
        if (-not $pf -or -not $pr) { throw "$key : fog $fogId or region $regionId not in the $map dump" }
        $dx = $pr[0] - $pf[0]; $dz = $pr[2] - $pf[2]; $len = [math]::Sqrt($dx * $dx + $dz * $dz)
        if ($len -lt 0.5) { throw "$key : region $regionId is at the fog $fogId, no direction" }
        $dx /= $len; $dz /= $len
        $rot = [math]::Atan2($dx, $dz) * 180 / [math]::PI + 180
        if ($rot -gt 180) { $rot -= 360 }
        $sp = @([math]::Round($pf[0] - 2.5 * $dx, 2), [math]::Round($pf[1] + 0.5, 2), [math]::Round($pf[2] - 2.5 * $dz, 2), [math]::Round($rot, 2))
        $prepFog = [int64]$fogId
        Write-Host ("{0,-20} fog {1} -> region {2}: {3:N1} m, spawn ({4})" -f $key, $fogId, $regionId, $len, ($sp -join ', '))
    }

    # Spawn in front of a fog wall in another map than the boss's ($prepElsewhere).
    $spawnMap = $map; $spawnIds = $ids; $spawnClone = $players[0]; $cloneMap = $null
    $prep = if ($prepFog) { @{ regionClone = [int64]$fogEvent.Matches[0].Groups[2].Value; radius = 12 } } else { $null }
    # A 9005800 first-time flag (e.g. Margit's intro flag, off during the reflection so the intro plays):
    # while it's off the fight starts without the fog, when the player walks up to the boss (Margit: within
    # 25 m, ~35 m from the fog). The prep region then spans the way: centred mid-way to the boss, radius
    # half that distance + 10 m.
    if ($prep -and ([int64]$fogEvent.Matches[0].Groups[3].Value -ne 0 -or $walkToBoss -contains $key)) {
        $pb = Get-Pos $lines $(if ($anchors[$key]) { $anchors[$key] } else { $chr })   # phase one: where the player walks up to
        if ($pb) {
            $half = [math]::Sqrt([math]::Pow($pb[0] - $sp[0], 2) + [math]::Pow($pb[1] - $sp[1], 2) + [math]::Pow($pb[2] - $sp[2], 2)) / 2
            $prep.regionCenter = @([math]::Round(($pb[0] + $sp[0]) / 2, 2), [math]::Round(($pb[1] + $sp[1]) / 2, 2), [math]::Round(($pb[2] + $sp[2]) / 2, 2))
            $prep.radius = [math]::Max(12, [math]::Ceiling($half + 10))
            Write-Host ("{0,-20} first-time start possible: prep region r={1} around ({2})" -f $key, $prep.radius, ($prep.regionCenter -join ', '))
        }
    }
    $entityBase = [int64]$chr - ([int64]$chr % 1000)
    if ($prepElsewhere[$key]) {
        $pe = $prepElsewhere[$key]
        $sp = $pe.sp
        if ($pe.map) {
            $spawnMap = $pe.map; $entityBase = $pe.entityBase
            $sl = Get-Content "$MsbDir\$spawnMap.txt" -Encoding utf8
            $spawnIds = @{}; (Get-Section $sl 'AllEntityIDs') -split ' ' | % { $spawnIds[$_] = $true }
            $spawnClone = @(Get-Section $sl 'Players' | ? { $_ -match '^\d+\t' -and $_ -notmatch '^0\t' } | % { [int64](($_ -split "`t")[0]) })[0]
        }
        if ($pe.cloneMap) { $cloneMap = $pe.cloneMap; $spawnClone = $pe.clone }
        $prep = if ($pe.ContainsKey('fog')) { @{ regionClone = $pe.regionClone; radius = $pe.radius; triggerAsset = $pe.triggerAsset; regionCenter = $pe.regionCenter; regionHeight = $pe.regionHeight; arenaRegion = $pe.arenaRegion } } else { $null }
        $prepFog = if ($pe.fog) { $pe.fog } else { 0 }
        Write-Host ("{0,-20} hand-placed in {1}: spawn ({2}), prep {3}" -f $key, $spawnMap, ($sp -join ', '), [bool]$prep)
    }

    if ($existingSpawn[$key]) {
        $spawn = [ordered]@{ entity = $existingSpawn[$key]; existing = $true; x = $sp[0]; y = $sp[1]; z = $sp[2]; rotY = $sp[3] }
    } else {
        $spawnId = (989..900 | % { $entityBase + $_ } | ? { -not $spawnIds["$_"] -and -not $usedEntities["$_"] } | Select-Object -First 1)
        $usedEntities["$spawnId"] = $true
        $spawn = [ordered]@{ entity = $spawnId; clone = $spawnClone; x = $sp[0]; y = $sp[1]; z = $sp[2]; rotY = $sp[3] }
        if ($spawnMap -ne $map) { $spawn.map = $spawnMap }
        if ($cloneMap) { $spawn.cloneMap = $cloneMap }
    }

    # 5 flags per boss near the end of the defeat flag's block: 990.., then 995.., 980.., 985.. for more
    # bosses in the same block.
    $flagBase = [int64]$defeat - ([int64]$defeat % 1000)
    $k = [int]$flagBlocks["$flagBase"]; $flagBlocks["$flagBase"] = $k + 1
    $f = $flagBase + @(990, 995, 980, 985, 970, 975)[$k]
    $mapParts = $map.Substring(1) -split '_' | % { [int]$_ }

    $b = [ordered]@{
        key = $key; map = $map; mapId = $mapParts
        bossEntity = $chr; anchorEntity = $(if ($anchors[$key]) { $anchors[$key] } else { $chr })
        defeatFlag = $defeat; nameId = $nameId
        banner = $(if ($bannerOverride[$key]) { $bannerOverride[$key] } else { Get-Banner $map $chr })
        finalPhaseFlag = $(if ($finalPhase[$key]) { $finalPhase[$key] } else { 0 })
        fogFlag = $fog; startRegion = $start; fallbackAi = $ai
        spawn = $spawn
        exitSpawn = $exit
        flags = [ordered]@{ request = $f; active = $f + 1; warping = $f + 2; loaded = $f + 3; wasDefeated = $f + 4 }
    }
    if ($radius[$key]) { $b.radius = $radius[$key] }
    if ($presenceDelay[$key]) { $b.presenceDelay = $presenceDelay[$key] }
    if ($resetFlags[$key]) { $b.resetFlags = $resetFlags[$key] }
    if ($menuText[$key]) { $b.menuText = $menuText[$key] }
    if ($menuNameIds[$key]) { $b.menuNameIds = $menuNameIds[$key] }
    # Shadow of the Erdtree boss: its map is a DLC one (m20..m28 dungeons, m61 overworld; base game is
    # m10..m19 and m60). The menu lists it only if the game has the DLC.
    $b.dlc = ($mapParts[0] -ge 20 -and $mapParts[0] -ne 60)
    $b.realDeath = $false
    $b.deathAnim = Get-DeathAnim $chr
    if ($clearFlag[$key]) { $b.clearFlag = $clearFlag[$key] }
    if ($variants[$key]) { $b.variants = $variants[$key] }
    if ($tempOff[$key]) {
        $b.tempOff = @($tempOff[$key] | % { [ordered]@{ flag = $_; value = (New-SpareFlag $defeat); saved = (New-SpareFlag $defeat) } })
    }
    if ($giveWeapon[$key]) { $b.giveWeapon = [ordered]@{ id = $giveWeapon[$key][0]; itemLot = $giveWeapon[$key][1]; given = (New-SpareFlag $defeat) } }
    $entryFog = if ($fogEvent) { [int64]$fogEvent.Matches[0].Groups[1].Value } else { 0 }
    # early: when the wall goes on (event 7980011). 0 = once the fight started (fog flag); for the fog the
    # player spawns in front of (prepFog) right on arrival so it can be walked through (1), unless the
    # 9005800 call has a first-time flag: while that's off the first fight starts without the fog (the
    # player walks in), so then only if it's on (the flag).
    $firstTime = if ($fogEvent) { [int64]$fogEvent.Matches[0].Groups[3].Value } else { 0 }
    $walls = @($fogInits | ? { $_.flag -eq [int64]$defeat -or ($entryFog -and $_.asset -eq $entryFog -and $_.map -eq $map.Substring(0, 9)) } |
        Sort-Object asset -Unique | % {
            $early = if ($prepFog -and $_.asset -eq $prepFog) { if ($firstTime) { $firstTime } else { 1 } } else { 0 }
            [ordered]@{ asset = $_.asset; sfx = $_.sfx; early = $early } })
    if ($walls -and -not ($noFogWalls -contains $key)) { $b.fogWalls = $walls }
    if ($prep) {
        # "Still at the start" region around the spawn: leaving it before the fight started ends the reflection.
        $regionEntity = (989..900 | % { $entityBase + $_ } | ? { -not $spawnIds["$_"] -and -not $usedEntities["$_"] } | Select-Object -First 1)
        $usedEntities["$regionEntity"] = $true
        $b.prepFog = [ordered]@{ asset = $prepFog; region = $regionEntity; clone = $prep.regionClone; radius = $prep.radius }
        if ($prep.regionCenter) { $b.prepFog.center = $prep.regionCenter }
        if ($prep.regionHeight) { $b.prepFog.height = $prep.regionHeight }
        if ($prep.arenaRegion) { $b.prepFog.arena = $prep.arenaRegion }
        if ($prep.triggerAsset) {
            $ta = $prep.triggerAsset
            $triggerEntity = (989..900 | % { $entityBase + $_ } | ? { -not $spawnIds["$_"] -and -not $usedEntities["$_"] } | Select-Object -First 1)
            $usedEntities["$triggerEntity"] = $true
            $b.prepFog.trigger = [ordered]@{ entity = $triggerEntity; clone = $ta.clone; x = $ta.x; y = $ta.y; z = $ta.z }
        }
    }
    $graces = Get-Graces $map
    $b.hide = [ordered]@{
        characters = @(@($graces.characters) + @($hideExtra[$key].characters) | ? { $_ } | Select-Object -Unique)
        assets = @(@($graces.assets) + @($hideExtra[$key].assets) | ? { $_ } | Select-Object -Unique)
    }
    $b
}
$json = [ordered]@{
    comment = 'Boss Reflections boss table. Order = menu order. See README for field meanings.'
    bosses = @($bosses)
} | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText($Out, $json, (New-Object Text.UTF8Encoding $false))
"wrote $($bosses.Count) bosses to $Out"
