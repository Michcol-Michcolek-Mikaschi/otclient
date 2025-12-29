offlineTrainingWindow = nil
offlineTrainingButton = nil
local OP_CODE = 56

function toggle()
    if not offlineTrainingWindow then return end
    if offlineTrainingWindow:isVisible() then
        offlineTrainingWindow:hide()
        if offlineTrainingButton then
            offlineTrainingButton:setOn(false)
            offlineTrainingButton:setImageClip({x=0, y=0, width=20, height=20})
        end
    else
        offlineTrainingWindow:show()
        offlineTrainingWindow:raise()
        offlineTrainingWindow:focus()
        if offlineTrainingButton then
            offlineTrainingButton:setOn(true)
            offlineTrainingButton:setImageClip({x=20, y=0, width=20, height=20})
        end
    end
end

function init()
    connect(g_game, { onGameEnd = offline })

    offlineTrainingWindow = g_ui.displayUI('offlinetraining')
    if offlineTrainingWindow then
        offlineTrainingWindow:hide()
    end

    -- Add button to Top Menu (Right Side)
    offlineTrainingButton = modules.game_mainpanel.addToggleButton(
        'offlineTrainingButton', 
        tr('Offline Training'), 
        '/images/options/offline_taning', 
        toggle, 
        false, 
        8
    )
    if offlineTrainingButton then
        offlineTrainingButton:setImageClip({x=0, y=0, width=20, height=20})
    end
end

function terminate()
    disconnect(g_game, { onGameEnd = offline })

    if offlineTrainingWindow then
        offlineTrainingWindow:destroy()
        offlineTrainingWindow = nil
    end

    if offlineTrainingButton then
        offlineTrainingButton:destroy()
        offlineTrainingButton = nil
    end
end

function offline()
    if offlineTrainingWindow then
        offlineTrainingWindow:hide()
    end
    if offlineTrainingButton then
        offlineTrainingButton:setOn(false)
        offlineTrainingButton:setImageClip({x=0, y=0, width=20, height=20})
    end
end

function onMiniWindowClose()
    -- Deprecated
end

function selectSkill(skillId, skillName)
    local id = tonumber(skillId)
    if id == nil then
        return
    end
    
    local message = tr('Are you sure you want to start offline training for %s?\nYou will be logged out.', skillName)
    
    local yesCallback = function()
        if g_game.isOnline() then
            g_game.getProtocolGame():sendExtendedOpcode(OP_CODE, tostring(id))
        end
        offlineTrainingWindow:hide()
        if offlineTrainingButton then
            offlineTrainingButton:setOn(false)
            offlineTrainingButton:setImageClip({x=0, y=0, width=20, height=20})
        end
    end

    local noCallback = function() end

    displayYesNoModal(tr('Offline Training'), message, yesCallback, noCallback)
end

function displayYesNoModal(title, message, yesCallback, noCallback)
    local window = g_ui.createWidget('MainWindow', rootWidget)
    window:setText(title)
    window:setWidth(380)
    window:setHeight(140)

    local label = g_ui.createWidget('Label', window)
    label:setText(message)
    label:setTextAlign(AlignCenter)
    label:setColor('#c0c0c0')
    label:addAnchor(AnchorTop, 'parent', AnchorTop)
    label:addAnchor(AnchorLeft, 'parent', AnchorLeft)
    label:addAnchor(AnchorRight, 'parent', AnchorRight)
    label:setMarginTop(15)
    label:setTextWrap(true)
    label:setTextAutoResize(true)

    local yesButton = g_ui.createWidget('Button', window)
    yesButton:setText(tr('Yes'))
    yesButton:setWidth(80)
    yesButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    yesButton:addAnchor(AnchorRight, 'parent', AnchorHorizontalCenter)
    yesButton:setMarginRight(10)
    yesButton:setMarginBottom(10)
    yesButton.onClick = function()
        window:destroy()
        if yesCallback then yesCallback() end
    end

    local noButton = g_ui.createWidget('Button', window)
    noButton:setText(tr('No'))
    noButton:setWidth(80)
    noButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
    noButton:addAnchor(AnchorLeft, 'parent', AnchorHorizontalCenter)
    noButton:setMarginLeft(10)
    noButton:setMarginBottom(10)
    noButton.onClick = function()
        window:destroy()
        if noCallback then noCallback() end
    end
end
