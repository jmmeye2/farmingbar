local addonName, addon = ...
local FarmingBar = LibStub("AceAddon-3.0"):GetAddon("FarmingBar")
local L = LibStub("AceLocale-3.0"):GetLocale("FarmingBar", true)
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)

local _G = _G
local floor = math.floor

--*------------------------------------------------------------------------

local Type = "FarmingBar_Button"
local Version = 1

--*------------------------------------------------------------------------

local function GetModifiers()
    local mod = ""
    if IsShiftKeyDown() then
        mod = "shift"
    end
    if IsControlKeyDown() then
        mod = "ctrl"..(mod ~= "" and "-" or "")..mod
    end
    if IsAltKeyDown() then
        mod = "alt"..(mod ~= "" and "-" or "")..mod
    end
    return mod
end

--*------------------------------------------------------------------------

local postClickMethods = {
    clearObjective = function(self, ...)
        self.widget:ClearObjective()
    end,

    includeBank = function(self, ...)
        local widget = self.widget
        local objectiveTitle = widget:GetUserData("objectiveTitle")

        if addon:IsObjectiveAutoItem(objectiveTitle) then
            addon:SetTrackerDBInfo(objectiveTitle, 1, "includeBank", "_toggle")
            widget:SetObjectiveID(objectiveTitle)
            -- TODO: Update tracker frame if visible
            -- TODO: Alert bar progress if changed
        end
    end,

    moveObjective = function(self, ...)
        local widget = self.widget
        local bar = addon.bars[widget:GetUserData("barID")]
        local objectiveTitle = widget:GetUserData("objectiveTitle")
        local buttonID = widget:GetUserData("buttonID")

        if objectiveTitle and not addon.moveButton then
            widget.Flash:Show()
            UIFrameFlash(widget.Flash, 0.5, 0.5, -1)
            addon.moveButton = {widget, objectiveTitle}
        elseif addon.moveButton then
            widget:SwapButtons(addon.moveButton)
        end
    end,

    showObjectiveBuilder = function(self, ...)
        addon.ObjectiveBuilder:Load(self.widget:GetUserData("objectiveTitle"))
    end,
}

--*------------------------------------------------------------------------

local function Control_OnDragStart(self, buttonClicked, ...)
    local widget = self.widget
    local keybinds = FarmingBar.db.global.keybinds.dragButton

    widget:SetUserData("isDragging", true)

    if buttonClicked == keybinds.button then
        local mod = GetModifiers()

        if mod == keybinds.modifier then
            local objectiveTitle = widget:GetUserData("objectiveTitle")
            addon.moveButton = {widget, objectiveTitle}
            addon.DragFrame:Load(objectiveTitle)
            widget:ClearObjective()
        end
    end
end

------------------------------------------------------------

local function Control_OnDragStop(self)
    self.widget:SetUserData("isDragging", nil)
end

------------------------------------------------------------

local function Control_OnEnter(self)
    if addon.DragFrame:IsVisible() then
        self.widget:SetUserData("dragTitle", addon.DragFrame:GetObjective())
    end
end

------------------------------------------------------------

local function Control_OnEvent(self, event, ...)
    local widget = self.widget
    local barID = widget:GetUserData("barID")
    local barDB = addon.bars[barID]:GetUserData("barDB")
    local buttonID = widget:GetUserData("buttonID")
    local objectiveTitle = widget:GetUserData("objectiveTitle")
    local objectiveInfo = addon:GetObjectiveInfo(objectiveTitle)

    if event == "BAG_UPDATE" or event == "BAG_UPDATE_COOLDOWN" or event == "CURRENCY_DISPLAY_UPDATE" then
        if not barDB.alerts.muteAll then
            local count = addon:GetObjectiveCount(objectiveTitle)
            if count ~= widget:GetCount() then
                widget:SetCount()
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        widget:SetAttribute()
        self:UnregisterEvent(event)
        -- TODO: print combat left
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not objectiveInfo then return end
        if FarmingBar.db.profile.style.buttonLayers.Cooldown and objectiveInfo.displayRef.trackerType == "ITEM" then
            local startTime, duration, enable = GetItemCooldown(objectiveInfo.displayRef.trackerID)
            widget.Cooldown:SetCooldown(startTime, duration)
            widget.Cooldown:GetRegions():SetFontObject(NumberFontNormalSmall)
            -- TODO: custom fonts
            -- widget.Cooldown:GetRegions():SetFont(LSM:Fetch("font", self:GetBar().db.font.face or addon.db.profile.style.font.face) or "", (self:GetBar().db.font.size or addon.db.profile.style.font.size) * 1.5, self:GetBar().db.font.outline or addon.db.profile.style.font.outline)
            widget.Cooldown:Show()
        else
            widget.Cooldown:SetCooldown(0, 0)
            widget.Cooldown:Hide()
        end
    end
