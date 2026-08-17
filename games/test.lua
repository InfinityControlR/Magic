-- Magic Loot - live drop inspector
--
-- This diagnostic reads the client-side drop hierarchy and shows it in its
-- own ScreenGui. It never activates a prompt, calls a remote, attacks, moves
-- the player or writes to any object belonging to the game.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local INSPECTOR_VERSION = "2.3-copy"

local CONFIG = {
    RefreshSeconds = 0.25,
    MaxDropModels = 25,
    MaxOtherModelNames = 20,
    MaxDirectChildren = 80,
    MaxFallbackInstances = 180,
    MaxRecentChanges = 60,
    MaxDescendantsPerDrop = 70,
    MaxAttributesPerInstance = 30,
    MaxErrorsPerScan = 25,
    MaxDisplayCharacters = 70000,
    MaxFieldCharacters = 180,
    ReferenceRange = 150,
}

local localPlayer = Players.LocalPlayer
local playerGui = nil

if localPlayer ~= nil then
    local ok, result = pcall(function()
        return localPlayer:WaitForChild("PlayerGui", 8)
    end)

    if ok then
        playerGui = result
    end
end

if playerGui == nil then
    warn("[Magic Loot Drop Inspector] PlayerGui is unavailable.")
    return
end

-- Everything created below this point is UI owned by this inspector.
local rootGui = Instance.new("ScreenGui")
rootGui.Name = "MagicLootDropInspector_" .. tostring(math.floor(os.clock() * 1000))
rootGui.ResetOnSpawn = false
rootGui.IgnoreGuiInset = false
rootGui.DisplayOrder = 1000000
rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
rootGui.Parent = playerGui

local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.new(0.5, 0, 0.5, 0)
window.Size = UDim2.new(0.82, 0, 0.80, 0)
window.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Parent = rootGui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(560, 360)
sizeConstraint.MaxSize = Vector2.new(1050, 740)
sizeConstraint.Parent = window

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 10)
windowCorner.Parent = window

local windowStroke = Instance.new("UIStroke")
windowStroke.Color = Color3.fromRGB(70, 78, 99)
windowStroke.Thickness = 1
windowStroke.Transparency = 0.15
windowStroke.Parent = window

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 54)
header.BackgroundColor3 = Color3.fromRGB(25, 29, 40)
header.BorderSizePixel = 0
header.Parent = window

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.new(0, 16, 0, 7)
title.Size = UDim2.new(1, -380, 0, 22)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Magic Loot - Drop Inspector v" .. INSPECTOR_VERSION
title.TextColor3 = Color3.fromRGB(238, 241, 248)
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.new(0, 16, 0, 29)
subtitle.Size = UDim2.new(1, -380, 0, 17)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Solo lectura - no activa drops, prompts ni remotos"
subtitle.TextColor3 = Color3.fromRGB(151, 160, 181)
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local livePill = Instance.new("TextLabel")
livePill.Name = "LiveState"
livePill.AnchorPoint = Vector2.new(1, 0.5)
livePill.Position = UDim2.new(1, -58, 0.5, 0)
livePill.Size = UDim2.new(0, 78, 0, 26)
livePill.BackgroundColor3 = Color3.fromRGB(31, 92, 64)
livePill.BorderSizePixel = 0
livePill.Font = Enum.Font.GothamBold
livePill.Text = "LIVE"
livePill.TextColor3 = Color3.fromRGB(183, 255, 214)
livePill.TextSize = 12
livePill.Parent = header

local liveCorner = Instance.new("UICorner")
liveCorner.CornerRadius = UDim.new(1, 0)
liveCorner.Parent = livePill

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -12, 0.5, 0)
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(73, 37, 44)
closeButton.BorderSizePixel = 0
closeButton.AutoButtonColor = true
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 196, 202)
closeButton.TextSize = 15
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 7)
closeCorner.Parent = closeButton

local toolbar = Instance.new("Frame")
toolbar.Name = "Toolbar"
toolbar.Position = UDim2.new(0, 0, 0, 54)
toolbar.Size = UDim2.new(1, 0, 0, 66)
toolbar.BackgroundColor3 = Color3.fromRGB(21, 24, 33)
toolbar.BorderSizePixel = 0
toolbar.Parent = window

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Position = UDim2.new(0, 16, 0, 8)
statusLabel.Size = UDim2.new(1, -244, 0, 24)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.Text = "Buscando Workspace.DropsClient..."
statusLabel.TextColor3 = Color3.fromRGB(215, 219, 231)
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Parent = toolbar

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Position = UDim2.new(0, 16, 0, 34)
hintLabel.Size = UDim2.new(1, -32, 0, 20)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.Text = "Déjalo abierto cuando caiga loot. Pulsa Pausar para leer o hacer una captura."
hintLabel.TextColor3 = Color3.fromRGB(132, 142, 164)
hintLabel.TextSize = 11
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextTruncate = Enum.TextTruncate.AtEnd
hintLabel.Parent = toolbar

local refreshButton = Instance.new("TextButton")
refreshButton.Name = "Refresh"
refreshButton.AnchorPoint = Vector2.new(1, 0)
refreshButton.Position = UDim2.new(1, -12, 0, 8)
refreshButton.Size = UDim2.new(0, 100, 0, 26)
refreshButton.BackgroundColor3 = Color3.fromRGB(45, 54, 76)
refreshButton.BorderSizePixel = 0
refreshButton.AutoButtonColor = true
refreshButton.Font = Enum.Font.GothamSemibold
refreshButton.Text = "Actualizar"
refreshButton.TextColor3 = Color3.fromRGB(222, 229, 247)
refreshButton.TextSize = 11
refreshButton.Parent = toolbar

local refreshCorner = Instance.new("UICorner")
refreshCorner.CornerRadius = UDim.new(0, 6)
refreshCorner.Parent = refreshButton

