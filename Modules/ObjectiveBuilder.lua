local addonName, addon = ...
local FarmingBar = LibStub("AceAddon-3.0"):GetAddon("FarmingBar")
local L = LibStub("AceLocale-3.0"):GetLocale("FarmingBar", true)
local AceGUI = LibStub("AceGUI-3.0", true)

local tinsert, tremove, wipe, pairs = table.insert, table.remove, table.wipe, pairs
local strfind, strformat, gsub, strupper, tonumber = string.find, string.format, string.gsub, string.upper, tonumber

local ObjectiveBuilder = addon.ObjectiveBuilder

--*------------------------------------------------------------------------

local function autoIcon_OnValueChanged(self)
    addon:SetObjectiveDBInfo("autoIcon", self:GetValue())
end

------------------------------------------------------------

local function customCondition_OnEnterPressed(self)
    local condition = self:GetText()

    if addon:ValidateCustomCondition(condition) then
        addon:SetObjectiveDBInfo("customCondition", condition)
    else
        addon:ReportError(L.InvalidCustomCondition)
        self:SetFocus()
        self:HighlightText()
    end
end

------------------------------------------------------------

local function displayIcon_OnEnterPressed(self)
    addon:SetObjectiveDBInfo("icon", self:GetText())
end

------------------------------------------------------------

--!
local function displayRefHelp_OnClick(mainContent, label)
    if label:GetText() and label:GetText() ~= " " then
        label:SetText("")
        label:SetWidth(30)
    else
        --@retail@
        label:SetText(L.DisplayReferenceDescription)
        --@end-retail@
        --[===[@non-retail@
        -- Removing the currency reference from Classic here to make the localization page cleanier/easier to translate.
        label:SetText(gsub(L.DisplayReferenceDescription, L.DisplayReferenceDescription_Gsub, ""))
        --@end-non-retail@]===]
        label:SetWidth(label.frame:GetParent():GetWidth() - 10)
    end

    mainContent:DoLayout()
end

------------------------------------------------------------

local function displayRefMacrotext_OnEnterPressed(self)
    addon:SetObjectiveDBInfo("displayRef.trackerID", self:GetText())
end

------------------------------------------------------------

local function displayRefTrackerID_OnEnterPressed(self)
    local objectiveTitle, objectiveInfo = addon:GetSelectedObjectiveInfo()
    local trackerID = self:GetText()

    if addon:ValidateObjectiveData(objectiveInfo.displayRef.trackerType, trackerID) then
        addon:SetObjectiveDBInfo("displayRef.trackerID", objectiveInfo.displayRef.trackerType == "ITEM" and validTrackerID or tonumber(trackerID))

        self:SetText(objectiveInfo.displayRef.trackerID)
        self:ClearFocus()
    else
        addon:ReportError(L.InvalidTrackerID(objectiveInfo.displayRef.trackerType, trackerID))

        self:SetText("")
        self:SetFocus()
    end
end

------------------------------------------------------------

local function displayRefTrackerType_OnValueChanged(self, selected)
    addon:SetObjectiveDBInfo("displayRef.trackerType", selected ~= "NONE" and selected or false)
    -- addon:SetObjectiveDBInfo("displayRef.trackerID", false)
    --! have to add checks if we do this ^
end

------------------------------------------------------------

--!
local function excludeListLabel_OnClick(self, buttonClicked, key)
    if IsShiftKeyDown() and buttonClicked == "RightButton" then
        tremove(select(4, addon:GetSelectedObjectiveInfo()).exclude, key)
        self:LoadExcludeList()
    end
end

------------------------------------------------------------

local function excludeObjectives_OnEnterPressed(self)
    local objective = self:GetText()
    local validObjective = addon:ObjectiveExists(objective)

    if validObjective then
        local objectiveTitle, _, _, trackerInfo = addon:GetSelectedObjectiveInfo()
        local excluded = trackerInfo.exclude

        --! Should I not move this below the error reporting and rehighlight on err?
        self:SetText()

        if strupper(objectiveTitle) == strupper(objective) then
            addon:ReportError(L.InvalidTrackerExclusion)
            return
        elseif addon:ObjectiveIsExcluded(excluded, objective) then
            addon:ReportError(L.ObjectiveIsExcluded)
            return
        end

        tinsert(excluded, validObjective)

        addon.ObjectiveBuilder:LoadExcludeList()
    else
        addon:ReportError(L.InvalidObjectiveTitle)
        self:HighlightText()
    end
end

------------------------------------------------------------

