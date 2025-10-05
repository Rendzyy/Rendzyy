-- Visual UI + Autofarm + Manual + Working Destroy
local Visual = loadstring(game:HttpGet("https://raw.githubusercontent.com/bimoraa/Visual/refs/heads/main/library.lua"))()

-- catat ScreenGui yang ada sebelum kita initialize UI (CoreGui + PlayerGui)
local function listScreenGuis()
    local map = {}
    local player = game.Players.LocalPlayer
    local parents = { game:GetService("CoreGui") }
    if player and player:FindFirstChild("PlayerGui") then table.insert(parents, player.PlayerGui) end
    for _, parent in ipairs(parents) do
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ScreenGui") then
                map[child] = true
            end
        end
    end
    return map
end

local beforeGuis = listScreenGuis()

-- BUAT UI
local win = Visual:Create("Checkpoint Hub")
local tabTele = win:Tab("Teleports", 0)
local tabFarm = win:Tab("Autofarm", 0)
local tabSet  = win:Tab("Settings", 0)

local player = game.Players.LocalPlayer

local function teleportTo(pos)
    local char = player.Character or player.CharacterAdded:Wait()
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(pos)
    end
end

local checkpoints = {
    {"Speed Run", Vector3.new(-159.8, 30.1, -42.0)},
    {"Finish", Vector3.new(-4836.5, 218.1, 2073.1)},
}

-- manual buttons
for _, data in ipairs(checkpoints) do
    local name, pos = data[1], data[2]
    tabTele:Button(name, function()
        teleportTo(pos)
    end)
end

-- autofarm controls (Start/Stop/RunOnce)
local autofarmEnabled = false

tabFarm:Button("Start AutoFarm", function()
    if autofarmEnabled then return end
    autofarmEnabled = true
    task.spawn(function()
        while autofarmEnabled do
            for _, d in ipairs(checkpoints) do
                if not autofarmEnabled then break end
                teleportTo(d[2])
                task.wait(2) -- ubah sesuai perlu
            end
            task.wait(1)
        end
    end)
end)

tabFarm:Button("Stop AutoFarm", function()
    autofarmEnabled = false
end)

tabFarm:Button("Run Once", function()
    task.spawn(function()
        for _, d in ipairs(checkpoints) do
            teleportTo(d[2])
            task.wait(2)
        end
    end)
end)

-- initialize UI (render)
win:Initialize()

-- setelah initialize => cari ScreenGui baru yang dibuat oleh Visual
local afterMap = listScreenGuis()
local createdGuis = {}
for gObj,_ in pairs(afterMap) do
    if not beforeGuis[gObj] then
        table.insert(createdGuis, gObj)
    end
end

-- Destroy GUI yang aman: hentikan autofarm lalu buang semua ScreenGui yang baru dibuat
tabSet:Button("Destroy GUI (Safe)", function()
    autofarmEnabled = false
    -- destroy GUI objects created just now
    for _, g in ipairs(createdGuis) do
        if g and g.Parent then
            pcall(function() g:Destroy() end)
        end
    end
    -- coba juga panggil win:Destroy() jika tersedia (tidak semua versi Visual punya)
    pcall(function() if type(win.Destroy) == "function" then win:Destroy() end end)
    -- close possible notifications (beberapa lib membuat notif terpisah)
    -- attempt to clear any leftover ScreenGuis named like the window (best effort)
    pcall(function()
        for _, parent in ipairs({game:GetService("CoreGui"), player:FindFirstChild("PlayerGui")}) do
            if parent then
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("ScreenGui") and (child.Name:match("Checkpoint") or child.Name:match("Visual") or child.Name:match("Teleport")) then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end)
end)

-- alternatif: Destroy GUI instantly by name (jika kamu tahu nama ScreenGui)
tabSet:Button("Destroy by Name (Checkpoint Hub)", function()
    autofarmEnabled = false
    for _, parent in ipairs({game:GetService("CoreGui"), player:FindFirstChild("PlayerGui")}) do
        if parent then
            local found = parent:FindFirstChild("Checkpoint Hub")
            if found then pcall(function() found:Destroy() end) end
        end
    end
end)
 
