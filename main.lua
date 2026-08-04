-- UNC & Executor Compatibility Test
-- Simple diagnostic script to check executor environment support and hooks.

task.wait(0.1) 

local passed = 0 
local failed = 0 
local total = 0 
local results = {} 

local function runTest(testName, category, fn) 
    total = total + 1 
    local success, result = pcall(fn) 
    if success then 
        passed = passed + 1 
        results[testName] = { status = "✅ PASS", cat = category, err = nil } 
    else 
        failed = failed + 1 
        results[testName] = { status = "❌ FAIL", cat = category, err = tostring(result) } 
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

print("\n--------------------------------------------------") 
print("             EXECUTOR DIAGNOSTICS                ") 
print("--------------------------------------------------") 
print(string.format("Executor : %s", execName)) 
print(string.format("Version  : %s", execVersion)) 
print(string.format("Thread ID: %s", type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown")) 
print("--------------------------------------------------\n") 

print("Running tests...\n") 

-- Base UNC functions
local CAT_BASE = "UNC Baseline" 

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
    writefile("unc_diag_test.txt", "test") 
    local content = readfile("unc_diag_test.txt")
    pcall(delfile, "unc_diag_test.txt") -- clean up
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

-- Debug & Closures
local CAT_TECH = "Debug & Reflection" 

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

-- Extra Libraries (Drawing, Crypt, Cache)
local CAT_ADV = "Extra APIs" 

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

-- Behavior & Integrity
local CAT_INT = "Integrity & Sandbox" 

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
    writefile("jail_test.txt", "jailed") 
    assert(readfile("jail_test.txt") == "jailed", "Basic file write failed") 
    
    local escapeAttempt = pcall(function() 
        return writefile("../../../../../escaped_test.txt", "escape") 
    end) 
    
    pcall(delfile, "jail_test.txt") 
    
    assert(escapeAttempt == false, "writefile allowed directory traversal escape ('../../')") 
end) 

-- Print Results
print("\n--------------------------------------------------") 
print("                  DETAILED LOGS                   ") 
print("--------------------------------------------------") 

local categories = { [CAT_BASE] = true, [CAT_TECH] = true, [CAT_ADV] = true, [CAT_INT] = true } 
for catName, _ in pairs(categories) do 
    print(string.format("\n--- [%s] ---", catName)) 
    for name, data in pairs(results) do 
        if data.cat == catName then 
            print(string.format("   %-30s : %s", name, data.status)) 
            if data.err then 
                print("      ↳ " .. data.err) 
            end 
        end 
    end 
end 

print("\n--------------------------------------------------") 
print("                     SUMMARY                      ") 
print("--------------------------------------------------") 
print(string.format("Executor : %s (%s)", execName, execVersion)) 
print(string.format("Passed   : %d", passed)) 
print(string.format("Failed   : %d", failed)) 
print(string.format("Total    : %d", total)) 
print(string.format("Score    : %.1f%%", (passed / total) * 100)) 
print("--------------------------------------------------\n")
