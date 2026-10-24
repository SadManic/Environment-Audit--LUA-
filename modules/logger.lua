-- logger.lua
-- csv/json logging, appends every run

local Config = import("config")
local JSON   = import("json")

local Logger = {}

Logger.EXPORT_ENABLED = (type(writefile) == "function" and type(readfile) == "function")

local function csvEscape(str)
    str = tostring(str)
    if str:find('[,"\n]') then
        str = '"' .. str:gsub('"', '""') .. '"'
    end
    return str
end

local function getTimestamp()
    if type(os) == "table" and type(os.date) == "function" then
        local ok, result = pcall(os.date, "%Y-%m-%d %H:%M:%S")
        if ok then return result end
    end
    return tostring(os and os.time and os.time() or "unknown")
end

-- readfile throws if the file doesn't exist so wrap that
local function safeReadFile(path)
    local ok, content = pcall(readfile, path)
    if ok and type(content) == "string" then
        return content, true
    end
    return nil, false
end

-- writes both csv and json logs for one completed run, returns the json export status
function Logger.export(runData)
    Config.log("EXPORT", Logger.EXPORT_ENABLED
        and "File I/O available, log export enabled"
        or "File I/O unavailable, log export disabled",
        Logger.EXPORT_ENABLED and "INFO" or "WARN")

    if not Logger.EXPORT_ENABLED then
        return "skipped"
    end

    local runTimestamp = getTimestamp()
    Config.log("EXPORT", string.format("Starting export pass, timestamp=%s", runTimestamp), "INFO")

    local testResultsForExport = {}
    for _, name in ipairs(runData.resultOrder) do
        local data = runData.results[name]
        table.insert(testResultsForExport, {
            name = name,
            category = data.cat,
            status = data.status,
            error = data.err,
        })
    end

    -- csv
    local csvOk = pcall(function()
        local existingCsv, hasExisting = safeReadFile(Config.CSV_LOG_FILE)
        local csvRows = {}

        if not hasExisting or existingCsv == "" then
            table.insert(csvRows,
                "timestamp,executor,version,test_name,category,status,error,raw_score_pct,weighted_score_pct")
        end

        for _, t in ipairs(testResultsForExport) do
            table.insert(csvRows, table.concat({
                csvEscape(runTimestamp),
                csvEscape(runData.execName),
                csvEscape(runData.execVersion),
                csvEscape(t.name),
                csvEscape(t.category),
                csvEscape(t.status),
                csvEscape(t.error or ""),
                string.format("%.1f", runData.scorePct),
                string.format("%.1f", runData.weightedPct),
            }, ","))
        end

        local csvBlock = table.concat(csvRows, "\n") .. "\n"
        writefile(Config.CSV_LOG_FILE, (hasExisting and existingCsv or "") .. csvBlock)
    end)
    Config.log("EXPORT", csvOk
        and string.format("CSV log written to %s", Config.CSV_LOG_FILE)
        or string.format("CSV log write to %s failed", Config.CSV_LOG_FILE),
        csvOk and "INFO" or "ERROR")

    -- json
    local jsonOk = pcall(function()
        local runEntry = {
            timestamp          = runTimestamp,
            executor            = runData.execName,
            version              = runData.execVersion,
            passed              = runData.passed,
            failed              = runData.failed,
            total                = runData.total,
            raw_score_pct       = tonumber(string.format("%.1f", runData.scorePct)),
            weighted_score_pct  = tonumber(string.format("%.1f", runData.weightedPct)),
            tests                = testResultsForExport,
        }

        local existingJson, hasExisting = safeReadFile(Config.JSON_LOG_FILE)
        local runLog = {}

        if hasExisting and existingJson ~= "" then
            local decoded, decodeErr = JSON.decode(existingJson)
            if decoded ~= nil and JSON.isArray(decoded) then
                runLog = decoded
            else
                -- corrupted, back it up before overwriting
                Config.log("EXPORT", string.format("Existing JSON log unparsable (%s), backing up to %s",
                    tostring(decodeErr), Config.JSON_BACKUP_FILE), "WARN")
                pcall(writefile, Config.JSON_BACKUP_FILE, existingJson)
                runLog = {}
            end
        end

        table.insert(runLog, runEntry)
        writefile(Config.JSON_LOG_FILE, JSON.encode(runLog))
    end)

    local jsonExportStatus = jsonOk and "ok" or "failed"
    Config.log("EXPORT", jsonOk
        and string.format("JSON log written to %s", Config.JSON_LOG_FILE)
        or string.format("JSON log write to %s failed", Config.JSON_LOG_FILE),
        jsonOk and "INFO" or "ERROR")

    return jsonExportStatus
end

return Logger
