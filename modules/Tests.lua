-- tests.lua
-- Test execution runner & test definitions.
-- Depends on: config.lua

local Config = import("config")

local Tests = {}

-- ===== Executor identification =====
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

-- ===== Runner state + runTest =====
-- Returns a fresh runner object so Tests.run() can be called more than once cleanly.
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
            self.results[testName] = { status = "PASS", cat = category, err = nil }
            Config.log("TEST", string.format("'%s' PASSED", testName), "TRACE")
        else
            self.failed = self.failed + 1
            self.results[testName] = { status = "FAIL", cat = category, err = tostring(result) }
            Config.log("TEST", string.format("'%s' FAILED :: %s", testName, tostring(result)), "ERROR")
        end

        table.insert(self.resultOrder, testName)
    end

    return runner
end

-- ===== Test definitions, grouped by category =====
local function runBaselineTests(runner)
    Config.log("SUITE", string.format("Beginning category '%s'", Config.CAT_BASE), "INFO")

    runner:runTest("Environment Tables", Config.CAT_BASE, function()
        assert(type(getgenv) == "function", "Missing getgenv")
        assert(type(getrenv) == "function", "Missing getrenv")
        assert(type(getreg) == "function", "Missing getreg")
    end)

    runner:runTest("getrawmetatable", Config.CAT_BASE, function()
        assert(type(getrawmetatable) == "function", "Missing getrawmetatable")
        local t = setmetatable({}, { __metatable = "Protected" })
        local meta = getrawmetatable(t)
        assert(type(meta) == "table", "Failed to get metatable from protected table")
    end)

    runner:runTest("setrawmetatable", Config.CAT_BASE, function()
        assert(type(setrawmetatable) == "function", "Missing setrawmetatable")
        local t = setmetatable({}, { __metatable = "Protected" })
        setrawmetatable(t, { __index = function() return "patched" end })
        assert(t.anyKey == "patched", "Failed to modify metatable via setrawmetatable")
    end)

    runner:runTest("setreadonly / isreadonly", Config.CAT_BASE, function()
        assert(type(setreadonly) == "function", "Missing setreadonly")
        assert(type(isreadonly) == "function", "Missing isreadonly")
        local t = {}
        setreadonly(t, true)
        assert(isreadonly(t) == true, "Table read-only state didn't change")
    end)

    runner:runTest("hookfunction", Config.CAT_BASE, function()
        assert(type(hookfunction) == "function", "Missing hookfunction")
        local function target() return "original" end
        local original = hookfunction(target, function() return "hooked" end)
        assert(target() == "hooked", "Hook didn't override target function")
        assert(original() == "original", "Original function copy failed")
    end)

    runner:runTest("hookmetamethod", Config.CAT_BASE, function()
        assert(type(hookmetamethod) == "function", "Missing hookmetamethod")
        local t = setmetatable({}, { __index = function(self, key) return "original_meta" end })
        local original = hookmetamethod(t, "__index", function() return "hooked_meta" end)
        assert(t.anyKey == "hooked_meta", "__index hook failed")
        assert(original() == "original_meta", "Original metamethod copy failed")
    end)

    runner:runTest("newcclosure / iscclosure", Config.CAT_BASE, function()
        assert(type(newcclosure) == "function", "Missing newcclosure")
        assert(type(iscclosure) == "function", "Missing iscclosure")
        local f = function() return "test" end
        local c = newcclosure(f)
        assert(iscclosure(c) == true, "iscclosure returned false for newcclosure wrapper")
        assert(c() == "test", "Wrapped function returned wrong value")
    end)

    runner:runTest("checkclosure / clonefunction", Config.CAT_BASE, function()
        assert(type(clonefunction) == "function", "Missing clonefunction")
        local f = function() return "clone_me" end
        local cloned = clonefunction(f)
        assert(cloned() == "clone_me", "Cloned function returned wrong value")
        assert(cloned ~= f, "clonefunction returned original reference")
    end)

    runner:runTest("getgc", Config.CAT_BASE, function()
        assert(type(getgc) == "function", "Missing getgc")
        assert(type(getgc()) == "table", "getgc didn't return a table")
    end)

    runner:runTest("getinstances", Config.CAT_BASE, function()
        local getinst = getinstances or get_instances
        local getnil = getnilinstances or get_nil_instances
        assert(type(getinst) == "function", "Missing getinstances")
        assert(type(getnil) == "function", "Missing getnilinstances")
        assert(type(getinst()) == "table", "getinstances didn't return a table")
        assert(type(getnil()) == "table", "getnilinstances didn't return a table")
    end)

    runner:runTest("Interaction Utilities", Config.CAT_BASE, function()
        assert(type(fireclickdetector) == "function" or type(firetouchinterest) == "function", "Missing click/touch fire functions")
    end)

    runner:runTest("readfile / writefile", Config.CAT_BASE, function()
        assert(type(writefile) == "function", "Missing writefile")
        assert(type(readfile) == "function", "Missing readfile")
        local filename = "unc_diag_test.txt"
        writefile(filename, "test")
        local content = readfile(filename)
        pcall(delfile, filename)
        assert(content == "test", "File content didn't match after write")
    end)

    runner:runTest("http request", Config.CAT_BASE, function()
        local reqFunc = request or http_request or (http and http.request)
        assert(type(reqFunc) == "function", "Missing HTTP request function")
    end)

    runner:runTest("getloadedmodules", Config.CAT_BASE, function()
        local getmodules = getloadedmodules or getmodules
        assert(type(getmodules) == "function", "Missing getloadedmodules")
    end)

    runner:runTest("checkcaller", Config.CAT_BASE, function()
        assert(type(checkcaller) == "function", "Missing checkcaller")
        assert(checkcaller() == true, "checkcaller returned false inside script thread")
    end)

    runner:runTest("decompile", Config.CAT_BASE, function()
        local decomp = decompile or disassemble or getscriptbytecode
        assert(type(decomp) == "function", "Missing decompiler function")
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
        local ref2 = cloneRefFunc(testPart)
        assert(ref1 ~= ref2, "cloneref gave duplicate proxies")
        assert(ref1 == testPart, "Proxy equality check failed")
    end)

    runner:runTest("compareinstances", Config.CAT_TECH, function()
        local comp = compareinstances or (cloneref and function(a, b) return a == b end)
        assert(type(comp) == "function", "Missing compareinstances")
        local p = Instance.new("Part")
        assert(comp(p, p) == true, "compareinstances returned false for same part")
    end)

    runner:runTest("debug.getinfo", Config.CAT_TECH, function()
        local getinfo = debug.getinfo or getinfo
        assert(type(getinfo) == "function", "Missing debug.getinfo")
        local info = getinfo(1)
        assert(type(info) == "table" and info.short_src ~= nil, "getinfo returned bad table")
    end)

    runner:runTest("debug.getupvalues / setupvalue", Config.CAT_TECH, function()
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

    runner:runTest("debug.getconstants", Config.CAT_TECH, function()
        local getconstants = debug.getconstants or getconstants
        assert(type(getconstants) == "function", "Missing debug.getconstants")
        local function target() return "const_marker" end
        local original = hookfunction(target, function() return "hooked" end)
        local consts = getconstants(original)
        local found = false
        for _, v in ipairs(consts) do if v == "const_marker" then found = true break end end
        assert(found, "Couldn't find constant in hooked function copy")
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
    end)

    runner:runTest("crypt library", Config.CAT_ADV, function()
        local lib = crypt or Base64 or base64
        assert(type(lib) == "table" or type(crypt) == "table", "Missing crypt library")
        local enc = (crypt and crypt.base64encode) or (lib and lib.encode) or base64_encode
        local dec = (crypt and crypt.base64decode) or (lib and lib.decode) or base64_decode
        assert(type(enc) == "function" and type(dec) == "function", "Missing base64 encode/decode")
        local testData = "UNC_TEST"
        assert(dec(enc(testData)) == testData, "Base64 encode/decode check failed")
    end)

    runner:runTest("Drawing library", Config.CAT_ADV, function()
        assert(type(Drawing) == "table" and type(Drawing.new) == "function", "Missing Drawing library")
        local line = Drawing.new("Line")
        assert(type(line) == "table" or type(line) == "userdata", "Drawing.new didn't create object")
        assert(line.Visible ~= nil, "Drawing object missing properties")
        line:Remove()
    end)

    runner:runTest("gethui / protectgui", Config.CAT_ADV, function()
        local gethuiFunc = gethui or get_hidden_gui or protectgui
        assert(type(gethuiFunc) == "function", "Missing gethui or protectgui")
    end)

    runner:runTest("getsenv / getscriptclosure", Config.CAT_ADV, function()
        local getsenvFunc = getsenv or getscriptenvs
        assert(type(getsenvFunc) == "function" or type(getscriptclosure) == "function", "Missing env/closure functions")
    end)

    runner:runTest("cache.invalidate", Config.CAT_ADV, function()
        assert(type(cache) == "table" and type(cache.invalidate) == "function", "Missing cache library")
        local p = Instance.new("Part")
        cache.invalidate(p)
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
    end)

    -- Check for leaks besides just the word "exploit"
    runner:runTest("Traceback filtering", Config.CAT_INT, function()
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
    runner:runTest("File system jail test", Config.CAT_INT, function()
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

    Config.log("SUITE", string.format("Category '%s' complete (%d/%d passed so far)", Config.CAT_INT, runner.passed, runner.total), "INFO")
end

-- ===== Public entrypoint =====
-- Runs the full suite and returns a runData table consumed by ui.lua / logger.lua.
function Tests.run()
    local execName, execVersion = Tests.identifyExecutor()
    local runner = newRunner()

    runBaselineTests(runner)
    runDebugReflectionTests(runner)
    runExtraApiTests(runner)
    runIntegritySandboxTests(runner)

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
