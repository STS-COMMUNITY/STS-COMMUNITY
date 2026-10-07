
-- ============================================
-- ★ MAULZZ×BRYAN - RBXM IMPORTER V14.2
-- ENGINE: MAULZZ×BRYAN IMPORTER
-- UI: MAULZZ×BRYAN IMPORTER V00.8 STYLE
-- MODIF: Part Stabil (Tidak Roboh) & Bisa Digeser
-- ============================================
if not game:IsLoaded() then game.Loaded:Wait() end
local MaulzzBryanImporter = {}
MaulzzBryanImporter.__index = MaulzzBryanImporter
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local InsertService = game:GetService("InsertService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local isAuthenticated = true
_G.MAULZZ_RAW_SOURCES = _G.MAULZZ_RAW_SOURCES or {}
-- ============================================
-- SCREENGUI SETUP (Delta Executor Protection)
-- ============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MAULZZ_BRyAN_IMPORTER"
screenGui.ResetOnSpawn = false
if syn and syn.protect_gui then
    syn.protect_gui(screenGui)
    screenGui.Parent = CoreGui
elseif gethui then
    screenGui.Parent = gethui()
else
    screenGui.Parent = CoreGui
end
-- ============================================
-- SISTEM ANIMASI RGB KUNING - BIRU (GLOBAL)
-- ============================================
local rgbStrokes = {}
local function applyYellowBlueRGBBorder(parentFrame, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness or 2
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parentFrame
    table.insert(rgbStrokes, stroke)
    return stroke
end
task.spawn(function()
    local t = 0
    while task.wait(0.03) do
        t = t + 0.05
        local alpha = (math.sin(t) + 1) / 2
        local r = (1 - alpha) * 255 + alpha * 0
        local g = (1 - alpha) * 200 + alpha * 150
        local b = (1 - alpha) * 0 + alpha * 255
        local currentColor = Color3.fromRGB(r, g, b)
        for _, stroke in ipairs(rgbStrokes) do
            if stroke and stroke.Parent then
                stroke.Color = currentColor
            end
        end
    end
end)
-- ============================================
-- PALETTE & STATE
-- ============================================
local PALETTE = {
    Background = Color3.fromRGB(15, 15, 19),
    CardBg = Color3.fromRGB(10, 10, 14),
    InputBg = Color3.fromRGB(10, 10, 13),
    AccentCyan = Color3.fromRGB(0, 200, 220),
    AccentBlue = Color3.fromRGB(0, 120, 215),
    AccentGold = Color3.fromRGB(255, 200, 50),
    AccentGreen = Color3.fromRGB(0, 220, 150),
    AccentRed = Color3.fromRGB(220, 50, 60),
    TextWhite = Color3.fromRGB(240, 240, 240),
    TextDark = Color3.fromRGB(0, 0, 0),
    TextMuted = Color3.fromRGB(180, 180, 180),
    InnerBorder = Color3.fromRGB(30, 30, 40),
}
local UIState = {
    loginFrame = nil,
    mainFrame = nil,
    sizeFrame = nil,
    musicFrame = nil,
    toggleButton = nil,
    scrollFrame = nil,
    statusLabel = nil,
    searchBox = nil,
    detectedFiles = {},
    currentFilter = "",
    isScanning = false,
    panelVisible = false,
}
-- ============================================
-- HTTP REQUEST UTILITY (importer utility)
-- ============================================
local function httpRequest(url, method, headers, data)
    method = method or "GET"
    headers = headers or {}
    headers["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
    local fns = {
        function() if syn and syn.request then local r = syn.request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body, r.StatusCode end end,
        function() if request then local r = request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body, r.StatusCode end end,
        function() if http_request then local r = http_request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body, r.StatusCode end end,
        function() if fluxus and fluxus.request then local r = fluxus.request({Url=url,Method=method,Headers=headers,Body=data}); return r.Body, r.StatusCode end end,
        function() return game:HttpGet(url, true), 200 end,
    }
    for _, fn in ipairs(fns) do
        local ok, body, status = pcall(fn)
        if ok and body and type(body) == "string" and #body > 0 then return body, status or 200 end
    end
    return nil, nil
end
-- ============================================
-- BUFFER UTILITY (importer utility)
-- ============================================
local function Buffer(str, allowOverflows)
    local Stream = {
        Offset = 0, Source = str,
        Length = #str,
        AllowOverflows = (allowOverflows == nil and true) or allowOverflows
    }
    function Stream:read(len, shift)
        len = len or 1; shift = (shift == nil and true) or shift
        local dat = string.sub(self.Source, self.Offset+1, self.Offset+len)
        if shift then self:seek(len) end
        return dat
    end
    function Stream:seek(len) self.Offset = math.clamp(self.Offset+len, 0, self.Length) end
    function Stream:readNumber(fmt, shift)
        fmt = fmt or "I1"
        local chunk = self:read(string.packsize(fmt), shift)
        return string.unpack(fmt, chunk)
    end
    function Stream:append(s) self.Source = self.Source..s; self.Length = #self.Source end
    function Stream:toEnd() self.Offset = self.Length end
    return Stream
end
local function transformInt(x) return (x%2==0) and (x/2) or (-(x+1)/2) end
local function rbxF32(x) x = bit32.rrotate(x,1); return string.unpack(">f", string.pack(">I4",x)) end
local basicTypes = {}
function basicTypes.String(buf) return buf:read(buf:readNumber("<I4")) end
function basicTypes.Int32(buf) return transformInt(buf:readNumber(">I4")) end
function basicTypes.Int64(buf) return transformInt(buf:readNumber(">I8")) end
function basicTypes.Float32(buf) return rbxF32(buf:readNumber(">I4")) end
function basicTypes.Float64(buf) return buf:readNumber("<d") end
function basicTypes.InterleaveArrayWithSize(buf, count, sizeof)
    if count < 0 then return Buffer("", false) end
    local stream = buf:read(count*sizeof); local out = table.create(count)
    for i = 1, count do
        local chunk = table.create(sizeof)
        for s = 0, sizeof-1 do
            local bitPos = i + (count*s); chunk[s+1] = string.sub(stream, bitPos, bitPos)
        end
        out[i] = table.concat(chunk)
    end
    return Buffer(table.concat(out), false)
end
function basicTypes.unsignedIntArray(buf, count)
    if count < 1 then return {} end
    local o = table.create(count); local strings = basicTypes.InterleaveArrayWithSize(buf, count, 4)
    for i = 1, count do o[i] = strings:readNumber("<I4") end
    return o
end
function basicTypes.Int32Array(buf, count)
    if count < 1 then return {} end
    local o = table.create(count); local strings = basicTypes.InterleaveArrayWithSize(buf, count, 4)
    for i = 1, count do o[i] = basicTypes.Int32(strings) end
    return o
end
function basicTypes.Int64Array(buf, count)
    if count < 1 then return {} end
    local o = table.create(count); local strings = basicTypes.InterleaveArrayWithSize(buf, count, 8)
    for i = 1, count do o[i] = basicTypes.Int64(strings) end
    return o
end
function basicTypes.RbxF32Array(buf, count)
    if count < 1 then return {} end
    local o = table.create(count); local strings = basicTypes.InterleaveArrayWithSize(buf, count, 4)
    for i = 1, count do o[i] = basicTypes.Float32(strings) end
    return o
end
function basicTypes.RefArray(buf, count)
    if count < 1 then return {} end
    local o = table.create(count); local refs = basicTypes.Int32Array(buf, count); local last = 0
    for i = 1, count do local ref = last + refs[i]; o[i] = ref; last = ref end
    return o
end
-- ============================================
-- LZ4 DECOMPRESSOR (full implementation)
-- ============================================
local function lz4(lz4data)
    local inputStream = Buffer(lz4data)
    local compressedLen = string.unpack("<I4", inputStream:read(4))
    local decompressedLen= string.unpack("<I4", inputStream:read(4))
    local reserved = string.unpack("<I4", inputStream:read(4))
    if reserved ~= 0 then error("not lz4") end
    if compressedLen == 0 then return inputStream:read(decompressedLen) end
    local outputStream = Buffer("")
    repeat
        local token = string.byte(inputStream:read())
        local litLen = bit32.rshift(token, 4)
        local matLen = bit32.band(token, 15) + 4
        if litLen >= 15 then
            repeat
                local nextByte = string.byte(inputStream:read())
                litLen = litLen + nextByte
            until nextByte ~= 0xFF
        end
        local literal = inputStream:read(litLen)
        outputStream:append(literal); outputStream:toEnd()
        if outputStream.Length < decompressedLen then
            local offset = string.unpack("<I2", inputStream:read(2))
            if matLen >= 19 then
                repeat
                    local nextByte = string.byte(inputStream:read())
                    matLen = matLen + nextByte
                until nextByte ~= 0xFF
            end
            outputStream:seek(-offset)
            local pos = outputStream.Offset
            local match = outputStream:read(matLen)
            local unreadBytes = outputStream.LastUnreadBytes or 0
            local extra
            if unreadBytes then
                repeat
                    outputStream.Offset = pos
                    extra = outputStream:read(unreadBytes)
                    unreadBytes = outputStream.LastUnreadBytes or 0
                    match = match .. extra
                until unreadBytes <= 0
            end
            outputStream:append(match); outputStream:toEnd()
        end
    until outputStream.Length >= decompressedLen
    return outputStream.Source
end
-- ============================================
-- ZSTD FALLBACK (importer utility)
-- ============================================
local function b64encode(str)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local out = {}
    for i = 1, #str, 3 do
        local b0, b1, b2 = string.byte(str, i, i+2)
        local b = bit32.lshift(b0, 16) + bit32.lshift(b1 or 0, 8) + (b2 or 0)
        table.insert(out, chars:sub(bit32.extract(b,18,6)+1, bit32.extract(b,18,6)+1))
        table.insert(out, chars:sub(bit32.extract(b,12,6)+1, bit32.extract(b,12,6)+1))
        table.insert(out, b1 and chars:sub(bit32.extract(b,6,6)+1, bit32.extract(b,6,6)+1) or "=")
        table.insert(out, b2 and chars:sub(bit32.band(b,63)+1, bit32.band(b,63)+1) or "=")
    end
    return table.concat(out)
end
local function zstd(stream)
    local zbase64 = b64encode(stream)
    local json = '{"m":null,"t":"buffer","zbase64":"' .. zbase64 .. '"}'
    local x = HttpService:JSONDecode(json)
    return buffer.tostring(x)
end
-- ============================================
-- RBXM BINARY PARSER — SOURCE EXTRACTOR
-- (RBXM source parser)
-- ============================================
local function parseRBXMForSources(data)
    local sources = {}
    local rbxmBuf = Buffer(data, false)
    if rbxmBuf:read(8) ~= "<roblox!" or rbxmBuf:read(6) ~= string.char(137,255,13,10,26,10) then return sources, "Invalid header" end
    if rbxmBuf:read(2) ~= (string.char(0)..string.char(0)) then return sources, "Invalid version" end
    local classCount = rbxmBuf:readNumber("<i4")
    local instCount = rbxmBuf:readNumber("<i4")
    local classRefs, virtualInstances, strings, chunkInfo = {}, {}, {}, {}
    local _EC = "END"..string.char(0)
    local valid = {[_EC]=true,["INST"]=true,["META"]=true,["PRNT"]=true,["PROP"]=true,["SIGN"]=true,["SSTR"]=true}
    for k in pairs(valid) do chunkInfo[k] = {} end
    if rbxmBuf:read(8) ~= string.char(0,0,0,0,0,0,0,0) then return sources, "Invalid header2" end
    local index, last_chunk = 0, nil
    repeat
        index = index + 1
        local chunk = { InternalID = index, Header = rbxmBuf:read(4) }
        if not valid[chunk.Header] then return sources, "Invalid chunk: " .. tostring(chunk.Header) end
        local lz4Header = rbxmBuf:read(16, false)
        local compressed = string.unpack("<I4", string.sub(lz4Header, 1, 4))
        local decompressed = string.unpack("<I4", string.sub(lz4Header, 5, 8))
        local zstd_check = string.sub(lz4Header, 13, 16)
        local dataChunk
        if compressed == 0 then
            dataChunk = rbxmBuf:read(decompressed + 12)
        else
            if zstd_check == string.char(40,181,47,253) then
                rbxmBuf:seek(12); dataChunk = zstd(rbxmBuf:read(compressed))
            else
                dataChunk = lz4(rbxmBuf:read(compressed + 12))
            end
        end
        chunk.Data = Buffer(dataChunk, false)
        table.insert(chunkInfo[chunk.Header], chunk)
        last_chunk = chunk
    until last_chunk and last_chunk.Header == _EC
    for _, chunk in ipairs(chunkInfo["SSTR"] or {}) do
        local buf = chunk.Data
        if buf:readNumber("<I4") == 0 then
            for i = 1, buf:readNumber("<I4") do buf:read(16); strings[i] = basicTypes.String(buf) end
        end
    end
    for _, chunk in ipairs(chunkInfo["INST"] or {}) do
        local buf = chunk.Data
        local classID = buf:readNumber("<I4")
        local className = basicTypes.String(buf)
        if buf:read() == "\1" then return sources, "Contains services" end
        local count = buf:readNumber("<I4")
        local refs = basicTypes.RefArray(buf, count)
        classRefs[classID] = { Name = className, Sizeof = count, Refs = refs }
        for _, ref in ipairs(refs) do
            virtualInstances[ref] = { ClassId = classID, ClassName = className, Ref = ref, Properties = {}, Children = {} }
        end
    end
    for _, chunk in ipairs(chunkInfo["PROP"] or {}) do
        local buf = chunk.Data
        local classID = buf:readNumber("<I4")
        local classref = classRefs[classID]
        if not classref then return sources, "Missing classref" end
        local refs = classref.Refs
        local sizeof = classref.Sizeof
        local name = basicTypes.String(buf)
        if string.byte(buf:read(1, false)) == 0x1E then buf:seek(1) end
        local typeID = string.byte(buf:read())
        local props = {}
        if typeID == 0x01 or typeID == 0x1D then
            for i = 1, sizeof do props[i] = basicTypes.String(buf) end
        elseif typeID == 0x02 then
            for i = 1, sizeof do props[i] = buf:read() ~= string.char(0) end
        elseif typeID == 0x03 then props = basicTypes.Int32Array(buf, sizeof)
        elseif typeID == 0x04 then props = basicTypes.RbxF32Array(buf, sizeof)
        elseif typeID == 0x05 then
            for i = 1, sizeof do props[i] = basicTypes.Float64(buf) end
        else
            for i = 1, sizeof do
                if typeID == 0x13 then props = basicTypes.RefArray(buf, sizeof); break else buf:read(4) end
            end
        end
        if name == "Source" or name == "ContentText" then
            for i, v in ipairs(refs) do
                if virtualInstances[v] and props[i] then virtualInstances[v].Properties[name] = props[i] end
            end
        end
    end
    local function buildSourceMap(node, path)
        local src = node.Properties["Source"] or node.Properties["ContentText"]
        if src and type(src) == "string" and #src > 0 then sources[path] = src end
        for _, child in ipairs(node.Children or {}) do
            buildSourceMap(child, path .. "." .. child.ClassName .. ":" .. (child.Properties["Name"] or "unnamed"))
        end
    end
    for _, chunk in ipairs(chunkInfo["PRNT"] or {}) do
        local buf = chunk.Data
        if buf:read() ~= string.char(0) then return sources, "Invalid PRNT" end
        local count = buf:readNumber("<I4")
        local child_refs = basicTypes.RefArray(buf, count)
        local parent_refs = basicTypes.RefArray(buf, count)
        for i = 1, count do
            local child = virtualInstances[child_refs[i]]
            local parent = virtualInstances[parent_refs[i]]
            if child and parent then table.insert(parent.Children, child) end
        end
    end
    local roots = {}
    for _, inst in pairs(virtualInstances) do
        local hasParent = false
        for _, other in pairs(virtualInstances) do
            for _, child in ipairs(other.Children or {}) do if child.Ref == inst.Ref then hasParent = true; break end end
            if hasParent then break end
        end
        if not hasParent then table.insert(roots, inst) end
    end
    for _, root in ipairs(roots) do
        buildSourceMap(root, root.ClassName .. ":" .. (root.Properties["Name"] or "root"))
    end
    return sources, nil
end
-- ============================================
-- STUDIO LITE INTEGRATION (importer utility)
-- ============================================
local slFolder = ReplicatedStorage:FindFirstChild("StudioLiteFolder")
local serverFuncs= slFolder and slFolder:FindFirstChild("ServerFunctions")
local function triggerServerLoad(idStr)
    if not serverFuncs or not idStr or idStr == "" then return end
    local id = tostring(idStr):match("%d+")
    if id then pcall(function() serverFuncs:InvokeServer("LoadMeshToRuntimeMeshes", tonumber(id)) end) end
end
local SL_CACHE = {}
local function injectStudioLiteUI(scr, sourceMap)
    if not scr:IsA("LuaSourceContainer") then return end
    local path = scr.ClassName .. ":" .. scr.Name
    local realSource = sourceMap and sourceMap[path]
    if not realSource then pcall(function() realSource = scr.Source end) end
    if realSource and #realSource > 0 then
        realSource = realSource:gsub(string.char(0).."*$", "")
    else
        realSource = "-- [MAULZZ×BRYAN] Source tidak ditemukan."
    end
    _G.MAULZZ_RAW_SOURCES[scr] = realSource
    local UI_TEXT = realSource
    if #UI_TEXT > 150000 then
        UI_TEXT = "-- [MAULZZ×BRYAN Warning] Source terlalu panjang.\n\n" .. string.sub(UI_TEXT, 1, 150000) .. "\n\n... [TERPOTONG]"
    end
    local existingTB = scr:FindFirstChild("SL_CodeTextBox")
    if existingTB then
        existingTB.Text = UI_TEXT
        if scr.ClassName == "ModuleScript" then
            local ro = scr:FindFirstChild("SL_1ReadOnly")
            if ro then ro.ContentText = UI_TEXT; ro.Text = UI_TEXT end
        end
        return
    end
    if not serverFuncs then return end
    local map = { Script = "InsertScriptScript", LocalScript = "InsertLocalScriptLocalScript", ModuleScript = "InsertModuleScriptModuleScript" }
    local assetName= map[scr.ClassName]
    if not assetName then return end
    if not SL_CACHE[assetName] then
        pcall(function()
            serverFuncs:InvokeServer("LoadAssetToPlayerGui", assetName)
            local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
            local guiF = PlayerGui:WaitForChild(assetName, 3)
            if guiF then
                SL_CACHE[assetName] = {}
                for _, c in ipairs(guiF:GetChildren()) do table.insert(SL_CACHE[assetName], c:Clone()) end
                serverFuncs:InvokeServer("ClearAssetFromPlayerGui", assetName)
            end
        end)
    end
    if not SL_CACHE[assetName] then return end
    pcall(function()
        for _, c in ipairs(SL_CACHE[assetName]) do c:Clone().Parent = scr end
        local tb = scr:FindFirstChild("SL_CodeTextBox")
        if tb then
            tb.Text = UI_TEXT
            if scr.ClassName == "ModuleScript" then
                local ro = scr:FindFirstChild("SL_1ReadOnly")
                if ro then ro.ContentText = UI_TEXT; ro.Text = UI_TEXT end
            end
        end
    end)
end
local function injectAllScripts(root, sourceMap)
    if not root then return 0 end
    local list = {}
    if root:IsA("LuaSourceContainer") then table.insert(list, root) end
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("LuaSourceContainer") then table.insert(list, d) end
    end
    local count = 0
    for _, s in ipairs(list) do
        pcall(injectStudioLiteUI, s, sourceMap); count = count + 1; task.wait(0.02)
    end
    return count
end
-- ============================================
-- ★★★ MODIFIKASI: STABIL TAPI BISA DIGESER ★★★
-- ============================================
local function ApplyStudioLiteProperties(obj)
    if not obj then return end
    pcall(function()
        if obj:IsA("BasePart") then
            if obj:GetAttribute("SL_Anchored") == nil then
                obj:SetAttribute("SL_Anchored", obj.Anchored)
            end
            if obj:GetAttribute("SL_CanCollide") == nil then
                obj:SetAttribute("SL_CanCollide", obj.CanCollide)
            end
        end
    end)
    for _, child in ipairs(obj:GetChildren()) do ApplyStudioLiteProperties(child) end
end
local function LoadAssetsToSLServer(obj)
    local function scan(node)
        pcall(function()
            if node:IsA("MeshPart") then triggerServerLoad(node.MeshId); triggerServerLoad(node.TextureID)
            elseif node:IsA("Decal") or node:IsA("Texture") then triggerServerLoad(node.Texture)
            elseif node:IsA("SpecialMesh") then triggerServerLoad(node.MeshId); triggerServerLoad(node.TextureId)
            elseif node:IsA("Clothing") or node:IsA("ShirtGraphic") then
                triggerServerLoad(node.ClassName == "ShirtGraphic" and node.Graphic or node[node.ClassName.."Template"])
            elseif node:IsA("UnionOperation") or node:IsA("PartOperation") then triggerServerLoad(node.AssetId) end
        end)
        for _, child in ipairs(node:GetChildren()) do scan(child) end
    end
    scan(obj)
end
local SVC_MAP = {
    Workspace = workspace,
    ReplicatedStorage = ReplicatedStorage,
    ReplicatedFirst = game:GetService("ReplicatedFirst"),
    StarterGui = game:GetService("StarterGui"),
    StarterPack = game:GetService("StarterPack"),
    StarterPlayer = game:GetService("StarterPlayer"),
    Lighting = game:GetService("Lighting"),
    SoundService = game:GetService("SoundService"),
    ServerScriptService = _G.sss or ReplicatedStorage,
    ServerStorage = _G.ss or ReplicatedStorage,
    Teams = ReplicatedStorage,
    Chat = ReplicatedStorage,
}
local function insertObjects(objects, isRbxl, sourceMap)
    local count = 0
    for _, obj in ipairs(objects) do
        pcall(function()
            local target = (isRbxl and (SVC_MAP[obj.ClassName] or SVC_MAP[obj.Name])) or workspace
            if target == workspace and obj:IsA("Service") then target = ReplicatedStorage end
            if isRbxl and target ~= workspace then
                for _, ch in ipairs(obj:GetChildren()) do
                    pcall(function()
                        ch.Parent = target
                        injectAllScripts(ch, sourceMap)
                        ApplyStudioLiteProperties(ch)
                        LoadAssetsToSLServer(ch)
                        count = count + 1
                    end)
                    task.wait(0.01)
                end
            else
                obj.Parent = target
                injectAllScripts(obj, sourceMap)
                ApplyStudioLiteProperties(obj)
                LoadAssetsToSLServer(obj)
                count = count + 1
            end
        end)
    end
    return count
end
-- ============================================
-- SAFE ANCHOR SYSTEM (MODIFIED)
-- Mencegah roboh saat spawn, tapi memungkinkan interaksi
-- ============================================
local function IsPlayerCharacter(inst)
    local char = LocalPlayer.Character
    return char and inst:IsDescendantOf(char)
end
local function SafeAnchor(part)
    if not part:IsA("BasePart") or IsPlayerCharacter(part) then return end
    pcall(function()
        for _, child in ipairs(part:GetDescendants()) do
            if child:IsA("JointInstance") or child:IsA("Constraint") or child:IsA("BodyMover") then
                child:Destroy()
            end
        end
        part.Anchored = true
        part.CanCollide = true
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)
end
Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("BasePart") then
        task.spawn(function()
            task.wait()
            SafeAnchor(desc)
        end)
    end
end)
-- ============================================
-- FILE SCANNER (Delta WORKSPACE SCAN_PATHS)
-- ============================================
local SCAN_PATHS = {
    -- Delta's virtual executor workspace (most important)
    "workspace",
    "Delta/workspace",
    "delta/workspace",

    -- Android storage fallbacks
    "/storage/emulated/0/Delta/workspace",
    "/storage/emulated/0/Delta/Workspace",
    "/sdcard/Delta/workspace",
    "/sdcard/Delta/Workspace",
    "/sdcard/Android/Delta/workspace",
    "Android/Delta/workspace",

    -- Other common executor workspace aliases
    "../workspace",
    ".",
    "",
    "models",
    "rbxm",
    "downloads",
    "fluxus",
    "KRNL Scripts",
    "Electron",
    "Hydrogen",
}
local function safeReadFile(p)
    if not readfile then return nil end
    local ok, d = pcall(readfile, p)
    return ok and d or nil
end
local function safeListFiles(p)
    if not listfiles then return nil end
    local ok, f = pcall(listfiles, p)
    return ok and f or nil
end
local function getFileName(p)
    local s = tostring(p):gsub("\\", "/"):gsub("%s+$", "")
    return s:match("([^/]+)$") or s
end

local function getFileType(n)
    n = tostring(n):lower():gsub("%s+$", "")
    if n:match("%.rbxl$") or n:match("%.rbxlx$") then
        return "RBXL"
    elseif n:match("%.rbxm$") or n:match("%.rbxmx$") then
        return "RBXM"
    end
    return nil
end
local function looksFolder(p) return not getFileName(p):match("%.[%a%d]+") end
local function scanDeep(folder, depth, results, seen)
    if depth > 6 or seen[folder] then return end
    seen[folder] = true

    local list = safeListFiles(folder)
    if type(list) ~= "table" then return end

    for _, rawPath in ipairs(list) do
        local path = tostring(rawPath)
        local name = getFileName(path)
        local ftype = getFileType(name)

        if ftype and not seen[path] then
            seen[path] = true

            -- listfiles() is enough to display a file.
            -- Do not discard it when readfile() cannot read the
            -- same path representation.
            local content = safeReadFile(path)
            local sizeFormatted = "RBXM"

            if type(content) == "string" and #content > 0 then
                if #content < 1024 then
                    sizeFormatted = tostring(#content) .. " B"
                elseif #content < 1048576 then
                    sizeFormatted = string.format("%.1f KB", #content / 1024)
                else
                    sizeFormatted = string.format("%.1f MB", #content / 1048576)
                end
            end

            local ext = name:lower():match("%.([^%.]+)$") or "rbxm"

            table.insert(results, {
                name = name,
                path = path,
                ftype = ftype,
                folder = folder,
                ext = ext,
                icon = "📦",
                sizeFormatted = sizeFormatted,
                readable = type(content) == "string" and #content > 0,
            })

        elseif looksFolder(path) then
            scanDeep(path, depth + 1, results, seen)
        end
    end
end
local function scanAll()
    local results, seen = {}, {}
    local readableRoots = {}

    for _, p in ipairs(SCAN_PATHS) do
        local list = safeListFiles(p)

        if type(list) == "table" then
            table.insert(readableRoots, p)
            scanDeep(p, 0, results, seen)
        end
    end

    -- Some Delta builds expose the workspace as a virtual root
    -- and return absolute paths from listfiles(). Those files are
    -- still accepted; only the extension determines what is shown.
    return results, readableRoots
end
-- ============================================
-- LOAD FILE — FULL FALLBACK CHAIN (import logic)
-- ============================================
local function loadFile(fileInfo)
    local isRbxl = fileInfo.ftype == "RBXL"
    local data = safeReadFile(fileInfo.path)
    if not data or #data == 0 then return false, "readfile gagal: " .. tostring(fileInfo.path) end
    local sourceMap = {}
    if not isRbxl then
        local ok, sources, err = pcall(parseRBXMForSources, data)
        if ok and sources then sourceMap = sources end
    end
    if getcustomasset then
        local ok1, aid = pcall(getcustomasset, fileInfo.path)
        if ok1 and aid and aid ~= "" then
            local ok2, objs = pcall(function() return game:GetObjects(aid) end)
            if ok2 and objs and #objs > 0 then
                return true, insertObjects(objs, isRbxl, sourceMap) .. " object(s) loaded"
            end
        end
    end
    local ok3, o3 = pcall(function() return game:GetObjects("rbxasset://" .. fileInfo.path) end)
    if ok3 and o3 and #o3 > 0 then
        return true, insertObjects(o3, isRbxl, sourceMap) .. " object(s) loaded"
    end
    if getcustomasset and writefile then
        local tempName = "maulzz_temp_" .. tostring(tick()):gsub("%.", "") .. ".rbxm"
        local tempPaths = {
            "workspace/" .. tempName,
            "Delta/workspace/" .. tempName,
            tempName,
        }
        for _, tp in ipairs(tempPaths) do
            local wOk = pcall(writefile, tp, data)
            if wOk then
                local ok4, aid2 = pcall(getcustomasset, tp)
                if ok4 and aid2 and aid2 ~= "" then
                    local ok5, objs2 = pcall(function() return game:GetObjects(aid2) end)
                    pcall(delfile or function() end, tp)
                    if ok5 and objs2 and #objs2 > 0 then
                        return true, insertObjects(objs2, isRbxl, sourceMap) .. " object(s) loaded"
                    end
                else
                    pcall(delfile or function() end, tp)
                end
            end
        end
    end
    return false, "Semua metode load gagal untuk: " .. tostring(fileInfo.path)
end
-- ============================================
-- HOOKS — Anti-Putus Studio Lite (importer utility)
-- ============================================
task.spawn(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if not checkcaller() and method == "InvokeServer" then
                if self.Name == "GetScriptSourceServerFunction" then
                    local target = tostring(args[1])
                    for obj, src in pairs(_G.MAULZZ_RAW_SOURCES) do
                        if typeof(obj) == "Instance" and (obj.ClassName .. obj.Name) == target then
                            if src and src ~= "" then return src end
                        end
                    end
                    for _, place in ipairs({
                        workspace, ReplicatedStorage, _G.sss, _G.ss,
                        game:GetService("StarterGui"), game:GetService("StarterPlayer"),
                        LocalPlayer:FindFirstChild("PlayerGui"), LocalPlayer:FindFirstChild("Backpack")
                    }) do
                        if place then
                            for _, obj in ipairs(place:GetDescendants()) do
                                if obj:IsA("LuaSourceContainer") and (obj.ClassName .. obj.Name) == target then
                                    local src = _G.MAULZZ_RAW_SOURCES[obj]
                                    if src and src ~= "" then return src end
                                end
                            end
                        end
                    end
                end
                if self.Name == "SaveScriptSourceServerFunction" then
                    local target = tostring(args[1])
                    local newSource = tostring(args[2])
                    for obj, _ in pairs(_G.MAULZZ_RAW_SOURCES) do
                        if typeof(obj) == "Instance" and (obj.ClassName .. obj.Name) == target then
                            _G.MAULZZ_RAW_SOURCES[obj] = newSource; break
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end
    if hookfunction then
        local oldRequire
        oldRequire = hookfunction(getrenv().require or require, function(module)
            if typeof(module) == "Instance" and module:IsA("ModuleScript") then
                local src = _G.MAULZZ_RAW_SOURCES[module]
                if src and src ~= "" then
                    local func, err = loadstring(src)
                    if func then
                        local success, result = pcall(func)
                        if success then return result end
                    end
                end
            end
            return oldRequire(module)
        end)
        local oldGetObjects
        oldGetObjects = hookfunction(game.GetObjects, function(self, url, ...)
            local assetId = tostring(url):match("%d+")
            if assetId then triggerServerLoad(assetId) end
            local objects = oldGetObjects(self, url, ...)
            if objects then
                for _, obj in ipairs(objects) do
                    pcall(function() injectAllScripts(obj, {}) end)
                    pcall(function() ApplyStudioLiteProperties(obj) end)
                    pcall(function() LoadAssetsToSLServer(obj) end)
                end
            end
            return objects
        end)
        local oldLoadAsset
        oldLoadAsset = hookfunction(InsertService.LoadAsset, function(self, assetId, ...)
            triggerServerLoad(tostring(assetId))
            local obj = oldLoadAsset(self, assetId, ...)
            if obj then
                pcall(function() injectAllScripts(obj, {}) end)
                pcall(function() ApplyStudioLiteProperties(obj) end)
                pcall(function() LoadAssetsToSLServer(obj) end)
            end
            return obj
        end)
    end
end)
-- ============================================
-- UI BUILDER — MAULZZ×BRYAN IMPORTER V00.8 STYLE
-- ============================================
-- 0. TOMBOL GUI MAULZZ×BRYAN
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "MAULZZToggleBtn"
toggleBtn.Size = UDim2.new(0, 50, 0, 32)
toggleBtn.Position = UDim2.new(0, 15, 0.45, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 19)
toggleBtn.Text = "M×B"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 10
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Visible = true
toggleBtn.Parent = screenGui
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn
local toggleStroke = Instance.new("UIStroke")
toggleStroke.Thickness = 1
toggleStroke.Color = Color3.fromRGB(40, 40, 45)
toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
toggleStroke.Parent = toggleBtn
UIState.toggleButton = toggleBtn
-- ============================================
-- ============================================
-- 1. PANEL UTAMA (150 x 250)
-- ============================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainImporterFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 480)
mainFrame.Position = UDim2.new(0.5, -150, 0.12, 0)
mainFrame.BackgroundColor3 = PALETTE.Background
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Visible = true
mainFrame.Parent = screenGui
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame
applyYellowBlueRGBBorder(mainFrame, 2)
UIState.mainFrame = mainFrame
-- Header Bar
local topBarFrame = Instance.new("Frame")
topBarFrame.Size = UDim2.new(1, 0, 0, 22)
topBarFrame.BackgroundTransparency = 1
topBarFrame.Parent = mainFrame
local headerImage = Instance.new("ImageLabel")
headerImage.Size = UDim2.new(0, 30, 0, 30)
headerImage.Position = UDim2.new(0, 4, 0, 25)
headerImage.BackgroundTransparency = 1
headerImage.Image = "rbxassetid://78851330031113"
headerImage.ScaleType = Enum.ScaleType.Fit
headerImage.Parent = mainFrame
local headerImage2 = Instance.new("ImageLabel")
headerImage2.Size = UDim2.new(1, -42, 0, 30)
headerImage2.Position = UDim2.new(0, 38, 0, 25)
headerImage2.BackgroundColor3 = PALETTE.CardBg
headerImage2.BackgroundTransparency = 0.15
headerImage2.Image = "rbxassetid://135292644233722"
headerImage2.ImageTransparency = 0.2
headerImage2.ScaleType = Enum.ScaleType.Crop
headerImage2.Parent = mainFrame
local headerImageCorner = Instance.new("UICorner")
headerImageCorner.CornerRadius = UDim.new(0, 4)
headerImageCorner.Parent = headerImage2
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -25, 1, 0)
titleLabel.Position = UDim2.new(0, 6, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MAULZZ×BRYAN IMPORTER"
titleLabel.TextColor3 = PALETTE.TextWhite
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 8
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBarFrame
local closeMainBtn = Instance.new("TextButton")
closeMainBtn.Size = UDim2.new(0, 14, 0, 14)
closeMainBtn.Position = UDim2.new(1, -18, 0, 4)
closeMainBtn.BackgroundColor3 = PALETTE.AccentRed
closeMainBtn.Text = "X"
closeMainBtn.TextColor3 = PALETTE.TextWhite
closeMainBtn.Font = Enum.Font.GothamBold
closeMainBtn.TextSize = 7
closeMainBtn.Parent = topBarFrame
local closeMainCorner = Instance.new("UICorner")
closeMainCorner.CornerRadius = UDim.new(0, 3)
closeMainCorner.Parent = closeMainBtn
closeMainBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)
toggleBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)
-- Running Text Banner
local marqueeContainer = Instance.new("Frame")
marqueeContainer.Size = UDim2.new(1, -12, 0, 14)
marqueeContainer.Position = UDim2.new(0, 6, 0, 58)
marqueeContainer.BackgroundColor3 = PALETTE.CardBg
marqueeContainer.ClipsDescendants = true
marqueeContainer.Parent = mainFrame
local marqueeCorner = Instance.new("UICorner")
marqueeCorner.CornerRadius = UDim.new(0, 3)
marqueeCorner.Parent = marqueeContainer
local marqueeText = Instance.new("TextLabel")
marqueeText.Size = UDim2.new(0, 400, 1, 0)
marqueeText.Position = UDim2.new(1, 0, 0, 0)
marqueeText.BackgroundTransparency = 1
marqueeText.Text = "★ MAULZZ×BRYAN ★ IMPORT FILE RBXM ★ MAULZZ×BRYAN ★ IMPORT FILE RBXM ★"
marqueeText.TextColor3 = PALETTE.AccentGold
marqueeText.Font = Enum.Font.GothamBold
marqueeText.TextSize = 6.5
marqueeText.TextXAlignment = Enum.TextXAlignment.Left
marqueeText.Parent = marqueeContainer
local marqueeSpeed = 35
RunService.RenderStepped:Connect(function(dt)
    if marqueeText.Position.X.Offset <= -marqueeText.AbsoluteSize.X / 2 then
        marqueeText.Position = UDim2.new(1, 0, 0, 0)
    else
        marqueeText.Position = marqueeText.Position - UDim2.new(0, marqueeSpeed * dt, 0, 0)
    end
end)
-- Navigasi Tombol Header
local btnHeaderFrame = Instance.new("Frame")
btnHeaderFrame.Size = UDim2.new(1, -12, 0, 18)
btnHeaderFrame.Position = UDim2.new(0, 6, 0, 78)
btnHeaderFrame.BackgroundTransparency = 1
btnHeaderFrame.Parent = mainFrame
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0.31, 0, 1, 0)
refreshBtn.Position = UDim2.new(0, 0, 0, 0)
refreshBtn.BackgroundColor3 = PALETTE.AccentBlue
refreshBtn.Text = "🔄 SCAN"
refreshBtn.TextColor3 = PALETTE.TextWhite
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = 5.5
refreshBtn.Parent = btnHeaderFrame
local refCorner = Instance.new("UICorner")
refCorner.CornerRadius = UDim.new(0, 3)
refCorner.Parent = refreshBtn
local openSizeBtn = Instance.new("TextButton")
openSizeBtn.Size = UDim2.new(0.31, 0, 1, 0)
openSizeBtn.Position = UDim2.new(0.345, 0, 0, 0)
openSizeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
openSizeBtn.Text = "⚙️ UKURAN"
openSizeBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
openSizeBtn.Font = Enum.Font.GothamBold
openSizeBtn.TextSize = 5.5
openSizeBtn.Parent = btnHeaderFrame
local openSizeCorner = Instance.new("UICorner")
openSizeCorner.CornerRadius = UDim.new(0, 3)
openSizeCorner.Parent = openSizeBtn
local openMusicBtn = Instance.new("TextButton")
openMusicBtn.Size = UDim2.new(0.31, 0, 1, 0)
openMusicBtn.Position = UDim2.new(0.69, 0, 0, 0)
openMusicBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
openMusicBtn.Text = "🎵 MUSIK"
openMusicBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
openMusicBtn.Font = Enum.Font.GothamBold
openMusicBtn.TextSize = 5.5
openMusicBtn.Parent = btnHeaderFrame
local openMusicCorner = Instance.new("UICorner")
openMusicCorner.CornerRadius = UDim.new(0, 3)
openMusicCorner.Parent = openMusicBtn
-- Search Bar
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -12, 0, 16)
searchBox.Position = UDim2.new(0, 6, 0, 99)
searchBox.BackgroundColor3 = PALETTE.InputBg
searchBox.PlaceholderText = "🔍 Cari File..."
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
searchBox.PlaceholderColor3 = PALETTE.TextMuted
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 6.5
searchBox.Parent = mainFrame
local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 3)
searchCorner.Parent = searchBox
UIState.searchBox = searchBox
-- Scroll File Area
local scrollList = Instance.new("ScrollingFrame")
scrollList.Size = UDim2.new(1, -12, 1, -132)
scrollList.Position = UDim2.new(0, 6, 0, 118)
scrollList.BackgroundColor3 = PALETTE.CardBg
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 2
scrollList.ScrollBarImageColor3 = PALETTE.AccentCyan
scrollList.Parent = mainFrame
local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 4)
listCorner.Parent = scrollList
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 3)
listLayout.Parent = scrollList
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollList.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
end)
UIState.scrollFrame = scrollList
-- Footer Status
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -12, 0, 12)
statusLabel.Position = UDim2.new(0, 6, 1, -13)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready - tekan SCAN"
statusLabel.TextColor3 = PALETTE.AccentGreen
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 6.5
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame
UIState.statusLabel = statusLabel
-- ============================================
-- 2. SIZE ADJUSTER PANEL (130 x 105)
-- ============================================
local sizeFrame = Instance.new("Frame")
sizeFrame.Name = "SizeAdjusterSeparate"
sizeFrame.Size = UDim2.new(0, 130, 0, 105)
sizeFrame.Position = UDim2.new(0.32, 0, 0.22, 0)
sizeFrame.BackgroundColor3 = PALETTE.Background
sizeFrame.Active = true
sizeFrame.Draggable = true
sizeFrame.ClipsDescendants = true
sizeFrame.Visible = false
sizeFrame.Parent = screenGui
local sizeCorner = Instance.new("UICorner")
sizeCorner.CornerRadius = UDim.new(0, 8)
sizeCorner.Parent = sizeFrame
applyYellowBlueRGBBorder(sizeFrame, 2)
UIState.sizeFrame = sizeFrame
local sizeTitle = Instance.new("TextLabel")
sizeTitle.Size = UDim2.new(1, -22, 0, 14)
sizeTitle.Position = UDim2.new(0, 6, 0, 2)
sizeTitle.BackgroundTransparency = 1
sizeTitle.Text = "UKURAN PANEL"
sizeTitle.TextColor3 = PALETTE.TextWhite
sizeTitle.Font = Enum.Font.GothamBold
sizeTitle.TextSize = 7
sizeTitle.TextXAlignment = Enum.TextXAlignment.Left
sizeTitle.Parent = sizeFrame
local closeSizeBtn = Instance.new("TextButton")
closeSizeBtn.Size = UDim2.new(0, 11, 0, 11)
closeSizeBtn.Position = UDim2.new(1, -14, 0, 3)
closeSizeBtn.BackgroundColor3 = PALETTE.AccentRed
closeSizeBtn.Text = "X"
closeSizeBtn.TextColor3 = PALETTE.TextWhite
closeSizeBtn.Font = Enum.Font.GothamBold
closeSizeBtn.TextSize = 6
closeSizeBtn.Parent = sizeFrame
local closeSizeCorner = Instance.new("UICorner")
closeSizeCorner.CornerRadius = UDim.new(0, 3)
closeSizeCorner.Parent = closeSizeBtn
openSizeBtn.MouseButton1Click:Connect(function()
    sizeFrame.Visible = not sizeFrame.Visible
end)
closeSizeBtn.MouseButton1Click:Connect(function()
    sizeFrame.Visible = false
end)
local function createSlider(yPos, labelText, defaultVal, minVal, maxVal, onChange)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.3, 0, 0, 10)
    label.Position = UDim2.new(0, 6, 0, yPos)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = PALETTE.TextMuted
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 6
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = sizeFrame
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(0.2, 0, 0, 10)
    valueLabel.Position = UDim2.new(1, -20, 0, yPos)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 6
    valueLabel.Parent = sizeFrame
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -48, 0, 3)
    track.Position = UDim2.new(0, 32, 0, yPos + 3)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    track.Parent = sizeFrame
    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track
    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 6, 0, 6)
    knob.Position = UDim2.new((defaultVal - minVal)/(maxVal - minVal), -3, 0.5, -3)
    knob.BackgroundColor3 = Color3.fromRGB(240, 190, 40)
    knob.Text = ""
    knob.Parent = track
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob
    local dragging = false
    knob.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local mousePos = input.Position.X
            local trackPos = track.AbsolutePosition.X
            local trackSize = track.AbsoluteSize.X
            local relativeX = math.clamp(mousePos - trackPos, 0, trackSize)
            local percent = relativeX / trackSize
            local calculatedValue = math.floor(minVal + (maxVal - minVal) * percent)
            knob.Position = UDim2.new(percent, -3, 0.5, -3)
            valueLabel.Text = tostring(calculatedValue)
            onChange(calculatedValue)
        end
    end)
    return function(newVal)
        local percent = (newVal - minVal)/(maxVal - minVal)
        knob.Position = UDim2.new(percent, -3, 0.5, -3)
        valueLabel.Text = tostring(newVal)
        onChange(newVal)
    end
