DirectDepositEventFrame = CreateFrame("frame", "DirectDeposit Frame");
myPrefixDirectDeposit = "DirectDeposit121";
MyAddOn_CommsDirectDeposit = {};
SLASH_DIRECTDEPOSIT1 = "/dd"
SLASH_DIRECTDEPOSIT2 = "/directdeposit"

local selected, unselected = true, true
local wishSelected, wishUnselected = true, true

local DEBUG_MODE = false

local DirectDeposit_DepositFrame = {};

local isUpdating = false
local depositing = false
local depositedItemCount = 0

local gbankOpen = false

local availableItems = {}
local directDepositGlobalButton = nil

tinsert(UISpecialFrames, DirectDepositEventFrame:GetName())

function SlashCmdList.DIRECTDEPOSIT(msg, editbox)
    local lowerMsg = strlower(strtrim(msg))
    -- if they enter edit, then check if they are an officer and open the edit window
    if lowerMsg == "edit" then
        if(C_GuildInfo.IsGuildOfficer()) then
            DirectDepositEventFrame:CreateWishList();
        else 
            print("You must be an officer to edit the wish list.")
        end
    elseif lowerMsg == "export" then
            DirectDepositEventFrame:export();
    elseif lowerMsg == "import" then
        DirectDepositEventFrame:import();
    elseif lowerMsg == "" then
            DirectDepositEventFrame:CreateDonationList();
    else
        print(msg .. " is not a valid command")
    end
end

function DirectDepositEventFrame:LoadSavedVariables()
    if depositingItems == nil then
        depositingItems = {}
    end
    if requestedItems == nil then
        requestedItems = {}
    end
    if dd_timestamp == nil then
        dd_timestamp = 0
    end
    if not dd_deposit_frame_loc then
        dd_deposit_frame_loc = {"CENTER", UIParent, "CENTER", 0, -100}
    end
end

local function debugPrint(msg)
    if DEBUG_MODE then
        print(msg)
    end
end

local function tprint (tbl, indent)
    if not indent then indent = 0 end
    local toprnt = string.rep(" ", indent) .. "{\r\n"
    indent = indent + 2
    for k, v in pairs(tbl) do
        toprnt = toprnt .. string.rep(" ", indent)
      if (type(k) == "number") then
        toprnt = toprnt .. "[" .. k .. "] = "
      elseif (type(k) == "string") then
        toprnt = toprnt  .. k ..  "= "
      end
      if (type(v) == "number") then
        toprnt = toprnt .. v .. ",\r\n"
      elseif (type(v) == "string") then
        toprnt = toprnt .. "\"" .. v .. "\",\r\n"
      elseif (type(v) == "table") then
        toprnt = toprnt .. tprint(v, indent + 2) .. ",\r\n"
      else
        toprnt = toprnt .. "\"" .. tostring(v) .. "\",\r\n"
      end
    end
    toprnt = toprnt .. string.rep(" ", indent-2) .. "}"
    return toprnt
end

function DirectDepositEventFrame:export()
    -- Get the current dd_timestamp
    local dd_timestamp = time()

    -- Prepare the data to be sent
    local dataToSend = {
        dd_timestamp = dd_timestamp,
        requestedItems = requestedItems
    }

    local serializedString = SerializerDirectDeposit:Serialize(dataToSend)
    local compressedData = DeflaterDirectDeposit:CompressDeflate(serializedString)
    local encodedString = DeflaterDirectDeposit:EncodeForPrint(compressedData)

    local frame = AceGUIDirectDeposit:Create("Frame")
    frame:SetTitle("Export Data")
    frame:SetWidth(400)
    frame:SetHeight(200)

    local editBox = AceGUIDirectDeposit:Create("MultiLineEditBox")
    editBox:SetText(encodedString)
    editBox:SetFullWidth(true)
    editBox.button:Hide()  -- hide the accept button
    frame:AddChild(editBox)

    -- Add the frame as a global variable under the name `DirectDepositExportFrame`
    _G["DirectDepositExportFrame"] = frame.frame
    -- Register the global variable `DirectDepositExportFrame` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "DirectDepositExportFrame")
end

