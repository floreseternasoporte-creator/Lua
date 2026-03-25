--===========================================================
-- HARRY POTTER DUELING GAME - SERVER SCRIPT v11.0
-- Coloca esto en: ServerScriptService > Script
--===========================================================

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local RunService        = game:GetService("RunService")
local DataStoreService  = game:GetService("DataStoreService")

--===========================================================
-- CONFIG
--===========================================================
local LOBBY_SPAWN = Vector3.new(0, 6, 0)

local PLAYER_HEALTH = 150
local ROUND_TIME    = 90
local TOTAL_ROUNDS  = 3

local SPELL_CAST_SOUND_ID  = "rbxassetid://139822052056984"
local SPELL_DEATH_SOUND_ID = "rbxassetid://120717906835357"
local SPELL_HIT_SOUND_ID   = "rbxassetid://200632875"
local CLASH_SOUND_ID       = "rbxassetid://157878578"

-- Hechizos con daño, velocidad, knockback
local SPELLS = {
	Lumos         = { damage = 20,  speed = 65,  knockback = 22, duration = 0.65, color = Color3.fromRGB(255,240,100), trailColor = Color3.fromRGB(255,255,180) },
	Expelliarmus  = { damage = 35,  speed = 70,  knockback = 45, duration = 0.9,  color = Color3.fromRGB(220,50,50),   trailColor = Color3.fromRGB(255,120,120)  },
	Stupefy       = { damage = 45,  speed = 58,  knockback = 38, duration = 1.2,  color = Color3.fromRGB(220,0,10),    trailColor = Color3.fromRGB(255,80,80)    },
	Serpensortia  = { damage = 55,  speed = 52,  knockback = 55, duration = 1.4,  color = Color3.fromRGB(0,220,60),    trailColor = Color3.fromRGB(100,255,100)  },
	Sectumsempra  = { damage = 70,  speed = 78,  knockback = 60, duration = 1.5,  color = Color3.fromRGB(160,0,0),     trailColor = Color3.fromRGB(220,40,40)    },
	Crucio        = { damage = 80,  speed = 55,  knockback = 30, duration = 2.0,  color = Color3.fromRGB(180,0,220),   trailColor = Color3.fromRGB(220,100,255)  },
	AvadaKedavra  = { damage = 999, speed = 90,  knockback = 80, duration = 0.3,  color = Color3.fromRGB(0,200,20),    trailColor = Color3.fromRGB(80,255,80)    },
}

local HOUSES = {
	{ name = "Gryffindor", primary = "Crimson",       neon = Color3.fromRGB(200,20,20),   badge = "🦁", sigil = Color3.fromRGB(255,215,0) },
	{ name = "Slytherin",  primary = "Bright green",  neon = Color3.fromRGB(0,180,60),    badge = "🐍", sigil = Color3.fromRGB(180,180,180) },
	{ name = "Ravenclaw",  primary = "Bright blue",   neon = Color3.fromRGB(30,80,220),   badge = "🦅", sigil = Color3.fromRGB(150,150,255) },
	{ name = "Hufflepuff", primary = "Bright yellow", neon = Color3.fromRGB(220,190,0),   badge = "🦡", sigil = Color3.fromRGB(30,30,30) },
}

-- Pad positions intentionally near spawn center so they are always visible (mobile + streaming)
local PAD_X = 24
local PAD_Z = 16
local PAD_Y = 3.6
local SIGN_Y = 18
local PAD_DATA = {
	{ pos = Vector3.new(-PAD_X, PAD_Y, -PAD_Z), house = HOUSES[1], signPos = Vector3.new(-PAD_X, SIGN_Y, -44), signLook = Vector3.new(-PAD_X, SIGN_Y, -PAD_Z) },
	{ pos = Vector3.new( PAD_X, PAD_Y, -PAD_Z), house = HOUSES[2], signPos = Vector3.new( PAD_X, SIGN_Y, -44), signLook = Vector3.new( PAD_X, SIGN_Y, -PAD_Z) },
	{ pos = Vector3.new(-PAD_X, PAD_Y,  PAD_Z), house = HOUSES[3], signPos = Vector3.new(-PAD_X, SIGN_Y,  44), signLook = Vector3.new(-PAD_X, SIGN_Y,  PAD_Z) },
	{ pos = Vector3.new( PAD_X, PAD_Y,  PAD_Z), house = HOUSES[4], signPos = Vector3.new( PAD_X, SIGN_Y,  44), signLook = Vector3.new( PAD_X, SIGN_Y,  PAD_Z) },
}

local ARENA_CENTERS = {
	Vector3.new(0, 5, 320),
	Vector3.new(0, 5, 460),
	Vector3.new(0, 5, 600),
	Vector3.new(0, 5, 740),
}

--===========================================================
-- DATASTORES
--===========================================================
local KillsStore   = DataStoreService:GetDataStore("DuelKills_v11")
local KillsOrdered = DataStoreService:GetOrderedDataStore("DuelKillsRank_v11")

