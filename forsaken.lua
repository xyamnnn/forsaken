local function validateLoader()
    if not getgenv().SillyHubLoader then
        game:GetService("Players").LocalPlayer:Kick("❌ access denied: please use the official silly hub loader!\n\nget it from: https://discord.gg/ZEWJGgsP7e (also try u skiding?)")
        return false
    end
    return true
end

if not validateLoader() then return end -- 🛑 stop the script from running


local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/main/source.lua", true))()

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local player = Players.LocalPlayer

-- ESP Variables
local espEnabled = false
local highlightKillersEnabled = false
local highlightSurvivorsEnabled = false
local highlightToolsEnabled = false
local espLinesEnabled = false
local autoGenEnabled = false
local autoGenStepTime = 1.5
local jumpEnabled = false
local bypassKillerWallsEnabled = false

-- Tracking tables
local killerHighlights = {}
local survivorHighlights = {}
local toolHighlights = {}
local killerBeams = {}
local survivorBeams = {}
local healthDisplays = {}

-- Connections
local highlightConnection
local staminaConnection
local jumpConnection
local bypassConnection
local staminaEnabled = false

-- Beam ESP system
local beamFolder = Instance.new("Folder")
beamFolder.Name = "ESPBeams"
beamFolder.Parent = workspace

-- Get player torso (handles both R6 and R15)
local function getTorso(character)
    return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
end

-- Create ESP line that can be seen through walls and updates in real-time
local function createBeam(fromPart, toPart, color, name, isKiller)
    -- Clean up existing line with same name
    local existingLine = beamFolder:FindFirstChild(name)
    if existingLine then
        existingLine:Destroy()
    end
    
    -- Create a Part-based line that can be seen through walls
    local line = Instance.new("Part")
    line.Name = name
    line.Anchored = true
    line.CanCollide = false
    line.CanTouch = false
    line.Material = Enum.Material.Neon
    line.TopSurface = Enum.SurfaceType.Smooth
    line.BottomSurface = Enum.SurfaceType.Smooth
    line.Color = color
    line.Transparency = 0
    
    -- Calculate initial position and size
    local distance = (fromPart.Position - toPart.Position).Magnitude
    line.Size = Vector3.new(isKiller and 0.4 or 0.25, isKiller and 0.4 or 0.25, distance)
    line.CFrame = CFrame.lookAt(fromPart.Position, toPart.Position) * CFrame.new(0, 0, -distance/2)
    
    line.Parent = beamFolder
    
    -- Add highlight to make it fully visible through walls
    local highlight = Instance.new("Highlight")
    highlight.Parent = line
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    return line, highlight, fromPart, toPart
end

-- Update ESP line position in real-time
local function updateBeamPosition(lineData, isKiller)
    if lineData and lineData.line and lineData.fromPart and lineData.toPart then
        if lineData.fromPart.Parent and lineData.toPart.Parent then
            local distance = (lineData.fromPart.Position - lineData.toPart.Position).Magnitude
            lineData.line.Size = Vector3.new(isKiller and 0.4 or 0.25, isKiller and 0.4 or 0.25, distance)
            lineData.line.CFrame = CFrame.lookAt(lineData.fromPart.Position, lineData.toPart.Position) * CFrame.new(0, 0, -distance/2)
        end
    end
end

