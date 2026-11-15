local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local autoJumpToggleRef = nil

local function mirrorUrls(url)
    local owner, repo, branch, path = string.match(
        url,
        "^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/refs/heads/([^/]+)/(.+)$"
    )
    if not owner then
        return { url }
    end
    local raw = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/refs/heads/" .. branch .. "/" .. path
    return {
        "https://gh-proxy.com/" .. raw,
        "https://ghproxy.net/" .. raw,
        raw,
        "https://cdn.jsdelivr.net/gh/" .. owner .. "/" .. repo .. "@" .. branch .. "/" .. path,
        "https://ghfast.top/" .. raw,
    }
end

local function bodyLooksBroken(body, mustCompile)
    if type(body) ~= "string" or #body < 32 then
        return true
    end
    local head = string.sub(body, 1, 32)
    if head == "404: Not Found" or string.find(head, "<?xml", 1, true) or string.find(head, "AccessDenied", 1, true) then
        return true
    end
    if mustCompile and not loadstring(body) then
        return true
    end
    return false
end

local function fetchWithRetry(url, mustCompile)
    local urls = mirrorUrls(url)
    local lastErr = nil
    for i = 1, #urls do
        for _ = 1, 2 do
            local ok, body = pcall(function()
                return game:HttpGet(urls[i])
            end)
            if ok and not bodyLooksBroken(body, mustCompile) then
                return body
            end
            if not ok then
                lastErr = tostring(body)
            end
            task.wait(0.2)
        end
    end
    warn("[UI] 全部 5 个下载通道都失败：" .. tostring(url) .. (lastErr and (" | 最后错误：" .. lastErr) or ""))
    return nil
end

local function compileLuaSource(source)
    if type(source) ~= "string" or #source == 0 then
        return nil
    end
    local chunk = loadstring(source)
    if not chunk then
        return nil
    end
    local ok, result = pcall(chunk)
    if ok then
        return result
    end
    return nil
end

local function makeIconModule(lucideIcons)
    local module = {
        IconsType = "lucide",
        New = nil,
        IconThemeTag = nil,
        Icons = {
            lucide = lucideIcons,
        },
    }

    local function parseIconString(iconString)
        if type(iconString) == "string" then
            local splitIndex = string.find(iconString, ":")
            if splitIndex then
                return string.sub(iconString, 1, splitIndex - 1), string.sub(iconString, splitIndex + 1)
            end
        end
        return nil, iconString
    end

    local function defaultFormatIcon(image)
        return {
            image,
            { ImageRectSize = Vector2.new(0, 0), ImageRectPosition = Vector2.new(0, 0) },
        }
    end

    function module.SetIconsType(iconType)
        module.IconsType = iconType
    end

    function module.Init(New, IconThemeTag)
        module.New = New
        module.IconThemeTag = IconThemeTag
        return module
    end

    function module.AddIcons(packName, iconsData)
        if type(packName) ~= "string" or type(iconsData) ~= "table" then
            return
        end
        local pack = module.Icons[packName]
        if type(pack) ~= "table" then
            pack = {}
            module.Icons[packName] = pack
        end
        for iconName, iconValue in pairs(iconsData) do
            if type(iconValue) == "number" then
                iconValue = "rbxassetid://" .. tostring(iconValue)
            end
            pack[iconName] = iconValue
        end
    end

    function module.Icon(icon, iconType, defaultFormat)
        defaultFormat = defaultFormat ~= false
        local parsedType, parsedName = parseIconString(icon)
        local targetType = parsedType or iconType or module.IconsType
        local pack = module.Icons[targetType]
        if type(pack) == "table" and parsedName ~= nil then
            local entry = pack[parsedName]
            if type(entry) == "string" then
                if string.find(entry, "rbxassetid://", 1, true) then
                    if defaultFormat then
                        return defaultFormatIcon(entry)
                    end
                    return entry
                end
                return defaultFormatIcon(entry)
            elseif type(entry) == "table" and entry.Image then
                return {
                    entry.Image,
                    {
                        ImageRectSize = entry.ImageRectSize or Vector2.new(0, 0),
                        ImageRectPosition = entry.ImageRectPosition or Vector2.new(0, 0),
                        Parts = entry.Parts,
                    },
                }
            end
        end
        return defaultFormatIcon("")
    end

    function module.GetIcon(icon, iconType)
        return module.Icon(icon, iconType, false)
    end

    function module.Icon2(icon, iconType)
        return module.Icon(icon, iconType, true)
    end

    function module.Image(config)
        local colors = config and config.Colors or { Color3.new(1, 1, 1), Color3.new(1, 1, 1) }
        local size = config and config.Size or UDim2.new(0, 24, 0, 24)
        local icon = config and config.Icon or nil
        local iconType = config and config.Type or nil
        local iconLabel = module.Icon2(icon, iconType)
        local image = ""
        local rectSize = nil
        local rectOffset = nil
        if type(iconLabel) == "string" then
            image = iconLabel
        elseif type(iconLabel) == "table" then
            image = iconLabel[1] or ""
            local info = iconLabel[2]
            if type(info) == "table" then
                rectSize = info.ImageRectSize
                rectOffset = info.ImageRectPosition
            end
        end
        local function resolveColor(color)
            if typeof(color) == "Color3" then
                return color
            end
            return Color3.new(1, 1, 1)
        end
        local function createLabel(props)
            if type(module.New) == "function" then
                local ok, frame = pcall(module.New, "ImageLabel", props)
                if ok and frame then
                    return frame
                end
            end
            local frame = Instance.new("ImageLabel")
            for key, value in pairs(props) do
                if key ~= "ThemeTag" then
                    pcall(function()
                        frame[key] = value
                    end)
                end
            end
            return frame
        end
        local props = {
            Size = size,
            BackgroundTransparency = 1,
            ImageColor3 = resolveColor(colors[1]),
            Image = image or "",
        }
        if rectSize then
            props.ImageRectSize = rectSize
        end
        if rectOffset then
            props.ImageRectOffset = rectOffset
        end
        return { IconFrame = createLabel(props) }
    end

    return module
