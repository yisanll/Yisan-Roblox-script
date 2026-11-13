local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Yisan886/Aero/refs/heads/main/ui.lua.txt"))()

WindUI:AddTheme({
    Name = "Fallen Aero",
    Accent = Color3.fromHex("#7C3AED"),
    Background = Color3.fromHex("#09090B"),
    Outline = Color3.fromHex("#4C1D95"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#71717A"),
    Button = Color3.fromHex("#1E1B4B"),
    Icon = Color3.fromHex("#A78BFA"),
})

local Window = WindUI:CreateWindow({
    Title = "Aero      ",
    Folder = "Aero",
    SideBarWidth = 180,
    Background = "https://chaton-images.s3.us-east-2.amazonaws.com/alHcHts2JjSlmMRKjQeDXFipKS5LjNhrKrkN8TxbH7HgPmXA1QbuEYZh3Hwnb9F5_1536x1024x1945789.png", -- 背景视频
    BackgroundImageTransparency = 0.35,
    OpenButton = {
        Title = "打开脚本",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.9,
        Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromHex("6D28D9")),
        ColorSequenceKeypoint.new(1, Color3.fromHex("A855F7"))
        }),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

Window:Tag({
    Title = "V1.04",
    Color = Color3.fromHex("00CED1"),
    Radius = 2,
})

Window:Tag({
    Title = "Yisan",
    Icon = "crown",
    Color = Color3.fromHex("FFD700"),
    Radius = 2,
})


local COLOR_SCHEMES = {
    ["Fallen Purple"] = {
        ColorSequence.new({
            ColorSequenceKeypoint.new(
                0,
                Color3.fromHex("2E1065")
            ),
            ColorSequenceKeypoint.new(
                0.3,
                Color3.fromHex("4C1D95")
            ),
            ColorSequenceKeypoint.new(
                0.6,
                Color3.fromHex("7C3AED")
            ),
            ColorSequenceKeypoint.new(
                1,
                Color3.fromHex("C084FC")
            )
        }),
        "waves"
    }
}

local animationSpeed = 5

local function createRainbowBorder(window, colorScheme)
    local mainFrame = window.UIElements.Main
    if not mainFrame then return nil end

    local existingStroke = mainFrame:FindFirstChild("RainbowStroke")
    if existingStroke then existingStroke:Destroy() end

    if not mainFrame:FindFirstChildOfClass("UICorner") then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 16)
        corner.Parent = mainFrame
    end

    local rainbowStroke = Instance.new("UIStroke")
    rainbowStroke.Name = "RainbowStroke"
    rainbowStroke.Thickness = 1.5
    rainbowStroke.Transparency = 0.15
    rainbowStroke.Color = Color3.new(1, 1, 1)
    rainbowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    rainbowStroke.LineJoinMode = Enum.LineJoinMode.Round
    rainbowStroke.Parent = mainFrame

    local glowEffect = Instance.new("UIGradient")
    glowEffect.Name = "GlowEffect"
    local schemeData = COLOR_SCHEMES[colorScheme] or COLOR_SCHEMES["Fallen Purple"]
    glowEffect.Color = schemeData and schemeData[1] or ColorSequence.new(Color3.fromHex("7C3AED"))
    glowEffect.Rotation = 0
    glowEffect.Parent = rainbowStroke
    local outerGlow = Instance.new("UIStroke")
    outerGlow.Name = "OuterGlow"
    outerGlow.Thickness = 8
    outerGlow.Transparency = 0.85
    outerGlow.Color = Color3.fromHex("7C3AED")
    outerGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outerGlow.Parent = mainFrame
    return rainbowStroke
end

local function startBorderAnimation(window, speed)
    local mainFrame = window.UIElements.Main
    if not mainFrame then return nil end
    local rainbowStroke = mainFrame:FindFirstChild("RainbowStroke")
    if not rainbowStroke then return nil end
    local glowEffect = rainbowStroke:FindFirstChild("GlowEffect")
    if not glowEffect then return nil end

    return RunService.Heartbeat:Connect(function()
        if not rainbowStroke or rainbowStroke.Parent == nil then return end
        glowEffect.Rotation = (tick() * speed * 10) % 360
    end)
end

if createRainbowBorder(Window, "Fallen Purple") then
    startBorderAnimation(Window, animationSpeed)
end

local blur = Lighting:FindFirstChildOfClass("BlurEffect")
if not blur then
    blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = Lighting
end

task.spawn(function()
    local wasOpen = false
    while true do
        task.wait(0.1)
        local mainFrame = Window.UIElements and Window.UIElements.Main
        local isOpen = mainFrame and mainFrame.Visible or false
        
        if isOpen ~= wasOpen then
            wasOpen = isOpen
            TweenService:Create(blur, TweenInfo.new(0.3), {
                Size = isOpen and 20 or 0
            }):Play()
        end
    end
end)

local getRoot
getRoot = function(model)
    return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

-- Evade 当前版本把玩家模型放在 workspace.Game.Players，旧版本在 workspace.Players
local function getGamePlayersContainer()
    local gameFolder = workspace:FindFirstChild("Game")
    local nested = gameFolder and gameFolder:FindFirstChild("Players")
    if nested then
        return nested
    end
    return workspace:FindFirstChild("Players")
end

-- 倒地检测：当前版本看角色的 "Downed" 属性，旧版本退回 Humanoid 血量
local function isPlayerDowned(model)
    if not model or not model.Parent then
        return false
    end
    local ok, downed = pcall(function()
        return model:GetAttribute("Downed")
    end)
    if ok and downed ~= nil then
        return downed == true
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil and humanoid.Health <= 0
end

