local DONATION_URL = nil
local GAME_SHOP_CODE = 201

local categories = {}
local offers = {}
local history = {}

local gameShopWindow = nil
local shopButton = nil
local selected = nil
local selectedOffer = nil
local changeNameWindow = nil
local msgWindow = nil
local transferWindow = nil

local premiumPoints = 0
local premiumSecondPoints = -1

local CATEGORY_NONE = -1
local CATEGORY_PREMIUM = 0
local CATEGORY_ITEM = 1
local CATEGORY_BLESSING = 2
local CATEGORY_OUTFIT = 3
local CATEGORY_MOUNT = 4
local CATEGORY_EXTRAS = 5
local CATEGORY_AURA = 6

local searchResultCategoryId = "Search Results"

-- Aura System Variables
local ownedAuras = {}
local equippedAura = 0
local currentAuraIndex = 1
local myAurasVisible = false
local auraEffectIds = {
    301, 302, 303,  -- Fire, Ice, Lightning (podstawowe)
    176, 177, 178, 179, 180, 181,  -- Shop Auras
    316, 330, 334, 338, 339, 346, 350, 364, 366, 370,
    388, 403, 405, 406, 407, 410, 411, 412, 416, 417,
    436, 438, 439, 447, 448, 449, 450, 456, 457, 458,
    459, 461, 466, 468, 477, 488, 489, 490, 498, 499,
    500, 501, 511, 514, 516, 517, 520, 523, 529, 530,
    531, 532, 533, 534, 535, 539, 540, 543, 544, 545,
    548, 559, 565, 566, 636, 659, 896, 898, 935, 954,
    955, 960, 962, 965, 985, 986, 987, 988, 990, 991, 1070, 777
}

-- Account Status Variables
local premiumDaysCount = 0
local vipDaysCount = 0

function init()
    connect(
        g_game,
        {
            onGameStart = create,
            onGameEnd = destroy
        }
    )

    ProtocolGame.registerExtendedOpcode(GAME_SHOP_CODE, onExtendedOpcode)
    
    -- Shop button is handled by game_mainpanel (Store button)
    
    if g_game.isOnline() then
        create()
    end
end

function terminate()
    disconnect(
        g_game,
        {
            onGameStart = create,
            onGameEnd = destroy
        }
    )

    ProtocolGame.unregisterExtendedOpcode(GAME_SHOP_CODE, onExtendedOpcode)
    
    destroy()
end

function onExtendedOpcode(protocol, code, buffer)
    local json_status, json_data =
        pcall(
        function()
            return json.decode(buffer)
        end
    )
    if not json_status then
        g_logger.error("SHOP json error: " .. json_data)
        return false
    end

    local action = json_data["action"]
    local data = json_data["data"]
    if not action or not data then
        return false
    end

    if action == "fetchBase" then
        onGameShopFetchBase(data)
    elseif action == "fetchOffers" then
        onGameShopFetchOffers(data)
    elseif action == "fetchDescription" then
        onGameShopFetchDescription(data)
    elseif action == "points" then
        onGameShopUpdatePoints(data)
    elseif action == "history" then
        onGameShopUpdateHistory(data)
    elseif action == "msg" then
        onGameShopMsg(data)
    elseif action == "fetchAuras" then
        onGameShopFetchAuras(data)
    elseif action == "equipAura" then
        onEquipAura(data)
    elseif action == "unequipAura" then
        onUnequipAura()
    elseif action == "accountStatus" then
        onAccountStatusUpdate(data)
    end
end

function create()
    if gameShopWindow then
        return
    end
    gameShopWindow = g_ui.displayUI("game_shop")
    gameShopWindow:hide()

    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({action = "fetch", data = {}}))
    end
    createTransferWindow()
end

function destroy()
    if gameShopWindow then
        gameShopWindow:destroy()
        gameShopWindow = nil
    end

    if msgWindow then
        msgWindow:destroy()
        msgWindow = nil
    end

    if changeNameWindow then
        changeNameWindow:destroy()
        changeNameWindow = nil
    end

    if transferWindow then
        transferWindow:destroy()
        transferWindow = nil
    end

    selected = nil
    selectedOffer = nil
end

function onGameShopFetchBase(data)
    -- Clear offers when receiving new base data (shop refresh)
    offers = {}
    
    for i = 1, #data.categories do
        addCategory(data.categories[i])
    end

    DONATION_URL = data.url
end

function hideTransferWindow()
    if transferWindow then
        transferWindow:hide()
    end
end

function show()
    hideTransferWindow()
    if not gameShopWindow then
        create()
    end

    if not gameShopWindow then
        return
    end

    hideHistory()
    gameShopWindow:show()
    gameShopWindow:raise()
    gameShopWindow:focus()
    
    -- Fetch owned auras and account status when shop opens
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({action = "fetchAuras", data = {}}))
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({action = "getAccountStatus", data = {}}))
    end
end

function hide()
    hideTransferWindow()
    if gameShopWindow then
        gameShopWindow:hide()
    end
end

function toggle()
    if gameShopWindow and gameShopWindow:isVisible() then
        hide()
    else
        show()
    end
end

function showHistory()
    deselect()
    gameShopWindow:getChildById("offers"):hide()
    gameShopWindow:getChildById("history"):show()
