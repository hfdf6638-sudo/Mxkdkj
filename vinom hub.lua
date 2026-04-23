-- leaked by https://discord.gg/WfTDsBPR9n join for more sources


local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIGURATION
-- ============================================================
local Config = {
    SpeedBoostEnabled = false,
    SpeedBoost = 59,
    SpeedBoostKey = Enum.KeyCode.Q,
    
    SpeedBoost2Enabled = false,
    SpeedBoost2 = 29,
    SpeedBoost2Key = Enum.KeyCode.E,
    
    AutoRight = false,
    AutoRightKey = Enum.KeyCode.R,
    AutoLeft = false,
    AutoLeftKey = Enum.KeyCode.F,
    
    TrackPlayerEnabled = false,
    TrackPlayerKey = Enum.KeyCode.X,
    TrackSpeed = 55,
    TrackDistance = 1.5,
    
    Unwalk = false,
    
    JumpPowerEnabled = false,
    JumpPower = 70,
    
    GravityEnabled = false,
    Gravity = 50,
    
    -- Anti Ragdoll
    AntiRagdollEnabled = false,
    
    -- Galaxy Mode
    GalaxyEnabled = false,
    GalaxyGravityPercent = 70,
    GalaxyKey = Enum.KeyCode.Z,
    
    -- Auto Grab
    AutoGrabEnabled = false,
    AutoGrabRadius = 35,
}

-- ============================================================
-- VARIABLES
-- ============================================================
local ScreenGui = nil
local IsListeningForKey = false
local CurrentKeybindSetting = nil
local IsShuttingDown = false

-- Speed Boost
local SpeedBoost1Connection = nil
local SpeedBoost2Connection = nil

-- AUTO GRAB
local AutoGrabConnection = nil
local AutoGrabScanThread = nil
local SpamToggleThread = nil
local CachedGrabbables = {}
local GRAB_COOLDOWN = 0.001
local lastGrabTick = 0

-- GUI Auto Grab
local AutoGrabGUI = nil
local pulseConn = nil

-- Variables Auto Walk
local AutoWalkConnection = nil
local currentWaypointIndex = 1
local waypoints = {}
local isAutoWalking = false
local isReturning = false
local isPaused = false
local inEnemyBase = false
local HasBrainrotInHand = false
local BrainrotDetectionConnection = nil
local OriginalCameraZoom = nil
local OriginalCameraMaxZoom = nil

-- Variables Track Player
local TrackPlayerConnection = nil
local TrackTargetPlayer = nil
local TrackPlayerGUI = nil
local TrackPlayerGUIVisible = false

-- Unwalk
local UnwalkConnection = nil

-- Jump & Gravity
local OriginalJumpPower = nil
local GravityController = {
    Attachment = nil,
    VectorForce = nil,
    Connection = nil
}

-- GALAXY MODE
local galaxyVectorForce = nil
local galaxyAttachment = nil
local galaxyEnabled = false
local hopsEnabled = false
local lastHopTime = 0
local spaceHeld = false
local originalJumpPower = 50
local DEFAULT_GRAVITY = 196.2
local HOP_POWER = 35
local HOP_COOLDOWN = 0.08

-- ANTI RAGDOLL
local AntiRagdollConnection = nil

-- Bouton Galaxy
local GalaxyKeyBtn = nil

-- Positions exactes des poses brainrot
local BRAINROT_POSITIONS = {
    Vector3.new(-485.50, -6.43, 96.08),
    Vector3.new(-485.30, -6.43, 22.36),
}

-- ============================================================
-- FONCTIONS DE BASE
-- ============================================================

local function safe(func, ...)
    local success, result = pcall(func, ...)
    return success and result or nil
end

local function GetCharacter() 
    if not LocalPlayer then return nil end
    return safe(function() return LocalPlayer.Character end)
end

local function GetHumanoid()
    local char = GetCharacter()
    if not char then return nil end
    return safe(function() return char:FindFirstChildOfClass("Humanoid") end)
