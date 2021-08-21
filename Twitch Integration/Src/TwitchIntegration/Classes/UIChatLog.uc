class UIChatLog extends UIPanel
    config(TwitchChatCommands)
    dependson(TwitchIntegrationConfig);

var localized string ClearButtonLabel;

var config float TimeToShowOnMessageReceived;

struct ChatMessage {
    var string Sender;
    var string Body;
    var string MsgId;
    var XComGameState_Unit Unit;
};

var private int XPos;

var private UIButton m_ClearButton;
var private UIButton m_ExpandCollapseButton;
var private UITextContainer m_TextContainer;

var private array<ChatMessage> Messages;

function UIChatLog InitChatLog(int InitX, int InitY, int InitWidth, int InitHeight) {
    local Object ThisObj;
    InitPanel();
    SetPosition(InitX, InitY);
    SetSize(InitWidth, InitHeight);

    m_TextContainer = Spawn(class'UITextContainer', self);
    m_TextContainer.InitTextContainer('', "", InitX, InitY, InitWidth, InitHeight, /* addBG */ true, class'UIUtilities_Controls'.const.MC_X2BackgroundSimple);
    m_TextContainer.SetAlpha(0.8);

    m_ClearButton = Spawn(class'UIButton', self);
    m_ClearButton.InitButton(/* InitName */, ClearButtonLabel, OnClearButtonClicked);
    m_ClearButton.SetAlpha(0.8);
    m_ClearButton.SetPosition(InitX, m_TextContainer.Y + m_TextContainer.Height + 8);

    // TODO: get an actual icon on this button somehow
    m_ExpandCollapseButton = Spawn(class'UIButton', self);
    m_ExpandCollapseButton.ResizeToText = false;
    m_ExpandCollapseButton.InitButton(/* InitName */, "&lt;", OnExpandCollapseButtonClicked);
    m_ExpandCollapseButton.SetAlpha(0.8);
    m_ExpandCollapseButton.SetPosition(InitX + m_TextContainer.Width + 3, m_TextContainer.Y);
    m_ExpandCollapseButton.SetSize(28, 28);

    ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'TwitchModConfigSaved', OnModConfigChanged, ELD_Immediate);

    Collapse();

    if (!`TI_CFG(bShowChatLog)) {
        Hide();
    }

    return self;
}

function AddMessage(string Sender, string Body, optional XComGameState_Unit Unit, optional string MsgId) {
    local ChatMessage Message;

    // Do formatting on display, not storage, in case user config changes at runtime
    Message.Body = Body;
    Message.Sender = Sender;
    Message.Unit = Unit;
    Message.MsgId = MsgId;

    // TODO: probably a good idea to have a max chat history size at some point?
    Messages.AddItem(Message);

    // TODO: don't expand if it was manually collapsed; make expand button flash instead
    UpdateUI();
    Expand();
    ClearTimer('Collapse');

    if (TimeToShowOnMessageReceived > 0) {
        SetTimer(TimeToShowOnMessageReceived, /* inBLoop */ false, 'Collapse');
    }
}

function Collapse() {
    XPos = X;

    // animate off screen
    AnimateX(-m_TextContainer.width);
    m_ExpandCollapseButton.SetText("&gt;");
}

function Expand() {
    // animate back on screen
    AnimateX(XPos);
    m_ExpandCollapseButton.SetText("&lt;");
}

function bool IsCollapsed() {
    return X < 0;
}

private function string FormatMessageBody(string Body, optional XComGameState_Unit Unit) {
    Body = class'TextUtilities_Twitch'.static.SanitizeText(Body);

    if (Unit == none) {
        return Body;
    }

    if (`TI_CFG(bFormatDeadMessages) && Unit.IsDead()) {
        Body = "..." @ LOCS(Body) @ "...";
    }

    return Body;
}

private function string FormatSenderName(string Sender, optional XComGameState_Unit Unit) {
    local bool bIsFriendlyUnit;
    local string SenderColor;
    local eTwitchConfig_ChatLogColorScheme ColorScheme;
    local eTwitchConfig_ChatLogNameFormat NameFormat;
    local TwitchViewer Viewer;
    local XComGameState_TwitchObjectOwnership Ownership;

    if (Unit == none) {
        return Sender;
    }

    bIsFriendlyUnit = Unit.GetTeam() == eTeam_XCom;
    NameFormat = bIsFriendlyUnit ? `TI_CFG(ChatLogFriendlyNameFormat) : `TI_CFG(ChatLogEnemyNameFormat);
    Ownership = class'XComGameState_TwitchObjectOwnership'.static.FindForObject(Unit.GetReference().ObjectID);

    // Only use full name for friendly units, or visible enemy units
    if (NameFormat == ETC_UnitNameOnly && (bIsFriendlyUnit || class'X2TacticalVisibilityHelpers'.static.CanXComSquadSeeTarget(Unit.ObjectID))) {
        Sender = Unit.GetFullName();
    }

    ColorScheme = `TI_CFG(ChatLogColorScheme);

    if (ColorScheme == ETC_TwitchColors) {
        if (`TISTATEMGR.TwitchChatConn.GetViewer(Ownership.TwitchLogin, Viewer) != INDEX_NONE) {
            SenderColor = Mid(Viewer.ChatColor, 1); // strip leading # from color
        }
    }
    else if (ColorScheme == ETC_TeamColors) {
        switch (Unit.GetTeam()) {
            case eTeam_Alien:
                SenderColor = class'UIUtilities_Colors'.const.BAD_HTML_COLOR;
                break;
            case eTeam_TheLost:
                SenderColor = class'UIUtilities_Colors'.const.THELOST_HTML_COLOR;
                break;
            default:
                SenderColor = class'UIUtilities_Colors'.const.NORMAL_HTML_COLOR;
                break;
        }
    }

    // bFormatDeadMessages takes priority over other color options
    if (`TI_CFG(bFormatDeadMessages) && Unit.IsDead()) {
        SenderColor = class'UIUtilities_Colors'.const.DISABLED_HTML_COLOR;
    }

    if (SenderColor != "") {
        Sender = "<font color='#" $ SenderColor $ "'>" $ Sender $ "</font>";
    }

    return Sender;
}

private function OnClearButtonClicked(UIButton Button) {
    Messages.Length = 0;
    UpdateUI();
}

private function OnExpandCollapseButtonClicked(UIButton Button) {
    ClearTimer('Collapse');

    if (IsCollapsed()) {
        Expand();
    }
    else {
        Collapse();
    }
}

private function EventListenerReturn OnModConfigChanged(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData) {
    // Re-render all messages in case we've changed our display settings
    UpdateUI();

    return ELR_NoInterrupt;
}

private function UpdateUI() {
    local string FullChat;
    local string FormattedMessage;
    local ChatMessage Message;

    if (!`TI_CFG(bShowChatLog)) {
        Hide();
        return;
    }

    Show();

    foreach Messages(Message) {
        FormattedMessage = FormatSenderName(Message.Sender, Message.Unit) $ ": " $ FormatMessageBody(Message.Body, Message.Unit);

        if (FullChat == "") {
            FullChat = FormattedMessage;
        }
        else {
            FullChat = FullChat $ "\n" $ FormattedMessage;
        }
    }

    // Individual messages can wrap but UITextContainer doesn't realize that when scrolling, so
    // we add a couple of newlines to move it along
    FullChat = FullChat $ "\n\n";

    m_TextContainer.SetHTMLText(FullChat);
    m_TextContainer.Scrollbar.SetThumbAtPercent(1.0);
}