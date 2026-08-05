-- main.lua,
-- Full suite
task.wait(0.1) 

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local devConsole = nil

-- ===== Debug Logger =====
local DEBUG_ENABLED = false -- flip to true to see [UNC-DIAG] trace lines in the output console
local DEBUG_PREFIX = "[UNC-DIAG]"

local function debugLog(stage, msg, level)
    if not DEBUG_ENABLED then return end
    level = level or "INFO"
    local ts = (type(os) == "table" and type(os.date) == "function")
        and (select(2, pcall(os.date, "%H:%M:%S")) or "??:??:??")
        or tostring(os and os.time and os.time() or "??:??:??")
    print(string.format("%s [%s] [%s] %s :: %s", DEBUG_PREFIX, ts, level, stage, msg))
end

debugLog("INIT", "Diagnostic suite starting, waiting for environment to settle", "INFO")

pcall(function()
    devConsole = CoreGui:WaitForChild("DevConsoleMaster", 3)
end)

debugLog("INIT", devConsole and "DevConsoleMaster located, rich-text rendering available" or "DevConsoleMaster not found, falling back to plain print output", devConsole and "INFO" or "WARN")

-- Rainbow text gen, colors shift over time
local function getAnimatedRainbowText(text, timeOffset)
    local result = ""
    local len = #text
    timeOffset = timeOffset or 0
    
    for i = 1, len do
        local char = text:sub(i, i)
        if char == " " then
            result = result .. " "
        else
            local hue = ((i / len) + (timeOffset * 0.4)) % 1
            local color = Color3.fromHSV(hue, 0.85, 1)
            local hexColor = string.format("#%02X%02X%02X", 
                math.floor(color.R * 255), 
                math.floor(color.G * 255), 
                math.floor(color.B * 255)
            )
            result = result .. string.format('<font color="%s">%s</font>', hexColor, char)
        end
    end
    return "<b>" .. result .. "</b>"
end

-- Colors in hex
local HEX_GREEN  = "#50FA7B"
local HEX_RED    = "#FF5555"
local HEX_YELLOW = "#F1FA8C"
local HEX_CYAN   = "#8BE9FD"
local HEX_PURPLE = "#BD93F9"
local HEX_WHITE  = "#FFFFFF"

local passed = 0 
local failed = 0 
local total = 0 
local results = {} 
local resultOrder = {}   -- Preserves insertion order per category for stable output
local maxNameLength = 0

-- Baseline tests count more than the extras
local CATEGORY_WEIGHT = {
    ["UNC Baseline"]        = 3,
    ["Debug & Reflection"]  = 2,
    ["Integrity & Sandbox"] = 2,
    ["Extra APIs"]          = 1,
}

local weightedEarned = 0
local weightedTotal = 0

local function runTest(testName, category, fn) 
    total = total + 1 
    if #testName > maxNameLength then
        maxNameLength = #testName
    end

    local weight = CATEGORY_WEIGHT[category] or 1
    weightedTotal = weightedTotal + weight

    debugLog("TEST", string.format("Running '%s' [%s] (weight=%d)", testName, category, weight), "TRACE")

    local success, result = pcall(fn) 
    if success then 
        passed = passed + 1 
        weightedEarned = weightedEarned + weight
        results[testName] = { status = "PASS", cat = category, err = nil } 
        debugLog("TEST", string.format("'%s' PASSED", testName), "TRACE")
    else 
        failed = failed + 1 
        results[testName] = { status = "FAIL", cat = category, err = tostring(result) } 
        debugLog("TEST", string.format("'%s' FAILED :: %s", testName, tostring(result)), "ERROR")
    end 

    table.insert(resultOrder, testName)
end 

-- Executor info
debugLog("EXEC-ID", "Attempting to identify host executor", "INFO")
local execName, execVersion = "Unknown", "N/A" 

if type(identifyexecutor) == "function" then 
    local s, name, ver = pcall(identifyexecutor) 
    if s then execName, execVersion = tostring(name or execName), tostring(ver or execVersion) end 
elseif type(getexecutorname) == "function" then 
    local s, name = pcall(getexecutorname) 
    if s then execName = tostring(name) end 
end 

debugLog("EXEC-ID", string.format("Resolved executor as '%s' (%s)", execName, execVersion), "INFO")

-- Categories
local CAT_BASE = "UNC Baseline" 
local CAT_TECH = "Debug & Reflection" 
local CAT_ADV  = "Extra APIs" 
local CAT_INT  = "Integrity & Sandbox" 