-- ! Move this
local function filterAutoItems_OnEnter(self)
    if FarmingBar.db.global.hints.ObjectiveBuilder then
        GameTooltip:SetOwner(self.frame, "ANCHOR_BOTTOMRIGHT", 0, 0)
        GameTooltip:AddLine(strformat("%s:", L["Hint"]))
        GameTooltip:AddLine(L.FilterAutoItemsHint, unpack(addon.tooltip_description))
        GameTooltip:Show()
    end
end

------------------------------------------------------------

local function filterAutoItems_OnLeave(self)
    if FarmingBar.db.global.hints.ObjectiveBuilder then
        GameTooltip:ClearLines()
        GameTooltip:Hide()
    end
end
-- !

------------------------------------------------------------

local function filterAutoItems_OnValueChanged(self, _, value)
    addon:SetDBValue("global", "settings.misc.filterOBAutoItems", value)
    ObjectiveBuilder:LoadObjectives()
end

------------------------------------------------------------

local function mainTabGroup_OnGroupSelected(self, selected)
    local objectiveTitle = addon:GetSelectedObjectiveInfo()

    if objectiveTitle then
        ObjectiveBuilder:GetUserData("selectedTabs")[objectiveTitle] = selected
    end

    self:ReleaseChildren()

    if selected == "objectiveTab" then
        self:SetLayout("Fill")
        addon:ObjectiveBuilder_LoadObjectiveTab(objectiveTitle)
    elseif selected == "conditionTab" then
        self:SetLayout("Fill")
        addon:ObjectiveBuilder_LoadConditionTab(objectiveTitle)
    elseif selected == "trackersTab" then
        self:SetLayout("FB30_2RowSplitBottom")
        addon:ObjectiveBuilder_LoadTrackersTab(objectiveTitle)
    end
end

------------------------------------------------------------

local function NumericEditBox_OnTextChanged(self)
    self:SetText(string.gsub(self:GetText(), "[%s%c%p%a]", ""))
    self.editbox:SetCursorPosition(strlen(self:GetText()))
end

------------------------------------------------------------

local function trackerCondition_OnValueChanged(selected)
    addon:SetObjectiveDBInfo("trackerCondition", selected)
end

------------------------------------------------------------

--!
local function trackerID_OnEnterPressed(self)
    local objectiveTitle, _, tracker, trackerInfo = addon:GetSelectedObjectiveInfo()

    ------------------------------------------------------------

    if not self:GetText() or self:GetText() == "" then
        -- Clear trackerID
        addon:SetTrackerDBInfo(objectiveTitle, tracker, "trackerID", "")

        self:ClearFocus()

        -- ObjectiveBuilder:UpdateTrackerButton(tracker) --!
        RefreshObjectiveBuilder()
        return
    end

    ------------------------------------------------------------

    local validTrackerID = addon:ValidateObjectiveData(trackerInfo.trackerType, self:GetText())

    if validTrackerID or self:GetText() == "" then
        local newTrackerID = trackerInfo.trackerType == "ITEM" and validTrackerID or tonumber(self:GetText())
        local trackerIDExists = addon:TrackerExists(newTrackerID)

        if trackerIDExists then
            self:SetText(trackerInfo.trackerID)

            if newTrackerID ~= trackerInfo.trackerID then
                addon:ReportError(L.TrackerIDExists(self:GetText()))

                self:HighlightText()
                self:SetFocus()
            end
        else
            addon:SetTrackerDBInfo(objectiveTitle, tracker, "trackerID", newTrackerID)

            self:SetText(trackerInfo.trackerID)
            self:ClearFocus()

            -- ObjectiveBuilder:UpdateTrackerButton(tracker) --!
            RefreshObjectiveBuilder()
        end
    else
        addon:ReportError(L.InvalidTrackerID(trackerInfo.trackerType, self:GetText()))

        self:SetText(trackerInfo.trackerID)
        self:HighlightText()
        self:SetFocus()
    end
end

------------------------------------------------------------

local function trackerObjective_OnEnterPressed(self)
    local objectiveTitle, _, tracker = addon:GetSelectedObjectiveInfo()
    local text = self:GetText() ~= "" and self:GetText() or 1
    local objective = tonumber(text) > 0 and tonumber(text) or 1

    addon:SetTrackerDBInfo(objectiveTitle, tracker, "objective", objective)

    self:SetText(objective)
    self:ClearFocus()
end

------------------------------------------------------------

local function trackerType_OnValueChanged(self, selected)
    local objectiveTitle, _, tracker = addon:GetSelectedObjectiveInfo()

    addon:SetTrackerDBInfo(objectiveTitle, tracker, "trackerType", selected)

    RefreshObjectiveBuilder()
