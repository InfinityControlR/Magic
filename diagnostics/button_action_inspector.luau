-- Magic Loot - button/action inspector
--
-- Observes GuiButton activations and correlates them with outgoing Roblox remotes.
-- It never activates a button and never sends a remote by itself.

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if PlayerGui == nil then
    warn("Magic Loot Button Inspector: PlayerGui was not found")
    return
end

local CONFIG = {
    MaxTimelineEntries = 100,
    MaxRenderedTimelineEntries = 30,
    MaxCorrelatedRemotes = 30,
    MaxReportCharacters = 120000,
    MaxArguments = 24,
    MaxArgumentDepth = 3,
    MaxArgumentNodes = 160,
    MaxArgumentCharacters = 6000,
    MaxFormattedValueLength = 4000,
    MaxTableItems = 24,
    MaxStringLength = 500,
    CorrelationSeconds = 2,
    MaxPendingRemoteRecords = 240,
    MaxRemoteRecordsPerHeartbeat = 80,
    RenderIntervalSeconds = 0.12,
}

local rootGui = Instance.new("ScreenGui")
rootGui.Name = "MagicLootButtonActionInspector_" .. tostring(math.random(100000, 999999))
rootGui.ResetOnSpawn = false
rootGui.IgnoreGuiInset = false
rootGui.DisplayOrder = 2147483000
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function chooseUiParent()
    local getHuiOk, hui = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if getHuiOk and typeof(hui) == "Instance" then
        local huiParentOk = pcall(function()
            rootGui.Parent = hui
        end)
        if huiParentOk then
            return nil
        end
    end

    local coreOk = pcall(function()
        rootGui.Parent = CoreGui
    end)
    if coreOk then
        return nil
    end

    return PlayerGui
end

local chosenParent = chooseUiParent()
if chosenParent ~= nil then
    rootGui.Parent = chosenParent
end

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(1, 0.5)
window.Position = UDim2.new(1, -18, 0.5, 0)
local expandedWindowSize = UDim2.new(0, 620, 0, 560)
local minimizedWindowSize = UDim2.new(0, 360, 0, 58)
window.Size = expandedWindowSize
window.BackgroundColor3 = Color3.fromRGB(17, 20, 28)
window.BorderSizePixel = 0
window.Parent = rootGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(300, 58)
sizeConstraint.MaxSize = Vector2.new(760, 700)
sizeConstraint.Parent = window

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 10)
windowCorner.Parent = window

local windowStroke = Instance.new("UIStroke")
windowStroke.Color = Color3.fromRGB(56, 65, 88)
windowStroke.Thickness = 1
windowStroke.Transparency = 0.15
windowStroke.Parent = window

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3 = Color3.fromRGB(25, 29, 40)
header.BorderSizePixel = 0
header.Parent = window

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.new(0, 14, 0, 7)
title.Size = UDim2.new(1, -340, 0, 22)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Magic Loot - Button/Action Inspector"
title.TextColor3 = Color3.fromRGB(238, 241, 248)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header
local expandedTitleSize = title.Size
local minimizedTitleSize = UDim2.new(1, -100, 0, 22)

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.new(0, 14, 0, 31)
subtitle.Size = UDim2.new(1, -340, 0, 17)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Pulsa el botón objetivo y después copia el informe"
subtitle.TextColor3 = Color3.fromRGB(151, 160, 181)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local copyButton = Instance.new("TextButton")
copyButton.Name = "Copy"
copyButton.AnchorPoint = Vector2.new(1, 0.5)
copyButton.Position = UDim2.new(1, -172, 0.5, 0)
copyButton.Size = UDim2.new(0, 104, 0, 32)
copyButton.BackgroundColor3 = Color3.fromRGB(37, 83, 112)
copyButton.BorderSizePixel = 0
copyButton.Font = Enum.Font.GothamSemibold
copyButton.Text = "Copiar"
copyButton.TextColor3 = Color3.fromRGB(205, 239, 255)
copyButton.TextSize = 11
copyButton.Parent = header

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 7)
copyCorner.Parent = copyButton

local clearButton = Instance.new("TextButton")
clearButton.Name = "Clear"
clearButton.AnchorPoint = Vector2.new(1, 0.5)
clearButton.Position = UDim2.new(1, -90, 0.5, 0)
clearButton.Size = UDim2.new(0, 70, 0, 32)
clearButton.BackgroundColor3 = Color3.fromRGB(59, 55, 75)
clearButton.BorderSizePixel = 0
clearButton.Font = Enum.Font.GothamSemibold
clearButton.Text = "Limpiar"
clearButton.TextColor3 = Color3.fromRGB(226, 221, 244)
clearButton.TextSize = 11
clearButton.Parent = header

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 7)
clearCorner.Parent = clearButton

