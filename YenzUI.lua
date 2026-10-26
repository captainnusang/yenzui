-- yenz_spotify.lua — Pixel Lineage Automation Script
-- UI library loaded from GitHub (YenzUI.lua)

repeat task.wait() until game:IsLoaded()

-- Explicit dependencies: locals inside YenzUI.lua are not visible in this file.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local Client = PlayerScripts:WaitForChild("PlatformBattlesClient", 30)
assert(Client, "[Yenz] PlatformBattlesClient was not found within 30 seconds")
if game.PlaceId ~= 126256942507957 then
    warn("[Yenz] Open Pixel Lineage before running this script")
    return
end

-- Unload previous instance
local runtime = getgenv and getgenv() or _G
if runtime.Yenz and runtime.Yenz.Unload then runtime.Yenz.Unload() end
if runtime.PLHub and runtime.PLHub.Unload then runtime.PLHub.Unload() end
for _, root in ipairs({game:GetService("CoreGui"), game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")}) do
    if root then
        for _, child in ipairs(root:GetDescendants()) do
            if child:IsA("ScreenGui") and (child.Name == "YenzUI" or child.Name == "NeverloseUI") then child:Destroy() end
        end
    end
end

-- ── Load UI Library from GitHub ──────────────────────────────────────────────
local YENZUI_URL = "https://raw.githubusercontent.com/captainnusang/yenzui/refs/heads/main/YenzUI.lua"
assert(type(loadstring) == "function", "[Yenz] This environment does not provide loadstring")
local fetched, body = pcall(function() return game:HttpGet(YENZUI_URL, true) end)
assert(fetched, "[Yenz] Could not download YenzUI.lua: " .. tostring(body))
assert(type(body) == "string" and #body > 0, "[Yenz] YenzUI.lua returned an empty response")
local chunk, compileError = loadstring(body, "@YenzUI.lua")
assert(chunk, "[Yenz] YenzUI.lua compile error: " .. tostring(compileError))
local loaded, result = pcall(chunk)
assert(loaded, "[Yenz] YenzUI.lua runtime error: " .. tostring(result))
local Library = result
assert(type(Library) == "table" and type(Library.CreateWindow) == "function",
    "[Yenz] YenzUI.lua must return a Library table with CreateWindow")
assert(type(Library.Icons) == "table", "[Yenz] YenzUI.lua does not export Library.Icons")
assert(type(Library.Flags) == "table", "[Yenz] YenzUI.lua does not export Library.Flags")

-- Self-contained helpers for this script's custom skill priority widget.
local T = Library.Theme or {
    Accent = Color3.fromRGB(132, 110, 255),
    TextMuted = Color3.fromRGB(150, 150, 165),
    TextPrimary = Color3.fromRGB(235, 235, 245),
    CardBackground = Color3.fromRGB(28, 28, 36),
    ToggleOff = Color3.fromRGB(65, 65, 75),
    ToggleThumb = Color3.fromRGB(245, 245, 250),
    SelectedSurface = Color3.fromRGB(48, 44, 68),
}
local F = {Regular = Enum.Font.Gotham, Medium = Enum.Font.GothamMedium}
local function New(className, properties, children)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        if key ~= "Parent" then object[key] = value end
    end
    for _, child in ipairs(children or {}) do child.Parent = object end
    if properties and properties.Parent then object.Parent = properties.Parent end
    return object
end
local function Corner(radius)
    return New("UICorner", {CornerRadius = UDim.new(0, radius)})
end
local function Stroke(color, transparency, thickness)
    return New("UIStroke", {Color = color, Transparency = transparency, Thickness = thickness})
end
local function ListLayout(padding)
    return New("UIListLayout", {Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder})
end
local function Tween(object, seconds, properties)
    local animation = TweenService:Create(object, TweenInfo.new(seconds), properties)
    animation:Play()
    return animation
end
local helperConnections = {}
local function Track(connection)
    helperConnections[#helperConnections + 1] = connection
    return connection
end
local function DisconnectAll()
    for _, connection in ipairs(helperConnections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(helperConnections)
end
local Icons = Library.Icons

local RPGCommand = game:GetService("ReplicatedStorage"):WaitForChild("PlatformBattles", 15):WaitForChild("Remotes", 15):WaitForChild("RPGCommand")
local RPGState   = game:GetService("ReplicatedStorage"):WaitForChild("PlatformBattles", 15):WaitForChild("Remotes", 15):WaitForChild("RPGState")
local shared2    = game:GetService("ReplicatedStorage"):WaitForChild("PlatformBattles", 15):WaitForChild("Shared", 15)
local RunConfig  = require(shared2:WaitForChild("RunConfig"))
local RunModifiers = require(shared2:WaitForChild("RunModifiers"))

local alive = true
local connections = {}  -- gameplay connections (tracked separately for Unload)
local controls = {}
local defaults = {}
local flagTypes = {}
local activeLobby = nil
local lastBattle = nil
local lastBattleActionKey = nil
local lastRunType = nil
local runWorkerActive = false
local runBusy = false
local runStarted = false
local runAttempts = 0
local nextRunAt = 0

local function notice(title, message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title=tostring(title), Text=tostring(message), Duration=4})
    end)
    print("[Yenz] "..tostring(message))
end

local function addControl(group, method, options)
    local control = group[method](group, options)
    if options.Flag and control and control.Set then
        controls[options.Flag] = control
        defaults[options.Flag] = options.Default
        flagTypes[options.Flag] = type(options.Default)
    end
    return control
end

local function safeName(name)
    name = tostring(name or ""):gsub("[^%w _%-]",""):sub(1,48)
    return name:match("^%s*(.-)%s*$")
end

local configFolder = "Yenz/Configs/"..tostring(LocalPlayer.UserId)
local autoloadPath = configFolder.."/autoload.txt"
local function fileReady()
    if not (isfolder and makefolder and isfile and readfile and writefile) then return false end
    pcall(function()
        if not isfolder("Yenz") then makefolder("Yenz") end
        if not isfolder("Yenz/Configs") then makefolder("Yenz/Configs") end
        if not isfolder(configFolder) then makefolder(configFolder) end
    end)
    return isfolder(configFolder)
end

local function configPath(name)
    name = safeName(name)
    if name=="" then return nil end
    return configFolder.."/"..name..".json"
end

-- Skill priority state (v2 model)
local SkillPriorityState = {
    version = 2,
    normal  = {},  -- { key=string, name=string, enabled=bool }
    boss    = {},
}

local function serializableFlags()
    local result = {}
    for flag, value in pairs(Library.Flags) do
        if type(value)=="boolean" or type(value)=="number" or type(value)=="string" then
            result[flag] = value
        end
    end
    -- Embed skill priority v2
    result._skillPriorityV2 = SkillPriorityState
    return result
end

local function saveConfig(name, silent)
    if not fileReady() then if not silent then notice("Config","Executor file access is unavailable") end; return false end
    local path = configPath(name)
    if not path then if not silent then notice("Config","Enter a config name") end; return false end
    local ok = pcall(function() writefile(path, HttpService:JSONEncode(serializableFlags())) end)
    if not silent then notice("Config", ok and ("Saved "..safeName(name)) or "Could not save config") end
    return ok
end

local function loadConfig(name, silent)
    local path = configPath(name)
    if not (fileReady() and path and isfile(path)) then
        if not silent then notice("Config","Config not found for this account") end; return false
    end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data)~="table" then
        if not silent then notice("Config","Invalid config file") end; return false
    end
    for flag, value in pairs(data) do
        if flag ~= "_skillPriorityV2" then
            local control = controls[flag]
            if control and type(value)==flagTypes[flag] then pcall(function() control:Set(value) end) end
        end
    end
    -- Load skill priority v2
    if type(data._skillPriorityV2)=="table" then
        local sp = data._skillPriorityV2
        if type(sp.normal)=="table" then SkillPriorityState.normal = sp.normal end
        if type(sp.boss)=="table" then SkillPriorityState.boss = sp.boss end
    else
        -- Legacy migration: read skill_normal_1..6 / skill_boss_1..6
        local function migrateLegacy(prefix, dest)
            local seen = {}
            for i = 1, 6 do
                local v = data[prefix..i]
                if v and v ~= "None" and v ~= "" and not seen[v] then
                    seen[v] = true
                    dest[#dest+1] = {key=v, name=v, enabled=true}
                end
            end
        end
        SkillPriorityState.normal = {}; SkillPriorityState.boss = {}
        migrateLegacy("skill_normal_", SkillPriorityState.normal)
        migrateLegacy("skill_boss_",   SkillPriorityState.boss)
    end
    if not silent then notice("Config","Loaded "..safeName(name)) end
    return true
end

local function slotGate()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local ui = pg and pg:FindFirstChild("PlatformBattlesUI")
    local root = ui and ui:FindFirstChild("Root")
    return root and root:FindFirstChild("ProfileGate")
end

local function activateNative(button)
    if not (button and button:IsA("GuiButton") and button.Visible and button.Active) then return false end
    if firesignal and pcall(firesignal, button.Activated) then return true end
    if getconnections then
        local ok, list = pcall(getconnections, button.Activated)
        if ok then
            for _, connection in ipairs(list or {}) do
                if connection.Enabled and connection.Fire and pcall(function() connection:Fire() end) then return true end
            end
        end
    end
    return false
end

local function selectCharacterSlot(number)
    local gate = slotGate()
    if not (gate and gate.Visible) then return false end
    local slotsPage = gate:FindFirstChild("CharacterSlotsPage")
    if not slotsPage then return false end
    if not (slotsPage and slotsPage.Visible) then
        local main = gate:FindFirstChild("MainMenuPage")
        local menu = main and main:FindFirstChild("MainMenu")
        local inner = menu and menu:FindFirstChild("Inner")
        if not activateNative(inner and inner:FindFirstChild("CharacterSelect")) then return false end
        local deadline = os.clock()+4
        repeat task.wait(0.1) until slotsPage.Visible or os.clock()>=deadline
    end
    if not slotsPage.Visible then return false end
    local window = slotsPage:FindFirstChild("SlotsWindow")
    local inner = window and window:FindFirstChild("Inner")
    local cards = inner and inner:FindFirstChild("SlotCards")
    local card = cards and cards:FindFirstChild("Slot"..tostring(number))
    local cardInner = card and card:FindFirstChild("Inner")
    local action = cardInner and cardInner:FindFirstChild("Action")
    local label = action and tostring(action.Text or ""):upper() or ""
    if label=="" or label:find("LOCK",1,true) or label:find("UNLOCK",1,true)
        or label:find("R$",1,true) or label:find("CREATE",1,true) then return false end
    return activateNative(action)
end

local function difficultyId(runType)
    if runType=="Torment" then
        local tier = tonumber(tostring(Library.Flags.run_tormenttier or "Torment 1"):match("%d+")) or 1
        local option = RunConfig.TormentDifficulty(tier)
        return option and option.id, 1
    end
    local choice = tostring(Library.Flags.run_diff or "Normal"):lower()
    for _, value in ipairs(RunConfig.Difficulties or {}) do
        if tostring(value.name or value.id):lower()==choice then
            return value.id, math.clamp(tonumber(Library.Flags.run_startact) or 1, 1, #RunConfig.Acts)
        end
    end
    return nil, nil
end

local function chosenModifier()
    local label = tostring(Library.Flags.run_modifier or "None")
    if label=="Random" then
        local list={}
        for _, value in ipairs(RunModifiers.List or {}) do
            if tostring(value.id)~="none" then list[#list+1]=value end
        end
        if #list>0 then return list[math.random(1,#list)].id end
    end
    for _, value in ipairs(RunModifiers.List or {}) do
        if tostring(value.name or value.id):lower()==label:lower() then return value.id end
    end
    return "none"
end

local function waitLobby(predicate, seconds)
    local deadline = os.clock()+seconds
    repeat
        if activeLobby and predicate(activeLobby) then return true end
        task.wait(0.1)
    until not alive or os.clock()>=deadline
    return false
end

local function startRun(runType)
    if runBusy or not alive then return false end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local village = pg and pg:FindFirstChild("PlatformBattlesVillage")
    if not (village and village.Enabled) then notice("Run","Enter the Village first"); return false end
    local diff, act = difficultyId(runType)
    if not diff then notice("Run","Selected difficulty is unavailable"); return false end
    if activeLobby and activeLobby.state=="lobby" and activeLobby.hostUserId~=LocalPlayer.UserId then
        notice("Run","The current lobby belongs to another host"); return false
    end
    runBusy=true; local ok=false
    local success, err = pcall(function()
        local host = activeLobby and activeLobby.state=="lobby" and activeLobby.hostUserId==LocalPlayer.UserId
        if not host then
            RPGCommand:FireServer("RunLobby",{action="host",difficulty=diff,startAct=act})
        elseif activeLobby.difficulty~=diff or tonumber(activeLobby.startAct)~=act then
            RPGCommand:FireServer("RunLobby",{action="difficulty",difficulty=diff,startAct=act})
        end
        if not waitLobby(function(s) return s.state=="lobby" and s.hostUserId==LocalPlayer.UserId and s.difficulty==diff and tonumber(s.startAct)==act end, 6) then
            error("Difficulty or Act was rejected") end
        local modifier = chosenModifier()
        if activeLobby.modifier~=modifier then
            RPGCommand:FireServer("RunLobby",{action="modifier",modifier=modifier})
            if not waitLobby(function(s) return s.modifier==modifier end,6) then error("Modifier was rejected") end
        end
        for _, member in ipairs(type(activeLobby.members)=="table" and activeLobby.members or {}) do
            if member.userId~=LocalPlayer.UserId and not member.ready then error("A party member is not ready") end
        end
        RPGCommand:FireServer("RunLobby",{action="start",revision=activeLobby.revision})
        lastRunType=runType; runAttempts+=1; nextRunAt=os.clock()+10; ok=true
    end)
    runBusy=false
    if not success then notice("Run",tostring(err):match("[^:]+$") or "Run request failed") end
    return ok
end

local function startRunWorker()
    if runWorkerActive then return end
    runWorkerActive=true
    task.spawn(function()
        while alive do
            local enabled = Library.Flags.farm_autofarm==true or (Library.Flags.run_autoreplay==true and lastRunType~=nil)
            if not enabled then break end
            if LocalPlayer:GetAttribute("PBInRun")==true then
                runStarted=true; runAttempts=0
            elseif runStarted then
                runStarted=false; activeLobby=nil; nextRunAt=os.clock()+2
            elseif os.clock()>=nextRunAt and not runBusy then
                if runAttempts>=3 then
                    notice("Run","Run start was not accepted; automation stopped")
                    if controls.farm_autofarm then controls.farm_autofarm:Set(false) end
                    if controls.run_autoreplay then controls.run_autoreplay:Set(false) end
                    break
                end
                startRun(lastRunType or "Story")
            end
            task.wait(0.75)
        end
        runWorkerActive=false
    end)
end

-- PixelQTE patch
local pixelQTE = require(Client:WaitForChild("PixelQTE"))
local originalHandle, hookedHandle
do
    local mt = getmetatable(pixelQTE)
    if mt and rawget(mt,"Handle") then
        originalHandle = rawget(mt,"Handle")
        hookedHandle = function(self, event, payload)
            if alive and Library.Flags.battle_autoperfect==true
                and type(payload)=="table" and payload.battleId~=nil and payload.token~=nil then
                if event=="DefenseTimingStarted" or event=="DefenseTimingResolved" then return true end
            end
            return originalHandle(self,event,payload)
        end
        mt.Handle = hookedHandle
    else
        originalHandle = pixelQTE.Handle
        hookedHandle = function(self, event, payload)
            if alive and Library.Flags.battle_autoperfect==true
                and type(payload)=="table" and payload.battleId~=nil and payload.token~=nil then
                if event=="DefenseTimingStarted" or event=="DefenseTimingResolved"
                    or event=="WarriorBladeTimingStarted" or event=="MageRhythmStarted"
                    or event=="ThiefSlashStarted" then return true end
            end
            return originalHandle(self,event,payload)
        end
        pixelQTE.Handle = hookedHandle
    end
end

local _handledQteTokens = {}

local function answerDefense(payload)
    if not alive or Library.Flags.battle_autoperfect~=true then return end
    if type(payload)~="table" or not payload.battleId or not payload.token then return end
    local key = "def:"..tostring(payload.token)
    if _handledQteTokens[key] then return end
    _handledQteTokens[key]=true
    local startedAt = tonumber(payload.startedAt)
    if not startedAt then return end
    if type(payload.marks)=="table" and #payload.marks>0 then
        local duration = math.max(0.2, tonumber(payload.duration) or 2)
        for _, m in ipairs(payload.marks) do
            if not alive then return end
            local hitAt = startedAt + math.clamp(tonumber(m) or 0.5,0,1)*duration
            local w = hitAt+0.012-workspace:GetServerTimeNow()
            if w>0 then task.wait(w) end
            if not alive then return end
            RPGCommand:FireServer("DefenseTimingInput",{battleId=payload.battleId,token=payload.token,pressedAt=workspace:GetServerTimeNow()})
        end
    else
        local target = tonumber(payload.target)
        if not target then return end
        local hitAt = startedAt+target*(tonumber(payload.duration) or 0.85)
        local w = hitAt+0.012-workspace:GetServerTimeNow()
        if w>0 then task.wait(w) end
        if not alive then return end
        RPGCommand:FireServer("DefenseTimingInput",{battleId=payload.battleId,token=payload.token,pressedAt=workspace:GetServerTimeNow()})
    end
end

local function answerMinigame(event, payload)
    return -- Attack minigames: synthetic results rejected by current server path
    -- (dead code below preserved from original)
end

local RunMapView = require(Client:WaitForChild("RunMapView"))
local originalRunMapUpdate = RunMapView.Update
local hookedRunMapUpdate
local lastPathVote = nil
hookedRunMapUpdate = function(self)
    local result = originalRunMapUpdate(self)
    if not alive or Library.Flags.farm_autovotepath~=true then return result end
    local state = self.state
    if type(state)~="table" or state.phase~="choose" or type(state.choices)~="table" then return result end
    local priority = tostring(Library.Flags.farm_pathpriority or "First")
    local index = 1
    if priority~="First" then
        for i, choice in ipairs(state.choices) do
            local label = type(choice)=="table" and tostring(choice.type or choice.name or choice.id or "") or tostring(choice)
            if label:lower():find(priority:lower(),1,true) then index=i; break end
        end
    end
    local voteKey = tostring(state.id)..":"..tostring(state.round)..":"..tostring(index)
    if #state.choices>0 and voteKey~=lastPathVote then
        local sent = pcall(function() self:_send("vote",{choice=index}) end)
        if sent then lastPathVote=voteKey end
    end
    return result
end
RunMapView.Update = hookedRunMapUpdate

-- Skill discovery
local skillDropdowns = {}
local knownSkillNames = {"None"}
local _skillListViews = {}  -- registered drag-list views to refresh on discovery

local function actionCategory(action)
    local value = tostring(action.category or action.kind or action.id or ""):lower()
    if value:find("skill",1,true) or value:find("spell",1,true) or value:find("ability",1,true) then return "Skill" end
    if value:find("potion",1,true) or value:find("item",1,true) or value:find("bag",1,true) then return "Item" end
    if value=="gearscroll" or value:find("scroll",1,true) then return "Scroll" end
    if value:find("guard",1,true) or value:find("block",1,true) then return "Guard" end
    if value:find("meditate",1,true) or value:find("flee",1,true) or value:find("run",1,true) then return "Utility" end
    return "Attack"
end

local function updateSkillOptions(actions)
    local names = {"None"}
    local seen = {}
    for _, action in ipairs(actions) do
        if type(action)=="table" and actionCategory(action)=="Skill" then
            local name = tostring(action.name or action.id or "")
            if name~="" and not seen[name] then
                seen[name]=true; names[#names+1]=name
            end
        end
    end
    table.sort(names, function(a,b)
        if a=="None" then return true end; if b=="None" then return false end; return a<b
    end)
    local signature = table.concat(names,"|")
    if signature==table.concat(knownSkillNames,"|") then return end
    knownSkillNames = names

    -- Update legacy dropdown controls
    for _, dropdown in ipairs(skillDropdowns) do dropdown:Refresh(names) end

    -- Update skill priority list views (new drag-list widget)
    for _, view in ipairs(_skillListViews) do
        if type(view.onDiscover)=="function" then view.onDiscover(names) end
    end

    -- Append newly discovered skills to SkillPriorityState (default disabled)
    local function appendNewSkills(list)
        local existing = {}
        for _, entry in ipairs(list) do existing[entry.key]=true end
        for _, name in ipairs(names) do
            if name~="None" and not existing[name] then
                list[#list+1] = {key=name, name=name, enabled=false}
            end
        end
    end
    appendNewSkills(SkillPriorityState.normal)
    appendNewSkills(SkillPriorityState.boss)
end

local function currentHP(snapshot)
    for _, member in ipairs(type(snapshot.party)=="table" and snapshot.party or {}) do
        if type(member)=="table" and tonumber(member.userId)==LocalPlayer.UserId then
            return tonumber(member.hp), tonumber(member.maxHp)
        end
    end
    if type(snapshot.player)=="table" then return tonumber(snapshot.player.hp), tonumber(snapshot.player.maxHp) end
    return nil, nil
end

local function firstEnemy(snapshot)
    for _, enemy in ipairs(type(snapshot.enemies)=="table" and snapshot.enemies or {}) do
        if type(enemy)=="table" then
            local actor = enemy.actor or enemy
            local hp = tonumber(actor.hp)
            if hp and hp>0 then return tonumber(enemy.index) or 1, hp, tonumber(actor.maxHp) end
        end
    end
    return tonumber(snapshot.currentEnemyIndex) or tonumber(snapshot.activeEnemyIndex) or 1, nil, nil
end

-- Updated battleAction uses SkillPriorityState (v2 model, unlimited slots)
local function battleAction(snapshot)
    if not snapshot.canAct then return nil end
    local actions = type(snapshot.actions)=="table" and snapshot.actions or {}
    local boss = snapshot.boss==true
    if not boss then
        for _, enemy in ipairs(type(snapshot.enemies)=="table" and snapshot.enemies or {}) do
            if type(enemy)=="table" then
                local actor = enemy.actor or enemy
                if actor.boss==true or actor.isBoss==true then boss=true; break end
            end
        end
    end
    -- Guard on boss brace
    if Library.Flags.battle_autoguardbrace==true then
        local function hasBrace(statuses)
            if type(statuses)~="table" then return false end
            for k, v in pairs(statuses) do
                if k=="BossBrace" or v=="BossBrace"
                    or (type(v)=="table" and (v.id=="BossBrace" or v.name=="BossBrace")) then return true end
            end
            return false
        end
        local bracing=false
        for _, enemy in ipairs(type(snapshot.enemies)=="table" and snapshot.enemies or {}) do
            if type(enemy)=="table" then
                local actor=enemy.actor or enemy
                if actor.brace or actor.telegraph or actor.bracing or hasBrace(actor.statuses) or hasBrace(enemy.statuses) then
                    bracing=true; break end
            end
        end
        if bracing then
            for _, action in ipairs(actions) do
                if type(action)=="table" and action.enabled~=false and actionCategory(action)=="Guard" then return action end
            end
        end
    end
    -- Skill priority (v2 model)
    if Library.Flags.skill_auto_enabled==true then
        local priorityList = boss and SkillPriorityState.boss or SkillPriorityState.normal
        -- Build an immutable snapshot for this turn
        local snapshot_list = {}
        for _, entry in ipairs(priorityList) do snapshot_list[#snapshot_list+1]=entry end

        for _, entry in ipairs(snapshot_list) do
            if entry.enabled and entry.key and entry.key~="None" and entry.key~="" then
                for _, action in ipairs(actions) do
                    if type(action)=="table" and action.enabled~=false
                        and actionCategory(action)=="Skill"
                        and (tostring(action.name or action.id)==entry.key or tostring(action.id)==entry.key) then
                        return action
                    end
                end
            end
        end
        -- Burst fallback (highest-cost available skill)
        if Library.Flags.skill_burst==true then
            local strongest
            for _, action in ipairs(actions) do
                if type(action)=="table" and action.enabled~=false and actionCategory(action)=="Skill" then
                    if not strongest or (tonumber(action.cost) or 0)>(tonumber(strongest.cost) or 0) then
                        strongest=action end
                end
            end
            if strongest then return strongest end
        end
    end
    -- Basic attack fallback
    for _, action in ipairs(actions) do
        if type(action)=="table" and action.enabled~=false and actionCategory(action)=="Attack" then return action end
    end
    -- Utility last resort
    for _, action in ipairs(actions) do
        if type(action)=="table" and action.enabled~=false and actionCategory(action)=="Utility" then return action end
    end
    return nil
end

local lastBattleActionAt = nil

local function recoverBattleSnap()
    if not (RPGState and getconnections and debug and debug.getupvalues) then return end
    pcall(function()
        for _, c in ipairs(getconnections(RPGState.OnClientEvent)) do
            local fn = c.Function
            if not fn then continue end
            local seen = {}
            local function walk(f, depth)
                if lastBattle or depth>6 or seen[f] then return end
                seen[f]=true
                local ok, uvs = pcall(debug.getupvalues, f)
                if not ok then return end
                for _, v in ipairs(uvs) do
                    if type(v)=="table" and (rawget(v,"activeEnemyIndex")~=nil or rawget(v,"currentEnemyIndex")~=nil) then
                        lastBattle=v; return
                    elseif type(v)=="function" then walk(v,depth+1) end
                end
            end
            walk(fn,1)
            if lastBattle then break end
        end
    end)
end

local function handleBattle(snapshot)
    if type(snapshot)~="table" or snapshot.id==nil then return end
    lastBattle=snapshot
    local actions = type(snapshot.actions)=="table" and snapshot.actions or {}
    updateSkillOptions(actions)
    if not snapshot.canAct then lastBattleActionKey=nil; return end
    if snapshot.activeUnit and snapshot.activeUnit~="Player" then return end
    local turnId = snapshot.turnNumber or snapshot.revision or snapshot.round or snapshot.turn or snapshot.seq or os.clock()
    local key = tostring(snapshot.id)..":"..tostring(turnId)..":"..tostring(snapshot.activeUnit or "")
    if key==lastBattleActionKey and os.clock()-(lastBattleActionAt or 0)<4 then return end
    local selected = nil
    local hp, maxHp = currentHP(snapshot)
    if Library.Flags.battle_autopotion==true and hp and maxHp and maxHp>0
        and hp/maxHp*100<=(tonumber(Library.Flags.battle_potionhp) or 60)
        and (tonumber(snapshot.potions) or 0)>0 then
        for _, action in ipairs(actions) do
            if type(action)=="table" and action.enabled~=false and actionCategory(action)=="Item" then
                local label=(tostring(action.id or "").." "..tostring(action.name or "")):lower()
                if label:find("potion",1,true) then selected=action; break end
            end
        end
    end
    selected = selected or battleAction(snapshot)
    if not selected then return end
    local payload = {battleId=snapshot.id, actionId=selected.id}
    if tostring(selected.targetType or "Self")=="Enemy" then payload.targetEnemyIndex=firstEnemy(snapshot) end
    if tostring(selected.targetType or "Self")=="Ally" then payload.targetUserId=LocalPlayer.UserId end
    lastBattleActionKey=key; lastBattleActionAt=os.clock()
    RPGCommand:FireServer("CombatAction",payload)
end

connections[#connections+1] = RPGState.OnClientEvent:Connect(function(kind, payload)
    if not alive then return end
    if kind=="RunLobby" and type(payload)=="table" then
        activeLobby=payload
    elseif kind=="BattleStarted" or kind=="BattleUpdated" then
        local snapshot = type(payload)=="table" and (payload.snapshot or payload.battle or payload) or nil
        if snapshot then task.defer(handleBattle,snapshot) end
    elseif kind=="BattleEnded" then
        lastBattle,lastBattleActionKey,lastBattleActionAt=nil,nil,nil
        table.clear(_handledQteTokens)
    elseif type(payload)=="table" then
        if kind=="DefenseTimingStarted" then
            task.spawn(answerDefense,payload)
        elseif kind=="MageRhythmStarted" or kind=="WarriorBladeTimingStarted" or kind=="ThiefSlashStarted" then
            task.spawn(answerMinigame,kind,payload)
        end
    end
end)

task.spawn(function()
    for _=1,5 do
        task.wait(1.2)
        if not alive then return end
        if LocalPlayer:GetAttribute("InTurnBattle")==true and not lastBattle then
            recoverBattleSnap()
            if lastBattle then task.spawn(handleBattle,lastBattle) end
        end
    end
    while alive do
        task.wait(5)
        if LocalPlayer:GetAttribute("InTurnBattle")==true
            and (not lastBattle or (lastBattle.canAct and os.clock()-(lastBattleActionAt or 0)>8)) then
            recoverBattleSnap()
            if lastBattle then task.spawn(handleBattle,lastBattle) end
        end
    end
end)

task.spawn(function()
    while alive do
        local gate = slotGate()
        if gate and gate.Visible and Library.Flags.party_autoenter==true then
            local slot = math.clamp(tonumber(Library.Flags.party_slot) or 1,1,6)
            pcall(selectCharacterSlot,slot)
            task.wait(1)
        else task.wait(0.3) end
    end
end)

-- pendingSwitch: disabled toggle with Planned badge
local function pendingSwitch(group, name, flag)
    local r = group:AddCheckbox({Name=name, Flag=flag, Default=false, Callback=function(value)
        if value and controls[flag] then
            controls[flag]:Set(false)
            notice("Yenz", name.." needs a verified game event before it can run")
        end
    end})
    -- Wrap with a Planned badge by adding a label after
    group:AddLabel("↑ Planned — not yet connected")
    return r
end

local function configNames()
    local names = {}
    if fileReady() and listfiles then
        local ok, paths = pcall(listfiles, configFolder)
        if ok then
            for _, path in ipairs(paths or {}) do
                local name = tostring(path):match("([^/\\]+)%.json$")
                if name then names[#names+1]=name end
            end
        end
    end
    table.sort(names)
    if #names==0 then names[1]="default" end
    return names
end

local configList
local function refreshConfigNames()
    if configList then configList:Refresh(configNames()) end
end

-- ==============================================================================
--  SECTION 8 — SKILL PRIORITY DRAG-LIST WIDGET
-- ==============================================================================
local function buildSkillPriorityList(parentFrame, listData, listName, saveCallback)
    -- listData is the reference to SkillPriorityState.normal or .boss
    -- It is a live table; we modify it in place and call saveCallback on commit.

    local container = New("Frame", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Parent = parentFrame,
    })

    -- Empty state label
    local emptyLabel = New("TextLabel", {
        Text = "No skills discovered yet\nEnter a battle to populate this list.",
        Font = F.Regular, TextSize = 11, TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,48), Position = UDim2.fromOffset(0,4),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        Visible = #listData == 0,
        Parent = container,
    })

    local rowHolder = New("Frame", {
        Size = UDim2.new(1,0,0,0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = container,
    }, {ListLayout(4)})

    local _rows = {}     -- array of {frame, data_entry}
    local _dragActive = false
    local _dragGhost = nil
    local _dragSrcIdx = nil
    local _dragOrigOrder = nil
    local _dragConn = {}
    local buildRows  -- forward declaration

    local function cancelDrag()
        if not _dragActive then return end
        _dragActive = false
        if _dragGhost then _dragGhost:Destroy(); _dragGhost=nil end
        -- Restore original order
        if _dragOrigOrder then
            table.clear(listData)
            for _, entry in ipairs(_dragOrigOrder) do listData[#listData+1]=entry end
        end
        _dragOrigOrder = nil; _dragSrcIdx = nil
        for _, c in ipairs(_dragConn) do pcall(function() c:Disconnect() end) end
        table.clear(_dragConn)
        -- Refresh row order
        for _, row in ipairs(_rows) do if row.frame and row.frame.Parent then row.frame.LayoutOrder=0 end end
        buildRows()
    end

    buildRows = function()
        -- Clear existing rows
        for _, row in ipairs(_rows) do if row.frame then row.frame:Destroy() end end
        table.clear(_rows)
        emptyLabel.Visible = #listData == 0
        rowHolder.Visible  = #listData > 0

        for i, entry in ipairs(listData) do
            local rowF = New("Frame", {
                Size = UDim2.new(1,0,0,28),
                BackgroundColor3 = T.CardBackground,
                BackgroundTransparency = 1,
                LayoutOrder = i,
                Parent = rowHolder,
            }, {Corner(5)})

            -- Index label
            New("TextLabel", {
                Text = tostring(i),
                Font = F.Medium, TextSize = 11, TextColor3 = T.TextMuted,
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(18,28), Position = UDim2.fromOffset(6,0),
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = rowF,
            })

            -- Drag handle (6 dots pattern via text)
            local handle = New("TextButton", {
                Text = "⠿",
                Font = F.Regular, TextSize = 14, TextColor3 = T.TextMuted,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Size = UDim2.fromOffset(18,28), Position = UDim2.fromOffset(24,0),
                Parent = rowF,
            })

            -- Skill name
            New("TextLabel", {
                Text = entry.name or entry.key or "?",
                Font = F.Regular, TextSize = 12, TextColor3 = T.TextPrimary,
                BackgroundTransparency = 1,
                Size = UDim2.new(1,-72,0,28), Position = UDim2.fromOffset(44,0),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = rowF,
            })

            -- Enabled checkbox
            local enabled = entry.enabled
            local enabledTrack = New("TextButton", {
                Size = UDim2.fromOffset(26,14),
                Position = UDim2.new(1,-32,0.5,-7),
                BackgroundColor3 = enabled and T.Accent or T.ToggleOff,
                AutoButtonColor = false, Text = "",
                Parent = rowF,
            }, {Corner(100)})
            local enabledThumb = New("Frame", {
                Size = UDim2.fromOffset(12,12),
                Position = UDim2.new(0, enabled and 12 or 2, 0.5,-6),
                BackgroundColor3 = T.ToggleThumb,
                BorderSizePixel = 0,
                Parent = enabledTrack,
            }, {Corner(100)})
            enabledTrack.MouseButton1Click:Connect(function()
                entry.enabled = not entry.enabled
                enabled = entry.enabled
                Tween(enabledTrack, 0.1, {BackgroundColor3 = enabled and T.Accent or T.ToggleOff})
                Tween(enabledThumb, 0.1, {Position = UDim2.new(0, enabled and 12 or 2, 0.5,-6)})
                if saveCallback then saveCallback() end
            end)

            -- Drag logic (mouse only, 6px threshold)
            local THRESH = 6
            handle.InputBegan:Connect(function(input)
                if _dragActive then return end
                if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                local startPos2 = input.Position
                local srcIdx = i
                -- Wait for threshold
                local moved = false
                local preConn
                preConn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        preConn:Disconnect()
                    end
                end)
                local checkConn
                checkConn = UserInputService.InputChanged:Connect(function(mv)
                    if mv.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                    if not moved and (mv.Position - startPos2).Magnitude >= THRESH then
                        moved = true; checkConn:Disconnect()
                        -- Begin drag
                        _dragActive = true
                        _dragSrcIdx = srcIdx
                        _dragOrigOrder = {}
                        for _, e in ipairs(listData) do _dragOrigOrder[#_dragOrigOrder+1]=e end
                        -- Ghost
                        local rp = rowHolder.AbsolutePosition
                        _dragGhost = New("Frame", {
                            Size = UDim2.fromOffset(rowF.AbsoluteSize.X, 28),
                            Position = UDim2.fromOffset(input.Position.X - rp.X - 60, input.Position.Y - rp.Y - 14),
                            BackgroundColor3 = T.SelectedSurface,
                            BackgroundTransparency = 0.2,
                            ZIndex = 50, Parent = rowHolder,
                        }, {Corner(5), Stroke(T.Accent, 0, 1)})
                        New("TextLabel", {
                            Text = entry.name or entry.key,
                            Font = F.Regular, TextSize = 12, TextColor3 = T.TextPrimary,
                            BackgroundTransparency = 1,
                            Size = UDim2.fromScale(1,1),
                            TextXAlignment = Enum.TextXAlignment.Center,
                            Parent = _dragGhost,
                        })
                        -- Highlight dragged row
                        rowF.BackgroundTransparency = 0.5

                        -- Move ghost and compute insertion
                        _dragConn[#_dragConn+1] = UserInputService.InputChanged:Connect(function(mv2)
                            if mv2.UserInputType ~= Enum.UserInputType.MouseMovement then return end
                            if not _dragActive or not _dragGhost then return end
                            local rp2 = rowHolder.AbsolutePosition
                            _dragGhost.Position = UDim2.fromOffset(mv2.Position.X-rp2.X-60, mv2.Position.Y-rp2.Y-14)
                            -- Find insertion index
                            local my = mv2.Position.Y
                            local bestIdx = #listData
                            for ri, rowInfo in ipairs(_rows) do
                                if rowInfo.frame and rowInfo.frame.Parent then
                                    local midY = rowInfo.frame.AbsolutePosition.Y + rowInfo.frame.AbsoluteSize.Y/2
                                    if my < midY then bestIdx = ri-1; break end
                                end
                            end
                            bestIdx = math.clamp(bestIdx, 1, #listData)
                            -- Reorder preview
                            local draggedEntry = table.remove(listData, srcIdx)
                            table.insert(listData, bestIdx, draggedEntry)
                            for ri2, re in ipairs(listData) do
                                for _, rowInfo2 in ipairs(_rows) do
                                    if rowInfo2.entry == re then
                                        rowInfo2.frame.LayoutOrder = ri2; break
                                    end
                                end
                            end
                            -- Update srcIdx for next move
                            for ri3, re3 in ipairs(listData) do
                                if re3 == draggedEntry then srcIdx=ri3; break end
                            end
                        end)

                        -- Drop
                        _dragConn[#_dragConn+1] = UserInputService.InputEnded:Connect(function(ev)
                            if ev.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                            if not _dragActive then return end
                            _dragActive = false
                            if _dragGhost then _dragGhost:Destroy(); _dragGhost=nil end
                            _dragOrigOrder = nil; _dragSrcIdx = nil
                            for _, c in ipairs(_dragConn) do pcall(function() c:Disconnect() end) end
                            table.clear(_dragConn)
                            buildRows()
                            if saveCallback then saveCallback() end
                        end)
                    end
                end)
                Track(UserInputService.InputEnded:Connect(function(ev)
                    if ev == input or ev.UserInputType == Enum.UserInputType.MouseButton1 then
                        checkConn:Disconnect()
                    end
                end))
            end)

            -- Move Up / Down fallback buttons
            local upBtn = New("TextButton", {Text="↑", Font=F.Regular, TextSize=11, TextColor3=T.TextMuted,
                BackgroundTransparency=1, AutoButtonColor=false,
                Size=UDim2.fromOffset(14,14), Position=UDim2.new(1,-48,0,2), Parent=rowF})
            local dnBtn = New("TextButton", {Text="↓", Font=F.Regular, TextSize=11, TextColor3=T.TextMuted,
                BackgroundTransparency=1, AutoButtonColor=false,
                Size=UDim2.fromOffset(14,14), Position=UDim2.new(1,-48,0,14), Parent=rowF})
            upBtn.MouseButton1Click:Connect(function()
                if i<=1 then return end
                listData[i], listData[i-1] = listData[i-1], listData[i]
                buildRows(); if saveCallback then saveCallback() end
            end)
            dnBtn.MouseButton1Click:Connect(function()
                if i>=#listData then return end
                listData[i], listData[i+1] = listData[i+1], listData[i]
                buildRows(); if saveCallback then saveCallback() end
            end)

            _rows[#_rows+1] = {frame=rowF, entry=entry}
        end
    end

    -- Initial build
    buildRows()

    -- Register for discovery updates
    _skillListViews[#_skillListViews+1] = {
        onDiscover = function(_names)
            buildRows()
        end
    }

    return {
        cancelDrag = cancelDrag,
        refresh = buildRows,
    }
end

-- ==============================================================================
--  SECTION 9 — WINDOW + PAGE COMPOSITION
-- ==============================================================================
local Window = Library:CreateWindow({
    Title = "Yenz", User = LocalPlayer.Name, Till = "Pixel Lineage", Blur = 0,
    OnSave = function() if saveConfig(Library.Flags.cfg_name or "default", false) then refreshConfigNames() end end,
})

-- ── HOME (overview) ────────────────────────────────────────────────────────
local HomeTab = Window:AddTab("Home", Icons.home)
local HomeGen = HomeTab:AddSubtab("General")
local h1 = HomeGen:AddGroup("Overview", nil, "Left", 200)
h1:AddLabel("Welcome to Yenz for Pixel Lineage.")
h1:AddLabel("Use the sidebar to navigate to Farm, Run, Skills, and more.")
local h2 = HomeGen:AddGroup("Quick Status", nil, "Right", 200)
h2:AddLabel("Auto Farm: check Farm › General")
h2:AddLabel("Auto Skill: check Skills › General")
h2:AddLabel("Config: check Settings")

-- ── MAIN CATEGORY ─────────────────────────────────────────────────────────
Window:AddCategory("MAIN")

-- ── FARM ──────────────────────────────────────────────────────────────────
local FarmTab = Window:AddTab("Farm", Icons.axe_battle)
local FarmGen = FarmTab:AddSubtab("General")
local FarmPath = FarmTab:AddSubtab("Path")

-- Hero banner on Farm/General
local heroCard = FarmGen:AddGroup("Welcome Back", nil, "Left", 80)
heroCard:AddLabel("WELCOME BACK")
heroCard:AddLabel(LocalPlayer.Name)
heroCard:AddLabel("Your next run, your way.")

local f1 = FarmGen:AddGroup("Auto Farm", Icons.hammer, "Left", 200)
addControl(f1, "AddCheckbox", {Name="Auto Farm", Default=false, Flag="farm_autofarm", Callback=function(value)
    if value then runAttempts=0; nextRunAt=0; startRunWorker() end
end})
addControl(f1, "AddCheckbox", {Name="Auto Vote Path", Default=false, Flag="farm_autovotepath"})
f1:AddButton({Name="Path Priority →", Callback=function() FarmPath:Select() end})
pendingSwitch(f1, "Auto Use Dungeon Keys", "farm_autokeys")
pendingSwitch(f1, "Auto Close Popups", "farm_autoclosepopups")

local f2 = FarmGen:AddGroup("In Battle", Icons.crown, "Right", 260)
addControl(f2, "AddCheckbox", {Name="Auto Perfect", Default=false, Flag="battle_autoperfect"})
f2:AddLabel("Dodge + minigames")
addControl(f2, "AddCheckbox", {Name="Auto Potion", Default=false, Flag="battle_autopotion"})
addControl(f2, "AddSlider", {Name="Potion at HP", Min=10, Max=90, Default=60, Suffix="%", Flag="battle_potionhp"})
pendingSwitch(f2, "Auto Guard on Boss Brace", "battle_autoguardbrace")
pendingSwitch(f2, "Use Brews", "battle_usebrews")

-- Path subtab
local pathGroup = FarmPath:AddGroup("Path Preferences", Icons.crosshairs, "Left", 300)
addControl(pathGroup, "AddChips", {
    Name = "Prefer",
    Items = {"First", "Rest", "Shop", "Blood Altar", "Boss"},
    Default = "First",
    Flag = "farm_pathpriority",
    Callback = function(value)
        -- runtime path priority is read live from Library.Flags.farm_pathpriority
    end,
})
pathGroup:AddSeparator()
pathGroup:AddLabel("Picks the first campfire node matching your preference.")
pathGroup:AddLabel("'First' always takes the top-left node (default).")
pathGroup:AddLabel("Campfire live payload needed for Rest / Shop / Blood Altar.")

-- ── RUN ───────────────────────────────────────────────────────────────────
local RunTab = Window:AddTab("Run", Icons.feather)
local RunGen = RunTab:AddSubtab("General")

local r1 = RunGen:AddGroup("Story Run", Icons.crosshairs, "Left", 250)
local difficulties = {}
for _, value in ipairs(RunConfig.Difficulties or {}) do
    local name = tostring(value.name or value.id)
    difficulties[#difficulties+1] = name:sub(1,1):upper()..name:sub(2):lower()
end
addControl(r1, "AddDropdown", {Name="Difficulty", Items=difficulties, Default="Normal", Flag="run_diff"})
local modifierNames = {"None","Random"}
for _, value in ipairs(RunModifiers.List or {}) do
    if tostring(value.id)~="none" then modifierNames[#modifierNames+1]=tostring(value.name or value.id) end
end
addControl(r1, "AddDropdown", {Name="Modifier", Items=modifierNames, Default="None", Flag="run_modifier"})
addControl(r1, "AddSlider", {Name="Start Act", Min=1, Max=math.max(2,#RunConfig.Acts), Default=1, Flag="run_startact"})
r1:AddButton({Name="Start Story Run", Primary=true, Callback=function()
    task.spawn(function() if startRun("Story") and Library.Flags.run_autoreplay then startRunWorker() end end)
end})

local r2 = RunGen:AddGroup("After the Run", nil, "Left", 160)
r2:AddLabel("Replays the last started type (Story / Torment)")
addControl(r2, "AddCheckbox", {Name="Auto Replay", Default=false, Flag="run_autoreplay", Callback=function(value)
    if value then runAttempts=0; nextRunAt=0; startRunWorker() end
end})
pendingSwitch(r2, "Leave After Act Boss", "run_leaveafterboss")

local r3 = RunGen:AddGroup("Torment", Icons.dagger, "Right", 250)
local tormentTiers = {}
for index=1, math.max(1, tonumber(RunConfig.Torment and RunConfig.Torment.OpenTiers) or 99) do
    tormentTiers[#tormentTiers+1]="Torment "..index
end
addControl(r3, "AddDropdown", {Name="Tier", Items=tormentTiers, Default="Torment 1", Flag="run_tormenttier"})
pendingSwitch(r3, "Next Tier After Clear", "run_nexttier")
r3:AddButton({Name="Start Torment", Primary=true, Callback=function()
    task.spawn(function() if startRun("Torment") and Library.Flags.run_autoreplay then startRunWorker() end end)
end})

-- ── PARTY ─────────────────────────────────────────────────────────────────
local PartyTab = Window:AddTab("Party", Icons.user)
local PartyGen = PartyTab:AddSubtab("General")
local p1 = PartyGen:AddGroup("Party", Icons.mouse, "Left", 240)
addControl(p1, "AddDropdown", {Name="Party Role", Items={"Off","Leader","Member"}, Default="Off", Flag="party_role"})
addControl(p1, "AddSlider", {Name="Character Slot", Min=1, Max=6, Default=1, Flag="party_slot"})
addControl(p1, "AddCheckbox", {Name="Auto Enter Slot", Default=false, Flag="party_autoenter"})
addControl(p1, "AddTextbox", {Name="Leader Username", Placeholder="Empty = any", Default="", Flag="party_leadername"})
p1:AddLabel("Character entry uses the game's unlocked slot buttons.")
local p2 = PartyGen:AddGroup("Leader: Members", Icons.code, "Right", 240)
p2:AddLabel("Party invites need a verified in-game command.")
for index=1,4 do
    addControl(p2, "AddTextbox", {Name="Member "..index, Placeholder="member "..index.." username", Default="", Flag="party_m"..index})
end

-- ── ITEMS CATEGORY ─────────────────────────────────────────────────────────
Window:AddCategory("ITEMS")

local TargetTab = Window:AddTab("Target", Icons.crosshairs)
local TargetGen = TargetTab:AddSubtab("General")
local tg1 = TargetGen:AddGroup("Target Item Farm", Icons.save, "Left", 200)
pendingSwitch(tg1, "Target Item Farm", "target_farm_enabled")
tg1:AddButton({Name="Target Items…", Callback=function() notice("Target","Drop locations need a verified game loot table") end})
local tg2 = TargetGen:AddGroup("How it works", nil, "Right", 200)
tg2:AddLabel("Runs the Act for the next target item")
tg2:AddLabel("Loops until it drops, then advances")
tg2:AddLabel("Boss drops may use Boss Rush")
tg2:AddLabel("Target routing is pending live drop data")

local LootTab = Window:AddTab("Loot", Icons.pallet)
local LootGen = LootTab:AddSubtab("General")
local l1 = LootGen:AddGroup("Auto Sell", Icons.code, "Left", 260)
pendingSwitch(l1, "Auto Sell Gear", "loot_autosell")
addControl(l1, "AddDropdown", {Name="Sell: All Types", Items={"Common, Uncommon, Rare, Epic","Rare, Epic","All"}, Default="Common, Uncommon, Rare, Epic", Flag="loot_sellrarity"})
addControl(l1, "AddDropdown", {Name="Sell: Picked Types", Items={"Legendary","Epic, Legendary","All"}, Default="Legendary", Flag="loot_sellpickedrarity"})
addControl(l1, "AddDropdown", {Name="Picked Types", Items={"Helmet, Chest, Legs, Relic","Weapon, Relic","All"}, Default="Helmet, Chest, Legs, Relic", Flag="loot_pickedtypes"})
l1:AddLabel("Sell rules require an account inventory preview.")
local l2 = LootGen:AddGroup("Bag", Icons.save, "Right", 260)
pendingSwitch(l2, "Auto Stash Gear (bag 75%)", "loot_autostash")
pendingSwitch(l2, "Stop When Bag Full", "loot_stopfullbag")

local ForgeTab = Window:AddTab("Forge", Icons.hammer)
local ForgeGen = ForgeTab:AddSubtab("General")
local fg1 = ForgeGen:AddGroup("Auto Hone", Icons.axe_battle, "Left", 260)
pendingSwitch(fg1, "Auto Hone (in castle)", "forge_autohone")
fg1:AddButton({Name="Hone Window (pick pieces)…", Callback=function() notice("Forge","Choose gear after the Hone selection is connected") end})
addControl(fg1, "AddSlider", {Name="Default target", Min=5, Max=10, Default=5, Flag="forge_targetplus"})
fg1:AddLabel("Only selected pieces will be honed")
fg1:AddLabel("From +5, failure can lower the level")

-- ── COMBAT CATEGORY ─────────────────────────────────────────────────────────
Window:AddCategory("COMBAT")

local SkillsTab = Window:AddTab("Skills", Icons.feather)
local SkillsGen = SkillsTab:AddSubtab("General")
local SkillsPriority = SkillsTab:AddSubtab("Priority")

local sk1 = SkillsGen:AddGroup("Skill Use", Icons.code, "Left", 260)
sk1:AddButton({Name="Skill Priority →", Callback=function() SkillsPriority:Select() end})
addControl(sk1, "AddCheckbox", {Name="Auto Skill", Default=false, Flag="skill_auto_enabled"})
addControl(sk1, "AddCheckbox", {Name="Burst Fallback (highest cost)", Default=true, Flag="skill_burst"})
pendingSwitch(sk1, "Smart Finisher", "skill_smartfinisher")
pendingSwitch(sk1, "Use Scrolls", "skill_usescrolls")
local sk2 = SkillsGen:AddGroup("How it works", nil, "Right", 260)
sk2:AddLabel("Priority: top ready skill each turn")
sk2:AddLabel("Separate Normal and Boss lists")
sk2:AddLabel("No ready skill: basic attack")
sk2:AddLabel("Skills appear after your first battle")
sk2:AddLabel("Burst fallback uses highest-cost available skill (not guaranteed highest damage)")

-- Priority subtab — two drag-list cards
local spSaveCallback = function()
    if Library.Flags.cfg_autosave then task.spawn(function() saveConfig(Library.Flags.cfg_name or "default", true) end) end
end

local normalCard = SkillsPriority:AddGroup("Enemy Skills", Icons.feather, "Left", 300)
normalCard:AddLabel("Drag to reorder · Toggle to enable/disable")
-- Build drag list inside normalCard's bodyList frame
if normalCard._bodyList then
    buildSkillPriorityList(normalCard._bodyList, SkillPriorityState.normal, "Normal", spSaveCallback)
end

local bossCard = SkillsPriority:AddGroup("Boss Skills", Icons.crown, "Right", 300)
bossCard:AddLabel("Drag to reorder · Toggle to enable/disable")
if bossCard._bodyList then
    buildSkillPriorityList(bossCard._bodyList, SkillPriorityState.boss, "Boss", spSaveCallback)
end

-- Also keep the top-strip Auto Skill / Burst toggles on Priority page
-- (these mirror SkillsGen controls via shared flags)

-- ── SETTINGS CATEGORY ───────────────────────────────────────────────────────
Window:AddCategory("SETTINGS")

local SettingsTab = Window:AddTab("Settings", Icons.save)
local SettingsGen = SettingsTab:AddSubtab("General")
local st1 = SettingsGen:AddGroup("Profile & Configuration", Icons.save, "Left", 320)
local configName = addControl(st1, "AddTextbox", {Name="Config Name", Default="default", Flag="cfg_name"})
configList = addControl(st1, "AddDropdown", {Name="Saved Configs", Items=configNames(), Default="default", Flag="cfg_selected", Callback=function(value)
    if configName then configName:Set(value) end
end})
st1:AddButton({Name="Save Config", Callback=function()
    if saveConfig(Library.Flags.cfg_name, false) then refreshConfigNames(); configList:Set(Library.Flags.cfg_name) end
end})
st1:AddButton({Name="Load Config", Callback=function() loadConfig(Library.Flags.cfg_selected, false) end})
st1:AddButton({Name="Delete Config", Callback=function()
    local name = safeName(Library.Flags.cfg_selected)
    local path = configPath(name)
    if not (path and isfile and delfile and isfile(path)) then notice("Config","Config not found"); return end
    local ok = pcall(delfile, path)
    if ok then refreshConfigNames(); configList:Set(configNames()[1]); notice("Config","Deleted "..name) end
end})
st1:AddButton({Name="Reset to Default", Callback=function()
    for flag, value in pairs(defaults) do
        if controls[flag] and value~=nil then controls[flag]:Set(value) end
    end
    notice("Config","Defaults restored")
end})
addControl(st1, "AddCheckbox", {Name="Auto Save on Changes", Default=false, Flag="cfg_autosave"})
addControl(st1, "AddCheckbox", {Name="Auto Load for This Account", Default=false, Flag="cfg_autoload", Callback=function(value)
    if not fileReady() then return end
    if value then
        pcall(writefile, autoloadPath, safeName(Library.Flags.cfg_name))
    elseif delfile and isfile(autoloadPath) then
        pcall(delfile, autoloadPath)
    end
end})

local st2 = SettingsGen:AddGroup("Interface Settings", Icons.mouse, "Right", 240)
st2:AddKeybind({Name="Menu Toggle Key", Default=Enum.KeyCode.Insert, Callback=function(key)
    Library.ToggleKey = key
end})
st2:AddColorPicker({Name="Accent Color", Default=T.Accent, Callback=function(color)
    T.Accent = color
end})
st2:AddLabel("Press Insert to show or hide Yenz")

-- ── STARTUP ──────────────────────────────────────────────────────────────────
-- Select Farm tab as the default page
task.defer(function()
    FarmTab:Select()
    FarmGen:Select()
end)

if fileReady() and isfile(autoloadPath) then
    local ok, name = pcall(readfile, autoloadPath)
    if ok then loadConfig(name, true); controls.cfg_autoload:Set(true) end
end
if Library.Flags.farm_autofarm or Library.Flags.run_autoreplay then startRunWorker() end

-- Auto-save worker
task.spawn(function()
    local lastPayload = nil
    while alive do
        if Library.Flags.cfg_autosave==true and fileReady() then
            local payload = HttpService:JSONEncode(serializableFlags())
            if payload~=lastPayload then
                if saveConfig(Library.Flags.cfg_name, true) then lastPayload=payload; refreshConfigNames() end
            end
        end
        task.wait(2)
    end
end)

-- Close button → confirm dialog
-- Removed invalid colon member access; the descendant scan below handles the close button.
-- Use the closeBtn reference from window construction (captured via runtime.Yenz.Unload path)
-- The close/unload is wired via runtime.Yenz.Unload below
-- We'll connect the close button in the window reference
do
    -- Walk to find the close TextButton by text "×" in the topbar
    local topbarFrame = Window.Root:FindFirstChild("MainArea") and Window.Root.MainArea:FindFirstChild("Topbar")
    if topbarFrame then
        for _, child in ipairs(topbarFrame:GetDescendants()) do
            if child:IsA("TextButton") and child.Text=="×" then
                child.MouseButton1Click:Connect(function()
                    Window:ShowCloseConfirm(function()
                        if runtime.Yenz and runtime.Yenz.Unload then runtime.Yenz.Unload() end
                    end)
                end)
                break
            end
        end
    end
end

-- ==============================================================================
--  SECTION 10 — RUNTIME EXPORT
-- ==============================================================================
runtime.Yenz = {
    Library = Library,
    Window = Window,
    Controls = controls,
    Unload = function()
        alive = false
        if pixelQTE.Handle == hookedHandle then pixelQTE.Handle = originalHandle end
        if RunMapView.Update == hookedRunMapUpdate then RunMapView.Update = originalRunMapUpdate end
        for _, connection in ipairs(connections) do pcall(function() connection:Disconnect() end) end
        DisconnectAll()
        Window:Destroy()
        runtime.Yenz = nil
    end,
}
return runtime.Yenz
