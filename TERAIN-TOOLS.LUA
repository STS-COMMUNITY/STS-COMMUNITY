--========================================================--
-- MAULZZ×BRYAN TERRAIN TOOLS V2
-- PREMIUM MOBILE UI / CLEAN FEATURE TEXT
--========================================================--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local terrain = Workspace.Terrain

--========================================================--
-- CONFIG
--========================================================--

local BACKGROUND_ID = "rbxassetid://78851330031113"

local brushOn = false
local shape = "Box"
local materialName = "Grass"
local terrainMode = "Add"

local brushSize = 16
local brushHeight = 8

local painting = false
local lastPaint = 0

local draggingPanel = false
local panelDragStart
local panelStartPosition

local draggingLogo = false
local logoDragStart
local logoStartPosition
local logoMoved = false

local pointerPosition = Vector2.new(0, 0)

local shapes = {
	"Box",
	"Sphere",
	"Cylinder",
	"Wedge"
}

local materials = {
	"Grass",
	"LeafyGrass",
	"Ground",
	"Mud",
	"Sand",
	"Rock",
	"Snow",
	"Ice",
	"Slate",
	"Basalt",
	"CrackedLava",
	"Limestone",
	"Sandstone",
	"Salt",
	"Pavement",
	"Concrete",
	"Brick",
	"Cobblestone",
	"WoodPlanks",
	"Wood",
	"Glacier",
	"Asphalt"
}

--========================================================--
-- COLORS
--========================================================--

local BG = Color3.fromRGB(6, 6, 9)
local PANEL = Color3.fromRGB(12, 12, 16)
local BUTTON = Color3.fromRGB(25, 25, 31)
local SELECTED = Color3.fromRGB(78, 78, 89)

local TEXT = Color3.fromRGB(238, 238, 243)
local MUTED = Color3.fromRGB(145, 145, 157)

local GREEN = Color3.fromRGB(90, 235, 125)
local RED = Color3.fromRGB(255, 95, 95)

local BORDER = Color3.fromRGB(62, 62, 72)

--========================================================--
-- GUI
--========================================================--

local gui = Instance.new("ScreenGui")
gui.Name = "MaulzzBryanTerrainTools"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

--========================================================--
-- HELPERS
--========================================================--