--===========================================================
-- REMOTES
--===========================================================
local Remotes = ReplicatedStorage:FindFirstChild("DuelRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "DuelRemotes"
	Remotes.Parent = ReplicatedStorage
end

local function makeRemote(name, isFunction)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new(isFunction and "RemoteFunction" or "RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local RE_BattleStart  = makeRemote("BattleStart")
local RE_BattleEnd    = makeRemote("BattleEnd")
local RE_CastSpell    = makeRemote("CastSpell")
local RE_Countdown    = makeRemote("Countdown")
local RE_RoundUpdate  = makeRemote("RoundUpdate")
local RE_SpellEffect  = makeRemote("SpellEffect")
local RE_WandAnim     = makeRemote("WandAnim")
local RE_ClashUpdate  = makeRemote("ClashUpdate")

--===========================================================
-- STATE
--===========================================================
local squares      = {}
local squareParts  = {}
local squareTriggers = {}
local padStations  = {}
local arenaData    = {}

local playerSquare = {}
local playerDuel   = {}
local pendingCast  = {}
local clashActive  = {}
local playerKills  = {}
local loadingKills = {}

for i = 1, 4 do
	squares[i] = { players = {}, inBattle = false, countdown = false }
end

--===========================================================
-- HELPERS
--===========================================================
local function makePart(name, size, cf, color, material, parent, canCollide, anchored)
	local p = Instance.new("Part")
	p.Name        = name
	p.Size        = size
	p.CFrame      = cf
	p.BrickColor  = BrickColor.new(color)
	p.Material    = material or Enum.Material.SmoothPlastic
	p.Anchored    = (anchored ~= false)
	p.CanCollide  = (canCollide ~= false)
	p.CastShadow  = false
	p.TopSurface    = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless    = true
	p.Parent      = parent
	return p
end

local function addTex(part, face, u, v, texId)
	local t = Instance.new("Texture")
	t.Texture       = texId or "rbxassetid://1536723462"
	t.Face          = face or Enum.NormalId.Top
	t.StudsPerTileU = u or 6
	t.StudsPerTileV = v or 6
	t.Parent        = part
end

local function playSoundAt(pos, soundId, vol)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume  = vol or 1
	s.RollOffMaxDistance = 80
	local p = Instance.new("Part")
	p.Anchored    = true
	p.CanCollide  = false
	p.Transparency = 1
	p.Size        = Vector3.new(1,1,1)
	p.CFrame      = CFrame.new(pos)
	p.Parent      = workspace
	s.Parent      = p
	s:Play()
	Debris:AddItem(p, 4)
end

local function getWandTip(char)
	if not char then return nil end
	local wand = char:FindFirstChild("Varita Magica")
	if not wand then return nil end
	return wand:FindFirstChild("WandTip")
end

local function freezePlayer(player, frozen)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.WalkSpeed  = frozen and 0 or 16
	hum.JumpPower  = frozen and 0 or 50
end

local function teleportTo(player, position, lookAt)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(position, lookAt)
	end
end

local function clearWand(player)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		for _, i in ipairs(bp:GetChildren()) do
			if i.Name == "Varita Magica" then i:Destroy() end
		end
	end
	if player.Character then
		for _, i in ipairs(player.Character:GetChildren()) do
			if i.Name == "Varita Magica" then i:Destroy() end
		end
	end
end

local function returnToLobby(player)
	local char = player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(LOBBY_SPAWN + Vector3.new(math.random(-8,8), 0, math.random(-8,8)))
	end
	clearWand(player)
end

local function registerKill(killer)
	if not killer or not killer:IsA("Player") then return end
	playerKills[killer] = (playerKills[killer] or 0) + 1
	local ls = killer:FindFirstChild("leaderstats")
	local kv = ls and ls:FindFirstChild("Kills")
	if kv then kv.Value = playerKills[killer] end
	task.spawn(function()
		local uid = tostring(killer.UserId)
		pcall(function() KillsStore:SetAsync(uid, playerKills[killer]) end)
		pcall(function() KillsOrdered:SetAsync(uid, playerKills[killer]) end)
	end)
end

local function loadKills(player)
	if loadingKills[player] then return end
	loadingKills[player] = true
	local uid = tostring(player.UserId)
	local kills = 0
	local ok, result = pcall(function() return KillsStore:GetAsync(uid) end)
	if ok and typeof(result) == "number" then kills = result end
	playerKills[player] = kills
	local ls = player:FindFirstChild("leaderstats")
	local kv = ls and ls:FindFirstChild("Kills")
	if kv then kv.Value = kills end
	loadingKills[player] = nil
end

local function saveKills(player)
	if not playerKills[player] then return end
	local uid   = tostring(player.UserId)
	local kills = playerKills[player]
	pcall(function() KillsStore:SetAsync(uid, kills) end)
	pcall(function() KillsOrdered:SetAsync(uid, kills) end)
end

--===========================================================
-- WAND CREATION (more detailed)
--===========================================================
local function createWand(houseName, houseNeon)
	local wand = Instance.new("Tool")
	wand.Name          = "Varita Magica"
	wand.RequiresHandle = true
	wand.CanBeDropped  = false
	wand.GripPos       = Vector3.new(0, -0.55, 0)
	wand.GripForward   = Vector3.new(0, 0, 1)
	wand.GripRight     = Vector3.new(1, 0, 0)
	wand.GripUp        = Vector3.new(0, 1, 0)
	wand:SetAttribute("HouseName", houseName or "Gryffindor")

	local neonCol = houseNeon or Color3.fromRGB(255, 200, 80)

	local handle = Instance.new("Part")
	handle.Name        = "Handle"
	handle.Size        = Vector3.new(0.20, 1.4, 0.20)
	handle.BrickColor  = BrickColor.new("Reddish brown")
	handle.Material    = Enum.Material.WoodPlanks
	handle.CanCollide  = false
	handle.Massless    = true
	handle.CastShadow  = false
	handle.Parent      = wand

	local body = Instance.new("Part")
	body.Name       = "WandBody"
	body.Size       = Vector3.new(0.12, 1.0, 0.12)
	body.BrickColor = BrickColor.new("Dark orange")
	body.Material   = Enum.Material.WoodPlanks
	body.CanCollide = false
	body.Massless   = true
	body.CastShadow = false
	body.Parent     = wand

	local tip = Instance.new("Part")
	tip.Name       = "WandTip"
	tip.Size       = Vector3.new(0.09, 0.30, 0.09)
	tip.Color      = neonCol
	tip.Material   = Enum.Material.Neon
	tip.CanCollide = false
	tip.Massless   = true
	tip.CastShadow = false
	tip.Parent     = wand

	-- Orb at tip
	local orb = Instance.new("Part")
	orb.Name        = "WandOrb"
	orb.Shape       = Enum.PartType.Ball
	orb.Size        = Vector3.new(0.22, 0.22, 0.22)
	orb.Color       = neonCol
	orb.Material    = Enum.Material.Neon
	orb.CanCollide  = false
	orb.Massless    = true
	orb.CastShadow  = false
	orb.Transparency = 0.15
	orb.Parent      = wand

	local function weld(p0, p1)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p0
		w.Part1 = p1
		w.Parent = p0
	end

	weld(handle, body)
	weld(handle, tip)
	weld(handle, orb)

	body.CFrame = handle.CFrame * CFrame.new(0, 1.1, 0)
	tip.CFrame  = handle.CFrame * CFrame.new(0, 1.65, 0)
	orb.CFrame  = handle.CFrame * CFrame.new(0, 1.82, 0)

	local tipAtt = Instance.new("Attachment")
	tipAtt.Name     = "TipAttachment"
	tipAtt.Position = Vector3.new(0, 0.15, 0)
	tipAtt.Parent   = tip

	-- Idle sparkle emitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, neonCol),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 180, 255)),
	}
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(0.5, 0.07),
		NumberSequenceKeypoint.new(1, 0),
	}
	emitter.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}
	emitter.Speed       = NumberRange.new(0.5, 2)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Lifetime    = NumberRange.new(0.2, 0.6)
	emitter.Rate        = 12
	emitter.Parent      = tipAtt

	-- Burst emitter (for casting)
	local burstEmitter = Instance.new("ParticleEmitter")
	burstEmitter.Name         = "BurstEmitter"
	burstEmitter.Color        = ColorSequence.new(neonCol)
	burstEmitter.LightEmission = 1
	burstEmitter.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	}
	burstEmitter.Speed       = NumberRange.new(10, 35)
	burstEmitter.Lifetime    = NumberRange.new(0.15, 0.55)
	burstEmitter.SpreadAngle = Vector2.new(360, 360)
	burstEmitter.Enabled     = false
	burstEmitter.Parent      = tipAtt

	local glow = Instance.new("PointLight")
	glow.Brightness = 4
	glow.Color      = neonCol
	glow.Range      = 10
	glow.Parent     = orb

	return wand
end