local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "Minimize"
minimizeButton.AnchorPoint = Vector2.new(1, 0.5)
minimizeButton.Position = UDim2.new(1, -50, 0.5, 0)
minimizeButton.Size = UDim2.new(0, 32, 0, 32)
minimizeButton.BackgroundColor3 = Color3.fromRGB(45, 53, 72)
minimizeButton.BorderSizePixel = 0
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(207, 218, 242)
minimizeButton.TextSize = 16
minimizeButton.Parent = header

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 7)
minimizeCorner.Parent = minimizeButton

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -10, 0.5, 0)
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(73, 37, 44)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 196, 202)
closeButton.TextSize = 14
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Position = UDim2.new(0, 14, 0, 66)
statusLabel.Size = UDim2.new(1, -28, 0, 22)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.Text = "Preparando captura..."
statusLabel.TextColor3 = Color3.fromRGB(218, 222, 234)
statusLabel.TextSize = 11
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Parent = window

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Position = UDim2.new(0, 14, 0, 89)
hintLabel.Size = UDim2.new(1, -28, 0, 32)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.Text = "Arrastra la cabecera para moverlo; usa - para minimizar. No pulsa botones ni envía remotos."
hintLabel.TextColor3 = Color3.fromRGB(135, 145, 166)
hintLabel.TextSize = 10
hintLabel.TextWrapped = true
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextYAlignment = Enum.TextYAlignment.Top
hintLabel.Parent = window

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ReportScroll"
scroll.Position = UDim2.new(0, 12, 0, 126)
scroll.Size = UDim2.new(1, -24, 1, -138)
scroll.BackgroundColor3 = Color3.fromRGB(11, 14, 20)
scroll.BorderSizePixel = 0
scroll.Active = true
scroll.ScrollingEnabled = true
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 7
scroll.ScrollBarImageColor3 = Color3.fromRGB(88, 105, 143)
scroll.Parent = window

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 7)
scrollCorner.Parent = scroll

local reportText = Instance.new("TextLabel")
reportText.Name = "Report"
reportText.Position = UDim2.new(0, 10, 0, 8)
reportText.Size = UDim2.new(1, -20, 0, 40)
reportText.BackgroundTransparency = 1
reportText.Font = Enum.Font.Code
reportText.Text = "Esperando que pulses un botón del juego..."
reportText.TextColor3 = Color3.fromRGB(207, 214, 229)
reportText.TextSize = 12
reportText.TextWrapped = true
reportText.TextXAlignment = Enum.TextXAlignment.Left
reportText.TextYAlignment = Enum.TextYAlignment.Top
reportText.RichText = false
reportText.Parent = scroll

local alive = true
local closed = false
local startedAt = os.clock()
local sequence = 0
local attachedButtons = 0
local readErrors = 0
local timeline = {}
local globalConnections = {}
local buttonConnections = {}
local latestReport = ""
local latestButton = nil
local latestButtonRecord = nil
local correlatedRemotes = {}
local hookInstalled = false
local hookActive = false
local originalNamecall = nil
local hookFunction = nil
local hookInstaller = nil
local minimized = false
local renderScheduled = false
local lastRenderAt = 0
local pendingRemoteRecords = {}
local droppedRemoteRecords = 0

local function setWindowAbsolutePosition(topLeft)
    local camera = workspace.CurrentCamera
    if camera == nil then
        return
    end
    local viewport = camera.ViewportSize
    local size = window.AbsoluteSize
    local maximumX = math.max(0, viewport.X - size.X)
    local maximumY = math.max(0, viewport.Y - size.Y)
    local x = math.clamp(topLeft.X, 0, maximumX)
    local y = math.clamp(topLeft.Y, 0, maximumY)
    window.AnchorPoint = Vector2.new(0, 0)
    window.Position = UDim2.fromOffset(x, y)
end

local function cleanText(value, limit)
    local text = value == nil and "" or tostring(value)
    text = text:gsub("[%c]", " ")
    local maximum = limit or CONFIG.MaxStringLength
    if #text > maximum then
        return text:sub(1, maximum) .. "..."
    end
    return text
end

local function safeProperty(instance, property)
    local ok, value = pcall(function()
        return instance[property]
    end)
    if ok then
        return value
    end
    readErrors = readErrors + 1
    return nil
