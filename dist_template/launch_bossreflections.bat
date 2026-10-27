@echo off
chcp 65001 >nul
:: Boss Reflections: starts Elden Ring through Mod Engine 2 with this mod.
:: This folder must be named BossReflections and sit inside the Mod Engine 2 folder (next to
:: modengine2_launcher.exe).
set "HERE=%~dp0"
if not exist "%HERE%..\modengine2_launcher.exe" goto wrongplace
if not exist "%HERE%mod\regulation.bin" goto wrongplace

:: Mod Engine 2 fails to resolve a relative mod path ("Unable to resolve mod path"), so the config is
:: rewritten with this folder's absolute path at every start (UTF-8 without BOM, '\' doubled for TOML).
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p = (Join-Path $env:HERE 'mod').Replace('\', '\\'); $t = \"[modengine]`ndebug = false`nexternal_dlls = []`n`n[extension.mod_loader]`nenabled = true`nloose_params = false`nmods = [`n    { enabled = true, name = `\"bossreflections`\", path = `\"$p`\" }`n]`n`n[extension.scylla_hide]`nenabled = false`n\"; [IO.File]::WriteAllText((Join-Path $env:HERE 'config_bossreflections.toml'), $t, (New-Object Text.UTF8Encoding $false))"

:: The grace menu sorted for the game's current Steam language.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%select_language.ps1"
cd /d "%HERE%.."
modengine2_launcher.exe -t er -c "%HERE%config_bossreflections.toml"
exit /b 0

:wrongplace
echo Boss Reflections is not installed correctly.
echo Put the BossReflections folder inside the Mod Engine 2 folder, next to modengine2_launcher.exe,
echo and keep the folder name BossReflections.
echo.
echo Mod BossReflections ustanovlen nepravilno: papka BossReflections dolzhna lezhat v papke Mod Engine 2,
echo ryadom s modengine2_launcher.exe, i nazyvatsya imenno BossReflections.
pause
exit /b 1
