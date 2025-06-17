local gameScripts = {
    [18687417158] = "forsaken.lua",
}

local baseURL = "https://raw.githubusercontent.com/xyamnnn/sillyprojects/main/"
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local plr = Players.LocalPlayer

getgenv().SillyHubLoader = true

local function loadScript(url, retries)
    retries = retries or 3
    local success, result = pcall(game.HttpGet, game, url)
    
    if not success or not result or result == "" then
        if retries > 0 then
            wait(1)
            return loadScript(url, retries - 1)
        end
        plr:Kick("Failed to load script. Check connection or report issue: https://discord.gg/ZEWJGgsP7e")
        return
    end
    
    local execSuccess, execError = pcall(function()
        local func = loadstring(result)
        if func then
            func()
        else
            error("loadstring returned nil")
        end
    end)
    if not execSuccess then
        warn("Script execution failed: " .. tostring(execError))
    end
end

local function setupAntiIdle()
    pcall(function()
        for _, conn in pairs(getconnections(plr.Idled)) do
            conn:Disable()
        end
    end)
    
    plr.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local scriptFile = gameScripts[game.PlaceId]
if not scriptFile then
    plr:Kick("Game not supported. Report if this is wrong: https://discord.gg/ZEWJGgsP7e")
    return
end

setupAntiIdle()
loadScript(baseURL .. scriptFile) 
