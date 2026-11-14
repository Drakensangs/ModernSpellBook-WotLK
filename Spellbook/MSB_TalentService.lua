--[[
	Talent helpers: tags talent abilities (searchable with "talent"),
	lists talents, and forgets learned talent spells after a talent reset.
--]]

local talentKeyword = string.lower(TALENT.. ";")

MSB_class "MSB_CTalentService"
{
	__init = function(self)
		local service = self
		-- A reset is the spent points dropping to 0. Characters without talents
		-- (and the 0 the client can report before talents load) are no reset.
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
		self.frame:SetScript("OnEvent", function()
			local spent = service:GetAllTalentPointsSpent()
			if (spent == 0 and service.lastSpent and service.lastSpent > 0) then
				service:ResetKnownTalents()
			end
			service.lastSpent = spent
			MSB_SpellBook:OnSpellsChanged()
		end)
	end;

	-- =================== MARK TALENT =============================

	MarkSpellAsTalent = function(self, spellInfo)
		spellInfo.isTalentAbility = true

		local key = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
		local entry = ModernSpellBook_DB.spells[key]

		if (entry and entry.keywords and not string.find(entry.keywords, talentKeyword)) then
			entry.keywords = entry.keywords .. talentKeyword
		end
	end;

	-- =================== QUERY ===================================

	GetAllTalentPointsSpent = function(self)
		local totalTalentPointsSpent = 0
		for i = 1, GetNumTalentTabs() do
			local _, _, pointsSpent = GetTalentTabInfo(i)
			totalTalentPointsSpent = totalTalentPointsSpent + (pointsSpent or 0)
		end
		return totalTalentPointsSpent
	end;

	GetAllTalents = function(self, showOnlyKnown)
		local talentGridPositions = {}
		for t = 1, GetNumTalentTabs() do
			local talentGroupName, _, pointsSpent = GetTalentTabInfo(t)
			if (not talentGroupName) then break end

			if (pointsSpent > 0 or not showOnlyKnown) then
				talentGridPositions[talentGroupName] = {}

				for i = 1, GetNumTalents(t) do
					local nameTalent, icon, _, _, currRank = GetTalentInfo(t, i)
					if (nameTalent and (currRank > 0 or not showOnlyKnown)) then
						local spellInfo = {
							spellName = nameTalent,
							spellIcon = icon,
							spellRank = PET_PASSIVE,
							spellID = nil,
							isPassive = true,
							isTalent = true,
							talentGrid = {t, i},
							category = talentGroupName
						}

						MSB_SpellDataService:RegisterSpell(spellInfo)
						table.insert(talentGridPositions[talentGroupName], spellInfo)
					end
				end
			end
		end

		return talentGridPositions
	end;

	-- =================== RESET ===================================

	-- After a respec: forgets the learned talents and the spells they gave
	-- ("Mangle" also drops "Mangle (Cat)"), so relearning shows them as new.
	-- Ranks known from a trainer become unlearned again instead: their level
	-- and cost are only read on a trainer's first visit.
	ResetKnownTalents = function(self)
		local talentNames = {}
		for t = 1, GetNumTalentTabs() do
			for i = 1, GetNumTalents(t) do
				local nameTalent = GetTalentInfo(t, i)
				if (nameTalent) then talentNames[nameTalent] = true end
			end
		end
		local keysToRemove = {}
		for spellKey, entry in pairs(ModernSpellBook_DB.spells) do
			local name = string.match(spellKey, "^(.-)|") or spellKey
			if (entry.learned and (talentNames[name] or talentNames[MSB_TalentStem(name)])) then
				if (entry.level_req) then
					entry.learned = false
					entry.seen_new = true
					entry.seen_trainable = false
				else
					table.insert(keysToRemove, spellKey)
				end
			end
		end
		for _, key in ipairs(keysToRemove) do
			ModernSpellBook_DB.spells[key] = nil
		end
	end;
}

MSB_TalentService = MSB_CTalentService()
