local marketWindow = nil
local marketButton = nil
local marketTabBar = nil
local buyPanel = nil
local sellPanel = nil
local createOfferPanel = nil
local selectedOffer = nil
local selectedSellItem = nil
local selectedSellItemData = nil
local pendingOffer = nil
local OPCODE_MARKET = 52

local itemsXmlPath = '/data/items/items.xml'
local itemCategories = {}
local itemCategoriesByName = {}
local itemNamesById = {}
local allOffers = {}
local selectedCategory = 'All'
local searchText = ''
local sortOrder = 'asc'

local CATEGORIES = {
    ['head'] = 'Helmets',
    ['body'] = 'Armors',
    ['legs'] = 'Legs',
    ['feet'] = 'Boots',
    ['two-handed'] = 'Weapons',
    ['one-handed'] = 'Weapons',
    -- ['shield'] = 'Shields', -- Removed as requested
    ['ring'] = 'Rings',
    ['necklace'] = 'Amulets',
    ['ammo'] = 'Ammunition',
    ['backpack'] = 'Containers',
    -- Weapon Types
    ['sword'] = 'Weapons',
    ['club'] = 'Weapons',
    ['axe'] = 'Weapons',
    ['distance'] = 'Weapons',
    ['wand'] = 'Weapons',
    ['rod'] = 'Weapons',
    ['glover'] = 'Weapons'
}

function init()
    g_logger.info("Game Market: Module loading...")
    connect(g_game, { onGameStart = onGameStart,
                      onGameEnd = onGameEnd })
    
    -- Nasłuchuj na zmiany w kontenerach/ekwipunku
    connect(Container, {
        onUpdateItem = onContainerItemChange,
        onRemoveItem = onContainerItemChange
    })
    
    ProtocolGame.registerExtendedOpcode(OPCODE_MARKET, onMarketOpcode)

    marketWindow = g_ui.displayUI('game_market')
    marketWindow:hide()

    marketTabBar = marketWindow:getChildById('marketTabBar')
    local contentPanel = marketWindow:getChildById('contentPanel')
    marketTabBar:setContentWidget(contentPanel)
    
    marketTabBar.onTabChange = function(tabBar, tab)
        if tab and tab.tabPanel then
            tab.tabPanel:show()
        end
    end

    buyPanel = marketWindow:getChildById('buyPanel')
    sellPanel = marketWindow:getChildById('sellPanel')
    createOfferPanel = marketWindow:getChildById('createOfferPanel')

    marketTabBar:addTab('Buy Offers', buyPanel)
    marketTabBar:addTab('My Offers', sellPanel)
    marketTabBar:addTab('Create Offer', createOfferPanel)

    -- Setup drop handler
    local slotPanel = createOfferPanel:recursiveGetChildById('sellSlotPanel')
    if slotPanel then
        slotPanel.onDrop = onSellItemDrop
    else
        g_logger.error("Game Market: Could not find sellSlotPanel")
    end

    loadItemsXml()
    initCategoryList()
    
    -- Init Sort Combo
    local sortCombo = buyPanel:getChildById('sortComboBox')
    sortCombo:addOption('Price: Low to High', {sort = 'asc'})
    sortCombo:addOption('Price: High to Low', {sort = 'desc'})
    sortCombo.onOptionChange = onSortChange

    if g_game.isOnline() then
        onGameStart()
    end
    
    -- Debug feedback
    if table.size(itemCategories) == 0 then
        g_logger.error("Game Market: No categories loaded! Check log for errors.")
    else
        g_logger.info("Game Market: Ready with " .. table.size(itemCategories) .. " categorized items.")
    end
    
    g_logger.info("Game Market: Module loaded successfully.")
end

