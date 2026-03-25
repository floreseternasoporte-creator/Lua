--===========================================================
-- HARRY POTTER DUELING GAME - LOCAL SCRIPT v11.0
-- Coloca en: StarterPlayerScripts > LocalScript
--===========================================================

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local Backpack    = LocalPlayer:WaitForChild("Backpack")
local Camera      = workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("DuelRemotes", 30)
if not Remotes then error("No DuelRemotes") end

local RE_BattleStart  = Remotes:WaitForChild("BattleStart")
local RE_BattleEnd    = Remotes:WaitForChild("BattleEnd")
local RE_CastSpell    = Remotes:WaitForChild("CastSpell")
local RE_Countdown    = Remotes:WaitForChild("Countdown")
local RE_RoundUpdate  = Remotes:WaitForChild("RoundUpdate")
local RE_SpellEffect  = Remotes:WaitForChild("SpellEffect")
local RE_WandAnim     = Remotes:WaitForChild("WandAnim")
local RE_ClashUpdate  = Remotes:WaitForChild("ClashUpdate")

local isInDuel   = false
local spellOnCD  = {}
local WAND_NAME  = "Varita Magica"

--===========================================================
-- SPELLS DEFINITION (7 spells from the series)
--===========================================================
local SPELLS = {
	{
		name      = "Lumos",
		label     = "LUMOS",
		key       = "Q",
		cd        = 2.5,
		desc      = "Orbe de luz dorada. Daño ligero.",
		icon      = "✨",
		mainColor  = Color3.fromRGB(255, 240, 100),
		glowColor  = Color3.fromRGB(255, 220, 50),
		btnBg     = Color3.fromRGB(40, 35, 5),
		textColor = Color3.fromRGB(255, 240, 80),
	},
	{
		name      = "Expelliarmus",
		label     = "EXPELLIARMUS",
		key       = "E",
		cd        = 3.5,
		desc      = "El hechizo de desarme de Harry. Lanzamiento potente.",
		icon      = "🌀",
		mainColor  = Color3.fromRGB(220, 50, 50),
		glowColor  = Color3.fromRGB(255, 100, 100),
		btnBg     = Color3.fromRGB(45, 5, 5),
		textColor = Color3.fromRGB(255, 120, 100),
	},
	{
		name      = "Stupefy",
		label     = "STUPEFY",
		key       = "R",
		cd        = 4.0,
		desc      = "Aturdidor rojo. Daño considerable.",
		icon      = "⚡",
		mainColor  = Color3.fromRGB(220, 0, 10),
		glowColor  = Color3.fromRGB(255, 60, 60),
		btnBg     = Color3.fromRGB(50, 0, 0),
		textColor = Color3.fromRGB(255, 80, 80),
	},
	{
		name      = "Serpensortia",
		label     = "SERPENSORTIA",
		key       = "T",
		cd        = 5.0,
		desc      = "Invoca una serpiente de energía. Gran daño.",
		icon      = "🐍",
		mainColor  = Color3.fromRGB(0, 220, 60),
		glowColor  = Color3.fromRGB(80, 255, 80),
		btnBg     = Color3.fromRGB(0, 30, 10),
		textColor = Color3.fromRGB(80, 255, 100),
	},
	{
		name      = "Sectumsempra",
		label     = "SECTUMSEMPRA",
		key       = "Y",
		cd        = 7.0,
		desc      = "Maldición oscura de Snape. Daño severo.",
		icon      = "🩸",
		mainColor  = Color3.fromRGB(160, 0, 0),
		glowColor  = Color3.fromRGB(220, 30, 30),
		btnBg     = Color3.fromRGB(35, 0, 0),
		textColor = Color3.fromRGB(200, 40, 40),
	},
	{
		name      = "Crucio",
		label     = "CRUCIO",
		key       = "U",
		cd        = 10.0,
		desc      = "Maldición imperdonable. Daño masivo + knockback.",
		icon      = "💀",
		mainColor  = Color3.fromRGB(180, 0, 220),
		glowColor  = Color3.fromRGB(220, 80, 255),
		btnBg     = Color3.fromRGB(30, 0, 40),
		textColor = Color3.fromRGB(200, 80, 255),
	},
	{
		name      = "AvadaKedavra",
		label     = "AVADA KEDAVRA",
		key       = "I",
		cd        = 25.0,
		desc      = "La maldición asesina. Derrota instantánea.",
		icon      = "☠",
		mainColor  = Color3.fromRGB(0, 200, 20),
		glowColor  = Color3.fromRGB(0, 255, 40),
		btnBg     = Color3.fromRGB(0, 20, 5),
		textColor = Color3.fromRGB(60, 255, 40),
	},
}

-- Build lookup
local spellMap = {}
for _, sp in ipairs(SPELLS) do
	spellMap[sp.name] = sp
end

--===========================================================
-- GUI SETUP
--===========================================================
local oldGui = PlayerGui:FindFirstChild("DuelUI")
if oldGui then oldGui:Destroy() end

local sg        = Instance.new("ScreenGui")
sg.Name         = "DuelUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent       = PlayerGui

