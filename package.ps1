# Packs the built mod (run build.ps1 first) for distribution: dist\BossReflections_v<Version>.zip with a
# BossReflections folder to extract into the Mod Engine 2 folder (portable launcher, config and language
# picker from dist_template, readmes).
param([string]$Version = '1.0')
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$pkg = Join-Path $dist 'BossReflections'
$zip = Join-Path $dist "BossReflections_v$Version.zip"
if (-not (Test-Path "$root\mod\regulation.bin")) { throw 'mod\ is not built: run build.ps1 first' }

Remove-Item $pkg, $zip -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $pkg | Out-Null
Copy-Item "$root\mod" "$pkg\mod" -Recurse
# The menu actually used is put in place by select_language.ps1 at every start; ship the English one.
Copy-Item "$pkg\mod\lang\engus\m00_00_00_00.talkesdbnd.dcx" "$pkg\mod\script\talk\m00_00_00_00.talkesdbnd.dcx" -Force
foreach ($f in 'launch_bossreflections.bat', 'config_bossreflections.toml', 'select_language.ps1') {
    Copy-Item "$root\dist_template\$f" "$pkg\$f"
}
# Readmes with a BOM so Notepad shows the Cyrillic right.
foreach ($f in 'README_RU.txt', 'README_EN.txt') {
    [IO.File]::WriteAllText("$pkg\$f", [IO.File]::ReadAllText("$root\dist_template\$f"), (New-Object Text.UTF8Encoding $true))
}

# No machine-specific paths may be left in what we ship.
$leak = Get-ChildItem $pkg -File | ? { $_.Extension -in '.bat', '.toml', '.ps1' } | Select-String -Pattern 'D:\\|C:\\Users' -SimpleMatch:$false
if ($leak) { throw "machine-specific path in package: $($leak -join '; ')" }

# Entries written one by one with standard '/' separators (PowerShell 5.1's Compress-Archive and .NET Framework's
# CreateFromDirectory write '\', which some tools and mod sites mishandle), under a top BossReflections folder.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem $pkg -Recurse -File) {
        $entry = 'BossReflections/' + $file.FullName.Substring($pkg.Length + 1).Replace('\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal)
    }
} finally { $archive.Dispose() }
$files = (Get-ChildItem $pkg -Recurse -File).Count
"{0}: {1} files, {2:N1} MB" -f $zip, $files, ((Get-Item $zip).Length / 1MB)