end

local function safeFullName(instance)
    local ok, value = pcall(function()
        return instance:GetFullName()
    end)
    if ok then
        return cleanText(value, 800)
    end
    readErrors = readErrors + 1
    return "<path unavailable>"
end

local function safeIsA(instance, className)
    local ok, result = pcall(function()
        return instance:IsA(className)
    end)
    return ok and result == true
end

local function formatValue(value, depth, activeTables, budget)
    budget = budget or { nodes = 0 }
    budget.nodes = budget.nodes + 1
    if budget.nodes > CONFIG.MaxArgumentNodes then
        return "<node limit>"
    end
    local valueType = typeof(value)
    if value == nil then
        return "nil"
    end
    if valueType == "string" then
        return string.format("%q", cleanText(value, CONFIG.MaxStringLength))
    end
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "Instance" then
        return string.format(
            "<%s %s>",
            cleanText(safeProperty(value, "ClassName"), 80),
            safeFullName(value)
        )
    end
    if valueType ~= "table" then
        return cleanText(tostring(value), CONFIG.MaxStringLength)
    end

    if depth >= CONFIG.MaxArgumentDepth then
        return "{<depth limit>}"
    end
    if activeTables[value] then
        return "{<cycle>}"
    end
    activeTables[value] = true

    local pieces = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > CONFIG.MaxTableItems then
            table.insert(pieces, "...")
            break
        end
        table.insert(
            pieces,
            "[" .. formatValue(key, depth + 1, activeTables, budget) .. "]="
                .. formatValue(item, depth + 1, activeTables, budget)
        )
    end
    activeTables[value] = nil
    return cleanText("{" .. table.concat(pieces, ", ") .. "}", CONFIG.MaxFormattedValueLength)
end

local function cloneValueForSnapshot(value, depth, activeTables, budget)
    budget.nodes = budget.nodes + 1
    if budget.nodes > CONFIG.MaxArgumentNodes then
        return "<node limit>"
    end
    if typeof(value) ~= "table" then
        return value
    end
    if depth >= CONFIG.MaxArgumentDepth then
        return "<depth limit>"
    end
    if activeTables[value] then
        return "<cycle>"
    end

    activeTables[value] = true
    local clone = {}
    local count = 0
    local key, item = next(value)
    while key ~= nil do
        count = count + 1
        if count > CONFIG.MaxTableItems then
            clone["<truncated>"] = true
            break
        end
        local clonedKey = cloneValueForSnapshot(key, depth + 1, activeTables, budget)
        local clonedItem = cloneValueForSnapshot(item, depth + 1, activeTables, budget)
        clone[clonedKey] = clonedItem
        key, item = next(value, key)
    end
    activeTables[value] = nil
    return clone
end

local function clonePackedArguments(packed)
    local clone = { n = packed.n }
    local budget = { nodes = 0 }
    local maximum = math.min(packed.n, CONFIG.MaxArguments)
    for index = 1, maximum do
        clone[index] = cloneValueForSnapshot(packed[index], 0, {}, budget)
    end
    return clone
end

local function snapshotPackedArguments(packed)
    local result = {}
    local budget = { nodes = 0 }
    local totalCharacters = 0
    local maximum = math.min(packed.n, CONFIG.MaxArguments)
    for index = 1, maximum do
        local formatted = formatValue(packed[index], 0, {}, budget)
        totalCharacters = totalCharacters + #formatted
        if totalCharacters > CONFIG.MaxArgumentCharacters then
            result[index] = "<character limit>"
            break
        end
        result[index] = formatted
    end
    if packed.n > maximum then
        result[maximum + 1] = string.format("<%d more arguments>", packed.n - maximum)
    end
    return result
end

local function sortedAttributes(instance)
    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)
    if not ok then
        readErrors = readErrors + 1
        return "<unavailable>"
    end

    local keys = {}
    for key in pairs(attributes) do
        table.insert(keys, tostring(key))
    end
    table.sort(keys)
    if #keys == 0 then
        return "<none>"
    end

    local parts = {}
    for _, key in ipairs(keys) do
        table.insert(parts, key .. "=" .. formatValue(attributes[key], 0, {}, { nodes = 0 }))
    end
    return table.concat(parts, "; ")
end

local function sortedTags(instance)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(instance)
    end)
    if not ok then
        readErrors = readErrors + 1
        return "<unavailable>"
    end
    table.sort(tags)
    if #tags == 0 then
        return "<none>"
    end
    return table.concat(tags, ", ")