local function tw(obj, props, t, sty, dir)
	return TweenService:Create(obj, TweenInfo.new(t or 0.3, sty or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
end

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or 0.12, 0)
	c.Parent = p
	return c
end

local function stroke(p, col, th, transp)
	local s       = Instance.new("UIStroke")
	s.Color       = col
	s.Thickness   = th or 2
	s.Transparency = transp or 0
	s.Parent      = p
	return s
end

local function makeFrame(parent, size, pos, bg, alpha, zi)
	local f = Instance.new("Frame")
	f.Size                 = size
	f.Position             = pos
	f.BackgroundColor3     = bg or Color3.fromRGB(0, 0, 0)
	f.BackgroundTransparency = alpha or 0
	f.BorderSizePixel      = 0
	f.ZIndex               = zi or 10
	f.Parent               = parent
	return f
end

local function makeLabel(parent, text, size, pos, col, font, zi, scaled)
	local l = Instance.new("TextLabel")
	l.Size                 = size
	l.Position             = pos
	l.BackgroundTransparency = 1
	l.Text                 = text
	l.TextColor3           = col or Color3.fromRGB(255, 255, 255)
	l.Font                 = font or Enum.Font.GothamBold
	l.TextScaled           = (scaled ~= false)
	l.BorderSizePixel      = 0
	l.ZIndex               = zi or 10
	l.Parent               = parent
	return l
end

--===========================================================
-- BLACK SCREEN
--===========================================================
local blackScreen = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 1, 50)

local function fadeBlack(target, t)
	local tween = tw(blackScreen, {BackgroundTransparency = target}, t or 0.5, Enum.EasingStyle.Linear)
	tween:Play()
	tween.Completed:Wait()
end

--===========================================================
-- ANNOUNCEMENT SCREEN
--===========================================================
local announceBg = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 0, 55)
announceBg.Visible = false

local annCon = makeFrame(announceBg, UDim2.new(0.6, 0, 0.5, 0), UDim2.new(0.2, 0, 0.25, 0), Color3.fromRGB(0, 0, 0), 1, 56)

local ann1 = makeLabel(annCon, "⚔ DUELO DE MAGIA ⚔", UDim2.new(1, 0, 0.28, 0), UDim2.new(0, 0, 0.04, 0),
	Color3.fromRGB(255, 215, 0), Enum.Font.GothamBlack, 57)
ann1.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
ann1.TextStrokeTransparency = 0
ann1.TextTransparency       = 1

local ann2 = makeLabel(annCon, "COMENZARÁ PRONTO", UDim2.new(1, 0, 0.18, 0), UDim2.new(0, 0, 0.34, 0),
	Color3.fromRGB(200, 200, 255), Enum.Font.GothamBold, 57)
ann2.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
ann2.TextStrokeTransparency = 0
ann2.TextTransparency = 1

local annDivider = makeFrame(annCon, UDim2.new(0.75, 0, 0.02, 0), UDim2.new(0.125, 0, 0.56, 0), Color3.fromRGB(255, 215, 0), 0.35, 57)
annDivider.Visible = false

local annVS = makeLabel(annCon, "", UDim2.new(1, 0, 0.25, 0), UDim2.new(0, 0, 0.65, 0),
	Color3.fromRGB(180, 180, 220), Enum.Font.GothamBold, 57)
annVS.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
annVS.TextStrokeTransparency = 0
annVS.TextTransparency = 1

--===========================================================
-- COUNTDOWN
--===========================================================
local cdWrap = makeFrame(sg, UDim2.new(0, 160, 0, 90), UDim2.new(0.5, -80, 0.04, 0), Color3.fromRGB(4, 1, 14), 0.25, 20)
cdWrap.Visible = false
corner(cdWrap, 0.18)
stroke(cdWrap, Color3.fromRGB(255, 215, 0), 2)

local cdTitle  = makeLabel(cdWrap, "DUELO", UDim2.new(1, 0, 0.38, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 215, 0), Enum.Font.GothamBold, 21)
local cdNum    = makeLabel(cdWrap, "5", UDim2.new(1, 0, 0.58, 0), UDim2.new(0, 0, 0.4, 0), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 21)

local function showCountdown(n)
	cdWrap.Visible = true
	cdNum.Text     = tostring(n)
	cdNum.TextTransparency = 0.8
	tw(cdNum, {TextTransparency = 0}, 0.22, Enum.EasingStyle.Back):Play()

	if n == 1 then
		task.delay(1.2, function()
			cdNum.Text       = "¡DUEL!"
			cdNum.TextColor3 = Color3.fromRGB(255, 80, 80)
			task.wait(0.85)
			tw(cdWrap, {BackgroundTransparency = 1}, 0.35):Play()
			tw(cdNum,  {TextTransparency = 1}, 0.35):Play()
			task.wait(0.4)
			cdWrap.Visible              = false
			cdWrap.BackgroundTransparency = 0.25
			cdNum.TextTransparency       = 0
			cdNum.TextColor3             = Color3.fromRGB(255, 255, 255)
		end)
	end
end