function loadItemsXml()
    -- Try multiple paths to ensure we find the file
    local paths = {
        '/data/items/items.xml',
        'data/items/items.xml',
        'items.xml',
        '../forgottenserver/data/items/items.xml'
    }
    
    local content = nil
    local usedPath = nil
    
    for _, path in ipairs(paths) do
        if g_resources.fileExists(path) then
            content = g_resources.readFileContents(path)
            if content then
                usedPath = path
                break
            end
        end
    end

    if not content then
        g_logger.error('Game Market: Could not find items.xml in any expected path.')
        g_game.talk('Market Error: items.xml not found!')
        return
    end

    g_logger.info('Game Market: Parsing ' .. usedPath .. ' (Size: ' .. #content .. ')')
    -- g_game.talk('Market: Loaded items.xml from ' .. usedPath) -- Uncomment for debug

    local currentId = nil
    local currentMaxId = nil
    local currentName = nil
    local count = 0
    
    for line in content:gmatch("[^\r\n]+") do
        -- Check for item start
        if line:find('<item') then
            local id = line:match('id=["\'](%d+)["\']')
            local fromId = line:match('fromid=["\'](%d+)["\']')
            local toId = line:match('toid=["\'](%d+)["\']')
            local name = line:match('name=["\']([^"\']+)["\']')
            
            if name then
                currentName = name:lower()
                -- Store display name (Title Case)
                local displayName = name:gsub("(%a)([%w_']*)", function(first, rest) return first:upper()..rest:lower() end)
                
                if id then
                    itemNamesById[tonumber(id)] = displayName
                elseif fromId and toId then
                    for i = tonumber(fromId), tonumber(toId) do
                        itemNamesById[i] = displayName
                    end
                end
            else
                currentName = nil
            end
            
            if id then
                currentId = tonumber(id)
                currentMaxId = nil
            elseif fromId and toId then
                currentId = tonumber(fromId)
                currentMaxId = tonumber(toId)
            else
                currentId = nil
                currentMaxId = nil
            end
            
            -- Check if it's a self-closing item tag (ends with />)
            -- But be careful not to match attributes on the same line if any (unlikely in this format)
            if line:find('/>') and not line:find('<attribute') then
                 -- It's a one-liner item, we might process attributes on this line below, 
                 -- but we need to ensure we don't carry over state to next lines.
                 -- However, the logic below checks 'if currentId', so we are good for this line.
                 -- We just need to make sure we reset at the end of this iteration.
            end
        end

        if currentId then
            -- Check for slotType or weaponType attribute
            local category = nil
            
            if line:find('key=["\']slotType["\']') or line:find('key=["\']weaponType["\']') then
                local value = line:match('value=["\']([^"\']+)["\']')
                if value then
                    value = value:lower():gsub("^%s*(.-)%s*$", "%1") -- trim and lower
                    category = CATEGORIES[value]
                end
            end
            
            if category then
                -- Map by ID
                if currentMaxId then
                    for i = currentId, currentMaxId do
                        itemCategories[i] = category
                    end
                    count = count + (currentMaxId - currentId + 1)
                else
                    itemCategories[currentId] = category
                    count = count + 1
                end
                
                -- Map by Name
                if currentName then
                    itemCategoriesByName[currentName] = category
                end
            end
            
            -- Check for item end
            -- Only reset if it is </item> OR if it was a self-closing <item ... />
            -- We must NOT reset on <attribute ... />
            if line:find('</item>') then
                currentId = nil
                currentMaxId = nil
                currentName = nil
            elseif line:find('<item') and line:find('/>') then
                -- Self closing item tag
                currentId = nil
                currentMaxId = nil
                currentName = nil
            end
        end
    end
    g_logger.info('Game Market: Successfully categorized ' .. count .. ' items.')
end

function initCategoryList()
    local list = buyPanel:getChildById('categoryList')
    local categories = {'All', 'Helmets', 'Armors', 'Legs', 'Boots', 'Weapons', 'Rings', 'Amulets', 'Ammunition', 'Containers', 'Others'}
    
    for _, cat in ipairs(categories) do
        local label = g_ui.createWidget('MarketOfferLabel', list)
        label:setText(cat)
        label:setId('cat_' .. cat)
        label.category = cat
        label:setHeight(20)
        label:setMarginLeft(5)
        
        label.onClick = function(widget)
            selectCategory(widget.category)
            for _, child in pairs(list:getChildren()) do
                child:setBackgroundColor('#00000000')
            end
            widget:setBackgroundColor('#ffffff22')
        end
    end
    
    -- Select 'All' by default
    local allLabel = list:getChildById('cat_All')
    if allLabel then
        allLabel:setBackgroundColor('#ffffff22')
    end
end

function selectCategory(category)
    selectedCategory = category
    filterOffers()
end

function onSortChange(widget, option, data)
    sortOrder = data.sort
    filterOffers()
end

function onSearchTextChange(text)
    searchText = text:lower()
    filterOffers()
end

function clearOfferPreview()
    local details = buyPanel:getChildById('detailsPanel')
    if details then
        local preview = details:getChildById('itemPreview')
        if preview then preview:clearItem() end
        
        local nameLabel = details:getChildById('itemName')
        if nameLabel then nameLabel:setText('') end
        
        local priceLabel = details:getChildById('itemPrice')
        if priceLabel then priceLabel:setText('') end
        
        local sellerLabel = details:getChildById('itemSeller')
        if sellerLabel then sellerLabel:setText('') end
        
        local statsLabel = details:getChildById('itemStats')
        if statsLabel then statsLabel:setText('') end
        
        local buyButton = details:getChildById('buyButton')
        if buyButton then buyButton:setEnabled(false) end
    end
    selectedOffer = nil
end

function filterOffers()
    local list = buyPanel:getChildById('offerList')
    list:destroyChildren()
    
    -- Wyczyść podgląd przy każdym filtrowaniu
    clearOfferPreview()
    
    local filteredOffers = {}
    
    for i, offer in ipairs(allOffers) do
        local name = offer.itemName
        if not name or name == "" then
            name = getItemName(offer.itemId)
        end
        
        local matchCategory = false
        if selectedCategory == 'All' then
            matchCategory = true
        else
            -- Ensure itemId is a number for lookup
            local clientId = tonumber(offer.itemId)
            local serverId = clientId
            
            -- Try to get Server ID from Client ID if possible
            local thingType = g_things.getThingType(clientId, ThingCategoryItem)
            if thingType and thingType.getServerId then
                local sid = thingType:getServerId()
                if sid and sid > 0 then
                    serverId = sid
                end
            end

            local cat = itemCategories[serverId] or itemCategories[clientId]
            
            -- Fallback to name lookup
            if not cat and name and name ~= "" then
                cat = itemCategoriesByName[name:lower()]
            end
            
            -- Fallback to ThingType (OTB) attributes
            if (not cat or cat == 'Others') and thingType then
                if thingType.getClothSlot then
                    local slot = thingType:getClothSlot()
                    if slot == 1 then cat = 'Helmets'
                    elseif slot == 4 then cat = 'Armors'
                    elseif slot == 7 then cat = 'Legs'
                    elseif slot == 8 then cat = 'Boots'
                    elseif slot == 2 then cat = 'Amulets'
                    elseif slot == 9 then cat = 'Rings'
                    elseif slot == 10 then cat = 'Ammunition'
                    end
                end
            end
            
            cat = cat or 'Others'
            
            if cat == selectedCategory then
                matchCategory = true
            end
        end
        
        local matchSearch = true
        if searchText ~= '' then
            if not name:lower():find(searchText, 1, true) then
                matchSearch = false
            end
        end
        
        if matchCategory and matchSearch then
            -- Store name in offer for display later
            offer._displayName = name
            table.insert(filteredOffers, offer)
        end
    end
    
    -- Sort filtered offers
    table.sort(filteredOffers, function(a, b)
        local priceA = tonumber(a.price) or 0
        local priceB = tonumber(b.price) or 0
        if sortOrder == 'asc' then
            return priceA < priceB
        else
            return priceA > priceB
        end
    end)
    
    -- Display sorted offers
    for i, offer in ipairs(filteredOffers) do
        local label = g_ui.createWidget('MarketOfferLabel', list)
        
        -- Oblicz pozostały czas
        local expiresText = ""
        if offer.expiresAt and offer.expiresAt > 0 then
            local remainingTime = offer.expiresAt - os.time()
            if remainingTime > 0 then
                local hours = math.floor(remainingTime / 3600)
                local minutes = math.floor((remainingTime % 3600) / 60)
                if hours > 0 then
                    expiresText = string.format(" [%dh]", hours)
                else
                    expiresText = string.format(" [%dm]", minutes)
                end
            else
                expiresText = " [EXP]"
            end
        end
        
        label:setText(offer.amount .. 'x ' .. offer._displayName .. ' - ' .. offer.price .. ' gp' .. expiresText)
        label:setId('offer' .. offer.id)
        label.offer = offer
        label:setHeight(20)
        label:setMarginLeft(5)
        
        label.onClick = function(widget)
            selectOffer(widget.offer)
            for _, child in pairs(list:getChildren()) do
                child:setBackgroundColor('#00000000')
            end
            widget:setBackgroundColor('#ffffff22')
        end
    end
end

function terminate()
    disconnect(g_game, { onGameStart = onGameStart,
                         onGameEnd = onGameEnd })
    
    -- Odłącz eventy kontenerów
    disconnect(Container, {
        onUpdateItem = onContainerItemChange,
        onRemoveItem = onContainerItemChange
    })
    
    ProtocolGame.unregisterExtendedOpcode(OPCODE_MARKET)

    if marketWindow then
        marketWindow:destroy()
    end

    if marketButton then
        marketButton:destroy()
        marketButton = nil
    end
end

function onGameStart()
    -- Request offers when game starts
    refreshOffers()

    if not marketButton then
        -- Try to find game_mainpanel
        if modules.game_mainpanel then
            marketButton = modules.game_mainpanel.addToggleButton('marketButton', 'Market', '/images/options/market_40x20', toggle, false, 9)
            
            -- Setup icon clips for 40x20 sprite (20x20 normal, 20x20 active/pressed)
            marketButton:setImageClip({x=0, y=0, width=20, height=20})
            
            local originalSetOn = marketButton.setOn
            marketButton.setOn = function(self, state)
                if originalSetOn then originalSetOn(self, state) end
                if state then
                    self:setImageClip({x=20, y=0, width=20, height=20})
                else
                    self:setImageClip({x=0, y=0, width=20, height=20})
                end
            end
            
            marketButton:setOn(false)
        else
            -- Fallback if mainpanel is missing (should not happen with dependency)
            print("ERROR: game_mainpanel not found for game_market")
        end
    end
end

function onGameEnd()
    if marketWindow:isVisible() then
        marketWindow:hide()
    end
end

-- Funkcja wywoływana gdy item w kontenerze zostanie zmieniony/usunięty
function onContainerItemChange(container, slot, item, oldItem)
    -- Sprawdź czy mamy wybrany item do sprzedaży
    if not selectedSellItemData then
        return
    end
    
    -- Sprawdź czy zmiana dotyczy naszego itemu
    local savedPos = selectedSellItemData.position
    if not savedPos then
        return
    end
    
    -- Sprawdź czy pozycja pasuje (slot w kontenerze)
    -- Pozycja itemu w kontenerze: x=65535, y=containerId+64, z=slot
    if savedPos.x == 65535 then
        -- To jest pozycja w kontenerze
        local containerId = savedPos.y - 64
        if containerId == container:getId() and savedPos.z == slot then
            -- To nasz item! Został zmieniony lub usunięty
            clearCreateOfferSlot()
        end
    end
end

function clearCreateOfferSlot()
    selectedSellItem = nil
    selectedSellItemData = nil
    pendingOffer = nil
    if createOfferPanel then
        local slotPanel = createOfferPanel:recursiveGetChildById('sellSlotPanel')
        if slotPanel then
            local display = slotPanel:getChildById('sellItemDisplay')
            if display then
                display:clearItem()
            end
        end
        local priceInput = createOfferPanel:getChildById('priceInput')
        if priceInput then
            priceInput:setText('')
        end
    end
end

function toggle()
    if marketWindow:isVisible() then
        marketWindow:hide()
        -- Wyczyść slot przy zamykaniu
        clearCreateOfferSlot()
    else
        -- Wyczyść slot przy otwieraniu
        clearCreateOfferSlot()
        marketWindow:show()
        marketWindow:raise()
        marketWindow:focus()
        refreshOffers()
    end
end

function refreshOffers()
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedOpcode(OPCODE_MARKET, json.encode({action = "fetch_offers"}))
        protocol:sendExtendedOpcode(OPCODE_MARKET, json.encode({action = "fetch_my_offers"}))
    end
end

function onMarketOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_MARKET then return end
    
    local status, data = pcall(json.decode, buffer)
    if not status or not data then return end
    
    if data.action == "open_market" then
        -- Otwórz okno marketu
        if marketWindow then
            marketWindow:show()
            marketWindow:raise()
            marketWindow:focus()
            if marketButton then marketButton:setOn(true) end
            refreshOffers()
        end
    elseif data.action == "offers" then
        updateOfferList(data.data)
    elseif data.action == "my_offers" then
        updateMyOffersList(data.data)
    elseif data.action == "msg" then
        g_game.talk(data.text) -- Show message in chat
    elseif data.action == "identify_result" then
        if pendingOffer and pendingOffer.item:getId() == data.itemId then
            showConfirmDialog(pendingOffer.item, pendingOffer.price, data.name)
        end
    end
end

function updateOfferList(offers)
    allOffers = offers
    -- Wyczyść podgląd ponieważ poprzednio wybrana oferta może już nie istnieć
    clearOfferPreview()
    filterOffers()
end

function updateMyOffersList(offers)
    local list = sellPanel:getChildById('myOffersList')
    list:destroyChildren()
    
    for i, offer in ipairs(offers) do
        local label = g_ui.createWidget('MarketOfferLabel', list)
        local name = offer.itemName
        if not name or name == "" then
            name = getItemName(offer.itemId)
        end
        
        -- Oblicz pozostały czas
        local expiresText = ""
        if offer.expiresAt and offer.expiresAt > 0 then
            local remainingTime = offer.expiresAt - os.time()
            if remainingTime > 0 then
                local hours = math.floor(remainingTime / 3600)
                local minutes = math.floor((remainingTime % 3600) / 60)
                if hours > 0 then
                    expiresText = string.format(" [%dh %dm left]", hours, minutes)
                else
                    expiresText = string.format(" [%dm left]", minutes)
                end
            else
                expiresText = " [EXPIRED]"
            end
        end
        
        label:setText(offer.amount .. 'x ' .. name .. ' - ' .. offer.price .. ' gp' .. expiresText)
        label:setId('myOffer' .. offer.id)
        label.offer = offer
        label:setHeight(20)
        label:setMarginLeft(5)
        
        label.onClick = function(widget)
            selectedOffer = widget.offer
            for _, child in pairs(list:getChildren()) do
                child:setBackgroundColor('#00000000')
            end
            widget:setBackgroundColor('#ffffff22')
        end
    end
end

function selectOffer(offer)
    selectedOffer = offer
    local details = buyPanel:getChildById('detailsPanel')
    
    local item = Item.create(offer.itemId)
    item:setCount(offer.amount)
    
    -- Parse attributes for stats
    local statsText = ""
    if offer.attributes and offer.attributes ~= "" then
        local status, attr = pcall(json.decode, offer.attributes)
        if status and attr then
            if attr.description then
                -- Set description on the virtual item so tooltip picks it up
                if item.setTooltip then
                    item:setTooltip(attr.description)
                end
                
                -- Try to parse stats from description like in tooltip
                local desc = attr.description
                local healthLeech = desc:match('%[Health Leech: %+([%d%.]+)%%%]')
                if healthLeech then statsText = statsText .. 'Health Leech: +' .. healthLeech .. '%\n' end
                
                local manaLeech = desc:match('%[Mana Leech: %+([%d%.]+)%%%]')
                if manaLeech then statsText = statsText .. 'Mana Leech: +' .. manaLeech .. '%\n' end
                
                local defEnergy = desc:match('%[Defense Energy: %+([%d%.]+)%%%]')
                if defEnergy then statsText = statsText .. 'Defense Energy: +' .. defEnergy .. '%\n' end
                
                local defMelee = desc:match('%[Defense Melee: %+([%d%.]+)%%%]')
                if defMelee then statsText = statsText .. 'Defense Melee: +' .. defMelee .. '%\n' end
                
                local chakraDmg = desc:match('%[Chakra Damage: %+([%d%.]+)%%%]')
                if chakraDmg then statsText = statsText .. 'Chakra Damage: +' .. chakraDmg .. '%\n' end
                
                local meleeDmg = desc:match('%[Melee Damage: %+([%d%.]+)%%%]')
                if meleeDmg then statsText = statsText .. 'Melee Damage: +' .. meleeDmg .. '%\n' end
            end
            
            -- Also check direct stats if saved
            if attr.attack then statsText = statsText .. 'Attack: ' .. attr.attack .. '\n' end
            if attr.defense then statsText = statsText .. 'Defense: ' .. attr.defense .. '\n' end
        end
    end
    
    -- Use setItem instead of setItemId to pass the virtual item with description
    details:getChildById('itemPreview'):setItem(item)
    
    local name = offer.itemName
    if not name or name == "" then
        name = getItemName(offer.itemId)
    end
    details:getChildById('itemName'):setText(name)
    
    details:getChildById('itemPrice'):setText(offer.price .. ' gp')
    details:getChildById('itemSeller'):setText('Seller: ' .. offer.seller)
    details:getChildById('buyButton'):setEnabled(true)
    
    details:getChildById('itemStats'):setText(statsText)
end

function buySelectedOffer()
    if not selectedOffer then return end
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedOpcode(OPCODE_MARKET, json.encode({action = "buy", offerId = selectedOffer.id}))
        -- Refresh list after a short delay to allow server to process
        scheduleEvent(refreshOffers, 500)
    end
end

function cancelSelectedOffer()
    if not selectedOffer then return end
    local protocol = g_game.getProtocolGame()
    if protocol then
        protocol:sendExtendedOpcode(OPCODE_MARKET, json.encode({action = "cancel", offerId = selectedOffer.id}))
        -- Refresh list after a short delay to allow server to process
        scheduleEvent(refreshOffers, 500)
    end
end

function getItemName(id)
    -- Check our XML cache first (Direct ID)
    if itemNamesById[id] then
        return itemNamesById[id]
    end

    local thingType = g_things.getThingType(id, ThingCategoryItem or 0)
    
    -- Try Server ID lookup if we have the ThingType
    if thingType and thingType.getServerId then
        local sid = thingType:getServerId()
        if sid and sid > 0 and itemNamesById[sid] then
            return itemNamesById[sid]
        end
        
        -- Debug: If we have a valid SID but no name, maybe the XML isn't loaded?
        -- Or if SID is 0, the OTB is missing the mapping.
    end

    -- Fallback to Client ThingType name
    if thingType then
        local name = thingType:getName()
        if name and name ~= "" and name ~= "Item " .. id then
            return name
        end
    end
    
    -- If we still don't have a name, return generic with debug info
    local debugSid = (thingType and thingType.getServerId) and thingType:getServerId() or 0
    return "Item " .. id .. " (SID: " .. debugSid .. ")"
end

function createOffer()
    if not selectedSellItem or not selectedSellItemData then
        g_game.talk("Please drag an item to the slot first.")
        return
    end
    
    local price = tonumber(createOfferPanel:getChildById('priceInput'):getText())
    if not price or price <= 0 then
        g_game.talk("Please enter a valid price.")
        return
    end
    
    -- Capture item locally to avoid nil upvalue issues in callback
    local itemToSell = selectedSellItem
    
    -- Weryfikacja czy item nadal istnieje i jest taki sam
    local currentItem = itemToSell
    if not currentItem or currentItem:getId() ~= selectedSellItemData.id then
        g_game.talk("The item has been moved or removed. Please drag it again.")
        clearCreateOfferSlot()
        return
    end
    
    -- Sprawdź czy pozycja i ilość się zgadzają
    local currentPos = currentItem:getPosition()
    local savedPos = selectedSellItemData.position
    if currentPos.x ~= savedPos.x or currentPos.y ~= savedPos.y or currentPos.z ~= savedPos.z then
        g_game.talk("The item has been moved. Please drag it again.")
        clearCreateOfferSlot()
        return
    end
    
    -- Try to get name locally first
    local name = getItemName(itemToSell:getId())
    
    -- If name is generic (contains "Item" and digits), ask server for identification
    if name:find("Item %d+") then
        local protocol = g_game.getProtocolGame()
        if protocol then
            protocol:sendExtendedOpcode(OPCODE_MARKET, json.encode({
                action = "identify",
                itemId = itemToSell:getId()
            }))
            -- We will show the dialog when the server responds
            -- Store pending offer details
            pendingOffer = {
                item = itemToSell,
                price = price
            }
            return
        end
    end
    
    showConfirmDialog(itemToSell, price, name)
end

function showConfirmDialog(itemToSell, price, name)
    local msg = "Do you want to sell " .. itemToSell:getCount() .. "x " .. name .. " for " .. price .. " gp?"
    
    local messageBox
    local yesCallback = function()
        if messageBox then
            messageBox:destroy()
            messageBox = nil
        end

        local protocol = g_game.getProtocolGame()
        if protocol then
            protocol:sendExtendedOpcode(OPCODE_MARKET, json.encode({
                action = "sell",
                itemId = itemToSell:getId(),
                count = itemToSell:getCount(),
                price = price,
                -- Send position to identify exact item instance
                position = itemToSell:getPosition()
            }))
            -- Refresh list after a short delay to allow server to process
            scheduleEvent(refreshOffers, 500)
        end
        -- Clear slot
        local slotPanel = createOfferPanel:recursiveGetChildById('sellSlotPanel')
        if slotPanel then
            local display = slotPanel:getChildById('sellItemDisplay')
            if display then
                display:clearItem()
            end
        end
        createOfferPanel:getChildById('priceInput'):setText('')
        
        -- Only clear global if it matches what we just sold
        if selectedSellItem == itemToSell then
            selectedSellItem = nil
            selectedSellItemData = nil
        end
        pendingOffer = nil
    end
    
    local noCallback = function()
        if messageBox then
            messageBox:destroy()
            messageBox = nil
        end
        pendingOffer = nil
    end
    
    messageBox = displayGeneralBox("Confirm Sell", msg, {{text='Yes', callback=yesCallback}, {text='No', callback=noCallback}}, yesCallback, noCallback)
end

function onSellItemDrop(widget, draggedWidget, mousePos)
    if not draggedWidget or not draggedWidget.getItem then 
        return false
    end
    
    local item = draggedWidget:getItem()
    if not item then 
        return false
    end
    
    -- Zapisz pełne informacje o itemie do weryfikacji
    selectedSellItem = item
    selectedSellItemData = {
        id = item:getId(),
        count = item:getCount(),
        position = item:getPosition()
    }
    
    local display = widget:getChildById('sellItemDisplay')
    if display then
        display:setItem(item)
    end
    return true
end
