local EliteLib = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local CHAMBER_DIR = "ChamberAI"

local function EnsureChamberDir()
	if isfolder and makefolder and not isfolder(CHAMBER_DIR) then
		pcall(makefolder, CHAMBER_DIR)
	end
end
EnsureChamberDir()

local CONFIG_FILE = CHAMBER_DIR .. "/ChamberChat_Config.json"

local DefaultConfig = {
	BgTransparency = 0,
	GlowActive = true,
	TypewriterActive = true,
	ChatTextSize = 14,
	ScanlineActive = true,
	RippleActive = true,
}

local Config = table.clone(DefaultConfig)

local function SaveConfig()
	if writefile then
		pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
	end
end

local function LoadConfig()
	if isfile and isfile(CONFIG_FILE) then
		local ok, decoded = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
		if ok and type(decoded) == "table" then
			for k, v in pairs(DefaultConfig) do
				if decoded[k] == nil then decoded[k] = v end
			end
			Config = decoded
			return
		end
	end
	Config = table.clone(DefaultConfig)
end

LoadConfig()

local C = {
	Text        = Color3.fromRGB(230, 230, 235),
	Bg          = Color3.fromRGB(10, 10, 13),
	Sidebar     = Color3.fromRGB(15, 15, 20),
	Accent      = Color3.fromRGB(212, 175, 55),
	AccentDim   = Color3.fromRGB(140, 110, 30),
	Surface     = Color3.fromRGB(28, 28, 35),
	Outline     = Color3.fromRGB(40, 40, 50),
	Muted       = Color3.fromRGB(90, 90, 100),
	Danger      = Color3.fromRGB(200, 50, 50),
	Good        = Color3.fromRGB(70, 180, 100),
	Warn        = Color3.fromRGB(210, 170, 60),
	Font        = Enum.Font.Gotham,
	FontBold    = Enum.Font.GothamBold,
	FontMono    = Enum.Font.Code,
}

local AllTransparencyTargets = {}
local AllGridCells = {}

local function RegisterTransparency(instance, baseTransparency)
	table.insert(AllTransparencyTargets, { inst = instance, base = baseTransparency or 0 })
end

local function ApplyTransparency(value, instant)
	for _, cell in ipairs(AllGridCells) do
		if cell and cell.Parent then
			local t = math.min(0.55 + value * 0.45, 1)
			if instant then cell.ImageTransparency = t
			else TweenService:Create(cell, TweenInfo.new(0.2), { ImageTransparency = t }):Play() end
		end
	end
	for _, entry in ipairs(AllTransparencyTargets) do
		if entry.inst and entry.inst.Parent then
			local target = math.min(entry.base + value, 1)
			if instant then
				entry.inst.BackgroundTransparency = target
			else
				TweenService:Create(entry.inst, TweenInfo.new(0.2), { BackgroundTransparency = target }):Play()
			end
		end
	end
end

local function MakeRipple(parent, x, y)
	if not Config.RippleActive then return end
	local ripple = Instance.new("Frame", parent)
	ripple.Size = UDim2.new(0, 0, 0, 0)
	ripple.Position = UDim2.new(0, x - parent.AbsolutePosition.X, 0, y - parent.AbsolutePosition.Y)
	ripple.BackgroundColor3 = C.Accent
	ripple.BackgroundTransparency = 0.6
	ripple.BorderSizePixel = 0
	ripple.ZIndex = 10
	Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)
	local size = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.5
	TweenService:Create(ripple, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, size, 0, size),
		Position = UDim2.new(0, x - parent.AbsolutePosition.X - size / 2, 0, y - parent.AbsolutePosition.Y - size / 2),
		BackgroundTransparency = 1,
	}):Play()
	task.delay(0.5, function() ripple:Destroy() end)
end

