--[[
	Reads a class trainer's spell list when you open it and saves spells
	you haven't learned yet (learned = false), so the book can show them
	as unlearned with their required level and training cost.
--]]

-- Name of the talent a spell comes from, as far as the name tells: the
-- spell itself ("Pyroblast") or its base before a form suffix
-- ("Mangle (Cat)" -> "Mangle").
local function TalentStem(spellName)
	return string.match(spellName, "^(.-) %(") or spellName
end
MSB_TalentStem = TalentStem

local TRAINER_FILTER_TYPES = { "available", "unavailable", "used" }

MSB_class "MSB_CTrainerDataService"
{
	__init = function(self)
		self.frame = CreateFrame("Frame")
		self.frame:RegisterEvent("TRAINER_SHOW")

		local service = self
		self.frame:SetScript("OnEvent", function()
			MSB_After(0.3, function()
				service:CaptureTrainerData()
			end)
		end)
	end;

	-- =================== CAPTURE =============================

	CaptureTrainerData = function(self)
		if (not GetNumTrainerServices) then return end
		-- Profession trainers list recipes such as "Arcane Elixir", which the
		-- name check below would take for a class school
		if (IsTradeskillTrainer and IsTradeskillTrainer()) then return end

		-- The trainer only lists what its filters let through: with every
		-- filter off it reports no services at all (not even the headers).
		-- So every filter is turned on before anything is counted, and the
		-- player's own choices are always put back afterwards, even if the
		-- scan stops early or fails.
		local savedFilters = self:ShowAllTrainerServices()
		local ok, err = pcall(self.ScanTrainerServices, self)
		self:RestoreTrainerFilters(savedFilters)
		if (not ok) then geterrorhandler()(err) end
	end;

	-- Turns every trainer filter on; returns the player's previous settings
	ShowAllTrainerServices = function(self)
		local savedFilters = {}
		if (not SetTrainerServiceTypeFilter) then return savedFilters end
		for _, filterType in ipairs(TRAINER_FILTER_TYPES) do
			if (GetTrainerServiceTypeFilter) then
				local ok, isOn = pcall(GetTrainerServiceTypeFilter, filterType)
				if (ok) then savedFilters[filterType] = isOn and 1 or 0 end
			end
			pcall(SetTrainerServiceTypeFilter, filterType, 1, 0)
		end
		return savedFilters
	end;

	RestoreTrainerFilters = function(self, savedFilters)
		if (not SetTrainerServiceTypeFilter or not savedFilters) then return end
		for filterType, isOn in pairs(savedFilters) do
			if (isOn == 0) then pcall(SetTrainerServiceTypeFilter, filterType, 0, 0) end
		end
	end;

	-- Reads the full list; expects every filter to be on already
	ScanTrainerServices = function(self)
		local numServices = GetNumTrainerServices()
		if (not numServices or numServices == 0) then return end

		-- Detect if this is a class trainer by checking if any
		-- service header matches a talent tab or class spell tab name.
		local classCategoryList = {}
		for t = 1, GetNumTalentTabs() do
			local name = GetTalentTabInfo(t)
			if (name) then table.insert(classCategoryList, name) end
		end
		local numSpellTabs = GetNumSpellTabs and GetNumSpellTabs() or 4
		for i = 1, numSpellTabs do
			local name = GetSpellTabInfo(i)
			if (name) then table.insert(classCategoryList, name) end
		end
		table.insert(classCategoryList, GENERAL or "General")

		local function MatchClassCategory(name)
			if (not name or name == "") then return nil end
			local lowerName = string.lower(name)
			for _, canonical in ipairs(classCategoryList) do
				local lowerCanonical = string.lower(canonical)
				if (lowerName == lowerCanonical) then
					return canonical
				end
				local prefixLen = math.min(4, string.len(lowerCanonical))
				if (prefixLen > 0 and string.find(lowerName, string.sub(lowerCanonical, 1, prefixLen), 1, true) == 1) then
					return canonical
				end
			end
			return nil
		end

		local isClassTrainer = false
		for i = 1, numServices do
			local ok, name = pcall(GetTrainerServiceInfo, i)
			if (ok and name) then
				name = string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
				if (MatchClassCategory(name)) then
					isClassTrainer = true
					break
				end
			end
		end

		if (not isClassTrainer) then return end

		-- No rescan unless the trainer lists more services than last time
		-- (both counts are of the full, unfiltered list).
		-- Lists saved by older versions (no training costs) are read once more.
		if (ModernSpellBook_DB.trainerScanned and ModernSpellBook_DB.trainerServiceCount
			and ModernSpellBook_DB.trainerCostsSaved) then
			if (numServices <= ModernSpellBook_DB.trainerServiceCount) then
				return
			end
		end

		local currentSpecHeader = GENERAL or "General"
		local currentSpecIsValid = true

		local generalCategories = {
			["Defense"] = true,
			["Weapons"] = true,
			["Armor"] = true,
			["Plate Mail"] = true,
			["Mail"] = true,
			["Leather"] = true,
			["Shield"] = true,
		}

		local skipSpells = {
			["Plate Mail"] = true, ["Mail"] = true, ["Leather"] = true,
			["Shield"] = true, ["Block"] = true, ["Parry"] = false, ["Dodge"] = true,
			["Dual Wield"] = true,
		}

		local capturedCount = 0

		for i = 1, numServices do
			-- serviceType: "header", "available", "unavailable" or "used"
			local name, rank, serviceType
			local ok, r1, r2, r3 = pcall(GetTrainerServiceInfo, i)
			if (ok) then
				name = r1 and string.gsub(r1, "^%s+", "") or nil
				name = name and string.gsub(name, "%s+$", "") or nil
				rank = r2 and string.gsub(r2, "^%s+", "") or ""
				rank = string.gsub(rank, "%s+$", "")
				serviceType = r3
			end

			if (name and name ~= "") then
				local icon = ""
				if (GetTrainerServiceIcon) then
					local iconOk, iconResult = pcall(GetTrainerServiceIcon, i)
					if (iconOk) then icon = iconResult or "" end
				end

				local noIcon = (not icon or icon == "" or icon == 0)
				-- Headers by type; the missing icon is only a fallback, since a
				-- spell without an icon would otherwise hide the rest of its school
				local isHeader
				if (serviceType) then isHeader = (serviceType == "header") else isHeader = noIcon end

				if (skipSpells[name]) then
					-- Armor and weapon skills: not shown in the book
				elseif (isHeader) then
					-- Category header
					if (generalCategories[name]) then
						currentSpecHeader = GENERAL or "General"
						currentSpecIsValid = true
					else
						local canonical = MatchClassCategory(name)
						if (canonical) then
							currentSpecHeader = canonical
							currentSpecIsValid = true
						else
							currentSpecHeader = name
							currentSpecIsValid = false
						end
					end
				elseif (not currentSpecIsValid) then
					-- Skip spells under non-class categories (e.g. Poisons)
				else
					if (noIcon) then icon = "Interface\\Icons\\INV_Misc_QuestionMark" end
					local levelReq = 0
					if (GetTrainerServiceLevelReq) then
						local lvlOk, lvlResult = pcall(GetTrainerServiceLevelReq, i)
						if (lvlOk) then levelReq = lvlResult or 0 end
					end

					local description = nil
					pcall(function()
						if (GetTrainerServiceDescription) then
							description = GetTrainerServiceDescription(i)
							if (description) then
								description = string.gsub(string.gsub(description, "^%s+", ""), "%s+$", "")
							end
						end
					end)

					-- Copper the trainer asks for (shown in the spell's tooltip)
					local cost = nil
					pcall(function()
						if (GetTrainerServiceCost) then
							cost = GetTrainerServiceCost(i)
						end
					end)

					local key = MSB_SpellKey(name, rank or "")
					local entry = ModernSpellBook_DB.spells[key]

					if (not entry) then
						-- New spell from trainer, player doesn't know it yet
						ModernSpellBook_DB.spells[key] = {
							icon = icon,
							category = currentSpecHeader,
							desc = description,
							cost = cost,
							level_req = levelReq,
							keywords = string.lower(name .. ";" .. (rank or "") .. ";" .. currentSpecHeader .. ";" .. (description or "") .. ";"),
							learned = false,
							seen_new = true,
							seen_trainable = false,
						}
						capturedCount = capturedCount + 1
					elseif (not entry.learned) then
						-- Already registered as unlearned, update trainer data
						entry.icon = icon
						entry.category = currentSpecHeader
						entry.desc = description
						entry.keywords = string.lower(name .. ";" .. (rank or "") .. ";" .. currentSpecHeader .. ";" .. (description or "") .. ";")
						entry.cost = cost
						entry.level_req = levelReq
						capturedCount = capturedCount + 1
					else
						-- Already learned, just update metadata
						capturedCount = capturedCount + 1
					end
				end
			end
		end

		ModernSpellBook_DB.trainerScanned = true
		ModernSpellBook_DB.trainerServiceCount = numServices
		ModernSpellBook_DB.trainerCostsSaved = true

		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00ModernSpellBook:|r Captured " .. capturedCount .. " spells from trainer.")

		-- The pages are rebuilt even while the book is closed: otherwise the
		-- next opening shows the pages from before the trainer visit
		MSB_SpellBook:MarkDirty()
		if (ModernSpellBookFrame and ModernSpellBookFrame:IsVisible()) then
			MSB_SpellBook:DrawPage()
		end
	end;

	-- ================= UNLEARNED SPELLS =======================

	-- Unlearned talents, by name
	GetUnlearnedTalentNames = function(self)
		local names = {}
		for t = 1, GetNumTalentTabs() do
			for i = 1, GetNumTalents(t) do
				local nameTalent, _, _, _, currRank = GetTalentInfo(t, i)
				if (nameTalent and currRank == 0) then
					names[nameTalent] = true
				end
			end
		end
		return names
	end;

	-- Trainer spells (by name) that need a talent you haven't learned,
	-- e.g. "Mangle (Cat)" without the Mangle talent
	GetTalentBlockedSpells = function(self)
		local unlearnedTalents = self:GetUnlearnedTalentNames()
		local blocked = {}
		for spellKey, entry in pairs(ModernSpellBook_DB.spells) do
			if (not entry.learned) then
				local name = string.match(spellKey, "^(.-)|") or spellKey
				if (unlearnedTalents[name] or unlearnedTalents[TalentStem(name)]) then
					blocked[name] = true
				end
			end
		end
		return blocked
	end;

	GetUnlearnedSpells = function(self)
		-- Build a set of currently known spells from spellbook
		local knownSet = {}
		local knownHighestRank = {}
		local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 4
		for i = 1, numTabs do
			local tabName, _, offset, numSpells = GetSpellTabInfo(i)
			if (not tabName) then break end
			for s = offset + 1, offset + numSpells do
				local spellName, spellRank = GetSpellName(s, BOOKTYPE_SPELL)
				if (spellName) then
					knownSet[MSB_SpellKey(spellName, spellRank or "")] = true
					local _, _, num = string.find(spellRank or "", "(%d+)")
					local rankNum = tonumber(num) or 0
					if (not knownHighestRank[spellName] or rankNum > knownHighestRank[spellName]) then
						knownHighestRank[spellName] = rankNum
					end
				end
			end
		end

		local talentBlockedSpells = self:GetTalentBlockedSpells()

		-- Known spell names, plus their stems, to tell learned talents apart
		local knownNames = {}
		for spellName in pairs(knownHighestRank) do
			knownNames[spellName] = true
			knownNames[TalentStem(spellName)] = true
		end

		local unlearnedByCategory = {}
		local trainerSpellNames = {}

		-- Collect unlearned spells from DB (trainer data)
		if (ModernSpellBook_DB.trainerScanned) then
			for spellKey, entry in pairs(ModernSpellBook_DB.spells) do
				if (not entry.learned) then
					local pipePos = string.find(spellKey, "|", 1, true)
					local name = string.sub(spellKey, 1, pipePos - 1)
					local rank = string.sub(spellKey, pipePos + 1)

					if (knownSet[spellKey]) then
						-- Just learned this exact rank: flag it as "New"
						entry.learned = true
						entry.seen_new = false
					else
						local _, _, num = string.find(rank or "", "(%d+)")
						local rankNum = tonumber(num) or 0
						local highest = knownHighestRank[name]
						if (highest and (rankNum <= highest or highest == 0)) then
							entry.learned = true
						else
							local cat = entry.category or "Unknown"
							if (not unlearnedByCategory[cat]) then
								unlearnedByCategory[cat] = {}
							end
							table.insert(unlearnedByCategory[cat], {
								spellName = name,
								spellRank = rank,
								spellIcon = entry.icon,
								spellID = nil,
								bookType = nil,
								description = entry.desc,
								cost = entry.cost,
								isPassive = (rank == "Passive" or rank == PET_PASSIVE),
								isTalent = false,
								isPetSpell = false,
								isUnlearned = true,
								talentBlocked = talentBlockedSpells[name] or false,
								levelReq = entry.level_req,
								castName = nil,
								category = cat,
							})
							trainerSpellNames[name] = true
						end
					end
				end
			end
		end

		-- Always add unlearned talents (doesn't require trainer data)
		local _, englishClass = UnitClass("player")
		local isDeathKnight = (englishClass == "DEATHKNIGHT")

		for t = 1, GetNumTalentTabs() do
			local talentGroupName = GetTalentTabInfo(t)
			if (talentGroupName) then
				for i = 1, GetNumTalents(t) do
					local nameTalent, icon, tier, _, currRank, maxRank = GetTalentInfo(t, i)
					if (nameTalent and currRank == 0) then
						if (not knownNames[nameTalent]) then
							local trainerHasRanks = trainerSpellNames[nameTalent]

							if (not unlearnedByCategory[talentGroupName]) then
								unlearnedByCategory[talentGroupName] = {}
							end

							local alreadyAdded = false
							for _, s in ipairs(unlearnedByCategory[talentGroupName]) do
								if (s.spellName == nameTalent and (not trainerHasRanks or s.spellRank == "Rank 1")) then
									alreadyAdded = true
									break
								end
							end

							if (not alreadyAdded) then
								local rankLabel
								local isPassiveTalent
								if (trainerHasRanks) then
									rankLabel = "Talent"
									isPassiveTalent = false
								elseif (maxRank == 1) then
									rankLabel = "Talent"
									isPassiveTalent = false
								else
									rankLabel = nil
									isPassiveTalent = true
								end

								if (rankLabel) then
								table.insert(unlearnedByCategory[talentGroupName], {
									spellName = nameTalent,
									spellRank = rankLabel,
									spellIcon = icon,
									spellID = nil,
									bookType = nil,
									isPassive = isPassiveTalent,
									isTalent = true,
									talentGrid = {t, i},
									isPetSpell = false,
									isUnlearned = true,
									levelReq = isDeathKnight and math.max(55, 10 + (tier - 1) * 5) or (10 + (tier - 1) * 5),
									castName = nil,
									category = talentGroupName,
								})
							end
							end
						end
					end
				end
			end
		end

		-- Sort each category
		for _, spells in pairs(unlearnedByCategory) do
			local groupMinLevel = {}
			for _, sp in ipairs(spells) do
				local lvl = sp.levelReq or 0
				if (not groupMinLevel[sp.spellName] or lvl < groupMinLevel[sp.spellName]) then
					groupMinLevel[sp.spellName] = lvl
				end
			end

			table.sort(spells, function(a, b)
				local aGroupLvl = groupMinLevel[a.spellName] or 0
				local bGroupLvl = groupMinLevel[b.spellName] or 0
				if (aGroupLvl ~= bGroupLvl) then
					return aGroupLvl < bGroupLvl
				end
				if (a.spellName ~= b.spellName) then
					return a.spellName < b.spellName
				end
				return (a.levelReq or 0) < (b.levelReq or 0)
			end)
		end

		return unlearnedByCategory
	end;
}

MSB_TrainerDataService = MSB_CTrainerDataService()
