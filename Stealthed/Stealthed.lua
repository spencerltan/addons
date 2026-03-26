local f = CreateFrame("Frame", "StealthAlert", UIParent)
f:SetSize(400, 100)
f:SetPoint("CENTER", 0, 80)
f:SetFrameStrata("TOOLTIP")

-- Text
local text = f:CreateFontString(nil, "OVERLAY")
text:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
text:SetPoint("CENTER")
text:SetTextColor(0, 1, 0)
text:SetText("Stealthed")
text:Hide()

-- Bounce animation
local ag = text:CreateAnimationGroup()
local up = ag:CreateAnimation("Translation")
up:SetOffset(0, 10)
up:SetDuration(0.2)
up:SetSmoothing("IN_OUT")
up:SetOrder(1)

local down = ag:CreateAnimation("Translation")
down:SetOffset(0, -10)
down:SetDuration(0.2)
down:SetSmoothing("IN_OUT")
down:SetOrder(2)

ag:SetLooping("REPEAT")

local function Update()
    -- Using the direct engine check instead of aura scanning
    local isStealthed = IsStealthed()

    if isStealthed then
        if not text:IsShown() then
            text:Show()
            ag:Play()
        end
    else
        if text:IsShown() then
            text:Hide()
            ag:Stop()
        end
    end
end

-- UPDATE_STEALTH is the perfect event for this
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_STEALTH")

f:SetScript("OnEvent", function(self, event)
    Update()
end)

-- Initial check in case you load in already stealthed
Update()