end

--*------------------------------------------------------------------------

local function TrackerButton_OnClick(tracker)
    ObjectiveBuilder:SetUserData("selectedTracker", tracker)
    addon:ObjectiveBuilder_LoadTrackerInfo(tracker)
end

--*------------------------------------------------------------------------

local methods = {
    GetSelectedObjective = function(self)
        return self:GetUserData("selectedObjective")

    end,

    ------------------------------------------------------------

    GetSelectedObjectiveInfo = function(self)
        local objectiveTitle = self:GetSelectedObjective()
        local objectiveInfo = addon:GetObjectiveInfo(objectiveTitle)
        local tracker = self:GetSelectedTracker()
        local trackerInfo = tracker and addon:GetTrackerInfo(objectiveTitle, tracker)

        return objectiveTitle, objectiveInfo, tracker, trackerInfo
    end,

    ------------------------------------------------------------

    GetSelectedTab = function(self, objectiveTitle)
        return self:GetUserData("selectedTabs")[objectiveTitle]
    end,

    ------------------------------------------------------------

    GetSelectedTracker = function(self)
        return self:GetUserData("selectedTracker")
    end,

    ------------------------------------------------------------

    GetObjectiveButton = function(self, objectiveTitle)
        for _, button in pairs(self.objectiveList.children) do
            if button:GetUserData("objectiveTitle") == objectiveTitle then
                return button
            end
        end
    end,

    ------------------------------------------------------------

    Load = function(self, objectiveTitle)
        self:Show()
        self:LoadObjectives(objectiveTitle)
    end,

    ------------------------------------------------------------

    LoadExcludeList = function(self)
        local _, _, _, trackerInfo = addon:GetSelectedObjectiveInfo()
        local excludeList = addon.ObjectiveBuilder.excludeList

        excludeList:ReleaseChildren()

        ------------------------------------------------------------

        for key, objectiveTitle in pairs(trackerInfo.exclude) do
            local label = AceGUI:Create("FB30_InteractiveLabel")
            label:SetFullWidth(true)
            label:SetText(objectiveTitle)
            label:SetImageSize(15, 15)
            label:SetImage(addon:GetObjectiveIcon(objectiveTitle))
            excludeList:AddChild(label)

            label:SetCallback("OnClick", function(_, _, buttonClicked) excludeListLabel_OnClick(self, buttonClicked, key) end)

            label:SetTooltip(addon.GetExcludeListLabelTooltip)
        end
    end,

    ------------------------------------------------------------

    LoadObjectives = function(self, objectiveTitle)
        local objectiveList = self.objectiveList
        local filter = self.objectiveSearchBox:GetText()

        objectiveList:ReleaseChildren()

        ------------------------------------------------------------

        for objectiveTitle, objective in addon.pairs(FarmingBar.db.global.objectives, function(a, b) return strupper(a) < strupper(b) end) do
            local notFiltered = not filter or strfind(strupper(objectiveTitle), strupper(filter))
            local autoFilterEnabled = addon:GetDBValue("global", "settings.misc.filterOBAutoItems")
            local notAutoFiltered = autoFilterEnabled and not addon:IsObjectiveAutoItem(objectiveTitle) or not autoFilterEnabled

            if notFiltered and notAutoFiltered then
                local button = AceGUI:Create("FarmingBar_ObjectiveButton")
                button:SetFullWidth(true)
                button:SetObjective(objectiveTitle)
                objectiveList:AddChild(button)
            end
        end

        ------------------------------------------------------------

        local selectedObjectiveTitle = objectiveTitle or self:GetSelectedObjective()

        if selectedObjectiveTitle then
            self:GetObjectiveButton(selectedObjectiveTitle).frame:Click()
        else
            self.mainPanel:ReleaseChildren()
        end
    end,

    ------------------------------------------------------------

    LoadTrackers = function(self)
        local _, objectiveInfo = addon:GetSelectedObjectiveInfo()
        local trackerList = addon.ObjectiveBuilder.trackerList

        trackerList:ReleaseChildren()
        wipe(trackerList.status.selected)
        wipe(trackerList.status.children)

        ------------------------------------------------------------

        for tracker, trackerInfo in pairs(objectiveInfo.trackers) do
            local button = AceGUI:Create("FarmingBar_TrackerButton")
            button:SetFullWidth(true)
            addon:GetTrackerDataTable(trackerInfo.trackerType, trackerInfo.trackerID, function(data)
                button:SetText(data.name)
                button:SetIcon(data.icon)
                tinsert(trackerList.status.children, {trackerTitle = data.name, button = button})
            end)
            button:SetStatus(trackerList.status)
            button:SetMenuFunc(GetTrackerContextMenu)
            button:SetTooltip(addon.GetTrackerButtonTooltip)
            trackerList:AddChild(button)

            ------------------------------------------------------------

            button:SetCallback("OnClick", function(self, event, ...) TrackerButton_OnClick(tracker) end)
        end
    end,

    ------------------------------------------------------------

    SelectObjective = function(self, objectiveTitle)
        self:SetUserData("selectedObjective", objectiveTitle)

        local mainPanel = self.mainPanel.frame
        if objectiveTitle then
            mainPanel:Show()
        else
            mainPanel:Hide()
        end

        self.mainContent:SelectTab(self:GetSelectedTab(objectiveTitle) or "objectiveTab")
    end,

    ------------------------------------------------------------

    UpdateTrackerButton = function(self)
        local _, _, tracker, trackerInfo = addon:GetSelectedObjectiveInfo()

        addon:GetTrackerDataTable(trackerInfo.trackerType, trackerInfo.trackerID, function(data)
            local button = addon.ObjectiveBuilder.trackerList.status.children[tracker].button
            button:SetText(data.name)
            button:SetIcon(data.icon)
        end)
    end,
}

