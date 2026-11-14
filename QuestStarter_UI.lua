--[[
    The pop-up button. It's a secure item button: clicking it (or the key binding)
    uses the quest item exactly as a right-click in your bags would.
]]

local QS = QuestStarter
local UI = {}
QS.UI = UI

local btn, db

BINDING_HEADER_QUESTSTARTER = "Quest Starter"
_G["BINDING_NAME_CLICK QuestStarterButton:LeftButton"] = "Start the quest from a quest item"

function UI.ResetPosition()
    if not btn or InCombatLockdown() then return end
    btn:ClearAllPoints()
    btn:SetPoint("TOP", UIParent, "TOP", 0, -160)
end

function UI.Init(savedDB)
    db = savedDB
    btn = CreateFrame("Button", "QuestStarterButton", UIParent, "SecureActionButtonTemplate, BackdropTemplate")
    btn:SetSize(250, 48)
    btn:SetFrameStrata("HIGH")
    btn:SetClampedToScreen(true)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type1", "item")
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    if btn.SetBackdrop then
        btn:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        btn:SetBackdropColor(0.1, 0.08, 0, 0.9)
        btn:SetBackdropBorderColor(1, 0.82, 0, 1)
    end

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(36, 36)
    btn.icon:SetPoint("LEFT", 6, 0)
    btn.mark = btn:CreateTexture(nil, "OVERLAY")
    btn.mark:SetSize(36, 36)
    btn.mark:SetPoint("CENTER", btn.icon)
    btn.mark:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBang")

    btn.title = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    btn.title:SetPoint("TOPLEFT", btn.icon, "TOPRIGHT", 8, -1)
    btn.title:SetJustifyH("LEFT")
    btn.title:SetText("New quest! Click to start")
    btn.item = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btn.item:SetPoint("BOTTOMLEFT", btn.icon, "BOTTOMRIGHT", 8, 1)
    btn.item:SetWidth(190)
    btn.item:SetJustifyH("LEFT")
    btn.item:SetWordWrap(false)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", 4, -4)
    hl:SetPoint("BOTTOMRIGHT", -4, 4)
    hl:SetColorTexture(1, 0.82, 0, 0.15)

    -- gentle pulse so it gets noticed
    if btn.CreateAnimationGroup then
        local ag = btn:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Alpha")
        a:SetFromAlpha(1)
        a:SetToAlpha(0.65)
        a:SetDuration(0.8)
        btn.pulse = ag
    end

    btn:SetScript("PreClick", function(self, button, down)
        if button == "LeftButton" then QS.NoteItemUse() end
    end)
    btn:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down and self.itemID then
            QS.Ignore(self.itemID)
            QS.Print("Won't show that item again. /qs reset to undo.")
        end
    end)
    btn:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        db.point = { point, rel, x, y }
    end)
    btn:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cff33ff66Click|r: start the quest   |cffaaaaaaRight-click|r: ignore   |cffaaaaaaShift+drag|r: move", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if db.point then
        btn:ClearAllPoints()
        btn:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    else
        UI.ResetPosition()
    end
    btn:Hide()
end

-- only ever called out of combat
function UI.Update(list, isNew)
    if not btn then return end
    local s = list[1]
    if not s or not db.settings.button then
        btn.itemID, btn.link = nil, nil
        btn:SetAttribute("item1", nil)
        btn:Hide()
        if btn.pulse then btn.pulse:Stop() end
        return
    end
    btn.itemID, btn.link = s.itemID, s.link
    btn:SetAttribute("item1", s.bag .. " " .. s.slot)
    btn.icon:SetTexture(s.icon)
    local more = #list > 1 and ("  |cffaaaaaa(+" .. (#list - 1) .. " more)|r") or ""
    btn.item:SetText((s.link or ("item " .. s.itemID)) .. more)
    btn:Show()
    if btn.pulse and isNew then btn.pulse:Play() end
end

function UI.Button() return btn end
