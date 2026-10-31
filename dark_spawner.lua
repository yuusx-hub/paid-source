local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

if not game:IsLoaded() then game.Loaded:Wait() end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Trove, AnimalsData, MutationsData, TraitsData, RaritiesData, AnimalsShared, NumberUtils, FastOverheadController, AnimalOverheadController, ConfirmationController, SoundController, BackpackController, NotificationController, Config, saveConfig, dropSyncCache, numToString, calcGeneration, getAnimalTemplate, AnimalAnimations, SoundsAnimals, VFX, BrainrotAssets, SpawnEffectsController, VFXRoadStartBase, postFakeLiveboardEntry, claimFakeLiveboardEntry, triggerFakeEvent, getLocalContainer, SpawnedSlots, HeldBrainrot, PlacePrompts, myPlotChannel, activeFakeSlots, hudConnections, fakeExtra, hudPatchInited, resolveMyPlot, getPlotModel, getPlayerChannel, getMaxSlots, addToFakeIndex
do
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Synchronizer = require(Packages.Synchronizer)
Trove = require(Packages.Trove)
local Datas = ReplicatedStorage:WaitForChild("Datas")
AnimalsData = require(Datas.Animals)
MutationsData = require(Datas.Mutations)
TraitsData = require(Datas.Traits)
RaritiesData = require(Datas.Rarities)
local BasesData = require(Datas.Bases)
AnimalsShared = require(ReplicatedStorage.Shared.Animals)
NumberUtils = require(ReplicatedStorage.Utils.NumberUtils)
FastOverheadController = require(ReplicatedStorage.Controllers.FastOverheadController)
AnimalOverheadController = require(ReplicatedStorage.Controllers.AnimalOverheadController)

ConfirmationController = require(ReplicatedStorage.Controllers.ConfirmationController)
SoundController = require(ReplicatedStorage.Controllers.SoundController)
BackpackController = require(ReplicatedStorage.Controllers.BackpackController)
NotificationController = nil
pcall(function()
    NotificationController = require(
        ReplicatedStorage.Controllers.NotificationController)
end)
local AnimalModels = ReplicatedStorage:WaitForChild("Models"):WaitForChild("Animals")

local CONFIG_PATH = "dark_spawner_config.json"
Config = {
    autoLoad  = false,
    layout    = {},
    fakeIndex = {},
    recent    = {},
    last      = {},
    hotkey    = false,
    window    = false,
}

local function loadConfig()
    if not (readfile and isfile) then return end
    local ok, raw = pcall(function()
        return isfile(CONFIG_PATH) and readfile(CONFIG_PATH) or nil
    end)
    if not ok or not raw then return end
    local ok2, parsed = pcall(HttpService.JSONDecode, HttpService, raw)
    if ok2 and type(parsed) == "table" then
        for k, v in pairs(parsed) do Config[k] = v end
    end
    if type(Config.layout) ~= "table" then Config.layout = {} end
    if type(Config.fakeIndex) ~= "table" then Config.fakeIndex = {} end
    if type(Config.recent) ~= "table" then Config.recent = {} end
    if type(Config.last) ~= "table" then Config.last = {} end
    for name, v in pairs(Config.fakeIndex) do
        if type(v) ~= "table" then Config.fakeIndex[name] = { Default = true } end
    end
end
loadConfig()

local saveQueued = false
function saveConfig()
    if saveQueued or not writefile then return end
    saveQueued = true
    task.delay(0.5, function()
        saveQueued = false
        local ok, json = pcall(HttpService.JSONEncode, HttpService, Config)
        if ok then pcall(writefile, CONFIG_PATH, json) end
    end)
end

local syncCache = {}

local function syncTable(key, fresh)
    if not fresh then
        local cached = syncCache[key]
        if cached then return cached end
    end
    local prev = getthreadidentity and getthreadidentity() or nil
    if setthreadidentity then pcall(setthreadidentity, 8) end
    local ok, data = pcall(Synchronizer.GetTableFromChannel, Synchronizer, key)
    if setthreadidentity then pcall(setthreadidentity, prev or 8) end
    if ok and type(data) == "table" then
        syncCache[key] = data
        return data
    end
    syncCache[key] = nil
    return nil
end

function dropSyncCache(key)
    if key == nil then table.clear(syncCache) else syncCache[key] = nil end
end

local channels = {}
local watchers = {}
local watcherRunning = false

local function signature(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts, n = {}, 0
    for k, e in pairs(v) do
        n += 1
        parts[n] = tostring(k) .. "="
            .. (type(e) == "table"
                and (tostring(e.UUID or e.Index) .. tostring(e.Mutation))
                or tostring(e))
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function startWatcherLoop()
    if watcherRunning then return end
    watcherRunning = true
    task.spawn(function()
        local tickN = 0
        while true do
            task.wait(0.3)
            tickN += 1
            if tickN % 16 == 0 then
                for _, w in ipairs(watchers) do syncCache[w.key] = nil end
            end
            for _, w in ipairs(watchers) do
                local cur = signature(w.ch:Get(w.path))
                if cur ~= w.last then
                    w.last = cur
                    local v = w.ch:Get(w.path)
                    for _, fn in ipairs(w.fns) do task.spawn(fn, v) end
                end
            end
        end
    end)
end

local function addWatcher(ch, path, fn)
    for _, w in ipairs(watchers) do
        if w.ch == ch and w.path == path then
            table.insert(w.fns, fn)
            return
        end
    end
    table.insert(watchers, {
        ch = ch, key = ch.Key, path = path, fns = { fn },
        last = signature(ch:Get(path)),
    })
    startWatcherLoop()
end

local function makeChannel(key)
    local ch = channels[key]
    if ch then return ch end
    ch = { Key = key }
    function ch:Get(path)
        local t = syncTable(key)
        if not t then return nil end
        if type(path) == "table" then
            for _, k in ipairs(path) do
                if type(t) ~= "table" then return nil end
                t = t[k]
            end
            return t
        end
        return t[path]
    end

    function ch:OnChanged(path, fn)
        addWatcher(self, path, fn)
    end
    channels[key] = ch
    return ch
end

local _numSuffixes = {"","K","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc","Ud","Dd","Td","Qad","Qid","Sxd","Spd","Ocd","Nod","Vg","Uvg","Dvg","Tvg"}
function numToString(n, decimals)
    decimals = decimals or 1
    local abs = math.abs(n); local mag = math.max(1, abs)
    local tier = math.floor(math.log(mag, 1000))
    local suffix = _numSuffixes[tier + 1] or ("e+" .. tier)
    local scaled = n * (10 ^ decimals / 1000 ^ tier)
    local floored = math.floor(scaled) / 10 ^ decimals
    return (("%." .. decimals .. "f"):format(floored)):gsub("%.?0+$", "") .. suffix
end

function calcGeneration(animalName, mutation, traits)
    local entry = AnimalsData[animalName]; if not entry then return 0 end
    local base = entry.Generation or (entry.Price * 0.1); local mult = 1
    if mutation and mutation ~= "None" then
        local m = MutationsData[mutation]
        if m and m.Modifier then mult = mult + m.Modifier end
    end
    local sleepy = false
    if type(traits) == "table" then
        for _, t in ipairs(traits) do
            if t == "Sleepy" then sleepy = true
            else local te = TraitsData[t]; if te and te.MultiplierModifier then mult = mult + te.MultiplierModifier end end
        end
    end
    local r = math.round(base * mult)
    if sleepy then r = math.round(r * 0.5) end
    return r
end

local templateCache = {}
function getAnimalTemplate(animalName)
    local cached = templateCache[animalName]
    if cached then return cached end
    local ok, m = pcall(function()
        return AnimalsShared:GetAnimatedModel(animalName, "Idle")
    end)
    if setthreadidentity then pcall(setthreadidentity, 8) end
    if ok and typeof(m) == "Instance" then
        pcall(function() m.Parent = nil end)
        templateCache[animalName] = m
        return m
    end
    local legacy = AnimalModels:FindFirstChild(animalName)
    if legacy then templateCache[animalName] = legacy end
    return legacy
end
AnimalAnimations = ReplicatedStorage:WaitForChild("Animations"):WaitForChild("Animals")

SoundsAnimals = ReplicatedStorage:FindFirstChild("Sounds")
    and ReplicatedStorage.Sounds:FindFirstChild("Animals")

VFX = nil
pcall(function() VFX = require(ReplicatedStorage.Shared.VFX) end)
BrainrotAssets = nil
pcall(function() BrainrotAssets = require(ReplicatedStorage.Shared.BrainrotAssets) end)
SpawnEffectsController = ReplicatedStorage:FindFirstChild("Controllers")
    and ReplicatedStorage.Controllers:FindFirstChild("SpawnEffectsController")
VFXRoadStartBase = SpawnEffectsController
    and SpawnEffectsController:FindFirstChild("RoadStartBase")

local LiveboardScrollingFrame = nil
local LiveboardServerTemplate = nil

local function findLiveboard()
    if LiveboardScrollingFrame and LiveboardScrollingFrame.Parent then
        return LiveboardScrollingFrame
    end
    local lp = Players.LocalPlayer
    local pg = lp:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, child in ipairs(pg:GetChildren()) do
        if child:IsA("SurfaceGui") then
            local sf = child:FindFirstChild("ScrollingFrame")
            if sf and sf:FindFirstChild("ServerTemplate") then
                LiveboardScrollingFrame = sf
                LiveboardServerTemplate = sf:FindFirstChild("ServerTemplate")
                return sf
            end
        end
    end
    return nil
end

local CustomRichTextController = nil
pcall(function()
    CustomRichTextController = require(
        ReplicatedStorage.Controllers.CustomRichTextController)
end)

local liveTickers, liveTickerRunning = {}, false
local function addLiveTicker(fn)
    local handle = { fn = fn }
    function handle:Disconnect() liveTickers[self] = nil end
    liveTickers[handle] = true
    if not liveTickerRunning then
        liveTickerRunning = true
        task.spawn(function()
            while next(liveTickers) do
                task.wait(1)
                for h in pairs(liveTickers) do pcall(h.fn) end
            end
            liveTickerRunning = false
        end)
    end
    return handle
end

local fakeLiveboardEntries = {}

local function readEntrySpawnTime(entry)
    local filler = entry:FindFirstChild("Filler")
    if not filler then return nil end
    local spawnedLbl = filler:FindFirstChild("Spawned")
    if not spawnedLbl then return nil end
    local txt = spawnedLbl.Text or ""

    local mins, secs = txt:match("Spawned (%d+)m (%d+)s ago")
    if mins then
        return workspace:GetServerTimeNow() - (tonumber(mins) * 60 + tonumber(secs))
    end
    mins = txt:match("Spawned (%d+)m ago")
    if mins then
        return workspace:GetServerTimeNow() - (tonumber(mins) * 60)
    end
    secs = txt:match("Spawned (%d+)s ago")
    if secs then
        return workspace:GetServerTimeNow() - tonumber(secs)
    end
    return nil
end

local resortQueued = false
local function resortLiveboard()
    if resortQueued then return end
    resortQueued = true
    task.defer(function()
        resortQueued = false
        local sf = findLiveboard()
        if not sf then return end

        local entries = {}
        for _, child in ipairs(sf:GetChildren()) do
            if child:IsA("Frame") and child.Name == "Entry" then
                local spawnTime = nil

                for _, rec in pairs(fakeLiveboardEntries) do
                    if rec.entry == child then
                        spawnTime = rec.spawnTime
                        break
                    end
                end

                if not spawnTime then
                    spawnTime = readEntrySpawnTime(child)
                end
                if spawnTime then
                    table.insert(entries, { frame = child, time = spawnTime })
                end
            end
        end

        table.sort(entries, function(a, b) return a.time > b.time end)

        for i, e in ipairs(entries) do
            if e.frame.LayoutOrder ~= i then
                e.frame.LayoutOrder = i
            end
        end
    end)
end

do
    task.spawn(function()
        local sf = findLiveboard()
        local startedAt = os.clock()
        while not sf and (os.clock() - startedAt) < 30 do
            task.wait(0.5)
            sf = findLiveboard()
        end
        if not sf then return end
        sf.ChildAdded:Connect(function(child)
            if child:IsA("Frame") and child.Name == "Entry" then
                resortLiveboard()
            end
        end)
        sf.ChildRemoved:Connect(function(child)
            if child:IsA("Frame") and child.Name == "Entry" then
                resortLiveboard()
            end
        end)
    end)
end

local function applyFakeOwner(entry, userId, displayName)
    local filler = entry:FindFirstChild("Filler")
    if not filler then return end
    local playerBg = filler:FindFirstChild("PlayerBg")
    if not playerBg then return end

    if userId and displayName then
        playerBg.Visible = true
        local username = playerBg:FindFirstChild("Username")
        if username then
            username.Text = displayName
            username.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        local headshot = playerBg:FindFirstChild("Headshot")
        if headshot then

            task.delay(math.random() * 7, function()
                if headshot and headshot.Parent then
                    headshot.Image = string.format(
                        "rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100",
                        userId)
                end
            end)
        end
    else
        playerBg.Visible = false
        local username = playerBg:FindFirstChild("Username")
        if username then
            username.Text = "UNCLAIMED"
            username.TextColor3 = Color3.fromRGB(255, 61, 61)
        end
        local headshot = playerBg:FindFirstChild("Headshot")
        if headshot then
            headshot.Image = ""
        end
    end
end

function postFakeLiveboardEntry(driverUID, animalName, mutation)
    local sf = findLiveboard()
    if not sf or not LiveboardServerTemplate then return end

    local data = AnimalsData[animalName]
    if not data then return end

    local rarity = data.Rarity
    if rarity ~= "OG" and rarity ~= "Secret" then return end

    local timestamp = workspace:GetServerTimeNow()
    local displayDuration = 300

    local entry = LiveboardServerTemplate:Clone()
    entry.Name = "Entry"
    entry.Visible = true

    local filler = entry:FindFirstChild("Filler")
    if not filler then
        entry:Destroy()
        return
    end

    local title = filler:FindFirstChild("Title")
    if title then
        if CustomRichTextController and CustomRichTextController.apply then
            pcall(function()
                CustomRichTextController.apply(title,
                    AnimalsShared:ColorBrainrotName(animalName))
            end)
        else
            title.Text = animalName
        end
    end

    local spawnedLbl = filler:FindFirstChild("Spawned")
    if spawnedLbl then
        spawnedLbl.Text = "Spawned 0s ago"
    end

    local location = filler:FindFirstChild("Location")
    if location then
        location.Text = "[SERVER]"
    end

    applyFakeOwner(entry, nil, nil)

    local brainrotBg = filler:FindFirstChild("BrainrotBg")
    if brainrotBg then
        local img = brainrotBg:FindFirstChild("Img")
        if img then img.Visible = false end

        local viewport = Instance.new("ViewportFrame")
        viewport.Name = "BrainrotViewport"
        viewport.BackgroundTransparency = 1
        viewport.Size = UDim2.fromScale(1, 1)
        viewport.Position = UDim2.fromScale(0.5, 0.5)
        viewport.AnchorPoint = Vector2.new(0.5, 0.5)
        viewport.Parent = brainrotBg

        task.spawn(function()
            pcall(function()
                AnimalsShared:AttachOnViewport(animalName, viewport, nil, mutation)
            end)
        end)
    end

    local bar = filler:FindFirstChild("Bar")
    if bar then
        local fill = bar:FindFirstChild("Fill")
        if fill then
            fill.Size = UDim2.fromScale(1, 1)
            local tween = TweenService:Create(fill,
                TweenInfo.new(displayDuration, Enum.EasingStyle.Linear),
                { Size = UDim2.fromScale(0, 1) })
            tween:Play()
        end
    end

    local heartbeatConn
    heartbeatConn = addLiveTicker(function()
        if not entry.Parent then
            heartbeatConn:Disconnect()
            return
        end
        if spawnedLbl then
            local elapsed = workspace:GetServerTimeNow() - timestamp
            local secs = math.max(0, math.floor(elapsed))
            local text
            if secs < 60 then
                text = "Spawned " .. secs .. "s ago"
            else
                local mins = math.floor(secs / 60)
                local rem = secs % 60
                if rem > 0 then
                    text = "Spawned " .. mins .. "m " .. rem .. "s ago"
                else
                    text = "Spawned " .. mins .. "m ago"
                end
            end
            spawnedLbl.Text = text
        end
    end)

    entry.Parent = sf

    fakeLiveboardEntries[driverUID] = {
        entry = entry,
        spawnTime = timestamp,
        heartbeatConn = heartbeatConn,
    }

    task.delay(displayDuration, function()
        if heartbeatConn then
            pcall(function() heartbeatConn:Disconnect() end)
        end
        if entry and entry.Parent then
            pcall(function() entry:Destroy() end)
        end
        fakeLiveboardEntries[driverUID] = nil
    end)

    resortLiveboard()
end

function claimFakeLiveboardEntry(driverUID)
    local rec = fakeLiveboardEntries[driverUID]
    if not rec or not rec.entry or not rec.entry.Parent then return end
    local lp = Players.LocalPlayer
    applyFakeOwner(rec.entry, lp.UserId, lp.DisplayName)
end

local EventController = nil
pcall(function()
    EventController = require(ReplicatedStorage.Controllers.EventController)
end)

local BRAINROT_EVENT_MAP = {
    ["Strawberry Elephant"] = "Strawberry",
    ["Skibidi Toilet"]      = "Skibidi",
    ["Meowl"]               = "Meowl",
    ["John Pork"]           = "John Pork",
}

local FAKE_EVENT_DURATION = 180

local fakeEvents = {}

function triggerFakeEvent(animalName)
    local eventName = BRAINROT_EVENT_MAP[animalName]
    if not eventName then return end
    if not EventController then return end

    if EventController:IsActive(eventName) then return end

    local channelTable = syncTable("Events", true)
    if not channelTable then return end

    if type(channelTable.ActiveEvents) ~= "table" then
        channelTable.ActiveEvents = {}
    end

    local cleanupFns = {}

    if eventName == "Skibidi" then

        if not ReplicatedStorage:GetAttribute("SkibidiEventSeed") then
            local seed = math.random(1, 999999)
            ReplicatedStorage:SetAttribute("SkibidiEventSeed", seed)
            table.insert(cleanupFns, function()
                ReplicatedStorage:SetAttribute("SkibidiEventSeed", nil)
            end)
        end
    elseif eventName == "Meowl" then

    end

    local serverNow = workspace:GetServerTimeNow()
    local activeEventEntry = {
        eventName = eventName,
        startedAt = serverNow,
        endsAt    = serverNow + FAKE_EVENT_DURATION,
    }

    table.insert(channelTable.ActiveEvents, activeEventEntry)

    fakeEvents[eventName] = {
        entry = activeEventEntry,
        expiresAt = os.clock() + FAKE_EVENT_DURATION,
        cleanupFns = cleanupFns,
    }

    pcall(function()
        EventController:Execute(eventName)
    end)

    task.delay(FAKE_EVENT_DURATION, function()
        local rec = fakeEvents[eventName]
        if not rec or rec.entry ~= activeEventEntry then return end
        fakeEvents[eventName] = nil

        local cur = syncTable("Events", true)
        if cur and type(cur.ActiveEvents) == "table" then
            for i, e in ipairs(cur.ActiveEvents) do
                if e == activeEventEntry then
                    table.remove(cur.ActiveEvents, i)
                    break
                end
            end
        end

        pcall(function()
            EventController:Cancel(eventName)
        end)

        for _, fn in ipairs(rec.cleanupFns or {}) do
            pcall(fn)
        end
    end)
end

function getLocalContainer()
    local cam = workspace.CurrentCamera
    if not cam then return workspace end
    local f = cam:FindFirstChild("DarkSpawner_Models")
    if not f then
        f = Instance.new("Folder")
        f.Name = "DarkSpawner_Models"
        f.Parent = cam
    end
    return f
end

SpawnedSlots   = {}
HeldBrainrot   = nil
PlacePrompts   = {}
local myPlotGUID       = nil
myPlotChannel    = nil
local myPlayerChannel  = nil

activeFakeSlots = {}
hudConnections  = {}
fakeExtra       = 0
hudPatchInited  = false

function resolveMyPlot()
    if myPlotGUID and myPlotChannel then return myPlotGUID, myPlotChannel end
    local plotsFolder = workspace:FindFirstChild("Plots")
    if not plotsFolder then return nil, nil end

    for _, plot in pairs(plotsFolder:GetChildren()) do
        if plot:IsA("Model") then
            local data = syncTable(plot.Name)
            local owner = data and data.Owner
            local isMine = false
            if typeof(owner) == "Instance" then
                isMine = owner == LocalPlayer
            elseif type(owner) == "table" then
                isMine = owner.UserId == LocalPlayer.UserId or owner.Name == LocalPlayer.Name
            elseif type(owner) == "string" then
                isMine = owner == LocalPlayer.Name or owner == LocalPlayer.DisplayName
                    or owner == tostring(LocalPlayer.UserId)
            elseif type(owner) == "number" then
                isMine = owner == LocalPlayer.UserId
            end
            if isMine then
                myPlotGUID    = plot.Name
                myPlotChannel = makeChannel(plot.Name)
                return myPlotGUID, myPlotChannel
            end
        end
    end
    return nil, nil
end

function getPlotModel()
    resolveMyPlot()
    if not myPlotGUID then return nil end
    local f = workspace:FindFirstChild("Plots")
    if f then return f:FindFirstChild(myPlotGUID) end
    return nil
end

function getPlayerChannel()
    if myPlayerChannel then return myPlayerChannel end
    if syncTable(LocalPlayer) then
        myPlayerChannel = makeChannel(LocalPlayer)
    end
    return myPlayerChannel
end

function getMaxSlots()
    local ch = getPlayerChannel()
    if ch then
        local rebirth = ch:Get("Rebirth")
        if type(rebirth) == "number" then
            local base = BasesData[rebirth]
            if base and base.MaxAnimals then return base.MaxAnimals end
        end
    end
    return 27
end

local function realHasInIndex(animalName, mutation)
    local ch = myPlayerChannel
    if not ch then return false end
    local entry = ch:Get({ "Index", animalName })
    if type(entry) ~= "table" then return false end
    if mutation == nil or mutation == "Default" then
        return next(entry) ~= nil
    end
    return entry[mutation] ~= nil
end

function addToFakeIndex(animalName, mutation)
    if not animalName or animalName == "" then return end
    if not AnimalsData[animalName] then return end
    local entry = Config.fakeIndex[animalName]
    if type(entry) ~= "table" then
        entry = {}
        Config.fakeIndex[animalName] = entry
    end
    local changed = false
    if not entry.Default then
        entry.Default = true
        changed = true
    end
    local mut = mutation
    if mut == "None" or mut == "" then mut = nil end
    if mut and mut ~= "Default" and not entry[mut] then
        entry[mut] = true
        changed = true
    end
    if changed then saveConfig() end
end

do
    local IndexShared
    pcall(function() IndexShared = require(ReplicatedStorage.Shared.Index) end)
    if IndexShared then
        local function countFakeExtra(mutation)
            local mut = mutation or "Default"
            local extra = 0
            for name, mutations in pairs(Config.fakeIndex) do
                if type(mutations) == "table" and mutations[mut]
                    and not realHasInIndex(name, mut) then
                    extra += 1
                end
            end
            return extra
        end

        local origGet = IndexShared.GetIndexAnimals
        if type(origGet) == "function" then
            IndexShared.GetIndexAnimals = function(self, player, mutation, ...)
                local v1, v2, v3 = origGet(self, player, mutation, ...)
                if player == LocalPlayer and type(v1) == "number" then
                    local extra = countFakeExtra(mutation)
                    if extra > 0 then
                        v1 = math.min(v1 + extra, v3 or (v1 + extra))
                    end
                end
                return v1, v2, v3
            end
        end

        local origIs = IndexShared.IsComplete
        if type(origIs) == "function" then
            IndexShared.IsComplete = function(self, player, mutation, ...)
                local result = origIs(self, player, mutation, ...)
                if result or player ~= LocalPlayer then return result end
                local v1, v2 = IndexShared:GetIndexAnimals(player, mutation)
                if type(v1) == "number" and type(v2) == "number" and v2 > 0 then
                    return v1 >= v2
                end
                return result
            end
        end
    end
end

task.spawn(function()
    local function waitPath(root, ...)
        local node = root
        for _, name in ipairs({ ... }) do
            node = node and node:WaitForChild(name, 10)
            if not node then return nil end
        end
        return node
    end

    local IndexGui = PlayerGui:WaitForChild("Index", 60)
    if not IndexGui then return end
    local IndexFrame = waitPath(IndexGui, "Index")
    local Main       = waitPath(IndexFrame, "Main")
    local List       = waitPath(Main, "Content", "Holder", "List")
    local Mutations  = waitPath(Main, "Mutations")
    if not (IndexFrame and Main and List and Mutations) then return end

    local WHITE = Color3.fromRGB(255, 255, 255)
    local BLACK = Color3.fromRGB(0, 0, 0)

    local currentTab = "Default"
    local mutCleanups = {}
    local hookedCards = {}

    local function shouldUnlock(animalName)
        local entry = Config.fakeIndex[animalName]
        return type(entry) == "table" and entry[currentTab] == true
    end

    local function cleanupMutation(card)
        local c = mutCleanups[card]
        if not c then return end
        mutCleanups[card] = nil
        pcall(function()
            if type(c) == "function" then c()
            elseif type(c) == "table" then
                if c.Destroy then c:Destroy() elseif c.Disconnect then c:Disconnect() end
            end
        end)
    end

    local function applyMutationToCard(card, animalName)
        cleanupMutation(card)
        if currentTab == "Default" then return end
        if realHasInIndex(animalName, currentTab) then return end
        local vp = card:FindFirstChild("ViewportFrame")
        if not vp then return end
        local model
        for _, d in ipairs(vp:GetDescendants()) do
            if d:IsA("Model") then model = d; break end
        end
        if not model then return end
        local ok, result = pcall(function()
            return AnimalsShared:ApplyMutation(model, animalName, currentTab, true)
        end)
        if ok and result then mutCleanups[card] = result end
    end

    local function applyOverride(card)
        if not shouldUnlock(card.Name) then
            cleanupMutation(card)
            return
        end
        local nameLbl = card:FindFirstChild("NameLabel")
        local vp = card:FindFirstChild("ViewportFrame")
        if nameLbl and not nameLbl.Visible then nameLbl.Visible = true end
        if vp and vp.ImageColor3 ~= WHITE then vp.ImageColor3 = WHITE end
        applyMutationToCard(card, card.Name)
    end

    local function hookCard(card)
        if hookedCards[card] or not card:IsA("GuiObject") then return end
        if card.Name == "Template" then return end
        hookedCards[card] = true

        local nameLbl = card:WaitForChild("NameLabel", 3)
        local vp      = card:WaitForChild("ViewportFrame", 3)
        if nameLbl then
            nameLbl:GetPropertyChangedSignal("Visible"):Connect(function()
                if not nameLbl.Visible and shouldUnlock(card.Name) then
                    nameLbl.Visible = true
                end
            end)
        end
        if vp then
            vp:GetPropertyChangedSignal("ImageColor3"):Connect(function()
                if vp.ImageColor3 == BLACK and shouldUnlock(card.Name) then
                    vp.ImageColor3 = WHITE
                end
            end)
            vp.DescendantAdded:Connect(function(d)
                if d:IsA("Model") and currentTab ~= "Default" and shouldUnlock(card.Name) then
                    task.defer(applyMutationToCard, card, card.Name)
                end
            end)
        end
        applyOverride(card)
    end

    for _, child in ipairs(List:GetChildren()) do task.spawn(hookCard, child) end
    List.ChildAdded:Connect(function(child) task.defer(hookCard, child) end)

    local function refreshAllCards()
        task.defer(function()
            for card in pairs(hookedCards) do
                if card.Parent then applyOverride(card) else hookedCards[card] = nil end
            end
        end)
    end

    local function hookMutBtn(btn)
        if not btn:IsA("GuiButton") or btn.Name == "Template" then return end
        if btn:GetAttribute("__DarkTabHooked") then return end
        btn:SetAttribute("__DarkTabHooked", true)
        btn.Activated:Connect(function()
            if currentTab == btn.Name then return end
            currentTab = btn.Name
            refreshAllCards()
        end)
    end
    for _, child in ipairs(Mutations:GetChildren()) do hookMutBtn(child) end
    Mutations.ChildAdded:Connect(function(child) task.defer(hookMutBtn, child) end)

    IndexFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if IndexFrame.Visible then refreshAllCards() end
    end)
end)