--===========================================================
-- HUD (top-center)
--===========================================================
local hudWrap = makeFrame(sg, UDim2.new(0, 500, 0, 90), UDim2.new(0.5, -250, 0, 6), Color3.fromRGB(3, 1, 12), 0.2, 15)
hudWrap.Visible = false
corner(hudWrap, 0.14)
stroke(hudWrap, Color3.fromRGB(255, 215, 0), 1.5)

local oppLabel = makeLabel(hudWrap, "VS ????", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 4), Color3.fromRGB(255, 215, 0), Enum.Font.GothamBold, 16)
makeFrame(hudWrap, UDim2.new(0.85, 0, 0, 1), UDim2.new(0.075, 0, 0, 28), Color3.fromRGB(255, 215, 0), 0.6, 16)

local hudBottom = makeFrame(hudWrap, UDim2.new(1, 0, 0, 55), UDim2.new(0, 0, 0, 33), Color3.fromRGB(0, 0, 0), 1, 16)

local timerBox = makeFrame(hudBottom, UDim2.new(0, 70, 0, 38), UDim2.new(1, -78, 0.5, -19), Color3.fromRGB(8, 4, 25), 0.3, 17)
corner(timerBox, 0.2)
stroke(timerBox, Color3.fromRGB(160, 120, 255), 1.5)
local timerLabel = makeLabel(timerBox, "1:30", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 18)

local roundRow = makeFrame(hudBottom, UDim2.new(0, 210, 0, 38), UDim2.new(0.5, -105, 0.5, -19), Color3.fromRGB(0, 0, 0), 1, 17)
local roundLayout = Instance.new("UIListLayout")
roundLayout.FillDirection       = Enum.FillDirection.Horizontal
roundLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
roundLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
roundLayout.Padding             = UDim.new(0, 8)
roundLayout.Parent              = roundRow

local roundDots = {}
for i = 1, 3 do
	local cap = makeFrame(roundRow, UDim2.new(0, 58, 0, 32), UDim2.new(0, 0, 0, 0), Color3.fromRGB(35, 35, 45), 0, 17)
	corner(cap, 0.4)
	local str = stroke(cap, Color3.fromRGB(80, 80, 100), 1.5)
	local rl  = makeLabel(cap, "R"..i, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(150, 150, 170), Enum.Font.GothamBold, 18)
	roundDots[i] = { frame = cap, label = rl, str = str }
end

local function updateHUD(round, timeLeft, myWins, oppWins)
	local m = math.floor(timeLeft / 60)
	local s = math.max(0, math.floor(timeLeft % 60))
	timerLabel.Text = string.format("%d:%02d", m, s)

	if timeLeft <= 10 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
	elseif timeLeft <= 20 then
		timerLabel.TextColor3 = Color3.fromRGB(255, 160, 40)
	else
		timerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	for i = 1, 3 do
		local d = roundDots[i]
		if i == round then
			d.frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			d.label.TextColor3       = Color3.fromRGB(0, 0, 0)
			d.str.Color              = Color3.fromRGB(255, 215, 0)
		elseif i < round then
			local won = (i <= myWins)
			d.frame.BackgroundColor3 = won and Color3.fromRGB(0, 180, 50) or Color3.fromRGB(180, 30, 30)
			d.label.TextColor3       = Color3.fromRGB(255, 255, 255)
			d.str.Color              = won and Color3.fromRGB(0, 255, 70) or Color3.fromRGB(255, 60, 60)
		else
			d.frame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			d.label.TextColor3       = Color3.fromRGB(150, 150, 170)
			d.str.Color              = Color3.fromRGB(80, 80, 100)
		end
	end
end

--===========================================================
-- HP BAR
--===========================================================
local hpWrap = makeFrame(sg, UDim2.new(0, 300, 0, 52), UDim2.new(0.02, 0, 1, -68), Color3.fromRGB(4, 1, 14), 0.3, 15)
hpWrap.Visible = false
corner(hpWrap, 0.18)
stroke(hpWrap, Color3.fromRGB(180, 0, 0), 2)

local hpTextLabel = makeLabel(hpWrap, "HP  150 / 150", UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, 4), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 16)
local hpBg = makeFrame(hpWrap, UDim2.new(1, -12, 0, 10), UDim2.new(0, 6, 0, 28), Color3.fromRGB(35, 0, 0), 0, 16)
corner(hpBg, 1)
local hpBar = makeFrame(hpBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(50, 210, 50), 0, 17)
corner(hpBar, 1)

--===========================================================
-- VERTICAL SPELL BAR (right side, scrollable)
--===========================================================
-- Container on right side, vertically centered
local spellBarWrap = makeFrame(sg, UDim2.new(0, 140, 0, 0), UDim2.new(1, -150, 0.5, 0), Color3.fromRGB(0, 0, 0), 1, 15)
spellBarWrap.AutomaticSize = Enum.AutomaticSize.Y
spellBarWrap.Visible       = false
spellBarWrap.AnchorPoint   = Vector2.new(0, 0.5)
spellBarWrap.Position      = UDim2.new(1, -152, 0.5, 0)

