// Boss Reflections: refight remembrance bosses from the site of grace menu, Sekiro style.
// Appended to the vanilla common.emevd by build.ps1, which also adds one $InitializeEvent per boss and
// event (slot = boss index) to $Event(0), with the values from src\bosses.json:
//
//   requestFlag     flags.request: set by the grace menu, consumed here
//   activeFlag      flags.active: a reflection of this boss is in progress
//   warpingFlag     flags.warping: between the start of the reflection and arriving in the arena
//   loadedFlag      flags.loaded: set by a tiny event build.ps1 adds to the boss map's own emevd, i.e.
//                   "the boss map's events have started"; cleared before the warp, so set again = the
//                   map was (re)loaded after the warp. The reflection can be started from a grace in the
//                   boss map itself, so being in that map or near the boss proves nothing by itself.
//   wasDefeatedFlag flags.wasDefeated: the boss was already defeated in the world when the reflection
//                   started. Every reflection ends with defeatFlag back to that state.
//   defeatFlag      vanilla "boss defeated" flag: cleared while the reflection runs
//   map             area/block/region/index of the boss map
//   arenaSpawn      player spawn point added inside the boss fog, inside the vanilla fight start region
//   exitSpawn       vanilla player spawn point near the arena, fallback exit
//   anchorEntity    character present from the start of the fight; "player within radius of it or of
//   radius          bossEntity" = the player is at the boss (the boss map is loaded)
//   bossEntity      the boss character (last phase), bossNameId its health bar name
//   fogFlag         vanilla "player passed the fog" flag: with the player in the start region it makes
//                   the vanilla events start the fight (intro, AI, health bar, music)
//   fallbackAi      1 = also enable bossEntity's AI and health bar ourselves (single-entity bosses)
//   finalPhaseFlag  vanilla flag only on in the last phase (0 = none); phaseFlag is the same, or
//                   activeFlag when there is none (always on during the reflection)
//   banner          TextBannerType of the vanilla defeat banner
//   hidden entity   bosses.json hide.characters / hide.assets: things vanilla shows in the arena for a
//                   defeated boss through flags we don't touch (graces, Rennala's NPC form, Marika's body)
//
// Winning: bosses are kept immortal and at 1 HP in their last phase the reflection counts as won
// ("protected victory", event 7980005), so their vanilla defeat event never runs (rewards, runes, world and
// quest changes, respawn point / warps). bosses.json realDeath true would let an already defeated boss die
// for real instead (events 7980002); no boss uses it now, as a real death awards its runes. defeatFlag
// ends in its state from before.
// Our SpEffects (src\param\SpEffectParam.rows.xml):
//   7980000  warp to the last rested grace (the one the reflection was opened from). Same as the
//            Memory of Grace effect 3226, minus 3226's "lose all held runes".
//   7980001  no runes from kills while the reflection runs (no reward, like Sekiro's reflections).

// Start: the grace menu requested a reflection -> revive the boss and warp right behind its fog.
$Event(7980000, Restart, function(requestFlag, activeFlag, warpingFlag, loadedFlag, wasDefeatedFlag, defeatFlag, finalPhaseFlag, clearFlag, areaId, blockId, regionId, indexId, arenaSpawn) {
    WaitFor(EventFlag(requestFlag));
    SetEventFlagID(requestFlag, OFF);
    SetEventFlagID(activeFlag, ON);
    SetEventFlagID(warpingFlag, ON);
    SetEventFlagID(loadedFlag, OFF);
    SetEventFlagID(wasDefeatedFlag, OFF);
    if (EventFlag(defeatFlag)) {
        SetEventFlagID(wasDefeatedFlag, ON);
    }
    SetEventFlagID(defeatFlag, OFF);
    if (Signed(finalPhaseFlag) != 0) {
        SetEventFlagID(finalPhaseFlag, OFF);
    }
    // clearFlag: a vanilla "fight already started once" flag that would make the fight wait for a
    // region the spawn point can't be in (Loretta); vanilla sets it again when the fight starts.
    if (Signed(clearFlag) != 0) {
        SetEventFlagID(clearFlag, OFF);
    }
    WaitFixedTimeSeconds(1);
    WarpPlayer(areaId, blockId, regionId, indexId, arenaSpawn, 0);
    RestartEvent();
});

