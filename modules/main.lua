-- main.lua
-- entrypoint. grabs every module straight off github, cache-busted, then runs the suite.

task.wait(0.1)

local REPO_OWNER  = "SadManic"
local REPO_NAME   = "Environment-Audit--LUA-"
local REPO_BRANCH = "main"
local REPO_PATH   = "modules"

local BASE_URL = string.format(
    "https://raw.githubusercontent.com/%s/%s/%s/%s/",
    REPO_OWNER, REPO_NAME, REPO_BRANCH, REPO_PATH
)

local moduleCache = {}

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

local Config = import("config")
local Tests  = import("tests")
local Ui     = import("ui")
local Logger = import("logger")

Config.log("INIT", "Diagnostic suite starting, waiting for environment to settle", "INFO")

local CoreGui = game:GetService("CoreGui")
local devConsole = nil
pcall(function()
    devConsole = CoreGui:WaitForChild("DevConsoleMaster", 3)
end)
Config.log("INIT", devConsole
    and "DevConsoleMaster located, rich-text rendering available"
    or "DevConsoleMaster not found, falling back to plain print output",
    devConsole and "INFO" or "WARN")

-- 1. Start benchmark timer
local startTime = tick()

-- run the suite
local runData = Tests.run()

-- export csv/json logs
runData.EXPORT_ENABLED = Logger.EXPORT_ENABLED
runData.jsonExportStatus = Logger.export(runData)

-- 2. End benchmark timer
local durationMs = (tick() - startTime) * 1000

-- render output with benchmark time and interactive hooks
local outputLines, animatedLineIndices, filterMarker, copyMarker = Ui.buildOutputLines(runData, durationMs)
local plainBuffer = Ui.printPlain(outputLines, animatedLineIndices)
Ui.attachDevConsole(devConsole, outputLines, animatedLineIndices, plainBuffer, runData, durationMs, filterMarker, copyMarker)

Config.log("DONE", string.format("Diagnostic suite finished in %.1fms", durationMs), "INFO")
