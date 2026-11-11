local ADDON_NAME, HKD = ...

HKD.VERSION = "1.0.0"

----------------------------------------------------------------------------
-- Default saved-variable structure
----------------------------------------------------------------------------
local DEFAULTS = {
    version  = HKD.VERSION,
    settings = {
        enabled = true,
        sound = {
            enabled = true,
            channel = "Master",
            volume  = 1.0,
        },
        confetti = {
            enabled   = true,
            intensity = "normal",
            duration  = 2.0,
        },
    },
}

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

----------------------------------------------------------------------------
-- Simple event frame  (one handler per event name – that's enough here)
----------------------------------------------------------------------------
local frame = CreateFrame("Frame")
HKD.frame = frame

local eventHandlers = {}

function HKD.RegisterEvent(event, handler)
    eventHandlers[event] = handler
    frame:RegisterEvent(event)
end

function HKD.UnregisterEvent(event)
    eventHandlers[event] = nil
    frame:UnregisterEvent(event)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local handler = eventHandlers[event]
    if handler then handler(event, ...) end
end)

----------------------------------------------------------------------------
-- Shared state
----------------------------------------------------------------------------
local IsSecret      = issecretvalue or function() return false end
local KILL_COOLDOWN = 2          -- seconds – prevents double-fire
local lastKillTime  = -math.huge

HKD.db    = nil
HKD.ready = false

----------------------------------------------------------------------------
-- Public entry point
----------------------------------------------------------------------------
function HKD.OnHonorKill()
    HKD.PlayKillSound()
    local ok, err = pcall(HKD.LaunchConfetti)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Honor Celebration confetti error:|r " .. tostring(err))
    end
end

local function FireKill()
    if not HKD.ready or not HKD.db.settings.enabled then return end
    local now = GetTime()
    if now - lastKillTime < KILL_COOLDOWN then return end
    lastKillTime = now
    HKD.OnHonorKill()
end

----------------------------------------------------------------------------
-- PRIMARY trigger: watch our current target's health/flags.
-- Fires the instant an enemy player hits 0 HP – before the server ever
-- sends CHAT_MSG_COMBAT_HONOR_GAIN (~1 s server-side delay).
----------------------------------------------------------------------------
local function CheckTargetDeath()
    if not UnitExists("target") then return end
    if not UnitIsPlayer("target") then return end
    if UnitIsFriend("player", "target") then return end
    if UnitIsFeignDeath and UnitIsFeignDeath("target") then return end

    local hp   = UnitHealth("target")
    local dead = UnitIsDead("target")
    if IsSecret(hp) or IsSecret(dead) then return end

    if dead or hp == 0 then
        FireKill()
    end
end

-- UNIT_HEALTH and UNIT_FLAGS both pass (event, unitToken)
local function OnUnitEvent(_, unit)
    if unit == "target" then
        CheckTargetDeath()
    end
end

----------------------------------------------------------------------------
-- FALLBACK trigger: CHAT_MSG_COMBAT_HONOR_GAIN.
-- Catches kills where the target had already changed before death
-- (tab-kills, AoE, target running out of range, etc.).
-- The 2-second cooldown stops it double-firing when the death watcher
-- already triggered.
----------------------------------------------------------------------------
local function OnHonorGain(_, msg)
    if type(msg) ~= "string" or IsSecret(msg) then return end
    FireKill()
end

----------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------
HKD.RegisterEvent("ADDON_LOADED", function(_, addon)
    if addon ~= ADDON_NAME then return end
    HKD.UnregisterEvent("ADDON_LOADED")

    if not HonorCelebrationDB then HonorCelebrationDB = {} end
    ApplyDefaults(HonorCelebrationDB, DEFAULTS)
    HKD.db = HonorCelebrationDB

    HKD.ready = true

    -- Primary: target death watcher (fires instantly at 0 HP).
    -- pcall every registration – event names vary across classic client builds;
    -- an unknown event name throws a Lua error that would abort this whole block.
    pcall(HKD.RegisterEvent, "UNIT_HEALTH",        OnUnitEvent)
    pcall(HKD.RegisterEvent, "UNIT_FLAGS",         OnUnitEvent)
    pcall(HKD.RegisterEvent, "UNIT_DYNAMIC_FLAGS", OnUnitEvent)

    -- Fallback: server honor-gain message (~1 s delay, but always fires).
    -- The shared 2-second cooldown stops it double-firing when the death
    -- watcher already triggered above.
    HKD.RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN", OnHonorGain)

    -- Slash commands
    SLASH_HONORCELEBRATION1 = "/hc"
    SLASH_HONORCELEBRATION2 = "/honorcelebration"
    SlashCmdList["HONORCELEBRATION"] = function(input)
        local cmd = strtrim(input or ""):lower()
        if cmd == "options" or cmd == "config" or cmd == "" then
            HKD.OpenOptions()
        elseif cmd == "test" then
            HKD.OnHonorKill()
        elseif cmd == "enable" then
            HKD.db.settings.enabled = true
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Honor Celebration:|r Enabled.")
        elseif cmd == "disable" then
            HKD.db.settings.enabled = false
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Honor Celebration:|r Disabled.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Honor Celebration|r commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  /hc           \226\128\147 open options")
            DEFAULT_CHAT_FRAME:AddMessage("  /hc test      \226\128\147 fire a test celebration")
            DEFAULT_CHAT_FRAME:AddMessage("  /hc enable    \226\128\147 enable the addon")
            DEFAULT_CHAT_FRAME:AddMessage("  /hc disable   \226\128\147 disable the addon")
        end
    end
end)
