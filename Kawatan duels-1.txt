--[[
========================================

╔════════════════════════╗
║          Cypher Spectre ║ DeepSight    ║  
╚════════════════════════╝

Script Deobfuscated by Cypher Spectre
Version: DeepSight 

Author:
@roman666cabj

========================================
]]

-- Kawatan Duels

--// OPTIMIZER FPS (REAL)
local Lighting = game:GetService("Lighting")
local optimizerEnabled = false
local savedLighting = {}
local optimized = {}

local function enableOptimizer()
    if optimizerEnabled then return end
    optimizerEnabled = true

--// SETUP CHARACTER

local function setupCharacter(char)

    character = char

    hrp = character:WaitForChild("HumanoidRootPart")

    hum = character:WaitForChild("Humanoid")

end    savedLighting = {
        GlobalShadows = Lighting.GlobalShadows,
        FogStart = Lighting.FogStart,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
    }

    Lighting.GlobalShadows = false
    Lighting.FogStart = 0
    Lighting.FogEnd = 1e9
    Lighting.Brightness = 1
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0

    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            optimized[v] = {v.Material, v.Reflectance}
            v.Material = Enum.Material.Plastic
            v.Reflectance = 0

        elseif v:IsA("Decal") or v:IsA("Texture") then
            optimized[v] = v.Transparency
            v.Transparency = 1

        elseif v:IsA("ParticleEmitter")
        or v:IsA("Trail")
        or v:IsA("Smoke")
        or v:IsA("Fire") then
            optimized[v] = v.Enabled
            v.Enabled = false
        end
    end
end

local function disableOptimizer()
    if not optimizerEnabled then return end
    optimizerEnabled = false

    for k,v in pairs(savedLighting) do
        Lighting[k] = v
    end

    for obj,val in pairs(optimized) do
        if obj and obj.Parent then
            if typeof(val) == "table" then
                obj.Material = val[1]
                obj.Reflectance = val[2]
            elseif typeof(val) == "boolean" then
                obj.Enabled = val
            else
                obj.Transparency = val
            end
        end
    end

    optimized = {}
end

--// XRAY BASE SOLO TRANSPARENCIA (SIN HIGHLIGHT)

local baseOriginalTransparencies = {}
local plotConnections = {}
local xrayConnection

local function applyXray(plot)
    if baseOriginalTransparencies[plot] then return end

    baseOriginalTransparencies[plot] = {}

    -- Quitar SOLO el highlight viejo del Xray si existe
    local oldHL = plot:FindFirstChild("BaseXRayHighlight")
    if oldHL then
        oldHL:Destroy()
    end

    for _, part in ipairs(plot:GetDescendants()) do
        if part:IsA("BasePart") then

            -- Si tenía highlight viejo del Xray, eliminarlo
            local oldPartHL = part:FindFirstChild("BaseXRayHighlight")
            if oldPartHL then
                oldPartHL:Destroy()
            end

            -- Aplicar transparencia normal
            if part.Transparency < 0.6 then
                baseOriginalTransparencies[plot][part] = part.Transparency
                part.Transparency = 0.68
            end
        end
    end

    -- Detectar regeneración interna
    plotConnections[plot] = plot.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            if desc.Transparency < 0.6 then
                baseOriginalTransparencies[plot][desc] = desc.Transparency
                desc.Transparency = 0.68
            end
        end
    end)
end

function toggleESPBases(enable)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end

    if not enable then
        -- Desconectar conexiones
        for _, conn in pairs(plotConnections) do
            conn:Disconnect()
        end
        plotConnections = {}

        if xrayConnection then
            xrayConnection:Disconnect()
            xrayConnection = nil
        end

        -- Restaurar transparencias originales
        for plot, parts in pairs(baseOriginalTransparencies) do
            for part, original in pairs(parts) do
                if part and part.Parent then
                    part.Transparency = original
                end
            end
        end

        baseOriginalTransparencies = {}
        return
    end

    -- Aplicar a plots actuales
    for _, plot in ipairs(plots:GetChildren()) do
        applyXray(plot)
    end

    -- Detectar plots nuevos
    xrayConnection = plots.ChildAdded:Connect(function(newPlot)
        task.wait(0.2)
        applyXray(newPlot)
    end)
end

--// ESP PLAYERS AZUL (INCLUYE INVISIBLES)

local Players = game:GetService("Players")
local lp = Players.LocalPlayer

local espConnections = {}
local espEnabled = false

local function createESP(plr)
	if plr == lp then return end
	if not plr.Character then return end
	if plr.Character:FindFirstChild("ESP_BLUE") then return end

	local char = plr.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local head = char:FindFirstChild("Head")
	if not (hrp and head) then return end

	--------------------------------------------------
	-- HIGHLIGHT AZUL
	--------------------------------------------------

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESP_BLUE"
	highlight.FillColor = Color3.fromRGB(0,120,255)
	highlight.OutlineColor = Color3.fromRGB(0,120,255)
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = char

	--------------------------------------------------
	-- HITBOX AZUL
	--------------------------------------------------

	local hitbox = Instance.new("BoxHandleAdornment")
	hitbox.Name = "ESP_Hitbox"
	hitbox.Adornee = hrp
	hitbox.Size = Vector3.new(4,6,2)
	hitbox.Color3 = Color3.fromRGB(0,120,255)
	hitbox.Transparency = 0.5
	hitbox.AlwaysOnTop = true
	hitbox.ZIndex = 10
	hitbox.Parent = char

	--------------------------------------------------
	-- NOMBRE AZUL
	--------------------------------------------------

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ESP_Name"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0,200,0,50)
	billboard.StudsOffset = Vector3.new(0,3,0)
	billboard.AlwaysOnTop = true
	billboard.Parent = char

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1,0,1,0)
	label.BackgroundTransparency = 1
	label.Text = plr.DisplayName or plr.Name
	label.TextColor3 = Color3.fromRGB(0,120,255)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.6
	label.TextStrokeColor3 = Color3.fromRGB(0,0,0)
	label.Parent = billboard
end

local function removeESP(plr)
	if not plr.Character then return end

	local char = plr.Character

	local highlight = char:FindFirstChild("ESP_BLUE")
	if highlight then highlight:Destroy() end

	local hitbox = char:FindFirstChild("ESP_Hitbox")
	if hitbox then hitbox:Destroy() end

	local name = char:FindFirstChild("ESP_Name")
	if name then name:Destroy() end
end

function toggleESPPlayers(enable)
	espEnabled = enable

	if enable then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= lp then
				if plr.Character then
					createESP(plr)
				end

				local conn = plr.CharacterAdded:Connect(function()
					task.wait(0.2)
					if espEnabled then
						createESP(plr)
					end
				end)

				table.insert(espConnections, conn)
			end
		end

		local playerAddedConn = Players.PlayerAdded:Connect(function(plr)
			if plr == lp then return end

			local charAddedConn = plr.CharacterAdded:Connect(function()
				task.wait(0.2)
				if espEnabled then
					createESP(plr)
				end
			end)

			table.insert(espConnections, charAddedConn)
		end)

		table.insert(espConnections, playerAddedConn)

	else
		for _, plr in ipairs(Players:GetPlayers()) do
			removeESP(plr)
		end

		for _, conn in ipairs(espConnections) do
			if conn and conn.Connected then
				conn:Disconnect()
			end
		end

		espConnections = {}
	end
end

--// ANTI SENTRY / TORRETA

local antiSentryConnection
local antiSentryTarget

local DETECTION_DISTANCE = 60
local PULL_DISTANCE = -5

local function getCharacter()
    return game.Players.LocalPlayer.Character
end

local function getWeapon()
    local player = game.Players.LocalPlayer
    local char = getCharacter()
    if not char then return nil end
    return player.Backpack:FindFirstChild("Bat") or char:FindFirstChild("Bat")
end

