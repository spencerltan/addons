-- ============================================================
--  FocusAlertInterrupt  v11.0
-- ============================================================

local DEFAULTS = {
    enabled    = true,
    ttsMessage = "Interrupt",
}

-- Base cooldowns in seconds (Midnight 12.0)
local CLASS_INTERRUPTS = {
    DEATHKNIGHT = { { id = 47528,  name = "Mind Freeze",        cd = 15 } },
    DEMONHUNTER = { { id = 183752, name = "Disrupt",            cd = 15 } },
    DRUID       = { { id = 106839, name = "Skull Bash",         cd = 15, specs = {102,103,104} } },
    EVOKER      = { { id = 351338, name = "Quell",              cd = 40, specs = {1467,1473} } },
    HUNTER      = { { id = 147362, name = "Counter Shot",       cd = 24, specs = {253,254} },
                    { id = 187707, name = "Muzzle",             cd = 15, specs = {255} } },
    MAGE        = { { id = 2139,   name = "Counterspell",       cd = 20 } },  -- 20s in Midnight
    MONK        = { { id = 116705, name = "Spear Hand Strike",  cd = 15, specs = {268,269} } },
    PALADIN     = { { id = 96231,  name = "Rebuke",             cd = 15, specs = {66,70} } },
    PRIEST      = { { id = 15487,  name = "Silence",            cd = 45, specs = {258} } },
    ROGUE       = { { id = 1766,   name = "Kick",               cd = 15 } },
    SHAMAN      = { { id = 57994,  name = "Wind Shear",         cd = 12 } },
    WARLOCK     = { { id = 19647,  name = "Spell Lock",         cd = 24 },
                    { id = 119910, name = "Axe Toss",           cd = 30, specs = {265} } },
    WARRIOR     = { { id = 6552,   name = "Pummel",             cd = 15 } },
}

-- ---------------------------------------------------------------
--  State
-- ---------------------------------------------------------------
local db
local playerClass, playerSpec
local interruptSpells   = {}
local interruptSpellIDs = {}  -- spellID -> cd seconds
local interruptReadyAt  = 0   -- GetTime() when interrupt comes off CD (0 = assume ready)
local lastAlertTime     = 0
local ALERT_THROTTLE    = 1.5
local pendingAlert      = false
local lastInterruptCastTime = nil  -- GetTime() when we last cast our interrupt
local lastInterruptSpellID  = nil  -- spellID of that cast (for Coldthirst etc.)

-- ---------------------------------------------------------------
--  Function definitions (all before frame event registration)
-- ---------------------------------------------------------------
local function InitDB()
    FAI_DB = FAI_DB or {}
    for k, v in pairs(DEFAULTS) do
        if FAI_DB[k] == nil then FAI_DB[k] = v end
    end
    db = FAI_DB
end

local CD_REDUCTION_TALENTS = {
    -- Mage: Quick Witted — Counterspell CD -5s (25 -> 20)
    [382297] = { affects = 2139,   reduction = 5  },
    -- Evoker: Imposing Presence — Quell CD -20s (40 -> 20)
    [371016] = { affects = 351338, reduction = 20 },
    -- Shaman: Wailing Winds — Wind Shear CD -4s (12 -> 8)
    [329526] = { affects = 57994,  reduction = 4  },
}

-- Talents that reduce CD only on SUCCESSFUL interrupt (applied after UNIT_SPELLCAST_INTERRUPTED)
local CD_ON_SUCCESS_TALENTS = {
    -- DK: Coldthirst — Mind Freeze CD -3s on successful interrupt
    [378848] = { affects = 47528, reduction = 3 },
}

-- Whether any on-success talents are active (populated by ScanTalents)
local onSuccessReductions = {}  -- spellID -> reduction seconds
local cachedCD = {}             -- spellID -> true talent-adjusted CD in seconds

