local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:wait()
local humanoid = char:WaitForChild("Humanoid")
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local ts = game:GetService("TweenService")
local ws = workspace
local cg = game:GetService("CoreGui")
local rep = game:GetService("ReplicatedStorage")
local cam = ws.CurrentCamera
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- ==================== إعدادات Folks Hub الأساسية ====================
local jumpHeightBR = 23
local jumpSpeedBR = 120
local brainrotEnabled = true
local infinityJumpEnabled = false
local jumpForce = 50
local clampFallSpeed = 80

local NORMAL_SPEED = 60
local CARRY_SPEED = 30
local FOV_VALUE = 70
local isMobile = uis.TouchEnabled
local UI_SCALE = isMobile and 0.8 or 1.0
local speedToggled = false
local autoBatToggled = false
local hittingCooldown = false

-- ==================== إعدادات Keybinds من Folks Hub ====================
local Keybinds = {
    AutoBat = Enum.KeyCode.E,
    SpeedToggle = Enum.KeyCode.Q,
    AutoLeft = Enum.KeyCode.Z,
    AutoRight = Enum.KeyCode.C,
    InfiniteJump = Enum.KeyCode.M,
    UIToggle = Enum.KeyCode.U,
    Float = Enum.KeyCode.F
}

-- ==================== إعدادات السرقة التلقائية ====================
local Values = {
    STEAL_RADIUS = 12,
    STEAL_DURATION = 1,
    DEFAULT_GRAVITY = 196.2,
    GalaxyGravityPercent = 70,
    HOP_POWER = 35,
    HOP_COOLDOWN = 0.01,
}

-- ==================== المتغيرات العامة ====================
local speed55 = false
local speedSteal = false
local spinbot = false
local autograb = false
local xrayon = false
local antirag = false
local floaton = false
local infjump = false
local AutoLeftEnabled = false
local AutoRightEnabled = false
local autoBatToggled = false

local target = nil
local floatConn = nil
local floatSpeed = 56.1
local vertSpeed = 35

local xrayOg = {}
local xrayConns = {}
local conns = {}

-- متغيرات السرقة التلقائية المتقدمة
local AnimalsData = nil
local animalCache = {}
local promptMem = {}
local stealMem = {}
local lastUid = nil
local radius = 150
local stealing = false
local stealProg = 0
local curTarget = nil
local stealStart = 0
local stealConn = nil
local grabUI = nil
local progBar = nil

-- متغيرات Auto Left/Right
local POSITION_L1 = Vector3.new(-476.48, -6.28,  92.73)
local POSITION_L2 = Vector3.new(-483.12, -4.95,  94.80)
local POSITION_R1 = Vector3.new(-476.16, -6.52,  25.62)
local POSITION_R2 = Vector3.new(-483.04, -5.09,  23.14)
local autoLeftPhase = 1
local autoRightPhase = 1
local autoLeftConnection = nil
local autoRightConnection = nil

-- ==================== دوال Folks Hub (Anti Ragdoll متطور) ====================
local anti = {}
local antiMode = nil
local ragConns = {}
local charCache = {}

local blocked = {
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.Dead] = true
}

local function cacheChar()
    local c = player.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return false end
    charCache = {
        char = c,
        hum = h,
        root = r
    }
    return true
end

local function killConns()
    for _, c in pairs(ragConns) do
        pcall(function() c:Disconnect() end)
    end
    ragConns = {}
end

local function isRagdoll()
    if not charCache.hum then return false end
    local s = charCache.hum:GetState()
    if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then
        return true
    end
    local et = player:GetAttribute("RagdollEndTime")
    if et then
        local n = ws:GetServerTimeNow()
        if (et - n) > 0 then
            return true
        end
    end
    return false
end

local function removeCons()
    if not charCache.char then return end
    for _, d in pairs(charCache.char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and string.find(d.Name, "RagdollAttachment")) then
            pcall(function() d:Destroy() end)
        end
    end
end

local function forceExit()
    if not charCache.hum or not charCache.root then return end
    pcall(function()
        player:SetAttribute("RagdollEndTime", ws:GetServerTimeNow())
    end)
    if charCache.hum.Health > 0 then
        charCache.hum:ChangeState(Enum.HumanoidStateType.Running)
    end
    charCache.root.Anchored = false
    charCache.root.AssemblyLinearVelocity = Vector3.zero