end

local function siblingOrdinal(instance)
    local parent = safeProperty(instance, "Parent")
    if parent == nil then
        return 1
    end
    local ok, children = pcall(function()
        return parent:GetChildren()
    end)
    if not ok then
        readErrors = readErrors + 1
        return 1
    end

    local ordinal = 0
    for _, child in ipairs(children) do
        if child.Name == instance.Name and child.ClassName == instance.ClassName then
            ordinal = ordinal + 1
            if child == instance then
                return ordinal
            end
        end
    end
    return math.max(1, ordinal)
end

local function pathSegments(instance)
    local segments = {}
    local current = instance
    while current ~= nil and current ~= PlayerGui do
        table.insert(segments, 1, {
            name = cleanText(current.Name, 200),
            className = cleanText(current.ClassName, 100),
            ordinal = siblingOrdinal(current),
        })
        current = safeProperty(current, "Parent")
        if #segments >= 30 then
            break
        end
    end
    return segments
end

local function selectorSnippet(button)
    local segments = pathSegments(button)
    local lines = {
        "local Players = game:GetService(\"Players\")",
        "local node = Players.LocalPlayer:WaitForChild(\"PlayerGui\")",
        "local function childAt(parent, name, className, ordinal)",
        "    local seen = 0",
        "    for _, child in ipairs(parent:GetChildren()) do",
        "        if child.Name == name and child.ClassName == className then",
        "            seen = seen + 1",
        "            if seen == ordinal then return child end",
        "        end",
        "    end",
        "    return nil",
        "end",
    }

    for _, segment in ipairs(segments) do
        table.insert(
            lines,
            string.format(
                "node = assert(childAt(node, %q, %q, %d), %q)",
                segment.name,
                segment.className,
                segment.ordinal,
                "missing GUI segment: " .. segment.name
            )
        )
    end
    table.insert(lines, "local targetButton = node")
    table.insert(lines, "assert(targetButton:IsA(\"GuiButton\"), \"target is not a GuiButton\")")
    table.insert(lines, "print(targetButton:GetFullName())")
    return table.concat(lines, "\n")
end

local function addTimeline(entry)
    sequence = sequence + 1
    entry.sequence = sequence
    entry.clock = entry.clock or os.clock()
    table.insert(timeline, 1, entry)
    while #timeline > CONFIG.MaxTimelineEntries do
        table.remove(timeline)
    end
end

local function nearestButtonEntry(clockValue)
    local bestSequence = nil
    local bestDelta = nil
    for _, entry in ipairs(timeline) do
        if entry.kind == "BUTTON" then
            local delta = math.abs(clockValue - entry.clock)
            if delta <= CONFIG.CorrelationSeconds and (bestDelta == nil or delta < bestDelta) then
                bestSequence = entry.sequence
                bestDelta = delta
            end
        end
    end
    return bestSequence, bestDelta
end

local function describeAncestors(button)
    local parts = {}
    local current = button
    local depth = 0
    while current ~= nil and current ~= PlayerGui and depth < 14 do
        table.insert(
            parts,
            cleanText(safeProperty(current, "ClassName"), 80)
                .. ":" .. cleanText(safeProperty(current, "Name"), 160)
        )
        current = safeProperty(current, "Parent")
        depth = depth + 1
    end
    table.insert(parts, "PlayerGui")
    return table.concat(parts, " <- ")
end

local function considerCorrelatedRemote(entry)
    if latestButtonRecord == nil then
        return
    end
    local delta = math.abs(entry.clock - latestButtonRecord.clock)
    if delta > CONFIG.CorrelationSeconds then
        return
    end
    table.insert(correlatedRemotes, entry)
    table.sort(correlatedRemotes, function(first, second)
        local firstDelta = math.abs(first.clock - latestButtonRecord.clock)
        local secondDelta = math.abs(second.clock - latestButtonRecord.clock)
        if firstDelta == secondDelta then
            return first.sequence < second.sequence
        end
        return firstDelta < secondDelta
    end)
    while #correlatedRemotes > CONFIG.MaxCorrelatedRemotes do
        table.remove(correlatedRemotes)
    end
end