end
local setWidthSlider = createSlider(20, "Lebar", 150, 120, 350, function(val)
    mainFrame.Size = UDim2.new(0, val, 0, mainFrame.Size.Y.Offset)
end)
local setHeightSlider = createSlider(44, "Tinggi", 250, 160, 450, function(val)
    mainFrame.Size = UDim2.new(0, mainFrame.Size.X.Offset, 0, val)
end)
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1, -12, 0, 15)
resetBtn.Position = UDim2.new(0, 6, 1, -18)
resetBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
resetBtn.Text = "RESET (150 x 250)"
resetBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 6
resetBtn.Parent = sizeFrame
local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 3)
resetCorner.Parent = resetBtn
resetBtn.MouseButton1Click:Connect(function()
    setWidthSlider(150)
    setHeightSlider(250)
end)
-- ============================================
-- 3. MUSIC PANEL (150 x 250)
-- ============================================
local musicFrame = Instance.new("Frame")
musicFrame.Name = "MusicPlayerSeparate"
musicFrame.Size = UDim2.new(0, 150, 0, 250)
musicFrame.Position = UDim2.new(0.52, 0, 0.22, 0)
musicFrame.BackgroundColor3 = PALETTE.Background
musicFrame.Active = true
musicFrame.Draggable = true
musicFrame.ClipsDescendants = true
musicFrame.Visible = false
musicFrame.Parent = screenGui
local musicCorner = Instance.new("UICorner")
musicCorner.CornerRadius = UDim.new(0, 8)
musicCorner.Parent = musicFrame
applyYellowBlueRGBBorder(musicFrame, 2)
UIState.musicFrame = musicFrame
local musicTitle = Instance.new("TextLabel")
musicTitle.Size = UDim2.new(1, -25, 0, 18)
musicTitle.Position = UDim2.new(0, 6, 0, 2)
musicTitle.BackgroundTransparency = 1
musicTitle.Text = "🎵 MUSIK & JADWAL SOLAT"
musicTitle.TextColor3 = PALETTE.TextWhite
musicTitle.Font = Enum.Font.GothamBold
musicTitle.TextSize = 6.5
musicTitle.TextXAlignment = Enum.TextXAlignment.Left
musicTitle.Parent = musicFrame
local closeMusicBtn = Instance.new("TextButton")
closeMusicBtn.Size = UDim2.new(0, 14, 0, 14)
closeMusicBtn.Position = UDim2.new(1, -18, 0, 4)
closeMusicBtn.BackgroundColor3 = PALETTE.AccentRed
closeMusicBtn.Text = "X"
closeMusicBtn.TextColor3 = PALETTE.TextWhite
closeMusicBtn.Font = Enum.Font.GothamBold
closeMusicBtn.TextSize = 7
closeMusicBtn.Parent = musicFrame
local closeMusicCorner = Instance.new("UICorner")
closeMusicCorner.CornerRadius = UDim.new(0, 3)
closeMusicCorner.Parent = closeMusicBtn
openMusicBtn.MouseButton1Click:Connect(function()
    musicFrame.Visible = not musicFrame.Visible
end)
closeMusicBtn.MouseButton1Click:Connect(function()
    musicFrame.Visible = false
end)
-- Clock & Prayer Info Card
local infoCard = Instance.new("Frame")
infoCard.Size = UDim2.new(1, -12, 0, 58)
infoCard.Position = UDim2.new(0, 6, 0, 22)
infoCard.BackgroundColor3 = PALETTE.CardBg
infoCard.Parent = musicFrame
local infoCorner = Instance.new("UICorner")
infoCorner.CornerRadius = UDim.new(0, 5)
infoCorner.Parent = infoCard
local clockTimeLabel = Instance.new("TextLabel")
clockTimeLabel.Size = UDim2.new(0.48, 0, 0, 14)
clockTimeLabel.Position = UDim2.new(0, 4, 0, 14)
clockTimeLabel.BackgroundTransparency = 1
clockTimeLabel.Text = "00:00:00"
clockTimeLabel.TextColor3 = PALETTE.TextWhite
clockTimeLabel.Font = Enum.Font.GothamBold
clockTimeLabel.TextSize = 7.5
clockTimeLabel.TextXAlignment = Enum.TextXAlignment.Center
clockTimeLabel.Parent = infoCard
local clockZoneLabel = Instance.new("TextLabel")
clockZoneLabel.Size = UDim2.new(0.48, 0, 0, 12)
clockZoneLabel.Position = UDim2.new(0, 4, 0, 28)
clockZoneLabel.BackgroundTransparency = 1
clockZoneLabel.Text = "WIB"
clockZoneLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
clockZoneLabel.Font = Enum.Font.GothamMedium
clockZoneLabel.TextSize = 6.5
clockZoneLabel.TextXAlignment = Enum.TextXAlignment.Center
clockZoneLabel.Parent = infoCard
local divider = Instance.new("Frame")
divider.Size = UDim2.new(0, 1, 0.8, 0)
divider.Position = UDim2.new(0.48, 0, 0.1, 0)
divider.BackgroundColor3 = PALETTE.InnerBorder
divider.BorderSizePixel = 0
divider.Parent = infoCard
local solatTimesLabel = Instance.new("TextLabel")
solatTimesLabel.Size = UDim2.new(0.5, 0, 1, -6)
solatTimesLabel.Position = UDim2.new(0.5, 0, 0, 3)
solatTimesLabel.BackgroundTransparency = 1
solatTimesLabel.Text = "Subuh 04:30\nDzuhur 12:00\nAshar 15:15\nMaghrib 18:00\nIsya 19:15"
solatTimesLabel.TextColor3 = Color3.fromRGB(170, 180, 195)
solatTimesLabel.Font = Enum.Font.GothamMedium
solatTimesLabel.TextSize = 5.5
solatTimesLabel.TextXAlignment = Enum.TextXAlignment.Right
solatTimesLabel.Parent = infoCard
task.spawn(function()
    while task.wait(1) do
        local date = os.date("!*t", os.time() + 7 * 3600)
        clockTimeLabel.Text = string.format("%02d:%02d:%02d", date.hour, date.min, date.sec)
    end
end)
-- Music Player
local currentSound = Instance.new("Sound")
currentSound.Name = "CustomMusicPlayer"
currentSound.Volume = 2
currentSound.Looped = true
currentSound.Parent = SoundService
local musicListScroll = Instance.new("ScrollingFrame")
musicListScroll.Size = UDim2.new(1, -12, 1, -112)
musicListScroll.Position = UDim2.new(0, 6, 0, 84)
musicListScroll.BackgroundTransparency = 1
musicListScroll.BorderSizePixel = 0
musicListScroll.ScrollBarThickness = 2
musicListScroll.Parent = musicFrame
local musicLayout = Instance.new("UIListLayout")
musicLayout.Padding = UDim.new(0, 4)
musicLayout.Parent = musicListScroll
local songs = {
    {Name = "Black Hole", Id = "rbxassetid://118362297271903"},
    {Name = "Macarena", Id = "rbxassetid://93497396408206"}
}
local currentPlayingBtn = nil
for _, songData in pairs(songs) do
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 22)
    card.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    card.Parent = musicListScroll
    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 3)
    cCorner.Parent = card
    local nameLab = Instance.new("TextLabel")
    nameLab.Size = UDim2.new(0.6, 0, 1, 0)
    nameLab.Position = UDim2.new(0, 4, 0, 0)
    nameLab.BackgroundTransparency = 1
    nameLab.Text = "🎵 " .. songData.Name
    nameLab.TextColor3 = Color3.fromRGB(220, 220, 220)
    nameLab.Font = Enum.Font.GothamBold
    nameLab.TextSize = 6
    nameLab.TextXAlignment = Enum.TextXAlignment.Left
    nameLab.Parent = card
    local playBtn = Instance.new("TextButton")
    playBtn.Size = UDim2.new(0.35, 0, 0.75, 0)
    playBtn.Position = UDim2.new(0.62, 0, 0.125, 0)
    playBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    playBtn.Text = "▶ PLAY"
    playBtn.TextColor3 = PALETTE.TextWhite
    playBtn.Font = Enum.Font.GothamBold
    playBtn.TextSize = 6
    playBtn.Parent = card
    local playCorner = Instance.new("UICorner")
    playCorner.CornerRadius = UDim.new(0, 3)
    playCorner.Parent = playBtn
    playBtn.MouseButton1Click:Connect(function()
        if currentSound.SoundId == songData.Id and currentSound.IsPlaying then
            currentSound:Stop()
            playBtn.Text = "▶ PLAY"
            playBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        else
            if currentPlayingBtn then
                currentPlayingBtn.Text = "▶ PLAY"
                currentPlayingBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
            end
            currentSound:Stop()
            currentSound.SoundId = songData.Id
            currentSound:Play()
            playBtn.Text = "⏸ STOP"
            playBtn.BackgroundColor3 = PALETTE.AccentRed
            currentPlayingBtn = playBtn
        end
    end)