-- Scroll frame for spells
local spellScroll = Instance.new("ScrollingFrame")
spellScroll.Size                = UDim2.new(1, 0, 0, 380)
spellScroll.Position            = UDim2.new(0, 0, 0, 0)
spellScroll.BackgroundTransparency = 1
spellScroll.BorderSizePixel     = 0
spellScroll.ScrollBarThickness  = 4
spellScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
spellScroll.CanvasSize          = UDim2.new(0, 0, 0, #SPELLS * 72 + 10)
spellScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
spellScroll.ZIndex              = 15
spellScroll.Parent              = spellBarWrap

local spellList = Instance.new("UIListLayout")
spellList.FillDirection       = Enum.FillDirection.Vertical
spellList.HorizontalAlignment = Enum.HorizontalAlignment.Center
spellList.SortOrder           = Enum.SortOrder.LayoutOrder
spellList.Padding             = UDim.new(0, 5)
spellList.Parent              = spellScroll

-- Padding
local listPad = Instance.new("UIPadding")
listPad.PaddingTop    = UDim.new(0, 5)
listPad.PaddingBottom = UDim.new(0, 5)
listPad.PaddingLeft   = UDim.new(0, 2)
listPad.PaddingRight  = UDim.new(0, 2)
listPad.Parent        = spellScroll

-- Header label
local spellHeader = makeLabel(spellBarWrap, "⚡ HECHIZOS", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, -0.07, 0),
	Color3.fromRGB(255, 215, 0), Enum.Font.GothamBlack, 16)

local spellButtons = {}
for i, sp in ipairs(SPELLS) do
	-- Card container
	local card = Instance.new("Frame")
	card.Name                 = "SpellCard_"..sp.name
	card.Size                 = UDim2.new(1, -4, 0, 65)
	card.BackgroundColor3     = sp.btnBg
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel      = 0
	card.LayoutOrder           = i
	card.ZIndex                = 15
	card.Parent                = spellScroll
	corner(card, 0.14)

	local cardStroke = stroke(card, sp.glowColor, 1.5)

	-- Icon circle left
	local iconBg = makeFrame(card, UDim2.new(0, 42, 0, 42), UDim2.new(0, 5, 0.5, -21), sp.mainColor, 0.8, 16)
	corner(iconBg, 1)
	iconBg.BackgroundColor3 = sp.mainColor * 0.4
	local iconLabel = makeLabel(iconBg, sp.icon, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold, 17)

	-- Spell name
	local nameLabel = makeLabel(card, sp.label, UDim2.new(0, 85, 0, 22), UDim2.new(0, 52, 0, 6),
		sp.textColor, Enum.Font.GothamBlack, 16)
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Key hint
	local keyLabel = makeLabel(card, "["..sp.key.."]", UDim2.new(0, 28, 0, 16), UDim2.new(0, 52, 0, 28),
		Color3.fromRGB(180, 180, 180), Enum.Font.GothamMedium, 16)
	keyLabel.TextScaled = true
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- CD label
	local cdLabel = makeLabel(card, tostring(sp.cd).."s", UDim2.new(0, 35, 0, 16), UDim2.new(0, 82, 0, 28),
		Color3.fromRGB(140, 140, 160), Enum.Font.GothamBold, 16)
	cdLabel.TextScaled = true
	cdLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Cooldown overlay
	local ovFrame = makeFrame(card, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 0, 0), 0.55, 17)
	ovFrame.Visible = false
	corner(ovFrame, 0.14)

	local ovText = makeLabel(ovFrame, "", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0),
		sp.textColor, Enum.Font.GothamBlack, 18)
	ovText.TextSize  = 26

	-- Cooldown bar at bottom of card
	local cdBarBg = makeFrame(card, UDim2.new(1, -10, 0, 4), UDim2.new(0, 5, 1, -8), Color3.fromRGB(20, 20, 20), 0, 17)
	corner(cdBarBg, 1)
	local cdBar = makeFrame(cdBarBg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), sp.glowColor, 0, 17)
	corner(cdBar, 1)

	-- TextButton overlay (invisible, full card)
	local btn = Instance.new("TextButton")
	btn.Size                 = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                 = ""
	btn.ZIndex               = 18
	btn.Parent               = card

	spellButtons[sp.name] = {
		card      = card,
		cardStroke = cardStroke,
		ovFrame   = ovFrame,
		ovText    = ovText,
		cdBar     = cdBar,
		cdBarBg   = cdBarBg,
		iconBg    = iconBg,
		btn       = btn,
		sp        = sp,
	}
end

--===========================================================
-- CLASH UI (center screen bar)
--===========================================================
local clashWrap = makeFrame(sg, UDim2.new(0, 500, 0, 70), UDim2.new(0.5, -250, 0.85, 0), Color3.fromRGB(0, 0, 0), 1, 60)
clashWrap.Visible = false

local clashBg = makeFrame(clashWrap, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(5, 3, 15), 0.15, 61)
corner(clashBg, 0.25)
stroke(clashBg, Color3.fromRGB(100, 255, 100), 2)

