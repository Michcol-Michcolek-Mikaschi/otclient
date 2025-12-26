local OPCODE_CRAFTING = 55

local craftingWindow
local craftingButton
local craftingTabBar
local craftingPanel
local recipesPanel
local recipesList
local selectedRecipeId = nil -- For the RECIPES tab selection
local currentCraftRecipeId = nil -- For the CRAFTING tab auto-detection
local craftConfirmWindow = nil -- Confirmation dialog

-- Śledzenie przedmiotów w slotach craftingu (pozycja + id)
local slotTracking = {}

-- OTB Mapping: Server ID -> Client ID
local serverToClient = {}

-- Definicja przepisów (musi być zgodna z serwerem) - używamy Server ID
local recipes = {
    {
        id = 1,
        name = "Weight Band",
        ingredients = {57583, 57584, 57585, 57586, 57587},
        result = 57588
    }
}

-- Funkcja do konwersji Server ID na Client ID
function getClientId(serverId)
    if serverToClient[serverId] then
        return serverToClient[serverId]
    end
    return serverId -- fallback
end

-- OTB Parser functions
local function getU8(data, pos)
    return string.byte(data, pos), pos + 1
end

local function getU16(data, pos)
    local b1 = string.byte(data, pos)
    local b2 = string.byte(data, pos + 1)
    return b1 + b2 * 256, pos + 2
end

local function getU32(data, pos)
    local b1 = string.byte(data, pos)
    local b2 = string.byte(data, pos + 1)
    local b3 = string.byte(data, pos + 2)
    local b4 = string.byte(data, pos + 3)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216, pos + 4
end

-- Ładowanie OTB
function loadItemsOtb()
    local itemsOtbPath = '/game_itemtooltip/items.otb'
    local path = g_resources.resolvePath(itemsOtbPath)
    if not g_resources.fileExists(path) then
        path = g_resources.resolvePath('/data/items/items.otb')
    end
    
    if not g_resources.fileExists(path) then
        return
    end
    
    local fileContent = g_resources.readFileContents(path)
    local len = #fileContent
    local pos = 1

    -- Signature
    local signature
    signature, pos = getU32(fileContent, pos)

    -- Parse nodes
    local function parseNode()
        if pos > len then return nil end
        local startByte = string.byte(fileContent, pos)
        pos = pos + 1
        if startByte ~= 0xFE then return nil end

        local node = { dataBuffer = {}, children = {} }
        
        while pos <= len do
            local byte = string.byte(fileContent, pos)
            if byte == 0xFE then
                local child = parseNode()
                if not child then return nil end
                table.insert(node.children, child)
            elseif byte == 0xFF then
                pos = pos + 1
                node.data = table.concat(node.dataBuffer)
                return node
            elseif byte == 0xFD then
                pos = pos + 1
                if pos > len then break end
                local escapedByte = string.byte(fileContent, pos)
                pos = pos + 1
                table.insert(node.dataBuffer, string.char(escapedByte))
            else
                pos = pos + 1
                table.insert(node.dataBuffer, string.char(byte))
            end
        end
        return nil
    end

    local root = parseNode()
    if not root then
        return
    end

    local clientToServer = {}
    local count = 0

    for _, child in ipairs(root.children) do
        local cData = child.data
        local cPos = 1
        local cLen = #cData
        
        if cLen >= 5 then
            local category
            category, cPos = getU8(cData, cPos)
            local flags
            flags, cPos = getU32(cData, cPos)
            
            local serverId = 0
            local clientId = 0
            
            while cPos <= cLen do
                local attrByte
                attrByte, cPos = getU8(cData, cPos)
                
                if attrByte == 0 or attrByte == 0xFF then break end
                if cPos + 2 > cLen then break end
                
                local attrLen
                attrLen, cPos = getU16(cData, cPos)
                
                if cPos + attrLen - 1 > cLen then break end
                
                if attrByte == 16 then -- ServerId
                    serverId, _ = getU16(cData, cPos)
                elseif attrByte == 17 then -- ClientId
                    clientId, _ = getU16(cData, cPos)
                end
                
                cPos = cPos + attrLen
            end
            
            if serverId > 0 and clientId > 0 then
                if serverId > 30000 and serverId < 30100 then
                    serverId = serverId - 30000
                end
                clientToServer[clientId] = serverId
                serverToClient[serverId] = clientId
                count = count + 1
            end
        end
    end
end

