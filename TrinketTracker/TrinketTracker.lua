local f = CreateFrame("Frame")
local timeLeft = 0
local isOnCooldown = false

-------------------------------------------------------
-- 1. THE UI (Stays Hidden until 5.0)
-------------------------------------------------------
local alert = CreateFrame("Frame", "TrinketCDAlert", UIParent, "BackdropTemplate")
alert:SetSize(400, 50)
alert:SetPoint("CENTER", 0, 250) 
alert:Hide() 

-- The Icon
alert.icon = CreateFrame("Frame", nil, alert, "BackdropTemplate")
alert.icon:SetSize(36, 36)
alert.icon:SetPoint("LEFT", 0, 0)
alert.icon:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
alert.icon:SetBackdropBorderColor(0, 0, 0, 1)

alert.tex = alert.icon:CreateTexture(nil, "OVERLAY")
alert.tex:SetSize(34, 34)
alert.tex:SetPoint("CENTER")
alert.tex:SetTexCoord(0.1, 0.9, 0.1, 0.9)

-- The Text (Pure Red)
alert.text = alert:CreateFontString(nil, "OVERLAY")
alert.text:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE")
alert.text:SetTextColor(1, 0, 0) 
alert.text:SetPoint("LEFT", alert.icon, "RIGHT", 10, 0)

-------------------------------------------------------
-- 2. THE TIMER LOGIC
-------------------------------------------------------
local function UpdateDisplay(self, elapsed)
    if timeLeft > 0 then
        timeLeft = timeLeft - elapsed
        
        -- THE 5-SECOND GATE
        if timeLeft <= 5 then
            if not alert:IsShown() then alert:Show() end
            alert.text:SetText(string.format("Available in %.1f", timeLeft))
        else
            -- Ensure it stays hidden if above 5s
            if alert:IsShown() then alert:Hide() end
        end
    else
        timeLeft = 0
        isOnCooldown = false
        alert:Hide()
        f:SetScript("OnUpdate", nil)
    end
end

local function CheckTrinketUsage()
    for _, slot in pairs({13, 14}) do
        local start, duration, enable = GetInventoryItemCooldown("player", slot)
        
        if duration and duration > 30 and start > 0 and not isOnCooldown then
            timeLeft = duration - (GetTime() - start)
            
            local itemID = GetInventoryItemID("player", slot)
            if itemID then
                alert.tex:SetTexture(C_Item.GetItemIconByID(itemID))
            end
            
            isOnCooldown = true
            f:SetScript("OnUpdate", UpdateDisplay)
            return 
        end
    end
end

-------------------------------------------------------
-- 3. EVENTS & TEST COMMAND
-------------------------------------------------------
f:RegisterEvent("BAG_UPDATE_COOLDOWN")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(self, event)
    if event == "BAG_UPDATE_COOLDOWN" then
        CheckTrinketUsage()
    else
        isOnCooldown = false
        alert:Hide()
    end
end)

-- THE 10-SECOND TEST
SLASH_TESTTRINKET1 = "/testtrinket"
SlashCmdList["TESTTRINKET"] = function()
    timeLeft = 10 -- Total countdown starts at 10
    alert.tex:SetTexture(C_Item.GetItemIconByID(250144)) -- Emberwing Feather Icon
    isOnCooldown = true
    f:SetScript("OnUpdate", UpdateDisplay)
    print("|cffff0000[Test]|r: 10s Timer started. Popup should appear in 5 seconds...")
end