--===========================================================
-- WALL KNOCKBACK (slam into wall)
--===========================================================
local function knockIntoWall(character, awayDir, force, duration)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end
	if hum.Health <= 0 then return end

	local dir = (awayDir and awayDir.Magnitude > 0) and awayDir.Unit or hrp.CFrame.LookVector

	hum:ChangeState(Enum.HumanoidStateType.FallingDown)
	hum.PlatformStand = true

	-- Launch them hard
	hrp.AssemblyLinearVelocity = dir * (force or 40) + Vector3.new(0, math.max(14, (force or 40) * 0.18), 0)

	task.delay(duration or 1.0, function()
		if hum.Parent and hum.Health > 0 then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function damageAndKnockback(victimChar, hum, damage, killer, awayDir, spellData)
	if not hum or hum.Health <= 0 then return false end

	hum:TakeDamage(damage)

	if hum.Health <= 0 then
		if victimChar then
			playSoundAt(victimChar:GetPivot().Position, SPELL_DEATH_SOUND_ID, 1)
		end
		registerKill(killer)
		return true
	end

	playSoundAt(victimChar:GetPivot().Position, SPELL_HIT_SOUND_ID, 0.8)
	knockIntoWall(victimChar, awayDir, spellData and spellData.knockback or 35, spellData and spellData.duration or 1.0)
	return false
end

local function giveFighterSetup(player, houseIdx)
	local char  = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = PLAYER_HEALTH
		hum.Health    = PLAYER_HEALTH
	end
	clearWand(player)
	local house = HOUSES[houseIdx] or HOUSES[1]
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		createWand(house.name, house.neon).Parent = bp
	end
end

--===========================================================
-- DECORATION HELPERS
--===========================================================
local function addWallTorch(pos, parent)
	local base = makePart("TorchBase", Vector3.new(0.7, 1.4, 0.7), CFrame.new(pos), "Dark stone grey", Enum.Material.SmoothPlastic, parent, false, true)
	local bowl = makePart("TorchBowl", Vector3.new(1.0, 0.6, 1.0), CFrame.new(pos + Vector3.new(0, 1.0, 0)), "Dark orange", Enum.Material.SmoothPlastic, parent, false, true)
	local fire = Instance.new("Fire")
	fire.Heat           = 10
	fire.Size           = 4
	fire.Color          = Color3.fromRGB(255, 120, 10)
	fire.SecondaryColor = Color3.fromRGB(255, 220, 0)
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Brightness = 7
	light.Range       = 30
	light.Color       = Color3.fromRGB(255, 150, 40)
	light.Parent = bowl
end

local function addGothicPillar(cx, cy, cz, height, parent)
	makePart("PillarShaft", Vector3.new(3.5, height, 3.5), CFrame.new(cx, cy + height/2, cz), "Medium stone grey", Enum.Material.SmoothPlastic, parent, true, true)
	makePart("PillarBase",  Vector3.new(5, 2.2, 5), CFrame.new(cx, cy + 1.1, cz), "Dark stone grey", Enum.Material.SmoothPlastic, parent, true, true)
	makePart("PillarCap",   Vector3.new(5, 2.2, 5), CFrame.new(cx, cy + height - 1.1, cz), "Dark stone grey", Enum.Material.SmoothPlastic, parent, true, true)
end

local function addStainedGlass(pos, size, colors, parent)
	makePart("SGFrame", size + Vector3.new(0.5, 0.5, 0), CFrame.new(pos), "Dark stone grey", Enum.Material.SmoothPlastic, parent, false, true)
	local segH = size.Y / #colors
	for i, c in ipairs(colors) do
		local seg = makePart("SGSeg_"..i, Vector3.new(size.X - 0.35, segH - 0.12, 0.18),
			CFrame.new(pos + Vector3.new(0, (i-1)*segH - size.Y/2 + segH/2, -0.12)),
			"White", Enum.Material.Neon, parent, false, true)
		seg.Color = c
		seg.Transparency = 0.3
		local gl = Instance.new("PointLight")
		gl.Brightness = 1.8
		gl.Range      = 14
		gl.Color      = c
		gl.Parent     = seg
	end
end

local function createFlyingCandle(position, parent)
	local candle = Instance.new("Part")
	candle.Name       = "FlyingCandle"
	candle.Size       = Vector3.new(0.28, 1.2, 0.28)
	candle.BrickColor = BrickColor.new("White")
	candle.Material   = Enum.Material.SmoothPlastic
	candle.Anchored   = true
	candle.CanCollide = false
	candle.CastShadow = false
	candle.CFrame     = CFrame.new(position)
	candle.Parent     = parent

	local flame = Instance.new("Fire")
	flame.Heat           = 3
	flame.Size           = 1.8
	flame.Color          = Color3.fromRGB(255, 200, 80)
	flame.SecondaryColor = Color3.fromRGB(255, 120, 30)
	flame.Parent = candle

	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range       = 18
	light.Color       = Color3.fromRGB(255, 180, 60)
	light.Parent = candle

	local basePos = position
	local offset  = math.random(0, 628) / 100
	local speed   = 0.4 + math.random(0, 40) / 100
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not candle.Parent then
			conn:Disconnect()
			return
		end
		offset += dt * speed
		candle.CFrame = CFrame.new(basePos.X, basePos.Y + math.sin(offset) * 0.6, basePos.Z)
	end)
	return candle
end

