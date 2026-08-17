-- Magic Loot locomotion module - staged release 1 (Walking only)
--
-- This module never teleports the character and never changes movement speed.
-- It is loaded behind a protected bridge in the main script; a load/runtime
-- failure therefore cannot prevent Magic Loot itself from opening.

local Module = {}

function Module.create(context)
    local state = {
        active = false,
        generation = 0,
        heartbeat = 0,
        stage = nil,
        stagePart = nil,
        humanoid = nil,
        root = nil,
        destination = nil,
        lastMoveAt = 0,
    }

    local api = {}

    local function stop()
        local wasActive = state.active
        local humanoid = state.humanoid
        local root = state.root

        state.generation = state.generation + 1
        state.active = false
        state.heartbeat = 0
        state.stage = nil
        state.stagePart = nil
        state.humanoid = nil
        state.root = nil
        state.destination = nil
        state.lastMoveAt = 0

        if wasActive and humanoid ~= nil and root ~= nil then
            pcall(function()
                humanoid:MoveTo(root.Position)
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

        local distance = (root.Position - destination).Magnitude
        if distance <= 4 then
            stop()
            return "stage " .. tostring(stage) .. " walking arrived"
        end

        local now = os.clock()
        local sameRoute = state.active
            and state.stage == stage
            and state.stagePart == stagePart
            and state.humanoid == humanoid
            and state.root == root
            and state.destination ~= nil
            and (state.destination - destination).Magnitude <= 0.25

        if not sameRoute then
            stop()
            local moved = pcall(function()
                humanoid:MoveTo(destination)
            end)
            if not moved then
                return "stage " .. tostring(stage) .. " walking unavailable"
            end

            state.active = true
            state.generation = state.generation + 1
            state.stage = stage
            state.stagePart = stagePart
            state.humanoid = humanoid
            state.root = root
            state.destination = destination
            state.lastMoveAt = now
            startWatchdog(state.generation)
        elseif now - state.lastMoveAt >= 2.5 then
            local moved = pcall(function()
                humanoid:MoveTo(destination)
            end)
            if not moved then
                stop()
                return "stage " .. tostring(stage) .. " walking unavailable"
            end
            state.lastMoveAt = now
        end

        state.heartbeat = now
        return string.format("stage %d walking %.1f studs", stage, distance)
    end

    function api:BlocksAttack()
        return false
    end

    function api:Stop()
        stop()
    end

    return api
end

return Module