local function ScanTalents()
    local configID
    local ok0, cid = pcall(function()
        return C_ClassTalents.GetActiveConfigID()
    end)
    if ok0 and cid then configID = cid end
    if not configID then return end

    local ok1, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not ok1 or not configInfo or not configInfo.treeIDs or #configInfo.treeIDs == 0 then return end

    local treeID = configInfo.treeIDs[1]
    local ok2, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not ok2 or not nodeIDs then return end

    for _, nodeID in ipairs(nodeIDs) do
        local ok3, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if ok3 and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
            local entryID = nodeInfo.activeEntry.entryID
            if entryID then
                local ok4, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                if ok4 and entryInfo and entryInfo.definitionID then
                    local ok5, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                    if ok5 and defInfo and defInfo.spellID then
                        local talent = CD_REDUCTION_TALENTS[defInfo.spellID]
                        if talent then
                            -- Find the affected interrupt spell and apply reduction
                            for _, spell in ipairs(interruptSpells) do
                                if spell.id == talent.affects then
                                    local base = spell.cd
                                    local newCd
                                    if talent.pct then
                                        newCd = math.floor(base * (1 - talent.pct / 100) + 0.5)
                                    else
                                        newCd = base - talent.reduction
                                    end
                                    if newCd > 1 then
                                        cachedCD[spell.id] = newCd
                                    end
                                end
                            end
                        end
                        -- Check on-success talents (e.g. DK Coldthirst)
                        local onSuccess = CD_ON_SUCCESS_TALENTS[defInfo.spellID]
                        if onSuccess then
                            onSuccessReductions[onSuccess.affects] = onSuccess.reduction
                        end
                    end
                end
            end
        end
    end
end

local function TryCacheCD()
    if InCombatLockdown() then return end
    for _, spell in ipairs(interruptSpells) do
        local ok, info = pcall(C_Spell.GetSpellCooldown, spell.id)
        if ok and info then
            local ok2, dur = pcall(function() return info.duration end)
            if ok2 and dur then
                local clean = tonumber(string.format("%.1f", dur))
                if clean and clean > 1.5 and clean < 120 then
                    cachedCD[spell.id] = clean
                end
            end
        end
    end
end

local function GetSpellCD(spell)
    return cachedCD[spell.id] or spell.cd
end

local function UpdateInterruptSpells()
    local idx = GetSpecialization()
    if idx then _, _, _, playerSpec = GetSpecializationInfo(idx) end
    local data = CLASS_INTERRUPTS[playerClass]
    local oldIDs = interruptSpellIDs
    interruptSpells   = {}
    interruptSpellIDs = {}
    if not data then return end
    for _, spell in ipairs(data) do
        local matches = not spell.specs
        if not matches then
            for _, s in ipairs(spell.specs) do
                if s == playerSpec then matches = true; break end
            end
        end
        if matches then
            -- GetSpellBaseCooldown as initial fallback only — TryCacheCD
            -- will replace it with the true talent-modified value.
            local actualCd = spell.cd
            local ok, ms = pcall(GetSpellBaseCooldown, spell.id)
            if ok and ms and ms > 1500 then
                actualCd = ms / 1000
            end
            local resolved = { id = spell.id, name = spell.name, cd = actualCd }
            table.insert(interruptSpells, resolved)
            interruptSpellIDs[spell.id] = actualCd
        end
    end
    local spellsChanged = false
    for id in pairs(interruptSpellIDs) do
        if not oldIDs[id] then spellsChanged = true; break end
    end
    for id in pairs(oldIDs) do
        if not interruptSpellIDs[id] then spellsChanged = true; break end
    end
    if spellsChanged then
        interruptReadyAt = 0
        cachedCD = {}
    end
    ScanTalents()  -- apply talent CD reductions before TryCacheCD overwrites with API value
    TryCacheCD()   -- prefer direct API read if available (out of combat)
end

local function IsInterruptReady()
    if interruptReadyAt == 0 then return true end
    return GetTime() >= interruptReadyAt
end

local function SpeakAlert()
    local now = GetTime()
    if (now - lastAlertTime) < ALERT_THROTTLE then return end
    lastAlertTime = now
    local voiceID = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
    local msg = (db.ttsMessage ~= "") and db.ttsMessage or DEFAULTS.ttsMessage
    C_VoiceChat.SpeakText(voiceID, msg, 0, 100, false)
end

local function CheckAndAlert()
    if not db or not db.enabled then return end
    if not UnitExists("focus") then return end
    local casting = UnitCastingInfo("focus")
    if not casting then casting = UnitChannelInfo("focus") end
    if not casting then return end
    if not IsInterruptReady() then return end
    pendingAlert = true
end

-- ---------------------------------------------------------------
--  Frames — created before SetScript, registered at bottom
-- ---------------------------------------------------------------

-- CleanFrame: TTS calls only, never registers events
local CleanFrame = CreateFrame("Frame", "FAI_CleanFrame")

-- Main event frame
local ef = CreateFrame("Frame", "FAI_EventFrame")

-- Player cast frame — tracks our own interrupt casts
local playerCastFrame = CreateFrame("Frame", "FAI_PlayerCastFrame")

-- ---------------------------------------------------------------
--  Scripts — set after all function definitions
-- ---------------------------------------------------------------
local wasInterruptReady = true
local focusWasCasting = false  -- track cast state to detect new casts via polling