local function renderReport()
    if not alive or closed then
        return
    end

    local lines = {
        "MAGIC LOOT BUTTON/ACTION INSPECTOR",
        string.format(
            "elapsed=%.1fs | buttons=%d | events=%d | pending=%d | dropped=%d | errors=%d | remote-spy=%s",
            os.clock() - startedAt,
            attachedButtons,
            #timeline,
            #pendingRemoteRecords,
            droppedRemoteRecords,
            readErrors,
            hookInstalled and "ON" or "UNAVAILABLE"
        ),
        "",
        "Uso: pulsa una vez el botón de la room y espera 1-2 segundos.",
        "Después pulsa Copiar y pega aquí el informe completo.",
        "El inspector no ejecuta botones ni envía llamadas de red.",
        "",
    }
    local reportCharacters = #table.concat(lines, "\n")
    local reportTruncated = false

    local function addLine(value)
        if reportTruncated then
            return false
        end
        local line = value == nil and "" or tostring(value)
        if reportCharacters + #line + 1 > CONFIG.MaxReportCharacters then
            table.insert(lines, "... report truncated by safety limit ...")
            reportTruncated = true
            return false
        end
        table.insert(lines, line)
        reportCharacters = reportCharacters + #line + 1
        return true
    end

    local function addButtonDetails(entry)
        addLine(string.format("#%d BUTTON +%.3fs", entry.sequence, entry.clock - startedAt))
        addLine("  path: " .. entry.path)
        addLine("  class/name: " .. entry.className .. " / " .. entry.name)
        addLine("  text/image: " .. entry.content)
        addLine("  input: " .. entry.input .. " | clickCount=" .. entry.clickCount)
        addLine("  geometry: " .. entry.geometry)
        addLine("  state: " .. entry.state)
        addLine("  attributes: " .. entry.attributes)
        addLine("  tags: " .. entry.tags)
        addLine("  ancestry: " .. entry.ancestry)
    end

    local function addRemoteDetails(entry)
        local correlation = "none"
        local buttonSequence, buttonDelta = nearestButtonEntry(entry.clock)
        if latestButtonRecord ~= nil then
            local latestDelta = math.abs(entry.clock - latestButtonRecord.clock)
            if latestDelta <= CONFIG.CorrelationSeconds
                and (buttonDelta == nil or latestDelta < buttonDelta) then
                buttonSequence = latestButtonRecord.sequence
                buttonDelta = latestDelta
            end
        end
        if buttonSequence ~= nil then
            correlation = string.format("BUTTON #%d (delta %.3fs)", buttonSequence, buttonDelta)
        end
        addLine(string.format("#%d REMOTE +%.3fs", entry.sequence, entry.clock - startedAt))
        addLine("  method: " .. entry.method)
        addLine("  remote: " .. entry.className .. " " .. entry.path)
        addLine("  correlation: " .. correlation)
        for argumentIndex, argument in ipairs(entry.arguments) do
            if not addLine(string.format("  arg[%d]: %s", argumentIndex, argument)) then
                break
            end
        end
    end

    if latestButtonRecord ~= nil then
        addLine("LATEST TARGET BUTTON (preserved even if the live timeline fills):")
        addButtonDetails(latestButtonRecord)
        addLine("")
        addLine(string.format(
            "CLOSEST REMOTES WITHIN +/- %.1fs (%d):",
            CONFIG.CorrelationSeconds,
            #correlatedRemotes
        ))
        if #correlatedRemotes == 0 then
            addLine("  <none captured>")
        else
            for _, entry in ipairs(correlatedRemotes) do
                addRemoteDetails(entry)
                addLine("")
            end
        end
        addLine("RECENT TIMELINE:")
    end

    for index, entry in ipairs(timeline) do
        if index > CONFIG.MaxRenderedTimelineEntries or reportTruncated then
            break
        end
        if entry.kind == "BUTTON" then
            addButtonDetails(entry)
        elseif entry.kind == "REMOTE" then
            addRemoteDetails(entry)
        elseif entry.kind == "INFO" then
            addLine(string.format("#%d INFO %s", entry.sequence, entry.message))
        end
        addLine("")
    end

    if latestButton ~= nil then
        local selectorOk, selector = pcall(selectorSnippet, latestButton)
        if selectorOk then
            addLine("PASSIVE LOCATOR FOR LAST BUTTON (does not activate it):")
            addLine(selector)
            addLine("")
        end
    end

    latestReport = table.concat(lines, "\n")
    local oldCanvas = scroll.CanvasPosition
    reportText.Text = latestReport

    local width = math.max(300, scroll.AbsoluteSize.X - 28)
    local ok, measured = pcall(function()
        return TextService:GetTextSize(latestReport, reportText.TextSize, reportText.Font, Vector2.new(width, 100000))
    end)
    local contentHeight = 80
    if ok then
        contentHeight = math.max(80, measured.Y + 24)
    end
    reportText.Size = UDim2.new(1, -20, 0, contentHeight)
    scroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 18)
    local maximumY = math.max(0, contentHeight + 18 - scroll.AbsoluteSize.Y)
    scroll.CanvasPosition = Vector2.new(0, math.min(oldCanvas.Y, maximumY))

    statusLabel.Text = string.format(
        "Botones conectados: %d | Eventos: %d | Remotos: %s | Errores: %d",
        attachedButtons,
        #timeline,
        hookInstalled and "capturando" or "sin soporte del executor",
        readErrors
    )
