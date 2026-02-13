dofile('itemsXML.lua')


-- Wywołanie funkcji testowych
-- Przykład: Załóżmy, że ID serwera dla "Z-Sword" to 12814
-- Definiujemy nazwę przedmiotu

function CreateStats()
    local createStats = {
        loadedVersionItems = 0;
        ownParser = false;

        _loadClientVersionItems = nil;
        _checkLootTextMessage = nil;

        init = function(self)
            self._loadClientVersionItems = function() self:loadClientVersionItems() end
            self._checkLootTextMessage = function(messageMode, message) self:checkLootTextMessage(messageMode, message) end

            connect(g_game, { onClientVersionChange = self._loadClientVersionItems })
            connect(g_game, { onTextMessage = self._checkLootTextMessage })

            if (self.loadedVersionItems == 0 and g_game.getClientVersion() ~= 0) or (g_game.getClientVersion() ~= 0 and self.loadedVersionItems ~= g_game.getClientVersion()) then
                self:loadClientVersionItems()
            end
        end;

        terminate = function(self)
            disconnect(g_game, { onClientVersionChange = self._loadClientVersionItems })
            disconnect(g_game, { onTextMessage = self._checkLootTextMessage })
        end;

        -- Load items

        loadClientVersionItems = function(self)
            print("Rozpoczęcie ładowania przedmiotów wersji klienta")
            local version = g_game.getClientVersion()
            print("Aktualna wersja klienta: ", version)

            if version ~= self.loadedVersionItems then
                -- OTClient-Redemption nie ma findItemTypeByPluralName
                -- Musimy używać własnego parsera XML
                print("Używam własnego parsera XML dla loot stats")
                
                -- NAJPIERW próbuj załadować items.xml z głównej lokalizacji (z serwera)
                local xmlPath = '/mods/loot_stats/ui/items.xml'
                
                -- Sprawdź czy plik XML dla tej wersji istnieje
                if not g_resources.fileExists(xmlPath) then
                    print("Brak głównego items.xml, próbuję z items_versions/" .. version)
                    xmlPath = '/mods/loot_stats/items_versions/' .. version .. '/items.xml'
                    
                    if not g_resources.fileExists(xmlPath) then
                        print("Brak pliku XML dla wersji " .. version .. ", używam wersji 860 jako fallback")
                        xmlPath = '/mods/loot_stats/items_versions/860/items.xml'
                    end
                end
                
                if g_resources.fileExists(xmlPath) then
                    self.ownParser = ItemsXML()
                    self.ownParser:parseItemsXML(xmlPath)
                    print("Plik XML załadowany pomyślnie: " .. xmlPath)
                else
                    print("Błąd: Brak pliku XML nawet dla fallbacku (860)")
                    return
                end

                self.loadedVersionItems = version
            end
            print("Zakończenie ładowania przedmiotów wersji klienta")
           
            
        end;

        -- Convert plural to singular

        convertPluralToSingular = function(self, searchWord)
            -- OTClient-Redemption nie ma findItemTypeByPluralName
            -- Zawsze używamy własnego parsera
            if self.ownParser then
                return self.ownParser:convertPluralToSingular(searchWord)
            else
                print("Błąd: Parser XML nie został załadowany")
                return false
            end
        end;

        -- Find item ID by name

        findItemIdByName = function(self, itemName)
            if not items or type(items) ~= "table" then
                return nil
            end
            
            local lowerName = itemName:lower()
            
            -- Hardcoded coin mappings (bo items.xml nie ma plural dla coinów)
            if lowerName == "gold coin" or lowerName == "gold coins" then
                return 2148
            elseif lowerName == "platinum coin" or lowerName == "platinum coins" then
                return 2152
            elseif lowerName == "crystal coin" or lowerName == "crystal coins" then
                return 2160
            end
            
            for id, itemData in pairs(items) do
                if itemData.name and itemData.name:lower() == lowerName then
                    return id
                end
            end
            
            return nil
        end;

        -- Parse message logs

        returnPluralNameFromLoot = function(lootMonsterName, itemWord)
            for a,b in pairs(store.lootStatsTable[lootMonsterName].loot) do
                if b.plural == itemWord then
                    return a
                end
            end

            return false
        end;

        checkLootTextMessage = function(self, messageMode, message)
           
            if self.loadedVersionItems == 0 then
                return
            end

            local fromLootValue, toLootValue = string.find(message, 'Loot of ')
            if toLootValue then
                -- Return monster
                local lootMonsterName = string.sub(message, toLootValue + 1, string.find(message, ':') - 1)
                local isAFromLootValue, isAToLootValue = string.find(lootMonsterName, 'a ')
                if isAToLootValue then
                    lootMonsterName = string.sub(lootMonsterName, isAToLootValue + 1, string.len(lootMonsterName))
                end

                local isANFromLootValue, isANToLootValue = string.find(lootMonsterName, 'an ')
                if isANToLootValue then
                    lootMonsterName = string.sub(lootMonsterName, isANToLootValue + 1, string.len(lootMonsterName))
                end

                -- If no monster then add monster to table
                if not store.lootStatsTable[lootMonsterName] then
                    store.lootStatsTable[lootMonsterName] = { loot = {}, count = 0 }
                end

                -- Update monster kill count information
                store.lootStatsTable[lootMonsterName].count = store.lootStatsTable[lootMonsterName].count + 1

                -- Return Loot
                local lootString = string.sub(message, string.find(message, ': ') + 2, string.len(message))

                -- If dot at the ned of sentence (OTS only), delete it
                if not store:getIgnoreLastSignWhenDot() then
                    if string.sub(lootString, string.len(lootString)) == '.' then
                        lootString = string.sub(lootString, 0, string.len(lootString) - 1)
                    end
                end

                local lootToScreen = {}
                for word in string.gmatch(lootString, '([^,]+)') do
                    -- Delete first space
                    if string.sub(word, 0, 1) == ' ' then
                        word = string.sub(word, 2, string.len(word))
                    end

                    -- NAJPIERW sprawdź czy to format {ID|...} z serwera
                    local serverItemId = string.match(word, '^{(%d+)|')
                    local serverItemName = string.match(word, '{%d+|(.+)}')
                    
                    if serverItemId and serverItemName then
                        -- Serwer wysłał w formacie {ID|nazwa} - użyj TEGO ID!
                        
                        -- Usuń 'a ' / 'an ' z nazwy
                        local cleanName = serverItemName
                        if cleanName:sub(1, 2) == 'a ' then
                            cleanName = cleanName:sub(3)
                        elseif cleanName:sub(1, 3) == 'an ' then
                            cleanName = cleanName:sub(4)
                        end
                        
                        -- Sprawdź czy nazwa zaczyna się od liczby
                        local itemCount = 1
                        local numMatch = cleanName:match('^(%d+)%s+')
                        if numMatch then
                            itemCount = tonumber(numMatch)
                            cleanName = cleanName:gsub('^%d+%s+', '')
                        end
                        
                        -- Zapisz do store używając klucza z ID
                        local storeKey = "{" .. serverItemId .. "|" .. cleanName .. "}"
                        if not store.lootStatsTable[lootMonsterName].loot[storeKey] then
                            store.lootStatsTable[lootMonsterName].loot[storeKey] = {}
                            store.lootStatsTable[lootMonsterName].loot[storeKey].count = 0
                        end
                        store.lootStatsTable[lootMonsterName].loot[storeKey].count = store.lootStatsTable[lootMonsterName].loot[storeKey].count + itemCount
                        
                        -- Dodaj do lootToScreen używając ID z serwera
                        local screenKey = "{" .. serverItemId .. "|" .. itemCount .. " " .. cleanName .. "}"
                        if not lootToScreen[screenKey] then
                            lootToScreen[screenKey] = {}
                        end
                        lootToScreen[screenKey].count = itemCount
                        
                        -- Przejdź do następnego itemu
                        goto continue
                    end

                    -- Stary kod dla formatów bez {ID|...}
                    
                    -- Delete 'a ' / 'an '
                    local isAToLootValue, isAFromLootValue = string.find(word, 'a ')
                    if isAFromLootValue then
                        word = string.sub(word, isAFromLootValue + 1, string.len(word))
                    end

                    local isANToLootValue, isANFromLootValue = string.find(word, 'an ')
                    if isANFromLootValue then
                        word = string.sub(word, isANFromLootValue + 1, string.len(word))
                    end

                    -- Check is first sign is number
                    if type(tonumber(string.sub(word, 0, 1))) == 'number' then
                        local itemCount = tonumber(string.match(word, "%d+"))
                        local delFN, delLN = string.find(word, itemCount)
                        local itemWord = string.sub(word, delLN + 2)
                        local isPluralNameInLoot = self.returnPluralNameFromLoot(lootMonsterName, itemWord)

                        if isPluralNameInLoot then
                            if not store.lootStatsTable[lootMonsterName].loot[isPluralNameInLoot] then
                                store.lootStatsTable[lootMonsterName].loot[isPluralNameInLoot] = {}
                                store.lootStatsTable[lootMonsterName].loot[isPluralNameInLoot].count = 0
                            end

                            -- Znajdź ID i stwórz klucz z ID
                            local itemId = self:findItemIdByName(isPluralNameInLoot)
                            local screenKey = itemId and ("{" .. itemId .. "|" .. itemCount .. " " .. isPluralNameInLoot .. "}") or isPluralNameInLoot
                            
                            if not lootToScreen[screenKey] then
                                lootToScreen[screenKey] = {}
                                lootToScreen[screenKey].count = 0
                            end

                            store.lootStatsTable[lootMonsterName].loot[isPluralNameInLoot].count = store.lootStatsTable[lootMonsterName].loot[isPluralNameInLoot].count + itemCount
                            lootToScreen[screenKey].count = itemCount
                        else
                            local pluralNameToSingular = self:convertPluralToSingular(itemWord)
                            if pluralNameToSingular then
                                if not store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular] then
                                    store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular] = {}
                                    store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular].count = 0
                                end

                                if not store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular].plural then
                                    store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular].plural = itemWord
                                end

                                -- Znajdź ID i stwórz klucz z ID
                                local itemId = self:findItemIdByName(pluralNameToSingular)
                                local screenKey = itemId and ("{" .. itemId .. "|" .. itemCount .. " " .. pluralNameToSingular .. "}") or pluralNameToSingular
                                
                                if not lootToScreen[screenKey] then
                                    lootToScreen[screenKey] = {}
                                    lootToScreen[screenKey].count = 0
                                end

                                store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular].count = store.lootStatsTable[lootMonsterName].loot[pluralNameToSingular].count + itemCount
                                lootToScreen[screenKey].count = itemCount
                            else
                                -- Nie znaleziono ani plural ani singular - użyj oryginalnego word
                                if not store.lootStatsTable[lootMonsterName].loot[word] then
                                    store.lootStatsTable[lootMonsterName].loot[word] = {}
                                    store.lootStatsTable[lootMonsterName].loot[word].count = 0
                                end

                                -- Spróbuj znaleźć ID dla całego word (może zawierać count)
                                local itemId = self:findItemIdByName(word)
                                local screenKey = itemId and ("{" .. itemId .. "|" .. word .. "}") or word
                                
                                if not lootToScreen[screenKey] then
                                    lootToScreen[screenKey] = {}
                                    lootToScreen[screenKey].count = 0
                                end

                                store.lootStatsTable[lootMonsterName].loot[word].count = store.lootStatsTable[lootMonsterName].loot[word].count + 1
                                lootToScreen[screenKey].count = 1
                            end
                        end
                    else
                        -- Pojedynczy item (bez liczby na początku) - traktuj jako count = 1
                        local itemNameToStore = word
                        
                        if not store.lootStatsTable[lootMonsterName].loot[itemNameToStore] then
                            store.lootStatsTable[lootMonsterName].loot[itemNameToStore] = {}
                            store.lootStatsTable[lootMonsterName].loot[itemNameToStore].count = 0
                        end

                        -- Znajdź ID i stwórz klucz z ID (dodaj "1 " na początku nazwy)
                        local itemId = self:findItemIdByName(itemNameToStore)
                        local screenKey = itemId and ("{" .. itemId .. "|1 " .. itemNameToStore .. "}") or itemNameToStore
                        
                        if not lootToScreen[screenKey] then
                            lootToScreen[screenKey] = {}
                            lootToScreen[screenKey].count = 0
                        end

                        -- Pojedynczy item ma count = 1
                        store.lootStatsTable[lootMonsterName].loot[itemNameToStore].count = store.lootStatsTable[lootMonsterName].loot[itemNameToStore].count + 1
                        lootToScreen[screenKey].count = 1
                    end
                    
                    ::continue::
                end

                store:addLootLog(lootToScreen)
                lootToScreen = {}
            end

            store:refreshLootStatsTable()
        
       
    end;
    }
   

    return createStats
end