local ESP = {
    Players = false,
    Monsters = false,
    Self = false,
    MaxDistance = 2500,
}

local D = Drawing or drawing
local drawPool = {}
local aliveKeys = {}

local function getDraw(key)
    local t = drawPool[key]
    if not t then
        t = { box = D.new("Square"), text = D.new("Text") }
        t.box.Thickness = 2
        t.box.Filled = false
        t.text.Size = 14
        t.text.Center = true
        t.text.Outline = true
        drawPool[key] = t
    end
    return t
end

local function getDistance(model)
    local lpChar = player.Character
    local lpRoot = lpChar and getRoot(lpChar)
    local root = getRoot(model)
    if lpRoot and root then
        return (lpRoot.Position - root.Position).Magnitude
    end
    return nil
end

local function drawTarget(t, model, name, color, downed, hp, dist)
    local root = getRoot(model)
    local ok, extents = pcall(function() return model:GetExtentsSize() end)
    if not root or not ok then
        t.box.Visible = false
        t.text.Visible = false
        return
    end

    local w = math.max(extents.X / 2, 1.5)
    local hh = math.max(extents.Y / 2, 2)
    local cf = root.CFrame
    local corners = {
        cf:PointToWorldSpace(Vector3.new(-w, hh, 0)),
        cf:PointToWorldSpace(Vector3.new(w, hh, 0)),
        cf:PointToWorldSpace(Vector3.new(-w, -hh, 0)),
        cf:PointToWorldSpace(Vector3.new(w, -hh, 0)),
    }

    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local onScreen = false
    for _, pos in ipairs(corners) do
        local v, vis = Camera:WorldToViewportPoint(pos)
        if vis then onScreen = true end
        if v.X < minX then minX = v.X end
        if v.X > maxX then maxX = v.X end
        if v.Y < minY then minY = v.Y end
        if v.Y > maxY then maxY = v.Y end
    end

    if not onScreen or (dist and dist > ESP.MaxDistance) then
        t.box.Visible = false
        t.text.Visible = false
        return
    end

    t.box.Position = Vector2.new(minX, minY)
    t.box.Size = Vector2.new(maxX - minX, maxY - minY)
    t.box.Color = color
    t.box.Visible = true

    local parts = {}
    if name then table.insert(parts, name) end
    if downed then table.insert(parts, "[倒地]") end
    if hp then table.insert(parts, "HP:" .. hp) end
    if dist then table.insert(parts, math.floor(dist) .. "m") end

    t.text.Text = table.concat(parts, " | ")
    t.text.Position = Vector2.new((minX + maxX) / 2, minY - 16)
    t.text.Color = color
    t.text.Visible = true
end