local function findSentryTarget()
    local player = game.Players.LocalPlayer
    local char = getCharacter()
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local rootPos = char.HumanoidRootPart.Position

    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name:find("Sentry") and not obj.Name:lower():find("bullet") then

            local ownerId = obj.Name:match("Sentry_(%d+)")
            if ownerId and tonumber(ownerId) == player.UserId then
                continue
            end

            local part = obj:IsA("BasePart") and obj
                or obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))

            if part and (rootPos - part.Position).Magnitude <= DETECTION_DISTANCE then
                return obj
            end
        end
    end
end

local function moveSentry(obj)
    local char = getCharacter()
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    for _, part in pairs(obj:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    local root = char.HumanoidRootPart
    local cf = root.CFrame * CFrame.new(0, 0, PULL_DISTANCE)

    if obj:IsA("BasePart") then
        obj.CFrame = cf
    elseif obj:IsA("Model") then
        local main = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if main then
            main.CFrame = cf
        end
    end
end

local function attackSentry()
    local char = getCharacter()
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local weapon = getWeapon()
    if not weapon then return end

    if weapon.Parent == game.Players.LocalPlayer.Backpack then
        hum:EquipTool(weapon)
        task.wait(0.1)
    end

    local handle = weapon:FindFirstChild("Handle")
    if handle then
        handle.CanCollide = false
    end

    pcall(function()
        weapon:Activate()
    end)

    for _, r in pairs(weapon:GetDescendants()) do
        if r:IsA("RemoteEvent") then
            pcall(function()
                r:FireServer()
            end)
        end
    end
end

local function startAntiSentry()
    if antiSentryConnection then return end

    antiSentryConnection = game:GetService("RunService").Heartbeat:Connect(function()

        if antiSentryTarget and antiSentryTarget.Parent == workspace then
            moveSentry(antiSentryTarget)
            attackSentry()
        else
            antiSentryTarget = findSentryTarget()
        end

    end)
end

local function stopAntiSentry()
    if antiSentryConnection then
        antiSentryConnection:Disconnect()
        antiSentryConnection = nil
    end
    antiSentryTarget = nil
end

-- =========================
-- ANTI BEE & DISCO SYSTEM
-- =========================

local player = game.Players.LocalPlayer

local ANTI_BEE_DISCO = {
	enabled = false,
	connections = {},
	originalMoveFunction = nil,
	controlsProtected = false
}

local BAD_LIGHTING_NAMES = {
	Blue = true,
	DiscoEffect = true,
	BeeBlur = true,
	ColorCorrection = true,
}

local function antiBeeDiscoNuke(obj)
	if not obj or not obj.Parent then return end
	if BAD_LIGHTING_NAMES[obj.Name] then
		pcall(function()
			obj:Destroy()
		end)
	end
end

local function antiBeeDiscoDisconnectAll()
	for _, conn in ipairs(ANTI_BEE_DISCO.connections) do
		if typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	ANTI_BEE_DISCO.connections = {}
end

local function protectControls()
	if ANTI_BEE_DISCO.controlsProtected then return end

	pcall(function()
		local PlayerScripts = player.PlayerScripts
		local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
		if not PlayerModule then return end

		local Controls = require(PlayerModule):GetControls()
		if not Controls then return end

		if not ANTI_BEE_DISCO.originalMoveFunction then
			ANTI_BEE_DISCO.originalMoveFunction = Controls.moveFunction
		end

		local function protectedMoveFunction(self, moveVector, relativeToCamera)
			if ANTI_BEE_DISCO.originalMoveFunction then
				ANTI_BEE_DISCO.originalMoveFunction(self, moveVector, relativeToCamera)
			end
		end

		local controlCheckConn = game:GetService("RunService").Heartbeat:Connect(function()
			if not ANTI_BEE_DISCO.enabled then return end

			if Controls.moveFunction ~= protectedMoveFunction then
				Controls.moveFunction = protectedMoveFunction
			end
		end)

		table.insert(ANTI_BEE_DISCO.connections, controlCheckConn)
		Controls.moveFunction = protectedMoveFunction
		ANTI_BEE_DISCO.controlsProtected = true
	end)
end

local function restoreControls()
	if not ANTI_BEE_DISCO.controlsProtected then return end

	pcall(function()
		local PlayerScripts = player.PlayerScripts
		local PlayerModule = PlayerScripts:FindFirstChild("PlayerModule")
		if not PlayerModule then return end

		local Controls = require(PlayerModule):GetControls()
		if not Controls or not ANTI_BEE_DISCO.originalMoveFunction then return end

		Controls.moveFunction = ANTI_BEE_DISCO.originalMoveFunction
		ANTI_BEE_DISCO.controlsProtected = false
	end)
end

local function blockBuzzingSound()
	pcall(function()
		local PlayerScripts = player.PlayerScripts
		local beeScript = PlayerScripts:FindFirstChild("Bee", true)
		if beeScript then
			local buzzing = beeScript:FindFirstChild("Buzzing")
			if buzzing and buzzing:IsA("Sound") then
				buzzing:Stop()
				buzzing.Volume = 0
			end
		end
	end)
end

local function enableAntiBee()
	if ANTI_BEE_DISCO.enabled then return end
	ANTI_BEE_DISCO.enabled = true

	local Lighting = game:GetService("Lighting")

	for _, inst in ipairs(Lighting:GetDescendants()) do
		antiBeeDiscoNuke(inst)
	end

	local addedConn = Lighting.DescendantAdded:Connect(function(obj)
		if not ANTI_BEE_DISCO.enabled then return end
		antiBeeDiscoNuke(obj)
	end)

	table.insert(ANTI_BEE_DISCO.connections, addedConn)

	protectControls()

	local soundConn = game:GetService("RunService").Heartbeat:Connect(function()
		if not ANTI_BEE_DISCO.enabled then return end
		blockBuzzingSound()
	end)

	table.insert(ANTI_BEE_DISCO.connections, soundConn)
end

local function disableAntiBee()
	if not ANTI_BEE_DISCO.enabled then return end
	ANTI_BEE_DISCO.enabled = false

	restoreControls()
	antiBeeDiscoDisconnectAll()
end

--// =========================
-- ANTI FPS DEVOURER SYSTEM (FULL 3D CLOTHING REMOVER)
-- =========================

local ANTI_FPS_DEVOURER = {
    enabled = false,
    connections = {},
    hiddenAccessories = {}
}

-- Ocultar accesorio específico
local function removeAccessory(accessory)
    if not ANTI_FPS_DEVOURER.hiddenAccessories[accessory] then
        ANTI_FPS_DEVOURER.hiddenAccessories[accessory] = accessory.Parent
        accessory.Parent = nil
    end
end

-- Escanear modelo completo
local function scanModel(model)
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("Accessory") then
            removeAccessory(obj)
        end
    end
end

function enableAntiFPSDevourer()
    if ANTI_FPS_DEVOURER.enabled then return end
    ANTI_FPS_DEVOURER.enabled = true

    -- 🔥 Escanear TODO el workspace (jugadores, clones, NPCs)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Accessory") then
            removeAccessory(obj)
        end
    end

    -- 🔥 Detectar nuevos objetos (Quantum Cloner incluido)
    local conn = workspace.DescendantAdded:Connect(function(obj)
        if ANTI_FPS_DEVOURER.enabled then
            if obj:IsA("Accessory") then
                removeAccessory(obj)
            end
        end
    end)

    table.insert(ANTI_FPS_DEVOURER.connections, conn)
end

function disableAntiFPSDevourer()
    if not ANTI_FPS_DEVOURER.enabled then return end
    ANTI_FPS_DEVOURER.enabled = false

    -- Desconectar
    for _, conn in ipairs(ANTI_FPS_DEVOURER.connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end

    ANTI_FPS_DEVOURER.connections = {}

    -- Restaurar accesorios
    for accessory, originalParent in pairs(ANTI_FPS_DEVOURER.hiddenAccessories) do
        if accessory then
            accessory.Parent = originalParent
        end
    end

    ANTI_FPS_DEVOURER.hiddenAccessories = {}
end

--// SERVICES

local Players = game:GetService("Players")

local RunService = game:GetService("RunService")

local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Hitbox Expander (controlado por toggle "Aimbot")
local hitboxExpanded = false
local originalHRPSizes = {}          -- para guardar y restaurar
local hitboxPlayerAddedConn = nil

local character, hrp, hum

--// MELEE AIMBOT (INTEGRADO AL HUB)
-- Insertar DESPUÉS de las definiciones de servicios y ANTES de setupCharacter

local MELEE_RANGE = 45
local MELEE_ONLY_ENEMIES = true  -- Puedes hacer toggle si quieres, pero por ahora fijo

local meleeEnabled = false
local meleeConnection
local meleeAlignOrientation
local meleeAttachment

local function isValidMeleeTarget(humanoid, rootPart)
    if not (humanoid and rootPart) then return false end
    if humanoid.Health <= 0 then return false end

    if MELEE_ONLY_ENEMIES then
        local targetPlayer = Players:GetPlayerFromCharacter(humanoid.Parent)
        if not targetPlayer or targetPlayer == player then
            return false
        end
    end

    return true
end

local function getClosestMeleeTarget(hrp)
    local closest
    local minDist = MELEE_RANGE

    for _, p in ipairs(Players:GetPlayers()) do
        if p == player then continue end
        local char = p.Character
        if not char then continue end

        local targetHrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if isValidMeleeTarget(hum, targetHrp) then
            local dist = (targetHrp.Position - hrp.Position).Magnitude
            if dist < minDist then
                minDist = dist
                closest = targetHrp
            end
        end
    end

    return closest
end

local function createMeleeAimbot(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 8)
    local humanoid = char:WaitForChild("Humanoid", 8)

    if not (hrp and humanoid) then return end

    -- Cleanup viejo
    if meleeAlignOrientation then
        pcall(function() meleeAlignOrientation:Destroy() end)
    end
    if meleeAttachment then
        pcall(function() meleeAttachment:Destroy() end)
    end

    meleeAttachment = Instance.new("Attachment")
    meleeAttachment.Parent = hrp

    meleeAlignOrientation = Instance.new("AlignOrientation")
    meleeAlignOrientation.Attachment0 = meleeAttachment
    meleeAlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
    meleeAlignOrientation.RigidityEnabled = true
    meleeAlignOrientation.MaxTorque = 100000
    meleeAlignOrientation.Responsiveness = 200
    meleeAlignOrientation.Parent = hrp

    if meleeConnection then
        meleeConnection:Disconnect()
    end

    meleeConnection = RunService.RenderStepped:Connect(function()
        if not char.Parent or not meleeEnabled then return end

        local target = getClosestMeleeTarget(hrp)

        if target then
            humanoid.AutoRotate = false
            meleeAlignOrientation.Enabled = true
            local targetPos = Vector3.new(target.Position.X, hrp.Position.Y, target.Position.Z)
            meleeAlignOrientation.CFrame = CFrame.lookAt(hrp.Position, targetPos)
        else
            meleeAlignOrientation.Enabled = false
            humanoid.AutoRotate = true
        end
    end)
end

local function disableMeleeAimbot()
    meleeEnabled = false

    if meleeConnection then
        meleeConnection:Disconnect()
        meleeConnection = nil
    end

    if meleeAlignOrientation then
        meleeAlignOrientation.Enabled = false
        pcall(function() meleeAlignOrientation:Destroy() end)
        meleeAlignOrientation = nil
    end

    if character and character:FindFirstChild("Humanoid") then
        character.Humanoid.AutoRotate = true
    end

    if meleeAttachment then
        pcall(function() meleeAttachment:Destroy() end)
        meleeAttachment = nil
    end
end

--// 🔥 NEW ADVANCED ANTI RAGDOLL

local antiRagdollMode = nil
local ragdollConnections = {}
local cachedCharData = {}

local function cacheCharacterData()
    local char = player.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    if not hum or not root then return false end

    cachedCharData = {
        character = char,
        humanoid = hum,
        root = root,
        originalWalkSpeed = hum.WalkSpeed,
        originalJumpPower = hum.JumpPower,
        isFrozen = false
    }

    return true
end

local function disconnectAllRagdoll()
    for _, conn in ipairs(ragdollConnections) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    ragdollConnections = {}
end

local function isRagdolled()
    if not cachedCharData.humanoid then return false end

    local hum = cachedCharData.humanoid
    local state = hum:GetState()

    if state == Enum.HumanoidStateType.Physics
    or state == Enum.HumanoidStateType.Ragdoll
    or state == Enum.HumanoidStateType.FallingDown then
        return true
    end

    local endTime = player:GetAttribute("RagdollEndTime")
    if endTime then
        local now = workspace:GetServerTimeNow()
        if (endTime - now) > 0 then
            return true
        end
    end

    return false
end

local function removeRagdollConstraints()
    if not cachedCharData.character then return end

    for _, descendant in ipairs(cachedCharData.character:GetDescendants()) do
        if descendant:IsA("BallSocketConstraint") or
           (descendant:IsA("Attachment") and descendant.Name:find("RagdollAttachment")) then
            pcall(function()
                descendant:Destroy()
            end)
        end
    end
end

local function forceExitRagdoll()
    if not cachedCharData.humanoid or not cachedCharData.root then return end

    local hum = cachedCharData.humanoid
    local root = cachedCharData.root

    pcall(function()
        local now = workspace:GetServerTimeNow()
        player:SetAttribute("RagdollEndTime", now)
    end)

    if hum.Health > 0 then
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end

    root.Anchored = false
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function antiRagdollLoop()
    while antiRagdollMode do
        task.wait()

        if isRagdolled() then
            removeRagdollConstraints()
            forceExitRagdoll()
        end

        -- 🔥 AUTO CAMERA FIX
        local cam = workspace.CurrentCamera
        if cam and cachedCharData.humanoid then
            if cam.CameraSubject ~= cachedCharData.humanoid then
                cam.CameraSubject = cachedCharData.humanoid
            end
        end
    end
end

function toggleAntiRagdoll(enable)
    if enable then
        disconnectAllRagdoll()
        if not cacheCharacterData() then return end

        antiRagdollMode = "v1"

        local charConn = player.CharacterAdded:Connect(function()
            task.wait(0.5)
            if antiRagdollMode then
                cacheCharacterData()
            end
        end)

        table.insert(ragdollConnections, charConn)
        task.spawn(antiRagdollLoop)

    else
        antiRagdollMode = nil
        disconnectAllRagdoll()
        cachedCharData = {}
    end
end

--// SETUP CHARACTER

local function setupCharacter(char)

    character = char

    hrp = character:WaitForChild("HumanoidRootPart")

    hum = character:WaitForChild("Humanoid")

    -- 🔥 NUEVO: Recrear Melee Aimbot si está activado
    if meleeEnabled then
        task.spawn(function()
            task.wait(0.3)
            createMeleeAimbot(char)
        end)
    end

end

if player.Character then

    setupCharacter(player.Character)

end

player.CharacterAdded:Connect(setupCharacter)

--// GUI

local gui = Instance.new("ScreenGui")

gui.Name = "BoosterCustomizer"

gui.ResetOnSpawn = false

gui.Enabled = false -- 👈 IMPORTANTE (empieza oculto)

gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")

main.Size = UDim2.new(0,200,0,185)

main.Position = UDim2.new(0.5,-100,0.15,0)

main.BackgroundColor3 = Color3.fromRGB(0,0,0)

main.BackgroundTransparency = 0.35

main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0,10)

local stroke = Instance.new("UIStroke", main)

stroke.Color = Color3.fromRGB(0,120,255)

stroke.Thickness = 2

--// DRAG HANDLE (barra superior)

local dragHandle = Instance.new("Frame")

dragHandle.Size = UDim2.new(1,0,0,30)

dragHandle.Position = UDim2.new(0,0,0,0)

dragHandle.BackgroundTransparency = 1

dragHandle.Parent = main

--// DRAGGING LOGIC ESTABLE (PC + MOBILE)

local dragging = false

local dragInput = nil

local dragStart = Vector2.new()

local startPos = Vector2.new()

local function update(input)

    local delta = input.Position - dragStart

    main.Position = UDim2.new(

        0,

        startPos.X + delta.X,

        0,

        startPos.Y + delta.Y

    )

end

dragHandle.InputBegan:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1

    or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true

        dragInput = input

        dragStart = input.Position

        startPos = Vector2.new(main.AbsolutePosition.X, main.AbsolutePosition.Y)

        input.Changed:Connect(function()

            if input.UserInputState == Enum.UserInputState.End then

                dragging = false

                dragInput = nil

            end

        end)

    end

end)