-- Create or update health display
local function createHealthDisplay(character, isKiller)
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    
    if not humanoid or not head then return end
    
    local existingDisplay = head:FindFirstChild("HealthDisplay")
    if existingDisplay then
        -- Update existing display
        local healthLabel = existingDisplay:FindFirstChild("HealthLabel")
        if healthLabel then
            healthLabel.Text = "HP: " .. math.floor(math.max(0, humanoid.Health))
            healthLabel.TextColor3 = isKiller and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 150, 255)
        end
        return existingDisplay
    end
    
    -- Create new display (bigger size)
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "HealthDisplay"
    billboardGui.Parent = head
    billboardGui.Size = UDim2.new(0, 140, 0, 35)
    billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.LightInfluence = 0
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "HealthLabel"
    healthLabel.Parent = billboardGui
    healthLabel.Size = UDim2.new(1, 0, 1, 0)
    healthLabel.BackgroundTransparency = 1
    healthLabel.Text = "HP: " .. math.floor(math.max(0, humanoid.Health))
    healthLabel.TextColor3 = isKiller and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 150, 255)
    healthLabel.TextStrokeTransparency = 0
    healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    healthLabel.TextSize = 16
    healthLabel.Font = Enum.Font.SourceSansBold
    
    healthDisplays[character] = billboardGui
    return billboardGui
end

-- Clean up player ESP
local function cleanupPlayer(character)
    -- Remove highlights
    if killerHighlights[character] then
        killerHighlights[character]:Destroy()
        killerHighlights[character] = nil
    end
    if survivorHighlights[character] then
        survivorHighlights[character]:Destroy()
        survivorHighlights[character] = nil
    end
    
    -- Remove health displays
    if healthDisplays[character] then
        healthDisplays[character]:Destroy()
        healthDisplays[character] = nil
    end
    
    -- Remove ESP lines
    if killerBeams[character] then
        if killerBeams[character].line then killerBeams[character].line:Destroy() end
        if killerBeams[character].highlight then killerBeams[character].highlight:Destroy() end
        killerBeams[character] = nil
    end
    if survivorBeams[character] then
        if survivorBeams[character].line then survivorBeams[character].line:Destroy() end
        if survivorBeams[character].highlight then survivorBeams[character].highlight:Destroy() end
        survivorBeams[character] = nil
    end
end