function init()
    connect(g_game, { onGameStart = onGameStart,
                      onGameEnd = onGameEnd })
    
    -- Nasłuchuj na zmiany w kontenerach
    connect(Container, { 
        onOpen = onContainerOpen,
        onClose = onContainerClose,
        onUpdateItem = onContainerUpdateItem,
        onRemoveItem = onContainerRemoveItem
    })

    -- Załaduj mapowanie OTB
    loadItemsOtb()

    -- Inicjalizacja UI
    local status, err = pcall(function()
        craftingWindow = g_ui.displayUI('game_crafting')
        
        if not craftingWindow then
            error("g_ui.displayUI('game_crafting') returned nil! Check if game_crafting.otui exists and has no errors.")
        end

        craftingWindow:hide()
        
        craftingTabBar = craftingWindow:recursiveGetChildById('craftingTabBar')
        craftingPanel = craftingWindow:recursiveGetChildById('craftingPanel')
        recipesPanel = craftingWindow:recursiveGetChildById('recipesPanel')
        recipesList = craftingWindow:recursiveGetChildById('recipesList')

        -- Setup Tabs
        craftingTabBar:setContentWidget(craftingWindow:recursiveGetChildById('contentPanel'))
        
        craftingTabBar.onTabChange = function(tabBar, tab)
            if tab and tab.tabPanel then
                tab.tabPanel:show()
            end
        end

        craftingTabBar:addTab(tr('Crafting'), craftingPanel)
        craftingTabBar:addTab(tr('Recipes'), recipesPanel)
        
        -- Setup Sloty Craftingu
        for i = 1, 5 do
            local slot = craftingWindow:recursiveGetChildById('slot' .. i)
            if slot then
                slot.onDrop = onSlotDrop
                slot.slotIndex = i
                -- Prawy przycisk myszy czyści slot
                slot.onMouseRelease = function(widget, mousePos, mouseButton)
                    if mouseButton == MouseRightButton then
                        clearSlot(i)
                        return true
                    end
                end
            end
        end
        
        refreshRecipesList()
    end)

    if not status then
        g_logger.error("Game Crafting: UI Init Error: " .. tostring(err))
    end

    -- Dodawanie przycisku z opóźnieniem
    scheduleEvent(addCraftingButton, 500)

    if g_game.isOnline() then
        onGameStart()
    end
end

function addCraftingButton()
    if craftingButton then return end

    if modules.game_mainpanel then
        craftingButton = modules.game_mainpanel.addToggleButton('craftingButton', tr('Crafting'), '/images/options/crafting', toggle, false, 8)
        
        if craftingButton then
            craftingButton:setOn(false)
            if modules.game_mainpanel.initControlButtons then
                modules.game_mainpanel.initControlButtons()
            end
        end
    end
end

function terminate()
    disconnect(g_game, { onGameStart = onGameStart,
                         onGameEnd = onGameEnd })
    
    -- Odłącz nasłuchiwanie kontenerów
    disconnect(Container, { 
        onOpen = onContainerOpen,
        onClose = onContainerClose,
        onUpdateItem = onContainerUpdateItem,
        onRemoveItem = onContainerRemoveItem
    })

    if craftingWindow then
        craftingWindow:destroy()
    end
    
    if craftingButton then
        craftingButton:destroy()
        craftingButton = nil
    end
    
    slotTracking = {}
end

function onGameStart()
    scheduleEvent(addCraftingButton, 1000)
end

function onGameEnd()
    if craftingWindow then craftingWindow:hide() end
    -- Wyczyść wszystkie sloty przy wylogowaniu
    for i = 1, 5 do
        slotTracking[i] = nil
    end
end

function toggle()
    if not craftingWindow then return end

    if craftingWindow:isVisible() then
        craftingWindow:hide()
        if craftingButton then craftingButton:setOn(false) end
    else
        -- Przy otwarciu okna waliduj sloty
        validateAllSlots()
        craftingWindow:show()
        craftingWindow:raise()
        craftingWindow:focus()
        if craftingButton then craftingButton:setOn(true) end
    end
end

function refreshRecipesList()
    if not recipesList then return end
    recipesList:destroyChildren()
    for _, recipe in ipairs(recipes) do
        local label = g_ui.createWidget('TextListLabel', recipesList)
        label:setText(recipe.name)
        label:setId('recipe_' .. recipe.id)
        label:setHeight(20)
        label.recipeId = recipe.id
        
        -- Use onFocusChange instead of onClick (more reliable for TextList items)
        label.onFocusChange = function(widget, focused)
            if focused then
                selectRecipe(widget.recipeId)
            end
        end
    end
    
    -- Auto-select first recipe
    if #recipes > 0 then
        selectRecipe(recipes[1].id)
    end
end

