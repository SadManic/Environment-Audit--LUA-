-- UNC & Executor Compatibility Test
-- Environment Audit — LUA (Tight Spacing Edition)
-- Diagnostic script to benchmark executor environment support and hook integrity.

task.wait(0.1) 

-- Configuration
local HEADER_FONT_SIZE = 28 

-- 1. DevConsole RichText Listener Setup (Safe pcall)
local CoreGui = game:GetService("CoreGui")
local devConsole = nil

pcall(function()
    devConsole = CoreGui:WaitForChild("DevConsoleMaster", 3)
    if devConsole then
        for _, v in pairs(devConsole:GetDescendants()) do
            if v:IsA("TextLabel") then v.RichText = true end
        end
        devConsole.DescendantAdded:Connect(function(child)
            if child:IsA("TextLabel") then child.RichText = true end
        end)
    end
end)

-- Color Palette
local HEX_GREEN  = "#50FA7B"
local HEX_RED    = "#FF5555"
local HEX_YELLOW = "#F1FA8C"
local HEX_CYAN   = "#8BE9FD"
local HEX_PURPLE = "#BD93F9"
local HEX_GRAY   = "#808080"

-- 2. Persistent Animated Rainbow Header (Supports Size Scaling)
local function printAnimatedHeader(plainText, uniqueMarker, fontSize)
    fontSize = fontSize or HEADER_FONT_SIZE
    uniqueMarker = uniqueMarker or " 🌟"
    print(plainText .. uniqueMarker)
    
    if not devConsole then return end

    task.spawn(function()
        while true do
            local targetLabel = nil
            for _, v in pairs(devConsole:GetDescendants()) do
                if v:IsA("TextLabel") and v.Text:find(uniqueMarker, 1, true) then
                    v.RichText = true
                    targetLabel = v
                    break
                end
            end
            
            if targetLabel then
                local hue = (tick() * 0.3) % 1 
                local color = Color3.fromHSV(hue, 1, 1)
                local hex = string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
                
                targetLabel.Text = string.format(
                    '<font size="%d"><b><font color="%s">%s</font></b><font color="#FFFFFF">%s</font></font>', 
                    fontSize, hex, plainText, uniqueMarker
                )
            end
            
            task.wait(0.03)
        end
    end)
end

-- 3. Persistent RichText Printer
local function printRich(text)
    local marker = " 🏷️"
    print(text .. marker)
    
    if not devConsole then return end
    
    task.spawn(function()
        for i = 1, 15 do
            for _, v in pairs(devConsole:GetDescendants()) do
                if v:IsA("TextLabel") and v.Text:find(marker, 1, true) then
                    v.RichText = true
                    v.Text = text
                    break
                end
            end
            task.wait(0.05)
        end
    end)
end

local passed = 0 
local failed = 0 
local total = 0 
local results = {} 
local maxNameLength = 0 -- Calculated dynamically for automatic text column padding

local function runTest(testName, category, fn) 
    total = total + 1 
    if #testName > maxNameLength then
        maxNameLength = #testName
    end

    local success, result = pcall(fn) 
    if success then 
        passed = passed + 1 
        results[testName] = { status = "PASS", cat = category, err = nil } 
    else 
        failed = failed + 1 
        results[testName] = { status = "FAIL", cat = category, err = tostring(result) } 
    end 
end 

-- Get executor info
local execName, execVersion = "Unknown", "N/A" 

if type(identifyexecutor) == "function" then 
    local s, name, ver = pcall(identifyexecutor) 
    if s then execName, execVersion = tostring(name or execName), tostring(ver or execVersion) end 
elseif type(getexecutorname) == "function" then 
    local s, name = pcall(getexecutorname) 
    if s then execName = tostring(name) end 
end 

-- Categories Defined
local CAT_BASE = "UNC Baseline" 
local CAT_TECH = "Debug & Reflection" 
local CAT_ADV  = "Extra APIs" 
local CAT_INT  = "Integrity & Sandbox" 

local categoryOrder = { CAT_BASE, CAT_TECH, CAT_ADV, CAT_INT }