--===========================================================
-- HOUSE BANNER (wall hanging)
--===========================================================
local function createHouseBanner(pos, lookAt, house, parent)
	-- Banner back
	local banner = makePart("Banner_"..house.name, Vector3.new(8, 14, 0.3), CFrame.new(pos, lookAt), "Dark stone grey", Enum.Material.SmoothPlastic, parent, false, true)

	-- Colored panel
	local panel = makePart("BannerPanel_"..house.name, Vector3.new(7, 12, 0.4), CFrame.new(pos + Vector3.new(0, 0, -0.2), lookAt + Vector3.new(0,0,-0.2)), house.primary, Enum.Material.SmoothPlastic, parent, false, true)
	panel.Color = house.neon * 0.7

	-- Neon border
	local border = makePart("BannerBorder_"..house.name, Vector3.new(7.4, 12.4, 0.1), CFrame.new(pos + Vector3.new(0, 0, -0.3), lookAt + Vector3.new(0,0,-0.3)), "White", Enum.Material.Neon, parent, false, true)
	border.Color       = house.neon
	border.Transparency = 0.3

	local borderLight = Instance.new("PointLight")
	borderLight.Color      = house.neon
	borderLight.Brightness = 3
	borderLight.Range      = 18
	borderLight.Parent     = border

	-- SurfaceGui on panel
	local gui = Instance.new("SurfaceGui")
	gui.Face        = Enum.NormalId.Front
	gui.AlwaysOnTop = false
	gui.Parent      = panel

	local frame = Instance.new("Frame")
	frame.Size                  = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size                  = UDim2.new(1, 0, 0.25, 0)
	nameLabel.Position              = UDim2.new(0, 0, 0.68, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font                  = Enum.Font.GothamBlack
	nameLabel.TextScaled            = true
	nameLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Text                  = string.upper(house.name)
	nameLabel.Parent = frame

	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size                  = UDim2.new(1, 0, 0.55, 0)
	badgeLabel.Position              = UDim2.new(0, 0, 0.05, 0)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Font                  = Enum.Font.GothamBold
	badgeLabel.TextScaled            = true
	badgeLabel.TextColor3            = Color3.fromRGB(255, 255, 255)
	badgeLabel.Text                  = house.badge
	badgeLabel.Parent = frame
end

--===========================================================
-- SPAWN / LOBBY
--===========================================================
local spawnLoc = workspace:FindFirstChild("LobbySpawn")
if not spawnLoc then
	spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name        = "LobbySpawn"
	spawnLoc.Size        = Vector3.new(6, 1, 6)
	spawnLoc.CFrame      = CFrame.new(0, 3, 0)
	spawnLoc.Transparency = 1
	spawnLoc.CanCollide  = true
	spawnLoc.Anchored    = true
	spawnLoc.Neutral     = true
	spawnLoc.Parent      = workspace
end

local LobbyModel = workspace:FindFirstChild("HogwartsLobby")
if LobbyModel then LobbyModel:Destroy() end
LobbyModel       = Instance.new("Model")
LobbyModel.Name  = "HogwartsLobby"
LobbyModel.Parent = workspace

local LW, LD, LH = 165, 95, 65

local floor = makePart("Floor", Vector3.new(LW, 2, LD), CFrame.new(0, 1, 0), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, true, true)
addTex(floor, Enum.NormalId.Top, 9, 9)

local wallBack  = makePart("WallBack",  Vector3.new(LW, LH, 2.5),   CFrame.new(0,  LH/2+1, -LD/2), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, true, true)
local wallFront = makePart("WallFront", Vector3.new(LW, LH, 2.5),   CFrame.new(0,  LH/2+1,  LD/2), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, true, true)
local wallLeft  = makePart("WallLeft",  Vector3.new(2.5, LH, LD+5), CFrame.new(-LW/2, LH/2+1, 0),  "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, true, true)
local wallRight = makePart("WallRight", Vector3.new(2.5, LH, LD+5), CFrame.new( LW/2, LH/2+1, 0),  "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, true, true)
local ceiling   = makePart("Ceiling",   Vector3.new(LW, 2.5, LD),   CFrame.new(0,  LH+2, 0),       "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, true, true)

for _, w in ipairs({wallBack, wallFront, wallLeft, wallRight, ceiling}) do
	addTex(w, Enum.NormalId.Front, 8, 8)
	addTex(w, Enum.NormalId.Back,  8, 8)
end

-- Vault ribs
for z = -35, 35, 12 do
	makePart("VaultZ_"..z, Vector3.new(LW, 2, 2), CFrame.new(0, LH+1, z), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, false, true)
end
for x = -75, 75, 18 do
	makePart("VaultX_"..x, Vector3.new(2, 2, LD), CFrame.new(x, LH+1, 0), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, false, true)
end

-- Pillars
local pillarZ = {-32, -12, 12, 32}
for _, px in ipairs({-65, 65}) do
	for _, pz in ipairs(pillarZ) do
		addGothicPillar(px, 2, pz, LH - 4, LobbyModel)
	end
end

-- Stained glass on back wall
local glassColors = {
	{Color3.fromRGB(200, 30, 30),  Color3.fromRGB(255, 215, 0),  Color3.fromRGB(200, 30, 30)},
	{Color3.fromRGB(0, 140, 60),   Color3.fromRGB(180, 180, 180), Color3.fromRGB(0, 140, 60)},
	{Color3.fromRGB(30, 60, 200),  Color3.fromRGB(180, 180, 220), Color3.fromRGB(30, 60, 200)},
	{Color3.fromRGB(210, 180, 0),  Color3.fromRGB(30, 30, 30),   Color3.fromRGB(210, 180, 0)},
}
for i, gc in ipairs(glassColors) do
	local xPos = -45 + (i-1) * 30
	addStainedGlass(Vector3.new(xPos, LH-12, -LD/2+1), Vector3.new(10, 16, 0.4), gc, LobbyModel)
end

-- Torches
for _, cp in ipairs({
	Vector3.new(-60, LH-5, -22), Vector3.new(-60, LH-5, 22),
	Vector3.new(0,   LH-5, -22), Vector3.new(0,   LH-5, 0), Vector3.new(0, LH-5, 22),
	Vector3.new( 60, LH-5, -22), Vector3.new( 60, LH-5, 22),
}) do
	addWallTorch(cp, LobbyModel)
end

-- Flying candles
for i = 1, 14 do
	createFlyingCandle(Vector3.new(math.random(-70, 70), LH - math.random(5, 18), math.random(-40, 40)), LobbyModel)
end

-- House banners on the SIDE WALLS (left and right)
createHouseBanner(Vector3.new(-LW/2+1.5, 20, -25), Vector3.new(0, 20, -25), HOUSES[1], LobbyModel) -- Gryffindor left
createHouseBanner(Vector3.new(-LW/2+1.5, 20,  25), Vector3.new(0, 20,  25), HOUSES[3], LobbyModel) -- Ravenclaw left
createHouseBanner(Vector3.new( LW/2-1.5, 20, -25), Vector3.new(0, 20, -25), HOUSES[2], LobbyModel) -- Slytherin right
createHouseBanner(Vector3.new( LW/2-1.5, 20,  25), Vector3.new(0, 20,  25), HOUSES[4], LobbyModel) -- Hufflepuff right

-- Also banners on back wall above pads
for i, pd in ipairs(PAD_DATA) do
	local h = HOUSES[i]
	local bx = pd.pos.X
	createHouseBanner(Vector3.new(bx, 28, -LD/2+1.5), Vector3.new(bx, 28, 0), h, LobbyModel)
end

--===========================================================
-- PAD STATIONS — high-visibility duel pads + status signs
--===========================================================
local function createPadStation(idx, data)
	-- Base tile: clearly visible so players can find where to stand
	local pad = makePart("DuelPad_"..idx, Vector3.new(11, 0.25, 11), CFrame.new(data.pos), "White", Enum.Material.Neon, LobbyModel, false, true)
	pad.Transparency = 0.22 -- visible from far away, still keeps glow style
	pad.Color        = Color3.fromRGB(255, 215, 0)
	pad.CanTouch     = true
	squareParts[idx] = pad

	local padLight = Instance.new("PointLight")
	padLight.Color      = Color3.fromRGB(255, 215, 0)
	padLight.Brightness = 1.6
	padLight.Range      = 18
	padLight.Parent     = pad

	-- Trigger volume (separate from visuals) so joining works reliably on all devices
	local trigger = makePart(
		"DuelPadTrigger_"..idx,
		Vector3.new(12, 6, 12),
		CFrame.new(data.pos + Vector3.new(0, 3, 0)),
		"Really black",
		Enum.Material.SmoothPlastic,
		LobbyModel,
		false,
		true
	)
	trigger.Transparency = 1
	trigger.CanTouch = true
	squareTriggers[idx] = trigger

	-- Floating beacon for easy discovery from far camera angles
	local beacon = makePart("PadBeacon_"..idx, Vector3.new(1.2, 14, 1.2), CFrame.new(data.pos + Vector3.new(0, 7, 0)), "White", Enum.Material.Neon, LobbyModel, false, true)
	beacon.Color = Color3.fromRGB(255, 215, 0)
	beacon.Transparency = 0.3
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(255, 215, 0)
	beaconLight.Brightness = 2.2
	beaconLight.Range = 20
	beaconLight.Parent = beacon

	-- Thin glowing border frame
	for _, side in ipairs({
		{ size = Vector3.new(11, 0.2, 0.4),  offset = Vector3.new(0, 0.1,  5.5) },
		{ size = Vector3.new(11, 0.2, 0.4),  offset = Vector3.new(0, 0.1, -5.5) },
		{ size = Vector3.new(0.4, 0.2, 11),  offset = Vector3.new( 5.5, 0.1, 0) },
		{ size = Vector3.new(0.4, 0.2, 11),  offset = Vector3.new(-5.5, 0.1, 0) },
	}) do
		local edge = makePart("PadEdge_"..idx, side.size, CFrame.new(data.pos + side.offset), "White", Enum.Material.Neon, LobbyModel, false, true)
		edge.Color       = Color3.fromRGB(255, 215, 0)
		edge.Transparency = 0.08
		local edgeLight = Instance.new("PointLight")
		edgeLight.Color      = Color3.fromRGB(255, 215, 0)
		edgeLight.Brightness = 2
		edgeLight.Range      = 12
		edgeLight.Parent     = edge
	end

	-- Corner posts
	for _, cOff in ipairs({
		Vector3.new( 5.5, 0.5,  5.5),
		Vector3.new( 5.5, 0.5, -5.5),
		Vector3.new(-5.5, 0.5,  5.5),
		Vector3.new(-5.5, 0.5, -5.5),
	}) do
		local post = makePart("PadPost_"..idx, Vector3.new(0.5, 1.5, 0.5), CFrame.new(data.pos + cOff), "White", Enum.Material.Neon, LobbyModel, false, true)
		post.Color = Color3.fromRGB(255, 215, 0)
	end

	-- Sign board (positioned right against the wall)
	local sign = makePart("PadSign_"..idx, Vector3.new(10, 7, 0.2), CFrame.new(data.signPos, data.signLook), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, false, true)

	local gui = Instance.new("SurfaceGui")
	gui.Face        = Enum.NormalId.Front
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent      = sign

	local holder = Instance.new("Frame")
	holder.Size                   = UDim2.new(1, 0, 1, 0)
	holder.BackgroundColor3       = Color3.fromRGB(8, 5, 20)
	holder.BackgroundTransparency = 0.08
	holder.BorderSizePixel        = 0
	holder.Parent = gui
	Instance.new("UICorner", holder).CornerRadius = UDim.new(0.06, 0)

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color     = data.house.neon
	uiStroke.Thickness = 2.5
	uiStroke.Parent    = holder

	local badgeLbl = Instance.new("TextLabel")
	badgeLbl.Size                   = UDim2.new(1, 0, 0.30, 0)
	badgeLbl.Position               = UDim2.new(0, 0, 0.04, 0)
	badgeLbl.BackgroundTransparency = 1
	badgeLbl.Font                   = Enum.Font.GothamBold
	badgeLbl.TextScaled             = true
	badgeLbl.TextColor3             = Color3.fromRGB(255, 255, 255)
	badgeLbl.Text                   = data.house.badge
	badgeLbl.Parent = holder

	local title = Instance.new("TextLabel")
	title.Name                    = "Title"
	title.BackgroundTransparency  = 1
	title.Size                    = UDim2.new(1, 0, 0.25, 0)
	title.Position                = UDim2.new(0, 0, 0.36, 0)
	title.Font                    = Enum.Font.GothamBlack
	title.TextScaled              = true
	title.TextColor3              = data.house.neon
	title.TextStrokeColor3        = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency  = 0.3
	title.Text                    = string.upper(data.house.name)
	title.Parent = holder

	local status = Instance.new("TextLabel")
	status.Name                   = "Status"
	status.BackgroundTransparency = 1
	status.Size                   = UDim2.new(1, 0, 0.26, 0)
	status.Position               = UDim2.new(0, 0, 0.68, 0)
	status.Font                   = Enum.Font.GothamMedium
	status.TextScaled             = true
	status.TextColor3             = Color3.fromRGB(220, 220, 220)
	status.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
	status.TextStrokeTransparency = 0.4
	status.Text                   = "0/2 · TOCA PARA UNIRTE"
	status.Parent = holder

	padStations[idx] = {
		part   = pad,
		beacon = beacon,
		sign   = sign,
		title  = title,
		status = status,
		house  = data.house,
	}
end

for i, data in ipairs(PAD_DATA) do
	createPadStation(i, data)
end

local function updatePadStation(idx)
	local sq  = squares[idx]
	local st  = padStations[idx]
	local pad = squareParts[idx]
	local beacon = st and st.beacon
	if not sq or not st or not pad then return end

	local goldColor = Color3.fromRGB(255, 215, 0)
	local redColor  = Color3.fromRGB(255, 50, 50)

	if sq.inBattle then
		pad.Transparency = 0.15
		pad.Color = redColor
		if beacon then
			beacon.Color = redColor
			beacon.Transparency = 0.22
		end
		st.status.Text      = "⚔ EN BATALLA"
		st.status.TextColor3 = redColor
	elseif sq.countdown then
		pad.Transparency = 0.12
		pad.Color = Color3.fromRGB(255, 150, 0)
		if beacon then
			beacon.Color = Color3.fromRGB(255, 160, 0)
			beacon.Transparency = 0.2
		end
		st.status.Text      = "⏳ PREPARANDO..."
		st.status.TextColor3 = Color3.fromRGB(255, 200, 0)
	elseif #sq.players == 0 then
		pad.Transparency = 0.22
		pad.Color = goldColor
		if beacon then
			beacon.Color = goldColor
			beacon.Transparency = 0.3
		end
		st.status.Text      = "0/2 · TOCA PARA UNIRTE"
		st.status.TextColor3 = Color3.fromRGB(200, 200, 200)
	elseif #sq.players == 1 then
		pad.Transparency = 0.10
		pad.Color = Color3.fromRGB(100, 255, 100)
		if beacon then
			beacon.Color = Color3.fromRGB(100, 255, 100)
			beacon.Transparency = 0.18
		end
		st.status.Text      = "1/2 · ESPERANDO..."
		st.status.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		pad.Transparency = 0.08
		pad.Color = Color3.fromRGB(255, 255, 100)
		if beacon then
			beacon.Color = Color3.fromRGB(255, 255, 100)
			beacon.Transparency = 0.12
		end
		st.status.Text      = "2/2 · ¡LISTOS!"
		st.status.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

for i = 1, 4 do updatePadStation(i) end

--===========================================================
-- WALL LEADERBOARD
--===========================================================
local boardPart = makePart("LeaderboardBoard", Vector3.new(26, 16, 0.4), CFrame.new(0, 23, LD/2 - 1.35), "Dark stone grey", Enum.Material.SmoothPlastic, LobbyModel, false, true)
local boardGui  = Instance.new("SurfaceGui")
boardGui.Face        = Enum.NormalId.Front
boardGui.AlwaysOnTop = true
boardGui.LightInfluence = 0
boardGui.Parent = boardPart

local boardRoot = Instance.new("Frame")
boardRoot.Size                   = UDim2.new(1, 0, 1, 0)
boardRoot.BackgroundColor3       = Color3.fromRGB(6, 4, 16)
boardRoot.BackgroundTransparency = 0.04
boardRoot.BorderSizePixel        = 0
boardRoot.Parent = boardGui
Instance.new("UICorner", boardRoot).CornerRadius = UDim.new(0.03, 0)
local bStroke = Instance.new("UIStroke")
bStroke.Color     = Color3.fromRGB(255, 215, 0)
bStroke.Thickness = 2.5
bStroke.Parent    = boardRoot

local boardTitle = Instance.new("TextLabel")
boardTitle.Size                  = UDim2.new(1, 0, 0.14, 0)
boardTitle.Position              = UDim2.new(0, 0, 0.02, 0)
boardTitle.BackgroundTransparency = 1
boardTitle.Font                  = Enum.Font.GothamBlack
boardTitle.TextScaled            = true
boardTitle.TextColor3            = Color3.fromRGB(255, 215, 0)
boardTitle.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
boardTitle.TextStrokeTransparency = 0.3
boardTitle.Text                  = "⚡ MEJORES MAGOS ⚡"
boardTitle.Parent = boardRoot

local rowsFrame = Instance.new("Frame")
rowsFrame.Size                  = UDim2.new(0.96, 0, 0.82, 0)
rowsFrame.Position              = UDim2.new(0.02, 0, 0.16, 0)
rowsFrame.BackgroundTransparency = 1
rowsFrame.Parent = boardRoot

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding             = UDim.new(0, 4)
rowsLayout.FillDirection       = Enum.FillDirection.Vertical
rowsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowsLayout.Parent = rowsFrame

local leaderboardRows = {}
for i = 1, 5 do
	local row = Instance.new("Frame")
	row.Size                  = UDim2.new(1, 0, 0.18, 0)
	row.BackgroundColor3      = Color3.fromRGB(14, 10, 26)
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel       = 0
	row.Parent = rowsFrame
	Instance.new("UICorner", row).CornerRadius = UDim.new(0.08, 0)

	local rank = Instance.new("TextLabel")
	rank.Name                  = "Rank"
	rank.Size                  = UDim2.new(0.12, 0, 1, 0)
	rank.BackgroundTransparency = 1
	rank.Font                  = Enum.Font.GothamBold
	rank.TextScaled            = true
	rank.TextColor3            = Color3.fromRGB(255, 215, 0)
	rank.Text                  = "#"..i
	rank.Parent = row

	local avatar = Instance.new("ImageLabel")
	avatar.Name                 = "Avatar"
	avatar.Size                 = UDim2.new(0.14, 0, 0.78, 0)
	avatar.Position             = UDim2.new(0.13, 0, 0.11, 0)
	avatar.BackgroundTransparency = 1
	avatar.Image                = ""
	avatar.Parent = row
	Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

	local name = Instance.new("TextLabel")
	name.Name                  = "Name"
	name.Size                  = UDim2.new(0.46, 0, 1, 0)
	name.Position              = UDim2.new(0.29, 0, 0, 0)
	name.BackgroundTransparency = 1
	name.Font                  = Enum.Font.GothamBold
	name.TextScaled            = true
	name.TextColor3            = Color3.fromRGB(255, 255, 255)
	name.Text                  = "—"
	name.Parent = row

	local kills = Instance.new("TextLabel")
	kills.Name                 = "Kills"
	kills.Size                 = UDim2.new(0.22, 0, 1, 0)
	kills.Position             = UDim2.new(0.76, 0, 0, 0)
	kills.BackgroundTransparency = 1
	kills.Font                 = Enum.Font.GothamBold
	kills.TextScaled           = true
	kills.TextColor3           = Color3.fromRGB(210, 180, 0)
	kills.Text                 = "0"
	kills.Parent = row

	leaderboardRows[i] = { row = row, rank = rank, avatar = avatar, name = name, kills = kills }
end

local function refreshLeaderboard()
	local ok, pages = pcall(function() return KillsOrdered:GetSortedAsync(false, 5) end)
	if not ok or not pages then
		for i = 1, 5 do
			leaderboardRows[i].name.Text   = "—"
			leaderboardRows[i].kills.Text  = "0"
			leaderboardRows[i].avatar.Image = ""
		end
		return
	end
	local page = pages:GetCurrentPage()
	for i = 1, 5 do
		local row   = leaderboardRows[i]
		local entry = page[i]
		if entry then
			local userId = tonumber(entry.key)
			local score  = tonumber(entry.value) or 0
			row.kills.Text = tostring(score)
			local displayName = "Jugador"
			local thumb       = ""
			if userId then
				local okN, nR = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
				if okN and nR then displayName = nR else displayName = "ID "..tostring(userId) end
				local okT, tR = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
				if okT and tR then thumb = tR end
			end
			row.name.Text   = displayName
			row.avatar.Image = thumb
		else
			row.name.Text   = "—"
			row.kills.Text  = "0"
			row.avatar.Image = ""
		end
	end
end

task.spawn(function()
	while true do refreshLeaderboard() task.wait(10) end
end)

--===========================================================
-- ARENAS
--===========================================================
local function buildArena(idx)
	local center = ARENA_CENTERS[idx]
	local model  = Instance.new("Model")
	model.Name   = "Arena_"..idx
	model.Parent = workspace

	local AW, AD, AH = 36, 88, 35
	local house = HOUSES[idx]

	local function ap(name, size, offset, color, mat, canCollide)
		return makePart(name, size, CFrame.new(center + offset), color, mat, model, canCollide ~= false, true)
	end

	local aFloor = ap("Floor", Vector3.new(AW, 2, AD), Vector3.new(0, -1, 0), "Dark stone grey", Enum.Material.SmoothPlastic, true)
	addTex(aFloor, Enum.NormalId.Top, 5, 5)

	local function wall(name, size, off)
		local w = ap(name, size, off, "Dark stone grey", Enum.Material.SmoothPlastic, true)
		addTex(w, Enum.NormalId.Front, 7, 7)
		addTex(w, Enum.NormalId.Back, 7, 7)
		return w
	end

	wall("WallBack",  Vector3.new(AW+5, AH, 2.5),   Vector3.new(0,  AH/2-1, -AD/2))
	wall("WallFront", Vector3.new(AW+5, AH, 2.5),   Vector3.new(0,  AH/2-1,  AD/2))
	wall("WallLeft",  Vector3.new(2.5,  AH, AD+5),  Vector3.new(-AW/2, AH/2-1, 0))
	wall("WallRight", Vector3.new(2.5,  AH, AD+5),  Vector3.new( AW/2, AH/2-1, 0))
	ap("Ceiling", Vector3.new(AW+5, 2.5, AD+5), Vector3.new(0, AH-1, 0), "Dark stone grey", Enum.Material.SmoothPlastic, true)

	for z = -AD/2+10, AD/2-10, 12 do
		ap("VaultZ_"..z, Vector3.new(AW, 2, 2), Vector3.new(0, AH-2.5, z), "Dark stone grey", Enum.Material.SmoothPlastic, false)
	end

	-- Pillars
	for _, pOff in ipairs({
		Vector3.new(-AW/2+3, 0, -AD/2+3), Vector3.new(-AW/2+3, 0, AD/2-3),
		Vector3.new( AW/2-3, 0, -AD/2+3), Vector3.new( AW/2-3, 0, AD/2-3),
	}) do
		addGothicPillar(center.X + pOff.X, center.Y + pOff.Y, center.Z + pOff.Z, AH-2, model)
	end

	-- Stained glass
	local vColors = {house.neon, Color3.fromRGB(255, 255, 180), house.neon}
	addStainedGlass(center + Vector3.new(-10, AH-12, -AD/2+1), Vector3.new(7, 14, 0.4), vColors, model)
	addStainedGlass(center + Vector3.new(  0, AH-12, -AD/2+1), Vector3.new(7, 14, 0.4), vColors, model)
	addStainedGlass(center + Vector3.new( 10, AH-12, -AD/2+1), Vector3.new(7, 14, 0.4), vColors, model)

	-- House banner on arena wall
	createHouseBanner(
		Vector3.new(center.X, center.Y + 18, center.Z - AD/2 + 1.5),
		Vector3.new(center.X, center.Y + 18, center.Z),
		house, model
	)

	-- Flying candles
	for i = 1, 8 do
		createFlyingCandle(
			Vector3.new(center.X + math.random(-AW/2+4, AW/2-4), center.Y + AH - math.random(5, 14), center.Z + math.random(-AD/2+4, AD/2-4)),
			model
		)
	end

	-- Torches
	for _, tp in ipairs({
		Vector3.new(-AW/2+3, 12, -AD/2+9), Vector3.new(-AW/2+3, 12, AD/2-9),
		Vector3.new( AW/2-3, 12, -AD/2+9), Vector3.new( AW/2-3, 12, AD/2-9),
		Vector3.new(0, 12, -AD/2+9),        Vector3.new(0, 12, AD/2-9),
	}) do
		addWallTorch(center + tp, model)
	end

	arenaData[idx] = {
		spawnA    = center + Vector3.new(-10, 3.5, -22),
		spawnB    = center + Vector3.new( 10, 3.5,  22),
		centerPos = center + Vector3.new(0, 3.5, 0),
	}
end

for i = 1, 4 do buildArena(i) end

--===========================================================
-- CLASH SYSTEM (beam tug-of-war)
--===========================================================
local function destroyClashVisual(v)
	if not v then return end
	for _, obj in ipairs({v.beam, v.spark1, v.spark2, v.light, v.mid, v.trail1, v.trail2}) do
		if obj and obj.Parent then pcall(function() obj:Destroy() end) end
	end
end

local function makeClashBeam(p1, p2, col1, col2)
	local c1, c2 = p1.Character, p2.Character
	if not c1 or not c2 then return nil end
	local tip1 = getWandTip(c1)
	local tip2 = getWandTip(c2)
	if not tip1 or not tip2 then return nil end

	local a0 = tip1:FindFirstChild("TipAttachment") or Instance.new("Attachment")
	a0.Name   = "TipAttachment"
	a0.Position = Vector3.new(0, 0.15, 0)
	a0.Parent = tip1

	local a1 = tip2:FindFirstChild("TipAttachment") or Instance.new("Attachment")
	a1.Name   = "TipAttachment"
	a1.Position = Vector3.new(0, 0.15, 0)
	a1.Parent = tip2

	local beam = Instance.new("Beam")
	beam.Attachment0   = a0
	beam.Attachment1   = a1
	beam.FaceCamera    = true
	beam.Width0        = 0.5
	beam.Width1        = 0.5
	beam.LightEmission = 1
	beam.Color         = ColorSequence.new(col1, col2)
	beam.Transparency  = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	}
	beam.Segments = 20
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.Parent = tip1

	local spark1 = Instance.new("ParticleEmitter")
	spark1.Color        = ColorSequence.new(col1)
	spark1.LightEmission = 1
	spark1.Size         = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	}
	spark1.Speed       = NumberRange.new(8, 22)
	spark1.Lifetime    = NumberRange.new(0.08, 0.25)
	spark1.Rate        = 120
	spark1.SpreadAngle = Vector2.new(360, 360)
	spark1.Parent      = tip1

	local spark2 = spark1:Clone()
	spark2.Color  = ColorSequence.new(col2)
	spark2.Parent = tip2

	local mid = Instance.new("Part")
	mid.Anchored    = true
	mid.CanCollide  = false
	mid.Transparency = 1
	mid.Size        = Vector3.new(1, 1, 1)
	mid.CFrame      = CFrame.new((tip1.Position + tip2.Position) / 2)
	mid.Parent      = workspace

	local light = Instance.new("PointLight")
	light.Color      = Color3.fromRGB(100, 255, 100)
	light.Brightness = 22
	light.Range      = 28
	light.Parent     = mid

	return { beam = beam, spark1 = spark1, spark2 = spark2, mid = mid, light = light }
end

local function spellPower(spellName)
	local s = SPELLS[spellName]
	return s and s.damage or 0
end

local function startClash(p1, spell1, p2, spell2, arenaIdx)
	if clashActive[arenaIdx] then return end
	clashActive[arenaIdx] = true
	pendingCast[p1] = nil
	pendingCast[p2] = nil

	local sp1 = SPELLS[spell1] or SPELLS.Lumos
	local sp2 = SPELLS[spell2] or SPELLS.Lumos

	playSoundAt((p1.Character and p1.Character:GetPivot().Position) or Vector3.new(0,0,0), CLASH_SOUND_ID, 1)

	local v = makeClashBeam(p1, p2, sp1.color, sp2.color)
	freezePlayer(p1, true)
	freezePlayer(p2, true)

	RE_ClashUpdate:FireClient(p1, "Start", spell1, spell2, 0.5)
	RE_ClashUpdate:FireClient(p2, "Start", spell2, spell1, 0.5)

	-- Power contest: higher power pushes ball toward opponent
	local power1   = spellPower(spell1)
	local power2   = spellPower(spell2)
	local total    = power1 + power2
	local progress = 0.5  -- 0 = p1 wins, 1 = p2 wins

	local clashTime = 0
	local maxTime   = 5.0  -- max clash duration

	while clashTime < maxTime do
		task.wait(0.05)
		clashTime += 0.05

		if not p1.Parent or not p2.Parent then break end
		if not playerDuel[p1] or not playerDuel[p2] then break end

		-- Drift toward winner
		local drift = (power2 - power1) / total * 0.012
		drift += (math.random() - 0.5) * 0.008  -- slight randomness
		progress = math.clamp(progress + drift, 0, 1)

		RE_ClashUpdate:FireClient(p1, "Progress", spell1, spell2, 1 - progress)
		RE_ClashUpdate:FireClient(p2, "Progress", spell2, spell1, progress)

		if progress <= 0.02 then
			-- p1 wins
			break
		elseif progress >= 0.98 then
			-- p2 wins
			break
		end

		if v and v.mid then
			local tip1 = getWandTip(p1.Character)
			local tip2 = getWandTip(p2.Character)
			if tip1 and tip2 then
				v.mid.CFrame = CFrame.new(tip1.Position:Lerp(tip2.Position, progress))
				v.light.Color = sp1.color:Lerp(sp2.color, progress)
			end
		end
	end

	local winner, loser, winSpell
	if progress <= 0.5 then
		winner = p1; loser = p2; winSpell = spell1
	else
		winner = p2; loser = p1; winSpell = spell2
	end

	RE_ClashUpdate:FireClient(p1, "End", spell1, spell2, progress)
	RE_ClashUpdate:FireClient(p2, "End", spell2, spell1, 1 - progress)
	destroyClashVisual(v)

	freezePlayer(p1, false)
	freezePlayer(p2, false)
	clashActive[arenaIdx] = false

	task.wait(0.1)

	if playerDuel[winner] and playerDuel[loser] then
		local lchar = loser.Character
		if lchar then
			local hum    = lchar:FindFirstChildOfClass("Humanoid")
			local winChar = winner.Character
			local awayDir = winChar and (lchar:GetPivot().Position - winChar:GetPivot().Position) or Vector3.new(0,0,1)
			if hum then
				local spData = SPELLS[winSpell]
				damageAndKnockback(lchar, hum, spData and spData.damage or 30, winner, awayDir, spData)
			end
		end
	end
end

--===========================================================
-- PROJECTILE LAUNCHER
--===========================================================
local function launchProjectile(caster, duelInfo, spellName)
	local opponent  = duelInfo.opponent
	local casterChar = caster.Character
	local oppChar   = opponent and opponent.Character
	if not casterChar or not oppChar then return end

	local spellData = SPELLS[spellName]
	if not spellData then return end

	local tipPart  = getWandTip(casterChar)
	local startPos = tipPart and tipPart.Position or (casterChar:GetPivot().Position + Vector3.new(0, 1.5, 0))
	local targetPos = oppChar:GetPivot().Position + Vector3.new(0, 1, 0)
	local dir      = (targetPos - startPos)
	if dir.Magnitude <= 0 then return end
	dir = dir.Unit

	-- Trigger wand animation on client
	RE_WandAnim:FireClient(caster, spellName)

	-- Burst particles at tip
	if tipPart then
		local burstEm = tipPart:FindFirstChild("TipAttachment") and
			tipPart:FindFirstChild("TipAttachment"):FindFirstChildOfClass("ParticleEmitter")
		-- Server can't directly emit, client handles visuals
	end

	-- Projectile
	local proj = Instance.new("Part")
	proj.Name        = "SpellProj_"..spellName
	proj.Size        = Vector3.new(0.4, 0.4, 0.4)
	proj.Color       = spellData.color
	proj.Material    = Enum.Material.Neon
	proj.CanCollide  = false
	proj.CanTouch    = true
	proj.Anchored    = false
	proj.CastShadow  = false
	proj.Shape       = Enum.PartType.Ball
	proj.CFrame      = CFrame.new(startPos)
	proj.Parent      = workspace

	local pl = Instance.new("PointLight")
	pl.Brightness = 9
	pl.Range      = 20
	pl.Color      = spellData.color
	pl.Parent     = proj

	-- Trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.1, 0)
	a0.Parent   = proj
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.1, 0)
	a1.Parent   = proj

	local trail = Instance.new("Trail")
	trail.Attachment0  = a0
	trail.Attachment1  = a1
	trail.Lifetime     = 0.3
	trail.Color        = ColorSequence.new{
		ColorSequenceKeypoint.new(0, spellData.color),
		ColorSequenceKeypoint.new(1, spellData.trailColor),
	}
	trail.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	}
	trail.WidthScale   = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	}
	trail.LightEmission = 1
	trail.Parent = proj

	-- Particles
	local pe = Instance.new("ParticleEmitter")
	pe.Color        = ColorSequence.new(spellData.color, spellData.trailColor)
	pe.LightEmission = 1
	pe.Size         = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	}
	pe.Speed       = NumberRange.new(2, 6)
	pe.Lifetime    = NumberRange.new(0.1, 0.3)
	pe.Rate        = 40
	pe.SpreadAngle = Vector2.new(20, 20)
	pe.Parent      = proj

	local bv = Instance.new("BodyVelocity")
	bv.Velocity  = dir * (spellData.speed or 65)
	bv.MaxForce  = Vector3.new(1e9, 1e9, 1e9)
	bv.Parent    = proj

	playSoundAt(startPos, SPELL_CAST_SOUND_ID, 0.8)

	local hitDone = false
	proj.Touched:Connect(function(hit)
		if hitDone then return end
		if not hit or not hit.Parent then return end
		if hit.Parent == casterChar then return end
		local hp = Players:GetPlayerFromCharacter(hit.Parent)
		if hp ~= opponent then return end
		hitDone = true

		local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
		damageAndKnockback(hit.Parent, hum, spellData.damage, caster, dir, spellData)

		RE_SpellEffect:FireClient(caster, spellName.."_hit", false)
		RE_SpellEffect:FireClient(opponent, spellName.."_hit", true)

		proj:Destroy()
	end)

	Debris:AddItem(proj, 8)