function DirectDepositEventFrame:import(callback)
    local frame = AceGUIDirectDeposit:Create("Frame")
    frame:SetTitle("Import Data")
    frame:SetWidth(400)
    frame:SetHeight(200)

    local editBox = AceGUIDirectDeposit:Create("MultiLineEditBox")
    editBox:SetFullWidth(true)
    editBox.button:Hide()  -- hide the accept button
    frame:AddChild(editBox)

    local button = AceGUIDirectDeposit:Create("Button")
    button:SetText("Import")
    button:SetCallback("OnClick", function()
        local data = editBox:GetText()
        local compressedData = DeflaterDirectDeposit:DecodeForPrint(data)
        local serializedString = DeflaterDirectDeposit:DecompressDeflate(compressedData)
        local success, dataPassed = SerializerDirectDeposit:Deserialize(serializedString)
        if success then
            -- Only overwrite if the passed dd_timestamp is higher than the current one
            if dataPassed.dd_timestamp > dd_timestamp then
                requestedItems = dataPassed.requestedItems
                dd_timestamp = dataPassed.dd_timestamp
                for i, depositItem in ipairs(depositingItems) do
                    -- Assume the item is not in the new requestedItems
                    local found = false
                    -- Check if the item is in the new requestedItems
                    for j, requestItem in ipairs(requestedItems) do
                        if depositItem.name == requestItem.name then
                            found = true
                            break
                        end
                    end
                    -- If the item is not in the new requestedItems, set its state to false
                    if not found then
                        depositItem.state = false
                    end
                end
                print("Import successful!")
            else
                print("Failed to import data. Your version is newer.")
            end
        else
            print("Failed to import data. Please try again with a valid import.")
        end
        frame:Release()
        -- Call the callback function after frame is closed
        if callback then
            callback()
        end
    end)
    frame:AddChild(button)
end

function MyAddOn_CommsDirectDeposit:Init()
    AceCommDirectDeposit:Embed(self)
    self:RegisterComm(self.Prefix, "OnCommReceived")
end

function MyAddOn_CommsDirectDeposit:SendSyncResponse(receiver)
    local dataToSend = {
        type = "dd_sync_response_v1",
        dd_timestamp = dd_timestamp
    }

    local serializedString = SerializerDirectDeposit:Serialize(dataToSend)
    local compressedData = DeflaterDirectDeposit:CompressDeflate(serializedString)
    local encodedString, err = DeflaterDirectDeposit:EncodeForWoWAddonChannel(compressedData)
    debugPrint("did sync encoding and stuff")

    self:SendCommMessage(myPrefixDirectDeposit, encodedString, "WHISPER", receiver)
    debugPrint("sent sync response to " .. receiver)
end

function MyAddOn_CommsDirectDeposit:Distribute()
    -- Get the current dd_timestamp
    dd_timestamp = time()

    -- Prepare the data to be sent
    local dataToSend = {
        type = "dd_distribute_v1",
        dd_timestamp = dd_timestamp,
        requestedItems = requestedItems
    }
    
    local serializedString = SerializerDirectDeposit:Serialize(dataToSend)
    local compressedData = DeflaterDirectDeposit:CompressDeflate(serializedString)
    local encodedString, err = DeflaterDirectDeposit:EncodeForWoWAddonChannel(compressedData)

    -- Send the encoded data to the guild channel
    self:SendCommMessage(myPrefixDirectDeposit, encodedString, "GUILD")

end

function MyAddOn_CommsDirectDeposit:SendUpdate(receiver)
    local dataToSend = {
        type = "dd_update_v1",
        dd_timestamp = dd_timestamp,
        requestedItems = requestedItems
    }

    local serializedString = SerializerDirectDeposit:Serialize(dataToSend)
    local compressedData = DeflaterDirectDeposit:CompressDeflate(serializedString)
    local encodedString, err = DeflaterDirectDeposit:EncodeForWoWAddonChannel(compressedData)

    self:SendCommMessage(myPrefixDirectDeposit, encodedString, "WHISPER", receiver)
end

