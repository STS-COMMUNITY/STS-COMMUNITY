--[[
    MAULZZ PRESET
    Replace Obstacle
    UI redesign:
    - Blue light/dark gradient border
    - Panel artwork: 134509549840946
    - Floating round logo: 92951662755076
    - Draggable + mobile friendly
    - Minimize / restore
    - Source / Target / Replace / Clear / Status
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local LOGO_ROUND = "rbxassetid://92951662755076"
local LOGO_PANEL = "rbxassetid://134509549840946"

local C = {
    BG = Color3.fromRGB(8, 8, 14),
    HEADER = Color3.fromRGB(17, 16, 28),
    CARD = Color3.fromRGB(18, 19, 31),
    FIELD = Color3.fromRGB(11, 12, 22),

    BLUE_DARK = Color3.fromRGB(20, 45, 170),
    BLUE = Color3.fromRGB(65, 125, 255),
    BLUE_LIGHT = Color3.fromRGB(125, 220, 255),

    PURPLE = Color3.fromRGB(112, 75, 255),
    TEXT = Color3.fromRGB(248, 248, 255),
    SUB = Color3.fromRGB(155, 158, 180),
    BORDER = Color3.fromRGB(42, 55, 105),

    SUCCESS = Color3.fromRGB(70, 235, 145),
    DANGER = Color3.fromRGB(255, 80, 100),
    WARNING = Color3.fromRGB(255, 190, 70),
}

local function tween(obj, props, duration)
    local t = TweenService:Create(
        obj,
        TweenInfo.new(duration or .2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        props
    )
    t:Play()
    return t
end

local function corner(obj, radius)
    local x = Instance.new("UICorner")
    x.CornerRadius = UDim.new(0, radius or 8)
    x.Parent = obj
    return x
end

local function stroke(obj, color, thickness)
    local x = Instance.new("UIStroke")
    x.Color = color or C.BORDER
    x.Thickness = thickness or 1
    x.Parent = obj
    return x
end

local function blueGradient(obj, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.BLUE_LIGHT),
        ColorSequenceKeypoint.new(.28, C.BLUE),
        ColorSequenceKeypoint.new(.65, C.BLUE_DARK),
        ColorSequenceKeypoint.new(1, C.BLUE_LIGHT),
    })
    g.Rotation = rotation or 45
    g.Parent = obj
    return g
end

local function cleanup()
    for _, serviceName in ipairs({"CoreGui", "PlayerGui"}) do
        pcall(function()
            local root = game:GetService(serviceName)
            for _, name in ipairs({"MAULZZ_PRESET", "FORKTHUB_ObstacleReplacer"}) do
                local old = root:FindFirstChild(name)
                if old then old:Destroy() end
            end
        end)
    end
end

cleanup()

-- =========================================================
-- OBJECT ENGINE
-- =========================================================

local srcList, tgtPool = {}, {}
local srcContainer = nil
local selectMode, selectConn

local function getSize(obj)
    if obj:IsA("BasePart") then return obj.Size end

    local ok, size = pcall(function()
        return obj:GetExtentsSize()
    end)
    if ok and size then return size end

    local inf = math.huge
    local x0,y0,z0,x1,y1,z1 = inf,inf,inf,-inf,-inf,-inf

    for _, v in ipairs(obj:GetDescendants()) do
        if v:IsA("BasePart") then
            local cf, h = v.CFrame, v.Size * .5
            for _, sx in ipairs({-1,1}) do
                for _, sy in ipairs({-1,1}) do
                    for _, sz in ipairs({-1,1}) do
                        local p = cf:PointToWorldSpace(Vector3.new(sx*h.X,sy*h.Y,sz*h.Z))
                        x0,y0,z0 = math.min(x0,p.X),math.min(y0,p.Y),math.min(z0,p.Z)
                        x1,y1,z1 = math.max(x1,p.X),math.max(y1,p.Y),math.max(z1,p.Z)
                    end
                end
            end
        end
    end

    return Vector3.new(x1-x0,y1-y0,z1-z0)
end

local function getAABBCenter(obj)
    if obj:IsA("BasePart") then return obj.Position end

    local inf = math.huge
    local x0,y0,z0,x1,y1,z1 = inf,inf,inf,-inf,-inf,-inf

    for _, v in ipairs(obj:GetDescendants()) do
        if v:IsA("BasePart") then
            local cf, h = v.CFrame, v.Size * .5
            for _, sx in ipairs({-1,1}) do
                for _, sy in ipairs({-1,1}) do
                    for _, sz in ipairs({-1,1}) do
                        local p = cf:PointToWorldSpace(Vector3.new(sx*h.X,sy*h.Y,sz*h.Z))
                        x0,y0,z0 = math.min(x0,p.X),math.min(y0,p.Y),math.min(z0,p.Z)
                        x1,y1,z1 = math.max(x1,p.X),math.max(y1,p.Y),math.max(z1,p.Z)
                    end
                end
            end
        end
    end

    return Vector3.new((x0+x1)*.5,(y0+y1)*.5,(z0+z1)*.5)
end

local function scaleToMatch(newObj, oldObj)
    local oldSize = getSize(oldObj)
    local newSize = getSize(newObj)
    if newSize.X < .001 or newSize.Y < .001 or newSize.Z < .001 then
        return false
    end

    -- Models are scaled uniformly first. This keeps the target model's
    -- original rotation/shape instead of introducing a skewed result.
    if newObj:IsA("Model") then
        local sx = oldSize.X / math.max(newSize.X, .001)
        local sy = oldSize.Y / math.max(newSize.Y, .001)
        local sz = oldSize.Z / math.max(newSize.Z, .001)
        local uniform = (sx * sy * sz) ^ (1/3)
        uniform = math.clamp(uniform, .001, 1000)

        local ok = pcall(function()
            newObj:ScaleTo(uniform)
        end)
        return ok
    elseif newObj:IsA("BasePart") then
        newObj.Size = oldSize
        return true
    end

    return false
end

local function rotationOnly(cf)
    return cf - cf.Position
end

-- Put the replacement at the source center, but KEEP THE TARGET'S
-- orientation. This is the important part that prevents the replacement
-- from inheriting a random/source tilt.
local function placeReplacement(clone, chosen, targetCenter)
    if clone:IsA("BasePart") then
        local targetRotation = rotationOnly(chosen.CFrame)
        clone.CFrame = CFrame.new(targetCenter) * targetRotation
        return
    end

    if clone:IsA("Model") then
        local targetPivot = chosen:GetPivot()
        local targetRotation = rotationOnly(targetPivot)

        -- First give the clone exactly the target's rotation.
        clone:PivotTo(CFrame.new(targetCenter) * targetRotation)

        -- ScaleTo keeps the model pivot orientation, so recalculate its
        -- visual center afterwards and translate without changing rotation.
        local center = getAABBCenter(clone)
        local shift = targetCenter - center
        if shift.Magnitude > 0.0001 then
            local p = clone:GetPivot()
            clone:PivotTo(CFrame.new(p.Position + shift) * rotationOnly(p))
        end
        return
    end

    local center = getAABBCenter(clone)
    local shift = targetCenter - center
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Position += shift
        end
    end
end

-- Backward-compatible helper used nowhere else, kept for safety.
local function moveToPosition(obj, targetCenter)
    local shift = targetCenter - getAABBCenter(obj)
    if obj:IsA("Model") then
        local p = obj:GetPivot()
        obj:PivotTo(CFrame.new(p.Position + shift) * rotationOnly(p))
    elseif obj:IsA("BasePart") then
        obj.Position += shift
    else
        for _, d in ipairs(obj:GetDescendants()) do
            if d:IsA("BasePart") then d.Position += shift end
        end
    end
end

-- Resolve the real object that was clicked. Mouse.Target is ALWAYS a BasePart,
-- so we must walk upward to the nearest Model before looking for its pool.
local function getClickedObject(target)
    if not target then return nil end

    local current = target
    while current and current ~= workspace do
        if current:IsA("Model") then
            return current
        end
        current = current.Parent
    end

    if target:IsA("BasePart") then
        return target
    end

    return nil
end

-- Build the pool from the selected object's immediate container.
-- Example: Workspace > ALL RINTANGAN > 12 > OBS > Part
-- Clicking Part resolves to OBS, then its parent (12) becomes the pool.
local function resolveObjects(obj)
    if not obj then return {}, nil end

    local parent = obj.Parent
    if parent and parent ~= workspace and (parent:IsA("Model") or parent:IsA("Folder")) then
        local pool = {}
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                table.insert(pool, child)
            end
        end

        if #pool > 0 then
            return pool, parent
        end
    end

    return {obj}, nil
end

-- =========================================================
-- GUI
-- =========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MAULZZ_PRESET"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global

local parentOK = pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not parentOK or not ScreenGui.Parent then
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Floating round logo
local Floating = Instance.new("ImageButton")
Floating.Name = "FloatingLogo"
Floating.Parent = ScreenGui
Floating.Size = UDim2.fromOffset(48,48)
Floating.Position = UDim2.new(0,18,.5,-24)
Floating.BackgroundColor3 = C.BG
Floating.BorderSizePixel = 0
Floating.Image = LOGO_ROUND
Floating.ScaleType = Enum.ScaleType.Fit
Floating.AutoButtonColor = false
Floating.Active = true
Floating.Visible = false
Floating.ZIndex = 100
corner(Floating,8)

local floatStroke = stroke(Floating, C.BLUE, 2)
blueGradient(floatStroke, 45)

Floating.MouseEnter:Connect(function()
    if not Floating:GetAttribute("Dragging") then
        tween(Floating,{Size=UDim2.fromOffset(52,52)},.15)
    end
end)
Floating.MouseLeave:Connect(function()
    if not Floating:GetAttribute("Dragging") then
        tween(Floating,{Size=UDim2.fromOffset(48,48)},.15)
    end
end)

local restore

-- Floating logo can also be dragged/geser.
-- A short click opens the panel; dragging only moves the logo.
local floatingDragging = false
local floatingDragStart = nil
local floatingStartPos = nil
local floatingMoved = false
local floatingPressTime = 0

Floating:SetAttribute("Dragging", false)

Floating.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        floatingDragging = true
        floatingMoved = false
        floatingPressTime = os.clock()
        floatingDragStart = input.Position
        floatingStartPos = Floating.Position
        Floating:SetAttribute("Dragging", true)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if floatingDragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - floatingDragStart

        if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
            floatingMoved = true
        end

        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(800,600)
        local size = Floating.AbsoluteSize
        local nx = math.clamp(
            floatingStartPos.X.Offset + delta.X,
            4,
            math.max(4, viewport.X - size.X - 4)
        )
        local ny = math.clamp(
            floatingStartPos.Y.Offset + delta.Y,
            4,
            math.max(4, viewport.Y - size.Y - 4)
        )

        Floating.Position = UDim2.new(0,nx,0,ny)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if floatingDragging and (
        input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        floatingDragging = false
        Floating:SetAttribute("Dragging", false)

        -- Only open when it was a click, not a drag.
        if not floatingMoved and (os.clock() - floatingPressTime) < 0.8 then
            restore()
        end

        tween(Floating,{Size=UDim2.fromOffset(48,48)},.12)
    end
end)

-- Main
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = ScreenGui
Main.AnchorPoint = Vector2.new(.5,.5)
Main.Position = UDim2.new(.5,0,.5,0)
Main.Size = UDim2.new(.9,0,.72,0)
Main.BackgroundColor3 = C.BG
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
corner(Main,15)

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.Parent = Main
sizeConstraint.MinSize = Vector2.new(310,390)
sizeConstraint.MaxSize = Vector2.new(430,570)

local mainStroke = stroke(Main,C.BLUE,2)
blueGradient(mainStroke,45)

-- Background artwork, centered and slightly dark
local Artwork = Instance.new("ImageLabel")
Artwork.Name = "PanelArtwork"
Artwork.Parent = Main
Artwork.AnchorPoint = Vector2.new(.5,.5)
Artwork.Position = UDim2.new(.5,0,.52,0)
Artwork.Size = UDim2.new(1,-12,1,-12)
Artwork.BackgroundTransparency = 1
Artwork.Image = LOGO_PANEL
Artwork.ScaleType = Enum.ScaleType.Crop
Artwork.ImageTransparency = .78
Artwork.ZIndex = 1
Artwork.Active = false

local ArtworkShade = Instance.new("Frame")
ArtworkShade.Parent = Main
Artwork.Size = UDim2.fromScale(1,1)
ArtworkShade.BackgroundColor3 = Color3.fromRGB(3,4,10)
ArtworkShade.BackgroundTransparency = .22
ArtworkShade.BorderSizePixel = 0
ArtworkShade.ZIndex = 2
ArtworkShade.Active = false
corner(ArtworkShade,15)

-- Header
local Header = Instance.new("Frame")
Header.Parent = Main
Header.Size = UDim2.new(1,0,0,68)
Header.BackgroundColor3 = C.HEADER
Header.BackgroundTransparency = .06
Header.BorderSizePixel = 0
Header.ZIndex = 10
corner(Header,14)

local HeaderCover = Instance.new("Frame")
HeaderCover.Parent = Header
HeaderCover.Size = UDim2.new(1,0,0,14)
HeaderCover.Position = UDim2.new(0,0,1,-14)
HeaderCover.BackgroundColor3 = C.HEADER
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 10

local PanelLogo = Instance.new("ImageLabel")
PanelLogo.Parent = Header
PanelLogo.Size = UDim2.fromOffset(44,44)
PanelLogo.Position = UDim2.fromOffset(12,12)
PanelLogo.BackgroundTransparency = 1
PanelLogo.Image = LOGO_PANEL
PanelLogo.ScaleType = Enum.ScaleType.Fit
PanelLogo.ZIndex = 12

local Title = Instance.new("TextLabel")
Title.Parent = Header
Title.Size = UDim2.new(1,-155,0,23)
Title.Position = UDim2.fromOffset(64,10)
Title.BackgroundTransparency = 1
Title.Text = "MAULZZ PRESET"
Title.TextColor3 = C.TEXT
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12

local Subtitle = Instance.new("TextLabel")
Subtitle.Parent = Header
Subtitle.Size = UDim2.new(1,-155,0,18)
Subtitle.Position = UDim2.fromOffset(64,34)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Replace Obstacle • Public Tool"
Subtitle.TextColor3 = C.SUB
Subtitle.TextSize = 10
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.ZIndex = 12

local function headerButton(x,text,color)
    local b = Instance.new("TextButton")
    b.Parent = Header
    b.Size = UDim2.fromOffset(38,48)
    b.Position = UDim2.new(1,x,0,10)
    b.BackgroundTransparency = 1
    b.Text = text
    b.TextColor3 = color
    b.TextSize = 20
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.ZIndex = 40
    b.Active = true
    return b
end

local MinBtn = headerButton(-82,"−",C.SUB)
local CloseBtn = headerButton(-42,"×",C.SUB)

MinBtn.MouseEnter:Connect(function() tween(MinBtn,{TextColor3=C.BLUE_LIGHT}) end)
MinBtn.MouseLeave:Connect(function() tween(MinBtn,{TextColor3=C.SUB}) end)
CloseBtn.MouseEnter:Connect(function() tween(CloseBtn,{TextColor3=C.DANGER}) end)
CloseBtn.MouseLeave:Connect(function() tween(CloseBtn,{TextColor3=C.SUB}) end)

-- Content
local Content = Instance.new("ScrollingFrame")
Content.Parent = Main
Content.Size = UDim2.new(1,0,1,-102)
Content.Position = UDim2.fromOffset(0,68)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = C.BLUE
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new()
Content.ZIndex = 40
Content.Active = true

local pad = Instance.new("UIPadding")
pad.Parent = Content
pad.PaddingTop = UDim.new(0,14)
pad.PaddingBottom = UDim.new(0,20)
pad.PaddingLeft = UDim.new(0,15)
pad.PaddingRight = UDim.new(0,15)

local list = Instance.new("UIListLayout")
list.Parent = Content
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0,10)
list.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Status
local StatusBar = Instance.new("Frame")
StatusBar.Parent = Main
StatusBar.AnchorPoint = Vector2.new(0,1)
StatusBar.Position = UDim2.new(0,0,1,0)
StatusBar.Size = UDim2.new(1,0,0,34)
StatusBar.BackgroundColor3 = C.BG
StatusBar.BackgroundTransparency = .04
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 20

