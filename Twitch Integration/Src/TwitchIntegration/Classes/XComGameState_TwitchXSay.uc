class XComGameState_TwitchXSay extends XComGameState_BaseObject;

var string MessageBody;
var string Sender;
var int SendingUnitObjectID;
var string TwitchMessageId;
var bool bMessageDeleted;

defaultproperties
{
    bTacticalTransient = true
}