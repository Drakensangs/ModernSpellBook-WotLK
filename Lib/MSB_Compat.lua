-- Compatibility layer for Wrath of the Lich King 3.3.5a (Interface 30300):
-- fills in APIs and globals the addon expects but this client lacks.

-- Fallbacks in case a locale doesn't define one of these strings
if not TALENT then TALENT = "Talent" end
if not NEW then NEW = "New" end
if not SPELLBOOK then SPELLBOOK = "Spellbook" end
if not PET_PASSIVE then PET_PASSIVE = "Passive" end
if not GENERAL then GENERAL = "General" end

-- MSB_After(delay, func): C_Timer.After where the client has it, otherwise
-- an OnUpdate timer. The global C_Timer is left alone so other addons'
-- backports aren't mistaken for a partial one.
if (C_Timer and C_Timer.After) then
	MSB_After = function(delay, func) C_Timer.After(delay, func) end
else
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

	MSB_After = function(delay, func)
		table.insert(timerFrame.timers, {
			endTime = GetTime() + delay,
			func = func
		})
		timerFrame:Show()
	end
end

-- Sound names for 3.3.5a's PlaySound() (kept out of the global SOUNDKIT)
MSB_SOUND = {
	IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
	IG_ABILITY_PAGE_TURN = "igAbiliityPageTurn",
	IG_SPELLBOOK_OPEN = "igSpellBookOpen",
	IG_SPELLBOOK_CLOSE = "igSpellBookClose",
}

-- Spellbook item APIs: newer names first, 3.3.5a names as fallback
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

-- IsPassiveSpell exists on 3.3.5a; the rank-text check is only a safety net
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

-- Spell description for search keywords. Newer clients have
-- GetSpellDescription (by spell ID, read from the link); 3.3.5a doesn't,
-- so a hidden tooltip is read instead: its last line is the description.
local scanTip
function MSB_GetSpellDescription(slot, bookType)
	bookType = bookType or BOOKTYPE_SPELL
	if (GetSpellDescription and GetSpellLink) then
		local link = GetSpellLink(slot, bookType)
		local spellID = link and tonumber(string.match(link, "spell:(%d+)"))
		return spellID and GetSpellDescription(spellID) or nil
	end
	if (not scanTip) then
		scanTip = CreateFrame("GameTooltip", "MSB_ScanTooltip", nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	local ok = pcall(scanTip.SetSpell, scanTip, slot, bookType)
	local lines = scanTip:NumLines()
	local text = ok and lines > 1 and _G["MSB_ScanTooltipTextLeft" .. lines]:GetText() or nil
	scanTip:Hide()
	return text
end

if not PRODUCT_CHOICE_PAGE_NUMBER then
	PRODUCT_CHOICE_PAGE_NUMBER = "Page %d / %d"
end

-- Blanks the "Click to learn" line of talent tooltips: the spellbook only
-- shows talents, it can't learn them. Matches the client's own (localized)
-- string so talent descriptions are left alone.
function MSB_StripLearnPromptFromTooltip()
	local prompt = TOOLTIP_TALENT_LEARN or "Click to learn"
	for i = 2, GameTooltip:NumLines() do
		local fs = _G["GameTooltipTextLeft" .. i]
		if (fs and fs:GetText() == prompt) then
			fs:SetText("")
		end
	end
end

-- GetTalentLink doesn't exist on 3.3.5a: falls back to a plain,
-- link-colored [Talent Name] (not clickable)
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

-- Spell tab icons are paths on this client; numeric texture IDs (newer
-- clients) can't be resolved and show no icon.
function MSB_ResolveTexture(textureIDOrPath)
	if type(textureIDOrPath) == "number" then
		return ""
	end
	return textureIDOrPath
end
