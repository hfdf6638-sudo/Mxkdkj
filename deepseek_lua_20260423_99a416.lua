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
local pp = game:GetService("ProximityPromptService")

-- ============ المتغيرات العامة ============
local speed55 = false
local speedSteal = false
local spinbot = false
local autograb = false
local xrayon = false
local antirag = false
local floaton = false
local infjump = false
local espEnabled = true
local espBaseEnabled = false
local antiTurret = false
local antiLag = false
local hitboxExpand = false
local espHitbox = false
local flyDefender = false
local duelsSpeed = false
local autoBat = false
local redDuel = false
local blueDuel = false

local target = nil
local floatConn = nil
local floatSpeed = 56.1
local vertSpeed = 35

local xrayOg = {}
local xrayConns = {}
local conns = {}
local espFolder = nil
local espConnections = {}
local baseEspThread = nil

-- ============ ANTI KICK ============
local function antiKick()
    for _, v in pairs(getconnections(player.Idled)) do
        v:Disable()
    end
    game:GetService("ScriptContext").Error:Connect(function() return end)
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    local old = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" or method == "kick" or method == "Kicked" or method == "kicked" then
            return nil
        end
        return old(self, ...)
    end)
end
antiKick()

-- ============ ANTI RAGDOLL ============
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

-- ============ SPINBOT ============
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