local pauseButton = Instance.new("TextButton")
pauseButton.Name = "Pause"
pauseButton.AnchorPoint = Vector2.new(1, 0)
pauseButton.Position = UDim2.new(1, -120, 0, 8)
pauseButton.Size = UDim2.new(0, 88, 0, 26)
pauseButton.BackgroundColor3 = Color3.fromRGB(67, 53, 34)
pauseButton.BorderSizePixel = 0
pauseButton.AutoButtonColor = true
pauseButton.Font = Enum.Font.GothamSemibold
pauseButton.Text = "Pausar"
pauseButton.TextColor3 = Color3.fromRGB(250, 221, 166)
pauseButton.TextSize = 11
pauseButton.Parent = toolbar

local pauseCorner = Instance.new("UICorner")
pauseCorner.CornerRadius = UDim.new(0, 6)
pauseCorner.Parent = pauseButton

local copyButton = Instance.new("TextButton")
copyButton.Name = "CopyReport"
copyButton.AnchorPoint = Vector2.new(1, 0.5)
copyButton.Position = UDim2.new(1, -148, 0.5, 0)
copyButton.Size = UDim2.new(0, 120, 0, 34)
copyButton.BackgroundColor3 = Color3.fromRGB(37, 83, 112)
copyButton.BorderSizePixel = 0
copyButton.AutoButtonColor = true
copyButton.Font = Enum.Font.GothamSemibold
copyButton.Text = "Copiar informe"
copyButton.TextColor3 = Color3.fromRGB(205, 239, 255)
copyButton.TextSize = 11
copyButton.ZIndex = 5
copyButton.Parent = header

local copyCorner = Instance.new("UICorner")
copyCorner.CornerRadius = UDim.new(0, 6)
copyCorner.Parent = copyButton

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "ReportScroll"
scroll.Position = UDim2.new(0, 10, 0, 130)
scroll.Size = UDim2.new(1, -20, 1, -166)
scroll.BackgroundColor3 = Color3.fromRGB(13, 16, 22)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 7
scroll.ScrollBarImageColor3 = Color3.fromRGB(88, 101, 134)
scroll.Active = true
scroll.ScrollingEnabled = true
scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.Parent = window

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 7)
scrollCorner.Parent = scroll

local reportText = Instance.new("TextLabel")
reportText.Name = "Report"
reportText.Position = UDim2.new(0, 11, 0, 9)
reportText.Size = UDim2.new(1, -22, 0, 30)
reportText.AutomaticSize = Enum.AutomaticSize.None
reportText.BackgroundTransparency = 1
reportText.Font = Enum.Font.Code
reportText.Text = "Esperando el primer escaneo..."
reportText.TextColor3 = Color3.fromRGB(207, 214, 229)
reportText.TextSize = 13
reportText.TextWrapped = true
reportText.TextXAlignment = Enum.TextXAlignment.Left
reportText.TextYAlignment = Enum.TextYAlignment.Top
reportText.RichText = false
reportText.Parent = scroll

local footer = Instance.new("TextLabel")
footer.Name = "Footer"
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 14, 1, -5)
footer.Size = UDim2.new(1, -28, 0, 23)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.Text = "La X detiene el escaneo y elimina únicamente este popup."
footer.TextColor3 = Color3.fromRGB(112, 122, 143)
footer.TextSize = 10
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = window

local alive = true
local closed = false
local paused = false
local refreshRequested = true
local scanNumber = 0
local connections = {}
local lastReportText = ""
local clipboardChecked = false
local clipboardWriter = nil
local instanceIds = setmetatable({}, { __mode = "k" })
local nextInstanceId = 1
local previousInventory = nil
local recentChanges = {}

local function cleanText(value, maximum)
    local ok, result = pcall(tostring, value)
    local text = ok and result or "<tostring error>"
    text = string.gsub(text, "\r", "\\r")
    text = string.gsub(text, "\n", "\\n")
    text = string.gsub(text, "\t", "\\t")
    text = string.gsub(text, "%c", "?")

    local limit = maximum or CONFIG.MaxFieldCharacters
    if #text > limit then
        return string.sub(text, 1, limit) .. "...<truncated>"
    end

    return text
end

local function getClipboardWriter()
    if clipboardChecked then
        return clipboardWriter
    end

    clipboardChecked = true
    pcall(function()
        if type(setclipboard) == "function" then
            clipboardWriter = setclipboard
        elseif type(toclipboard) == "function" then
            clipboardWriter = toclipboard
        end
    end)

    return clipboardWriter
end

local function instanceId(instance)
    local current = instanceIds[instance]
    if current ~= nil then
        return current
    end

    current = nextInstanceId
    nextInstanceId = nextInstanceId + 1
    instanceIds[instance] = current
    return current
end

local function addError(errors, context, err)
    if #errors >= CONFIG.MaxErrorsPerScan then
        return
    end

    table.insert(errors, cleanText(context, 100) .. ": " .. cleanText(err, 220))
end

local function safeProperty(errors, instance, propertyName)
    local ok, result = pcall(function()
        return instance[propertyName]
    end)

    if not ok then
        addError(errors, propertyName, result)
        return false, nil
    end

    return true, result
end

local function safeIsA(instance, className)
    local ok, result = pcall(function()
        return instance:IsA(className)
    end)

    return ok and result == true
end

local function safePath(instance)
    local ok, result = pcall(function()
        return instance:GetFullName()
    end)

    if ok then
        return cleanText(result, 260)
    end

    return "<path unavailable>"
end

local function safeDescendants(errors, instance)
    local ok, result = pcall(function()
        return instance:GetDescendants()
    end)

    if ok then
        return result
    end

    addError(errors, "GetDescendants " .. safePath(instance), result)
    return {}
end

local function safeChildren(errors, instance)
    local ok, result = pcall(function()
        return instance:GetChildren()
    end)

    if ok then
        return result
    end

    addError(errors, "GetChildren " .. safePath(instance), result)
    return {}
end

local function safeAttribute(errors, instance, attributeName)
    local ok, result = pcall(function()
        return instance:GetAttribute(attributeName)
    end)

    if ok then
        return result
    end

    addError(errors, "GetAttribute " .. attributeName, result)
    return nil
end

local function finiteNumber(value)
    local ok, result = pcall(tonumber, value)
    if not ok or result == nil then
        return nil
    end

    if result ~= result or result == math.huge or result == -math.huge then
        return nil
    end

    return result
end

local function numberText(number)
    if number == nil then
        return "<nil>"
    end

    return string.format("%.3f", number)