local categoryOrder = { CAT_BASE, CAT_TECH, CAT_ADV, CAT_INT }

debugLog("SUITE", string.format("Beginning category '%s'", CAT_BASE), "INFO")

-- Baseline tests
runTest("Environment Tables", CAT_BASE, function() 
    assert(type(getgenv) == "function", "Missing getgenv")
    assert(type(getrenv) == "function", "Missing getrenv")
    assert(type(getreg) == "function", "Missing getreg")
end) 

runTest("getrawmetatable", CAT_BASE, function() 
    assert(type(getrawmetatable) == "function", "Missing getrawmetatable")
    local t = setmetatable({}, { __metatable = "Protected" }) 
    local meta = getrawmetatable(t)
    assert(type(meta) == "table", "Failed to get metatable from protected table") 
end) 

runTest("setrawmetatable", CAT_BASE, function() 
    assert(type(setrawmetatable) == "function", "Missing setrawmetatable")
    local t = setmetatable({}, { __metatable = "Protected" }) 
    setrawmetatable(t, { __index = function() return "patched" end }) 
    assert(t.anyKey == "patched", "Failed to modify metatable via setrawmetatable") 
end) 

runTest("setreadonly / isreadonly", CAT_BASE, function() 
    assert(type(setreadonly) == "function", "Missing setreadonly")
    assert(type(isreadonly) == "function", "Missing isreadonly")
    local t = {} 
    setreadonly(t, true) 
    assert(isreadonly(t) == true, "Table read-only state didn't change") 
end) 

runTest("hookfunction", CAT_BASE, function() 
    assert(type(hookfunction) == "function", "Missing hookfunction")
    local function target() return "original" end 
    local original = hookfunction(target, function() return "hooked" end) 
    assert(target() == "hooked", "Hook didn't override target function")
    assert(original() == "original", "Original function copy failed") 
end) 

runTest("hookmetamethod", CAT_BASE, function() 
    assert(type(hookmetamethod) == "function", "Missing hookmetamethod")
    local t = setmetatable({}, { __index = function(self, key) return "original_meta" end }) 
    local original = hookmetamethod(t, "__index", function() return "hooked_meta" end) 
    assert(t.anyKey == "hooked_meta", "__index hook failed")
    assert(original() == "original_meta", "Original metamethod copy failed") 
end) 

runTest("newcclosure / iscclosure", CAT_BASE, function() 
    assert(type(newcclosure) == "function", "Missing newcclosure")
    assert(type(iscclosure) == "function", "Missing iscclosure")
    local f = function() return "test" end 
    local c = newcclosure(f) 
    assert(iscclosure(c) == true, "iscclosure returned false for newcclosure wrapper")
    assert(c() == "test", "Wrapped function returned wrong value") 
end) 

runTest("checkclosure / clonefunction", CAT_BASE, function() 
    assert(type(clonefunction) == "function", "Missing clonefunction")
    local f = function() return "clone_me" end 
    local cloned = clonefunction(f) 
    assert(cloned() == "clone_me", "Cloned function returned wrong value")
    assert(cloned ~= f, "clonefunction returned original reference") 
end) 

runTest("getgc", CAT_BASE, function() 
    assert(type(getgc) == "function", "Missing getgc")
    assert(type(getgc()) == "table", "getgc didn't return a table") 
end) 

runTest("getinstances", CAT_BASE, function() 
    local getinst = getinstances or get_instances 
    local getnil = getnilinstances or get_nil_instances 
    assert(type(getinst) == "function", "Missing getinstances")
    assert(type(getnil) == "function", "Missing getnilinstances")
    assert(type(getinst()) == "table", "getinstances didn't return a table")
    assert(type(getnil()) == "table", "getnilinstances didn't return a table") 
end) 

runTest("Interaction Utilities", CAT_BASE, function() 
    assert(type(fireclickdetector) == "function" or type(firetouchinterest) == "function", "Missing click/touch fire functions") 
end) 

runTest("readfile / writefile", CAT_BASE, function() 
    assert(type(writefile) == "function", "Missing writefile")
    assert(type(readfile) == "function", "Missing readfile")
    local filename = "unc_diag_test.txt"
    writefile(filename, "test") 
    local content = readfile(filename)
    pcall(delfile, filename)
    assert(content == "test", "File content didn't match after write") 
end) 