end

local lucideSource = fetchWithRetry("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua", true)
local lucideData = compileLuaSource(lucideSource)
if type(lucideData) ~= "table" then
    lucideData = {}
end

local AeroIconModule = makeIconModule(lucideData)
__AeroIconsModule = AeroIconModule
do
    local genv = nil
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            genv = env
        end
    end
    if genv then
        genv.__AeroIconsModule = AeroIconModule
    end
end

local uiSource = fetchWithRetry("https://raw.githubusercontent.com/Yisan886/Aero/refs/heads/main/ui.lua.txt", true)
if not uiSource then
    error("[躲避] UI 库下载失败，请检查执行器的 HTTP 是否可用")
end

local iconsLoaderPattern = 'local l=loadstring%(%s*game%.HttpGetAsync%s+and%s+game:HttpGetAsync%(%s*j%s*%)%s*or%s+h:GetAsync%(%s*j%s*%)%s*%)%s*%(%)'
local iconsLoaderReplacement = "local l=(getgenv and getgenv().__AeroIconsModule) or __AeroIconsModule"
local patchedSource, replacementCount = string.gsub(uiSource, iconsLoaderPattern, iconsLoaderReplacement, 1)
local iconsPatched = replacementCount > 0
if iconsPatched then
    uiSource = patchedSource
else
    local urlPos = string.find(uiSource, "Icons/main/Main-v2.lua", 1, true)
    if urlPos then
        local loadPos = string.find(uiSource, "loadstring(", urlPos, true)
        if loadPos then
            local expressionEnd = string.find(uiSource, ")()", loadPos, true)
            if expressionEnd then
                local lastLocalPos = nil
                local searchStart = 1
                while true do
                    local found = string.find(uiSource, "local l=", searchStart, true)
                    if not found or found > loadPos then
                        break
                    end
                    lastLocalPos = found
                    searchStart = found + 1
                end
                if lastLocalPos then
                    uiSource = string.sub(uiSource, 1, lastLocalPos - 1)
                        .. iconsLoaderReplacement
                        .. string.sub(uiSource, expressionEnd + 3)
                    iconsPatched = true
                end
            end
        end
    end
end
if not iconsPatched then
    warn("[躲避] UI 图标加载段未匹配，已回退到原版加载方式")
end

local uiChunk = loadstring(uiSource)
if not uiChunk then
    error("[躲避] UI 库编译失败")
end
local WindUI = uiChunk()

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
    Background = "https://chaton-images.s3.us-east-2.amazonaws.com/alHcHts2JjSlmMRKjQeDXFipKS5LjNhrKrkN8TxbH7HgPmXA1QbuEYZh3Hwnb9F5_1536x1024x1945789.png",
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
    Title = "V2.0",
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

    local lastUpdate = 0
    return RunService.Heartbeat:Connect(function()
        if not rainbowStroke or rainbowStroke.Parent == nil then return end
        local now = os.clock()
        if now - lastUpdate < 0.05 then return end
        lastUpdate = now
        glowEffect.Rotation = (tick() * speed * 10) % 360
    end)
end

if createRainbowBorder(Window, "Fallen Purple") then
    startBorderAnimation(Window, animationSpeed)
end

local blur = Instance.new("BlurEffect")
blur.Name = "AeroBlur"
blur.Size = 0
blur.Parent = Lighting