local function addCorner(object, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
	return c
end

local function addStroke(object, color, transparency, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency or 0
	s.Thickness = thickness or 1
	s.Parent = object
	return s
end

local function createLabel(parent, text, size, color, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = color or TEXT
	l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	l.TextSize = size or 12
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = false
	l.ClipsDescendants = true
	l.Size = UDim2.new(1, 0, 0, 20)
	l.Parent = parent
	return l
end

local function createButton(parent, text)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = BUTTON
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = TEXT
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 11
	b.TextWrapped = false
	b.ClipsDescendants = true
	b.Parent = parent
	addCorner(b, 10)
	addStroke(b, BORDER, 0.4, 1)
	return b
end

--========================================================--
-- MAIN PANEL
--========================================================--

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.70, 0.50)
main.Size = UDim2.fromOffset(380, 540)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui

addCorner(main, 22)
addStroke(main, Color3.fromRGB(70, 70, 80), 0.15, 1)

--========================================================--
-- RESPONSIVE SCALE
--========================================================--

local uiScale = Instance.new("UIScale")
uiScale.Parent = main

local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize

	local factor = math.min(
		viewport.X / 1250,
		viewport.Y / 800
	)

	factor = math.max(
		0.72,
		math.min(0.86, factor)
	)

	uiScale.Scale = factor
end

updateScale()

if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

--========================================================--
-- BACKGROUND
--========================================================--

local background = Instance.new("ImageLabel")
background.Name = "PanelBackground"
background.BackgroundColor3 = BG
background.BackgroundTransparency = 0
background.Image = BACKGROUND_ID
background.ImageTransparency = 0.28
background.ScaleType = Enum.ScaleType.Crop
background.Size = UDim2.fromScale(1, 1)
background.Position = UDim2.fromScale(0, 0)
background.ZIndex = 1
background.Parent = main

addCorner(background, 22)

--========================================================--
-- DARK OVERLAY
--========================================================--

local overlay = Instance.new("Frame")
overlay.Name = "DarkOverlay"
overlay.BackgroundColor3 = Color3.fromRGB(3, 3, 6)
overlay.BackgroundTransparency = 0.40
overlay.BorderSizePixel = 0
overlay.Size = UDim2.fromScale(1, 1)
overlay.Position = UDim2.fromScale(0, 0)
overlay.ZIndex = 2
overlay.Parent = main

addCorner(overlay, 22)

--========================================================--
-- HEADER
--========================================================--

local header = Instance.new("Frame")
header.BackgroundTransparency = 1
header.Size = UDim2.new(1, 0, 0, 62)
header.ZIndex = 10
header.Parent = main

local headerLogo = Instance.new("ImageLabel")
headerLogo.BackgroundTransparency = 1
headerLogo.Image = BACKGROUND_ID
headerLogo.ImageTransparency = 0
headerLogo.Size = UDim2.fromOffset(32, 32)
headerLogo.Position = UDim2.fromOffset(10, 8)
headerLogo.ScaleType = Enum.ScaleType.Fit
headerLogo.ZIndex = 11
headerLogo.Parent = header
addCorner(headerLogo, 10)

local title = createLabel(
	header,
	"MAULZZ×BRYAN TERRAIN",
	13,
	TEXT,
	true
)
title.Position = UDim2.fromOffset(48, 5)
title.Size = UDim2.fromOffset(180, 21)
title.ZIndex = 11

local subtitle = createLabel(
	header,
	"PREMIUM TERRAIN SUITE  •  V2.0",
	8,
	MUTED,
	false
)
subtitle.Position = UDim2.fromOffset(48, 27)
subtitle.Size = UDim2.fromOffset(200, 17)
subtitle.ZIndex = 11

local fps = createLabel(header, "FPS: --", 9, GREEN, true)
fps.TextXAlignment = Enum.TextXAlignment.Right
fps.Position = UDim2.new(1, -105, 0, 7)
fps.Size = UDim2.fromOffset(62, 16)
fps.ZIndex = 11

local ping = createLabel(header, "PING: --", 9, GREEN, true)
ping.TextXAlignment = Enum.TextXAlignment.Right
ping.Position = UDim2.new(1, -105, 0, 26)
ping.Size = UDim2.fromOffset(62, 16)
ping.ZIndex = 11

local closeButton = createButton(header, "×")
closeButton.Position = UDim2.new(1, -38, 0, 8)
closeButton.Size = UDim2.fromOffset(28, 28)
closeButton.TextSize = 17
closeButton.ZIndex = 12

closeButton.MouseButton1Click:Connect(function()
	main.Visible = false
	painting = false
end)

local headerLine = Instance.new("Frame")
headerLine.BackgroundColor3 = BORDER
headerLine.BackgroundTransparency = 0.2
headerLine.BorderSizePixel = 0
headerLine.Position = UDim2.new(0, 12, 1, -1)
headerLine.Size = UDim2.new(1, -24, 0, 1)
headerLine.ZIndex = 11
headerLine.Parent = header

--========================================================--
-- PANEL DRAG
--========================================================--

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		draggingPanel = true
		panelDragStart = input.Position
		panelStartPosition = main.Position
	end
end)

header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		draggingPanel = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not draggingPanel then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - panelDragStart

	main.Position = UDim2.new(
		panelStartPosition.X.Scale,
		panelStartPosition.X.Offset + delta.X,
		panelStartPosition.Y.Scale,
		panelStartPosition.Y.Offset + delta.Y
	)
end)

--========================================================--
-- SCROLL CONTENT
--========================================================--

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Content"
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Position = UDim2.fromOffset(10, 68)
scroll.Size = UDim2.new(1, -20, 1, -76)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(120, 120, 130)
scroll.ScrollBarImageTransparency = 0.35
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ZIndex = 5
scroll.Parent = main

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 7)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = scroll

