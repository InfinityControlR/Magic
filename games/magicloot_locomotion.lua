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
        stage = nil,
        stagePart = nil,
        humanoid = nil,
        root = nil,
        destination = nil,
        bound = false,
        bestDistance = math.huge,
        lastProgressAt = 0,
        retryStage = nil,
        retryStagePart = nil,
        retryAt = 0,
    }

    local api = {}

    local function stop()
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
        state.bound = false
        state.bestDistance = math.huge
        state.lastProgressAt = 0
        state.retryStage = nil
        state.retryStagePart = nil
        state.retryAt = 0

        if wasActive and humanoid ~= nil and root ~= nil then
            pcall(function()
                humanoid:Move(Vector3.new(0, 0, 0), false)
            end)
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
                    stop()
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
            stop()
            return
        end

        if state.active
            and (state.stage ~= stage or state.stagePart ~= stagePart)
        then
            stop()
        end
        if state.retryAt > 0
            and (state.retryStage ~= stage or state.retryStagePart ~= stagePart)
        then
            stop()
        end
    end

    function api:Update(mode, stage, stagePart, root, destination)
        if mode ~= "Walking" then
            stop()
            return "locomotion mode unavailable"
        end

        if stagePart == nil or root == nil or typeof(destination) ~= "Vector3" then
            stop()
            return "stage " .. tostring(stage) .. " waiting for destination"
        end

        local character = root.Parent
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid == nil or humanoid.Health <= 0 then
            stop()
            return "stage " .. tostring(stage) .. " waiting for character"
        end

        local delta = destination - root.Position
        local planar = Vector3.new(delta.X, 0, delta.Z)
        local distance = planar.Magnitude
        if distance <= 4 then
            stop()
            return "stage " .. tostring(stage) .. " walking arrived"
        end

        local now = os.clock()
        if state.retryAt > now
            and state.retryStage == stage
            and state.retryStagePart == stagePart
        then
            return string.format(
                "stage %d walking stalled; retry in %.1fs",
                stage,
                state.retryAt - now
            )
        elseif state.retryAt > 0 then
            state.retryStage = nil
            state.retryStagePart = nil
            state.retryAt = 0
        end

        local sameRoute = state.active
            and state.stage == stage
            and state.stagePart == stagePart
            and state.humanoid == humanoid
            and state.root == root
            and state.destination ~= nil
            and (state.destination - destination).Magnitude <= 0.25

        if not sameRoute then
            stop()
            state.active = true
            state.generation = state.generation + 1
            state.stage = stage
            state.stagePart = stagePart
            state.humanoid = humanoid
            state.root = root
            state.destination = destination
            state.bestDistance = distance
            state.lastProgressAt = now

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
                stop()
                return "stage " .. tostring(stage) .. " walking unavailable"
            end

            state.bound = true
            startWatchdog(state.generation)
        elseif distance <= state.bestDistance - 0.5 then
            state.bestDistance = distance
            state.lastProgressAt = now
        elseif now - state.lastProgressAt > 6 then
            stop()
            state.retryStage = stage
            state.retryStagePart = stagePart
            state.retryAt = now + 5
            return "stage " .. tostring(stage) .. " walking stalled; attacks resumed"
        end

        state.heartbeat = now
        return string.format("stage %d walking %.1f studs", stage, distance)
    end

    function api:BlocksAttack()
        if state.active and os.clock() - state.heartbeat > 1 then
            stop()
        end
        return state.active
    end

    function api:Stop()
        stop()
    end

    return api
end

return Module