dragHandle.InputChanged:Connect(function(input)

    if input == dragInput and dragging then

        update(input)

    end

end)

--// TITLE

local title = Instance.new("TextLabel")

title.Size = UDim2.new(1,0,0,30)

title.Position = UDim2.new(0,10,0,0)

title.BackgroundTransparency = 1

title.Text = "Booster Customizer"

title.Font = Enum.Font.GothamBold

title.TextSize = 15

title.TextColor3 = Color3.fromRGB(0,120,255)

title.TextXAlignment = Enum.TextXAlignment.Left

title.Parent = main

--// ACTIVATE BUTTON

local activate = Instance.new("TextButton")

activate.Size = UDim2.new(1,-20,0,30)

activate.Position = UDim2.new(0,10,0,35)

activate.BackgroundColor3 = Color3.fromRGB(25,25,25)

activate.TextColor3 = Color3.fromRGB(255,255,255)

activate.Text = "OFF"

activate.Font = Enum.Font.GothamBold

activate.TextSize = 14

activate.Parent = main

Instance.new("UICorner", activate).CornerRadius = UDim.new(0,8)

local activateStroke = Instance.new("UIStroke", activate)

activateStroke.Color = Color3.fromRGB(0,120,255)

--// CREATE ROW FUNCTION

local function createRow(text,posY,default)

    local label = Instance.new("TextLabel")

    label.Size = UDim2.new(0.55,0,0,25)

    label.Position = UDim2.new(0,10,0,posY)

    label.BackgroundTransparency = 1

    label.Text = text

    label.Font = Enum.Font.GothamBold

    label.TextSize = 13

    label.TextColor3 = Color3.fromRGB(255,255,255)

    label.TextXAlignment = Enum.TextXAlignment.Left

    label.Parent = main

    local box = Instance.new("TextBox")

    box.Size = UDim2.new(0.4,0,0,25)

    box.Position = UDim2.new(0.55,5,0,posY)

    box.BackgroundColor3 = Color3.fromRGB(20,20,20)

    box.TextColor3 = Color3.fromRGB(255,255,255)

    box.Text = tostring(default)

    box.Font = Enum.Font.GothamBold

    box.TextSize = 13

    box.ClearTextOnFocus = false

    box.Parent = main

    Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)

    local s = Instance.new("UIStroke", box)

    s.Color = Color3.fromRGB(0,120,255)

    return box