function MyAddOn_CommsDirectDeposit:OnCommReceived(passedPrefix, msg, distribution, sender)
    if (passedPrefix == myPrefixDirectDeposit) then
        local playerName = UnitName("player")
        if sender == playerName then
            return -- Exit if the sender is the current user
        end

        if msg == "dd_sync_v1" then
            debugPrint("received sync")
            self:SendSyncResponse(sender)
            debugPrint("done sending sync response")
        elseif msg == "dd_request_v1" then
            debugPrint("received request")
            self:SendUpdate(sender)
            debugPrint("done sending update")
        else
            local decodedString = DeflaterDirectDeposit:DecodeForWoWAddonChannel(msg)
            local decompressedData = DeflaterDirectDeposit:DecompressDeflate(decodedString)
            local success, dataReceived = SerializerDirectDeposit:Deserialize(decompressedData)
            if not success then
                print("Deserialization error: ", dataReceived) -- In case of an error, dataReceived is the error message
            else
                if dataReceived.type == "dd_sync_response_v1" then
                    debugPrint("received sync response")
                    if dd_timestamp > dataReceived.dd_timestamp then
                        debugPrint("sending update since my timestamp is newer")
                        self:SendUpdate(sender)
                        debugPrint("done sending update since my timestamp is newer")
                    else
                        debugPrint("sending request since my timestamp is older")
                        self:SendCommMessage(myPrefixDirectDeposit, "dd_request_v1", "WHISPER", sender)
                        debugPrint("done sending request since my timestamp is older")
                    end
                elseif dataReceived.type == "dd_distribute_v1" then
                    debugPrint("received distribute")
                    dd_timestamp = dataReceived.dd_timestamp
                    requestedItems = dataReceived.requestedItems
                    debugPrint("done updating from distribute")
                elseif dataReceived.type == "dd_update_v1" then
                    debugPrint("received update")
                    if dd_timestamp < dataReceived.dd_timestamp then
                        debugPrint("updating from update")
                        dd_timestamp = dataReceived.dd_timestamp
                        requestedItems = dataReceived.requestedItems
                        debugPrint("done updating from update")
                    end
                end
            end
        end
    end
end

function DirectDepositEventFrame:onLoad()
    debugPrint("in onLoad")
    SerializerDirectDeposit = LibStub("LibSerialize");
	DeflaterDirectDeposit = LibStub("LibDeflate");
	AceGUIDirectDeposit = LibStub("AceGUI-3.0");
	AceCommDirectDeposit = LibStub:GetLibrary("AceComm-3.0");
	MyAddOn_CommsDirectDeposit.Prefix = myPrefixDirectDeposit;
	MyAddOn_CommsDirectDeposit:Init();
    debugPrint("done onLoad")
end

