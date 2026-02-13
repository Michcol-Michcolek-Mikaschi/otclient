

function ShowLootOnScreen()
    local showLootOnScreen = {
        mainScreenTab = {};
        cacheLastTime = { t = 0, i = 1 };
        lootIconOnScreen = {};

        init = function(self)
            self:connectStoreWithElements()
        end;

        terminate = function(self)
            self:disconnectStoreFromElements()
            self:destroy()
        end;

        add = function(self, tab)
            for i = 1, store:getAmountLootOnScreen() do
                self.mainScreenTab[i] = {}
                if i + 1 <= store:getAmountLootOnScreen() then
                    self.mainScreenTab[i] = self.mainScreenTab[i + 1]
                else
                    if tab ~= nil then
                        self.mainScreenTab[i].loot = tab
                        if g_clock.millis() == self.cacheLastTime.t then
                            self.mainScreenTab[i].id = g_clock.millis() * 100 + self.cacheLastTime.i
                            self.cacheLastTime.i = self.cacheLastTime.i + 1
                            self:scheduleDisappear(self.mainScreenTab[i].id)
                        else
                            self.mainScreenTab[i].id = g_clock.millis()
                            self.cacheLastTime.t = g_clock.millis()
                            self.cacheLastTime.i = 1
                            self:scheduleDisappear(self.mainScreenTab[i].id)
                        end
                    else
                        self.mainScreenTab[i] = nil
                    end
                end
            end

            if tab == nil and table.size(self.mainScreenTab) then
                self.mainScreenTab[#self.mainScreenTab] = nil
            end

            self:refresh()
        end;

        scheduleDisappear = function(self, id)
            scheduleEvent(function()
                for a,b in pairs(self.mainScreenTab) do
                    if self.mainScreenTab[a].id == id then
                        self.mainScreenTab[a] = nil
                        self:add(nil)
                        self:refresh()
                        break
                    end
                end
            end, store:getDelayTimeLootOnScreen())
        end;

        refresh = function(self)
            self:destroy()
        
            local screenWidth = self:getMapPanel():getWidth()
            local lootIconsWidth = 32 * table.size(self.mainScreenTab)
            local actualX = (screenWidth - lootIconsWidth) / 2
            local actualY = 0

            if self:getTopMenu():isVisible() then
                actualY = self:getTopMenu():getHeight()
            end
            
            for a, b in pairs(self.mainScreenTab) do
                if actualY <= self:getMapPanel():getHeight() - 32 then
                    for c, d in pairs(b.loot) do
                        if actualX <= self:getMapPanel():getWidth() - 32 then
                            local itemId = nil
                            local itemName = c
                            local itemCount = d.count or 1
                            
                            -- Parsuj format {ID|nazwa}
                            local parsedId = string.match(c, '{(%d+)|')
                            local parsedName = string.match(c, '|([^}]+)}')
                            
                            -- Obsłuż błędny format
                            if not parsedName and string.find(c, '}') then
                                parsedName = string.gsub(c, '}', '')
                                itemName = parsedName
                            end
                            
                            if parsedId and parsedName then
                                itemId = tonumber(parsedId)
                                itemName = parsedName
                                
                                -- Wyciągnij liczbę z nazwy
                                local numInName = string.match(itemName, '^(%d+)%s+')
                                if numInName then
                                    itemCount = tonumber(numInName)
                                    itemName = string.gsub(itemName, '^%d+%s+', '')
                                end
                            end
                            
                            -- Twórz widget TYLKO gdy itemId jest poprawne
                            if itemId then
                                self.lootIconOnScreen[c..a] = g_ui.createWidget("LootIcon", self:getMapPanel())
                                local widget = self.lootIconOnScreen[c .. a]
                                
                                widget:setItemId(itemId)
                                
                                -- Ustaw count PRZED virtual i pozycją
                                if itemCount > 1 then
                                    widget:setItemCount(itemCount)
                                end
            
                                widget:setVirtual(true)
                                widget:setX(actualX + self:getMapPanel():getX())
                                widget:setY(actualY)
                                actualX = actualX + 32
                            end
                        end
                    end
                end
        
                actualX = 0
                actualY = actualY + 32
            end
        end;

        destroy = function(self)
            for a,b in pairs(self.lootIconOnScreen) do
                self.lootIconOnScreen[a]:destroy()
                self.lootIconOnScreen[a] = nil
            end
        end;

        getMapPanel = function(self)
            return modules.game_interface.getMapPanel()
        end;

        getTopMenu = function(self)
            return modules.client_topmenu.getTopMenu()
        end;

        connectStoreWithElements = function(self)
            store.onAddLootLog.showLootOnScreen = function(lootData) self:addLootLog(lootData) end
        end;

        disconnectStoreFromElements = function(self)
            store.onAddLootLog.showLootOnScreen = nil
        end;

        addLootLog = function(self, lootData)
            if store:getShowLootOnScreen() then
                self:add(lootData)
            end
        end;
    }

    return showLootOnScreen
end