-- Clean up all tool highlights
local function cleanupAllTools()
    for tool, highlight in pairs(toolHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    toolHighlights = {}
end

-- Main ESP update function
local function updateESP()
    if not espEnabled then return end
    
    local playersFolder = workspace:FindFirstChild("Players")
    if not playersFolder then return end
    
    local myCharacter = player.Character
    local myTorso = myCharacter and getTorso(myCharacter)
    
    -- Track current players
    local currentKillers = {}
    local currentSurvivors = {}
    
    -- Handle Killers
    if highlightKillersEnabled then
        local killers = playersFolder:FindFirstChild("Killers")
        if killers then
            for _, killer in pairs(killers:GetChildren()) do
                if killer:IsA("Model") and killer ~= myCharacter then
                    currentKillers[killer] = true
                    local killerTorso = getTorso(killer)
                    
                    if killerTorso then
                        -- Create highlight
                        if not killerHighlights[killer] then
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "KillerHighlight"
                            highlight.Parent = killer
                            highlight.FillColor = Color3.fromRGB(255, 0, 0)
                            highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
                            highlight.FillTransparency = 0.5
                            highlight.OutlineTransparency = 0
                            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            killerHighlights[killer] = highlight
                        end
                        
                        -- Create/update health display
                        createHealthDisplay(killer, true)
                        
                        -- Create ESP line
                        if myTorso and espLinesEnabled then
                            if not killerBeams[killer] then
                                local uniqueName = killer.Name .. "_Killer_" .. tostring(tick()):gsub("%.", "")
                                local line, highlight, fromPart, toPart = createBeam(myTorso, killerTorso, Color3.fromRGB(255, 0, 0), uniqueName, true)
                                killerBeams[killer] = {line = line, highlight = highlight, fromPart = fromPart, toPart = toPart}
                            else
                                -- Update existing line position
                                updateBeamPosition(killerBeams[killer], true)
                            end
                        elseif not espLinesEnabled and killerBeams[killer] then
                            -- Clean up line if ESP lines disabled
                            if killerBeams[killer].line then killerBeams[killer].line:Destroy() end
                            if killerBeams[killer].highlight then killerBeams[killer].highlight:Destroy() end
                            killerBeams[killer] = nil
                        end
                    end
                end
            end
        end
    end
    
    -- Handle Survivors
    if highlightSurvivorsEnabled then
        local survivors = playersFolder:FindFirstChild("Survivors")
        if survivors then
            for _, survivor in pairs(survivors:GetChildren()) do
                if survivor:IsA("Model") and survivor ~= myCharacter then
                    currentSurvivors[survivor] = true
                    local survivorTorso = getTorso(survivor)
                    
                    if survivorTorso then
                        -- Create highlight
                        if not survivorHighlights[survivor] then
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "SurvivorHighlight"
                            highlight.Parent = survivor
                            highlight.FillColor = Color3.fromRGB(0, 100, 255)
                            highlight.OutlineColor = Color3.fromRGB(0, 100, 255)
                            highlight.FillTransparency = 0.5
                            highlight.OutlineTransparency = 0
                            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                            survivorHighlights[survivor] = highlight
                        end
                        
                        -- Create/update health display
                        createHealthDisplay(survivor, false)
                        
                        -- Create ESP line
                        if myTorso and espLinesEnabled then
                            if not survivorBeams[survivor] then
                                local uniqueName = survivor.Name .. "_Survivor_" .. tostring(tick()):gsub("%.", "")
                                local line, highlight, fromPart, toPart = createBeam(myTorso, survivorTorso, Color3.fromRGB(0, 100, 255), uniqueName, false)
                                survivorBeams[survivor] = {line = line, highlight = highlight, fromPart = fromPart, toPart = toPart}
                            else
                                -- Update existing line position
                                updateBeamPosition(survivorBeams[survivor], false)
                            end
                        elseif not espLinesEnabled and survivorBeams[survivor] then
                            -- Clean up line if ESP lines disabled
                            if survivorBeams[survivor].line then survivorBeams[survivor].line:Destroy() end
                            if survivorBeams[survivor].highlight then survivorBeams[survivor].highlight:Destroy() end
                            survivorBeams[survivor] = nil
                        end
                    end
                end
            end
        end
    end
    
    -- Handle Tools (CONTINUOUS CHECK FOR MULTIPLE INSTANCES)
    if highlightToolsEnabled then
        local currentTools = {}
        
        -- Function to find all children with specific names
        local function findAllChildrenWithName(parent, name)
            local found = {}
            if parent then
                pcall(function()
                    for _, child in pairs(parent:GetChildren()) do
                        if child.Name == name then
                            table.insert(found, child)
                        end
                    end
                end)
            end
            return found
        end
        
        -- Check all instances at the 4 specific locations
        local allTools = {}
        
        -- workspace.BloxyCola (all instances)
        for _, tool in pairs(findAllChildrenWithName(workspace, "BloxyCola")) do
            table.insert(allTools, tool)
        end
        
        -- workspace.Medkit (all instances)
        for _, tool in pairs(findAllChildrenWithName(workspace, "Medkit")) do
            table.insert(allTools, tool)
        end
        
        -- workspace.Map.Ingame.BloxyCola (all instances)
        if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") then
            for _, tool in pairs(findAllChildrenWithName(workspace.Map.Ingame, "BloxyCola")) do
                table.insert(allTools, tool)
            end
        end
        
        -- workspace.Map.Ingame.Medkit (all instances)
        if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Ingame") then
            for _, tool in pairs(findAllChildrenWithName(workspace.Map.Ingame, "Medkit")) do
                table.insert(allTools, tool)
            end
        end
        
        -- Highlight all found tools
        for _, obj in pairs(allTools) do
            if obj and obj.Parent then
                currentTools[obj] = true
                if not toolHighlights[obj] then
                    pcall(function()
                        local highlight = Instance.new("Highlight")
                        highlight.Parent = obj
                        if obj.Name == "BloxyCola" then
                            highlight.FillColor = Color3.fromRGB(255, 200, 80)
                            highlight.OutlineColor = Color3.fromRGB(255, 160, 60)
                        else -- Medkit
                            highlight.FillColor = Color3.fromRGB(255, 150, 150)
                            highlight.OutlineColor = Color3.fromRGB(255, 100, 100)
                        end
                        highlight.FillTransparency = 0.5
                        highlight.OutlineTransparency = 0
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        toolHighlights[obj] = highlight
                    end)
                end
            end
        end
        
        -- Clean up removed tools
        for tool, highlight in pairs(toolHighlights) do
            if not currentTools[tool] or not tool.Parent then
                pcall(function()
                    if highlight and highlight.Parent then
                        highlight:Destroy()
                    end
                    toolHighlights[tool] = nil
                end)
            end
        end
    else
        -- Clean up all tool highlights when disabled
        cleanupAllTools()
    end
    
    -- Clean up removed players
    for killer, _ in pairs(killerHighlights) do
        if not currentKillers[killer] or not killer.Parent then
            cleanupPlayer(killer)
        end
    end
    
    for survivor, _ in pairs(survivorHighlights) do
        if not currentSurvivors[survivor] or not survivor.Parent then
            cleanupPlayer(survivor)
        end
    end
end

-- Jump system
local function enableJump()
    jumpEnabled = true
    if not jumpConnection then
        jumpConnection = RunService.Heartbeat:Connect(function()
            if jumpEnabled then
                pcall(function()
                    local lp = game:GetService("Players").LocalPlayer
                    local h
                    for _, g in {"Survivors", "Killers"} do
                        local playersGroup = workspace:FindFirstChild("Players")
                        if playersGroup then
                            local group = playersGroup:FindFirstChild(g)
                            if group then
                                for _, m in ipairs(group:GetChildren()) do
                                    if m:GetAttribute("Username") == lp.Name then
                                        h = m:FindFirstChildOfClass("Humanoid")
                                        break
                                    end
                                end
                            end
                        end
                        if h then break end
                    end
                    h = h or lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                    if h then
                        h.JumpHeight = 7.2
                        h.JumpPower = 50
                    end
                end)
            end
        end)
    end
end

local function disableJump()
    jumpEnabled = false
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        local h
        for _, g in {"Survivors", "Killers"} do
            local playersGroup = workspace:FindFirstChild("Players")
            if playersGroup then
                local group = playersGroup:FindFirstChild(g)
                if group then
                    for _, m in ipairs(group:GetChildren()) do
                        if m:GetAttribute("Username") == lp.Name then
                            h = m:FindFirstChildOfClass("Humanoid")
                            break
                        end
                    end
                end
            end
            if h then break end
        end
        h = h or lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        if h then
            h.JumpHeight = 0
            h.JumpPower = 0
        end
    end)
