autolootWindow = nil
autolootButton = nil

local currentMode = 1
local blacklistEnabled = false
local blacklistItems = {}

function init()
  connect(g_game, { onGameStart = online,
                    onGameEnd = offline })
  
  autolootButton = modules.client_topmenu.addRightGameToggleButton('autolootButton', 
    tr('Auto Loot') .. ' (Ctrl+L)', '/images/topbuttons/autoloot', toggle)
  autolootButton:setOn(false)
  
  autolootWindow = g_ui.loadUI('autoloot', rootWidget)
  autolootWindow:hide()
  
  g_keyboard.bindKeyDown('Ctrl+L', toggle)
  
  ProtocolGame.registerExtendedOpcode(200, onExtendedOpcode)
  
  if g_game.isOnline() then
    online()
  end
end

function onExtendedOpcode(protocol, opcode, buffer)
  if opcode == 200 then
    -- Bank balance update
    local balance = tonumber(buffer) or 0
    
    if autolootWindow and autolootWindow:isVisible() then
      local bankLabel = autolootWindow:recursiveGetChildById('bankBalanceLabel')
      if bankLabel then
        -- Format with thousand separators
        local formatted = tostring(balance):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        bankLabel:setText(string.format('%s gold', formatted))
      end
    end
  end
end

function terminate()
  disconnect(g_game, { onGameStart = online,
                        onGameEnd = offline })
  
  ProtocolGame.unregisterExtendedOpcode(200)
  
  g_keyboard.unbindKeyDown('Ctrl+L')
  
  if autolootWindow then
    autolootWindow:destroy()
  end
  
  if autolootButton then
    autolootButton:destroy()
  end
end

function online()
  if autolootWindow then
    -- Initialize with default mode
    setMode(1)
    -- Request current status from server
    scheduleEvent(loadStatus, 1000)
    -- Request bank balance from server
    requestBankBalance()
  end
end

function requestBankBalance()
  if not g_game.isOnline() then
    return
  end
  
  local protocolGame = g_game.getProtocolGame()
  if protocolGame then
    protocolGame:sendExtendedOpcode(200, "request")
  end
  
  -- Request every 3 seconds
  scheduleEvent(requestBankBalance, 3000)
end

function offline()
  hide()
end

function toggle()
  if autolootButton:isOn() then
    hide()
  else
    show()
  end
end

function show()
  autolootWindow:show()
  autolootWindow:raise()
  autolootWindow:focus()
  autolootButton:setOn(true)
  -- Request current balance immediately
  requestBankBalance()
end

function hide()
  autolootWindow:hide()
  autolootButton:setOn(false)
end

function setMode(mode)
  currentMode = mode
  g_game.talk("!autoloot mode," .. mode)
  
  -- Update UI - highlight active mode
  for i = 1, 4 do
    local modeBtn = autolootWindow:recursiveGetChildById('modeButton' .. i)
    if modeBtn then
      if i == mode then
        modeBtn:setOn(true)
      else
        modeBtn:setOn(false)
      end
    end
  end
  
  local modeNames = {
    [1] = "All except food",
    [2] = "All items + food", 
    [3] = "Only food",
    [4] = "Disabled"
  }
  
  modules.game_textmessage.displayGameMessage("Autoloot mode: " .. modeNames[mode])
end

function toggleBlacklist()
  blacklistEnabled = not blacklistEnabled
  
  -- Send to server
  g_game.talk("!autoloot blacklist_toggle," .. (blacklistEnabled and "1" or "0"))
  
  local blacklistBtn = autolootWindow:recursiveGetChildById('blacklistToggle')
  if blacklistBtn then
    blacklistBtn:setChecked(blacklistEnabled)
    blacklistBtn:setText(blacklistEnabled and 'ON' or 'OFF')
    blacklistBtn:setColor(blacklistEnabled and '#2ecc71' or '#95a5a6')
  end
  
  local inputSection = autolootWindow:recursiveGetChildById('inputSection')
  if inputSection then
    inputSection:setEnabled(blacklistEnabled)
    inputSection:setOpacity(blacklistEnabled and 1.0 or 0.6)
  end
  
  local itemsPanel = autolootWindow:recursiveGetChildById('blacklistItemsPanel')
  if itemsPanel then
    itemsPanel:setEnabled(blacklistEnabled)
    itemsPanel:setOpacity(blacklistEnabled and 1.0 or 0.6)
  end
  
  modules.game_textmessage.displayGameMessage(
    blacklistEnabled and "Blacklist enabled" or "Blacklist disabled"
  )