end

--===========================================================
-- CAST HANDLER
--===========================================================
local WINDUP      = 0.15
local CLASH_WINDOW = 0.28

RE_CastSpell.OnServerEvent:Connect(function(caster, spellName)
	local duelInfo = playerDuel[caster]
	if not duelInfo then return end
	if not SPELLS[spellName] then return end

	local arenaIdx = duelInfo.arenaIdx
	local opponent = duelInfo.opponent
	if not opponent or not playerDuel[opponent] then return end

	local now = os.clock()
	local oppPending = pendingCast[opponent]

	if oppPending and (now - oppPending.time) <= CLASH_WINDOW and not clashActive[arenaIdx] then
		pendingCast[caster] = nil
		task.spawn(startClash, opponent, oppPending.spell, caster, spellName, arenaIdx)
		return
	end

	local token = {}
	pendingCast[caster] = { spell = spellName, time = now, token = token }

	task.delay(WINDUP, function()
		local pc = pendingCast[caster]
		if not pc or pc.token ~= token then return end
		if not playerDuel[caster] or not playerDuel[opponent] then
			pendingCast[caster] = nil
			return
		end
		if clashActive[arenaIdx] then
			pendingCast[caster] = nil
			return
		end
		pendingCast[caster] = nil
		launchProjectile(caster, duelInfo, spellName)
	end)
end)

