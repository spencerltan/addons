local frame = CreateFrame("Frame")
-- Register specifically for the player's successful casts
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

-- The corrected Spell ID from your debug log
local targetID = 280719 

frame:SetScript("OnEvent", function(self, event, unit, castID, spellID)
    -- Check if the casted spell matches the debugged ID
    if spellID == targetID then
        
        -- Start the 19-second internal countdown timer
        C_Timer.After(19, function()
            -- Access LibSharedMedia-3.0 to find the "Bite" sound
            local LSM = LibStub("LibSharedMedia-3.0", true)
            
            if LSM then
                -- Fetch the file path for the sound named "Bite" seen in your menu
                local soundPath = LSM:Fetch("sound", "Bite")
                
                if soundPath then
                    -- Play the file to the Master channel
                    PlaySoundFile(soundPath, "Master")
                end
            end
        end)
    end
end)