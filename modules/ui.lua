-- ui.lua
-- Rainbow text engine, rich-text console hook, merged failure badges, and advanced floating toolbar

local Config = import("config")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local Ui = {}

local activeRainbowConnection = nil

function Ui.getAnimatedRainbowText(text, timeOffset)
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

function Ui.buildOutputLines(runData, durationMs)
    Config.log("RENDER", "Assembling output lines and computing scores", "INFO")

    local outputLines = {}
    local animatedLineIndices = {}
    local lineMetadata = {}

    local aegisAsciiHeader = {
        "AEGIS SECURITY SUITE",
        "ENVIRONMENT INTEGRITY AUDIT"
    }

    for idx, line in ipairs(aegisAsciiHeader) do
        table.insert(outputLines, "HEADER_ANIMATED_PLACEHOLDER_" .. idx)
        animatedLineIndices[idx] = line
    end

    table.insert(outputLines, string.format('<font color="%s"><b>Exec Time :</b></font> <font color="%s">%.2fms</font>', Config.HEX_PURPLE, Config.HEX_CYAN, durationMs or 0))
    table.insert(outputLines, string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execName))
    table.insert(outputLines, string.format('<font color="%s"><b>Version   :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execVersion))
    table.insert(outputLines, string.format('<font color="%s"><b>Thread ID :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown"))
    table.insert(outputLines, string.format('<font color="%s"><i>[+] Checks complete!</i></font>', Config.HEX_CYAN))
    
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s"><b>                  DETAILED LOGS                   </b></font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))

    local formatSpecifier = string.format('   <font color="%%s">%%-%ds</font> : %%s', runData.maxNameLength)

    for _, catName in ipairs(Config.categoryOrder) do
        table.insert(outputLines, string.format('<font color="%s"><b>[%s]</b></font>', Config.HEX_PURPLE, catName:upper()))
        for _, name in ipairs(runData.resultOrder) do
            local data = runData.results[name]
            if data and data.cat == catName then
                local isCritical = (catName == "Integrity & Sandbox" or catName == "Security & Anti-Cheat" or name:find("jail") or name:find("freeze"))
                
                local badge
                if data.status == "PASS" then
                    badge = string.format('<font color="%s"><b>[PASS]</b></font>', Config.HEX_GREEN)
                elseif isCritical then
                    badge = string.format('<font color="%s"><b>[CRITICAL FAIL]</b></font>', Config.HEX_RED)
                else
                    badge = string.format('<font color="%s"><b>[WARNING]</b></font>', Config.HEX_YELLOW)
                end

                local lineIdx = #outputLines + 1
                table.insert(outputLines, string.format(formatSpecifier, Config.HEX_WHITE, name, badge))
                lineMetadata[lineIdx] = { status = data.status, isCritical = isCritical }
                
                if data.status == "FAIL" then
                    local cleanErr = data.err or "Unknown error"
                    local reasonIdx = #outputLines + 1
                    table.insert(outputLines, string.format('      <font color="%s">↳ <i>%s</i></font>', Config.HEX_RED, cleanErr))
                    lineMetadata[reasonIdx] = { status = "FAIL", isCritical = isCritical }
                end
            end
        end
    end

    Config.log("RENDER", string.format("Raw score %.1f%%, weighted score %.1f%%", runData.scorePct, runData.weightedPct), "INFO")

    local gradeBadge = runData.weightedPct >= 95
        and string.format('<font color="%s"><b>[PERFECT]</b></font>', Config.HEX_GREEN)
        or (runData.weightedPct >= 80 and string.format('<font color="%s"><b>[GOOD]</b></font>', Config.HEX_YELLOW) or string.format('<font color="%s"><b>[WEAK]</b></font>', Config.HEX_RED))

    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))

    local summaryIdx = #outputLines + 1
    table.insert(outputLines, "SUMMARY_ANIMATED_PLACEHOLDER")
    animatedLineIndices[summaryIdx] = "SUMMARY"

    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s (%s)</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execName, runData.execVersion))
    table.insert(outputLines, string.format('<font color="%s"><b>Passed    :</b></font> <font color="%s"><b>%d</b></font>', Config.HEX_PURPLE, Config.HEX_GREEN, runData.passed))
    table.insert(outputLines, string.format('<font color="%s"><b>Failed    :</b></font> <font color="%s"><b>%d</b></font>', Config.HEX_PURPLE, Config.HEX_RED, runData.failed))
    table.insert(outputLines, string.format('<font color="%s"><b>Total     :</b></font> <font color="%s">%d</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.total))
    table.insert(outputLines, string.format('<font color="%s"><b>Raw Score :</b></font> <font color="%s"><b>%.1f%%</b></font>', Config.HEX_PURPLE, Config.HEX_CYAN, runData.scorePct))
    table.insert(outputLines, string.format('<font color="%s"><b>Weighted  :</b></font> <font color="%s"><b>%.1f%%</b></font> %s', Config.HEX_PURPLE, Config.HEX_CYAN, runData.weightedPct, gradeBadge))
    table.insert(outputLines, string.format('<font color="%s"><b>Export    :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW,
        runData.EXPORT_ENABLED
            and string.format("%s / %s (json: %s)", Config.CSV_LOG_FILE, Config.JSON_LOG_FILE, runData.jsonExportStatus)
            or "disabled (no writefile/readfile)"))
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))

    return outputLines, animatedLineIndices, lineMetadata
