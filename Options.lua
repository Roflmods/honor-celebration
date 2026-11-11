local _, HKD = ...

----------------------------------------------------------------------------
-- Options panel – registered in ESC → Options → AddOns
----------------------------------------------------------------------------

local panel, category

----------------------------------------------------------------------------
-- Layout constants
----------------------------------------------------------------------------
local LABEL_COLOR = "|cffc0a060"
local SECTION_GAP = -18
local ITEM_GAP    = -4
local NEST_INDENT = 20
local LABEL_INSET = 26

local function Place(frame, anchor, yOff, x)
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x - (anchor.olbX or 0), yOff)
    frame.olbX = x
end

----------------------------------------------------------------------------
-- Widget factory helpers (self-contained – no dependency on OlympusLeaderboard)
----------------------------------------------------------------------------

local function SectionLabel(parent, text, anchor, yOff)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    Place(fs, anchor, yOff or SECTION_GAP, 0)
    fs:SetText(LABEL_COLOR .. text .. "|r")
    return fs
end

local function MakeCheck(parent, text, anchor, yOff, getter, setter, indent)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    Place(c, anchor, yOff or ITEM_GAP, indent or 0)
    local label = c.Text or c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetText(text)
    label:SetPoint("LEFT", c, "RIGHT", 2, 1)
    c.label = label
    c.Refresh = function()
        c:SetChecked(getter())
    end
    c:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    c:Refresh()
    c.SetGroupEnabled = function(enabled)
        c:SetEnabled(enabled)
        c:SetAlpha(enabled and 1.0 or 0.4)
    end
    return c
end

local function MakeDropdown(parent, label, anchor, yOff, width, options, getter, setter, indent)
    local dd = CreateFrame("Frame", nil, parent)
    Place(dd, anchor, yOff or ITEM_GAP, indent or 0)
    dd:SetSize(width + 140, 26)

    local lbl = dd:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("LEFT", LABEL_INSET, 0)
    lbl:SetText(label)

    local btn = CreateFrame("Button", nil, dd)
    btn:SetSize(width, 22)
    btn:SetPoint("LEFT", lbl, "RIGHT", 8, 0)

    -- Button background
    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    btnBg:SetVertexColor(0.16, 0.17, 0.21, 0.8)

    local inner = CreateFrame("Frame", nil, btn)
    inner:SetPoint("TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", -1, 1)
    local innerBg = inner:CreateTexture(nil, "BACKGROUND")
    innerBg:SetAllPoints()
    innerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    innerBg:SetVertexColor(0.09, 0.09, 0.12, 0.9)

    local btnText = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btnText:SetPoint("CENTER")
    btn.label = btnText

    local arrow = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetText("\226\150\188")

    -- Drop-down list
    local menuFrame = CreateFrame("Frame", nil, btn)
    menuFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menuFrame:SetWidth(width)
    menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    menuFrame:Hide()

    local menuBg = menuFrame:CreateTexture(nil, "BACKGROUND")
    menuBg:SetAllPoints()
    menuBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    menuBg:SetVertexColor(0.06, 0.06, 0.09, 0.95)

    local menuBorder = menuFrame:CreateTexture(nil, "BORDER")
    menuBorder:SetPoint("TOPLEFT", -1, 1)
    menuBorder:SetPoint("BOTTOMRIGHT", 1, -1)
    menuBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    menuBorder:SetVertexColor(0.38, 0.40, 0.48, 0.8)

    local menuH = 0
    for i, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, menuFrame)
        item:SetSize(width - 2, 20)
        item:SetPoint("TOPLEFT", 1, -(i - 1) * 20 - 1)

        local itemText = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        itemText:SetPoint("LEFT", 6, 0)
        itemText:SetText(opt.label or opt.value)

        local itemHl = item:CreateTexture(nil, "HIGHLIGHT")
        itemHl:SetAllPoints()
        itemHl:SetTexture("Interface\\Buttons\\WHITE8x8")
        itemHl:SetVertexColor(0.28, 0.35, 0.50, 0.3)

        item:SetScript("OnClick", function()
            setter(opt.value)
            btnText:SetText(opt.label or opt.value)
            menuFrame:Hide()
        end)
        menuH = menuH + 20
    end
    menuFrame:SetHeight(menuH + 2)

    btn:SetScript("OnClick", function()
        if menuFrame:IsShown() then menuFrame:Hide() else menuFrame:Show() end
    end)

    dd.Refresh = function()
        local val = getter()
        for _, opt in ipairs(options) do
            if opt.value == val then
                btnText:SetText(opt.label or opt.value)
                return
            end
        end
        btnText:SetText(tostring(val))
    end
    dd:Refresh()

    dd.button = btn
    dd.SetGroupEnabled = function(enabled)
        btn:EnableMouse(enabled)
        dd:SetAlpha(enabled and 1.0 or 0.4)
        if not enabled then menuFrame:Hide() end
    end
    return dd