--===========================================================
-- ROUNDS
--===========================================================
local function removeFromSquare(player)
	local idx = playerSquare[player]
	if not idx then return end
	local sq = squares[idx]
	for k, p in ipairs(sq.players) do
		if p == player then
			table.remove(sq.players, k)
			break
		end
	end
	playerSquare[player] = nil
	updatePadStation(idx)
end

local function endBattle(squareIdx)
	local sq = squares[squareIdx]
	if sq then
		sq.inBattle  = false
		sq.countdown = false
		updatePadStation(squareIdx)
	end
end

local function startRound(p1, p2, roundNum, arenaIdx, wins)
	RE_RoundUpdate:FireClient(p1, roundNum, ROUND_TIME, wins[1], wins[2])
	RE_RoundUpdate:FireClient(p2, roundNum, ROUND_TIME, wins[2], wins[1])

	local arena = arenaData[arenaIdx]
	giveFighterSetup(p1, arenaIdx)
	giveFighterSetup(p2, arenaIdx)
	task.wait(0.25)

	teleportTo(p1, arena.spawnA, arena.spawnB)
	teleportTo(p2, arena.spawnB, arena.spawnA)
	task.wait(0.2)

	freezePlayer(p1, false)
	freezePlayer(p2, false)

	local roundFinished = false
	local roundWinner   = nil

	local function onDeath(dead, survivor)
		if roundFinished then return end
		roundFinished = true
		roundWinner   = survivor
	end

	local function watchDeath(player, opp)
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end
		hum.Died:Connect(function()
			if playerDuel[player] then onDeath(player, opp) end
		end)
	end

	watchDeath(p1, p2)
	watchDeath(p2, p1)

	local timeLeft = ROUND_TIME
	local timerConn
	timerConn = RunService.Heartbeat:Connect(function(dt)
		if roundFinished then
			if timerConn then timerConn:Disconnect() end
			return
		end
		timeLeft -= dt
		local tInt = math.ceil(timeLeft)
		RE_RoundUpdate:FireClient(p1, roundNum, tInt, wins[1], wins[2])
		RE_RoundUpdate:FireClient(p2, roundNum, tInt, wins[2], wins[1])
		if timeLeft <= 0 then
			roundFinished = true
			roundWinner   = nil
			if timerConn then timerConn:Disconnect() end
		end
	end)

	while not roundFinished do task.wait(0.1) end
	if timerConn then timerConn:Disconnect() end
	return roundWinner