end

local function scheduleRender()
    if minimized or not alive or closed then
        return
    end
    renderScheduled = true
end

local function recordButton(button, inputObject, clickCount)
    if not alive or closed then
        return
    end

    local content = ""
    if safeIsA(button, "TextButton") then
        content = cleanText(safeProperty(button, "Text"), 500)
    elseif safeIsA(button, "ImageButton") then
        content = cleanText(safeProperty(button, "Image"), 500)
    end

    local inputDescription = "<unknown>"
    if inputObject ~= nil then
        inputDescription = cleanText(safeProperty(inputObject, "UserInputType"), 100)
            .. " / " .. cleanText(safeProperty(inputObject, "KeyCode"), 100)
    end

    local absolutePosition = safeProperty(button, "AbsolutePosition")
    local absoluteSize = safeProperty(button, "AbsoluteSize")
    local geometry = "position=" .. cleanText(absolutePosition, 100)
        .. " size=" .. cleanText(absoluteSize, 100)

    local state = "Visible=" .. cleanText(safeProperty(button, "Visible"), 40)
        .. " Active=" .. cleanText(safeProperty(button, "Active"), 40)
        .. " Interactable=" .. cleanText(safeProperty(button, "Interactable"), 40)
        .. " ZIndex=" .. cleanText(safeProperty(button, "ZIndex"), 40)

    local buttonEntry = {
        kind = "BUTTON",
        clock = os.clock(),
        path = safeFullName(button),
        className = cleanText(safeProperty(button, "ClassName"), 100),
        name = cleanText(safeProperty(button, "Name"), 200),
        content = content,
        input = inputDescription,
        clickCount = cleanText(clickCount, 40),
        geometry = geometry,
        state = state,
        attributes = sortedAttributes(button),
        tags = sortedTags(button),
        ancestry = describeAncestors(button),
    }
    latestButton = button
    latestButtonRecord = buttonEntry
    correlatedRemotes = {}
    addTimeline(buttonEntry)
    for _, entry in ipairs(timeline) do
        if entry.kind == "REMOTE" then
            considerCorrelatedRemote(entry)
        end
    end
    if not minimized then
        scheduleRender()
    end
end

local recordRemote = nil

local function snapshotAndRecordRemote(method, remote, clonedArguments, capturedClock)
    if not alive or closed or not hookActive then
        return
    end
    local snapshotOk, arguments = pcall(snapshotPackedArguments, clonedArguments)
    if not snapshotOk then
        readErrors = readErrors + 1
        arguments = { "<argument snapshot failed>" }
    end
    recordRemote(method, remote, arguments, capturedClock)
end

recordRemote = function(method, remote, arguments, capturedClock)
    if not alive or closed or not hookActive then
        return
    end
    local remoteEntry = {
        kind = "REMOTE",
        clock = capturedClock,
        method = cleanText(method, 80),
        path = safeFullName(remote),
        className = cleanText(safeProperty(remote, "ClassName"), 100),
        arguments = arguments,
    }
    addTimeline(remoteEntry)
    considerCorrelatedRemote(remoteEntry)
    if not minimized then
        scheduleRender()
    end
end

local function enqueueRemoteCapture(method, remote, clonedArguments, capturedClock)
    if not alive or closed or not hookActive then
        return
    end
    while #pendingRemoteRecords >= CONFIG.MaxPendingRemoteRecords do
        table.remove(pendingRemoteRecords, 1)
        droppedRemoteRecords = droppedRemoteRecords + 1
    end
    table.insert(pendingRemoteRecords, {
        method = method,
        remote = remote,
        arguments = clonedArguments,
        clock = capturedClock,
    })
end

