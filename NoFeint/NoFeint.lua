local f = CreateFrame("Frame", "FeintAlert", UIParent)
f:SetSize(400, 150)
f:SetPoint("CENTER", 200, 80) 
f:SetFrameStrata("TOOLTIP")

local timerFrame = CreateFrame("Frame", "FeintDurationTracker", UIParent, "BackdropTemplate")
timerFrame:SetSize(37, 37)
timerFrame:SetPoint("CENTER", 0, -100) -- Exact Center
timerFrame:Hide()

timerFrame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8X8", 
    edgeSize = 3,
})
timerFrame:SetBackdropBorderColor(0, 0, 0, 1)

timerFrame.icon = timerFrame:CreateTexture(nil, "BACKGROUND")
timerFrame.icon:SetSize(31, 31)
timerFrame.icon:SetPoint("CENTER")
timerFrame.icon:SetTexture(C_Spell.GetSpellTexture(1966)) -- Feint
timerFrame.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

timerFrame.text = timerFrame:CreateFontString(nil, "OVERLAY")
timerFrame.text:SetFont("Fonts\\expressway.ttf", 16, "OUTLINE")
timerFrame.text:SetPoint("CENTER", 0, 0)
timerFrame.text:SetTextColor(1, 1, 1)

local expirationTime = 0
local soundFolder = [[Interface\AddOns\NoFeint\]]

-- Alert Group Logic (For the Red "NO" Alert)
local function CreateAlertGroup(parent, color)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(200, 40)
    group:SetPoint("CENTER", 0, 0)
    group.prefix = group:CreateFontString(nil, "OVERLAY")
    group.prefix:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
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
    group.timer:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
    group.timer:SetTextColor(color.r, color.g, color.b)
    group.timer:SetPoint("LEFT", group.icon, "RIGHT", 10, 0)
    return group
end

local redAlert = CreateAlertGroup(f, {r=1, g=0, b=0})
local charges, MAX_CHARGES, RECHARGE_TIME, rechargeEndTimes = 2, 2, 15, {}
local playedNoFeintSound = false

f:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
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
        redAlert:Hide()
        playedNoFeintSound = false 
    end

    local timeLeft = expirationTime - now
    if timeLeft > 0 then timerFrame.text:SetText(string.format("%.1f", timeLeft)) else timerFrame:Hide() end
end)

f:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == 1966 then
        expirationTime = GetTime() + 6
        timerFrame:Show()
        charges = math.max(0, charges - 1)
        local thisRechargeEnd = (#rechargeEndTimes > 0 and rechargeEndTimes[#rechargeEndTimes] or GetTime()) + RECHARGE_TIME
        table.insert(rechargeEndTimes, thisRechargeEnd)
        C_Timer.After(thisRechargeEnd - GetTime(), function()
            charges = math.min(MAX_CHARGES, charges + 1)
            if #rechargeEndTimes > 0 then table.remove(rechargeEndTimes, 1) end
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        charges, rechargeEndTimes, expirationTime = 2, {}, 0
    end
end)
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")