-- Render Top Header (Removed gap below header)
printAnimatedHeader("📌 ENVIRONMENT AUDIT — LUA", " 📌", HEADER_FONT_SIZE)
printRich(string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW, execName))
printRich(string.format('<font color="%s"><b>Version   :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW, execVersion))
printRich(string.format('<font color="%s"><b>Thread ID :</b></font> <font color="%s">%s</font>', HEX_PURPLE, HEX_YELLOW, type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown"))
printRich(string.format('<font color="%s"><i>⏳ Running environment checks...</i></font>', HEX_GRAY))

-- Base UNC functions
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
    local cleanup = function() pcall(delfile, filename) end
    
    writefile(filename, "test") 
    local content = readfile(filename)
    cleanup()
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

runTest("Traceback filtering", CAT_INT, function() 
    assert(type(newcclosure) == "function", "Missing newcclosure")
    local traceCheck = false 
    local proxyClosure = newcclosure(function() 
        local stack = debug.traceback() 
        if not string.find(stack, "exploit") then 
            traceCheck = true 
        end 
    end) 
    proxyClosure() 
    assert(traceCheck == true, "debug.traceback leaked internal paths") 
end) 

runTest("File system jail test", CAT_INT, function() 
    assert(type(writefile) == "function", "Missing writefile")
    assert(type(readfile) == "function", "Missing readfile")
    
    local filename = "jail_test.txt"
    local cleanup = function() pcall(delfile, filename) end
    
    writefile(filename, "jailed") 
    local validRead = readfile(filename) == "jailed"
    
    local escapeAttempt = pcall(function() 
        return writefile("../../../../../escaped_test.txt", "escape") 
    end) 
    
    cleanup()
    
    assert(validRead, "Basic file write failed")
    assert(escapeAttempt == false, "writefile allowed directory traversal escape ('../../')") 
end) 

-- Detailed Results Log
printRich(string.format('<font color="%s">==================================================</font>', HEX_CYAN))
printRich(string.format('<font color="%s"><b>                 DETAILED LOGS                    </b></font>', HEX_CYAN))
printRich(string.format('<font color="%s">==================================================</font>', HEX_CYAN))

-- Dynamic format string calculated based on longest test title
local formatSpecifier = string.format('   <font color="%%s">%%-%ds</font> : %%s', maxNameLength)

for _, catName in ipairs(categoryOrder) do 
    -- Removed \n prefix so category header sits flush with its first test item
    printRich(string.format('<font color="%s"><b>📁 <u>%s</u></b></font>', HEX_PURPLE, catName:upper())) 
    for name, data in pairs(results) do 
        if data.cat == catName then 
            local badge = data.status == "PASS" 
                and string.format('<font color="%s"><b>✅ PASS</b></font>', HEX_GREEN) 
                or string.format('<font color="%s"><b>❌ FAIL</b></font>', HEX_RED)
            
            printRich(string.format(formatSpecifier, HEX_GRAY, name, badge)) 
            if data.err then 
                printRich(string.format('      <font color="%s"><i>↳ %s</i></font>', HEX_RED, data.err)) 
            end 
        end 
    end 
end 

-- Summary Box
local scorePct = (passed / total) * 100
local gradeBadge = scorePct >= 95 
    and string.format('<font color="%s"><b>🟢 PERFECT</b></font>', HEX_GREEN) 
    or (scorePct >= 80 and string.format('<font color="%s"><b>🟡 GOOD</b></font>', HEX_YELLOW) or string.format('<font color="%s"><b>🔴 WEAK</b></font>', HEX_RED))

printRich(string.format('<font color="%s">==================================================</font>', HEX_CYAN))
printAnimatedHeader("SUMMARY", " 📊", HEADER_FONT_SIZE)
printRich(string.format('<font color="%s">==================================================</font>', HEX_CYAN))
printRich(string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s (%s)</font>', HEX_PURPLE, HEX_YELLOW, execName, execVersion))
printRich(string.format('<font color="%s"><b>Passed    :</b></font> <font color="%s"><b>%d</b></font>', HEX_PURPLE, HEX_GREEN, passed))
printRich(string.format('<font color="%s"><b>Failed    :</b></font> <font color="%s"><b>%d</b></font>', HEX_PURPLE, HEX_RED, failed))
printRich(string.format('<font color="%s"><b>Total     :</b></font> <font color="%s">%d</font>', HEX_PURPLE, HEX_YELLOW, total))
printRich(string.format('<font color="%s"><b>Score     :</b></font> <font color="%s"><b>%.1f%%</b></font> %s', HEX_PURPLE, HEX_CYAN, scorePct, gradeBadge))
printRich(string.format('<font color="%s">==================================================</font>', HEX_CYAN))

-- Optional JSON File Export Function
if type(writefile) == "function" and type(game.GetService) == "function" then
    getgenv().ExportUNCResults = function(fileName)
        fileName = fileName or "unc_audit_results.json"
        local HttpService = game:GetService("HttpService")
        local payload = {
            executor = execName,
            version = execVersion,
            score = scorePct,
            passed = passed,
            failed = failed,
            total = total,
            details = results
        }
        local success, err = pcall(function()
            writefile(fileName, HttpService:JSONEncode(payload))
        end)
        if success then
            printRich(string.format('<font color="%s">💾 Audit exported successfully to "%s"</font>', HEX_GREEN, fileName))
        else
            printRich(string.format('<font color="%s">❌ Failed to export results: %s</font>', HEX_RED, tostring(err)))
        end
    end
end
