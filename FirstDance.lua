local f = CreateFrame("Frame", "FirstDanceAlert", UIParent)
f:SetSize(400, 100)
f:SetPoint("CENTER", 0, 200) 
f:SetFrameStrata("TOOLTIP")

local BUFF_ID = 470677
local buffEnd = 0

local function CreateActiveGroup(parent, color)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(250, 40)
    group:SetPoint("CENTER", 0, 0)
    
    group.icon = CreateFrame("Frame", nil, group, "BackdropTemplate")
    group.icon:SetSize(36, 36)
    group.icon:SetPoint("LEFT", 45, 0)
    group.icon:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8", 
        edgeSize = 2,
    })
    group.icon:SetBackdropBorderColor(0, 0, 0, 1)
    
    local tex = group.icon:CreateTexture(nil, "OVERLAY")
    tex:SetSize(34, 34)
    tex:SetPoint("CENTER")
    tex:SetTexture(C_Spell.GetSpellTexture(BUFF_ID)) 
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    group.timer = group:CreateFontString(nil, "OVERLAY")
    group.timer:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
    group.timer:SetTextColor(color.r, color.g, color.b)
    group.timer:SetPoint("LEFT", group.icon, "RIGHT", 10, 0)
    
    return group
end

local greenAlert = CreateActiveGroup(f, {r=0, g=1, b=0})

f:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if buffEnd > now then
        local remaining = buffEnd - now
        greenAlert:Show()
        greenAlert.timer:SetText(string.format("- %.1f", remaining))
    else
        greenAlert:Hide()
        buffEnd = 0
    end
end)

f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        -- Start 6s timer as soon as combat ends
        buffEnd = GetTime() + 6
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" then
        -- Clear timer if we re-enter combat or load a zone
        buffEnd = 0
        greenAlert:Hide()
    end
end)

f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Test command
SLASH_FIRSTDANCE1 = "/testdance"
SlashCmdList["FIRSTDANCE"] = function()
    buffEnd = GetTime() + 6
end