end

------------------------------------------------------------

local function Control_OnLeave(self)
    self.widget:SetUserData("dragTitle")
end

------------------------------------------------------------

local function Control_OnReceiveDrag(self)
    local widget = self.widget
    local objectiveTitle = widget:GetUserData("dragTitle")

    if objectiveTitle then
        if addon.moveButton then
            widget:SwapButtons(addon.moveButton)
        else
            widget:SetObjectiveID(objectiveTitle)
        end

        widget:SetUserData("dragTitle", nil)
    elseif not objectiveTitle then
        objectiveTitle = addon:CreateObjectiveFromCursor()
        widget:SetObjectiveID(objectiveTitle)
    end

    addon.DragFrame:Clear()
end

------------------------------------------------------------

local function Control_PostClick(self, buttonClicked, ...)
    local widget = self.widget
    if widget:GetUserData("isDragging") then return end
    local cursorType, cursorID = GetCursorInfo()

    if cursorType == "item" and not IsModifierKeyDown() and buttonClicked == "LeftButton" then
        local objectiveTitle = addon:CreateObjectiveFromCursor()
        widget:SetObjectiveID(objectiveTitle)
        ClearCursor()
        return
    elseif addon.DragFrame:IsVisible() then
        if addon.moveButton then
            widget:SwapButtons(addon.moveButton)
        else
            widget:SetObjectiveID(addon.DragFrame:GetObjective())
        end
        addon.DragFrame:Clear()
        return
    end

    ClearCursor()

    ------------------------------------------------------------

    local keybinds = FarmingBar.db.global.keybinds.button

    for keybind, keybindInfo in pairs(keybinds) do
        if buttonClicked == keybindInfo.button then
            local mod = GetModifiers()

            if mod == keybindInfo.modifier then
                local func = postClickMethods[keybind]
                if func then
                    func(self, keybindInfo, buttonClicked, ...)
                end
            end
        end
    end
end

--*------------------------------------------------------------------------