end

local function GetRootPart()
    local char = GetCharacter()
    if not char then return nil end
    return safe(function() return char:FindFirstChild("HumanoidRootPart") end)
end

-- Capture original jump power
local function captureJumpPower()
    local c = GetCharacter()
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum and hum.JumpPower > 0 then
            originalJumpPower = hum.JumpPower
        end
    end
end

-- Capture on current character
task.spawn(function()
    task.wait(1)
    captureJumpPower()
end)

-- Recapture when character respawns
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    captureJumpPower()
end)

-- ============================================================
-- AUTO GRAB COMPLET
-- ============================================================

local function isMyBase(plotName)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            return yourBase.Enabled == true
        end
    end
    return false
end

local function ScanGrabbables()
    local results = {}

    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in ipairs(plots:GetChildren()) do
            if plot:IsA("Model") and not isMyBase(plot.Name) then
                local podiums = plot:FindFirstChild("AnimalPodiums")
                if podiums then
                    for _, podium in ipairs(podiums:GetChildren()) do
                        if podium:IsA("Model") then
                            local base   = podium:FindFirstChild("Base")
                            local spawn  = base and base:FindFirstChild("Spawn")
                            local attach = spawn and spawn:FindFirstChild("PromptAttachment")
                            if attach then
                                for _, p in ipairs(attach:GetChildren()) do
                                    if p:IsA("ProximityPrompt") then
                                        results[#results+1] = { type="prompt", prompt=p, part=base or podium }
                                    end
                                end
                            end
                        end
                    end
                end
                for _, item in ipairs(plot:GetChildren()) do
                    if item:IsA("Tool") then
                        local handle = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart")
                        if handle then
                            results[#results+1] = { type="tool", tool=item, part=handle }
                        end
                    end
                end
            end
        end
    end

    for _, folderName in ipairs({"Debris","Drops","Collectibles","DroppedItems"}) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, desc in ipairs(folder:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    results[#results+1] = { type="prompt", prompt=desc, part=desc.Parent }
                elseif desc:IsA("Tool") then
                    local handle = desc:FindFirstChild("Handle") or desc:FindFirstChildWhichIsA("BasePart")
                    if handle then results[#results+1] = { type="tool", tool=desc, part=handle } end
                end
            end
        end
    end

    for _, item in ipairs(workspace:GetChildren()) do
        if item:IsA("Tool") then
            local handle = item:FindFirstChild("Handle") or item:FindFirstChildWhichIsA("BasePart")
            if handle then results[#results+1] = { type="tool", tool=item, part=handle } end
        end
    end

    CachedGrabbables = results
end

local function StartScan()
    if AutoGrabScanThread then return end
    AutoGrabScanThread = task.spawn(function()
        while Config.AutoGrabEnabled do
            pcall(ScanGrabbables)
            task.wait(0.01)
        end
        AutoGrabScanThread = nil
    end)
end

local function TryGrab(item, humanoid)
    if item.type == "prompt" then
        if fireproximityprompt then
            fireproximityprompt(item.prompt)
        else
            item.prompt:InputHoldBegin()
            task.delay(0, function()
                if item.prompt and item.prompt.Parent then
                    item.prompt:InputHoldEnd()
                end
            end)
        end
    elseif item.type == "tool" then
        pcall(function() humanoid:EquipTool(item.tool) end)
    end
end

local function RunGrabLoop()
    if AutoGrabConnection then AutoGrabConnection:Disconnect() end

    AutoGrabConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoGrabEnabled then return end

        local rootPart = GetRootPart()
        local humanoid = GetHumanoid()
        if not rootPart or not humanoid then return end

        local now = tick()
        if now - lastGrabTick < GRAB_COOLDOWN then return end

        local myPos    = rootPart.Position
        local radius   = Config.AutoGrabRadius
        local bestDist = radius + 1
        local bestItem = nil

        for _, item in ipairs(CachedGrabbables) do
            if item.part and item.part.Parent then
                local ok, pos = pcall(function()
                    return item.part:IsA("BasePart") and item.part.Position or item.part:GetPivot().Position
                end)
                if ok and pos then
                    local dist = (pos - myPos).Magnitude
                    if dist < bestDist then
                        if item.type == "prompt" and item.prompt and item.prompt.Parent and item.prompt.Enabled then
                            bestDist = dist
                            bestItem = item
                        elseif item.type == "tool" and item.tool and item.tool.Parent then
                            bestDist = dist
                            bestItem = item
                        end
                    end
                end
            end
        end

        if bestItem then
            lastGrabTick = now
            TryGrab(bestItem, humanoid)
        end
    end)
end

local function StartSpamToggle()
    if SpamToggleThread then return end

    SpamToggleThread = task.spawn(function()
        while Config.AutoGrabEnabled do
            RunGrabLoop()
            task.wait(0.015)

            if AutoGrabConnection then
                AutoGrabConnection:Disconnect()
                AutoGrabConnection = nil
            end
            task.wait(0.005)
        end

        SpamToggleThread = nil
    end)
end

local function StopAutoGrab()
    Config.AutoGrabEnabled = false

    if SpamToggleThread then
        task.cancel(SpamToggleThread)
        SpamToggleThread = nil
    end
    if AutoGrabConnection then
        AutoGrabConnection:Disconnect()
        AutoGrabConnection = nil
    end
    if AutoGrabScanThread then
        task.cancel(AutoGrabScanThread)
        AutoGrabScanThread = nil
    end

    CachedGrabbables = {}
end

local function startPulse()
    if pulseConn then return end
    pulseConn = task.spawn(function()
        while Config.AutoGrabEnabled and AutoGrabGUI and AutoGrabGUI.statusDot and AutoGrabGUI.statusDot.Parent do
            TweenService:Create(AutoGrabGUI.statusDot, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0.5
            }):Play()
            task.wait(0.4)
            TweenService:Create(AutoGrabGUI.statusDot, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                BackgroundTransparency = 0
            }):Play()
            task.wait(0.4)
        end
        pulseConn = nil
    end)
end

local function stopPulse()
    if pulseConn then
        task.cancel(pulseConn)
        pulseConn = nil
    end
    if AutoGrabGUI and AutoGrabGUI.statusDot then
        AutoGrabGUI.statusDot.BackgroundTransparency = 0
    end
end

local function updateAutoGrabUI()
    if not AutoGrabGUI then return end
    
    if Config.AutoGrabEnabled then
        TweenService:Create(AutoGrabGUI.statusDot, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(0, 255, 0) }):Play()
        AutoGrabGUI.statusText.Text = "ACTIF"
        AutoGrabGUI.statusText.TextColor3 = Color3.fromRGB(0, 255, 0)
        AutoGrabGUI.toggleBtn.Text = "DÉSACTIVER"
        TweenService:Create(AutoGrabGUI.toggleBtn, TweenInfo.new(0.2), { BackgroundTransparency = 0.3 }):Play()
        startPulse()
    else
        stopPulse()
        TweenService:Create(AutoGrabGUI.statusDot, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(255, 0, 0) }):Play()
        AutoGrabGUI.statusText.Text = "INACTIF"
        AutoGrabGUI.statusText.TextColor3 = Color3.fromRGB(255, 255, 255)
        AutoGrabGUI.toggleBtn.Text = "ACTIVER"
        TweenService:Create(AutoGrabGUI.toggleBtn, TweenInfo.new(0.2), { BackgroundTransparency = 0.6 }):Play()
    end
end

local function SetAutoGrab(state)
    Config.AutoGrabEnabled = state
    if state then
        StartScan()
        StartSpamToggle()
    else
        StopAutoGrab()
    end
    updateAutoGrabUI()
end

-- ============================================================
-- GUI AUTO GRAB (style duel) - Blue theme
-- ============================================================
local function CreateAutoGrabGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "AutoGrabGUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Global
    sg.DisplayOrder = 999999998
    sg.Parent = playerGui

    -- Frame principal (style duel)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 120)
    frame.Position = UDim2.new(0, 30, 0.5, -60)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = sg

    -- Coins arrondis
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    -- Bordure bleue
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 100, 255)  -- Bleu principal
    stroke.Thickness = 2
    stroke.Transparency = 0.2
    stroke.Parent = frame

    -- Titre
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "AUTO GRAB"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    -- Dégradé bleu pour le titre
    local titleGrad = Instance.new("UIGradient")
    titleGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 100, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    }
    titleGrad.Parent = title

    -- Ligne de séparation
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, -20, 0, 1)
    sep.Position = UDim2.new(0, 10, 0, 40)
    sep.BackgroundColor3 = Color3.fromRGB(0, 100, 255)
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.Parent = frame

    -- Status dot
    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 10, 0, 10)
    statusDot.Position = UDim2.new(0, 15, 0, 52)
    statusDot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    statusDot.BorderSizePixel = 0
    statusDot.Parent = frame
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    -- Status text
    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -40, 0, 20)
    statusText.Position = UDim2.new(0, 30, 0, 47)
    statusText.BackgroundTransparency = 1
    statusText.Text = "INACTIF"
    statusText.Font = Enum.Font.GothamBold
    statusText.TextSize = 12
    statusText.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = frame

    -- Bouton toggle (style duel)
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, 35)
    toggleBtn.Position = UDim2.new(0, 10, 0, 75)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 70, 180)  -- Bleu foncé
    toggleBtn.BackgroundTransparency = 0.6
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "ACTIVER"
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(0, 100, 255)
    btnStroke.Thickness = 1.5
    btnStroke.Transparency = 0.5
    btnStroke.Parent = toggleBtn

    AutoGrabGUI = {
        ScreenGui = sg,
        Frame = frame,
        statusDot = statusDot,
        statusText = statusText,
        toggleBtn = toggleBtn,
        btnStroke = btnStroke,
    }

    -- Hover effects
    toggleBtn.MouseEnter:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundTransparency = 0.4 }):Play()
    end)
    toggleBtn.MouseLeave:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundTransparency = Config.AutoGrabEnabled and 0.3 or 0.6 }):Play()
    end)
    toggleBtn.MouseButton1Click:Connect(function()
        TweenService:Create(toggleBtn, TweenInfo.new(0.1), { BackgroundTransparency = 0.2 }):Play()
        task.delay(0.1, function()
            TweenService:Create(toggleBtn, TweenInfo.new(0.1), { BackgroundTransparency = Config.AutoGrabEnabled and 0.3 or 0.6 }):Play()
        end)
        SetAutoGrab(not Config.AutoGrabEnabled)
    end)

    -- Drag system
    local dragging, dragStart, frameStart = false, nil, nil

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = frame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                frameStart.X.Scale, frameStart.X.Offset + delta.X,
                frameStart.Y.Scale, frameStart.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return AutoGrabGUI
