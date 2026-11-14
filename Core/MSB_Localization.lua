--[[
	Translated UI strings. Missing keys fall back to enUS.
	Supported: enUS, frFR, deDE, esES, esMX, ruRU (ruRU by ZamestoTV)
--]]

MSB_class "MSB_CLocalization"
{
	__init = function(self)
		self.locales = {}

		self.locales["enUS"] = {
			ShowPassive = "Show passives",
			SearchAbilities = "Search abilities, keywords",
			NoResults = "No results. Try a different search term.|nFor example, '",
			NoPetSpells = "No pet spells available.",
		}

		self.locales["frFR"] = {
			ShowPassive = "Afficher les passifs",
			SearchAbilities = "Rechercher des sorts, mots-clés",
			NoResults = "Aucun résultat. Essayez un autre terme de recherche.|nPar exemple, '",
			NoPetSpells = "Aucune compétence de familier disponible.",
		}

		self.locales["deDE"] = {
			ShowPassive = "Passive anzeigen",
			SearchAbilities = "Fähigkeiten, Schlüsselwörter suchen",
			NoResults = "Keine Ergebnisse. Versuchen Sie es mit einem anderen Suchbegriff.|nZum Beispiel, '",
			NoPetSpells = "Keine Begleiterfähigkeiten verfügbar.",
		}

		self.locales["esES"] = {
			ShowPassive = "Mostrar pasivos",
			SearchAbilities = "Buscar habilidades, palabras clave",
			NoResults = "Sin resultados. Pruebe con un término de búsqueda diferente.|nPor ejemplo, '",
			NoPetSpells = "No hay hechizos de mascota disponibles.",
		}

		self.locales["esMX"] = {
			ShowPassive = "Mostrar pasivas",
			SearchAbilities = "Buscar habilidades, palabras clave",
			NoResults = "Sin resultados. Intenta con otro término de búsqueda.|nPor ejemplo, '",
			NoPetSpells = "No hay hechizos de mascota disponibles.",
		}

		self.locales["ruRU"] = {
			ShowPassive = "Показать пассивные",
			SearchAbilities = "Поиск способностей, ключевые слова",
			NoResults = "Нет результатов. Попробуйте другой поисковый запрос.|nНапример, '",
			NoPetSpells = "Нет доступных заклинаний питомца.",
		}

		self.current = setmetatable(self.locales[GetLocale()] or {}, { __index = self.locales["enUS"] })
	end;
}

MSB_Localization = MSB_CLocalization()