local clashTitle = makeLabel(clashWrap, "⚡ CHOQUE DE HECHIZOS ⚡", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 4),
	Color3.fromRGB(100, 255, 100), Enum.Font.GothamBlack, 62)

-- Progress bar for clash
local clashBarBg = makeFrame(clashWrap, UDim2.new(0.9, 0, 0, 12), UDim2.new(0.05, 0, 0, 32), Color3.fromRGB(20, 20, 20), 0, 62)
corner(clashBarBg, 1)

local clashBarLeft = makeFrame(clashBarBg, UDim2.new(0.5, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(255, 100, 100), 0, 63)
clashBarLeft.AnchorPoint = Vector2.new(1, 0)
clashBarLeft.Position    = UDim2.new(0.5, 0, 0, 0)

local clashBarRight = makeFrame(clashBarBg, UDim2.new(0.5, 0, 1, 0), UDim2.new(0.5, 0, 0, 0), Color3.fromRGB(100, 255, 100), 0, 63)

-- Orb marker
local clashOrb = makeFrame(clashBarBg, UDim2.new(0, 18, 0, 18), UDim2.new(0.5, -9, 0.5, -9), Color3.fromRGB(255, 255, 255), 0, 64)
clashOrb.AnchorPoint = Vector2.new(0, 0)
corner(clashOrb, 1)

local clashSpell1Label = makeLabel(clashWrap, "", UDim2.new(0.45, 0, 0, 18), UDim2.new(0.02, 0, 0, 50),
	Color3.fromRGB(255, 120, 120), Enum.Font.GothamBold, 62)
clashSpell1Label.TextXAlignment = Enum.TextXAlignment.Left

local clashSpell2Label = makeLabel(clashWrap, "", UDim2.new(0.45, 0, 0, 18), UDim2.new(0.53, 0, 0, 50),
	Color3.fromRGB(100, 255, 100), Enum.Font.GothamBold, 62)
clashSpell2Label.TextXAlignment = Enum.TextXAlignment.Right

--===========================================================
-- RESULT SCREEN
--===========================================================
local resWrap = makeFrame(sg, UDim2.new(0, 400, 0, 180), UDim2.new(0.5, -200, 0.32, 0), Color3.fromRGB(0, 0, 0), 0.25, 90)
resWrap.Visible = false
corner(resWrap, 0.14)
stroke(resWrap, Color3.fromRGB(255, 215, 0), 2.5)

local resTxt = makeLabel(resWrap, "VICTORIA", UDim2.new(1, 0, 0.55, 0), UDim2.new(0, 0, 0.08, 0),
	Color3.fromRGB(255, 215, 0), Enum.Font.GothamBlack, 91)
resTxt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
resTxt.TextStrokeTransparency = 0
resTxt.TextTransparency = 1

local resSub = makeLabel(resWrap, "", UDim2.new(1, 0, 0.28, 0), UDim2.new(0, 0, 0.68, 0),
	Color3.fromRGB(200, 200, 200), Enum.Font.GothamMedium, 91)
resSub.TextTransparency = 1

--===========================================================
-- WAND ANIMATION (client-side)
--===========================================================
local wandAnimConn = nil

local function getRightShoulderMotor(char)
	if not char then return nil end
	local upperTorso = char:FindFirstChild("UpperTorso")
	local torso      = char:FindFirstChild("Torso")
	if upperTorso then return upperTorso:FindFirstChild("RightShoulder") end
	if torso then return torso:FindFirstChild("Right Shoulder") end
	return nil
end

local function playWandCastAnimation(spellName)
	local char = LocalPlayer.Character
	if not char then return end

	local motor       = getRightShoulderMotor(char)
	local wandInChar  = char:FindFirstChild(WAND_NAME)
	if not motor then return end

	-- Spell-specific animation flavor
	local sp = spellMap[spellName]
	local rotX1, rotY1, rotZ1, rotX2, rotY2, rotZ2
	local dur1, dur2, dur3

	if spellName == "AvadaKedavra" then
		-- Grand sweeping upward motion
		rotX1, rotY1, rotZ1 = -55, 15, 20
		rotX2, rotY2, rotZ2 = 12, -8, -12
		dur1, dur2, dur3 = 0.1, 0.08, 0.22
	elseif spellName == "Crucio" then
		-- Violent downward jab
		rotX1, rotY1, rotZ1 = -30, -20, 25
		rotX2, rotY2, rotZ2 = 20, 5, -10
		dur1, dur2, dur3 = 0.08, 0.07, 0.2
	elseif spellName == "Sectumsempra" then
		-- Sharp horizontal slash
		rotX1, rotY1, rotZ1 = -15, 30, -35
		rotX2, rotY2, rotZ2 = 5, -15, 15
		dur1, dur2, dur3 = 0.07, 0.06, 0.18
	elseif spellName == "Stupefy" then
		-- Quick jab forward
		rotX1, rotY1, rotZ1 = -40, 8, 15
		rotX2, rotY2, rotZ2 = 8, -5, -8
		dur1, dur2, dur3 = 0.08, 0.07, 0.2
	else
		-- Standard flick
		rotX1, rotY1, rotZ1 = -35, 10, 18
		rotX2, rotY2, rotZ2 = 8, -4, -8
		dur1, dur2, dur3 = 0.1, 0.08, 0.22
	end

	local origTransform = motor.Transform

	-- Phase 1: Wind-up
	motor.Transform = origTransform * CFrame.Angles(math.rad(rotX1), math.rad(rotY1), math.rad(rotZ1))

	-- Burst emitter on wand tip
	local tip = wandInChar and wandInChar:FindFirstChild("WandTip")
	local tipAtt = tip and tip:FindFirstChild("TipAttachment")
	local burstEmitter = tipAtt and tipAtt:FindFirstChild("BurstEmitter")
	if burstEmitter then
		burstEmitter.Color = sp and ColorSequence.new(sp.mainColor) or burstEmitter.Color
		burstEmitter:Emit(30)
	end

	task.delay(dur1, function()
		if not motor.Parent then return end
		-- Phase 2: Release snap
		motor.Transform = origTransform * CFrame.Angles(math.rad(rotX2), math.rad(rotY2), math.rad(rotZ2))

		if burstEmitter then
			burstEmitter:Emit(50)
		end

		task.delay(dur2, function()
			if not motor.Parent then return end
			-- Phase 3: Return
			local ret = TweenService:Create(motor, TweenInfo.new(dur3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Transform = origTransform})
			ret:Play()
		end)
	end)
end

-- Camera shake
local shakeActive = false
local function shakeCamera(intensity, duration)
	if shakeActive then return end
	shakeActive = true
	local elapsed = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= duration then
			conn:Disconnect()
			shakeActive = false
			return
		end
		local decay   = 1 - (elapsed / duration)
		local offsetX = (math.random() - 0.5) * 2 * intensity * decay
		local offsetY = (math.random() - 0.5) * 2 * intensity * decay
		Camera.CFrame = Camera.CFrame * CFrame.new(offsetX * 0.1, offsetY * 0.1, 0)
	end)