local function collectTargets()
    local list = {}
    local container = getGamePlayersContainer()
    if not container then return list end

    for _, model in ipairs(container:GetChildren()) do
        if model:IsA("Model") then
            local team = model:GetAttribute("Team")
            if team == "Nextbot" and ESP.Monsters then
                list[#list + 1] = { model = model, kind = "monster" }
            elseif team == "PlayerTeam" and (model ~= player.Character or ESP.Self) and ESP.Players then
                list[#list + 1] = { model = model, kind = "player" }
            end
        end
    end
    return list
end

local function update()
    if not D then return end
    local targets = collectTargets()
    aliveKeys = {}

    for _, entry in ipairs(targets) do
        local model = entry.model
        local key = entry.kind .. ":" .. tostring(model)
        aliveKeys[key] = true

        local t = getDraw(key)
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local hp = humanoid and math.floor(humanoid.Health + 0.5) or nil
        local dist = getDistance(model)

        if entry.kind == "player" then
            local downed = isPlayerDowned(model)
            local disp = humanoid and humanoid.DisplayName or model.Name
            local name = (disp and disp ~= "" and disp ~= "(无)") and disp or model.Name
            drawTarget(t, model, name, downed and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(0, 255, 128), downed, hp, dist)
        else
            drawTarget(t, model, model.Name, Color3.fromRGB(255, 40, 40), false, nil, dist)
        end
    end

    local toRemove = {}
    for key, t in pairs(drawPool) do
        if not aliveKeys[key] then
            table.insert(toRemove, key)
        end
    end
    for _, key in ipairs(toRemove) do
        local t = drawPool[key]
        pcall(function() t.box:Remove() end)
        pcall(function() t.text:Remove() end)
        drawPool[key] = nil
    end
end

task.spawn(function()
    while true do
        pcall(update)
        task.wait(0.03)
    end
end)

-- ==================== 移动 / 跳跃 ====================
local currentSpeed = 2000
local jumpValue = 7
local autoJumpEnabled = false

-- 滑块 7 ≈ 默认跳跃高度（studs）；把“高度”换算成 Humanoid 的起跳速度
local DEFAULT_JUMP = 7.2
local GRAVITY = 196.2

-- Evade 自定义移动属性表的字段签名（getgc 兜底时用）
local MOVE_STAT_KEYS = {
    "Friction",
    "AirStrafeAcceleration",
    "JumpHeight",
    "RunDeaccel",
    "JumpSpeedMultiplier",
    "JumpCap",
    "SprintCap",
    "WalkSpeedMultiplier",
    "BhopEnabled",
    "Speed",
    "AirAcceleration",
    "RunAccel",
    "SprintAcceleration",
}

local BaseStatsModule = nil
local MoveFunctions = nil
local CharacterService = nil
local moveFunctionsHooked = false
local jumpBaseHeight = setmetatable({}, { __mode = "k" })
local moveStatsBase = setmetatable({}, { __mode = "k" })
local cachedMoveStats = {}
local lastMoveStatsScan = 0
local unpackResults = table.unpack or unpack

local function packResults(...)
    return { n = select("#", ...), ... }
end

local function jumpPowerForHeight(height)
    if type(height) ~= "number" or height <= 0 then
        return 0
    end
    return math.sqrt(2 * GRAVITY * height)
end

local function safeRequire(instance)
    if not instance then
        return nil
    end
    local ok, result = pcall(require, instance)
    if ok then
        return result
    end
    return nil
end

local function findMovementInstance()
    local objects = ReplicatedStorage:FindFirstChild("Objects")
    local gameFolder = objects and objects:FindFirstChild("Game")
    local characterFolder = gameFolder and gameFolder:FindFirstChild("Character")
    local clientFolder = characterFolder and characterFolder:FindFirstChild("Client")
    return clientFolder and clientFolder:FindFirstChild("Movement")
end

-- 静态默认属性（兼容旧版本路径）
local function findBaseStats()
    local movement = findMovementInstance()
    if not movement then
        return nil
    end
    local moveStatsInstance = movement:FindFirstChild("MoveStats")
    if not moveStatsInstance then
        return nil
    end
    local module = safeRequire(moveStatsInstance:FindFirstChild("BaseStats"))
    if type(module) ~= "table" then
        local moveStatsModule = safeRequire(moveStatsInstance)
        if type(moveStatsModule) == "table" then
            module = moveStatsModule.BaseStats
        end
    end
    if type(module) == "table" then
        return module
    end
    return nil
end

-- 找到 Movement.MoveFunction.Functions（各移动状态的函数表）
local function findMoveFunctions()
    local movement = findMovementInstance()
    if not movement then
        return nil
    end
    local moveFunction = movement:FindFirstChild("MoveFunction")
    if moveFunction then
        local functions = safeRequire(moveFunction:FindFirstChild("Functions"))
        if type(functions) == "table" then
            return functions
        end
        local moveFunctionModule = safeRequire(moveFunction)
        if type(moveFunctionModule) == "table" and type(moveFunctionModule.Functions) == "table" then
            return moveFunctionModule.Functions
        end
    end
    local functions = safeRequire(movement:FindFirstChild("Functions"))
    if type(functions) == "table" then
        return functions
    end
    local movementModule = safeRequire(movement)
    if type(movementModule) == "table" then
        if type(movementModule.Functions) == "table" then
            return movementModule.Functions
        end
        local moveFunctionModule = movementModule.MoveFunction
        if type(moveFunctionModule) == "table" and type(moveFunctionModule.Functions) == "table" then
            return moveFunctionModule.Functions
        end
    end
    return nil
end

-- 本地角色对象（带 MoveStats / AttemptJump / DataRegistry）
local lastCharacterServiceAttempt = 0
local function getLocalCharacterObject()
    if not CharacterService then
        local now = os.clock()
        if CharacterService == nil or now - lastCharacterServiceAttempt >= 5 then
            lastCharacterServiceAttempt = now
            local services = ReplicatedStorage:FindFirstChild("Services")
            local asset = services and services:FindFirstChild("Asset")
            local characterService = safeRequire(asset and asset:FindFirstChild("CharacterService"))
            CharacterService = characterService or false
        end
    end
    if not CharacterService then
        return nil
    end
    local ok, characterObject = pcall(function()
        return CharacterService:GetLocalCharacter()
    end)
    if ok then
        return characterObject
    end
    return nil
end

local function isMoveStatsTable(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    for _, key in ipairs(MOVE_STAT_KEYS) do
        if rawget(tbl, key) == nil then
            return false
        end
    end
    return true
end

local function collectMoveStatsTables()
    local result = {}
    local characterObject = getLocalCharacterObject()
    if characterObject then
        local ok, stats = pcall(function()
            return characterObject.MoveStats
        end)
        if ok and isMoveStatsTable(stats) then
            result[#result + 1] = stats
        end
    end
    if #result > 0 then
        return result
    end

    local now = os.clock()
    if now - lastMoveStatsScan >= 2 then
        lastMoveStatsScan = now
        cachedMoveStats = {}
        if type(getgc) == "function" then
            pcall(function()
                for _, obj in ipairs(getgc(true)) do
                    if isMoveStatsTable(obj) then
                        cachedMoveStats[#cachedMoveStats + 1] = obj
                    end
                end
            end)
        end
    end
    return cachedMoveStats
end

-- 把速度 / 跳跃高度写进游戏自己的移动属性表（这样蹲下、滑铲都会生效）
local function applyMoveStats()
    for _, stats in ipairs(collectMoveStatsTables()) do
        pcall(function()
            local baseHeight = jumpBaseHeight[stats]
            if baseHeight == nil then
                baseHeight = tonumber(rawget(stats, "JumpHeight")) or 0
                if baseHeight > 0 then
                    jumpBaseHeight[stats] = baseHeight
                end
            end

            -- 记录原始的速度/加速度，用来做等比例缩放（避免高速时“惯性太强/刹不住”）
            local base = moveStatsBase[stats]
            if base == nil then
                local baseSpeed = tonumber(rawget(stats, "Speed")) or 0
                if baseSpeed > 0 then
                    base = {
                        Speed = baseSpeed,
                        RunAccel = tonumber(rawget(stats, "RunAccel")) or 0,
                        RunDeaccel = tonumber(rawget(stats, "RunDeaccel")) or 0,
                        SprintAcceleration = tonumber(rawget(stats, "SprintAcceleration")) or 0,
                    }
                    moveStatsBase[stats] = base
                end
            end

            if currentSpeed > 0 then
                stats.Speed = currentSpeed
                if base and base.Speed > 0 then
                    local factor = currentSpeed / base.Speed
                    if base.RunAccel > 0 then
                        stats.RunAccel = base.RunAccel * factor
                    end
                    if base.RunDeaccel > 0 then
                        stats.RunDeaccel = base.RunDeaccel * factor
                    end
                    if base.SprintAcceleration > 0 then
                        stats.SprintAcceleration = base.SprintAcceleration * factor
                    end
                end
            end
            if baseHeight > 0 then
                stats.JumpHeight = baseHeight * (jumpValue / DEFAULT_JUMP)
            end
        end)
    end
    if BaseStatsModule then
        pcall(function()
            BaseStatsModule.Speed = currentSpeed
        end)
    end
end

-- 读取游戏自己的移动输入（优先用游戏数据，避免 Humanoid.MoveDirection 不可靠）
local function getMovementInput(data)
    if not data or type(data.Get) ~= "function" then
        return nil
    end
    local ok, input = pcall(function()
        return data:Get("MoveDirection")
    end)
    if ok then
        return input
    end
    return nil
end

-- 判断是否正在蹲下/滑铲（兼容属性、状态字符串和游戏数据三种来源）
local function isCrouching(data)
    local character = player.Character
    if character then
        local ok, crouching = pcall(function()
            return character:GetAttribute("Crouching")
        end)
        if ok and crouching == true then
            return true
        end
        local stateOk, stateValue = pcall(function()
            return character:GetAttribute("State")
        end)
        if stateOk and type(stateValue) == "string" then
            if string.find(stateValue, "Crouch") ~= nil or string.find(stateValue, "Slide") ~= nil then
                return true
            end
        end
    end
    if data and type(data.Get) == "function" then
        local ok, crouching = pcall(function()
            return data:Get("Crouching")
        end)
        if ok and crouching == true then
            return true
        end
        local stateOk, stateValue = pcall(function()
            return data:Get("State")
        end)
        if stateOk and type(stateValue) == "string" then
            if string.find(stateValue, "Crouch") ~= nil or string.find(stateValue, "Slide") ~= nil then
                return true
            end
        end
    end
    local container = getGamePlayersContainer()
    local model = container and container:FindFirstChild(player.Name)
    if not model then
        return false
    end
    local modelOk, modelState = pcall(function()
        return model:GetAttribute("State")
    end)
    if modelOk and type(modelState) == "string" then
        if string.find(modelState, "Crouch") ~= nil or string.find(modelState, "Slide") ~= nil then
            return true
        end
    end
    return false
end

-- 只调整水平速度的“大小”，方向始终沿用游戏自己算出的方向，避免按 A/D 时方向错乱；
-- 没有移动输入时完全不干预（否则松开按键还会被推着走，表现为惯性过强）。
local function adjustPlaneSpeed(mover, data)
    if mover == nil then
        return
    end
    local target = currentSpeed
    if target <= 0 then
        return
    end
    local baseMover = mover.BaseMover
    if not baseMover then
        return
    end
    local character = player.Character
    if not character then
        return
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return
    end
    local input = getMovementInput(data)
    if not input or input.Magnitude < 0.05 then
        return
    end
    local planeVelocity = baseMover.PlaneVelocity
    if typeof(planeVelocity) ~= "Vector2" then
        return
    end
    local magnitude = planeVelocity.Magnitude
    if magnitude <= 0 or magnitude >= target then
        return
    end
    -- 蹲下/滑铲：滑条速度直接生效；普通移动：游戏明显没加速到位时才补速，保持原本手感
    if not isCrouching(data) and magnitude >= target * 0.5 then
        return
    end
    baseMover.PlaneVelocity = planeVelocity.Unit * target
end

local function installMoveFunctionHooks()
    if moveFunctionsHooked then
        return
    end
    if not MoveFunctions then
        MoveFunctions = findMoveFunctions()
    end
    if type(MoveFunctions) ~= "table" then
        return
    end
    moveFunctionsHooked = true
    for name, stateFunction in pairs(MoveFunctions) do
        if type(name) == "string" and type(stateFunction) == "function" then
            MoveFunctions[name] = function(...)
                local results = packResults(stateFunction(...))
                pcall(adjustPlaneSpeed, results[1], select(3, ...))
                return unpackResults(results, 1, results.n)
            end
        end
    end
end

local function applyJumpToHumanoid()
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    pcall(function()
        humanoid.UseJumpPower = true
        humanoid.JumpPower = math.clamp(jumpPowerForHeight(jumpValue), 0, 1000)
        humanoid.JumpHeight = jumpValue
    end)
end

local function applySpeed(value)
    currentSpeed = value
    pcall(applyMoveStats)
end

local function applyJump(value)
    jumpValue = value
    pcall(applyMoveStats)
    applyJumpToHumanoid()
end

-- 触发跳跃（优先走游戏自身的角色控制器，旧版本退回 Humanoid）
local function characterAttemptJump()
    local character = player.Character
    if not character then
        return
    end
    local characterObject = getLocalCharacterObject()
    if characterObject then
        local ok = pcall(function()
            characterObject:AttemptJump()
        end)
        if ok then
            return
        end
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

task.spawn(function()
    pcall(installMoveFunctionHooks)
    pcall(applyMoveStats)
    pcall(applyJumpToHumanoid)
    while true do
        task.wait(1)
        if not BaseStatsModule then
            BaseStatsModule = findBaseStats()
        end
        pcall(installMoveFunctionHooks)
        pcall(applyMoveStats)
        pcall(applyJumpToHumanoid)
    end
end)

local lastJumpTime = 0
local function hookAutoJump(char)
    local humanoid = char:WaitForChild("Humanoid")
    humanoid.StateChanged:Connect(function(_, new)
        if not autoJumpEnabled then return end
        if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
            task.delay(0.1, function()
                if not autoJumpEnabled then return end
                local now = tick()
                if now - lastJumpTime < 0.3 then return end
                lastJumpTime = now
                characterAttemptJump()
            end)
        end
    end)
end
player.CharacterAdded:Connect(hookAutoJump)
if player.Character then hookAutoJump(player.Character) end

-- 自动跳跃：不依赖 Humanoid 状态机，直接用游戏控制器的 Grounded 数据判断
task.spawn(function()
    while true do
        task.wait(0.1)
        if autoJumpEnabled then
            pcall(function()
                local characterObject = getLocalCharacterObject()
                local grounded = nil
                if characterObject then
                    local dataRegistry = characterObject.DataRegistry
                    if dataRegistry and dataRegistry.Get then
                        grounded = dataRegistry:Get("Grounded")
                    end
                end
                if grounded == nil then
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
                end
                if grounded then
                    local now = tick()
                    if now - lastJumpTime < 0.3 then
                        return
                    end
                    lastJumpTime = now
                    characterAttemptJump()
                end
            end)
        end
    end
end)

local autoRevive = false
local downedSince = nil
local reviveAttempts = 0
local lastReviveFire = 0

-- 触发游戏自己的“复活/重开”远程（当前版本在 ReplicatedStorage.Remotes，旧版本在 Events）
local function isRemoteEvent(instance)
    if not instance then
        return false
    end
    local ok, result = pcall(function()
        return instance:IsA("RemoteEvent") or instance:IsA("UnreliableRemoteEvent")
    end)
    return ok and result
end

local function fireModeRemote(remote, argument)
    if not isRemoteEvent(remote) then
        return false
    end
    local ok = pcall(function()
        remote:FireServer(argument)
    end)
    return ok
end

local function tryPlayerModeRoot(root)
    if not root then
        return false
    end
    local playerFolder = root:FindFirstChild("Player")
    if playerFolder then
        if fireModeRemote(playerFolder:FindFirstChild("ChangePlayerMode"), true) then
            return true
        end
        if fireModeRemote(playerFolder:FindFirstChild("SetPlayerMode"), true) then
            return true
        end
    end
    -- 递归查找同名远程（结构可能比旧版本深）
    for _, name in ipairs({ "ChangePlayerMode", "SetPlayerMode" }) do
        local ok, found = pcall(function()
            return root:FindFirstChild(name, true)
        end)
        if ok and fireModeRemote(found, true) then
            return true
        end
    end
    return false
end

local function firePlayerModeEvent()
    local roots = {}
    for _, rootName in ipairs({ "Remotes", "Events" }) do
        local root = ReplicatedStorage:FindFirstChild(rootName)
        if root then
            roots[#roots + 1] = root
        end
    end

    for _, root in ipairs(roots) do
        if tryPlayerModeRoot(root) then
            return true
        end
    end

    -- 旧版本兜底：SetPlayerMode:FireServer(UI.GameUIService)
    local services = ReplicatedStorage:FindFirstChild("Services")
    local ui = services and services:FindFirstChild("UI")
    for _, root in ipairs(roots) do
        local ok, remote = pcall(function()
            return root:FindFirstChild("SetPlayerMode", true)
        end)
        if ok and isRemoteEvent(remote) then
            local fired = pcall(function()
                remote:FireServer(ui and ui.GameUIService)
            end)
            if fired then
                return true
            end
        end
    end
    return false
end

local function isDowned()
    return isPlayerDowned(player.Character)
end

local function tryAutoRevive()
    if not autoRevive then
        downedSince = nil
        reviveAttempts = 0
        return
    end
    if not isDowned() then
        downedSince = nil
        reviveAttempts = 0
        return
    end
    local now = tick()
    if downedSince == nil then
        downedSince = now
        return
    end
    -- 倒地后先等 1.5 秒，避免状态切换瞬间误触
    if now - downedSince < 1.5 then
        return
    end
    -- 连续尝试很多次仍失败时，冷却 30 秒后再重试
    if reviveAttempts >= 30 then
        if now - lastReviveFire <= 30 then
            return
        end
        reviveAttempts = 0
    end
    -- 每 1.5 秒发送一次，直到倒地状态解除
    if now - lastReviveFire < 1.5 then
        return
    end
    lastReviveFire = now
    reviveAttempts = reviveAttempts + 1
    firePlayerModeEvent()
end

task.spawn(function()
    while true do
        task.wait(0.25)
        tryAutoRevive()
    end
end)

local platformEnabled = false
local platformHeight = 400
local platform = nil
local mapCenter = nil
local hasCenter = false
local cachedPartsCenter = nil
local lastFallbackScan = 0

local function median(t)
    if #t == 0 then return nil end
    table.sort(t)
    return t[math.floor(#t / 2) + 1]
end

local function destroyPlatform()
    if platform then
        pcall(function() platform:Destroy() end)
        platform = nil
    end
end

local function buildPlatform()
    if not mapCenter then return end
    destroyPlatform()
    platform = Instance.new("Part")
    platform.Name = "SkyPlatform"
    platform.Size = Vector3.new(300, 4, 300)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Material = Enum.Material.Glass
    platform.Transparency = 0.4
    platform.Color = Color3.fromRGB(200, 230, 255)
    platform.CastShadow = false
    platform.Reflectance = 0.1
    platform.Position = Vector3.new(mapCenter.X, mapCenter.Y + platformHeight, mapCenter.Z)
    platform.Parent = workspace
end

local function centerFromSpawns()
    local xs, ys, zs = {}, {}, {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            table.insert(xs, obj.Position.X)
            table.insert(ys, obj.Position.Y)
            table.insert(zs, obj.Position.Z)
        end
    end
    if #xs == 0 then return nil end
    return Vector3.new(median(xs), median(ys), median(zs))
end

local function centerFromParts()
    local xs, zs = {}, {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Anchored then
            local sz = obj.Size
            if sz.X < 500 and sz.Z < 500 then
                table.insert(xs, obj.Position.X)
                table.insert(zs, obj.Position.Z)
            end
        end
    end
    if #xs == 0 then return nil end
    return Vector3.new(median(xs), 0, median(zs))
end

local function rescanCenter()
    local newCenter = nil
    local groundY = 0

    local spawnCenter = centerFromSpawns()
    if spawnCenter then
        newCenter = spawnCenter
        groundY = spawnCenter.Y
    else
        local now = tick()
        if not cachedPartsCenter or (now - lastFallbackScan >= 20) then
            cachedPartsCenter = centerFromParts()
            lastFallbackScan = now
        end
        if not cachedPartsCenter then return end
        local char = player.Character
        local root = char and getRoot(char)
        groundY = (root and root.Position.Y > -1000) and root.Position.Y or 0
        newCenter = Vector3.new(cachedPartsCenter.X, groundY, cachedPartsCenter.Z)
    end

    if not hasCenter then
        mapCenter = Vector3.new(newCenter.X, groundY, newCenter.Z)
        hasCenter = true
        buildPlatform()
        return
    end

    local moved = Vector3.new(newCenter.X - mapCenter.X, 0, newCenter.Z - mapCenter.Z).Magnitude
    if moved > 150 then
        mapCenter = Vector3.new(newCenter.X, groundY, newCenter.Z)
        buildPlatform()
    end
end

local function clearForces(char)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BodyVelocity") or v:IsA("BodyForce") or v:IsA("LinearVelocity") then
            pcall(function() v:Destroy() end)
        end
    end
end

local function teleportToPlatform()
    if not platformEnabled or not platform then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    clearForces(char)

    local target = Vector3.new(platform.Position.X, platform.Position.Y + platform.Size.Y / 2 + 3, platform.Position.Z)
    char:PivotTo(CFrame.new(target))

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        Camera.CameraSubject = humanoid
    end
    Camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 5, 12), target)
end

task.spawn(function()
    local lastForceTeleport = 0
    local lastRescan = 0

    while true do
        task.wait(0.3)
        if not platformEnabled then continue end

        local char = player.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local now = tick()
        if now - lastRescan >= 4 then
            lastRescan = now
            rescanCenter()
        end

        if not platform or not platform.Parent then
            if hasCenter then buildPlatform() end
        end

        if not platform then continue end

        local top = platform.Position.Y + platform.Size.Y / 2
        local dropped = root.Position.Y < (top - 25)
        local timeUp = (now - lastForceTeleport) >= 5

        if dropped or timeUp then
            lastForceTeleport = now
            teleportToPlatform()
        end
    end
end)

player.CharacterAdded:Connect(function(char)
    task.wait(1)
    char:WaitForChild("HumanoidRootPart", 5)
    if platformEnabled then
        teleportToPlatform()
    end
end)

local rescueEnabled = false
local rescueCurrentTarget = nil
local rescueSelfDowned = false
local rescueVelocity = nil
local rescueKeyHeld = false

local rescueCFG = {
    HoverHeight = 3,
    FlySpeed = 2500,
    ArriveDist = 3,
    HoldDistance = 15,
    PressE = true,
    PressInterval = 0.01,
    TargetSwitchDelay = 1.5,
    MaxDistance = 3000,
    UpdateInterval = 0.02,
}

local function findDownedPlayer()
    local container = getGamePlayersContainer()
    if not container then return nil end
    local best, bestDist = nil, math.huge
    local myChar = player.Character
    local myRoot = myChar and getRoot(myChar)
    for _, model in ipairs(container:GetChildren()) do
        if model:IsA("Model") and model ~= myChar and model:GetAttribute("Team") == "PlayerTeam" then
            if isPlayerDowned(model) then
                local root = getRoot(model)
                if root then
                    local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                    if dist <= rescueCFG.MaxDistance and dist < bestDist then
                        best, bestDist = model, dist
                    end
                end
            end
        end
    end
    return best
end

local function getRescueVelocity(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    if not rescueVelocity or rescueVelocity.Parent ~= root then
        if rescueVelocity then pcall(function() rescueVelocity:Destroy() end) end
        rescueVelocity = Instance.new("BodyVelocity")
        rescueVelocity.Name = "RescueVelocity"
        rescueVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        rescueVelocity.Velocity = Vector3.new(0, 0, 0)
        rescueVelocity.Parent = root
    end
    return rescueVelocity
end

local function destroyRescueVelocity()
    if rescueVelocity then
        pcall(function() rescueVelocity:Destroy() end)
        rescueVelocity = nil
    end
end

local function rescueRestoreMove()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            applyJumpToHumanoid()
        end
    end
    destroyRescueVelocity()
end

local function rescueHoldKey()
    if not rescueKeyHeld then
        rescueKeyHeld = true
        pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
    end
end

local function rescueReleaseKey()
    if rescueKeyHeld then
        rescueKeyHeld = false
        pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
    end
end

local function handleSelfDowned()
    rescueSelfDowned = true
    rescueReleaseKey()
    rescueCurrentTarget = nil
    rescueRestoreMove()
end

task.spawn(function()
    while true do
        task.wait(rescueCFG.UpdateInterval)

        if not rescueEnabled then
            rescueReleaseKey()
            rescueCurrentTarget = nil
            destroyRescueVelocity()
            continue
        end

        local myChar = player.Character
        if not myChar then continue end

        if isDowned() then
            handleSelfDowned()
            continue
        end

        if rescueSelfDowned then
            rescueSelfDowned = false
        end

        if rescueCurrentTarget and not isPlayerDowned(rescueCurrentTarget) then
            rescueReleaseKey()
            rescueCurrentTarget = nil
            destroyRescueVelocity()
            task.wait(rescueCFG.TargetSwitchDelay)
            continue
        end

        if not rescueCurrentTarget then
            rescueCurrentTarget = findDownedPlayer()
        end

        if not rescueCurrentTarget then
            rescueReleaseKey()
            destroyRescueVelocity()
            continue
        end

        local targetRoot = getRoot(rescueCurrentTarget)
        if not targetRoot then
            rescueCurrentTarget = nil
            continue
        end

        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then continue end

        local targetPos = targetRoot.Position + Vector3.new(0, rescueCFG.HoverHeight, 0)
        local diff = targetPos - myRoot.Position
        local dist = diff.Magnitude

        local bv = getRescueVelocity(myChar)
        if bv then
            if dist > rescueCFG.ArriveDist then
                local speed = rescueCFG.FlySpeed
                local maxStep = dist / math.max(rescueCFG.UpdateInterval, 0.01)
                speed = math.min(speed, maxStep)
                bv.Velocity = diff.Unit * speed
            else
                bv.Velocity = Vector3.new(0, 0, 0)
            end
        end

        if dist < rescueCFG.HoldDistance then
            if rescueCFG.PressE then rescueHoldKey() end
        else
            rescueReleaseKey()
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(rescueCFG.PressInterval)
        if not rescueEnabled or rescueSelfDowned then
            rescueReleaseKey()
            continue
        end
        if rescueKeyHeld then
            pcall(function() VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
            task.wait(0.01)
            pcall(function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
        end
    end
end)

local boomboxEnabled = false
local bbCurrent = nil
local bbSongId = 1840041514
local bbVolume = 1
local bbPlaying = true

local bbSongs = {
    {"Getting Higher", 1840041514},
    {"Christmas Rock", 1839286325},
    {"21st Century", 1837367459},
    {"Clap", 1843663202},
    {"Moon King", 1842514702},
    {"Pull Over", 1839983980},
    {"Watcha Don", 1837908256},
    {"Jingle Bells", 1839286187},
    {"Funky Agent", 1839322710},
    {"Teach Me", 1836515657},
}

local bbSkin = nil
pcall(function()
    bbSkin = ReplicatedStorage.Items.BaseItems.Boomboxes.Boombox
end)

local function bbFindSound()
    local holders = {player.Character, getGamePlayersContainer()}
    for _, h in ipairs(holders) do
        if h then
            for _, d in ipairs(h:GetDescendants()) do
                if d:IsA("Sound") and d.Name == "LocalMusic" then return d end
            end
        end
    end
    return nil
end

local function bbApplySong(id)
    bbSongId = id
    local s = bbFindSound()
    if s then
        s.SoundId = "rbxassetid://" .. id
        if bbPlaying then s:Play() end
    end
end

local function bbSetVolume(v)
    bbVolume = v / 100
    local s = bbFindSound()
    if s then s.Volume = bbVolume end
end

local function bbFindPart(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "Boombox" and d:IsA("BasePart") then return d end
    end
    return nil
end

local function bbFindWeld(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "Boombox" and d:IsA("Weld") then return d end
    end
    return nil
end

local function bbGetModel()
    local pf = getGamePlayersContainer()
    if not pf then return nil end
    local fb = nil
    for _, m in ipairs(pf:GetChildren()) do
        if m:IsA("Model") then
            if m.Name == player.Name then return m end
            if not fb and m:GetAttribute("Team") == "PlayerTeam" then fb = m end
        end
    end
    return fb
end

local function bbFindAnchor(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "UpperTorso" then return d end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "Torso" then return d end
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Name == "HumanoidRootPart" then return d end
    end
    return nil
end

local function bbDestroy()
    if bbCurrent and bbCurrent.bb and bbCurrent.bb.Parent then
        pcall(function() bbCurrent.bb:Destroy() end)
    end
    bbCurrent = nil
end

local function bbBuild()
    if not bbSkin then return end
    local model = bbGetModel()
    local anchor = model and bbFindAnchor(model)
    if not model or not anchor then return end

    if bbCurrent and bbCurrent.bb and bbCurrent.bb.Parent and bbCurrent.anchor == anchor then
        return
    end

    local templateName = (anchor.Name == "Torso") and "CharacterClassic" or "Character"
    local template = bbSkin:FindFirstChild(templateName)
    if not template then return end
    local bbT = bbFindPart(template)
    if not bbT then return end

    bbDestroy()

    local bb = bbT:Clone()
    bb.Name = "LocalBoombox"
    bb.Anchored = false
    bb.CanCollide = false
    bb.Massless = true
    for _, c in ipairs(bb:GetChildren()) do
        if c:IsA("JointInstance") then c:Destroy() end
    end

    local weldT = bbFindWeld(template)
    local rel = weldT and (weldT.C0 * weldT.C1:Inverse()) or CFrame.new(0, 0, -1.2)
    bb.CFrame = anchor.CFrame * rel
    bb.Parent = model

    for _, d in ipairs(model:GetDescendants()) do
        if d.Name == "LocalBoombox" and d ~= bb then
            pcall(function() d:Destroy() end)
        end
    end

    local w = Instance.new("Weld")
    w.Part0 = anchor
    w.Part1 = bb
    w.C0 = rel
    w.C1 = CFrame.new()
    w.Parent = bb

    local s = Instance.new("Sound")
    s.Name = "LocalMusic"
    s.SoundId = "rbxassetid://" .. bbSongId
    s.Volume = bbVolume
    s.Looped = true
    s.Parent = bb
    if bbPlaying then s:Play() end

    bbCurrent = {bb = bb, anchor = anchor}
end

task.spawn(function()
    while true do
        task.wait(1)
        if not boomboxEnabled then continue end
        pcall(bbBuild)
    end
end)

local Tab = Window:Tab({
    Title = "功能",
    Icon = "sparkles",
    Locked = false,
})
Window:SelectTab(1)

local espSection = Tab:Section({
    Title = "ESP",
    IconName = "eye"
})

espSection:Toggle({
    Title = "玩家方框",
    Value = false,
    Callback = function(state)
        ESP.Players = state
    end
})

espSection:Toggle({
    Title = "怪物方框",
    Value = false,
    Callback = function(state)
        ESP.Monsters = state
    end
})

espSection:Toggle({
    Title = "显示自己",
    Value = false,
    Callback = function(state)
        ESP.Self = state
    end
})

espSection:Slider({
    Title = "最大距离",
    Value = {
        Min = 100,
        Max = 5000,
        Default = 2500,
    },
    Callback = function(value)
        ESP.MaxDistance = value
    end
})

local moveSection = Tab:Section({
    Title = "移动",
    IconName = "zap"
})

moveSection:Toggle({
    Title = "自动跳跃",
    Value = false,
    Callback = function(state)
        autoJumpEnabled = state
    end
})

moveSection:Slider({
    Title = "移动速度",
    Value = {
        Min = 1,
        Max = 10000,
        Default = 2000,
    },
    Callback = function(value)
        applySpeed(value)
    end
})

moveSection:Slider({
    Title = "跳跃高度",
    Value = {
        Min = 0,
        Max = 100,
        Default = 1,
    },
    Callback = function(value)
        applyJump(value)
    end
})

local reviveSection = Tab:Section({
    Title = "复活",
    IconName = "heart"
})

reviveSection:Toggle({
    Title = "自动复活",
    Value = false,
    Callback = function(state)
        autoRevive = state
    end
})

local rescueSection = Tab:Section({
    Title = "复活",
    IconName = "hand-heart"
})

rescueSection:Toggle({
    Title = "自动救",
    Value = false,
    Callback = function(state)
        rescueEnabled = state
        if not state then
            rescueReleaseKey()
            rescueCurrentTarget = nil
            rescueSelfDowned = false
            rescueRestoreMove()
        end
    end
})

local farmSection = Tab:Section({
    Title = "农场",
    IconName = "home"
})

farmSection:Toggle({
    Title = "高空平台",
    Value = false,
    Callback = function(state)
        platformEnabled = state
        if state then
            rescanCenter()
        else
            destroyPlatform()
        end
    end
})

farmSection:Slider({
    Title = "平台高度",
    Value = {
        Min = 100,
        Max = 2000,
        Default = 400,
    },
    Callback = function(value)
        platformHeight = value
        if platform then
            buildPlatform()
        end
    end
})

farmSection:Button({
    Title = "传送至平台",
    Callback = function()
        teleportToPlatform()
    end
})

local musicSection = Tab:Section({
    Title = "音箱",
    IconName = "music"
})

musicSection:Toggle({
    Title = "挂载音箱",
    Value = false,
    Callback = function(state)
        boomboxEnabled = state
        if not state then
            bbDestroy()
        end
    end
})

for _, v in ipairs(bbSongs) do
    musicSection:Button({
        Title = v[1],
        Desc = tostring(v[2]),
        Callback = function()
            bbApplySong(v[2])
            WindUI:Notify({
                Title = "正在播放",
                Content = v[1],
                Duration = 2
            })
        end
    })
end

musicSection:Slider({
    Title = "音量",
    Value = {
        Min = 0,
        Max = 100,
        Default = 100,
    },
    Callback = function(value)
        bbSetVolume(value)
    end
})

musicSection:Toggle({
    Title = "播放中",
    Value = true,
    Callback = function(state)
        bbPlaying = state
        local s = bbFindSound()
        if s then
            if state then
                s:Play()
            else
                s:Pause()
            end
        end
    end
})

musicSection:Button({
    Title = "停止",
    Callback = function()
        local s = bbFindSound()
        if s then s:Stop() end
    end
})

local customId = nil
musicSection:Input({
    Title = "自定义ID",
    Placeholder = "输入歌曲ID",
    Callback = function(v)
        customId = tonumber(v)
    end
})

musicSection:Button({
    Title = "播放自定义",
    Callback = function()
        if customId and customId > 0 then
            bbApplySong(customId)
            WindUI:Notify({
                Title = "正在播放",
                Content = "ID " .. tostring(customId),
                Duration = 2
            })
        end
    end
})