end

-- ============================================================
-- JUMP POWER
-- ============================================================
local function UpdateJumpPower()
    safe(function()
        local humanoid = GetHumanoid()
        if not humanoid then return end
        
        if Config.JumpPowerEnabled then
            if OriginalJumpPower == nil then
                OriginalJumpPower = humanoid.JumpPower
            end
            humanoid.UseJumpPower = true
            humanoid.JumpPower = Config.JumpPower
        else
            if OriginalJumpPower then
                humanoid.JumpPower = OriginalJumpPower
                OriginalJumpPower = nil
            end
        end
    end)
end

-- ============================================================
-- GRAVITY CONTROL
-- ============================================================
local function SetupGravity()
    safe(function()
        local hrp = GetRootPart()
        if not hrp then return end
        
        if GravityController.Attachment then
            GravityController.Attachment:Destroy()
            GravityController.Attachment = nil
        end
        if GravityController.VectorForce then
            GravityController.VectorForce:Destroy()
            GravityController.VectorForce = nil
        end
        if GravityController.Connection then
            GravityController.Connection:Disconnect()
            GravityController.Connection = nil
        end
        
        local attach = Instance.new("Attachment")
        attach.Name = "GravityControl_Attachment"
        attach.Parent = hrp
        GravityController.Attachment = attach
        
        local force = Instance.new("VectorForce")
        force.Name = "GravityControl_Force"
        force.Attachment0 = attach
        force.RelativeTo = Enum.ActuatorRelativeTo.World
        force.ApplyAtCenterOfMass = true
        force.Force = Vector3.new(0, 0, 0)
        force.Parent = hrp
        GravityController.VectorForce = force
    end)
