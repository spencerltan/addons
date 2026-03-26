local f = CreateFrame("Frame", "CombatTransitionAlert", UIParent)
f:SetSize(400, 100)
f:SetPoint("CENTER", 0, 150) -- Adjusted height so it doesn't overlap your stealth text
f:SetFrameStrata("TOOLTIP")

local function CreateBouncingText(parent, label, color)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\expressway.ttf", 36, "OUTLINE")
    t:SetPoint("CENTER")
    t:SetTextColor(color.r, color.g, color.b)
    t:SetText(label)
    t:Hide()

    local ag = t:CreateAnimationGroup()
    local up = ag:CreateAnimation("Translation")
    up:SetOffset(0, 15)
    up:SetDuration(0.2)
    up:SetSmoothing("IN_OUT")
    up:SetOrder(1)

    local down = ag:CreateAnimation("Translation")
    down:SetOffset(0, -15)
    down:SetDuration(0.2)
    down:SetSmoothing("IN_OUT")
    down:SetOrder(2)

    ag:SetLooping("REPEAT")
    
    return t, ag
end

local enterText, enterAnim = CreateBouncingText(f, "+Entering Combat", {r=1, g=0, b=0})
local exitText, exitAnim = CreateBouncingText(f, "+Exiting Combat", {r=0, g=1, b=0})

local function ShowAlert(text, anim)
    -- Hide both first to prevent overlapping if you spam combat in/out
    enterText:Hide()
    enterAnim:Stop()
    exitText:Hide()
    exitAnim:Stop()

    -- Show the requested one
    text:Show()
    anim:Play()

    -- Automatically hide after 2 seconds
    C_Timer.After(2, function()
        text:Hide()
        anim:Stop()
    end)
end

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        ShowAlert(enterText, enterAnim)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ShowAlert(exitText, exitAnim)
    end
end)

f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Test commands
SLASH_COMBATTEST1 = "/testcombat"
SlashCmdList["COMBATTEST"] = function(msg)
    if msg == "in" then
        ShowAlert(enterText, enterAnim)
    else
        ShowAlert(exitText, exitAnim)
    end
end