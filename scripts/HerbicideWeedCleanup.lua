HerbicideWeedCleanup = {}
HerbicideWeedCleanup.modDirectory = g_currentModDirectory
HerbicideWeedCleanup.modName = g_currentModName
HerbicideWeedCleanup.SWEEP_INTERVAL = 2000
HerbicideWeedCleanup.ACTIVE_GRACE_PERIOD = 15000
HerbicideWeedCleanup.AREA_MARGIN = 2
HerbicideWeedCleanup.FILE_NAME = "herbicideWeedCleanup.xml"

source(HerbicideWeedCleanup.modDirectory .. "scripts/HerbicideWeedCleanupSettings.lua")

HerbicideWeedCleanup.settings = HerbicideWeedCleanupSettings.new(HerbicideWeedCleanup)
HerbicideWeedCleanup.settings:install()

function HerbicideWeedCleanup:loadMap()
    self.weedModifier = nil
    self.witheredWeedFilters = nil
    self.sweepTimer = 0
    self.clock = 0
    self.activeArea = nil

    self.settings:install()
    self.settings:loadSettings()
    self.settings:initializeSettingsOption()
end

function HerbicideWeedCleanup:deleteMap()
    self.weedModifier = nil
    self.witheredWeedFilters = nil
end

function HerbicideWeedCleanup:getWeedModifier()
    if self.weedModifier == nil then
        local weedSystem = g_currentMission ~= nil and g_currentMission.weedSystem or nil
        if weedSystem == nil or not weedSystem:getMapHasWeed() then
            return nil
        end

        local replacementData = weedSystem:getHerbicideReplacements()
        if replacementData == nil or replacementData.weed == nil then
            return nil
        end

        local witheredStates = {}
        for _, targetState in pairs(replacementData.weed.replacements) do
            if targetState > 0 then
                witheredStates[targetState] = true
            end
        end

        if next(witheredStates) == nil then
            return nil
        end

        local weedMapId, weedFirstChannel, weedNumChannels = weedSystem:getDensityMapData()

        self.weedModifier = DensityMapModifier.new(weedMapId, weedFirstChannel, weedNumChannels, g_terrainNode)

        self.witheredWeedFilters = {}
        for state, _ in pairs(witheredStates) do
            local filter = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels)
            filter:setValueCompareParams(DensityValueCompareType.EQUAL, state)
            table.insert(self.witheredWeedFilters, filter)
        end
    end

    return self.weedModifier
end

function HerbicideWeedCleanup:getCurrentPeriod()
    local environment = g_currentMission ~= nil and g_currentMission.environment or nil
    return environment ~= nil and environment.currentPeriod or nil
end

function HerbicideWeedCleanup:registerHerbicideActivity(ax, az, bx, bz, cx, cz)
    local dx, dz = bx + cx - ax, bz + cz - az
    local margin = HerbicideWeedCleanup.AREA_MARGIN
    local minX = math.min(ax, bx, cx, dx) - margin
    local maxX = math.max(ax, bx, cx, dx) + margin
    local minZ = math.min(az, bz, cz, dz) - margin
    local maxZ = math.max(az, bz, cz, dz) + margin

    if self.activeArea == nil then
        self.activeArea = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, period = self:getCurrentPeriod() }
    else
        local a = self.activeArea
        a.minX = math.min(a.minX, minX)
        a.maxX = math.max(a.maxX, maxX)
        a.minZ = math.min(a.minZ, minZ)
        a.maxZ = math.max(a.maxZ, maxZ)
    end
    self.activeArea.lastSprayAt = self.clock
end

function HerbicideWeedCleanup:sweepActiveArea()
    local weedModifier = self:getWeedModifier()
    if weedModifier == nil then
        return
    end

    local a = self.activeArea
    weedModifier:setParallelogramWorldCoords(a.minX, a.minZ, a.maxX, a.minZ, a.minX, a.maxZ, DensityCoordType.POINT_POINT_POINT)

    for _, filter in ipairs(self.witheredWeedFilters) do
        weedModifier:executeSet(0, filter)
    end
end

