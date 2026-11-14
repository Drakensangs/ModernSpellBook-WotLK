--[[
	Reads the player's and pet's spells and talents, filters and sorts
	them, and remembers every spell seen (learned or from a trainer) in
	ModernSpellBook_DB.spells, keyed "SpellName|Rank".
--]]

-- Key used for ModernSpellBook_DB.spells
function MSB_SpellKey(name, rank)
	return name .. "|" .. (rank or "")
end

-- Profession skills and specializations: moved from General into their
-- own "Professions" section (English names only)
local professionRanks = {
	["Apprentice"] = true, ["Journeyman"] = true, ["Expert"] = true,
	["Artisan"] = true, ["Master"] = true,
}
local professionSpells = {
	["Basic Campfire"] = true, ["Find Herbs"] = true, ["Find Minerals"] = true,
	["Find Fish"] = true, ["Find Trees"] = true, ["Smelting"] = true, ["Disenchant"] = true,
	["Pick Lock"] = true, ["Prospecting"] = true, ["Milling"] = true,
	["Survey"] = true, ["Cooking Fire"] = true,
	["Mining"] = true, ["Herbalism"] = true, ["Skinning"] = true,
	["Fishing"] = true, ["Cooking"] = true, ["First Aid"] = true,
	["Tailoring"] = true, ["Leatherworking"] = true, ["Blacksmithing"] = true,
	["Engineering"] = true, ["Enchanting"] = true, ["Alchemy"] = true,
	["Jewelcrafting"] = true, ["Inscription"] = true, ["Runeforging"] = true,

	-- Tailoring
	["Mooncloth Tailoring"] = true, ["Northern Cloth Scavenging"] = true,
	["Shadoweave Tailoring"] = true, ["Spellfire Tailoring"] = true,
	-- Skinning
	["Master of Anatomy"] = true,
	-- Leatherworking
	["Dragonscale Leatherworking"] = true, ["Elemental Leatherworking"] = true,
	["Tribal Leatherworking"] = true,
	-- Engineering
	["Gnomish Engineer"] = true, ["Goblin Engineer"] = true,
	-- Jewelcrafting
	["Gem Perfection"] = true,
	-- Alchemy
	["Elixir Master"] = true, ["Potion Master"] = true,
	["Transmutation Master"] = true, ["Mixology"] = true,
	-- Blacksmithing
	["Toughness"] = true, ["Armorsmith"] = true,
	["Master Axesmith"] = true, ["Master Hammersmith"] = true,
	["Master Swordsmith"] = true, ["Weaponsmith"] = true,
	-- Herbalism
	["Lifeblood"] = true,
}