local function GlitchText(label, finalText)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#@$%&*"
	task.spawn(function()
		for i = 1, 8 do
			local glitch = ""
			for j = 1, #finalText do
				if math.random() > 0.5 then
					glitch = glitch .. string.sub(chars, math.random(1, #chars), math.random(1, #chars))
				else
					glitch = glitch .. string.sub(finalText, j, j)
				end
			end
			label.Text = glitch
			task.wait(0.04)
		end
		label.Text = finalText
	end)
end

function EliteLib:CreateWindow(titleText, subtitleText)
	if CoreGui:FindFirstChild("ChamberChatPanel") then
		CoreGui.ChamberChatPanel:Destroy()
	end
	AllTransparencyTargets = {}
	AllGridCells = {}

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "ChamberChatPanel"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.Parent = CoreGui

	local MainFrame = Instance.new("Frame")
	MainFrame.Size = UDim2.new(0, 620, 0, 520)
	MainFrame.Position = UDim2.new(0.5, -310, 0.5, -260)
	MainFrame.BackgroundColor3 = C.Bg
	MainFrame.BackgroundTransparency = Config.BgTransparency
	MainFrame.BorderSizePixel = 0
	MainFrame.Active = true
	MainFrame.ClipsDescendants = true
	MainFrame.Parent = ScreenGui
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)
	RegisterTransparency(MainFrame, 0)
	local MainStroke = Instance.new("UIStroke", MainFrame)
	MainStroke.Color = C.Accent
	MainStroke.Thickness = 1.5
	MainStroke.Transparency = Config.GlowActive and 0.4 or 1

	local GridBgCanvas = Instance.new("CanvasGroup", MainFrame)
	GridBgCanvas.Size = UDim2.new(1, 0, 1, 0)
	GridBgCanvas.Position = UDim2.new(0, 0, 0, 0)
	GridBgCanvas.BackgroundTransparency = 1
	Instance.new("UICorner", GridBgCanvas).CornerRadius = UDim.new(0, 14)

	local GridBg = Instance.new("ImageLabel", GridBgCanvas)
	GridBg.Size = UDim2.new(4, 0, 1, 0)
	GridBg.Position = UDim2.new(0, 0, 0, 0)
	GridBg.BackgroundTransparency = 1
	GridBg.BorderSizePixel = 0
	GridBg.ZIndex = 1
	GridBg.Image = "rbxassetid://6372755229"
	GridBg.ImageColor3 = Color3.fromRGB(20, 20, 26)
	GridBg.ImageTransparency = 0.6
	GridBg.ScaleType = Enum.ScaleType.Tile
	GridBg.TileSize = UDim2.new(0, 40, 0, 40)
	table.insert(AllGridCells, GridBg)

	local EdgeGradients = {}
	local gradientDirs = {
		{ size = UDim2.new(0.35, 0, 1, 0), pos = UDim2.new(0, 0, 0, 0), rot = 90 },
		{ size = UDim2.new(0.35, 0, 1, 0), pos = UDim2.new(0.65, 0, 0, 0), rot = -90 },
		{ size = UDim2.new(1, 0, 0.35, 0), pos = UDim2.new(0, 0, 0, 0), rot = 0 },
		{ size = UDim2.new(1, 0, 0.35, 0), pos = UDim2.new(0, 0, 0.65, 0), rot = 180 },
	}
	for _, d in ipairs(gradientDirs) do
		local veil = Instance.new("Frame", MainFrame)
		veil.Size = d.size
		veil.Position = d.pos
		veil.BackgroundColor3 = C.Bg
		veil.BackgroundTransparency = 1
		veil.BorderSizePixel = 0
		veil.ZIndex = 2
		local grad = Instance.new("UIGradient", veil)
		grad.Color = ColorSequence.new(Color3.fromRGB(10,10,13), Color3.fromRGB(10,10,13))
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Rotation = d.rot
		table.insert(EdgeGradients, veil)
	end

	local gridOffset = 0
	local GridBgTweenInfo = TweenInfo.new(10,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut,
		-1,
		false
	)
	task.spawn(function()
		local GridBgTween = TweenService:Create(GridBg,GridBgTweenInfo,{Position = UDim2.new(0.25, 0, 0, 0)})
		GridBgTween:Play()
	end)

	local ScanlineFrame = Instance.new("Frame", MainFrame)
	ScanlineFrame.Size = UDim2.new(1, 0, 1, 0)
	ScanlineFrame.BackgroundTransparency = 1
	ScanlineFrame.ZIndex = 100
	ScanlineFrame.BorderSizePixel = 0

	if Config.ScanlineActive then
		for i = 0, 260 do
			local line = Instance.new("Frame", ScanlineFrame)
			line.Size = UDim2.new(1, 0, 0, 1)
			line.Position = UDim2.new(0, 0, 0, i * 2)
			line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			line.BackgroundTransparency = 0.94
			line.BorderSizePixel = 0
			line.ZIndex = 100
		end
	end

	local glowConn
	local function RestartGlowLoop()
		if glowConn then glowConn:Disconnect() glowConn = nil end
		if not Config.GlowActive then
			MainStroke.Transparency = 1
			return
		end
		local function loop()
			while task.wait(2) do
				if not ScreenGui or not ScreenGui.Parent then break end
				if not Config.GlowActive then MainStroke.Transparency = 1; break end
				TweenService:Create(MainStroke, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.2 }):Play()
				task.wait(1.8)
				TweenService:Create(MainStroke, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.75 }):Play()
			end
		end
		task.spawn(loop)
	end
	RestartGlowLoop()

	local TopBar = Instance.new("Frame")
	TopBar.Size = UDim2.new(1, 0, 0, 48)
	TopBar.BackgroundColor3 = C.Sidebar
	TopBar.BackgroundTransparency = Config.BgTransparency
	TopBar.BorderSizePixel = 0
	TopBar.ZIndex = 5
	TopBar.Parent = MainFrame
	Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 14)
	RegisterTransparency(TopBar, 0)

	local TopBarCoverBottom = Instance.new("Frame", TopBar)
	TopBarCoverBottom.Size = UDim2.new(1, 0, 0, 14)
	TopBarCoverBottom.Position = UDim2.new(0, 0, 1, -14)
	TopBarCoverBottom.BackgroundColor3 = C.Sidebar
	TopBarCoverBottom.BackgroundTransparency = Config.BgTransparency
	TopBarCoverBottom.BorderSizePixel = 0
	TopBarCoverBottom.ZIndex = 5
	RegisterTransparency(TopBarCoverBottom, 0)

	local AccentBar = Instance.new("Frame", TopBar)
	AccentBar.Size = UDim2.new(1, 0, 0, 2)
	AccentBar.Position = UDim2.new(0, 0, 1, -2)
	AccentBar.BackgroundColor3 = C.Accent
	AccentBar.BackgroundTransparency = 0.5
	AccentBar.BorderSizePixel = 0
	AccentBar.ZIndex = 6

	local dragging, dragStart, startPos
	TopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	local TitleLabel = Instance.new("TextLabel", TopBar)
	TitleLabel.Size = UDim2.new(1, -130, 0, 26)
	TitleLabel.Position = UDim2.new(0, 18, 0, 6)
	TitleLabel.Text = titleText
	TitleLabel.Font = C.FontBold
	TitleLabel.TextSize = 15
	TitleLabel.TextColor3 = C.Accent
	TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	TitleLabel.BackgroundTransparency = 1
	TitleLabel.ZIndex = 6

	local SubtitleLabel = Instance.new("TextLabel", TopBar)
	SubtitleLabel.Size = UDim2.new(1, -130, 0, 14)
	SubtitleLabel.Position = UDim2.new(0, 18, 0, 30)
	SubtitleLabel.Text = subtitleText
	SubtitleLabel.Font = C.FontMono
	SubtitleLabel.TextSize = 10
	SubtitleLabel.TextColor3 = C.Muted
	SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	SubtitleLabel.BackgroundTransparency = 1
	SubtitleLabel.ZIndex = 6

	local function MakeTopBtn(offsetX, symbol, strokeColor)
		local btn = Instance.new("TextButton", TopBar)
		btn.Size = UDim2.new(0, 28, 0, 28)
		btn.Position = UDim2.new(1, offsetX, 0, 10)
		btn.BackgroundColor3 = C.Surface
		btn.Text = symbol
		btn.Font = Enum.Font.SourceSansBold
		btn.TextSize = 20
		btn.TextColor3 = C.Text
		btn.BorderSizePixel = 0
		btn.ZIndex = 7
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
		local s = Instance.new("UIStroke", btn)
		s.Color = strokeColor
		s.Transparency = 0.5
		btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = strokeColor, TextColor3 = C.Bg }):Play() end)
		btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = C.Surface, TextColor3 = C.Text }):Play() end)
		return btn
	end

	local CloseBtn = MakeTopBtn(-36, "×", C.Danger)
	CloseBtn.MouseButton1Click:Connect(function()
		TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quart), { Size = UDim2.new(0, 620, 0, 0), BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function() ScreenGui:Destroy() end)
	end)

	local MinimizeBtn = MakeTopBtn(-70, "−", C.Accent)
	local isMinimized = false

	local ContentFrame = Instance.new("Frame", MainFrame)
	ContentFrame.Size = UDim2.new(1, 0, 1, -48)
	ContentFrame.Position = UDim2.new(0, 0, 0, 48)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.ClipsDescendants = true

	MinimizeBtn.MouseButton1Click:Connect(function()
		isMinimized = not isMinimized
		local targetSize = isMinimized and UDim2.new(0, 620, 0, 48) or UDim2.new(0, 620, 0, 520)
		TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = targetSize }):Play()
		ContentFrame.Visible = not isMinimized
	end)

	local Sidebar = Instance.new("Frame", ContentFrame)
	Sidebar.Size = UDim2.new(0, 155, 1, -16)
	Sidebar.Position = UDim2.new(0, 8, 0, 8)
	Sidebar.BackgroundColor3 = C.Sidebar
	Sidebar.BackgroundTransparency = Config.BgTransparency
	Sidebar.BorderSizePixel = 0
	Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)
	RegisterTransparency(Sidebar, 0)

	local SidebarStroke = Instance.new("UIStroke", Sidebar)
	SidebarStroke.Color = C.Outline
	SidebarStroke.Transparency = 0

	local TabBtnContainer = Instance.new("Frame", Sidebar)
	TabBtnContainer.Size = UDim2.new(1, -16, 1, -16)
	TabBtnContainer.Position = UDim2.new(0, 8, 0, 8)
	TabBtnContainer.BackgroundTransparency = 1
	local TabLayout = Instance.new("UIListLayout", TabBtnContainer)
	TabLayout.Padding = UDim.new(0, 4)

	local PageContainer = Instance.new("Frame", ContentFrame)
	PageContainer.Size = UDim2.new(1, -175, 1, -16)
	PageContainer.Position = UDim2.new(0, 171, 0, 8)
	PageContainer.BackgroundTransparency = 1

	local WindowEngine = {
		CurrentTab = nil,
		AllLabels = {},
		MainFrame = MainFrame,
		Sidebar = Sidebar,
		TopBar = TopBar,
		MainStroke = MainStroke,
		ScanlineFrame = ScanlineFrame,
		RestartGlowLoop = RestartGlowLoop,
	}

	function WindowEngine:ApplyBgTransparency(value, instant)
		Config.BgTransparency = value
		ApplyTransparency(value, instant)
	end

	function WindowEngine:UpdateAllTextSizes(size)
		for _, lbl in ipairs(self.AllLabels) do
			if lbl and lbl.Parent then lbl.TextSize = size end
		end
	end

	function WindowEngine:CreateTab(tabName)
		local isFirst = (self.CurrentTab == nil)

		local TabBtn = Instance.new("TextButton", TabBtnContainer)
		TabBtn.Size = UDim2.new(1, 0, 0, 36)
		TabBtn.BackgroundColor3 = C.Sidebar
		TabBtn.Text = ""
		TabBtn.BorderSizePixel = 0
		TabBtn.ClipsDescendants = true
		Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)
		local TabBtnStroke = Instance.new("UIStroke", TabBtn)
		TabBtnStroke.Color = C.Outline
		TabBtnStroke.Transparency = 1

		local TabIcon = Instance.new("Frame", TabBtn)
		TabIcon.Size = UDim2.new(0, 3, 0, 16)
		TabIcon.Position = UDim2.new(0, 0, 0.5, -8)
		TabIcon.BackgroundColor3 = C.Accent
		TabIcon.BackgroundTransparency = 1
		TabIcon.BorderSizePixel = 0

		local TabBtnLabel = Instance.new("TextLabel", TabBtn)
		TabBtnLabel.Size = UDim2.new(1, -16, 1, 0)
		TabBtnLabel.Position = UDim2.new(0, 12, 0, 0)
		TabBtnLabel.Text = tabName
		TabBtnLabel.Font = C.Font
		TabBtnLabel.TextSize = 12
		TabBtnLabel.TextColor3 = C.Muted
		TabBtnLabel.TextXAlignment = Enum.TextXAlignment.Left
		TabBtnLabel.BackgroundTransparency = 1

		local Page = Instance.new("Frame", PageContainer)
		Page.Size = UDim2.new(1, 0, 1, 0)
		Page.BackgroundTransparency = 1
		Page.Visible = false

		local ScrollFrame = Instance.new("ScrollingFrame", Page)
		ScrollFrame.Size = UDim2.new(1, 0, 1, 0)
		ScrollFrame.BackgroundTransparency = 1
		ScrollFrame.BorderSizePixel = 0
		ScrollFrame.ScrollBarThickness = 2
		ScrollFrame.ScrollBarImageColor3 = C.Accent
		ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
		local ScrollLayout = Instance.new("UIListLayout", ScrollFrame)
		ScrollLayout.Padding = UDim.new(0, 6)
		ScrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y + 10)
		end)
		local ScrollPadding = Instance.new("UIPadding", ScrollFrame)
		ScrollPadding.PaddingTop = UDim.new(0, 4)
		ScrollPadding.PaddingRight = UDim.new(0, 4)

		local function Select()
			if self.CurrentTab then
				self.CurrentTab.Page.Visible = false
				TweenService:Create(self.CurrentTab.Btn, TweenInfo.new(0.15), { BackgroundColor3 = C.Sidebar, TextColor3 = C.Muted }):Play()
				self.CurrentTab.BtnLabel.TextColor3 = C.Muted
				self.CurrentTab.Stroke.Transparency = 1
				TweenService:Create(self.CurrentTab.Icon, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
			end
			self.CurrentTab = { Page = Page, Btn = TabBtn, BtnLabel = TabBtnLabel, Stroke = TabBtnStroke, Icon = TabIcon }
			Page.Visible = true
			TweenService:Create(TabBtn, TweenInfo.new(0.15), { BackgroundColor3 = C.Surface }):Play()
			TabBtnLabel.TextColor3 = C.Accent
			TabBtnStroke.Transparency = 0
			TabBtnStroke.Color = C.Accent
			TweenService:Create(TabIcon, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		end

		TabBtn.MouseButton1Click:Connect(function()
			MakeRipple(TabBtn, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
			Select()
		end)
		if isFirst then Select() end

		local Elements = {}

		local function BaseElement(height)
			local f = Instance.new("Frame", ScrollFrame)
			f.Size = UDim2.new(1, 0, 0, height)
			f.BackgroundColor3 = C.Surface
			f.BorderSizePixel = 0
			f.ClipsDescendants = true
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
			local s = Instance.new("UIStroke", f)
			s.Color = C.Outline
			s.Transparency = 0.5
			return f, s
		end

		function Elements:AddButton(text, callback)
			local f, _ = BaseElement(42)
			f.BackgroundColor3 = C.Surface

			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(1, -50, 1, 0)
			lbl.Position = UDim2.new(0, 14, 0, 0)
			lbl.Text = text
			lbl.Font = C.Font
			lbl.TextSize = 13
			lbl.TextColor3 = C.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.BackgroundTransparency = 1

			local Arrow = Instance.new("TextLabel", f)
			Arrow.Size = UDim2.new(0, 30, 1, 0)
			Arrow.Position = UDim2.new(1, -38, 0, 0)
			Arrow.Text = "›"
			Arrow.Font = C.FontBold
			Arrow.TextSize = 20
			Arrow.TextColor3 = C.AccentDim
			Arrow.BackgroundTransparency = 1

			local btn = Instance.new("TextButton", f)
			btn.Size = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text = ""

			btn.MouseEnter:Connect(function()
				TweenService:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = C.Surface }):Play()
				TweenService:Create(Arrow, TweenInfo.new(0.12), { TextColor3 = C.Accent }):Play()
			end)
			btn.MouseLeave:Connect(function()
				TweenService:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = C.Surface }):Play()
				TweenService:Create(Arrow, TweenInfo.new(0.12), { TextColor3 = C.AccentDim }):Play()
			end)
			btn.MouseButton1Click:Connect(function()
				MakeRipple(f, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
				TweenService:Create(f, TweenInfo.new(0.08), { BackgroundColor3 = C.Accent }):Play()
				TweenService:Create(lbl, TweenInfo.new(0.08), { TextColor3 = C.Bg }):Play()
				task.wait(0.12)
				TweenService:Create(f, TweenInfo.new(0.15), { BackgroundColor3 = C.Surface }):Play()
				TweenService:Create(lbl, TweenInfo.new(0.15), { TextColor3 = C.Text }):Play()
				callback()
			end)
			return btn
		end

		function Elements:AddToggle(text, default, callback)
			local f, _ = BaseElement(42)
			local state = default

			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(1, -70, 1, 0)
			lbl.Position = UDim2.new(0, 14, 0, 0)
			lbl.Text = text
			lbl.Font = C.Font
			lbl.TextSize = 13
			lbl.TextColor3 = C.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.BackgroundTransparency = 1

			local Track = Instance.new("Frame", f)
			Track.Size = UDim2.new(0, 38, 0, 20)
			Track.Position = UDim2.new(1, -52, 0.5, -10)
			Track.BorderSizePixel = 0
			Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

			local Thumb = Instance.new("Frame", Track)
			Thumb.Size = UDim2.new(0, 16, 0, 16)
			Thumb.BackgroundColor3 = C.Bg
			Thumb.BorderSizePixel = 0
			Instance.new("UICorner", Thumb).CornerRadius = UDim.new(1, 0)

			local btn = Instance.new("TextButton", f)
			btn.Size = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text = ""

			local function UpdateVisuals(s, instant)
				state = s
				local bg = s and C.Accent or C.Sidebar
				local thumbPos = s and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
				if instant then
					Track.BackgroundColor3 = bg
					Thumb.Position = thumbPos
				else
					TweenService:Create(Track, TweenInfo.new(0.15), { BackgroundColor3 = bg }):Play()
					TweenService:Create(Thumb, TweenInfo.new(0.15), { Position = thumbPos }):Play()
				end
			end

			UpdateVisuals(default, true)

			btn.MouseButton1Click:Connect(function()
				MakeRipple(f, UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
				UpdateVisuals(not state, false)
				callback(state)
			end)

			return {
				SetState = function(self, val)
					UpdateVisuals(val, false)
					callback(val)
				end
			}
		end

		function Elements:AddSlider(text, min, max, default, callback)
			local f, _ = BaseElement(52)
			local currentVal = default

			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(1, -80, 0, 20)
			lbl.Position = UDim2.new(0, 14, 0, 6)
			lbl.Text = text
			lbl.Font = C.Font
			lbl.TextSize = 12
			lbl.TextColor3 = C.Text
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.BackgroundTransparency = 1

			local ValLabel = Instance.new("TextLabel", f)
			ValLabel.Size = UDim2.new(0, 70, 0, 20)
			ValLabel.Position = UDim2.new(1, -84, 0, 6)
			ValLabel.Font = C.FontMono
			ValLabel.TextSize = 12
			ValLabel.TextColor3 = C.Accent
			ValLabel.TextXAlignment = Enum.TextXAlignment.Right
			ValLabel.BackgroundTransparency = 1

			local BarBg = Instance.new("TextButton", f)
			BarBg.Size = UDim2.new(1, -28, 0, 5)
			BarBg.Position = UDim2.new(0, 14, 0, 36)
			BarBg.BackgroundColor3 = C.Sidebar
			BarBg.Text = ""
			BarBg.BorderSizePixel = 0
			Instance.new("UICorner", BarBg).CornerRadius = UDim.new(1, 0)

			local Fill = Instance.new("Frame", BarBg)
			Fill.BackgroundColor3 = C.Accent
			Fill.BorderSizePixel = 0
			Fill.Size = UDim2.new(0, 0, 1, 0)
			Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

			local Knob = Instance.new("Frame", BarBg)
			Knob.Size = UDim2.new(0, 12, 0, 12)
			Knob.Position = UDim2.new(0, -6, 0.5, -6)
			Knob.BackgroundColor3 = C.Accent
			Knob.BorderSizePixel = 0
			Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)
			local KnobStroke = Instance.new("UIStroke", Knob)
			KnobStroke.Color = C.Bg
			KnobStroke.Thickness = 2

			local function SetValue(val, instant)
				currentVal = math.clamp(math.round(val), min, max)
				local pct = (currentVal - min) / (max - min)
				ValLabel.Text = tostring(currentVal)
				if instant then
					Fill.Size = UDim2.new(pct, 0, 1, 0)
					Knob.Position = UDim2.new(pct, -6, 0.5, -6)
				else
					TweenService:Create(Fill, TweenInfo.new(0.12), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
					TweenService:Create(Knob, TweenInfo.new(0.12), { Position = UDim2.new(pct, -6, 0.5, -6) }):Play()
				end
			end

			SetValue(default, true)

			local sliding = false
			local function OnInput(input)
				local pct = math.clamp((input.Position.X - BarBg.AbsolutePosition.X) / BarBg.AbsoluteSize.X, 0, 1)
				local val = math.round(min + (max - min) * pct)
				SetValue(val, true)
				callback(val)
			end

			BarBg.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					sliding = true
					OnInput(input)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then OnInput(input) end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
			end)

			return {
				SetValue = function(self, val)
					SetValue(val, false)
					callback(val)
				end
			}
		end

		function Elements:AddLabel(text)
			local f = Instance.new("Frame", ScrollFrame)
			f.Size = UDim2.new(1, 0, 0, 24)
			f.BackgroundTransparency = 1

			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.Text = text
			lbl.Font = C.FontMono
			lbl.TextSize = 10
			lbl.TextColor3 = C.Muted
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.BackgroundTransparency = 1
			return lbl
		end

		function Elements:AddSeparator()
			local f = Instance.new("Frame", ScrollFrame)
			f.Size = UDim2.new(1, 0, 0, 1)
			f.BackgroundColor3 = C.Outline
			f.BackgroundTransparency = 0.5
			f.BorderSizePixel = 0
		end

		function Elements:AddSection(title)
			local f = Instance.new("Frame", ScrollFrame)
			f.Size = UDim2.new(1, 0, 0, 28)
			f.BackgroundTransparency = 1

			local line = Instance.new("Frame", f)
			line.Size = UDim2.new(1, 0, 0, 1)
			line.Position = UDim2.new(0, 0, 0.5, 0)
			line.BackgroundColor3 = C.Outline
			line.BackgroundTransparency = 0.3
			line.BorderSizePixel = 0

			local bg = Instance.new("Frame", f)
			bg.Size = UDim2.new(0, TextService:GetTextSize(title, 10, C.FontMono, Vector2.new(400, 28)).X + 16, 0, 18)
			bg.Position = UDim2.new(0, 8, 0.5, -9)
			bg.BackgroundColor3 = C.Surface
			bg.BorderSizePixel = 0
			Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

			local lbl = Instance.new("TextLabel", bg)
			lbl.Size = UDim2.new(1, -8, 1, 0)
			lbl.Position = UDim2.new(0, 4, 0, 0)
			lbl.Text = title
			lbl.Font = C.FontMono
			lbl.TextSize = 10
			lbl.TextColor3 = C.Accent
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.BackgroundTransparency = 1
		end

		function Elements:AddInfoRow(key, valueFunc)
			local f, _ = BaseElement(36)
			f.BackgroundColor3 = Color3.fromRGB(12, 12, 16)

			local keyLbl = Instance.new("TextLabel", f)
			keyLbl.Size = UDim2.new(0.45, 0, 1, 0)
			keyLbl.Position = UDim2.new(0, 12, 0, 0)
			keyLbl.Text = key
			keyLbl.Font = C.FontMono
			keyLbl.TextSize = 11
			keyLbl.TextColor3 = C.Muted
			keyLbl.TextXAlignment = Enum.TextXAlignment.Left
			keyLbl.BackgroundTransparency = 1

			local valLbl = Instance.new("TextLabel", f)
			valLbl.Size = UDim2.new(0.55, -12, 1, 0)
			valLbl.Position = UDim2.new(0.45, 0, 0, 0)
			valLbl.Text = type(valueFunc) == "function" and valueFunc() or tostring(valueFunc)
			valLbl.Font = C.FontMono
			valLbl.TextSize = 11
			valLbl.TextColor3 = C.Accent
			valLbl.TextXAlignment = Enum.TextXAlignment.Right
			valLbl.BackgroundTransparency = 1

			if type(valueFunc) == "function" then
				task.spawn(function()
					while f and f.Parent do
						valLbl.Text = valueFunc()
						task.wait(1)
					end
				end)
			end
		end

		function Elements:AddResultsPanel(height)
			local Outer, OuterStroke = BaseElement(height or 220)
			Outer.BackgroundColor3 = Color3.fromRGB(8, 8, 11)
			OuterStroke.Color = C.Outline
			OuterStroke.Transparency = 0.4
			Outer.ClipsDescendants = true

			local Inner = Instance.new("ScrollingFrame", Outer)
			Inner.Size = UDim2.new(1, -8, 1, -8)
			Inner.Position = UDim2.new(0, 4, 0, 4)
			Inner.BackgroundTransparency = 1
			Inner.BorderSizePixel = 0
			Inner.ScrollBarThickness = 2
			Inner.ScrollBarImageColor3 = C.Accent
			Inner.CanvasSize = UDim2.new(0, 0, 0, 0)

			local InnerLayout = Instance.new("UIListLayout", Inner)
			InnerLayout.Padding = UDim.new(0, 4)
			InnerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				Inner.CanvasSize = UDim2.new(0, 0, 0, InnerLayout.AbsoluteContentSize.Y + 8)
			end)

			local Panel = {}

			function Panel:AddRow(label, status, detail)
				local f = Instance.new("Frame", Inner)
				f.Size = UDim2.new(1, 0, 0, detail and 38 or 24)
				f.BackgroundColor3 = Color3.fromRGB(16, 16, 21)
				f.BorderSizePixel = 0
				Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
				local s = Instance.new("UIStroke", f)
				s.Transparency = 0.7

				local statusColor = C.Muted
				local statusSymbol = "•"
				if status == "pass" then statusColor = C.Good statusSymbol = "✓"
				elseif status == "fail" then statusColor = C.Danger statusSymbol = "✕"
				elseif status == "missing" then statusColor = C.Muted statusSymbol = "–"
				elseif status == "skip" then statusColor = C.Warn statusSymbol = "›"
				end
				s.Color = statusColor

				local Mark = Instance.new("TextLabel", f)
				Mark.Size = UDim2.new(0, 24, 0, 16)
				Mark.Position = UDim2.new(0, 6, 0, 3)
				Mark.Text = statusSymbol
				Mark.Font = C.FontBold
				Mark.TextSize = 12
				Mark.TextColor3 = statusColor
				Mark.BackgroundTransparency = 1

				local NameLbl = Instance.new("TextLabel", f)
				NameLbl.Size = UDim2.new(1, -36, 0, 16)
				NameLbl.Position = UDim2.new(0, 30, 0, 3)
				NameLbl.Text = label
				NameLbl.Font = C.FontMono
				NameLbl.TextSize = 10
				NameLbl.TextColor3 = C.Text
				NameLbl.TextXAlignment = Enum.TextXAlignment.Left
				NameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				NameLbl.BackgroundTransparency = 1

				if detail then
					local DetailLbl = Instance.new("TextLabel", f)
					DetailLbl.Size = UDim2.new(1, -36, 0, 14)
					DetailLbl.Position = UDim2.new(0, 30, 0, 20)
					DetailLbl.Text = detail
					DetailLbl.Font = C.FontMono
					DetailLbl.TextSize = 9
					DetailLbl.TextColor3 = C.Muted
					DetailLbl.TextXAlignment = Enum.TextXAlignment.Left
					DetailLbl.TextTruncate = Enum.TextTruncate.AtEnd
					DetailLbl.BackgroundTransparency = 1
				end

				return f
			end

			function Panel:Clear()
				for _, child in ipairs(Inner:GetChildren()) do
					if child:IsA("Frame") then child:Destroy() end
				end
			end

			return Panel
		end

                -- ==============================================================
                -- CHAT CLIENT (UI + HOOK SİSTEMİ, AI MANTIĞI YOK)
                -- ==============================================================
                function Elements:AddChatClient()
                    ScrollFrame:Destroy()

                    local ChatScroll = Instance.new("ScrollingFrame", Page)
                    ChatScroll.Size = UDim2.new(1, 0, 1, -62)
                    ChatScroll.Position = UDim2.new(0, 0, 0, 0)
                    ChatScroll.BackgroundTransparency = 1
                    ChatScroll.BorderSizePixel = 0
                    ChatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
                    ChatScroll.ScrollBarThickness = 2
                    ChatScroll.ScrollBarImageColor3 = C.Accent

                    local ChatPadding = Instance.new("UIPadding", ChatScroll)
                    ChatPadding.PaddingLeft = UDim.new(0, 6)
                    ChatPadding.PaddingRight = UDim.new(0, 6)
                    ChatPadding.PaddingTop = UDim.new(0, 6)

                    local ChatLayout = Instance.new("UIListLayout", ChatScroll)
                    ChatLayout.Padding = UDim.new(0, 10)
                    ChatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                        ChatScroll.CanvasSize = UDim2.new(0, 0, 0, ChatLayout.AbsoluteContentSize.Y + 16)
                        TweenService:Create(ChatScroll, TweenInfo.new(0.3, Enum.EasingStyle.Quart), { CanvasPosition = Vector2.new(0, ChatLayout.AbsoluteContentSize.Y + 100) }):Play()
                    end)

                    local InputWrap = Instance.new("Frame", Page)
                    InputWrap.Size = UDim2.new(1, 0, 0, 52)
                    InputWrap.Position = UDim2.new(0, 0, 1, -56)
                    InputWrap.BackgroundColor3 = C.Surface
                    InputWrap.BorderSizePixel = 0
                    Instance.new("UICorner", InputWrap).CornerRadius = UDim.new(0, 10)
                    local InputStroke = Instance.new("UIStroke", InputWrap)
                    InputStroke.Color = C.Outline

                    local TextBox = Instance.new("TextBox", InputWrap)
                    TextBox.Size = UDim2.new(1, -54, 1, -12)
                    TextBox.Position = UDim2.new(0, 12, 0, 6)
                    TextBox.BackgroundTransparency = 1
                    TextBox.Font = C.Font
                    TextBox.PlaceholderText = ">> type a message..."
                    TextBox.PlaceholderColor3 = C.Muted
                    TextBox.Text = ""
                    TextBox.TextColor3 = C.Text
                    TextBox.TextSize = Config.ChatTextSize
                    TextBox.TextXAlignment = Enum.TextXAlignment.Left
                    TextBox.ClearTextOnFocus = false

                    local SendBtn = Instance.new("TextButton", InputWrap)
                    SendBtn.Size = UDim2.new(0, 36, 0, 36)
                    SendBtn.Position = UDim2.new(1, -44, 0.5, -18)
                    SendBtn.BackgroundColor3 = C.Accent
                    SendBtn.Text = "↑"
                    SendBtn.Font = C.FontBold
                    SendBtn.TextSize = 18
                    SendBtn.TextColor3 = C.Bg
                    SendBtn.BorderSizePixel = 0
                    Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 8)

                    TextBox.Focused:Connect(function()
                        TweenService:Create(InputStroke, TweenInfo.new(0.15), { Color = C.Accent }):Play()
                    end)
                    TextBox.FocusLost:Connect(function()
                        TweenService:Create(InputStroke, TweenInfo.new(0.15), { Color = C.Outline }):Play()
                    end)

                    -- ==============================================================
                    -- MESAJ OLUŞTURMA (CreateMessage)
                    -- ==============================================================
                    local function CreateMessage(sender, text, instant)
                        local isUser = sender == "User"
                        local maxWidth = math.min(ChatScroll.AbsoluteSize.X * 0.78, 360)
                        local textSize = TextService:GetTextSize(text, Config.ChatTextSize, C.Font, Vector2.new(maxWidth - 28, 9999))
                        local bubbleH = textSize.Y + 22
                        local bubbleW = math.max(math.min(textSize.X + 28, maxWidth), 48)

                        local Row = Instance.new("Frame", ChatScroll)
                        Row:SetAttribute("Sender", sender)
                        Row.Size = UDim2.new(1, 0, 0, bubbleH)
                        Row.BackgroundTransparency = 1

                        local Bubble = Instance.new("Frame", Row)
                        Bubble.Name = "ChatBubble"
                        Bubble.Size = UDim2.new(0, bubbleW, 0, bubbleH)
                        Bubble.BackgroundColor3 = isUser and C.Accent or C.Surface
                        Bubble.BorderSizePixel = 0
                        Bubble.BackgroundTransparency = 1
                        Instance.new("UICorner", Bubble).CornerRadius = UDim.new(0, 10)

                        if not isUser then
                            local bs = Instance.new("UIStroke", Bubble)
                            bs.Color = C.Accent
                            bs.Thickness = 0.8
                            bs.Transparency = 0.6
                        end

                        Bubble.Position = isUser
                            and UDim2.new(1, -bubbleW, 0, 0)
                            or UDim2.new(0, 0, 0, 0)

                        local Lbl = Instance.new("TextLabel", Bubble)
                        Lbl.Size = UDim2.new(1, -24, 1, -12)
                        Lbl.Position = UDim2.new(0, 12, 0, 6)
                        Lbl.BackgroundTransparency = 1
                        Lbl.Font = C.Font
                        Lbl.RichText = true
                        Lbl.TextColor3 = isUser and C.Bg or C.Text
                        Lbl.TextSize = Config.ChatTextSize
                        Lbl.TextWrapped = true
                        Lbl.TextXAlignment = isUser and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
                        Lbl.Text = ""

                        table.insert(WindowEngine.AllLabels, Lbl)

                        local slideStart = isUser
                            and UDim2.new(1, 0, 0, 0)
                            or UDim2.new(0, -30, 0, 0)
                        Bubble.Position = slideStart
                        Bubble.BackgroundTransparency = 1

                        TweenService:Create(Bubble, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Position = isUser and UDim2.new(1, -bubbleW, 0, 0) or UDim2.new(0, 0, 0, 0),
                            BackgroundTransparency = 0,
                        }):Play()

                        if not isUser and Config.TypewriterActive and not instant then
                            task.spawn(function()
                                task.wait(0.1)
                                for i = 1, #text do
                                    Lbl.Text = string.sub(text, 1, i)
                                    task.wait(0.011)
                                end
                            end)
                        else
                            Lbl.Text = text
                            Lbl.TextTransparency = 1
                            TweenService:Create(Lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
                        end
                        return Row
                    end

                    -- ==============================================================
                    -- HOOK SİSTEMİ
                    -- ==============================================================
                    local hooks = {
                        onMessageSend = nil,   -- function(messageFrame, text)
                        onMessageEdit = nil,   -- function(messageFrame, newText, oldText) -> modified newText
                        onMessageDelete = nil, -- function(messageFrame)
                    }

					local validHooks = { onMessageSend = true, onMessageEdit = true, onMessageDelete = true }
					local function AddHook(name, func)
					    if validHooks[name] then
					        hooks[name] = func
					    end
					end

                    -- ==============================================================
                    -- SEND MESSAGE (Kullanıcı mesajını oluşturur ve hook'u çağırır)
                    -- ==============================================================
                    local function SendMessage()
                        local msg = TextBox.Text
                        if msg == "" then return end
                        TextBox.Text = ""

                        local userMsg = CreateMessage("User", msg)

                        if hooks.onMessageSend then
                            task.spawn(function()
                                hooks.onMessageSend(userMsg, msg)
                            end)
                        end

                        return userMsg
                    end

                    SendBtn.MouseButton1Click:Connect(SendMessage)
                    TextBox.FocusLost:Connect(function(enter) if enter then SendMessage() end end)

                    -- ==============================================================
                    -- CHAT API
                    -- ==============================================================
                    local chatApi = {}
                    chatApi.SendMessage = function(sender, text, instant)
                        if sender == "AI" then
                            return CreateMessage("AI", tostring(text), instant)
                        else
                            return CreateMessage("User", tostring(text), instant)
                        end
                    end
                    chatApi.EditMessage = function(msgFrame, newText, instant)
                        local maxWidth = math.min(ChatScroll.AbsoluteSize.X * 0.78, 360)
                        local textSize = TextService:GetTextSize(newText, Config.ChatTextSize, C.Font, Vector2.new(maxWidth - 28, 9999))
                        local bubbleH = textSize.Y + 22
                        local bubbleW = math.max(math.min(textSize.X + 28, maxWidth), 48)

                        msgFrame.Size = UDim2.new(1, 0, 0, bubbleH)

                        local Bubble = msgFrame:FindFirstChild("ChatBubble")
                        if not Bubble then return end
                        Bubble.Size = UDim2.new(0, bubbleW, 0, bubbleH)
                        local Lbl = Bubble:FindFirstChildOfClass("TextLabel")
                        if not Lbl then return end
                        local isUser = msgFrame:GetAttribute("Sender") == "User"

                        -- Hook: onMessageEdit
                        if hooks.onMessageEdit then
                            local oldText = Lbl.Text
                            local modified = hooks.onMessageEdit(msgFrame, newText, oldText)
                            if modified then newText = modified end
                        end

                        local slideStart = isUser
                            and UDim2.new(1, 0, 0, 0)
                            or UDim2.new(0, -30, 0, 0)
                        Bubble.Position = slideStart
                        Bubble.BackgroundTransparency = 1

                        TweenService:Create(Bubble, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Position = isUser and UDim2.new(1, -bubbleW, 0, 0) or UDim2.new(0, 0, 0, 0),
                            BackgroundTransparency = 0,
                        }):Play()

                        if not isUser and Config.TypewriterActive and not instant then
                            task.spawn(function()
                                task.wait(0.1)
                                for i = 1, #newText do
                                    Lbl.Text = string.sub(newText, 1, i)
                                    task.wait(0.011)
                                end
                            end)
                        else
                            Lbl.Text = newText
                            Lbl.TextTransparency = 1
                            TweenService:Create(Lbl, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
                        end
                    end
                    chatApi.DeleteMessage = function(msgFrame)
                        if hooks.onMessageDelete then
                            hooks.onMessageDelete(msgFrame)
                        end

                        local isUser = msgFrame:GetAttribute("Sender") == "User"
                        local Bubble = msgFrame:FindFirstChild("ChatBubble")
                        if not Bubble then return end

                        local targetPos = isUser and UDim2.fromScale(1.5,0) or UDim2.fromScale(-1.5,0)
                        local tween = TweenService:Create(Bubble, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                            Position = Bubble.Position + targetPos,
                            BackgroundTransparency = 1,
                        })
                        tween:Play()
                        tween.Completed:Once(function()
                            msgFrame:Destroy()
                        end)
                    end
                    chatApi.AddHook = AddHook

                    -- Varsayılan hoşgeldin mesajları
                    CreateMessage("AI", [[System online. Chamber Protocol v2.0 — all modules stabilized.]])
                    CreateMessage("AI", [[<b><font color="#]].. C.Accent:ToHex() ..[[">Ready for custom AI integration via hooks.</font></b>]])

                    return chatApi
                end

		function Elements:AddScriptEditor(filename)
			ScrollFrame:Destroy()

			local rawContent = ""
			if readfile then
				local ok, data = pcall(readfile, filename)
				if ok then rawContent = data end
			end

			local LUA_KEYWORDS = {
				["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
				["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,
				["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,
				["repeat"]=true,["return"]=true,["then"]=true,["true"]=true,["until"]=true,
				["while"]=true,["self"]=true,
			}
			local LUA_BUILTINS = {
				["print"]=true,["warn"]=true,["error"]=true,["assert"]=true,["pcall"]=true,
				["xpcall"]=true,["pairs"]=true,["ipairs"]=true,["next"]=true,["select"]=true,
				["type"]=true,["typeof"]=true,["tostring"]=true,["tonumber"]=true,
				["rawget"]=true,["rawset"]=true,["setmetatable"]=true,["getmetatable"]=true,
				["require"]=true,["loadstring"]=true,["unpack"]=true,["table"]=true,
				["string"]=true,["math"]=true,["os"]=true,["task"]=true,
				["game"]=true,["workspace"]=true,["script"]=true,["Instance"]=true,
				["Vector3"]=true,["Vector2"]=true,["CFrame"]=true,["Color3"]=true,
				["UDim2"]=true,["UDim"]=true,["Enum"]=true,["TweenInfo"]=true,
			}

			local LUA_SUGGESTIONS = {}
			do
				local seen = {}
				for k in pairs(LUA_KEYWORDS) do
					if not seen[k] then seen[k] = true table.insert(LUA_SUGGESTIONS, k) end
				end
				for k in pairs(LUA_BUILTINS) do
					if not seen[k] then seen[k] = true table.insert(LUA_SUGGESTIONS, k) end
				end
				table.sort(LUA_SUGGESTIONS)
			end

			local function Esc(s)
				return (s:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
			end

			local function TokenizeLine(line)
				local out = ""
				local i = 1
				local len = #line
				while i <= len do
					local ch = line:sub(i,i)
					if line:sub(i,i+1) == "--" then
						out = out..'<font color="rgb(106,153,85)">'..Esc(line:sub(i)).."</font>"
						break
					elseif ch == '"' or ch == "'" then
						local delim = ch
						local j = i+1
						while j <= len do
							local c = line:sub(j,j)
							if c == "\\" then j=j+2
							elseif c == delim then j=j+1; break
							else j=j+1 end
						end
						out = out..'<font color="rgb(206,145,120)">'..Esc(line:sub(i,j-1)).."</font>"
						i = j
					elseif ch:match("%d") or (ch=="." and line:sub(i+1,i+1):match("%d")) then
						local j=i
						while j<=len and line:sub(j,j):match("[%d%.xXa-fA-F]") do j=j+1 end
						out = out..'<font color="rgb(181,206,168)">'..Esc(line:sub(i,j-1)).."</font>"
						i=j
					elseif ch:match("[%a_]") then
						local j=i
						while j<=len and line:sub(j,j):match("[%w_]") do j=j+1 end
						local word=line:sub(i,j-1)
						if LUA_KEYWORDS[word] then
							out=out..'<font color="rgb(197,134,192)">'..word.."</font>"
						elseif LUA_BUILTINS[word] then
							out=out..'<font color="rgb(78,201,176)">'..word.."</font>"
						else
							out=out..'<font color="rgb(212,212,212)">'..Esc(word).."</font>"
						end
						i=j
					elseif ch:match("[%+%-%*/%%^#&|~<>=%(%)%[%]{}%.,:;]") then
						out=out..'<font color="rgb(212,175,55)">'..Esc(ch).."</font>"
						i=i+1
					else
						out=out..Esc(ch)
						i=i+1
					end
				end
				return out
			end

			local LINE_H = 18

			local EditorHeader = Instance.new("Frame", Page)
			EditorHeader.Size = UDim2.new(1, 0, 0, 36)
			EditorHeader.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
			EditorHeader.BorderSizePixel = 0
			EditorHeader.ZIndex = 5
			Instance.new("UICorner", EditorHeader).CornerRadius = UDim.new(0, 8)

			local FileLabel = Instance.new("TextLabel", EditorHeader)
			FileLabel.Size = UDim2.new(1, -200, 1, 0)
			FileLabel.Position = UDim2.new(0, 10, 0, 0)
			FileLabel.Text = "📄 "..tostring(filename)
			FileLabel.Font = C.FontMono
			FileLabel.TextSize = 11
			FileLabel.TextColor3 = C.Accent
			FileLabel.TextXAlignment = Enum.TextXAlignment.Left
			FileLabel.BackgroundTransparency = 1
			FileLabel.ZIndex = 6

			local function MakeEditorBtn(ox, label, col)
				local b = Instance.new("TextButton", EditorHeader)
				b.Size = UDim2.new(0, 58, 0, 24)
				b.Position = UDim2.new(1, ox, 0.5, -12)
				b.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
				b.Text = label
				b.Font = C.FontBold
				b.TextSize = 10
				b.TextColor3 = col
				b.BorderSizePixel = 0
				b.ZIndex = 6
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
				local s = Instance.new("UIStroke", b); s.Color = col; s.Transparency = 0.5
				b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3=col, TextColor3=C.Bg}):Play() end)
				b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(28,28,35), TextColor3=col}):Play() end)
				return b
			end

			local RunBtn  = MakeEditorBtn(-190, "▶ Run",  C.Good)
			local SaveBtn = MakeEditorBtn(-126, "💾 Save", C.Accent)
			local NewBtn  = MakeEditorBtn(-62,  "+ New",  C.Muted)

			local EditorBody = Instance.new("Frame", Page)
			EditorBody.Size = UDim2.new(1, 0, 1, -90)
			EditorBody.Position = UDim2.new(0, 0, 0, 40)
			EditorBody.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			EditorBody.BorderSizePixel = 0
			Instance.new("UICorner", EditorBody).CornerRadius = UDim.new(0, 8)
			local EditorStroke = Instance.new("UIStroke", EditorBody)
			EditorStroke.Color = C.Outline

			local LineNumPanel = Instance.new("Frame", EditorBody)
			LineNumPanel.Size = UDim2.new(0, 40, 1, 0)
			LineNumPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
			LineNumPanel.BorderSizePixel = 0
			Instance.new("UICorner", LineNumPanel).CornerRadius = UDim.new(0, 8)

			local LineNumScroll = Instance.new("ScrollingFrame", LineNumPanel)
			LineNumScroll.Size = UDim2.new(1, 0, 1, -6)
			LineNumScroll.Position = UDim2.new(0, 0, 0, 6)
			LineNumScroll.BackgroundTransparency = 1
			LineNumScroll.BorderSizePixel = 0
			LineNumScroll.ScrollBarThickness = 0
			LineNumScroll.ScrollingEnabled = false
			LineNumScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			local LNLayout = Instance.new("UIListLayout", LineNumScroll)
			LNLayout.Padding = UDim.new(0, 0)
			LNLayout.SortOrder = Enum.SortOrder.LayoutOrder

			local HighlightScroll = Instance.new("ScrollingFrame", EditorBody)
			HighlightScroll.Size = UDim2.new(1, -40, 1, -6)
			HighlightScroll.Position = UDim2.new(0, 40, 0, 6)
			HighlightScroll.BackgroundTransparency = 1
			HighlightScroll.BorderSizePixel = 0
			HighlightScroll.ScrollBarThickness = 0
			HighlightScroll.ScrollingEnabled = false
			HighlightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			local HLLayout = Instance.new("UIListLayout", HighlightScroll)
			HLLayout.Padding = UDim.new(0, 0)
			HLLayout.SortOrder = Enum.SortOrder.LayoutOrder
			local HLPad = Instance.new("UIPadding", HighlightScroll)
			HLPad.PaddingLeft = UDim.new(0, 6)

			local EditScroll = Instance.new("ScrollingFrame", EditorBody)
			EditScroll.Size = UDim2.new(1, -40, 1, -6)
			EditScroll.Position = UDim2.new(0, 40, 0, 6)
			EditScroll.BackgroundTransparency = 1
			EditScroll.BorderSizePixel = 0
			EditScroll.ScrollBarThickness = 5
			EditScroll.ScrollBarImageColor3 = C.Accent
			EditScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			EditScroll.ZIndex = 3

			local EditBox = Instance.new("TextBox", EditScroll)
			EditBox.Size = UDim2.new(1, -12, 0, 400)
			EditBox.Position = UDim2.new(0, 6, 0, 0)
			EditBox.BackgroundTransparency = 1
			EditBox.Font = C.FontMono
			EditBox.TextSize = 13
			EditBox.TextColor3 = Color3.new(0,0,0)
			EditBox.TextTransparency = 0.999
			EditBox.Text = rawContent
			EditBox.TextXAlignment = Enum.TextXAlignment.Left
			EditBox.TextYAlignment = Enum.TextYAlignment.Top
			EditBox.MultiLine = true
			EditBox.ClearTextOnFocus = false
			EditBox.BorderSizePixel = 0
			EditBox.ZIndex = 4
			EditBox.RichText = false

			local SuggestionBar = Instance.new("ScrollingFrame", Page)
			SuggestionBar.Size = UDim2.new(1, 0, 0, 26)
			SuggestionBar.Position = UDim2.new(0, 0, 1, -50)
			SuggestionBar.BackgroundColor3 = Color3.fromRGB(16, 16, 21)
			SuggestionBar.BorderSizePixel = 0
			SuggestionBar.ScrollBarThickness = 0
			SuggestionBar.ScrollingDirection = Enum.ScrollingDirection.X
			SuggestionBar.CanvasSize = UDim2.new(0, 0, 0, 0)
			SuggestionBar.Visible = false
			Instance.new("UICorner", SuggestionBar).CornerRadius = UDim.new(0, 5)
			local SuggestionLayout = Instance.new("UIListLayout", SuggestionBar)
			SuggestionLayout.FillDirection = Enum.FillDirection.Horizontal
			SuggestionLayout.Padding = UDim.new(0, 4)
			SuggestionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			local SuggestionPad = Instance.new("UIPadding", SuggestionBar)
			SuggestionPad.PaddingLeft = UDim.new(0, 4)
			SuggestionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				SuggestionBar.CanvasSize = UDim2.new(0, SuggestionLayout.AbsoluteContentSize.X + 8, 0, 0)
			end)

			local hlLabels = {}
			local lnLabels = {}
			local prevLines = {}

			local function EnsureLineLabel(i)
				if not lnLabels[i] then
					local nf = Instance.new("TextLabel", LineNumScroll)
					nf.Size = UDim2.new(1, -4, 0, LINE_H)
					nf.BackgroundTransparency = 1
					nf.Font = C.FontMono
					nf.TextSize = 11
					nf.TextColor3 = Color3.fromRGB(70, 70, 85)
					nf.TextXAlignment = Enum.TextXAlignment.Right
					nf.LayoutOrder = i
					nf.ZIndex = 2
					lnLabels[i] = nf
				end
				if not hlLabels[i] then
					local hf = Instance.new("TextLabel", HighlightScroll)
					hf.Size = UDim2.new(1, 0, 0, LINE_H)
					hf.Font = C.FontMono
					hf.TextSize = 13
					hf.RichText = true
					hf.TextColor3 = Color3.fromRGB(212, 212, 212)
					hf.TextXAlignment = Enum.TextXAlignment.Left
					hf.TextYAlignment = Enum.TextYAlignment.Center
					hf.LayoutOrder = i
					hf.ZIndex = 2
					hlLabels[i] = hf
				end
			end

			local function RebuildLines(text)
				local lines = {}
				for ln in (text.."\n"):gmatch("([^\n]*)\n") do
					table.insert(lines, ln)
				end
				if #lines == 0 then lines = {""} end

				for i, ln in ipairs(lines) do
					EnsureLineLabel(i)
					if prevLines[i] ~= ln then
						lnLabels[i].Text = tostring(i)
						hlLabels[i].Text = TokenizeLine(ln)
						hlLabels[i].BackgroundColor3 = Color3.fromRGB(22, 22, 28)
						hlLabels[i].BackgroundTransparency = i % 2 == 0 and 0.6 or 1
					end
				end

				for i = #lines + 1, #lnLabels do
					if lnLabels[i] then lnLabels[i]:Destroy() lnLabels[i] = nil end
					if hlLabels[i] then hlLabels[i]:Destroy() hlLabels[i] = nil end
				end

				prevLines = lines

				local h = #lines * LINE_H + 12
				LineNumScroll.CanvasSize = UDim2.new(0, 0, 0, h)
				HighlightScroll.CanvasSize = UDim2.new(0, 0, 0, h)
				EditScroll.CanvasSize = UDim2.new(0, 0, 0, h)
				EditBox.Size = UDim2.new(1, -12, 0, math.max(h, 400))
			end

			RebuildLines(rawContent)

			EditScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
				local y = EditScroll.CanvasPosition.Y
				HighlightScroll.CanvasPosition = Vector2.new(0, y)
				LineNumScroll.CanvasPosition = Vector2.new(0, y)
			end)

			local function GetCurrentWordFragment()
				local pos = EditBox.CursorPosition
				if pos == nil or pos < 1 then return nil end
				local sub = rawContent:sub(1, pos - 1)
				return sub:match("[%a_][%w_]*$")
			end

			local function InsertSuggestion(word, name)
				local pos = EditBox.CursorPosition
				if pos == nil or pos < 1 then return end
				local before = rawContent:sub(1, pos - 1 - #word)
				local after = rawContent:sub(pos)
				local newText = before..name..after
				EditBox.Text = newText
				EditBox.CursorPosition = #before + #name + 1
				SuggestionBar.Visible = false
			end

			local function UpdateSuggestions()
				for _, b in ipairs(SuggestionBar:GetChildren()) do
					if b:IsA("TextButton") then b:Destroy() end
				end
				local word = GetCurrentWordFragment()
				if not word or #word < 2 then
					SuggestionBar.Visible = false
					return
				end
				local lowerWord = word:lower()
				local shown = 0
				for _, name in ipairs(LUA_SUGGESTIONS) do
					if shown >= 8 then break end
					if name:sub(1, #word):lower() == lowerWord and name:lower() ~= lowerWord then
						local b = Instance.new("TextButton", SuggestionBar)
						b.Size = UDim2.new(0, TextService:GetTextSize(name, 11, C.FontMono, Vector2.new(200, 20)).X + 16, 1, 0)
						b.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
						b.Text = name
						b.Font = C.FontMono
						b.TextSize = 11
						b.TextColor3 = C.Accent
						b.BorderSizePixel = 0
						b.LayoutOrder = shown
						Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
						b.MouseButton1Click:Connect(function()
							InsertSuggestion(word, name)
						end)
						shown = shown + 1
					end
				end
				SuggestionBar.Visible = shown > 0
			end

			local debounce
			EditBox:GetPropertyChangedSignal("Text"):Connect(function()
				rawContent = EditBox.Text
				UpdateSuggestions()
				if debounce then task.cancel(debounce) end
				debounce = task.delay(0.05, function()
					RebuildLines(rawContent)
				end)
			end)

			EditBox:GetPropertyChangedSignal("CursorPosition"):Connect(UpdateSuggestions)

			local StatusBar = Instance.new("Frame", Page)
			StatusBar.Size = UDim2.new(1, 0, 0, 20)
			StatusBar.Position = UDim2.new(0, 0, 1, -20)
			StatusBar.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
			StatusBar.BorderSizePixel = 0
			Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 5)

			local StatusLbl = Instance.new("TextLabel", StatusBar)
			StatusLbl.Size = UDim2.new(1, -8, 1, 0)
			StatusLbl.Position = UDim2.new(0, 8, 0, 0)
			StatusLbl.Font = C.FontMono
			StatusLbl.TextSize = 10
			StatusLbl.TextColor3 = C.Muted
			StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
			StatusLbl.BackgroundTransparency = 1
			StatusLbl.Text = "Lua  |  "..tostring(filename).."  |  Ready"

			local function SetStatus(msg, col)
				StatusLbl.Text = "Lua  |  "..tostring(filename).."  |  "..msg
				StatusLbl.TextColor3 = col or C.Muted
			end

			RunBtn.MouseButton1Click:Connect(function()
				local fn, err = loadstring(rawContent)
				if fn then
					SetStatus("Running...", C.Good)
					task.spawn(function()
						local ok, runerr = pcall(fn)
						task.wait()
						if ok then
							SetStatus("Ran successfully ✓", C.Good)
						else
							SetStatus("Error: "..tostring(runerr):sub(1,100), C.Danger)
						end
					end)
				else
					SetStatus("Syntax error: "..tostring(err):sub(1,100), C.Danger)
				end
			end)

			SaveBtn.MouseButton1Click:Connect(function()
				if writefile then
					local ok, err = pcall(writefile, filename, rawContent)
					if ok then
						SetStatus("Saved ✓", C.Good)
						task.delay(2, function() SetStatus("Ready") end)
					else
						SetStatus("Save failed: "..tostring(err), C.Danger)
					end
				else
					SetStatus("writefile not available", C.Warn)
				end
			end)

			NewBtn.MouseButton1Click:Connect(function()
				EditBox.Text = ""
				SetStatus("New file — save to write to disk", C.Warn)
			end)
		end

		return Elements
	end

	return WindowEngine
end

return EliteLib
