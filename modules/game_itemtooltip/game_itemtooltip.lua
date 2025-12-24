local items = {}
local itemsXmlPath = '/data/items/items.xml'
local itemsOtbPath = '/game_itemtooltip/items.otb'
local itemTooltip = nil
local clientToServer = {}
local OtbLoader = require('otb_loader')
local OPCODE_TOOLTIP = 51

function init()
    -- Create the tooltip widget
    itemTooltip = g_ui.createWidget('UIWidget', rootWidget)
    itemTooltip:setId('itemTooltip')
    itemTooltip:setBackgroundColor('#000000cc')
    itemTooltip:setBorderColor('#ffffff')
    itemTooltip:setBorderWidth(1)
    itemTooltip:setVisible(false)
    itemTooltip:setPhantom(true)
    
    local itemName = g_ui.createWidget('UILabel', itemTooltip)
    itemName:setId('itemName')
    itemName:addAnchor(AnchorTop, 'parent', AnchorTop)
    itemName:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    itemName:setMarginTop(5)
    itemName:setMarginLeft(5)
    itemName:setMarginRight(5)
    itemName:setTextAlign(AlignCenter)

    local itemImage = g_ui.createWidget('UIItem', itemTooltip)
    itemImage:setId('itemImage')
    itemImage:addAnchor(AnchorTop, 'itemName', AnchorBottom)
    itemImage:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    itemImage:setMarginTop(5)
    itemImage:setSize({width=32, height=32})
    itemImage:setVirtual(true)
    
    local itemStats = g_ui.createWidget('UILabel', itemTooltip)
    itemStats:setId('itemStats')
    itemStats:addAnchor(AnchorTop, 'itemImage', AnchorBottom)
    itemStats:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    itemStats:setMarginTop(5)
    itemStats:setMarginLeft(5)
    itemStats:setMarginRight(5)
    itemStats:setTextAlign(AlignCenter)

    loadItemsXml()
    loadItemsOtb()
    
    connect(UIWidget, { onHoverChange = onItemHoverChange })
    ProtocolGame.registerExtendedOpcode(OPCODE_TOOLTIP, onTooltipOpcode)
    
    -- Force check current hovered widget
    local mouseWidget = rootWidget:recursiveGetChildByPos(g_window.getMousePosition(), false)
    if mouseWidget then
        onItemHoverChange(mouseWidget, true)
    end
end

function terminate()
    ProtocolGame.unregisterExtendedOpcode(OPCODE_TOOLTIP)
    disconnect(UIWidget, { onHoverChange = onItemHoverChange })
    if itemTooltip then
        itemTooltip:destroy()
        itemTooltip = nil
    end
    items = {}
    clientToServer = {}
end

function onTooltipOpcode(protocol, opcode, buffer)
    if opcode ~= OPCODE_TOOLTIP then return end
    if not itemTooltip:isVisible() then return end
    
    -- g_logger.info("Opcode Response: " .. buffer)

    -- Parse stats from buffer
    local desc = buffer
    local statsWidget = itemTooltip:getChildById('itemStats')
    local currentText = statsWidget:getText()
    
    local statsText = ''
    
    local healthLeech = desc:match('%[Health Leech: %+([%d%.]+)%%%]')
    if healthLeech then
        statsText = statsText .. '{Health Leech: +' .. healthLeech .. '%, #ff00ff}\n'
    end
    
    local manaLeech = desc:match('%[Mana Leech: %+([%d%.]+)%%%]')
    if manaLeech then
        statsText = statsText .. '{Mana Leech: +' .. manaLeech .. '%, #00ffff}\n'
    end
    
    local defEnergy = desc:match('%[Defense Energy: %+([%d%.]+)%%%]')
    if defEnergy then
        statsText = statsText .. '{Defense Energy: +' .. defEnergy .. '%, #ffaaaa}\n'
    end
    
    local defMelee = desc:match('%[Defense Melee: %+([%d%.]+)%%%]')
    if defMelee then
        statsText = statsText .. '{Defense Melee: +' .. defMelee .. '%, #aaaaff}\n'
    end
    
    local chakraDmg = desc:match('%[Chakra Damage: %+([%d%.]+)%%%]')
    if chakraDmg then
        statsText = statsText .. '{Chakra Damage: +' .. chakraDmg .. '%, #ffa500}\n'
    end
    
    local meleeDmg = desc:match('%[Melee Damage: %+([%d%.]+)%%%]')
    if meleeDmg then
        statsText = statsText .. '{Melee Damage: +' .. meleeDmg .. '%, #a52a2a}\n'
    end
    
    if statsText ~= '' then
        statsWidget:setColoredText(currentText .. statsText)
        statsWidget:resizeToText()
        
        local nameWidget = itemTooltip:getChildById('itemName')
        local width = math.max(nameWidget:getWidth(), statsWidget:getWidth(), 32) + 20
        local height = 5 + nameWidget:getHeight() + 5 + 32 + 5 + statsWidget:getHeight() + 5
        itemTooltip:setSize({width=width, height=height})
    end