task.spawn(function()
    local wasOpen = false
    while true do
        task.wait(0.1)
        if not blur.Parent then
            blur = Instance.new("BlurEffect")
            blur.Name = "AeroBlur"
            blur.Size = 0
            blur.Parent = Lighting
        end
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

local function getGamePlayersContainer()
    local gameFolder = workspace:FindFirstChild("Game")
    local nested = gameFolder and gameFolder:FindFirstChild("Players")
    if nested then
        return nested
    end
    return workspace:FindFirstChild("Players")
end

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

local CharacterService = nil
local getLocalCharacterObject

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

local function getMonsterContainers()
    local containers = {}
    local seen = {}
    local function push(container)
        if container and not seen[container] then
            seen[container] = true
            containers[#containers + 1] = container
        end
    end
    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder then
        push(gameFolder:FindFirstChild("Players"))
        push(gameFolder:FindFirstChild("Rigs"))
        push(gameFolder:FindFirstChild("Nextbots"))
        push(gameFolder:FindFirstChild("Monsters"))
        push(gameFolder:FindFirstChild("NPCs"))
        for _, child in ipairs(gameFolder:GetChildren()) do
            if child:IsA("Folder") or child:IsA("Model") then
                local lower = string.lower(child.Name)
                if string.find(lower, "nextbot", 1, true)
                    or string.find(lower, "monster", 1, true)
                    or string.find(lower, "npc", 1, true) then
                    push(child)
                end
            end
        end
    end
    push(workspace:FindFirstChild("Players"))
    push(workspace:FindFirstChild("Rigs"))
    push(workspace:FindFirstChild("Nextbots"))
    push(workspace:FindFirstChild("Monsters"))
    return containers
end

local function isMonsterModel(model)
    local okAi, ai = pcall(function()
        return model:GetAttribute("AI")
    end)
    if okAi and ai ~= nil and ai ~= false then
        return true
    end
    local okTeam, team = pcall(function()
        return model:GetAttribute("Team")
    end)
    if okTeam and team == "Nextbot" then
        return true
    end
    return false
end

local monsterScanCache = {}
local lastMonsterScan = 0

local function refreshMonsterScan()
    local now = os.clock()
    if now - lastMonsterScan < 2 then
        return
    end
    lastMonsterScan = now
    monsterScanCache = {}
    pcall(function()
        for _, descendant in ipairs(workspace:GetDescendants()) do
            if descendant:IsA("Model") and isMonsterModel(descendant) then
                monsterScanCache[#monsterScanCache + 1] = descendant
                if #monsterScanCache >= 100 then
                    break
                end
            end
        end
    end)
end

local function getModelPart(model)
    local root = model:FindFirstChild("HumanoidRootPart")
    if root then
        return root
    end
    local primary = model.PrimaryPart
    if primary then
        return primary
    end
    return model:FindFirstChildWhichIsA("BasePart", true)
end

local function drawTarget(t, cam, model, name, color, downed, hp, dist)
    if not cam then
        t.box.Visible = false
        t.text.Visible = false
        return
    end
    local okBox, boxCFrame, boxSize = pcall(function()
        return model:GetBoundingBox()
    end)
    if not okBox or not boxCFrame or not boxSize then
        local part = getModelPart(model)
        if not part then
            t.box.Visible = false
            t.text.Visible = false
            return
        end
        boxCFrame = part.CFrame
        boxSize = part.Size
    end

    local halfX = math.max(boxSize.X / 2, 1)
    local halfY = math.max(boxSize.Y / 2, 1)
    local corners = {
        boxCFrame:PointToWorldSpace(Vector3.new(-halfX, halfY, 0)),
        boxCFrame:PointToWorldSpace(Vector3.new(halfX, halfY, 0)),
        boxCFrame:PointToWorldSpace(Vector3.new(-halfX, -halfY, 0)),
        boxCFrame:PointToWorldSpace(Vector3.new(halfX, -halfY, 0)),
    }

    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local onScreen = false
    for _, pos in ipairs(corners) do
        local v, vis = cam:WorldToViewportPoint(pos)
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
    local seen = {}
    local function add(model, kind)
        if not model or seen[model] then
            return
        end
        seen[model] = true
        list[#list + 1] = { model = model, kind = kind }
    end

    for _, container in ipairs(getMonsterContainers()) do
        for _, model in ipairs(container:GetChildren()) do
            if model:IsA("Model") and model.Parent then
                if isMonsterModel(model) then
                    if ESP.Monsters then
                        add(model, "monster")
                    end
                elseif ESP.Players then
                    local team = model:GetAttribute("Team")
                    if team == "PlayerTeam" and (model ~= player.Character or ESP.Self) then
                        add(model, "player")
                    end
                end
            end
        end
    end

    if ESP.Monsters then
        refreshMonsterScan()
        for _, model in ipairs(monsterScanCache) do
            if model.Parent then
                add(model, "monster")
            end
        end
    end

    getLocalCharacterObject()
    if CharacterService then
        local ok, characters = pcall(CharacterService.GetCharacters, CharacterService)
        if ok and type(characters) == "table" then
            for _, characterObject in ipairs(characters) do
                local model = nil
                pcall(function()
                    model = characterObject.Model
                end)
                if model and model.Parent and model:IsA("Model") then
                    if isMonsterModel(model) then
                        if ESP.Monsters then
                            add(model, "monster")
                        end
                    elseif ESP.Players then
                        local team = model:GetAttribute("Team")
                        if team == "PlayerTeam" and (model ~= player.Character or ESP.Self) then
                            add(model, "player")
                        end
                    end
                end
            end
        end
    end
    return list
end

local espActive = false

local function clearDrawPool()
    for key, t in pairs(drawPool) do
        pcall(function() t.box:Remove() end)
        pcall(function() t.text:Remove() end)
        drawPool[key] = nil
    end
    aliveKeys = {}
    espActive = false
end

local function update()
    if not D then return end

    if not ESP.Players and not ESP.Monsters then
        if espActive or next(drawPool) ~= nil then
            clearDrawPool()
        end
        return
    end
    espActive = true
    local cam = workspace.CurrentCamera
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
            drawTarget(t, cam, model, name, downed and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(0, 255, 128), downed, hp, dist)
        else
            local aiName = nil
            pcall(function()
                local ai = model:GetAttribute("AI")
                if type(ai) == "string" and ai ~= "" then
                    aiName = ai
                end
            end)
            drawTarget(t, cam, model, aiName or model.Name, Color3.fromRGB(255, 40, 40), false, hp, dist)
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
        task.wait(0.05)
    end
end)

local speedMultiplier = 1
local speedApplied = false
local moveBaseSpeed = nil
local jumpLevel = 1
local autoJumpEnabled = false

local JUMP_STEP = 0.25
local jumpBaseHeight = nil
local jumpBaseApplied = false

local function getJumpMultiplier()
    if jumpLevel <= 0 then
        return 0
    end
    return 1 + (jumpLevel - 1) * JUMP_STEP
end

local BaseStatsModule = nil
local cachedMoveStats = {}
local nextMoveStatsScan = os.clock() + 30

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

local lastCharacterServiceAttempt = 0
local cachedCharacterObject = nil
local cachedCharacterObjectAt = 0

getLocalCharacterObject = function()
    local now = os.clock()
    if cachedCharacterObject and now - cachedCharacterObjectAt < 1 then
        return cachedCharacterObject
    end
    if not CharacterService then
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
    local ok, characterObject = pcall(CharacterService.GetLocalCharacter, CharacterService)
    if ok and characterObject then
        cachedCharacterObject = characterObject
        cachedCharacterObjectAt = now
        return characterObject
    end
    cachedCharacterObject = nil
    return nil
end

local function isUsableMoveStats(tbl)
    return type(tbl) == "table" and type(rawget(tbl, "Speed")) == "number"
end

local function getMoveStatsFromCharacter()
    local characterObject = getLocalCharacterObject()
    if not characterObject then
        return nil
    end
    local movement = characterObject.Movement
    if not movement then
        return nil
    end
    local moveStatsObject = movement.MoveStats
    if not moveStatsObject then
        return nil
    end
    local ok, stats = pcall(function()
        return moveStatsObject:GetMoveStats()
    end)
    if ok and isUsableMoveStats(stats) then
        return stats
    end
    return nil
end

local function collectMoveStatsTables()
    local characterStats = getMoveStatsFromCharacter()
    if characterStats then
        return { characterStats }
    end

    local now = os.clock()
    if now < nextMoveStatsScan or not player.Character then
        return cachedMoveStats
    end

    cachedMoveStats = {}
    nextMoveStatsScan = now + 60
    return cachedMoveStats
end

local function setStatIfChanged(stats, key, value)
    if rawget(stats, key) ~= value then
        stats[key] = value
        return true
    end
    return false
end

local function resolveMoveBaseSpeed()
    if moveBaseSpeed then
        return moveBaseSpeed
    end
    if BaseStatsModule then
        local value = tonumber(BaseStatsModule.Speed)
        if value and value > 0 then
            moveBaseSpeed = value
            return moveBaseSpeed
        end
    end
    local stats = getMoveStatsFromCharacter()
    if stats then
        local value = tonumber(rawget(stats, "Speed")) or 0
        if value > 0 then
            moveBaseSpeed = value
            return moveBaseSpeed
        end
    end
    return nil
end

local function applyMoveStats()
    local mult = speedMultiplier
    if mult <= 1 and not speedApplied then
        return
    end
    local base = resolveMoveBaseSpeed()
    if not base or base <= 0 then
        return
    end
    local target = base * mult
    if target < 1 then
        return
    end
    for _, stats in ipairs(collectMoveStatsTables()) do
        if isUsableMoveStats(stats) then
            pcall(function()
                setStatIfChanged(stats, "Speed", target)
            end)
        end
    end
    speedApplied = mult > 1
end

local function getLiveMoveStats()
    local stats = getMoveStatsFromCharacter()
    if stats then
        return stats
    end
    for _, cachedStats in ipairs(collectMoveStatsTables()) do
        if isUsableMoveStats(cachedStats) then
            return cachedStats
        end
    end
    return nil
end

local function loadJumpBase()
    if BaseStatsModule then
        local value = tonumber(BaseStatsModule.JumpHeight)
        if value and value > 0 then
            jumpBaseHeight = value
            return value
        end
    end
    return jumpBaseHeight
end

local function captureJumpBase()
    if jumpBaseHeight then
        return
    end
    local stats = getLiveMoveStats()
    if not stats then
        return
    end
    local value = tonumber(rawget(stats, "JumpHeight")) or 0
    if value > 0 then
        jumpBaseHeight = value
    end
end


local function applyJumpState()
    local baseHeight = loadJumpBase()
    if not baseHeight then
        return
    end
    local targetHeight = baseHeight * getJumpMultiplier()
    local stats = getLiveMoveStats()

    if stats and jumpLevel > 1 then
        pcall(setStatIfChanged, stats, "JumpHeight", targetHeight)
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    if humanoid and jumpLevel > 1 then
        pcall(function()
            if humanoid.UseJumpPower ~= false then
                humanoid.UseJumpPower = false
            end
            if humanoid.JumpHeight ~= targetHeight then
                humanoid.JumpHeight = targetHeight
            end
        end)
    end
    if stats then
        jumpBaseApplied = true
    end
end

local function setJumpLevel(value)
    jumpLevel = value
    pcall(applyJumpState)
end

local function applySpeed(value)
    speedMultiplier = value
    pcall(applyMoveStats)
end

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

local lastBaseStatsAttempt = 0
task.spawn(function()
    lastBaseStatsAttempt = os.clock()
    BaseStatsModule = findBaseStats()
    if not BaseStatsModule then
        lastBaseStatsAttempt = 0
        captureJumpBase()
    end
    pcall(applyMoveStats)
    pcall(applyJumpState)
    for _ = 1, 20 do
        if jumpBaseApplied then
            break
        end
        task.wait(0.25)
        pcall(applyMoveStats)
        pcall(applyJumpState)
    end
    while true do

        task.wait(5)
        if not BaseStatsModule then
            local now = os.clock()
            if now - lastBaseStatsAttempt >= 15 then
                lastBaseStatsAttempt = now
                BaseStatsModule = findBaseStats()
            end
        end
        pcall(applyMoveStats)
        if jumpLevel > 1 or not jumpBaseApplied then
            pcall(applyJumpState)
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(applyMoveStats)
    end
end)

player.CharacterAdded:Connect(function()
    cachedCharacterObject = nil
    cachedCharacterObjectAt = 0
    task.delay(1, function()
        captureJumpBase()
        pcall(applyMoveStats)
        pcall(applyJumpState)
    end)
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

local EvadeNet = {}

do
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

    local function findRoot(name)
        return ReplicatedStorage:FindFirstChild(name)
    end

    local function findRemote(remoteName, folderName)
        for _, rootName in ipairs({ "Events", "Remotes", "Shared" }) do
            local root = findRoot(rootName)
            if root then
                local parent = root
                if folderName then
                    parent = root:FindFirstChild(folderName)
                end
                if parent then
                    local remote = parent:FindFirstChild(remoteName)
                    if remote and isRemoteEvent(remote) then
                        return remote
                    end
                end
            end
        end
        return nil
    end

    EvadeNet.changeMode = findRemote("ChangePlayerMode", "Player") or findRemote("ChangePlayerMode")
    EvadeNet.respawn = findRemote("Respawn") or findRemote("Respawn", "Player") or findRemote("Respawn", "Character")
    EvadeNet.interact = findRemote("Interact", "Character") or findRemote("Revive", "Character")
    EvadeNet.compat = true

    function EvadeNet.FireRespawnCompat()
        local roots = {}
        for _, rootName in ipairs({ "Remotes", "Events" }) do
            local root = findRoot(rootName)
            if root then
                roots[#roots + 1] = root
            end
        end
        for _, root in ipairs(roots) do
            if tryPlayerModeRoot(root) then
                return true
            end
        end
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

    function EvadeNet.FireRespawnSafe()
        if EvadeNet.changeMode then
            local ok = pcall(function()
                EvadeNet.changeMode:FireServer(true)
            end)
            if ok then
                return true
            end
        end
        if EvadeNet.respawn then
            local ok = pcall(function()
                EvadeNet.respawn:FireServer()
            end)
            if ok then
                return true
            end
        end
        return false
    end
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

    if EvadeNet.compat then

        if now - downedSince < 1.5 then
            return
        end
        if reviveAttempts >= 30 then
            if now - lastReviveFire <= 30 then
                return
            end
            reviveAttempts = 0
        end
        if now - lastReviveFire < 1.5 then
            return
        end
        lastReviveFire = now
        reviveAttempts = reviveAttempts + 1
        EvadeNet.FireRespawnCompat()
        return
    end

    if now - downedSince < 2 then
        return
    end
    if reviveAttempts >= 2 then
        return
    end
    if now - lastReviveFire < 3 then
        return
    end
    lastReviveFire = now
    reviveAttempts = reviveAttempts + 1
    EvadeNet.FireRespawnSafe()
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
local cachedSpawnCenter = nil
local lastSpawnScan = 0

local platformTeleportSuppressedUntil = 0

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

local function scanContainers(scan)
    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder then
        local result = scan(gameFolder)
        if result then
            return result
        end
    end
    return scan(workspace)
end

local function centerFromSpawns()
    return scanContainers(function(root)
        local xs, ys, zs = {}, {}, {}
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("SpawnLocation") then
                xs[#xs + 1] = obj.Position.X
                ys[#ys + 1] = obj.Position.Y
                zs[#zs + 1] = obj.Position.Z
            end
        end
        if #xs == 0 then
            return nil
        end
        return Vector3.new(median(xs), median(ys), median(zs))
    end)
end

local function centerFromParts()
    return scanContainers(function(root)
        local xs, zs = {}, {}
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored then
                local sz = obj.Size
                if sz.X < 500 and sz.Z < 500 then
                    xs[#xs + 1] = obj.Position.X
                    zs[#zs + 1] = obj.Position.Z
                end
            end
        end
        if #xs == 0 then
            return nil
        end
        return Vector3.new(median(xs), 0, median(zs))
    end)
end

local function rescanCenter()
    local now = tick()

    if now - lastSpawnScan >= 10 then
        lastSpawnScan = now
        cachedSpawnCenter = centerFromSpawns()
    end

    local newCenter = nil
    local groundY = 0
    local spawnCenter = cachedSpawnCenter
    if spawnCenter then
        newCenter = spawnCenter
        groundY = spawnCenter.Y
    else
        if not cachedPartsCenter or (now - lastFallbackScan >= 60) then
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

    pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        Camera.CameraSubject = humanoid
    end
    Camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 5, 12), target)
end

local platformPinned = false

local function platformPinAnchor()
    if not platform then return nil end
    return Vector3.new(platform.Position.X, platform.Position.Y + platform.Size.Y / 2 + 3, platform.Position.Z)
end

local function setPlatformCollide(state)
    if platform and platform.Parent then
        pcall(function() platform.CanCollide = state end)
    end
end

local function snapCore(root, anchor)
    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    local current = root.CFrame
    root.CFrame = CFrame.new(anchor) * (current - current.Position)
end

local function snapToPlatformAnchor()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local anchor = platformPinAnchor()
    if not root or not anchor then return end
    pcall(snapCore, root, anchor)
end

local function pinToPlatform()
    if not platformEnabled or not platform then
        platformPinned = false
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not platformPinAnchor() then
        platformPinned = false
        return
    end
    platformPinned = true
    setPlatformCollide(true)
    snapToPlatformAnchor()
end

local function unpinPlatform()
    platformPinned = false
    setPlatformCollide(false)
end

local function destroyPlatformPin()
    platformPinned = false
    setPlatformCollide(false)
end

local function returnToPlatform()
    if not platformEnabled then return end
    pcall(teleportToPlatform)
    platformTeleportSuppressedUntil = tick() + 0.5
    pcall(pinToPlatform)
end

RunService.Heartbeat:Connect(function()
    if not platformPinned or not platformEnabled then return end
    snapToPlatformAnchor()
end)

RunService.RenderStepped:Connect(function()
    if not platformPinned or not platformEnabled then return end
    snapToPlatformAnchor()
end)

task.spawn(function()
    local lastRescan = 0

    while true do
        task.wait(0.1)
        if not platformEnabled then
            destroyPlatformPin()
            continue
        end

        local char = player.Character
        if not char then
            destroyPlatformPin()
            continue
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
            destroyPlatformPin()
            continue
        end

        local now = tick()
        if now - lastRescan >= 20 then
            lastRescan = now
            rescanCenter()
        end

        if not platform or not platform.Parent then
            if hasCenter then buildPlatform() end
        end

        if not platform then
            destroyPlatformPin()
            continue
        end

        local top = platform.Position.Y + platform.Size.Y / 2
        local anchor = Vector3.new(platform.Position.X, top + 3, platform.Position.Z)
        local dropped = root.Position.Y < (top - 25)
        local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
        local flatAnchor = Vector3.new(anchor.X, 0, anchor.Z)
        local farAway = (flat - flatAnchor).Magnitude > math.max(platform.Size.X * 0.15, 20)

        if now < platformTeleportSuppressedUntil then
            destroyPlatformPin()
        elseif dropped or farAway then
            teleportToPlatform()
            pinToPlatform()
        elseif isDowned() then
            platformPinned = false
            setPlatformCollide(true)
        else
            pinToPlatform()
        end
    end
end)

player.CharacterAdded:Connect(function(char)
    task.wait(1)
    char:WaitForChild("HumanoidRootPart", 5)
    if platformEnabled then
        teleportToPlatform()
        pinToPlatform()
    end
end)

local rescueEnabled = false
local rescueCurrentTarget = nil
local rescueSelfDowned = false
local rescueVelocity = nil

local rescueCFG = {
    HoverHeight = 3,
    FlySpeed = 2500,
    ArriveDist = 3,
    HoldDistance = 15,
    PressE = true,
    PressInterval = 0.02,
    TargetSwitchDelay = 1.5,
    MaxDistance = 3000,
    UpdateInterval = 0.03,
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

local function destroyRescueVelocity(stop)
    if rescueVelocity then
        pcall(function() rescueVelocity:Destroy() end)
        rescueVelocity = nil
    end
    if stop then
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            pcall(function()
                root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end)
        end
    end
end

local function rescueRestoreMove()
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
            pcall(applyJumpState)
        end
    end
    destroyRescueVelocity()
end

local rescuePrompt = {
    held = nil,
    startedAt = 0,
    lastInteractFire = 0,
}

local function rescueHoldKey()
    local target = rescueCurrentTarget
    if not target or not target.Parent then
        return
    end
    local prompt = nil
    pcall(function()
        prompt = target:FindFirstChildWhichIsA("ProximityPrompt", true)
    end)
    if prompt and prompt.Enabled then
        if rescuePrompt.held ~= prompt then
            if rescuePrompt.held then
                pcall(function()
                    rescuePrompt.held:InputHoldEnd()
                end)
            end
            rescuePrompt.held = prompt
            rescuePrompt.startedAt = os.clock()
            pcall(function()
                prompt:InputHoldBegin()
            end)
        elseif os.clock() - rescuePrompt.startedAt > 10 then

            pcall(function()
                prompt:InputHoldEnd()
            end)
            rescuePrompt.held = nil
        end
        return
    end

    local now = os.clock()
    if EvadeNet.interact and now - rescuePrompt.lastInteractFire >= 1 then
        rescuePrompt.lastInteractFire = now
        local targetName = target.Name
        pcall(function()
            EvadeNet.interact:FireServer("Revive", true, targetName)
        end)
    end
end

local function rescueReleaseKey()
    local prompt = rescuePrompt.held
    rescuePrompt.held = nil
    if prompt then
        pcall(function()
            prompt:InputHoldEnd()
        end)
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
            destroyRescueVelocity(true)
            if platformEnabled then
                returnToPlatform()
            end
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
            destroyRescueVelocity(true)
            continue
        end

        local myRoot = myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then continue end

        if platformEnabled then
            platformTeleportSuppressedUntil = tick() + 1.5
            unpinPlatform()
            if myRoot.Position.Y - targetRoot.Position.Y > 60 then
                local landing = targetRoot.Position + Vector3.new(0, rescueCFG.HoverHeight + 20, 0)
                pcall(function()
                    myChar:PivotTo(CFrame.new(landing))
                end)
            end
        end

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

local itemFarmEnabled = false
local itemFarmPickupDelay = 0.15
local itemFarmBlacklist = {}

local function getEffectsFolder()
    local effects = workspace:FindFirstChild("Effects")
    if effects then
        return effects
    end
    local gameFolder = workspace:FindFirstChild("Game")
    return gameFolder and gameFolder:FindFirstChild("Effects")
end

local function getTicketContainer()
    local effects = getEffectsFolder()
    if not effects then
        return nil
    end
    return effects:FindFirstChild("Tickets")
end

local function itemPosition(item)
    if item:IsA("BasePart") then
        return item.Position
    end
    if item:IsA("Model") or item:IsA("Tool") then
        local primary = item.PrimaryPart
        if primary then
            return primary.Position
        end
        local part = item:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.Position
        end
        local ok, pivot = pcall(function()
            return item:GetPivot().Position
        end)
        if ok then
            return pivot
        end
    end
    return nil
end

local function getVisiblePart(item)
    if item:IsA("BasePart") then
        if item.Transparency < 0.95 then
            return item
        end
        return nil
    end
    local primary = nil
    if item:IsA("Model") then
        primary = item.PrimaryPart
    end
    if primary and primary.Transparency < 0.95 then
        return primary
    end
    for _, descendant in ipairs(item:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Transparency < 0.95 then
            return descendant
        end
    end
    return nil
end

local function getTicketPosition(ticket, part)
    if ticket:IsA("BasePart") then
        return ticket.Position
    end
    if ticket:IsA("Model") then
        local ok, box = pcall(function()
            return ticket:GetBoundingBox()
        end)
        if ok and box then
            return box.Position
        end
    end
    if part then
        return part.Position
    end
    return itemPosition(ticket)
end

local function collectActiveTickets()
    local container = getTicketContainer()
    if not container then
        return {}
    end
    local result = {}
    local function walk(folder, depth)
        if depth > 4 then
            return
        end
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("Folder") then
                walk(child, depth + 1)
            elseif child:IsA("Model") or child:IsA("Tool") or child:IsA("BasePart") then
                local part = nil
                if child:IsA("BasePart") then
                    part = child
                else
                    part = getVisiblePart(child)
                end
                if part then
                    local position = getTicketPosition(child, part)
                    if position then
                        result[#result + 1] = { object = child, part = part, position = position }
                    end
                end
            end
        end
    end
    walk(container, 0)
    return result
end

local function pressE()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end)
    task.wait(0.05)
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function fireTouch(rootPart, part)
    if type(firetouchinterest) ~= "function" then
        return false
    end
    local ok = pcall(function()
        firetouchinterest(rootPart, part, false)
    end)
    task.wait(0.03)
    pcall(function()
        firetouchinterest(rootPart, part, true)
    end)
    return ok
end

local function interactTicket(rootPart, ticket, part)
    local prompt = ticket:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt and prompt.Enabled then
        if type(fireproximityprompt) == "function" then
            if pcall(fireproximityprompt, prompt) then
                return
            end
        end
        local ok = pcall(function()
            prompt:InputHoldBegin()
            task.wait(math.clamp(tonumber(prompt.HoldDuration) or 0, 0, 0.4))
            prompt:InputHoldEnd()
        end)
        if ok then
            return
        end
    end
    local clickDetector = ticket:FindFirstChildWhichIsA("ClickDetector", true)
    if clickDetector and type(fireclickdetector) == "function" then
        if pcall(fireclickdetector, clickDetector) then
            return
        end
    end
    if fireTouch(rootPart, part) then
        return
    end
    pressE()
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if not itemFarmEnabled then
            itemFarmBlacklist = {}
            continue
        end
        local container = getTicketContainer()
        if not container then
            continue
        end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            continue
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then
            continue
        end
        local downedOk, downedValue = pcall(function()
            return character:GetAttribute("Downed")
        end)
        if downedOk and downedValue == true then
            continue
        end

        local now = tick()
        local best = nil
        local bestDistance = math.huge
        for _, entry in ipairs(collectActiveTickets()) do
            local blacklistedUntil = itemFarmBlacklist[entry.object]
            if not blacklistedUntil or now >= blacklistedUntil then
                local distance = (entry.position - root.Position).Magnitude
                if distance < bestDistance then
                    best, bestDistance = entry, distance
                end
            end
        end
        if not best then
            continue
        end

        if platformEnabled then
            platformTeleportSuppressedUntil = tick() + 2
            unpinPlatform()
        end

        pcall(function()
            character:PivotTo(CFrame.new(best.position + Vector3.new(0, 3, 0)))
        end)
        task.wait(0.08)
        pcall(function()
            character:PivotTo(CFrame.new(best.position))
        end)
        task.wait(0.05)
        interactTicket(root, best.object, best.part)
        task.wait(itemFarmPickupDelay)

        local stillThere = best.object.Parent ~= nil and getVisiblePart(best.object) ~= nil
        if stillThere then
            itemFarmBlacklist[best.object] = tick() + 1.5
        end

        if platformEnabled then
            returnToPlatform()
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

local helpSection = Tab:Section({
    Title = "快捷键说明",
    IconName = "keyboard"
})

helpSection:Paragraph({
    Title = "显示 / 隐藏 UI",
    Desc = "按 Insert 或 F2 键"
})

helpSection:Paragraph({
    Title = "打开 / 关闭自动跳跃",
    Desc = "按 Home 或 F3 键"
})

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

autoJumpToggleRef = moveSection:Toggle({
    Title = "自动跳跃",
    Value = false,
    Callback = function(state)
        autoJumpEnabled = state
    end
})

moveSection:Slider({
    Title = "移动速度倍率",
    Value = {
        Min = 1,
        Max = 10,
        Default = 1,
    },
    Callback = function(value)
        applySpeed(value)
    end
})

moveSection:Slider({
    Title = "跳跃高度",
    Value = {
        Min = 1,
        Max = 100,
        Default = 1,
    },
    Callback = function(value)
        setJumpLevel(value)
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

reviveSection:Toggle({
    Title = "自动复活(兼容模式)",
    Value = true,
    Callback = function(state)
        EvadeNet.compat = state
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
            destroyPlatformPin()
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
        pinToPlatform()
    end
})

local itemSection = Tab:Section({
    Title = "活动道具",
    IconName = "hand-heart"
})

itemSection:Toggle({
    Title = "自动拾取活动道具",
    Value = false,
    Callback = function(state)
        itemFarmEnabled = state
    end
})

itemSection:Slider({
    Title = "拾取间隔",
    Value = {
        Min = 0.05,
        Max = 0.6,
        Default = 0.15,
    },
    Callback = function(value)
        itemFarmPickupDelay = value
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

task.spawn(function()
    local brokenTicks = 0
    while true do
        task.wait(1)
        local ok = pcall(function()
            local pg = player:FindFirstChildOfClass("PlayerGui")
            if not pg then
                brokenTicks = 0
                return
            end
            local gameGui = pg:FindFirstChild("Game")
            local shared = pg:FindFirstChild("Shared")
            if not (gameGui and shared) then
                brokenTicks = 0
                return
            end
            local char = player.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            local downed = char and char:GetAttribute("Downed")
            local healthy = humanoid == nil or humanoid.Health > 0
            if (not gameGui.Enabled) and (not shared.Enabled) and healthy and not downed then
                brokenTicks = brokenTicks + 1
                if brokenTicks >= 2 then
                    gameGui.Enabled = true
                    shared.Enabled = true
                    brokenTicks = 0
                    local hud = gameGui:FindFirstChild("HUD")
                    local interactors = hud and hud:FindFirstChild("Interactors")
                    local popups = interactors and interactors:FindFirstChild("Popups")
                    if popups then
                        for _, child in ipairs(popups:GetChildren()) do
                            if child.Visible then
                                pcall(function()
                                    child.Visible = false
                                end)
                            end
                        end
                    end
                end
            else
                brokenTicks = 0
            end
        end)
        if not ok then
            brokenTicks = 0
        end
    end
end)

local UI_HIDE_KEYS = { Enum.KeyCode.Insert, Enum.KeyCode.F2 }
local AUTO_JUMP_KEYS = { Enum.KeyCode.Home, Enum.KeyCode.F3 }
local uiHidden = false

local UI_SCREEN_GUI_FIELDS = { "ScreenGui", "NotificationGui", "DropdownGui", "TooltipGui" }

local function setWindUiEnabled(enabled)
    for _, field in ipairs(UI_SCREEN_GUI_FIELDS) do
        local gui = WindUI[field]
        if gui then
            pcall(function()
                gui.Enabled = enabled
            end)
        end
    end
end

local function hideOpenButton()
    pcall(function()
        local openButton = Window.OpenButtonMain
        if openButton then
            openButton:Visible(false)
        end
    end)
end

local function setUiHidden(hidden)
    uiHidden = hidden
    pcall(function()
        Window.IsOpenButtonEnabled = not hidden
    end)
    if hidden then
        pcall(function()
            Window:Close()
        end)
        hideOpenButton()
        task.delay(0.5, hideOpenButton)
        setWindUiEnabled(false)
    else
        setWindUiEnabled(true)
        pcall(function()
            Window:Open()
        end)
        local elements = Window.UIElements
        if elements and elements.Main then
            pcall(function()
                elements.Main.Visible = true
            end)
        end
        hideOpenButton()
    end
end

local function matchesKeyCode(input, keyCodes)
    for _, keyCode in ipairs(keyCodes) do
        if input.KeyCode == keyCode then
            return true
        end
    end
    return false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end
    if UserInputService:GetFocusedTextBox() then
        return
    end
    if matchesKeyCode(input, UI_HIDE_KEYS) then
        setUiHidden(not uiHidden)
        return
    end
    if matchesKeyCode(input, AUTO_JUMP_KEYS) then
        autoJumpEnabled = not autoJumpEnabled
        if autoJumpToggleRef then
            pcall(function()
                autoJumpToggleRef:Set(autoJumpEnabled)
            end)
        end
        pcall(function()
            WindUI:Notify({
                Title = "自动跳跃",
                Content = autoJumpEnabled and "已开启" or "已关闭",
                Duration = 1.5
            })
        end)
    end
end)
