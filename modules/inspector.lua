-- Dragonsz | Inspector Module v2
-- Ao mirar em NPC/Player: mostra informacoes detalhadas
-- Clique direito para fixar (pinnar) o alvo

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Inspector = {}

local scanConn    = nil
local clickConn   = nil
local onDataReady = nil

local function safe(fn, fallback)
    local ok, v = pcall(fn)
    return (ok and v ~= nil) and v or fallback
end

local function getLevel(model)
    local keywords = {"Level","level","Nivel","nivel","LVL","lvl","Rank","rank","Lv","lv"}
    for _, name in ipairs(keywords) do
        local v = safe(function() return model:FindFirstChild(name, true) end)
        if v and safe(function() return v:IsA("IntValue") or v:IsA("NumberValue") end, false) then
            return tostring(safe(function() return v.Value end, "?"))
        end
    end
    local statFolders = {"leaderstats","Stats","stats","Data","data"}
    for _, fname in ipairs(statFolders) do
        local folder = safe(function() return model:FindFirstChild(fname, true) end)
        if folder then
            for _, child in ipairs(safe(function() return folder:GetChildren() end, {})) do
                local n = safe(function() return child.Name:lower() end, "")
                if n:find("level") or n:find("nivel") or n:find("rank") or n:find("lvl") then
                    return tostring(safe(function() return child.Value end, "?"))
                end
            end
        end
    end
    return "?"
end

local function getHP(model)
    local hum = safe(function() return model:FindFirstChildOfClass("Humanoid") end)
    if not hum then return "?" end
    local hp  = safe(function() return math.floor(hum.Health) end, 0)
    local max = safe(function() return math.floor(hum.MaxHealth) end, 0)
    return hp .. " / " .. max
end

local function getWalkSpeed(model)
    local hum = safe(function() return model:FindFirstChildOfClass("Humanoid") end)
    if not hum then return "?" end
    return tostring(safe(function() return hum.WalkSpeed end, "?"))
end

local function getWeapons(model)
    local weapons = {}
    local plr = safe(function() return Players:GetPlayerFromCharacter(model) end)
    if plr then
        local bp = safe(function() return plr:FindFirstChildOfClass("Backpack") end)
        if bp then
            for _, t in ipairs(safe(function() return bp:GetChildren() end, {})) do
                if safe(function() return t:IsA("Tool") end, false) then
                    table.insert(weapons, safe(function() return t.Name end, "?"))
                end
            end
        end
    end
    for _, t in ipairs(safe(function() return model:GetChildren() end, {})) do
        if safe(function() return t:IsA("Tool") end, false) then
            table.insert(weapons, safe(function() return t.Name end, "?") .. " [EQ]")
        end
    end
    return #weapons > 0 and weapons or {"Nenhuma"}
end

local function getAnimations(model)
    local found = {}
    local animator = nil
    local hum = safe(function() return model:FindFirstChildOfClass("Humanoid") end)
    if hum then
        animator = safe(function() return hum:FindFirstChildOfClass("Animator") end)
    end
    if not animator then
        local ctrl = safe(function() return model:FindFirstChildOfClass("AnimationController") end)
        if ctrl then
            animator = safe(function() return ctrl:FindFirstChildOfClass("Animator") end)
        end
    end
    if animator then
        local tracks = safe(function() return animator:GetPlayingAnimationTracks() end, {})
        for _, t in ipairs(tracks) do
            local name = safe(function() return t.Name end, "")
            if name == "" then
                name = safe(function()
                    return tostring(t.Animation and t.Animation.AnimationId or "?")
                end, "?")
            end
            name = name:gsub("rbxassetid://",""):gsub("https://www%.roblox%.com/asset/%?id=","")
            local spd = safe(function() return string.format("%.1f", t.Speed) end, "?")
            table.insert(found, name .. " (spd:" .. spd .. ")")
        end
    end
    return #found > 0 and found or {"Nenhuma tocando"}
end

local function getSkills(model)
    local skills = {}
    local folders = {"Skills","Abilities","Attacks","Moves","Spells","Powers",
                     "skills","abilities","attacks","moves","spells"}
    for _, fname in ipairs(folders) do
        local folder = safe(function() return model:FindFirstChild(fname, true) end)
        if folder then
            for _, child in ipairs(safe(function() return folder:GetChildren() end, {})) do
                local n = safe(function() return child.Name end, "")
                if n ~= "" then table.insert(skills, n) end
            end
        end
    end
    return #skills > 0 and skills or {"Nao detectadas"}
end

