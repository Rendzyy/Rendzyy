-- ========== FULL CHECKPOINT HUB (Visual UI) with Protector, Diagnostic, Bypass ==========
-- Run in executor (Arceus X / Synapse etc). Use privately.

-- Load Visual UI Library
local ok, Visual = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/bimoraa/Visual/refs/heads/main/library.lua"))()
end)
if not ok or not Visual then
    warn("[Checkpoint Hub] Failed to load Visual UI library.")
    return
end

-- Create Window
local winName = "Checkpoint Hub"
local win = Visual:Create(winName)

-- Tabs
local tabTele = win:Tab("Teleports", 0)
local tabFarm = win:Tab("Autofarm", 0)
local tabSet  = win:Tab("Settings", 0)
local tabDiag = win:Tab("Diagnostics", 0)

local player = game.Players.LocalPlayer
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

-- TELEPORT FUNCTION
local function teleportTo(pos)
    local char = player.Character or player.CharacterAdded:Wait()
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(pos)
    end
end

-- CHECKPOINTS (ordered)
local checkpoints = {
    {"Checkpoint 1", Vector3.new(-663.6, 59.3, -443.1)},
    {"Checkpoint 2", Vector3.new(-46.0, 43.3, -555.4)},
    {"Checkpoint 3", Vector3.new(832.9, 67.3, -426.7)},
    {"Checkpoint 4", Vector3.new(1014.9, 72.0, -110.0)},
    {"Checkpoint 5", Vector3.new(2089.7, 71.3, -146.7)},
    {"Checkpoint 6", Vector3.new(2331.0, 63.6, -139.0)},
    {"Checkpoint 7", Vector3.new(2547.5, 43.2, -413.3)},
    {"Checkpoint 8", Vector3.new(2684.6, 87.4, -333.9)},
    {"Checkpoint 9", Vector3.new(2713.3, 159.1, -363.0)},
    {"Checkpoint 10", Vector3.new(3037.5, 155.3, -365.7)},
    {"Checkpoint 11", Vector3.new(3230.2, -4.5, -336.8)},
    {"Checkpoint 12", Vector3.new(3668.1, 23.5, -220.2)},
    {"Checkpoint 13", Vector3.new(3725.0, 91.3, -246.9)},
    {"Checkpoint 14", Vector3.new(3965.6, 67.6, -308.3)},
    {"Checkpoint 15", Vector3.new(4432.9, 83.9, -309.9)},
    {"Checkpoint 16", Vector3.new(4522.5, 87.3, -282.3)},
}

-- populate Teleports tab
for _, data in ipairs(checkpoints) do
    local name, pos = data[1], data[2]
    tabTele:Button(name, function()
        teleportTo(pos)
    end)
end

-- ========== AUTOFARM ==========
local autofarmEnabled = false
tabFarm:Button("Start AutoFarm", function()
    if autofarmEnabled then return end
    autofarmEnabled = true
    task.spawn(function()
        while autofarmEnabled do
            for _, d in ipairs(checkpoints) do
                if not autofarmEnabled then break end
                teleportTo(d[2])
                task.wait(2)
            end
            task.wait(1)
        end
    end)
end)
tabFarm:Button("Stop AutoFarm", function() autofarmEnabled = false end)
tabFarm:Button("Run Once", function()
    task.spawn(function()
        for _, d in ipairs(checkpoints) do
            teleportTo(d[2])
            task.wait(2)
        end
    end)
end)

-- ========== BYPASS + PROTECTOR (auto-start) ==========
-- Configuration (ubah jika perlu)
local cp14_pos = Vector3.new(3965.6, 67.6, -308.3)
local cp14_radius = 12
local safe_offset = Vector3.new(0, 14, 0)
local explosionBlockerEnabled = false
local autoBypassEnabled = false
local explosionBlockerConn = nil
local autoprobeConn = nil

-- Aggressive health protection
local protectHealthEnabled = true
local maxHealthOverride = 1e8
local healthWatcherConn = nil
local periodicProtectThread = nil

local function protectCharacter(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    pcall(function()
        hum.MaxHealth = maxHealthOverride
        hum.Health = hum.MaxHealth
    end)
    if healthWatcherConn then pcall(healthWatcherConn.Disconnect, healthWatcherConn) end
    healthWatcherConn = hum.HealthChanged:Connect(function(h)
        -- restore instantly if drops
        if protectHealthEnabled and h < hum.MaxHealth then
            pcall(function() hum.Health = hum.MaxHealth end)
        end
    end)
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if protectHealthEnabled then protectCharacter(char) end
end)
if player.Character and protectHealthEnabled then protectCharacter(player.Character) end

-- periodic restore thread
periodicProtectThread = task.spawn(function()
    while true do
        task.wait(0.2)
        if protectHealthEnabled and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    if hum.MaxHealth ~= maxHealthOverride then hum.MaxHealth = maxHealthOverride end
                    if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
                end)
            end
        end
    end
end)

-- Explosion blocker: delete Explosion instances and suspicious parts
local function startExplosionBlocker()
    if explosionBlockerEnabled then return end
    explosionBlockerEnabled = true
    explosionBlockerConn = workspace.DescendantAdded:Connect(function(obj)
        if not explosionBlockerEnabled then return end
        -- remove Explosion instances
        if obj:IsA("Explosion") then
            pcall(function() obj:Destroy() end)
            return
        end
        -- remove suspicious parts by name pattern
        if obj:IsA("BasePart") then
            local nm = tostring(obj.Name):lower()
            if nm:match("explod") or nm:match("bomb") or nm:match("blast") or nm:match("fx") or nm:match("grenade") then
                pcall(function() obj:Destroy() end)
            end
        end
    end)
end