end

local function startDuel(squareIdx)
	local sq = squares[squareIdx]
	if sq.inBattle or sq.countdown then return end
	if #sq.players < 2 then return end

	sq.countdown = true
	updatePadStation(squareIdx)

	local p1 = sq.players[1]
	local p2 = sq.players[2]

	freezePlayer(p1, true)
	freezePlayer(p2, true)

	for t = 5, 1, -1 do
		if not playerSquare[p1] or not playerSquare[p2] then
			freezePlayer(p1, false)
			freezePlayer(p2, false)
			sq.countdown = false
			updatePadStation(squareIdx)
			return
		end
		RE_Countdown:FireClient(p1, t)
		RE_Countdown:FireClient(p2, t)
		task.wait(1)
	end

	sq.countdown = false
	sq.inBattle  = true
	playerSquare[p1] = nil
	playerSquare[p2] = nil
	sq.players = {}
	updatePadStation(squareIdx)

	local arena = arenaData[squareIdx]
	if not arena then endBattle(squareIdx); return end

	playerDuel[p1] = { opponent = p2, arenaIdx = squareIdx }
	playerDuel[p2] = { opponent = p1, arenaIdx = squareIdx }

	RE_BattleStart:FireClient(p1, p2.Name)
	RE_BattleStart:FireClient(p2, p1.Name)

	task.wait(1.8)

	teleportTo(p1, arena.spawnA, arena.spawnB)
	teleportTo(p2, arena.spawnB, arena.spawnA)
	freezePlayer(p1, false)
	freezePlayer(p2, false)

	local wins = {0, 0}
	local overallWinner, overallLoser

	for round = 1, TOTAL_ROUNDS do
		if not playerDuel[p1] or not playerDuel[p2] then break end

		local rWinner = startRound(p1, p2, round, squareIdx, wins)

		if rWinner == p1 then
			wins[1] += 1
		elseif rWinner == p2 then
			wins[2] += 1
		end

		RE_RoundUpdate:FireClient(p1, round, 0, wins[1], wins[2])
		RE_RoundUpdate:FireClient(p2, round, 0, wins[2], wins[1])

		if wins[1] >= 2 then overallWinner = p1; overallLoser = p2; break end
		if wins[2] >= 2 then overallWinner = p2; overallLoser = p1; break end

		if round < TOTAL_ROUNDS then
			freezePlayer(p1, true)
			freezePlayer(p2, true)
			task.wait(2)
		end
	end

	if not overallWinner then
		if wins[1] > wins[2] then
			overallWinner = p1; overallLoser = p2
		elseif wins[2] > wins[1] then
			overallWinner = p2; overallLoser = p1
		end
	end

	if overallWinner then
		RE_BattleEnd:FireClient(overallWinner, overallWinner.Name, true)
		if overallLoser then RE_BattleEnd:FireClient(overallLoser, overallWinner.Name, false) end
	else
		RE_BattleEnd:FireClient(p1, "EMPATE", false)
		RE_BattleEnd:FireClient(p2, "EMPATE", false)
	end

	playerDuel[p1]   = nil
	playerDuel[p2]   = nil
	pendingCast[p1]  = nil
	pendingCast[p2]  = nil

	task.delay(4, function()
		if overallWinner and overallWinner.Character then returnToLobby(overallWinner) end
		if overallLoser then
			if not overallLoser.Character then overallLoser:LoadCharacter(); task.wait(0.8) end
			returnToLobby(overallLoser)
		end
		endBattle(squareIdx)
	end)