end

-- Simple stamina system with continuous loop
local function spoofSprint()
    staminaEnabled = true
    
    -- Start continuous loop
    if not staminaConnection then
        staminaConnection = task.spawn(function()
            while staminaEnabled do
                pcall(function()
                    local sprintModule = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)
                    sprintModule.StaminaLossDisabled = true
                    sprintModule.StaminaLoss = 0
                end)
                task.wait(0.1)
            end
        end)
    end
end

local function restoreOriginal()
    staminaEnabled = false
    
    -- Stop the loop
    if staminaConnection then
        task.cancel(staminaConnection)
        staminaConnection = nil
    end
    
    pcall(function()
        local sprintModule = require(game.ReplicatedStorage.Systems.Character.Game.Sprinting)
        sprintModule.StaminaLossDisabled = false
        sprintModule.StaminaLoss = 10
    end)
end

-- Generator system
local function setupGenerators()
    local success, map = pcall(function()
        return workspace:WaitForChild("Map", 5):WaitForChild("Ingame", 5):WaitForChild("Map", 5)
    end)
    if not success then return nil end
    
    local genCount = 0
    for _, obj in pairs(map:GetChildren()) do
        if obj.Name == "Generator" then
            genCount = genCount + 1
            obj.Name = "generator" .. genCount
        end
    end
    return map
end