runTest("http request", CAT_BASE, function() 
    local reqFunc = request or http_request or (http and http.request) 
    assert(type(reqFunc) == "function", "Missing HTTP request function") 
end) 

runTest("getloadedmodules", CAT_BASE, function() 
    local getmodules = getloadedmodules or getmodules 
    assert(type(getmodules) == "function", "Missing getloadedmodules") 
end) 

runTest("checkcaller", CAT_BASE, function() 
    assert(type(checkcaller) == "function", "Missing checkcaller")
    assert(checkcaller() == true, "checkcaller returned false inside script thread") 
end) 

runTest("decompile", CAT_BASE, function() 
    local decomp = decompile or disassemble or getscriptbytecode 
    assert(type(decomp) == "function", "Missing decompiler function") 
end) 

debugLog("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", CAT_BASE, passed, total), "INFO")
debugLog("SUITE", string.format("Beginning category '%s'", CAT_TECH), "INFO")

-- Debug & Reflection
runTest("cloneref", CAT_TECH, function() 
    local cloneRefFunc = cloneref or (oh and oh.cloneref) 
    assert(type(cloneRefFunc) == "function", "Missing cloneref") 
    local testPart = Instance.new("Part") 
    local ref1 = cloneRefFunc(testPart) 
    local ref2 = cloneRefFunc(testPart) 
    assert(ref1 ~= ref2, "cloneref gave duplicate proxies") 
    assert(ref1 == testPart, "Proxy equality check failed") 
end) 

runTest("compareinstances", CAT_TECH, function() 
    local comp = compareinstances or (cloneref and function(a, b) return a == b end) 
    assert(type(comp) == "function", "Missing compareinstances") 
    local p = Instance.new("Part") 
    assert(comp(p, p) == true, "compareinstances returned false for same part") 
end) 

runTest("debug.getinfo", CAT_TECH, function() 
    local getinfo = debug.getinfo or getinfo 
    assert(type(getinfo) == "function", "Missing debug.getinfo") 
    local info = getinfo(1) 
    assert(type(info) == "table" and info.short_src ~= nil, "getinfo returned bad table") 
end) 

runTest("debug.getupvalues / setupvalue", CAT_TECH, function() 
    local getupvals = debug.getupvalues or getupvalues 
    local setupval = debug.setupvalue or setupvalue 
    assert(type(getupvals) == "function", "Missing debug.getupvalues")
    assert(type(setupval) == "function", "Missing debug.setupvalue") 
    local state = "secure" 
    local function testFn() return state end 
    for idx, val in pairs(getupvals(testFn)) do 
        if val == "secure" then 
            setupval(testFn, idx, "breached") 
            break 
        end 
    end 
    assert(testFn() == "breached", "setupvalue failed to change upvalue") 
end) 

runTest("debug.getconstants", CAT_TECH, function() 
    local getconstants = debug.getconstants or getconstants 
    assert(type(getconstants) == "function", "Missing debug.getconstants") 
    local function target() return "const_marker" end 
    local original = hookfunction(target, function() return "hooked" end) 
    local consts = getconstants(original) 
    local found = false 
    for _, v in ipairs(consts) do if v == "const_marker" then found = true break end end 
    assert(found, "Couldn't find constant in hooked function copy") 
end) 

debugLog("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", CAT_TECH, passed, total), "INFO")
debugLog("SUITE", string.format("Beginning category '%s'", CAT_ADV), "INFO")

-- Extra APIs
runTest("__namecall", CAT_ADV, function() 
    assert(type(getnamecallmethod) == "function", "Missing getnamecallmethod") 
    assert(type(hookmetamethod) == "function", "Missing hookmetamethod") 
    local interceptedMethod = nil 
    local original 
    original = hookmetamethod(game, "__namecall", newcclosure(function(self, ...) 
        interceptedMethod = getnamecallmethod() 
        return original(self, ...) 
    end)) 
    game:GetService("Workspace") 
    assert(interceptedMethod == "GetService", "Failed to catch GetService via __namecall") 
end) 

runTest("crypt library", CAT_ADV, function() 
    local lib = crypt or Base64 or base64 
    assert(type(lib) == "table" or type(crypt) == "table", "Missing crypt library") 
    local enc = (crypt and crypt.base64encode) or (lib and lib.encode) or base64_encode 
    local dec = (crypt and crypt.base64decode) or (lib and lib.decode) or base64_decode 
    assert(type(enc) == "function" and type(dec) == "function", "Missing base64 encode/decode") 
    local testData = "UNC_TEST" 
    assert(dec(enc(testData)) == testData, "Base64 encode/decode check failed") 
end) 