local divider = Instance.new("Frame")
divider.Parent = StatusBar
divider.Size = UDim2.new(1,0,0,1)
divider.BackgroundColor3 = C.BLUE_DARK
divider.BorderSizePixel = 0

local dot = Instance.new("TextLabel")
dot.Parent = StatusBar
dot.Size = UDim2.fromOffset(18,34)
dot.Position = UDim2.fromOffset(13,0)
dot.BackgroundTransparency = 1
dot.Text = "●"
dot.TextColor3 = C.SUCCESS
dot.TextSize = 10

local statusLabel = Instance.new("TextLabel")
statusLabel.Parent = StatusBar
statusLabel.Size = UDim2.new(1,-50,1,0)
statusLabel.Position = UDim2.fromOffset(32,0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready • MAULZZ PRESET"
statusLabel.TextColor3 = C.SUB
statusLabel.TextSize = 10
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local function setStatus(text,color)
    statusLabel.Text = text
    tween(statusLabel,{TextColor3=color or C.SUB},.18)
    tween(dot,{TextColor3=color or C.SUCCESS},.18)
end

-- UI helpers
local function section(order,text)
    local f = Instance.new("Frame")
    f.Parent = Content
    f.LayoutOrder = order
    f.Size = UDim2.new(1,0,0,18)
    f.BackgroundTransparency = 1

    local l = Instance.new("TextLabel")
    l.Parent = f
    l.Size = UDim2.fromScale(1,1)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = C.BLUE_LIGHT
    l.TextSize = 9
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    return f
end

local function card(order,titleText,nameText,countText)
    local f = Instance.new("Frame")
    f.Parent = Content
    f.LayoutOrder = order
    f.Size = UDim2.new(1,0,0,82)
    f.BackgroundColor3 = C.CARD
    f.BackgroundTransparency = .08
    f.BorderSizePixel = 0
    corner(f,9)

    local s = stroke(f,C.BORDER,1)
    blueGradient(s,45)

    local t = Instance.new("TextLabel")
    t.Parent = f
    t.Size = UDim2.new(1,-100,0,14)
    t.Position = UDim2.fromOffset(13,9)
    t.BackgroundTransparency = 1
    t.Text = titleText
    t.TextColor3 = C.BLUE_LIGHT
    t.TextSize = 9
    t.Font = Enum.Font.GothamBold
    t.TextXAlignment = Enum.TextXAlignment.Left

    local n = Instance.new("TextLabel")
    n.Parent = f
    n.Size = UDim2.new(1,-105,0,20)
    n.Position = UDim2.fromOffset(13,28)
    n.BackgroundTransparency = 1
    n.Text = nameText
    n.TextColor3 = C.TEXT
    n.TextSize = 11
    n.Font = Enum.Font.GothamBold
    n.TextXAlignment = Enum.TextXAlignment.Left
    n.TextTruncate = Enum.TextTruncate.AtEnd

    local c = Instance.new("TextLabel")
    c.Parent = f
    c.Size = UDim2.new(1,-105,0,14)
    c.Position = UDim2.fromOffset(13,55)
    c.BackgroundTransparency = 1
    c.Text = countText
    c.TextColor3 = C.SUB
    c.TextSize = 9
    c.Font = Enum.Font.GothamMedium
    c.TextXAlignment = Enum.TextXAlignment.Left

    local b = Instance.new("TextButton")
    b.Parent = f
    b.AnchorPoint = Vector2.new(1,.5)
    b.Position = UDim2.new(1,-13,.5,0)
    b.Size = UDim2.fromOffset(80,32)
    b.BackgroundColor3 = C.FIELD
    b.BorderSizePixel = 0
    b.Text = "SELECT"
    b.TextColor3 = C.BLUE_LIGHT
    b.TextSize = 9
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Active = true
    b.ZIndex = 50
    corner(b,7)

    local bs = stroke(b,C.BORDER,1)

    b.MouseEnter:Connect(function()
        tween(b,{BackgroundColor3=C.BLUE_DARK,TextColor3=C.TEXT},.15)
        tween(bs,{Color=C.BLUE_LIGHT},.15)
    end)
    b.MouseLeave:Connect(function()
        tween(b,{BackgroundColor3=C.FIELD,TextColor3=C.BLUE_LIGHT},.15)
        tween(bs,{Color=C.BORDER},.15)
    end)

    return n,c,b
end

section(1,"REPLACEMENT DATA")
section(2,"SOURCE MODEL")
local srcName,srcCount,srcBtn = card(3,"SOURCE","None Selected","0 objects detected")

section(4,"TARGET POOL")
local tgtName,tgtCount,tgtBtn = card(5,"TARGET","None Selected","0 variants loaded")

section(6,"EXECUTION")

local replaceBtn = Instance.new("TextButton")
replaceBtn.Parent = Content
replaceBtn.LayoutOrder = 7
replaceBtn.Size = UDim2.new(1,0,0,46)
replaceBtn.BackgroundColor3 = C.PURPLE
replaceBtn.BorderSizePixel = 0
replaceBtn.Text = "REPLACE 0 OBJECTS"
replaceBtn.TextColor3 = C.TEXT
replaceBtn.TextSize = 11
replaceBtn.Font = Enum.Font.GothamBold
replaceBtn.AutoButtonColor = false
replaceBtn.Active = true
replaceBtn.ZIndex = 40
corner(replaceBtn,9)
local rg = blueGradient(replaceBtn,0)

replaceBtn.MouseEnter:Connect(function()
    tween(replaceBtn,{BackgroundColor3=C.BLUE},.15)
end)
replaceBtn.MouseLeave:Connect(function()
    tween(replaceBtn,{BackgroundColor3=C.PURPLE},.15)
end)

local clearBtn = Instance.new("TextButton")
clearBtn.Parent = Content
clearBtn.LayoutOrder = 8
clearBtn.Size = UDim2.new(1,0,0,30)
clearBtn.BackgroundColor3 = C.FIELD
clearBtn.BackgroundTransparency = .15
clearBtn.BorderSizePixel = 0
clearBtn.Text = "Clear All Selection"
clearBtn.TextColor3 = C.SUB
clearBtn.TextSize = 10
clearBtn.Font = Enum.Font.GothamMedium
clearBtn.AutoButtonColor = false
clearBtn.Active = true
clearBtn.ZIndex = 40
corner(clearBtn,7)
local clearStroke = stroke(clearBtn,C.BORDER,1)

clearBtn.MouseEnter:Connect(function()
    tween(clearBtn,{TextColor3=C.TEXT,BackgroundColor3=C.BLUE_DARK},.15)
end)
clearBtn.MouseLeave:Connect(function()
    tween(clearBtn,{TextColor3=C.SUB,BackgroundColor3=C.FIELD},.15)
end)

local footer = Instance.new("TextLabel")
footer.Parent = Content
footer.LayoutOrder = 99
footer.Size = UDim2.new(1,0,0,26)
footer.BackgroundTransparency = 1
footer.Text = "© MAULZZ PRESET • Replace Obstacle"
footer.TextColor3 = C.BLUE_LIGHT
footer.TextSize = 9
footer.Font = Enum.Font.GothamBold
footer.TextYAlignment = Enum.TextYAlignment.Bottom

local function updateUI()
    replaceBtn.Text = "REPLACE "..#srcList.." OBJECTS"
    srcCount.Text = #srcList.." objects detected"
    tgtCount.Text = #tgtPool.." variants loaded"
end

local function stopSelect()
    selectMode = nil
    if selectConn then
        selectConn:Disconnect()
        selectConn = nil
    end
    srcBtn.Text = "SELECT"
    tgtBtn.Text = "SELECT"
end

local function getWorldTarget()
    -- Use the same Mouse object as FORKT first, then fall back to a camera
    -- raycast. The fallback makes selection reliable when a custom GUI is
    -- sitting in CoreGui/PlayerGui and Mouse.Target is not updated normally.
    local target = Mouse.Target
    if target and target:IsDescendantOf(workspace) then
        return target
    end

    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local pos = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    return result and result.Instance or nil
end

local function startSelect(mode)
    stopSelect()
    selectMode = mode

    local button = mode == "source" and srcBtn or tgtBtn
    button.Text = "CANCEL"
    setStatus("Click an object in the 3D world...", C.WARNING)

    -- Use the exact same selection mechanism as the working FORKT HUB:
    -- Mouse.Button1Down + Mouse.Target.  Do not reject the click because
    -- Roblox Studio may mark it as processed by its own selection tool.
    selectConn = Mouse.Button1Down:Connect(function()
        if not selectMode then return end

        local target = Mouse.Target
        if not target or not target:IsDescendantOf(workspace) then
            setStatus("Missed. Click a visible 3D part.", C.DANGER)
            return
        end

        local obj = getClickedObject(target)
        if not obj then
            setStatus("Clicked object is not a valid Model/Part.", C.DANGER)
            return
        end

        -- Walk upward through nested folders/models.  This makes a click on
        -- any Part/MeshPart inside OBS resolve to the OBS model itself.
        local pool, parent = resolveObjects(obj)
        if #pool == 0 then
            setStatus("No selectable objects found in this container.", C.DANGER)
            return
        end

        if mode == "source" then
            srcList = pool
            srcContainer = parent
            if parent then
                srcName.Text = "📂 " .. parent.Name
                setStatus("Source folder loaded: " .. #pool .. " objects.", C.SUCCESS)
            else
                srcName.Text = "📦 " .. obj.Name
                setStatus("Source object loaded.", C.SUCCESS)
            end
        else
            tgtPool = pool
            if parent then
                tgtName.Text = "📂 " .. parent.Name
                setStatus("Target pool loaded: " .. #pool .. " variants.", C.SUCCESS)
            else
                tgtName.Text = "📦 " .. obj.Name
                setStatus("Target object loaded.", C.SUCCESS)
            end
        end

        updateUI()
        stopSelect()
    end)
end

srcBtn.MouseButton1Click:Connect(function()
    if selectMode == "source" then
        stopSelect()
        setStatus("Ready.",C.SUB)
    else
        startSelect("source")
    end
end)

tgtBtn.MouseButton1Click:Connect(function()
    if selectMode == "target" then
        stopSelect()
        setStatus("Ready.",C.SUB)
    else
        startSelect("target")
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    srcList, tgtPool = {}, {}
    srcContainer = nil
    srcName.Text = "None Selected"
    tgtName.Text = "None Selected"
    stopSelect()
    updateUI()
    setStatus("Selection cleared.",C.SUB)
end)

local processing = false

replaceBtn.MouseButton1Click:Connect(function()
    if processing then return end
    if #srcList == 0 or #tgtPool == 0 then
        setStatus("Select Source & Target first!",C.DANGER)
        return
    end

    processing = true
    replaceBtn.Text = "PROCESSING..."
    tween(replaceBtn,{BackgroundColor3=C.WARNING},.18)

    local targetSet, toReplace = {}, {}
    for _, t in ipairs(tgtPool) do targetSet[t] = true end

    for _, s in ipairs(srcList) do
        if s and s.Parent and not targetSet[s] then
            table.insert(toReplace,s)
        end
    end

    if #toReplace == 0 then
        setStatus("Source objects no longer exist.",C.DANGER)
        replaceBtn.Text = "REPLACE 0 OBJECTS"
        tween(replaceBtn,{BackgroundColor3=C.PURPLE},.18)
        processing = false
        return
    end

    task.spawn(function()
        local okCount, failCount = 0, 0
        local newSources = {}

        for i, old in ipairs(toReplace) do
            local ok = pcall(function()
                local chosen = tgtPool[math.random(1,#tgtPool)]
                local center = getAABBCenter(old)

                local clone = chosen:Clone()
                clone.Name = chosen.Name
                clone.Parent = old.Parent

                -- Scale without inheriting the source rotation.
                scaleToMatch(clone, old)
                placeReplacement(clone, chosen, center)

                old:Destroy()
                table.insert(newSources, clone)
            end)

            if ok then okCount += 1 else failCount += 1 end
            if i % 10 == 0 then RunService.Heartbeat:Wait() end
        end

        tween(replaceBtn,{BackgroundColor3=C.PURPLE},.18)
        replaceBtn.Text = "REPLACE "..#srcList.." OBJECTS"

        if failCount == 0 then
            setStatus("Success! "..okCount.." items replaced. Ready again.",C.SUCCESS)
        else
            setStatus("Done: "..okCount.." OK, "..failCount.." FAILED.",C.WARNING)
        end

        processing = false

        -- IMPORTANT: keep the source pool alive for repeated use.
        -- Rebuild it from the original container after replacement so the
        -- newly-created clones become the next source set. This is what
        -- allows REPLACE to be pressed repeatedly without re-running the UI.
        if srcContainer and srcContainer.Parent then
            local refreshed = {}
            for _, child in ipairs(srcContainer:GetChildren()) do
                if (child:IsA("Model") or child:IsA("BasePart")) and not targetSet[child] then
                    table.insert(refreshed, child)
                end
            end
            srcList = refreshed
        else
            srcList = newSources
        end

        srcName.Text = (#srcList > 0) and ("↻ Ready ("..#srcList.." objects)") or "None Selected"
        updateUI()
    end)
end)

-- =========================================================
-- DRAGGING
-- =========================================================

local dragging, dragStart, dragStartPos = false,nil,nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        dragStartPos = Main.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            dragStartPos.X.Scale,
            dragStartPos.X.Offset + delta.X,
            dragStartPos.Y.Scale,
            dragStartPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- =========================================================
-- MINIMIZE / RESTORE
-- =========================================================

local minimized = false

local function minimize()
    if minimized then return end
    minimized = true
    stopSelect()

    -- The floating logo keeps its own position, so it can be moved
    -- anywhere on screen and will stay there after minimize.
    tween(Main,{Size=UDim2.new(.9,0,0,0)},.22)

    task.delay(.22,function()
        Main.Visible = false
        Floating.Visible = true
        Floating.Size = UDim2.fromOffset(8,8)
        tween(Floating,{Size=UDim2.fromOffset(48,48)},.28)
    end)
end

restore = function()
    if not minimized then return end
    minimized = false

    Floating.Visible = false
    Main.Visible = true
    Main.Size = UDim2.new(.9,0,0,0)

    tween(Main,{Size=UDim2.new(.9,0,.72,0)},.28)
end

MinBtn.MouseButton1Click:Connect(minimize)
-- Restore is handled by the draggable floating-logo input above.

CloseBtn.MouseButton1Click:Connect(function()
    stopSelect()
    ScreenGui:Destroy()
end)

updateUI()
setStatus("Ready • MAULZZ PRESET",C.SUCCESS)

print("[MAULZZ PRESET] Replace Obstacle loaded")
