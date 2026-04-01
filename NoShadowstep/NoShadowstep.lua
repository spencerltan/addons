local f = CreateFrame("Frame", "ShadowstepAlert", UIParent)
f:SetSize(400, 100)
f:SetPoint("CENTER", -200, 80) -- 200px to the left
f:SetFrameStrata("TOOLTIP")

-- Audio setup
local soundFolder = [[Interface\AddOns\NoShadowstep\]]
local playedNoShadowstepSound = false

-- Function to create the "NO [ICON]" group
local function CreateMissingGroup(parent, color)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(250, 40)
    group:SetPoint("CENTER", 0, 0)
    
    -- 1. "NO" Text
    group.prefix = group:CreateFontString(nil, "OVERLAY")
    group.prefix:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
    group.prefix:SetTextColor(color.r, color.g, color.b)
    group.prefix:SetText("NO")
    group.prefix:SetPoint("LEFT", 0, 0)
    
    -- 2. The Icon
    group.icon = CreateFrame("Frame", nil, group, "BackdropTemplate")
    group.icon:SetSize(36, 36)
    group.icon:SetPoint("LEFT", group.prefix, "RIGHT", 10, 0)
    group.icon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8", 
        edgeSize = 2,
    })
    group.icon:SetBackdropBorderColor(0, 0, 0, 1)
    
    local tex = group.icon:CreateTexture(nil, "OVERLAY")
    tex:SetSize(34, 34)
    tex:SetPoint("CENTER")
    tex:SetTexture(C_Spell.GetSpellTexture(36554)) -- Shadowstep ID
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- 3. The Countdown Text
    group.timer = group:CreateFontString(nil, "OVERLAY")
    group.timer:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
    group.timer:SetTextColor(color.r, color.g, color.b)
    group.timer:SetPoint("LEFT", group.icon, "RIGHT", 10, 0)
    
    return group
end

local redAlert = CreateMissingGroup(f, {r=1, g=0, b=0})
redAlert:Hide()

local charges = 2
local MAX_CHARGES = 2
local RECHARGE_TIME = 30
local rechargeEndTimes = {}

f:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()

    -- Only show when out of charges
    if charges <= 0 then
        redAlert:Show()
        
        -- TTS Logic: Play sound once when charges hit 0
        if not playedNoShadowstepSound then
            playedNoShadowstepSound = true
            PlaySoundFile(soundFolder .. "noshadowstep.ogg", "Master")
        end

        if #rechargeEndTimes > 0 then
            local firstRecharge = rechargeEndTimes[1]
            redAlert.timer:SetText(string.format("- %.1f", math.max(0, firstRecharge - now)))
        else
            redAlert.timer:SetText("")
        end
    else
        redAlert:Hide()
        playedNoShadowstepSound = false -- Reset flag so it can play again next time
    end
end)

f:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == 36554 then
        local now = GetTime()
        charges = math.max(0, charges - 1)
        
        local thisRechargeEnd = (#rechargeEndTimes > 0 and rechargeEndTimes[#rechargeEndTimes] or now) + RECHARGE_TIME
        table.insert(rechargeEndTimes, thisRechargeEnd)

        C_Timer.After(thisRechargeEnd - now, function()
            charges = math.min(MAX_CHARGES, charges + 1)
            if #rechargeEndTimes > 0 then table.remove(rechargeEndTimes, 1) end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        charges = MAX_CHARGES
        rechargeEndTimes = {}
        playedNoShadowstepSound = false
    end
end)

f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")