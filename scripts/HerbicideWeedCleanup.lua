HerbicideWeedCleanup = {}
HerbicideWeedCleanup.modDirectory = g_currentModDirectory
HerbicideWeedCleanup.modName = g_currentModName
HerbicideWeedCleanup.SWEEP_INTERVAL = 2000
HerbicideWeedCleanup.ACTIVE_GRACE_PERIOD = 15000
HerbicideWeedCleanup.AREA_MARGIN = 2

source(HerbicideWeedCleanup.modDirectory .. "scripts/HerbicideWeedCleanupSettings.lua")

HerbicideWeedCleanup.settings = HerbicideWeedCleanupSettings.new(HerbicideWeedCleanup)
HerbicideWeedCleanup.settings:install()

function HerbicideWeedCleanup:loadMap()
    self.weedModifier = nil
    self.witheredWeedFilters = nil
    self.sweepTimer = 0
    self.clock = 0
    self.activeArea = nil
    self.lastPeriod = nil

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

function HerbicideWeedCleanup:registerHerbicideActivity(ax, az, bx, bz, cx, cz)
    local dx, dz = bx + cx - ax, bz + cz - az
    local margin = HerbicideWeedCleanup.AREA_MARGIN
    local minX = math.min(ax, bx, cx, dx) - margin
    local maxX = math.max(ax, bx, cx, dx) + margin
    local minZ = math.min(az, bz, cz, dz) - margin
    local maxZ = math.max(az, bz, cz, dz) + margin

    if self.activeArea == nil then
        self.activeArea = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
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
        local environment = g_currentMission ~= nil and g_currentMission.environment or nil
        local currentPeriod = environment ~= nil and environment.currentPeriod or nil
        if currentPeriod == nil then
            return
        end

        if self.lastPeriod == nil then
            self.lastPeriod = currentPeriod
            return
        end

        if currentPeriod == self.lastPeriod then
            return
        end

        self.lastPeriod = currentPeriod
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
