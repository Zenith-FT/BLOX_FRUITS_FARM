-- ============================================================
-- MAIN BLOX FRUITS - tout-en-un
--   1. Auto-select team Pirates
--   2. Auto-farm fruits (tween vers les Tools sur la map)
--   3. Auto-store fruits (slot 12 visible >1s -> sequence store)
--   4. Notifier "plus de fruits sur la map"
--   5. Notifier "fruit recupere" (slot 12 invisible -> visible)
--   6. Serverhop si plus de fruits pendant X sec (via __ServerBrowser)
-- ============================================================

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local TweenS      = game:GetService("TweenService")

local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui")

-- >>> CONFIG <<<
local TEAM              = "Pirates"
local FARM_MAX_SPEED    = 500    -- vitesse max du tween en studs/s
local FARM_SCAN_WAIT    = 2      -- pause entre 2 scans de la map

-- serverhop
local HOP_TIMEOUT       = 10     -- secondes sans fruit avant de hop
local SELF_URL          = "https://github.com/Zenith-FT/BLOX_FRUITS_FARM/blob/main/BLOX_FRUITS.lua"     -- URL de CE script pour relance auto (optionnel)

local MaxPlayers        = Players.MaxPlayers
local teleportQueue     = queue_on_teleport or (syn and syn.queue_on_teleport)

===

task.wait(5)

-- ============================================================
-- 0. FAST MODE (optimisation map) avant de rejoindre
-- ============================================================
local function clickFastMode()
    local mainGui = playerGui:WaitForChild("Main (minimal)", 10)
    if not mainGui then warn("[FastMode] 'Main (minimal)' introuvable") return end
    local chooseTeam = mainGui:WaitForChild("ChooseTeam", 10)
    if not chooseTeam then warn("[FastMode] ChooseTeam introuvable") return end
    local btn = chooseTeam:WaitForChild("FastModeButton", 10)
    if not btn then warn("[FastMode] FastModeButton introuvable") return end

    if type(firesignal) == "function" then
        local fired = false
        for _, sig in ipairs({ "Activated", "MouseButton1Click" }) do
            local ok = pcall(function() firesignal(btn[sig]) end)
            if ok then fired = true end
        end
        if fired then
            print("[FastMode] active")
        else
            warn("[FastMode] echec fire signal")
        end
    else
        warn("[FastMode] firesignal indispo sur cet executor")
    end
end

-- ============================================================
-- 1. AUTO-SELECT TEAM
-- ============================================================
local function autoSelectTeam()
    repeat task.wait() until player:FindFirstChild("DataLoaded")
    local ok = pcall(function()
        RS:WaitForChild("Remotes").CommF_:InvokeServer("SetTeam2", TEAM)
    end)
    if not ok then
        task.wait(1)
        return autoSelectTeam()
    end
    repeat task.wait() until player.Character
        and player.Character:IsDescendantOf(workspace.Characters)
    print("[Main] team " .. TEAM .. " selectionnee")
end

clickFastMode()    -- optimise la map d'abord
autoSelectTeam()   -- puis rejoint en Pirates

-- ============================================================
-- GUI PARTAGE + helper toast
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FruitNotifier"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function makeToast(shownY, bgColor, glowA, glowB, dotColor, textColor, defaultText)
    local hiddenPos = UDim2.new(0.5, 0, 0, -90)
    local shownPos  = UDim2.new(0.5, 0, 0, shownY)

    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(0.5, 0)
    toast.Size = UDim2.new(0, 300, 0, 52)
    toast.Position = hiddenPos
    toast.BackgroundColor3 = bgColor
    toast.BackgroundTransparency = 0.1
    toast.Parent = gui
    Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", toast)
    stroke.Thickness = 2
    stroke.Transparency = 0.1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local sGrad = Instance.new("UIGradient", stroke)
    sGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, glowA),
        ColorSequenceKeypoint.new(1, glowB),
    }

    local dot = Instance.new("Frame", toast)
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.new(0, 16, 0.5, 0)
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.BackgroundColor3 = dotColor
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel", toast)
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 36, 0, 0)
    label.Size = UDim2.new(1, -46, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = defaultText
    label.TextColor3 = textColor
    label.TextSize = 15

    TweenS:Create(stroke,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Thickness = 3.5, Transparency = 0.35}
    ):Play()

    return { frame = toast, label = label, hiddenPos = hiddenPos, shownPos = shownPos }
end