// Arrival: the boss map has loaded after the warp. Let the vanilla events start the fight (the player
// stands in the start region; fogFlag is set a few times because the vanilla boss BGM event clears it
// when it starts). No death, no runes from kills. If the boss isn't there (e.g. a map variant without
// it), call the reflection off.
// prepFog: the boss's fog wall asset when the player spawns in front of it (bosses.json prepFog), else 0.
// Then the player buffs and walks through the fog, and vanilla sets fogFlag; we don't.
$Event(7980001, Restart, function(activeFlag, warpingFlag, loadedFlag, wasDefeatedFlag, defeatFlag, anchorEntity, bossEntity, bossNameId, fogFlag, fallbackAi, radius, presenceDelay, prepFog) {
    WaitFor(EventFlag(activeFlag) && EventFlag(warpingFlag) && EventFlag(loadedFlag));
    SetEventFlagID(warpingFlag, OFF);
    EnableCharacterImmortality(10000);
    SetSpEffect(10000, 7980001);
    GotoIf(S0, Signed(prepFog) != 0);
    SetEventFlagID(fogFlag, ON);
    WaitFixedTimeSeconds(0.5);
    SetEventFlagID(fogFlag, ON);
    WaitFixedTimeSeconds(0.5);
    SetEventFlagID(fogFlag, ON);
    WaitFixedTimeSeconds(1);
    SetEventFlagID(fogFlag, ON);
S0:
    // With prepFog, the boss is checked for only once the player started the fight (it may not be there
    // before: Fortissax appears in the dream).
    GotoIf(S3, Signed(prepFog) == 0);
    WaitFor(EventFlag(fogFlag) || !EventFlag(activeFlag));
    GotoIf(S2, !EventFlag(activeFlag));
S3:
    // Some bosses only appear after a cutscene the arrival starts (Fortissax): wait up to presenceDelay.
    present = EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) || EntityInRadiusOfEntity(10000, bossEntity, radius, 1);
    time = ElapsedSeconds(presenceDelay);
    WaitFor(present || time);
    if (!EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) && !EntityInRadiusOfEntity(10000, bossEntity, radius, 1)) {
        SetEventFlagID(activeFlag, OFF);
        if (EventFlag(wasDefeatedFlag)) {
            SetEventFlagID(defeatFlag, ON);
        }
        DisableCharacterImmortality(10000);
        ClearSpEffect(10000, 7980001);
        SetSpEffect(10000, 7980000);
        RestartEvent();
    }
    // Fallback AI: once the fight started (with prepFog: the player went through the fog), and again a few
    // seconds later, in case a vanilla start event (or its intro cutscene) disabled it meanwhile.
    GotoIf(S2, Signed(fallbackAi) == 0);
    GotoIf(S1, Signed(prepFog) == 0);
    WaitFor(EventFlag(fogFlag) || !EventFlag(activeFlag));
    GotoIf(S2, !EventFlag(activeFlag));
    WaitFixedTimeSeconds(2);
S1:
    EnableCharacterAI(bossEntity);
    DisplayBossHealthBar(Enabled, bossEntity, 0, bossNameId);
    WaitFixedTimeSeconds(5);
    GotoIf(S2, !EventFlag(activeFlag));
    EnableCharacterAI(bossEntity);
S2:
    WaitFor(!EventFlag(activeFlag));
    DisableCharacterImmortality(10000);
    RestartEvent();
});

// Victory over an already defeated boss: vanilla boss events set the defeat flag again -> back to the grace.
$Event(7980002, Restart, function(activeFlag, defeatFlag) {
    WaitFor(EventFlag(activeFlag) && EventFlag(defeatFlag));
    SetEventFlagID(activeFlag, OFF);
    DisableCharacterImmortality(10000);
    WaitFixedTimeSeconds(8);
    ClearSpEffect(10000, 7980001);
    SetSpEffect(10000, 7980000);
    RestartEvent();
});