local methods = {
    OnAcquire = function(self)
        self.frame:ClearAllPoints()
        self.frame:Show()
        self.AutoCastable:Hide()

        self.Cooldown:SetDrawEdge(FarmingBar.db.profile.style.buttonLayers.CooldownEdge)
    end,

    ------------------------------------------------------------

    ClearObjective = function(self)
        self:SetUserData("objectiveTitle", nil)
        FarmingBar.db.char.bars[self:GetUserData("barID")].objectives[self:GetUserData("buttonID")] = nil

        self.frame:UnregisterEvent("BAG_UPDATE")
        self.frame:UnregisterEvent("BAG_UPDATE_COOLDOWN")
        self.frame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")

        self:UpdateLayers()
    end,

    ------------------------------------------------------------

    GetCount = function(self)
        return self.Count:GetText()
    end,

    ------------------------------------------------------------

    SetAttribute = function(self)
        local info = FarmingBar.db.global.keybinds.button.useItem
        local buttonType = (info.modifier ~= "" and (info.modifier.."-") or "").."type"..(info.button == "RightButton" and 2 or 1)
        local objectiveTitle = self:GetUserData("objectiveTitle")
        local objectiveInfo = addon:GetObjectiveInfo(objectiveTitle)

        if objectiveInfo and self.frame:GetAttribute(buttonType) == "macro" and objectiveInfo.displayRef.trackerType == "MACROTEXT" then
            if self.frame:GetAttribute("macrotext") == objectiveInfo.displayRef.trackerID then
                return
            end
        elseif objectiveInfo and self.frame:GetAttribute(buttonType) == "item" and objectiveInfo.displayRef.trackerType == "ITEM" then
            if self.frame:GetAttribute("item") == ("item"..objectiveInfo.displayRef.trackerID) then
                return
            end
        end

        if UnitAffectingCombat("player") then
            self.frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            -- TODO: print combat error
            return
        end

        self.frame:SetAttribute(buttonType, nil)
        self.frame:SetAttribute("item", nil)
        self.frame:SetAttribute("macrotext", nil)

        if not objectiveInfo then return end

        if objectiveInfo.displayRef.trackerType == "ITEM" and objectiveInfo.displayRef.trackerID then
            self.frame:SetAttribute(buttonType, "item")
            self.frame:SetAttribute("item", "item:"..objectiveInfo.displayRef.trackerID)
        elseif objectiveInfo.displayRef.trackerType == "MACROTEXT" then
            self.frame:SetAttribute(buttonType, "macro")
            self.frame:SetAttribute("macrotext", objectiveInfo.displayRef.trackerID)
        end
    end,

    ------------------------------------------------------------

    SetCount = function(self)

        local objectiveTitle = self:GetUserData("objectiveTitle")
        local objectiveInfo = addon:GetObjectiveInfo(objectiveTitle)
        local style = FarmingBar.db.profile.style.font.fontStrings.count

        self.Count:SetText(objectiveTitle and addon:GetObjectiveCount(objectiveTitle) or "")

        if not objectiveTitle then return end

        if style.colorType == "ITEMQUALITY" and addon:IsObjectiveAutoItem(objectiveTitle) then -- and item
            local r, g, b = GetItemQualityColor(C_Item.GetItemQualityByID(objectiveInfo.trackers[1].trackerID))
            self.Count:SetTextColor(r, g, b, 1)
        elseif style.colorType == "INCLUDEBANK" and addon:IsObjectiveBankIncluded(objectiveTitle) then -- and includeBank
            self.Count:SetTextColor(1, .82, 0, 1)
        else
            self.Count:SetTextColor(unpack(style.color))
        end
    end,

    ------------------------------------------------------------

    SetIcon = function(self)
        local objectiveTitle = self:GetUserData("objectiveTitle")
        self.Icon:SetTexture(objectiveTitle and addon:GetObjectiveIcon(objectiveTitle) or "")
    end,

    ------------------------------------------------------------

    SetObjective = function(self)
        local objectiveTitle = self:GetUserData("objectiveTitle")
        local objectiveInfo = addon:GetObjectiveInfo(objectiveTitle)

        if objectiveInfo.objective then
            local formattedObjective, objective = LibStub("LibAddonUtils-1.0").iformat(objectiveInfo.objective, 2)
            self.Objective:SetText(formattedObjective)

            local count = addon:GetObjectiveCount(objectiveTitle)

            if count >= objective then
                self.Objective:SetTextColor(0, 1 , 0, 1)
                if floor(count / objective) > 1 then
                    self.Objective:SetText(formattedObjective.."*")
                end
            else
                self.Objective:SetTextColor(1, .82, 0, 1)
            end
        else
            self.Objective:SetText("")
        end
    end,

    ------------------------------------------------------------

    SetObjectiveID = function(self, objectiveTitle)
        if not objectiveTitle then
            self:ClearObjective()
            return
        end

        self:SetUserData("objectiveTitle", objectiveTitle)
        FarmingBar.db.char.bars[self:GetUserData("barID")].objectives[self:GetUserData("buttonID")] = objectiveTitle

        self.frame:RegisterEvent("BAG_UPDATE")
        self.frame:RegisterEvent("BAG_UPDATE_COOLDOWN")
        self.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

        self:UpdateLayers()
    end,

    ------------------------------------------------------------

    SetPoint = function(self, ...) --point, anchor, relpoint, x, y
        self.frame:SetPoint(...)
    end,

    ------------------------------------------------------------

    SetSize = function(self, ...) --width, height
        self.frame:SetSize(...)
        self.Count:SetWidth(self.frame:GetWidth())
    end,

    ------------------------------------------------------------

    SwapButtons = function(self, moveButton)
        local objectiveTitle = self:GetUserData("objectiveTitle")
        local moveButtonWidget, moveButtonObjectiveTitle = moveButton[1], moveButton[2]
        addon.moveButton = nil

        self:SetObjectiveID(moveButtonObjectiveTitle)
        moveButtonWidget:SetObjectiveID(objectiveTitle)

        UIFrameFlashStop(moveButtonWidget.Flash)
        moveButtonWidget.Flash:Hide()
    end,

    ------------------------------------------------------------

    UpdateAutoCastable = function(self)
        local objectiveTitle = self:GetUserData("objectiveTitle")

        if FarmingBar.db.profile.style.buttonLayers.AutoCastable then
            if not addon:IsObjectiveBankIncluded(objectiveTitle) then
                self.AutoCastable:Hide()
            else
                self.AutoCastable:Show()
            end
        else
            self.AutoCastable:Hide()
        end
    end,

    ------------------------------------------------------------

    UpdateBorder = function(self)
        local objectiveTitle = self:GetUserData("objectiveTitle")
        local objectiveInfo = addon:GetObjectiveInfo(objectiveTitle)

        if FarmingBar.db.profile.style.buttonLayers.Border then
            local itemQuality = C_Item.GetItemQualityByID(objectiveInfo.trackers[1].trackerID)
            if itemQuality > 1 then
                local r, g, b = GetItemQualityColor(itemQuality)
                self.Border:SetVertexColor(r, g, b, 1)
                self.Border:Show()
            end
        else
            self.Border:Hide()
        end
    end,

    ------------------------------------------------------------

    UpdateLayers = function(self)
        self:SetIcon()
        self:SetCount()
        self:SetObjective()
        self:UpdateAutoCastable()
        self:UpdateBorder()
        self:SetAttribute()
    end,
}