--========================================================--
-- SECTION CREATOR
--========================================================--

local function createSection(titleText)
	local section = Instance.new("Frame")
	section.BackgroundColor3 = PANEL
	section.BackgroundTransparency = 0.15
	section.BorderSizePixel = 0
	section.Size = UDim2.new(1, -2, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.ZIndex = 6
	section.Parent = scroll

	addCorner(section, 15)
	addStroke(section, BORDER, 0.45, 1)

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 9)
	padding.PaddingLeft = UDim.new(0, 9)
	padding.PaddingRight = UDim.new(0, 9)
	padding.Parent = section

	-- FIX: section title and content now have their own vertical layout.
	-- This prevents the MATERIAL title from overlapping SELECTED / SEARCH.
	local sectionLayout = Instance.new("UIListLayout")
	sectionLayout.FillDirection = Enum.FillDirection.Vertical
	sectionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	sectionLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionLayout.Padding = UDim.new(0, 5)
	sectionLayout.Parent = section

	local titleLabel = createLabel(
		section,
		titleText,
		11,
		TEXT,
		true
	)
	titleLabel.LayoutOrder = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.ZIndex = 8

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.LayoutOrder = 2
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.ZIndex = 7
	content.Parent = section

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Vertical
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 6)
	contentLayout.Parent = content

	return section, content
end

--========================================================--
-- BRUSH
--========================================================--

local brushSection, brushContent = createSection("BRUSH")

local brushRow = Instance.new("Frame")
brushRow.BackgroundTransparency = 1
brushRow.Size = UDim2.new(1, 0, 0, 42)
brushRow.LayoutOrder = 1
brushRow.ZIndex = 8
brushRow.Parent = brushContent

local brushState = createLabel(brushRow, "OFF", 10, RED, true)
brushState.Position = UDim2.fromOffset(0, 11)
brushState.Size = UDim2.fromOffset(70, 18)

local toggle = createButton(brushRow, "")
toggle.Position = UDim2.new(1, -78, 0, 2)
toggle.Size = UDim2.fromOffset(76, 38)

local knob = Instance.new("Frame")
knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
knob.BorderSizePixel = 0
knob.Size = UDim2.fromOffset(27, 27)
knob.Position = UDim2.fromOffset(6, 5)
knob.ZIndex = 10
knob.Parent = toggle
addCorner(knob, 20)

toggle.MouseButton1Click:Connect(function()
	brushOn = not brushOn

	if brushOn then
		brushState.Text = "ON"
		brushState.TextColor3 = GREEN
		toggle.BackgroundColor3 = SELECTED
		knob.Position = UDim2.new(1, -33, 0, 5)
	else
		brushState.Text = "OFF"
		brushState.TextColor3 = RED
		toggle.BackgroundColor3 = BUTTON
		knob.Position = UDim2.fromOffset(6, 5)
	end
end)

--========================================================--
-- SHAPE
--========================================================--

local shapeSection, shapeContent = createSection("SHAPE")

local shapeGrid = Instance.new("UIGridLayout")
shapeGrid.CellPadding = UDim2.fromOffset(5, 5)
shapeGrid.CellSize = UDim2.new(0.5, -3, 0, 38)
shapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
shapeGrid.Parent = shapeContent

local shapeButtons = {}

local shapeIcons = {
	Box = "□  BOX",
	Sphere = "○  SPHERE",
	Cylinder = "▣  CYLINDER",
	Wedge = "◢  WEDGE"
}

for _, shapeName in ipairs(shapes) do
	local button = createButton(
		shapeContent,
		shapeIcons[shapeName] or shapeName
	)

	button.LayoutOrder = table.find(shapes, shapeName) or 1
	shapeButtons[shapeName] = button

	button.MouseButton1Click:Connect(function()
		shape = shapeName

		for name, otherButton in pairs(shapeButtons) do
			if name == shape then
				otherButton.BackgroundColor3 = SELECTED
			else
				otherButton.BackgroundColor3 = BUTTON
			end
		end
	end)