end
local function getEmptySlot(plotModel)
    local podiums = plotModel:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    resolveMyPlot()
    local animalList = myPlotChannel and myPlotChannel:Get("AnimalList") or {}
    local children = podiums:GetChildren()
    table.sort(children, function(a, b)
        return (tonumber(a.Name) or 999) < (tonumber(b.Name) or 999)
    end)
    for _, p in ipairs(children) do
        local idx = tonumber(p.Name)
        if idx then
            if SpawnedSlots[idx] then continue end
            if animalList[idx] ~= nil and animalList[idx] ~= "Empty" then continue end
            return idx
        end
    end
    return nil
end

local CurrencyLabel = nil
local setupHudPatch, spawnAnimalAt, clearSlot, showToast, spawnCarpetBrainrot, refreshTradeSlots, onCharacterRespawn, spawnAnimal, FDX, clearAll
do
local CashoutContainer = nil
local cashValue = nil
local overridingLeader = false

local function spawnFakePopup(amount)
    if not CashoutContainer or not CashoutContainer.Parent then return end
    local template = CashoutContainer:FindFirstChild("Template")
    if not template then return end
    local TweenService = game:GetService("TweenService")
    pcall(function()
        local clone = template:Clone()
        clone.Text       = "+$" .. NumberUtils:ToString(math.abs(amount), 2)
        clone.TextColor3 = Color3.fromRGB(13, 255, 0)
        clone.Visible    = true
        clone.Parent     = CashoutContainer

        local ti = TweenInfo.new(5, Enum.EasingStyle.Linear)
        local t1 = TweenService:Create(clone, ti, { TextTransparency = 1 })
        local stroke = clone:FindFirstChildWhichIsA("UIStroke")
        if stroke then
            local t2 = TweenService:Create(stroke, ti, { Transparency = 1 })
            t2:Play()
        end
        t1.Completed:Once(function()
            pcall(function() clone:Destroy() end)
        end)
        t1:Play()
    end)
end

local function addCoins(amount)
    if amount <= 0 then return end
    fakeExtra += amount

    if CurrencyLabel and CurrencyLabel.Parent then
        local ch = getPlayerChannel()
        local realTotal = (ch and ch:Get("Coins")) or 0
        pcall(function()
            CurrencyLabel.Text = "$"
                .. NumberUtils:ToString(realTotal + fakeExtra, 2)
        end)
    end

    if cashValue and cashValue.Parent then
        local ch = getPlayerChannel()
        local realTotal = (ch and ch:Get("Coins")) or 0
        local displayTotal = realTotal + fakeExtra
        overridingLeader = true
        pcall(function()
            if cashValue:IsA("StringValue") then
                cashValue.Value = NumberUtils:ToString(displayTotal, 1)
            else
                cashValue.Value = displayTotal
            end
        end)
        overridingLeader = false
    end

    spawnFakePopup(amount)

    pcall(function()
        SoundController:PlaySound("Sounds.Sfx.Cashout")
    end)
end

local function buildAnimalOverhead(adornee, animalName, mutationName, traitsList, trove)
    local data = AnimalsData[animalName]
    if not data then return nil, function() end end

    local gui, cleanup = FastOverheadController.createFastOverhead({
        adornee     = adornee,
        guiTemplate = FastOverheadController.GuiTemplates.AnimalOverhead
    })
    if not gui then return nil, function() end end

    AnimalOverheadController:Populate({
        Overhead  = gui,
        Index     = animalName,
        Traits    = traitsList,
        Mutation  = mutationName,
        Player    = LocalPlayer,
        Trove     = trove
    })

    local genLabel = gui:FindFirstChild("Generation")
    if genLabel then
        local ok, gen = pcall(function()
            return calcGeneration(animalName, mutationName, traitsList)
        end)
        if ok and gen then
            genLabel.Text = "$" .. numToString(gen) .. "/s"
        else
            genLabel.Text = "$0/s"
        end
        genLabel.Visible = not data.HideGeneration
    end

    for _, child in gui:GetChildren() do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:SetAttribute("DefaultState", child.Visible)
        end
    end

    return gui, cleanup
end

local function buildCashPadGui(adornee)
    local gui, cleanup
    local ok = pcall(function()
        gui, cleanup = FastOverheadController.createFastOverhead({
            adornee     = adornee,
            guiTemplate = FastOverheadController.GuiTemplates.CashPad
        })
    end)
    if not ok then return nil, nil end
    return gui, cleanup
end

function setupHudPatch()
    if hudPatchInited then return end
    hudPatchInited = true

    local Currency, Cashout
    do
        local LeftBottom = PlayerGui:WaitForChild("LeftBottom", 10)
        if not LeftBottom then return end
        local LBFrame = LeftBottom:WaitForChild("LeftBottom", 10)
        if not LBFrame then return end
        Currency = LBFrame:FindFirstChild("Currency")
        Cashout  = LBFrame:FindFirstChild("Cashout")
        if not Currency or not Cashout then return end
        CurrencyLabel    = Currency
        CashoutContainer = Cashout
    end

    task.spawn(function()
        local leaderstats = LocalPlayer:WaitForChild("leaderstats", 10)
        if not leaderstats then return end
        local val = leaderstats:FindFirstChild("Coins")
            or leaderstats:FindFirstChild("Cash")
            or leaderstats:FindFirstChild("Money")
        if not val then
            for _, child in ipairs(leaderstats:GetChildren()) do
                if child:IsA("NumberValue") or child:IsA("IntValue")
                   or child:IsA("StringValue") then
                    val = child
                    break
                end
            end
        end
        cashValue = val
    end)

    local overridingCurr = false
    local currConn = Currency:GetPropertyChangedSignal("Text"):Connect(function()
        if overridingCurr then return end
        if fakeExtra <= 0 then return end
        overridingCurr = true
        pcall(function()
            local ch = getPlayerChannel()
            local realTotal = (ch and ch:Get("Coins")) or 0
            Currency.Text = "$" .. NumberUtils:ToString(realTotal + fakeExtra, 2)
        end)
        overridingCurr = false
    end)
    table.insert(hudConnections, currConn)

    task.spawn(function()
        local waited = 0
        while not cashValue and waited < 10 do
            task.wait(0.5)
            waited += 0.5
        end
        if not cashValue then return end

        local leaderConn = cashValue:GetPropertyChangedSignal("Value")
            :Connect(function()
                if overridingLeader then return end
                if fakeExtra <= 0 then return end
                overridingLeader = true
                pcall(function()
                    local ch = getPlayerChannel()
                    local realTotal = (ch and ch:Get("Coins")) or 0
                    local displayTotal = realTotal + fakeExtra
                    if cashValue:IsA("StringValue") then
                        cashValue.Value = NumberUtils:ToString(displayTotal, 1)
                    else
                        cashValue.Value = displayTotal
                    end
                end)
                overridingLeader = false
            end)
        table.insert(hudConnections, leaderConn)
    end)

end

local CASH_SUFFIXES = {
    { 1e33, "De" }, { 1e30, "No" }, { 1e27, "Oc" },
    { 1e24, "Sp" }, { 1e21, "Sx" }, { 1e18, "Qn" },
    { 1e15, "Qa" }, { 1e12, "T"  }, { 1e9,  "B"  },
    { 1e6,  "M"  }, { 1e3,  "K"  },
}
local function fmtCash(n)
    n = math.floor(n + 0.5)
    if n < 1000 then return string.format("%d", n) end
    for _, sfx in ipairs(CASH_SUFFIXES) do
        if n >= sfx[1] then
            local v = math.floor(n / sfx[1] * 10) / 10
            return (string.format("%.1f", v):gsub("%.?0+$", "")) .. sfx[2]
        end
    end
    return string.format("%d", n)
end

local cashPads, cashPadCount = {}, 0
local cashHB = nil
local cashTickerRunning = false

local function cashHeartbeat()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        for pad in pairs(cashPads) do pad.inside = false end
        return
    end
    local p = hrp.Position
    for pad in pairs(cashPads) do
        local dx, dz, dy = p.X - pad.cx, p.Z - pad.cz, p.Y - pad.cy
        local inside = (dx * dx + dz * dz <= pad.hr2) and (math.abs(dy) <= pad.vr)
        if inside and not pad.inside then pad.payout() end
        pad.inside = inside
    end
end

local function startCashTicker()
    if cashTickerRunning then return end
    cashTickerRunning = true
    task.spawn(function()
        while cashPadCount > 0 do
            local now = workspace:GetServerTimeNow()
            task.wait(math.max(0.05, math.ceil(now) - now))
            for pad in pairs(cashPads) do pad.refresh() end
        end
        cashTickerRunning = false
    end)
end

local function registerCashPad(pad)
    cashPads[pad] = true
    cashPadCount += 1
    if not cashHB then cashHB = RunService.Heartbeat:Connect(cashHeartbeat) end
    startCashTicker()
end

local function unregisterCashPad(pad)
    if not cashPads[pad] then return end
    cashPads[pad] = nil
    cashPadCount -= 1
    if cashPadCount <= 0 and cashHB then
        cashHB:Disconnect()
        cashHB = nil
    end
end

local function patchCashPad(plotModel, slotNumber, animalName, mutation, traits)
    local noop = function() end
    local podium = plotModel.AnimalPodiums:FindFirstChild(tostring(slotNumber))
    if not podium then return noop end

    local claim = podium:FindFirstChild("Claim")
    local claimMain = claim and claim:FindFirstChild("Main")
    if not claimMain then return noop end

    local genPerSecond = calcGeneration(animalName, mutation, traits)
    local running = true
    local slotBaseline = workspace:GetServerTimeNow()

    local function getAccumulated()
        local elapsed = math.floor(workspace:GetServerTimeNow() - slotBaseline)
        if elapsed < 0 then elapsed = 0 end
        return elapsed * genPerSecond
    end

    local cashPadGui, cashPadCleanup = buildCashPadGui(claimMain)
    if not cashPadGui then
        return function() running = false end
    end

    local collectAmount = cashPadGui:FindFirstChild("CollectAmount", true)
    local offline       = cashPadGui:FindFirstChild("Offline", true)

    local function refresh()
        if not running or not cashPadGui.Parent then return end
        if collectAmount then
            local txt = "$" .. fmtCash(getAccumulated())
            if collectAmount.Text ~= txt then collectAmount.Text = txt end
        end
        if offline then
            if offline.Visible then offline.Visible = false end
            if offline.Text ~= "" then offline.Text = "" end
        end
    end
    refresh()

    local pad
    local hitbox = claim:FindFirstChild("Hitbox")
    if hitbox and hitbox:IsA("BasePart") then
        local size = hitbox.Size + Vector3.new(2, 6, 2)
        local center = hitbox.Position
        local horiz = math.max(size.X, size.Z) * 0.5 + 1.5
        local lastPayoutAt = 0
        pad = {
            cx = center.X, cy = center.Y, cz = center.Z,
            hr2 = horiz * horiz,
            vr = math.max(size.Y * 0.5 + 4, 5),
            inside = false,
            refresh = refresh,
            payout = function()
                if not running then return end
                local now = os.clock()
                if now - lastPayoutAt < 0.25 then return end
                lastPayoutAt = now
                local payout = math.floor(getAccumulated())
                if payout > 0 then addCoins(payout) end
                slotBaseline = workspace:GetServerTimeNow()
                refresh()
            end,
        }
        registerCashPad(pad)
    end

    return function()
        running = false
        if pad then unregisterCashPad(pad) end
        if cashPadCleanup then pcall(cashPadCleanup) end
        if cashPadGui then pcall(function() cashPadGui:Destroy() end) end
    end
end



local clearPlacePrompts
local setSlotGrabbed
local showPlacePrompts




local heldTrove        = nil
local holdAnimTrack    = nil
local speedConn        = nil
local originalWalkSpeed = nil

local function clearHeldModel()
    pcall(function()
        BackpackController:SetEnabled("DarkSpawner_Holding", true)
    end)

    if holdAnimTrack then
        holdAnimTrack:Stop()
        holdAnimTrack:Destroy()
        holdAnimTrack = nil
    end
    if speedConn then
        speedConn:Disconnect()
        speedConn = nil
    end
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum and originalWalkSpeed then
        hum.WalkSpeed = originalWalkSpeed
    end
    originalWalkSpeed = nil
    if heldTrove then heldTrove:Destroy(); heldTrove = nil end
end

function onCharacterRespawn()
    if HeldBrainrot then
        local fromSlot = HeldBrainrot.fromSlot
        if fromSlot and SpawnedSlots[fromSlot] then
            setSlotGrabbed(fromSlot, false)
        end
        HeldBrainrot = nil
    end
    clearHeldModel()
    clearPlacePrompts()
end