end

local function StartGravity()
    if not Config.GravityEnabled then return end
    
    safe(function()
        SetupGravity()
        
        if GravityController.Connection then
            GravityController.Connection:Disconnect()
        end
        
        GravityController.Connection = RunService.RenderStepped:Connect(function()
            if IsShuttingDown or not Config.GravityEnabled or not GravityController.VectorForce then return end
            
            safe(function()
                local hrp = GetRootPart()
                if not hrp then return end
                
                local gravityStrength = Config.Gravity / 100
                local counterForce = hrp.AssemblyMass * workspace.Gravity * (1 - gravityStrength)
                GravityController.VectorForce.Force = Vector3.new(0, counterForce, 0)
            end)
        end)
    end)
end

local function StopGravity()
    safe(function()
        if GravityController.Connection then
            GravityController.Connection:Disconnect()
            GravityController.Connection = nil
        end
        if GravityController.VectorForce then
            GravityController.VectorForce.Force = Vector3.new(0, 0, 0)
        end
    end)
end

-- ============================================================
-- ANTI RAGDOLL
-- ============================================================
local function SetupAntiRagdoll()
    if AntiRagdollConnection then
        AntiRagdollConnection:Disconnect()
    end
    
    AntiRagdollConnection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown or not Config.AntiRagdollEnabled then return end
        
        safe(function()
            local char = GetCharacter()
            if not char then return end
            
            local root = char:FindFirstChild("HumanoidRootPart")
            local humanoid = GetHumanoid()
            
            if humanoid then
                local humState = humanoid:GetState()
                if humState == Enum.HumanoidStateType.Physics or 
                   humState == Enum.HumanoidStateType.Ragdoll or 
                   humState == Enum.HumanoidStateType.FallingDown then
                    
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    workspace.CurrentCamera.CameraSubject = humanoid
                    
                    pcall(function()
                        if LocalPlayer.Character then
                            local PlayerModule = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
                            if PlayerModule then
                                local Controls = require(PlayerModule:FindFirstChild("ControlModule"))
                                Controls:Enable()
                            end
                        end
                    end)
                    
                    if root then
                        root.Velocity = Vector3.new(0, 0, 0)
                        root.RotVelocity = Vector3.new(0, 0, 0)
                    end
                end
            end
            
            -- Réactiver les Motor6D désactivés
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("Motor6D") and obj.Enabled == false then
                    obj.Enabled = true
                end
            end
        end)
    end)
