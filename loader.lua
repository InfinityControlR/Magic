if not game:IsLoaded() then
    game.Loaded:Wait()
end


if identifyexecutor then
    local execName = tostring(identifyexecutor()):lower()
    if execName:find("solara") or execName:find("xeno") then
        game:GetService("Players").LocalPlayer:Kick("EXECUTOR NOT SUPPORTED[PLEASE DON'T GET MAD THIS IS SOLARA/XENO'S FAULT]")
        return
    end
end

local BASE = 'https://raw.githubusercontent.com/InfinityControlR/Magic/main/games/'
local LOCOMOTION = 'https://raw.githubusercontent.com/InfinityControlR/Magic/1520f8938d3cdb72bafb31e90b7ad8f8b81b3fcc/games/magicloot_locomotion.lua'

local games = {
    [118455659]  = 'magicloot.lua',
}

local file = games[game.CreatorId]
if file then
    task.wait(math.random())

    local factory = nil
    local extensionOk, extension = pcall(function()
        local source = game:HttpGet(LOCOMOTION)
        local chunk, compileError = loadstring(source)
        if type(chunk) ~= 'function' then
            error(tostring(compileError or 'locomotion compile failed'))
        end
        local result = chunk()
        if type(result) ~= 'table' or type(result.create) ~= 'function' then
            error('invalid locomotion module')
        end
        return result
    end)
    if extensionOk then
        factory = extension
    end

    local source = game:HttpGet(BASE .. file)
    local chunk, compileError = loadstring(source)
    if type(chunk) ~= 'function' then
        error(tostring(compileError or 'Magic Loot compile failed'))
    end
    chunk(factory)
end
