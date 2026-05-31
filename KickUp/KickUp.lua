local frame = CreateFrame("Frame")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

local _, _, classID = UnitClass("player");

local class_tbl =
{
    [0] = 0,       -- None
    [1] = 6552,    -- Warrior
    [2] = 96231,   -- Paladin
    [3] = 147362,  -- Hunter
    [4] = 1766,    -- Rogue
    [5] = 15487,   -- Priest
    [6] = 47528,   -- Death Knight
    [7] = 57994,   -- Shaman
    [8] = 2139,    -- Mage
    [9] = 132409,  -- Warlock
    [10] = 116705, -- Monk
    [11] = 106839, -- Druid
    [12] = 183752, -- Demon Hunter
}

local cooldowntimer_tbl = 
{
    [6552] = 15,    -- Pummel
    [96231] = 15,   -- Rebuke
    [147362] = 24,  -- Counter Shot
    [1766] = 15,    -- Kick
    [15487] = 45,   -- Silence
    [47528] = 15,   -- Mind Freeze
    [57994] = 12,   -- Wind Shear
    [2139] = 24,    -- Counterspell
    [132409] = 24,  -- Spell Lock
    [116705] = 15,  -- Spear Hand Strike
    [106839] = 15,  -- Skull Bash no solar beam cause i don't like owls
    [183752] = 15,  -- Disrupt
}

-- Kick Spell ID
local targetID = class_tbl[classID]

frame:SetScript("OnEvent", function(self, event, unit, castID, spellID)
    if spellID == targetID then
        -- Kick is a 15s cooldown. 
        -- If you want the sound to play right as it's ready, use 15.
        -- If you want a warning slightly before, use 14.
        C_Timer.After(cooldowntimer_tbl[spellID], function()
            -- Path to your custom file
            local soundPath = [[Interface\AddOns\KickUp\kickup.ogg]]
            PlaySoundFile(soundPath, "Master")
        end)
    end
end)