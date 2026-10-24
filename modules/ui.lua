-- Replace the button frame section inside ui.lua under the filterMarker condition with this:

if targetRichText:find(filterMarker, 1, true) then
    -- Keep just the clean header title without the duplicate text
    obj.Text = targetRichText:gsub(filterMarker, "")
    
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "FilterButtonFrame"
    buttonFrame.BackgroundTransparency = 1
    -- Pin it cleanly to the right side of the label row
    buttonFrame.Size = UDim2.new(0, 210, 1, 0)
    buttonFrame.AnchorPoint = Vector2.new(1, 0)
    buttonFrame.Position = UDim2.new(1, -10, 0, 0)
    buttonFrame.Parent = obj
    
    local function createButton(name, posX, color)
        local btn = Instance.new("TextButton")
        btn.Text = name
        btn.TextColor3 = color
        btn.BackgroundTransparency = 0.3
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        btn.Size = UDim2.new(0, 64, 0, 18)
        btn.Position = UDim2.new(0, posX, 0.5, -9)
        btn.Font = Enum.Font.Code
        btn.TextSize = 11
        btn.Parent = buttonFrame
        return btn
    end

    local btnAll = createButton("ALL", 0, Color3.fromRGB(200,200,200))
    local btnCrit = createButton("CRIT", 70, Color3.fromRGB(255, 100, 100))
    local btnFail = createButton("FAIL", 140, Color3.fromRGB(255, 165, 0))
    
    local function applyFilter(filterType)
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