end

function loadItemsOtb()
    local path = g_resources.resolvePath(itemsOtbPath)
    if not g_resources.fileExists(path) then
        -- Try alternative path
        path = g_resources.resolvePath('items.otb')
    end
    
    if g_resources.fileExists(path) then
        g_logger.info('Loading OTB from: ' .. path)
        local mapping = OtbLoader.load(path)
        if mapping then
            clientToServer = mapping
            g_logger.info('Loaded OTB mapping for ' .. table.size(clientToServer) .. ' items')
        else
            g_logger.error('Failed to parse OTB file')
        end
    else
        g_logger.warning('items.otb not found. Tooltips might show wrong data.')
    end
end

function loadItemsXml()
    if not g_resources.fileExists(itemsXmlPath) then
        g_logger.error('Items XML not found: ' .. itemsXmlPath)
        return
    end

    local content = g_resources.readFileContents(itemsXmlPath)
    if not content then
        g_logger.error('Failed to read items.xml')
        return
    end

    local currentItem = nil
    
    for line in content:gmatch("[^\r\n]+") do
        if line:match('<item%s+') then
            local id = line:match('id="(%d+)"')
            local name = line:match('name="([^"]+)"')
            local fromId = line:match('fromid="(%d+)"')
            local toId = line:match('toid="(%d+)"')
            
            if id and name then
                currentItem = {id = tonumber(id), name = name, stats = {}}
                items[currentItem.id] = currentItem
            elseif fromId and toId and name then
                local start = tonumber(fromId)
                local stop = tonumber(toId)
                for i = start, stop do
                    items[i] = {id = i, name = name, stats = {}}
                end
                currentItem = nil 
            end
            
            if line:match('/>%s*$') then
                currentItem = nil
            end
        elseif currentItem then
            local key, value = line:match('<attribute%s+key="([^"]+)"%s+value="([^"]+)"')
            if key and value then
                if key == 'attack' or key == 'defense' or key == 'weight' or key == 'armor' then
                    currentItem.stats[key] = value
                end
            end
            
            if line:match('</item>') then
                currentItem = nil
            end
        end
    end
    g_logger.info('Loaded ' .. table.size(items) .. ' items from items.xml')
end

function onItemHoverChange(widget, hovered)
    if widget:getClassName() ~= 'UIItem' then return end

    if not hovered then
        if itemTooltip then
            itemTooltip:hide()
            disconnect(rootWidget, { onMouseMove = moveTooltip })
        end
        return
    end
    
    local item = widget:getItem()
    if not item then return end
    
    local clientId = item:getId()
    local serverId = clientId
    
    -- Try to get Server ID from mapping
    if clientToServer[clientId] then
        serverId = clientToServer[clientId]
    else
        -- Fallback: check if ThingType has getServerId (unlikely)
        local thingType = g_things.getThingType(clientId, ThingCategoryItem)
        if thingType and thingType.getServerId then
            serverId = thingType:getServerId()
        end
    end
    
    -- g_logger.info('Hovered Client ID: ' .. clientId .. ', Server ID: ' .. serverId)
    
    local itemData = items[serverId]
    
    if itemData then
        updateTooltip(item, itemData)
        itemTooltip:show()
        itemTooltip:raise()
        moveTooltip()
        connect(rootWidget, { onMouseMove = moveTooltip })
        
        -- Send Opcode Request
        local protocol = g_game.getProtocolGame()
        if protocol then
            local pos = item:getPosition()
            -- Check if item is in inventory or equipment
            if pos and pos.x == 65535 then
                if pos.y < 64 then -- Equipment
                    protocol:sendExtendedOpcode(OPCODE_TOOLTIP, "eq:" .. pos.y)
                else -- Container
                    local containerId = pos.y - 64
                    protocol:sendExtendedOpcode(OPCODE_TOOLTIP, "inv:" .. containerId .. ":" .. pos.z)
                end
            end
        end
    else
        -- g_logger.warning('No data for Server ID: ' .. serverId)
    end