--*------------------------------------------------------------------------

local function Constructor()
    local frame = CreateFrame("Button", Type.. AceGUI:GetNextWidgetNum(Type), UIParent, "SecureActionButtonTemplate, SecureHandlerDragTemplate")
    frame:RegisterForClicks("AnyUp")
    frame:RegisterForDrag("LeftButton", "RightButton")
	frame:SetScript("OnDragStart", Control_OnDragStart)
	frame:SetScript("OnDragStop", Control_OnDragStop)
	frame:SetScript("OnEnter", Control_OnEnter)
	frame:SetScript("OnEvent", Control_OnEvent)
	frame:SetScript("OnLeave", Control_OnLeave)
	frame:SetScript("OnReceiveDrag", Control_OnReceiveDrag)
    frame:SetScript("PostClick", Control_PostClick)

    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("BANKFRAME_OPENED")
    frame:RegisterEvent("BANKFRAME_CLOSED")

    local FloatingBG = frame:CreateTexture("$parentFloatingBG", "BACKGROUND", nil, 1)
    FloatingBG:SetAllPoints(frame)

    local Icon = frame:CreateTexture("$parentIcon", "BACKGROUND", nil, 2)
    Icon:SetAllPoints(frame)

    local Flash = frame:CreateTexture("$parentFlash", "BACKGROUND", nil, 3)
    Flash:SetAllPoints(frame)
    Flash:Hide()

    local Border = frame:CreateTexture("$parentBorder", "BORDER", nil, 1)
    Border:SetAllPoints(frame)
    Border:Hide()

    local AutoCastable = frame:CreateTexture("$parentAutoCastable", "OVERLAY", nil, 2)
    AutoCastable:SetAllPoints(frame)

    local Count = frame:CreateFontString(nil, "OVERLAY", nil, 3)
    Count:SetFont([[Fonts\FRIZQT__.TTF]], 12, "OUTLINE")
    Count:SetPoint("BOTTOMRIGHT", -2, 2)
    Count:SetPoint("BOTTOMLEFT", 2, 2)
    Count:SetJustifyH("RIGHT")

    local Objective = frame:CreateFontString(nil, "OVERLAY", nil, 3)
    Objective:SetFont([[Fonts\FRIZQT__.TTF]], 12, "OUTLINE")
    Objective:SetPoint("TOPLEFT", 2, -2)
    Objective:SetPoint("TOPRIGHT", -2, -2)
    Objective:SetJustifyH("LEFT")

    local Cooldown = CreateFrame("Cooldown", "$parentCooldown", frame, "CooldownFrameTemplate")
    Cooldown:SetAllPoints(frame)


    ------------------------------------------------------------

    local widget = {
		type  = Type,
        frame = frame,
        FloatingBG = FloatingBG,
        Icon = Icon,
        Flash = Flash,
        Border = Border,
        AutoCastable = AutoCastable,
        Count = Count,
        Objective = Objective,
        Cooldown = Cooldown,
    }

    frame.widget = widget

    for method, func in pairs(methods) do
        widget[method] = func
    end

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)