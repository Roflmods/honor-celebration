local _, HKD = ...

----------------------------------------------------------------------------
-- Sound + confetti celebration on every Honor Kill
----------------------------------------------------------------------------

local SOUND_FILE = "Interface\\AddOns\\honor-celebration\\Sounds\\GruntBirthday.ogg"

----------------------------------------------------------------------------
-- Sound channel → CVar mapping
-- Used to temporarily reduce a channel's volume when playing below 100 %.
----------------------------------------------------------------------------
local CVAR_MAP = {
    Master   = "Sound_MasterVolume",
    SFX      = "Sound_SFXVolume",
    Music    = "Sound_MusicVolume",
    Ambience = "Sound_AmbienceVolume",
    Dialog   = "Sound_DialogVolume",
}

----------------------------------------------------------------------------
-- Confetti parameters
----------------------------------------------------------------------------
local CONFETTI_COLORS = {
    { 1.0, 0.2, 0.2 },   -- red
    { 0.2, 0.6, 1.0 },   -- sky blue
    { 0.2, 1.0, 0.2 },   -- green
    { 1.0, 1.0, 0.2 },   -- yellow
    { 1.0, 0.4, 1.0 },   -- pink
    { 1.0, 0.6, 0.1 },   -- orange
    { 0.6, 0.2, 1.0 },   -- purple
    { 0.2, 1.0, 1.0 },   -- cyan
}

-- Intensity presets: how many particles and how big each one is.
local INTENSITY = {
    subtle = { count = 15, size = 4 },
    normal = { count = 30, size = 6 },
    party  = { count = 60, size = 8 },
}

local GRAVITY     = 600   -- pixels/s² pulling particles downward
local MAX_PARTICLES = 60

----------------------------------------------------------------------------
-- Particle pool
-- One persistent frame; OnUpdate is a no-op while nothing is airborne.
----------------------------------------------------------------------------
local confettiFrame = CreateFrame("Frame", nil, UIParent)
confettiFrame:SetAllPoints(UIParent)
confettiFrame:SetFrameStrata("FULLSCREEN_DIALOG")
confettiFrame:SetFrameLevel(100)
confettiFrame:EnableMouse(false)

local particles   = {}
local activeCount = 0

for i = 1, MAX_PARTICLES do
    local p = confettiFrame:CreateTexture(nil, "OVERLAY")
    p:SetColorTexture(1, 1, 1, 1)
    p:Hide()
    particles[i] = {
        tex  = p,
        x    = 0, y    = 0,
        dx   = 0, dy   = 0,
        life = 0, maxLife = 0,
        active = false,
    }
end

confettiFrame:SetScript("OnUpdate", function(_, dt)
    if activeCount <= 0 then return end
    local done = 0
    for i = 1, MAX_PARTICLES do
        local p = particles[i]
        if p.active then
            p.life = p.life - dt
            if p.life <= 0 then
                p.tex:Hide()
                p.active = false
                done = done + 1
            else
                p.dy = p.dy - GRAVITY * dt
                p.x  = p.x + p.dx * dt
                p.y  = p.y + p.dy * dt
                p.tex:SetAlpha(math.max(0, p.life / p.maxLife))
                p.tex:SetPoint("CENTER", confettiFrame, "CENTER", p.x, p.y)
            end
        end
    end
    activeCount = activeCount - done
end)

----------------------------------------------------------------------------
-- Launch a confetti burst
----------------------------------------------------------------------------
function HKD.LaunchConfetti()
    local s = HKD.db and HKD.db.settings.confetti
    if not s or not s.enabled then return end

    local profile = INTENSITY[s.intensity] or INTENSITY.normal
    local count   = math.min(profile.count, MAX_PARTICLES)
    local size    = profile.size
    local dur     = tonumber(s.duration) or 2.0
    if dur <= 0 then dur = 2.0 end

    -- Reset all particles first so a rapid double-kill doesn't ghost old ones
    activeCount = 0
    for i = 1, MAX_PARTICLES do
        particles[i].tex:Hide()
        particles[i].active = false
    end

    -- Spawn from the center, slightly above the vertical midpoint
    local cx, cy = 0, 50

    for i = 1, count do
        local p = particles[i]
        local color = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
        p.tex:SetVertexColor(color[1], color[2], color[3])
        p.tex:SetSize(size, size)
        p.tex:ClearAllPoints()
        p.tex:SetPoint("CENTER", confettiFrame, "CENTER", cx, cy)
        p.tex:SetAlpha(1)
        p.tex:Show()

        p.x  = cx + (math.random() - 0.5) * 100
        p.y  = cy
        p.dx = (math.random() - 0.5) * 600
        p.dy = math.random(250, 550)
        p.life    = dur * (0.6 + math.random() * 0.4)
        p.maxLife = p.life
        p.active  = true
        activeCount = activeCount + 1
    end

    confettiFrame:Show()
end

----------------------------------------------------------------------------
-- Sound playback
-- At 100% volume we just call PlaySoundFile.
-- Below that we temporarily adjust the channel's CVar so the relative volume
-- is correct, then restore it after the clip finishes (~3 s headroom).
----------------------------------------------------------------------------
local pendingRestore = {}

local function PlaySoundAtVolume(channel, vol)
    if vol <= 0 then return end
    channel = channel or "Master"

    if vol >= 1.0 then
        PlaySoundFile(SOUND_FILE, channel)
        return
    end

    local cvar = CVAR_MAP[channel]
    if not cvar then
        -- Unknown channel – just play at whatever the current level is
        PlaySoundFile(SOUND_FILE, channel)
        return
    end

    local orig = tonumber(GetCVar(cvar)) or 1.0

    -- Cancel any in-flight restore so rapid calls don't fight each other
    if pendingRestore[cvar] then
        pendingRestore[cvar]:Cancel()
        pendingRestore[cvar] = nil
    end

    local adjusted = orig * vol
    SetCVar(cvar, tostring(adjusted))

    -- Play immediately – SetCVar is synchronous so the engine sees the new
    -- value in the same frame. No defer needed (a defer adds audible lag).
    PlaySoundFile(SOUND_FILE, channel)

    -- Restore after the clip (GruntBirthday ≈ 2 s; 3 s gives headroom)
    pendingRestore[cvar] = C_Timer.NewTicker(3.0, function(ticker)
        ticker:Cancel()
        pendingRestore[cvar] = nil
        local current = tonumber(GetCVar(cvar)) or 0
        if math.abs(current - adjusted) < 0.001 then
            SetCVar(cvar, tostring(orig))
        end
    end, 1)
end

function HKD.PlayKillSound()
    local s = HKD.db and HKD.db.settings.sound
    if not s or not s.enabled then return end
    PlaySoundAtVolume(s.channel, s.volume or 1.0)
end

-- Called by the options panel "Test" buttons
function HKD.TestSound()
    local s = HKD.db and HKD.db.settings.sound
    PlaySoundAtVolume((s and s.channel) or "Master", (s and s.volume) or 1.0)
end

function HKD.TestConfetti()
    local ok, err = pcall(HKD.LaunchConfetti)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff4444Honor Celebration confetti error:|r " .. tostring(err))
    end
end