local function getClosestGenerator()
    local success, map = pcall(function()
        return workspace:WaitForChild("Map", 5):WaitForChild("Ingame", 5):WaitForChild("Map", 5)
    end)
    if not success then return nil end
    
    local char = player.Character
    if not char then return nil end
    local torso = getTorso(char)
    if not torso then return nil end
    
    local hrp = torso.Position
    local closestGen = nil
    local closestDist = math.huge
    
    for i = 1, 5 do
        local genName = "generator"..i
        local gen = map:FindFirstChild(genName)
        if gen and gen:FindFirstChild("Remotes") and gen.Remotes:FindFirstChild("RE") then
            local genPos = gen.PrimaryPart and gen.PrimaryPart.Position or gen:GetModelCFrame().Position
            local dist = (genPos - hrp).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestGen = gen
            end
        end
    end
    return closestGen
end

local function startAutoGenerator()
    task.spawn(function()
        while autoGenEnabled do
            -- Check if Ingame folder exists and has content before starting
            local mapExists = false
            pcall(function()
                local map = workspace:FindFirstChild("Map")
                if map then
                    local ingame = map:FindFirstChild("Ingame")
                    if ingame and #ingame:GetChildren() > 0 then
                        mapExists = true
                    end
                end
            end)
            
            if mapExists then
                setupGenerators()
                local puzzleUI = player.PlayerGui:FindFirstChild("PuzzleUI")
                if puzzleUI and puzzleUI.Enabled then
                    task.wait(autoGenStepTime)
                    while autoGenEnabled and puzzleUI and puzzleUI.Enabled do
                        local closestGen = getClosestGenerator()
                        if closestGen and closestGen:FindFirstChild("Remotes") and closestGen.Remotes:FindFirstChild("RE") then
                            closestGen.Remotes.RE:FireServer()
                        end
                        task.wait(autoGenStepTime)
                        puzzleUI = player.PlayerGui:FindFirstChild("PuzzleUI")
                    end
                else
                    task.wait(0.1)
                end
            else
                -- Wait longer if map isn't ready
                task.wait(1)
            end
        end
    end)
end

-- This method makes YOU act like a killer by setting ALL your character parts to "Killers" collision group
local function enableBypassKillerWalls()
    if bypassConnection then return end
    bypassKillerWallsEnabled = true
    bypassConnection = task.spawn(function()
        while bypassKillerWallsEnabled do
            pcall(function()
                local char = Players.LocalPlayer.Character
                if char then
                    -- Set ALL parts of YOUR character to "Killers" collision group
                    for _, part in pairs(char:GetChildren()) do
                        if part:IsA("BasePart") then
                            pcall(function() 
                                PhysicsService:SetPartCollisionGroup(part, "Killers") 
                            end)
                        end
                    end
                end
            end)
            task.wait(0.5)
        end
    end)
end

local function disableBypassKillerWalls()
    bypassKillerWallsEnabled = false
    if bypassConnection then 
        task.cancel(bypassConnection) 
        bypassConnection = nil 
    end
    
    pcall(function()
        -- Reset YOUR character's parts back to default
        local char = Players.LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    pcall(function() 
                        PhysicsService:SetPartCollisionGroup(part, "Default") 
                    end)
                end
            end
        end
    end)
end

-- Character respawn handling
local function onCharacterAdded(character)
    character:WaitForChild("HumanoidRootPart")
    -- Clear old ESP lines
    for _, line in pairs(beamFolder:GetChildren()) do
        line:Destroy()
    end
    killerBeams = {}
    survivorBeams = {}
end

-- Connect character respawn
player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
    onCharacterAdded(player.Character)
end

-- Create Luna Window
local Window = Luna:CreateWindow({
    Name = "Silly hub Project",
    Subtitle = "Forsaken",
    LogoID = "82795327169782",
    LoadingEnabled = true,
    LoadingTitle = "Forsaken Loading...",
    LoadingSubtitle = "idkwhattoputherelol",
    ConfigSettings = {
        RootFolder = nil,
        ConfigFolder = "Silly hub Forsaken"
    },
    KeySystem = false,
    Watermark = "Beta version"
})

