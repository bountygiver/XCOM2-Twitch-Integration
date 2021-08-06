//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_TwitchIntegration.uc
//
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the
//  player creates a new campaign or loads a saved game.
//
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_TwitchIntegration extends X2DownloadableContentInfo
	dependson(XComGameState_TwitchEventPoll);

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{
}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{
}

/// <summary>
/// Casts a vote in the current poll as though it was cast by the specified viewer.
/// </summary>
exec function TwitchCastVote(string ViewerName, int Option) {
	class'X2TwitchUtils'.static.GetStateManager().CastVote(ViewerName, Option - 1);
}

/// <summary>
/// Executes a Twitch command as though it were coming from the specified viewer.
/// </summary>
exec function TwitchChatCommand(string Command, string ViewerName, string CommandBody) {
    class'X2TwitchUtils'.static.GetStateManager().HandleChatCommand(Command, ViewerName, CommandBody);
}

/// <summary>
/// Connects to Twitch chat, forcibly disconnecting first if bForceReconnect is true.
/// </summary>
exec function TwitchConnect(bool bForceReconnect = false) {
    class'X2TwitchUtils'.static.GetStateManager().ConnectToTwitchChat(bForceReconnect);
}

exec function TwitchDebugSendRawIrc(string RawIrcMessage) {
    class'X2TwitchUtils'.static.GetStateManager().TwitchChatConn.DebugSendRawIrc(RawIrcMessage);
}

/// <summary>
/// Ends the currently running poll, if any.
/// </summary>
exec function TwitchEndPoll() {
	class'X2TwitchUtils'.static.GetStateManager().ResolveCurrentPoll();
}

/// <summary>
/// Immediately executes the action with the given name (as specified in config).
/// </summary>
exec function TwitchExecuteAction(name ActionName) {
    local X2TwitchEventActionTemplate Action;

    Action = class'X2TwitchUtils'.static.GetTwitchEventActionTemplate(ActionName);

    if (Action == none) {
        class'Helpers'.static.OutputMsg("Did not find an Action template called " $ ActionName);
        return;
    }

    Action.Apply();
}

/// <summary>
/// Lists all viewers who own a unit. Does not distinguish between dead and living units, or units which aren't
/// on the current mission if any (such as Chosen or XCOM soldiers).
/// </summary>
exec function TwitchListRaffledViewers() {
    local XComGameState_TwitchObjectOwnership OwnershipState;

    foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_TwitchObjectOwnership', OwnershipState) {
        class'Helpers'.static.OutputMsg("Object ID " $ OwnershipState.OwnedObjectRef.ObjectID $ " owned by viewer " $ OwnershipState.TwitchUsername);
    }
}

/// <summary>
/// Executes a quick poll with predetermined results for testing purposes.
/// </summary>
exec function TwitchQuickPoll(ePollType PollType) {
    TwitchStartPoll(PollType, 2);
    TwitchCastVote("user1", 1);
    TwitchCastVote("user2", 2);
    TwitchCastVote("user3", 2);
    TwitchEndPoll();
}

/// <summary>
/// Re-raffles the unit closest to the mouse cursor. Follows standard raffle rules, so XCOM soldiers
/// cannot be re-raffled using this method.
/// </summary>
exec function TwitchRaffleUnitUnderMouse() {
	local XComGameState NewGameState;
	local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

	Unit = `CHEATMGR.GetClosestUnitToCursor(, /* bConsiderDead */ true);
	if (Unit == none) {
        return;
    }

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    if (OwnershipState != none) {
        class'Helpers'.static.OutputMsg("Deleting ownership data for unit..");

        // Delete the existing ownership so this unit can be raffled
        NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Console: Reassign Owner");
        NewGameState.RemoveStateObject(OwnershipState.ObjectID);
        `TACTICALRULES.SubmitGameState(NewGameState);
    }

    class'Helpers'.static.OutputMsg("Triggering raffle of all unowned units");
    `XEVENTMGR.TriggerEvent('TwitchAssignUnitNames');
}

/// <summary>
/// Reassigns ownership of the unit closest to the mouse cursor to the given viewer. This method does not
/// use any raffling, and does work on XCOM soldiers. It also works on dead units.
/// </summary>
exec function TwitchReassignUnitUnderMouse(string ViewerName) {
	local XComGameState NewGameState;
	local XComGameState_TwitchObjectOwnership OwnershipState;
	local XComGameState_Unit Unit;

	Unit = `CHEATMGR.GetClosestUnitToCursor(, /* bConsiderDead */ true);
	if (Unit == none) {
        return;
    }

    // TODO: need to make sure the given viewer doesn't already own something

    OwnershipState = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.ObjectID);

    // Don't submit a game state if we aren't changing anything
    if (OwnershipState != none && OwnershipState.TwitchUsername == ViewerName) {
        return;
    }

    if (OwnershipState == none && ViewerName == "") {
        return;
    }

    class'Helpers'.static.OutputMsg("Reassigning owner of '" $ Unit.GetFullName() $ "' to viewer '" $ ViewerName $ "'");

    NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Twitch Console: Reassign Owner");

    // TODO: this isn't following the rules to change the unit name or other side effects of ownership
    if (ViewerName == "") {
        // We're unsetting ownership without setting new ownership
        NewGameState.RemoveStateObject(OwnershipState.ObjectID);
    }
    else {
        if (OwnershipState == none) {
            OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.CreateStateObject(class'XComGameState_TwitchObjectOwnership'));
        }
        else {
            OwnershipState = XComGameState_TwitchObjectOwnership(NewGameState.ModifyStateObject(class'XComGameState_TwitchObjectOwnership', OwnershipState.ObjectID));
        }

        OwnershipState.TwitchUsername = ViewerName;
    }

    `TACTICALRULES.SubmitGameState(NewGameState);
}

/// <summary>
/// Starts a new poll with randomly-selected events from the given poll type.
/// </summary>
exec function TwitchStartPoll(ePollType PollType, int DurationInTurns) {
	class'X2TwitchUtils'.static.GetStateManager().StartPoll(PollType, DurationInTurns);
}