end

local function StopAntiRagdoll()
    if AntiRagdollConnection then
        AntiRagdollConnection:Disconnect()
        AntiRagdollConnection = nil
    end
end

-- ============================================================
-- UNWALK
-- ============================================================
local function SetupUnwalk()
    if UnwalkConnection then
        UnwalkConnection:Disconnect()
    end
    
    UnwalkConnection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown or not Config.Unwalk then return end
        
        safe(function()
            local humanoid = GetHumanoid()
            if not humanoid then return end
            
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then return end
            
            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                track:Stop()
            end
        end)
    end)
end

-- ============================================================
-- SPEED BOOST
-- ============================================================
local function ApplySpeedBoost(speedValue)
    safe(function()
        local humanoid = GetHumanoid()
        local rootPart = GetRootPart()
        if not humanoid or not rootPart then return false end
        if humanoid.MoveDirection.Magnitude > 0.1 then
            local moveDir = humanoid.MoveDirection.Unit
            if moveDir.Magnitude > 0 then
                rootPart.AssemblyLinearVelocity = Vector3.new(
                    moveDir.X * speedValue,
                    rootPart.AssemblyLinearVelocity.Y,
                    moveDir.Z * speedValue
                )
                return true
            end
        end
        return false
    end)
end

local function StartSpeedBoost1()
    if SpeedBoost1Connection then SpeedBoost1Connection:Disconnect() end
    SpeedBoost1Connection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown then return end
        if Config.SpeedBoostEnabled then ApplySpeedBoost(Config.SpeedBoost) end
    end)
