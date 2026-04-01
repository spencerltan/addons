local addonName = "RogueDurationManager"
local f = CreateFrame("Frame", addonName, UIParent)
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_STATS")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")

-- CONFIGURATION
local ICON_SIZE, SPACING, FONT, Y_OFFSET = 37, 5, "Fonts\\expressway.ttf", -100
local soundFolder = [[Interface\AddOns\NoFeint\]]
local lastCombatExit = GetTime() 
local firstDanceAvailable = true 

-- 1. NO-FEINT RED ALERT FRAME
local alertFrame = CreateFrame("Frame", "FeintAlert", UIParent, "BackdropTemplate")
alertFrame:SetSize(400, 150)
alertFrame:SetPoint("CENTER", 200, 80)
alertFrame:SetFrameStrata("TOOLTIP")

local function CreateAlertGroup(parent, color)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(200, 40)
    group:SetPoint("CENTER", 0, 0)
    group.prefix = group:CreateFontString(nil, "OVERLAY")
    group.prefix:SetFont(FONT, 32, "OUTLINE")
    group.prefix:SetTextColor(color.r, color.g, color.b)
    group.prefix:SetText("NO")
    group.prefix:SetPoint("LEFT", 0, 0)
    group.icon = CreateFrame("Frame", nil, group, "BackdropTemplate")
    group.icon:SetSize(36, 36)
    group.icon:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
    group.icon:SetBackdropBorderColor(0, 0, 0, 1)
    group.icon:SetPoint("LEFT", group.prefix, "RIGHT", 10, 0)
    local tex = group.icon:CreateTexture(nil, "OVERLAY")
    tex:SetSize(34, 34)
    tex:SetPoint("CENTER")
    tex:SetTexture(C_Spell.GetSpellTexture(1966))
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    group.timer = group:CreateFontString(nil, "OVERLAY")
    group.timer:SetFont(FONT, 32, "OUTLINE")
    group.timer:SetTextColor(color.r, color.g, color.b)
    group.timer:SetPoint("LEFT", group.icon, "RIGHT", 10, 0)
    return group
end

local redAlert = CreateAlertGroup(alertFrame, {r=1, g=0, b=0})
local charges, MAX_CHARGES, rechargeEndTimes, playedNoFeintSound = 2, 2, {}, false

-- 2. DYNAMIC ICON TRACKING
local trackedSpells = {
    [185313] = { sortOrder = 1, fallback = 6, syncID = 185422 }, -- Shadow Dance
    [121471] = { sortOrder = 2, fallback = 20 }, -- Shadow Blades
    [1966]   = { sortOrder = 3, fallback = 6  }, -- Feint
    [5277]   = { sortOrder = 4, fallback = 10 }, -- Evasion
    [31224]  = { sortOrder = 5, fallback = 5  }, -- Cloak
    [2983]   = { sortOrder = 6, fallback = 8  }, -- Sprint
    [114018] = { sortOrder = 7, fallback = 15 }, -- Shroud
}

local activeIcons = {}

-- 3. LOGIC
local function GetShadowDanceDuration()
    local currentHaste = GetHaste() / 100
    local isFirst = false
    local base = 6.0 
    
    if IsPlayerSpell(382505) and firstDanceAvailable then
        local timeSinceExit = GetTime() - lastCombatExit
        if not InCombatLockdown() or timeSinceExit >= 6 then
            isFirst = true
            base = 9.0 -- Correct base for First Dance
            firstDanceAvailable = false 
        end
    end

    -- 1.25 multiplier verified across all test cases
    local finalDuration = base * (1 + (currentHaste * 1.25))

    print("|cff00ff00[RogueTracker]|r First Dance: " .. (isFirst and "YES" or "NO") .. 
          " | Base: " .. base .. "s | Calc: " .. string.format("%.1fs", finalDuration))
    
    return finalDuration
end

local function SyncAura(id)
    local icon = activeIcons[id]
    if not icon then return end
    local syncID = trackedSpells[id].syncID or id
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(syncID)
    if aura and aura.expirationTime > 0 then icon.expires = aura.expirationTime end
end