local function slideIn(t, msg)
    if msg then t.label.Text = msg end
    t.frame.Position = t.hiddenPos
    TweenS:Create(t.frame,
        TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = t.shownPos}
    ):Play()
end

local function slideOut(t)
    TweenS:Create(t.frame,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = t.hiddenPos}
    ):Play()
end

-- toast #1 : plus de fruits (bleu -> violet)
local toastEmpty = makeToast(22,
    Color3.fromRGB(14, 14, 24),
    Color3.fromRGB(80, 170, 255), Color3.fromRGB(175, 90, 255),
    Color3.fromRGB(150, 110, 255), Color3.fromRGB(230, 230, 255),
    "Plus de fruits sur la map")

-- toast #2 : fruit recupere (teal -> bleu)
local toastPick = makeToast(84,
    Color3.fromRGB(14, 20, 20),
    Color3.fromRGB(60, 255, 190), Color3.fromRGB(90, 200, 255),
    Color3.fromRGB(80, 255, 200), Color3.fromRGB(225, 255, 245),
    "Fruit recupere")

local pickHideThread
local function popCollected(msg)
    if pickHideThread then task.cancel(pickHideThread) end
    slideIn(toastPick, msg)
    pickHideThread = task.delay(2.5, function() slideOut(toastPick) end)
end

-- ============================================================
-- DETECTION FRUITS SUR LA MAP (Tools)
-- ============================================================
local function fruitsOnMap()
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Tool") then return true end
    end
    return false
end

-- ============================================================
-- 4. NOTIFIER "plus de fruits sur la map"
-- ============================================================
task.spawn(function()
    local emptyVisible = false
    while true do
        task.wait(1)
        local has = fruitsOnMap()
        if not has and not emptyVisible then
            emptyVisible = true
            slideIn(toastEmpty, "Plus de fruits sur la map")
        elseif has and emptyVisible then
            emptyVisible = false
            slideOut(toastEmpty)
        end
    end
end)

-- ============================================================
-- 2. AUTO-FARM FRUITS (tween HRP vers chaque Tool sur la map)
--    Resiste a la mort : detecte le deces, annule le tween,
--    attend le respawn, puis repart chercher les fruits restants.
-- ============================================================

-- retourne (hrp, humanoid) seulement si le perso est VIVANT
local function getLiveHRP()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp, hum
end

-- attend qu'un perso vivant soit dispo (apres mort/respawn)
local function waitForLiveChar()
    while true do
        local hrp = getLiveHRP()
        if hrp then return hrp end
        task.wait(0.3)
    end
end

