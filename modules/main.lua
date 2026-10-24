-- main.lua
-- Entrypoint for AEGIS security suite.
--
-- Usage:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/SadManic/Environment-Audit--LUA-/main/modules/main.lua"))()

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

Config.log("INIT", "AEGIS suite starting, waiting for environment to settle", "INFO")

local CoreGui = game:GetService("CoreGui")
local devConsole = nil
pcall(function()
    devConsole = CoreGui:WaitForChild("DevConsoleMaster", 3)
end)
Config.log("INIT", devConsole
    and "DevConsoleMaster located, rich-text rendering available"
    or "DevConsoleMaster not immediately found, fallback listeners engaged",
    devConsole and "INFO" or "WARN")

local function runFullAudit()
    local startTime = tick()
    local runData = Tests.run()

    runData.EXPORT_ENABLED = Logger.EXPORT_ENABLED
    runData.jsonExportStatus = Logger.export(runData)

    local durationMs = (tick() - startTime) * 1000

    local outputLines, animatedLineIndices, lineMetadata = Ui.buildOutputLines(runData, durationMs)
    local plainBuffer = Ui.printPlain(outputLines, animatedLineIndices)
    Ui.attachDevConsole(devConsole, outputLines, animatedLineIndices, plainBuffer, lineMetadata, runData, durationMs, runFullAudit)

    Config.log("DONE", string.format("AEGIS suite run finished in %.2f ms", durationMs), "INFO")
end

runFullAudit()