end

local function MakeSlider(parent, label, anchor, yOff, minVal, maxVal, step, getter, setter, fmt, indent)
    local container = CreateFrame("Frame", nil, parent)
    Place(container, anchor, yOff or SECTION_GAP, indent or 0)
    container:SetSize(280, 36)

    local lbl = container:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", LABEL_INSET, 0)
    lbl:SetText(label)

    local valText = container:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valText:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, container)
    slider:SetPoint("TOPLEFT", LABEL_INSET, -14)
    slider:SetSize(220, 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:EnableMouseWheel(true)

    local bgTex = slider:CreateTexture(nil, "BACKGROUND")
    bgTex:SetPoint("LEFT", 0, 0)
    bgTex:SetPoint("RIGHT", 0, 0)
    bgTex:SetHeight(8)
    bgTex:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(16, 16)
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnValueChanged", function(self, val)
        val = math.floor(val / step + 0.5) * step
        setter(val)
        valText:SetText(fmt and fmt(val) or tostring(val))
    end)

    slider:SetScript("OnMouseWheel", function(self, delta)
        local val = self:GetValue() + (delta > 0 and step or -step)
        val = math.max(minVal, math.min(maxVal, val))
        self:SetValue(val)
    end)

    container.Refresh = function()
        local val = getter()
        slider:SetValue(val)
        valText:SetText(fmt and fmt(val) or tostring(val))
    end
    container:Refresh()

    container.SetGroupEnabled = function(enabled)
        slider:EnableMouse(enabled)
        slider:EnableMouseWheel(enabled)
        container:SetAlpha(enabled and 1.0 or 0.4)
    end
    return container
end

local function MakeButton(parent, text, width, anchor, yOff, onClick, indent)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    Place(btn, anchor, yOff or ITEM_GAP, (indent or 0) + LABEL_INSET)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    btn.SetGroupEnabled = function(enabled)
        btn:SetEnabled(enabled)
        btn:SetAlpha(enabled and 1.0 or 0.4)
    end
    return btn
end

local function MakeNote(parent, text, anchor, yOff, indent)
    local wrapper = CreateFrame("Frame", nil, parent)
    Place(wrapper, anchor, yOff or -2, (indent or 0) + LABEL_INSET)
    wrapper:SetSize(430, 28)
    local fs = wrapper:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT")
    fs:SetWidth(400)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    wrapper.SetGroupEnabled = function(enabled)
        wrapper:SetAlpha(enabled and 1.0 or 0.4)
    end
    return wrapper
end

-- Gray-out child widgets when their parent checkbox is unchecked
local function NestUnder(parentCheck, children)
    local function Update()
        local on = parentCheck:GetChecked()
        for _, child in ipairs(children) do
            if child.SetGroupEnabled then child:SetGroupEnabled(on) end
        end
    end
    parentCheck:HookScript("OnClick", Update)
    local origRefresh = parentCheck.Refresh
    parentCheck.Refresh = function()
        origRefresh()
        Update()
    end
    Update()
end

