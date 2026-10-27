# Boss Reflections: puts the site of grace menu for the game's current language into the mod
# (mod\lang\<lang> -> mod\script\talk). The menu can't tell the game language by itself and its boss list is
# sorted alphabetically per language, so launch_bossreflections.bat runs this before every start.
# The language is the one Steam gives Elden Ring (Properties > General > Language); English if not found.
$ErrorActionPreference = 'Stop'
$mod = Join-Path $PSScriptRoot 'mod'

$steamToMsg = @{
    arabic = 'araae'; german = 'deude'; english = 'engus'; french = 'frafr'; italian = 'itait'; japanese = 'jpnjp'
    koreana = 'korkr'; polish = 'polpl'; brazilian = 'porbr'; russian = 'rusru'; latam = 'spaar'; spanish = 'spaes'
    thai = 'thath'; schinese = 'zhocn'; tchinese = 'zhotw'
}

# Elden Ring's Steam manifest: in the Steam folder or any of its library folders.
function Find-Manifest {
    $steam = $null
    foreach ($key in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam') {
        try {
            $p = Get-ItemProperty $key -ErrorAction Stop
            $steam = if ($p.SteamPath) { $p.SteamPath } else { $p.InstallPath }
            if ($steam) { break }
        } catch { }
    }
    if (-not $steam) { return $null }
    $libraries = @($steam -replace '/', '\')
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s*"([^"]+)"')) { $libraries += $m.Groups[1].Value -replace '\\\\', '\' }
    }
    foreach ($lib in $libraries | Select-Object -Unique) {
        $acf = Join-Path $lib 'steamapps\appmanifest_1245620.acf'
        if (Test-Path $acf) { return $acf }
    }
    $null
}

$steamLang = $null
try {
    $manifest = Find-Manifest
    if ($manifest) {
        # "UserConfig" { "language" "english" }: the language chosen in Steam for the game.
        $m = [regex]::Match((Get-Content $manifest -Raw), '"UserConfig"\s*\{[^}]*"language"\s*"(\w+)"')
        if ($m.Success) { $steamLang = $m.Groups[1].Value }
    }
} catch { }
$lang = if ($steamLang -and $steamToMsg[$steamLang]) { $steamToMsg[$steamLang] } else { 'engus' }

$src = Join-Path $mod "lang\$lang\m00_00_00_00.talkesdbnd.dcx"
if (-not (Test-Path $src)) { $src = Join-Path $mod 'lang\engus\m00_00_00_00.talkesdbnd.dcx' }
New-Item -ItemType Directory -Force (Join-Path $mod 'script\talk') | Out-Null
Copy-Item $src (Join-Path $mod 'script\talk\m00_00_00_00.talkesdbnd.dcx') -Force
Write-Host "Boss Reflections: menu language $lang (Steam: $steamLang)"
