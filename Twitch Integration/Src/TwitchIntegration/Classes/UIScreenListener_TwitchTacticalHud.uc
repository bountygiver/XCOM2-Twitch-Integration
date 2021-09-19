// Usually we connect to Twitch by responding to the OnTacticalBeginPlay event, but unfortunately,
// that event does not fire when loading into the tactical game directly.
class UIScreenListener_TwitchTacticalHud extends UIScreenListener
    config(NonExistentConfigFile);

var private bool bIsAltDown;
var private bool bIsControlDown;
var privatewrite config bool bPermanentNameplatesEnabled;

event OnInit(UIScreen Screen) {
    local UITacticalHud TacticalHud;

    TacticalHud = UITacticalHud(Screen);
    if (TacticalHud == none) {
        return;
    }

    `TILOGCLS("OnInit 1: Twitch nameplates enabled: " $ default.bPermanentNameplatesEnabled);
    default.bPermanentNameplatesEnabled = false;
    `TILOGCLS("OnInit 2: Twitch nameplates enabled: " $ default.bPermanentNameplatesEnabled);

    TacticalHud.Movie.Stack.SubscribeToOnInputForScreen(TacticalHud, OnTacticalHudInput);

    // Wait a few seconds; when the tactical HUD first loads there may still be a cinematic or loading
    // screen up, so any temporary things we do (like a 'connection successful' toast) will disappear
    // without being seen by the player
    `BATTLE.SetTimer(5.0, /* inBLoop */ false, nameof(SpawnStateManagerIfNeeded), self);

    // Set up a timer to periodically check if units enter/leave LOS and handle their nameplates accordingly
    `BATTLE.SetTimer(0.1, /* inBLoop */ true, nameof(CheckUnitLosStatus), self);
}

event OnRemoved(UIScreen Screen) {
    if (UITacticalHud(Screen) == none) {
        return;
    }

    // Remove timers so we don't leak
    `BATTLE.ClearTimer(nameof(CheckUnitLosStatus), self);
}

protected function CheckUnitLosStatus() {
    local bool bUnitIsVisibleToSquad;
    local UIWorldMessageMgr WorldMessageMgr;
    local UIUnitFlagManager UnitFlagManager;
	local UIUnitFlag UnitFlag;
	local XComGameStateHistory History;
    local XGUnit Unit;

    UnitFlagManager = `PRES.m_kUnitFlagManager;

    if (UnitFlagManager == none) {
        `TILOGCLS("No UnitFlagManager, skipping update to nameplates");
        return;
    }

    foreach `XCOMGAME.AllActors(class'XGUnit', Unit) {
        UnitFlag = UnitFlagManager.GetFlagForObjectID(Unit.ObjectID);

        // If a unit flag exists, simply tie into its state; we'll want to match it as often as possible
        if (UnitFlag != none) {
            bUnitIsVisibleToSquad = UnitFlag.bIsVisible;
        }
        else if (Unit.IsDead()) {
            // Never show nameplates on dead units
            bUnitIsVisibleToSquad = false;
        }
        else  {
            bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);
        }

        if (!bUnitIsVisibleToSquad) {
            class'UIUtilities_Twitch'.static.HideTwitchName(Unit.ObjectID, WorldMessageMgr);
        }
        else if (default.bPermanentNameplatesEnabled)  {
            class'UIUtilities_Twitch'.static.ShowTwitchName(Unit.ObjectID, , /* bPermanent */ true);
        }
    }
}

protected function bool OnTacticalHudInput(UIScreen Screen, int iInput, int ActionMask) {
    if (iInput == class'UIUtilities_Input'.const.FXS_KEY_LEFT_ALT) {
        if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) == class'UIUtilities_Input'.const.FXS_ACTION_PRESS) {
            bIsAltDown = true;
        }
        else if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) {
            bIsAltDown = false;
        }

        // Never consume alt, just track its state
        return false;
    }

    if (iInput == class'UIUtilities_Input'.const.FXS_KEY_LEFT_CONTROL) {
        if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) == class'UIUtilities_Input'.const.FXS_ACTION_PRESS) {
            bIsControlDown = true;
        }
        else if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) == class'UIUtilities_Input'.const.FXS_ACTION_RELEASE) {
            bIsControlDown = false;
        }

        // Never consume control, just track its state
        return false;
    }

    if (iInput == class'UIUtilities_Input'.const.FXS_KEY_T && bIsControlDown && bIsAltDown) {
        if ((ActionMask & class'UIUtilities_Input'.const.FXS_ACTION_PRESS) == class'UIUtilities_Input'.const.FXS_ACTION_PRESS) {
            ToggleNameplates();

            return true;
        }
    }

    return false;
}

private function SpawnStateManagerIfNeeded() {
    if (`TISTATEMGR == none) {
        `XCOMGAME.Spawn(class'TwitchStateManager').Initialize();
    }
}

private function ToggleNameplates() {
    local bool bUnitIsVisibleToSquad;
    local UIWorldMessageMgr WorldMessageMgr;
    local XGUnit Unit;

    default.bPermanentNameplatesEnabled = !default.bPermanentNameplatesEnabled;
    WorldMessageMgr = `PRES.m_kWorldMessageManager;

    `TILOGCLS("Twitch nameplates enabled: " $ default.bPermanentNameplatesEnabled);

    foreach `XCOMGAME.AllActors(class'XGUnit', Unit) {
        if (default.bPermanentNameplatesEnabled) {
            bUnitIsVisibleToSquad = class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID);

            if (bUnitIsVisibleToSquad) {
                class'UIUtilities_Twitch'.static.ShowTwitchName(Unit.ObjectID, , /* bPermanent */ true);
            }
        }
        else {
            class'UIUtilities_Twitch'.static.HideTwitchName(Unit.ObjectID, WorldMessageMgr);
        }
    }
}

defaultproperties
{
    bIsAltDown=false
    bIsControlDown=false
}