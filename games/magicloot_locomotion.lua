-- Magic Loot external controller - Walking locomotion plus native Broom jump
--
-- This module never teleports the character and never changes movement speed.
-- It is loaded behind a protected bridge in the main script; a load/runtime
-- failure therefore cannot prevent Magic Loot itself from opening.

local Module = {}

function Module.create(context)
    context = type(context) == "table" and context or {}
    local runService = game:GetService("RunService")
    local players = game:GetService("Players")
    local bindName = "MagicLootWalkingControl_"
        .. tostring(math.random(1, 1000000000))
        .. "_"
        .. tostring(os.clock())
    local state = {
        active = false,
        generation = 0,
        heartbeat = 0,
        preparedStage = nil,
        preparedStagePart = nil,
        routeChangedAt = 0,
        stage = nil,
        stagePart = nil,
        humanoid = nil,
        root = nil,
        destination = nil,
        finalDestination = nil,
        phase = nil,
        bound = false,
        lastPosition = nil,
        lastMovedAt = 0,
        resetHumanoid = nil,
        resetCharacter = nil,
        resetDeadline = 0,
        resetUsedStage = nil,
        blockedStage = nil,
        settleUntil = 0,
    }

    local api = {}

    -- Broom uses the native StageJump button so the game's own handler keeps
    -- ownership of validation, mounting, flight and landing. No remote is sent
    -- directly from this module.
    local broomStages = { 4, 8, 13, 18, 23 }
    local broomStageSet = { [4] = true, [8] = true, [13] = true, [18] = true, [23] = true }
    local broom = {
        alive = true,
        installed = false,
        workerStarted = false,
        enabled = false,
        stage = nil,
        armed = false,
        readyAt = 0,
        reason = nil,
        waitingForBase = false,
        sawDungeon = false,
        returnEpisode = false,
        returnToken = 0,
        lastActivatedAt = -math.huge,
        activations = 0,
        status = "broom disabled",
    }

    local function broomOption(name, fallback)
        if type(context.option) ~= "function" then return fallback end
        local ok, value = pcall(context.option, name, fallback)
        return ok and value ~= nil and value or fallback
    end

    local function broomToggle()
        if type(context.toggle) ~= "function" then return false end
        local ok, value = pcall(context.toggle, "AutoBroom")
        return ok and value == true
    end

    local function broomStage(value)
        local number = tonumber(value)
        if number == nil then return nil end
        local stage = math.floor(number)
        if stage ~= number or not broomStageSet[stage] then return nil end
        return stage
    end

    local function broomReturnDelay()
        return math.clamp(tonumber(broomOption("BroomReturnDelay", 5)) or 5, 1, 30)
    end

    local function inDungeonChallenge()
        local player = players.LocalPlayer
        if player == nil then return nil end
        local value = player:FindFirstChild("InDungeonChallenge")
        if value == nil then return nil end
        local ok, result = pcall(function() return tonumber(value.Value) end)
        return ok and result or nil
    end

    local function broomIsA(instance, className)
        if instance == nil then return false end
        local ok, result = pcall(function() return instance:IsA(className) end)
        return ok and result == true
    end

    local function broomChild(parent, name, className)
        if parent == nil then return nil end
        local ok, children = pcall(function() return parent:GetChildren() end)
        if not ok or type(children) ~= "table" then return nil end
        for _, child in ipairs(children) do
            if child.Name == name and broomIsA(child, className) then return child end
        end
        return nil
    end

    local function broomAttribute(instance, name)
        if instance == nil then return nil end
        local ok, value = pcall(function() return instance:GetAttribute(name) end)
        if ok then return value end
        return nil
    end

    local function broomLocked(instance)
        return broomAttribute(instance, "Locked") == true
            or broomAttribute(instance, "IsLocked") == true
            or broomAttribute(instance, "Unlocked") == false
            or broomAttribute(instance, "IsUnlocked") == false
    end

    local function locateBroomButton(stage)
        local player = players.LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui") or nil
        if playerGui == nil then return nil, nil, "PlayerGui unavailable" end
        local screen = broomChild(playerGui, "ScreenGui", "ScreenGui")
        local jump = broomChild(screen, "StageJump", "Frame")
        local frame = broomChild(jump, "Frame", "Frame")
        local scrolling = broomChild(frame, "_ScrollingFrame", "ScrollingFrame")
        local stageFrame = broomChild(scrolling, tostring(stage), "Frame")
        local teleport = broomChild(stageFrame, "传送按钮", "Frame")
        local button = broomChild(teleport, "Button", "GuiButton")
        if button == nil then return nil, stageFrame, "native StageJump button not found" end
        local current, descendant = pcall(function() return button:IsDescendantOf(playerGui) end)
        if not current or not descendant then return nil, stageFrame, "native StageJump button is stale" end
        return button, stageFrame, nil
    end

    local function validateBroomButton(button, stageFrame)
        if not broomIsA(button, "GuiButton") then return false, "native button unavailable" end
        local activeOk, active = pcall(function() return button.Active end)
        if activeOk and active == false then return false, "native button inactive" end
        local interactOk, interact = pcall(function() return button.Interactable end)
        if interactOk and interact == false then return false, "native button not interactable" end
        if broomLocked(stageFrame) or broomLocked(button) then return false, "broom stage locked" end
        return true, nil
    end

    local function broomConnections(signal)
        if type(getconnections) ~= "function" then return nil end
        local ok, values = pcall(getconnections, signal)
        return ok and type(values) == "table" and #values or nil
    end

    local function fireBroomButton(button)
        if type(firesignal) ~= "function" then return false, "firesignal unavailable" end
        local signal = button.Activated
        local signalName = "Activated"
        local count = broomConnections(signal)
        if count == 0 then
            local mouse = button.MouseButton1Click
            local mouseCount = broomConnections(mouse)
            if mouseCount ~= nil and mouseCount > 0 then
                signal = mouse
                signalName = "MouseButton1Click"
            else
                return false, "native button has no connected activation signal"
            end
        end
        local ok, detail = pcall(firesignal, signal)
        return ok, ok and signalName or tostring(detail)
    end

    local function disarmBroom()
        broom.armed = false
        broom.readyAt = 0
        broom.reason = nil
    end

    local function armBroom(reason, now)
        broom.waitingForBase = false
        broom.sawDungeon = false
        broom.armed = true
        broom.reason = reason
        local delay = reason == "inventory return" and broomReturnDelay() or 0
        broom.readyAt = math.max(now + delay, broom.lastActivatedAt + 2)
    end

    local function updateBroom()
        local enabled = broomToggle()
        local selected = broomStage(broomOption("BroomStage", "4"))
        local now = os.clock()
        if not enabled then
            broom.enabled = false
            broom.stage = selected
            broom.waitingForBase = false
            broom.sawDungeon = false
            broom.returnEpisode = false
            disarmBroom()
            broom.status = "broom disabled"
            return
        end
        if selected == nil then
            broom.enabled = true
            broom.stage = nil
            broom.waitingForBase = false
            broom.returnEpisode = false
            disarmBroom()
            broom.status = "unsupported broom stage"
            return
        end
        local wasEnabled = broom.enabled
        local changed = broom.stage ~= selected
        broom.enabled = true
        broom.stage = selected
        if not wasEnabled then
            broom.returnEpisode = false
            armBroom("initial", now)
        elseif changed then
            if broom.waitingForBase then
                disarmBroom()
            elseif broom.returnEpisode then
                armBroom("inventory return", now)
            else
                armBroom("stage changed", now)
            end
        end
        if broom.waitingForBase then
            local challenge = inDungeonChallenge()
            if challenge ~= nil and challenge > 0 then broom.sawDungeon = true end
            if challenge == nil or challenge > 0 or not broom.sawDungeon then
                broom.status = "broom waiting for InDungeonChallenge >0 -> 0"
                return
            end
            armBroom("inventory return", now)
        end
        if not broom.armed then return end
        if now < broom.readyAt then
            broom.status = string.format("broom stage %d armed in %.1fs", selected, broom.readyAt - now)
            return
        end
        local button, stageFrame, locateError = locateBroomButton(selected)
        if button == nil then
            broom.status = "broom waiting: " .. tostring(locateError)
            return
        end
        local valid, validationError = validateBroomButton(button, stageFrame)
        if not valid then
            broom.status = "broom waiting: " .. tostring(validationError)
            return
        end
        local reason = broom.reason
        disarmBroom()
        local fired, detail = fireBroomButton(button)
        if not fired then
            broom.returnEpisode = false
            broom.waitingForBase = false
            broom.status = "broom activation failed: " .. tostring(detail)
            return
        end
        broom.activations = broom.activations + 1
        broom.lastActivatedAt = now
        if reason == "inventory return" then broom.returnEpisode = false end
        broom.status = string.format("broom stage %d activated once via %s", selected, tostring(detail))
    end

    local function startBroomWorker()
        if broom.workerStarted then return end
        broom.workerStarted = true
        task.spawn(function()
            while broom.alive do
                if type(context.alive) == "function" then
                    local aliveOk, hostAlive = pcall(context.alive)
                    if not aliveOk or hostAlive == false then break end
                end
                local ok, detail = pcall(updateBroom)
                if not ok then broom.status = "broom worker error: " .. tostring(detail) end
                task.wait(ok and 0.1 or 1)
            end
            broom.alive = false
        end)
    end

    local function clearPreparedRoute()
        state.preparedStage = nil
        state.preparedStagePart = nil
        state.routeChangedAt = 0
    end

    local function stopMovement()
        local wasActive = state.active
        local humanoid = state.humanoid
        local root = state.root

        if state.bound then
            pcall(function()
                runService:UnbindFromRenderStep(bindName)
            end)
        end

        state.generation = state.generation + 1
        state.active = false
        state.heartbeat = 0
        state.stage = nil
        state.stagePart = nil
        state.humanoid = nil
        state.root = nil
        state.destination = nil
        state.finalDestination = nil
        state.phase = nil
        state.bound = false
        state.lastPosition = nil
        state.lastMovedAt = 0

        if wasActive and humanoid ~= nil and root ~= nil then
            pcall(function()
                humanoid:Move(Vector3.new(0, 0, 0), false)
            end)
        end
    end

    local function resetAll()
        stopMovement()
        clearPreparedRoute()
        state.settleUntil = 0
    end

    local function planarDistance(left, right)
        local delta = left - right
        return Vector3.new(delta.X, 0, delta.Z).Magnitude
    end

    local function readEnterDelay()
        if type(context) ~= "table" or type(context.option) ~= "function" then
            return 0
        end
        local ok, value = pcall(context.option, "EnterDelay", 0)
        if not ok then
            return 0
        end
        return math.max(0, tonumber(value) or 0)
    end

    local function resolveStagePart(stage)
        if type(context) ~= "table" or type(context.stagePart) ~= "function" then
            return nil
        end
        local ok, part = pcall(context.stagePart, stage)
        if ok and part ~= nil and part:IsA("BasePart") then
            return part
        end
        return nil
    end

    local function groundPoint(part)
        return part.Position
            - Vector3.new(0, part.Size.Y * 0.5, 0)
            + Vector3.new(0, 3, 0)
    end

    local function isOverFootprint(part, point)
        local localPoint = part.CFrame:PointToObjectSpace(point)
        return math.abs(localPoint.X) <= part.Size.X * 0.5
            and math.abs(localPoint.Z) <= part.Size.Z * 0.5
    end

    local function chooseInitialDestination(stage, stagePart, root, destination)
        if stage ~= 1 or isOverFootprint(stagePart, root.Position) then
            return destination, "final"
        end

        local secondStagePart = resolveStagePart(2)
        if secondStagePart == nil then
            return destination, "final"
        end

        local firstPoint = destination
        local secondPoint = groundPoint(secondStagePart)
        local axisDelta = secondPoint - firstPoint
        local planarAxis = Vector3.new(axisDelta.X, 0, axisDelta.Z)
        if planarAxis.Magnitude < 1 then
            return destination, "final"
        end

        -- Stages 1 and 2 define the centre line. Approaching stage 1 from
        -- the opposite side first prevents a diagonal cut from a train corner.
        local entryDirection = -planarAxis.Unit
        local localDirection = stagePart.CFrame:VectorToObjectSpace(entryDirection)
        local distanceToX = math.huge
        local distanceToZ = math.huge
        if math.abs(localDirection.X) > 0.0001 then
            distanceToX = stagePart.Size.X * 0.5 / math.abs(localDirection.X)
        end
        if math.abs(localDirection.Z) > 0.0001 then
            distanceToZ = stagePart.Size.Z * 0.5 / math.abs(localDirection.Z)
        end
        local entryOffset = math.min(distanceToX, distanceToZ)
        if entryOffset == math.huge then
            return destination, "final"
        end
        local entry = firstPoint + entryDirection * (entryOffset + 6)
        return Vector3.new(entry.X, destination.Y, entry.Z), "align"
    end

    local function notifyReset()
        if type(context) == "table" and type(context.notify) == "function" then
            pcall(context.notify, "Walking stuck for 20s; resetting character")
        end
    end

    local function startWatchdog(generation)
        task.spawn(function()
            while state.active and state.generation == generation do
                task.wait(0.25)
                if state.active
                    and state.generation == generation
                    and os.clock() - state.heartbeat > 1
                then
                    resetAll()
                    break
                end
            end
        end)
    end

    function api:GetModes()
        return { "Walking" }
    end

    function api:Supports(mode)
        return mode == "Walking"
    end

    function api:Install(group)
        if broom.installed then return true end
        group:AddToggle("AutoBroom", {
            Text = "Auto Broom",
            Default = false,
        })
        group:AddDropdown("BroomStage", {
            Text = "Broom stage",
            Values = { "4", "8", "13", "18", "23" },
            Default = "4",
            Multi = false,
        })
        group:AddSlider("BroomReturnDelay", {
            Text = "Broom delay after inventory return",
            Default = 5,
            Min = 1,
            Max = 30,
            Rounding = 0,
        })
        broom.installed = true
        startBroomWorker()
        return true
    end

    function api:OnAutoReturnFull()
        if not broomToggle() then return false end
        local selected = broomStage(broomOption("BroomStage", "4"))
        if selected == nil then return false end
        broom.enabled = true
        broom.stage = selected
        if broom.returnEpisode then
            local current = inDungeonChallenge()
            if current ~= nil and current > 0 then broom.sawDungeon = true end
            return true
        end
        broom.returnEpisode = true
        broom.returnToken = broom.returnToken + 1
        broom.waitingForBase = true
        broom.sawDungeon = true
        disarmBroom()
        broom.status = "broom return token armed before DUNGEON_RETURN_TOWN"
        return true
    end

    function api:GetBroomStatus()
        return {
            enabled = broom.enabled,
            stage = broom.stage,
            armed = broom.armed,
            waitingForBase = broom.waitingForBase,
            returnToken = broom.returnToken,
            activationCount = broom.activations,
            message = broom.status,
        }
    end

    function api:GetBroomStages()
        local result = {}
        for index, value in ipairs(broomStages) do result[index] = value end
        return result
    end

    function api:Prepare(mode, stage, stagePart)
        if mode ~= "Walking" or stagePart == nil then
            resetAll()
            return
        end

        local now = os.clock()
        if state.resetUsedStage ~= nil and state.resetUsedStage ~= stage then
            state.resetUsedStage = nil
            state.blockedStage = nil
        end
        local routeChanged = state.preparedStage ~= stage
            or state.preparedStagePart ~= stagePart

        if routeChanged then
            stopMovement()
            state.preparedStage = stage
            state.preparedStagePart = stagePart
            state.routeChangedAt = now
        end
    end

    function api:Update(mode, stage, stagePart, root, destination)
        if mode ~= "Walking" then
            resetAll()
            return "locomotion mode unavailable"
        end

        if stagePart == nil or root == nil or typeof(destination) ~= "Vector3" then
            resetAll()
            return "stage " .. tostring(stage) .. " waiting for destination"
        end

        if state.preparedStage ~= stage or state.preparedStagePart ~= stagePart then
            api:Prepare(mode, stage, stagePart)
        end

        local now = os.clock()
        local remainingDelay = readEnterDelay() - (now - state.routeChangedAt)
        if remainingDelay > 0 then
            stopMovement()
            return string.format(
                "entering stage %s in %.1fs",
                tostring(stage),
                remainingDelay
            )
        end

        local character = root.Parent
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid == nil or humanoid.Health <= 0 then
            stopMovement()
            return "stage " .. tostring(stage) .. " waiting for character"
        end

        if state.resetHumanoid ~= nil then
            if humanoid ~= state.resetHumanoid or character ~= state.resetCharacter then
                state.resetHumanoid = nil
                state.resetCharacter = nil
                state.resetDeadline = 0
                state.settleUntil = now + 1.5
            elseif now < state.resetDeadline then
                stopMovement()
                return "stage " .. tostring(stage) .. " waiting for character reset"
            else
                stopMovement()
                return "stage " .. tostring(stage) .. " reset not accepted; walking paused"
            end
        end

        if now < state.settleUntil then
            stopMovement()
            return string.format(
                "stage %s character settling %.1fs",
                tostring(stage),
                state.settleUntil - now
            )
        end

        if state.blockedStage == stage then
            stopMovement()
            return "stage " .. tostring(stage) .. " walking paused after repeated stall"
        end

        local finalDistance = planarDistance(destination, root.Position)
        if finalDistance <= 4 then
            stopMovement()
            return "stage " .. tostring(stage) .. " walking arrived"
        end

        local sameRoute = state.active
            and state.stage == stage
            and state.stagePart == stagePart
            and state.humanoid == humanoid
            and state.root == root
            and state.finalDestination ~= nil
            and planarDistance(state.finalDestination, destination) <= 0.25

        if not sameRoute then
            stopMovement()
            local initialDestination, phase = chooseInitialDestination(
                stage,
                stagePart,
                root,
                destination
            )
            state.active = true
            state.generation = state.generation + 1
            state.stage = stage
            state.stagePart = stagePart
            state.humanoid = humanoid
            state.root = root
            state.destination = initialDestination
            state.finalDestination = destination
            state.phase = phase
            state.lastPosition = root.Position
            state.lastMovedAt = now

            local moved = pcall(function()
                runService:UnbindFromRenderStep(bindName)
                runService:BindToRenderStep(
                    bindName,
                    Enum.RenderPriority.Character.Value + 1,
                    function()
                        if not state.active
                            or state.humanoid ~= humanoid
                            or state.root ~= root
                            or state.destination == nil
                            or humanoid.Parent == nil
                            or humanoid.Health <= 0
                            or root.Parent == nil
                        then
                            return
                        end

                        local currentDelta = state.destination - root.Position
                        local currentPlanar = Vector3.new(
                            currentDelta.X,
                            0,
                            currentDelta.Z
                        )
                        if currentPlanar.Magnitude <= 4 then
                            humanoid:Move(Vector3.new(0, 0, 0), false)
                        else
                            humanoid:Move(currentPlanar.Unit, false)
                        end
                    end
                )
            end)
            if not moved then
                resetAll()
                return "stage " .. tostring(stage) .. " walking unavailable"
            end

            state.bound = true
            startWatchdog(state.generation)
        end

        local distance = planarDistance(state.destination, root.Position)
        if state.phase == "align" and distance <= 4 then
            state.phase = "final"
            state.destination = destination
            state.lastPosition = root.Position
            state.lastMovedAt = now
            distance = planarDistance(destination, root.Position)
        end

        if state.phase == "final" and distance <= 4 then
            stopMovement()
            return "stage " .. tostring(stage) .. " walking arrived"
        end

        if state.lastPosition == nil
            or planarDistance(root.Position, state.lastPosition) >= 1
        then
            state.lastPosition = root.Position
            state.lastMovedAt = now
        elseif now - state.lastMovedAt >= 20 then
            if state.resetUsedStage == stage then
                stopMovement()
                state.blockedStage = stage
                return "stage " .. tostring(stage) .. " walking paused after repeated stall"
            end
            local stuckHumanoid = humanoid
            local stuckCharacter = character
            stopMovement()
            state.resetUsedStage = stage
            state.resetHumanoid = stuckHumanoid
            state.resetCharacter = stuckCharacter
            state.resetDeadline = now + 15
            notifyReset()
            local requested = pcall(function()
                stuckHumanoid:ChangeState(Enum.HumanoidStateType.Dead)
            end)
            if not requested then
                state.resetDeadline = now
                return "stage " .. tostring(stage) .. " character reset unavailable"
            end
            return "stage " .. tostring(stage) .. " resetting stuck character"
        end

        state.heartbeat = now
        local action = state.phase == "align" and "aligning" or "walking"
        return string.format("stage %d %s %.1f studs", stage, action, distance)
    end

    function api:BlocksAttack()
        if state.active and os.clock() - state.heartbeat > 1 then
            resetAll()
        end
        return state.active
    end

    function api:StopWalking()
        resetAll()
    end

    function api:Stop()
        broom.alive = false
        broom.enabled = false
        broom.returnEpisode = false
        broom.waitingForBase = false
        disarmBroom()
        resetAll()
    end

    return api
end

return Module