end

local function StopSpeedBoost1()
    if SpeedBoost1Connection then SpeedBoost1Connection:Disconnect(); SpeedBoost1Connection = nil end
end

local function StartSpeedBoost2()
    if SpeedBoost2Connection then SpeedBoost2Connection:Disconnect() end
    SpeedBoost2Connection = RunService.Heartbeat:Connect(function()
        if IsShuttingDown then return end
        if Config.SpeedBoost2Enabled then ApplySpeedBoost(Config.SpeedBoost2) end
    end)
end

local function StopSpeedBoost2()
    if SpeedBoost2Connection then SpeedBoost2Connection:Disconnect(); SpeedBoost2Connection = nil end
end

-- ============================================================
-- GALAXY MODE
-- ============================================================
local function setupGalaxyForce()
    pcall(function()
        local c = GetCharacter()
        if not c then return end
        local h = GetRootPart()
        if not h then return end
        if galaxyVectorForce then galaxyVectorForce:Destroy() end
        if galaxyAttachment then galaxyAttachment:Destroy() end
        galaxyAttachment = Instance.new("Attachment")
        galaxyAttachment.Parent = h
        galaxyVectorForce = Instance.new("VectorForce")
        galaxyVectorForce.Attachment0 = galaxyAttachment
        galaxyVectorForce.ApplyAtCenterOfMass = true
        galaxyVectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
        galaxyVectorForce.Force = Vector3.new(0, 0, 0)
        galaxyVectorForce.Parent = h
    end)
end

local function updateGalaxyForce()
    if not Config.GalaxyEnabled or not galaxyVectorForce then return end
    local c = GetCharacter()
    if not c then return end
    local mass = 0
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then
            mass = mass + p:GetMass()
        end
    end
    local tg = DEFAULT_GRAVITY * (Config.GalaxyGravityPercent / 100)
    galaxyVectorForce.Force = Vector3.new(0, mass * (DEFAULT_GRAVITY - tg) * 0.95, 0)
end

local function adjustGalaxyJump()
    pcall(function()
        local c = GetCharacter()
        if not c then return end
        local hum = GetHumanoid()
        if not hum then return end
        if not Config.GalaxyEnabled then
            hum.JumpPower = originalJumpPower
            return
        end
        local ratio = math.sqrt((DEFAULT_GRAVITY * (Config.GalaxyGravityPercent / 100)) / DEFAULT_GRAVITY)
        hum.JumpPower = originalJumpPower * ratio
    end)
end

local function doMiniHop()
    if not Config.GalaxyEnabled then return end
    pcall(function()
        local c = GetCharacter()
        if not c then return end
        local h = GetRootPart()
        local hum = GetHumanoid()
        if not h or not hum then return end
        if tick() - lastHopTime < HOP_COOLDOWN then return end
        lastHopTime = tick()
        if hum.FloorMaterial == Enum.Material.Air then
            h.AssemblyLinearVelocity = Vector3.new(h.AssemblyLinearVelocity.X, HOP_POWER, h.AssemblyLinearVelocity.Z)
        end
    end)
