-- ui.lua
-- rainbow text gen, output line rendering, devconsole hook with transparent container row

local Config = import("config")
local RunService = game:GetService("RunService")

local Ui = {}

-- Clean per-letter HSV pulse engine
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

-- build the output lines from a finished run
function Ui.buildOutputLines(runData, durationMs)
    Config.log("RENDER", "Assembling output lines and computing scores", "INFO")

    local outputLines = {}
    local animatedLineIndices = {}

    -- Clean text header using pure letters and spaces
    local aegisAsciiHeader = {
        "AEGIS SECURITY SUITE",
        "ENVIRONMENT INTEGRITY AUDIT"
    }

    for idx, line in ipairs(aegisAsciiHeader) do
        table.insert(outputLines, "HEADER_ANIMATED_PLACEHOLDER_" .. idx)
        animatedLineIndices[idx] = line
    end

    -- Benchmark & Software Info at the top
    table.insert(outputLines, string.format('<font color="%s"><b>Exec Time :</b></font> <font color="%s">%.2fms</font>', Config.HEX_PURPLE, Config.HEX_CYAN, durationMs or 0))
    table.insert(outputLines, string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execName))
    table.insert(outputLines, string.format('<font color="%s"><b>Version   :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execVersion))
    table.insert(outputLines, string.format('<font color="%s"><b>Thread ID :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown"))
    table.insert(outputLines, string.format('<font color="%s"><i>[+] Checks complete!</i></font>', Config.HEX_CYAN))
    
    local toolbarMarker = " [TOOLBAR_UI_MARKER]"
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s"><b>                    DETAILED LOGS                   </b></font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))
    table.insert(outputLines, " " .. toolbarMarker)

    local formatSpecifier = string.format('   <font color="%%s">%%-%ds</font> : %%s', runData.maxNameLength)

    for _, catName in ipairs(Config.categoryOrder) do
        table.insert(outputLines, string.format('<font color="%s"><b>[%s]</b></font>', Config.HEX_PURPLE, catName:upper()))
        for _, name in ipairs(runData.resultOrder) do
            local data = runData.results[name]
            if data.cat == catName then
                local badge = data.status == "PASS"
                    and string.format('<font color="%s"><b>[PASS]</b></font>', Config.HEX_GREEN)
                    or string.format('<font color="%s"><b>[FAIL]</b></font>', Config.HEX_RED)

                local lineIdx = #outputLines + 1
                local filterTag = string.format(" [FID:%d:%s]", lineIdx, data.status)
                table.insert(outputLines, string.format(formatSpecifier, Config.HEX_WHITE, name, badge) .. filterTag)
                
                if data.status == "FAIL" then
                    local isCritical = (catName == "Integrity & Sandbox" or catName == "Security & Anti-Cheat" or name:find("jail") or name:find("freeze"))
                    local severityText = isCritical and "[CRITICAL FAILURE]" or "[WARNING]"
                    local severityHex = isCritical and Config.HEX_RED or Config.HEX_YELLOW

                    local cleanErr = data.err or "Unknown error"
                    cleanErr = cleanErr:gsub("^.-:%d+:%s*", "")

                    table.insert(outputLines, string.format('      <font color="%s"><b>%s</b></font> <font color="%s"><i>↳ %s</i></font>', severityHex, severityText, Config.HEX_RED, cleanErr) .. filterTag)
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

    return outputLines, animatedLineIndices, toolbarMarker
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

function Ui.attachDevConsole(devConsole, outputLines, animatedLineIndices, plainBuffer, runData, durationMs, toolbarMarker)
    if not devConsole then
        Config.log("RENDER", "Skipping rich-text formatter, no DevConsole available", "INFO")
        return
    end

    Config.log("RENDER", "Attaching rich-text formatter to DevConsole labels", "INFO")

    task.spawn(function()
        local activeLabels = {}
        local resultLines = {}

        local function checkAndFormatLabel(obj)
            if obj:IsA("TextLabel") then
                for idx, marker in ipairs(plainBuffer) do
                    if obj.Text:find(marker, 1, true) then
                        obj.RichText = true
                        activeLabels[idx] = obj

                        if not animatedLineIndices[idx] then
                            if idx <= #outputLines then
                                local targetRichText = outputLines[idx]
                                if targetRichText then
                                    if targetRichText:find(toolbarMarker, 1, true) then
                                        -- Force native printed text completely invisible so it cannot bleed through
                                        obj.TextTransparency = 1
                                        obj.Text = " "

                                        if obj:FindFirstChild("AEGIS_Toolbar") then
                                            obj.AEGIS_Toolbar:Destroy()
                                        end

                                        local toolbarFrame = Instance.new("Frame")
                                        toolbarFrame.Name = "AEGIS_Toolbar"
                                        toolbarFrame.BackgroundTransparency = 1
                                        toolbarFrame.Size = UDim2.new(1, 0, 1, 0)
                                        toolbarFrame.Position = UDim2.new(0, 0, 0, 0)
                                        toolbarFrame.Parent = obj

                                        local statusLbl = Instance.new("TextLabel")
                                        statusLbl.Text = "[FILTER: ALL]"
                                        statusLbl.TextColor3 = Color3.fromRGB(130, 130, 130)
                                        statusLbl.BackgroundTransparency = 1
                                        statusLbl.Size = UDim2.new(0, 110, 1, 0)
                                        statusLbl.Position = UDim2.new(0, 2, 0, 0)
                                        statusLbl.Font = Enum.Font.Code
                                        statusLbl.TextSize = 11
                                        statusLbl.TextXAlignment = Enum.TextXAlignment.Left
                                        statusLbl.Parent = toolbarFrame

                                        local function createButton(name, posX, width, color)
                                            local btn = Instance.new("TextButton")
                                            btn.Text = name
                                            btn.TextColor3 = color
                                            btn.BackgroundTransparency = 0.3
                                            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                                            btn.Size = UDim2.new(0, width, 0, 18)
                                            btn.Position = UDim2.new(0, posX, 0.5, -9)
                                            btn.Font = Enum.Font.Code
                                            btn.TextSize = 11
                                            btn.Parent = toolbarFrame
                                            return btn
                                        end

                                        local btnAll  = createButton("ALL", 120, 46, Color3.fromRGB(210, 210, 210))
                                        local btnCrit = createButton("CRIT", 172, 46, Color3.fromRGB(255, 95, 95))
                                        local btnFail = createButton("FAIL", 224, 46, Color3.fromRGB(255, 170, 0))
                                        local copyBtn = createButton("COPY", 276, 54, Color3.fromRGB(110, 255, 110))

                                        local function applyFilter(filterType)
                                            statusLbl.Text = "[FILTER: " .. filterType .. "]"
                                            for lineIdx, lineLabels in pairs(resultLines) do
                                                local shouldShow = true
                                                local lineText = outputLines[lineIdx] or ""
                                                if filterType == "CRIT" then
                                                    shouldShow = lineText:find("%[CRITICAL FAILURE%]") ~= nil
                                                elseif filterType == "FAIL" then
                                                    shouldShow = lineText:find("FAIL") ~= nil
                                                end
                                                for _, lbl in ipairs(lineLabels) do
                                                    if lbl and lbl.Parent then
                                                        lbl.Parent.Visible = shouldShow
                                                    end
                                                end
                                            end
                                        end

                                        btnAll.MouseButton1Click:Connect(function() applyFilter("ALL") end)
                                        btnCrit.MouseButton1Click:Connect(function() applyFilter("CRIT") end)
                                        btnFail.MouseButton1Click:Connect(function() applyFilter("FAIL") end)

                                        copyBtn.MouseButton1Click:Connect(function()
                                            if setclipboard then
                                                local report = {}
                                                table.insert(report, "--- AEGIS SECURITY AUDIT REPORT ---")
                                                table.insert(report, string.format("Software: %s (%s)", runData.execName, runData.execVersion))
                                                table.insert(report, string.format("Exec Time: %.2fms", durationMs or 0))
                                                table.insert(report, string.format("Score: %.1f%%", runData.weightedPct))
                                                table.insert(report, "----------------------------------")
                                                for _, line in ipairs(outputLines) do
                                                    if not line:find("PLACEHOLDER") and not line:find("=================") and not line:find(" [FID") then
                                                        table.insert(report, line:gsub("<[^>]+>", ""))
                                                    elseif line:find(" [FID") and (line:find("FAIL") or line:find("CRITICAL")) then
                                                        table.insert(report, line:gsub(" %[FID:.*", ""):gsub("<[^>]+>", ""))
                                                    end
                                                end
                                                setclipboard(table.concat(report, "\n"))
                                                copyBtn.Text = "COPIED"
                                                task.wait(1)
                                                copyBtn.Text = "COPY"
                                            else
                                                copyBtn.Text = "NO API"
                                                task.wait(2)
                                                copyBtn.Text = "COPY"
                                            end
                                        end)

                                        -- Guard against DevConsole resetting Text or TextTransparency
                                        local isLocking = false
                                        local function enforceHidden()
                                            if not isLocking and (obj.TextTransparency ~= 1 or obj.Text ~= " ") then
                                                isLocking = true
                                                obj.TextTransparency = 1
                                                obj.Text = " "
                                                isLocking = false
                                            end
                                        end
                                        obj:GetPropertyChangedSignal("Text"):Connect(enforceHidden)
                                        obj:GetPropertyChangedSignal("TextTransparency"):Connect(enforceHidden)
                                    else
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
                            end
                        else
                            local lineIdx = outputLines[idx] and outputLines[idx]:match(" %[FID:(%d+):")
                            if lineIdx then
                                lineIdx = tonumber(lineIdx)
                                if not resultLines[lineIdx] then resultLines[lineIdx] = {} end
                                table.insert(resultLines[lineIdx], obj)
                            end
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

        local lastUpdate = 0
        RunService.RenderStepped:Connect(function()
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