local function stopExplosionBlocker()
    explosionBlockerEnabled = false
    if explosionBlockerConn then pcall(function() explosionBlockerConn:Disconnect() end) end
    explosionBlockerConn = nil
end

-- Auto-bypass: when player near CP14, teleport to safe_offset
local function startAutoBypass()
    if autoBypassEnabled then return end
    autoBypassEnabled = true
    autoprobeConn = RunService.Heartbeat:Connect(function()
        if not autoBypassEnabled then return end
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist = (hrp.Position - cp14_pos).Magnitude
            if dist <= cp14_radius then
                pcall(function() hrp.CFrame = CFrame.new(cp14_pos + safe_offset) end)
                task.wait(0.6)
            end
        end
    end)
end

local function stopAutoBypass()
    autoBypassEnabled = false
    if autoprobeConn then pcall(function() autoprobeConn:Disconnect() end) end
    autoprobeConn = nil
end

-- start bypass features automatically
startExplosionBlocker()
startAutoBypass()

-- Settings UI buttons for bypass/protector
tabSet:Button("Safe TP to CP14 (offset)", function() teleportTo(cp14_pos + safe_offset) end)
tabSet:Button("Stop Explosion Blocker", function() stopExplosionBlocker() end)
tabSet:Button("Start Explosion Blocker", function() startExplosionBlocker() end)
tabSet:Button("Stop AutoBypass", function() stopAutoBypass() end)
tabSet:Button("Start AutoBypass", function() startAutoBypass() end)
tabSet:Button("Toggle Health Protect (AutoRestore)", function()
    protectHealthEnabled = not protectHealthEnabled
    if protectHealthEnabled and player.Character then protectCharacter(player.Character) end
end)

-- ========== DIAGNOSTIC MONITOR ==========
local recent = {} -- ring buffer of recent events
local function pushLog(kind, info)
    table.insert(recent, 1, {time = tick(), kind = kind, info = info})
    while #recent > 300 do table.remove(recent) end
end

-- workspace additions monitor
local monAddedConn = workspace.DescendantAdded:Connect(function(obj)
    local info = string.format("%s | Class=%s | Parent=%s", tostring(obj.Name), obj.ClassName, obj.Parent and obj.Parent.Name or "nil")
    pushLog("Added", info)
    -- also print for immediate feedback
    print("[MONITOR] Added ->", info)
    if obj:IsA("Explosion") then
        local s = ("Explosion at %s radius=%s"):format(tostring(obj.Position), tostring(obj.BlastRadius))
        pushLog("Explosion", s)
        print("[MONITOR] Explosion ->", s)
    end
end)

-- try safe namecall hook to log remote calls (exploit env only)
local nmok, nmhook = pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if tostring(self):find("RemoteEvent") or tostring(self):find("RemoteFunction") then
            pcall(function()
                pushLog("RemoteCall", tostring(self).." "..method)
                print("[MONITOR] Remote "..method.." -> "..tostring(self))
            end)
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
    return true
end)
if not nmok then
    print("[MONITOR] Namecall hook not available in this executor env.")
end

-- attach to player's humanoid to dump on death
local function attachHumanoidLogging()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.Died:Connect(function()
        print("----- MONITOR DUMP ON DEATH -----")
        print("Player died at pos:", char:FindFirstChild("HumanoidRootPart") and tostring(char.HumanoidRootPart.Position) or "n/a")
        for i = 1, math.min(80, #recent) do
            local e = recent[i]
            print(string.format("[%0.2f] %s -> %s", e.time, e.kind, e.info))
        end
        print("----- END DUMP -----")
    end)
end
player.CharacterAdded:Connect(function() task.wait(0.5); attachHumanoidLogging() end)
if player.Character then task.wait(0.5); attachHumanoidLogging() end

-- Diagnostics tab UI: show last 8 recent entries in UI as Buttons (click to print)
tabDiag:Button("Print recent logs", function()
    print("==== Recent Logs ====")
    for i = 1, math.min(120, #recent) do
        local e = recent[i]
        print(string.format("[%0.2f] %s -> %s", e.time, e.kind, e.info))
    end
    print("==== End Logs ====")
end)

-- ========== Destroy GUI (robust) ==========
tabSet:Button("Destroy GUI (safe)", function()
    -- stop active features
    autofarmEnabled = false
    stopExplosionBlocker()
    stopAutoBypass()
    protectHealthEnabled = false
    -- attempt to destroy ScreenGuis created: try common names and search patterns
    local function tryDestroyByName(n)
        for _, parent in ipairs({game:GetService("CoreGui"), player:FindFirstChild("PlayerGui")}) do
            if parent then
                local f = parent:FindFirstChild(n)
                if f then pcall(function() f:Destroy() end) end
            end
        end
    end
    tryDestroyByName(winName)
    tryDestroyByName("Visual")
    tryDestroyByName("VisualUI")
    -- search and destroy ScreenGuis by pattern
    for _, parent in ipairs({game:GetService("CoreGui"), player:FindFirstChild("PlayerGui")}) do
        if parent then
            for _, c in ipairs(parent:GetChildren()) do
                if c:IsA("ScreenGui") then
                    local nm = tostring(c.Name):lower()
                    if nm:match("checkpoint") or nm:match("teleport") or nm:match("visual") or nm:match("hub") then
                        pcall(function() c:Destroy() end)
                    end
                end
            end
        end
    end
    pcall(function() if type(win.Destroy) == "function" then win:Destroy() end end)
    print("[Checkpoint Hub] Destroy attempted.")
end)

-- initialize UI
win:Initialize()

-- quick print
print("[Checkpoint Hub] Loaded. Bypass (ExplosionBlocker + AutoBypass) started automatically.")
print("[Checkpoint Hub] Use Settings tab to Stop features or Destroy GUI.")

-- End of full script