end

local function antiLoop()
    while antiMode == "v1" and charCache.hum do
        task.wait()
        if isRagdoll() then
            removeCons()
            forceExit()
        end
    end
end

local function setupCam()
    if not charCache.hum then return end
    table.insert(ragConns, rs.RenderStepped:Connect(function()
        if antiMode ~= "v1" then return end
        local c = ws.CurrentCamera
        if c and charCache.hum and c.CameraSubject ~= charCache.hum then
            c.CameraSubject = charCache.hum
        end
    end))
end

local function onChar(c)
    task.wait(0.5)
    if not antiMode then return end
    if cacheChar() then
        if antiMode == "v1" then
            setupCam()
            task.spawn(antiLoop)
        end
    end
end

function anti.Enable(m)
    if m ~= "v1" then return end
    if antiMode == m then return end
    anti.Disable()
    if not cacheChar() then return end
    antiMode = m
    table.insert(ragConns, player.CharacterAdded:Connect(onChar))
    setupCam()
    task.spawn(antiLoop)
end

function anti.Disable()
    if not antiMode then return end
    antiMode = nil
    killConns()
    charCache = {}
end

-- ==================== Spinbot محسن ====================
local function spinOn(c)
    local hrp = c:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    for _, v in pairs(hrp:GetChildren()) do
        if v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end
    local bv = Instance.new("BodyAngularVelocity")
    bv.MaxTorque = Vector3.new(0, math.huge, 0)
    bv.AngularVelocity = Vector3.new(0, 40, 0)
    bv.Parent = hrp
end

local function spinOff(c)
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in pairs(hrp:GetChildren()) do
                if v:IsA("BodyAngularVelocity") then
                    v:Destroy()
                end
            end
        end
    end
end

-- ==================== دوال Auto Left/Right ====================
local function faceSouth()
    local c = player.Character
    if not c then return end
    local rp = c:FindFirstChild("HumanoidRootPart")
    if not rp then return end
    rp.CFrame = CFrame.new(rp.Position) * CFrame.Angles(0, 0, 0)
end

local function faceNorth()
    local c = player.Character
    if not c then return end
    local rp = c:FindFirstChild("HumanoidRootPart")
    if not rp then return end
    rp.CFrame = CFrame.new(rp.Position) * CFrame.Angles(0, math.rad(180), 0)
end

local function setCarryMode(state)
    speedToggled = state
end