CleanFrame:SetScript("OnUpdate", function()
    if pendingAlert then
        pendingAlert = false
        SpeakAlert()
        return
    end

    if not db or not db.enabled or not UnitExists("focus") then
        focusWasCasting = false
        wasInterruptReady = true
        return
    end

    local casting = UnitCastingInfo("focus")
    if not casting then casting = UnitChannelInfo("focus") end
    local isCasting = casting ~= nil
    local nowReady = IsInterruptReady()

    -- Alert if focus is casting and interrupt is ready.
    -- Catches: newly started casts (backup for missed events),
    -- focus switches to already-casting target, and
    -- interrupt coming off CD mid-cast.
    if isCasting and nowReady and (not focusWasCasting or not wasInterruptReady) then
        SpeakAlert()
    end

    focusWasCasting = isCasting
    wasInterruptReady = nowReady
end)

ef:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "FocusAlertInterrupt" then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        local _, classFile = UnitClass("player")
        playerClass = classFile
        UpdateInterruptSpells()
        -- Talent system may not be fully ready at PLAYER_LOGIN — re-scan after a short delay
        C_Timer.After(1, function()
            ScanTalents()
            TryCacheCD()
        end)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "SPELLS_CHANGED" then
        UpdateInterruptSpells()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat — read true talent-adjusted CDs now that they're not secret
        TryCacheCD()
    elseif event == "PLAYER_FOCUS_CHANGED" then
        -- Defer by one frame: PLAYER_FOCUS_CHANGED fires before the "focus"
        -- unit token updates to the new target, so UnitCastingInfo("focus")
        -- would still return the old target's data.
        C_Timer.After(0, CheckAndAlert)
    end
end)

playerCastFrame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
    if unit ~= "player" then return end
    for _, spell in ipairs(interruptSpells) do
        local ok, matches = pcall(function() return spell.id == spellID end)
        if ok and matches then
            -- Try to read duration directly (works outside combat / if non-secret)
            local ok2, info = pcall(C_Spell.GetSpellCooldown, spell.id)
            if ok2 and info then
                local ok3, dur = pcall(function() return info.duration end)
                if ok3 and dur then
                    local clean = tonumber(string.format("%.1f", dur))
                    if clean and clean > 1.5 and clean < 120 then
                        cachedCD[spell.id] = clean
                    end
                end
            end
            interruptReadyAt = GetTime() + GetSpellCD(spell)
            -- Record cast time for Coldthirst correlation window
            lastInterruptCastTime = GetTime()
            lastInterruptSpellID  = spell.id
            return
        end
    end
end)

-- focusInterruptFrame: detects when focus cast is interrupted.
-- If it happens within 1s of our interrupt cast, it was our interrupt —
-- apply any on-success CD reductions (e.g. DK Coldthirst: -3s).
local focusInterruptFrame = CreateFrame("Frame", "FAI_FocusInterruptFrame")
focusInterruptFrame:SetScript("OnEvent", function(self, event, unit)
    if unit ~= "focus" then return end
    if not lastInterruptCastTime then return end
    if (GetTime() - lastInterruptCastTime) > 1.0 then return end
    -- Our interrupt caused this — apply on-success reduction
    if lastInterruptSpellID and onSuccessReductions[lastInterruptSpellID] then
        local reduction = onSuccessReductions[lastInterruptSpellID]
        interruptReadyAt = interruptReadyAt - reduction
        -- Don't apply twice
        lastInterruptCastTime = nil
        lastInterruptSpellID  = nil
    end
end)


local focusCastFrame = CreateFrame("Frame", "FAI_FocusCastFrame")
focusCastFrame:SetScript("OnEvent", function(self, event, unit)
    if unit == "focus" then CheckAndAlert() end
end)

-- ---------------------------------------------------------------
--  Event registration — MAIN CHUNK, after all SetScript calls
-- ---------------------------------------------------------------
ef:RegisterEvent("ADDON_LOADED")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ef:RegisterEvent("SPELLS_CHANGED")
ef:RegisterEvent("PLAYER_REGEN_ENABLED")
ef:RegisterEvent("PLAYER_FOCUS_CHANGED")

-- RegisterUnitEvent for unit-specific events (MIT pattern)
playerCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
focusCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
focusInterruptFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "focus")

