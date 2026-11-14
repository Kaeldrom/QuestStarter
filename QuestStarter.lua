--[[
    Quest Starter
    When an item that starts a quest lands in your bags, a glowing button pops up.
    One click (or your key binding) opens the quest, and Quest Starter accepts it for you.

    Why a button and not fully automatic? WoW does not let addons use items by
    themselves (only a real click or key press can), so the button is the
    closest thing to automatic the game allows. Accepting the quest window that
    opens from an item IS allowed, so that part needs no click at all.

    QuestStarterDB = { settings = { autoAccept, button, sound }, ignored = { [itemID] = true }, point = {...} }
]]

local ADDON = ...
local QS = {}
QuestStarter = QS

local DEFAULTS = { autoAccept = true, button = true, sound = true }
local ITEM_WINDOW = 10 -- seconds after using a starter item in which a quest window counts as "from an item"

local db
local starters = {}       -- { {bag, slot, itemID, questID, link}, ... } in bag order
local lastItemUse = -100
local pendingRefresh = false

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00Quest Starter|r: " .. tostring(msg))
end
QS.Print = Print

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

---------------------------------------------------------------------------
-- Finding quest-starting items
---------------------------------------------------------------------------
local BAGS = {}
local function BuildBags()
    BAGS = {}
    for b = 0, (NUM_BAG_SLOTS or 4) do BAGS[#BAGS + 1] = b end
    local E = Enum and Enum.BagIndex
    if E and E.ReagentBag then BAGS[#BAGS + 1] = E.ReagentBag end
end

local function QuestInfo(bag, slot)
    if C_Container.GetContainerItemQuestInfo then
        local q = C_Container.GetContainerItemQuestInfo(bag, slot)
        if q then return q.questID, q.isActive end
        return nil
    end
    if GetContainerItemQuestInfo then
        local _, questID, isActive = GetContainerItemQuestInfo(bag, slot)
        return questID, isActive
    end
end

local function AlreadyDone(questID)
    local QL = C_QuestLog
    if QL and QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(questID) then return true end
    if QL and QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(questID) then return true end
    return false
end

function QS.Scan()
    local found = {}
    for _, bag in ipairs(BAGS) do
        for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and not IsSecret(info.itemID) and not db.ignored[info.itemID] then
                local questID, isActive = QuestInfo(bag, slot)
                if questID and questID ~= 0 and not isActive and not AlreadyDone(questID) then
                    found[#found + 1] = { bag = bag, slot = slot, itemID = info.itemID, questID = questID,
                                          link = info.hyperlink, icon = info.iconFileID }
                end
            end
        end
    end
    return found
end

function QS.Starters() return starters end

---------------------------------------------------------------------------
-- Refreshing (secure button attributes can't change in combat)
---------------------------------------------------------------------------
local lastSeen = {}

function QS.Refresh()
    pendingRefresh = false
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    local old = lastSeen
    starters = QS.Scan()
    lastSeen = {}
    local isNew = false
    for _, s in ipairs(starters) do
        lastSeen[s.itemID] = true
        if not old[s.itemID] then isNew = true end
    end
    if QS.UI then QS.UI.Update(starters, isNew) end
    if isNew and db.settings.sound and PlaySound and SOUNDKIT and SOUNDKIT.UI_AUTO_QUEST_NEW then
        PlaySound(SOUNDKIT.UI_AUTO_QUEST_NEW)
    end
end

local refreshQueued = false
local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0.2, function()
        refreshQueued = false
        QS.Refresh()
    end)
end
QS.QueueRefresh = QueueRefresh

-- the button (or the player) just used a starter item
function QS.NoteItemUse() lastItemUse = GetTime() end

function QS.Ignore(itemID)
    db.ignored[itemID] = true
    QueueRefresh()
end

---------------------------------------------------------------------------
-- Accepting the quest window that opens from an item
---------------------------------------------------------------------------
local function FromItem(questStartItemID)
    if questStartItemID and questStartItemID ~= 0 and not IsSecret(questStartItemID) then return true end
    return GetTime() - lastItemUse <= ITEM_WINDOW
end

function QS.OnQuestDetail(questStartItemID)
    if not db.settings.autoAccept or not FromItem(questStartItemID) then return end
    if IsShiftKeyDown and IsShiftKeyDown() then return end -- hold Shift to read it first
    lastItemUse = -100
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        CloseQuest() -- the game already took it
    else
        AcceptQuest()
    end
    local title = GetTitleText and GetTitleText()
    if title and not IsSecret(title) then Print("Accepted |cffffffff" .. title .. "|r.") end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "|cff33ff66on|r" or "|cffff6666off|r" end

local function Slash(msg)
    local cmd = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if cmd == "accept" then
        db.settings.autoAccept = not db.settings.autoAccept
        Print("Auto-accept " .. OnOff(db.settings.autoAccept))
    elseif cmd == "button" then
        db.settings.button = not db.settings.button
        Print("Pop-up button " .. OnOff(db.settings.button))
        QueueRefresh()
    elseif cmd == "sound" then
        db.settings.sound = not db.settings.sound
        Print("Sound " .. OnOff(db.settings.sound))
    elseif cmd == "reset" then
        wipe(db.ignored)
        db.point = nil
        if QS.UI then QS.UI.ResetPosition() end
        Print("Ignored items cleared and button moved back.")
        QueueRefresh()
    else
        Print("Auto-accept " .. OnOff(db.settings.autoAccept) .. ", button " .. OnOff(db.settings.button) .. ", sound " .. OnOff(db.settings.sound))
        Print("/qs accept | button | sound - turn each on/off")
        Print("/qs reset - un-ignore items and move the button back")
        Print("Set a key: Options > Keybindings > AddOns > Quest Starter. Shift+drag moves the button; right-click ignores an item.")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
QS.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        QuestStarterDB = QuestStarterDB or {}
        db = QuestStarterDB
        db.settings = db.settings or {}
        db.ignored = db.ignored or {}
        for k, v in pairs(DEFAULTS) do if db.settings[k] == nil then db.settings[k] = v end end
        BuildBags()
        if QS.UI then QS.UI.Init(db) end
        for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
                              "QUEST_LOG_UPDATE", "QUEST_DETAIL", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
            pcall(frame.RegisterEvent, frame, ev)
        end
        -- a starter item used by hand (right-click in the bags) also counts
        if C_Container and C_Container.UseContainerItem then
            hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
                local questID, isActive = QuestInfo(bag, slot)
                if questID and questID ~= 0 and not isActive then QS.NoteItemUse() end
            end)
        end
        SLASH_QUESTSTARTER1 = "/qs"
        SLASH_QUESTSTARTER2 = "/queststarter"
        SlashCmdList.QUESTSTARTER = Slash
        QueueRefresh()
    elseif event == "QUEST_DETAIL" then
        QS.OnQuestDetail(...)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingRefresh then QS.Refresh() end
    else
        QueueRefresh()
    end
end)
frame:RegisterEvent("PLAYER_LOGIN")