end

--// ROWS

local speedBox = createRow("Speed",75,53)

local stealBox = createRow("Steal Speed",110,29)

local jumpBox = createRow("Jump",145,60)

--// VALUES

local active = false

local speedConnection

local speedNoStealValue = 52

local speedStealValue = 28

local jumpValue = 50

--// SANITIZE

local function applyInput(box,min,max,default)

    box.FocusLost:Connect(function()

        local text = box.Text:gsub("%D","")

        local num = tonumber(text) or default

        num = math.clamp(num,min,max)

        box.Text = tostring(num)

    end)

end

applyInput(speedBox,15,200,53)

applyInput(stealBox,15,200,29)

applyInput(jumpBox,50,200,60)

--// BUTTON LOGIC

activate.MouseButton1Click:Connect(function()

    active = not active

    if active then

        activate.Text = "ON"

        activate.BackgroundColor3 = Color3.fromRGB(0,120,255)

        speedConnection = RunService.Heartbeat:Connect(function()

            if character and hrp and hum then

                speedNoStealValue = tonumber(speedBox.Text) or 53

                speedStealValue = tonumber(stealBox.Text) or 29

                jumpValue = tonumber(jumpBox.Text) or 60

                local moveDirection = hum.MoveDirection

                if moveDirection.Magnitude > 0 then

                    local isSteal = hum.WalkSpeed < 25

                    local currentSpeed = isSteal and speedStealValue or speedNoStealValue

                    hrp.AssemblyLinearVelocity = Vector3.new(

                        moveDirection.X * currentSpeed,

                        hrp.AssemblyLinearVelocity.Y,

                        moveDirection.Z * currentSpeed

                    )

                end

            end

        end)

    else

        activate.Text = "OFF"

        activate.BackgroundColor3 = Color3.fromRGB(25,25,25)

        if speedConnection then

            speedConnection:Disconnect()

            speedConnection = nil

        end

    end

end)

--// JUMP

UserInputService.JumpRequest:Connect(function()
    if not character or not hum or not hrp then return end

    local state = hum:GetState()

    -- 🔹 JUMP BOOSTER (solo en el suelo)
    if active then
        if state == Enum.HumanoidStateType.Running
        or state == Enum.HumanoidStateType.Landed then

            local jumpPower = tonumber(jumpBox.Text) or 70

            hrp.AssemblyLinearVelocity = Vector3.new(
                hrp.AssemblyLinearVelocity.X,
                jumpPower,
                hrp.AssemblyLinearVelocity.Z
            )
        end
    end

    -- 🔹 INFINITE JUMP (siempre 50 fijo)
    if infiniteJumpEnabled then
        hrp.AssemblyLinearVelocity = Vector3.new(
            hrp.AssemblyLinearVelocity.X,
            50,
            hrp.AssemblyLinearVelocity.Z
        )
    end
end)

--// Kawatan Duels - RADIO CUADRADO ACOTADO SUBIDO (Y = -2.5)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local lp = Players.LocalPlayer
local RunService = game:GetService("RunService")

local RunService = game:GetService("RunService")

local spinForce

local function startSpinBody()
    local char = lp.Character
    if not char then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if spinForce then return end

    spinForce = Instance.new("BodyAngularVelocity")
    spinForce.Name = "SpinForce"
    spinForce.AngularVelocity = Vector3.new(0, 25, 0) -- velocidad estilo 22s
    spinForce.MaxTorque = Vector3.new(0, math.huge, 0)
    spinForce.P = 1250
    spinForce.Parent = root
end

local function stopSpinBody()
    if spinForce then
        spinForce:Destroy()
        spinForce = nil
    end
end

local spinGui
local spinActive = false

local function createSpinButton()
    if spinGui then return end

    spinGui = Instance.new("ScreenGui")
    spinGui.Name = "SpinButtonGui"
    spinGui.Parent = game:GetService("CoreGui")

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0,140,0,50)
    button.Position = UDim2.new(0.5,-70,0.75,0)
    button.Text = "SPIN"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 18
    button.TextColor3 = Color3.new(1,1,1)
    button.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    button.Parent = spinGui

    -- Esquinas curvas
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,16)
    corner.Parent = button

    -- Draggable
    button.Active = true
    button.Draggable = true

    button.MouseButton1Click:Connect(function()
        spinActive = not spinActive

        if spinActive then
            button.Text = "SPINNING"
            button.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            startSpinBody()
        else
            button.Text = "SPIN"
            button.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            stopSpinBody()
        end
    end)
end

local function removeSpinButton()
    stopSpinBody()
    spinActive = false

    if spinGui then
        spinGui:Destroy()
        spinGui = nil
    end
end

task.wait(1)

--////////////////////////////////////////////////////
-- SCREEN GUI
--////////////////////////////////////////////////////
local sg = Instance.new("ScreenGui")
sg.Name = "KawatanDuels"
sg.ResetOnSpawn = false
sg.Parent = lp:WaitForChild("PlayerGui")