task.spawn(function()
    while true do
        task.wait(FARM_SCAN_WAIT)

        -- si mort, attend le respawn avant de continuer (ne s'arrete jamais)
        if not getLiveHRP() then
            waitForLiveChar()
        end

        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA("Tool") and v:FindFirstChild("Handle") then
                local hrp = getLiveHRP()
                if not hrp then
                    break   -- mort en cours de pass -> on ressort, le respawn est gere en haut
                end

                -- duree = distance / vitesse max, pour ne jamais depasser 500 studs/s.
                -- Easing Linear = vitesse constante (sinon le pic depasserait la moyenne).
                local dist = (v.Handle.Position - hrp.Position).Magnitude
                local tweenTime = math.max(dist / FARM_MAX_SPEED, 0.1)

                local tween = TweenS:Create(hrp,
                    TweenInfo.new(tweenTime, Enum.EasingStyle.Linear),
                    { CFrame = v.Handle.CFrame })
                tween:Play()

                -- attente interruptible : on bail si on meurt ou si le fruit disparait
                local elapsed = 0
                while elapsed < tweenTime + 1 do
                    task.wait(0.2)
                    elapsed += 0.2
                    if not getLiveHRP() then
                        tween:Cancel()   -- mort -> stop le tween mort
                        break
                    end
                    if not v.Parent then
                        break            -- fruit ramasse / disparu -> passe au suivant
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- 6. SERVERHOP (via le remote __ServerBrowser du jeu)
-- ============================================================
local __ServerBrowser = RS:WaitForChild("__ServerBrowser")

-- blacklist temporaire des serveurs deja visites (expire apres BLACKLIST_TTL)
local BLACKLIST_TTL = 300   -- 5 minutes
local hopBlacklist = getgenv().__bfHopBlacklist or {}
getgenv().__bfHopBlacklist = hopBlacklist   -- persiste a travers un re-exec / relance

local function isBlacklisted(job)
    local expiry = hopBlacklist[job]
    if not expiry then return false end
    if os.clock() > expiry then
        hopBlacklist[job] = nil   -- expire -> nettoie
        return false
    end
    return true
end

local function blacklistServer(job)
    hopBlacklist[job] = os.clock() + BLACKLIST_TTL
end

local function getServers()
    local all, done = {}, 0
    for i = 1, 100 do
        task.spawn(function()
            local ok, res = pcall(function() return __ServerBrowser:InvokeServer(i) end)
            if ok and res then
                for job, info in pairs(res) do all[job] = info end
            end
            done += 1
        end)
    end
    repeat task.wait() until done >= 100
    return all
end

local hopping = false
local function serverHop()
    if hopping then return end
    hopping = true
    print("[ServerHop] recuperation des serveurs...")

    -- relance auto au nouveau serveur (si SELF_URL renseignee)
    if type(teleportQueue) == "function" and SELF_URL ~= "" then
        teleportQueue([[
            loadstring(game:HttpGet("]] .. SELF_URL .. [["))()
        ]])
        print("[ServerHop] script mis en file pour relance auto")
    end

    local currentJob = __ServerBrowser:InvokeServer("getjob")
    blacklistServer(currentJob)      -- le serveur actuel est blacklist pour 5min
    local tried = {}                 -- serveurs deja tentes CE cycle (pleins / rates)
    local MAX_TRIES = 8
    local CONFIRM_WAIT = 6           -- secondes d'attente pour confirmer le hop

    for attempt = 1, MAX_TRIES do
        -- refetch a chaque essai : les counts changent (un serveur peut se vider/remplir)
        local servers = getServers()

        local candidates = {}
        for job, info in pairs(servers) do
            local count = tonumber(info.Count)
            if job ~= currentJob and not tried[job] and not isBlacklisted(job)
                and count and count < MaxPlayers then
                table.insert(candidates, { job = job, count = count })
            end
        end

        if #candidates == 0 then
            warn("[ServerHop] aucun serveur dispo (essai " .. attempt .. ")")
            task.wait(2)
            continue
        end

        -- privilegie les serveurs les moins remplis (moins de risque qu'il soit plein)
        table.sort(candidates, function(a, b) return a.count < b.count end)
        local pick = candidates[math.random(1, math.min(5, #candidates))]  -- top 5 les plus vides
        local chosen = pick.job
        tried[chosen] = true
        blacklistServer(chosen)      -- blacklist des qu'on le tente

        print(("[ServerHop] essai %d -> %s (%d joueurs)"):format(attempt, chosen, pick.count))
        pcall(function()
            __ServerBrowser:InvokeServer("teleport", chosen)
        end)

        -- si le hop reussit, le jeu unload et ce code s'arrete de tourner.
        -- si on est toujours la apres CONFIRM_WAIT -> le hop a rate (serveur plein), on retry.
        task.wait(CONFIRM_WAIT)
        warn("[ServerHop] toujours dans le serveur -> hop rate, retry...")
    end

    warn("[ServerHop] echec apres " .. MAX_TRIES .. " essais")
    hopping = false
end

-- timer : hop si plus de fruits pendant HOP_TIMEOUT secondes
task.spawn(function()
    local timeLeft = HOP_TIMEOUT
    while true do
        task.wait(1)
        if fruitsOnMap() then
            if timeLeft ~= HOP_TIMEOUT then
                print("[Timer] Fruit detecte -> reset a " .. HOP_TIMEOUT)
            end
            timeLeft = HOP_TIMEOUT
        else
            timeLeft -= 1
            print("[Timer] " .. timeLeft)
            if timeLeft <= 0 then
                print("[Timer] " .. HOP_TIMEOUT .. "s sans fruit -> serverhop !")
                serverHop()
                break
            end
        end
    end
end)

-- ============================================================
-- 3. AUTO-STORE : helpers
-- ============================================================
-- trouve le Tool fruit (celui qui a un EatRemote) dans le Backpack ou le Character
local function findFruitTool()
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("EatRemote") then
                return t
            end
        end
    end
    local char = player.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t:FindFirstChild("EatRemote") then
                return t
            end
        end
    end
    return nil
end

-- ============================================================
-- 3. AUTO-STORE via remote CommF_ "StoreFruit" (fiable, zero clic)
--    Le fruit doit etre EQUIPE (dans Character) pour que le store passe.
-- ============================================================
local CommF = RS:WaitForChild("Remotes"):WaitForChild("CommF_")

local busy = false
local function runStoreSequence(fruit)
    if busy then return end
    busy = true

    -- resout le fruit si non fourni
    fruit = fruit or findFruitTool()
    if not (fruit and fruit:FindFirstChild("EatRemote")) then
        warn("[Store] aucun fruit a stocker")
        busy = false
        return
    end

    local char = player.Character
    if not char then
        warn("[Store] pas de character")
        busy = false
        return
    end

    -- garde du jeu : le fruit doit etre dans le Character (equipe).
    -- s'il est dans le Backpack, on l'equipe d'abord.
    if fruit.Parent ~= char then
        fruit.Parent = char
        task.wait(0.3)
    end

    local originalName = fruit:GetAttribute("OriginalName") or fruit.Name

    local ok, result = pcall(function()
        return CommF:InvokeServer("StoreFruit", originalName, fruit)
    end)

    if not ok then
        warn("[Store] echec InvokeServer : " .. tostring(result))
    elseif result == true then
        print("[Store] fruit stocke : " .. tostring(originalName))
    elseif type(result) == "number" then
        warn("[Store] stockage plein (capacite " .. tostring(result) .. ")")
    else
        warn("[Store] retour inattendu : " .. tostring(result))
    end

    busy = false
end

-- ============================================================
-- 5. DETECTEUR NOUVEAU FRUIT (par reference d'instance)
--    Remplace le hack du slot 12. Zero faux positif sur
--    equip/desequip, respawn, changement de sea, teleport.
--    -> notifier "fruit recupere" + trigger auto-store.
-- ============================================================
local backpack = player:WaitForChild("Backpack")

-- un fruit stockable = Tool avec EatRemote + nom finissant par " Fruit"
local function isUneatenFruit(tool)
    return tool:IsA("Tool")
        and tool:FindFirstChild("EatRemote") ~= nil
        and tool.Name:sub(-6) == " Fruit"
end

-- table a cles faibles : on stocke les REFERENCES d'instance (pas les noms)
local knownFruits = setmetatable({}, { __mode = "k" })

-- seed : marque les fruits deja presents comme connus (pas de trigger dessus)
local function seedKnownFruits()
    for _, container in ipairs({ backpack, player.Character }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if isUneatenFruit(tool) then
                    knownFruits[tool] = true
                end
            end
        end
    end
end
seedKnownFruits()

-- callback : un fruit apparait dans un conteneur
local function onFruitAdded(fruit)
    if not isUneatenFruit(fruit) then return end
    if knownFruits[fruit] then
        -- meme instance qui bouge (equip/desequip) -> ignorer
        return
    end
    knownFruits[fruit] = true

    -- NOUVEAU FRUIT confirme
    local original = fruit:GetAttribute("OriginalName") or fruit.Name
    print("[fruit] NOUVEAU : " .. fruit.Name .. " (" .. tostring(original) .. ")")

    popCollected("Fruit recupere : " .. tostring(original))
    task.spawn(function() runStoreSequence(fruit) end)
end

-- listener Backpack
backpack.ChildAdded:Connect(onFruitAdded)

-- listener Character (reconnecte a chaque respawn)
local charConn
local function connectChar()
    if charConn then charConn:Disconnect() charConn = nil end
    local char = player.Character
    if not char then return end
    charConn = char.ChildAdded:Connect(onFruitAdded)
end
connectChar()

-- respawn : reconnecte le Character + rescan (le Backpack persiste)
player.CharacterAdded:Connect(function(newChar)
    connectChar()
    for _, container in ipairs({ backpack, newChar }) do
        for _, tool in ipairs(container:GetChildren()) do
            if isUneatenFruit(tool) and not knownFruits[tool] then
                knownFruits[tool] = true   -- present apres respawn, pas un pickup
            end
        end
    end
end)

-- nettoyage : retire du set les fruits qui quittent DEFINITIVEMENT l'inventaire
-- (manges, jetes, vendus). Delai pour ignorer les moves equip/desequip.
local function onFruitRemoved(fruit)
    if not (fruit:IsA("Tool") and fruit:FindFirstChild("EatRemote")) then return end
    task.delay(0.5, function()
        if fruit.Parent ~= backpack and fruit.Parent ~= player.Character then
            knownFruits[fruit] = nil
        end
    end)
end
backpack.ChildRemoved:Connect(onFruitRemoved)
if player.Character then
    player.Character.ChildRemoved:Connect(onFruitRemoved)
end

print("[Main] tous les modules lances")