function HerbicideWeedCleanup:update(dt)
    self.clock = (self.clock or 0) + dt

    if self.activeArea == nil then
        return
    end

    if self.settings.mode == HerbicideWeedCleanupSettings.MODE_DELAYED then
        local currentPeriod = self:getCurrentPeriod()
        if currentPeriod == nil then
            return
        end

        if self.activeArea.period == nil then
            self.activeArea.period = currentPeriod
            return
        end

        if currentPeriod == self.activeArea.period then
            return
        end

        self:sweepActiveArea()
        self.activeArea = nil
        return
    end

    self.sweepTimer = (self.sweepTimer or 0) + dt
    if self.sweepTimer < HerbicideWeedCleanup.SWEEP_INTERVAL then
        return
    end
    self.sweepTimer = 0

    self:sweepActiveArea()

    if self.clock - self.activeArea.lastSprayAt > HerbicideWeedCleanup.ACTIVE_GRACE_PERIOD then
        self.activeArea = nil
    end
end

function HerbicideWeedCleanup:getSavegameFilePath()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if savegameDir == nil then
        return nil
    end

    return savegameDir .. "/" .. HerbicideWeedCleanup.FILE_NAME
end

function HerbicideWeedCleanup:loadFromSavegame()
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    local path = self:getSavegameFilePath()
    if path == nil or not fileExists(path) then
        return
    end

    local xmlFile = XMLFile.load("herbicideWeedCleanupXML", path)
    if xmlFile == nil then
        return
    end

    local key = "herbicideWeedCleanup.pendingArea"
    local minX = xmlFile:getFloat(key .. "#minX")
    local maxX = xmlFile:getFloat(key .. "#maxX")
    local minZ = xmlFile:getFloat(key .. "#minZ")
    local maxZ = xmlFile:getFloat(key .. "#maxZ")
    if minX ~= nil and maxX ~= nil and minZ ~= nil and maxZ ~= nil then
        self.activeArea = {
            minX = minX,
            maxX = maxX,
            minZ = minZ,
            maxZ = maxZ,
            period = xmlFile:getInt(key .. "#period"),
            lastSprayAt = self.clock or 0
        }
    end

    xmlFile:delete()
end

function HerbicideWeedCleanup:saveToSavegame()
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    local path = self:getSavegameFilePath()
    if path == nil then
        return
    end

    local xmlFile = XMLFile.create("herbicideWeedCleanupXML", path, "herbicideWeedCleanup")
    if xmlFile == nil then
        Logging.error("%s: could not create %s", HerbicideWeedCleanup.modName, path)
        return
    end

    local a = self.activeArea
    if a ~= nil then
        local key = "herbicideWeedCleanup.pendingArea"
        xmlFile:setFloat(key .. "#minX", a.minX)
        xmlFile:setFloat(key .. "#maxX", a.maxX)
        xmlFile:setFloat(key .. "#minZ", a.minZ)
        xmlFile:setFloat(key .. "#maxZ", a.maxZ)
        if a.period ~= nil then
            xmlFile:setInt(key .. "#period", a.period)
        end
    end

    xmlFile:save()
    xmlFile:delete()
end

function HerbicideWeedCleanup.updateSprayArea(startWorldX, superFunc, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, sprayType, sprayAmount)
    local area, totalArea = superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, sprayType, sprayAmount)

    local sprayTypeDesc = g_sprayTypeManager ~= nil and g_sprayTypeManager:getSprayTypeByIndex(sprayType) or nil
    if sprayTypeDesc ~= nil and sprayTypeDesc.isHerbicide then
        HerbicideWeedCleanup:registerHerbicideActivity(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    end

    return area, totalArea
end

FSDensityMapUtil.updateSprayArea = Utils.overwrittenFunction(FSDensityMapUtil.updateSprayArea, HerbicideWeedCleanup.updateSprayArea)

addModEventListener(HerbicideWeedCleanup)

FSBaseMission.loadMapFinished = Utils.appendedFunction(FSBaseMission.loadMapFinished, function()
    HerbicideWeedCleanup:loadFromSavegame()
end)

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function()
    HerbicideWeedCleanup:saveToSavegame()
end)
