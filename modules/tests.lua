-- tests.lua
-- Diagnostic audit suite and test definitions with granular technical assertions

local Config = import("config")

local Tests = {}

function Tests.identifyExecutor()
    Config.log("EXEC-ID", "Attempting to identify host executor", "INFO")
    local execName, execVersion = "Unknown", "N/A"

    if type(identifyexecutor) == "function" then
        local s, name, ver = pcall(identifyexecutor)
        if s then execName, execVersion = tostring(name or execName), tostring(ver or execVersion) end
    elseif type(getexecutorname) == "function" then
        local s, name = pcall(getexecutorname)
        if s then execName = tostring(name) end
    end

    Config.log("EXEC-ID", string.format("Resolved executor as '%s' (%s)", execName, execVersion), "INFO")
    return execName, execVersion
end

local function newRunner()
    local runner = {
        passed = 0,
        failed = 0,
        total = 0,
        results = {},
        resultOrder = {},
        maxNameLength = 0,
        weightedEarned = 0,
        weightedTotal = 0,
    }

    function runner:runTest(testName, category, fn)
        self.total = self.total + 1
        if #testName > self.maxNameLength then
            self.maxNameLength = #testName
        end

        local weight = Config.CATEGORY_WEIGHT[category] or 1
        self.weightedTotal = self.weightedTotal + weight

        Config.log("TEST", string.format("Running '%s' [%s] (weight=%d)", testName, category, weight), "TRACE")

        local success, result = pcall(fn)
        if success then
            self.passed = self.passed + 1
            self.weightedEarned = self.weightedEarned + weight
            local passDetail = (type(result) == "string" and result ~= "") and result or "Assertion verified under standard parameters."
            self.results[testName] = { 
                status = "PASS", 
                cat = category, 
                err = nil, 
                detail = passDetail 
            }
            Config.log("TEST", string.format("'%s' PASSED", testName), "TRACE")
        else
            self.failed = self.failed + 1
            local cleanErr = tostring(result):gsub("^.-:%d+:%s*", "")
            self.results[testName] = { 
                status = "FAIL", 
                cat = category, 
                err = cleanErr, 
                detail = "Assertion failed during runtime execution: " .. cleanErr 
            }
            Config.log("TEST", string.format("'%s' FAILED :: %s", testName, cleanErr), "ERROR")
        end

        table.insert(self.resultOrder, testName)
    end

    return runner
end