local function pumpInspector()
    if not alive or closed then
        return
    end

    local recordsToDrain = math.min(
        #pendingRemoteRecords,
        CONFIG.MaxRemoteRecordsPerHeartbeat
    )
    for _ = 1, recordsToDrain do
        local capture = table.remove(pendingRemoteRecords, 1)
        snapshotAndRecordRemote(
            capture.method,
            capture.remote,
            capture.arguments,
            capture.clock
        )
    end

    local now = os.clock()
    if renderScheduled and not minimized
        and now - lastRenderAt >= CONFIG.RenderIntervalSeconds then
        lastRenderAt = now
        renderScheduled = false
        renderReport()
    end
end

local function isOwnUi(instance)
    if instance == rootGui then
        return true
    end
    local ok, result = pcall(function()
        return instance:IsDescendantOf(rootGui)
    end)
    return ok and result == true
end

local function disconnectButton(button)
    local connection = buttonConnections[button]
    if connection == nil then
        return
    end
    pcall(function()
        connection:Disconnect()
    end)
    buttonConnections[button] = nil
    attachedButtons = math.max(0, attachedButtons - 1)
end

local function attachButton(candidate)
    if not alive or closed or buttonConnections[candidate] ~= nil or isOwnUi(candidate) then
        return
    end
    if not safeIsA(candidate, "GuiButton") then
        return
    end

    local ok, connection = pcall(function()
        return candidate.Activated:Connect(function(inputObject, clickCount)
            recordButton(candidate, inputObject, clickCount)
        end)
    end)
    if ok and connection ~= nil then
        buttonConnections[candidate] = connection
        attachedButtons = attachedButtons + 1
    else
        readErrors = readErrors + 1
    end
end

local function installRemoteObserver()
    local hookOk, hookValue = pcall(function()
        return hookmetamethod
    end)
    local methodOk, methodValue = pcall(function()
        return getnamecallmethod
    end)
    if not hookOk or type(hookValue) ~= "function"
        or not methodOk or type(methodValue) ~= "function" then
        return false
    end

    hookInstaller = hookValue
    local rawHandler = function(self, ...)
        if not hookActive then
            return originalNamecall(self, ...)
        end
        local methodOk, method = pcall(methodValue)
        if not methodOk then
            readErrors = readErrors + 1
            return originalNamecall(self, ...)
        end
        if method ~= "FireServer" and method ~= "InvokeServer" then
            return originalNamecall(self, ...)
        end
        if typeof(self) ~= "Instance" then
            return originalNamecall(self, ...)
        end
        local className = safeProperty(self, "ClassName")
        local validRemote = (method == "FireServer"
            and (className == "RemoteEvent" or className == "UnreliableRemoteEvent"))
            or (method == "InvokeServer" and className == "RemoteFunction")
        if not validRemote then
            return originalNamecall(self, ...)
        end

        local argumentsPacked = table.pack(...)
        local cloneOk, clonedArguments = pcall(clonePackedArguments, argumentsPacked)
        if not cloneOk then
            readErrors = readErrors + 1
            clonedArguments = table.pack("<argument clone failed>")
        end
        local enqueueOk = pcall(
            enqueueRemoteCapture,
            method,
            self,
            clonedArguments,
            os.clock()
        )
        if not enqueueOk then
            readErrors = readErrors + 1
        end
        return originalNamecall(self, ...)
    end

    local closureOk, closureFactory = pcall(function()
        return newcclosure
    end)
    if closureOk and type(closureFactory) == "function" then
        hookFunction = closureFactory(rawHandler)
    else
        hookFunction = rawHandler
    end

    local installOk, previous = pcall(hookInstaller, game, "__namecall", hookFunction)
    if not installOk or type(previous) ~= "function" then
        hookFunction = nil
        return false
    end
    originalNamecall = previous
    hookInstalled = true
    hookActive = true
    return true
end

local function getClipboardWriter()
    local firstOk, first = pcall(function()
        return setclipboard
    end)
    if firstOk and type(first) == "function" then
        return first
    end
    local secondOk, second = pcall(function()
        return toclipboard
    end)
    if secondOk and type(second) == "function" then
        return second
    end
    return nil
end