end

local function valueText(value)
    local kind = typeof(value)

    if kind == "nil" then
        return "<nil>"
    elseif kind == "string" then
        return "\"" .. cleanText(value) .. "\" <string>"
    elseif kind == "number" then
        return cleanText(value) .. " <number>"
    elseif kind == "boolean" then
        return tostring(value) .. " <boolean>"
    elseif kind == "Vector3" then
        return string.format(
            "(%.3f, %.3f, %.3f) <Vector3>",
            value.X,
            value.Y,
            value.Z
        )
    elseif kind == "Vector2" then
        return string.format("(%.3f, %.3f) <Vector2>", value.X, value.Y)
    elseif kind == "CFrame" then
        return string.format(
            "CFrame position=(%.3f, %.3f, %.3f)",
            value.Position.X,
            value.Position.Y,
            value.Position.Z
        )
    elseif kind == "Color3" then
        return string.format(
            "Color3(%.3f, %.3f, %.3f)",
            value.R,
            value.G,
            value.B
        )
    elseif kind == "Instance" then
        local classOk, className = pcall(function()
            return value.ClassName
        end)
        return string.format(
            "[%s] %s",
            classOk and cleanText(className, 60) or "Instance",
            safePath(value)
        )
    end

    return cleanText(value) .. " <" .. cleanText(kind, 60) .. ">"
end