------------------------------------------------------------

function addon:Initialize_ObjectiveBuilder()
    ObjectiveBuilder = AceGUI:Create("FB30_Window")
    ObjectiveBuilder:SetTitle("Farming Bar "..L["Objective Builder"])
    ObjectiveBuilder:SetSize(700, 500)
    ObjectiveBuilder:SetLayout("FB30_2RowSplitBottom")
    ObjectiveBuilder:SetUserData("selectedTabs", {})
    ObjectiveBuilder:Hide()
    self.ObjectiveBuilder = ObjectiveBuilder

    for method, func in pairs(methods) do
        ObjectiveBuilder[method] = func
    end

    ------------------------------------------------------------

    self.MenuFrame = self.MenuFrame or CreateFrame("Frame", "FarmingBarMenuFrame", UIParent, "UIDropDownMenuTemplate")

    ------------------------------------------------------------

    local topContent = AceGUI:Create("SimpleGroup")
    topContent:SetFullWidth(true)
    topContent:SetLayout("Flow")
    ObjectiveBuilder:AddChild(topContent)

    ------------------------------------------------------------

    local newObjectiveButton = AceGUI:Create("FB30_InteractiveLabel")
    newObjectiveButton:SetText(L["New Objective"])
    newObjectiveButton:SetWidth(newObjectiveButton.label:GetStringWidth() + newObjectiveButton.image:GetWidth())
    newObjectiveButton:SetImageSize(newObjectiveButton.label:GetHeight(), newObjectiveButton.label:GetHeight())
    newObjectiveButton:SetImage(514607)
    topContent:AddChild(newObjectiveButton)

    newObjectiveButton:SetCallback("OnClick", function() addon:CreateObjective() end)
    newObjectiveButton:SetCallback("OnReceiveDrag", function() addon:CreateObjectiveFromCursor() end)

    if FarmingBar.db.global.hints.ObjectiveBuilder then
        newObjectiveButton:SetTooltip(addon.GetNewObjectiveButtonTooltip)
    end

    ------------------------------------------------------------

    local importObjectiveButton = AceGUI:Create("FB30_InteractiveLabel")
    importObjectiveButton:SetText(L["Import Objective"])
    importObjectiveButton:SetWidth(importObjectiveButton.label:GetStringWidth() + importObjectiveButton.image:GetWidth())
    importObjectiveButton:SetImageSize(importObjectiveButton.label:GetHeight(), importObjectiveButton.label:GetHeight())
    importObjectiveButton:SetImage(131906, 1, 0, 0, 1)
    importObjectiveButton:SetDisabled(true)
    topContent:AddChild(importObjectiveButton)

    -- importObjectiveButton:SetCallback("OnClick", function() ????? end) -- TODO: implement import/export

    ------------------------------------------------------------

    local filterAutoItems = AceGUI:Create("CheckBox")
    filterAutoItems:SetLabel(L["Filter Auto Items"])
    filterAutoItems:SetValue(FarmingBar.db.global.settings.misc.filterOBAutoItems)
    filterAutoItems:SetWidth(filterAutoItems.text:GetStringWidth() + filterAutoItems.checkbg:GetWidth())
    topContent:AddChild(filterAutoItems)
    ObjectiveBuilder.filterAutoItems = filterAutoItems

    filterAutoItems:SetCallback("OnEnter", filterAutoItems_OnEnter)
    filterAutoItems:SetCallback("OnLeave", filterAutoItems_OnLeave)
    filterAutoItems:SetCallback("OnValueChanged", filterAutoItems_OnValueChanged)

    ------------------------------------------------------------

    local sidePanel = AceGUI:Create("SimpleGroup")
    sidePanel:SetRelativeWidth(1/4)
    sidePanel:SetFullHeight(true)
    sidePanel:SetLayout("FB30_2RowFill")
    ObjectiveBuilder:AddChild(sidePanel)

    ------------------------------------------------------------

    local objectiveSearchBox = AceGUI:Create("FB30_SearchEditBox")
    objectiveSearchBox:SetFullWidth(true)
    sidePanel:AddChild(objectiveSearchBox)
    ObjectiveBuilder.objectiveSearchBox = objectiveSearchBox

    objectiveSearchBox:SetCallback("OnTextChanged", function(self) ObjectiveBuilder:LoadObjectives() end)

    ------------------------------------------------------------

    local objectiveList = AceGUI:Create("ScrollFrame")
    objectiveList:SetLayout("List")
    sidePanel:AddChild(objectiveList)
    objectiveList:SetUserData("renaming", {})
    ObjectiveBuilder.objectiveList = objectiveList

    ------------------------------------------------------------

    local mainPanel = AceGUI:Create("SimpleGroup")
    mainPanel:SetRelativeWidth(3/4)
    mainPanel:SetFullHeight(true)
    mainPanel:SetLayout("Fill")
    ObjectiveBuilder:AddChild(mainPanel)
    ObjectiveBuilder.mainPanel = mainPanel

    ------------------------------------------------------------

    self:Initialize_DragFrame()

    ------------------------------------------------------------
    --Debug-----------------------------------------------------
    ------------------------------------------------------------
    if FarmingBar.db.global.debug.ObjectiveBuilder then
        C_Timer.After(1, function()
            ObjectiveBuilder:Load()

            -- for key, objective in pairs(addon.ObjectiveBuilder.children) do
            --     objective.button.frame:Click()
            --     if FarmingBar.db.global.debug.ObjectiveBuilderTrackers then
            --         addon.ObjectiveBuilder.mainContent:SelectTab("trackersTab")

            --         if key == #addon.ObjectiveBuilder.children then
            --             for _, tracker in pairs(ObjectiveBuilder.trackerList.status.children) do
            --                 tracker.button.frame:Click()
            --                 break
            --             end
            --         end
            --     elseif FarmingBar.db.global.debug.ObjectiveBuilderCondition then
            --         addon.ObjectiveBuilder.mainContent:SelectTab("conditionTab")
            --     end
            --     break
            -- end
        end)
    end
    ------------------------------------------------------------
    ------------------------------------------------------------