-- Create Home Tab
Window:CreateHomeTab({
    SupportedExecutors = {"Autumn", "Zenith", "Wave", "AWP", "Volcano", "Velocity", "Swift", "Seliware", "Potassium", "Solara", "Bunni", "Xeno", "Sirhurt", "Lovreware", "Hydrogen", "Macsploit", "Synapse", "Script-Ware", "Krnl", "Fluxus", "Delta", "Electron", "JJSploit", "WeAreDevs", "Trigon", "Nihon", "Calamari", "ProtoSmasher", "Sentinel"},
    DiscordInvite = "ZEWJGgsP7e",
    Icon = 1
})

-- Create Main Tab
local Tab = Window:CreateTab({
    Name = "Main Features",
    Icon = "settings",
    ImageSource = "Material",
    ShowTitle = true
})

-- Announcement Section
local AnnouncementParagraph = Tab:CreateParagraph({
    Title = "🔥 BIG ANNOUNCEMENT 🔥",
    Text = "AFK FARMING IS COMING SOON! Stay tuned for updates and new features!"
})

-- Discord Button
local DiscordButton = Tab:CreateButton({
    Name = "Discord Server",
    Description = "auto copies the server invite to your clipboard. also join so u can suggest me ideas for new features and possibly a new game if i feel like it and yeah ofc for help",
    Callback = function()
        setclipboard("https://discord.gg/ZEWJGgsP7e")
    end
})

-- Infinite Stamina Toggle
local StaminaToggle = Tab:CreateToggle({
    Name = "Infinite Stamina",
    Description = "run forever without getting tired or slowing down",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            spoofSprint()
        else
            restoreOriginal()
        end
    end
}, "InfiniteSprint")

local GenToggle = Tab:CreateToggle({
    Name = "Auto Complete Generator Steps",
    Description = "automatically completes generator repair puzzles for you",
    CurrentValue = false,
    Callback = function(Value)
        autoGenEnabled = Value
        if autoGenEnabled then
            startAutoGenerator()
        end
    end
}, "AutoGenerator")

local GenSlider = Tab:CreateSlider({
    Name = "Step Interval",
    Range = {1.5, 20},
    Increment = 0.1,
    CurrentValue = 1.5,
    Callback = function(Value)
        autoGenStepTime = math.max(1.5, Value)
        if Value < 1.5 then
            GenSlider:Set(1.5)
        end
    end
}, "AutoGenStepTime")

-- Jump Toggle
local JumpToggle = Tab:CreateToggle({
    Name = "Enable Jump",
    Description = "allows you to jump and move around freely",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            enableJump()
        else
            disableJump()
        end
    end
}, "EnableJump")

-- Bypass Killer Walls Toggle
local BypassToggle = Tab:CreateToggle({
    Name = "Bypass Killer Walls",
    Description = "walk through walls that only killers can normally pass",
    CurrentValue = false,
    Callback = function(Value)
        if Value then
            enableBypassKillerWalls()
        else
            disableBypassKillerWalls()
        end
    end
}, "BypassKillerWalls")

-- ESP Section
local KillerToggle = Tab:CreateToggle({
    Name = "Highlight Killers",
    Description = "makes killers glow red and shows their health",
    CurrentValue = false,
    Callback = function(Value)
        highlightKillersEnabled = Value
        espEnabled = highlightKillersEnabled or highlightSurvivorsEnabled or highlightToolsEnabled
        
        if espEnabled and not highlightConnection then
            highlightConnection = RunService.Heartbeat:Connect(function()
                pcall(updateESP)
            end)
        elseif not espEnabled and highlightConnection then
            highlightConnection:Disconnect()
            highlightConnection = nil
            -- Clean up all ESP
            for killer, _ in pairs(killerHighlights) do
                cleanupPlayer(killer)
            end
            for survivor, _ in pairs(survivorHighlights) do
                cleanupPlayer(survivor)
            end
            cleanupAllTools()
            killerHighlights = {}
            survivorHighlights = {}
        end
    end
}, "HighlightKillers")