end
local stopAllBtn = Instance.new("TextButton")
stopAllBtn.Size = UDim2.new(1, -12, 0, 18)
stopAllBtn.Position = UDim2.new(0, 6, 1, -24)
stopAllBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
stopAllBtn.Text = "⏹ MATIKAN MUSIK"
stopAllBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
stopAllBtn.Font = Enum.Font.GothamBold
stopAllBtn.TextSize = 6.5
stopAllBtn.Parent = musicFrame
local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 4)
stopCorner.Parent = stopAllBtn
stopAllBtn.MouseButton1Click:Connect(function()
    currentSound:Stop()
    if currentPlayingBtn then
        currentPlayingBtn.Text = "▶ PLAY"
        currentPlayingBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        currentPlayingBtn = nil
    end
end)
-- ============================================
-- MAIN CONTROLLER
-- ============================================
function MaulzzBryanImporter:TogglePanel(forceState)
    if forceState ~= nil then UIState.panelVisible = forceState
    else UIState.panelVisible = not UIState.panelVisible end
    if UIState.mainFrame then UIState.mainFrame.Visible = UIState.panelVisible end
end
function MaulzzBryanImporter:ScanFiles()
    if UIState.isScanning then return end
    UIState.isScanning = true
    if UIState.statusLabel then UIState.statusLabel.Text = "⏳ Scanning..." end
    task.spawn(function()
        local files = scanAll()
        UIState.detectedFiles = files
        self:RefreshFileList()
        if UIState.statusLabel then
            if #files > 0 then
                UIState.statusLabel.Text = "✅ Total: " .. #files .. " Files"
            else
                UIState.statusLabel.Text = "⚠ Workspace terbaca, 0 RBXM"
            end
        end
        UIState.isScanning = false
    end)
