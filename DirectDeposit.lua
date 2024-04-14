DirectDepositEventFrame = CreateFrame("frame", "DirectDeposit Frame");
myPrefix = "DirectDeposit121";
MyAddOn_Comms = {};
SLASH_DIRECTDEPOSIT1 = "/dd"
SLASH_DIRECTDEPOSIT2 = "/directdeposit"

local selected, unselected = true, true
local wishSelected, wishUnselected = true, true

tinsert(UISpecialFrames, DirectDepositEventFrame:GetName())

-- remove duplicates from each of the locale tables
for locale, items in pairs(LOCALE) do
    local uniqueItems = {}
    local uniqueNames = {}
    for id, name in pairs(items) do
        if not uniqueNames[name] then
            uniqueItems[id] = name
            uniqueNames[name] = true
        end
    end
    LOCALE[locale] = uniqueItems
end

function DirectDepositEventFrame:onLoad()
    Serializer = LibStub("LibSerialize");
	Deflater = LibStub("LibDeflate");
	AceGUI = LibStub("AceGUI-3.0");
	AceComm = LibStub:GetLibrary("AceComm-3.0");
	MyAddOn_Comms.Prefix = myPrefix;
	MyAddOn_Comms:Init();
end

function DirectDepositEventFrame:OnEvent(event, text)
    if(event == "PLAYER_ENTERING_WORLD") then
		DirectDepositEventFrame:onLoad();
    elseif(event == "ADDON_LOADED") then
        if(text == "DirectDeposit") then
            DirectDepositEventFrame:LoadSavedVariables();
        end
	end
end

DirectDepositEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
DirectDepositEventFrame:RegisterEvent("ADDON_LOADED")
DirectDepositEventFrame:SetScript("OnEvent", DirectDepositEventFrame.OnEvent);

function DirectDepositEventFrame:LoadSavedVariables()
    if depositingItems == nil then
        depositingItems = {}
    end
    if requestedItems == nil then
        requestedItems = {}
    end
end


function DirectDepositEventFrame:export()
    local serializedString = Serializer:Serialize(requestedItems)
    local compressedData = Deflater:CompressDeflate(serializedString)
    local encodedString = Deflater:EncodeForPrint(compressedData)

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Export Data")
    frame:SetWidth(400)
    frame:SetHeight(200)

    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetText(encodedString)
    editBox:SetFullWidth(true)
    editBox.button:Hide()  -- hide the accept button
    frame:AddChild(editBox)

    -- Add the frame as a global variable under the name `DirectDepositEventFrameGlobal`
    _G["DirectDepositEventFrameGlobal"] = frame.frame
    -- Register the global variable `DirectDepositEventFrameGlobal` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "DirectDepositEventFrameGlobal")
end

function DirectDepositEventFrame:import()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Import Data")
    frame:SetWidth(400)
    frame:SetHeight(200)

    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetFullWidth(true)
    editBox.button:Hide()  -- hide the accept button
    frame:AddChild(editBox)

    local button = AceGUI:Create("Button")
    button:SetText("Import")
    button:SetCallback("OnClick", function()
        local data = editBox:GetText()
        local compressedData = Deflater:DecodeForPrint(data)
        local serializedString = Deflater:DecompressDeflate(compressedData)
        local success, requestedItems = Serializer:Deserialize(serializedString)
        if success then
            requestedItems = requestedItems
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
            print("Failed to import data. Please try again with a valid import.")
        end
        frame:Release()
    end)
    frame:AddChild(button)
end

function SlashCmdList.DIRECTDEPOSIT(msg, editbox)
    -- if they enter edit, then check if they are the gm and open the edit window
    if strtrim(msg) == "edit" then
        -- if(IsGuildLeader(UnitName("player")) or UnitName("player") == "Vandredor") then
        if(C_GuildInfo.IsGuildOfficer() or UnitName("player") == "Vandredor") then
        --if(C_GuildInfo.IsGuildOfficer()) then -- does not work for myself. need to test with officer, gm and gm alts.
            print("Hey you are very important - either the GM or Van. Van's most important though.")
            DirectDepositEventFrame:CreateWishList();
        else
            print("You are not an officer.")
        end
    -- if they dont enter edit, then open the selection window
    else
        DirectDepositEventFrame:CreateDonationList();
    end
