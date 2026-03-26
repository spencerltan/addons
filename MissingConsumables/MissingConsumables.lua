local f = CreateFrame("Frame", "ConsumableAlert", UIParent)
f:SetSize(400, 250) 
f:SetPoint("CENTER", 0, 300) 
f:SetFrameStrata("TOOLTIP")

-- Table for all Flask IDs (T1, T2, T3)
local flaskIDs = {
    [241322] = true,  -- Flask of the Magisters (T3) Mast
    [1235108] = true, -- Flask of the Magisters (T2) Mast
    [241326] = true,  -- Flask of the Shattered Sun (T3) Crit
    [241327] = true,  -- Flask of the Shattered Sun (T2) Crit
    [241324] = true,  -- Flask of the Blood Knight (T3) Haste
    [241325] = true,  -- Flask of the Blood Knight (T2) Haste
    [241320] = true,  -- Flask of the Thalassian Resistance (T3) Vers
    [241321] = true,  -- Flask of the Thalassian Resistance (T2) Vers
}

-- Table for all Food/Well Fed IDs
local foodIDs = {
    [1219183] = true, -- Arcano Cutlets
    [1285644] = true, -- Hearty Harandar Celebration
    [1232080] = true, -- Hearty Blooming Feast
}

local function CreateBounce(textObj)
    local ag = textObj:CreateAnimationGroup()
    local moveUp = ag:CreateAnimation("Translation")
    moveUp:SetOffset(0, 10)
    moveUp:SetDuration(0.2)
    moveUp:SetSmoothing("IN_OUT")
    moveUp:SetOrder(1)
    local moveDown = ag:CreateAnimation("Translation")
    moveDown:SetOffset(0, -10)
    moveDown:SetDuration(0.2)
    moveDown:SetSmoothing("IN_OUT")
    moveDown:SetOrder(2)
    ag:SetLooping("REPEAT")
    return ag
end

-- 1. FOOD ALERT (Yellow)
local FoodText = f:CreateFontString(nil, "OVERLAY")
FoodText:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE") 
FoodText:SetPoint("TOP", f, "TOP", 0, 0)
FoodText:SetTextColor(1, 1, 0) 
FoodText:SetText("**Missing Food**")
FoodText:Hide()
local foodAg = CreateBounce(FoodText)

-- 2. FLASK ALERT (Light Blue)
local FlaskText = f:CreateFontString(nil, "OVERLAY")
FlaskText:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE") 
FlaskText:SetPoint("TOP", FoodText, "BOTTOM", 0, -10)
FlaskText:SetTextColor(0.4, 0.8, 1) 
FlaskText:SetText("**Missing Flask**")
FlaskText:Hide()
local flaskAg = CreateBounce(FlaskText)

-- 3. MAIN HAND ALERT (Purple)
local MHText = f:CreateFontString(nil, "OVERLAY")
MHText:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE") 
MHText:SetPoint("TOP", FlaskText, "BOTTOM", 0, -10)
MHText:SetTextColor(0.7, 0.3, 1) -- Purple
MHText:SetText("**Missing Main Hand Consumable**")
MHText:Hide()
local mhAg = CreateBounce(MHText)

-- 4. OFF HAND ALERT (Green)
local OHText = f:CreateFontString(nil, "OVERLAY")
OHText:SetFont("Fonts\\expressway.ttf", 32, "OUTLINE") 
OHText:SetPoint("TOP", MHText, "BOTTOM", 0, -10)
OHText:SetTextColor(0, 1, 0) -- Green
OHText:SetText("**Missing Off Hand Consumable**")
OHText:Hide()
local ohAg = CreateBounce(OHText)

local function Update()
    if UnitIsDeadOrGhost("player") then 
        FoodText:Hide() foodAg:Stop()
        FlaskText:Hide() flaskAg:Stop()
        MHText:Hide() mhAg:Stop()
        OHText:Hide() ohAg:Stop()
        return 
    end

    local inInstance, instanceType = IsInInstance()
    
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        local hasFood, hasFlask = false, false
        for id in pairs(foodIDs) do if C_UnitAuras.GetPlayerAuraBySpellID(id) then hasFood = true break end end
        for id in pairs(flaskIDs) do if C_UnitAuras.GetPlayerAuraBySpellID(id) then hasFlask = true break end end

        local hasMH, _, _, _, hasOH = GetWeaponEnchantInfo()

        if not hasFood then if not FoodText:IsShown() then FoodText:Show() foodAg:Play() end else FoodText:Hide() foodAg:Stop() end
        if not hasFlask then if not FlaskText:IsShown() then FlaskText:Show() flaskAg:Play() end else FlaskText:Hide() flaskAg:Stop() end
        
        if not hasMH then 
            if not MHText:IsShown() then MHText:Show() mhAg:Play() end 
        else 
            MHText:Hide() mhAg:Stop() 
        end

        if not hasOH and GetInventoryItemID("player", 17) then 
            if not OHText:IsShown() then OHText:Show() ohAg:Play() end 
        else 
            OHText:Hide() ohAg:Stop() 
        end
    else
        FoodText:Hide() foodAg:Stop()
        FlaskText:Hide() flaskAg:Stop()
        MHText:Hide() mhAg:Stop()
        OHText:Hide() ohAg:Stop()
    end
end

f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")

f:SetScript("OnEvent", function(self, event, unit)
    if (event == "UNIT_AURA" and unit == "player") or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ALIVE" or (event == "UNIT_INVENTORY_CHANGED" and unit == "player") then
        Update()
    end
end)