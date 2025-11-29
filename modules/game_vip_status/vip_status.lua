-- VIP Status System
-- Shows purple name for VIP players
-- Uses extended opcode 202 to receive VIP player list from server

local VIP_OPCODE = 202
local VIP_NAME_COLOR = '#AA00FF'  -- Purple/Violet color for VIP names

local vipPlayers = {}  -- Table of VIP player names (lowercase)
local initialized = false
local creatureConnected = false

function init()
    g_logger.info("[VIP Status] Initializing VIP Status module...")
    
    connect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
    
    ProtocolGame.registerExtendedOpcode(VIP_OPCODE, onExtendedOpcode)
    
    -- Connect to creature events
    if not creatureConnected then
        connect(Creature, {
            onAppear = onCreatureAppear
        })
        creatureConnected = true
    end
    
    if g_game.isOnline() then
        onGameStart()
    end
    
    initialized = true
    g_logger.info("[VIP Status] Module initialized successfully!")
end

function terminate()
    if not initialized then return end
    
    disconnect(g_game, {
        onGameStart = onGameStart,
        onGameEnd = onGameEnd
    })
    
    ProtocolGame.unregisterExtendedOpcode(VIP_OPCODE)
    
    if creatureConnected then
        disconnect(Creature, {
            onAppear = onCreatureAppear
        })
        creatureConnected = false
    end
    
    vipPlayers = {}
    initialized = false
    g_logger.info("[VIP Status] Module terminated.")
end

function onGameStart()
    g_logger.info("[VIP Status] Game started, requesting VIP list...")
    
    -- Request VIP list from server after a short delay
    scheduleEvent(function()
        requestVipList()
    end, 2000)
end

function onGameEnd()
    vipPlayers = {}
end

function requestVipList()
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        g_logger.info("[VIP Status] Sending VIP list request to server...")
        protocolGame:sendExtendedOpcode(VIP_OPCODE, json.encode({
            action = "getVipList",
            data = {}
        }))
    else
        g_logger.warning("[VIP Status] No protocol game available!")
    end
end

function onExtendedOpcode(protocol, opcode, buffer)
    g_logger.info("[VIP Status] Received extended opcode: " .. tostring(opcode))
    
    local status, json_data = pcall(function()
        return json.decode(buffer)
    end)
    
    if not status then
        g_logger.error("[VIP Status] JSON error: " .. tostring(json_data))
        return false
    end
    
    local action = json_data["action"]
    local data = json_data["data"]
    
    if not action then
        g_logger.warning("[VIP Status] No action in received data")
        return false
    end
    
    g_logger.info("[VIP Status] Received action: " .. tostring(action))
    
    if action == "vipList" then
        onVipListReceived(data)
    end
    
    return true
end

function onVipListReceived(data)
    vipPlayers = {}
    
    if data and data.players then
        g_logger.info("[VIP Status] Received VIP players: " .. #data.players)
        for _, name in ipairs(data.players) do
            vipPlayers[name:lower()] = true
            g_logger.info("[VIP Status] VIP Player: " .. name)
        end
    else
        g_logger.info("[VIP Status] No VIP players in list")
    end
    
    -- Update all visible creatures
    updateAllCreatures()
end

function isVipPlayer(name)
    if not name then return false end
    return vipPlayers[name:lower()] == true
end

function updateAllCreatures()
    local player = g_game.getLocalPlayer()
    if not player then return end
    
    -- Update local player first
    updateCreatureVipStatus(player)
    
    -- Update all visible creatures on map
    local gameMapPanel = modules.game_interface.getMapPanel()
    if gameMapPanel then
        local spectators = gameMapPanel:getSpectators()
        if spectators then
            for _, creature in ipairs(spectators) do
                updateCreatureVipStatus(creature)
            end
        end
    end
end

function updateCreatureVipStatus(creature)
    if not creature then return end
    if not creature:isPlayer() then return end
    
    local name = creature:getName()
    if not name or name == "" then return end
    
    if isVipPlayer(name) then
        -- Set purple name color for VIP player
        creature:setNameColor(VIP_NAME_COLOR)
        g_logger.info("[VIP Status] Setting VIP name color for: " .. name)
    else
        -- Clear custom name color for non-VIP
        creature:clearNameColor()
    end
end

function onCreatureAppear(creature)
    if not initialized then return end
    if not creature then return end
    
    scheduleEvent(function()
        -- Check if creature still exists and is valid
        if creature and creature:getId() and creature:getId() > 0 then
            updateCreatureVipStatus(creature)
        end
    end, 500)
end

g_logger.info("[VIP Status] VIP Status module script loaded")