end

-- filler for lua errors
function MyAddOn_Comms:Init()
    AceComm:Embed(self);
    self:RegisterComm(self.Prefix, "OnCommReceived");
end

function MyAddOn_Comms:OnCommReceived(passedPrefix, msg, distribution, sender)
    if (passedPrefix == myPrefix) then
        print("sure")
    end--if
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

    -- Create a separate container for the checkboxes
    local checkboxContainer = AceGUI:Create("SimpleGroup")
    checkboxContainer:SetFullWidth(true)
    checkboxContainer:SetFullHeight(true)
    checkboxContainer:SetLayout("Flow")

    local function populateItems(items)
        for _, item in ipairs(items) do
            local checkbox = AceGUI:Create("CheckBox")
            checkbox:SetLabel(item.name)

            -- Find the item in depositingItems and use its state as the initial value
            local depositingItem = findItem(item.name)
            if depositingItem then
                checkbox:SetValue(depositingItem.state or false)
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
    local frame = AceGUI:Create("Frame", "LootSpecHelper Main Frame")

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
        AceGUI:Release(widget)
    end)
    frame:SetLayout("Flow")

    local testContainer = AceGUI:Create("SimpleGroup")
    testContainer:SetLayout("Flow")
    testContainer:SetFullHeight(true)
    testContainer:SetFullWidth(true)
    frame:AddChild(testContainer);

    local scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("List");
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetFullWidth(true)

    -- Add a section header for the filters
    local filterHeader = AceGUI:Create("Label")
    filterHeader:SetFontObject(GameFontNormalLarge)
    filterHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    filterHeader:SetText("Filters")
    filterHeader:SetFullWidth(true)
    testContainer:AddChild(filterHeader)

    -- Create a search box
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Search")
    searchBox:SetWidth(200)

    -- add button to import here
    local importButton = AceGUI:Create("Button")
    importButton:SetText("Import")
    importButton:SetCallback("OnClick", function()
        DirectDepositEventFrame:import()
    end)
    testContainer:AddChild(importButton)

    local selectedCheckbox = AceGUI:Create("CheckBox")
    selectedCheckbox:SetLabel("Selected")
    selectedCheckbox:SetValue(selected)
    selectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        selected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
        end)
    end)
    testContainer:AddChild(selectedCheckbox)

    local unselectedCheckbox = AceGUI:Create("CheckBox")
    unselectedCheckbox:SetLabel("Unselected")
    unselectedCheckbox:SetValue(unselected)
    unselectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        unselected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
        end)
    end)
    testContainer:AddChild(unselectedCheckbox)

    testContainer:AddChild(searchBox)

    -- Add a section header for the items
    local itemsHeader = AceGUI:Create("Label")
    itemsHeader:SetFontObject(GameFontNormalLarge)
    itemsHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    itemsHeader:SetText("Items")
    itemsHeader:SetFullWidth(true)
    testContainer:AddChild(itemsHeader)

    searchBox:SetCallback("OnTextChanged", function(_, _, value)
        checkboxContainer:ReleaseChildren()

        local filteredItems = filterItems(value)
        populateItems(filteredItems)
    end)

    populateItems(requestedItems)
    scrollContainer:AddChild(checkboxContainer)
    testContainer:AddChild(scrollContainer)
end