local function getStats(model)
    local result = {}
    local statFolders = {"Stats","stats","leaderstats","Attributes","Data","data","Values"}
    for _, fname in ipairs(statFolders) do
        local f = safe(function() return model:FindFirstChild(fname, true) end)
        if f then
            for _, child in ipairs(safe(function() return f:GetChildren() end, {})) do
                local isVal = safe(function()
                    return child:IsA("IntValue") or child:IsA("NumberValue")
                        or child:IsA("StringValue") or child:IsA("BoolValue")
                end, false)
                if isVal then
                    local n = safe(function() return child.Name end, "?")
                    local v = safe(function() return tostring(child.Value) end, "?")
                    table.insert(result, n .. ": " .. v)
                end
            end
        end
    end
    local attrs = safe(function() return model:GetAttributes() end, {})
    for k, v in pairs(attrs) do
        table.insert(result, "[Attr] " .. tostring(k) .. ": " .. tostring(v))
    end
    return #result > 0 and result or {"Nenhuma stat encontrada"}
end

local function getTeam(model)
    local plr = safe(function() return Players:GetPlayerFromCharacter(model) end)
    if plr then
        local team = safe(function() return plr.Team end)
        return team and safe(function() return team.Name end, "Sem time") or "Sem time"
    end
    local tag = safe(function()
        return model:FindFirstChild("Team") or model:FindFirstChild("team") or model:FindFirstChild("Faction")
    end)
    if tag then
        return tostring(safe(function() return tag.Value end) or safe(function() return tag.Name end) or "?")
    end
    return "NPC"
end

local function getDistance(model, localPlayer)
    local lc   = safe(function() return localPlayer.Character end)
    if not lc then return "?" end
    local lhrp = safe(function() return lc:FindFirstChild("HumanoidRootPart") end)
    local thrp = safe(function()
        return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
    end)
    if not lhrp or not thrp then return "?" end
    local dist = safe(function() return (lhrp.Position - thrp.Position).Magnitude end)
    return dist and string.format("%.1f studs", dist) or "?"
end

local function buildData(model, localPlayer)
    local plr  = safe(function() return Players:GetPlayerFromCharacter(model) end)
    local dname = plr and safe(function() return plr.DisplayName end, "") or ""
    local name  = (dname ~= "") and dname or safe(function() return model.Name end, "?")
    return {
        name       = name,
        kind       = plr and "Player" or "NPC",
        username   = plr and ("@" .. safe(function() return plr.Name end, "?")) or safe(function() return model.Name end, "?"),
        level      = getLevel(model),
        hp         = getHP(model),
        walkspeed  = getWalkSpeed(model),
        distance   = getDistance(model, localPlayer),
        team       = getTeam(model),
        weapons    = getWeapons(model),
        animations = getAnimations(model),
        skills     = getSkills(model),
        stats      = getStats(model),
    }
end

local function getTargetModel(camera, localPlayer)
    local vp  = safe(function() return camera.ViewportSize end)
    if not vp then return nil end
    local ray = safe(function() return camera:ScreenPointToRay(vp.X/2, vp.Y/2) end)
    if not ray then return nil end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = safe(function() return localPlayer.Character end)
    if char then params.FilterDescendantsInstances = {char} end

    local result = safe(function() return workspace:Raycast(ray.Origin, ray.Direction * 600, params) end)
    if not result then return nil end

    local hit = safe(function() return result.Instance end)
    if not hit then return nil end

    local model = hit
    local limit = 0
    while model and limit < 10 do
        local hum = safe(function() return model:FindFirstChildOfClass("Humanoid") end)
        if hum and model ~= char then return model end
        model = safe(function() return model.Parent end)
        limit = limit + 1
    end
    return nil
end

function Inspector.start(localPlayer, camera, callback)
    onDataReady = callback
    local lastModel = nil
    local timer = 0

    scanConn = RunService.Heartbeat:Connect(function(dt)
        timer = timer + dt
        if timer < 0.3 then return end
        timer = 0
        local ok, model = pcall(getTargetModel, camera, localPlayer)
        if not ok then model = nil end
        if model ~= lastModel then
            lastModel = model
            if onDataReady then
                if model then
                    local ok2, data = pcall(buildData, model, localPlayer)
                    onDataReady(ok2 and data or nil)
                else
                    onDataReady(nil)
                end
            end
        end
    end)

    clickConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            local ok, model = pcall(getTargetModel, camera, localPlayer)
            if ok and model and onDataReady then
                local ok2, data = pcall(buildData, model, localPlayer)
                if ok2 and data then
                    data.pinned = true
                    onDataReady(data)
                end
            end
        end
    end)

    print("[Dragonsz] Inspector iniciado.")
end

function Inspector.stop()
    if scanConn  then scanConn:Disconnect();  scanConn  = nil end
    if clickConn then clickConn:Disconnect(); clickConn = nil end
    onDataReady = nil
    print("[Dragonsz] Inspector encerrado.")
end

function Inspector.inspect(model, localPlayer)
    local ok, data = pcall(buildData, model, localPlayer)
    return ok and data or nil
end

return Inspector
