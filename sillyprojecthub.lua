local gameScripts = {
    [186874171582] = "forsaken.lua",
    -- placeholder
}

local baseURL = "https://raw.githubusercontent.com/xyamnnn/sillyprojects/main/"
local Players = game:GetService("Players")
local plr = Players.LocalPlayer

local scriptFile = gameScripts[game.PlaceId]

if scriptFile then
    loadstring(game:HttpGet(baseURL .. scriptFile))()
else
    game.Players.LocalPlayer:Kick("this game is not supported, if this is the right game and ur getting this error report it here to me. https://discord.gg/ZEWJGgsP7e")
end

for _, conn in next, getconnections(plr.Idled) do
    conn:Disable()
end

local VirtualUser = game:GetService("VirtualUser")

plr.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