local SurvivorToggle = Tab:CreateToggle({
    Name = "Highlight Survivors",
    Description = "makes survivors glow blue and shows their health",
    CurrentValue = false,
    Callback = function(Value)
        highlightSurvivorsEnabled = Value
        espEnabled = highlightKillersEnabled or highlightSurvivorsEnabled or highlightToolsEnabled
        
        if espEnabled and not highlightConnection then
            highlightConnection = RunService.Heartbeat:Connect(function()
                pcall(updateESP)
            end)
        elseif not espEnabled and highlightConnection then
            highlightConnection:Disconnect()
            highlightConnection = nil
            -- Clean up all ESP
            for killer, _ in pairs(killerHighlights) do
                cleanupPlayer(killer)
            end
            for survivor, _ in pairs(survivorHighlights) do
                cleanupPlayer(survivor)
            end
            cleanupAllTools()
            killerHighlights = {}
            survivorHighlights = {}
        end
    end
}, "HighlightSurvivors")

local ESPToggle = Tab:CreateToggle({
    Name = "Enable ESP Lines",
    Description = "draws colored lines connecting you to all players",
    CurrentValue = false,
    Callback = function(Value)
        espLinesEnabled = Value
        if not espLinesEnabled then
            -- Clean up all ESP lines
            for _, line in pairs(beamFolder:GetChildren()) do
                line:Destroy()
            end
            killerBeams = {}
            survivorBeams = {}
        end
    end
}, "ESPLines")

local ToolToggle = Tab:CreateToggle({
    Name = "Highlight Items",
    Description = "makes important items glow so you can find them easily",
    CurrentValue = false,
    Callback = function(Value)
        highlightToolsEnabled = Value
        espEnabled = highlightKillersEnabled or highlightSurvivorsEnabled or highlightToolsEnabled
        
        if espEnabled and not highlightConnection then
            highlightConnection = RunService.Heartbeat:Connect(function()
                pcall(updateESP)
            end)
        elseif not espEnabled and highlightConnection then
            highlightConnection:Disconnect()
            highlightConnection = nil
            -- Clean up all ESP
            for killer, _ in pairs(killerHighlights) do
                cleanupPlayer(killer)
            end
            for survivor, _ in pairs(survivorHighlights) do
                cleanupPlayer(survivor)
            end
            cleanupAllTools()
            killerHighlights = {}
            survivorHighlights = {}
        end
        
        -- IMMEDIATE CLEANUP WHEN DISABLING TOOLS
        if not Value then
            cleanupAllTools()
        end
    end
}, "HighlightTools")

-- Cleanup on disconnect
player.AncestryChanged:Connect(function()
    restoreOriginal()
    autoGenEnabled = false
    espEnabled = false
    disableBypassKillerWalls()
    
    if highlightConnection then 
        highlightConnection:Disconnect() 
        highlightConnection = nil
    end
    
    if jumpConnection then
        jumpConnection:Disconnect()
        jumpConnection = nil
    end
    
    if bypassConnection then
        task.cancel(bypassConnection)
        bypassConnection = nil
    end
    
    -- Clean up all ESP elements
    for killer, _ in pairs(killerHighlights) do
        cleanupPlayer(killer)
    end
    for survivor, _ in pairs(survivorHighlights) do
        cleanupPlayer(survivor)
    end
    cleanupAllTools()
    
    if beamFolder then beamFolder:Destroy() end
    
    -- Clear all tracking tables
    killerHighlights = {}
    survivorHighlights = {}
    toolHighlights = {}
    killerBeams = {}
    survivorBeams = {}
    healthDisplays = {}
end)

setupGenerators()

Luna:LoadAutoloadConfig()