local function CreateIcon(spellID, data)
    local icon = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3})
    icon:SetBackdropBorderColor(0, 0, 0, 1)
    icon.tex = icon:CreateTexture(nil, "BACKGROUND")
    icon.tex:SetSize(ICON_SIZE-6, ICON_SIZE-6)
    icon.tex:SetPoint("CENTER")
    icon.tex:SetTexture(C_Spell.GetSpellTexture(spellID))
    icon.tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    icon.text = icon:CreateFontString(nil, "OVERLAY")
    icon.text:SetFont(FONT, 16, "OUTLINE")
    icon.text:SetTextColor(0, 1, 0) 
    icon.text:SetPoint("CENTER", 0, 0)
    icon.sortOrder = data.sortOrder
    return icon
end

local function UpdateLayout()
    local temp = {}
    for _, icon in pairs(activeIcons) do if icon:IsShown() then table.insert(temp, icon) end end
    table.sort(temp, function(a, b) return a.sortOrder < b.sortOrder end)
    local count = #temp
    if count == 0 then return end
    local totalWidth = (count * ICON_SIZE) + ((count - 1) * SPACING)
    local startOffset = -(totalWidth / 2) + (ICON_SIZE / 2)
    for i, icon in ipairs(temp) do
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", UIParent, "CENTER", startOffset + ((i-1) * (ICON_SIZE + SPACING)), Y_OFFSET)
    end
end

f:SetScript("OnUpdate", function()
    local now = GetTime()
    
    -- Update Red Alert / "No Feint" Countdown
    if charges <= 0 then
        redAlert:Show()
        if not playedNoFeintSound then 
            playedNoFeintSound = true 
            PlaySoundFile(soundFolder .. "nofeint.ogg", "Master") 
        end
        if #rechargeEndTimes > 0 then 
            redAlert.timer:SetText(string.format("- %.1f", math.max(0, rechargeEndTimes[1] - now))) 
        end
    else
        redAlert:Hide(); playedNoFeintSound = false
    end

    -- Update Active Duration Icons
    local changed = false
    for id, icon in pairs(activeIcons) do
        if icon:IsShown() then
            local left = (icon.expires or 0) - now
            if left <= 0 then icon:Hide(); changed = true 
            else icon.text:SetText(string.format("%.1f", left)) end
        end
    end
    if changed then UpdateLayout() end
end)

f:SetScript("OnEvent", function(self, event, unit, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        charges, rechargeEndTimes = 2, {}
        for _, icon in pairs(activeIcons) do icon:Hide() end
        firstDanceAvailable = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        lastCombatExit = GetTime(); firstDanceAvailable = true 
    elseif event == "UNIT_STATS" and unit == "player" then
        if activeIcons[185313] and activeIcons[185313]:IsShown() then SyncAura(185313) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        local id = select(2, ...)
        
        -- Feint Charge Logic
        if id == 1966 then
            charges = math.max(0, charges - 1)
            local thisRechargeEnd = (#rechargeEndTimes > 0 and rechargeEndTimes[#rechargeEndTimes] or GetTime()) + 15
            table.insert(rechargeEndTimes, thisRechargeEnd)
            C_Timer.After(thisRechargeEnd - GetTime(), function() 
                charges = math.min(MAX_CHARGES, charges + 1)
                if #rechargeEndTimes > 0 then table.remove(rechargeEndTimes, 1) end
            end)
        end

        -- Icon Tracking Logic
        local data = trackedSpells[id]
        if data then
            if not activeIcons[id] then activeIcons[id] = CreateIcon(id, data) end
            local icon = activeIcons[id]
            icon.expires = GetTime() + (id == 185313 and GetShadowDanceDuration() or data.fallback)
            icon:Show(); UpdateLayout(); SyncAura(id)
        end
    elseif event == "UNIT_AURA" and unit == "player" then
        for id, _ in pairs(trackedSpells) do if activeIcons[id] and activeIcons[id]:IsShown() then SyncAura(id) end end
    end
end)

SLASH_ROGUETEST1 = "/roguetest"
SlashCmdList["ROGUETEST"] = function()
    firstDanceAvailable = true
    for id, data in pairs(trackedSpells) do f:GetScript("OnEvent")(f, "UNIT_SPELLCAST_SUCCEEDED", "player", nil, id) end
end