end

function hideHistory()
    gameShopWindow:getChildById("offers"):show()
    gameShopWindow:getChildById("history"):hide()
end

local entriesPerPage = 25
local currentPage = 1
local totalPages = 1

function updateHistory()
    local historyPanel = gameShopWindow:getChildById("history")
    local historyList = historyPanel:getChildById("list")
    historyList:destroyChildren()

    local index = ((currentPage - 1) * entriesPerPage) + 1
    for i = index, math.min(#history, index + entriesPerPage - 1) do
        local widget = g_ui.createWidget("HistoryWidget", historyList)
        widget:getChildById("date"):setText(history[i].date)
        widget:getChildById("price"):setText((history[i].price > 0 and "+" or "") .. comma_value(history[i].price))
        widget:getChildById("price"):setOn(history[i].price > 0)
        widget:getChildById("coin"):setOn(history[i].isSecondPrice)
        widget:getChildById("description"):setText(history[i].name)
    end

    historyPanel:getChildById("pageLabel"):setText("Page " .. currentPage .. "/" .. totalPages)
end

function onGameShopUpdateHistory(historyList)
    currentPage = 1
    history = historyList
    totalPages = math.max(1, math.ceil(#history / entriesPerPage))

    local historyPanel = gameShopWindow:getChildById("history")
    updateHistory()
    historyPanel:getChildById("nextPageButton"):setVisible(totalPages > 1)
end

function prevPage()
    if currentPage == 1 then
        return true
    end

    currentPage = currentPage - 1

    local historyPanel = gameShopWindow:getChildById("history")
    updateHistory()

    historyPanel:getChildById("nextPageButton"):setVisible(currentPage < totalPages)
    historyPanel:getChildById("prevPageButton"):setVisible(currentPage > 1)
end

function nextPage()
    if currentPage == totalPages then
        return true
    end

    currentPage = currentPage + 1

    local historyPanel = gameShopWindow:getChildById("history")
    updateHistory()

    historyPanel:getChildById("nextPageButton"):setVisible(currentPage < totalPages)
    historyPanel:getChildById("prevPageButton"):setVisible(currentPage > 1)
end

function deselect()
    if selected then
        selected:getChildById("button"):setChecked(false)
        local arrow = selected:getChildById("selectArrow")
        if arrow then
            arrow:hide()
        end

        if not selected:getChildById("subCategories") then
            selected = selected:getParent():getParent()
            selected:getChildById("expandArrow"):show()
        end

        selected:setHeight(22)
        selected:getChildById("subCategories"):hide()
    end
end

function comma_value(n)
    local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function buyPoints()
    g_platform.openUrl(DONATION_URL)
end

function onGameShopFetchOffers(data)
    -- Append offers instead of replacing (supports chunked sending from server)
    if not offers[data.category] then
        offers[data.category] = {}
    end
    for _, offer in ipairs(data.offers) do
        table.insert(offers[data.category], offer)
    end
    
    if not selected and data.category == "Premium Time" then
        select(gameShopWindow:getChildById("categoriesList"):getChildren()[1]:getChildById("button"))
    end
end

function addCategory(data)
    categories[data.title] = data
    local categoriesList = gameShopWindow:getChildById("categoriesList")
    local category
    if data.parent then
        local parentPanel = categoriesList:getChildById(data.parent)
        category = g_ui.createWidget("ShopSubCategory", parentPanel:getChildById("subCategories"))
        parentPanel:getChildById("expandArrow"):show()
    else
        category = g_ui.createWidget("ShopCategory", categoriesList)
    end

    category:setId(data.title)
    category:getChildById("button"):setIconClip(data.iconId * 13 .. " 0 13 13")
    category:getChildById("name"):setText(data.title)
end

function onGameShopUpdatePoints(data)
    premiumPoints = tonumber(data.points)
    premiumSecondPoints = tonumber(data.secondPoints)

    if not gameShopWindow then
        create()
    end

    if not gameShopWindow then
        return
    end

    local pointsWidget = gameShopWindow:getChildById("balance"):getChildById("value")
    pointsWidget:setText(comma_value(premiumPoints))

    local balanceSecondWidget = gameShopWindow:getChildById("balanceSecond")
    if premiumSecondPoints ~= -1 then
        balanceSecondWidget:getChildById("value"):setText(comma_value(premiumSecondPoints))
        balanceSecondWidget:show()
        balanceSecondWidget:setWidth(105)
        balanceSecondWidget:setMarginLeft(6)
        transferWindow.taskPointsLabelCoin:show()
        transferWindow.taskPointsAmountScrollbar:show()
        transferWindow.taskPointsCoin:show()
        transferWindow.taskPointsBalance:show()
        transferWindow.taskPointsBalance:setText(tr("Transferable Task points: ") .. comma_value(premiumSecondPoints))
        transferWindow.taskPointsAmountScrollbar:setMaximum(premiumSecondPoints)
    else
        balanceSecondWidget:hide()
        balanceSecondWidget:setWidth(1)
        balanceSecondWidget:setMarginLeft(0)
        transferWindow.taskPointsBalance:hide()
        transferWindow.taskPointsAmountLabel:hide()
        transferWindow.taskPointsLabelCoin:hide()
        transferWindow.taskPointsAmountScrollbar:hide()
        transferWindow.taskPointsCoin:hide()
    end

    transferWindow.coinsBalance:setText(tr("Transferable Tibia Coins: ") .. comma_value(premiumPoints))
    transferWindow.coinsAmountScrollbar:setMaximum(premiumPoints)
end

function select(self, ignoreSearch)
    hideHistory()
    if not ignoreSearch then
        eraseSearchResults()
    end

    local selfParent = self:getParent()
    local panel = selfParent:getChildById("subCategories")
    if panel then
        deselect()
        selected = selfParent

        if panel:getChildCount() > 0 then
            panel:show()
            selfParent:setHeight((panel:getChildCount() + 1) * 22)
            selfParent:getChildById("expandArrow"):hide()
            select(panel:getChildren()[1]:getChildById("button"))
        else
            self:setChecked(true)
        end
    else
        if selected then
            selected:getChildById("button"):setChecked(false)

            local arrow = selected:getChildById("selectArrow")
            if arrow then
                arrow:hide()
            end
        end

        selected = selfParent

        self:setChecked(true)
        selfParent:getChildById("selectArrow"):show()
    end

    showOffers(selfParent:getId())
end

function selectOffer(self)
    if selectedOffer then
        selectedOffer:setChecked(false)
    end

    self:setChecked(true)
    selectedOffer = self
    
    if not selectedOffer.categoryId then
        selectedOffer.categoryId = selected:getId()
    end

    updateDescription(self)
end

function showOffers(id)
    local offersCache = offers[id]
    if not offersCache then
        return
    end

    local currentOutfit = g_game.getLocalPlayer():getOutfit()
    local offersPanel = gameShopWindow:getChildById("offers")
    local offersList = offersPanel:getChildById("offersList")
    offersList:destroyChildren()

    for i = 1, #offersCache do
        local widget = offersList:getChildById(offersCache[i].name)
        local price = offersCache[i].price
        if widget then
            local additionalPriceWidget = widget:getChildById("additionalPrice")
            additionalPriceWidget:getChildById("coin"):setOn(offersCache[i].isSecondPrice)
            additionalPriceWidget:getChildById("value"):setText(comma_value(price))
            additionalPriceWidget:show()

            local additionalCountWidget = widget:getChildById("additionalCount")
            additionalCountWidget:setText(offersCache[i].count .. "x")
            additionalCountWidget:show()

            widget:getChildById("count"):show()
            widget.additionalPriceValue = price
            widget.additionalIsSecondPrice = isSecondPrice
            widget.additionalCountValue = offersCache[i].count

            if i == 2 then
                selectOffer(widget)
            end
        else
            local widget = g_ui.createWidget("OfferWidget", offersList)
            local priceWidget = widget:getChildById("price")
            priceWidget:getChildById("coin"):setOn(offersCache[i].isSecondPrice)
            priceWidget:getChildById("value"):setText(comma_value(price))

            widget:getChildById("name"):setText(offersCache[i].name)
            widget:getChildById("count"):setText(offersCache[i].count .. "x")
            widget:setId(offersCache[i].name)
            widget.data = offersCache[i]
            widget.categoryId = id

            local imagePanel = widget:getChildById("imagePanel")
            local image = imagePanel:getChildById("image")
            local categoryId = offersCache[i].categoryId
            local item = imagePanel:getChildById("item")
            local outfit = imagePanel:getChildById("outfit")
            local mount = imagePanel:getChildById("mount")
            local auraPreview = imagePanel:getChildById("auraPreview")

            local imageSource = offersCache[i].image
            if not imageSource and type(offersCache[i].id) == "string" then
                imageSource = offersCache[i].id
            end

            if imageSource and categoryId ~= CATEGORY_AURA then
                image:show()
                if not imageSource:match("%.png$") then
                    imageSource = imageSource .. ".png"
                end
                image:setImageSource("/game_shop/images/" .. imageSource)
            elseif categoryId == CATEGORY_AURA then
                -- Set category ID for updateDescription
                widget.offerCategoryId = categoryId
                
                -- Show creature with aura effect
                local auraId = offersCache[i].id
                auraPreview:show()
                auraPreview:setOutfit(currentOutfit)
                local auraCreature = auraPreview:getCreature()
                if auraCreature then
                    auraCreature:clearAttachedEffects()
                    if type(auraId) == "number" then
                        local effect = g_attachedEffects.getById(auraId)
                        if effect then
                            auraCreature:attachEffect(effect)
                        end
                    end
                end
                
                -- Check if owned and show badge
                local ownedLabel = widget:getChildById("ownedLabel")
                if ownedLabel and isAuraOwned(auraId) then
                    ownedLabel:show()
                end
            elseif type(offersCache[i].id) == "number" then
                widget.offerCategoryId = categoryId
                if categoryId == CATEGORY_ITEM then
                    item:show()
                    item:setItemId(offersCache[i].id)
                    widget:getChildById("count"):show()
                elseif categoryId == CATEGORY_OUTFIT then
                    currentOutfit.type = offersCache[i].id
                    outfit:show()
                    outfit:setOutfit(currentOutfit)
                elseif categoryId == CATEGORY_MOUNT then
                    mount:show()
                    mount:setOutfit({type = offersCache[i].id})
                elseif categoryId == CATEGORY_EXTRAS then
                    item:show()
                    item:setItemId(offersCache[i].id)
                end
            end

            if i == 1 then
                selectOffer(widget)
            end
        end
    end
    
    -- Hide My Auras panel when showing offers
    if myAurasVisible then
        local offersPanel = gameShopWindow:getChildById("offers")
        local myAurasPanel = offersPanel:getChildById("myAuras")
        myAurasPanel:hide()
        offersPanel:getChildById("offersList"):show()
        offersPanel:getChildById("offersListScrollBar"):show()
        offersPanel:getChildById("offerDetails"):show()
        myAurasVisible = false
        gameShopWindow:getChildById("myAurasButton"):setChecked(false)
    end
end

function updateDescription(self)
    local offersPanel = gameShopWindow:getChildById("offers")
    local offerDetails = offersPanel:getChildById("offerDetails")
    offerDetails:show()
    offerDetails:getChildById("name"):setText(self.data.name)

    local descriptionPanel = offerDetails:getChildById("description")
    local widget = descriptionPanel:getChildren()[1]
    if not widget then
        widget = g_ui.createWidget("OfferDescriptionLabel", descriptionPanel)
    end

    local categoryToUse = self.data.originalCategory or self.categoryId
    if self.categoryId == searchResultCategoryId and not self.data.originalCategory then
        categoryToUse = self.data.parent
    end

    g_game.getProtocolGame():sendExtendedOpcode(
        GAME_SHOP_CODE,
        json.encode({
            action = "getDescription",
            data = {
                category = categoryToUse,
                name = self.data.name
            }
        })
    )

    local buyButton = offerDetails:getChildById("buyButton")
    local priceWidget = offerDetails:getChildById("price")
    local additionalBuyButton = offerDetails:getChildById("additionalBuyButton")
    local additionalPriceWidget = offerDetails:getChildById("additionalPrice")

    priceWidget:setOn(self.data.isSecondPrice)
    priceWidget:setText(comma_value(self.data.price))

    local globalPoints = self.data.isSecondPrice and premiumSecondPoints or premiumPoints
    priceWidget:setEnabled(self.data.price <= globalPoints)
    buyButton:setEnabled(self.data.price <= globalPoints)

    if self.additionalPriceValue and self.additionalCountValue then
        buyButton:setText("Buy " .. self.data.count)

        additionalPriceWidget:setEnabled(self.additionalPriceValue <= globalPoints)
        additionalBuyButton:setText("Buy " .. self.additionalCountValue)
        additionalBuyButton:show()
        additionalBuyButton:setEnabled(self.additionalPriceValue <= globalPoints)
        additionalBuyButton.price = self.additionalPriceValue
        additionalBuyButton.count = self.additionalCountValue
        buyButton.secondPrice = self.data.secondPrice
        buyButton.price = self.data.price
        buyButton.count = self.data.count

        additionalPriceWidget:setOn(self.data.isSecondPrice)
        additionalPriceWidget:setText(comma_value(self.additionalPriceValue))
        additionalPriceWidget:show()
    else
        additionalBuyButton:hide()

        buyButton.secondPrice = nil
        buyButton.price = nil
        buyButton.count = nil

        buyButton:setText("Buy")
        additionalPriceWidget:hide()
    end

    local currentOutfit = g_game.getLocalPlayer():getOutfit()
    local imagePanel = offerDetails:getChildById("imagePanel")
    local image = imagePanel:getChildById("image")
    local item = imagePanel:getChildById("item")
    local outfit = imagePanel:getChildById("outfit")
    local mount = imagePanel:getChildById("mount")
    image:hide()
    item:hide()
    outfit:hide()
    mount:hide()
    local detailImage = self.data.image
    if not detailImage and type(self.data.id) == "string" then
        detailImage = self.data.id
    end

    -- Obsługa kategorii AURA
    local auraPreview = imagePanel:getChildById("auraPreview")
    local ownedBadge = offerDetails:getChildById("ownedBadge")
    local prevOfferBtn = imagePanel:getChildById("prevOfferBtn")
    local nextOfferBtn = imagePanel:getChildById("nextOfferBtn")
    
    if auraPreview then auraPreview:hide() end
    if ownedBadge then ownedBadge:hide() end
    if prevOfferBtn then prevOfferBtn:hide() end
    if nextOfferBtn then nextOfferBtn:hide() end
    
    local categoryId = self.offerCategoryId or self.data.offerCategoryId or self.data.categoryId or self.categoryId
    
    if categoryId == CATEGORY_AURA then
        -- Wyświetl podgląd aury z efektem
        if auraPreview then
            auraPreview:show()
            local playerOutfit = g_game.getLocalPlayer():getOutfit()
            auraPreview:setOutfit(playerOutfit)
            
            -- Przypisz efekt aury
            local effectId = self.data.id
            local auraCreature = auraPreview:getCreature()
            if auraCreature and effectId and g_attachedEffects then
                auraCreature:clearAttachedEffects()
                local effect = g_attachedEffects.getById(effectId)
                if effect then
                    auraCreature:attachEffect(effect)
                end
            end
        end
        
        -- Pokaż strzałki nawigacji
        if prevOfferBtn then prevOfferBtn:show() end
        if nextOfferBtn then nextOfferBtn:show() end
        
        -- Sprawdź czy aura jest posiadana
        local owned = isAuraOwned(self.data.id)
        if owned and ownedBadge then
            ownedBadge:show()
        end
        
        -- Zmień tekst przycisku
        if owned then
            buyButton:setText("Owned")
            buyButton:setEnabled(false)
        else
            buyButton:setText("Buy")
            buyButton:setEnabled(self.data.price <= globalPoints)
        end
    elseif detailImage then
        image:show()
        if not detailImage:match("%.png$") then
            detailImage = detailImage .. ".png"
        end
        image:setImageSource("/game_shop/images/" .. detailImage)
    elseif type(self.data.id) == "number" then
        if table.contains({CATEGORY_ITEM, CATEGORY_EXTRAS}, categoryId) then
            item:show()
            item:setItemId(self.data.id)
        elseif categoryId == CATEGORY_OUTFIT then
            currentOutfit.type = self.data.id
            outfit:show()
            outfit:setOutfit(currentOutfit)
        elseif categoryId == CATEGORY_MOUNT then
            mount:show()
            mount:setOutfit({type = self.data.id})
        end
    end
end

function onGameShopFetchDescription(data)
    if not selectedOffer then
        return
    end
    
    if selectedOffer.data.name ~= data.name then
        return
    end
    
    if selectedOffer.categoryId == searchResultCategoryId and 
       data.category and selectedOffer.data.originalCategory and 
       data.category ~= selectedOffer.data.originalCategory then
        return
    end

    local offersPanel = gameShopWindow:getChildById("offers")
    local offerDetails = offersPanel:getChildById("offerDetails")
    local descriptionPanel = offerDetails:getChildById("description")
    local widget = descriptionPanel:getChildren()[1]
    if not widget then
        widget = g_ui.createWidget("OfferDescriptionLabel", descriptionPanel)
    end
    widget:setText(data.description)
end

function onOfferBuy(self)
    if not selectedOffer then
        displayInfoBox("Error", "Something went wrong, make sure to select category and offer.")
        return
    end

    -- Sprawdź czy to kategoria aury
    local categoryId = selectedOffer.offerCategoryId or selectedOffer.data.offerCategoryId or selectedOffer.categoryId
    if categoryId == CATEGORY_AURA then
        -- Sprawdź czy aura jest już posiadana
        if isAuraOwned(selectedOffer.data.id) then
            displayInfoBox("Info", "You already own this aura.")
            return
        end
        
        hide()
        
        local title = "Purchase Aura"
        local msg = "Do you want to buy " .. selectedOffer.data.name .. " for " .. comma_value(selectedOffer.data.price) .. " points?"
        
        msgWindow = displayGeneralBox(
            title,
            msg,
            {
                {text = "Yes", callback = buyAuraConfirmed},
                {text = "No", callback = buyCanceled},
                anchor = AnchorHorizontalCenter
            },
            buyAuraConfirmed,
            buyCanceled
        )
        msgWindow.auraId = selectedOffer.data.id
        return
    end

    hide()

    local title = "Purchase Confirmation"
    local msg
    if self.count and self.count > 1 then
        msg =
            "Do you want to buy " ..
            self.count .. "x " .. selectedOffer.data.name .. " for " .. comma_value(self.price) .. " points?"
    else
        msg =
            "Do you want to buy " ..
            selectedOffer.data.name .. " for " .. comma_value(selectedOffer.data.price) .. " points?"
    end

    if selectedOffer.data.name == "Name Change" then
        msgWindow =
            displayGeneralBox(
            title,
            msg,
            {
                {text = "Yes", callback = changeName},
                {text = "No", callback = buyCanceled},
                anchor = AnchorHorizontalCenter
            },
            changeName,
            buyCanceled
        )
    else
        msgWindow =
            displayGeneralBox(
            title,
            msg,
            {
                {text = "Yes", callback = buyConfirmed},
                {text = "No", callback = buyCanceled},
                anchor = AnchorHorizontalCenter
            },
            buyConfirmed,
            buyCanceled
        )
    end

    if self.count and self.count > 1 then
        msgWindow.count = self.count
        msgWindow.price = self.price
    else
        msgWindow.count = selectedOffer.data.count
        msgWindow.price = selectedOffer.data.price
    end
end

function buyConfirmed()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(
            GAME_SHOP_CODE,
            json.encode(
                {
                    action = "purchase",
                    data = {
                        count = msgWindow.count,
                        price = msgWindow.price,
                        name = selectedOffer.data.name,
                        id = selectedOffer.data.id,
                        parent = selectedOffer.data.parent,
                        originalCategory = selectedOffer.data.originalCategory
                    }
                }
            )
        )
    end

    msgWindow:destroy()
    msgWindow = nil
end

function buyAuraConfirmed()
    local auraId = msgWindow.auraId
    if auraId then
        purchaseAura(auraId)
    end
    msgWindow:destroy()
    msgWindow = nil
end

function buyCanceled()
    msgWindow:destroy()
    msgWindow = nil
    show()
end

function changeName()
    msgWindow:destroy()
    msgWindow = nil
    if changeNameWindow then
        return
    end

    changeNameWindow = g_ui.displayUI("changename")
end

function confirmChangeName()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(
            GAME_SHOP_CODE,
            json.encode(
                {
                    action = "purchase",
                    data = {
                        count = selectedOffer.data.count,
                        price = selectedOffer.data.price,
                        name = selectedOffer.data.name,
                        id = selectedOffer.data.id,
                        parent = selectedOffer.data.parent,
                        nick = changeNameWindow:getChildById("targetName"):getText()
                    }
                }
            )
        )

        changeNameWindow:destroy()
        changeNameWindow = nil
    end
end

function cancelChangeName()
    changeNameWindow:destroy()
    changeNameWindow = nil
end

function onGameShopMsg(data)
    local type = data.type
    local text = data.msg

    local title = nil
    local close = false
    if type == "info" then
        title = "Store Information"
        close = data.close
    elseif type == "error" then
        title = "Store Error"
        close = true
    end

    if close then
        hideHistory()
        hide()
    end

    displayInfoBoxWithCallback(
        title,
        text,
        {{text = "Ok", callback = defaultCallback}},
        function()
            show()
        end
    )
end

function displayInfoBoxWithCallback(title, message, callback)
    local messageBox
    local defaultCallback = function()
        if callback then
            show()
        end
        messageBox:ok()
    end

    messageBox =
        UIMessageBox.display(
        title,
        message,
        {{text = "Ok", callback = defaultCallback}},
        defaultCallback,
        defaultCallback
    )
    return messageBox
end

function changeCoinsAmount(value)
    transferWindow:getChildById("coinsAmountLabel"):setText("Amount to gift: " .. comma_value(value))
end

function changeTaskPointsAmount(value)
    transferWindow:getChildById("taskPointsAmountLabel"):setText("Amount to gift: " .. comma_value(value))
end

function confirmGiftCoins()
    if not transferWindow then
        return
    end

    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(
            GAME_SHOP_CODE,
            json.encode(
                {
                    action = "transfer",
                    data = {
                        amount = tonumber(transferWindow.coinsAmountScrollbar:getValue()),
                        amountSecond = tonumber(transferWindow.taskPointsAmountScrollbar:getValue()),
                        target = transferWindow.recipient:getText()
                    }
                }
            )
        )
        transferWindow.recipient:setText("")
        transferWindow.coinsAmountScrollbar:setValue(0)
        transferWindow.taskPointsAmountScrollbar:setValue(0)
    end
end

function cancelGiftCoins()
    if transferWindow then
        transferWindow:hide()
        show()
    end
end

function createTransferWindow()
    if not transferWindow then
        transferWindow = g_ui.displayUI("giftcoins")
        transferWindow:hide()
    end
end

function toggle()
    if not gameShopWindow then
        return
    end

    if gameShopWindow:isVisible() then
        return hide()
    end

    show()
end

function toggleGiftCoins()
    if transferWindow then
        hide()
        transferWindow:show()
        transferWindow:raise()
        transferWindow:focus()
        transferWindow:setOn(premiumSecondPoints ~= -1)
    end
end

function onTypeSearch(self)
    gameShopWindow:getChildById("searchButton"):setEnabled(#self:getText() > 2)
end

function eraseSearchResults()
    local widget = gameShopWindow:getChildById("categoriesList"):getChildById(searchResultCategoryId)
    if widget then
        if selected == widget then
            selected = nil
        end
        widget:destroy()
    end
end

function onSearch()
    local searchTextEdit = gameShopWindow:getChildById("searchTextEdit")
    local text = searchTextEdit:getText()

    if #text < 3 then
        return
    end

    eraseSearchResults()
    addCategory(
        {
            title = searchResultCategoryId,
            iconId = 7,
            categoryId = CATEGORY_NONE
        }
    )

    offers[searchResultCategoryId] = {}
    local results = {}
    local searchTerm = text:lower()

    for categoryId, offerData in pairs(offers) do
        if categoryId ~= searchResultCategoryId then
            for _, offer in pairs(offerData) do
                if string.find(offer.name:lower(), searchTerm) then
                    local offerCopy = table.copy(offer)
                    offerCopy.originalCategory = categoryId
                    offerCopy.offerCategoryId = offer.categoryId
                    table.insert(results, offerCopy)
                end
            end
        end
    end

    for _, offer in ipairs(results) do
        table.insert(offers[searchResultCategoryId], offer)
    end

    local children = gameShopWindow:getChildById("categoriesList"):getChildren()
    select(children[#children]:getChildById("button"), true)
    searchTextEdit:clearText()
end

-- ==================== AURA SYSTEM FUNCTIONS ====================

-- ==================== ACCOUNT STATUS FUNCTIONS ====================

function onAccountStatusUpdate(data)
    premiumDaysCount = data.premiumDays or 0
    vipDaysCount = data.vipDays or 0
    updateAccountStatusDisplay()
end

function updateAccountStatusDisplay()
    if not gameShopWindow then
        return
    end
    
    local statusPanel = gameShopWindow:getChildById("accountStatusPanel")
    if not statusPanel then
        return
    end
    
    local premiumLabel = statusPanel:getChildById("premiumDays")
    local vipLabel = statusPanel:getChildById("vipDays")
    local premiumText = statusPanel:getChildById("premiumLabel")
    local vipText = statusPanel:getChildById("vipLabelText")
    
    if premiumLabel then
        if premiumDaysCount > 0 then
            premiumLabel:setText(premiumDaysCount .. "d")
            premiumLabel:setColor("#44AD25")  -- Green for active
            if premiumText then premiumText:setColor("#44AD25") end
        else
            premiumLabel:setText("0d")
            premiumLabel:setColor("#808080")  -- Gray for inactive
            if premiumText then premiumText:setColor("#808080") end
        end
    end
    
    if vipLabel then
        if vipDaysCount > 0 then
            vipLabel:setText(vipDaysCount .. "d")
            vipLabel:setColor("#9370DB")  -- Purple for active VIP
            if vipText then vipText:setColor("#9370DB") end
        else
            vipLabel:setText("0d")
            vipLabel:setColor("#808080")  -- Gray for inactive
            if vipText then vipText:setColor("#808080") end
        end
    end
end

function requestAccountStatus()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({action = "getAccountStatus", data = {}}))
    end
end

-- ==================== AURA FUNCTIONS ====================

function onGameShopFetchAuras(data)
    ownedAuras = {}
    
    -- New format: server sends only owned aura IDs
    if data.ownedIds then
        -- Create lookup table for owned IDs
        local ownedLookup = {}
        for _, id in ipairs(data.ownedIds) do
            ownedLookup[id] = true
        end
        
        -- Build ownedAuras list from local auraEffectIds
        for _, effectId in ipairs(auraEffectIds) do
            if ownedLookup[effectId] then
                table.insert(ownedAuras, {
                    id = effectId,
                    name = "Aura " .. effectId,
                    owned = true
                })
            end
        end
    -- Legacy format: server sends full auras list
    elseif data.auras then
        for _, aura in ipairs(data.auras) do
            if aura.owned then
                table.insert(ownedAuras, aura)
            end
        end
    end
    
    equippedAura = data.equippedAura or 0
    
    -- Apply the aura effect to local player if one is equipped
    -- This handles the case when player logs in with an active aura
    local player = g_game.getLocalPlayer()
    if player and equippedAura > 0 then
        -- Clear any existing aura effects first
        for _, effectId in ipairs(auraEffectIds) do
            player:detachEffectById(effectId)
        end
        
        -- Attach the equipped aura
        local effect = g_attachedEffects.getById(equippedAura)
        if effect then
            player:attachEffect(effect)
        end
    end
    
    -- Always update My Auras panel if visible
    if myAurasVisible then
        updateMyAurasPanel()
    end
end

function onEquipAura(data)
    local auraId = data.auraId
    equippedAura = auraId
    
    -- Attach the effect to local player
    local player = g_game.getLocalPlayer()
    if player then
        -- Clear any existing aura effects first by ID
        for _, effectId in ipairs(auraEffectIds) do
            player:detachEffectById(effectId)
        end
        
        -- Attach the new aura
        if auraId > 0 then
            local effect = g_attachedEffects.getById(auraId)
            if effect then
                player:attachEffect(effect)
            end
        end
    end
    
    if myAurasVisible then
        updateMyAurasPanel()
    end
end

function onUnequipAura()
    local player = g_game.getLocalPlayer()
    if player then
        -- Clear all aura effects by ID
        for _, effectId in ipairs(auraEffectIds) do
            player:detachEffectById(effectId)
        end
    end
    
    equippedAura = 0
    
    if myAurasVisible then
        updateMyAurasPanel()
    end
end

function toggleMyAuras()
    local offersPanel = gameShopWindow:getChildById("offers")
    local myAurasPanel = offersPanel:getChildById("myAuras")
    local historyPanel = gameShopWindow:getChildById("history")
    local myAurasButton = gameShopWindow:getChildById("myAurasButton")
    
    if myAurasVisible then
        myAurasVisible = false
        myAurasPanel:hide()
        offersPanel:getChildById("offersList"):show()
        offersPanel:getChildById("offersListScrollBar"):show()
        offersPanel:getChildById("offerDetails"):show()
        myAurasButton:setChecked(false)
    else
        myAurasVisible = true
        historyPanel:hide()
        offersPanel:getChildById("offersList"):hide()
        offersPanel:getChildById("offersListScrollBar"):hide()
        offersPanel:getChildById("offerDetails"):hide()
        myAurasPanel:show()
        myAurasButton:setChecked(true)
        
        -- Fetch latest aura data
        local protocolGame = g_game.getProtocolGame()
        if protocolGame then
            protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({action = "fetchAuras", data = {}}))
        end
        
        currentAuraIndex = 1
        updateMyAurasPanel()
    end
end

function updateMyAurasPanel()
    local offersPanel = gameShopWindow:getChildById("offers")
    local myAurasPanel = offersPanel:getChildById("myAuras")
    
    local auraImagePanel = myAurasPanel:getChildById("auraImagePanel")
    local auraCreature = auraImagePanel:getChildById("auraCreature")
    local auraName = myAurasPanel:getChildById("auraName")
    local auraCount = myAurasPanel:getChildById("auraCount")
    local toggleButton = myAurasPanel:getChildById("toggleAuraButton")
    local emptyLabel = myAurasPanel:getChildById("auraEmpty")
    local prevBtn = auraImagePanel:getChildById("prevAuraBtn")
    local nextBtn = auraImagePanel:getChildById("nextAuraBtn")
    
    if #ownedAuras == 0 then
        emptyLabel:show()
        auraImagePanel:hide()
        auraName:hide()
        auraCount:hide()
        toggleButton:hide()
        return
    end
    
    emptyLabel:hide()
    auraImagePanel:show()
    auraName:show()
    auraCount:show()
    toggleButton:show()
    
    -- Clamp index
    if currentAuraIndex > #ownedAuras then
        currentAuraIndex = 1
    end
    if currentAuraIndex < 1 then
        currentAuraIndex = #ownedAuras
    end
    
    local currentAura = ownedAuras[currentAuraIndex]
    
    -- Setup creature with aura effect
    auraCreature:show()
    local player = g_game.getLocalPlayer()
    if player then
        auraCreature:setOutfit(player:getOutfit())
        
        -- Clear and attach aura effect to preview creature
        local creature = auraCreature:getCreature()
        if creature then
            creature:clearAttachedEffects()
            local effect = g_attachedEffects.getById(currentAura.id)
            if effect then
                creature:attachEffect(effect)
            end
        end
    end
    
    auraName:setText(currentAura.name)
    auraCount:setText(currentAuraIndex .. " / " .. #ownedAuras)
    
    -- Show/hide navigation buttons
    prevBtn:setVisible(#ownedAuras > 1)
    nextBtn:setVisible(#ownedAuras > 1)
    
    -- Update toggle button text
    if equippedAura == currentAura.id then
        toggleButton:setText("Unequip")
    else
        toggleButton:setText("Equip")
    end
end

function prevAura()
    if #ownedAuras <= 1 then
        return
    end
    
    currentAuraIndex = currentAuraIndex - 1
    if currentAuraIndex < 1 then
        currentAuraIndex = #ownedAuras
    end
    
    updateMyAurasPanel()
end

function nextAura()
    if #ownedAuras <= 1 then
        return
    end
    
    currentAuraIndex = currentAuraIndex + 1
    if currentAuraIndex > #ownedAuras then
        currentAuraIndex = 1
    end
    
    updateMyAurasPanel()
end

function toggleAura()
    if #ownedAuras == 0 then
        return
    end
    
    local currentAura = ownedAuras[currentAuraIndex]
    if not currentAura then
        return
    end
    
    local protocolGame = g_game.getProtocolGame()
    if not protocolGame then
        return
    end
    
    if equippedAura == currentAura.id then
        -- Unequip
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({
            action = "unequipAura",
            data = {}
        }))
    else
        -- Equip
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({
            action = "equipAura",
            data = { auraId = currentAura.id }
        }))
    end
end

function prevOffer()
    if not selectedOffer or not selectedOffer.categoryId then
        return
    end
    
    local categoryOffers = offers[selectedOffer.categoryId]
    if not categoryOffers or #categoryOffers <= 1 then
        return
    end
    
    local currentIndex = 1
    for i, offer in ipairs(categoryOffers) do
        if offer.name == selectedOffer.data.name then
            currentIndex = i
            break
        end
    end
    
    local newIndex = currentIndex - 1
    if newIndex < 1 then
        newIndex = #categoryOffers
    end
    
    -- Find and select the offer widget
    local offersList = gameShopWindow:getChildById("offers"):getChildById("offersList")
    local children = offersList:getChildren()
    for _, widget in ipairs(children) do
        if widget.data and widget.data.name == categoryOffers[newIndex].name then
            selectOffer(widget)
            break
        end
    end
end

function nextOffer()
    if not selectedOffer or not selectedOffer.categoryId then
        return
    end
    
    local categoryOffers = offers[selectedOffer.categoryId]
    if not categoryOffers or #categoryOffers <= 1 then
        return
    end
    
    local currentIndex = 1
    for i, offer in ipairs(categoryOffers) do
        if offer.name == selectedOffer.data.name then
            currentIndex = i
            break
        end
    end
    
    local newIndex = currentIndex + 1
    if newIndex > #categoryOffers then
        newIndex = 1
    end
    
    -- Find and select the offer widget
    local offersList = gameShopWindow:getChildById("offers"):getChildById("offersList")
    local children = offersList:getChildren()
    for _, widget in ipairs(children) do
        if widget.data and widget.data.name == categoryOffers[newIndex].name then
            selectOffer(widget)
            break
        end
    end
end

function purchaseAura(auraId)
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(GAME_SHOP_CODE, json.encode({
            action = "purchaseAura",
            data = { auraId = auraId }
        }))
    end
end

function isAuraOwned(auraId)
    for _, aura in ipairs(ownedAuras) do
        if aura.id == auraId then
            return true
        end
    end
    return false
end

function openCategory(categoryId)
    if not gameShopWindow then
        create()
    end
    
    if not gameShopWindow then
        return
    end
    
    if not gameShopWindow:isVisible() then
        gameShopWindow:show()
        gameShopWindow:raise()
        gameShopWindow:focus()
    end
    
    -- Find category widget
    local categoriesList = gameShopWindow:getChildById("categoriesList")
    if not categoriesList then
        return
    end
    
    local children = categoriesList:getChildren()
    
    for _, widget in ipairs(children) do
        if widget.data and widget.data.categoryId == categoryId then
            selectCategory(widget)
            break
        end
    end
end