end

function addToBlacklist()
  local itemInput = autolootWindow:recursiveGetChildById('blacklistInput')
  if not itemInput then return end
  
  local itemName = itemInput:getText()
  if itemName == "" then
    modules.game_textmessage.displayGameMessage("Enter item name or ID")
    return
  end
  
  -- Auto-enable blacklist if first item
  if #blacklistItems == 0 and not blacklistEnabled then
    blacklistEnabled = true
    g_game.talk("!autoloot blacklist_toggle,1")
    
    local blacklistBtn = autolootWindow:recursiveGetChildById('blacklistToggle')
    if blacklistBtn then
      blacklistBtn:setChecked(true)
      blacklistBtn:setText('ON')
      blacklistBtn:setColor('#2ecc71')
    end
    
    local inputSection = autolootWindow:recursiveGetChildById('inputSection')
    if inputSection then
      inputSection:setEnabled(true)
      inputSection:setOpacity(1.0)
    end
    
    local itemsPanel = autolootWindow:recursiveGetChildById('blacklistItemsPanel')
    if itemsPanel then
      itemsPanel:setEnabled(true)
      itemsPanel:setOpacity(1.0)
    end
  end
  
  -- Send to server immediately
  g_game.talk("!autoloot blacklist_add," .. itemName)
  
  -- Add to local list
  table.insert(blacklistItems, itemName)
  
  -- Update UI list
  updateBlacklistDisplay()
  
  -- Clear input
  itemInput:setText("")
  
  modules.game_textmessage.displayGameMessage("Added to blacklist: " .. itemName)
end

function removeFromBlacklist(index)
  if blacklistItems[index] then
    local itemName = blacklistItems[index]
    
    -- Send to server immediately
    g_game.talk("!autoloot blacklist_remove," .. itemName)
    
    table.remove(blacklistItems, index)
    updateBlacklistDisplay()
    modules.game_textmessage.displayGameMessage("Removed from blacklist: " .. itemName)
  end
end

function updateBlacklistDisplay()
  local listWidget = autolootWindow:recursiveGetChildById('blacklistItemsList')
  if not listWidget then return end
  
  listWidget:destroyChildren()
  
  for i, itemName in ipairs(blacklistItems) do
    local itemLabel = g_ui.createWidget('BlacklistItem', listWidget)
    itemLabel:getChildById('itemName'):setText(itemName)
    itemLabel:getChildById('removeBtn').onClick = function() removeFromBlacklist(i) end
  end
end

function loadStatus()
  -- Request current status from server
  g_game.talk("!autoloot status")
end

function clearBlacklist()
  -- Clear on server
  g_game.talk("!autoloot blacklist_clear")
  
  -- Clear local list
  blacklistItems = {}
  updateBlacklistDisplay()
  modules.game_textmessage.displayGameMessage("Blacklist cleared")
end

function deposit()
  local okCallback = function(amount)
    if amount and amount ~= "" then
      g_game.talk("!deposit " .. amount)
    end
  end
  
  local inputBox = UIInputBox.create('Deposit Gold', okCallback)
  inputBox:addLabel('Enter amount to deposit (or "all"):')
  inputBox:addLineEdit(nil, '', 20)
  inputBox:display()
end

function withdraw()
  local okCallback = function(amount)
    if amount and amount ~= "" then
      g_game.talk("!withdraw " .. amount)
    end
  end
  
  local inputBox = UIInputBox.create('Withdraw Gold', okCallback)
  inputBox:addLabel('Enter amount to withdraw:')
  inputBox:addLineEdit(nil, '', 20)
  inputBox:display()
end

function transfer()
  local okCallback = function(text)
    if text and text ~= "" then
      g_game.talk("!transfer " .. text)
    end
  end
  
  local inputBox = UIInputBox.create('Transfer Gold', okCallback)
  inputBox:addLabel('Enter: player name, amount')
  inputBox:addLabel('Example: John Doe, 1000')
  inputBox:addLineEdit(nil, '', 50)
  inputBox:display()
end