local function closeInspector()
    if closed then
        return
    end
    closed = true
    alive = false
    hookActive = false

    for _, connection in ipairs(globalConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    globalConnections = {}

    for button, connection in pairs(buttonConnections) do
        pcall(function()
            connection:Disconnect()
        end)
        buttonConnections[button] = nil
    end
    attachedButtons = 0

    if hookInstalled and hookInstaller ~= nil and originalNamecall ~= nil and hookFunction ~= nil then
        local ownsHook = false
        local getterOk, getter = pcall(function()
            return getrawmetatable
        end)
        if getterOk and type(getter) == "function" then
            local currentOk, currentHook = pcall(function()
                return getter(game).__namecall
            end)
            ownsHook = currentOk and currentHook == hookFunction
        end
        if ownsHook then
            pcall(hookInstaller, game, "__namecall", originalNamecall)
        end
    end
    hookInstalled = false
    pendingRemoteRecords = {}
    timeline = {}
    latestReport = ""
    latestButton = nil
    latestButtonRecord = nil
    correlatedRemotes = {}

    pcall(function()
        rootGui:Destroy()
    end)
end

table.insert(globalConnections, closeButton.Activated:Connect(closeInspector))

table.insert(globalConnections, minimizeButton.Activated:Connect(function()
    local currentTopLeft = window.AbsolutePosition
    minimized = not minimized
    if minimized then
        window.Size = minimizedWindowSize
        title.Size = minimizedTitleSize
        copyButton.Visible = false
        clearButton.Visible = false
        subtitle.Visible = false
        statusLabel.Visible = false
        hintLabel.Visible = false
        scroll.Visible = false
        minimizeButton.Text = "+"
    else
        window.Size = expandedWindowSize
        title.Size = expandedTitleSize
        copyButton.Visible = true
        clearButton.Visible = true
        subtitle.Visible = true
        statusLabel.Visible = true
        hintLabel.Visible = true
        scroll.Visible = true
        minimizeButton.Text = "-"
        scheduleRender()
    end
    task.defer(function()
        if alive and not closed then
            setWindowAbsolutePosition(currentTopLeft)
        end
    end)
end))

table.insert(globalConnections, clearButton.Activated:Connect(function()
    pendingRemoteRecords = {}
    droppedRemoteRecords = 0
    timeline = {}
    latestButton = nil
    latestButtonRecord = nil
    correlatedRemotes = {}
    latestReport = ""
    renderScheduled = false
    scheduleRender()
end))

table.insert(globalConnections, copyButton.Activated:Connect(function()
    local writer = getClipboardWriter()
    if writer == nil then
        copyButton.Text = "Sin soporte"
        copyButton.BackgroundColor3 = Color3.fromRGB(83, 44, 51)
    else
        local copied = pcall(writer, latestReport ~= "" and latestReport or reportText.Text)
        if copied then
            copyButton.Text = "Copiado"
            copyButton.BackgroundColor3 = Color3.fromRGB(34, 91, 62)
        else
            copyButton.Text = "Error"
            copyButton.BackgroundColor3 = Color3.fromRGB(83, 44, 51)
        end
    end
    task.delay(1.5, function()
        if alive and not closed then
            copyButton.Text = "Copiar"
            copyButton.BackgroundColor3 = Color3.fromRGB(37, 83, 112)
        end
    end)
end))

local dragging = false
local dragStart = nil
local startAbsolutePosition = nil

table.insert(globalConnections, header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startAbsolutePosition = window.AbsolutePosition
    end
end))

table.insert(globalConnections, UserInputService.InputChanged:Connect(function(input)
    if not dragging or dragStart == nil or startAbsolutePosition == nil then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        setWindowAbsolutePosition(startAbsolutePosition + Vector2.new(delta.X, delta.Y))
    end
end))

table.insert(globalConnections, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        dragStart = nil
        startAbsolutePosition = nil
    end
end))

table.insert(globalConnections, PlayerGui.DescendantAdded:Connect(function(descendant)
    attachButton(descendant)
end))

table.insert(globalConnections, PlayerGui.DescendantRemoving:Connect(function(descendant)
    disconnectButton(descendant)
end))

-- The __namecall hook can run with a restricted executor capability context.
-- Keep all popup Instance access in this top-level signal connection instead.
table.insert(globalConnections, RunService.Heartbeat:Connect(function()
    local pumpOk = pcall(pumpInspector)
    if not pumpOk then
        readErrors = readErrors + 1
        renderScheduled = false
    end
end))

local descendantsOk, descendants = pcall(function()
    return PlayerGui:GetDescendants()
end)
if descendantsOk then
    for _, descendant in ipairs(descendants) do
        attachButton(descendant)
    end
else
    readErrors = readErrors + 1
end

if installRemoteObserver() then
    addTimeline({
        kind = "INFO",
        message = "Remote correlation enabled (FireServer/InvokeServer observation only)",
    })
else
    addTimeline({
        kind = "INFO",
        message = "Remote correlation unavailable; button detection still works",
    })
end

local initialRenderOk = pcall(renderReport)
if not initialRenderOk then
    readErrors = readErrors + 1
end
