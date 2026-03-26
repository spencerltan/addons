local f = CreateFrame("Frame", "SprintAlert", UIParent)
f:SetSize(400, 100)
-- Matches Feint's X (200). Adjusting Y to -20 to sit below it.
f:SetPoint("CENTER", 200, -20) 
f:SetFrameStrata("TOOLTIP")

-- Function to create the Green Styled Group
local function CreateActiveGroup(parent, color)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(200, 40)
    group:SetPoint("CENTER", 0, 0)
    
    -- 1. The Icon (Centered in the group)
    group.icon = CreateFrame("Frame", nil, group, "BackdropTemplate")
    group.icon:SetSize(36, 36)
    group.icon:SetPoint("CENTER", -40, 0) -- Nudges icon left to make room for text
    group.icon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8", 
        edgeSize = 2,
    })
    group.icon:SetBackdropBorderColor(0, 0, 0, 1)
    
    local tex = group.icon:CreateTexture(nil, "OVERLAY")
    tex:SetSize(34, 34)
    tex:SetPoint("CENTER")
    tex:SetTexture(C_Spell.GetSpellTexture(2983)) 
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    -- 2. The Countdown Text
    group.timer = group:CreateFontString(nil, "OVERLAY")
    group.timer:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
    group.timer:SetTextColor(color.r, color.g, color.b)
    group.timer:SetPoint("LEFT", group.icon, "RIGHT", 10, 0)
    
    return group
end

local greenAlert = CreateActiveGroup(f, {r=0, g=1, b=0})
local buffEnd = 0

f:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if buffEnd > now then
        greenAlert:Show()
        greenAlert.timer:SetText(string.format("- %.1f", buffEnd - now))
    else
        greenAlert:Hide()
    end
end)

f:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == 2983 then
        buffEnd = GetTime() + 8
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        buffEnd = 0
    end
end)

f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")