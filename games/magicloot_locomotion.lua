-- Magic Loot locomotion module - staged release 1 (Walking only)
--
-- This module never teleports the character and never changes movement speed.
-- It is loaded behind a protected bridge in the main script; a load/runtime
-- failure therefore cannot prevent Magic Loot itself from opening.

local Module = {}

function Module.create(context)
    local runService = game:GetService("RunService")
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

    function api:Install(_group)
        return true
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

    function api:Stop()
        resetAll()
    end

    return api
end

return Module