end

shapeButtons.Box.BackgroundColor3 = SELECTED

--========================================================--
-- TERRAIN MODE
--========================================================--

local modeSection, modeContent = createSection("TERRAIN MODE")

local modeRow = Instance.new("Frame")
modeRow.BackgroundTransparency = 1
modeRow.Size = UDim2.new(1, 0, 0, 42)
modeRow.LayoutOrder = 1
modeRow.ZIndex = 8
modeRow.Parent = modeContent

local addButton = createButton(modeRow, "＋  ADD TERRAIN")
addButton.Position = UDim2.fromOffset(0, 0)
addButton.Size = UDim2.new(0.5, -3, 1, 0)
addButton.BackgroundColor3 = SELECTED

local eraseButton = createButton(modeRow, "×  ERASE")
eraseButton.Position = UDim2.new(0.5, 3, 0, 0)
eraseButton.Size = UDim2.new(0.5, -3, 1, 0)

addButton.MouseButton1Click:Connect(function()
	terrainMode = "Add"
	addButton.BackgroundColor3 = SELECTED
	eraseButton.BackgroundColor3 = BUTTON
end)

eraseButton.MouseButton1Click:Connect(function()
	terrainMode = "Erase"
	eraseButton.BackgroundColor3 = SELECTED
	addButton.BackgroundColor3 = BUTTON
end)

--========================================================--
-- BRUSH SETTINGS
--========================================================--

local sizeSection, sizeContent = createSection("BRUSH SETTINGS")

local function createNumberControl(
	parent,
	labelText,
	value,
	minValue,
	maxValue,
	step,
	callback
)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 42)
	row.Parent = parent

	local labelTextObject = createLabel(
		row,
		labelText,
		10,
		MUTED,
		true
	)

	labelTextObject.Position = UDim2.fromOffset(0, 0)
	labelTextObject.Size = UDim2.new(0.50, 0, 1, 0)

	local minus = createButton(row, "−")
	minus.Position = UDim2.new(1, -112, 0, 2)
	minus.Size = UDim2.fromOffset(34, 34)

	local valueLabel = createLabel(
		row,
		tostring(value),
		11,
		TEXT,
		true
	)

	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.Position = UDim2.new(1, -73, 0, 2)
	valueLabel.Size = UDim2.fromOffset(35, 34)

	local plus = createButton(row, "+")
	plus.Position = UDim2.new(1, -35, 0, 2)
	plus.Size = UDim2.fromOffset(34, 34)

	local current = value

	local function setValue(newValue)
		newValue = math.floor(newValue)

		if newValue < minValue then
			newValue = minValue
		end

		if newValue > maxValue then
			newValue = maxValue
		end

		current = newValue
		valueLabel.Text = tostring(current)
		callback(current)
	end

	minus.MouseButton1Click:Connect(function()
		setValue(current - step)
	end)

	plus.MouseButton1Click:Connect(function()
		setValue(current + step)
	end)
end

createNumberControl(
	sizeContent,
	"SIZE",
	16,
	4,
	64,
	4,
	function(value)
		brushSize = value
	end
)

createNumberControl(
	sizeContent,
	"HEIGHT / DEPTH",
	8,
	4,
	64,
	4,
	function(value)
		brushHeight = value
	end
)

--========================================================--
-- MATERIAL
--========================================================--

local materialSection, materialContent = createSection("MATERIAL")

local selectedLabel = createLabel(
	materialContent,
	"SELECTED MATERIAL: GRASS",
	10,
	GREEN,
	true
)

selectedLabel.LayoutOrder = 1
selectedLabel.Size = UDim2.new(1, 0, 0, 20)

local search = Instance.new("TextBox")
search.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
search.BackgroundTransparency = 0.15
search.BorderSizePixel = 0
search.PlaceholderText = "Search material..."
search.PlaceholderColor3 = MUTED
search.Text = ""
search.TextColor3 = TEXT
search.Font = Enum.Font.Gotham
search.TextSize = 10
search.ClearTextOnFocus = false
search.TextXAlignment = Enum.TextXAlignment.Left
search.Size = UDim2.new(1, 0, 0, 34)
search.LayoutOrder = 2
search.Parent = materialContent

