HerbicideWeedCleanupSettings = {}
HerbicideWeedCleanupSettings.MODE_IMMEDIATE = 1
HerbicideWeedCleanupSettings.MODE_DELAYED = 2

local HerbicideWeedCleanupSettings_mt = Class(HerbicideWeedCleanupSettings)

function HerbicideWeedCleanupSettings.new(owner, customMt)
    local self = setmetatable({}, customMt or HerbicideWeedCleanupSettings_mt)
    self.owner = owner
    self.mode = HerbicideWeedCleanupSettings.MODE_IMMEDIATE
    self.installed = false
    self.settingsInitialized = false
    self.settingsHeader = nil
    self.settingsRow = nil
    self.option = nil
    return self
end

function HerbicideWeedCleanupSettings:install()
    if self.installed then
        return true
    end
    if InGameMenuSettingsFrame == nil or Utils == nil or Utils.appendedFunction == nil then
        return false
    end

    InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
        self:onSettingsFrameOpen()
    end)

    self.installed = true
    return true
end

function HerbicideWeedCleanupSettings:getSaveKey()
    return "gameSettings.herbicideWeedCleanup.cleanupMode#state"
end

function HerbicideWeedCleanupSettings:normalizeMode(mode)
    mode = tonumber(mode) or HerbicideWeedCleanupSettings.MODE_IMMEDIATE
    if mode ~= HerbicideWeedCleanupSettings.MODE_IMMEDIATE and mode ~= HerbicideWeedCleanupSettings.MODE_DELAYED then
        mode = HerbicideWeedCleanupSettings.MODE_IMMEDIATE
    end
    return mode
end

function HerbicideWeedCleanupSettings:loadSettings()
    local mode = self.mode
    if g_savegameXML ~= nil and getXMLInt ~= nil then
        mode = Utils.getNoNil(getXMLInt(g_savegameXML, self:getSaveKey()), mode)
    end
    self.mode = self:normalizeMode(mode)
end

function HerbicideWeedCleanupSettings:saveSettings()
    if g_savegameXML ~= nil and setXMLInt ~= nil then
        setXMLInt(g_savegameXML, self:getSaveKey(), self.mode)
    end
end

function HerbicideWeedCleanupSettings:findElementRecursive(root, predicate)
    if root == nil then
        return nil
    end
    if predicate(root) then
        return root
    end
    if root.elements ~= nil then
        for _, child in ipairs(root.elements) do
            local found = self:findElementRecursive(child, predicate)
            if found ~= nil then
                return found
            end
        end
    end
    return nil
end

function HerbicideWeedCleanupSettings:isMultiTextOptionElement(element)
    return element ~= nil and MultiTextOptionElement ~= nil and element.isa ~= nil and element:isa(MultiTextOptionElement)
end

function HerbicideWeedCleanupSettings:hasMultiTextOption(element)
    return self:findElementRecursive(element, function(child)
        return self:isMultiTextOptionElement(child)
    end) ~= nil
end

function HerbicideWeedCleanupSettings:getGameSettingsLayout()
    if g_inGameMenu == nil or g_inGameMenu.pageSettings == nil then
        return nil
    end
    return g_inGameMenu.pageSettings.gameSettingsLayout
end

function HerbicideWeedCleanupSettings:getTemplates(layout)
    if layout == nil or layout.elements == nil then
        return nil, nil
    end

    local sectionHeader = nil
    local optionRow = nil

    for _, element in pairs(layout.elements) do
        if element.name == "sectionHeader" and sectionHeader == nil then
            sectionHeader = element
        end

        if optionRow == nil and element.typeName == "Bitmap" and self:hasMultiTextOption(element) then
            optionRow = element
        end

        if sectionHeader ~= nil and optionRow ~= nil then
            break
        end
    end

    return sectionHeader, optionRow
end

function HerbicideWeedCleanupSettings:setTooltipText(element, text)
    if element == nil then
        return
    end
    element.toolTip = text
    element.tooltip = text
    element.toolTipText = text
    element.tooltipText = text
    element.helpText = text
    element.description = text
    if element.setTooltip ~= nil then
        element:setTooltip(text)
    end
    if element.setToolTip ~= nil then
        element:setToolTip(text)
    end
    if element.setHelpText ~= nil then
        element:setHelpText(text)
    end
    if element.setDescription ~= nil then
        element:setDescription(text)
    end
end

function HerbicideWeedCleanupSettings:resetFocusData(element)
    if element == nil then
        return
    end

    element.focusId = nil
    element.focusChangeData = {}
    element.focusActive = false
    element.isAlwaysFocusedOnOpen = false

    if element.elements ~= nil then
        for _, child in pairs(element.elements) do
            self:resetFocusData(child)
        end
    end
end

function HerbicideWeedCleanupSettings:refreshFocusHandling(element)
    if element ~= nil and element.reloadFocusHandling ~= nil then
        element:reloadFocusHandling(true)
    end
end

function HerbicideWeedCleanupSettings:registerFocusData(element)
    if element == nil or FocusManager == nil or FocusManager.loadElementFromCustomValues == nil then
        return
    end
    FocusManager:loadElementFromCustomValues(element, nil, {}, false, false)
end

function HerbicideWeedCleanupSettings:getDescriptionText()
    if g_i18n == nil then
        return ""
    end
    return g_i18n:getText("hwc_setting_mode_desc")
end