end

--*------------------------------------------------------------------------

function addon:ObjectiveBuilder_DrawTabs()
    local ObjectiveBuilder = self.ObjectiveBuilder
    local mainPanel = ObjectiveBuilder.mainPanel

    mainPanel:ReleaseChildren()

    ------------------------------------------------------------

    local mainTabGroup = AceGUI:Create("TabGroup")
    mainTabGroup:SetLayout("Fill")
    mainPanel:AddChild(mainTabGroup)
    ObjectiveBuilder.mainContent = mainTabGroup

    mainTabGroup:SetTabs({
        {text = L["Objective"], value = "objectiveTab"},
        {text = L["Condition"], value = "conditionTab"},
        {text = L["Trackers"], value = "trackersTab"}
    })

    ------------------------------------------------------------

    mainTabGroup:SetCallback("OnGroupSelected", function(self, _, selected) mainTabGroup_OnGroupSelected(self, selected) end)
end

--*------------------------------------------------------------------------

function addon:ObjectiveBuilder_LoadConditionTab(objectiveTitle)
    local mainContent = self.ObjectiveBuilder.mainContent

    if not objectiveTitle then return end
    local objectiveInfo = self:GetObjectiveInfo(objectiveTitle)

    ------------------------------------------------------------

    local tabContent = AceGUI:Create("ScrollFrame")
    tabContent:SetLayout("Flow")
    mainContent:AddChild(tabContent)
    mainContent:SetLayout("Fill")

    ------------------------------------------------------------

    local trackerCondition = AceGUI:Create("Dropdown")
    trackerCondition:SetFullWidth(true)
    trackerCondition:SetLabel(L["Tracker Condition"])
    trackerCondition:SetList(
        {
            ANY = L["Any"],
            ALL = L["All"],
            CUSTOM = L["Custom"],
        },
        {"ANY", "ALL", "CUSTOM"}
    )
    trackerCondition:SetValue(objectiveInfo.trackerCondition)
    tabContent:AddChild(trackerCondition)

    trackerCondition:SetCallback("OnValueChanged", function(_, _, selected) trackerCondition_OnValueChanged(selected) end)

    ------------------------------------------------------------

    if objectiveInfo.trackerCondition == "CUSTOM" then
        local customCondition = AceGUI:Create("MultiLineEditBox")
        customCondition:SetFullWidth(true)
        customCondition:SetLabel(L["Custom Function"])
        customCondition:SetText(objectiveInfo.customCondition)
        tabContent:AddChild(customCondition)

        customCondition:SetCallback("OnEnterPressed", customCondition_OnEnterPressed)
    end

    ------------------------------------------------------------
    --Debug-----------------------------------------------------
    ------------------------------------------------------------
    if FarmingBar.db.global.debug.ObjectiveBuilder then
        local debug_checkCount = AceGUI:Create("Button")
        debug_checkCount:SetFullWidth(true)
        debug_checkCount:SetText("Check Count")
        tabContent:AddChild(debug_checkCount)

        debug_checkCount:SetCallback("OnClick", function(self, event, ...)
            print(addon:GetObjectiveCount((addon:GetSelectedObjectiveInfo())))
        end)
    end
    ------------------------------------------------------------
    ------------------------------------------------------------