-- ============ X-RAY ============
local function xrayToggle(e)
    xrayon = e
    local function isBase(o)
        if not (o:IsA("BasePart") or o:IsA("MeshPart") or o:IsA("UnionOperation")) then
            return false
        end
        local n = o.Name:lower()
        local p = o.Parent and o.Parent.Name:lower() or ""
        return string.find(n, "base") or string.find(n, "claim") or string.find(p, "base") or string.find(p, "claim")
    end
    if e then
        for _, c in pairs(xrayConns) do
            if c then c:Disconnect() end
        end
        xrayConns = {}
        xrayOg = {}
        for _, o in pairs(ws:GetDescendants()) do
            if isBase(o) then
                xrayOg[o] = o.LocalTransparencyModifier
                o.LocalTransparencyModifier = 0.8
            end
        end
        table.insert(xrayConns, ws.DescendantAdded:Connect(function(o)
            if isBase(o) then
                xrayOg[o] = o.LocalTransparencyModifier
                o.LocalTransparencyModifier = 0.8
            end
        end))
        table.insert(xrayConns, player.CharacterAdded:Connect(function()
            task.wait(0.5)
            for _, o in pairs(ws:GetDescendants()) do
                if isBase(o) then
                    if not xrayOg[o] then
                        xrayOg[o] = o.LocalTransparencyModifier
                    end
                    o.LocalTransparencyModifier = 0.8
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

-- ============ PLAYER ESP ============
local function setupESP()
    espFolder = Instance.new("Folder")
    espFolder.Name = "PlayerESP"
    espFolder.Parent = cg
end

local function createESP(targetPlayer)
    if targetPlayer == player then return end
    local character = targetPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local existing = espFolder:FindFirstChild(targetPlayer.Name)
    if existing then existing:Destroy() end
    
    local box = Instance.new("BoxHandleAdornment")
    box.Name = targetPlayer.Name
    box.Adornee = rootPart
    box.Size = rootPart.Size + Vector3.new(1.5, 2.5, 1.5)
    box.Color3 = Color3.fromRGB(0, 255, 0)
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Transparency = 0.2
    box.Parent = espFolder
end

local function removeESP(targetPlayer)
    local esp = espFolder:FindFirstChild(targetPlayer.Name)
    if esp then esp:Destroy() end
end

local function enableESP()
    if espFolder then espFolder:Destroy() end
    setupESP()
    
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= player then
            if p.Character then
                createESP(p)
            end
            espConnections[p] = p.CharacterAdded:Connect(function()
                task.wait(0.1)
                createESP(p)
            end)
        end
    end
    
    espConnections.playerAdded = game.Players.PlayerAdded:Connect(function(p)
        espConnections[p] = p.CharacterAdded:Connect(function()
            task.wait(0.1)
            createESP(p)
        end)
    end)
    
    espConnections.playerRemoving = game.Players.PlayerRemoving:Connect(function(p)
        removeESP(p)
        if espConnections[p] then
            espConnections[p]:Disconnect()
            espConnections[p] = nil
        end
    end)
end

local function disableESP()
    if espFolder then
        for _, child in pairs(espFolder:GetChildren()) do
            child:Destroy()
        end
        espFolder:Destroy()
        espFolder = nil
    end
    for k, v in pairs(espConnections) do
        if typeof(v) == "RBXScriptConnection" then
            v:Disconnect()
        end
    end
    espConnections = {}
end

-- ============ BASE ESP ============
local Plots = ws:WaitForChild("Plots")

local function getOwnBasePosition()
    for _, plot in pairs(Plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        local base = plot:FindFirstChild("DeliveryHitbox")
        if sign and sign:FindFirstChild("YourBase") and sign.YourBase.Enabled and base then
            return base.Position
        end
    end
    return nil
end

local function createOrUpdatePlotESP(plot)
    local purchases = plot:FindFirstChild("Purchases")
    if not purchases then return end
    local plotBlock = purchases:FindFirstChild("PlotBlock")
    if not plotBlock or not plotBlock:FindFirstChild("Main") then return end
    local main = plotBlock.Main
    local remainingTimeGui = main:FindFirstChild("BillboardGui") and main.BillboardGui:FindFirstChild("RemainingTime")
    local base = plot:FindFirstChild("DeliveryHitbox")
    
    local ownBasePos = getOwnBasePosition()
    if base and ownBasePos and (base.Position - ownBasePos).Magnitude < 1 then return end
    
    local billboard = main:FindFirstChild("ESP_Billboard")
    local textLabel
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Billboard"
        billboard.Adornee = main
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = main
        
        textLabel = Instance.new("TextLabel")
        textLabel.Name = "Label"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextScaled = true
        textLabel.Parent = billboard
    else
        textLabel = billboard:FindFirstChild("Label")
    end
    
    if remainingTimeGui then
        if remainingTimeGui:IsA("TextLabel") then
            local text = remainingTimeGui.Text
            if text == "0s" or text == "0" then
                textLabel.Text = "Unlocked"
                textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                textLabel.Text = text
                textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        elseif remainingTimeGui:IsA("NumberValue") then
            if remainingTimeGui.Value <= 0 then
                textLabel.Text = "Unlocked"
                textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                textLabel.Text = "Time Remaining: " .. remainingTimeGui.Value .. "s"
                textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end
end

local function enableBaseESP()
    if baseEspThread then task.cancel(baseEspThread) end
    baseEspThread = task.spawn(function()
        while espBaseEnabled do
            for _, plot in pairs(Plots:GetChildren()) do
                pcall(function() createOrUpdatePlotESP(plot) end)
            end
            task.wait(0.5)
        end
    end)
    Plots.ChildAdded:Connect(function(plot)
        task.wait(0.8)
        pcall(function() createOrUpdatePlotESP(plot) end)
    end)
end

local function disableBaseESP()
    if baseEspThread then
        task.cancel(baseEspThread)
        baseEspThread = nil
    end
    for _, plot in pairs(Plots:GetChildren()) do
        local main = plot:FindFirstChild("Purchases") and plot.Purchases:FindFirstChild("PlotBlock") and plot.Purchases.PlotBlock:FindFirstChild("Main")
        if main then
            local esp = main:FindFirstChild("ESP_Billboard")
            if esp then esp:Destroy() end
        end
    end
end

-- ============ SPEED SYSTEMS ============
local speedConn = nil
local stealSpeedConn = nil
local duelsSpeedConn = nil

local function startDuelsSpeed()
    if duelsSpeedConn then duelsSpeedConn:Disconnect() end
    duelsSpeedConn = rs.Heartbeat:Connect(function()
        if not duelsSpeed then return end
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return end
        if h.MoveDirection.Magnitude > 0.1 then
            local dir = Vector3.new(h.MoveDirection.X, 0, h.MoveDirection.Z).Unit
            r.AssemblyLinearVelocity = Vector3.new(dir.X * 59.5, r.AssemblyLinearVelocity.Y, dir.Z * 59.5)
        else
            r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
        end
    end)
end

local function startSpeed55()
    if speedConn then speedConn:Disconnect() end
    speedConn = rs.Heartbeat:Connect(function()
        if not speed55 then return end
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return end
        
        local carry = false
        local a = h:FindFirstChildOfClass("Animator")
        if a then
            for _, t in pairs(a:GetPlayingAnimationTracks()) do
                if string.find(t.Animation.AnimationId, "71186871415348") then
                    carry = true
                    break
                end
            end
        end
        
        if h.MoveDirection.Magnitude > 0 and not carry then
            r.AssemblyLinearVelocity = Vector3.new(h.MoveDirection.X * 55, r.AssemblyLinearVelocity.Y, h.MoveDirection.Z * 55)
        else
            r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
        end
    end)
end

local function startStealSpeed()
    if stealSpeedConn then stealSpeedConn:Disconnect() end
    stealSpeedConn = rs.Heartbeat:Connect(function()
        if not speedSteal then return end
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return end
        
        local carry = false
        local a = h:FindFirstChildOfClass("Animator")
        if a then
            for _, t in pairs(a:GetPlayingAnimationTracks()) do
                if string.find(t.Animation.AnimationId, "71186871415348") then
                    carry = true
                    break
                end
            end
        end
        
        if h.MoveDirection.Magnitude > 0 and carry then
            r.AssemblyLinearVelocity = Vector3.new(h.MoveDirection.X * 27, r.AssemblyLinearVelocity.Y, h.MoveDirection.Z * 27)
        else
            r.AssemblyLinearVelocity = Vector3.new(0, r.AssemblyLinearVelocity.Y, 0)
        end
    end)
end

-- ============ AUTO GRAB ============
local AnimalsData = nil
pcall(function()
    AnimalsData = require(rep:WaitForChild("Datas"):WaitForChild("Animals"))
end)

local animalCache = {}
local promptMem = {}
local stealMem = {}
local lastUid = nil
local lastPos = nil
local radius = 150
local stealing = false
local stealProg = 0
local curTarget = nil
local stealStart = 0
local stealConn = nil
local velConn = nil
local grabUI = nil
local progBar = nil
local dotsFolder = nil

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

local function updateVel()
    local h = hrp()
    if not h then return end
    local cur = h.Position
    lastPos = cur
end

local function shouldSteal(d)
    if not d or not d.pos then return false end
    local h = hrp()
    if not h then return false end
    return (h.Position - d.pos).Magnitude <= radius
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
        while tick() - st < 1.3 do
            stealProg = (tick() - st) / 1.3
            task.wait(0.05)
        end
        stealProg = 1
        if #data.trig > 0 then
            for _, fn in pairs(data.trig) do
                task.spawn(fn)
            end
        end
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
    
    dotsFolder = Instance.new("Folder")
    dotsFolder.Parent = m
    
    for i = 1, 30 do
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, math.random(2,4), 0, math.random(2,4))
        d.Position = UDim2.new(math.random(), 0, math.random(), 0)
        d.BackgroundColor3 = Color3.fromRGB(200, 0, 255)
        d.BackgroundTransparency = math.random(40,80)/100
        d.BorderSizePixel = 0
        d.Parent = dotsFolder
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1,0)
        dc.Parent = d
        d:SetAttribute("Speed", math.random(3,15)/1000)
    end
    
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
    if velConn then velConn:Disconnect() end
    velConn = rs.Heartbeat:Connect(updateVel)
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
    if velConn then
        velConn:Disconnect()
        velConn = nil
    end
    if grabUI then
        grabUI:Destroy()
        grabUI = nil
    end
    progBar = nil
    dotsFolder = nil
    animalCache = {}
    promptMem = {}
    stealMem = {}
end

-- ============ FLY DEFENDER ============
local flyDefenderConn = nil
local flyDefenderAutoBatRunning = false

local function startFlyDefender()
    if flyDefenderConn then flyDefenderConn:Disconnect() end
    
    local function getNearestPlayer()
        local c = player.Character
        if not c then return nil end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return nil end
        
        local nearest = nil
        local nearestDist = math.huge
        local myPos = hrp.Position
        
        for _, p in pairs(game.Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = p
                end
            end
        end
        return nearest
    end
    
    flyDefenderConn = rs.Heartbeat:Connect(function()
        if not flyDefender then return end
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        
        local nearest = getNearestPlayer()
        if nearest and nearest.Character and nearest.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = nearest.Character.HumanoidRootPart.Position
            local dir = (targetPos - hrp.Position).Unit
            hrp.AssemblyLinearVelocity = dir * 55
            h.PlatformStand = true
        end
    end)
    
    flyDefenderAutoBatRunning = true
    task.spawn(function()
        while flyDefenderAutoBatRunning and flyDefender do
            local c = player.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then
                    local bat = c:FindFirstChild("Bat") or player.Backpack:FindFirstChild("Bat")
                    if bat then
                        if bat.Parent == player.Backpack then
                            h:EquipTool(bat)
                            task.wait(0.1)
                        end
                        local equipped = c:FindFirstChild("Bat")
                        if equipped then
                            equipped:Activate()
                        end
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

local function stopFlyDefender()
    if flyDefenderConn then
        flyDefenderConn:Disconnect()
        flyDefenderConn = nil
    end
    flyDefenderAutoBatRunning = false
    local c = player.Character
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if h then h.PlatformStand = false end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
    end
end

-- ============ AUTO BAT ============
local autoBatRunning = false

local function startAutoBat()
    autoBatRunning = true
    task.spawn(function()
        while autoBatRunning and autoBat do
            local c = player.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then
                    local bat = c:FindFirstChild("Bat") or player.Backpack:FindFirstChild("Bat")
                    if bat then
                        if bat.Parent == player.Backpack then
                            h:EquipTool(bat)
                            task.wait(0.1)
                        end
                        local equipped = c:FindFirstChild("Bat")
                        if equipped then
                            equipped:Activate()
                        end
                    end
                end
            end
            task.wait(0.15)
        end
    end)
end

-- ============ DUELS SPOTS ============
local redDuelSpots = {
    CFrame.new(-475.51, -5.85, 25.98) * CFrame.Angles(0, math.rad(15.95), 0),
    CFrame.new(-488.59, -3.39, 24.23) * CFrame.Angles(0, math.rad(81.05), 0),
    CFrame.new(-474.57, -5.85, 26.02) * CFrame.Angles(0, math.rad(-85.51), 0),
    CFrame.new(-473