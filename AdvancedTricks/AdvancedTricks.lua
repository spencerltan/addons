local t = CreateFrame("Frame")
local lastTank = "" 

-------------------------------------------------------
-- 1. THE FLASH UI (Red, High Position, No Brackets)
-------------------------------------------------------
local flash = CreateFrame("Frame", "TricksFlashAlert", UIParent, "BackdropTemplate")
flash:SetSize(400, 50)
flash:SetPoint("CENTER", 0, 350) 
flash:Hide()

-- The Icon
flash.icon = CreateFrame("Frame", nil, flash, "BackdropTemplate")
flash.icon:SetSize(36, 36)
flash.icon:SetPoint("LEFT", 0, 0)
flash.icon:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8X8", 
    edgeSize = 2,
})
flash.icon:SetBackdropBorderColor(0, 0, 0, 1)

local tex = flash.icon:CreateTexture(nil, "OVERLAY")
tex:SetSize(34, 34)
tex:SetPoint("CENTER")
tex:SetTexture(C_Spell.GetSpellTexture(57934)) 
tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)

-- The Text (Pure Red)
flash.text = flash:CreateFontString(nil, "OVERLAY")
flash.text:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
flash.text:SetTextColor(1, 0, 0) -- Pure Red
flash.text:SetPoint("LEFT", flash.icon, "RIGHT", 10, 0)

-- Clean format: - Name
local function ShowTricksFlash(name)
    flash.text:SetText("- " .. (name or "Testing"))
    flash:SetAlpha(1)
    flash:Show()
    C_Timer.After(2, function() flash:Hide() end)
end

-------------------------------------------------------
-- 2. THE LOGIC
-------------------------------------------------------
local function UpdateTricksMacro()
    if InCombatLockdown() then return end
    local tankName = nil
    for i = 1, 40 do
        local unit = IsInRaid() and "raid"..i or "party"..i
        if UnitGroupRolesAssigned(unit) == "TANK" then
            tankName = GetUnitName(unit, true)
            break 
        end
    end
    if tankName and tankName ~= lastTank then
        local macroIndex = GetMacroIndexByName("Tricks")
        if macroIndex > 0 then
            EditMacro(macroIndex, "Tricks", nil, "#showtooltip\n/cast [@"..tankName.."] Tricks of the Trade")
            print("|cff00ff00[Tricks Alert]|r: Tricks set to |cffffff00" .. tankName .. "|r")
            lastTank = tankName
        end
    elseif not tankName then
        lastTank = "" 
    end
end

-------------------------------------------------------
-- 3. EVENTS & SLASH COMMANDS
-------------------------------------------------------
t:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
t:RegisterEvent("GROUP_ROSTER_UPDATE")
t:RegisterEvent("PLAYER_ENTERING_WORLD")

t:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellID == 57934 or (spellInfo and spellInfo.name == "Tricks of the Trade") then
            if lastTank ~= "" then
                ShowTricksFlash(lastTank)
            end
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, UpdateTricksMacro)
    end
end)

SLASH_TESTTRICKS1 = "/testtricks"
SlashCmdList["TESTTRICKS"] = function()
    ShowTricksFlash("Test Tank")
end

SLASH_UPDATETRICKS1 = "/updatetricks"
SlashCmdList["UPDATETRICKS"] = UpdateTricksMacro