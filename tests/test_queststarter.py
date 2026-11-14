"""Runs Quest Starter against a mock WoW API in real Lua 5.1.  pip install lupa  then:  python tests/test_queststarter.py"""
import os, sys
try:
    from lupa import lua51 as L
except ImportError:
    import lupa as L

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MOCK = r'''
printed = {}; calls = {}
T = 100
function GetTime() return T end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed+1] = m end }
timers = {}
C_Timer = { After = function(_, f) timers[#timers+1] = f end }
function run_timers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end

Widget = {}
Widget.__index = function(t, k)
  local v = rawget(Widget, k); if v ~= nil then return v end
  if type(k) == "string" and k:find("^%u") then return function() end end
end
function Widget:SetScript(k, fn) self.scripts[k] = fn end
function Widget:GetScript(k) return self.scripts[k] end
function Widget:RegisterEvent(e) self.events[e] = true end
function Widget:CreateFontString() return CreateFrame("FontString") end
function Widget:CreateTexture() return CreateFrame("Texture") end
function Widget:CreateAnimationGroup() return CreateFrame("AnimationGroup") end
function Widget:CreateAnimation() return CreateFrame("Animation") end
function Widget:SetText(t) self.text = t end
function Widget:GetText() return self.text or "" end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:IsShown() return self.shown end
function Widget:SetAttribute(k, v) if COMBAT then error("blocked in combat") end self.attrs[k] = v end
function Widget:GetAttribute(k) return self.attrs[k] end
function CreateFrame(kind, name)
  local f = setmetatable({ scripts = {}, events = {}, attrs = {}, kind = kind }, Widget)
  if name then _G[name] = f end
  return f
end
UIParent = CreateFrame("Frame"); GameTooltip = CreateFrame("GameTooltip")
function issecretvalue(v) return v == "SECRET" end
COMBAT = false
function InCombatLockdown() return COMBAT end
SHIFT = false
function IsShiftKeyDown() return SHIFT end
SOUNDKIT = { UI_AUTO_QUEST_NEW = 1 }
function PlaySound(id) calls[#calls+1] = "sound" end
function hooksecurefunc(t, k, post) local o = t[k]; t[k] = function(...) local r = o(...); post(...); return r end end

NUM_BAG_SLOTS = 4
CONTAINERS = {}; QUESTINFO = {}
function put(bag, slot, id, questID, active)
  CONTAINERS[bag] = CONTAINERS[bag] or {}; QUESTINFO[bag] = QUESTINFO[bag] or {}
  CONTAINERS[bag][slot] = id and { itemID = id, stackCount = 1, iconFileID = 7, hyperlink = "|cffffffff|Hitem:" .. id .. "|h[Item " .. id .. "]|h|r" } or nil
  QUESTINFO[bag][slot] = { isQuestItem = questID ~= nil, questID = questID, isActive = active or false }
end
C_Container = {
  GetContainerNumSlots = function(b) return CONTAINERS[b] and 16 or 0 end,
  GetContainerItemInfo = function(b, s) return CONTAINERS[b] and CONTAINERS[b][s] end,
  GetContainerItemQuestInfo = function(b, s) return (QUESTINFO[b] and QUESTINFO[b][s]) or { isQuestItem = false } end,
  UseContainerItem = function(b, s) calls[#calls+1] = "use " .. b .. " " .. s end,
}
DONE = {}
C_QuestLog = { IsQuestFlaggedCompleted = function(q) return DONE[q] end, GetLogIndexForQuestID = function() return nil end }
AUTO = false
function QuestGetAutoAccept() return AUTO end
function AcceptQuest() calls[#calls+1] = "accept" end
function CloseQuest() calls[#calls+1] = "close" end
function GetTitleText() return "The Head of the Beast" end
SlashCmdList = {}
'''

passed = failed = 0
def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print("FAIL:", name)

lua = L.LuaRuntime(unpack_returned_tuples=True)
lua.execute(MOCK)
for f in ("QuestStarter.lua", "QuestStarter_UI.lua"):
    lua.execute("local f = assert(loadstring(...)); f('QuestStarter')", open(os.path.join(ROOT, f), encoding="utf-8").read())
ev = lua.eval("function(e, ...) QuestStarter.frame:GetScript('OnEvent')(QuestStarter.frame, e, ...) end")
run = lua.execute
calls = lambda: list(lua.eval("calls").values())

# normal items and an active quest item don't show the button
run("put(0, 1, 100); put(0, 2, 200, 55, true)")
ev("PLAYER_LOGIN"); run("run_timers()")
check("button created", lua.eval("QuestStarterButton ~= nil"))
check("no button for normal/active items", not lua.eval("QuestStarterButton:IsShown()"))
check("binding name set", lua.eval("_G['BINDING_NAME_CLICK QuestStarterButton:LeftButton']") is not None)