end

------------------------------------------------------------

function addon:ObjectiveBuilder_LoadObjectiveTab(objectiveTitle)
    local mainContent = self.ObjectiveBuilder.mainContent

    if not objectiveTitle then return end
    local objectiveInfo = self:GetObjectiveInfo(objectiveTitle)

    ------------------------------------------------------------

    local tabContent = AceGUI:Create("ScrollFrame")
    tabContent:SetLayout("Flow")
    mainContent:AddChild(tabContent)
    mainContent:SetLayout("Fill")

    ------------------------------------------------------------

    local title = AceGUI:Create("Label")
    title:SetFullWidth(true)
    title:SetText(objectiveTitle)
    title:SetFontObject(GameFontNormalLarge)
    title:SetImageSize(20, 20)
    title:SetImage(self:GetObjectiveIcon(objectiveTitle))
    tabContent:AddChild(title)

    ------------------------------------------------------------

    local autoIcon = AceGUI:Create("CheckBox")
    autoIcon:SetFullWidth(true)
    autoIcon:SetValue(objectiveInfo.autoIcon)
    autoIcon:SetLabel(L["Automatic Icon"])
    tabContent:AddChild(autoIcon)

    autoIcon:SetCallback("OnValueChanged", autoIcon_OnValueChanged)

    ------------------------------------------------------------

    if not objectiveInfo.autoIcon then
        local displayIcon = AceGUI:Create("EditBox")
        displayIcon:SetRelativeWidth(1/2)
        displayIcon:SetText(objectiveInfo.icon)
        tabContent:AddChild(displayIcon, tabContent.objective)

        displayIcon:SetCallback("OnEnterPressed", displayIcon_OnEnterPressed)

        ------------------------------------------------------------

        local chooseButton = AceGUI:Create("Button")
        chooseButton:SetRelativeWidth(1/2)
        chooseButton:SetText(L["Choose"])
        tabContent:AddChild(chooseButton, tabContent.objective)

        -- chooseButton:SetCallback("OnClick", function() self.IconSelector:Show() end) -- TODO: Icon selector frame
    end

    ------------------------------------------------------------

    local displayRef = AceGUI:Create("Heading")
    displayRef:SetFullWidth(true)
    displayRef:SetText(L["Display Reference"])
    tabContent:AddChild(displayRef)

    ------------------------------------------------------------

    local displayRefTrackerType = AceGUI:Create("Dropdown")
    displayRefTrackerType:SetRelativeWidth(0.92)
    displayRefTrackerType:SetLabel(L["Type"])
    displayRefTrackerType:SetList(
        {
            ITEM = L["Item"],
            CURRENCY = L["Currency"],
            MACROTEXT = L["Macrotext"],
            NONE = L["None"],
        },
        {"ITEM", "CURRENCY", "MACROTEXT", "NONE"}
    )
    displayRefTrackerType:SetValue(objectiveInfo.displayRef.trackerType or "NONE")
    tabContent:AddChild(displayRefTrackerType)

    displayRefTrackerType:SetCallback("OnValueChanged", function(self, _, selected) displayRefTrackerType_OnValueChanged(self, selected) end)

    ------------------------------------------------------------

    local displayRefHelp = AceGUI:Create("FB30_InteractiveLabel")
    displayRefHelp:SetText(" ")
    displayRefHelp:SetImage(616343)
    displayRefHelp:SetImageSize(25, 25)
    displayRefHelp:SetWidth(30)
    tabContent:AddChild(displayRefHelp)

    displayRefHelp:SetCallback("OnClick", function(label) displayRefHelp_OnClick(tabContent, label) end)

    ------------------------------------------------------------

    if objectiveInfo.displayRef.trackerType == "MACROTEXT" then
        local displayRefMacrotext = AceGUI:Create("MultiLineEditBox")
        displayRefMacrotext:SetFullWidth(true)
        displayRefMacrotext:SetLabel(L["Macrotext"])
        displayRefMacrotext:SetText(objectiveInfo.displayRef.trackerID or "")
        tabContent:AddChild(displayRefMacrotext)

        displayRefMacrotext:SetCallback("OnEnterPressed", displayRefMacrotext_OnEnterPressed)
    elseif objectiveInfo.displayRef.trackerType and objectiveInfo.displayRef.trackerType ~= "NONE" then
        local displayRefTrackerID = AceGUI:Create("EditBox")
        displayRefTrackerID:SetFullWidth(true)
        displayRefTrackerID:SetLabel(self:GetTrackerTypeLabel(objectiveInfo.displayRef.trackerType))
        displayRefTrackerID:SetText(objectiveInfo.displayRef.trackerID or "")
        tabContent:AddChild(displayRefTrackerID)

        displayRefTrackerID:SetCallback("OnEnterPressed", displayRefTrackerID_OnEnterPressed)
    end
