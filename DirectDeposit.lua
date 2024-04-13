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

function MyAddOn_Comms:Init()
    AceComm:Embed(self);
    self:RegisterComm(self.Prefix, "OnCommReceived");
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
                return true
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
                if value then
                    -- If the checkbox is checked (value is true), add the item to requestedItems
                    table.insert(requestedItems, {id = id, name = name, state = value})
                else
                    -- If the checkbox is unchecked (value is false), remove the item from requestedItems
                    for i, requestedItem in ipairs(requestedItems) do
                        if requestedItem.id == id then
                            table.remove(requestedItems, i)
                            break
                        end
                    end
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