addCorner(search, 10)
addStroke(search, BORDER, 0.55, 1)

local materialScroll = Instance.new("ScrollingFrame")
materialScroll.BackgroundTransparency = 1
materialScroll.BorderSizePixel = 0
materialScroll.Size = UDim2.new(1, 0, 0, 170)
materialScroll.LayoutOrder = 3
materialScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
materialScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
materialScroll.ScrollBarThickness = 3
materialScroll.ScrollBarImageTransparency = 0.3
materialScroll.Parent = materialContent

local materialGrid = Instance.new("UIGridLayout")
materialGrid.CellPadding = UDim2.fromOffset(5, 5)
materialGrid.CellSize = UDim2.new(0.5, -3, 0, 34)
materialGrid.SortOrder = Enum.SortOrder.LayoutOrder
materialGrid.Parent = materialScroll

local materialButtons = {}

local function rebuildMaterials()
	for _, child in ipairs(materialScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	materialButtons = {}

	local query = string.lower(search.Text or "")

	for _, name in ipairs(materials) do
		local lowerName = string.lower(name)

		if query == ""
			or string.find(lowerName, query, 1, true) then

			local materialEnum = Enum.Material[name]

			if materialEnum then
				local button = createButton(
					materialScroll,
					"•  " .. name
				)

				button.TextSize = 10
				materialButtons[name] = button

				if name == materialName then
					button.BackgroundColor3 = SELECTED
				end

				button.MouseButton1Click:Connect(function()
					materialName = name

					selectedLabel.Text =
						"SELECTED MATERIAL: " ..
						string.upper(name)

					for materialName2, otherButton
						in pairs(materialButtons) do

						if materialName2 == materialName then
							otherButton.BackgroundColor3 = SELECTED
						else
							otherButton.BackgroundColor3 = BUTTON
						end
					end
				end)
			end
		end
	end
end

search:GetPropertyChangedSignal("Text"):Connect(rebuildMaterials)
rebuildMaterials()

--========================================================--
-- FLOATING LOGO
--========================================================--

local logoButton = Instance.new("ImageButton")
logoButton.Name = "FloatingLogo"
logoButton.AnchorPoint = Vector2.new(0, 0)
logoButton.Position = UDim2.fromOffset(18, 190)
logoButton.Size = UDim2.fromOffset(52, 52)
logoButton.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
logoButton.BackgroundTransparency = 0.12
logoButton.BorderSizePixel = 0
logoButton.Image = BACKGROUND_ID
logoButton.ImageTransparency = 0
logoButton.ScaleType = Enum.ScaleType.Fit
logoButton.ZIndex = 100
logoButton.Parent = gui

addCorner(logoButton, 14)
addStroke(
	logoButton,
	Color3.fromRGB(110, 110, 125),
	0.1,
	1
)

--========================================================--
-- LOGO DRAG / TAP
--========================================================--

logoButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		draggingLogo = true
		logoMoved = false
		logoDragStart = input.Position
		logoStartPosition = logoButton.Position
	end
end)

logoButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		if not logoMoved then
			main.Visible = not main.Visible
		end

		draggingLogo = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not draggingLogo then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - logoDragStart

	if math.abs(delta.X) > 5
		or math.abs(delta.Y) > 5 then

		logoMoved = true
	end

	local camera = Workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport = camera.ViewportSize

	local newX =
		logoStartPosition.X.Offset + delta.X

	local newY =
		logoStartPosition.Y.Offset + delta.Y

	local maxX = math.max(
		0,
		viewport.X - logoButton.AbsoluteSize.X
	)

	local maxY = math.max(
		0,
		viewport.Y - logoButton.AbsoluteSize.Y
	)

	newX = math.clamp(newX, 0, maxX)
	newY = math.clamp(newY, 0, maxY)

	logoButton.Position =
		UDim2.fromOffset(newX, newY)