local function attributesText(errors, instance)
    local ok, attributes = pcall(function()
        return instance:GetAttributes()
    end)

    if not ok then
        addError(errors, "GetAttributes " .. safePath(instance), attributes)
        return "<attributes unavailable>"
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
    local maximum = math.min(#keys, CONFIG.MaxAttributesPerInstance)
    for index = 1, maximum do
        local key = keys[index]
        table.insert(parts, cleanText(key, 80) .. "=" .. valueText(attributes[key]))
    end

    if #keys > maximum then
        table.insert(parts, "...+" .. tostring(#keys - maximum) .. " attributes")
    end

    return table.concat(parts, "; ")
end

local function tagsText(errors, instance)
    local ok, tags = pcall(function()
        return CollectionService:GetTags(instance)
    end)

    if not ok then
        addError(errors, "GetTags " .. safePath(instance), tags)
        return "<tags unavailable>"
    end

    table.sort(tags)
    if #tags == 0 then
        return "<none>"
    end

    local cleanTags = {}
    for _, tag in ipairs(tags) do
        table.insert(cleanTags, cleanText(tag, 80))
    end
    return table.concat(cleanTags, ", ")
end

local function sortedInstances(instances)
    local result = {}
    for _, instance in ipairs(instances) do
        table.insert(result, instance)
    end

    table.sort(result, function(left, right)
        return safePath(left) < safePath(right)
    end)
    return result
end

local function playerRoot(errors)
    local character = localPlayer and localPlayer.Character or nil
    if character == nil then
        return nil
    end

    local ok, root = pcall(function()
        return character:FindFirstChild("HumanoidRootPart")
    end)

    if not ok then
        addError(errors, "Find player HumanoidRootPart", root)
        return nil
    end

    if root ~= nil and safeIsA(root, "BasePart") then
        return root
    end

    return nil
end

local function passText(value)
    if value == nil then
        return "[?]"
    elseif value then
        return "[OK]"
    end

    return "[NO]"
end

local function appendInstanceDetails(addLine, errors, instance, prefix)
    local nameOk, name = safeProperty(errors, instance, "Name")
    local classOk, className = safeProperty(errors, instance, "ClassName")
    local displayName = nameOk and cleanText(name, 100) or "<name unavailable>"
    local displayClass = classOk and cleanText(className, 70) or "<class unavailable>"

    addLine(prefix .. "[" .. displayClass .. "] " .. displayName)
    addLine(prefix .. "  path: " .. safePath(instance))
    addLine(prefix .. "  attributes: " .. attributesText(errors, instance))

    local tags = tagsText(errors, instance)
    if tags ~= "<none>" then
        addLine(prefix .. "  tags: " .. tags)
    end

    if safeIsA(instance, "BasePart") then
        local positionOk, position = safeProperty(errors, instance, "Position")
        local sizeOk, size = safeProperty(errors, instance, "Size")
        if positionOk then
            addLine(prefix .. "  position: " .. valueText(position))
        end
        if sizeOk then
            addLine(prefix .. "  size: " .. valueText(size))
        end
    elseif safeIsA(instance, "Attachment") then
        local positionOk, position = safeProperty(errors, instance, "WorldPosition")
        if positionOk then
            addLine(prefix .. "  worldPosition: " .. valueText(position))
        end
    elseif safeIsA(instance, "ValueBase") then
        local valueOk, value = safeProperty(errors, instance, "Value")
        if valueOk then
            addLine(prefix .. "  value: " .. valueText(value))
        end
    end

    if safeIsA(instance, "Model") then
        local primaryOk, primaryPart = safeProperty(errors, instance, "PrimaryPart")
        if primaryOk then
            addLine(prefix .. "  PrimaryPart: " .. valueText(primaryPart))
        end
    end

    if safeIsA(instance, "TextLabel")
        or safeIsA(instance, "TextButton")
        or safeIsA(instance, "TextBox") then
        local textOk, textValue = safeProperty(errors, instance, "Text")
        local visibleOk, visible = safeProperty(errors, instance, "Visible")
        if textOk then
            addLine(prefix .. "  Text: " .. valueText(textValue))
        end
        if visibleOk then
            addLine(prefix .. "  Visible: " .. valueText(visible))
        end
    elseif safeIsA(instance, "ImageLabel") or safeIsA(instance, "ImageButton") then
        local imageOk, imageValue = safeProperty(errors, instance, "Image")
        local visibleOk, visible = safeProperty(errors, instance, "Visible")
        if imageOk then
            addLine(prefix .. "  Image: " .. valueText(imageValue))
        end
        if visibleOk then
            addLine(prefix .. "  Visible: " .. valueText(visible))
        end
    elseif safeIsA(instance, "BillboardGui") then
        local adorneeOk, adornee = safeProperty(errors, instance, "Adornee")
        local enabledOk, enabled = safeProperty(errors, instance, "Enabled")
        if adorneeOk then
            addLine(prefix .. "  Adornee: " .. valueText(adornee))
        end
        if enabledOk then
            addLine(prefix .. "  Enabled: " .. valueText(enabled))
        end
    elseif safeIsA(instance, "Highlight") then
        local adorneeOk, adornee = safeProperty(errors, instance, "Adornee")
        local enabledOk, enabled = safeProperty(errors, instance, "Enabled")
        if adorneeOk then
            addLine(prefix .. "  Adornee: " .. valueText(adornee))
        end
        if enabledOk then
            addLine(prefix .. "  Enabled: " .. valueText(enabled))
        end
    end

    if safeIsA(instance, "ProximityPrompt") then
        local properties = {
            "Enabled",
            "ActionText",
            "ObjectText",
            "HoldDuration",
            "MaxActivationDistance",
            "RequiresLineOfSight",
            "ClickablePrompt",
        }

        for _, propertyName in ipairs(properties) do
            local propertyOk, propertyValue = safeProperty(errors, instance, propertyName)
            if propertyOk then
                addLine(prefix .. "  " .. propertyName .. ": " .. valueText(propertyValue))
            end
        end
    end
end

local function inventoryDescriptor(errors, instance)
    local nameOk, name = safeProperty(errors, instance, "Name")
    local classOk, className = safeProperty(errors, instance, "ClassName")

    return string.format(
        "#%d [%s] %s | %s",
        instanceId(instance),
        classOk and cleanText(className, 70) or "<class unavailable>",
        nameOk and cleanText(name, 100) or "<name unavailable>",
        safePath(instance)
    )
end

local function updateRecentChanges(errors, descendants)
    local currentInventory = {}
    local addedSet = {}
    local additions = 0
    local removals = 0

    for _, instance in ipairs(descendants) do
        currentInventory[instance] = inventoryDescriptor(errors, instance)
    end

    if previousInventory ~= nil then
        for instance, descriptor in pairs(currentInventory) do
            if previousInventory[instance] == nil then
                additions = additions + 1
                addedSet[instance] = true
                table.insert(recentChanges, 1, string.format(
                    "scan %d  + ADDED  %s",
                    scanNumber,
                    descriptor
                ))
            end
        end

        for instance, descriptor in pairs(previousInventory) do
            if currentInventory[instance] == nil then
                removals = removals + 1
                table.insert(recentChanges, 1, string.format(
                    "scan %d  - REMOVED  %s",
                    scanNumber,
                    descriptor
                ))
            end
        end
    end

    while #recentChanges > CONFIG.MaxRecentChanges do
        table.remove(recentChanges)
    end

    previousInventory = currentInventory
    return additions, removals, addedSet
end

local function directBranchFor(errors, container, instance)
    local current = instance
    local steps = 0

    while current ~= nil and steps < 64 do
        local parentOk, parent = safeProperty(errors, current, "Parent")
        if not parentOk or parent == nil then
            return nil
        end
        if parent == container then
            return current
        end
        if parent == current then
            return nil
        end

        current = parent
        steps = steps + 1
    end

    return nil
end

local function fallbackRecord(errors, container, instance, root, directSet, addedSet)
    local nameOk, name = safeProperty(errors, instance, "Name")
    local classOk, className = safeProperty(errors, instance, "ClassName")
    local normalizedName = nameOk and tostring(name) or "<unknown>"
    local normalizedClass = classOk and tostring(className) or "<unknown>"
    local lowerName = string.lower(normalizedName)
    local keyword = string.find(lowerName, "drop", 1, true)
        or string.find(lowerName, "loot", 1, true)
        or string.find(lowerName, "item", 1, true)
        or string.find(lowerName, "pickup", 1, true)
        or string.find(lowerName, "material", 1, true)
        or string.find(lowerName, "reward", 1, true)
        or string.find(lowerName, "gold", 1, true)

    local attributes = {}
    local attributesOk, attributesResult = pcall(function()
        return instance:GetAttributes()
    end)
    if attributesOk then
        attributes = attributesResult
    else
        addError(errors, "GetAttributes " .. safePath(instance), attributesResult)
    end

    local attributeCount = 0
    for _ in pairs(attributes) do
        attributeCount = attributeCount + 1
    end

    local hasLegacyAttribute = attributes.DropLanded ~= nil
        or attributes.GoldValue ~= nil
        or attributes.Xyd ~= nil

    local parentNameNumber = nil
    local parentOk, parent = safeProperty(errors, instance, "Parent")
    if parentOk and parent ~= nil then
        local parentNameOk, parentName = safeProperty(errors, parent, "Name")
        if parentNameOk then
            parentNameNumber = finiteNumber(parentName)
        end
    end

    local isPrompt = safeIsA(instance, "ProximityPrompt")
    local isDetector = safeIsA(instance, "ClickDetector")
    local isValue = safeIsA(instance, "ValueBase")
    local isModel = safeIsA(instance, "Model")
    local isPart = safeIsA(instance, "BasePart")
    local isVisualMarker = safeIsA(instance, "BillboardGui")
        or safeIsA(instance, "ImageLabel")
        or safeIsA(instance, "Highlight")
    local isDirect = directSet[instance] == true
    local isAdded = addedSet[instance] == true
    local score = 0

    if isAdded then
        score = score + 200
    end
    if attributeCount > 0 then
        score = score + 100 + math.min(attributeCount, 20)
    end
    if hasLegacyAttribute then
        score = score + 250
    end
    if isPrompt then
        score = score + 90
    end
    if isDetector then
        score = score + 80
    end
    if keyword ~= nil then
        score = score + 70
    end
    if parentNameNumber ~= nil then
        score = score + 60
    end
    if isVisualMarker then
        score = score + 45
    end
    if isValue then
        score = score + 35
    end
    if isDirect then
        score = score + 30
    end
    if isModel then
        score = score + 20
    end
    if isPart then
        score = score + 10
    end

    local reasons = {}
    if isAdded then
        table.insert(reasons, "NEW")
    end
    if isDirect then
        table.insert(reasons, "direct-child")
    end
    if attributeCount > 0 then
        table.insert(reasons, "attributes=" .. tostring(attributeCount))
    end
    if hasLegacyAttribute then
        table.insert(reasons, "legacy-drop-attribute")
    end
    if keyword ~= nil then
        table.insert(reasons, "name-keyword")
    end
    if parentNameNumber ~= nil then
        table.insert(reasons, "numeric-parent")
    end
    if isVisualMarker then
        table.insert(reasons, "visual-marker")
    end
    if isPrompt then
        table.insert(reasons, "ProximityPrompt")
    end
    if isDetector then
        table.insert(reasons, "ClickDetector")
    end
    if isValue then
        table.insert(reasons, "ValueBase")
    end
    if isModel then
        table.insert(reasons, "Model")
    end
    if isPart then
        table.insert(reasons, "BasePart")
    end

    local distance = nil
    if root ~= nil and isPart then
        local distanceOk, distanceResult = pcall(function()
            return (instance.Position - root.Position).Magnitude
        end)
        if distanceOk then
            distance = distanceResult
        else
            addError(errors, "Fallback distance " .. safePath(instance), distanceResult)
        end
    end

    return {
        instance = instance,
        branch = directBranchFor(errors, container, instance),
        name = normalizedName,
        className = normalizedClass,
        path = safePath(instance),
        score = score,
        reasons = reasons,
        distance = distance,
        attributeCount = attributeCount,
        isSignal = isAdded
            or attributeCount > 0
            or keyword ~= nil
            or parentNameNumber ~= nil
            or isVisualMarker
            or isPrompt
            or isDetector
            or isValue,
    }
end

local function appendFallbackInventory(
    addLine,
    errors,
    container,
    descendants,
    root,
    additions,
    removals,
    addedSet
)
    addLine("")
    addLine(string.rep("!", 72))
    addLine("LEGACY SCHEMA MISMATCH: no Model named DropItem exists.")
    addLine("The inventory below makes no assumption about the current loot class or name.")
    addLine(string.format(
        "Component changes this scan: +%d added / -%d removed (baseline is not reported).",
        additions,
        removals
    ))

    addLine("")
    addLine("Recent component changes observed inside DropsClient:")
    if #recentChanges == 0 then
        addLine("  <none since this inspector established its baseline>")
    else
        for _, change in ipairs(recentChanges) do
            addLine("  " .. change)
        end
    end

    local directChildren = sortedInstances(safeChildren(errors, container))
    local directSet = {}
    for _, child in ipairs(directChildren) do
        directSet[child] = true
    end

    addLine("")
    addLine(string.format(
        "Direct children of DropsClient: showing %d/%d",
        math.min(#directChildren, CONFIG.MaxDirectChildren),
        #directChildren
    ))
    local maximumDirect = math.min(#directChildren, CONFIG.MaxDirectChildren)
    for index = 1, maximumDirect do
        local child = directChildren[index]
        local branchDescendants = safeDescendants(errors, child)
        addLine(string.format(
            "  BRANCH %d | descendants=%d | %s",
            index,
            #branchDescendants,
            inventoryDescriptor(errors, child)
        ))
        addLine("    attributes: " .. attributesText(errors, child))
        local tags = tagsText(errors, child)
        if tags ~= "<none>" then
            addLine("    tags: " .. tags)
        end
    end
    if #directChildren > maximumDirect then
        addLine("  ...+" .. tostring(#directChildren - maximumDirect) .. " direct children")
    end

    local records = {}
    local signalCount = 0
    for _, instance in ipairs(descendants) do
        local record = fallbackRecord(
            errors,
            container,
            instance,
            root,
            directSet,
            addedSet
        )
        table.insert(records, record)
        if record.isSignal then
            signalCount = signalCount + 1
        end
    end

    table.sort(records, function(left, right)
        if left.score == right.score then
            return left.path < right.path
        end
        return left.score > right.score
    end)

    local branchStatsByInstance = {}
    for _, record in ipairs(records) do
        local branch = record.branch
        if branch ~= nil then
            local stats = branchStatsByInstance[branch]
            if stats == nil then
                stats = {
                    branch = branch,
                    componentCount = 0,
                    signalCount = 0,
                    newComponentCount = 0,
                    maxComponentScore = 0,
                }
                branchStatsByInstance[branch] = stats
            end

            stats.componentCount = stats.componentCount + 1
            if record.isSignal then
                stats.signalCount = stats.signalCount + 1
            end
            if addedSet[record.instance] == true then
                stats.newComponentCount = stats.newComponentCount + 1
            end
            stats.maxComponentScore = math.max(stats.maxComponentScore, record.score)
        end
    end

    local branchStats = {}
    local candidateBranchCount = 0
    for _, stats in pairs(branchStatsByInstance) do
        table.insert(branchStats, stats)
        if stats.signalCount > 0 then
            candidateBranchCount = candidateBranchCount + 1
        end
    end

    table.sort(branchStats, function(left, right)
        if left.newComponentCount ~= right.newComponentCount then
            return left.newComponentCount > right.newComponentCount
        end
        if left.signalCount ~= right.signalCount then
            return left.signalCount > right.signalCount
        end
        if left.maxComponentScore ~= right.maxComponentScore then
            return left.maxComponentScore > right.maxComponentScore
        end
        return safePath(left.branch) < safePath(right.branch)
    end)

    addLine("")
    addLine(string.format(
        "Root branch grouping: %d total branches | %d branches contain signals",
        #directChildren,
        candidateBranchCount
    ))
    addLine("One visible loot object commonly contains many descendant components.")
    for index, stats in ipairs(branchStats) do
        addLine(string.format(
            "  ROOT %d | components=%d | signals=%d | new-components=%d | max-score=%d",
            index,
            stats.componentCount,
            stats.signalCount,
            stats.newComponentCount,
            stats.maxComponentScore
        ))
        addLine("    " .. inventoryDescriptor(errors, stats.branch))
        addLine("    attributes: " .. attributesText(errors, stats.branch))
    end

    addLine("")
    addLine(string.format(
        "Complete prioritized component inventory: showing %d/%d | signal components=%d",
        math.min(#records, CONFIG.MaxFallbackInstances),
        #records,
        signalCount
    ))
    addLine("Priority: newly appeared -> attributes/prompts -> suspicious names -> structural objects.")

    local maximumRecords = math.min(#records, CONFIG.MaxFallbackInstances)
    for index = 1, maximumRecords do
        local record = records[index]
        addLine("")
        addLine(string.format(
            "  COMPONENT %d | score=%d | %s",
            index,
            record.score,
            inventoryDescriptor(errors, record.instance)
        ))
        addLine("    reasons: " .. (#record.reasons > 0 and table.concat(record.reasons, ", ") or "none"))
        if record.distance ~= nil then
            addLine("    distance from player: " .. numberText(record.distance) .. " studs")
        end
        appendInstanceDetails(addLine, errors, record.instance, "    ")
    end

    if #records > maximumRecords then
        addLine("  ...+" .. tostring(#records - maximumRecords) .. " objects not shown")
    end

    return signalCount, candidateBranchCount
end

local function inspectDrop(addLine, errors, model, root, ordinal)
    local modelId = instanceId(model)
    local nameOk, modelName = safeProperty(errors, model, "Name")
    local parentOk, parent = safeProperty(errors, model, "Parent")
    local parentName = nil
    if parentOk and parent ~= nil then
        local parentNameOk, parentNameValue = safeProperty(errors, parent, "Name")
        if parentNameOk then
            parentName = parentNameValue
        end
    end

    local primaryOk, primaryPart = safeProperty(errors, model, "PrimaryPart")
    if not primaryOk or primaryPart == nil or not safeIsA(primaryPart, "BasePart") then
        primaryPart = nil
    end

    local rawLanded = safeAttribute(errors, model, "DropLanded")
    local rawGold = safeAttribute(errors, model, "GoldValue")
    local rawXyd = safeAttribute(errors, model, "Xyd")
    local xydNumber = finiteNumber(rawXyd)
    local parentNumber = finiteNumber(parentName)
    local tierInput = xydNumber or parentNumber or 1
    local derivedTier = math.max(1, math.floor(tierInput))
    local tierSource = "fallback 1"
    if xydNumber ~= nil then
        tierSource = "Xyd"
    elseif parentNumber ~= nil then
        tierSource = "Parent.Name"
    end

    local goldNumber = finiteNumber(rawGold)
    local flooredGold = goldNumber and math.floor(goldNumber) or 0
    local distance = nil
    if root ~= nil and primaryPart ~= nil then
        local ok, result = pcall(function()
            return (primaryPart.Position - root.Position).Magnitude
        end)
        if ok then
            distance = result
        else
            addError(errors, "Distance " .. safePath(model), result)
        end
    end

    local directPrompt = nil
    if primaryPart ~= nil then
        local ok, result = pcall(function()
            return primaryPart:FindFirstChild("PickupPrompt")
        end)
        if ok then
            directPrompt = result
        else
            addError(errors, "Direct PickupPrompt " .. safePath(model), result)
        end
    end

    local descendants = safeDescendants(errors, model)
    local recursivePrompts = {}
    for _, descendant in ipairs(descendants) do
        if safeIsA(descendant, "ProximityPrompt") then
            table.insert(recursivePrompts, descendant)
        end
    end

    local namePass = nameOk and modelName == "DropItem"
    local primaryPass = primaryPart ~= nil
    local rootPass = root ~= nil
    local rangePass = distance ~= nil and distance <= CONFIG.ReferenceRange or false
    local landedPass = rawLanded == true
    local objectReady = namePass and primaryPass and rootPass and rangePass and landedPass

    addLine("")
    addLine(string.rep("=", 72))
    addLine(string.format(
        "DROP #%d  |  runtime id %d  |  object gates %s",
        ordinal,
        modelId,
        passText(objectReady)
    ))
    addLine("path: " .. safePath(model))
    addLine("parent: " .. (parent and safePath(parent) or "<nil>"))
    addLine("all model attributes: " .. attributesText(errors, model))
    addLine("tags: " .. tagsText(errors, model))
    addLine("")
    addLine("Object-level gates used by the current AutoPickup worker:")
    addLine("  " .. passText(namePass) .. " Class=Model and Name=DropItem")
    addLine("  " .. passText(primaryPass) .. " PrimaryPart exists")
    addLine("  " .. passText(rootPass) .. " player HumanoidRootPart exists")
    addLine(string.format(
        "  %s distance <= %d  |  distance=%s studs",
        passText(distance ~= nil and rangePass or nil),
        CONFIG.ReferenceRange,
        numberText(distance)
    ))
    addLine("  " .. passText(landedPass) .. " DropLanded is boolean true  |  raw=" .. valueText(rawLanded))
    addLine("  GoldValue raw=" .. valueText(rawGold) .. "  | floor=" .. tostring(flooredGold))
    addLine(string.format(
        "  Tier=%d  | source=%s | Xyd=%s | Parent.Name=%s",
        derivedTier,
        tierSource,
        valueText(rawXyd),
        valueText(parentName)
    ))
    addLine("  Note: toggle, selected rarities and minimum value are UI/config gates, not object fields.")
    addLine("")
    addLine("Pickup route expected by the current script:")
    addLine("  " .. passText(directPrompt ~= nil) .. " PrimaryPart has direct child named PickupPrompt")
    if directPrompt ~= nil then
        local classOk, promptClass = safeProperty(errors, directPrompt, "ClassName")
        addLine("  direct child class: " .. (classOk and cleanText(promptClass, 80) or "<unavailable>"))
        appendInstanceDetails(addLine, errors, directPrompt, "    ")
    end
    addLine("  recursive ProximityPrompt count: " .. tostring(#recursivePrompts))
    for index, prompt in ipairs(sortedInstances(recursivePrompts)) do
        if index > 10 then
            addLine("    ...+" .. tostring(#recursivePrompts - 10) .. " prompts")
            break
        end
        addLine("    - " .. safePath(prompt) .. (prompt == directPrompt and " [DIRECT]" or " [RECURSIVE ONLY]"))
    end

    if primaryPart ~= nil then
        addLine("")
        addLine("PrimaryPart:")
        appendInstanceDetails(addLine, errors, primaryPart, "  ")
    end

    addLine("")
    addLine(string.format(
        "Descendant structure: showing %d/%d",
        math.min(#descendants, CONFIG.MaxDescendantsPerDrop),
        #descendants
    ))
    local sortedDescendants = sortedInstances(descendants)
    local maximum = math.min(#sortedDescendants, CONFIG.MaxDescendantsPerDrop)
    for index = 1, maximum do
        appendInstanceDetails(addLine, errors, sortedDescendants[index], "  ")
    end
    if #sortedDescendants > maximum then
        addLine("  ...+" .. tostring(#sortedDescendants - maximum) .. " descendants not shown")
    end

    return objectReady
end

local function makeSnapshot()
    local errors = {}
    local lines = {}
    local characterCount = 0
    local outputTruncated = false

    local function addLine(line)
        if outputTruncated then
            return
        end

        local safeLine = cleanText(line, 1200)
        if characterCount + #safeLine + 1 > CONFIG.MaxDisplayCharacters then
            table.insert(lines, "")
            table.insert(lines, "<DISPLAY TRUNCATED: safety character limit reached>")
            outputTruncated = true
            return
        end

        table.insert(lines, safeLine)
        characterCount = characterCount + #safeLine + 1
    end

    scanNumber = scanNumber + 1
    local root = playerRoot(errors)
    local container = nil
    local containerOk, containerResult = pcall(function()
        return Workspace:FindFirstChild("DropsClient")
    end)
    if containerOk then
        container = containerResult
    else
        addError(errors, "Find Workspace.DropsClient", containerResult)
    end

    addLine("MAGIC LOOT DROP INSPECTOR v" .. INSPECTOR_VERSION .. " - LIVE SNAPSHOT")
    addLine(string.format(
        "scan=%d  elapsed=%.1fs  refresh=%.1fs  placeId=%s",
        scanNumber,
        os.clock(),
        CONFIG.RefreshSeconds,
        cleanText(game.PlaceId, 40)
    ))
    addLine("mode=READ ONLY (the only created/modified objects belong to this popup)")
    addLine("")
    addLine("Expected by the current worker:")
    addLine("  Workspace.DropsClient -> descendant Model named DropItem")
    addLine("  PrimaryPart + DropLanded(boolean true) + range + GoldValue + tier")
    addLine("  pickup lookup: PrimaryPart:FindFirstChild(\"PickupPrompt\") [direct child]")
    addLine("")
    addLine("Workspace.DropsClient: " .. (container and safePath(container) or "<NOT FOUND>"))
    addLine("Player HumanoidRootPart: " .. (root and safePath(root) or "<NOT FOUND>"))

    if container == nil then
        local additions, removals = updateRecentChanges(errors, {})
        addLine("")
        addLine("No DropsClient exists as a direct Workspace child in this snapshot.")
        addLine("Keep this popup open while loot appears; it will update automatically.")
        return {
            text = table.concat(lines, "\n"),
            containerFound = false,
            rootFound = root ~= nil,
            branchCount = 0,
            candidateBranchCount = 0,
            descendantCount = 0,
            dropCount = 0,
            readyCount = 0,
            signalCount = 0,
            additionCount = additions,
            removalCount = removals,
            recentChangeCount = #recentChanges,
            errorCount = #errors,
        }
    end

    local descendants = safeDescendants(errors, container)
    local branchCount = #safeChildren(errors, container)
    local additions, removals, addedSet = updateRecentChanges(errors, descendants)
    local dropModels = {}
    local otherModelHistogram = {}
    local classHistogram = {}

    for _, descendant in ipairs(descendants) do
        local classOk, className = safeProperty(errors, descendant, "ClassName")
        local normalizedClass = classOk and tostring(className) or "<unknown>"
        classHistogram[normalizedClass] = (classHistogram[normalizedClass] or 0) + 1

        if safeIsA(descendant, "Model") then
            local nameOk, name = safeProperty(errors, descendant, "Name")
            local normalizedName = nameOk and tostring(name) or "<unknown>"
            if normalizedName == "DropItem" then
                table.insert(dropModels, descendant)
            else
                otherModelHistogram[normalizedName] = (otherModelHistogram[normalizedName] or 0) + 1
            end
        end
    end

    dropModels = sortedInstances(dropModels)
    addLine("")
    addLine("Container summary:")
    local containerClassOk, containerClass = safeProperty(errors, container, "ClassName")
    addLine("  class: " .. (containerClassOk and cleanText(containerClass, 80) or "<unavailable>"))
    addLine("  root branches (possible whole objects): " .. tostring(branchCount))
    addLine("  descendants: " .. tostring(#descendants))
    addLine("  DropItem models: " .. tostring(#dropModels))
    if #dropModels == 0 then
        addLine("  STATUS: the legacy DropItem signature is absent; generic inventory follows below.")
    end
    addLine("  container attributes: " .. attributesText(errors, container))

    local classNames = {}
    for className in pairs(classHistogram) do
        table.insert(classNames, className)
    end
    table.sort(classNames)
    for _, className in ipairs(classNames) do
        addLine("  class " .. cleanText(className, 80) .. ": " .. tostring(classHistogram[className]))
    end

    local otherNames = {}
    for name in pairs(otherModelHistogram) do
        table.insert(otherNames, name)
    end
    table.sort(otherNames)
    if #otherNames > 0 then
        addLine("  other Model names (useful if DropItem was renamed):")
        local maximumNames = math.min(#otherNames, CONFIG.MaxOtherModelNames)
        for index = 1, maximumNames do
            local name = otherNames[index]
            addLine("    " .. cleanText(name, 100) .. ": " .. tostring(otherModelHistogram[name]))
        end
        if #otherNames > maximumNames then
            addLine("    ...+" .. tostring(#otherNames - maximumNames) .. " names")
        end
    end

    local readyCount = 0
    local signalCount = 0
    local candidateBranchCount = 0
    local maximumDrops = math.min(#dropModels, CONFIG.MaxDropModels)
    for index = 1, maximumDrops do
        if inspectDrop(addLine, errors, dropModels[index], root, index) then
            readyCount = readyCount + 1
        end
    end
    if #dropModels > maximumDrops then
        addLine("")
        addLine("...+" .. tostring(#dropModels - maximumDrops) .. " DropItem models not detailed")
    end

    if #dropModels == 0 then
        signalCount, candidateBranchCount = appendFallbackInventory(
            addLine,
            errors,
            container,
            descendants,
            root,
            additions,
            removals,
            addedSet
        )
    end

    if #errors > 0 then
        addLine("")
        addLine("Read errors (objects may disappear while being inspected):")
        for _, err in ipairs(errors) do
            addLine("  - " .. err)
        end
    end

    return {
        text = table.concat(lines, "\n"),
        containerFound = true,
        rootFound = root ~= nil,
        branchCount = branchCount,
        candidateBranchCount = candidateBranchCount,
        descendantCount = #descendants,
        dropCount = #dropModels,
        readyCount = readyCount,
        signalCount = signalCount,
        additionCount = additions,
        removalCount = removals,
        recentChangeCount = #recentChanges,
        errorCount = #errors,
    }
end

local function renderSnapshot(snapshot)
    if not alive or closed then
        return
    end

    local oldCanvasPosition = scroll.CanvasPosition
    lastReportText = snapshot.text
    reportText.Text = snapshot.text

    local availableWidth = math.max(300, scroll.AbsoluteSize.X - 29)
    local measureOk, measured = pcall(function()
        return TextService:GetTextSize(
            snapshot.text,
            reportText.TextSize,
            reportText.Font,
            Vector2.new(availableWidth, 100000)
        )
    end)
    local contentHeight = measureOk and measured.Y + 24 or 5000
    reportText.Size = UDim2.new(1, -22, 0, contentHeight)
    scroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 18)

    local maximumScrollY = math.max(0, contentHeight + 18 - scroll.AbsoluteSize.Y)
    scroll.CanvasPosition = Vector2.new(
        0,
        math.min(oldCanvasPosition.Y, maximumScrollY)
    )

    statusLabel.Text = string.format(
        "DropsClient %s | root branches %d | descendants %d | candidate branches %d | legacy DropItem %d | errors %d",
        snapshot.containerFound and "OK" or "NO",
        snapshot.branchCount,
        snapshot.descendantCount,
        snapshot.candidateBranchCount,
        snapshot.dropCount,
        snapshot.errorCount
    )

    if snapshot.containerFound and snapshot.dropCount > 0 then
        statusLabel.TextColor3 = Color3.fromRGB(188, 229, 205)
    elseif snapshot.containerFound then
        statusLabel.TextColor3 = Color3.fromRGB(247, 197, 154)
    else
        statusLabel.TextColor3 = Color3.fromRGB(255, 164, 164)
    end
end

local function closeInspector()
    if closed then
        return
    end

    closed = true
    alive = false

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    pcall(function()
        rootGui:Destroy()
    end)
end

table.insert(connections, closeButton.Activated:Connect(closeInspector))

table.insert(connections, pauseButton.Activated:Connect(function()
    if closed then
        return
    end

    paused = not paused
    if paused then
        pauseButton.Text = "Continuar"
        pauseButton.BackgroundColor3 = Color3.fromRGB(38, 70, 55)
        pauseButton.TextColor3 = Color3.fromRGB(185, 241, 206)
        livePill.Text = "PAUSA"
        livePill.BackgroundColor3 = Color3.fromRGB(72, 60, 38)
        livePill.TextColor3 = Color3.fromRGB(248, 220, 164)
    else
        pauseButton.Text = "Pausar"
        pauseButton.BackgroundColor3 = Color3.fromRGB(67, 53, 34)
        pauseButton.TextColor3 = Color3.fromRGB(250, 221, 166)
        livePill.Text = "LIVE"
        livePill.BackgroundColor3 = Color3.fromRGB(31, 92, 64)
        livePill.TextColor3 = Color3.fromRGB(183, 255, 214)
        refreshRequested = true
    end
end))

table.insert(connections, refreshButton.Activated:Connect(function()
    if not closed then
        refreshRequested = true
    end
end))

table.insert(connections, copyButton.Activated:Connect(function()
    if closed then
        return
    end

    local writer = getClipboardWriter()
    if writer == nil then
        copyButton.Text = "Sin soporte"
        copyButton.BackgroundColor3 = Color3.fromRGB(83, 44, 51)
        copyButton.TextColor3 = Color3.fromRGB(255, 190, 197)
    else
        local payload = lastReportText
        if payload == "" then
            payload = reportText.Text
        end

        local copied = pcall(writer, payload)
        if copied then
            copyButton.Text = "Copiado"
            copyButton.BackgroundColor3 = Color3.fromRGB(34, 91, 62)
            copyButton.TextColor3 = Color3.fromRGB(183, 255, 214)
        else
            copyButton.Text = "Error"
            copyButton.BackgroundColor3 = Color3.fromRGB(83, 44, 51)
            copyButton.TextColor3 = Color3.fromRGB(255, 190, 197)
        end
    end

    task.delay(1.5, function()
        if alive and not closed then
            copyButton.Text = "Copiar informe"
            copyButton.BackgroundColor3 = Color3.fromRGB(37, 83, 112)
            copyButton.TextColor3 = Color3.fromRGB(205, 239, 255)
        end
    end)
end))

task.spawn(function()
    while alive do
        local parentOk, currentParent = pcall(function()
            return rootGui.Parent
        end)

        if not parentOk or currentParent == nil then
            alive = false
            break
        end

        if not paused or refreshRequested then
            refreshRequested = false
            local ok, snapshot = pcall(makeSnapshot)

            if alive and not closed then
                if ok then
                    local renderOk, renderError = pcall(function()
                        renderSnapshot(snapshot)
                    end)

                    if not renderOk and alive then
                        statusLabel.Text = "Render error: " .. cleanText(renderError, 180)
                        statusLabel.TextColor3 = Color3.fromRGB(255, 164, 164)
                    end
                else
                    statusLabel.Text = "Scan error: " .. cleanText(snapshot, 180)
                    statusLabel.TextColor3 = Color3.fromRGB(255, 164, 164)
                    reportText.Text = "The scan failed safely and will retry.\n\n" .. cleanText(snapshot, 1000)
                end
            end
        end

        task.wait(CONFIG.RefreshSeconds)
    end
end)