end

local function StartGalaxy()
    Config.GalaxyEnabled = true
    setupGalaxyForce()
    adjustGalaxyJump()
end

local function StopGalaxy()
    Config.GalaxyEnabled = false
    if galaxyVectorForce then
        galaxyVectorForce:Destroy()
        galaxyVectorForce = nil
    end
    if galaxyAttachment then
        galaxyAttachment:Destroy()
        galaxyAttachment = nil
    end
    adjustGalaxyJump()
end

local function ToggleGalaxy(state)
    Config.GalaxyEnabled = state
    if state then
        StartGalaxy()
    else
        StopGalaxy()
    end
end

-- ============================================================
-- AUTO WALK (AUTO RIGHT / AUTO LEFT) - 3 POSITIONS EXACTES
-- ============================================================
local FORWARD_SPEED = 59
local RETURN_SPEED = 29

local RIGHT_PATH = {
    Vector3.new(-473.32, -7.67, 10.16),
    Vector3.new(-472.71, -8.14, 29.92),
    Vector3.new(-472.87, -8.14, 49.50),
    Vector3.new(-472.45, -8.14, 65.05),
    Vector3.new(-472.94, -8.14, 82.48),
    Vector3.new(-475.00, -8.14, 96.84),  
    Vector3.new(-485.50, -6.43, 96.08),
}

local LEFT_PATH = {
    Vector3.new(-473.31, -7.67, 111.75),
    Vector3.new(-473.51, -8.14, 87.30),
    Vector3.new(-473.74, -8.14, 60.58),
    Vector3.new(-474.04, -8.14, 41.38),
    Vector3.new(-474.35, -8.14, 25.77),
    Vector3.new(-485.30, -6.43, 22.36),
}

-- Chemins de retour avec 3 positions exactes
local RIGHT_RETURN_PATH_FAST = {
    Vector3.new(-475.23, -8.14, 90.61),  -- Position départ Right
    Vector3.new(-476.24, -8.14, 57.32),  -- Milieu
    Vector3.new(-475.63, -8.14, 23.36),  -- Arrivée
}

local LEFT_RETURN_PATH_FAST = {
    Vector3.new(-474.23, -8.14, 26.51),  -- Position départ Left
    Vector3.new(-475.15, -8.14, 59.32),  -- Milieu
    Vector3.new(-475.62, -8.06, 97.99),  -- Arrivée
}

local waypoints = {}
local returnWaypoints = {}
local returnWaypointIndex = 1

local function StopAutoWalk()
    if AutoWalkConnection then
        AutoWalkConnection:Disconnect()
        AutoWalkConnection = nil
    end
    waypoints = {}
    returnWaypoints = {}
    currentWaypointIndex = 1
    returnWaypointIndex = 1
    isAutoWalking = false
    isReturning = false
    isPaused = false
    
    -- Restaurer la caméra
    if OriginalCameraZoom then
        LocalPlayer.CameraMinZoomDistance = OriginalCameraZoom
        OriginalCameraZoom = nil
    end
    if OriginalCameraMaxZoom then
        LocalPlayer.CameraMaxZoomDistance = OriginalCameraMaxZoom
        OriginalCameraMaxZoom = nil
    end
    
    local humanoid = GetHumanoid()
    if humanoid then humanoid:Move(Vector3.new(0, 0, 0)) end
    
    local rootPart = GetRootPart()
    if rootPart then rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end
end

local function FindClosestWaypoint(position, waypointList)
    local closestIndex = 1
    local closestDistance = math.huge
    
    for i, waypoint in ipairs(waypointList) do
        local dist = (Vector3.new(waypoint.X, position.Y, waypoint.Z) - position).Magnitude
        if dist < closestDistance then
            closestDistance = dist
            closestIndex = i
        end
    end
    return closestIndex
end

local function StartAutoWalk(direction)
    StopAutoWalk()
    
    -- Sauvegarder les valeurs originales de la caméra