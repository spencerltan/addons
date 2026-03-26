local f = CreateFrame("Frame", "ShroudAlert", UIParent)
f:SetSize(400, 100)
f:SetPoint("CENTER", 0, 200) 
f:SetFrameStrata("TOOLTIP")

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
    tex:SetTexture(C_Spell.GetSpellTexture(114018)) 
    tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    
    group.timer = group:CreateFontString(nil, "OVERLAY")
    group.timer:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
    group.timer:SetTextColor(color.r, color.g, color.b)
    group.timer:SetPoint("LEFT", group.icon, "RIGHT", 10, 0)
    
    return group
end

local greenAlert = CreateActiveGroup(f, {r=0, g=1, b=0})
local buffEnd = 0
local lastThreshold = -1 

local function GetChatChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

local function SendShroudMsg(msg)
    local chat = GetChatChannel()
    if chat then
        SendChatMessage(msg, chat)
    end
end

-- Function to kill the countdown immediately
local function KillShroud()
    if buffEnd > 0 then
        SendShroudMsg(">>SHROUD DOWN (COMBAT)<<")
        buffEnd = 0
        lastThreshold = -1
        greenAlert:Hide()
    end
end

f:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    if buffEnd > now then
        local remaining = buffEnd - now
        local floorSeconds = math.ceil(remaining)
        
        greenAlert:Show()
        greenAlert.timer:SetText(string.format("- %.1f", remaining))

        if floorSeconds ~= lastThreshold then
            if lastThreshold == -1 then
                SendShroudMsg(">>SHROUD UP<<")
            end
            
            if floorSeconds > 0 and floorSeconds <= 15 then
                SendShroudMsg("SHROUD ENDING IN >>" .. floorSeconds .. "<<")
            end
            
            lastThreshold = floorSeconds
        end
    elseif lastThreshold ~= -1 then
        SendShroudMsg(">>SHROUD DOWN<<")
        greenAlert:Hide()
        lastThreshold = -1
        buffEnd = 0
    else
        greenAlert:Hide()
    end
end)

f:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        if spellID == 114018 or spellID == 423662 then
            buffEnd = GetTime() + 15
            lastThreshold = -1 
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- This triggers the moment you enter combat
        KillShroud()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        buffEnd = 0
        lastThreshold = -1
        greenAlert:Hide()
    end
end)

f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED") -- New event for combat start

-- Test command
SLASH_TESTSHROUD1 = "/testshroud"
SlashCmdList["TESTSHROUD"] = function()
    buffEnd = GetTime() + 15
    lastThreshold = -1
end