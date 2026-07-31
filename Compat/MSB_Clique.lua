function MSB_SetupCliqueIntegration(spellBookObj)
	if (spellBookObj.frame.cliqueIntegrated) then return end
	if (not Clique or not Clique.Toggle) then return end

	spellBookObj.frame.cliqueIntegrated = true

	if (not CliqueFrame) then
		Clique:Toggle()
		if (CliqueFrame) then
			CliqueFrame:SetParent(UIParent)
			CliqueFrame:Hide()
		end
	else
		CliqueFrame:SetParent(UIParent)
	end

	local tabNumber = table.getn(spellBookObj.frame.Tabgroups) + 1
	local tab = CTab(spellBookObj.frame, "Clique", tabNumber, function()
		Clique:Toggle()
		if (CliqueFrame and CliqueFrame:IsShown()) then
			CliqueFrame:ClearAllPoints()
			CliqueFrame:SetPoint("TOPLEFT", ModernSpellBookFrame, "TOPRIGHT", 6, 0)
		end
	end)
	table.insert(spellBookObj.frame.Tabgroups, tab)
	spellBookObj.frame.cliqueTab = tab

	spellBookObj:PositionAllTabs()
end