runTest("Drawing library", CAT_ADV, function() 
    assert(type(Drawing) == "table" and type(Drawing.new) == "function", "Missing Drawing library") 
    local line = Drawing.new("Line") 
    assert(type(line) == "table" or type(line) == "userdata", "Drawing.new didn't create object") 
    assert(line.Visible ~= nil, "Drawing object missing properties") 
    line:Remove() 
end) 

runTest("gethui / protectgui", CAT_ADV, function() 
    local gethuiFunc = gethui or get_hidden_gui or protectgui 
    assert(type(gethuiFunc) == "function", "Missing gethui or protectgui") 
end) 

runTest("getsenv / getscriptclosure", CAT_ADV, function() 
    local getsenvFunc = getsenv or getscriptenvs 
    assert(type(getsenvFunc) == "function" or type(getscriptclosure) == "function", "Missing env/closure functions") 
end) 

runTest("cache.invalidate", CAT_ADV, function() 
    assert(type(cache) == "table" and type(cache.invalidate) == "function", "Missing cache library") 
    local p = Instance.new("Part") 
    cache.invalidate(p) 
end) 

debugLog("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", CAT_ADV, passed, total), "INFO")
debugLog("SUITE", string.format("Beginning category '%s'", CAT_INT), "INFO")

-- Integrity & Sandbox
runTest("Hook argument passing", CAT_INT, function() 
    assert(type(hookfunction) == "function", "Missing hookfunction")
    local mathBlock = function(a, b) return a + b end 
    local backup = hookfunction(mathBlock, function(a, b) return a * b end) 
    assert(mathBlock(5, 5) == 25, "Hooked function failed argument test") 
    assert(backup(5, 5) == 10, "Original backup returned wrong result") 
end) 

runTest("game metatable modifications", CAT_INT, function() 
    assert(type(getrawmetatable) == "function", "Missing getrawmetatable")
    assert(type(setreadonly) == "function", "Missing setreadonly")
    assert(type(isreadonly) == "function", "Missing isreadonly")
    
    local protectedMeta = getrawmetatable(game) 
    local originalReadOnlyState = isreadonly(protectedMeta) 
    setreadonly(protectedMeta, false) 
    assert(isreadonly(protectedMeta) == false, "Failed to unlock game metatable") 
    
    local testKey = "__diag_key" 
    protectedMeta[testKey] = "write_ok" 
    assert(protectedMeta[testKey] == "write_ok", "Couldn't write to game metatable") 
    
    protectedMeta[testKey] = nil 
    setreadonly(protectedMeta, originalReadOnlyState) 
end) 

-- Check for leaks besides just the word "exploit"
runTest("Traceback filtering", CAT_INT, function() 
    assert(type(newcclosure) == "function", "Missing newcclosure")

    local leakPatterns = {
        "exploit",
        "%.dll",                 -- Injected module names
        "%.so",                  -- Linux-side loaded libs
        "[Cc]:[\\/]",             -- Absolute windows paths
        "/home/",                -- Absolute unix paths
        "%[C%]",                 -- Raw C-stack frame marker some VMs leak
        "internal/",             -- Common internal source dir naming
        "bytecode",              -- Decompiler/bytecode leakage
    }

    local leaked = nil
    local proxyClosure = newcclosure(function() 
        local stack = debug.traceback() 
        for _, pattern in ipairs(leakPatterns) do
            if string.find(stack:lower(), pattern:lower()) then
                leaked = pattern
                break
            end
        end
    end) 
    proxyClosure() 
    assert(leaked == nil, "debug.traceback leaked internal detail matching pattern: " .. tostring(leaked)) 
end) 

