=====================================================================
  REFLECTIONS OF BATTLE (Boss Reflections) — ELDEN RING mod
  Version 1.0
=====================================================================

Boss rematches in the style of Sekiro's "Reflections of Strength".
Rest at any site of grace, choose "Reflections of Battle" and fight
the game's and the DLC's main bosses as often as you like.
The world doesn't change: no rewards, no runes, no consequences.


---------------------------------------------------------------------
 FEATURES
---------------------------------------------------------------------
- A new site of grace menu entry, "Reflections of Battle", with a
  boss list (alphabetical in the game's language).
- 31 fights: every remembrance boss (base game and Shadow of the
  Erdtree), plus Margit, the Godskin Duo, Loretta and Bayle.
  Radagon and the Elden Beast: Radagon alone, the Elden Beast alone,
  or the full fight with both, as in the original game.
- Every boss is available right away, even if not defeated yet.
  DLC bosses are listed only if you own the DLC.
- You appear in front of the arena's fog and can buff in peace.
  The fight starts when you walk through the fog (or, as in the
  original game, walk up to the boss).
- Intro cutscenes play in every fight.
- Win or lose, you return to the site of grace you started from.
  No runes lost, no rewards; a boss dead in your world stays dead,
  a living one stays alive.
- Two options at the top of the list:
    "Journey" — the NG cycle (NG ... NG+7) the bosses' strength and
      health are scaled to. Default: as in your world.
    "Scadutree Blessing" (DLC only) — the blessing level used in DLC
      boss fights. Default: your character's.
- Walking away from the boss before the fight starts sends you back
  to the grace.
- The mod's texts are in all 15 game languages (Arabic: English).


---------------------------------------------------------------------
 REQUIREMENTS
---------------------------------------------------------------------
1. ELDEN RING (Steam), eldenring.exe file version 2.7.2.0.
   The mod contains modified game files (regulation.bin, maps,
   scripts). Other game versions may break or crash.
   After a game update, wait for a mod update.
2. Mod Engine 2 (2.1.0.0 or newer):
   https://github.com/soulsmods/ModEngine2/releases
   (ModEngine-2.x.x.x-win64.zip)
3. The Shadow of the Erdtree DLC is NOT required. Without it the
   list shows the base game bosses only.


---------------------------------------------------------------------
 BEFORE INSTALLING
---------------------------------------------------------------------
- OFFLINE ONLY. Mod Engine 2 starts the game without Easy Anti-Cheat,
  so online play is unavailable — that's expected. Never go online
  with mods: you may get banned.
- Back up your saves:
    %APPDATA%\EldenRing\<your account number>\ER0000.sl2
  (paste %APPDATA%\EldenRing into the Explorer address bar) and copy
  the whole folder somewhere safe.


---------------------------------------------------------------------
 INSTALLATION
---------------------------------------------------------------------
1. Download Mod Engine 2 (link above) and extract it anywhere, e.g.
   to the desktop. You get a folder like ModEngine-2.1.0.0-win64 with
   modengine2_launcher.exe in it.

2. Extract this mod's archive INTO the Mod Engine 2 folder, so that
   you have:

     ModEngine-2.1.0.0-win64\
       modengine2_launcher.exe
       ...
       BossReflections\
         launch_bossreflections.bat
         config_bossreflections.toml
         select_language.ps1
         mod\
         README_EN.txt

   The BossReflections folder must sit next to
   modengine2_launcher.exe (not deeper) and keep exactly this name —
   don't rename it.

3. Start Steam (the game must be in your library).

4. Start the game by double-clicking
   BossReflections\launch_bossreflections.bat
   (not through Steam). You can put a shortcut to it on the desktop.

   If Windows says "Windows protected your PC", click "More info" →
   "Run anyway". The .bat only picks the menu language, writes the mod's
   path into config_bossreflections.toml and starts Mod Engine 2.

5. In game, rest at any site of grace: the menu has a new
   "Reflections of Battle" entry.


---------------------------------------------------------------------
 LANGUAGE
---------------------------------------------------------------------
The mod uses the game language set in Steam
(ELDEN RING → Properties → General → Language) and puts the menu in
that language every time you start through launch_bossreflections.bat.
After changing the language, just start through the same .bat again.


---------------------------------------------------------------------
 HOW TO PLAY
---------------------------------------------------------------------
- Site of grace → "Reflections of Battle" → pick a boss.
- You appear at the arena entrance. Buff, then walk through the fog.
- Victory: after a few seconds you're back at the grace.
- Defeat (your health stops at 1, you can't die), leaving the arena,
  or walking away from the boss before the fight: back to the grace,
  runes kept.
- Special fights:
    Fortissax — by the Prince of Death's throne, walk up to the
      glowing spot and choose "Begin the battle".
    Rykard — you get the Serpent-Hunter on arrival; it's taken back
      after the fight.
    Putrescent Knight — go through the fog and jump down into the
      arena, as in the original game.
    Radagon — the fight starts when you walk up to him.
- The "Journey" and "Scadutree Blessing" options are saved and apply
  to every fight until you change them.


---------------------------------------------------------------------
 COMPATIBILITY
---------------------------------------------------------------------
The mod replaces: regulation.bin, event\common.emevd and the event and
map files of the arenas (map\mapstudio), the site of grace menu
(script\talk\m00_00_00_00.talkesdbnd.dcx) and the menu texts
(msg\*\menu*.msgbnd.dcx).
Mods changing the same files (most balance / regulation.bin mods,
randomizers, mods of these maps) won't work together with it.
Seamless Co-op is not supported.


---------------------------------------------------------------------
 UNINSTALLING
---------------------------------------------------------------------
Finish the current reflection (get back to the grace) and quit the
game, then delete the BossReflections folder. Start the game through
Steam as usual. Your saves keep working.


---------------------------------------------------------------------
 TROUBLESHOOTING
---------------------------------------------------------------------
- No "Reflections of Battle" entry: the game wasn't started through
  launch_bossreflections.bat, or the BossReflections folder isn't next
  to modengine2_launcher.exe.
- The .bat window closes right away / PowerShell error: run it again;
  if that doesn't help, check that your antivirus didn't remove
  select_language.ps1.
- Menu in the wrong language: check the game language in Steam's
  properties.
- Crash when an arena loads: check the game version (eldenring.exe →
  Properties → Details → File version must be 2.7.2.0).
- Quit in the middle of a fight? On the next load the mod puts
  everything back and sends you to the grace.