end)

--========================================================--
-- POINTER
--========================================================--

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		pointerPosition = input.Position

	elseif input.UserInputType == Enum.UserInputType.Touch then
		pointerPosition = input.Position
	end
end)

--========================================================--
-- TERRAIN MATERIAL
--========================================================--

local function getTerrainMaterial()
	if terrainMode == "Erase" then
		return Enum.Material.Air
	end

	local selected = Enum.Material[materialName]

	if selected then
		return selected
	end

	return Enum.Material.Grass
end

--========================================================--
-- RAYCAST
--========================================================--

local function getTargetPosition()
	local camera = Workspace.CurrentCamera

	if not camera then
		return nil
	end

	if pointerPosition.X <= 0
		or pointerPosition.Y <= 0 then
		return nil
	end

	local ray = camera:ViewportPointToRay(
		pointerPosition.X,
		pointerPosition.Y
	)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList = {}

	if player.Character then
		table.insert(ignoreList, player.Character)
	end

	table.insert(ignoreList, main)
	table.insert(ignoreList, logoButton)

	params.FilterDescendantsInstances = ignoreList

	local result = Workspace:Raycast(
		ray.Origin,
		ray.Direction * 1500,
		params
	)

	if result then
		return result.Position
	end

	return nil
end

--========================================================--
-- TERRAIN PAINT
--========================================================--

local function paintTerrain(position)
	local now = os.clock()

	if now - lastPaint < 0.09 then
		return
	end

	lastPaint = now

	local material = getTerrainMaterial()

	local size = brushSize
	local height = brushHeight

	local x = math.floor(position.X / 4 + 0.5) * 4
	local y = math.floor(position.Y / 4 + 0.5) * 4
	local z = math.floor(position.Z / 4 + 0.5) * 4

	local cframe = CFrame.new(x, y, z)

	if shape == "Box" then
		terrain:FillBlock(
			cframe,
			Vector3.new(size, height, size),
			material
		)

	elseif shape == "Sphere" then
		terrain:FillBall(
			position,
			math.max(2, size / 2),
			material
		)

	elseif shape == "Cylinder" then
		terrain:FillCylinder(
			cframe,
			math.max(2, size / 2),
			height,
			material
		)

	elseif shape == "Wedge" then
		terrain:FillWedge(
			cframe,
			Vector3.new(size, height, size),
			material
		)
	end
end

--========================================================--
-- PAINT INPUT
--========================================================--

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		if not brushOn then
			return
		end

		if not main.Visible then
			return
		end

		painting = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		painting = false
	end
end)

--========================================================--
-- PAINT LOOP
--========================================================--

RunService.RenderStepped:Connect(function()
	if not painting then
		return
	end

	if not brushOn then
		return
	end

	if not main.Visible then
		return
	end

	local target = getTargetPosition()

	if target then
		paintTerrain(target)
	end
end)

--========================================================--
-- FPS / PING
--========================================================--

task.spawn(function()
	local frames = 0
	local lastTime = os.clock()

	while gui.Parent do
		frames += 1

		local now = os.clock()

		if now - lastTime >= 1 then
			fps.Text = "FPS: " .. tostring(frames)

			frames = 0
			lastTime = now

			local success, value = pcall(function()
				return Stats
					.Network
					.ServerStatsItem["Data Ping"]
					:GetValue()
			end)

			if success and value then
				ping.Text =
					"PING: "
					.. tostring(math.floor(value))
					.. "ms"
			else
				ping.Text = "PING: LIVE"
			end
		end

		RunService.RenderStepped:Wait()
	end
end)

--========================================================--
-- FINAL
--========================================================--

print("========================================")
print("MAULZZ×BRYAN TERRAIN TOOLS V2")
print("PREMIUM MOBILE UI LOADED")
print("CLEAN FEATURE TEXT")
print("BRUSH / SHAPE / MODE / SETTINGS / MATERIAL")
print("========================================")