end

function Ui.printPlain(outputLines, animatedLineIndices)
    Config.log("RENDER", string.format("Built %d output lines, printing to console", #outputLines), "INFO")

    local sessionToken = math.floor(tick() % 100000)
    local plainBuffer = {}
    
    for idx, line in ipairs(outputLines) do
        local plainText = line
        if animatedLineIndices[idx] then
            plainText = animatedLineIndices[idx]
        else
            plainText = line:gsub("<[^>]+>", "")
        end
        local marker = string.format(" [S%d:%02d]", sessionToken, idx)
        print(plainText .. marker)
        plainBuffer[idx] = marker
    end
    return plainBuffer
end

function Ui.attachDevConsole(devConsole, outputLines, animatedLineIndices, plainBuffer, lineMetadata, runData, durationMs, reRunCallback)
    task.spawn(function()
        local activeLabels = {}
        local labelsByLineIdx = {}

        local targetRoot = devConsole or CoreGui:FindFirstChild("DevConsoleMaster") or CoreGui

        local function checkAndFormatLabel(obj)
            if obj:IsA("TextLabel") then
                local objText = obj.Text
                for idx, marker in ipairs(plainBuffer) do
                    if objText:find(marker, 1, true) then
                        obj.RichText = true
                        activeLabels[idx] = obj
                        labelsByLineIdx[idx] = obj

                        if not animatedLineIndices[idx] then
                            if idx <= #outputLines then
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
                        end
                        break
                    end
                end
            end
        end

        for _, v in pairs(targetRoot:GetDescendants()) do
            checkAndFormatLabel(v)
        end

        targetRoot.DescendantAdded:Connect(function(desc)
            task.wait()
            checkAndFormatLabel(desc)
        end)

        if targetRoot ~= CoreGui then
            CoreGui.DescendantAdded:Connect(function(desc)
                task.wait()
                checkAndFormatLabel(desc)
            end)
        end

        -- Clean up prior screen gui instances
        local existingGui = CoreGui:FindFirstChild("AEGIS_ToolbarGui")
        if existingGui then existingGui:Destroy() end

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "AEGIS_ToolbarGui"
        screenGui.ResetOnSpawn = false
        pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(screenGui)
            elseif protectgui then protectgui(screenGui) end
        end)
        screenGui.Parent = CoreGui

        local fullWidth = 475
        local minWidth = 110
        local isMinimized = false

        local bar = Instance.new("Frame")
        bar.Name = "Toolbar"
        bar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        bar.BorderSizePixel = 1
        bar.BorderColor3 = Color3.fromRGB(50, 50, 60)
        bar.Size = UDim2.new(0, fullWidth, 0, 32)
        bar.Position = UDim2.new(1, -fullWidth - 15, 0, 10)
        bar.Active = true
        bar.Draggable = true
        bar.ClipsDescendants = true
        bar.Parent = screenGui

        -- Score chip color-coding
        local scoreColor = runData.weightedPct >= 90 and Color3.fromRGB(60, 220, 120)
            or (runData.weightedPct >= 75 and Color3.fromRGB(240, 190, 60) or Color3.fromRGB(240, 80, 80))

        local scoreChip = Instance.new("TextLabel")
        scoreChip.Text = string.format("%.1f%%", runData.weightedPct)
        scoreChip.TextColor3 = scoreColor
        scoreChip.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
        scoreChip.BorderSizePixel = 1
        scoreChip.BorderColor3 = scoreColor
        scoreChip.Size = UDim2.new(0, 50, 0, 20)
        scoreChip.Position = UDim2.new(0, 8, 0.5, -10)
        scoreChip.Font = Enum.Font.Code
        scoreChip.TextSize = 11
        scoreChip.Parent = bar

        local title = Instance.new("TextLabel")
        title.Text = "AEGIS"
        title.Font = Enum.Font.Code
        title.TextSize = 12
        title.TextColor3 = Color3.fromRGB(220, 220, 220)
        title.BackgroundTransparency = 1
        title.Size = UDim2.new(0, 42, 1, 0)
        title.Position = UDim2.new(0, 64, 0, 0)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = bar

        local controlsContainer = Instance.new("Frame")
        controlsContainer.Name = "Controls"
        controlsContainer.BackgroundTransparency = 1
        controlsContainer.Size = UDim2.new(0, 320, 1, 0)
        controlsContainer.Position = UDim2.new(0, 112, 0, 0)
        controlsContainer.Parent = bar

        local buttons = {}
        local currentActiveFilter = "ALL"

        local function makeBtn(parent, name, xPos, width, col)
            local btn = Instance.new("TextButton")
            btn.Name = name
            btn.Text = name
            btn.TextColor3 = col
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
            btn.BorderSizePixel = 1
            btn.BorderColor3 = Color3.fromRGB(45, 45, 55)
            btn.Size = UDim2.new(0, width, 0, 20)
            btn.Position = UDim2.new(0, xPos, 0.5, -10)
            btn.Font = Enum.Font.Code
            btn.TextSize = 11
            btn.Parent = parent
            return btn
        end

        local btnAll  = makeBtn(controlsContainer, "ALL", 0, 38, Color3.fromRGB(210, 210, 210))
        local btnCrit = makeBtn(controlsContainer, "CRIT", 42, 42, Color3.fromRGB(255, 95, 95))
        local btnFail = makeBtn(controlsContainer, "FAIL", 88, 42, Color3.fromRGB(255, 175, 50))
        local btnLogs = makeBtn(controlsContainer, "LOGS", 134, 44, Color3.fromRGB(180, 150, 255))
        local btnCopy = makeBtn(controlsContainer, "COPY", 182, 44, Color3.fromRGB(110, 255, 130))
        local btnReRun = makeBtn(controlsContainer, "↻", 230, 26, Color3.fromRGB(120, 200, 255))

        buttons["ALL"] = btnAll
        buttons["CRIT"] = btnCrit
        buttons["FAIL"] = btnFail

        local function updateFilterHighlights(filterType)
            currentActiveFilter = filterType
            for fName, btn in pairs(buttons) do
                if fName == filterType then
                    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
                    btn.BorderColor3 = Color3.fromRGB(100, 140, 255)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
                    btn.BorderColor3 = Color3.fromRGB(45, 45, 55)
                end
            end

            for lineIdx, meta in pairs(lineMetadata) do
                local lbl = labelsByLineIdx[lineIdx]
                if lbl and lbl.Parent then
                    local show = true
                    if filterType == "CRIT" then
                        show = (meta.status == "FAIL" and meta.isCritical == true)
                    elseif filterType == "FAIL" then
                        show = (meta.status == "FAIL")
                    end
                    lbl.Visible = show
                end
            end
        end

        updateFilterHighlights("ALL")

        btnAll.MouseButton1Click:Connect(function() updateFilterHighlights("ALL") end)
        btnCrit.MouseButton1Click:Connect(function() updateFilterHighlights("CRIT") end)
        btnFail.MouseButton1Click:Connect(function() updateFilterHighlights("FAIL") end)

        -- Toggle DevConsole visibility
        btnLogs.MouseButton1Click:Connect(function()
            pcall(function()
                local devMaster = CoreGui:FindFirstChild("DevConsoleMaster")
                if devMaster and devMaster:FindFirstChild("DevConsoleWindow") then
                    devMaster.DevConsoleWindow.Visible = not devMaster.DevConsoleWindow.Visible
                end
            end)
        end)

        -- Live re-run suite
        btnReRun.MouseButton1Click:Connect(function()
            btnReRun.Text = "..."
            task.wait(0.05)
            if reRunCallback then
                reRunCallback()
            end
        end)

        -- Exhaustive clipboard export
        btnCopy.MouseButton1Click:Connect(function()
            if setclipboard then
                local report = {}
                table.insert(report, "================================================================================")
                table.insert(report, "                     AEGIS ENVIRONMENT AUDIT REPORT                             ")
                table.insert(report, "================================================================================")
                table.insert(report, string.format("Host Software   : %s", runData.execName))
                table.insert(report, string.format("Software Version: %s", runData.execVersion))
                table.insert(report, string.format("Thread Identity : %s", type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown"))
                table.insert(report, string.format("Benchmark Time  : %.2f ms", durationMs or 0))
                table.insert(report, string.format("Audit Score     : %.1f%% (Passed: %d | Failed: %d | Total: %d)", runData.scorePct, runData.passed, runData.failed, runData.total))
                table.insert(report, string.format("Weighted Score  : %.1f%%", runData.weightedPct))
                table.insert(report, "================================================================================")
                table.insert(report, "                         TECHNICAL TEST ASSERTIONS                              ")
                table.insert(report, "================================================================================")

                for _, catName in ipairs(Config.categoryOrder) do
                    table.insert(report, "")
                    table.insert(report, string.format("[%s]", catName:upper()))
                    table.insert(report, string.rep("-", 80))

                    for _, name in ipairs(runData.resultOrder) do
                        local data = runData.results[name]
                        if data and data.cat == catName then
                            local isCritical = (catName == "Integrity & Sandbox" or catName == "Security & Anti-Cheat" or name:find("jail") or name:find("freeze"))
                            local tag = data.status == "PASS" and "[PASS]" or (isCritical and "[CRITICAL FAIL]" or "[WARNING]")

                            table.insert(report, string.format("TEST      : %s", name))
                            table.insert(report, string.format("STATUS    : %s", tag))
                            
                            if data.detail and data.detail ~= "" then
                                table.insert(report, string.format("EVALUATION: %s", data.detail))
                            end

                            if data.status == "FAIL" then
                                local rawErr = data.err or "Unknown Exception"
                                table.insert(report, string.format("EXCEPTION : %s", rawErr))
                            end

                            table.insert(report, string.rep(".", 40))
                        end
                    end
                end

                table.insert(report, "")
                table.insert(report, "================================================================================")
                table.insert(report, "                               END OF REPORT                                    ")
                table.insert(report, "================================================================================")

                setclipboard(table.concat(report, "\n"))
                btnCopy.Text = "COPIED"
                task.wait(1)
                btnCopy.Text = "COPY"
            else
                btnCopy.Text = "NO API"
                task.wait(2)
                btnCopy.Text = "COPY"
            end
        end)

        -- Window Controls (Minimize & Close)
        local btnMin = makeBtn(bar, "—", fullWidth - 52, 22, Color3.fromRGB(190, 190, 190))
        local btnClose = makeBtn(bar, "✕", fullWidth - 26, 22, Color3.fromRGB(255, 95, 95))

        btnMin.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            if isMinimized then
                controlsContainer.Visible = false
                btnMin.Text = "+"
                btnMin.Position = UDim2.new(0, minWidth - 46, 0.5, -10)
                btnClose.Position = UDim2.new(0, minWidth - 22, 0.5, -10)
                bar.Size = UDim2.new(0, minWidth, 0, 32)
            else
                controlsContainer.Visible = true
                btnMin.Text = "—"
                btnMin.Position = UDim2.new(0, fullWidth - 52, 0.5, -10)
                btnClose.Position = UDim2.new(0, fullWidth - 26, 0.5, -10)
                bar.Size = UDim2.new(0, fullWidth, 0, 32)
            end
        end)

        btnClose.MouseButton1Click:Connect(function()
            if activeRainbowConnection then
                activeRainbowConnection:Disconnect()
                activeRainbowConnection = nil
            end
            screenGui:Destroy()
        end)

        -- Header Animation Render Loop
        if activeRainbowConnection then
            activeRainbowConnection:Disconnect()
            activeRainbowConnection = nil
        end

        local lastUpdate = 0
        activeRainbowConnection = RunService.RenderStepped:Connect(function()
            local now = tick()
            if now - lastUpdate < 0.03 then return end
            lastUpdate = now

            for idx, rawText in pairs(animatedLineIndices) do
                local label = activeLabels[idx]
                if label and label.Parent then
                    label.Text = Ui.getAnimatedRainbowText(rawText, now)
                end
            end
        end)
    end)
end

return Ui