function DirectDepositEventFrame:DirectDepositRemoveOldItems()
    local tradeGoods
    local locale = GetLocale()

    -- if there ends up being multiple classic clients, this link has all the enums for the different versions
    -- https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID
    IsClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
    if IsClassic then
        locale = "CataClassic"
    end
    
    function merge_tables(table1, table2)
        local result = {}
        local name_set = {}
        
        local function insert_into_result(t)
            for id, name in pairs(t) do
                if not name_set[name] then
                    result[id] = name
                    name_set[name] = true
                end
            end
        end
        insert_into_result(table1)
        insert_into_result(table2)
    
        return result
    end

    tradeGoods = merge_tables(DirectDeposit_TRADE_GOODS[locale], DirectDeposit_CONSUMABLES[locale])

    -- go through requestedItems and depositingItems and if the item does not exist in tradeGoods, remove it from the list
    for i = #requestedItems, 1, -1 do
        local found = false
        for _, tradeItem in pairs(tradeGoods) do
            if requestedItems[i].name == tradeItem then
                found = true
                break
            end
        end
        if not found then
            table.remove(requestedItems, i)
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BAG_UPDATE")
-- button deposits everything from list, no handling of ranks whatsoever.
function DirectDepositEventFrame:CreateDepositButton()
    -- create the frame to hold the items
    local itemFrame = AceGUIDirectDeposit:Create("Frame")
    itemFrame:SetTitle("DirectDeposit")
    itemFrame:SetWidth(425)
    itemFrame:SetHeight(400)

    local point, relativeToName, relativePoint, xOfs, yOfs = unpack(dd_deposit_frame_loc)
    local relativeTo = _G[relativeToName]
    itemFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)

    itemFrame:SetCallback("OnClose", function(widget)
        local point, relativeTo, relativePoint, xOfs, yOfs = itemFrame:GetPoint()
        -- Set relativeToName to "UIParent" by default
        local relativeToName = "UIParent"
        if relativeTo then
            relativeToName = relativeTo:GetName()
        end
        dd_deposit_frame_loc = {point, relativeToName, relativePoint, xOfs, yOfs}
        AceGUIDirectDeposit:Release(widget)
        -- remove directDepositGlobalButton
        directDepositGlobalButton:Hide()
        directDepositGlobalButton = nil
    end)
    itemFrame:SetLayout("Fill")

    -- Create a ScrollFrame
    local scrollFrame = AceGUIDirectDeposit:Create("ScrollFrame")
    scrollFrame:SetLayout("Flow") 
    itemFrame:AddChild(scrollFrame)

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["itemFrame"] = itemFrame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "itemFrame")

    availableItems = {}
    AllBagIndexes = {
        Enum.BagIndex.Backpack,
        Enum.BagIndex.Bag_1,
        Enum.BagIndex.Bag_2,
        Enum.BagIndex.Bag_3,
        Enum.BagIndex.Bag_4,
    }
    -- determine items available to deposit
    for _, bag in ipairs(AllBagIndexes) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local itemName = GetItemInfo(itemLink)
                for _, item in ipairs(depositingItems) do
                    if item.name == itemName and item.state == true then
                        local linkChanged = (itemLink:gsub("|", "||") )
                        local rank = ""
                        if linkChanged:match("Tier1") then
                            rank = " Rank 1"
                        elseif linkChanged:match("Tier2") then
                            rank = " Rank 2"
                        elseif linkChanged:match("Tier3") then
                            rank = " Rank 3"
                        end
                        local newItem = {
                            name = item.name .. rank,
                            state = item.state
                        }
                        local itemInfo = {
                            bagId = bag,
                            slotId = slot,
                            item = newItem,
                            selected = true
                        }
                        table.insert(availableItems, itemInfo)
                        break
                    end
                end
            end
        end
    end


    -- add each item to the frame
    for i, itemInfo in ipairs(availableItems) do
        local itemLocation = ItemLocation:CreateFromBagAndSlot(itemInfo.bagId, itemInfo.slotId) -- get item location
        local itemCount = C_Item.GetStackCount(itemLocation) -- get item count from item location
        local isSplittable = itemCount and itemCount > 1 -- check if item is splittable

        -- Create a simple group to hold the item
        local itemGroup = AceGUIDirectDeposit:Create("SimpleGroup")
        itemGroup:SetFullWidth(true)
        itemGroup:SetLayout("Flow")
        
        -- Create a CheckBox for selection/deselection, use itemInfo.selected as the initial value and update it when the CheckBox is clicked
        local checkBox = AceGUIDirectDeposit:Create("CheckBox")
        checkBox:SetValue(itemInfo.selected)
        checkBox:SetWidth(30)
        checkBox:SetCallback("OnValueChanged", function(widget, event, value)
            itemInfo.selected = value
        end)
        itemGroup:AddChild(checkBox)
        
        -- Create a label for the name
        local label = AceGUIDirectDeposit:Create("Label")
        local itemName = itemInfo.item.name
        if isSplittable then
            itemName = tostring(itemCount) .. " x " .. itemName
        end
        label:SetText(itemName)
        label:SetWidth(220)
        itemGroup:AddChild(label)
        scrollFrame:AddChild(itemGroup)
        
        -- Create a Button for splitting if the item is splittable
        if isSplittable then
            local splitButton = AceGUIDirectDeposit:Create("Button")
            splitButton:SetText("Split")
            splitButton:SetWidth(100)
            splitButton:SetHeight(25)
            splitButton:SetCallback("OnClick", function(widget)
                -- Create a new frame for the popup
                local frame = AceGUIDirectDeposit:Create("Frame")
                frame:SetTitle("Split Stack")
                frame:SetLayout("Flow")
                frame:SetWidth(200)
                frame:SetHeight(200)
                
                -- Create a Slider for the number with AceGUI
                local slider = AceGUIDirectDeposit:Create("Slider")
                slider:SetLabel("Enter number to split:")
                slider:SetSliderValues(1, itemCount, 1)
                slider:SetValue(1)
                slider:SetCallback("OnValueChanged", function(widget, event, value)
                    local num = tonumber(value)
                    if num then
                        if num < 1 then
                            num = 1
                        elseif num > itemCount then
                            num = itemCount
                        end
                        widget:SetValue(num)
                    end
                end)
                slider:SetCallback("OnEnterPressed", function(widget, event, value)
                    local num = tonumber(value)
                    if num then
                        if num < 1 then
                            num = 1
                        elseif num > itemCount then
                            num = itemCount
                        end
                        widget:SetValue(num)
                    end
                end)
                frame:AddChild(slider)
            
                -- Create a Button for the OK action
                local okButton = AceGUIDirectDeposit:Create("Button")
                okButton:SetText("OK")
                okButton:SetWidth(100)
                okButton:SetCallback("OnClick", function(widget)
                    local value = slider.editbox:GetText()
                    local num = tonumber(value)
                    if num then
                        if num < 1 then
                            num = 1
                        elseif num > itemCount then
                            num = itemCount
                        end
                        slider:SetValue(num)
                    end
                    local num = slider:GetValue()
                    if num and num >= 1 and num <= itemCount then
                        C_Container.SplitContainerItem(itemInfo.bagId, itemInfo.slotId, num)
                        frame:Release()
                        DirectDepositEventFrame:CreateDepositButton()
                    end
                    depositedItemCount = #availableItems
                end)
                frame:AddChild(okButton)
            end)
            itemGroup:AddChild(splitButton)
        end
    end

    local directDepositMyButton = CreateFrame("Button", "directDepositMyButton", itemFrame.frame, "UIPanelButtonTemplate")
    directDepositGlobalButton = directDepositMyButton
    directDepositMyButton:SetSize(100 ,100)
    directDepositMyButton:SetPoint("BOTTOM", 0, -110)
    directDepositMyButton:SetNormalTexture("Interface\\AddOns\\DirectDeposit\\Media\\Icons\\DirectDeposit.jpeg")
    directDepositMyButton:SetText("Deposit")
    directDepositMyButton:SetNormalFontObject(GameFontNormalLarge)
    directDepositMyButton:SetHighlightFontObject(GameFontNormalLarge)

    local buttonText = directDepositMyButton:GetFontString()
    directDepositMyButton:SetNormalFontObject(GameFontNormalLarge)
    buttonText:SetPoint("BOTTOM", directDepositMyButton, "TOP", 0, 0)
    buttonText:SetTextColor(0, 1, 0)

    directDepositMyButton:SetScript("OnClick", function()
        PlaySoundFile("Interface\\AddOns\\DirectDeposit\\Media\\sounds\\ka-ching.mp3")
        local depositedItem = false
        depositedItemCount = 0
        local delay = 0
        depositing = true

        -- deposit all available items selected for deposit
        for _, itemInfo in ipairs(availableItems) do
            if itemInfo.selected then
                C_Timer.After(delay, function()
                    local status, itemLocation = pcall(ItemLocation.CreateFromBagAndSlot, ItemLocation, itemInfo.bagId, itemInfo.slotId) -- get item location
                    if not status then
                        print("Error creating item location: " .. itemLocation) -- itemLocation contains the error message if status is false                    
                    else
                        local itemCount = C_Item.GetStackCount(itemLocation) -- get item count from item location
                        if gbankOpen then
                            print("Depositing " .. itemCount .. " x " .. itemInfo.item.name)
                            C_Container.UseContainerItem(itemInfo.bagId, itemInfo.slotId)
                            depositedItem = true
                            depositedItemCount = depositedItemCount + 1
                        end
                    end
                end)
                delay = delay + 1 -- Increase delay by 1 second for each item
            end
        end

        C_Timer.After(delay, function()
            if not depositedItem then
                print("No items to deposit.")
            else
                print("Thank you for your donations!")
            end
            for _, frame in ipairs(DirectDeposit_DepositFrame) do
                frame:Release()
            end
            DirectDeposit_DepositFrame = {}
            DirectDepositEventFrame:CreateDepositButton() -- Refresh the frame
            depositing = false
        end)
    end)

    table.insert(DirectDeposit_DepositFrame, itemFrame);
    -- Register the BAG_UPDATE event
    local timer = nil
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "BAG_UPDATE" then
            if itemFrame:IsShown() and not isUpdating and not depositing then
                isUpdating = true
                if timer then
                    timer:Cancel()
                end
                timer = C_Timer.NewTimer(0.1, function()
                    for _,frame in ipairs(DirectDeposit_DepositFrame) do
                        frame:Release()
                    end
                    DirectDeposit_DepositFrame = {}
                    DirectDepositEventFrame:CreateDepositButton() -- Refresh the frame
                    isUpdating = false
                end)
            end
        end
    end)