end

--===========================================================
-- TOUCH PADS
--===========================================================
for i, sqPart in ipairs(squareParts) do
	local touchPart = squareTriggers[i] or sqPart
	touchPart.Touched:Connect(function(hit)
		local char   = hit and hit.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then return end
		if playerSquare[player] or playerDuel[player] then return end

		local sq = squares[i]
		if sq.inBattle or sq.countdown or #sq.players >= 2 then return end
		for _, p in ipairs(sq.players) do
			if p == player then return end
		end

		playerSquare[player] = i
		table.insert(sq.players, player)
		updatePadStation(i)

		if #sq.players == 2 then
			task.spawn(startDuel, i)
		end
	end)
end

local SQUARE_RADIUS = 7.5
RunService.Heartbeat:Connect(function()
	for i, pd in ipairs(PAD_DATA) do
		local sq = squares[i]
		if not sq.inBattle and not sq.countdown then
			for k = #sq.players, 1, -1 do
				local pl  = sq.players[k]
				local char = pl and pl.Character
				local hrp  = char and char:FindFirstChild("HumanoidRootPart")
				if not hrp then
					table.remove(sq.players, k)
					playerSquare[pl] = nil
					updatePadStation(i)
				else
					local dist = (Vector3.new(hrp.Position.X, pd.pos.Y, hrp.Position.Z) - pd.pos).Magnitude
					if dist > SQUARE_RADIUS then
						table.remove(sq.players, k)
						playerSquare[pl] = nil
						updatePadStation(i)
					end
				end
			end
		end
	end
end)

--===========================================================
-- PLAYER EVENTS
--===========================================================
Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name   = "leaderstats"
	ls.Parent = player

	local kills = Instance.new("IntValue")
	kills.Name   = "Kills"
	kills.Value  = 0
	kills.Parent = ls

	loadKills(player)

	player.CharacterAdded:Connect(function(char)
		removeFromSquare(player)
		playerDuel[player]  = nil
		pendingCast[player] = nil

		local hrp = char:WaitForChild("HumanoidRootPart")
		task.wait(0.15)
		hrp.CFrame = CFrame.new(LOBBY_SPAWN + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8)))
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromSquare(player)
	saveKills(player)

	if playerDuel[player] then
		local info     = playerDuel[player]
		local opponent = info.opponent
		playerDuel[player] = nil

		if opponent and playerDuel[opponent] then
			playerDuel[opponent] = nil
			RE_BattleEnd:FireClient(opponent, opponent.Name, true)
			task.spawn(function()
				task.wait(2)
				local c = opponent.Character
				if c and c:FindFirstChild("HumanoidRootPart") then
					c.HumanoidRootPart.CFrame = CFrame.new(LOBBY_SPAWN)
				end
				local sq = squares[info.arenaIdx]
				if sq then
					sq.inBattle  = false
					sq.countdown = false
					updatePadStation(info.arenaIdx)
				end
			end)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(60)
		for _, plr in ipairs(Players:GetPlayers()) do
			saveKills(plr)
		end
	end
end)

print("✨ [DuelGame v11.0] Server Script cargado — Casas, hechizos épicos, animaciones, clash dinámico")