end

------------------------------------------------------------

function addon:ObjectiveBuilder_LoadTrackersTab(objectiveTitle)
    local ObjectiveBuilder = addon.ObjectiveBuilder
    local tabContent = ObjectiveBuilder.mainContent

    if not objectiveTitle then return end
    local objectiveInfo = self:GetObjectiveInfo(objectiveTitle)

    ------------------------------------------------------------

    local topContent = AceGUI:Create("SimpleGroup")
    topContent:SetFullWidth(true)
    topContent:SetHeight(20)
    topContent:SetLayout("Flow")
    topContent:SetAutoAdjustHeight(false)
    tabContent:AddChild(topContent)

    ------------------------------------------------------------

    local newTrackerButton = AceGUI:Create("FB30_InteractiveLabel")
    newTrackerButton:SetText(L["New Tracker"])
    newTrackerButton:SetWidth(newTrackerButton.label:GetStringWidth() + newTrackerButton.image:GetWidth())
    newTrackerButton:SetImageSize(newTrackerButton.label:GetHeight(), newTrackerButton.label:GetHeight())
    newTrackerButton:SetImage(514607)
    topContent:AddChild(newTrackerButton)

    newTrackerButton:SetCallback("OnClick", function() addon:CreateTracker() end)
    newTrackerButton:SetCallback("OnReceiveDrag", function() addon:CreateTracker(true) end)
    if FarmingBar.db.global.hints.ObjectiveBuilder then
        newTrackerButton:SetTooltip(addon.GetNewTrackerButtonTooltip)
    end

    ------------------------------------------------------------

    local trackerListContainer = AceGUI:Create("SimpleGroup")
    trackerListContainer:SetLayout("Fill")
    tabContent:AddChild(trackerListContainer)

    ------------------------------------------------------------

    local trackerList = AceGUI:Create("ScrollFrame")
    trackerList:SetLayout("List")
    trackerListContainer:AddChild(trackerList)
    ObjectiveBuilder.trackerList = trackerList
    trackerList.status = {children = {}, selected = {}}

    ------------------------------------------------------------

    local trackerInfo = AceGUI:Create("ScrollFrame")
    trackerInfo:SetLayout("List")
    tabContent:AddChild(trackerInfo)
    trackerList.status.content = trackerInfo

    ------------------------------------------------------------

    ObjectiveBuilder:LoadTrackers()
end

--*------------------------------------------------------------------------