local function startAutoLeft()
    if autoLeftConnection then autoLeftConnection:Disconnect() end
    autoLeftPhase = 1
    autoLeftConnection = rs.Heartbeat:Connect(function()
        if not AutoLeftEnabled then return end
        local c = player.Character
        if not c then return end
        local rp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not rp or not hum then return end
        local spd = NORMAL_SPEED
        if autoLeftPhase == 1 then
            local tgt = Vector3.new(POSITION_L1.X, rp.Position.Y, POSITION_L1.Z)
            if (tgt - rp.Position).Magnitude < 1 then
                autoLeftPhase = 2
                setCarryMode(true)
                local d = (POSITION_L2 - rp.Position)
                local mv = Vector3.new(d.X, 0, d.Z).Unit
                hum:Move(mv, false)
                rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = (POSITION_L1 - rp.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif autoLeftPhase == 2 then
            local tgt = Vector3.new(POSITION_L2.X, rp.Position.Y, POSITION_L2.Z)
            if (tgt - rp.Position).Magnitude < 1 then
                hum:Move(Vector3.zero, false)
                rp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                AutoLeftEnabled = false
                if autoLeftConnection then autoLeftConnection:Disconnect() autoLeftConnection = nil end
                autoLeftPhase = 1
                faceSouth()
                return
            end
            local d = (POSITION_L2 - rp.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
        end
    end)
end

local function stopAutoLeft()
    if autoLeftConnection then autoLeftConnection:Disconnect() autoLeftConnection = nil end
    autoLeftPhase = 1
    local c = player.Character
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
    end
end

local function startAutoRight()
    if autoRightConnection then autoRightConnection:Disconnect() end
    autoRightPhase = 1
    autoRightConnection = rs.Heartbeat:Connect(function()
        if not AutoRightEnabled then return end
        local c = player.Character
        if not c then return end
        local rp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not rp or not hum then return end
        local spd = NORMAL_SPEED
        if autoRightPhase == 1 then
            local tgt = Vector3.new(POSITION_R1.X, rp.Position.Y, POSITION_R1.Z)
            if (tgt - rp.Position).Magnitude < 1 then
                autoRightPhase = 2
                setCarryMode(true)
                local d = (POSITION_R2 - rp.Position)
                local mv = Vector3.new(d.X, 0, d.Z).Unit
                hum:Move(mv, false)
                rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = (POSITION_R1 - rp.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif autoRightPhase == 2 then
            local tgt = Vector3.new(POSITION_R2.X, rp.Position.Y, POSITION_R2.Z)
            if (tgt - rp.Position).Magnitude < 1 then
                hum:Move(Vector3.zero, false)
                rp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                AutoRightEnabled = false
                if autoRightConnection then autoRightConnection:Disconnect() autoRightConnection = nil end
                autoRightPhase = 1
                faceNorth()
                return
            end
            local d = (POSITION_R2 - rp.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum:Move(mv, false)
            rp.AssemblyLinearVelocity = Vector3.new(mv.X * spd, rp.AssemblyLinearVelocity.Y, mv.Z * spd)
        end
    end)
end

local function stopAutoRight()
    if autoRightConnection then autoRightConnection:Disconnect() autoRightConnection = nil end
    autoRightPhase = 1
    local c = player.Character
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then hum:Move(Vector3.zero, false) end
    end
end

-- ==================== دوال Auto Bat المتقدمة ====================
local function getBat()
    local c = player.Character
    if not c then return nil end
    local tool = c:FindFirstChild("Bat")
    if tool then return tool end
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        tool = backpack:FindFirstChild("Bat")
        if tool then
            tool.Parent = c
            return tool
        end
    end
    return nil
end

local SAFE_DELAY = 0.08

local function tryHitBat()
    if hittingCooldown then return end
    hittingCooldown = true
    local bat = getBat()
    if bat then
        pcall(function()
            bat:Activate()
            local evt = bat:FindFirstChildWhichIsA("RemoteEvent")
            if evt then evt:FireServer() end
        end)
    end
    task.delay(SAFE_DELAY, function() hittingCooldown = false end)
end

local function getClosestPlayer()
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, math.huge end
    local closestPlayer = nil
    local closestDist = math.huge
    for _, plr in pairs(game.Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP = plr.Character.HumanoidRootPart
            local dist = (hrp.Position - targetHRP.Position).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPlayer = plr
            end
        end
    end
    return closestPlayer, closestDist
end

local function flyToFrontOfTarget(targetHRP, hrp)
    if not hrp then return end
    local forward = targetHRP.CFrame.LookVector
    local frontPos = targetHRP.Position + (forward * 2)
    local direction = (frontPos - hrp.Position).Unit
    hrp.Velocity = Vector3.new(direction.X * 57.5, direction.Y * 57.5, direction.Z * 57.5)
end

-- ==================== دوال X-Ray ====================
local function isXrayTarget(obj)
    if not (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation")) then
        return false
    end
    local n = obj.Name:lower()
    local p = obj.Parent and obj.Parent.Name:lower() or ""
    return string.find(n, "base") or string.find(n, "claim") or string.find(p, "base") or string.find(p, "claim") or string.find(n, "plot")
end

local function xrayToggle(e)
    xrayon = e
    if e then
        for _, c in pairs(xrayConns) do
            if c then c:Disconnect() end
        end
        xrayConns = {}
        xrayOg = {}
        for _, o in pairs(ws:GetDescendants()) do
            if isXrayTarget(o) then
                xrayOg[o] = o.LocalTransparencyModifier
                o.LocalTransparencyModifier = 0.7
            end
        end
        table.insert(xrayConns, ws.DescendantAdded:Connect(function(o)
            if isXrayTarget(o) then
                xrayOg[o] = o.LocalTransparencyModifier
                o.LocalTransparencyModifier = 0.7
            end
        end))
        table.insert(xrayConns, player.CharacterAdded:Connect(function()
            task.wait(0.5)
            for _, o in pairs(ws:GetDescendants()) do
                if isXrayTarget(o) then
                    if not xrayOg[o] then
                        xrayOg[o] = o.LocalTransparencyModifier
                    end
                    o.LocalTransparencyModifier = 0.7
                end
            end
        end))
    else
        for o, t in pairs(xrayOg) do
            if o and o.Parent then
                pcall(function() o.LocalTransparencyModifier = t end)
            end
        end
        for _, c in pairs(xrayConns) do
            if c then c:Disconnect() end
        end
        xrayConns = {}
        xrayOg = {}
    end
end

-- ==================== دوال Float المتقدمة ====================
local floatForce = nil
local floatAttachment = nil
local floatHeight = 10
local cachedMass = 0
local lastMassUpdate = 0

local function setupFloatForce()
    pcall(function()
        local c = player.Character
        if not c then return end
        local rp = c:FindFirstChild("HumanoidRootPart")
        if not rp then return end
        if floatForce then floatForce:Destroy() floatForce = nil end
        if floatAttachment then floatAttachment:Destroy() floatAttachment = nil end
        floatAttachment = Instance.new("Attachment")
        floatAttachment.Parent = rp
        floatForce = Instance.new("VectorForce")
        floatForce.Attachment0 = floatAttachment
        floatForce.ApplyAtCenterOfMass = true
        floatForce.RelativeTo = Enum.ActuatorRelativeTo.World
        floatForce.Force = Vector3.new(0, 0, 0)
        floatForce.Parent = rp
    end)
end

local function startFloat()
    floaton = true
    setupFloatForce()
    cachedMass = 0
    lastMassUpdate = 0
    
    if floatConn then floatConn:Disconnect() end
    floatConn = rs.Heartbeat:Connect(function(dt)
        if not floaton then return end
        pcall(function()
            local c = player.Character
            if not c then return end
            local rp = c:FindFirstChild("HumanoidRootPart")
            if not rp then return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            
            local now = tick()
            if now - lastMassUpdate > 2 or cachedMass == 0 then
                cachedMass = 0
                for _, p in pairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        cachedMass = cachedMass + p:GetMass()
                    end
                end
                lastMassUpdate = now
            end
            
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {c}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local result = ws:Raycast(rp.Position, Vector3.new(0, -500, 0), rayParams)
            local groundY = result and result.Position.Y or (rp.Position.Y - floatHeight)
            local targetY = groundY + floatHeight
            local diff = targetY - rp.Position.Y
            
            local kP = 500
            local kD = 80
            local velY = rp.AssemblyLinearVelocity.Y
            
            if math.abs(diff) < 0.1 and math.abs(velY) < 0.5 then
                diff = 0
                velY = 0
            end
            
            if floatForce then
                floatForce.Force = Vector3.new(0, cachedMass * (kP * diff - kD * velY + workspace.Gravity), 0)
            end
            hum.JumpPower = 0
        end)
    end)
end

local function stopFloat()
    floaton = false
    if floatConn then
        floatConn:Disconnect()
        floatConn = nil
    end
    if floatForce then
        floatForce:Destroy()
        floatForce = nil
    end
    if floatAttachment then
        floatAttachment:Destroy()
        floatAttachment = nil
    end
    pcall(function()
        local c = player.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local rp = c:FindFirstChild("HumanoidRootPart")
        if not rp then return end
        hum.JumpPower = 50
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = {c}
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local result = ws:Raycast(rp.Position, Vector3.new(0, -500, 0), rayParams)
        if result then
            rp.CFrame = CFrame.new(rp.Position.X, result.Position.Y + rp.Size.Y/2 + 0.1, rp.Position.Z)
            rp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end)
end

-- ==================== دوال السرقة التلقائية المتقدمة (Auto Grab) ====================
local function hrp()
    local c = player.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso")
end

local function isMyBase(n)
    local p = ws.Plots:FindFirstChild(n)
    if not p then return false end
    local s = p:FindFirstChild("PlotSign")
    if s then
        local y = s:FindFirstChild("YourBase")
        if y and y:IsA("BillboardGui") then
            return y.Enabled == true
        end
    end
    return false
end

local function scanPlot(p)
    if not p or not p:IsA("Model") then return end
    if isMyBase(p.Name) then return end
    local pods = p:FindFirstChild("AnimalPodiums")
    if not pods then return end
    for _, pod in pairs(pods:GetChildren()) do
        if pod:IsA("Model") and pod:FindFirstChild("Base") then
            local name = "Unknown"
            local spawn = pod.Base:FindFirstChild("Spawn")
            if spawn then
                for _, c in pairs(spawn:GetChildren()) do
                    if c:IsA("Model") and c.Name ~= "PromptAttachment" then
                        name = c.Name
                        if AnimalsData and AnimalsData[name] and AnimalsData[name].DisplayName then
                            name = AnimalsData[name].DisplayName
                        end
                        break
                    end
                end
            end
            table.insert(animalCache, {
                name = name,
                plot = p.Name,
                slot = pod.Name,
                pos = pod:GetPivot().Position,
                uid = p.Name .. "_" .. pod.Name,
            })
        end
    end
end

local function setupScanner()
    task.wait(2)
    local plots = ws:WaitForChild("Plots", 10)
    if not plots then return end
    for _, p in pairs(plots:GetChildren()) do
        if p:IsA("Model") then
            scanPlot(p)
        end
    end
    plots.ChildAdded:Connect(function(p)
        if p:IsA("Model") then
            task.wait(0.5)
            scanPlot(p)
        end
    end)
    task.spawn(function()
        while task.wait(5) do
            if autograb then
                animalCache = {}
                for _, p in pairs(plots:GetChildren()) do
                    if p:IsA("Model") then
                        scanPlot(p)
                    end
                end
            end
        end
    end)
end

local function findPrompt(d)
    if not d then return nil end
    local cached = promptMem[d.uid]
    if cached and cached.Parent then
        return cached
    end
    local p = ws.Plots:FindFirstChild(d.plot)
    if not p then return nil end
    local pods = p:FindFirstChild("AnimalPodiums")
    if not pods then return nil end
    local pod = pods:FindFirstChild(d.slot)
    if not pod then return nil end
    local b = pod:FindFirstChild("Base")
    if not b then return nil end
    local s = b:FindFirstChild("Spawn")
    if not s then return nil end
    local a = s:FindFirstChild("PromptAttachment")
    if not a then return nil end
    for _, pr in pairs(a:GetChildren()) do
        if pr:IsA("ProximityPrompt") then
            promptMem[d.uid] = pr
            return pr
        end
    end
    return nil
end

local function shouldSteal(d)
    if not d or not d.pos then return false end
    local h = hrp()
    if not h then return false end
    return (h.Position - d.pos).Magnitude <= radius
end

local function getNearest()
    local h = hrp()
    if not h then return nil end
    local n = nil
    local md = math.huge
    for _, d in pairs(animalCache) do
        if not isMyBase(d.plot) and d.pos then
            local dist = (h.Position - d.pos).Magnitude
            if dist < md then
                md = dist
                n = d
            end
        end
    end
    return n
end

local function buildCallbacks(p)
    if stealMem[p] then return end
    local data = {hold = {}, trig = {}, ready = true}
    local ok, c = pcall(getconnections, p.PromptButtonHoldBegan)
    if ok and type(c) == "table" then
        for _, con in pairs(c) do
            if type(con.Function) == "function" then
                table.insert(data.hold, con.Function)
            end
        end
    end
    local ok2, c2 = pcall(getconnections, p.Triggered)
    if ok2 and type(c2) == "table" then
        for _, con in pairs(c2) do
            if type(con.Function) == "function" then
                table.insert(data.trig, con.Function)
            end
        end
    end
    if #data.hold > 0 or #data.trig > 0 then
        stealMem[p] = data
    end
end

local function doSteal(p, d)
    local data = stealMem[p]
    if not data or not data.ready then return false end
    data.ready = false
    stealing = true
    stealProg = 0
    curTarget = d
    stealStart = tick()
    task.spawn(function()
        if #data.hold > 0 then
            for _, fn in pairs(data.hold) do
                task.spawn(fn)
            end
        end
        local st = tick()
        while tick() - st < Values.STEAL_DURATION do
            stealProg = (tick() - st) / Values.STEAL_DURATION
            task.wait(0.05)
        end
        stealProg = 1
        if #data.trig > 0 then
            for _, fn in pairs(data.trig) do
                task.spawn(fn)
            end
        end
        pcall(function() p:InputHoldEnded() end)
        task.wait(0.1)
        data.ready = true
        task.wait(0.3)
        stealing = false
        stealProg = 0
        curTarget = nil
    end)
    return true
end

local function attemptSteal(p, d)
    if not p or not p.Parent then return false end
    buildCallbacks(p)
    if not stealMem[p] then return false end
    return doSteal(p, d)
end

local function setupGrabUI()
    if grabUI and grabUI.Parent then
        grabUI:Destroy()
    end
    grabUI = Instance.new("ScreenGui")
    grabUI.Name = "GrabUI"
    grabUI.ResetOnSpawn = false
    grabUI.Parent = player:WaitForChild("PlayerGui")
    
    local m = Instance.new("Frame")
    m.Size = UDim2.new(0, 280, 0, 24)
    m.Position = UDim2.new(0.5, -140, 1, -100)
    m.BackgroundColor3 = Color3.fromRGB(15, 0, 35)
    m.BackgroundTransparency = 0.15
    m.BorderSizePixel = 0
    m.Parent = grabUI
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = m
    
    local s = Instance.new("UIStroke")
    s.Thickness = 1.5
    s.Color = Color3.fromRGB(170, 0, 255)
    s.Transparency = 0.1
    s.Parent = m
    
    local pb = Instance.new("Frame")
    pb.Size = UDim2.new(0.92, 0, 0, 10)
    pb.Position = UDim2.new(0.04, 0, 0.5, -5)
    pb.BackgroundColor3 = Color3.fromRGB(30, 0, 60)
    pb.BackgroundTransparency = 0.3
    pb.BorderSizePixel = 0
    pb.Parent = m
    
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = pb
    
    progBar = Instance.new("Frame")
    progBar.Size = UDim2.new(0, 0, 1, 0)
    progBar.BackgroundColor3 = Color3.fromRGB(200, 0, 255)
    progBar.BorderSizePixel = 0
    progBar.Parent = pb
    
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = progBar
end

local function startGrab()
    autograb = true
    setupGrabUI()
    setupScanner()
    if stealConn then stealConn:Disconnect() end
    stealConn = rs.Heartbeat:Connect(function()
        if not autograb then return end
        if stealing then return end
        local tar = getNearest()
        if not tar then return end
        if not shouldSteal(tar) then return end
        if lastUid ~= tar.uid then
            lastUid = tar.uid
        end
        local p = promptMem[tar.uid]
        if not p or not p.Parent then
            p = findPrompt(tar)
        end
        if p then
            attemptSteal(p, tar)
        end
    end)
end

local function stopGrab()
    autograb = false
    if stealConn then
        stealConn:Disconnect()
        stealConn = nil
    end
    if grabUI then
        grabUI:Destroy()
        grabUI = nil
    end
    progBar = nil
    animalCache = {}
    promptMem = {}
    stealMem = {}
end

-- ==================== دوال السرعة و القفز ====================
-- القفز اللانهائي (نسخة Folks Hub)
uis.JumpRequest:Connect(function()
    if infjump and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, jumpForce, hrp.AssemblyLinearVelocity.Z)
    end
end)

-- منع السرعة السلبية للقفز
rs.Heartbeat:Connect(function()
    if not infjump then return end
    local c = player.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if hrp and hrp.Velocity.Y < -clampFallSpeed then
        hrp.Velocity = Vector3.new(hrp.Velocity.X, -clampFallSpeed, hrp.Velocity.Z)
    end
end)

-- السرعة (نسخة Folks Hub)
rs.Heartbeat:Connect(function()
    local c = player.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    
    if h.MoveDirection.Magnitude > 0 then
        local vel = speedToggled and CARRY_SPEED or (speed55 and NORMAL_SPEED) or 0
        if vel > 0 then
            r.AssemblyLinearVelocity = Vector3.new(h.MoveDirection.X * vel,