end


function DirectDepositEventFrame:OnEvent(event, ...)
    if(event == "PLAYER_ENTERING_WORLD") then
        debugPrint("PEW.")
        if not SerializerDirectDeposit then
            DirectDepositEventFrame:onLoad();
        end
    elseif(event == "ADDON_LOADED") then
        local text = ...
        if(text == "DirectDeposit") then
            debugPrint("direct deposit loaded")
            DirectDepositEventFrame:LoadSavedVariables();
            DirectDepositRemoveOldItems();

            if not SerializerDirectDeposit then
                DirectDepositEventFrame:onLoad();
            end
            MyAddOn_CommsDirectDeposit:SendCommMessage(myPrefixDirectDeposit, "dd_sync_v1", "GUILD")
            debugPrint("sent addon loaded sync message")
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local type = ...
        if type == 10 then
            gbankOpen = true
            DirectDepositEventFrame:CreateDepositButton();
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local type = ...
        if type == 10 then
            gbankOpen = false
            if DirectDeposit_DepositFrame then
                for _, frame in ipairs(DirectDeposit_DepositFrame) do
                    frame:Hide()
                end
            end
        end
	end
end

DirectDepositEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DirectDepositEventFrame:RegisterEvent("ADDON_LOADED")
DirectDepositEventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
DirectDepositEventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
DirectDepositEventFrame:SetScript("OnEvent", DirectDepositEventFrame.OnEvent);

