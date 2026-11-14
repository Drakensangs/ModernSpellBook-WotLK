-- Clique support: opens Clique's binding panel beside the book. A "Clique"
-- tab in the two page view, a side button with Clique's icon in the one
-- page view.

local CLIQUE_ICON = "Interface\\AddOns\\Clique\\Images\\CliqueIcon"

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

	-- However the panel opens or closes: keep the side button lit while it is
	-- open, and make spell clicks bind (open) or cast (closed)
	if (CliqueFrame) then
		-- Kept on screen; PlaceCompatPanel puts it beside the book, or over
		-- it on narrow screens
		CliqueFrame:SetClampedToScreen(true)
		CliqueFrame:SetFrameStrata("HIGH")
		local function OnPanelToggled()
			spellBookObj:UpdateCompatButtons()
			spellBookObj:RefreshCastAttributes()
		end
		CliqueFrame:HookScript("OnShow", OnPanelToggled)
		CliqueFrame:HookScript("OnHide", OnPanelToggled)
	end

	local tab = spellBookObj:AddCompatAction({
		name = "Clique",
		tabLabel = "Clique",
		tooltip = "Clique",
		icon = CLIQUE_ICON,
		onClick = function()
			Clique:Toggle()
			if (CliqueFrame and CliqueFrame:IsShown()) then
				spellBookObj:PlaceCompatPanel(CliqueFrame)
			end
		end,
		isOpen = function()
			return CliqueFrame and CliqueFrame:IsShown()
		end,
	})
	spellBookObj.frame.cliqueTab = tab

	-- Clique's panel normally lives inside the stock spellbook and closes with
	-- it; moved to UIParent above, it has to be closed with our window instead.
	-- Closed the way Clique closes it: its own OnHide resets the spell-button
	-- covers, and its pullout tab is unchecked here.
	spellBookObj.frame:HookScript("OnHide", function()
		if (CliqueFrame and CliqueFrame:IsShown()) then
			CliqueFrame:Hide()
			if (CliquePulloutTab) then CliquePulloutTab:SetChecked(nil) end
		end
	end)
end