end

--===========================================================
-- SPELL CAST
--===========================================================
local function castSpell(spellName)
	if not isInDuel then return end
	if spellOnCD[spellName] then return end

	local char = LocalPlayer.Character
	if not char then return end
	local hum  = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local wand = char:FindFirstChild(WAND_NAME) or Backpack:FindFirstChild(WAND_NAME)
	if wand and wand.Parent == Backpack then
		hum:EquipTool(wand)
		task.wait(0.10)
	end

	if not char:FindFirstChild(WAND_NAME) then return end

	local sb = spellButtons[spellName]
	if not sb then return end
	local sp = sb.sp

	-- Play wand animation
	playWandCastAnimation(spellName)

	-- Flash the spell card
	tw(sb.card, {BackgroundColor3 = sp.mainColor * 0.6}, 0.08):Play()
	task.delay(0.12, function()
		tw(sb.card, {BackgroundColor3 = sp.btnBg}, 0.2):Play()
	end)

	spellOnCD[spellName] = true
	RE_CastSpell:FireServer(spellName)

	-- Screen flash for cast
	local fl = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), sp.mainColor, 0.7, 75)
	tw(fl, {BackgroundTransparency = 1}, 0.2):Play()
	task.delay(0.25, function() if fl.Parent then fl:Destroy() end end)

	-- Cooldown progress
	sb.ovFrame.Visible = true
	sb.cdBar.Size      = UDim2.new(0, 0, 1, 0)

	local endT = tick() + sp.cd
	task.spawn(function()
		while tick() < endT do
			local remaining = endT - tick()
			sb.ovText.Text  = string.format("%.1f", remaining)
			local pct = 1 - (remaining / sp.cd)
			sb.cdBar.Size   = UDim2.new(pct, 0, 1, 0)
			task.wait(0.05)
		end
		spellOnCD[spellName]   = nil
		sb.ovFrame.Visible     = false
		sb.cdBar.Size          = UDim2.new(1, 0, 1, 0)

		-- Ready flash
		tw(sb.card, {BackgroundColor3 = sp.mainColor * 0.5}, 0.15):Play()
		task.delay(0.2, function()
			tw(sb.card, {BackgroundColor3 = sp.btnBg}, 0.25):Play()
		end)
	end)
end

-- Button connections
for spName, sb in pairs(spellButtons) do
	sb.btn.Activated:Connect(function()
		castSpell(spName)
	end)
end

-- Keyboard shortcuts
UserInputService.InputBegan:Connect(function(inp, gp)
	if gp then return end
	for _, sp in ipairs(SPELLS) do
		if inp.KeyCode == Enum.KeyCode[sp.key] then
			castSpell(sp.name)
			return
		end
	end
end)