----------------------------------------------------------------------------
-- Build the panel
----------------------------------------------------------------------------
local refreshFuncs = {}

local function CreatePanel()
    panel = CreateFrame("Frame")
    panel.name = "Honor Celebration"

    -- Scroll frame so it works at any UI scale
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -6, 4)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(540, 1)
    scroll:SetScrollChild(content)

    local scrollBar = CreateFrame("Slider", nil, scroll)
    scrollBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -20)
    scrollBar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 20)
    scrollBar:SetWidth(14)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)

    local sbThumb = scrollBar:CreateTexture(nil, "ARTWORK")
    sbThumb:SetSize(14, 24)
    sbThumb:SetTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    scrollBar:SetThumbTexture(sbThumb)

    local sbBg = scrollBar:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints()
    sbBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    sbBg:SetVertexColor(0, 0, 0, 0.15)

    scrollBar:SetScript("OnValueChanged", function(self, val)
        scroll:SetVerticalScroll(val)
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = scrollBar:GetValue()
        local _, maxVal = scrollBar:GetMinMaxValues()
        scrollBar:SetValue(math.max(0, math.min(maxVal, cur - delta * 40)))
    end)

    content:SetScript("OnSizeChanged", function(self)
        local contentH = self:GetHeight()
        local viewH    = scroll:GetHeight()
        local maxScroll = math.max(0, contentH - viewH)
        scrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then scrollBar:Hide() else scrollBar:Show() end
    end)

    content:SetScript("OnShow", function(self)
        self:SetWidth(scroll:GetWidth() - 20)
    end)

    local s = function() return HKD.db.settings end

    -- ── Title ──────────────────────────────────────────────────────────
    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Honor Celebration v" .. HKD.VERSION)

    local desc = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")
    desc:SetText("Sound and confetti on every Honor Kill – no guild checks, no conditions.")

    local lastAnchor = desc

    -- ── Enable toggle ──────────────────────────────────────────────────
    local enableAll = MakeCheck(content, "Enable Honor Celebration", lastAnchor, SECTION_GAP - 4,
        function() return s().enabled end,
        function(v) s().enabled = v end)
    refreshFuncs[#refreshFuncs + 1] = enableAll
    lastAnchor = enableAll

    -- ══════════════════════ Sound Settings ════════════════════════════

    local sndSec = SectionLabel(content, "Sound", lastAnchor, SECTION_GAP - 4)

    local sndEnable = MakeCheck(content, "Enable kill sound", sndSec, ITEM_GAP,
        function() return s().sound.enabled end,
        function(v) s().sound.enabled = v end)
    refreshFuncs[#refreshFuncs + 1] = sndEnable

    -- Channel dropdown
    local channelOptions = {
        { value = "Master",   label = "Master"         },
        { value = "SFX",      label = "Sound Effects"  },
        { value = "Music",    label = "Music"           },
        { value = "Ambience", label = "Ambience"        },
        { value = "Dialog",   label = "Dialog"          },
    }
    local sndChannel = MakeDropdown(content, "Sound Channel:", sndEnable, ITEM_GAP - 4, 130,
        channelOptions,
        function() return s().sound.channel end,
        function(v) s().sound.channel = v end,
        NEST_INDENT)
    refreshFuncs[#refreshFuncs + 1] = sndChannel

    -- Volume slider (0–100 %)
    local sndVolume = MakeSlider(content, "Volume:", sndChannel, ITEM_GAP - 6,
        0, 100, 5,
        function() return (s().sound.volume or 1.0) * 100 end,
        function(v) s().sound.volume = v / 100 end,
        function(v) return tostring(math.floor(v)) .. "%" end,
        NEST_INDENT)
    refreshFuncs[#refreshFuncs + 1] = sndVolume

    local sndVolNote = MakeNote(content,
        "|cff888888Below 100% the selected channel is briefly quieted while the sound plays. "
        .. "Pick a less-used channel (e.g. Dialog) to avoid affecting other game sounds.|r",
        sndVolume, -2, NEST_INDENT)

    -- Test button
    local sndTest = MakeButton(content, "Test Sound", 90, sndVolNote, ITEM_GAP, function()
        HKD.TestSound()
    end, NEST_INDENT)

    NestUnder(sndEnable, { sndChannel, sndVolume, sndVolNote, sndTest })
    lastAnchor = sndTest

    -- ══════════════════════ Confetti Settings ════════════════════════

    local visSec = SectionLabel(content, "Confetti", lastAnchor, SECTION_GAP - 4)

    local visEnable = MakeCheck(content, "Enable confetti effect", visSec, ITEM_GAP,
        function() return s().confetti.enabled end,
        function(v) s().confetti.enabled = v end)
    refreshFuncs[#refreshFuncs + 1] = visEnable

    -- Intensity dropdown
    local intensityOptions = {
        { value = "subtle", label = "Subtle"              },
        { value = "normal", label = "Normal"              },
        { value = "party",  label = "Party Mode \240\159\142\137" },
    }
    local visIntensity = MakeDropdown(content, "Intensity:", visEnable, ITEM_GAP - 4, 130,
        intensityOptions,
        function() return s().confetti.intensity end,
        function(v) s().confetti.intensity = v end,
        NEST_INDENT)
    refreshFuncs[#refreshFuncs + 1] = visIntensity

    -- Duration slider (0.5 – 5.0 s)
    local visDur = MakeSlider(content, "Duration:", visIntensity, ITEM_GAP - 6,
        0.5, 5.0, 0.5,
        function() return s().confetti.duration end,
        function(v) s().confetti.duration = v end,
        function(v) return string.format("%.1f s", v) end,
        NEST_INDENT)
    refreshFuncs[#refreshFuncs + 1] = visDur

    -- Test button
    local visTest = MakeButton(content, "Test Confetti", 110, visDur, ITEM_GAP, function()
        HKD.TestConfetti()
    end, NEST_INDENT)

    NestUnder(visEnable, { visIntensity, visDur, visTest })
    lastAnchor = visTest

    -- ── Bottom spacer (lets the scroll frame size correctly) ───────────
    local spacer = CreateFrame("Frame", nil, content)
    spacer:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -20)
    spacer:SetSize(1, 40)
    spacer:SetScript("OnShow", function()
        local top    = content:GetTop()
        local bottom = spacer:GetBottom()
        if top and bottom then
            content:SetHeight(top - bottom + 20)
        else
            content:SetHeight(600)
        end
    end)
    content:SetHeight(600)

    -- Refresh all controls whenever the panel opens
    panel.Refresh = function()
        for _, rf in ipairs(refreshFuncs) do
            if rf.Refresh then rf:Refresh() end
        end
    end
    panel:SetScript("OnShow", panel.Refresh)

    -- Register with the game's options system
    local ok, err
    if Settings and Settings.RegisterCanvasLayoutCategory then
        ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, panel.name)
        if ok and category then
            ok, err = pcall(Settings.RegisterAddOnCategory, category)
            if not ok then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Honor Celebration:|r Settings.RegisterAddOnCategory: " .. tostring(err))
            end
        else
            category = nil
        end
    elseif InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end
end

function HKD.OpenOptions()
    if not panel then return end
    if Settings and Settings.OpenToCategory and category then
        local ok = pcall(Settings.OpenToCategory, category.GetID and category:GetID() or category.ID)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff8800Honor Celebration:|r Can't open options right now (try outside combat).")
        end
    elseif InterfaceOptionsFrame_OpenToCategory and panel then
        pcall(InterfaceOptionsFrame_OpenToCategory, panel)
        pcall(InterfaceOptionsFrame_OpenToCategory, panel)
    end
end

-- Build the panel on PLAYER_LOGIN.
-- This fires after every ADDON_LOADED has run, so Core.lua has already
-- populated HKD.db and HKD.ready. Far more reliable than deferring inside
-- ADDON_LOADED (C_Timer can be unstable that early on classic clients).
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    CreatePanel()
end)
