-- OTB Loader for OTClient
-- Maps Client ID to Server ID

local OtbLoader = {}

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

function OtbLoader.load(filename)
    if not g_resources.fileExists(filename) then
        g_logger.error("OTB file not found: " .. filename)
        return nil
    end

    local fileContent = g_resources.readFileContents(filename)
    local len = #fileContent
    local pos = 1

    -- Signature (4 bytes)
    local signature, pos = getU32(fileContent, pos)
    if signature ~= 0 then
        g_logger.error("Invalid OTB signature")
        return nil
    end

    -- Recursive Node Parser
    -- Markers: START=0xFE, END=0xFF, ESCAPE=0xFD
    local function parseNode()
        if pos > len then return nil end
        
        local startByte = string.byte(fileContent, pos)
        pos = pos + 1
        if startByte ~= 0xFE then
            -- Only log error if we are not at EOF (which shouldn't happen if logic is correct)
            -- But sometimes trailing bytes exist.
            -- g_logger.error("Expected NODE_START (FE) at " .. (pos-1) .. ", got " .. string.format("%02X", startByte))
            return nil
        end

        local node = { dataBuffer = {}, children = {} }
        
        while pos <= len do
            local byte = string.byte(fileContent, pos)
            
            if byte == 0xFE then -- Start of child node
                local child = parseNode()
                if not child then return nil end
                table.insert(node.children, child)
            elseif byte == 0xFF then -- End of current node
                pos = pos + 1
                node.data = table.concat(node.dataBuffer)
                return node
            elseif byte == 0xFD then -- Escape
                pos = pos + 1
                if pos > len then break end
                local escapedByte = string.byte(fileContent, pos)
                pos = pos + 1
                table.insert(node.dataBuffer, string.char(escapedByte))
            else -- Data
                pos = pos + 1
                table.insert(node.dataBuffer, string.char(byte))
            end
        end
        return nil -- EOF before NODE_END
    end

    local root = parseNode()
    if not root then
        g_logger.error("Failed to parse Root Node")
        return nil
    end

    -- Process Root Data
    local data = root.data
    local dPos = 1
    local dLen = #data
    
    -- Skip 1 byte (0) - Root Node usually starts with a 0 byte in data?
    -- Based on hex dump: FE 00 -> 00. So data starts with 00.
    dPos = dPos + 1
    
    -- Root Signature
    if dPos + 4 <= dLen then
        local rootSig, newPos = getU32(data, dPos)
        dPos = newPos
        if rootSig ~= 0 then
            g_logger.warning("Invalid Root Signature: " .. rootSig)
        end
    end
    
    -- Version Attribute
    if dPos <= dLen then
        local attr, newPos = getU8(data, dPos)
        dPos = newPos
        if attr == 0x01 then
            local attrLen, newPos = getU16(data, dPos)
            dPos = newPos
            dPos = dPos + attrLen -- Skip version info
        end
    end

    local clientToServer = {}
    local count = 0

    -- Process Children (ItemTypes)
    for _, child in ipairs(root.children) do
        local cData = child.data
        local cPos = 1
        local cLen = #cData
        
        -- ItemType Data
        if cLen >= 5 then -- Category(1) + Flags(4)
            local category, newPos = getU8(cData, cPos)
            cPos = newPos
            local flags, newPos = getU32(cData, cPos)
            cPos = newPos
            
            local serverId = 0
            local clientId = 0
            
            while cPos <= cLen do
                local attrByte, newPos = getU8(cData, cPos)
                cPos = newPos
                
                if attrByte == 0 or attrByte == 0xFF then
                    break
                end
                
                if cPos + 2 > cLen then break end
                local attrLen, newPos = getU16(cData, cPos)
                cPos = newPos
                
                if cPos + attrLen - 1 > cLen then break end
                
                if attrByte == 16 then -- ServerId
                    serverId, _ = getU16(cData, cPos)
                elseif attrByte == 17 then -- ClientId
                    clientId, _ = getU16(cData, cPos)
                end
                
                cPos = cPos + attrLen
            end
            
            if serverId > 0 and clientId > 0 then
                -- Handle 30000 offset logic
                if serverId > 30000 and serverId < 30100 then
                    serverId = serverId - 30000
                end
                
                clientToServer[clientId] = serverId
                count = count + 1
            end
        end
    end
    
    g_logger.info("OTB Loader: Mapped " .. count .. " items.")

    return clientToServer
end

return OtbLoader