--===========================================================
-- SPELL EFFECTS (received from server)
--===========================================================
RE_SpellEffect.OnClientEvent:Connect(function(spellName, isVictim)
	local sp = spellMap[spellName:gsub("_hit", "")]

	if isVictim then
		-- More intense screen flash if WE got hit
		local hitColor = sp and sp.mainColor or Color3.fromRGB(255, 50, 50)
		local fl = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), hitColor, 0.35, 80)
		tw(fl, {BackgroundTransparency = 1}, 0.6):Play()
		task.delay(0.7, function() if fl.Parent then fl:Destroy() end end)

		-- Shake based on spell power
		local intensity = 1.0
		if spellName:find("AvadaKedavra") then intensity = 3.0
		elseif spellName:find("Crucio") then intensity = 2.5
		elseif spellName:find("Sectumsempra") then intensity = 2.0
		elseif spellName:find("Serpensortia") then intensity = 1.5
		else intensity = 1.0 end

		shakeCamera(intensity, 0.7)

		-- Red vignette briefly
		local vig = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(180, 0, 0), 0.6, 78)
		tw(vig, {BackgroundTransparency = 1}, 0.9, Enum.EasingStyle.Quad):Play()
		task.delay(1, function() if vig.Parent then vig:Destroy() end end)
	else
		-- Caster sees smaller flash confirming hit
		if sp then
			local fl2 = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), sp.mainColor, 0.75, 75)
			tw(fl2, {BackgroundTransparency = 1}, 0.25):Play()
			task.delay(0.3, function() if fl2.Parent then fl2:Destroy() end end)
		end
	end
end)

--===========================================================
-- WAND ANIM (server tells us to animate)
--===========================================================
RE_WandAnim.OnClientEvent:Connect(function(spellName)
	-- Only animate our own char (server fires only to caster)
	playWandCastAnimation(spellName)
end)

--===========================================================
-- CLASH UI UPDATE
--===========================================================
RE_ClashUpdate.OnClientEvent:Connect(function(event, mySpell, theirSpell, myProgress)
	if event == "Start" then
		clashWrap.Visible = true
		local mySp    = spellMap[mySpell]
		local theirSp = spellMap[theirSpell]
		clashSpell1Label.Text       = mySp and (mySp.icon.." "..mySp.label) or mySpell
		clashSpell2Label.Text       = theirSp and (theirSp.label.." "..theirSp.icon) or theirSpell
		if mySp then clashBarLeft.BackgroundColor3  = mySp.mainColor end
		if theirSp then clashBarRight.BackgroundColor3 = theirSp.mainColor end
		clashTitle.TextColor3 = Color3.fromRGB(100, 255, 100)

		-- Clash start screen flash
		local fl = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(200, 255, 200), 0.4, 80)
		tw(fl, {BackgroundTransparency = 1}, 0.5):Play()
		task.delay(0.6, function() if fl.Parent then fl:Destroy() end end)

		shakeCamera(0.5, 0.4)

	elseif event == "Progress" then
		-- myProgress: 1 = I'm winning, 0 = they're winning
		local orbX = 1 - myProgress  -- orb position (0=left, 1=right from opponent's perspective)
		clashOrb.Position = UDim2.new(orbX, -9, 0.5, -9)
		clashBarLeft.Size  = UDim2.new(myProgress, 0, 1, 0)
		clashBarRight.Size = UDim2.new(1 - myProgress, 0, 1, 0)
		clashBarRight.Position = UDim2.new(myProgress, 0, 0, 0)

		-- Slight pulse shake during clash
		if math.random() > 0.7 then
			shakeCamera(0.2, 0.1)
		end

	elseif event == "End" then
		local won = (myProgress >= 0.98) or (myProgress > 0.5)
		clashTitle.Text       = won and "⚡ ¡TÚ GANAS EL CHOQUE!" or "⚡ PERDISTE EL CHOQUE..."
		clashTitle.TextColor3 = won and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 80, 80)

		-- Flash
		local winCol = won and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 50, 50)
		local fl = makeFrame(sg, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), winCol, 0.35, 80)
		tw(fl, {BackgroundTransparency = 1}, 0.6):Play()
		task.delay(0.7, function() if fl.Parent then fl:Destroy() end end)

		shakeCamera(won and 0.5 or 1.5, 0.6)

		task.delay(1.5, function()
			tw(clashWrap, {}, 0.4):Play()
			clashWrap.Visible = false
		end)
	end
end)

--===========================================================
-- ANNOUNCEMENT
--===========================================================
local function playAnnouncement(opponentName)
	fadeBlack(0, 0.5)
	announceBg.Visible = true
	announceBg.BackgroundTransparency = 0
	ann1.TextTransparency = 1
	ann2.TextTransparency = 1
	annVS.TextTransparency = 1
	annDivider.Visible = false
	task.wait(0.1)

	tw(ann1, {TextTransparency = 0}, 0.55, Enum.EasingStyle.Back):Play()
	task.wait(0.35)
	tw(ann2, {TextTransparency = 0}, 0.45, Enum.EasingStyle.Back):Play()
	task.wait(0.35)

	annDivider.Visible = true
	annVS.Text = LocalPlayer.Name .. "  ⚔  " .. opponentName
	oppLabel.Text = "VS  " .. opponentName

	tw(annVS, {TextTransparency = 0}, 0.4):Play()
	task.wait(2.0)

	tw(ann1, {TextTransparency = 1}, 0.28):Play()
	tw(ann2, {TextTransparency = 1}, 0.28):Play()
	tw(annVS, {TextTransparency = 1}, 0.28):Play()
	task.wait(0.2)
	tw(announceBg, {BackgroundTransparency = 1}, 0.4, Enum.EasingStyle.Linear):Play()
	task.wait(0.45)
	announceBg.Visible = false

	fadeBlack(1, 0.45)

	isInDuel = true
	hudWrap.Visible       = true
	hpWrap.Visible        = true
	spellBarWrap.Visible  = true

	-- Auto-equip wand
	task.defer(function()
		local char = LocalPlayer.Character
		local hum  = char and char:FindFirstChildOfClass("Humanoid")
		local wand = Backpack:FindFirstChild(WAND_NAME) or (char and char:FindFirstChild(WAND_NAME))
		if hum and wand and wand.Parent == Backpack then
			hum:EquipTool(wand)
		end
	end)