MSB_class "MSB_CSpellDataService"
{
	__init = function(self)
	end;

	-- ====================== KEYWORDS =============================

	BuildKeywords = function(self, spellInfo, entry)
		local kw = spellInfo.spellName .. ";"
		if (spellInfo.spellRank and spellInfo.spellRank ~= "") then
			kw = kw .. spellInfo.spellRank .. ";"
		end
		if (spellInfo.category) then
			kw = kw .. spellInfo.category .. ";"
		end
		if (spellInfo.isTalent or spellInfo.isTalentAbility) then
			kw = kw .. TALENT .. ";"
		else
			-- Read once and kept: the trainer's text, else the spell's tooltip
			if (entry.desc == nil and spellInfo.spellID) then
				entry.desc = MSB_GetSpellDescription(spellInfo.spellID, spellInfo.bookType) or ""
			end
			if (entry.desc and entry.desc ~= "") then
				kw = kw .. entry.desc .. ";"
			end
		end
		return string.lower(kw)
	end;

	-- ================= SPELL REGISTRATION ========================

	RegisterSpell = function(self, spellInfo)
		local key = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
		local entry = ModernSpellBook_DB.spells[key]

		if (not entry) then
			-- First time seeing this spell
			entry = { learned = true, seen_new = false }
			ModernSpellBook_DB.spells[key] = entry
		elseif (not entry.learned) then
			-- Seen at a trainer before it was learned
			entry.learned = true
			entry.seen_new = false
		end
		entry.keywords = self:BuildKeywords(spellInfo, entry)
	end;

	IsProfessionSpell = function(self, spellInfo)
		if (professionSpells[spellInfo.spellName]) then return true end
		if (spellInfo.spellRank and professionRanks[spellInfo.spellRank]) then return true end
		return false
	end;

	-- ====================== SORTING ==============================

	SortSpells = function(self, spells)
		table.sort(spells, function(a, b)
			if (a.spellName ~= b.spellName) then
				return a.spellName < b.spellName
			end
			local _, _, numA = string.find(a.spellRank or "", "(%d+)")
			local _, _, numB = string.find(b.spellRank or "", "(%d+)")
			return (tonumber(numA) or 0) < (tonumber(numB) or 0)
		end)
	end;

	-- ====================== FILTERING ============================

	-- Groups every learned, castable rank of the same spell and stores the
	-- sorted list (lowest rank first) on each of those spellInfos as
	-- spellInfo.learnedRanks. Only spells with 2+ learned numbered ranks get
	-- a list; the spellbook shows an expand arrow for those.
	AttachLearnedRanks = function(self, spellList)
		local function getRankNum(rankStr)
			if (not rankStr or rankStr == "") then return 0 end
			local _, _, num = string.find(rankStr, "(%d+)")
			return tonumber(num) or 0
		end

		local groups = {}
		for _, spellInfo in ipairs(spellList) do
			if (not spellInfo.isUnlearned and not spellInfo.isPassive and not spellInfo.isTalent
				and not spellInfo.isPetSpell and spellInfo.spellID and spellInfo.bookType == BOOKTYPE_SPELL) then
				local rankNum = getRankNum(spellInfo.spellRank)
				if (rankNum > 0) then
					local name = spellInfo.spellName
					if (not groups[name]) then groups[name] = { seen = {}, list = {} } end
					if (not groups[name].seen[rankNum]) then
						groups[name].seen[rankNum] = true
						spellInfo.rankNum = rankNum
						table.insert(groups[name].list, spellInfo)
					end
				end
			end
		end

		for _, group in pairs(groups) do
			local list = group.list
			if (table.getn(list) > 1) then
				table.sort(list, function(a, b) return a.rankNum < b.rankNum end)
				for _, spellInfo in ipairs(list) do
					spellInfo.learnedRanks = list
				end
			end
		end
	end;

	FilterHighestRanks = function(self, spellList)
		local function getRankNum(rankStr)
			if (not rankStr or rankStr == "") then return 0 end
			if (rankStr == "Talent") then return 1 end
			local _, _, num = string.find(rankStr, "(%d+)")
			return tonumber(num) or 0
		end

		local highestLearnedRank = {}
		for _, spellInfo in ipairs(spellList) do
			if (not spellInfo.isUnlearned) then
				local name = spellInfo.spellName
				local rankNum = getRankNum(spellInfo.spellRank)
				if (not highestLearnedRank[name] or rankNum > highestLearnedRank[name]) then
					highestLearnedRank[name] = rankNum
				end
			end
		end

		local nextUnlearnedRank = {}
		for _, spellInfo in ipairs(spellList) do
			if (spellInfo.isUnlearned) then
				local name = spellInfo.spellName
				local rankNum = getRankNum(spellInfo.spellRank)
				local learnedRank = highestLearnedRank[name] or 0
				if (rankNum > learnedRank) then
					if (not nextUnlearnedRank[name] or rankNum < nextUnlearnedRank[name]) then
						nextUnlearnedRank[name] = rankNum
					end
				end
			end
		end

		local filtered = {}
		for _, spellInfo in ipairs(spellList) do
			local name = spellInfo.spellName
			local rankNum = getRankNum(spellInfo.spellRank)
			if (spellInfo.isUnlearned) then
				if (nextUnlearnedRank[name] and rankNum == nextUnlearnedRank[name]) then
					table.insert(filtered, spellInfo)
				elseif (not highestLearnedRank[name] and rankNum == 0) then
					table.insert(filtered, spellInfo)
				end
			else
				if (rankNum == 0 or rankNum >= (highestLearnedRank[name] or 0)) then
					table.insert(filtered, spellInfo)
				end
			end
		end
		return filtered
	end;

	-- allSpells: { [category] = { spellInfo, ... } } of one tab. A keyword
	-- matching the word "New" also finds spells marked as newly learned.
	FilterSpells = function(self, filterString, allSpells)
		allSpells = allSpells or {}
		local keywords = {}
		local newWord = string.lower(NEW or "New")
		-- Plain-text matching (find with plain = true), so characters like
		-- ( [ . - are searched literally instead of breaking the pattern
		filterString = string.lower(filterString or "")
		for keyword in string.gmatch(filterString, "([^,; ]+)") do
			table.insert(keywords, keyword)
		end

		if (table.getn(keywords) == 0) then return allSpells end

		local filteredSpells = {}
		for category, spellList in pairs(allSpells) do
			for _, spellInfo in ipairs(spellList) do
				local key = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
				local entry = ModernSpellBook_DB.spells[key]
				local isNew = entry and entry.learned and not entry.seen_new
				local isMatch = true

				for _, keyword in ipairs(keywords) do
					if (isNew and keyword == newWord) then
						-- matches
					elseif (entry and entry.keywords) then
						if (not string.find(entry.keywords, keyword, 1, true)) then
							isMatch = false
							break
						end
					elseif (spellInfo.isUnlearned) then
						local searchStr = string.lower(spellInfo.spellName .. ";" .. (spellInfo.spellRank or "") .. ";" .. (spellInfo.category or ""))
						if (not string.find(searchStr, keyword, 1, true)) then
							isMatch = false
							break
						end
					else
						isMatch = false
						break
					end
				end

				if (isMatch) then
					if (filteredSpells[category] == nil) then
						filteredSpells[category] = {}
					end
					table.insert(filteredSpells[category], spellInfo)
				end
			end
		end

		return filteredSpells
	end;

	-- =================== SPELL COLLECTION ========================

	SpellInfoFromSpellBookItem = function(self, tabName, s)
		local spellNameFromBook, spellRank = MSB_GetSpellBookItemName(s, BOOKTYPE_SPELL)
		local spellIcon = MSB_GetSpellBookItemTexture(s, BOOKTYPE_SPELL)

		local spellID = s
		local castName = spellNameFromBook

		local spellInfo = {
			spellName = spellNameFromBook, spellIcon = spellIcon,
			spellID = spellID, castName = castName, category = tabName,
			bookType = BOOKTYPE_SPELL
		}

		if (ModernSpellBookFrame.unlockedStances[spellNameFromBook]) then
			spellInfo.stanceIndex = ModernSpellBookFrame.unlockedStances[spellNameFromBook]
		end

		local isPassive = MSB_IsPassiveSpell(s, BOOKTYPE_SPELL)
		if (isPassive) then
			spellRank = (spellRank and spellRank ~= "") and spellRank or PET_PASSIVE
		end

		spellInfo.castName = (spellRank and spellRank ~= "") and (spellNameFromBook.. "(".. spellRank.. ")") or spellNameFromBook
		spellInfo.spellRank = spellRank or ""
		spellInfo.isPassive = isPassive

		return spellInfo
	end;

	GetPetSpells = function(self)
		local petName = UnitName("pet")
		if (not petName) then return {} end

		local numPetSpells = HasPetSpells() or 0

		local passiveSpells = {}
		local petSpells = {}
		petSpells[petName] = {}
		for i = 1, numPetSpells do
			local spellName, spellSubName = MSB_GetSpellBookItemName(i, BOOKTYPE_PET)
			if (not spellName) then break end

			local spellIcon = MSB_GetSpellBookItemTexture(i, BOOKTYPE_PET)
			local spellInfo = {
				spellName = spellName,
				spellIcon = spellIcon,
				spellRank = spellSubName or "",
				spellID = i,
				bookType = BOOKTYPE_PET,
				isPassive = MSB_IsPassiveSpell(i, BOOKTYPE_PET),
				isTalent = false,
				isPetSpell = true,
				category = petName
			}
			-- Right click toggles autocast, as in Blizzard's pet book
			if (GetSpellAutocast) then
				local ok, canAutocast = pcall(GetSpellAutocast, i, BOOKTYPE_PET)
				spellInfo.canAutocast = ok and canAutocast and true or false
			end

			self:RegisterSpell(spellInfo)

			if (not spellInfo.isPassive) then
				table.insert(petSpells[petName], spellInfo)
			else
				table.insert(passiveSpells, spellInfo)
			end
		end

		local canShowPassives = ModernSpellBook_DB.showPassives
		if (canShowPassives) then
			for _, spellInfo in ipairs(passiveSpells) do
				table.insert(petSpells[petName], spellInfo)
			end
		end

		return petSpells
	end;

	GetPlayerSpells = function(self, showGeneralTab)
		local allSpellsDict = {}
		local canShowPassives = ModernSpellBook_DB.showPassives
		local passiveSpellsDict = {}

		-- Stances, forms, auras and presences, by name -> form index
		ModernSpellBookFrame.unlockedStances = {}
		for stanceIndex = 1, GetNumShapeshiftForms() do
			local texture, name = GetShapeshiftFormInfo(stanceIndex)
			if (not texture) then break end
			if (name) then
				ModernSpellBookFrame.unlockedStances[name] = stanceIndex
			end
		end

		local numTabs = GetNumSpellTabs and GetNumSpellTabs() or MAX_SKILLLINE_TABS or 4
		for i = 1, numTabs do
			local tabName, _, offset, numSpells = GetSpellTabInfo(i)
			if (not tabName) then break end

			if (showGeneralTab == (tabName == GENERAL)) then
				allSpellsDict[tabName] = {}
				passiveSpellsDict[tabName] = {}

				for s = offset + 1, offset + numSpells do
					if (not MSB_IsSpellHidden(s, BOOKTYPE_SPELL)) then
						local spellInfo = self:SpellInfoFromSpellBookItem(tabName, s)
						self:RegisterSpell(spellInfo)

						if (spellInfo.isPassive) then
							table.insert(passiveSpellsDict[tabName], spellInfo)
						else
							table.insert(allSpellsDict[tabName], spellInfo)
						end
					end
				end
			end
		end

		if (showGeneralTab) then
			if (canShowPassives) then
				for tabName, passiveSpells in pairs(passiveSpellsDict) do
					for i = 1, table.getn(passiveSpells) do
						table.insert(allSpellsDict[tabName], passiveSpells[i])
					end
				end
			end
			for _, spells in pairs(allSpellsDict) do
				self:SortSpells(spells)
			end
			if (allSpellsDict[GENERAL]) then
				local profSpells = {}
				local generalSpells = {}
				for _, spellInfo in ipairs(allSpellsDict[GENERAL]) do
					if (self:IsProfessionSpell(spellInfo)) then
						spellInfo.category = "Professions"
						table.insert(profSpells, spellInfo)
					else
						table.insert(generalSpells, spellInfo)
					end
				end
				allSpellsDict[GENERAL] = generalSpells
				if (table.getn(profSpells) > 0) then
					allSpellsDict["Professions"] = profSpells
				end
			end

			self:MergeUnlearnedSpells(allSpellsDict, true)
			for tabName, spells in pairs(allSpellsDict) do
				self:AttachLearnedRanks(spells)
				allSpellsDict[tabName] = self:FilterHighestRanks(spells)
			end
			return allSpellsDict
		end

		-- Merge talents with spells
		local existingCategories = {}
		for cat, _ in pairs(allSpellsDict) do
			table.insert(existingCategories, cat)
		end

		local talentGridPositions = MSB_TalentService:GetAllTalents(true)
		local talentKeys = {}
		for k, _ in pairs(talentGridPositions) do
			table.insert(talentKeys, k)
		end
		for _, origTalentGroupName in ipairs(talentKeys) do
			local talents = talentGridPositions[origTalentGroupName]
			local talentGroupName = origTalentGroupName
			if (allSpellsDict[talentGroupName] == nil) then
				local matched = false
				for _, knownGroup in ipairs(existingCategories) do
					if (string.find(string.lower(knownGroup), string.lower(string.sub(talentGroupName, 1, 4)), 1, true)) then
						talentGroupName = knownGroup
						for _, spellInfo in ipairs(talents) do
							spellInfo.category = talentGroupName
						end
						matched = true
						break
					end
				end
				if (not matched) then
					allSpellsDict[talentGroupName] = {}
					table.insert(existingCategories, talentGroupName)
				end
			end
			if (passiveSpellsDict[talentGroupName] == nil) then
				passiveSpellsDict[talentGroupName] = {}
			end
			for i = 1, table.getn(talents) do
				table.insert(passiveSpellsDict[talentGroupName], talents[i])
			end
		end

		for tabName, passiveSpells in pairs(passiveSpellsDict) do
			local namesDict = {}
			if (allSpellsDict[tabName]) then
				for listIndex, spellinfo in ipairs(allSpellsDict[tabName]) do
					if (namesDict[spellinfo.spellName] == nil) then
						namesDict[spellinfo.spellName] = {}
					end
					table.insert(namesDict[spellinfo.spellName], listIndex)
				end
			end

			if (canShowPassives) then
				self:SortSpells(passiveSpells)
			end

			for i = 1, table.getn(passiveSpells) do
				local isActiveTalent = namesDict[passiveSpells[i].spellName]
				if (isActiveTalent and allSpellsDict[tabName]) then
					for _, alreadyActiveSpellListIndex in ipairs(isActiveTalent) do
						local spellInfo = allSpellsDict[tabName][alreadyActiveSpellListIndex]
						MSB_TalentService:MarkSpellAsTalent(spellInfo)
					end
				elseif (canShowPassives) then
					if (not allSpellsDict[tabName]) then
						allSpellsDict[tabName] = {}
					end
					table.insert(allSpellsDict[tabName], passiveSpells[i])
				end
			end
		end

		for _, spells in pairs(allSpellsDict) do
			self:SortSpells(spells)
		end

		self:MergeUnlearnedSpells(allSpellsDict, false)

		for tabName, spells in pairs(allSpellsDict) do
			self:AttachLearnedRanks(spells)
			allSpellsDict[tabName] = self:FilterHighestRanks(spells)
		end

		return allSpellsDict
	end;

	-- tab: 1 class, 2 general, 3 pet. Returns the spells by category and
	-- whether they are pet spells.
	GetAvailableSpells = function(self, tab)
		if (tab == 1) then
			return self:GetPlayerSpells(false), false
		elseif (tab == 2) then
			return self:GetPlayerSpells(true), false
		elseif (tab == 3) then
			return self:GetPetSpells(), true
		else
			return {}, false
		end
	end;

	HasLearnedSpells = function(self)
		for _, entry in pairs(ModernSpellBook_DB.spells) do
			if (entry.learned) then return true end
		end
		return false
	end;

	SetupInitiallyKnownSpells = function(self)
		-- Temporarily include passives so they are registered as already seen
		local previousShowPassives = ModernSpellBook_DB.showPassives
		ModernSpellBook_DB.showPassives = true

		local allInitialSpells = {}
		table.insert(allInitialSpells, self:GetPlayerSpells(false))
		table.insert(allInitialSpells, self:GetPlayerSpells(true))
		table.insert(allInitialSpells, self:GetPetSpells())

		-- Mark everything as seen so nothing glows as "new" on first load
		for i = 1, 3 do
			for _, spellList in pairs(allInitialSpells[i]) do
				for _, spellInfo in ipairs(spellList) do
					local key = MSB_SpellKey(spellInfo.spellName, spellInfo.spellRank)
					local entry = ModernSpellBook_DB.spells[key]
					if (entry) then
						entry.seen_new = true
					end
				end
			end
		end

		ModernSpellBook_DB.showPassives = previousShowPassives
	end;

	MergeUnlearnedSpells = function(self, allSpellsDict, showGeneralTab)
		if (not ModernSpellBook_DB.showUnlearned) then return end
		if (not MSB_TrainerDataService) then return end
		local unlearned = MSB_TrainerDataService:GetUnlearnedSpells()
		if (not unlearned) then return end

		local canShowPassives = ModernSpellBook_DB.showPassives

		for category, spells in pairs(unlearned) do
			local isGeneral = (category == GENERAL)
			if (showGeneralTab == isGeneral) then
				local targetCat = category
				if (not allSpellsDict[category]) then
					-- Trainer and spellbook may name a school slightly differently
					local prefix = string.lower(string.sub(category, 1, 4))
					for existingCat, _ in pairs(allSpellsDict) do
						if (string.find(string.lower(existingCat), prefix, 1, true)) then
							targetCat = existingCat
							break
						end
					end
				end

				if (not allSpellsDict[targetCat]) then
					allSpellsDict[targetCat] = {}
				end

				for _, spellInfo in ipairs(spells) do
					if (not spellInfo.isPassive or canShowPassives) then
						table.insert(allSpellsDict[targetCat], spellInfo)
					end
				end
			end
		end
	end;

	GetUpcomingSpells = function(self)
		local playerLevel = UnitLevel("player")
		local upcoming = {}

		-- Spells that need a talent you haven't learned stay out of the row
		local talentBlocked = MSB_TrainerDataService:GetTalentBlockedSpells()

		-- Find the lowest level_req above player level among eligible spells
		local nextLevel = nil
		for key, entry in pairs(ModernSpellBook_DB.spells) do
			if (not entry.learned and entry.level_req) then
				local pipePos = string.find(key, "|", 1, true)
				local name = pipePos and string.sub(key, 1, pipePos - 1)
				if (name and not talentBlocked[name]) then
					local lvl = entry.level_req
					if (lvl > playerLevel) then
						if (not nextLevel or lvl < nextLevel) then
							nextLevel = lvl
						end
					end
				end
			end
		end

		if (not nextLevel) then return upcoming, nil end

		-- Collect all spells at that level (excluding talent-blocked)
		for key, entry in pairs(ModernSpellBook_DB.spells) do
			if (not entry.learned and entry.level_req == nextLevel) then
				local pipePos = string.find(key, "|", 1, true)
				if (pipePos) then
					local name = string.sub(key, 1, pipePos - 1)
					if (not talentBlocked[name]) then
						table.insert(upcoming, {
							name = name,
							rank = string.sub(key, pipePos + 1),
							icon = entry.icon,
							desc = entry.desc,
							cost = entry.cost,
						})
					end
				end
			end
		end

		-- Sort alphabetically
		table.sort(upcoming, function(a, b) return a.name < b.name end)

		return upcoming, nextLevel
	end;

	UpdateSpellCounter = function(self)
		if (not ModernSpellBookFrame.spellCounter) then return end
		if (not ModernSpellBook_DB.showSpellCounter) then
			ModernSpellBookFrame.spellCounter:Hide()
			return
		end

		local learned = 0
		local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 4
		for i = 1, numTabs do
			local tabName, _, _, numSpells = GetSpellTabInfo(i)
			if (not tabName) then break end
			learned = learned + (numSpells or 0)
		end

		local unlearned = 0
		if (MSB_TrainerDataService) then
			local unlearnedSpells = MSB_TrainerDataService:GetUnlearnedSpells()
			if (unlearnedSpells) then
				for _, spells in pairs(unlearnedSpells) do
					unlearned = unlearned + table.getn(spells)
				end
			end
		end

		if (ModernSpellBook_DB.trainerScanned and unlearned > 0) then
			ModernSpellBookFrame.spellCounter:SetText(learned .. "/" .. (learned + unlearned) .. " learned")
		elseif (ModernSpellBook_DB.trainerScanned) then
			ModernSpellBookFrame.spellCounter:SetText(learned .. " learned")
		else
			ModernSpellBookFrame.spellCounter:SetText(learned .. "/? learned")
		end
		ModernSpellBookFrame.spellCounter:Show()
	end;
}

MSB_SpellDataService = MSB_CSpellDataService()