# pick up a quest starter
run("put(1, 3, 300, 77)")
ev("BAG_UPDATE_DELAYED"); ev("BAG_UPDATE_DELAYED")
check("refresh debounced", lua.eval("#timers") == 1)
run("run_timers()")
b = "QuestStarterButton"
check("button shown", lua.eval(b + ":IsShown()"))
check("secure item attribute = bag slot", lua.eval(b + ":GetAttribute('item1')") == "1 3")
check("type is item", lua.eval(b + ":GetAttribute('type1')") == "item")
check("sound on new", "sound" in calls())
run("calls = {}")
ev("BAG_UPDATE_DELAYED"); run("run_timers()")
check("no sound for same item", "sound" not in calls())

# two starters -> "+1 more"
run("put(2, 1, 400, 88)"); ev("BAG_UPDATE_DELAYED"); run("run_timers()")
check("more shown", "+1 more" in lua.eval(b + ".item:GetText()"))
check("first in bag order", lua.eval(b + ":GetAttribute('item1')") == "1 3")

# clicking: PreClick notes the use, quest window opens -> accepted
run(b + ":GetScript('PreClick')(" + b + ", 'LeftButton', true)")
run("calls = {}")
ev("QUEST_DETAIL")
check("accepted after button click", calls() == ["accept"])
check("told the player", any("The Head of the Beast" in str(v) for v in lua.eval("printed").values()))

# quest window from an NPC (no item) is left alone
run("calls = {}; T = T + 60")
ev("QUEST_DETAIL")
check("NPC quest not touched", calls() == [])
ev("QUEST_DETAIL", 0)
check("item id 0 not touched", calls() == [])

# the event's questStartItemID alone is enough (right-click by hand)
ev("QUEST_DETAIL", 300)
check("accepted from questStartItemID", calls() == ["accept"])

# right-clicking the item in bags by hand also counts
run("calls = {}; T = T + 60; C_Container.UseContainerItem(1, 3)")
ev("QUEST_DETAIL")
check("manual bag use then accept", calls()[-1] == "accept")

# game auto-accepted -> just close
run("calls = {}; AUTO = true")
ev("QUEST_DETAIL", 300)
check("auto-accept quest closed", calls() == ["close"])
run("AUTO = false")

# shift held -> read it yourself
run("calls = {}; SHIFT = true"); ev("QUEST_DETAIL", 300); run("SHIFT = false")
check("shift skips", calls() == [])

# setting off
run("SlashCmdList.QUESTSTARTER('accept'); calls = {}"); ev("QUEST_DETAIL", 300)
check("auto-accept off", calls() == [])
run("SlashCmdList.QUESTSTARTER('accept')")

# accepted quest becomes active -> next starter shown
run("put(1, 3, 300, 77, true)"); ev("QUEST_ACCEPTED", 77); run("run_timers()")
check("moves to next starter", lua.eval(b + ":GetAttribute('item1')") == "2 1")
check("no more count", "+1" not in lua.eval(b + ".item:GetText()"))

# completed quest's leftover item ignored
run("DONE[88] = true"); ev("BAG_UPDATE_DELAYED"); run("run_timers()")
check("completed quest hidden", not lua.eval(b + ":IsShown()"))

# combat: no attribute changes, catches up after
run("DONE[88] = nil; COMBAT = true; put(3, 5, 500, 99)")
ev("BAG_UPDATE_DELAYED"); run("run_timers()")
check("deferred in combat", not lua.eval(b + ":IsShown()"))
run("COMBAT = false"); ev("PLAYER_REGEN_ENABLED")
check("shown after combat", lua.eval(b + ":IsShown()") and lua.eval(b + ":GetAttribute('item1')") == "2 1")

# right-click ignores
run(b + ":GetScript('PostClick')(" + b + ", 'RightButton', false)"); run("run_timers()")
check("ignored item skipped", lua.eval(b + ":GetAttribute('item1')") == "3 5")
check("ignore saved", lua.eval("QuestStarterDB.ignored[400]") is True)
run("SlashCmdList.QUESTSTARTER('reset')"); run("run_timers()")
check("reset un-ignores", lua.eval("QuestStarterDB.ignored[400]") is None and lua.eval(b + ":GetAttribute('item1')") == "2 1")

# button off
run("SlashCmdList.QUESTSTARTER('button')"); run("run_timers()")
check("button setting hides it", not lua.eval(b + ":IsShown()"))
run("SlashCmdList.QUESTSTARTER('')")

# secret item ids are skipped
run("SlashCmdList.QUESTSTARTER('button'); CONTAINERS = {}; QUESTINFO = {}; put(0, 1, 'SECRET', 5)")
ev("BAG_UPDATE_DELAYED"); run("run_timers()")
check("secret skipped", not lua.eval(b + ":IsShown()"))

print(f"{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