function addon:ObjectiveBuilder_LoadTrackerInfo(tracker)
    local ObjectiveBuilder = self.ObjectiveBuilder
    local objectiveTitle, _, _, trackerInfo = self:GetSelectedObjectiveInfo()
    local tabContent = ObjectiveBuilder.trackerList.status.content

    tabContent:ReleaseChildren()

    if not objectiveTitle or not trackerInfo then return end

    ------------------------------------------------------------

    --@retail@
    local trackerType = AceGUI:Create("Dropdown")
    trackerType:SetFullWidth(1)
    trackerType:SetLabel(L["Type"])
    trackerType:SetList(
        {
            ITEM = L["Item"],
            CURRENCY = L["Currency"],
        },
        {"ITEM", "CURRENCY"}
    )
    trackerType:SetValue(trackerInfo.trackerType)
    tabContent:AddChild(trackerType)

    trackerType:SetCallback("OnValueChanged", function(self, _, selected) trackerType_OnValueChanged(self, selected) end)
    --@end-retail@

    ------------------------------------------------------------

    local trackerID = AceGUI:Create("EditBox")
    trackerID:SetFullWidth(true)
    trackerID:SetLabel(self:GetTrackerTypeLabel(trackerInfo.trackerType))
    trackerID:SetText(trackerInfo.trackerID or "")
    tabContent:AddChild(trackerID)
    ObjectiveBuilder.trackerList.status.trackerID = trackerID

    trackerID:SetCallback("OnEnterPressed", trackerID_OnEnterPressed)

    ------------------------------------------------------------

    local trackerObjective = AceGUI:Create("EditBox")
    trackerObjective:SetFullWidth(true)
    trackerObjective:SetLabel(L["Objective"])
    trackerObjective:SetText(trackerInfo.objective or "")
    tabContent:AddChild(trackerObjective)

    trackerObjective:SetCallback("OnEnterPressed", trackerObjective_OnEnterPressed)
    trackerObjective:SetCallback("OnTextChanged", function(self) NumericEditBox_OnTextChanged(self) end)

    ------------------------------------------------------------

    local includeBank = AceGUI:Create("CheckBox")
    includeBank:SetFullWidth(true)
    includeBank:SetLabel(L["Include Bank"])
    includeBank:SetValue(trackerInfo.includeBank)
    tabContent:AddChild(includeBank)

    includeBank:SetCallback("OnValueChanged", function(self)
        local ObjectiveBuilder = addon.ObjectiveBuilder
        local objectiveTitle = ObjectiveBuilder:GetSelectedObjective()
        addon:SetTrackerDBInfo(objectiveTitle, ObjectiveBuilder:GetSelectedTracker(), "includeBank", self:GetValue())
        addon:UpdateButtons(objectiveTitle)
    end) --! move to local

    ------------------------------------------------------------

    local includeAllChars = AceGUI:Create("CheckBox")
    includeAllChars:SetFullWidth(true)
    includeAllChars:SetLabel(L["Include All Characters"])
    includeAllChars:SetValue(trackerInfo.includeAllChars)
    local missing = self:IsDataStoreLoaded()
    if #missing > 0 then
        includeAllChars:SetDisabled(true)
        local line = L["Missing"] ..": "..missing[1]
        if #missing > 1 then
            for i = 2, #missing do
                line = line ..", "..missing[i]
            end
        end
        includeAllChars:SetDescription(line)
    end
    tabContent:AddChild(includeAllChars)

    includeAllChars:SetCallback("OnValueChanged", function(self) addon:SetTrackerDBInfo(addon.ObjectiveBuilder:GetSelectedObjective(), addon.ObjectiveBuilder:GetSelectedTracker(), "includeAllChars", self:GetValue()) end)

    ------------------------------------------------------------

    local excludeObjectives = AceGUI:Create("EditBox")
    excludeObjectives:SetFullWidth(true)
    excludeObjectives:SetLabel(L["Exclude Objective"])
    tabContent:AddChild(excludeObjectives)

    excludeObjectives:SetCallback("OnEnterPressed", excludeObjectives_OnEnterPressed)

    ------------------------------------------------------------

    local excludeListContainer = AceGUI:Create("SimpleGroup")
    excludeListContainer:SetFullWidth(true)
    excludeListContainer:SetHeight(150)
    excludeListContainer:SetLayout("Fill")
    tabContent:AddChild(excludeListContainer)

    ------------------------------------------------------------

    local excludeList = AceGUI:Create("ScrollFrame")
    excludeList:SetLayout("FB30_PaddedList")
    excludeListContainer:AddChild(excludeList)
    ObjectiveBuilder.excludeList = excludeList

    ObjectiveBuilder:LoadExcludeList()
end