end

function updateTooltip(item, itemData)
    local imageWidget = itemTooltip:getChildById('itemImage')
    local nameWidget = itemTooltip:getChildById('itemName')
    local statsWidget = itemTooltip:getChildById('itemStats')
    
    imageWidget:setItemId(item:getId())
    
    -- Get dynamic name from item if available, otherwise use static name
    local name = ''
    if item.getName then
        name = item:getName()
    end
    if name == '' and itemData then
        name = itemData.name
    end
    
    -- Clean name for display (remove stats from name label)
    local displayName = name:gsub('%s*%[.-%]', '')
    nameWidget:setText(displayName)
    nameWidget:resizeToText()
    
    local statsText = ''
    if itemData.stats.attack then
        statsText = statsText .. '{Attack: ' .. itemData.stats.attack .. ', #ff0000}\n'
    end
    if itemData.stats.defense then
        statsText = statsText .. '{Defense: ' .. itemData.stats.defense .. ', #00ff00}\n'
    end
    if itemData.stats.armor then
        statsText = statsText .. '{Armor: ' .. itemData.stats.armor .. ', #ffff00}\n'
    end
    if itemData.stats.weight then
        statsText = statsText .. '{Weight: ' .. (tonumber(itemData.stats.weight)/100) .. ', #0000ff}\n'
    end
    
    -- Parse Custom Stats from Name (since Description is not synced)
    local desc = name
    
    -- Append manual tooltip if available (e.g. from Market)
    if item.getTooltip then
        local t = item:getTooltip()
        if t and t ~= '' then
            desc = desc .. ' ' .. t
        end
    end
    
    if desc and desc ~= '' then
        local healthLeech = desc:match('%[Health Leech: %+([%d%.]+)%%%]')
        if healthLeech then
            statsText = statsText .. '{Health Leech: +' .. healthLeech .. '%, #ff00ff}\n'
        end
        
        local manaLeech = desc:match('%[Mana Leech: %+([%d%.]+)%%%]')
        if manaLeech then
            statsText = statsText .. '{Mana Leech: +' .. manaLeech .. '%, #00ffff}\n'
        end
        
        local defEnergy = desc:match('%[Defense Energy: %+([%d%.]+)%%%]')
        if defEnergy then
            statsText = statsText .. '{Defense Energy: +' .. defEnergy .. '%, #ffaaaa}\n'
        end
        
        local defMelee = desc:match('%[Defense Melee: %+([%d%.]+)%%%]')
        if defMelee then
            statsText = statsText .. '{Defense Melee: +' .. defMelee .. '%, #aaaaff}\n'
        end
        
        local chakraDmg = desc:match('%[Chakra Damage: %+([%d%.]+)%%%]')
        if chakraDmg then
            statsText = statsText .. '{Chakra Damage: +' .. chakraDmg .. '%, #ffa500}\n'
        end
        
        local meleeDmg = desc:match('%[Melee Damage: %+([%d%.]+)%%%]')
        if meleeDmg then
            statsText = statsText .. '{Melee Damage: +' .. meleeDmg .. '%, #a52a2a}\n'
        end
    end
    
    statsWidget:setColoredText(statsText)
    statsWidget:resizeToText()
    
    local width = math.max(nameWidget:getWidth(), statsWidget:getWidth(), 32) + 20
    local height = 5 + nameWidget:getHeight() + 5 + 32 + 5 + statsWidget:getHeight() + 5
    
    itemTooltip:setSize({width=width, height=height})
end

function moveTooltip()
    if not itemTooltip:isVisible() then return end
    
    local pos = g_window.getMousePosition()
    local windowSize = g_window.getSize()
    local tooltipSize = itemTooltip:getSize()
    
    pos.x = pos.x + 10
    pos.y = pos.y + 10
    
    if pos.x + tooltipSize.width > windowSize.width then
        pos.x = windowSize.width - tooltipSize.width - 5
    end
    
    if pos.y + tooltipSize.height > windowSize.height then
        pos.y = windowSize.height - tooltipSize.height - 5
    end
    
    itemTooltip:setPosition(pos)
end
