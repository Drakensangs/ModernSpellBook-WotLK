-- Compatibility layer for Wrath of the Lich King 3.3.5a (Interface 30300).

MSB_COMPAT_LOADED = true

-- Global string fallbacks (in case a locale doesn't define one of these)
if not TALENT then TALENT = "Talent" end
if not NEW then NEW = "New" end
if not SPELLBOOK then SPELLBOOK = "Spellbook" end
if not PET_PASSIVE then PET_PASSIVE = "Passive" end
if not GENERAL then GENERAL = "General" end

-- C_Timer.After polyfill using OnUpdate.
-- C_Timer does not exist in 3.3.5a at all (added much later); this is a
-- real requirement, not just defensive.
if not C_Timer then
	C_Timer = {}
end
if not C_Timer.After then
	local timerFrame = CreateFrame("Frame")
	timerFrame.timers = {}
	timerFrame:SetScript("OnUpdate", function()
		local now = GetTime()
		local i = 1
		while i <= table.getn(timerFrame.timers) do
			local timer = timerFrame.timers[i]
			if now >= timer.endTime then
				table.remove(timerFrame.timers, i)
				timer.func()
			else
				i = i + 1
			end
		end
		if table.getn(timerFrame.timers) == 0 then
			timerFrame:Hide()
		end
	end)
	timerFrame:Hide()

	C_Timer.After = function(delay, func)
		table.insert(timerFrame.timers, {
			endTime = GetTime() + delay,
			func = func
		})
		timerFrame:Show()
	end
end

-- SOUNDKIT polyfill. 3.3.5a's PlaySound()
if not SOUNDKIT then
	SOUNDKIT = {}
end
local soundkitDefaults = {
	IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
	IG_ABILITY_PAGE_TURN = "igAbiliityPageTurn",
	IG_SPELLBOOK_OPEN = "igSpellBookOpen",
	IG_SPELLBOOK_CLOSE = "igSpellBookClose",
}
for key, value in pairs(soundkitDefaults) do
	if (SOUNDKIT[key] == nil) then
		SOUNDKIT[key] = value
	end
end

-- MSB-scoped wrappers for spellbook item APIs
function MSB_GetSpellBookItemName(index, bookType)
	if (GetSpellBookItemName) then
		return GetSpellBookItemName(index, bookType)
	end
	return GetSpellName(index, bookType)
end

function MSB_GetSpellBookItemTexture(index, bookType)
	if (GetSpellBookItemTexture) then
		return GetSpellBookItemTexture(index, bookType)
	end
	return GetSpellTexture(index, bookType)
end

-- 3.3.5a does have a real IsPassiveSpell(index, bookType) - this wrapper's
-- fallback only matters as a safety net.
function MSB_IsPassiveSpell(index, bookType)
	if (IsPassiveSpell) then
		return IsPassiveSpell(index, bookType)
	end
	bookType = bookType or BOOKTYPE_SPELL
	local _, rank = GetSpellName(index, bookType)
	if rank and (rank == PASSIVE or rank == "Passive") then
		return true
	end
	return false
end

function MSB_IsSpellHidden(index, bookType)
	if (IsSpellHidden) then
		return IsSpellHidden(index, bookType)
	end
	return false
end

function MSB_GetSpellDescription(index)
	if (GetSpellDescription) then
		return GetSpellDescription(index)
	end
	return nil
end

if not PRODUCT_CHOICE_PAGE_NUMBER then
	PRODUCT_CHOICE_PAGE_NUMBER = "Page %d / %d"
end

function MSB_SetTooltipSpell(spellID, bookType)
	if (GameTooltip.SetSpellByID) then
		GameTooltip:SetSpellByID(spellID, bookType)
	elseif (spellID and type(spellID) == "number") then
		GameTooltip:SetSpell(spellID, bookType or BOOKTYPE_SPELL)
	end
end

function MSB_PickupSpellBookItem(slot, bookType)
	if (PickupSpellBookItem) then
		PickupSpellBookItem(slot, bookType)
	else
		PickupSpell(slot, bookType or BOOKTYPE_SPELL)
	end
end

function MSB_StripLearnPromptFromTooltip()
	for i = 2, GameTooltip:NumLines() do
		local fs = _G["GameTooltipTextLeft" .. i]
		if (fs) then
			local text = fs:GetText()
			if (text and string.find(string.lower(text), "learn")) then
				fs:SetText("")
			end
		end
	end
end

-- GetTalentLink is not available on 3.3.5a; falls back to a non-clickable,
-- but still visually consistent, bracketed talent name.
function MSB_GetTalentLink(tab, index)
	if (GetTalentLink) then
		return GetTalentLink(tab, index)
	end
	local name = GetTalentInfo(tab, index)
	if name then
		return "|cff71d5ff[" .. name .. "]|r"
	end
	return nil
end

-- UnitClass classID polyfill.
-- 3.3.5a's UnitClass returns (localizedName, englishName) with no classID,
-- so we provide our own lookup for the class color table index.
MSB_ClassIndices = {
	["WARRIOR"] = 1,
	["PALADIN"] = 2,
	["HUNTER"] = 3,
	["ROGUE"] = 4,
	["PRIEST"] = 5,
	["DEATHKNIGHT"] = 6,
	["SHAMAN"] = 7,
	["MAGE"] = 8,
	["WARLOCK"] = 9,
	["MONK"] = 10,
	["DRUID"] = 11,
	["DEMONHUNTER"] = 12,
}
function MSB_GetClassIndex()
	local _, englishClass = UnitClass("player")
	return MSB_ClassIndices[englishClass] or 1
end

-- Numeric texture ID -> path mappings
MSB_Textures = {
	-- Minimize/Maximize button textures
	[335575] = "Interface\\Buttons\\UI-Panel-SmallerButton-Up",      -- maximize normal
	[335574] = "Interface\\Buttons\\UI-Panel-SmallerButton-Down",    -- maximize pushed
	[335578] = "Interface\\Buttons\\UI-Panel-CollapseButton-Up",     -- minimize normal
	[335577] = "Interface\\Buttons\\UI-Panel-CollapseButton-Down",   -- minimize pushed
	[130831] = "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", -- highlight
}

-- Helper to resolve texture IDs to paths
function MSB_ResolveTexture(textureIDOrPath)
	if type(textureIDOrPath) == "number" then
		return MSB_Textures[textureIDOrPath] or ""
	end
	return textureIDOrPath
end

-- ShowAllSpellRanksCheckbox - created properly by ModernSpellBook once the
-- spellbook frame is built. Just ensure the globals exist so any reference
-- to them before that point doesn't error.
if not ShowAllSpellRanksCheckbox then
	ShowAllSpellRanksCheckbox = nil
end
if not ShowAllSpellRanksCheckboxText then
	ShowAllSpellRanksCheckboxText = nil
end

-- SpellBookSpellIconsFrame stub
if not SpellBookSpellIconsFrame then
	SpellBookSpellIconsFrame = CreateFrame("Frame", "SpellBookSpellIconsFrame", UIParent)
	SpellBookSpellIconsFrame:SetWidth(1)
	SpellBookSpellIconsFrame:SetHeight(1)
	SpellBookSpellIconsFrame:Hide()
end

-- StanceBarFrame / ShapeshiftBarFrame
if not StanceBarFrame and not StanceBar then
	if ShapeshiftBarFrame then
		StanceBarFrame = ShapeshiftBarFrame
	else
		StanceBarFrame = CreateFrame("Frame")
		StanceBarFrame.numForms = 0
	end
end