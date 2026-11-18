-- English (enUS), the default: loaded on every client, first. The client's
-- own language file loads next and replaces these strings; a string it
-- leaves out stays English. Text the game already has in the client's
-- language comes from MSB_STR (Lib\MSB_Compat.lua) instead.
-- Translations keep the "%s" and "%d" fill-ins; "|n" is a line break.

MSB_L = {
	-- Settings menu
	SHOW_PASSIVES = "Show passives",
	REMEMBER_PAGE = "Remember page",
	SPELL_COUNTER = "Spell counter",
	SHOW_TALENTS = "Show talents",
	SHOW_UNLEARNED = "Show unlearned",
	SHOW_UPCOMING = "Show upcoming",
	CONTINUATION_HEADERS = "Continuation headers",
	LOCK_POSITION = "Lock position & scale",
	CLASS_BOOKMARK = "Class-colored bookmark",
	HIGHLIGHT_UNPLACED = "Highlight spells not on action bars",
	HIGHLIGHTS = "Highlights",
	LEARNED_GLOW = "Learned spells glow",
	LEARNED_BADGE = "Learned spells badge",
	AVAILABLE_GLOW = "Available spells glow",
	AVAILABLE_BADGE = "Available spells badge",
	FONT_SIZE = "Font size",
	TEXT_COLOR = "Spell text color",
	TEXT_COLOR_LIGHT = "Light",
	TEXT_COLOR_DARK = "Dark",
	ICON_FRAME = "Spell icon frame",
	ICON_FRAME_SPELLS = "Spells",
	ICON_FRAME_OTHER = "Other",
	ICON_FRAME_UNLEARNED = "Unlearned",
	RESET_POSITION = "Reset position & scale",

	-- Book
	TAB_PET = "Pet",
	TAB_TRAINING = "Training",		-- WhatsTraining tab
	SEARCH_PLACEHOLDER = "Search abilities, keywords",
	NO_RESULTS = "No results. Try a different search term.|nFor example, '%s, %s'",		-- "New", "Talent"
	NO_PET_SPELLS = "No pet spells available.",
	PAGE_NUMBER = "Page %d / %d",
	TRAINER_HINT_LONG = "Visit a class trainer in a major city to fetch the FULL list of available spells.",
	TRAINER_HINT_SHORT = "Visit a class trainer to fetch the FULL spell list.",
	UPCOMING_SPELLS = "New spells at %d:",		-- level
	COUNTER_LEARNED = "%d learned",
	COUNTER_LEARNED_OF = "%d/%d learned",
	COUNTER_LEARNED_UNKNOWN = "%d/? learned",
	BADGE_TRAIN = "Train",
	HIDE_RANKS = "Hide ranks",
	SHOW_RANKS = "Show all ranks",
	POSITION_LOCKED = "Position & scale locked",
	DRAG_TO_RESIZE = "Drag to resize",
	TWO_PAGE_VIEW = "Two page view",
	ONE_PAGE_VIEW = "One page view",

	-- Spell tooltips
	REQUIRES_TALENT = "Requires talent point.",
	VISIT_TRAINER = "Visit a class trainer to learn.",
	NOT_ON_BARS = "Not on your action bars",
	TRAINING_COST = "Training cost:",
	TRAINING_FREE = "Free",
	TOTAL_COST = "Total Cost: %s",		-- WhatsTraining: money
	COST = "Cost: %s",		-- WhatsTraining: money

	-- Chat messages
	DB_RESET = "Settings reset (DB version %s).",
	TRAINER_CAPTURED = "Captured %d spells from the trainer.",
	SETTINGS_RESET = "Settings reset to defaults.",
	NO_TRAINER_DATA = "No trainer cache to clear.",
	TRAINER_DATA_CLEARED = "Trainer cache cleared. Visit a trainer to rescan.",
	COMBAT_NO_OPEN = "/msb can't open the book in combat. Use your spellbook key.",
	COMBAT_NO_RESET = "Can't reset settings in combat.",
	COMMANDS = "commands:",
	CMD_TOGGLE = "Open or close the spellbook",
	CMD_RESET = "Reset settings to defaults",
	CMD_RESCAN = "Forget trainer spells (rescanned on your next visit)",
}