function selectRecipe(id)
    selectedRecipeId = id
    local recipe = nil
    for _, r in ipairs(recipes) do
        if r.id == id then recipe = r break end
    end

    if not recipe then return end

    -- 1. Update Name
    local nameLabel = craftingWindow:recursiveGetChildById('recipeNameLabel')
    if nameLabel then 
        nameLabel:setText(recipe.name) 
    end
    
    -- 2. Update Ingredients Label
    local ingredientsLabel = craftingWindow:recursiveGetChildById('ingredientsLabel')
    if ingredientsLabel then
        ingredientsLabel:setText("Ingredients (" .. #recipe.ingredients .. "):")
    end

    -- 3. Update Ingredients Panel
    local ingredientsPanel = craftingWindow:recursiveGetChildById('recipeIngredientsPanel')
    if ingredientsPanel then
        ingredientsPanel:destroyChildren()
        
        for i, serverId in ipairs(recipe.ingredients) do
            local clientId = getClientId(serverId)
            local itemWidget = g_ui.createWidget('IngredientItem', ingredientsPanel)
            if itemWidget then
                itemWidget:setItemId(clientId)
            end
        end
    end
    
    -- 4. Update Result
    local resultItem = craftingWindow:recursiveGetChildById('recipeResultItem')
    if resultItem then 
        resultItem:setVirtual(true)
        local resultClientId = getClientId(recipe.result)
        resultItem:setItemId(resultClientId)
    end
end

function onSlotDrop(widget, draggedWidget, mousePos)
    if draggedWidget:getClassName() == 'UIItem' and not draggedWidget:isVirtual() then
        local item = draggedWidget:getItem()
        if item then
            local slotIndex = widget.slotIndex
            local position = item:getPosition()
            
            -- Zapisz informacje o przedmiocie (pozycja + id)
            slotTracking[slotIndex] = {
                itemId = item:getId(),
                position = {
                    x = position.x,
                    y = position.y,
                    z = position.z
                },
                containerId = nil,
                containerSlot = nil
            }
            
            -- Jeśli przedmiot jest w kontenerze, zapisz containerId i slot
            if position.x == 65535 then
                slotTracking[slotIndex].containerId = position.y - 64
                slotTracking[slotIndex].containerSlot = position.z
            end
            
            widget:setItemId(item:getId())
            widget:setItemCount(1)
            checkCraftingSlots()
            return true
        end
    end
    return false
end

-- Funkcja do czyszczenia slotu
function clearSlot(slotIndex)
    local slot = craftingWindow:recursiveGetChildById('slot' .. slotIndex)
    if slot then
        slot:setItemId(0)
        slot:setItemCount(0)
    end
    slotTracking[slotIndex] = nil
    checkCraftingSlots()
end

-- Funkcja do walidacji wszystkich slotów - sprawdza czy przedmioty nadal istnieją
function validateAllSlots()
    for slotIndex, tracking in pairs(slotTracking) do
        if tracking then
            local itemStillExists = false
            
            if tracking.containerId ~= nil then
                -- Przedmiot był w kontenerze - sprawdź czy nadal tam jest
                local container = g_game.getContainer(tracking.containerId)
                if container then
                    local item = container:getItem(tracking.containerSlot)
                    if item and item:getId() == tracking.itemId then
                        itemStillExists = true
                    else
                        -- Może przedmiot przesunął się w kontenerze - szukaj po ID
                        for i = 0, container:getItemsCount() - 1 do
                            local checkItem = container:getItem(i)
                            if checkItem and checkItem:getId() == tracking.itemId then
                                -- Aktualizuj pozycję
                                tracking.containerSlot = i
                                itemStillExists = true
                                break
                            end
                        end
                    end
                end
            end
            
            if not itemStillExists then
                -- Przedmiot zniknął - wyczyść slot
                clearSlot(slotIndex)
            end
        end
    end
end

-- Callback: Otwarcie kontenera
function onContainerOpen(container, previousContainer)
    -- Waliduj sloty przy otwarciu kontenera
    scheduleEvent(validateAllSlots, 100)
end

-- Callback: Zamknięcie kontenera
function onContainerClose(container)
    local containerId = container:getId()
    
    -- Sprawdź czy któryś ze slotów śledził przedmiot z tego kontenera
    for slotIndex, tracking in pairs(slotTracking) do
        if tracking and tracking.containerId == containerId then
            clearSlot(slotIndex)
        end
    end
end

-- Callback: Aktualizacja przedmiotu w kontenerze
function onContainerUpdateItem(container, slot, item, oldItem)
    local containerId = container:getId()
    
    -- Sprawdź czy któryś slot śledził przedmiot na tej pozycji
    for slotIndex, tracking in pairs(slotTracking) do
        if tracking and tracking.containerId == containerId and tracking.containerSlot == slot then
            -- Jeśli nowy przedmiot ma inne ID lub go nie ma - wyczyść slot
            if not item or item:getId() ~= tracking.itemId then
                clearSlot(slotIndex)
            end
        end
    end
end

-- Callback: Usunięcie przedmiotu z kontenera
function onContainerRemoveItem(container, slot, lastItem)
    local containerId = container:getId()
    
    -- Sprawdź czy któryś slot śledził przedmiot na tej pozycji
    for slotIndex, tracking in pairs(slotTracking) do
        if tracking and tracking.containerId == containerId and tracking.containerSlot == slot then
            clearSlot(slotIndex)
        end
    end
    
    -- Zaktualizuj pozycje slotów dla przedmiotów które mogły się przesunąć
    for slotIndex, tracking in pairs(slotTracking) do
        if tracking and tracking.containerId == containerId and tracking.containerSlot > slot then
            tracking.containerSlot = tracking.containerSlot - 1
        end
    end
end

function checkCraftingSlots()
    currentCraftRecipeId = nil
    local resultItem = craftingWindow:recursiveGetChildById('resultItem')
    if resultItem then resultItem:setItemId(0) end
    
    -- Get current items in slots (these are Client IDs from drag&drop)
    local currentItems = {}
    for i = 1, 5 do
        local slot = craftingWindow:recursiveGetChildById('slot' .. i)
        if slot then
            currentItems[i] = slot:getItemId()
        else
            currentItems[i] = 0
        end
    end
    
    -- Check against recipes (convert Server ID to Client ID for comparison)
    for _, recipe in ipairs(recipes) do
        local match = true
        for i = 1, 5 do
            local expectedClientId = getClientId(recipe.ingredients[i])
            if currentItems[i] ~= expectedClientId then
                match = false
                break
            end
        end
        
        if match then
            currentCraftRecipeId = recipe.id
            if resultItem then 
                local resultClientId = getClientId(recipe.result)
                resultItem:setItemId(resultClientId) 
            end
            break
        end
    end
end

function craft()
    -- Check if all slots are empty
    local hasAnyItem = false
    for i = 1, 5 do
        local slot = craftingWindow:recursiveGetChildById('slot' .. i)
        if slot and slot:getItemId() > 0 then
            hasAnyItem = true
            break
        end
    end
    
    if not hasAnyItem then
        modules.game_textmessage.displayFailureMessage("Crafting failed: No items in crafting slots.")
        return
    end
    
    if not currentCraftRecipeId then
        modules.game_textmessage.displayFailureMessage("Crafting failed: Invalid item combination. Check your recipe.")
        return
    end

    -- Get recipe name for confirmation
    local recipeName = "Unknown"
    for _, recipe in ipairs(recipes) do
        if recipe.id == currentCraftRecipeId then
            recipeName = recipe.name
            break
        end
    end

    -- Show confirmation dialog
    local yesFunc = function()
        if craftConfirmWindow then
            craftConfirmWindow:destroy()
            craftConfirmWindow = nil
        end
        executeCraft()
    end
    
    local noFunc = function()
        if craftConfirmWindow then
            craftConfirmWindow:destroy()
            craftConfirmWindow = nil
        end
    end

    craftConfirmWindow = displayGeneralBox(
        tr('Crafting Confirmation'),
        tr('Are you sure you want to craft: %s?', recipeName),
        {
            {
                text = tr('Yes'),
                callback = yesFunc
            },
            {
                text = tr('No'),
                callback = noFunc
            },
            anchor = AnchorHorizontalCenter
        },
        yesFunc,
        noFunc
    )
end

function executeCraft()
    if not currentCraftRecipeId then
        modules.game_textmessage.displayFailureMessage("Crafting failed: Recipe no longer valid.")
        return
    end

    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        local json_data = {
            action = "craft",
            recipeId = currentCraftRecipeId
        }
        local jsonStr = json.encode(json_data)
        protocolGame:sendExtendedOpcode(OPCODE_CRAFTING, jsonStr)
        
        -- Show success message
        modules.game_textmessage.displayStatusMessage("Crafting in progress... Please wait.")
    else
        modules.game_textmessage.displayFailureMessage("Crafting failed: Connection error.")
    end
    
    -- Clear slots and tracking
    for i = 1, 5 do
        clearSlot(i)
    end
    checkCraftingSlots()
end