function HerbicideWeedCleanupSettings:setOptionTexts()
    local option = self.option
    if option == nil then
        return
    end

    if option.setLabel ~= nil then
        option:setLabel(g_i18n:getText("hwc_setting_mode_title"))
    end
    if option.setTexts ~= nil then
        option:setTexts({g_i18n:getText("hwc_setting_mode_immediate"), g_i18n:getText("hwc_setting_mode_delayed")})
    end
    if option.setState ~= nil then
        option:setState(self.mode)
    end
    self:setTooltipText(option, self:getDescriptionText())
end

function HerbicideWeedCleanupSettings:setNativeOptionTooltip(option, text)
    if option == nil then
        return
    end

    local function setIfText(element)
        if element ~= nil and element.setText ~= nil and element.typeName == "Text" then
            if element ~= option.labelElement and element ~= option.textElement then
                element:setText(text)
                return true
            end
        end
        return false
    end

    if option.elements ~= nil then
        if setIfText(option.elements[1]) then
            return
        end

        for _, child in pairs(option.elements) do
            if setIfText(child) then
                return
            end
        end
    end
end

function HerbicideWeedCleanupSettings:getStateFromCallback(a, b, c)
    if type(a) == "number" then
        return a
    end
    if type(b) == "number" then
        return b
    end
    if type(c) == "number" then
        return c
    end
    if self.option ~= nil and self.option.getState ~= nil then
        return self.option:getState()
    end
    return self.mode
end

function HerbicideWeedCleanupSettings:onOptionFocus()
    self:setNativeOptionTooltip(self.option, self:getDescriptionText())
end

function HerbicideWeedCleanupSettings:onClickMode(a, b, c)
    self.mode = self:normalizeMode(self:getStateFromCallback(a, b, c))
    self:saveSettings()
    self:setOptionTexts()
    self:onOptionFocus()
end

function HerbicideWeedCleanupSettings:prepareOptionRow(row)
    self:resetFocusData(row)

    local description = self:getDescriptionText()

    local function prepareChild(element)
        if element == nil then
            return
        end
        element.id = nil
        self:setTooltipText(element, description)
        element.onFocusCallback = function()
            self:onOptionFocus()
        end
        element.onHighlightCallback = function()
            self:onOptionFocus()
        end
        if element.elements ~= nil then
            for _, child in pairs(element.elements) do
                prepareChild(child)
            end
        end
    end

    row.id = nil
    row.name = "hwcCleanupModeRow"
    row.onFocusCallback = function()
        self:onOptionFocus()
    end
    row.onHighlightCallback = function()
        self:onOptionFocus()
    end
    self.settingsRow = row
    self:setTooltipText(row, description)

    if row.elements ~= nil then
        for _, element in pairs(row.elements) do
            prepareChild(element)
            if element.typeName == "Text" and element.setText ~= nil then
                element:setText(g_i18n:getText("hwc_setting_mode_title"))
            end
        end
    end

    local option = self:findElementRecursive(row, function(element)
        return self:isMultiTextOptionElement(element)
    end)

    if option == nil then
        return false
    end

    option.id = "hwcCleanupMode"
    option.name = "hwcCleanupMode"
    option.handleFocus = true
    if option.setHandleFocus ~= nil then
        option:setHandleFocus(true)
    else
        option.canChangeState = true
    end
    if option.setCanChangeState ~= nil then
        option:setCanChangeState(true)
    end
    option.isAlwaysFocusedOnOpen = false
    option.focused = false
    option.onFocusCallback = function()
        self:onOptionFocus()
    end
    option.onHighlightCallback = function()
        self:onOptionFocus()
    end
    option.onClickCallback = function(a, b, c)
        if FocusManager ~= nil then
            FocusManager:setFocus(option)
        end
        self:onOptionFocus()
        self:onClickMode(a, b, c)
    end
    self.option = option
    self:setOptionTexts()
    self:refreshFocusHandling(row)
    self:refreshFocusHandling(option)
    return true
end

function HerbicideWeedCleanupSettings:initializeSettingsOption()
    if self.settingsInitialized then
        return true
    end

    local layout = self:getGameSettingsLayout()
    if layout == nil or layout.elements == nil then
        return false
    end

    local headerTemplate, rowTemplate = self:getTemplates(layout)
    if headerTemplate == nil or rowTemplate == nil or headerTemplate.clone == nil or rowTemplate.clone == nil then
        return false
    end

    local header = headerTemplate:clone(layout)
    header:setText(g_i18n:getText("hwc_settings_header"))
    self.settingsHeader = header

    local row = rowTemplate:clone(layout)
    if not self:prepareOptionRow(row) then
        return false
    end

    self.settingsInitialized = true
    if layout.invalidateLayout ~= nil then
        layout:invalidateLayout()
    end

    self:registerFocusData(header)
    self:registerFocusData(self.settingsRow)

    if FocusManager ~= nil and FocusManager.setGui ~= nil and g_inGameMenu ~= nil then
        FocusManager:setGui(g_inGameMenu)
    end

    self:refreshFocusHandling(layout)
    self:refreshFocusHandling(self.settingsRow)
    self:refreshFocusHandling(self.option)

    self:updateSettingsFrame()
    return true
end

function HerbicideWeedCleanupSettings:updateSettingsFrame()
    self:loadSettings()

    if self.settingsHeader ~= nil then
        self.settingsHeader:setVisible(true)
    end
    if self.settingsRow ~= nil then
        self.settingsRow:setVisible(true)
    end

    self:setOptionTexts()
    self:refreshFocusHandling(self.settingsRow)
    self:refreshFocusHandling(self.option)
end

function HerbicideWeedCleanupSettings:onSettingsFrameOpen()
    if not self.settingsInitialized then
        self:initializeSettingsOption()
    end
    self:updateSettingsFrame()
end
