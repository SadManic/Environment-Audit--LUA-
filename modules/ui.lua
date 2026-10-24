-- ui.lua
-- rainbow text gen, output line rendering, devconsole hook with integrated failure tags

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
function Ui.buildOutputLines(runData)
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

    table.insert(outputLines, string.format('<font color="%s"><b>Software  :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execName))
    table.insert(outputLines, string.format('<font color="%s"><b>Version   :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, runData.execVersion))
    table.insert(outputLines, string.format('<font color="%s"><b>Thread ID :</b></font> <font color="%s">%s</font>', Config.HEX_PURPLE, Config.HEX_YELLOW, type(getthreadidentity) == "function" and tostring(getthreadidentity()) or "Unknown"))
    table.insert(outputLines, string.format('<font color="%s"><i>[+] Checks complete!</i></font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s"><b>                    DETAILED LOGS                   </b></font>', Config.HEX_CYAN))
    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))

    local formatSpecifier = string.format('   <font color="%%s">%%-%ds</font> : %%s', runData.maxNameLength)

    -- use resultOrder so this prints in the same order every run
    for _, catName in ipairs(Config.categoryOrder) do
        table.insert(outputLines, string.format('<font color="%s"><b>[%s]</b></font>', Config.HEX_PURPLE, catName:upper()))
        for _, name in ipairs(runData.resultOrder) do
            local data = runData.results[name]
            if data.cat == catName then
                local badge = data.status == "PASS"
                    and string.format('<font color="%s"><b>[PASS]</b></font>', Config.HEX_GREEN)
                    or string.format('<font color="%s"><b>[FAIL]</b></font>', Config.HEX_RED)

                table.insert(outputLines, string.format(formatSpecifier, Config.HEX_WHITE, name, badge))
                
                -- Integrated failure severity and reason on clean sub-lines
                if data.status == "FAIL" then
                    local isCritical = (catName == "Integrity & Sandbox" or catName == "Security & Anti-Cheat" or name:find("jail") or name:find("freeze"))
                    local severityBadge = isCritical 
                        and string.format('<font color="%s"><b>[CRITICAL FAILURE]</b></font>', Config.HEX_RED)
                        or string.format('<font color="%s"><b>[WARNING]</b></font>', Config.HEX_YELLOW)

                    table.insert(outputLines, string.format('      Severity : %s', severityBadge))
                    if data.err then
                        -- Clean up file paths from error string if desired, or show exact reason
                        table.insert(outputLines, string.format('      <font color="%s"><i>↳ Reason : %s</i></font>', Config.HEX_RED, data.err))
                    end
                end
            end
        end
    end

    Config.log("RENDER", string.format("Raw score %.1f%%, weighted score %.1f%%", runData.scorePct, runData.weightedPct), "INFO")

    local gradeBadge = runData.weightedPct >= 95
        and string.format('<font color="%s"><b>[PERFECT]</b></font>', Config.HEX_GREEN)
        or (runData.weightedPct >= 80 and string.format('<font color="%s"><b>[GOOD]</b></font>', Config.HEX_YELLOW) or string.format('<font color="%s"><b>[WEAK]</b></font>', Config.HEX_RED))

    table.insert(outputLines, string.format('<font color="%s">==================================================</font>', Config.HEX_CYAN))

    -- summary line (animated)
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

    return outputLines, animatedLineIndices
end

-- print it all, tag each line with a unique session stamp + marker
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

-- rainbow text in dev console if its open
function Ui.attachDevConsole(devConsole, outputLines, animatedLineIndices, plainBuffer)
    if not devConsole then
        Config.log("RENDER", "Skipping rich-text formatter, no DevConsole available", "INFO")
        return
    end

    Config.log("RENDER", "Attaching rich-text formatter to DevConsole labels", "INFO")

    task.spawn(function()
        local activeLabels = {}

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

        -- ~30fps update loop for smooth pulsing
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