-- Barra de progreso Auto Steal
local progressBarBg = Instance.new("Frame")
progressBarBg.Size = UDim2.new(0,240,0,10)
progressBarBg.Position = UDim2.new(0.5,-120,0,52)
progressBarBg.BackgroundColor3 = Color3.fromRGB(15,15,15)
progressBarBg.BackgroundTransparency = 0.25
progressBarBg.Visible = false
progressBarBg.Parent = sg
Instance.new("UICorner", progressBarBg).CornerRadius = UDim.new(0,8)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0,0,1,0)
progressFill.BackgroundColor3 = Color3.fromRGB(0,120,255)
progressFill.Parent = progressBarBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0,8)

local percentLabel = Instance.new("TextLabel")
percentLabel.Size = UDim2.new(1,0,1,0)
percentLabel.BackgroundTransparency = 1
percentLabel.Font = Enum.Font.GothamBold
percentLabel.TextSize = 11
percentLabel.TextColor3 = Color3.fromRGB(220,220,220)
percentLabel.Text = "0%"
percentLabel.Parent = progressBarBg

-- RADIO CUADRADO ACOTADO (subido a Y = -2.5)
local stealSquarePart = nil
local circleConnection = nil

local function hideSquare()
    if stealSquarePart then
        stealSquarePart:Destroy()
        stealSquarePart = nil
    end
end

local grabRadius = 50

local function createOrUpdateSquare(radius)
    if not stealSquarePart then
        stealSquarePart = Instance.new("Part")
        stealSquarePart.Name = "StealCircle"
        stealSquarePart.Anchored = true
        stealSquarePart.CanCollide = false
        stealSquarePart.Transparency = 0.7
        stealSquarePart.Material = Enum.Material.Neon
        stealSquarePart.Color = Color3.fromRGB(0, 120, 255)

        stealSquarePart.Shape = Enum.PartType.Cylinder

        -- IMPORTANTE: el cilindro necesita rotación

        stealSquarePart.Size = Vector3.new(0.05, radius*2, radius*2)

        stealSquarePart.Parent = workspace
    else
        stealSquarePart.Size = Vector3.new(0.05, radius*2, radius*2)
    end
end

local function updateSquarePosition()
    if stealSquarePart and lp.Character then
        local root = lp.Character:FindFirstChild("HumanoidRootPart")
        if root then
            stealSquarePart.CFrame =
                CFrame.new(root.Position + Vector3.new(0, -2.5, 0))
                * CFrame.Angles(0, 0, math.rad(90))
        end
    end
end

--////////////////////////////////////////////////////
-- TOP BAR (FPS + PING)
--////////////////////////////////////////////////////
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(0,240,0,32)
topBar.Position = UDim2.new(0.5,-120,0,15)
topBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
topBar.BackgroundTransparency = 0.15
topBar.Parent = sg
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0,10)

local strokeTop = Instance.new("UIStroke", topBar)
strokeTop.Color = Color3.fromRGB(0,120,255)

local topLabel = Instance.new("TextLabel")
topLabel.Size = UDim2.new(1,0,1,0)
topLabel.BackgroundTransparency = 1
topLabel.Font = Enum.Font.GothamBold
topLabel.TextSize = 14
topLabel.TextColor3 = Color3.fromRGB(0,120,255)
topLabel.Parent = topBar

local fps, framesCount, last = 60, 0, tick()
RunService.RenderStepped:Connect(function()
    framesCount += 1
    if tick() - last >= 1 then
        fps = framesCount
        framesCount = 0
        last = tick()
    end
    local ping = 0
    local network = Stats:FindFirstChild("Network")
    if network and network:FindFirstChild("ServerStatsItem") then
        local dataPing = network.ServerStatsItem:FindFirstChild("Data Ping")
        if dataPing then ping = math.floor(dataPing:GetValue()) end
    end
    topLabel.Text = "Kawatan Duels| "..fps.." FPS | "..ping.." ms"
end)

-- TOGGLE BUTTON (≡)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0,55,0,55)
toggleBtn.Position = UDim2.new(1,-70,0,70)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0,120,255)
toggleBtn.Text = "≡"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 38
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.Parent = sg
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0,14)

-- HUB PANEL
local HUB_WIDTH = 260
local HUB_HEIGHT = 320
local hub = Instance.new("Frame")
hub.Size = UDim2.new(0,HUB_WIDTH,0,HUB_HEIGHT)
hub.Position = UDim2.new(0,-350,0.5,-HUB_HEIGHT/2)
hub.BackgroundColor3 = Color3.fromRGB(0,0,0)
hub.BackgroundTransparency = 0.25
hub.Parent = sg
Instance.new("UICorner", hub).CornerRadius = UDim.new(0,14)

local strokeHub = Instance.new("UIStroke", hub)
strokeHub.Color = Color3.fromRGB(0,120,255)
strokeHub.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.55,0,0,40)
title.Position = UDim2.new(0,12,0,8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(0,120,255)
title.Text = "Kawatan Duels"
title.Parent = hub

local discordLabel = Instance.new("TextButton")
discordLabel.Size = UDim2.new(0.4,0,0,20)
discordLabel.Position = UDim2.new(0.55,6,0,14)
discordLabel.BackgroundTransparency = 1
discordLabel.TextColor3 = Color3.fromRGB(180,180,180)
discordLabel.TextSize = 12
discordLabel.Font = Enum.Font.Gotham
discordLabel.Text = "discord.gg/w24cF33xTn"
discordLabel.Parent = hub
discordLabel.MouseButton1Click:Connect(function()
    setclipboard("discord.gg/w24cF33xTn")
end)

-- SLOW FALL
local slowFallEnabled = false
RunService.Heartbeat:Connect(function()
    if not slowFallEnabled then return end
    local char = lp.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then return end
    if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
        local velocity = root.AssemblyLinearVelocity
        if velocity.Y < -1 then
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, velocity.Y * 0.5, velocity.Z)
        end
    end
end)

-- AUTO STEAL NEAREST + Radio cuadrado ajustable
local autoStealEnabled = false

local function findNearestSteal(root)
    local nearest, dist = nil, math.huge
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("ProximityPrompt") and desc.Enabled and desc.ActionText == "Steal" then
            local part = desc.Parent:IsA("BasePart") and desc.Parent or desc:FindFirstAncestorWhichIsA("BasePart")
            if part then
                local d = (part.Position - root.Position).Magnitude
                if d < dist and d <= grabRadius then
                    nearest = desc
                    dist = d
                end
            end
        end
    end
    return nearest
end

local function resetBar(hide)
    progressFill.Size = UDim2.new(0,0,1,0)
    percentLabel.Text = "0%"
    if hide then
        progressBarBg.Visible = false
    end
end

--// LOCK TARGET GUI SYSTEM

LOCK_RADIUS = 70
local LOCK_SPEED = 50

local lockGui
local lockHbConn
local lockLv, lockAtt, lockGyro
local lockEnabled = false

local function getNearest()
	local char = lp.Character
	if not char then return nil end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local nearest = nil
	local nearestDist = LOCK_RADIUS

	for _,plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp then
			local pc = plr.Character
			local phrp = pc and pc:FindFirstChild("HumanoidRootPart")
			if phrp then
				local d = (phrp.Position - hrp.Position).Magnitude
				if d <= nearestDist then
					nearest = plr
					nearestDist = d
				end
			end
		end
	end

	return nearest
end

local function getBat()
	for _,t in ipairs(lp.Backpack:GetChildren()) do
		if t:IsA("Tool") and string.find(string.lower(t.Name),"bat",1,true) then
			return t
		end
	end

	local char = lp.Character
	if char then
		for _,t in ipairs(char:GetChildren()) do
			if t:IsA("Tool") and string.find(string.lower(t.Name),"bat",1,true) then
				return t
			end
		end
	end

	return nil
end