local function createHeldModel(animalName, mutName, traitsList)
    clearHeldModel()

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    originalWalkSpeed = hum.WalkSpeed
    hum.WalkSpeed     = originalWalkSpeed * 0.6

    pcall(function() hum:UnequipTools() end)
    pcall(function()
        BackpackController:SetEnabled("DarkSpawner_Holding", false)
    end)

    local template = getAnimalTemplate(animalName)
    if not template then return end

    heldTrove = Trove.new()
    local heldModel = heldTrove:Clone(template)

    for _, part in heldModel:GetDescendants() do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery   = false
            part.CanTouch   = false
            part.Massless   = true
            part.Anchored   = false
        end
    end

    if mutName then
        pcall(function()
            heldTrove:Add(AnimalsShared:ApplyMutation(heldModel, animalName, mutName))
        end)
    end
    if traitsList then
        pcall(function()
            heldTrove:Add(AnimalsShared:ApplyTraits(heldModel, animalName, traitsList))
        end)
    end

    local anchor = heldTrove:Add(Instance.new("Part"))
    anchor.Size            = Vector3.new(0.1, 0.1, 0.1)
    anchor.Transparency    = 1
    anchor.CanCollide      = false
    anchor.CanQuery        = false
    anchor.Massless        = true
    anchor.Anchored        = false
    anchor.Name            = "HeldAnchor"
    anchor.Parent          = workspace

    local anchorWeld = heldTrove:Add(Instance.new("Weld"))
    anchorWeld.Part0  = hrp
    anchorWeld.Part1  = anchor
    anchorWeld.C0     = CFrame.new(0, 0, -2.5)
    anchorWeld.Parent = hrp

    heldModel:PivotTo(anchor.CFrame)
    heldModel.Parent = getLocalContainer()

    local animalWeld = heldTrove:Add(Instance.new("Weld"))
    animalWeld.Part0  = heldModel.PrimaryPart
    animalWeld.Part1  = anchor
    animalWeld.C0     = heldModel.PrimaryPart.CFrame:Inverse()
                        * heldModel:GetPivot()
    animalWeld.Parent = heldModel.PrimaryPart

    local existingAC = heldModel:FindFirstChild("AnimationController")
    if existingAC then existingAC:Destroy() end
    local hum2 = Instance.new("Humanoid", heldModel)
    hum2.Name                  = "AnimationController"
    hum2.EvaluateStateMachine  = false
    hum2.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.None
    hum2.PlatformStand         = true
    local animator2 = Instance.new("Animator", hum2)

    local animFolder = AnimalAnimations:FindFirstChild(animalName)
    local idleAnim   = animFolder and animFolder:FindFirstChild("Idle")
    if idleAnim and animator2 then
        local track = animator2:LoadAnimation(idleAnim)
        track.Looped = true
        track:Play()
        if track.Length and track.Length > 0 then
            local now = workspace:GetServerTimeNow()
            track.TimePosition = now % track.Length
        end
        heldTrove:Add(function() track:Stop(0); track:Destroy() end)
    end

    local charAnim = hum:FindFirstChildOfClass("Animator")
    if charAnim then
        local holdAnim = Instance.new("Animation")
        holdAnim.AnimationId = "rbxassetid://71186871415348"
        holdAnimTrack = charAnim:LoadAnimation(holdAnim)
        holdAnimTrack.Priority = Enum.AnimationPriority.Action4
        holdAnimTrack.Looped   = true
        holdAnimTrack:Play()
        holdAnim:Destroy()
    end

    speedConn = RunService.Heartbeat:Connect(function()
        local c2 = LocalPlayer.Character
        if c2 and hrp and hrp.Parent then
            local vel  = hrp.AssemblyLinearVelocity
            local hVel = Vector3.new(vel.X, 0, vel.Z)
            if hVel.Magnitude > 20 then
                local capped = hVel.Unit * 20
                hrp.AssemblyLinearVelocity =
                    Vector3.new(capped.X, vel.Y, capped.Z)
            end
        end
    end)
end

clearPlacePrompts = function()
    for _, pp in pairs(PlacePrompts) do
        if pp.prompt then pp.prompt:Destroy() end
        if pp.conn   then pp.conn:Disconnect() end

        if pp.slotIdx and SpawnedSlots[pp.slotIdx] then
            local sd = SpawnedSlots[pp.slotIdx]
            if sd.grabPrompt then sd.grabPrompt.Enabled = true end
            if sd.sellPrompt then sd.sellPrompt.Enabled = true end
        end
    end
    PlacePrompts = {}
end

showPlacePrompts = function()
    clearPlacePrompts()
    local plotModel = getPlotModel()
    if not plotModel or not HeldBrainrot then return end

    resolveMyPlot()
    local animalList = myPlotChannel and myPlotChannel:Get("AnimalList") or {}
    local podiums    = plotModel:FindFirstChild("AnimalPodiums")
    if not podiums then return end

    local d = AnimalsData[HeldBrainrot.animalName]
    local displayName = d and d.DisplayName or HeldBrainrot.animalName

    for _, pod in pairs(podiums:GetChildren()) do
        local idx = tonumber(pod.Name)
        if not idx then continue end

        local isGrabbedSlot = SpawnedSlots[idx] and SpawnedSlots[idx].isGrabbed

        local isOccupiedByVisual = SpawnedSlots[idx] ~= nil and not isGrabbedSlot
        local isOccupiedByReal = (not isOccupiedByVisual) and (not isGrabbedSlot)
            and animalList[idx] ~= nil and animalList[idx] ~= "Empty"

        if isOccupiedByReal then continue end

        local promptAtt = pod:FindFirstChild("Base")
            and pod.Base:FindFirstChild("Spawn")
            and pod.Base.Spawn:FindFirstChild("PromptAttachment")
        if not promptAtt then continue end

        if isOccupiedByVisual then
            local slotData = SpawnedSlots[idx]
            if slotData.grabPrompt then slotData.grabPrompt.Enabled = false end
            if slotData.sellPrompt then slotData.sellPrompt.Enabled = false end
        end

        local actionText = "Place"

        local prompt = Instance.new("ProximityPrompt")
        prompt.HoldDuration         = 1.5
        prompt.RequiresLineOfSight  = true
        prompt.Style                = Enum.ProximityPromptStyle.Custom
        prompt.ActionText           = actionText
        prompt.ObjectText           = displayName
        prompt:SetAttribute("State", "Place")
        prompt.Parent               = promptAtt

        local conn = prompt.Triggered:Connect(function()
            if not HeldBrainrot then return end
            local held     = HeldBrainrot
            local fromSlot = held.fromSlot

            HeldBrainrot = nil
            clearHeldModel()
            clearPlacePrompts()

            if isGrabbedSlot then

                if fromSlot and SpawnedSlots[fromSlot] then
                    clearSlot(fromSlot)
                end
                spawnAnimalAt(idx, held.animalName, held.mutation, held.traits)
            elseif isOccupiedByVisual and SpawnedSlots[idx] then

                local targetData = SpawnedSlots[idx]
                local targetAnimal   = targetData.animalName
                local targetMutation = targetData.mutation
                local targetTraits   = targetData.traits

                clearSlot(idx)
                if fromSlot and SpawnedSlots[fromSlot] then
                    clearSlot(fromSlot)
                end

                spawnAnimalAt(idx, held.animalName, held.mutation, held.traits)

                if fromSlot then
                    spawnAnimalAt(fromSlot, targetAnimal, targetMutation, targetTraits)
                end
            else

                if fromSlot and SpawnedSlots[fromSlot]
                   and SpawnedSlots[fromSlot].isGrabbed then
                    clearSlot(fromSlot)
                end

                spawnAnimalAt(idx, held.animalName, held.mutation, held.traits)
            end
        end)

        table.insert(PlacePrompts, {
            prompt = prompt,
            conn = conn,
            slotIdx = idx,
        })
    end
end

clearSlot = function(idx)
    local data = SpawnedSlots[idx]
    if not data then return end
    if data.grabPrompt      then data.grabPrompt:Destroy() end
    if data.sellPrompt      then data.sellPrompt:Destroy() end
    if data.grabConn        then data.grabConn:Disconnect() end
    if data.sellConn        then data.sellConn:Disconnect() end
    if data.cashPadCleanup  then pcall(data.cashPadCleanup) end
    if data.trove           then data.trove:Destroy() end
    if data.model           then data.model:Destroy() end
    activeFakeSlots[idx] = nil
    SpawnedSlots[idx] = nil
    if refreshTradeSlots then pcall(refreshTradeSlots) end
end

setSlotGrabbed = function(idx, grabbed)
    local data = SpawnedSlots[idx]
    if not data then return end
    data.isGrabbed = grabbed

    if data.model then
        for _, part in data.model:GetDescendants() do
            if part:IsA("BasePart") then
                local def = part:GetAttribute("DefaultTransparency")
                if def == nil then
                    def = part.Transparency
                    part:SetAttribute("DefaultTransparency", def)
                end
                part.Transparency = grabbed and (part.Transparency < 1 and 0.5 or part.Transparency) or def
            end
        end
    end

    if data.overheadGui then
        for _, child in data.overheadGui:GetChildren() do
            if child:IsA("TextLabel") then
                if child.Name == "Stolen" then
                    child.Visible = false
                elseif grabbed then
                    child.Visible = child.Name == "Generation"
                else
                    child.Visible = child:GetAttribute("DefaultState") ~= false
                end
            elseif child:IsA("Frame") and child.Name == "Traits" then
                child.Visible = grabbed or (child:GetAttribute("DefaultState") ~= false)
            end
        end
    end

    if data.grabPrompt then data.grabPrompt.Enabled = not grabbed end
    if data.sellPrompt then data.sellPrompt.Enabled = not grabbed end
end

function spawnAnimal(animalName, mutation, traits, targetSlot)
    local plotModel = getPlotModel()
    if not plotModel then return false end

    local slot = targetSlot or getEmptySlot(plotModel)
    if not slot then return false end

    local animalData = AnimalsData[animalName]
    if not animalData then return false end

    local podium = plotModel.AnimalPodiums:FindFirstChild(tostring(slot))
    if not podium then return false end
    local spawnPart = podium.Base.Spawn

    clearSlot(slot)

    local mutName = (mutation ~= "None") and mutation or nil
    local traitsList = nil
    if traits and #traits > 0 then
        traitsList = {}
        for i, v in ipairs(traits) do traitsList[i] = v end
    end

    local template = getAnimalTemplate(animalName)
    if not template then return false end

    local trove = Trove.new()
    local clone = trove:Clone(template)
    clone.Parent = getLocalContainer()

    for _, part in clone:GetDescendants() do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CanQuery   = false
            part.CanTouch   = false
            part.Massless   = true
        end
    end

    clone.PrimaryPart.Anchored = true

    if mutName then
        pcall(function()
            trove:Add(AnimalsShared:ApplyMutation(clone, animalName, mutName))
        end)
        clone:SetAttribute("Mutation", mutName)
    end

    local extents = clone:GetExtentsSize()

    if traitsList then
        pcall(function()
            trove:Add(AnimalsShared:ApplyTraits(clone, animalName, traitsList))
        end)
        clone:SetAttribute("Traits", table.concat(traitsList, ","))
    end

    clone:PivotTo(spawnPart:GetPivot())

    local existingAC = clone:FindFirstChild("AnimationController")
    if existingAC then existingAC:Destroy() end

    local hum = Instance.new("Humanoid", clone)
    hum.Name                 = "AnimationController"
    hum.EvaluateStateMachine = false
    hum.DisplayDistanceType  = Enum.HumanoidDisplayDistanceType.None
    hum.PlatformStand        = true
    local animator = Instance.new("Animator", hum)

    local animFolder = AnimalAnimations:FindFirstChild(animalName)
    local idleAnim   = animFolder and animFolder:FindFirstChild("Idle")
    if idleAnim and animator then
        local track = animator:LoadAnimation(idleAnim)
        track.Looped = true
        track:Play()
        if track.Length and track.Length > 0 then
            local now = workspace:GetServerTimeNow()
            track.TimePosition = now % track.Length
        end
        trove:Add(function() track:Stop(0); track:Destroy() end)
    end

    local overheadAtt = clone:FindFirstChild("OVERHEAD_ATTACHMENT", true)
    if not overheadAtt then
        local yOff = extents.Y * 0.75
            * (animalData.OverheadYOffsetModifier or 1)
        overheadAtt        = trove:Add(Instance.new("Attachment"))
        overheadAtt.Name   = "OVERHEAD_ATTACHMENT"
        overheadAtt.CFrame = CFrame.new(0, yOff, 0)
        overheadAtt.Parent = spawnPart
    end

    local overheadGui, overheadCleanup = buildAnimalOverhead(
        overheadAtt, animalName, mutName, traitsList, trove)
    if overheadCleanup then trove:Add(overheadCleanup) end

    local promptAtt = spawnPart:FindFirstChild("PromptAttachment")
    if not promptAtt then
        promptAtt        = Instance.new("Attachment")
        promptAtt.Name   = "PromptAttachment"
        promptAtt.Parent = spawnPart
    end

    local grabPrompt = Instance.new("ProximityPrompt")
    grabPrompt.HoldDuration        = 1.5
    grabPrompt.RequiresLineOfSight = true
    grabPrompt.Style               = Enum.ProximityPromptStyle.Custom
    grabPrompt.ActionText          = "Grab"
    grabPrompt.ObjectText          = animalData.DisplayName or animalName
    grabPrompt:SetAttribute("State", "Grab")
    grabPrompt.Parent              = promptAtt

    local grabConn = grabPrompt.Triggered:Connect(function()
        local data = SpawnedSlots[slot]
        if not data or data.isGrabbed then return end

        HeldBrainrot = {
            animalName = data.animalName,
            mutation   = data.mutation,
            traits     = data.traits,
            fromSlot   = slot
        }

        setSlotGrabbed(slot, true)
        createHeldModel(data.animalName, data.mutation, data.traits)
        showPlacePrompts()
    end)

    local sellPrompt = Instance.new("ProximityPrompt")
    sellPrompt.HoldDuration        = 1.5
    sellPrompt.RequiresLineOfSight = true
    sellPrompt.Style               = Enum.ProximityPromptStyle.Custom
    sellPrompt.KeyboardKeyCode     = Enum.KeyCode.F
    sellPrompt.GamepadKeyCode      = Enum.KeyCode.ButtonY
    sellPrompt.UIOffset            = Vector2.new(0, -72)
    sellPrompt.ActionText          = "Sell: $"
        .. NumberUtils:ToString(AnimalsShared:GetSellValue(animalName))
    sellPrompt.ObjectText          = ""
    sellPrompt:SetAttribute("State", "Sell")
    sellPrompt.Parent              = promptAtt

    local sellConn = sellPrompt.Triggered:Connect(function()
        local data = SpawnedSlots[slot]
        if not data then return end

        local function doSell()
            local d = SpawnedSlots[slot]
            if not d then return end
            local sellVal = AnimalsShared:GetSellValue(d.animalName)
            addCoins(sellVal)
            clearSlot(slot)
        end

        local rarity = animalData and animalData.Rarity
        local weight = 0
        if rarity then
            pcall(function()
                weight = AnimalsShared:GetRarityWeight(rarity) or 0
            end)
        end

        if weight >= 5 then
            task.spawn(function()
                if ConfirmationController:IsInPrompt() then return end
                local msg = "Do you want to sell " .. animalName .. "?"
                local confirmed = ConfirmationController:Show(msg)
                if confirmed then
                    doSell()
                end
            end)
        else
            doSell()
        end
    end)

    SpawnedSlots[slot] = {
        model       = clone,
        trove       = trove,
        animalName  = animalName,
        mutation    = mutName,
        traits      = traitsList,
        overheadGui = overheadGui,
        grabPrompt  = grabPrompt,
        sellPrompt  = sellPrompt,
        grabConn    = grabConn,
        sellConn    = sellConn,
        isGrabbed   = false
    }

    if not hudPatchInited then
        task.spawn(setupHudPatch)
    end

    do
        local fakeGen = 0
        pcall(function()
            fakeGen = calcGeneration(animalName, mutName, traitsList)
        end)
        if fakeGen > 0 then
            activeFakeSlots[slot] = {
                fakeGen = fakeGen,
                realGen = fakeGen,
            }
        end
    end

    local cashPadCleanup = patchCashPad(
        plotModel, slot, animalName, mutName, traitsList)
    SpawnedSlots[slot].cashPadCleanup = cashPadCleanup

    addToFakeIndex(animalName, mutName)
    if refreshTradeSlots then pcall(refreshTradeSlots) end

    return true
end

spawnAnimalAt = function(targetSlot, animalName, mutation, traits)
    return spawnAnimal(animalName, mutation or "None", traits or {}, targetSlot)
end

local function findVFXModel(animalName)
    local data = AnimalsData[animalName]
    if data and data.SpawnVFX and BrainrotAssets then
        local ok, m = pcall(BrainrotAssets.getEffect, data.SpawnVFX)
        if setthreadidentity then pcall(setthreadidentity, 8) end
        if ok and typeof(m) == "Instance" and m:IsA("Model") then return m end
    end
    if not SpawnEffectsController then return nil end
    local displayName = (data and data.DisplayName) or animalName
    local model = SpawnEffectsController:FindFirstChild(animalName)
        or SpawnEffectsController:FindFirstChild(displayName)
    if not model then
        local firstWord = displayName:match("^(%S+)")
        if firstWord and firstWord ~= displayName then
            model = SpawnEffectsController:FindFirstChild(firstWord)
        end
    end
    return (model and model:IsA("Model")) and model or nil
end

local function playVFXAtCFrame(vfxModel, cframe, duration)
    task.spawn(function()
        local clone = vfxModel:Clone()
        local tempPrimary = VFXRoadStartBase and VFXRoadStartBase:Clone()
        if tempPrimary then
            tempPrimary.Parent = clone
            clone.PrimaryPart = tempPrimary
            clone:PivotTo(cframe)
            clone.PrimaryPart = nil
            tempPrimary:Destroy()
        else
            clone:PivotTo(cframe)
        end
        clone.Parent = workspace
        pcall(function() VFX.emit(clone) end)
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("Sound") then
                pcall(function()
                    local attr = d:GetAttribute("SoundId")
                    if attr then d.SoundId = attr end
                    d:Play()
                end)
            end
        end
        task.wait(duration + 10)
        if clone and clone.Parent then
            pcall(function() clone:Destroy() end)
        end
    end)
end

local ROAD_SPEED   = 10
local SPAWN_EVERY  = 3
pcall(function()
    local g = require(ReplicatedStorage.Datas.Game)
    if g.RoadSpawn and type(g.RoadSpawn.AnimalSpeed) == "number" then
        ROAD_SPEED = g.RoadSpawn.AnimalSpeed
    end
    if g.RoadSpawn and type(g.RoadSpawn.SpawnEvery) == "number" then
        SPAWN_EVERY = g.RoadSpawn.SpawnEvery
    end
end)

local fakeDrivers, fakeDriverCount = {}, 0
local fakeDriverHB = nil
local reservedSlots = {}

local function getRoadLanes()
    local lanes = {}
    local road = workspace:FindFirstChild("Road")
    if not road then return lanes end
    local function add(container)
        local st = container:FindFirstChild("Start")
        local en = container:FindFirstChild("End")
        if st and en and st:IsA("BasePart") and en:IsA("BasePart") then
            lanes[#lanes + 1] = {
                start  = st,
                ground = container:FindFirstChild("StartGround") or st,
                ending = en,
            }
        end
    end
    add(road)
    for _, f in ipairs(road:GetChildren()) do
        if f:IsA("Folder") then add(f) end
    end
    return lanes
end

FDX = {}
local SOUND_RARITIES = {
    ["Brainrot God"] = true, ["Secret"] = true, ["OG"] = true, ["Admin"] = true,
    ["Taco"] = true, ["Spooky"] = true, ["Festive"] = true, ["Valentines"] = true,
    ["St Patrick's"] = true, ["Summer"] = true, ["Easter"] = true,
}
local function destroyFakeDriver(d)
    if not fakeDrivers[d] then return end
    fakeDrivers[d] = nil
    fakeDriverCount -= 1
    if fakeDriverCount <= 0 and fakeDriverHB then
        fakeDriverHB:Disconnect()
        fakeDriverHB = nil
    end
    if d.slot and reservedSlots[d.slot] == d then reservedSlots[d.slot] = nil end
    if d.repTraits then
        pcall(function() d.repTraits.Data.traits[d.uid] = nil end)
    end
    if next(fakeDrivers) == nil then
        for m in pairs(FDX.hiddenReal) do FDX.restoreReal(m) end
    end

    if d.model then pcall(function() d.model:Destroy() end) end
end

local PathfindingService = game:GetService("PathfindingService")
local function groundParams()
    local list = {}
    for _, tag in ipairs({"Ground", "Carpet", "roadcarpet", "WalkOver", "walkover"}) do
        for _, i in ipairs(CollectionService:GetTagged(tag)) do list[#list + 1] = i end
    end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Include
    rp.FilterDescendantsInstances = list
    return rp
end

FDX.hiddenReal = {}
FDX.hideScan = 0
function FDX.stashReal(m)

    local st = { prompts = {} }
    for _, pr in ipairs(m:GetDescendants()) do
        if pr:IsA("ProximityPrompt") then
            st.prompts[pr] = pr.Parent
            pr.Enabled = false
            pr.Parent = nil
        end
    end
    FDX.hiddenReal[m] = st
    CollectionService:RemoveTag(m, "Animal")
end
function FDX.restoreReal(m)
    local st = FDX.hiddenReal[m]
    FDX.hiddenReal[m] = nil
    if not st or not m.Parent then return end
    for pr, par in pairs(st.prompts) do
        if par and par.Parent then pr.Parent = par pr.Enabled = true end
    end
    CollectionService:AddTag(m, "Animal")
end
FDX.suppressUntil = 0
FDX.perma = {}
function FDX.stashPerma(m)
    if FDX.perma[m] then return end
    local st = {}
    for _, pr in ipairs(m:GetDescendants()) do
        if pr:IsA("ProximityPrompt") then st[pr] = pr.Parent pr.Enabled = false pr.Parent = nil end
    end
    FDX.perma[m] = st
    CollectionService:RemoveTag(m, "Animal")
end
function FDX.restorePerma()
    for m, st in pairs(FDX.perma) do
        FDX.perma[m] = nil
        if m.Parent then
            for pr, par in pairs(st) do if par and par.Parent then pr.Parent = par pr.Enabled = true end end
            CollectionService:AddTag(m, "Animal")
        end
    end
end

function FDX.watchSuppress()
    if FDX.watching then return end
    FDX.watching = true
    CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(m)
        if os.clock() >= FDX.suppressUntil then return end
        for d in pairs(fakeDrivers) do if d.model == m then return end end
        task.defer(function()
            if os.clock() < FDX.suppressUntil and m.Parent then
                for d in pairs(fakeDrivers) do if d.model == m then return end end
                pcall(FDX.stashPerma, m)
            end
        end)
    end)
