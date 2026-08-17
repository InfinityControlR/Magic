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

local games = {
    [118455659]  = 'magicloot.lua',
}   

local file = games[game.CreatorId]
if file then
    task.wait(math.random())
    loadstring(game:HttpGet(BASE .. file))()
end