-- Try a few traversal tricks, not just ".."
runTest("File system jail test", CAT_INT, function() 
    assert(type(writefile) == "function", "Missing writefile")
    assert(type(readfile) == "function", "Missing readfile")

    local filename = "jail_test.txt"
    writefile(filename, "jailed") 
    local validRead = readfile(filename) == "jailed"
    pcall(delfile, filename)
    assert(validRead, "Basic file write failed")

    local escapeAttempts = {
        "../../../../../escaped_test_1.txt",       -- Classic relative traversal
        "..\\..\\..\\..\\escaped_test_2.txt",       -- Backslash traversal (windows-style)
        "/etc/escaped_test_3.txt",                  -- Absolute unix path
        "C:/Windows/escaped_test_4.txt",            -- Absolute windows path
        "....//....//escaped_test_5.txt",           -- Doubled-dot slash trick
        "%2e%2e/%2e%2e/escaped_test_6.txt",         -- URL-encoded traversal
    }

    local escapedPaths = {}
    for _, path in ipairs(escapeAttempts) do
        local ok = pcall(function()
            writefile(path, "escape")
        end)
        if ok then
            table.insert(escapedPaths, path)
            pcall(delfile, path)
        end
    end

    assert(#escapedPaths == 0,
        string.format("writefile allowed %d directory traversal escape(s): %s",
            #escapedPaths, table.concat(escapedPaths, ", ")))
end) 

debugLog("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", CAT_INT, passed, total), "INFO")
debugLog("SUITE", string.format("All categories complete: %d passed, %d failed, %d total", passed, failed, total), "INFO")

-- Build the output lines
debugLog("RENDER", "Assembling output lines and computing scores", "INFO")
local outputLines = {}
local animatedLineIndices = {}

-- Header (animated)
table.insert(outputLines, "HEADER_ANIMATED_PLACEHOLDER")
animatedLineIndices[1] = "ENVIRONMENT AUDIT — LUA"

table.insert(outputLines, string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW, execName))
table.insert(outputLines, string.format('<font color="%s"><b>Version   :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW, execVersion))
table.insert(outputLines, string.format('<font color="%s"><b>Thread ID :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW, type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown"))
table.insert(outputLines, string.format('<font color="%s"><i>⏳ Checks complete!</i></font>', HEX_CYAN))
table.insert(outputLines, string.format('<font color="%s">==================================================</font>', HEX_CYAN))
table.insert(outputLines, string.format('<font color="%s"><b>                  DETAILED LOGS                  </b></font>', HEX_CYAN))
table.insert(outputLines, string.format('<font color="%s">==================================================</font>', HEX_CYAN))

local formatSpecifier = string.format('   <font color="%%s">%%-%ds</font> : %%s', maxNameLength)

-- Use resultOrder so this prints in the same order every run
for _, catName in ipairs(categoryOrder) do 
    table.insert(outputLines, string.format('<font color="%s"><b>📁 <u>%s</u></b></font>', HEX_PURPLE, catName:upper())) 
    for _, name in ipairs(resultOrder) do 
        local data = results[name]
        if data.cat == catName then 
            local badge = data.status == "PASS" 
                and string.format('<font color="%s"><b>✅ PASS</b></font>', HEX_GREEN) 
                or string.format('<font color="%s"><b>❌ FAIL</b></font>', HEX_RED)
            
            table.insert(outputLines, string.format(formatSpecifier, HEX_WHITE, name, badge)) 
            if data.err then 
                table.insert(outputLines, string.format('      <font color="%s"><i>↳ %s</i></font>', HEX_RED, data.err)) 
            end 
        end 
    end 
end 

local scorePct = (passed / total) * 100
local weightedPct = (weightedTotal > 0) and (weightedEarned / weightedTotal) * 100 or 0

debugLog("RENDER", string.format("Raw score %.1f%%, weighted score %.1f%%", scorePct, weightedPct), "INFO")

-- No json lib on these executors so rolling my own
local JSON = {}

-- encode
local JSON_ESCAPES = {
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
}

local function jsonEncodeString(str)
    str = tostring(str):gsub('[%c"\\]', function(c)
        return JSON_ESCAPES[c] or string.format('\\u%04x', string.byte(c))
    end)
    return '"' .. str .. '"'
end

-- Array = keys 1..N with no gaps, else it's an object
local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    if n == 0 then return true end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true
end

function JSON.encode(value)
    local vType = type(value)

    if value == nil then
        return "null"
    elseif vType == "boolean" then
        return tostring(value)
    elseif vType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return "null" -- Not valid JSON
        end
        return tostring(value)
    elseif vType == "string" then
        return jsonEncodeString(value)
    elseif vType == "table" then
        if isArray(value) then
            local parts = {}
            for i = 1, #value do
                parts[i] = JSON.encode(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(value) do
                table.insert(parts, jsonEncodeString(tostring(k)) .. ":" .. JSON.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "null" -- Functions, userdata, etc
    end
end

-- Decode

local function jsonSkipWhitespace(str, pos)
    local _, stop = str:find("^[ \t\r\n]*", pos)
    return stop + 1
end

local jsonDecodeValue -- Forward decl

local function jsonDecodeError(msg, str, pos)
    error(string.format("JSON decode error at position %d: %s (near '%s')",
        pos, msg, str:sub(pos, pos + 15)))
end

local function jsonDecodeString(str, pos)
    if str:sub(pos, pos) ~= '"' then jsonDecodeError("expected '\"'", str, pos) end
    pos = pos + 1
    local out = {}
    while true do
        local c = str:sub(pos, pos)
        if c == "" then
            jsonDecodeError("unterminated string", str, pos)
        elseif c == '"' then
            pos = pos + 1
            break
        elseif c == "\\" then
            local esc = str:sub(pos + 1, pos + 1)
            local simple = { n = "\n", t = "\t", r = "\r", b = "\b", f = "\f", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
            if simple[esc] then
                table.insert(out, simple[esc])
                pos = pos + 2
            elseif esc == "u" then
                local hex = str:sub(pos + 2, pos + 5)
                local codepoint = tonumber(hex, 16)
                if not codepoint then jsonDecodeError("bad \\u escape", str, pos) end
                -- utf8 encode
                if codepoint < 0x80 then
                    table.insert(out, string.char(codepoint))
                elseif codepoint < 0x800 then
                    table.insert(out, string.char(
                        0xC0 + math.floor(codepoint / 0x40),
                        0x80 + (codepoint % 0x40)))
                else
                    table.insert(out, string.char(
                        0xE0 + math.floor(codepoint / 0x1000),
                        0x80 + (math.floor(codepoint / 0x40) % 0x40),
                        0x80 + (codepoint % 0x40)))
                end
                pos = pos + 6
            else
                jsonDecodeError("unknown escape \\" .. esc, str, pos)
            end
        else
            table.insert(out, c)
            pos = pos + 1
        end
    end
    return table.concat(out), pos
end

local function jsonDecodeNumber(str, pos)
    local numStr = str:match("^-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
    if not numStr or numStr == "" then jsonDecodeError("invalid number", str, pos) end
    local num = tonumber(numStr)
    if not num then jsonDecodeError("invalid number literal: " .. numStr, str, pos) end
    return num, pos + #numStr
end

local function jsonDecodeArray(str, pos)
    pos = pos + 1 -- skip '['
    local arr = {}
    pos = jsonSkipWhitespace(str, pos)
    if str:sub(pos, pos) == "]" then return arr, pos + 1 end

    while true do
        local value
        value, pos = jsonDecodeValue(str, pos)
        table.insert(arr, value)
        pos = jsonSkipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == "," then
            pos = jsonSkipWhitespace(str, pos + 1)
        elseif c == "]" then
            return arr, pos + 1
        else
            jsonDecodeError("expected ',' or ']'", str, pos)
        end
    end
end

local function jsonDecodeObject(str, pos)
    pos = pos + 1 -- skip '{'
    local obj = {}
    pos = jsonSkipWhitespace(str, pos)
    if str:sub(pos, pos) == "}" then return obj, pos + 1 end

    while true do
        pos = jsonSkipWhitespace(str, pos)
        local key
        key, pos = jsonDecodeString(str, pos)
        pos = jsonSkipWhitespace(str, pos)
        if str:sub(pos, pos) ~= ":" then jsonDecodeError("expected ':'", str, pos) end
        pos = jsonSkipWhitespace(str, pos + 1)
        local value
        value, pos = jsonDecodeValue(str, pos)
        obj[key] = value
        pos = jsonSkipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == "," then
            pos = jsonSkipWhitespace(str, pos + 1)
        elseif c == "}" then
            return obj, pos + 1
        else
            jsonDecodeError("expected ',' or '}'", str, pos)
        end
    end
end

jsonDecodeValue = function(str, pos)
    pos = jsonSkipWhitespace(str, pos)
    local c = str:sub(pos, pos)
    if c == '"' then
        return jsonDecodeString(str, pos)
    elseif c == "{" then
        return jsonDecodeObject(str, pos)
    elseif c == "[" then
        return jsonDecodeArray(str, pos)
    elseif c == "-" or c:match("%d") then
        return jsonDecodeNumber(str, pos)
    elseif str:sub(pos, pos + 3) == "true" then
        return true, pos + 4
    elseif str:sub(pos, pos + 4) == "false" then
        return false, pos + 5
    elseif str:sub(pos, pos + 3) == "null" then
        return nil, pos + 4
    else
        jsonDecodeError("unexpected token", str, pos)
    end
end

-- Returns nil + err instead of throwing on bad input
function JSON.decode(str)
    if type(str) ~= "string" or str:match("^%s*$") then
        return nil, "empty input"
    end
    local ok, value, pos = pcall(function()
        local v, p = jsonDecodeValue(str, 1)
        return v, p
    end)
    if not ok then
        return nil, tostring(value)
    end
    return value
end

-- csv/json logging, appends every run
local EXPORT_ENABLED = (type(writefile) == "function" and type(readfile) == "function")
local CSV_LOG_FILE     = "unc_results_log.csv"
local JSON_LOG_FILE    = "unc_results_log.json"
local JSON_BACKUP_FILE = "unc_results_log.json.bak"

debugLog("EXPORT", EXPORT_ENABLED and "File I/O available, log export enabled" or "File I/O unavailable, log export disabled", EXPORT_ENABLED and "INFO" or "WARN")

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

local jsonExportStatus = "skipped"

if EXPORT_ENABLED then
    local runTimestamp = getTimestamp()
    debugLog("EXPORT", string.format("Starting export pass, timestamp=%s", runTimestamp), "INFO")

    local testResultsForExport = {}
    for _, name in ipairs(resultOrder) do
        local data = results[name]
        table.insert(testResultsForExport, {
            name = name,
            category = data.cat,
            status = data.status,
            error = data.err,
        })
    end

    -- csv
    local csvOk = pcall(function()
        local existingCsv, hasExisting = safeReadFile(CSV_LOG_FILE)
        local csvRows = {}

        if not hasExisting or existingCsv == "" then
            table.insert(csvRows,
                "timestamp,executor,version,test_name,category,status,error,raw_score_pct,weighted_score_pct")
        end

        for _, t in ipairs(testResultsForExport) do
            table.insert(csvRows, table.concat({
                csvEscape(runTimestamp),
                csvEscape(execName),
                csvEscape(execVersion),
                csvEscape(t.name),
                csvEscape(t.category),
                csvEscape(t.status),
                csvEscape(t.error or ""),
                string.format("%.1f", scorePct),
                string.format("%.1f", weightedPct),
            }, ","))
        end

        local csvBlock = table.concat(csvRows, "\n") .. "\n"
        writefile(CSV_LOG_FILE, (hasExisting and existingCsv or "") .. csvBlock)
    end)
    debugLog("EXPORT", csvOk and string.format("CSV log written to %s", CSV_LOG_FILE) or string.format("CSV log write to %s failed", CSV_LOG_FILE), csvOk and "INFO" or "ERROR")

    -- json
    local jsonOk = pcall(function()
        local runEntry = {
            timestamp          = runTimestamp,
            executor            = execName,
            version              = execVersion,
            passed              = passed,
            failed              = failed,
            total                = total,
            raw_score_pct       = tonumber(string.format("%.1f", scorePct)),
            weighted_score_pct  = tonumber(string.format("%.1f", weightedPct)),
            tests                = testResultsForExport,
        }

        local existingJson, hasExisting = safeReadFile(JSON_LOG_FILE)
        local runLog = {}

        if hasExisting and existingJson ~= "" then
            local decoded, decodeErr = JSON.decode(existingJson)
            if decoded ~= nil and isArray(decoded) then
                runLog = decoded
            else
                -- Corrupted, back it up before overwriting
                debugLog("EXPORT", string.format("Existing JSON log unparsable (%s), backing up to %s", tostring(decodeErr), JSON_BACKUP_FILE), "WARN")
                pcall(writefile, JSON_BACKUP_FILE, existingJson)
                runLog = {}
            end
        end

        table.insert(runLog, runEntry)
        writefile(JSON_LOG_FILE, JSON.encode(runLog))
    end)
    jsonExportStatus = jsonOk and "ok" or "failed"
    debugLog("EXPORT", jsonOk and string.format("JSON log written to %s", JSON_LOG_FILE) or string.format("JSON log write to %s failed", JSON_LOG_FILE), jsonOk and "INFO" or "ERROR")
end

local gradeBadge = weightedPct >= 95 
    and string.format('<font color="%s"><b>🟢 PERFECT</b></font>', HEX_GREEN) 
    or (weightedPct >= 80 and string.format('<font color="%s"><b>🟡 GOOD</b></font>', HEX_YELLOW) or string.format('<font color="%s"><b>🔴 WEAK</b></font>', HEX_RED))

table.insert(outputLines, string.format('<font color="%s">==================================================</font>', HEX_CYAN))

-- Summary line (animated)
local summaryIdx = #outputLines + 1
table.insert(outputLines, "SUMMARY_ANIMATED_PLACEHOLDER")
animatedLineIndices[summaryIdx] = "SUMMARY 📊"

table.insert(outputLines, string.format('<font color="%s">==================================================</font>', HEX_CYAN))
table.insert(outputLines, string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s (%s)</font>', HEX_PURPLE, HEX_YELLOW, execName, execVersion))
table.insert(outputLines, string.format('<font color="%s"><b>Passed    :</b></font> <font color="%s"><b>%d</b></font>', HEX_PURPLE, HEX_GREEN, passed))
table.insert(outputLines, string.format('<font color="%s"><b>Failed    :</b></font> <font color="%s"><b>%d</b></font>', HEX_PURPLE, HEX_RED, failed))
table.insert(outputLines, string.format('<font color="%s"><b>Total     :</b></font> <font color="%s">%d</font>', HEX_PURPLE, HEX_YELLOW, total))
table.insert(outputLines, string.format('<font color="%s"><b>Raw Score :</b></font> <font color="%s"><b>%.1f%%</b></font>', HEX_PURPLE, HEX_CYAN, scorePct))
table.insert(outputLines, string.format('<font color="%s"><b>Weighted  :</b></font> <font color="%s"><b>%.1f%%</b></font> %s', HEX_PURPLE, HEX_CYAN, weightedPct, gradeBadge))
table.insert(outputLines, string.format('<font color="%s"><b>Export    :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW,
    EXPORT_ENABLED
        and string.format("%s / %s (json: %s)", CSV_LOG_FILE, JSON_LOG_FILE, jsonExportStatus)
        or "disabled (no writefile/readfile)"))
table.insert(outputLines, string.format('<font color="%s">==================================================</font>', HEX_CYAN))

debugLog("RENDER", string.format("Built %d output lines, printing to console", #outputLines), "INFO")

-- Print it all
local plainBuffer = {}
for idx, line in ipairs(outputLines) do
    local plainText = line
    if animatedLineIndices[idx] then
        plainText = animatedLineIndices[idx]
    else
        plainText = line:gsub("<[^>]+>", "")
    end
    local marker = string.format(" [%02d]", idx)
    print(plainText .. marker)
    plainBuffer[idx] = marker
end

-- Rainbow text in dev console if its open
if devConsole then
    debugLog("RENDER", "Attaching rich-text formatter to DevConsole labels", "INFO")
    task.spawn(function()
        local activeLabels = {}

        local function checkAndFormatLabel(obj)
            if obj:IsA("TextLabel") then
                for idx, marker in ipairs(plainBuffer) do
                    if obj.Text:find(marker, 1, true) then
                        obj.RichText = true
                        activeLabels[idx] = obj
                        
                        -- Lock text so it doesn't get overwritten
                        if not animatedLineIndices[idx] then
                            local targetRichText = outputLines[idx]
                            obj.Text = targetRichText

                            local isUpdating = false
                            obj:GetPropertyChangedSignal("Text"):Connect(function()
                                if not isUpdating and obj.Text ~= targetRichText then
                                    isUpdating = true
                                    obj.RichText = true
                                    obj.Text = targetRichText
                                    isUpdating = false
                                end
                            end)
                        end
                        break
                    end
                end
            end
        end

        for _, v in pairs(devConsole:GetDescendants()) do
            checkAndFormatLabel(v)
        end

        devConsole.DescendantAdded:Connect(function(desc)
            task.wait()
            checkAndFormatLabel(desc)
        end)

        -- ~30fps, no need to go faster
        local lastUpdate = 0
        RunService.RenderStepped:Connect(function()
            local now = tick()
            if now - lastUpdate < 0.03 then return end
            lastUpdate = now

            for idx, rawText in pairs(animatedLineIndices) do
                local label = activeLabels[idx]
                if label and label.Parent then
                    if idx == 1 then
                        label.Text = "📌 " .. getAnimatedRainbowText(rawText, now) .. " 📌"
                    else
                        label.Text = getAnimatedRainbowText(rawText, now)
                    end
                end
            end
        end)
    end)
else
    debugLog("RENDER", "Skipping rich-text formatter, no DevConsole available", "INFO")
end

debugLog("DONE", "Diagnostic suite finished", "INFO")
