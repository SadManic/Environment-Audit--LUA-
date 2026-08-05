-- config.lua
-- Color palette, category weights, and debug settings shared across modules.

local Config = {}

-- ===== Debug settings =====
Config.DEBUG_ENABLED = false -- flip to true to see [UNC-DIAG] trace lines in the output console
Config.DEBUG_PREFIX  = "[UNC-DIAG]"

-- ===== Colors (hex) =====
Config.HEX_GREEN  = "#50FA7B"
Config.HEX_RED    = "#FF5555"
Config.HEX_YELLOW = "#F1FA8C"
Config.HEX_CYAN   = "#8BE9FD"
Config.HEX_PURPLE = "#BD93F9"
Config.HEX_WHITE  = "#FFFFFF"

-- ===== Categories =====
Config.CAT_BASE = "UNC Baseline"
Config.CAT_TECH = "Debug & Reflection"
Config.CAT_ADV  = "Extra APIs"
Config.CAT_INT  = "Integrity & Sandbox"

Config.categoryOrder = { Config.CAT_BASE, Config.CAT_TECH, Config.CAT_ADV, Config.CAT_INT }

-- Baseline tests count more than the extras
Config.CATEGORY_WEIGHT = {
    [Config.CAT_BASE] = 3,
    [Config.CAT_TECH] = 2,
    [Config.CAT_INT]  = 2,
    [Config.CAT_ADV]  = 1,
}

-- ===== Export file names =====
Config.CSV_LOG_FILE     = "unc_results_log.csv"
Config.JSON_LOG_FILE    = "unc_results_log.json"
Config.JSON_BACKUP_FILE = "unc_results_log.json.bak"

-- ===== Shared debug logger =====
-- Other modules call Config.log(stage, msg, level) instead of each rolling their own.
function Config.log(stage, msg, level)
    if not Config.DEBUG_ENABLED then return end
    level = level or "INFO"
    local ts = (type(os) == "table" and type(os.date) == "function")
        and (select(2, pcall(os.date, "%H:%M:%S")) or "??:??:??")
        or tostring(os and os.time and os.time() or "??:??:??")
    print(string.format("%s [%s] [%s] %s :: %s", Config.DEBUG_PREFIX, ts, level, stage, msg))
end

return Config