local function startLock()
	local char = lp.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	lockAtt = Instance.new("Attachment", hrp)

	lockLv = Instance.new("LinearVelocity", hrp)
	lockLv.Attachment0 = lockAtt
	lockLv.MaxForce = 50000
	lockLv.RelativeTo = Enum.ActuatorRelativeTo.World
	lockLv.Enabled = false

	lockGyro = Instance.new("AlignOrientation", hrp)
	lockGyro.Attachment0 = lockAtt
	lockGyro.MaxTorque = 50000
	lockGyro.Responsiveness = 120
	lockGyro.Enabled = false

	lockHbConn = RunService.Heartbeat:Connect(function()
		local targetPlayer = getNearest()
		if not targetPlayer then
			lockLv.Enabled = false
			lockGyro.Enabled = false
			return
		end

		local tChar = targetPlayer.Character
		local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
		if not tHrp then
			lockLv.Enabled = false
			lockGyro.Enabled = false
			return
		end

		lockLv.Enabled = true
		lockGyro.Enabled = true

		local frontPos = tHrp.Position + tHrp.CFrame.LookVector * 2.2
		local dir = frontPos - hrp.Position

		if dir.Magnitude > 0.5 then
			lockLv.VectorVelocity = dir.Unit * LOCK_SPEED
		else
			lockLv.VectorVelocity = Vector3.zero
		end

		lockGyro.CFrame = CFrame.lookAt(hrp.Position, frontPos)

		local bat = getBat()
		if bat then
			if bat.Parent ~= char then
				char.Humanoid:EquipTool(bat)
			end
			bat:Activate()
		end
	end)
end

local function stopLock()
	if lockHbConn then lockHbConn:Disconnect() lockHbConn = nil end
	if lockLv then lockLv:Destroy() lockLv = nil end
	if lockGyro then lockGyro:Destroy() lockGyro = nil end
	if lockAtt then lockAtt:Destroy() lockAtt = nil end
end

function createLockGui()
	if lockGui then return end

	lockGui = Instance.new("ScreenGui")
	lockGui.Name = "KawatanBatTarget"
	lockGui.Parent = lp.PlayerGui

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,140,0,50)
	btn.Position = UDim2.new(0.5,-70,0.75,0)
	btn.Text = "LOCK"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 18
	btn.TextColor3 = Color3.new(1,1,1)
	btn.BackgroundColor3 = Color3.fromRGB(0,120,255)
	btn.Parent = lockGui

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,16)

	btn.Active = true
	btn.Draggable = true

	btn.MouseButton1Click:Connect(function()
		lockEnabled = not lockEnabled

		if lockEnabled then
			btn.Text = "LOCKED"
			btn.BackgroundColor3 = Color3.fromRGB(200,0,0)
			startLock()
		else
			btn.Text = "LOCK"
			btn.BackgroundColor3 = Color3.fromRGB(0,120,255)
			stopLock()
		end
	end)
end

function destroyLockGui()
	lockEnabled = false
	stopLock()
	if lockGui then
		lockGui:Destroy()
		lockGui = nil
	end
end

-- MEDUSA SYSTEM GLOBAL
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local lp = Players.LocalPlayer
local MEDUSA_RADIUS = 10
local SPAM_DELAY = 0.15

local medusaPart
local lastUse = 0
local AutoMedusaEnabled = false
local MedusaInitialized = false

local function InitMedusa()

    if MedusaInitialized then return end
    MedusaInitialized = true

    local function createRadius()
        if medusaPart then medusaPart:Destroy() end

        medusaPart = Instance.new("Part")
        medusaPart.Name = "MedusaRadius"
        medusaPart.Anchored = true
        medusaPart.CanCollide = false
        medusaPart.Transparency = 1
        medusaPart.Material = Enum.Material.Neon
        medusaPart.Color = Color3.fromRGB(255, 0, 0)
        medusaPart.Shape = Enum.PartType.Cylinder
        medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2)
        medusaPart.Parent = workspace
    end

    local function isMedusaEquipped()
        local char = lp.Character
        if not char then return nil end

        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Medusa's Head" then
                return tool
            end
        end
        return nil
    end

    createRadius()

    -- VISUAL
    RunService.RenderStepped:Connect(function()

        if not AutoMedusaEnabled then
            if medusaPart then medusaPart.Transparency = 1 end
            return
        end

        medusaPart.Transparency = 0.75

        local char = lp.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        medusaPart.CFrame =
            CFrame.new(root.Position + Vector3.new(0, -2.5, 0))
            * CFrame.Angles(0, 0, math.rad(90))
    end)

    -- SPAM
    RunService.Heartbeat:Connect(function()

        if not AutoMedusaEnabled then return end

        local char = lp.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local tool = isMedusaEquipped()
        if not tool then return end

        if tick() - lastUse < SPAM_DELAY then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp then
                local pChar = plr.Character
                local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                if pRoot then
                    if (pRoot.Position - root.Position).Magnitude <= MEDUSA_RADIUS then
                        tool:Activate()
                        lastUse = tick()
                        break
                    end
                end
            end
        end
    end)
end

-- ======================
-- AUTO WALK con GUI de rutas (versión corregida)
-- ======================

local ContextActionService = game:GetService("ContextActionService")