// Loss: HP dropped to 1 (immortal), the player died anyway (e.g. a fall) or left the boss
// -> the boss is back in its world state and the player goes back to the grace, fully restored,
// keeping their runes. Watching starts only after arrival (warpingFlag off), so the warp itself
// doesn't count as leaving. "At the boss" = within radius of the phase-one or the last-phase
// character (the phase-one one may be gone after the phase change), and leaving only counts after
// 3 s, so a phase change cutscene that briefly has neither doesn't end the reflection.
$Event(7980003, Restart, function(activeFlag, warpingFlag, wasDefeatedFlag, defeatFlag, anchorEntity, bossEntity, radius, areaId, blockId, regionId, indexId, exitSpawn) {
    WaitFor(
        EventFlag(activeFlag)
            && !EventFlag(warpingFlag)
            && (EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) || EntityInRadiusOfEntity(10000, bossEntity, radius, 1)));
    WaitFor(
        !EventFlag(activeFlag)
            || (!EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) && !EntityInRadiusOfEntity(10000, bossEntity, radius, 1))
            || CharacterHPValue(10000) <= 1);
    GotoIf(L0, !EventFlag(activeFlag));
    GotoIf(L0, EventFlag(defeatFlag));
    GotoIf(L1, CharacterHPValue(10000) <= 1);
    WaitFixedTimeSeconds(3);
    GotoIf(L0, !EventFlag(activeFlag));
    GotoIf(L0, EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) || EntityInRadiusOfEntity(10000, bossEntity, radius, 1));
L1:
    SetEventFlagID(activeFlag, OFF);
    if (EventFlag(wasDefeatedFlag)) {
        SetEventFlagID(defeatFlag, ON);
    }
    ClearSpEffect(10000, 7980001);
    GotoIf(L0, !EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) && !EntityInRadiusOfEntity(10000, bossEntity, radius, 1));
    GotoIf(L0, CharacterHPValue(10000) <= 0);
    DisableCharacterImmortality(10000);
    BonfirelikeRecovery();
    SetSpEffect(10000, 7980000);
    WaitFixedTimeSeconds(5);
    GotoIf(L0, !EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) && !EntityInRadiusOfEntity(10000, bossEntity, radius, 1));
    WarpPlayer(areaId, blockId, regionId, indexId, exitSpawn, 0);
L0:
    RestartEvent();
});

// Loaded a save made during a reflection (quit out mid-fight, or one left over from an older build)
// -> undo it and send the player to the grace. While warping (the menu's warp also loads a map)
// the arrival event above handles it instead.
$Event(7980004, Restart, function(activeFlag, warpingFlag, wasDefeatedFlag, defeatFlag) {
    EndIf(!EventFlag(activeFlag));
    EndIf(EventFlag(warpingFlag));
    WaitFixedTimeSeconds(2);
    EndIf(!EventFlag(activeFlag));
    SetEventFlagID(activeFlag, OFF);
    if (EventFlag(wasDefeatedFlag)) {
        SetEventFlagID(defeatFlag, ON);
    }
    ClearSpEffect(10000, 7980001);
    SetSpEffect(10000, 7980000);
});

// End of a reflection of a boss that wasn't defeated in the world: put back vanilla progress flags the
// reflection turned on (resetFlag1/2, 0 = none; e.g. Fortissax's "inside Fia's dream" flag, which would
// otherwise pull the player into the dream whenever the map loads).
$Event(7980006, Restart, function(activeFlag, wasDefeatedFlag, resetFlag1, resetFlag2) {
    WaitFor(EventFlag(activeFlag));
    WaitFor(!EventFlag(activeFlag));
    GotoIf(L0, EventFlag(wasDefeatedFlag));
    if (Signed(resetFlag1) != 0) {
        SetEventFlagID(resetFlag1, OFF);
    }
    if (Signed(resetFlag2) != 0) {
        SetEventFlagID(resetFlag2, OFF);
    }
L0:
    RestartEvent();
});

// Protected victory: keep the boss from dying (immortality is renewed every second in case a phase change
// resets it); at 1 HP in its last phase the reflection is won: the boss plays its death animation
// (deathAnim; 0 = none known, which just interrupts its attack), the player can't be hit any more, and
// goes back to the grace (retried once, then the fallback exit if still at the boss).
// Skipped while realDeathFlag is on: an already defeated boss whose vanilla defeat event is safe to run
// again dies for real (vanilla death animation and banner; event 7980002 does the return).
$Event(7980005, Restart, function(activeFlag, warpingFlag, wasDefeatedFlag, defeatFlag, realDeathFlag, anchorEntity, bossEntity, radius, phaseFlag, banner, deathAnim, areaId, blockId, regionId, indexId, exitSpawn) {
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag) && !EventFlag(realDeathFlag));
    EnableCharacterImmortality(bossEntity);
    won = CharacterHPValue(bossEntity) <= 1 && EventFlag(phaseFlag);
    time = ElapsedSeconds(1);
    WaitFor(won || time || !EventFlag(activeFlag));
    RestartIf(!EventFlag(activeFlag));
    RestartIf(time.Passed);
    SetEventFlagID(activeFlag, OFF);
    EnableCharacterInvincibility(10000);
    ForceAnimationPlayback(bossEntity, deathAnim, false, false, false);
    DisableCharacterAI(bossEntity);
    DisplayBanner(banner);
    WaitFixedTimeSeconds(5);
    if (EventFlag(wasDefeatedFlag)) {
        SetEventFlagID(defeatFlag, ON);
    }
    DisableCharacterInvincibility(10000);
    ClearSpEffect(10000, 7980001);
    SetSpEffect(10000, 7980000);
    WaitFixedTimeSeconds(5);
    GotoIf(L0, !EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) && !EntityInRadiusOfEntity(10000, bossEntity, radius, 1));
    SetSpEffect(10000, 7980000);
    WaitFixedTimeSeconds(5);
    GotoIf(L0, !EntityInRadiusOfEntity(10000, anchorEntity, radius, 1) && !EntityInRadiusOfEntity(10000, bossEntity, radius, 1));
    WarpPlayer(areaId, blockId, regionId, indexId, exitSpawn, 0);
