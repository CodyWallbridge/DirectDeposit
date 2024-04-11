DirectDepositEventFrame = CreateFrame("frame", "DirectDeposit Frame");
myPrefix = "DirectDeposit121";
MyAddOn_Comms = {};
SLASH_DIRECTDEPOSIT1 = "/dd"
SLASH_DIRECTDEPOSIT2 = "/directdeposit"

tinsert(UISpecialFrames, DirectDepositEventFrame:GetName())

DirectDepositEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DirectDepositEventFrame:SetScript("OnEvent", DirectDepositEventFrame.OnEvent);

function SlashCmdList.DIRECTDEPOSIT(msg, editbox)
    if(IsGuildLeader(UnitName("player")) or UnitName("player") == "Vandredor") then
    -- in the future if we want to move to officers can use C_GuildInfo.IsGuildOfficer() instead. Also could use a whitelist style
        print("Hey you are very important - either the GM or Van. Van's most important though.")
        DirectDepositEventFrame:CreateEditListWindow();
    else
        print("You are not the guild leader")
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

function DirectDepositEventFrame:CreateEditListWindow()
    -- Create the frame container
    local frame = AceGUI:Create("Frame", "LootSpecHelper Main Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["LootSpecHelperGlobalFrameName"] = frame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "LootSpecHelperGlobalFrameName")

    frame:SetWidth(425)
    frame:SetHeight(500)
    frame:SetTitle("DirectDeposit")
    frame:SetStatusText("Created by Van on Garrosh.")
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
    end)

    -- test table for items
    local items = {
        {name = "Tattered Wildercloth"},
        {name = "Wildercloth"}
    }
    -- for each item in the table of items, create a checkbox with the item name and add it to a scrollable container which would be within frame
    -- Create a SimpleGroup (which is scrollable)
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)  -- optionally make it fill the whole frame
    frame:AddChild(scrollContainer)

    -- for each item in the table of items, create a checkbox with the item name and add it to the scrollable container
    for _, item in ipairs(items) do
        local checkbox = AceGUI:Create("CheckBox")
        checkbox:SetLabel(item.name)
        checkbox:SetValue(false)
        scrollContainer:AddChild(checkbox)
    end
end