function DirectDepositEventFrame:CreateWishList()
    local tradeGoods
    local locale = GetLocale()

    -- if there ends up being multiple classic clients, this link has all the enums for the different versions
    -- https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID
    IsClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
    if IsClassic then
        locale = "CataClassic"
    end
    
    function merge_tables(table1, table2)
        local result = {}
        local name_set = {}
        
        local function insert_into_result(t)
            for id, name in pairs(t) do
                if not name_set[name] then
                    result[id] = name
                    name_set[name] = true
                end
            end
        end
        insert_into_result(table1)
        insert_into_result(table2)
    
        return result
    end

    tradeGoods = merge_tables(DirectDeposit_TRADE_GOODS[locale], DirectDeposit_CONSUMABLES[locale])

    -- Create a separate container for the checkboxes
    local checkboxContainer = AceGUIDirectDeposit:Create("SimpleGroup")
    checkboxContainer:SetFullWidth(true)
    checkboxContainer:SetFullHeight(true)
    checkboxContainer:SetLayout("Flow")

    -- is the item being requested
    local function isItemRequested(itemName)
        for _, item in ipairs(requestedItems) do
            if item.name == itemName then
                return item.state
            end
        end
        return false
    end

    -- this does a linear search through requestedItems because requestedItems is setup in a super dumb way. changing would require significant refactoring. possibly in the future
    local function populateItems(items)
        -- cleanup requestedItems and remove legacy items
        for i = #requestedItems, 1, -1 do
            local found = false
            for _, tradeItem in pairs(items) do
                if requestedItems[i].name == tradeItem then
                    found = true
                    break
                end
            end
        end

        
        -- go through the items and create a checkbox for each
        for id, name in pairs(items) do
            local checkbox = AceGUIDirectDeposit:Create("CheckBox")
            checkbox:SetLabel(name)

            -- if the items being requested and the state is true, set to true
            if isItemRequested(name) then
                checkbox:SetValue(true)
            else
                checkbox:SetValue(false)
            end

            checkbox:SetCallback("OnValueChanged", function(_, _, value)
                -- Find the item in requestedItems
                local found = false
                for _, requestedItem in ipairs(requestedItems) do
                    if requestedItem.name == name then
                        -- Update its state if found
                        requestedItem.state = value
                        found = true
                        break
                    end
                end
                -- If not found, add a new item to requestedItems
                if not found then
                    table.insert(requestedItems, {name = name, state = value})
                end
            end)
            checkboxContainer:AddChild(checkbox)
        end
    end

    local function filterItems(searchTerm)
        local requestedItemsLookup = {}
        for _, item in ipairs(requestedItems) do
            requestedItemsLookup[item.name] = item.state
        end
    
        local filteredItems = {}
        for id, name in pairs(tradeGoods) do
            if string.find(name:lower(), searchTerm:lower()) then
                local state = requestedItemsLookup[name] or false
                if (state and wishSelected) or ((not state) and wishUnselected) then
                    filteredItems[id] = name
                end
            end
        end
        return filteredItems
    end

    -- Create the frame container
    local frame = AceGUIDirectDeposit:Create("Frame", "LootSpecHelper Main Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["LootSpecHelperGlobalFrameName"] = frame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "LootSpecHelperGlobalFrameName")

    frame:SetWidth(425)
    frame:SetHeight(500)
    frame:SetTitle("Wish List")
    frame:SetStatusText("Created by Van on Garrosh for JFS.")
    frame:SetCallback("OnClose", function(widget)
        AceGUIDirectDeposit:Release(widget)
    end)
    frame:SetLayout("Flow")

    local testContainer = AceGUIDirectDeposit:Create("SimpleGroup")
    testContainer:SetLayout("Flow")
    testContainer:SetFullHeight(true)
    testContainer:SetFullWidth(true)
    frame:AddChild(testContainer);

    local scrollContainer = AceGUIDirectDeposit:Create("ScrollFrame")
    scrollContainer:SetLayout("List");
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetFullWidth(true)

    -- Add a section header for the filters
    local filterHeader = AceGUIDirectDeposit:Create("Label")
    filterHeader:SetFontObject(GameFontNormalLarge)
    filterHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    filterHeader:SetText("Filters")
    filterHeader:SetFullWidth(true)
    testContainer:AddChild(filterHeader)

    -- Create a search box
    local searchBox = AceGUIDirectDeposit:Create("EditBox")
    searchBox:SetLabel("Search")
    searchBox:SetWidth(200)

    -- add button to export here
    local exportButton = AceGUIDirectDeposit:Create("Button")
    exportButton:SetText("Export")
    exportButton:SetWidth(175)
    exportButton:SetCallback("OnClick", function()
        DirectDepositEventFrame:export()
    end)
    testContainer:AddChild(exportButton)
    
    -- -- Create a save button
    local saveButton = AceGUIDirectDeposit:Create("Button")
    saveButton:SetText("Distribute")
    saveButton:SetWidth(175)
    saveButton:SetCallback("OnClick", function()
        print("List Distributed.")
        MyAddOn_CommsDirectDeposit:Distribute()
    end)
    testContainer:AddChild(saveButton)

    local selectedCheckbox = AceGUIDirectDeposit:Create("CheckBox")
    selectedCheckbox:SetLabel("Selected")
    selectedCheckbox:SetValue(wishSelected)
    selectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        wishSelected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
            scrollContainer:SetScroll(0)
            scrollContainer:DoLayout()
        end)
    end)
    testContainer:AddChild(selectedCheckbox)

    local unselectedCheckbox = AceGUIDirectDeposit:Create("CheckBox")
    unselectedCheckbox:SetLabel("Unselected")
    unselectedCheckbox:SetValue(wishUnselected)
    unselectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        wishUnselected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
            scrollContainer:SetScroll(0)
            scrollContainer:DoLayout()
        end)
    end)
    testContainer:AddChild(unselectedCheckbox)

    testContainer:AddChild(searchBox)

    -- Add a section header for the items
    local itemsHeader = AceGUIDirectDeposit:Create("Label")
    itemsHeader:SetFontObject(GameFontNormalLarge)
    itemsHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    itemsHeader:SetText("Items")
    itemsHeader:SetFullWidth(true)
    testContainer:AddChild(itemsHeader)

    searchBox:SetCallback("OnTextChanged", function(_, _, value)
        checkboxContainer:ReleaseChildren()
        
        local filteredItems = filterItems(value)
        populateItems(filteredItems)
        scrollContainer:SetScroll(0)
        scrollContainer:DoLayout()
    end)

    populateItems(tradeGoods) -- this is the bottle neck.
    scrollContainer:AddChild(checkboxContainer)
    testContainer:AddChild(scrollContainer)