local function createAutoWalkGui()
    if walkGui then return end

    -- Limpiar cualquier residuo anterior
    pcall(function()
        if game:GetService("CoreGui"):FindFirstChild("WalkButtonGui") then
            game:GetService("CoreGui").WalkButtonGui:Destroy()
        end
    end)

    walkGui = Instance.new("ScreenGui")
    walkGui.Name = "WalkButtonGui"
    walkGui.ResetOnSpawn = false
    walkGui.Parent = game:GetService("CoreGui")

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0,140,0,50)
    button.Position = UDim2.new(0.5,-70,0.75,0)
    button.Text = "WALK"
    button.Font = Enum.Font.GothamBold
    button.TextSize = 18
    button.TextColor3 = Color3.new(1,1,1)
    button.BackgroundColor3 = Color3.fromRGB(0,120,255)
    button.Active = true
    button.Draggable = true
    button.Parent = walkGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,16)
    corner.Parent = button

    -- Rutas (las mismas que tenías)
    local routes = {
        START_A = {
            StartPoint = Vector3.new(-475.92, -7.02, 99.32),
            Route = {
                Vector3.new(-476.14, -6.90, 25.66),
                Vector3.new(-482.98, -5.27, 24.82)
            }
        },
        START_B = {
            StartPoint = Vector3.new(-476.72, -6.60, 25.47),
            Route = {
                Vector3.new(-476.80, -6.57, 94.64),
                Vector3.new(-482.82, -5.27, 94.81)
            }
        }
    }

    local function getClosestRoute()
        local char = player.Character
        if not char then return nil end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        local closest, shortest = nil, math.huge
        for name, data in pairs(routes) do
            local dist = (root.Position - data.StartPoint).Magnitude
            if dist < shortest then
                shortest = dist
                closest = data
            end
        end
        return closest
    end

    local function blockMovement()
        ContextActionService:BindAction(
            "BlockMoveAutoWalk",
            function() return Enum.ContextActionResult.Sink end,
            false,
            Enum.PlayerActions.CharacterForward,
            Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,
            Enum.PlayerActions.CharacterRight,
            Enum.PlayerActions.CharacterJump
        )
    end

    local function unblockMovement()
        ContextActionService:UnbindAction("BlockMoveAutoWalk")
    end

    local function forceSpeed(humanoid)
        if walkSpeedConnection then
            walkSpeedConnection:Disconnect()
        end
        walkSpeedConnection = RunService.RenderStepped:Connect(function()
            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = 52
            end
        end)
    end

    local function stopForceSpeed(humanoid)
        if walkSpeedConnection then
            walkSpeedConnection:Disconnect()
            walkSpeedConnection = nil
        end
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end

    local function moveToPoint(point)
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChild("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not (humanoid and root) then return end

        while walkRunning do
            local direction = (point - root.Position)
            direction = Vector3.new(direction.X, 0, direction.Z)
            local mag = direction.Magnitude

            if mag < 2 then break end

            humanoid:Move(direction.Unit, false)
            RunService.RenderStepped:Wait()
        end

        if humanoid then
            humanoid:Move(Vector3.zero, false)
        end
    end

    local function startAutoWalk()
        local char = player.Character
        if not char then return end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid then return end

        walkRunning = true
        button.Text = "WALKING"
        button.BackgroundColor3 = Color3.fromRGB(200,0,0)

        blockMovement()
        forceSpeed(humanoid)

        local route = getClosestRoute()
        if not route then
            walkRunning = false
            stopForceSpeed(humanoid)
            unblockMovement()
            button.Text = "WALK"
            button.BackgroundColor3 = Color3.fromRGB(0,120,255)
            return
        end

        task.spawn(function()
            for _, point in ipairs(route.Route) do
                if not walkRunning then break end
                moveToPoint(point)
            end

            walkRunning = false
            stopForceSpeed(humanoid)
            unblockMovement()
            button.Text = "WALK"
            button.BackgroundColor3 = Color3.fromRGB(0,120,255)
        end)
    end

    local function stopAutoWalk()
        walkRunning = false
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        stopForceSpeed(humanoid)
        unblockMovement()
        if button and button.Parent then
            button.Text = "WALK"
            button.BackgroundColor3 = Color3.fromRGB(0,120,255)
        end
    end

    -- Conexión del botón
    button.MouseButton1Click:Connect(function()
        if walkRunning then
            stopAutoWalk()
        else
            startAutoWalk()
        end
    end)

    -- Limpieza automática al respawnear
    local respawnConn = player.CharacterAdded:Connect(function()
        stopAutoWalk()
    end)

    -- Guardamos para limpiar si se destruye el gui
    walkGui.AncestryChanged:Connect(function()
        if not walkGui.Parent then
            if respawnConn then respawnConn:Disconnect() end
        end
    end)
end


local function destroyAutoWalkGui()
    walkRunning = false

    if walkSpeedConnection then
        walkSpeedConnection:Disconnect()
        walkSpeedConnection = nil
    end

    ContextActionService:UnbindAction("BlockMoveAutoWalk")

    if walkGui then
        walkGui:Destroy()
        walkGui = nil
    end
end

-- SECTIONS Y TOGGLES
local sections = {"Combat","Player","Visual","Settings"}
local sectionButtons = {}
local frames = {}

local startX = 12
local spacing = 6
local sectionWidth = (260 - 2*startX - (spacing*(#sections-1))) / #sections
local sectionY = 55

local content = Instance.new("Frame")
content.Size = UDim2.new(1,-20,1,-110)
content.Position = UDim2.new(0,10,0,95)
content.BackgroundTransparency = 1
content.Parent = hub

for _,name in ipairs(sections) do
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.ScrollBarThickness = 4
    scroll.BackgroundTransparency = 1
    scroll.Visible = false
    scroll.Name = name.."Frame"
    scroll.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,8)
    layout.Parent = scroll
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y + 10)
    end)

    frames[name] = scroll
end

local function ShowSection(sectionName)
    for _,frame in pairs(frames) do frame.Visible = false end
    frames[sectionName].Visible = true
    for _,b in pairs(sectionButtons) do b.BackgroundColor3 = Color3.fromRGB(10,10,10) end
    for _,b in pairs(sectionButtons) do
        if b.Text == sectionName then b.BackgroundColor3 = Color3.fromRGB(0,120,255) end
    end
end

for i,v in ipairs(sections) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, sectionWidth,0,28)
    btn.Position = UDim2.new(0,startX + (i-1)*(sectionWidth+spacing),0,sectionY)
    btn.BackgroundColor3 = Color3.fromRGB(10,10,10)
    btn.Text = v
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Parent = hub
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", btn).Color = Color3.fromRGB(0,120,255)
    table.insert(sectionButtons, btn)
    btn.MouseButton1Click:Connect(function() ShowSection(v) end)
end

local function CreateToggle(sectionName,text)
    local parentFrame = frames[sectionName]

    if text == "Radio Steal Nearest" and sectionName == "Settings" then
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1,0,0,45)
        container.BackgroundColor3 = Color3.fromRGB(15,15,15)
        container.BackgroundTransparency = 0.2
        container.Parent = parentFrame
        Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
        Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0.6,0,1,0)
        label.Position = UDim2.new(0,12,0,0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(0,120,255)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = "Radio Steal Nearest"
        label.Parent = container

        local textbox = Instance.new("TextBox")
        textbox.Size = UDim2.new(0,80,0,30)
        textbox.Position = UDim2.new(1,-90,0.5,-15)
        textbox.BackgroundColor3 = Color3.fromRGB(30,30,30)
        textbox.TextColor3 = Color3.new(1,1,1)
        textbox.Font = Enum.Font.Gotham
        textbox.TextSize = 14
        textbox.Text = tostring(grabRadius)
        textbox.ClearTextOnFocus = false
        textbox.Parent = container
        Instance.new("UICorner", textbox).CornerRadius = UDim.new(0,6)
        Instance.new("UIStroke", textbox).Color = Color3.fromRGB(0,120,255)

        textbox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local num = tonumber(textbox.Text)
                if num and num > 0 and num <= 1000 then
                    grabRadius = num
                    if stealSquarePart then
                        stealSquarePart.Size = Vector3.new(0.05,grabRadius*2, grabRadius*2)
                    end
                else
                    textbox.Text = tostring(grabRadius)
                end
            end
        end)

        return
    end

    -- Toggle normal
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,45)
    container.BackgroundColor3 = Color3.fromRGB(15,15,15)
    container.BackgroundTransparency = 0.2
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,1,0)
    label.Position = UDim2.new(0,12,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(0,120,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = container

    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0,50,0,22)
    button.Position = UDim2.new(1,-60,0.5,-11)
    button.BackgroundColor3 = Color3.fromRGB(50,50,50)
    button.Text = ""
    button.Parent = container
    Instance.new("UICorner", button).CornerRadius = UDim.new(1,0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0,18,0,18)
    circle.Position = UDim2.new(0,2,0.5,-9)
    circle.BackgroundColor3 = Color3.fromRGB(220,220,220)
    circle.Parent = button
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1,0)

    local enabled = false

    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(0,120,255)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25), {Position = UDim2.new(1,-20,0.5,-9)}):Play()
        else
            TweenService:Create(button, TweenInfo.new(0.25), {BackgroundColor3 = Color3.fromRGB(50,50,50)}):Play()
            TweenService:Create(circle, TweenInfo.new(0.25), {Position = UDim2.new(0,2,0.5,-9)}):Play()
        end

        if text == "Speed Customizer" then
            local boosterGui = lp.PlayerGui:FindFirstChild("BoosterCustomizer")
            if boosterGui then
                boosterGui.Enabled = enabled
            end
        end

        if text == "Slow Fall" then
            slowFallEnabled = enabled

        elseif text == "Optimizer" then
            if enabled then enableOptimizer() else disableOptimizer() end

elseif text == "Spin Body" then
    if enabled then
        createSpinButton()
    else
        removeSpinButton()
    end

elseif text == "Anti Ragdoll" then
    toggleAntiRagdoll(enabled)

elseif text == "Anti FPS Devourer" then
    if enabled then
        enableAntiFPSDevourer()
    else
        disableAntiFPSDevourer()
    end

elseif text == "Anti Sentry" then
    if enabled then
        startAntiSentry()
    else
        stopAntiSentry()
    end

elseif text == "Infinite Jump" then
    infiniteJumpEnabled = enabled

elseif text == "Anti Bee & Disco" then
	if enabled then
		enableAntiBee()
	else
		disableAntiBee()
	end

elseif text == "Xray Base" then
    toggleESPBases(enabled)

elseif text == "ESP Players" then
    toggleESPPlayers(enabled)