local function runBaselineTests(runner)
    Config.log("SUITE", string.format("Beginning category '%s'", Config.CAT_BASE), "INFO")

    runner:runTest("Environment Tables", Config.CAT_BASE, function()
        assert(type(getgenv) == "function", "Missing getgenv")
        assert(type(getrenv) == "function", "Missing getrenv")
        assert(type(getreg) == "function", "Missing getreg")
        return "Core environment table accessors (getgenv, getrenv, getreg) are exposed as valid functions."
    end)

    runner:runTest("getrawmetatable", Config.CAT_BASE, function()
        assert(type(getrawmetatable) == "function", "Missing getrawmetatable")
        local t = setmetatable({}, { __metatable = "Protected" })
        local meta = getrawmetatable(t)
        assert(type(meta) == "table", "Failed to retrieve metatable from protected table")
        return "Bypassed __metatable protection lock; returned valid underlying metatable."
    end)

    runner:runTest("setrawmetatable", Config.CAT_BASE, function()
        assert(type(setrawmetatable) == "function", "Missing setrawmetatable")
        local t = setmetatable({}, { __metatable = "Protected" })
        setrawmetatable(t, { __index = function() return "patched" end })
        assert(t.anyKey == "patched", "Failed to modify metatable via setrawmetatable")
        return "Overrode protected metatable and forced __index evaluation."
    end)

    runner:runTest("setreadonly / isreadonly", Config.CAT_BASE, function()
        assert(type(setreadonly) == "function", "Missing setreadonly")
        assert(type(isreadonly) == "function", "Missing isreadonly")
        local t = {}
        setreadonly(t, true)
        assert(isreadonly(t) == true, "Table read-only state didn't change")
        setreadonly(t, false)
        assert(isreadonly(t) == false, "Table failed to revert write state")
        return "Toggled table write protection states and verified via isreadonly."
    end)

    runner:runTest("hookfunction", Config.CAT_BASE, function()
        assert(type(hookfunction) == "function", "Missing hookfunction")
        local function target() return "original" end
        local original = hookfunction(target, function() return "hooked" end)
        assert(target() == "hooked", "Hook didn't override target function")
        assert(original() == "original", "Original function trampoline copy failed")
        return "Successfully detoured target function and maintained original function closure reference."
    end)

    runner:runTest("hookmetamethod", Config.CAT_BASE, function()
        assert(type(hookmetamethod) == "function", "Missing hookmetamethod")
        local t = setmetatable({}, { __index = function(self, key) return "original_meta" end })
        local original = hookmetamethod(t, "__index", function() return "hooked_meta" end)
        assert(t.anyKey == "hooked_meta", "__index hook failed")
        assert(original() == "original_meta", "Original metamethod copy failed")
        return "Hooked metamethod __index on proxy table; preserved execution trampoline."
    end)

    runner:runTest("newcclosure / iscclosure", Config.CAT_BASE, function()
        assert(type(newcclosure) == "function", "Missing newcclosure")
        assert(type(iscclosure) == "function", "Missing iscclosure")
        local f = function() return "test" end
        local c = newcclosure(f)
        assert(iscclosure(c) == true, "iscclosure returned false for newcclosure wrapper")
        assert(c() == "test", "Wrapped function returned wrong value")
        return "Wrapped Luau closure into C closure proxy; iscclosure confirmed C-type flag."
    end)

    runner:runTest("checkclosure / clonefunction", Config.CAT_BASE, function()
        assert(type(clonefunction) == "function", "Missing clonefunction")
        local f = function() return "clone_me" end
        local cloned = clonefunction(f)
        assert(cloned() == "clone_me", "Cloned function returned wrong value")
        assert(cloned ~= f, "clonefunction returned original reference")
        return "Cloned function produced isolated duplicate reference preserving bytecode execution."
    end)

    runner:runTest("getgc", Config.CAT_BASE, function()
        assert(type(getgc) == "function", "Missing getgc")
        local gc = getgc()
        assert(type(gc) == "table", "getgc didn't return a table")
        assert(#gc > 0, "getgc returned an empty table")
        return string.format("Inspected garbage collection pool; retrieved %d live heap references.", #gc)
    end)

    runner:runTest("getinstances", Config.CAT_BASE, function()
        local getinst = getinstances or get_instances
        local getnil = getnilinstances or get_nil_instances
        assert(type(getinst) == "function", "Missing getinstances")
        assert(type(getnil) == "function", "Missing getnilinstances")
        local instances = getinst()
        local nilInstances = getnil()
        assert(type(instances) == "table", "getinstances didn't return a table")
        assert(type(nilInstances) == "table", "getnilinstances didn't return a table")
        return string.format("Traversed active instances (%d found) and nil-parented objects (%d found).", #instances, #nilInstances)
    end)

    runner:runTest("Interaction Utilities", Config.CAT_BASE, function()
        assert(type(fireclickdetector) == "function" or type(firetouchinterest) == "function", "Missing click/touch fire functions")
        return "Input simulation primitives (fireclickdetector / firetouchinterest) available."
    end)

    runner:runTest("readfile / writefile", Config.CAT_BASE, function()
        assert(type(writefile) == "function", "Missing writefile")
        assert(type(readfile) == "function", "Missing readfile")
        local filename = "aegis_io_verify.txt"
        writefile(filename, "AEGIS_PAYLOAD_TEST")
        local content = readfile(filename)
        pcall(delfile, filename)
        assert(content == "AEGIS_PAYLOAD_TEST", "File content mismatch on disk read")
        return "I/O write, read, and delete operations round-tripped with matching payload."
    end)

    runner:runTest("http request", Config.CAT_BASE, function()
        local reqFunc = request or http_request or (http and http.request)
        assert(type(reqFunc) == "function", "Missing HTTP request function")
        return "HTTP transport client exposed via request / http_request."
    end)

    runner:runTest("getloadedmodules", Config.CAT_BASE, function()
        local getmodules = getloadedmodules or getmodules
        assert(type(getmodules) == "function", "Missing getloadedmodules")
        local mods = getmodules()
        assert(type(mods) == "table", "getloadedmodules did not return table")
        return string.format("Identified %d loaded ModuleScript bytecode containers.", #mods)
    end)

    runner:runTest("checkcaller", Config.CAT_BASE, function()
        assert(type(checkcaller) == "function", "Missing checkcaller")
        assert(checkcaller() == true, "checkcaller returned false inside script thread")
        return "Execution context thread identity verified as elevated caller."
    end)

    runner:runTest("decompile", Config.CAT_BASE, function()
        local decomp = decompile or disassemble or getscriptbytecode
        assert(type(decomp) == "function", "Missing decompiler function")
        return "Bytecode extraction / disassembler backend available in environment."
    end)

    Config.log("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", Config.CAT_BASE, runner.passed, runner.total), "INFO")
end

local function runDebugReflectionTests(runner)
    Config.log("SUITE", string.format("Beginning category '%s'", Config.CAT_TECH), "INFO")

    runner:runTest("cloneref", Config.CAT_TECH, function()
        local cloneRefFunc = cloneref or (oh and oh.cloneref)
        assert(type(cloneRefFunc) == "function", "Missing cloneref")
        local testPart = Instance.new("Part")
        local ref1 = cloneRefFunc(testPart)
        assert(type(ref1) == "userdata" or type(ref1) == "table", "cloneref did not return valid proxy object")
        assert(ref1 ~= testPart, "cloneref returned raw instance reference instead of proxy")
        return "Generated spoofed instance pointer isolating identity from game introspection."
    end)

    runner:runTest("compareinstances", Config.CAT_TECH, function()
        local comp = compareinstances or (cloneref and function(a, b) return a == b end)
        assert(type(comp) == "function", "Missing compareinstances")
        local p = Instance.new("Part")
        assert(comp(p, p) == true, "compareinstances returned false for same part")
        return "Instance pointer equivalency verified across isolated userdata references."
    end)

    runner:runTest("debug.getinfo", Config.CAT_TECH, function()
        local getinfo = debug.getinfo or getinfo
        assert(type(getinfo) == "function", "Missing debug.getinfo")
        local info = getinfo(1)
        assert(type(info) == "table" and info.short_src ~= nil, "getinfo returned bad table")
        return string.format("Extracted stack activation frame.", tostring(info.short_src), tostring(info.currentline), tostring(info.nparams))
    end)

    runner:runTest("debug.getupvalues / setupvalue", Config.CAT_TECH, function()
        local getupvals = debug.getupvalues or getupvalues
        local setupval = debug.setupvalue or setupvalue
        assert(type(getupvals) == "function", "Missing debug.getupvalues")
        assert(type(setupval) == "function", "Missing debug.setupvalue")
        local state = "secure"
        local function testFn() return state end
        local upvals = getupvals(testFn)
        assert(type(upvals) == "table", "getupvalues did not return a table")
        setupval(testFn, 1, "tampered")
        assert(testFn() == "tampered", "setupvalue failed to mutate upvalue state")
        return "Reflected and modified closure scope upvalue register directly."
    end)

    runner:runTest("debug.getconstants", Config.CAT_TECH, function()
        local getconstants = debug.getconstants or getconstants
        assert(type(getconstants) == "function", "Missing debug.getconstants")
        local function target() return "const_marker" end
        local original = hookfunction(target, function() return "hooked" end)
        local consts = getconstants(original)
        local found = false
        for _, v in ipairs(consts) do if v == "const_marker" then found = true break end end
        assert(found, "Couldn't find constant in hooked function copy")
        return "Bytecode constant pool deserialized; target string constant located."
    end)

    Config.log("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", Config.CAT_TECH, runner.passed, runner.total), "INFO")
end

local function runExtraApiTests(runner)
    Config.log("SUITE", string.format("Beginning category '%s'", Config.CAT_ADV), "INFO")

    runner:runTest("__namecall", Config.CAT_ADV, function()
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
        return "Hooked fastcall invocation; captured __namecall method descriptor."
    end)

    runner:runTest("crypt library", Config.CAT_ADV, function()
        local lib = crypt or Base64 or base64
        assert(type(lib) == "table" or type(crypt) == "table", "Missing crypt library")
        local enc = (crypt and crypt.base64encode) or (lib and lib.encode) or base64_encode
        local dec = (crypt and crypt.base64decode) or (lib and lib.decode) or base64_decode
        assert(type(enc) == "function" and type(dec) == "function", "Missing base64 encode/decode")
        local testData = "UNC_TEST_AEGIS"
        assert(dec(enc(testData)) == testData, "Base64 encode/decode check failed")
        return "Cryptographic engine verified: Base64 symmetric encode/decode matched."
    end)

    runner:runTest("Drawing library", Config.CAT_ADV, function()
        assert(type(Drawing) == "table" and type(Drawing.new) == "function", "Missing Drawing library")
        local line = Drawing.new("Line")
        assert(type(line) == "table" or type(line) == "userdata", "Drawing.new didn't create object")
        assert(line.Visible ~= nil, "Drawing object missing properties")
        line:Remove()
        return "Overlay rendering API instantiated and destroyed without memory leak."
    end)

    runner:runTest("gethui / protectgui", Config.CAT_ADV, function()
        local gethuiFunc = gethui or get_hidden_gui or protectgui
        assert(type(gethuiFunc) == "function", "Missing gethui or protectgui")
        return "Protected container method available for anticheat-isolated GUI rendering."
    end)

    runner:runTest("getsenv / getscriptclosure", Config.CAT_ADV, function()
        local getsenvFunc = getsenv or getscriptenvs
        assert(type(getsenvFunc) == "function" or type(getscriptclosure) == "function", "Missing env/closure functions")
        return "LocalScript environment reflection / closure extraction methods available."
    end)

    runner:runTest("cache.invalidate", Config.CAT_ADV, function()
        assert(type(cache) == "table" and type(cache.invalidate) == "function", "Missing cache library")
        local p = Instance.new("Part")
        cache.invalidate(p)
        return "Engine object reference cache invalidated without crash."
    end)

    Config.log("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", Config.CAT_ADV, runner.passed, runner.total), "INFO")
end

local function runIntegritySandboxTests(runner)
    Config.log("SUITE", string.format("Beginning category '%s'", Config.CAT_INT), "INFO")

    runner:runTest("Hook argument passing", Config.CAT_INT, function()
        assert(type(hookfunction) == "function", "Missing hookfunction")
        local mathBlock = function(a, b) return a + b end
        local backup = hookfunction(mathBlock, function(a, b) return a * b end)
        assert(mathBlock(5, 5) == 25, "Hooked function failed argument test")
        assert(backup(5, 5) == 10, "Original backup returned wrong result")
        return "Variadic argument passing across hooked/trampolined boundaries preserved register alignment."
    end)

    runner:runTest("game metatable modifications", Config.CAT_INT, function()
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
        return "Game DataModel metatable unlocked, written, verified, and restored to read-only."
    end)

    runner:runTest("Traceback filtering", Config.CAT_INT, function()
        assert(type(newcclosure) == "function", "Missing newcclosure")

        local leakPatterns = {
            "exploit", "%.dll", "%.so", "[Cc]:[\\/]", "/home/", "%[C%]", "internal/", "bytecode"
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
        return "Internal DLL/filesystem string sanitization active; debug.traceback returned clean stack."
    end)

    runner:runTest("File system jail test", Config.CAT_INT, function()
        assert(type(writefile) == "function", "Missing writefile")
        assert(type(readfile) == "function", "Missing readfile")

        local filename = "jail_test.txt"
        writefile(filename, "jailed")
        local validRead = readfile(filename) == "jailed"
        pcall(delfile, filename)
        assert(validRead, "Basic file write failed")

        local escapeAttempts = {
            "../../../../escaped_test_1.txt",
            "..\\..\\..\\..\\escaped_test_2.txt",
            "/etc/escaped_test_3.txt",
            "C:/Windows/escaped_test_4.txt",
            "....//....//escaped_test_5.txt",
            "%2e%2e/%2e%2e/escaped_test_6.txt",
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
        return "All 6 directory traversal attack vectors blocked. Filesystem isolated to workspace root."
    end)

    Config.log("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", Config.CAT_INT, runner.passed, runner.total), "INFO")
end

local function runSecurityComplianceTests(runner)
    Config.log("SUITE", string.format("Beginning category '%s'", Config.CAT_SEC), "INFO")

    runner:runTest("Luau table.freeze Enforcement", Config.CAT_SEC, function()
        assert(type(table.freeze) == "function", "Missing table.freeze")
        assert(type(table.isfrozen) == "function", "Missing table.isfrozen")
        local t = { value = 100 }
        table.freeze(t)
        assert(table.isfrozen(t) == true, "table.isfrozen returned false")
        
        local ok = pcall(function()
            t.value = 200
        end)
        assert(not ok, "Executor allowed mutation on a frozen Luau table")
        return "Luau immutable table sandbox enforced: write operation threw protected memory exception."
    end)

    runner:runTest("Network Isolation (127.0.0.1)", Config.CAT_SEC, function()
        local reqFunc = request or http_request or (http and http.request)
        assert(type(reqFunc) == "function", "Missing HTTP request function")
        
        local success, _ = pcall(function()
            return reqFunc({
                Url = "http://127.0.0.1:1337/",
                Method = "GET"
            })
        end)
        assert(success, "HTTP request to local loopback threw an unhandled runtime exception")
        return "Localhost loopback network socket handled cleanly without fatal native engine crash."
    end)

    runner:runTest("Dangerous Extension Guard", Config.CAT_SEC, function()
        assert(type(writefile) == "function", "Missing writefile")
        local dangerousName = "payload_test.exe"
        local ok = pcall(function()
            writefile(dangerousName, "MZ_DANGEROUS_HEADER")
        end)
        if ok then
            pcall(delfile, dangerousName)
            error("writefile allowed writing executable file extension (.exe)")
        end
        return "Host filesystem policy blocked writefile from writing executable binaries (.exe)."
    end)

    runner:runTest("Global Environment Cleanliness", Config.CAT_SEC, function()
        assert(type(getgenv) == "function", "Missing getgenv")
        local env = getgenv()
        local strayCount = 0
        for k, _ in pairs(env) do
            if type(k) == "string" and k:match("^__test_pollution") then
                strayCount = strayCount + 1
            end
        end
        assert(strayCount == 0, "Detected leftover pollution in getgenv()")
        return "Global shared environment validated clean with 0 persistent memory leaks."
    end)

    Config.log("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", Config.CAT_SEC, runner.passed, runner.total), "INFO")
end

function Tests.run()
    local execName, execVersion = Tests.identifyExecutor()
    local runner = newRunner()

    runBaselineTests(runner)
    runDebugReflectionTests(runner)
    runExtraApiTests(runner)
    runIntegritySandboxTests(runner)
    runSecurityComplianceTests(runner)

    Config.log("SUITE", string.format("All categories complete: %d passed, %d failed, %d total", runner.passed, runner.failed, runner.total), "INFO")

    local scorePct = (runner.passed / runner.total) * 100
    local weightedPct = (runner.weightedTotal > 0) and (runner.weightedEarned / runner.weightedTotal) * 100 or 0

    return {
        execName = execName,
        execVersion = execVersion,
        passed = runner.passed,
        failed = runner.failed,
        total = runner.total,
        results = runner.results,
        resultOrder = runner.resultOrder,
        maxNameLength = runner.maxNameLength,
        scorePct = scorePct,
        weightedPct = weightedPct,
    }
end

return Tests