end
function MaulzzBryanImporter:RefreshFileList()
    if not UIState.scrollFrame then return end
    for _, child in ipairs(UIState.scrollFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local list = UIState.detectedFiles
    if UIState.currentFilter ~= "" then
        local filtered = {}
        for _, f in ipairs(list) do
            if string.find(string.lower(f.name), string.lower(UIState.currentFilter), 1, true) then
                table.insert(filtered, f)
            end
        end
        list = filtered
    end
    for _, data in ipairs(list) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -4, 0, 22)
        card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
        card.Parent = UIState.scrollFrame
        local cCorner = Instance.new("UICorner")
        cCorner.CornerRadius = UDim.new(0, 3)
        cCorner.Parent = card
        local textLab = Instance.new("TextLabel")
        textLab.Size = UDim2.new(0.62, 0, 1, 0)
        textLab.Position = UDim2.new(0, 4, 0, 0)
        textLab.BackgroundTransparency = 1
        textLab.Text = "🔖 " .. data.name
        textLab.TextColor3 = Color3.fromRGB(200, 200, 200)
        textLab.Font = Enum.Font.GothamMedium
        textLab.TextSize = 6
        textLab.TextXAlignment = Enum.TextXAlignment.Left
        textLab.TextTruncate = Enum.TextTruncate.AtEnd
        textLab.Parent = card
        local insertBtn = Instance.new("TextButton")
        insertBtn.Size = UDim2.new(0.33, 0, 0.75, 0)
        insertBtn.Position = UDim2.new(0.64, 0, 0.125, 0)
        insertBtn.BackgroundColor3 = PALETTE.AccentCyan
        insertBtn.Text = "INSERT"
        insertBtn.TextColor3 = PALETTE.TextDark
        insertBtn.Font = Enum.Font.GothamBold
        insertBtn.TextSize = 6
        insertBtn.Parent = card
        local iCorner = Instance.new("UICorner")
        iCorner.CornerRadius = UDim.new(0, 3)
        iCorner.Parent = insertBtn
        insertBtn.MouseButton1Click:Connect(function()
            MaulzzBryanImporter:LoadFile(data)
        end)
    end
end
function MaulzzBryanImporter:LoadFile(fileData)
    if UIState.statusLabel then UIState.statusLabel.Text = "⏳ Importing..." end
    task.spawn(function()
        local success, msg = loadFile(fileData)
        if success then
            if UIState.statusLabel then UIState.statusLabel.Text = "✅ " .. tostring(msg) end
        else
            local shortErr = string.sub(tostring(msg), 1, 30)
            if UIState.statusLabel then UIState.statusLabel.Text = "❌ " .. shortErr end
            warn("[MAULZZ×BRYAN RBXM] Gagal: " .. tostring(msg))
        end
        task.wait(3)
        if UIState.statusLabel then UIState.statusLabel.Text = "Ready - tekan SCAN" end
    end)
end
-- Search filter
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    UIState.currentFilter = searchBox.Text
    MaulzzBryanImporter:RefreshFileList()
end)
-- Scan button
refreshBtn.MouseButton1Click:Connect(function()
    MaulzzBryanImporter:ScanFiles()
end)
-- ============================================
-- INIT
-- ============================================
function MaulzzBryanImporter:Init()
    print("★ MAULZZ×BRYAN RBXM IMPORTER READY")
end
MaulzzBryanImporter:Init()
return MaulzzBryanImporter
