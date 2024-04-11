DirectDepositEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DirectDepositEventFrame:SetScript("OnEvent", DirectDepositEventFrame.OnEvent);

DirectDepositEventFrame = CreateFrame("frame", "DirectDeposit Frame");
myPrefix = "DirectDeposit121";
MyAddOn_Comms = {};
SLASH_DIRECTDEPOSIT1 = "/dp"
SLASH_DIRECTDEPOSIT2 = "/directdeposit"

tinsert(UISpecialFrames, DirectDepositEventFrame:GetName())

function SlashCmdList.LOOTSPECHELPER(msg, editbox)
    -- pass the players name into the IsGuildLeader function
    if(IsGuildLeader(UnitName("player") or UnitName("player") == "Vandredor")) then
        print("testing")
        --DirectDepositEventFrame:CreateEditListWindow();
    end
end

function DirectDepositEventFrame:OnEvent(event, text)
    if(event == "PLAYER_ENTERING_WORLD") then
		DirectDepositEventFrame:onLoad();
	end
end

function DirectDepositEventFrame:OnLoad()
    Serializer=LibStub("LibSerialize");
	Deflater = LibStub("LibDeflate");
	AceGUI = LibStub("AceGUI-3.0");
	AceComm = LibStub:GetLibrary("AceComm-3.0");
	MyAddOn_Comms.Prefix = myPrefix;
	MyAddOn_Comms:Init();
end

function MyAddOn_Comms:Init()
    AceComm:Embed(self);
    self:RegisterComm(self.Prefix, "OnCommReceived");
end