-- ---------------------------------------------------------------
--  Slash commands  /fai
-- ---------------------------------------------------------------
SLASH_FAI1 = "/fai"
SlashCmdList["FAI"] = function(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$")

    if input == "talents" then
        print("|cff88aaff[FAI] Active talent spell IDs:|r")
        local configID
        local ok0, cid = pcall(function() return C_ClassTalents.GetActiveConfigID() end)
        if ok0 and cid then configID = cid end
        if not configID then print("  No active config found."); return end
        local ok1, configInfo = pcall(C_Traits.GetConfigInfo, configID)
        if not ok1 or not configInfo or not configInfo.treeIDs then print("  No tree IDs."); return end
        local treeID = configInfo.treeIDs[1]
        local ok2, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
        if not ok2 or not nodeIDs then print("  No nodes."); return end
        local count = 0
        for _, nodeID in ipairs(nodeIDs) do
            local ok3, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            if ok3 and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
                local entryID = nodeInfo.activeEntry.entryID
                if entryID then
                    local ok4, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
                    if ok4 and entryInfo and entryInfo.definitionID then
                        local ok5, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                        if ok5 and defInfo and defInfo.spellID then
                            local ok6, spellName = pcall(C_Spell.GetSpellName, defInfo.spellID)
                            print("  spellID=" .. defInfo.spellID .. " name=" .. tostring(spellName))
                            count = count + 1
                        end
                    end
                end
            end
        end
        print("  Total: " .. count .. " active talents")

    elseif input == "debug" then
        local now = GetTime()
        print("|cff88aaff[FAI] Debug:|r")
        print("  playerClass: " .. tostring(playerClass))
        print("  interruptReadyAt: " .. tostring(interruptReadyAt))
        print("  CD remaining: " .. string.format("%.1f", math.max(0, interruptReadyAt - now)) .. "s")
        print("  IsInterruptReady: " .. tostring(IsInterruptReady()))
        print("  Interrupt spells detected:")
        for _, s in ipairs(interruptSpells) do
            local cached = cachedCD[s.id]
            local effective = GetSpellCD(s)
            local src = cached and "cached" or "base"
            print("    id=" .. s.id .. " name=" .. s.name .. " base=" .. s.cd .. "s effective=" .. effective .. "s (" .. src .. ")")
        end
        if #interruptSpells == 0 then print("    (none)") end

    elseif input == "" or input == "help" then
        print("|cff88aaff[FAI] Commands:|r")
        print("  /fai on/off        — enable or disable")
        print("  /fai test          — play TTS alert now")
        print("  /fai message <x>   — set TTS text")
        print("  /fai status        — show current settings")
        print("  /fai debug         — show cooldown tracking state")
        print("  /fai talents       — list all active talent spell IDs")

    elseif input == "on" then
        db.enabled = true
        print("|cff88aaff[FAI]|r |cff00ff00Enabled.|r")

    elseif input == "off" then
        db.enabled = false
        print("|cff88aaff[FAI]|r |cffff0000Disabled.|r")

    elseif input == "test" then
        local voiceID = C_TTSSettings.GetVoiceOptionID(Enum.TtsVoiceType.Standard)
        local msg = (db.ttsMessage ~= "") and db.ttsMessage or DEFAULTS.ttsMessage
        C_VoiceChat.SpeakText(voiceID, msg, 0, 100, false)
        print("|cff88aaff[FAI]|r Testing TTS: \"" .. msg .. "\"")

    elseif input:sub(1, 7) == "message" then
        local msg = input:sub(9):match("^%s*(.-)%s*$")
        if msg and msg ~= "" then
            db.ttsMessage = msg
            print("|cff88aaff[FAI]|r TTS message: \"" .. msg .. "\"")
        else
            print("|cff88aaff[FAI]|r Usage: /fai message <text>")
        end

    elseif input == "status" then
        local now = GetTime()
        local cdLeft = interruptReadyAt > 0 and math.max(0, interruptReadyAt - now) or 0
        print("|cff88aaff[FAI] Status:|r")
        print("  Enabled: " .. tostring(db and db.enabled))
        print("  Message: \"" .. (db and db.ttsMessage or "?") .. "\"")
        print("  Class:   " .. (playerClass or "?"))
        if #interruptSpells > 0 then
            local names = {}
            for _, s in ipairs(interruptSpells) do
                table.insert(names, s.name .. " (" .. s.cd .. "s)")
            end
            print("  Interrupts: " .. table.concat(names, ", "))
        else
            print("  Interrupts: none for this spec")
        end
        if cdLeft > 0 then
            print("  CD remaining: " .. string.format("%.1f", cdLeft) .. "s")
        else
            print("  Interrupt: |cff00ff00READY|r")
        end

    else
        print("|cff88aaff[FAI]|r Unknown command — /fai help for options.")
    end
end