end

--===========================================================
-- BATTLE EVENTS
--===========================================================
RE_BattleStart.OnClientEvent:Connect(function(opponentName)
	task.spawn(playAnnouncement, opponentName)
end)

RE_BattleEnd.OnClientEvent:Connect(function(winnerName, isWinner)
	isInDuel   = false
	spellOnCD  = {}

	spellBarWrap.Visible  = false
	hpWrap.Visible        = false
	hudWrap.Visible       = false
	cdWrap.Visible        = false
	clashWrap.Visible     = false
	announceBg.Visible    = false
	blackScreen.BackgroundTransparency = 1

	local isTie   = (winnerName == "EMPATE")
	local sub     = ""
	local resColor

	if isTie then
		resTxt.Text    = "⚖ EMPATE"
		resColor       = Color3.fromRGB(220, 220, 80)
		sub            = "Ningún mago ganó esta vez"
	elseif isWinner then
		resTxt.Text    = "🏆 VICTORIA"
		resColor       = Color3.fromRGB(255, 215, 0)
		sub            = "¡Has ganado el duelo!"
		shakeCamera(0.3, 0.5)
	else
		resTxt.Text    = "💀 DERROTA"
		resColor       = Color3.fromRGB(220, 55, 55)
		sub            = "Ganó " .. winnerName
	end

	resTxt.TextColor3  = resColor
	resSub.Text        = sub or ""

	local resStroke = resWrap:FindFirstChildOfClass("UIStroke")
	if resStroke then resStroke.Color = resColor end

	resWrap.Visible               = true
	resWrap.BackgroundTransparency = 1
	resTxt.TextTransparency       = 1
	resSub.TextTransparency       = 1

	tw(resWrap, {BackgroundTransparency = 0.25}, 0.5, Enum.EasingStyle.Back):Play()
	task.wait(0.3)
	tw(resTxt, {TextTransparency = 0}, 0.45):Play()
	tw(resSub, {TextTransparency = 0}, 0.45):Play()
	task.wait(4)
	tw(resWrap, {BackgroundTransparency = 1}, 0.45):Play()
	tw(resTxt,  {TextTransparency = 1}, 0.45):Play()
	tw(resSub,  {TextTransparency = 1}, 0.45):Play()
	task.wait(0.5)
	resWrap.Visible = false
end)

RE_Countdown.OnClientEvent:Connect(function(n)
	showCountdown(n)
end)

RE_RoundUpdate.OnClientEvent:Connect(function(round, timeLeft, myWins, oppWins)
	updateHUD(round, timeLeft, myWins, oppWins)
end)

--===========================================================
-- HP BAR UPDATE
--===========================================================
RunService.Heartbeat:Connect(function()
	if not isInDuel then return end
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
	TweenService:Create(hpBar, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
	hpTextLabel.Text = "HP  "..math.ceil(hum.Health).." / "..math.ceil(hum.MaxHealth)

	if pct > 0.55 then
		hpBar.BackgroundColor3 = Color3.fromRGB(40, 200, 50)
	elseif pct > 0.28 then
		hpBar.BackgroundColor3 = Color3.fromRGB(255, 160, 0)
	else
		hpBar.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
	end
end)

--===========================================================
-- AUTO-EQUIP WAND
--===========================================================
local function tryEquip()
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or not isInDuel then return end
	local wand = Backpack:FindFirstChild(WAND_NAME) or char:FindFirstChild(WAND_NAME)
	if wand and wand.Parent == Backpack then
		task.wait(0.1)
		hum:EquipTool(wand)
	end
end

Backpack.ChildAdded:Connect(function(c)
	if c.Name == WAND_NAME then tryEquip() end
end)

LocalPlayer.CharacterAdded:Connect(function()
	isInDuel  = false
	spellOnCD = {}

	hudWrap.Visible       = false
	hpWrap.Visible        = false
	spellBarWrap.Visible  = false
	cdWrap.Visible        = false
	clashWrap.Visible     = false
	resWrap.Visible       = false
	announceBg.Visible    = false
	blackScreen.BackgroundTransparency = 1
	task.wait(0.25)
end)

print("[DuelGame v11.0] LocalScript OK — Hechizos verticales, animación varita, clash épico")