L0:
    RestartEvent();
});

// Hide a character / asset vanilla shows in the arena because of flags the reflection doesn't touch.
// Hidden again a few times after arrival in case a vanilla event shows it a moment later; the map
// reload when leaving brings it back.
$Event(7980007, Restart, function(activeFlag, warpingFlag, entityId) {
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag));
    DisableCharacter(entityId);
    WaitFixedTimeSeconds(0.5);
    DisableCharacter(entityId);
    WaitFixedTimeSeconds(1);
    DisableCharacter(entityId);
    WaitFixedTimeSeconds(2);
    DisableCharacter(entityId);
    WaitFor(!EventFlag(activeFlag));
    RestartEvent();
});

// Assets also lose their SFX (e.g. the glow of Radahn's warp point back to Redmane Castle).
$Event(7980008, Restart, function(activeFlag, warpingFlag, entityId) {
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag));
    DisableAsset(entityId);
    DeleteAssetfollowingSFX(entityId, true);
    WaitFixedTimeSeconds(0.5);
    DisableAsset(entityId);
    DeleteAssetfollowingSFX(entityId, true);
    WaitFixedTimeSeconds(1);
    DisableAsset(entityId);
    DeleteAssetfollowingSFX(entityId, true);
    WaitFixedTimeSeconds(2);
    DisableAsset(entityId);
    DeleteAssetfollowingSFX(entityId, true);
    WaitFor(!EventFlag(activeFlag));
    RestartEvent();
});

// A vanilla flag turned off for the reflection and put back afterwards (bosses.json tempOff): intro
// cutscene "already seen" flags (the intro plays in every reflection), the Elden Beast's "ending reached".
// valueFlag keeps the flag's state, savedFlag says valueFlag holds it: a save loaded mid-reflection
// (savedFlag already on) doesn't overwrite it, and one loaded after doesn't lose it.
$Event(7980009, Restart, function(activeFlag, flag, valueFlag, savedFlag) {
    GotoIf(L0, !EventFlag(activeFlag) && EventFlag(savedFlag));
    WaitFor(EventFlag(activeFlag));
    if (!EventFlag(savedFlag)) {
        SetEventFlagID(valueFlag, OFF);
        if (EventFlag(flag)) {
            SetEventFlagID(valueFlag, ON);
        }
        SetEventFlagID(savedFlag, ON);
    }
    SetEventFlagID(flag, OFF);
    WaitFor(!EventFlag(activeFlag));
L0:
    SetEventFlagID(flag, OFF);
    if (EventFlag(valueFlag)) {
        SetEventFlagID(flag, ON);
    }
    SetEventFlagID(savedFlag, OFF);
    RestartEvent();
});

// A weapon the fight needs (bosses.json giveWeapon: Rykard's Serpent-Hunter): always given on arrival
// (an owned one may be in the storage chest), one taken back when the reflection ends (givenFlag: we gave
// it). Given through our own item lot (src\param\ItemLotParam_map.rows.xml, no "picked up" flag):
// DirectlyGivePlayerItem doesn't give weapons.
$Event(7980010, Restart, function(activeFlag, warpingFlag, weaponId, itemLotId, givenFlag) {
    GotoIf(L0, !EventFlag(activeFlag) && EventFlag(givenFlag));
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag));
    WaitFixedTimeSeconds(1);
    AwardItemLot(itemLotId);
    SetEventFlagID(givenFlag, ON);
    WaitFor(!EventFlag(activeFlag));