end

function FDX.updateOverlapHiding()
    local ours = {}
    for d in pairs(fakeDrivers) do
        if not d.target and d.part.Parent then ours[#ours + 1] = d.part.Position end
    end
    local seen = {}
    local cands = CollectionService:GetTagged("Animal")
    for m in pairs(FDX.hiddenReal) do cands[#cands + 1] = m end
    for _, m in ipairs(cands) do
        local pp = m.PrimaryPart
        local isFake = false
        for d in pairs(fakeDrivers) do if d.model == m then isFake = true break end end
        if pp and not isFake then
            local near = false
            for _, op in ipairs(ours) do
                local a, b = pp.Position, op
                if math.abs(a.X - b.X) < 5 and math.abs(a.Z - b.Z) < 9 then near = true break end
            end
            if near then
                seen[m] = true
                if not FDX.hiddenReal[m] then FDX.stashReal(m) end
            end
        end
    end
    for m in pairs(FDX.hiddenReal) do
        if not seen[m] then FDX.restoreReal(m) end
    end
end

function FDX.laneStartClear(lane)
    local sp = lane.ground.Position
    for _, m in ipairs(CollectionService:GetTagged("Animal")) do
        local pp = m.PrimaryPart
        if pp and math.abs(pp.Position.X - sp.X) < 6 and math.abs(pp.Position.Z - sp.Z) < 12 then
            local ours = false
            for d in pairs(fakeDrivers) do if d.model == m then ours = true break end end
            if not ours then return false end
        end
    end
    return true
end

local function fakeDriverStep(dt)
    FDX.hideScan += dt
    if FDX.hideScan >= 0.2 then
        FDX.hideScan = 0
        pcall(FDX.updateOverlapHiding)
    end
    local now = os.clock()
    for d in pairs(fakeDrivers) do
        local part = d.part
        if not (d.model.Parent and part.Parent) then
            destroyFakeDriver(d)
        elseif d.target then

            local cur = part.Position
            local tp = d.target
            local wps = d.wps
            local goal = tp
            if wps and d.wpi <= #wps then
                goal = wps[d.wpi].Position
                local hz = Vector3.new(goal.X, cur.Y, goal.Z)
                if (hz - cur).Magnitude < 2 then
                    d.wpi += 1
                    if d.wpi > #wps then d.wps = nil; goal = tp end
                end
            end
            if not (d.wps and d.wpi <= #d.wps) and (tp - cur).Magnitude < 2.5 then
                local arrive = d.onArrive
                d.onArrive = nil
                destroyFakeDriver(d)
                if arrive then task.spawn(arrive) end
            else
                local hz = Vector3.new(goal.X, cur.Y, goal.Z)
                local dirV = hz - cur
                local dist = dirV.Magnitude
                if dist > 0.1 then
                    local step = math.min(ROAD_SPEED * dt, dist)
                    local nh = cur + dirV.Unit * step
                    local gy = nh.Y
                    local ok, hit = pcall(function()
                        return workspace:Raycast(nh + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), groundParams())
                    end)
                    if ok and hit then gy = hit.Position.Y
                    else

                        local rp = RaycastParams.new()
                        rp.FilterType = Enum.RaycastFilterType.Exclude
                        local ex = { d.model }
                        local rma = workspace:FindFirstChild("RenderedMovingAnimals")
                        if rma then ex[#ex + 1] = rma end
                        local pl = game:GetService("Players").LocalPlayer.Character
                        if pl then ex[#ex + 1] = pl end
                        rp.FilterDescendantsInstances = ex
                        local h2 = workspace:Raycast(nh + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), rp)
                        if h2 then gy = h2.Position.Y end
                    end
                    local ny
                    if gy >= cur.Y then ny = math.min(gy, cur.Y + 20 * dt)
                    else ny = math.max(gy, cur.Y - 20 * dt) end
                    local np = Vector3.new(nh.X, ny, nh.Z)
                    local want = CFrame.lookAt(np, np + dirV.Unit)
                    part.CFrame = CFrame.new(np) * part.CFrame.Rotation:Lerp(want.Rotation, 0.05)
                end
            end
        else
            local dist = (now - d.t0) * ROAD_SPEED
            if dist >= d.total then
                destroyFakeDriver(d)
            else
                local pos = d.origin + d.dir * dist
                part.CFrame = CFrame.lookAt(pos, pos + d.dir)
            end
        end
    end
end

local function nextFreeSlot(plotModel)
    local podiums = plotModel:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    resolveMyPlot()
    local list = myPlotChannel and myPlotChannel:Get("AnimalList") or {}
    for i = 1, getMaxSlots() do
        if not SpawnedSlots[i] and not reservedSlots[i]
            and (list[i] == nil or list[i] == "Empty")
            and podiums:FindFirstChild(tostring(i)) then
            return i
        end
    end
    return nil
end

local function playAnimalSound(animalName, parent, name)
    if not SoundsAnimals or not parent then return end
    local tpl = SoundsAnimals:FindFirstChild(animalName)
    if not (tpl and tpl:IsA("Sound")) then return end
    local snd = tpl:Clone()
    snd.Name = name or "DarkSpawnerSound"
    local id = tpl:GetAttribute("SoundId")
    if id then snd.SoundId = id end
    snd.Parent = parent
    pcall(function() snd:Play() end)
    snd.Ended:Connect(function() pcall(function() snd:Destroy() end) end)
    snd.Stopped:Connect(function() pcall(function() snd:Destroy() end) end)
end

local function createFakeDriver(animalName, mutation, traits, lane)
    local data = AnimalsData[animalName]
    if not data then return nil, "unknown brainrot" end

    local mutName = (mutation and mutation ~= "None") and mutation or nil
    local delta = lane.ending.Position - lane.start.Position
    local flat = Vector3.new(delta.X, 0, delta.Z)
    local dir = flat.Magnitude > 0 and flat.Unit or Vector3.new(0, 0, 1)
    local origin = lane.ground.Position

    local model = Instance.new("Model")
    model.Name = game:GetService("HttpService"):GenerateGUID(false):lower()
    local part = Instance.new("Part")
    part.Name         = "Part"
    part.Size         = Vector3.new(1, 1, 1)
    part.Transparency = 1
    part.Anchored     = true
    part.CanCollide   = false
    part.CanQuery     = false
    part.CanTouch     = false
    part.CFrame       = CFrame.lookAt(origin, origin + dir)
    part.Parent       = model
    model.PrimaryPart = part

    model:SetAttribute("Index", animalName)
    if mutName then model:SetAttribute("Mutation", mutName) end

    local promptAtt = Instance.new("Attachment")
    promptAtt.Name = "PromptAttachment"
    promptAtt.Parent = part
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Purchase"
    prompt.ObjectText = (data.DisplayName or animalName) .. " $" .. NumberUtils:ToString(data.Price or 0)
    prompt.HoldDuration = 0.25
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false

    prompt.Parent = promptAtt

    local d = {
        model = model, part = part, origin = origin, dir = dir,
        total = flat.Magnitude, t0 = os.clock(), uid = model.Name,
    }

    prompt.Triggered:Connect(function()
        if not fakeDrivers[d] or d.target then return end
        local plotModel = getPlotModel()
        local slot = plotModel and nextFreeSlot(plotModel)
        if not slot then
            if NotificationController then
                pcall(function()
                    NotificationController:Error("You need more room in your base to buy a brainrot.")
                end)
            end
            return
        end
        local podium = plotModel.AnimalPodiums:FindFirstChild(tostring(slot))
        local base = podium and podium:FindFirstChild("Base")
        local spawnPart = base and base:FindFirstChild("Spawn")
        if not spawnPart then return end

        reservedSlots[slot] = d
        d.slot = slot
        pcall(function() prompt:Destroy() end)
        playAnimalSound(animalName, part, animalName)

        local at = plotModel:FindFirstChild("AnimalTarget")
        d.target = at and at.Position or Vector3.new(spawnPart.Position.X, part.Position.Y, spawnPart.Position.Z)
        d.wpi = 1
        task.spawn(function()
            local path = PathfindingService:CreatePath({
                AgentCanJump = true, AgentRadius = 1, Costs = { Avoid = math.huge },
            })
            local ok = pcall(function() path:ComputeAsync(part.Position, d.target) end)
            if ok and path.Status == Enum.PathStatus.Success and fakeDrivers[d] then
                local w = path:GetWaypoints()
                local si = 1
                for i = 1, math.min(5, #w) do
                    if (w[i].Position - part.Position).Magnitude < 3 then si = i + 1 else break end
                end
                d.wps, d.wpi = w, si
            end
        end)
        d.onArrive = function()
            reservedSlots[slot] = nil
            local ok = spawnAnimal(animalName, mutation or "None", traits or {}, slot)
            if ok then pcall(claimFakeLiveboardEntry, d.uid) end
        end
    end)

    fakeDrivers[d] = true
    fakeDriverCount += 1
    if not fakeDriverHB then
        fakeDriverHB = RunService.Heartbeat:Connect(fakeDriverStep)
    end

    local wroteTraits = false
    if traits and #traits > 0 then
        pcall(function()
            local rep = require(ReplicatedStorage.Packages.ReplicatorClient).get("AnimalTraits")
            if rep and type(rep.Data) == "table" then
                rep.Data.traits = rep.Data.traits or {}
                rep.Data.traits[d.uid] = table.clone(traits)
                d.repTraits = rep
                wroteTraits = true
            end
        end)
    end

    model:AddTag("Animal")
    model.Parent = workspace

    if traits and #traits > 0 and not wroteTraits then
        task.spawn(function()
            local rma = workspace:WaitForChild("RenderedMovingAnimals", 5)
            for _ = 1, 100 do
                if not fakeDrivers[d] or not rma then return end
                for _, v in ipairs(rma:GetChildren()) do
                    local pp = v:IsA("Model") and v.PrimaryPart
                    local w = pp and pp:FindFirstChildWhichIsA("Weld")
                    if w and w.Part1 == part then
                        pcall(function() AnimalsShared:ApplyTraits(v, animalName, traits) end)
                        return
                    end
                end
                task.wait(0.1)
            end
        end)
    end

    pcall(postFakeLiveboardEntry, d.uid, animalName, mutName)
    pcall(triggerFakeEvent, animalName)

    if SOUND_RARITIES[data.Rarity]
        and not (mutName == "Divine" and ReplicatedStorage:GetAttribute("DivineStairsEnabled")) then
        playAnimalSound(animalName, part, animalName)
    end

    if data.Rarity == "Secret" and data.DisplayName ~= "Lucky Block" then
        pcall(function()
            game:GetService("TextChatService").TextChannels.RBXSystem:DisplaySystemMessage(
                "<font color='#000000'>[SERVER] A secret Brainrot has spawned!</font>")
        end)
    elseif data.Rarity == "OG" then
        pcall(function()
            game:GetService("TextChatService").TextChannels.RBXSystem:DisplaySystemMessage(
                "<font color='#FFD700'>[SERVER] A " .. (data.DisplayName or animalName) .. " has spawned!</font>")
        end)
    end

    return d
end

local function clearFakeDrivers()
    local list = {}
    for d in pairs(fakeDrivers) do list[#list + 1] = d end
    for _, d in ipairs(list) do destroyFakeDriver(d) end
    FDX.suppressUntil = 0
    FDX.queue = {}
    FDX.notifyQueue()
    pcall(FDX.restorePerma)
end

FDX.launch = function(animalName, mutation, traits, lane)
    local data = AnimalsData[animalName]
    if not data then return false end

    if BrainrotAssets and BrainrotAssets.getModel then
        task.spawn(function()
            pcall(BrainrotAssets.getModel, animalName)
            if setthreadidentity then pcall(setthreadidentity, 8) end
        end)
    end

    local delay = 0
    if data.SpawnVFX then
        local vfxModel = VFX and findVFXModel(animalName)
        delay = data.SpawnDelay
        if not delay and vfxModel then

            local best
            for _, inst in ipairs(vfxModel:GetDescendants()) do
                if inst:IsA("ParticleEmitter") and inst:FindFirstAncestor("endspawnvfx") then
                    local ed = inst:GetAttribute("EmitDelay")
                    if ed and (not best or ed < best) then best = ed end
                end
            end
            if best then delay = math.max(best - 0.1, 0) end
        end
        delay = delay or 3
        FDX.watchSuppress()
        FDX.suppressUntil = math.max(FDX.suppressUntil, os.clock() + delay + SPAWN_EVERY)
        if vfxModel then
            playVFXAtCFrame(vfxModel, lane.start.CFrame, delay)
        end
    end

    if animalName == "Matteo" and data.SpawnVFX then

        pcall(function()
            local snd = ReplicatedStorage.Sounds.Others:FindFirstChild("MatteoAppearanceVoice")
            if snd then
                local c = snd:Clone()
                local attr = c:GetAttribute("SoundId")
                if attr then c.SoundId = attr end
                c.Parent = workspace
                c:Play()
                c.Ended:Once(function() c:Destroy() end)
            end
        end)
    end

    task.spawn(function()
        if delay > 0 then
            task.wait(delay)
        end
        local d = createFakeDriver(animalName, mutation, traits, lane)
        if not d then
            showToast("Spawn failed", "error")
        end
    end)
    return true
end

FDX.queue = {}
FDX.lastTick = os.clock()
FDX.notifyQueue = function()
    if FDX.onQueue then pcall(FDX.onQueue, #FDX.queue) end
end

FDX.takeLaneNearPos = function(pos)
    local best, bestD
    for _, lane in ipairs(getRoadLanes()) do
        local sp = lane.ground.Position
        local dx, dz = math.abs(pos.X - sp.X), math.abs(pos.Z - sp.Z)
        if dx < 8 and dz < 20 and (not bestD or dz < bestD) then best, bestD = lane, dz end
    end
    return best
end

FDX.consume = function(lane)
    if os.clock() < FDX.suppressUntil then return false end
    local item = table.remove(FDX.queue, 1)
    if not item then return false end
    FDX.notifyQueue()
    FDX.launch(item.animalName, item.mutation, item.traits, lane)
    return true
end

FDX.watchTicks = function()
    if FDX.tickWatching then return end
    FDX.tickWatching = true
    CollectionService:GetInstanceAddedSignal("Animal"):Connect(function(m)
        for d in pairs(fakeDrivers) do if d.model == m then return end end
        task.defer(function()
            local pp = m.PrimaryPart
            if not (pp and pp.Parent) then return end
            for d in pairs(fakeDrivers) do if d.model == m then return end end
            local lane = FDX.takeLaneNearPos(pp.Position)
            if not lane then return end
            FDX.lastTick = os.clock()
            if #FDX.queue > 0 and os.clock() >= FDX.suppressUntil then
                pcall(FDX.stashPerma, m)
                FDX.consume(lane)
            end
        end)
    end)
    task.spawn(function()
        while true do
            task.wait(0.25)
            if #FDX.queue > 0 and os.clock() - FDX.lastTick > SPAWN_EVERY + 1.5
                and os.clock() >= FDX.suppressUntil then
                local lanes = getRoadLanes()
                if #lanes > 0 then
                    FDX.lastTick = os.clock()
                    FDX.consume(lanes[1])
                end
            end
        end
    end)
end

spawnCarpetBrainrot = function(animalName, mutation, traits)
    local data = AnimalsData[animalName]
    if not data then return false, "unknown brainrot" end
    if #getRoadLanes() == 0 then return false, "road not found" end
    FDX.watchTicks()
    FDX.watchSuppress()
    FDX.queue[#FDX.queue + 1] = { animalName = animalName, mutation = mutation, traits = traits }
    FDX.notifyQueue()
    return true
end

function clearAll()
    clearFakeDrivers()
    for idx in pairs(SpawnedSlots) do clearSlot(idx) end
    clearPlacePrompts()
    clearHeldModel()
    HeldBrainrot = nil
end

end
if PlayerGui:FindFirstChild("DarkSpawnerGUI") then
    PlayerGui.DarkSpawnerGUI:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name           = "DarkSpawnerGUI"
Gui.ResetOnSpawn   = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true
Gui.Parent         = PlayerGui

local T = {
    bg0       = Color3.fromRGB(8, 8, 12),
    bg1       = Color3.fromRGB(14, 14, 20),
    bg2       = Color3.fromRGB(20, 20, 28),
    bg3       = Color3.fromRGB(28, 28, 40),
    bgHover   = Color3.fromRGB(40, 40, 58),
    bgActive  = Color3.fromRGB(55, 40, 85),
    accent    = Color3.fromRGB(140, 100, 255),
    accent2   = Color3.fromRGB(100, 60, 200),
    accentDim = Color3.fromRGB(70, 45, 140),
    accentGlow= Color3.fromRGB(180, 140, 255),
    green     = Color3.fromRGB(60, 200, 130),
    greenDk   = Color3.fromRGB(30, 140, 90),
    red       = Color3.fromRGB(255, 80, 100),
    redDk     = Color3.fromRGB(160, 40, 55),
    yellow    = Color3.fromRGB(255, 200, 80),
    blue      = Color3.fromRGB(100, 170, 255),
    amber     = Color3.fromRGB(255, 150, 60),
    text      = Color3.fromRGB(235, 230, 245),
    textDim   = Color3.fromRGB(170, 160, 190),
    textMute  = Color3.fromRGB(110, 105, 130),
    border    = Color3.fromRGB(45, 40, 65),
    borderHi  = Color3.fromRGB(100, 80, 160),
    borderGlow= Color3.fromRGB(140, 100, 255),
    rarity = {
        OG              = Color3.fromRGB(255, 215, 0),
        Secret          = Color3.fromRGB(220, 50, 220),
        ["Brainrot God"]= Color3.fromRGB(255, 100, 220),
        Mythic          = Color3.fromRGB(255, 80, 80),
        Legendary       = Color3.fromRGB(255, 165, 0),
        Epic            = Color3.fromRGB(170, 90, 255),
        Rare            = Color3.fromRGB(80, 150, 255),
        Common          = Color3.fromRGB(180, 180, 180),
    }
}

local function rarityColor(rarityName)
    local rd = RaritiesData[rarityName]
    if rd and rd.Color then return rd.Color end
    return T.rarity[rarityName] or T.textDim
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, radius or 8)
    return c
end

local function addStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke", parent)
    s.Color        = color or T.border
    s.Thickness    = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end

local function addPadding(parent, all, horiz, vert)
    local p = Instance.new("UIPadding", parent)
    if all then
        p.PaddingTop = UDim.new(0, all)
        p.PaddingBottom = UDim.new(0, all)
        p.PaddingLeft = UDim.new(0, all)
        p.PaddingRight = UDim.new(0, all)
    else
        p.PaddingLeft = UDim.new(0, horiz or 0)
        p.PaddingRight = UDim.new(0, horiz or 0)
        p.PaddingTop = UDim.new(0, vert or 0)
        p.PaddingBottom = UDim.new(0, vert or 0)
    end
    return p
end

local function addGradient(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient", parent)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    g.Rotation = rotation or 90
    return g
end

local function tween(obj, time, props, style, dir)
    local ti = TweenInfo.new(
        time or 0.15,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, ti, props)
    t:Play()
    return t
end

local ToastLayer = Instance.new("Frame")
ToastLayer.Name             = "ToastLayer"
ToastLayer.Size             = UDim2.new(0, 320, 1, 0)
ToastLayer.AnchorPoint      = Vector2.new(0.5, 0)
ToastLayer.Position         = UDim2.new(0.5, 0, 0, 16)
ToastLayer.BackgroundTransparency = 1
ToastLayer.ZIndex           = 200
ToastLayer.Parent           = Gui
do
    local layout = Instance.new("UIListLayout", ToastLayer)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment   = Enum.VerticalAlignment.Top
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.Padding             = UDim.new(0, 6)
end

local liveToasts = {}
local TOAST_MAX = 4
local TOAST_LIFE = 2.6

local Main, Title, setActiveTab
do
showToast = function(message, kind)
    kind = kind or "info"
    local accent = kind == "success" and T.green or kind == "error" and T.amber or T.accent

    local existing = liveToasts[message]
    if existing and existing.frame.Parent then
        existing.count += 1
        existing.stamp = os.clock()
        existing.badge.Text = "x" .. existing.count
        existing.badge.Visible = true
        local bump = existing.frame.Size
        existing.frame.Size = UDim2.new(1, 6, 0, 40)
        tween(existing.frame, 0.15, { Size = bump })
        return
    end

    local order = 0
    for _, t in pairs(liveToasts) do
        if t.frame.Parent then order += 1 end
    end
    if order >= TOAST_MAX then
        local oldest
        for _, t in pairs(liveToasts) do
            if t.frame.Parent and (not oldest or t.born < oldest.born) then oldest = t end
        end
        if oldest then oldest.kill() end
    end

    local toast = Instance.new("Frame")
    toast.Size                   = UDim2.new(1, 0, 0, 38)
    toast.BackgroundColor3       = T.bg2
    toast.BackgroundTransparency = 0.04
    toast.BorderSizePixel        = 0
    toast.ZIndex                 = 200
    toast.LayoutOrder            = math.floor(os.clock() * 100)
    addCorner(toast, 8)
    local stroke = addStroke(toast, accent, 1, 0.25)

    local bar = Instance.new("Frame", toast)
    bar.Size             = UDim2.new(0, 3, 1, -10)
    bar.Position         = UDim2.new(0, 7, 0, 5)
    bar.BackgroundColor3 = accent
    bar.BorderSizePixel  = 0
    bar.ZIndex           = 201
    addCorner(bar, 2)

    local txt = Instance.new("TextLabel", toast)
    txt.Size                   = UDim2.new(1, -62, 1, 0)
    txt.Position               = UDim2.new(0, 18, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text                   = message
    txt.TextColor3             = T.text
    txt.TextSize               = 12
    txt.Font                   = Enum.Font.GothamMedium
    txt.TextXAlignment         = Enum.TextXAlignment.Left
    txt.TextTruncate           = Enum.TextTruncate.AtEnd
    txt.ZIndex                 = 201

    local badge = Instance.new("TextLabel", toast)
    badge.Size                   = UDim2.new(0, 36, 1, 0)
    badge.Position               = UDim2.new(1, -42, 0, 0)
    badge.BackgroundTransparency = 1
    badge.Text                   = ""
    badge.Visible                = false
    badge.TextColor3             = accent
    badge.TextSize               = 11
    badge.Font                   = Enum.Font.GothamBold
    badge.TextXAlignment         = Enum.TextXAlignment.Right
    badge.ZIndex                 = 201

    toast.Parent = ToastLayer

    local entry = { frame = toast, badge = badge, count = 1, stamp = os.clock(), born = os.clock() }
    liveToasts[message] = entry

    local dead = false
    entry.kill = function()
        if dead then return end
        dead = true
        if liveToasts[message] == entry then liveToasts[message] = nil end
        if not toast.Parent then return end
        tween(toast, 0.2, { BackgroundTransparency = 1 })
        tween(stroke, 0.2, { Transparency = 1 })
        tween(bar, 0.2, { BackgroundTransparency = 1 })
        tween(txt, 0.2, { TextTransparency = 1 })
        tween(badge, 0.2, { TextTransparency = 1 })
        task.delay(0.22, function() toast:Destroy() end)
    end

    local base = toast.Size
    toast.Size = UDim2.new(1, 0, 0, 0)
    tween(toast, 0.18, { Size = base })

    task.spawn(function()
        while not dead do
            task.wait(0.15)
            if os.clock() - entry.stamp >= TOAST_LIFE then
                entry.kill()
            end
        end
    end)
end

local WIN_W, WIN_H = 420, 548
local FOOTER_H = 22
local TITLE_H = 36
local TAB_H = 32

Main = Instance.new("Frame")
Main.Name             = "Main"
Main.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
Main.Position         = UDim2.new(1, -WIN_W - 20, 0.5, -WIN_H/2)
Main.BackgroundColor3 = T.bg0
Main.BorderSizePixel  = 0
Main.Parent           = Gui
if type(Config.window) == "table" then
    local w = Config.window
    Main.Position = UDim2.new(w[1] or 1, w[2] or (-WIN_W - 20), w[3] or 0.5, w[4] or (-WIN_H / 2))
end
addCorner(Main, 12)
addStroke(Main, T.border, 1)
addGradient(Main, T.bg0, Color3.fromRGB(12, 10, 18), 90)

do
    local glow = Instance.new("Frame", Main)
    glow.Name             = "Glow"
    glow.Size             = UDim2.new(1, 4, 1, 4)
    glow.Position         = UDim2.new(0, -2, 0, -2)
    glow.BackgroundTransparency = 1
    glow.ZIndex           = 0
    addCorner(glow, 14)
    addStroke(glow, T.accent, 1, 0.85)
end

local TitleBar = Instance.new("Frame", Main)
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = T.bg1
TitleBar.BorderSizePixel  = 0
addCorner(TitleBar, 12)
addGradient(TitleBar, T.bg1, T.bg2, 90)

local TitleBorder = Instance.new("Frame", TitleBar)
TitleBorder.Size               = UDim2.new(1, -24, 0, 1)
TitleBorder.Position           = UDim2.new(0, 12, 1, -1)
TitleBorder.BackgroundColor3   = T.border
TitleBorder.BorderSizePixel    = 0
TitleBorder.ZIndex             = 2

local AccentDot = Instance.new("Frame", TitleBar)
AccentDot.Size             = UDim2.new(0, 8, 0, 8)
AccentDot.Position         = UDim2.new(0, 14, 0.5, -4)
AccentDot.BackgroundColor3 = T.accent
AccentDot.BorderSizePixel  = 0
addCorner(AccentDot, 4)
addStroke(AccentDot, T.accentGlow, 1, 0.4)

Title = Instance.new("TextLabel", TitleBar)
Title.Size                   = UDim2.new(0, 220, 1, 0)
Title.Position               = UDim2.new(0, 30, 0, 0)
Title.BackgroundTransparency = 1
Title.Text                   = "DARK SPAWNER"
Title.TextColor3             = T.text
Title.TextSize               = 13
Title.Font                   = Enum.Font.GothamBold
Title.TextXAlignment         = Enum.TextXAlignment.Left
Title.TextYAlignment         = Enum.TextYAlignment.Center

local function makeTitleBtn(parent, icon, color, xOffset)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0, 28, 0, 28)
    btn.Position         = UDim2.new(1, xOffset, 0.5, -14)
    btn.BackgroundColor3 = T.bg3
    btn.Text             = icon
    btn.TextColor3       = T.textDim
    btn.TextSize         = 14
    btn.Font             = Enum.Font.GothamBold
    btn.AutoButtonColor  = false
    btn.BorderSizePixel  = 0
    addCorner(btn, 6)
    addStroke(btn, T.border, 1)

    btn.MouseEnter:Connect(function()
        tween(btn, 0.12, { BackgroundColor3 = color, TextColor3 = T.text })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.12, { BackgroundColor3 = T.bg3, TextColor3 = T.textDim })
    end)
    return btn
end

local MinBtn = makeTitleBtn(TitleBar, "-", T.accent, -36)

local QueuePill = Instance.new("TextButton", TitleBar)
QueuePill.Size                   = UDim2.new(0, 84, 0, 20)
QueuePill.Position               = UDim2.new(1, -128, 0.5, -10)
QueuePill.BackgroundColor3       = T.bgActive
QueuePill.BorderSizePixel        = 0
QueuePill.Text                   = ""
QueuePill.TextColor3             = T.text
QueuePill.TextSize               = 10
QueuePill.Font                   = Enum.Font.GothamBold
QueuePill.Visible                = false
QueuePill.AutoButtonColor         = false
addCorner(QueuePill, 10)
addStroke(QueuePill, T.borderHi, 1)

QueuePill.MouseEnter:Connect(function() tween(QueuePill, 0.1, { BackgroundColor3 = T.accent2 }) end)
QueuePill.MouseLeave:Connect(function() tween(QueuePill, 0.1, { BackgroundColor3 = T.bgActive }) end)
QueuePill.MouseButton1Click:Connect(function()
    FDX.queue = {}
    FDX.notifyQueue()
    showToast("Queue cleared", "success")
end)

FDX.onQueue = function(n)
    QueuePill.Visible = n > 0
    QueuePill.Text = "QUEUE  " .. n
end

local TabBar = Instance.new("Frame", Main)
TabBar.Name                   = "TabBar"
TabBar.Size                   = UDim2.new(1, 0, 0, TAB_H)
TabBar.Position               = UDim2.new(0, 0, 0, TITLE_H)
TabBar.BackgroundColor3       = T.bg1
TabBar.BorderSizePixel        = 0
TabBar.ZIndex                 = 3

do
    local p = Instance.new("UIPadding", TabBar)
    p.PaddingLeft  = UDim.new(0, 12)
    p.PaddingRight = UDim.new(0, 12)
    p.PaddingTop   = UDim.new(0, 4)
    p.PaddingBottom = UDim.new(0, 0)
end

local TabLayout = Instance.new("UIListLayout", TabBar)
TabLayout.FillDirection         = Enum.FillDirection.Horizontal
TabLayout.SortOrder             = Enum.SortOrder.LayoutOrder
TabLayout.VerticalAlignment     = Enum.VerticalAlignment.Top
TabLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Left
TabLayout.Padding               = UDim.new(0, 6)

local TabBarBorder = Instance.new("Frame", Main)
TabBarBorder.Size               = UDim2.new(1, 0, 0, 1)
TabBarBorder.Position           = UDim2.new(0, 0, 0, TITLE_H + TAB_H - 1)
TabBarBorder.BackgroundColor3   = T.border
TabBarBorder.BorderSizePixel    = 0
TabBarBorder.ZIndex             = 4

local tabRefs = {}
local activeTabName = nil

function setActiveTab(name)
    activeTabName = name
    for tabName, ref in pairs(tabRefs) do
        local active = (tabName == name)
        ref.content.Visible = active
        tween(ref.btn, 0.12, {
            BackgroundColor3 = active and T.bg2 or T.bg1,
        })
        ref.lbl.TextColor3 = active and T.accent or T.textDim
        ref.indicator.BackgroundTransparency = active and 0 or 1
        ref.lbl.Font = active and Enum.Font.GothamBold or Enum.Font.GothamMedium
    end
end

local function addTab(name, displayText, layoutOrder)
    local btn = Instance.new("TextButton", TabBar)
    btn.Size                   = UDim2.new(0, 128, 1, -4)
    btn.BackgroundColor3       = T.bg1
    btn.BorderSizePixel        = 0
    btn.Text                   = ""
    btn.AutoButtonColor        = false
    btn.LayoutOrder            = layoutOrder
    btn.ZIndex                 = 4
    addCorner(btn, 6)

    local lbl = Instance.new("TextLabel", btn)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = string.upper(displayText)
    lbl.TextColor3             = T.textDim
    lbl.TextSize               = 11
    lbl.Font                   = Enum.Font.GothamMedium
    lbl.ZIndex                 = 5

    local indicator = Instance.new("Frame", btn)
    indicator.Size                   = UDim2.new(1, -16, 0, 2)
    indicator.Position               = UDim2.new(0, 8, 1, -2)
    indicator.BackgroundColor3       = T.accent
    indicator.BackgroundTransparency = 1
    indicator.BorderSizePixel        = 0
    indicator.ZIndex                 = 5
    addCorner(indicator, 1)

    btn.MouseEnter:Connect(function()
        if activeTabName ~= name then
            tween(btn, 0.1, { BackgroundColor3 = T.bg2 })
            lbl.TextColor3 = T.text
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTabName ~= name then
            tween(btn, 0.1, { BackgroundColor3 = T.bg1 })
            lbl.TextColor3 = T.textDim
        end
    end)
    btn.MouseButton1Click:Connect(function()
        setActiveTab(name)
    end)

    local content = Instance.new("Frame")
    content.Name                   = "Tab_" .. name
    content.Size                   = UDim2.new(1, 0, 1, 0)
    content.BackgroundTransparency = 1
    content.Visible                = false

    tabRefs[name] = { btn = btn, lbl = lbl, content = content, indicator = indicator }
    return content
end

local Body = Instance.new("Frame", Main)
Body.Name             = "Body"
Body.Size             = UDim2.new(1, 0, 1, -(TITLE_H + TAB_H + FOOTER_H))
Body.Position         = UDim2.new(0, 0, 0, TITLE_H + TAB_H)
Body.BackgroundTransparency = 1

local Footer = Instance.new("Frame", Main)
Footer.Name                   = "Footer"
Footer.Size                   = UDim2.new(1, 0, 0, FOOTER_H)
Footer.Position               = UDim2.new(0, 0, 1, -FOOTER_H)
Footer.BackgroundColor3       = T.bg1
Footer.BorderSizePixel        = 0
Footer.ZIndex                 = 3
addCorner(Footer, 12)
do
    local line = Instance.new("Frame", Footer)
    line.Size             = UDim2.new(1, 0, 0, 1)
    line.BackgroundColor3 = T.border
    line.BorderSizePixel  = 0
    line.ZIndex           = 4
end

local FooterText = Instance.new("TextLabel", Footer)
FooterText.Size                   = UDim2.new(1, -24, 1, 0)
FooterText.Position               = UDim2.new(0, 12, 0, 0)
FooterText.BackgroundTransparency = 1
FooterText.Text                   = ""
FooterText.TextColor3             = T.textMute
FooterText.TextSize               = 10
FooterText.Font                   = Enum.Font.GothamMedium
FooterText.TextXAlignment         = Enum.TextXAlignment.Left
FooterText.ZIndex                 = 4

task.spawn(function()
    while Gui.Parent do
        local text = ""
        if activeTabName == "plot" then
            local used = 0
            for _ in pairs(SpawnedSlots) do used += 1 end
            text = string.format("%d of %d podiums used", used, getMaxSlots())
        else
            text = "Dark Spawner"
        end
        FooterText.Text = text
        task.wait(0.25)
    end
end)

local function makeSection(parent, name, height, layoutOrder)
    local s = Instance.new("Frame", parent)
    s.Name             = name
    s.Size             = UDim2.new(1, 0, 0, height)
    s.BackgroundColor3 = T.bg1
    s.BorderSizePixel  = 0
    s.LayoutOrder      = layoutOrder
    addCorner(s, 10)
    addStroke(s, T.border, 1)
    return s
end

local function makeSectionLabel(parent, text, color)
    local l = Instance.new("TextLabel", parent)
    l.Size                   = UDim2.new(1, -16, 0, 14)
    l.Position               = UDim2.new(0, 12, 0, 8)
    l.BackgroundTransparency = 1
    l.Text                   = string.upper(text)
    l.TextColor3             = color or T.textDim
    l.TextSize               = 9
    l.Font                   = Enum.Font.GothamBold
    l.TextXAlignment         = Enum.TextXAlignment.Left
    return l
end

local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = input.Position
        startPos  = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                local p = Main.Position
                Config.window = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
                saveConfig()
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

local isMin = false
local minToken = 0
MinBtn.MouseButton1Click:Connect(function()
    isMin = not isMin
    minToken += 1
    local token = minToken
    if isMin then
        Body.Visible   = false
        TabBar.Visible = false
        TabBarBorder.Visible = false
        Footer.Visible = false
        tween(Main, 0.2, { Size = UDim2.new(0, WIN_W, 0, TITLE_H) })
        MinBtn.Text = "+"
    else
        tween(Main, 0.2, { Size = UDim2.new(0, WIN_W, 0, WIN_H) })
        MinBtn.Text = "-"
        task.delay(0.16, function()
            if token ~= minToken or isMin then return end
            Body.Visible   = true
            TabBar.Visible = true
            TabBarBorder.Visible = true
            Footer.Visible = true
        end)
    end
end)

local activeDropdown = nil
local activeDropdownClose = nil
local ownerRows      = setmetatable({}, { __mode = "k" })
local dropdownLayer  = Instance.new("Frame", Gui)
dropdownLayer.Name             = "DropdownLayer"
dropdownLayer.Size             = UDim2.new(1, 0, 1, 0)
dropdownLayer.BackgroundTransparency = 1
dropdownLayer.ZIndex           = 50

local function createDropdown(cfg)
    local title       = cfg.title       or "Select"
    local titleColor  = cfg.titleColor  or T.text
    local multi       = cfg.multi       or false
    local items       = cfg.items       or {}
    local default     = cfg.default     or (multi and {} or "None")
    local onChanged   = cfg.onChanged   or function() end
    local ddHeight    = cfg.ddHeight    or 220
    local rowRender   = cfg.rowRender   or "default"

    local state = {
        isOpen   = false,
        selected = multi and {} or default,
    }

    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 56)
    row.BackgroundColor3 = T.bg2
    row.BorderSizePixel  = 0
    addCorner(row, 10)
    local rowStroke = addStroke(row, T.border, 1)

    local accentBar = Instance.new("Frame", row)
    accentBar.Size               = UDim2.new(0, 3, 1, -16)
    accentBar.Position           = UDim2.new(0, 8, 0, 8)
    accentBar.BackgroundColor3   = titleColor
    accentBar.BorderSizePixel    = 0
    addCorner(accentBar, 2)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                   = UDim2.new(1, -60, 0, 13)
    lbl.Position               = UDim2.new(0, 18, 0, 9)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = string.upper(title)
    lbl.TextColor3             = titleColor
    lbl.TextSize               = 10
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextXAlignment         = Enum.TextXAlignment.Left

    local valContainer = Instance.new("Frame", row)
    valContainer.Size                   = UDim2.new(1, -60, 0, 22)
    valContainer.Position               = UDim2.new(0, 18, 0, 26)
    valContainer.BackgroundTransparency = 1

    local valLbl = Instance.new("TextLabel", valContainer)
    valLbl.Size                   = UDim2.new(1, 0, 1, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                   = multi and "None selected" or default
    valLbl.TextColor3             = T.textMute
    valLbl.TextSize               = 13
    valLbl.Font                   = Enum.Font.GothamMedium
    valLbl.TextXAlignment         = Enum.TextXAlignment.Left
    valLbl.TextTruncate           = Enum.TextTruncate.AtEnd

    local chipContainer = nil
    if multi then
        chipContainer = Instance.new("Frame", valContainer)
        chipContainer.Size                   = UDim2.new(1, 0, 1, 0)
        chipContainer.BackgroundTransparency = 1
        chipContainer.Visible                = false
        local cl = Instance.new("UIListLayout", chipContainer)
        cl.FillDirection      = Enum.FillDirection.Horizontal
        cl.SortOrder          = Enum.SortOrder.LayoutOrder
        cl.Padding            = UDim.new(0, 4)
        cl.VerticalAlignment  = Enum.VerticalAlignment.Center
    end

    local chev = Instance.new("TextLabel", row)
    chev.Size                   = UDim2.new(0, 24, 0, 24)
    chev.Position               = UDim2.new(1, -32, 0.5, -12)
    chev.BackgroundTransparency = 1
    chev.Text                   = "v"
    chev.TextColor3             = T.textDim
    chev.TextSize               = 14
    chev.Font                   = Enum.Font.GothamBold

    local clickBtn = Instance.new("TextButton", row)
    clickBtn.Size                   = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text                   = ""
    clickBtn.AutoButtonColor        = false
    clickBtn.ZIndex                 = 2

    clickBtn.MouseEnter:Connect(function()
        if not state.isOpen then
            tween(rowStroke, 0.12, { Color = T.borderHi })
        end
    end)
    clickBtn.MouseLeave:Connect(function()
        if not state.isOpen then
            tween(rowStroke, 0.12, { Color = T.border })
        end
    end)

    local dd = Instance.new("Frame", dropdownLayer)
    dd.Name             = "Dropdown"
    dd.BackgroundColor3 = T.bg1
    dd.BorderSizePixel  = 0
    dd.Visible          = false
    dd.ZIndex           = 100
    dd.ClipsDescendants = true
    addCorner(dd, 10)
    addStroke(dd, T.borderHi, 1)

    local searchRow = Instance.new("Frame", dd)
    searchRow.Size             = UDim2.new(1, -16, 0, 32)
    searchRow.Position         = UDim2.new(0, 8, 0, 8)
    searchRow.BackgroundColor3 = T.bg3
    searchRow.BorderSizePixel  = 0
    searchRow.ZIndex           = 101
    addCorner(searchRow, 6)
    addStroke(searchRow, T.border, 1)

    local searchBox = Instance.new("TextBox", searchRow)
    searchBox.Size                   = UDim2.new(1, -16, 1, 0)
    searchBox.Position               = UDim2.new(0, 8, 0, 0)
    searchBox.BackgroundTransparency = 1
    searchBox.PlaceholderText        = "Search..."
    searchBox.PlaceholderColor3      = T.textMute
    searchBox.Text                   = ""
    searchBox.TextColor3             = T.text
    searchBox.TextSize               = 11
    searchBox.Font                   = Enum.Font.Gotham
    searchBox.ClearTextOnFocus       = false
    searchBox.TextXAlignment         = Enum.TextXAlignment.Left
    searchBox.ZIndex                 = 102

    local toolbarHeight = 0
    local selectAllBtn, clearAllBtn
    if multi then
        toolbarHeight = 26

        local toolbar = Instance.new("Frame", dd)
        toolbar.Size                   = UDim2.new(1, -16, 0, 22)
        toolbar.Position               = UDim2.new(0, 8, 0, 44)
        toolbar.BackgroundTransparency = 1
        toolbar.ZIndex                 = 101

        selectAllBtn = Instance.new("TextButton", toolbar)
        selectAllBtn.Size             = UDim2.new(0.5, -3, 1, 0)
        selectAllBtn.Position         = UDim2.new(0, 0, 0, 0)
        selectAllBtn.BackgroundColor3 = T.bg3
        selectAllBtn.Text             = "Select All"
        selectAllBtn.TextColor3       = T.accent
        selectAllBtn.TextSize         = 10
        selectAllBtn.Font             = Enum.Font.GothamBold
        selectAllBtn.AutoButtonColor  = false
        selectAllBtn.BorderSizePixel  = 0
        selectAllBtn.ZIndex           = 102
        addCorner(selectAllBtn, 5)
        local saStroke = addStroke(selectAllBtn, T.accentDim, 1, 0.4)
        selectAllBtn.MouseEnter:Connect(function()
            tween(selectAllBtn, 0.1, { BackgroundColor3 = T.bgHover })
            tween(saStroke, 0.1, { Transparency = 0 })
        end)
        selectAllBtn.MouseLeave:Connect(function()
            tween(selectAllBtn, 0.1, { BackgroundColor3 = T.bg3 })
            tween(saStroke, 0.1, { Transparency = 0.4 })
        end)

        clearAllBtn = Instance.new("TextButton", toolbar)
        clearAllBtn.Size             = UDim2.new(0.5, -3, 1, 0)
        clearAllBtn.Position         = UDim2.new(0.5, 3, 0, 0)
        clearAllBtn.BackgroundColor3 = T.bg3
        clearAllBtn.Text             = "Clear"
        clearAllBtn.TextColor3       = T.textDim
        clearAllBtn.TextSize         = 10
        clearAllBtn.Font             = Enum.Font.GothamBold
        clearAllBtn.AutoButtonColor  = false
        clearAllBtn.BorderSizePixel  = 0
        clearAllBtn.ZIndex           = 102
        addCorner(clearAllBtn, 5)
        local caStroke = addStroke(clearAllBtn, T.border, 1, 0)
        clearAllBtn.MouseEnter:Connect(function()
            tween(clearAllBtn, 0.1, { BackgroundColor3 = T.bgHover })
            tween(caStroke, 0.1, { Color = T.red, Transparency = 0.4 })
        end)
        clearAllBtn.MouseLeave:Connect(function()
            tween(clearAllBtn, 0.1, { BackgroundColor3 = T.bg3 })
            tween(caStroke, 0.1, { Color = T.border, Transparency = 0 })
        end)
    end

    local listScroll = Instance.new("ScrollingFrame", dd)
    listScroll.Size                   = UDim2.new(1, -8, 1, -(52 + toolbarHeight))
    listScroll.Position               = UDim2.new(0, 4, 0, 48 + toolbarHeight)
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel        = 0
    listScroll.ScrollBarThickness     = 4
    listScroll.ScrollBarImageColor3   = T.accent
    listScroll.ScrollBarImageTransparency = 0.3
    listScroll.ZIndex                 = 101
    addPadding(listScroll, nil, 4, 0)

    local listLayout = Instance.new("UIListLayout", listScroll)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding   = UDim.new(0, 4)

    local itemBtns = {}

    local function updateChips()
        if not chipContainer then return end
        for _, c in chipContainer:GetChildren() do
            if c:IsA("Frame") then c:Destroy() end
        end
        if #state.selected == 0 then
            valLbl.Visible       = true
            chipContainer.Visible = false
            valLbl.Text          = "None selected"
            valLbl.TextColor3    = T.textMute
            return
        end
        valLbl.Visible       = false
        chipContainer.Visible = true

        local maxChips = 4
        for i, name in ipairs(state.selected) do
            if i > maxChips then
                local more = Instance.new("Frame", chipContainer)
                more.Size             = UDim2.new(0, 28, 0, 16)
                more.BackgroundColor3 = T.bg3
                more.BorderSizePixel  = 0
                more.LayoutOrder      = i
                addCorner(more, 8)
                addStroke(more, T.border, 1)
                local t = Instance.new("TextLabel", more)
                t.Size                   = UDim2.new(1, 0, 1, 0)
                t.BackgroundTransparency = 1
                t.Text                   = "+" .. (#state.selected - maxChips)
                t.TextColor3             = T.textDim
                t.TextSize               = 9
                t.Font                   = Enum.Font.GothamBold
                break
            end

            local td = TraitsData[name]
            local col = (td and td.Color) or T.accent

            local chip = Instance.new("Frame", chipContainer)
            chip.Size             = UDim2.new(0, 0, 0, 18)
            chip.AutomaticSize    = Enum.AutomaticSize.X
            chip.BackgroundColor3 = T.bg3
            chip.BorderSizePixel  = 0
            chip.LayoutOrder      = i
            addCorner(chip, 9)
            addStroke(chip, col, 1, 0.3)
            addPadding(chip, nil, 8, 0)

            local dot = Instance.new("Frame", chip)
            dot.Size             = UDim2.new(0, 5, 0, 5)
            dot.Position         = UDim2.new(0, 0, 0.5, -2)
            dot.BackgroundColor3 = col
            dot.BorderSizePixel  = 0
            addCorner(dot, 3)

            local txt = Instance.new("TextLabel", chip)
            txt.Size                   = UDim2.new(0, 0, 1, 0)
            txt.Position               = UDim2.new(0, 9, 0, 0)
            txt.AutomaticSize          = Enum.AutomaticSize.X
            txt.BackgroundTransparency = 1
            txt.Text                   = name
            txt.TextColor3             = col
            txt.TextSize               = 10
            txt.Font                   = Enum.Font.GothamBold
        end
    end

    local function updateValue()
        if multi then
            updateChips()
        else
            local item = nil
            for _, it in ipairs(items) do
                if it.name == state.selected then item = it break end
            end
            if item then
                valLbl.Text       = item.display or item.name
                valLbl.TextColor3 = item.color or T.text
            else
                valLbl.Text       = state.selected
                valLbl.TextColor3 = T.text
            end
        end
        onChanged(state.selected)
    end

    local function buildItem(item, idx, filter)
        local name    = item.name
        local display = item.display or name

        if filter and filter ~= "" then
            if not string.find(string.lower(display), string.lower(filter), 1, true) then
                return nil
            end
        end

        if rowRender == "card" then
            local barColor = item.barColor or T.accent
            local rarityName = item.rarity or ""
            local rate     = item.right or ""

            local btn = Instance.new("TextButton")
            btn.Size                   = UDim2.new(1, 0, 0, 42)
            btn.BackgroundColor3       = T.bg2
            btn.BorderSizePixel        = 0
            btn.Text                   = ""
            btn.AutoButtonColor        = false
            btn.LayoutOrder            = idx
            btn.ZIndex                 = 102
            btn.Parent                 = listScroll
            addCorner(btn, 7)
            local btnStroke = addStroke(btn, T.border, 1)

            local bar = Instance.new("Frame", btn)
            bar.Size             = UDim2.new(0, 4, 1, -8)
            bar.Position         = UDim2.new(0, 4, 0, 4)
            bar.BackgroundColor3 = barColor
            bar.BorderSizePixel  = 0
            bar.ZIndex           = 103
            addCorner(bar, 2)

            local nameLbl = Instance.new("TextLabel", btn)
            nameLbl.Size                   = UDim2.new(1, -130, 0, 14)
            nameLbl.Position               = UDim2.new(0, 14, 0, 6)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text                   = display
            nameLbl.TextColor3             = T.text
            nameLbl.TextSize               = 12
            nameLbl.Font                   = Enum.Font.GothamBold
            nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
            nameLbl.TextTruncate           = Enum.TextTruncate.AtEnd
            nameLbl.ZIndex                 = 103

            local pill = Instance.new("Frame", btn)
            pill.Size                   = UDim2.new(0, 0, 0, 14)
            pill.Position               = UDim2.new(0, 14, 0, 22)
            pill.AutomaticSize          = Enum.AutomaticSize.X
            pill.BackgroundColor3       = barColor
            pill.BackgroundTransparency = 0.82
            pill.BorderSizePixel        = 0
            pill.ZIndex                 = 103
            addCorner(pill, 7)
            addPadding(pill, nil, 6, 0)

            local pillTxt = Instance.new("TextLabel", pill)
            pillTxt.Size                   = UDim2.new(0, 0, 1, 0)
            pillTxt.AutomaticSize          = Enum.AutomaticSize.X
            pillTxt.BackgroundTransparency = 1
            pillTxt.Text                   = string.upper(rarityName)
            pillTxt.TextColor3             = Color3.new(1, 1, 1)
            pillTxt.TextSize               = 9
            pillTxt.Font                   = Enum.Font.GothamBold
            pillTxt.ZIndex                 = 104

            local rateLbl = Instance.new("TextLabel", btn)
            rateLbl.Size                   = UDim2.new(0, 90, 1, 0)
            rateLbl.Position               = UDim2.new(1, -98, 0, 0)
            rateLbl.BackgroundTransparency = 1
            rateLbl.Text                   = "$" .. rate
            rateLbl.TextColor3             = T.green
            rateLbl.TextSize               = 12
            rateLbl.Font                   = Enum.Font.GothamBold
            rateLbl.TextXAlignment         = Enum.TextXAlignment.Right
            rateLbl.ZIndex                 = 103

            local function refreshState()
                local sel = (state.selected == name)
                if sel then
                    btn.BackgroundColor3 = T.bgActive
                    btnStroke.Color      = barColor
                    btnStroke.Thickness  = 2
                    btnStroke.Transparency = 0
                else
                    btn.BackgroundColor3 = T.bg2
                    btnStroke.Color      = T.border
                    btnStroke.Thickness  = 1
                    btnStroke.Transparency = 0
                end
            end
            refreshState()

            btn.MouseEnter:Connect(function()
                if state.selected ~= name then
                    tween(btn, 0.1, { BackgroundColor3 = T.bgHover })
                    tween(btnStroke, 0.1, { Color = barColor, Transparency = 0.4 })
                end
            end)
            btn.MouseLeave:Connect(function()
                if state.selected ~= name then
                    tween(btn, 0.1, { BackgroundColor3 = T.bg2 })
                    tween(btnStroke, 0.1, { Color = T.border, Transparency = 0 })
                end
            end)
            btn.MouseButton1Click:Connect(function()
                state.selected = name
                updateValue()
                for _, fn in pairs(itemBtns) do
                    if fn.refresh then fn.refresh() end
                end
            end)

            return { btn = btn, refresh = refreshState }
        else
            local btn = Instance.new("TextButton")
            btn.Size                   = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3       = T.bg2
            btn.BorderSizePixel        = 0
            btn.Text                   = ""
            btn.AutoButtonColor        = false
            btn.LayoutOrder            = idx
            btn.ZIndex                 = 102
            btn.Parent                 = listScroll
            addCorner(btn, 6)
            local btnStroke = addStroke(btn, T.border, 1)

            local color = item.color or T.text

            if multi then
                local chk = Instance.new("Frame", btn)
                chk.Size             = UDim2.new(0, 14, 0, 14)
                chk.Position         = UDim2.new(0, 8, 0.5, -7)
                chk.BorderSizePixel  = 0
                chk.ZIndex           = 103
                addCorner(chk, 4)
                local chkStroke = addStroke(chk, color, 1, 0.3)

                local check = Instance.new("TextLabel", chk)
                check.Size                   = UDim2.new(1, 0, 1, 0)
                check.BackgroundTransparency = 1
                check.Text                   = "X"
                check.TextColor3             = Color3.new(1, 1, 1)
                check.TextSize               = 11
                check.Font                   = Enum.Font.GothamBold
                check.ZIndex                 = 104

                local dot = Instance.new("Frame", btn)
                dot.Size             = UDim2.new(0, 4, 0, 14)
                dot.Position         = UDim2.new(0, 28, 0.5, -7)
                dot.BackgroundColor3 = color
                dot.BorderSizePixel  = 0
                dot.ZIndex           = 103
                addCorner(dot, 2)

                local txt = Instance.new("TextLabel", btn)
                txt.Size                   = UDim2.new(1, -42, 1, 0)
                txt.Position               = UDim2.new(0, 38, 0, 0)
                txt.BackgroundTransparency = 1
                txt.Text                   = display
                txt.TextColor3             = color
                txt.TextSize               = 11
                txt.Font                   = Enum.Font.GothamMedium
                txt.TextXAlignment         = Enum.TextXAlignment.Left
                txt.ZIndex                 = 103

                local function refreshState()
                    local sel = table.find(state.selected, name) ~= nil
                    if sel then
                        chk.BackgroundColor3   = color
                        check.Visible          = true
                        chkStroke.Transparency = 0
                        btn.BackgroundColor3   = T.bg3
                    else
                        chk.BackgroundColor3   = T.bg0
                        check.Visible          = false
                        chkStroke.Transparency = 0.3
                        btn.BackgroundColor3   = T.bg2
                    end
                end
                refreshState()

                btn.MouseEnter:Connect(function()
                    tween(btnStroke, 0.1, { Color = color, Transparency = 0.4 })
                end)
                btn.MouseLeave:Connect(function()
                    tween(btnStroke, 0.1, { Color = T.border, Transparency = 0 })
                end)
                btn.MouseButton1Click:Connect(function()
                    local i = table.find(state.selected, name)
                    if i then
                        table.remove(state.selected, i)
                    else
                        table.insert(state.selected, name)
                    end
                    refreshState()
                    updateValue()
                end)

                return { btn = btn, refresh = refreshState }
            else
                local swatch = Instance.new("Frame", btn)
                swatch.Size             = UDim2.new(0, 4, 1, -10)
                swatch.Position         = UDim2.new(0, 6, 0, 5)
                swatch.BackgroundColor3 = color
                swatch.BorderSizePixel  = 0
                swatch.ZIndex           = 103
                addCorner(swatch, 2)

                local txt = Instance.new("TextLabel", btn)
                txt.Size                   = UDim2.new(1, -22, 1, 0)
                txt.Position               = UDim2.new(0, 16, 0, 0)
                txt.BackgroundTransparency = 1
                txt.Text                   = display
                txt.TextColor3             = color
                txt.TextSize               = 11
                txt.Font                   = Enum.Font.GothamMedium
                txt.TextXAlignment         = Enum.TextXAlignment.Left
                txt.ZIndex                 = 103

                local function refreshState()
                    local sel = (state.selected == name)
                    if sel then
                        btn.BackgroundColor3   = T.bgActive
                        btnStroke.Color        = color
                        btnStroke.Thickness    = 1
                        btnStroke.Transparency = 0
                    else
                        btn.BackgroundColor3   = T.bg2
                        btnStroke.Color        = T.border
                        btnStroke.Thickness    = 1
                        btnStroke.Transparency = 0
                    end
                end
                refreshState()

                btn.MouseEnter:Connect(function()
                    if state.selected ~= name then
                        tween(btn, 0.1, { BackgroundColor3 = T.bgHover })
                        tween(btnStroke, 0.1, { Color = color, Transparency = 0.4 })
                    end
                end)
                btn.MouseLeave:Connect(function()
                    if state.selected ~= name then
                        tween(btn, 0.1, { BackgroundColor3 = T.bg2 })
                        tween(btnStroke, 0.1, { Color = T.border, Transparency = 0 })
                    end
                end)
                btn.MouseButton1Click:Connect(function()
                    state.selected = name
                    updateValue()
                    for _, fn in pairs(itemBtns) do
                        if fn.refresh then fn.refresh() end
                    end
                end)

                return { btn = btn, refresh = refreshState }
            end
        end
    end

    local filterItems

    task.spawn(function()
        local rowH = (rowRender == "card") and 42 or 30
        for i, item in ipairs(items) do
            local entry = buildItem(item, i, nil)
            if entry then
                entry.display = string.lower(item.display or item.name)
                table.insert(itemBtns, entry)
            end
            if i % 10 == 0 then
                listScroll.CanvasSize = UDim2.new(0, 0, 0, #itemBtns * (rowH + 4))
                task.wait()
            end
        end
        listScroll.CanvasSize = UDim2.new(0, 0, 0, #itemBtns * (rowH + 4))
        if searchBox.Text ~= "" then filterItems(searchBox.Text) end
    end)

    function filterItems(filter)
        local rowH = (rowRender == "card") and 42 or 30
        local lowerFilter = (filter and filter ~= "") and string.lower(filter) or nil
        local visCount = 0
        for _, entry in ipairs(itemBtns) do
            local show = (not lowerFilter)
                or string.find(entry.display, lowerFilter, 1, true)
            entry.btn.Visible = show ~= nil
            if show then visCount += 1 end
        end
        listScroll.CanvasSize = UDim2.new(0, 0, 0, visCount * (rowH + 4))
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        filterItems(searchBox.Text)
    end)

    if multi and selectAllBtn and clearAllBtn then
        selectAllBtn.MouseButton1Click:Connect(function()
            table.clear(state.selected)
            for _, item in ipairs(items) do
                table.insert(state.selected, item.name)
            end
            updateValue()
            for _, fn in pairs(itemBtns) do
                if fn.refresh then fn.refresh() end
            end
        end)
        clearAllBtn.MouseButton1Click:Connect(function()
            table.clear(state.selected)
            updateValue()
            for _, fn in pairs(itemBtns) do
                if fn.refresh then fn.refresh() end
            end
        end)
    end

    local function positionDD()
        local ap = row.AbsolutePosition
        local as = row.AbsoluteSize
        local screenH = Gui.AbsoluteSize.Y
        local gap     = 6
        local marginBelow = 20

        local layerOffset = dropdownLayer.AbsolutePosition
        local startScreenY = ap.Y + as.Y + gap
        local startParentY = startScreenY - layerOffset.Y
        local startParentX = ap.X - layerOffset.X

        local availBelow = screenH - startScreenY - marginBelow
        local h = math.min(ddHeight, math.max(180, availBelow))

        dd.AnchorPoint = Vector2.new(0, 0)
        dd.Position = UDim2.new(0, startParentX, 0, startParentY)
        dd.Size = UDim2.new(0, as.X, 0, h)
        return h
    end

    local close
    local function open()
        if activeDropdown and activeDropdown ~= dd and activeDropdownClose then
            activeDropdownClose()
        end
        state.isOpen = true
        local finalH = positionDD()
        searchBox.Text = ""
        filterItems("")
        dd.Size = UDim2.new(0, dd.Size.X.Offset, 0, 0)
        dd.Visible = true
        tween(dd, 0.18, { Size = UDim2.new(0, row.AbsoluteSize.X, 0, finalH) })
        tween(rowStroke, 0.15, { Color = T.borderHi })
        tween(chev, 0.15, { Rotation = 180, TextColor3 = T.accent })
        activeDropdown = dd
        activeDropdownClose = close
    end

    close = function()
        state.isOpen = false
        dd.Visible = false
        pcall(function() searchBox:ReleaseFocus() end)
        tween(rowStroke, 0.15, { Color = T.border })
        tween(chev, 0.15, { Rotation = 0, TextColor3 = T.textDim })
        if activeDropdown == dd then
            activeDropdown = nil
            activeDropdownClose = nil
        end
    end

    local function toggle()
        if state.isOpen then close() else open() end
    end

    clickBtn.MouseButton1Click:Connect(toggle)
    ownerRows[dd] = row

    return {
        row     = row,
        dd      = dd,
        state   = state,
        refresh = function() filterItems(searchBox.Text) end,
        close   = close,
        open    = open,
        set     = function(value)
            if multi then
                state.selected = type(value) == "table" and table.clone(value) or {}
            else
                state.selected = value or "None"
            end
            updateValue()
            for _, fn in pairs(itemBtns) do
                if fn.refresh then fn.refresh() end
            end
        end,
    }
end

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        if activeDropdown and activeDropdown.Visible then
            task.defer(function()
                if not activeDropdown or not activeDropdown.Visible then
                    return
                end
                local pos    = input.Position
                local ddPos  = activeDropdown.AbsolutePosition
                local ddSize = activeDropdown.AbsoluteSize

                local insideDD =
                       pos.X >= ddPos.X and pos.X <= ddPos.X + ddSize.X
                   and pos.Y >= ddPos.Y and pos.Y <= ddPos.Y + ddSize.Y

                local insideRow = false
                local ownerRow = ownerRows[activeDropdown]
                if ownerRow then
                    local rp = ownerRow.AbsolutePosition
                    local rs = ownerRow.AbsoluteSize
                    insideRow =
                           pos.X >= rp.X and pos.X <= rp.X + rs.X
                       and pos.Y >= rp.Y and pos.Y <= rp.Y + rs.Y
                end

                if not insideDD and not insideRow then
                    activeDropdown.Visible = false
                    for _, desc in ipairs(activeDropdown:GetDescendants()) do
                        if desc:IsA("TextBox") then
                            pcall(function() desc:ReleaseFocus() end)
                        end
                    end
                    activeDropdown = nil
                end
            end)
        end
    end
end)

local RarityOrder = {
    OG=1, Secret=2, ["Brainrot God"]=3, Mythic=4,
    Legendary=5, Epic=6, Rare=7, Common=8
}

local animalItems = {}
do
    local sorted = {}
    for name, data in pairs(AnimalsData) do
        if type(data) == "table"
           and not data.HideFromIndex
           and not data.Egg
           and not data.LuckyBlock then
            table.insert(sorted, { name = name, data = data })
        end
    end
    table.sort(sorted, function(a, b)
        local oa = RarityOrder[a.data.Rarity] or 99
        local ob = RarityOrder[b.data.Rarity] or 99
        if oa == ob then
            return (a.data.Price or 0) > (b.data.Price or 0)
        end
        return oa < ob
    end)
    for _, e in ipairs(sorted) do
        local rarCol = rarityColor(e.data.Rarity)
        table.insert(animalItems, {
            name     = e.name,
            display  = e.data.DisplayName or e.name,
            color    = T.text,
            barColor = rarCol,
            rarity   = e.data.Rarity or "Common",
            right    = NumberUtils:ToString(e.data.Generation or 0) .. "/s"
        })
    end
end

local mutItems = {{ name = "None", display = "None", color = T.textDim }}
do
    local names = {}
    for name in pairs(MutationsData) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local d = MutationsData[name]
        table.insert(mutItems, {
            name    = name,
            display = d.DisplayText or name,
            color   = d.MainColor   or T.text,
        })
    end
end

local traitItems = {}
do
    local names = {}
    for name in pairs(TraitsData) do table.insert(names, name) end
    table.sort(names)
    for _, name in ipairs(names) do
        local d = TraitsData[name]
        table.insert(traitItems, {
            name    = name,
            display = name,
            color   = d and d.Color or T.text,
        })
    end
end

local recentRebuilders = {}

local function recentKey(entry)
    local traits = entry.traits and table.clone(entry.traits) or {}
    table.sort(traits)
    return entry.name .. "|" .. (entry.mutation or "None") .. "|" .. table.concat(traits, ",")
end

local function pushRecent(name, mutation, traits)
    local entry = {
        name     = name,
        mutation = mutation or "None",
        traits   = traits and table.clone(traits) or {},
    }
    local key = recentKey(entry)
    for i = #Config.recent, 1, -1 do
        if type(Config.recent[i]) ~= "table" or recentKey(Config.recent[i]) == key then
            table.remove(Config.recent, i)
        end
    end
    table.insert(Config.recent, 1, entry)
    while #Config.recent > 8 do table.remove(Config.recent) end
    saveConfig()
    for _, rebuild in ipairs(recentRebuilders) do rebuild() end
end

local function buildSpawnerTab(parent, kind)
    local selectedAnimal   = nil
    local selectedMutation = "None"
    local selectedTraits   = {}
    local selectedSlots    = {}
    local refreshPreview
    local restoring        = true

    local function saveLast()
        if restoring then return end
        Config.last[kind] = {
            name     = selectedAnimal,
            mutation = selectedMutation,
            traits   = selectedTraits and table.clone(selectedTraits) or {},
        }
        saveConfig()
    end

    do
        local p = Instance.new("UIPadding", parent)
        p.PaddingLeft   = UDim.new(0, 14)
        p.PaddingRight  = UDim.new(0, 14)
        p.PaddingTop    = UDim.new(0, 10)
        p.PaddingBottom = UDim.new(0, 10)
    end

    local layout = Instance.new("UIListLayout", parent)
    layout.SortOrder    = Enum.SortOrder.LayoutOrder
    layout.Padding      = UDim.new(0, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local SelectSection = makeSection(parent, "Selection", 226, 1)
    makeSectionLabel(SelectSection, "Selection", T.accent)

    local SelInner = Instance.new("ScrollingFrame", SelectSection)
    SelInner.Size                   = UDim2.new(1, -16, 1, -34)
    SelInner.Position               = UDim2.new(0, 8, 0, 28)
    SelInner.BackgroundTransparency = 1
    SelInner.BorderSizePixel        = 0
    SelInner.ScrollBarThickness     = 4
    SelInner.ScrollBarImageColor3   = T.accent
    SelInner.ScrollBarImageTransparency = 0.3
    SelInner.CanvasSize             = UDim2.new(0, 0, 0, 0)
    SelInner.AutomaticCanvasSize    = Enum.AutomaticSize.Y

    local SelLayout = Instance.new("UIListLayout", SelInner)
    SelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SelLayout.Padding   = UDim.new(0, 6)

    local animalDD = createDropdown({
        title      = "Brainrot",
        titleColor = T.accent,
        multi      = false,
        items      = animalItems,
        default    = "None",
        ddHeight   = 280,
        rowRender  = "card",
        onChanged  = function(val)
            selectedAnimal = (val ~= "None") and val or nil
            saveLast()
            if refreshPreview then refreshPreview() end
        end
    })
    animalDD.row.LayoutOrder = 1
    animalDD.row.Parent      = SelInner

    local mutDD = createDropdown({
        title      = "Mutation",
        titleColor = T.yellow,
        multi      = false,
        items      = mutItems,
        default    = "None",
        ddHeight   = 200,
        onChanged  = function(val)
            selectedMutation = val
            saveLast()
            if refreshPreview then refreshPreview() end
        end
    })
    mutDD.row.LayoutOrder = 2
    mutDD.row.Parent      = SelInner

    local traitDD = createDropdown({
        title      = "Traits",
        titleColor = T.blue,
        multi      = true,
        items      = traitItems,
        ddHeight   = 200,
        onChanged  = function(val)
            selectedTraits = val
            saveLast()
            if refreshPreview then refreshPreview() end
        end
    })
    traitDD.row.LayoutOrder = 3
    traitDD.row.Parent      = SelInner

    local slotDD = nil
    if kind == "plot" then
        task.spawn(function()
            local waited = 0
            while not getPlayerChannel() and waited < 30 do
                task.wait(0.2); waited += 0.2
            end
            local slotItems = {}
            for i = 1, getMaxSlots() do
                slotItems[i] = { name = tostring(i), display = "Slot " .. i, color = T.text }
            end
            slotDD = createDropdown({
                title      = "Target Slots (empty = auto)",
                titleColor = T.green,
                multi      = true,
                items      = slotItems,
                ddHeight   = 260,
                onChanged  = function(val) selectedSlots = val end,
            })
            slotDD.row.LayoutOrder = 4
            slotDD.row.Parent      = SelInner
        end)
    end

    local PreviewSection = makeSection(parent, "Preview", 88, 2)
    makeSectionLabel(PreviewSection, "Preview", T.textDim)

    local PreviewAccent = Instance.new("Frame", PreviewSection)
    PreviewAccent.Size             = UDim2.new(0, 3, 0, 50)
    PreviewAccent.Position         = UDim2.new(0, 12, 0, 26)
    PreviewAccent.BackgroundColor3 = T.textMute
    PreviewAccent.BorderSizePixel  = 0
    addCorner(PreviewAccent, 2)

    local PreviewName = Instance.new("TextLabel", PreviewSection)
    PreviewName.Size                   = UDim2.new(1, -160, 0, 20)
    PreviewName.Position               = UDim2.new(0, 24, 0, 26)
    PreviewName.BackgroundTransparency = 1
    PreviewName.Text                   = "No brainrot selected"
    PreviewName.TextColor3             = T.textMute
    PreviewName.TextSize               = 15
    PreviewName.Font                   = Enum.Font.GothamBold
    PreviewName.TextXAlignment         = Enum.TextXAlignment.Left
    PreviewName.TextTruncate           = Enum.TextTruncate.AtEnd

    local ChipRow = Instance.new("Frame", PreviewSection)
    ChipRow.Size                   = UDim2.new(1, -160, 0, 18)
    ChipRow.Position               = UDim2.new(0, 24, 0, 50)
    ChipRow.BackgroundTransparency = 1

    local ChipLayout = Instance.new("UIListLayout", ChipRow)
    ChipLayout.FillDirection         = Enum.FillDirection.Horizontal
    ChipLayout.SortOrder             = Enum.SortOrder.LayoutOrder
    ChipLayout.VerticalAlignment     = Enum.VerticalAlignment.Center
    ChipLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Left
    ChipLayout.Padding               = UDim.new(0, 4)

    local function makeChip(text, color, layoutOrder)
        local chip = Instance.new("Frame", ChipRow)
        chip.Size               = UDim2.new(0, 0, 0, 17)
        chip.AutomaticSize      = Enum.AutomaticSize.X
        chip.BackgroundColor3   = T.bg2
        chip.BorderSizePixel    = 0
        chip.LayoutOrder        = layoutOrder
        chip.Visible            = false
        addCorner(chip, 4)
        addStroke(chip, color, 1, 0.4)

        local pad = Instance.new("UIPadding", chip)
        pad.PaddingLeft  = UDim.new(0, 7)
        pad.PaddingRight = UDim.new(0, 7)

        local lbl = Instance.new("TextLabel", chip)
        lbl.Size                   = UDim2.new(0, 0, 1, 0)
        lbl.AutomaticSize          = Enum.AutomaticSize.X
        lbl.BackgroundTransparency = 1
        lbl.Text                   = text or ""
        lbl.TextColor3             = color
        lbl.TextSize               = 9
        lbl.Font                   = Enum.Font.GothamBold
        lbl.TextXAlignment         = Enum.TextXAlignment.Center

        return chip, lbl
    end

    local RarityChip,   RarityLbl   = makeChip("",  T.text,   1)
    local MutationChip, MutationLbl = makeChip("",  T.yellow, 2)
    local TraitChip,    TraitLbl    = makeChip("",  T.blue,   3)

    local PreviewRate = Instance.new("TextLabel", PreviewSection)
    PreviewRate.Size                   = UDim2.new(0, 140, 0, 24)
    PreviewRate.Position               = UDim2.new(1, -150, 0, 28)
    PreviewRate.BackgroundTransparency = 1
    PreviewRate.Text                   = "$0/s"
    PreviewRate.TextColor3             = T.green
    PreviewRate.TextSize               = 20
    PreviewRate.Font                   = Enum.Font.GothamBold
    PreviewRate.TextXAlignment         = Enum.TextXAlignment.Right

    local PreviewRateSub = Instance.new("TextLabel", PreviewSection)
    PreviewRateSub.Size                   = UDim2.new(0, 140, 0, 11)
    PreviewRateSub.Position               = UDim2.new(1, -150, 0, 54)
    PreviewRateSub.BackgroundTransparency = 1
    PreviewRateSub.Text                   = "GENERATION / SEC"
    PreviewRateSub.TextColor3             = T.textDim
    PreviewRateSub.TextSize               = 9
    PreviewRateSub.Font                   = Enum.Font.GothamBold
    PreviewRateSub.TextXAlignment         = Enum.TextXAlignment.Right

    refreshPreview = function()
        if selectedAnimal then
            local d = AnimalsData[selectedAnimal]
            local dn = (d and d.DisplayName) or selectedAnimal
            local rar = (d and d.Rarity) or "Common"
            local rcol = rarityColor(rar)

            PreviewName.Text       = dn
            PreviewName.TextColor3 = T.text
            PreviewAccent.BackgroundColor3 = rcol

            RarityChip.Visible = true
            RarityLbl.Text     = string.upper(rar)
            RarityLbl.TextColor3 = rcol
            local rstroke = RarityChip:FindFirstChildOfClass("UIStroke")
            if rstroke then rstroke.Color = rcol end

            if selectedMutation and selectedMutation ~= "None" then
                local md = MutationsData[selectedMutation]
                local mtxt = (md and md.DisplayText) or selectedMutation
                mtxt = mtxt:gsub("<[^>]+>", "")
                MutationChip.Visible = true
                MutationLbl.Text     = string.upper(mtxt)
            else
                MutationChip.Visible = false
            end

            if selectedTraits and #selectedTraits > 0 then
                TraitChip.Visible = true
                TraitLbl.Text     = #selectedTraits ..
                    (#selectedTraits == 1 and " TRAIT" or " TRAITS")
            else
                TraitChip.Visible = false
            end

            local mut = (selectedMutation ~= "None") and selectedMutation or nil
            local traits = (selectedTraits and #selectedTraits > 0) and selectedTraits or nil
            local ok, gen = pcall(function()
                return calcGeneration(selectedAnimal, mut, traits)
            end)
            if ok and gen then
                PreviewRate.Text = "$" .. numToString(gen) .. "/s"
            else
                PreviewRate.Text = "$0/s"
            end
        else
            PreviewName.Text       = "No brainrot selected"
            PreviewName.TextColor3 = T.textMute
            RarityChip.Visible     = false
            MutationChip.Visible   = false
            TraitChip.Visible      = false
            PreviewRate.Text       = "$0/s"
            PreviewAccent.BackgroundColor3 = T.textMute
        end
    end

    local RecentSection = makeSection(parent, "Recent", 54, 3)
    makeSectionLabel(RecentSection, "Recent", T.textDim)

    local RecentScroll = Instance.new("ScrollingFrame", RecentSection)
    RecentScroll.Size                   = UDim2.new(1, -16, 0, 24)
    RecentScroll.Position               = UDim2.new(0, 8, 0, 24)
    RecentScroll.BackgroundTransparency = 1
    RecentScroll.BorderSizePixel        = 0
    RecentScroll.ScrollBarThickness     = 0
    RecentScroll.ScrollingDirection     = Enum.ScrollingDirection.X
    RecentScroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
    RecentScroll.AutomaticCanvasSize    = Enum.AutomaticSize.X

    local RecentLayout = Instance.new("UIListLayout", RecentScroll)
    RecentLayout.FillDirection     = Enum.FillDirection.Horizontal
    RecentLayout.SortOrder         = Enum.SortOrder.LayoutOrder
    RecentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    RecentLayout.Padding           = UDim.new(0, 6)

    local function applyRecent(entry)
        animalDD.set(entry.name)
        mutDD.set(entry.mutation or "None")
        traitDD.set(entry.traits or {})
    end

    local function rebuildRecents()
        for _, c in ipairs(RecentScroll:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        if #Config.recent == 0 then
            local empty = Instance.new("TextLabel", RecentScroll)
            empty.Size                   = UDim2.new(0, 200, 1, 0)
            empty.BackgroundTransparency = 1
            empty.Text                   = "Your last spawns show up here"
            empty.TextColor3             = T.textMute
            empty.TextSize               = 11
            empty.Font                   = Enum.Font.GothamMedium
            empty.TextXAlignment         = Enum.TextXAlignment.Left
            return
        end
        for i, entry in ipairs(Config.recent) do
            local data = AnimalsData[entry.name]
            if data then
                local col = rarityColor(data.Rarity or "Common")
                local label = data.DisplayName or entry.name
                if entry.mutation and entry.mutation ~= "None" then
                    label = label .. " - " .. entry.mutation
                end
                local chip = Instance.new("TextButton", RecentScroll)
                chip.Size             = UDim2.new(0, 0, 0, 22)
                chip.AutomaticSize    = Enum.AutomaticSize.X
                chip.BackgroundColor3 = T.bg3
                chip.BorderSizePixel  = 0
                chip.LayoutOrder      = i
                chip.AutoButtonColor  = false
                chip.Text             = label
                chip.TextColor3       = T.text
                chip.TextSize         = 11
                chip.Font             = Enum.Font.GothamMedium
                addCorner(chip, 6)
                addStroke(chip, col, 1, 0.45)
                addPadding(chip, nil, 9, 0)
                chip.MouseEnter:Connect(function() tween(chip, 0.1, { BackgroundColor3 = T.bgActive }) end)
                chip.MouseLeave:Connect(function() tween(chip, 0.1, { BackgroundColor3 = T.bg3 }) end)
                chip.MouseButton1Click:Connect(function() applyRecent(entry) end)
            end
        end
    end
    table.insert(recentRebuilders, rebuildRecents)
    rebuildRecents()

    local ActionSection = makeSection(parent, "Actions", 50, 4)
    ActionSection.BackgroundTransparency = 1
    ActionSection.BorderSizePixel = 0
    for _, c in ActionSection:GetChildren() do
        if c:IsA("UIStroke") then c:Destroy() end
    end

    local selectedAmount = 1

    local Stepper = Instance.new("Frame", ActionSection)
    Stepper.Size             = UDim2.new(0, 118, 1, 0)
    Stepper.BackgroundColor3 = T.bg2
    Stepper.BorderSizePixel  = 0
    addCorner(Stepper, 8)
    addStroke(Stepper, T.border, 1)

    local AmountLbl = Instance.new("TextLabel", Stepper)
    AmountLbl.Size                   = UDim2.new(1, -72, 1, 0)
    AmountLbl.Position               = UDim2.new(0, 36, 0, 0)
    AmountLbl.BackgroundTransparency = 1
    AmountLbl.Text                   = "1"
    AmountLbl.TextColor3             = T.text
    AmountLbl.TextSize               = 16
    AmountLbl.Font                   = Enum.Font.GothamBold

    local function stepBtn(txt, x, delta)
        local b = Instance.new("TextButton", Stepper)
        b.Size             = UDim2.new(0, 30, 0, 30)
        b.Position         = UDim2.new(0, x, 0.5, -15)
        b.BackgroundColor3 = T.bg3
        b.Text             = txt
        b.TextColor3       = T.text
        b.TextSize         = 16
        b.Font             = Enum.Font.GothamBold
        b.AutoButtonColor  = false
        b.BorderSizePixel  = 0
        addCorner(b, 6)
        b.MouseEnter:Connect(function() tween(b, 0.1, { BackgroundColor3 = T.bgActive }) end)
        b.MouseLeave:Connect(function() tween(b, 0.1, { BackgroundColor3 = T.bg3 }) end)
        b.MouseButton1Click:Connect(function()
            selectedAmount = math.clamp(selectedAmount + delta, 1, 10)
            AmountLbl.Text = tostring(selectedAmount)
        end)
    end
    stepBtn("-", 4, -1)
    stepBtn("+", 84, 1)

    local SpawnBtn = Instance.new("TextButton", ActionSection)
    SpawnBtn.Size             = UDim2.new(1, -126, 1, 0)
    SpawnBtn.Position         = UDim2.new(0, 126, 0, 0)
    SpawnBtn.BackgroundColor3 = T.green
    SpawnBtn.Text             = ""
    SpawnBtn.AutoButtonColor  = false
    SpawnBtn.BorderSizePixel  = 0
    addCorner(SpawnBtn, 8)
    addStroke(SpawnBtn, T.greenDk, 1)
    addGradient(SpawnBtn, T.green, T.greenDk, 90)

    local SpawnLbl = Instance.new("TextLabel", SpawnBtn)
    SpawnLbl.Size                   = UDim2.fromScale(1, 1)
    SpawnLbl.Position               = UDim2.fromScale(0, 0)
    SpawnLbl.BackgroundTransparency = 1
    SpawnLbl.Text                   = kind == "carpet" and "QUEUE SPAWN" or "SPAWN"
    SpawnLbl.TextColor3             = Color3.new(1, 1, 1)
    SpawnLbl.TextSize               = 14
    SpawnLbl.Font                   = Enum.Font.GothamBold

    SpawnBtn.MouseEnter:Connect(function()
        tween(SpawnBtn, 0.12, { BackgroundColor3 = Color3.fromRGB(80, 225, 135) })
    end)
    SpawnBtn.MouseLeave:Connect(function()
        tween(SpawnBtn, 0.12, { BackgroundColor3 = T.green })
    end)

    local function doSpawn()
        if not selectedAnimal then
            local orig = SpawnBtn.Position
            tween(SpawnBtn, 0.05, { Position = orig + UDim2.fromOffset(4, 0) })
            task.wait(0.05)
            tween(SpawnBtn, 0.05, { Position = orig - UDim2.fromOffset(4, 0) })
            task.wait(0.05)
            tween(SpawnBtn, 0.05, { Position = orig })
            showToast("Select a brainrot", "error")
            return
        end
        animalDD.close(); mutDD.close(); traitDD.close()

        local d = AnimalsData[selectedAnimal]
        local dn = (d and d.DisplayName) or selectedAnimal
        local times = selectedAmount > 1 and (" x" .. selectedAmount) or ""

        if kind == "carpet" then
            local queued = 0
            for _ = 1, selectedAmount do
                local ok = spawnCarpetBrainrot(selectedAnimal, selectedMutation, selectedTraits)
                if ok then queued += 1 end
            end
            if queued > 0 then pushRecent(selectedAnimal, selectedMutation, selectedTraits) end
            if queued == selectedAmount then
                showToast("Queued " .. dn .. times, "success")
            elseif queued > 0 then
                showToast("Queued " .. queued .. "/" .. selectedAmount .. " " .. dn, "error")
            else
                showToast("Couldn't queue " .. dn, "error")
            end
            return
        end

        if slotDD then slotDD.close() end

        local plotModel = getPlotModel()
        if not plotModel then
            showToast("No base found", "error")
            return
        end

        local wanted = {}
        if type(selectedSlots) == "table" and #selectedSlots > 0 then
            for _, slotStr in ipairs(selectedSlots) do
                local n = tonumber(slotStr)
                if n then wanted[#wanted + 1] = n end
            end
            table.sort(wanted)
        end

        local placed, attempted = 0, 0
        if #wanted > 0 then
            for _, slot in ipairs(wanted) do
                attempted += 1
                local ok, res = pcall(spawnAnimal, selectedAnimal, selectedMutation, selectedTraits, slot)
                if ok and res then placed += 1 end
            end
        else
            for _ = 1, selectedAmount do
                local slot = getEmptySlot(plotModel)
                if not slot then break end
                attempted += 1
                local ok, res = pcall(spawnAnimal, selectedAnimal, selectedMutation, selectedTraits, slot)
                if ok and res then placed += 1 end
            end
            if attempted == 0 then
                showToast("Base is full", "error")
                return
            end
        end

        if placed > 0 then pushRecent(selectedAnimal, selectedMutation, selectedTraits) end
        if placed == attempted and placed > 0 then
            showToast("Spawned " .. dn .. (placed > 1 and (" x" .. placed) or ""), "success")
        elseif placed > 0 then
            showToast("Spawned " .. placed .. "/" .. attempted .. " " .. dn, "error")
        else
            showToast("Couldn't spawn " .. dn, "error")
        end
    end

    SpawnBtn.MouseButton1Click:Connect(doSpawn)

    do
        local last = Config.last[kind]
        if type(last) == "table" and last.name and AnimalsData[last.name] then
            animalDD.set(last.name)
            mutDD.set(last.mutation or "None")
            traitDD.set(last.traits or {})
        end
        restoring = false
    end

    refreshPreview()

    return {
        animalDD = animalDD,
        mutDD    = mutDD,
        traitDD  = traitDD,
        spawn = doSpawn,
        getSelected = function()
            return selectedAnimal, selectedMutation, selectedTraits
        end,
    }
end

local CarpetTab = addTab("carpet", "Carpet Spawner", 1)
CarpetTab.Parent = Body
local carpetCtl = buildSpawnerTab(CarpetTab, "carpet")

local PlotTab = addTab("plot", "Plot Spawner", 2)
PlotTab.Parent = Body
local plotCtl = buildSpawnerTab(PlotTab, "plot")

local ConfigTab = addTab("config", "Config", 3)
ConfigTab.Parent = Body
do
    local p = Instance.new("UIPadding", ConfigTab)
    p.PaddingLeft = UDim.new(0, 14); p.PaddingRight = UDim.new(0, 14)
    p.PaddingTop = UDim.new(0, 10); p.PaddingBottom = UDim.new(0, 10)
    local lay = Instance.new("UIListLayout", ConfigTab)
    lay.SortOrder = Enum.SortOrder.LayoutOrder; lay.Padding = UDim.new(0, 8)

    local function row(order, label, labelColor, btnText, btnColor, onClick)
        local sec = makeSection(ConfigTab, "Cfg" .. order, 50, order)
        makeSectionLabel(sec, label, labelColor)
        local b = Instance.new("TextButton", sec)
        b.Size = UDim2.new(0, 60, 0, 22); b.Position = UDim2.new(1, -72, 0, 20)
        b.BackgroundColor3 = btnColor; b.TextColor3 = Color3.new(1, 1, 1)
        b.Text = btnText; b.TextSize = 11; b.Font = Enum.Font.GothamBold
        b.BorderSizePixel = 0
        addCorner(b, 6)
        b.Activated:Connect(function() onClick(b) end)
        return b
    end

    row(1, "Auto-Load Layout on Execute", T.textDim,
        Config.autoLoad and "ON" or "OFF", Config.autoLoad and T.green or T.bg3,
        function(b)
            Config.autoLoad = not Config.autoLoad
            b.Text = Config.autoLoad and "ON" or "OFF"
            b.BackgroundColor3 = Config.autoLoad and T.green or T.bg3
            saveConfig()
        end)

    row(2, "Save Current Layout", T.textDim, "SAVE", T.accent, function()
        local saved = {}
        for idx, data in pairs(SpawnedSlots) do
            if not data.realIndex then
                saved[tostring(idx)] = { name = data.animalName, mutation = data.mutation, traits = data.traits }
            end
        end
        Config.layout = saved
        saveConfig()
        showToast("Layout saved", "success")
    end)

    row(3, "Load Saved Layout", T.textDim, "LOAD", T.accent2, function()
        if type(Config.layout) ~= "table" or not next(Config.layout) then
            showToast("No saved layout found", "error"); return
        end
        clearAll()
        for idxStr, entry in pairs(Config.layout) do
            local idx = tonumber(idxStr)
            if idx and type(entry) == "table" and entry.name then
                pcall(spawnAnimalAt, idx, entry.name, entry.mutation, entry.traits)
            end
        end
        showToast("Layout restored", "success")
    end)

    local hotkeyBtn
    local capturing = nil
    hotkeyBtn = row(4, "Spawn Hotkey", T.textDim,
        Config.hotkey or "NONE", T.bg3,
        function(b)
            if capturing then return end
            b.Text = "PRESS KEY"
            capturing = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
                capturing:Disconnect()
                task.defer(function() capturing = nil end)
                if input.KeyCode == Enum.KeyCode.Escape then
                    Config.hotkey = false
                    b.Text = "NONE"
                    showToast("Hotkey removed", "success")
                else
                    Config.hotkey = input.KeyCode.Name
                    b.Text = Config.hotkey
                    showToast("Hotkey set to " .. Config.hotkey, "success")
                end
                saveConfig()
            end)
        end)
    hotkeyBtn.Size     = UDim2.new(0, 96, 0, 22)
    hotkeyBtn.Position = UDim2.new(1, -108, 0, 20)

    row(5, "Reset Window Position", T.textDim, "RESET", T.bg3, function()
        Config.window = false
        Main.Position = UDim2.new(1, -WIN_W - 20, 0.5, -WIN_H / 2)
        saveConfig()
        showToast("Window reset", "success")
    end)

    row(6, "Clear All Spawns", T.red, "CLEAR", T.red, function()
        clearAll()
        showToast("Cleared", "success")
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed or capturing then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if not Config.hotkey or input.KeyCode.Name ~= Config.hotkey then return end
        local ctl = activeTabName == "carpet" and carpetCtl or activeTabName == "plot" and plotCtl
        if ctl then task.spawn(ctl.spawn) end
    end)
end

end
setActiveTab("carpet")

task.spawn(function()
    local TradeGui = PlayerGui:WaitForChild("TradeLiveTrade", 30)
    if not TradeGui then return end
    local TradeFrame = TradeGui:WaitForChild("TradeLiveTrade", 30)
    if not TradeFrame then return end

    local YourPanel = TradeFrame:WaitForChild("Your", 30)
    if not YourPanel then return end
    local YourScrolling = YourPanel:WaitForChild("ScrollingFrame", 30)
    if not YourScrolling then return end

    local Template = YourScrolling:WaitForChild("Template", 30)
    if not Template then return end

    local InterfaceController = require(
        ReplicatedStorage.Controllers.InterfaceController)

    local NotificationController = nil
    pcall(function()
        NotificationController = require(
            ReplicatedStorage.Controllers.NotificationController)
    end)

    local interfaceObj = nil
    for _ = 1, 60 do
        interfaceObj = InterfaceController:Get("TradeLiveTrade")
        if interfaceObj then break end
        task.wait(0.5)
    end
    if not interfaceObj then return end

    local fakeCards = {}

    local function cleanupFakes()
        for _, card in ipairs(fakeCards) do
            pcall(function() card:Destroy() end)
        end
        fakeCards = {}
    end

    local offeredFakeCount = 0
    local pumpReady

    local YourBaseSlots  = YourPanel:FindFirstChild("BaseSlots")
    local OtherPanel     = TradeFrame:FindFirstChild("Other")
    local OtherBaseSlots = OtherPanel and OtherPanel:FindFirstChild("BaseSlots")

    local function resolveTextLabel(node)
        if not node then return nil end
        if node:IsA("TextLabel") or node:IsA("TextButton") then return node end
        for _, c in ipairs(node:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then return c end
        end
        return nil
    end
    local YourBaseSlotsLbl  = resolveTextLabel(YourBaseSlots)
    local OtherBaseSlotsLbl = resolveTextLabel(OtherBaseSlots)

    local realYourText  = (YourBaseSlotsLbl  and YourBaseSlotsLbl.Text)  or nil
    local realOtherText = (OtherBaseSlotsLbl and OtherBaseSlotsLbl.Text) or nil

    local function makeSmartHook(label, signFn, name)
        if not label or not (label:IsA("TextLabel") or label:IsA("TextButton")) then
            return
        end

        local pendingSelfWrites = 0

        local function applyAdjust()
            local realRef = (label == YourBaseSlotsLbl) and realYourText or realOtherText
            if not realRef then return end
            local x, y = realRef:match("^(%-?%d+)/(%d+)$")
            x = tonumber(x); y = tonumber(y)
            if not x or not y then return end
            local newX = x + signFn() * offeredFakeCount
            local newText = newX .. "/" .. y
            if label.Text == newText then return end
            pendingSelfWrites += 1
            label.Text = newText
            label.TextColor3 = (newX > y)
                and Color3.fromRGB(255, 70, 70)
                or  Color3.fromRGB(255, 255, 255)
        end

        label:GetPropertyChangedSignal("Text"):Connect(function()
            if pendingSelfWrites > 0 then
                pendingSelfWrites -= 1
                return
            end
            local current = label.Text
            if label == YourBaseSlotsLbl then
                realYourText = current
            else
                realOtherText = current
            end
            applyAdjust()
        end)

        return applyAdjust
    end

    local applyYourAdjust  = makeSmartHook(YourBaseSlotsLbl,  function() return -1 end, "Your")
    local applyOtherAdjust = makeSmartHook(OtherBaseSlotsLbl, function() return  1 end, "Other")

    local function refreshAdjustments()
        if applyYourAdjust  then applyYourAdjust()  end
        if applyOtherAdjust then applyOtherAdjust() end
        if pumpReady then pumpReady() end
    end
    refreshTradeSlots = refreshAdjustments

    local OtherTimer       = OtherPanel and OtherPanel:FindFirstChild("Timer")
    local OtherReadyButton = OtherPanel and OtherPanel:FindFirstChild("ReadyButton")

    local fakeCooldownUntil = 0
    local fakeCooldownDur   = 5

    local lastAddAt         = 0
    local lastRemoveAt      = 0
    local addRemoveCooldown = 1.5

    if OtherTimer and (OtherTimer:IsA("TextLabel") or OtherTimer:IsA("TextButton")) then
        local pendingSelfWrites = 0
        OtherTimer:GetPropertyChangedSignal("Text"):Connect(function()
            if pendingSelfWrites > 0 then
                pendingSelfWrites -= 1
                return
            end
            local remaining = fakeCooldownUntil - os.clock()
            if remaining > 0 then
                local secs = math.floor(remaining * 10) / 10
                local newText = "⏰" .. tostring(secs) .. "s Left"
                if OtherTimer.Text ~= newText then
                    pendingSelfWrites += 1
                    OtherTimer.Text = newText
                end
            end
        end)
    end

    local grayColor  = Color3.fromRGB(112, 112, 112)
    local greenColor = Color3.fromRGB(81, 158, 86)

    local function desiredReadyColor()
        if fakeCooldownUntil > os.clock() then
            return grayColor
        end
        if offeredFakeCount > 0 then
            return greenColor
        end
        return nil
    end

    if OtherReadyButton and OtherReadyButton:IsA("GuiObject") then
        local pendingSelfWrites = 0
        OtherReadyButton:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            if pendingSelfWrites > 0 then
                pendingSelfWrites -= 1
                return
            end
            local desired = desiredReadyColor()
            if desired and OtherReadyButton.BackgroundColor3 ~= desired then
                pendingSelfWrites += 1
                OtherReadyButton.BackgroundColor3 = desired
            end
        end)
    end

    local pumping = false
    pumpReady = function()
        if pumping then return end
        pumping = true
        task.spawn(function()
            while desiredReadyColor() do
                task.wait(0.1)
                local desired = desiredReadyColor()
                if fakeCooldownUntil > os.clock() then
                local remaining = fakeCooldownUntil - os.clock()
                if OtherTimer and (OtherTimer:IsA("TextLabel") or OtherTimer:IsA("TextButton")) then
                    local secs = math.floor(remaining * 10) / 10
                    OtherTimer.Text = "⏰" .. tostring(secs) .. "s Left"
                end
            end
            if desired and OtherReadyButton and OtherReadyButton:IsA("GuiObject") then
                if OtherReadyButton.BackgroundColor3 ~= desired then
                    OtherReadyButton.BackgroundColor3 = desired
                end
            end
            end
            pumping = false
        end)
    end

    local function triggerFakeCooldown()
        fakeCooldownUntil = os.clock() + fakeCooldownDur
        pumpReady()
    end

    local fakeCardsHidden = false
    local fakeCardData = {}

    local function buildFakeCard(slotIdx, slotData)
        local animalName = slotData.animalName
        local mutation   = slotData.mutation
        local traits     = slotData.traits

        local animalRow = AnimalsData[animalName]
        if not animalRow then return end

        local clone = Template:Clone()
        clone.Name        = "Selection_" .. tostring(slotIdx)
        clone.Visible     = true
        clone.LayoutOrder = slotIdx

        local spacer = clone:FindFirstChild("Spacer")
        if not spacer then
            clone:Destroy()
            return
        end

        local title = spacer:FindFirstChild("Title")
        if title then
            title.Text = animalRow.DisplayName or animalName
        end

        local cashLbl = spacer:FindFirstChild("Cash")
        if cashLbl then
            local ok, gen = pcall(function()
                return calcGeneration(animalName, mutation, traits)
            end)
            if ok and gen then
                cashLbl.Text = "$" .. numToString(gen) .. "/s"
            else
                cashLbl.Text = "$0/s"
            end
        end

        local vp = spacer:FindFirstChild("ViewportFrame")
        if vp then
            pcall(function()
                AnimalsShared:AttachOnViewportWithOptimizations(
                    animalName, vp, nil, mutation)
            end)
        end

        local traitsContainer = spacer:FindFirstChild("Traits")
        local traitTemplate   = traitsContainer
            and traitsContainer:FindFirstChild("Template")
        if traits and traitsContainer and traitTemplate then
            for _, traitName in ipairs(traits) do
                local td = TraitsData[traitName]
                if td then
                    local tclone = traitTemplate:Clone()
                    tclone.Name    = traitName
                    tclone.Visible = true
                    tclone.Image   = td.Icon
                    tclone.Parent  = traitsContainer
                end
            end
        end

        local isOffered  = false
        local onCooldown = false

        local function applyColors()

            local showGreen = isOffered and not fakeCardsHidden
            spacer.BackgroundColor3 = showGreen
                and Color3.fromRGB(15, 50, 15)
                or  Color3.fromRGB(35, 45, 50)
            local stroke = spacer:FindFirstChildWhichIsA("UIStroke")
            if stroke then
                stroke.Color = showGreen
                    and Color3.fromRGB(0, 255, 0)
                    or  Color3.fromRGB(0, 0, 0)
            end
        end
        applyColors()

        if spacer.Activated then
            spacer.Activated:Connect(function()
                if onCooldown then return end

                if fakeCardsHidden then return end

                pcall(function()
                    SoundController:PlaySound("Sounds.Sfx.Activated")
                end)

                local isAdding = not isOffered
                local lastAt   = isAdding and lastAddAt or lastRemoveAt
                local sinceLast = os.clock() - lastAt
                if sinceLast < addRemoveCooldown then
                    if NotificationController then
                        local action = isAdding and "adding" or "removing"
                        pcall(function()
                            NotificationController:Error(
                                "Please wait before " .. action
                                .. " another brainrot")
                        end)
                    end
                    return
                end

                onCooldown = true
                if isAdding then
                    lastAddAt = os.clock()
                else
                    lastRemoveAt = os.clock()
                end

                isOffered = not isOffered
                if isOffered then
                    offeredFakeCount += 1
                else
                    offeredFakeCount -= 1
                end

                if fakeCardData[clone] then
                    fakeCardData[clone].isOffered = isOffered
                end
                applyColors()
                refreshAdjustments()
                triggerFakeCooldown()

                task.delay(0.3, function() onCooldown = false end)
            end)
        end

        clone.Parent = YourScrolling

        fakeCardData[clone] = {
            isOffered = false,
            applyColors = applyColors,
        }

        return clone
    end

    local function applyAcceptScreenState()
        for card, info in pairs(fakeCardData) do
            if card and card.Parent then
                if fakeCardsHidden then

                    card.Visible = info.isOffered
                else

                    card.Visible = true
                end

                if info.applyColors then
                    pcall(info.applyColors)
                end
            end
        end
    end

    local realCardVisibleConn = nil

    local function watchAnyRealCard()
        if realCardVisibleConn then
            pcall(function() realCardVisibleConn:Disconnect() end)
            realCardVisibleConn = nil
        end

        for _, child in ipairs(YourScrolling:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "Template" then
                local idxStr = child.Name:match("^Selection_(%d+)$")
                local idx = tonumber(idxStr)
                if idx then
                    local isFake = false
                    for _, fc in ipairs(fakeCards) do
                        if fc == child then
                            isFake = true
                            break
                        end
                    end
                    if not isFake then
                        watchingRealCard = child
                        realCardVisibleConn = child:GetPropertyChangedSignal("Visible")
                            :Connect(function()
                                fakeCardsHidden = not child.Visible
                                applyAcceptScreenState()
                            end)
                        fakeCardsHidden = not child.Visible
                        applyAcceptScreenState()
                        break
                    end
                end
            end
        end
    end

    local function injectAll()
        cleanupFakes()
        fakeCardsHidden = false
        fakeCardData = {}

        for slotIdx, slotData in pairs(SpawnedSlots) do
            local existing = YourScrolling:FindFirstChild(
                "Selection_" .. tostring(slotIdx))
            if not existing then
                local ok, card = pcall(buildFakeCard, slotIdx, slotData)
                if ok and card then
                    table.insert(fakeCards, card)
                end
            end
        end

        watchAnyRealCard()
    end

    local function sortAllCards()
        for _, child in ipairs(YourScrolling:GetChildren()) do
            if child:IsA("GuiObject") and child.Name ~= "Template" then
                local idxStr = child.Name:match("^Selection_(%d+)$")
                local idx = tonumber(idxStr)
                if idx then
                    child.LayoutOrder = idx
                end
            end
        end
    end

    YourScrolling.ChildAdded:Connect(function(child)
        if not child:IsA("GuiObject") then return end
        if child == Template then return end
        local idx = tonumber(child.Name:match("^Selection_(%d+)$"))
        if idx then
            child.LayoutOrder = idx
        end
    end)

    pcall(function()
        interfaceObj.OnOpen:Connect(function()
            task.wait(0.1)
            injectAll()
            sortAllCards()
        end)
    end)
    pcall(function()
        interfaceObj.OnClose:Connect(function()
            cleanupFakes()
        end)
    end)

    if interfaceObj:IsOpened() then
        task.wait(0.1)
        injectAll()
        sortAllCards()
    end
end)

task.spawn(function()
    task.wait(0.5)
    local plots = workspace:WaitForChild("Plots", 30)
    while not resolveMyPlot() do task.wait(0.2) end
    while not getPlayerChannel() do task.wait(0.2) end

    task.spawn(setupHudPatch)

    if plots then
        local function onPlotsChanged()
            dropSyncCache()
        end
        plots.ChildAdded:Connect(onPlotsChanged)
        plots.ChildRemoved:Connect(onPlotsChanged)
    end

    local function checkRealBrainrotsStillPresent()
        if not myPlotChannel then return end
        local list = myPlotChannel:Get("AnimalList")
        if type(list) ~= "table" then return end
        local toClear
        for slot, data in pairs(SpawnedSlots) do
            if data.realIndex then
                local entry = list[slot]
                local gone = type(entry) ~= "table"
                    or (data.realUUID and entry.UUID and entry.UUID ~= data.realUUID)
                if gone then
                    toClear = toClear or {}
                    toClear[#toClear + 1] = slot
                end
            end
        end
        if toClear then
            for _, slot in ipairs(toClear) do clearSlot(slot) end
        end
    end
    myPlotChannel:OnChanged("AnimalList", function()
        pcall(checkRealBrainrotsStillPresent)
    end)

    pcall(function()
        for _, data in pairs(SpawnedSlots) do
            addToFakeIndex(data.animalName, data.mutation)
        end
    end)

    if Config.autoLoad and type(Config.layout) == "table" and next(Config.layout) then
        for idxStr, entry in pairs(Config.layout) do
            local idx = tonumber(idxStr)
            if idx and type(entry) == "table" and entry.name then
                pcall(spawnAnimalAt, idx, entry.name, entry.mutation, entry.traits)
            end
        end
    end

    LocalPlayer.CharacterRemoving:Connect(onCharacterRespawn)
end)