elseif text == "No Walk Animation" then
    local char = lp.Character
    if not char then return end

    local animate = char:FindFirstChild("Animate")

    if enabled then
        if animate then
            savedAnimate = animate
            animate.Disabled = true
        end

        -- detener cualquier animación activa
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            for _,track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                track:Stop()
            end
        end

    else
        if savedAnimate then
            savedAnimate.Disabled = false
            savedAnimate = nil
        end
    end

elseif text == "Auto Bat" then
    autoBatActive = enabled

    if enabled then
        if autoBatLoop then
            autoBatActive = false
            autoBatLoop = nil
        end

        autoBatActive = true

        autoBatLoop = task.spawn(function()
            while autoBatActive do
                local char = lp.Character
                if char then
                    local tool = char:FindFirstChild("Bat")
                    if tool and tool:IsA("Tool") then
                        pcall(function()
                            tool:Activate()
                        end)
                    end
                end
                task.wait(0.4) -- velocidad del golpe
            end
        end)

    else
        autoBatActive = false
    end

elseif text == "Lock Target" then
	if enabled then
		createLockGui()
	else
		destroyLockGui()
	end

elseif text == "Auto Medusa" then
    AutoMedusaEnabled = not AutoMedusaEnabled
    InitMedusa()

elseif text == "Melee Aimbot" then
    meleeEnabled = enabled

    if enabled then
        if character then
            createMeleeAimbot(character)
        end
    else
        disableMeleeAimbot()
    end

elseif text == "Auto Walk" then
    autoWalkEnabled = enabled

    if enabled then
        createAutoWalkGui()
    else
        destroyAutoWalkGui()
    end

        elseif text == "Auto Steal Nearest" then
            autoStealEnabled = enabled
            if enabled then
                createOrUpdateSquare(grabRadius)
                progressBarBg.Visible = true
                local connection = RunService.RenderStepped:Connect(updateSquarePosition)
                task.spawn(function()
                    while autoStealEnabled do
                        local char = lp.Character
                        if char then
                            local root = char:FindFirstChild("HumanoidRootPart")
                            if root then
                                local prompt = findNearestSteal(root)
                                if prompt then
                                    progressBarBg.Visible = true
                                    local start = tick()
                                    while autoStealEnabled and findNearestSteal(root) == prompt do
                                        local p = math.clamp((tick() - start) / 1.2, 0, 1)
                                        progressFill.Size = UDim2.new(p, 0, 1, 0)
                                        percentLabel.Text = math.floor(p*100).."%"
                                        if p >= 0.99 then
                                            pcall(fireproximityprompt, prompt)
                                            task.wait(0.1)
                                            pcall(fireproximityprompt, prompt)
                                            start = tick()
                                        end
                                        task.wait()
                                    end
                                end
                            end
                        end
                        resetBar()
                        task.wait(0.15)
                    end
                    resetBar(true)
                    hideSquare()
                    if connection then connection:Disconnect() end
                end)
            else
                autoStealEnabled = false
                resetBar(true)
                hideSquare()
            end
        end
    end)
end

local combatFuncs = {"Melee Aimbot","Auto Steal Nearest","Auto Walk","Lock Target","Auto Medusa","Auto Bat","Anti Sentry"}
for _,f in ipairs(combatFuncs) do CreateToggle("Combat",f) end

local playerFuncs = {"Speed Customizer","No Walk Animation","Anti Ragdoll","Spin Body","Slow Fall","Infinite Jump"}
for _,f in ipairs(playerFuncs) do CreateToggle("Player",f) end

local visualFuncs = {"ESP Players","Anti Bee & Disco","Xray Base","Optimizer","Anti FPS Devourer"}
for _,f in ipairs(visualFuncs) do CreateToggle("Visual",f) end

-- Radio Steal Nearest en Settings
CreateToggle("Settings", "Radio Steal Nearest")

-- Radio Lock Target
do
    local parentFrame = frames["Settings"]

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,45)
    container.BackgroundColor3 = Color3.fromRGB(15,15,15)
    container.BackgroundTransparency = 0.2
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,1,0)
    label.Position = UDim2.new(0,12,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(0,120,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "Range Lock Target"
    label.Parent = container

    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.new(0,80,0,30)
    textbox.Position = UDim2.new(1,-90,0.5,-15)
    textbox.BackgroundColor3 = Color3.fromRGB(30,30,30)
    textbox.TextColor3 = Color3.new(1,1,1)
    textbox.Font = Enum.Font.Gotham
    textbox.TextSize = 14
    textbox.Text = tostring(LOCK_RADIUS)
    textbox.ClearTextOnFocus = false
    textbox.Parent = container
    Instance.new("UICorner", textbox).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", textbox).Color = Color3.fromRGB(0,120,255)

    textbox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = tonumber(textbox.Text)
            if num and num > 5 and num <= 500 then
                LOCK_RADIUS = num
            else
                textbox.Text = tostring(LOCK_RADIUS)
            end
        end
    end)
end

-- Radio Auto Medusa
do
    local parentFrame = frames["Settings"]

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,45)
    container.BackgroundColor3 = Color3.fromRGB(15,15,15)
    container.BackgroundTransparency = 0.2
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,1,0)
    label.Position = UDim2.new(0,12,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(0,120,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "Radio Auto Medusa"
    label.Parent = container

    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.new(0,80,0,30)
    textbox.Position = UDim2.new(1,-90,0.5,-15)
    textbox.BackgroundColor3 = Color3.fromRGB(30,30,30)
    textbox.TextColor3 = Color3.new(1,1,1)
    textbox.Font = Enum.Font.Gotham
    textbox.TextSize = 14
    textbox.Text = tostring(MEDUSA_RADIUS)
    textbox.ClearTextOnFocus = false
    textbox.Parent = container
    Instance.new("UICorner", textbox).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", textbox).Color = Color3.fromRGB(0,120,255)

    textbox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = tonumber(textbox.Text)
            if num and num > 1 and num <= 200 then
                MEDUSA_RADIUS = num

                if medusaPart then
                    medusaPart.Size = Vector3.new(0.05, MEDUSA_RADIUS*2, MEDUSA_RADIUS*2)
                end
            else
                textbox.Text = tostring(MEDUSA_RADIUS)
            end
        end
    end)
end

-- Melee Aimbot Range
do
    local parentFrame = frames["Settings"]

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,0,45)
    container.BackgroundColor3 = Color3.fromRGB(15,15,15)
    container.BackgroundTransparency = 0.2
    container.Parent = parentFrame
    Instance.new("UICorner", container).CornerRadius = UDim.new(0,10)
    Instance.new("UIStroke", container).Color = Color3.fromRGB(0,120,255)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6,0,1,0)
    label.Position = UDim2.new(0,12,0,0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(0,120,255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "Range Melee Aimbot"
    label.Parent = container

    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.new(0,80,0,30)
    textbox.Position = UDim2.new(1,-90,0.5,-15)
    textbox.BackgroundColor3 = Color3.fromRGB(30,30,30)
    textbox.TextColor3 = Color3.new(1,1,1)
    textbox.Font = Enum.Font.Gotham
    textbox.TextSize = 14
    textbox.Text = tostring(MELEE_RANGE)
    textbox.ClearTextOnFocus = false
    textbox.Parent = container
    Instance.new("UICorner", textbox).CornerRadius = UDim.new(0,6)
    Instance.new("UIStroke", textbox).Color = Color3.fromRGB(0,120,255)

    textbox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local num = tonumber(textbox.Text)
            if num and num > 1 and num <= 50 then
                MELEE_RANGE = num
            else
                textbox.Text = tostring(MELEE_RANGE)
            end
        end
    end)
end

ShowSection("Combat")

-- OPEN / CLOSE HUB
local opened = false
toggleBtn.MouseButton1Click:Connect(function()
    opened = not opened
    if opened then
        TweenService:Create(hub, TweenInfo.new(0.3), {Position = UDim2.new(0,20,0.5,-HUB_HEIGHT/2)}):Play()
    else
        TweenService:Create(hub, TweenInfo.new(0.3), {Position = UDim2.new(0,-350,0.5,-HUB_HEIGHT/2)}):Play()
    end
end)
