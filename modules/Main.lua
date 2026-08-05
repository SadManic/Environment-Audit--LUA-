--[[
    main.lua
    Entry point. Pulls every sub-module straight from the raw GitHub URLs below,
    cache-busts each request so you're never stuck on a stale copy, and then
    runs the full diagnostic suite.

    Usage (paste into your executor):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/<user>/<repo>/main/src/main.lua"))()
]]

task.wait(0.1)

-- ===== Repo config =====
local REPO_OWNER  = "your-github-username"
local REPO_NAME   = "unc-suite"
local REPO_BRANCH = "main"
local REPO_PATH   = "src" -- folder inside the repo that holds the .lua modules

local BASE_URL = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s/",
    REPO_OWNER, REPO_NAME, REPO_BRANCH, REPO_PATH
)

-- ===== Module cache so each file is only fetched once per run =====
local moduleCache = {}

--[[
    import(name)
    Fetches "<name>.lua" from the repo (cache-busted with a query param so
    executors/CDNs don't serve a stale copy), loads it, and caches the result
    for the rest of this run. Modules call import(...) themselves to pull in
    their own dependencies, so load order doesn't matter.
]]
function import(name)
    if moduleCache[name] then
        return moduleCache[name]
    end

    local url = BASE_URL .. name .. ".lua?cachebust=" .. tostring(math.random(1, 1e9)) .. tostring(tick())

    local ok, source = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(source) ~= "string" or source == "" then
        error(string.format("[import] Failed to fetch module '%s' from %s :: %s", name, url, tostring(source)))
    end

    local chunk, loadErr = loadstring(source, "=" .. name .. ".lua")
    if not chunk then
        error(string.format("[import] Failed to compile module '%s' :: %s", name, tostring(loadErr)))
    end

    local ok2, result = pcall(chunk)
    if not ok2 then
        error(string.format("[import] Error executing module '%s' :: %s", name, tostring(result)))
    end

    moduleCache[name] = result
    return result
end

-- ===== Load modules =====
local Config = import("config")
local Tests  = import("tests")
local Ui     = import("ui")
local Logger = import("logger")

Config.log("INIT", "Diagnostic suite starting, waiting for environment to settle", "INFO")

-- ===== Locate DevConsole (optional, enables rich-text rendering) =====
local CoreGui = game:GetService("CoreGui")
local devConsole = nil
pcall(function()
    devConsole = CoreGui:WaitForChild("DevConsoleMaster", 3)
end)
Config.log("INIT", devConsole
    and "DevConsoleMaster located, rich-text rendering available"
    or "DevConsoleMaster not found, falling back to plain print output",
    devConsole and "INFO" or "WARN")

-- ===== Run the suite =====
local runData = Tests.run()

-- ===== Export CSV/JSON logs =====
runData.EXPORT_ENABLED = Logger.EXPORT_ENABLED
runData.jsonExportStatus = Logger.export(runData)

-- ===== Render output =====
local outputLines, animatedLineIndices = Ui.buildOutputLines(runData)
local plainBuffer = Ui.printPlain(outputLines, animatedLineIndices)
Ui.attachDevConsole(devConsole, outputLines, animatedLineIndices, plainBuffer)

Config.log("DONE", "Diagnostic suite finished", "INFO")