end

function DirectDepositEventFrame:CreateDonationList()
    -- Function to find an item in depositingItems by name
    local function findItem(name)
        for _, item in ipairs(depositingItems) do
            if item.name == name then
                return item
            end
        end
        return nil
    end

    -- Create a separate container to hold the checkboxes for each item
    local checkboxContainer = AceGUIDirectDeposit:Create("SimpleGroup")
    checkboxContainer:SetFullWidth(true)
    checkboxContainer:SetFullHeight(true)
    checkboxContainer:SetLayout("Flow")

    local function populateItems(items)
        local locale = GetLocale()

        -- if there ends up being multiple classic clients, this link has all the enums for the different versions
        -- https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID
        IsClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE
        if IsClassic then
            locale = "CataClassic"
        end
        tradeGoods = DirectDeposit_TRADE_GOODS[locale]
        -- cleanup requestedItems and remove legacy items
        for i = #requestedItems, 1, -1 do
            local found = false
            for _, tradeItem in pairs(tradeGoods) do
                if requestedItems[i].name == tradeItem then
                    found = true
                    break
                end
            end
            if not found then
                table.remove(requestedItems, i)
            end
        end

        for _, item in ipairs(items) do
            if item.state == true then
                local checkbox = AceGUIDirectDeposit:Create("CheckBox")
                checkbox:SetLabel(item.name)

                -- Find the item in depositingItems and use its state as the initial value
                local depositingItem = findItem(item.name)
                if depositingItem then
                    checkbox:SetValue(depositingItem.state)
                else
                    checkbox:SetValue(false)
                end

                checkbox:SetCallback("OnValueChanged", function(_, _, value)
                    -- Find the item in depositingItems
                    local depositingItem = findItem(item.name)
                    if depositingItem then
                        -- If the item is found, update its state
                        depositingItem.state = value
                    else
                        -- If the item is not found, add it to depositingItems with the new state
                        table.insert(depositingItems, {name = item.name, state = value})
                    end
                end)
                checkboxContainer:AddChild(checkbox)
            end
        end
    end

    local function filterItems(searchTerm)
        local depositingItemsLookup = {}
        for _, item in ipairs(depositingItems) do
            depositingItemsLookup[item.name] = item
        end

        local filteredItems = {}
        for _, item in ipairs(requestedItems) do
            if string.find(item.name:lower(), searchTerm:lower()) then
                local depItem = depositingItemsLookup[item.name]
                local state = depItem and depItem.state or false
                if (state and selected) or (not state and unselected) then
                    table.insert(filteredItems, item)
                end
            end
        end
        return filteredItems
    end

    -- Create the frame container
    local frame = AceGUIDirectDeposit:Create("Frame", "LootSpecHelper Main Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["LootSpecHelperGlobalFrameName"] = frame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "LootSpecHelperGlobalFrameName")

    frame:SetWidth(425)
    frame:SetHeight(500)
    frame:SetTitle("Donation List")
    frame:SetStatusText("Created by Van on Garrosh for JFS.")
    frame:SetCallback("OnClose", function(widget)
        AceGUIDirectDeposit:Release(widget)
    end)
    frame:SetLayout("Flow")

    local testContainer = AceGUIDirectDeposit:Create("SimpleGroup")
    testContainer:SetLayout("Flow")
    testContainer:SetFullHeight(true)
    testContainer:SetFullWidth(true)
    frame:AddChild(testContainer);

    local scrollContainer = AceGUIDirectDeposit:Create("ScrollFrame")
    scrollContainer:SetLayout("List");
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetFullWidth(true)

    -- Add a section header for the filters
    local filterHeader = AceGUIDirectDeposit:Create("Label")
    filterHeader:SetFontObject(GameFontNormalLarge)
    filterHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    filterHeader:SetText("Filters")
    filterHeader:SetFullWidth(true)
    testContainer:AddChild(filterHeader)

    -- Create a search box
    local searchBox = AceGUIDirectDeposit:Create("EditBox")
    searchBox:SetLabel("Search")
    searchBox:SetWidth(200)

    -- add button to import here
    local importButton = AceGUIDirectDeposit:Create("Button")
    importButton:SetText("Import")
    importButton:SetCallback("OnClick", function()
        DirectDepositEventFrame:import(function()
            checkboxContainer:ReleaseChildren()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
        end)
    end)
    testContainer:AddChild(importButton)

    local selectedCheckbox = AceGUIDirectDeposit:Create("CheckBox")
    selectedCheckbox:SetLabel("Selected")
    selectedCheckbox:SetValue(selected)
    selectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        selected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
            scrollContainer:SetScroll(0)
            scrollContainer:DoLayout()
        end)
    end)
    testContainer:AddChild(selectedCheckbox)

    local unselectedCheckbox = AceGUIDirectDeposit:Create("CheckBox")
    unselectedCheckbox:SetLabel("Unselected")
    unselectedCheckbox:SetValue(unselected)
    unselectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        unselected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
            scrollContainer:SetScroll(0)
            scrollContainer:DoLayout()
        end)
    end)
    testContainer:AddChild(unselectedCheckbox)

    testContainer:AddChild(searchBox)

    -- Add a section header for the items
    local itemsHeader = AceGUIDirectDeposit:Create("Label")
    itemsHeader:SetFontObject(GameFontNormalLarge)
    itemsHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    itemsHeader:SetText("Items - " .. dd_timestamp)
    itemsHeader:SetWidth(200)

    testContainer:AddChild(itemsHeader)

    searchBox:SetCallback("OnTextChanged", function(_, _, value)
        checkboxContainer:ReleaseChildren()

        local filteredItems = filterItems(value)
        populateItems(filteredItems)
        scrollContainer:SetScroll(0)
        scrollContainer:DoLayout()
    end)

    populateItems(requestedItems)
    scrollContainer:AddChild(checkboxContainer)
    testContainer:AddChild(scrollContainer)
end