L0:
    if (EventFlag(givenFlag)) {
        RemoveItemFromPlayer(ItemType.Weapon, weaponId, 1);
    }
    SetEventFlagID(givenFlag, OFF);
    RestartEvent();
});

// Fog wall forced on after arrival (bosses.json fogWalls, from the vanilla common_func 9005811 calls):
// vanilla shows some only with other flags on (Morgott's entry fog, the Scadutree Avatar's before its
// first fight, the ones tied to intro flags). earlyFlag (bosses.json fogWalls early): 0 = once the fight
// started (fogFlag), as the player may still have to walk in; 1 = right on arrival (the fog the player
// spawns in front of, to walk through); a flag = on arrival if that flag is on, else once the fight
// started (a 9005800 first-time flag: while it's off the first fight starts without the fog). The map
// reload when leaving puts vanilla's state back.
$Event(7980011, Restart, function(activeFlag, warpingFlag, fogFlag, earlyFlag, assetId, sfxId) {
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag));
    GotoIf(L0, earlyFlag == 1);
    GotoIf(L1, earlyFlag == 0);
    GotoIf(L0, EventFlag(earlyFlag));
L1:
    WaitFor(EventFlag(fogFlag) || !EventFlag(activeFlag));
    GotoIf(L2, !EventFlag(activeFlag));
L0:
    WaitFixedTimeSeconds(1);
    EnableAsset(assetId);
    DeleteAssetfollowingSFX(assetId, true);
    CreateAssetfollowingSFX(assetId, 101, sfxId);
L2:
    WaitFor(!EventFlag(activeFlag));
    RestartEvent();
});

// Start of the fight by "examining" an asset we add to the map (bosses.json prepFog trigger; our
// ActionButtonParam row 7980000, src\param\ActionButtonParam.rows.xml), marked with a glow while it can be
// used: sets fogFlag (Fortissax: "enter Fia's dream", which vanilla sets from her dialogue).
$Event(7980013, Restart, function(activeFlag, warpingFlag, fogFlag, triggerAsset) {
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag));
    EnableAsset(triggerAsset);
    DeleteAssetfollowingSFX(triggerAsset, true);
    CreateAssetfollowingSFX(triggerAsset, 200, 806700);
    WaitFor(ActionButtonInArea(7980000, triggerAsset) || !EventFlag(activeFlag));
    DeleteAssetfollowingSFX(triggerAsset, true);
    GotoIf(L0, !EventFlag(activeFlag));
    SetEventFlagID(fogFlag, ON);
L0:
    WaitFor(!EventFlag(activeFlag));
    RestartEvent();
});

// Spawned in front of the fog (bosses.json prepFog): leaving the region around the spawn before going
// through the fog (fogFlag) ends the reflection -> back to the grace, like a loss.
// arenaRegion (0 = none): reaching it before vanilla set fogFlag starts the fight ourselves (Putrescent
// Knight: jumping down somewhere vanilla doesn't mark as the start; the fight needs fogFlag on landing).
$Event(7980012, Restart, function(activeFlag, warpingFlag, wasDefeatedFlag, defeatFlag, fogFlag, prepRegion, arenaRegion) {
    WaitFor(EventFlag(activeFlag) && !EventFlag(warpingFlag));
    WaitFixedTimeSeconds(1);
    GotoIf(L1, Signed(arenaRegion) == 0);
    WaitFor(EventFlag(fogFlag) || !EventFlag(activeFlag) || !InArea(10000, prepRegion) || InArea(10000, arenaRegion));
    GotoIf(L0, EventFlag(fogFlag) || !EventFlag(activeFlag));
    GotoIf(L2, !InArea(10000, arenaRegion));
    SetEventFlagID(fogFlag, ON);
    Goto(L0);
L1:
    WaitFor(EventFlag(fogFlag) || !EventFlag(activeFlag) || !InArea(10000, prepRegion));
    GotoIf(L0, EventFlag(fogFlag) || !EventFlag(activeFlag));
L2:
    SetEventFlagID(activeFlag, OFF);
    if (EventFlag(wasDefeatedFlag)) {
        SetEventFlagID(defeatFlag, ON);
    }
    DisableCharacterImmortality(10000);
    ClearSpEffect(10000, 7980001);
    SetSpEffect(10000, 7980000);
L0:
    WaitFor(!EventFlag(activeFlag));
    RestartEvent();
});
