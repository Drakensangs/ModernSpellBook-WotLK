--[[
	Action bar helper: tells which spells are not on any action bar
	(settings: "Highlight spells not on action bars"). The empty slot grid
	shown while the book is open lives in MSB_SecureBook.
--]]

local MAX_ACTION_SLOTS = 120	-- every bar page, including stance and bonus bars

MSB_class "MSB_CActionBarHelper"
{
	__init = function(self)
		self.placedSpells = nil

		-- Keep the highlight live while spells are dragged onto the bars
		local helper = self
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
		self.frame:RegisterEvent("UPDATE_MACROS")
		self.frame:RegisterEvent("PET_BAR_UPDATE")
		self.frame:SetScript("OnEvent", function(_, evt)
			evt = evt or event
			helper:InvalidatePlacedSpells()
			helper:QueueHighlightUpdate()
			-- Autocast toggled on the pet bar
			if (evt == "PET_BAR_UPDATE") then
				helper:QueueAutocastUpdate()
			end
		end)
	end;

	-- ==================== PLACED SPELLS ==========================

	InvalidatePlacedSpells = function(self)
		self.placedSpells = nil
	end;

	-- Names of every spell on an action bar, directly or through a macro,
	-- plus everything on the pet bar. Any rank counts.
	GetPlacedSpells = function(self)
		if (self.placedSpells) then return self.placedSpells end
		local names = {}

		for slot = 1, MAX_ACTION_SLOTS do
			if (HasAction(slot)) then
				local actionType, id, subType, spellID = GetActionInfo(slot)
				local name = nil
				if (actionType == "spell") then
					-- 3.3.5 gives the spellbook slot plus the spell ID
					if (spellID and GetSpellInfo) then
						name = GetSpellInfo(spellID)
					end
					if (not name and id) then
						local ok, bookName = pcall(GetSpellName, id, (subType == BOOKTYPE_PET) and BOOKTYPE_PET or BOOKTYPE_SPELL)
						if (ok) then name = bookName end
					end
				elseif (actionType == "macro" and id and GetMacroSpell) then
					name = GetMacroSpell(id)
				end
				if (name) then names[name] = true end
			end
		end

		for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
			local name = GetPetActionInfo(i)
			if (name) then names[name] = true end
		end

		self.placedSpells = names
		return names
	end;

	-- True for a learned, castable spell that isn't on any bar.
	-- Passives, talents and stances/forms (they live on the stance bar) never count.
	IsSpellUnplaced = function(self, spellInfo)
		if (not spellInfo or spellInfo.isUnlearned or spellInfo.isPassive) then return false end
		if (spellInfo.isTalent or spellInfo.stanceIndex) then return false end
		if (not spellInfo.isPetSpell and not spellInfo.castName) then return false end
		return not self:GetPlacedSpells()[spellInfo.spellName]
	end;

	-- Bars can fire many slot events at once; refresh the page a moment later
	QueueHighlightUpdate = function(self)
		if (self.updateQueued) then return end
		if (not ModernSpellBook_DB or not ModernSpellBook_DB.highlightUnplaced) then return end
		if (not ModernSpellBookFrame or not ModernSpellBookFrame:IsVisible()) then return end
		self.updateQueued = true
		local helper = self
		MSB_After(0.1, function()
			helper.updateQueued = false
			if (ModernSpellBookFrame:IsVisible() and MSB_SpellBook) then
				MSB_SpellBook:UpdateUnplacedHighlights()
			end
		end)
	end;

	QueueAutocastUpdate = function(self)
		if (self.autocastQueued) then return end
		if (not ModernSpellBookFrame or not ModernSpellBookFrame:IsVisible()) then return end
		self.autocastQueued = true
		local helper = self
		MSB_After(0.1, function()
			helper.autocastQueued = false
			if (ModernSpellBookFrame:IsVisible() and MSB_SpellBook) then
				MSB_SpellBook:UpdateAutocast()
			end
		end)
	end;
}

MSB_ActionBarHelper = MSB_CActionBarHelper()
