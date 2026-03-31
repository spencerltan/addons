local frame = CreateFrame("Frame")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

-- Kick Spell ID
local targetID = 1766 

frame:SetScript("OnEvent", function(self, event, unit, castID, spellID)
    if spellID == targetID then
        -- Kick is a 15s cooldown. 
        -- If you want the sound to play right as it's ready, use 15.
        -- If you want a warning slightly before, use 14.
        C_Timer.After(15, function()
            -- Path to your custom file
            local soundPath = [[Interface\AddOns\KickUp\kickup.ogg]]
            PlaySoundFile(soundPath, "Master")
        end)
    end
end)