function DirectDepositEventFrame:CreateWishList()
    local tradeGoods
    local locale = GetLocale()
    -- en_US, en_GB
    -- es_MX, es_ES
    -- zh_CN, zh_TW
    if locale == "pt_BR" then
        tradeGoods = LOCALE["pt_BR"]
    elseif locale == "es_MX" or locale == "es_ES" then
        tradeGoods = LOCALE["es_MX"]
    elseif locale == "de_DE" then
        tradeGoods = LOCALE["de_DE"]
    elseif locale == "fr_FR" then
        tradeGoods = LOCALE["fr_FR"]
    elseif locale == "it_IT" then
        tradeGoods = LOCALE["it_IT"]
    elseif locale == "ru_RU" then
        tradeGoods = LOCALE["ru_RU"]
    elseif locale == "ko_KR" then
        tradeGoods = LOCALE["ko_KR"]
    elseif locale == "zh_CN" or locale == "zh_TW" then
        tradeGoods = LOCALE["zh_CN"]
    else
        tradeGoods = LOCALE["en_US"]
    end

    -- is the item being requested
    local function isItemRequested(itemName)
        for _, item in ipairs(requestedItems) do
            if item.name == itemName then
                return item.state
            end
        end
        return false
    end

    -- Create a separate container for the checkboxes
    local checkboxContainer = AceGUI:Create("SimpleGroup")
    checkboxContainer:SetFullWidth(true)
    checkboxContainer:SetFullHeight(true)
    checkboxContainer:SetLayout("Flow")

    local function populateItems(items)
        for id, name in pairs(items) do
            local checkbox = AceGUI:Create("CheckBox")
            checkbox:SetLabel(name)

            -- if the item is in requestedItems, its state is true, otherwise it is false
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
    local frame = AceGUI:Create("Frame", "LootSpecHelper Main Frame")

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
        AceGUI:Release(widget)
    end)
    frame:SetLayout("Flow")

    local testContainer = AceGUI:Create("SimpleGroup")
    testContainer:SetLayout("Flow")
    testContainer:SetFullHeight(true)
    testContainer:SetFullWidth(true)
    frame:AddChild(testContainer);

    local scrollContainer = AceGUI:Create("ScrollFrame")
    scrollContainer:SetLayout("List");
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetFullWidth(true)

    -- Add a section header for the filters
    local filterHeader = AceGUI:Create("Label")
    filterHeader:SetFontObject(GameFontNormalLarge)
    filterHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    filterHeader:SetText("Filters")
    filterHeader:SetFullWidth(true)
    testContainer:AddChild(filterHeader)

    -- Create a search box
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Search")
    searchBox:SetWidth(200)

    -- add button to export here
    local exportButton = AceGUI:Create("Button")
    exportButton:SetText("Export")
    exportButton:SetCallback("OnClick", function()
        DirectDepositEventFrame:export()
    end)
    testContainer:AddChild(exportButton)

    local selectedCheckbox = AceGUI:Create("CheckBox")
    selectedCheckbox:SetLabel("Selected")
    selectedCheckbox:SetValue(wishSelected)
    selectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        wishSelected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
        end)
    end)
    testContainer:AddChild(selectedCheckbox)

    local unselectedCheckbox = AceGUI:Create("CheckBox")
    unselectedCheckbox:SetLabel("Unselected")
    unselectedCheckbox:SetValue(wishUnselected)
    unselectedCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        wishUnselected = value
        checkboxContainer:ReleaseChildren()
        C_Timer.After(0.1, function()
            local filteredItems = filterItems(searchBox:GetText())
            populateItems(filteredItems)
        end)
    end)
    testContainer:AddChild(unselectedCheckbox)
    
    testContainer:AddChild(searchBox)

    -- Add a section header for the items
    local itemsHeader = AceGUI:Create("Label")
    itemsHeader:SetFontObject(GameFontNormalLarge)
    itemsHeader:SetColor(0.4, 0.6, 1) -- Change font color (light blue)
    itemsHeader:SetText("Items")
    itemsHeader:SetFullWidth(true)
    testContainer:AddChild(itemsHeader)

    searchBox:SetCallback("OnTextChanged", function(_, _, value)
        checkboxContainer:ReleaseChildren()
        
        local filteredItems = filterItems(value)
        populateItems(filteredItems)
    end)
    
    populateItems(tradeGoods)
    scrollContainer:AddChild(checkboxContainer)
    testContainer:AddChild(scrollContainer)
end
