-- YenzUI.lua — Spotify-Inspired UI Library for Pixel Lineage
-- Load with: local Library = loadstring(game:HttpGet(RAW_URL))()
-- Contains only UI framework (Sections 1-6). No gameplay logic.

-- ==============================================================================
--  SECTION 1 — DESIGN TOKENS
-- ==============================================================================
local function hex(h)
    h = h:gsub("^#","")
    return Color3.fromRGB(tonumber(h:sub(1,2),16), tonumber(h:sub(3,4),16), tonumber(h:sub(5,6),16))
end

local T = {
    -- Surfaces
    WindowBackground    = hex("0B0D0E"),
    SidebarBackground   = hex("101315"),
    ContentBackground   = hex("121617"),
    CardBackground      = hex("1A2022"),
    CardHeader          = hex("20272A"),
    InputBackground     = hex("151A1C"),
    HoverSurface        = hex("252D30"),
    SelectedSurface     = hex("26302B"),
    -- Accent
    Accent              = hex("1DB954"),
    AccentBright        = hex("1ED760"),
    AccentDark          = hex("123E26"),
    -- Text
    TextPrimary         = hex("F4F6F5"),
    TextSecondary       = hex("A8B0B3"),
    TextMuted           = hex("778187"),
    TextDisabled        = hex("667075"),
    -- Structure
    Divider             = hex("2A3236"),
    ToggleOff           = hex("424A50"),
    ToggleThumb         = hex("F2F4F3"),
    -- Status
    Danger              = hex("E66B73"),
    Warning             = hex("E1B467"),
}

-- Gotham weight keeps compact labels close to the profile name while improving legibility.
local F = {
    Regular  = Enum.Font.GothamBold,
    Medium   = Enum.Font.GothamBold,
    SemiBold = Enum.Font.GothamBold,
    Bold     = Enum.Font.GothamBold,
}

-- ==============================================================================
--  SECTION 2 — ICON REGISTRY
-- ==============================================================================
local Icons = {
    crosshairs = "rbxassetid://96677288280405",
    ghost      = "rbxassetid://95400397758754",
    mouse      = "rbxassetid://74350468513068",
    user       = "rbxassetid://97066657594742",
    pallet     = "rbxassetid://83365140694071",
    hammer     = "rbxassetid://118512898552101",
    code       = "rbxassetid://100793810819046",
    save       = "rbxassetid://136566823798983",
    feather    = "rbxassetid://130188814728078",
    crown      = "rbxassetid://73317911385704",
    dagger     = "rbxassetid://133081986539088",
    baby       = "rbxassetid://127135446273067",
    ad         = "rbxassetid://134916447199398",
    axe_battle = "rbxassetid://91285868461583",
    avatar     = "rbxassetid://0",
    home       = "rbxassetid://97066657594742",
}
-- Legacy alias for runtime code that references lowercase icons.save
local icons = { save = Icons.save }

-- ==============================================================================
--  SECTION 3 — SERVICE REFS + UTILITIES
-- ==============================================================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")
local StarterGui       = game:GetService("StarterGui")
local LocalPlayer      = Players.LocalPlayer

local function New(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            if k == "Font" and typeof(v) == "EnumItem" then o.Font = v
            elseif k == "Font" and typeof(v) == "Font" then o.FontFace = v
            else o[k] = v end
        end
    end
    for _, c in ipairs(children or {}) do c.Parent = o end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end

local function Corner(r) return New("UICorner", {CornerRadius = UDim.new(0, r)}) end
local function Padding(t,r,b,l) return New("UIPadding", {PaddingTop=UDim.new(0,t or 0),PaddingRight=UDim.new(0,r or 0),PaddingBottom=UDim.new(0,b or 0),PaddingLeft=UDim.new(0,l or 0)}) end
local function Stroke(color, trans, thick)
    return New("UIStroke", {Color=color or T.Divider, Transparency=trans or 0, ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Thickness=thick or 1})
end
local function ListLayout(gap, dir, align)
    return New("UIListLayout", {Padding=UDim.new(0,gap or 0), SortOrder=Enum.SortOrder.LayoutOrder, FillDirection=dir or Enum.FillDirection.Vertical, HorizontalAlignment=align or Enum.HorizontalAlignment.Left})
end
local function Tween(obj, t, props, style)
    if not obj or not obj.Parent then return end
    local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play(); return tw
end

local function GetParentGui()
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then return hui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then
        local test = pcall(function() local f = Instance.new("Folder"); f.Parent = core; f:Destroy() end)
        if test then return core end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Connection manager for clean unload
local _allConnections = {}
local function Track(conn)
    _allConnections[#_allConnections+1] = conn
    return conn
end
local function Untrack(conn)
    if not conn then return end
    pcall(function() conn:Disconnect() end)
    for index=#_allConnections,1,-1 do
        if _allConnections[index]==conn then table.remove(_allConnections,index);break end
    end
end
local function DisconnectAll()
    for _, c in ipairs(_allConnections) do pcall(function() c:Disconnect() end) end
    table.clear(_allConnections)
end

-- ==============================================================================
--  SECTION 4 — LIBRARY TABLE
-- ==============================================================================
local Library = { Theme = T, Flags = {}, Icons = Icons, ToggleKey = Enum.KeyCode.RightControl }
Library.__index = Library

-- ==============================================================================
--  SECTION 5 — NEW LIBRARY:CREATEWINDOW  (Spotify-Inspired Shell)
-- ==============================================================================
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local localName = LocalPlayer and LocalPlayer.Name or "Player"
    local localDisplayName = LocalPlayer and LocalPlayer.DisplayName or localName
    local initialUser = {
        UserId = LocalPlayer and LocalPlayer.UserId or 0,
        Name = localName,
        DisplayName = localDisplayName,
        Image = cfg.Avatar,
    }
    if type(cfg.User) == "table" then
        initialUser.UserId = tonumber(cfg.User.UserId) or initialUser.UserId
        initialUser.Name = tostring(cfg.User.Name or initialUser.Name)
        initialUser.DisplayName = tostring(cfg.User.DisplayName or initialUser.DisplayName)
        initialUser.Image = cfg.User.Image or initialUser.Image
    elseif cfg.User ~= nil then
        initialUser.DisplayName = tostring(cfg.User)
    end

    -- ── ScreenGui ────────────────────────────────────────────────────────────
    local parentGui = GetParentGui()
    local previousGui = parentGui:FindFirstChild("YenzUI")
    local gui = New("ScreenGui", {
        Name = "YenzUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
        Parent = parentGui,
    })
    local blurEffect
    if cfg.Blur then
        local amount=type(cfg.Blur)=="number" and cfg.Blur or 12
        blurEffect=New("BlurEffect", {
            Name="YenzUIBlur",Size=math.clamp(amount,0,24),Enabled=true,Parent=Lighting,
        })
    end

    -- ── Root window (760×540 centered) ───────────────────────────────────────
    local WindowRoot = New("Frame", {
        Name = "WindowRoot",
        Size = UDim2.fromOffset(760, 540),
        Position = UDim2.new(0.5, -380, 0.5, -270),
        BackgroundColor3 = T.WindowBackground,
        BorderSizePixel = 0,
        Parent = gui,
    }, {Corner(10), Stroke(T.Divider, 0, 1)})

    -- ── Overlay layer (popups, tooltips, drag ghost) ──────────────────────────
    local OverlayLayer = New("Frame", {
        Name = "OverlayLayer",
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        ZIndex = 100,
        Parent = WindowRoot,
    })
    local PopupHost = New("Frame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=110, Parent=OverlayLayer})
    local TooltipHost = New("Frame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=120, Parent=OverlayLayer})
    local ToastHost = New("Frame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=115, Parent=OverlayLayer})
    local DragOverlay = New("Frame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=130, Parent=OverlayLayer})
    local ModalHost = New("Frame", {BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ZIndex=125, Parent=OverlayLayer})

    -- ── Sidebar (182px) ───────────────────────────────────────────────────────
    local Sidebar = New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 182, 1, 0),
        BackgroundColor3 = T.SidebarBackground,
        BorderSizePixel = 0,
        Parent = WindowRoot,
    }, {Corner(10)})
    -- Clip right corners of sidebar
    New("Frame", {Size=UDim2.fromOffset(10,540), Position=UDim2.fromOffset(172,0), BackgroundColor3=T.SidebarBackground, BorderSizePixel=0, Parent=Sidebar})

    -- Brand header
    local BrandHeader = New("Frame", {
        Name = "BrandHeader",
        Size = UDim2.new(1,0,0,50),
        BackgroundTransparency = 1,
        Parent = Sidebar,
    })
    local brandMark = New("Frame", {
        Name="BrandMark",
        Size=UDim2.fromOffset(24,24),
        Position=UDim2.fromOffset(14,13),
        BackgroundColor3=T.Accent,
        BorderSizePixel=0,
        Parent=BrandHeader,
    }, {Corner(100)})
    for index, width in ipairs({14,12,10}) do
        New("Frame", {
            Name="LogoWave"..index,
            Size=UDim2.fromOffset(width,2),
            Position=UDim2.fromOffset(5+(index-1),6+(index-1)*4),
            Rotation=5,
            BackgroundColor3=Color3.new(0,0,0),
            BorderSizePixel=0,
            Parent=brandMark,
        }, {Corner(2)})
    end
    local brandWordmark = New("TextLabel", {
        Text = "Yenz",
        Font = F.Bold,
        TextSize = 13,
        TextColor3 = T.TextPrimary,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(58,24),
        Position = UDim2.fromOffset(46, 13),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = BrandHeader,
    })
    New("TextLabel", {
        Text = "v2.0",
        Font = F.Regular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundColor3=T.InputBackground,
        Size = UDim2.fromOffset(34,18),
        Position = UDim2.new(1,-48,0,16),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment=Enum.TextYAlignment.Center,
        Parent = BrandHeader,
    }, {Corner(4),Stroke(T.Divider,0,1)})

    -- Divider under brand
    New("Frame", {Size=UDim2.new(1,-24,0,1), Position=UDim2.fromOffset(12,50), BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=Sidebar})

    -- Navigation scroll area
    local NavScroll = New("ScrollingFrame", {
        Name = "NavigationScroll",
        Size = UDim2.new(1,0,1,-106),
        Position = UDim2.fromOffset(0,52),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.Accent,
        ScrollBarImageTransparency = 0.6,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = Sidebar,
    }, {New("UIPadding",{PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)}),
        ListLayout(2)})

    -- Sidebar profile card; avatar image is filled asynchronously after the window is built.
    local AvatarViews = {}
    local alive = true
    local avatarVersion = 0
    local function InvokeCallback(label, callback, ...)
        if type(callback)~="function" then return end
        local args=table.pack(...)
        task.spawn(function()
            if not alive then return end
            local ok,err=pcall(callback,table.unpack(args,1,args.n))
            if not ok then warn("[YenzUI] "..tostring(label).." callback failed: "..tostring(err)) end
        end)
    end
    local ProfileFooter = New("Frame", {
        Name = "UserProfileCard",
        Size = UDim2.new(1,-16,0,48),
        Position = UDim2.new(0,8,1,-56),
        BackgroundColor3 = T.InputBackground,
        BorderSizePixel = 0,
        Parent = Sidebar,
    }, {Corner(8),Stroke(T.Divider,0,1)})
    local profileAvatar = New("Frame", {
        Name="AvatarRing",
        Size=UDim2.fromOffset(36,36),
        Position=UDim2.fromOffset(7,6),
        BackgroundColor3=T.Accent,
        BorderSizePixel=0,
        Parent=ProfileFooter,
    }, {Corner(100),Stroke(T.Accent,0,1.5)})
    local profileClip = New("Frame", {
        Size=UDim2.fromOffset(32,32),
        Position=UDim2.fromOffset(2,2),
        BackgroundColor3=T.SelectedSurface,
        BorderSizePixel=0,
        ClipsDescendants=true,
        Parent=profileAvatar,
    }, {Corner(100)})
    local profileFallback = New("TextLabel", {
        Text=string.sub(initialUser.DisplayName or initialUser.Name or "P",1,1):upper(),
        Font=F.Bold,TextSize=14,TextColor3=T.TextPrimary,
        BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
        Parent=profileClip,
    })
    local profileImage = New("ImageLabel", {
        Name="ProfileImage",Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,ImageTransparency=1,
        Image=initialUser.Image or "rbxthumb://type=AvatarBust&id="..tostring(initialUser.UserId).."&w=150&h=150",
        ScaleType=Enum.ScaleType.Crop,Parent=profileClip,
    }, {Corner(100)})
    AvatarViews[#AvatarViews+1]={Image=profileImage,Fallback=profileFallback}
    initialUser.AvatarFallbacks={profileFallback}
    New("Frame", {
        Name="OnlineDot",Size=UDim2.fromOffset(8,8),
        Position=UDim2.new(1,-9,1,-9),BackgroundColor3=T.AccentBright,
        BorderSizePixel=0,ZIndex=3,Parent=profileAvatar,
    }, {Corner(100),Stroke(T.InputBackground,0,1)})
    local profileDisplayName = New("TextLabel", {
        Name="DisplayName",Text=initialUser.DisplayName,
        Font=F.SemiBold,TextSize=11,TextColor3=T.TextPrimary,
        BackgroundTransparency=1,Size=UDim2.new(1,-60,0,16),
        Position=UDim2.fromOffset(50,6),TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,Parent=ProfileFooter,
    })
    local profileName = New("TextLabel", {
        Name="Username",Text="@"..initialUser.Name,
        Font=F.Regular,TextSize=10,TextColor3=T.TextMuted,
        BackgroundTransparency=1,Size=UDim2.new(1,-60,0,14),
        Position=UDim2.fromOffset(50,25),TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,Parent=ProfileFooter,
    })
    -- ── Main content area (578px) ─────────────────────────────────────────────
    local MainArea = New("Frame", {
        Name = "MainArea",
        Size = UDim2.new(1,-182,1,0),
        Position = UDim2.fromOffset(182,0),
        BackgroundColor3 = T.ContentBackground,
        BorderSizePixel = 0,
        Parent = WindowRoot,
    }, {Corner(10)})
    -- Left clip (square left edge)
    New("Frame", {Size=UDim2.fromOffset(10,540), Position=UDim2.fromOffset(0,0), BackgroundColor3=T.ContentBackground, BorderSizePixel=0, Parent=MainArea})

    -- Topbar (44px)
    local Topbar = New("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1,0,0,44),
        BackgroundColor3 = T.ContentBackground,
        BorderSizePixel = 0,
        Parent = MainArea,
    })
    New("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.fromOffset(0,44), BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=MainArea})

    local topbarPageLabel = New("TextLabel", {
        Text = cfg.Title or "Home",
        Font = F.SemiBold,
        TextSize = 13,
        TextColor3 = T.TextPrimary,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(112,44),
        Position = UDim2.fromOffset(16,0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Topbar,
    })
    local topbarSubtitleLabel = New("TextLabel", {
        Text = tostring(cfg.Till or "Pixel Lineage"),
        Font = F.Regular,
        TextSize = 11,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(130,44),
        Position = UDim2.fromOffset(128,0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = Topbar,
    })
    local statusPill = New("Frame", {Name="StatusPill",Size=UDim2.fromOffset(78,24),
        Position=UDim2.new(1,-146,0.5,-12),BackgroundColor3=T.InputBackground,BorderSizePixel=0,Parent=Topbar},
        {Corner(20),Stroke(T.Divider,0,1)})
    local statusDot = New("Frame", {Size=UDim2.fromOffset(6,6),Position=UDim2.fromOffset(9,9),
        BackgroundColor3=T.TextMuted,BorderSizePixel=0,Parent=statusPill}, {Corner(10)})
    local statusLabel = New("TextLabel", {Name="StatusText",Text="Idle",Font=F.Medium,TextSize=11,
        TextColor3=T.TextSecondary,BackgroundTransparency=1,Size=UDim2.new(1,-25,1,0),
        Position=UDim2.fromOffset(21,0),TextXAlignment=Enum.TextXAlignment.Left,Parent=statusPill})

    local minimizeBtn = New("TextButton", {
        Text = "−",
        Font = F.Bold,
        TextSize = 16,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28,42),
        Position = UDim2.new(1,-56,0,1),
        AutoButtonColor = false,
        Parent = Topbar,
    })
    local closeBtn = New("TextButton", {
        Text = "×",
        Font = F.Bold,
        TextSize = 18,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28,42),
        Position = UDim2.new(1,-28,0,1),
        AutoButtonColor = false,
        Parent = Topbar,
    })
    minimizeBtn.MouseEnter:Connect(function() minimizeBtn.TextColor3 = T.TextPrimary end)
    minimizeBtn.MouseLeave:Connect(function() minimizeBtn.TextColor3 = T.TextMuted end)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = T.Danger end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = T.TextMuted end)

    -- Page viewport (below the topbar)
    local PageViewport = New("Frame", {
        Name = "PageViewport",
        Size = UDim2.new(1,0,1,-44),
        Position = UDim2.fromOffset(0,44),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = MainArea,
    })
    local PageCanvas = New("CanvasGroup", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Parent = PageViewport,
    })

    -- Subtab bar (34px)
    local SubtabBar = New("Frame", {
        Name = "SubtabBar",
        Size = UDim2.new(1,0,0,34),
        BackgroundColor3 = T.CardHeader,
        BorderSizePixel = 0,
        Parent = PageCanvas,
        ZIndex = 10,
    })
    New("Frame", {Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),
        BackgroundColor3=T.Divider,BorderSizePixel=0,Parent=SubtabBar})
    local subBarList = New("Frame", {
        Size = UDim2.new(1,-24,1,0),
        Position = UDim2.fromOffset(12,0),
        BackgroundTransparency = 1,
        Parent = SubtabBar,
    }, {ListLayout(2, Enum.FillDirection.Horizontal)})

    -- Page body (scrollable two-column content below subtabs)
    local PageBody = New("Frame", {
        Name = "PageBody",
        Size = UDim2.new(1,0,1,-34),
        Position = UDim2.fromOffset(0,34),
        BackgroundTransparency = 1,
        Parent = PageCanvas,
    })

    -- ── Window state & helpers ────────────────────────────────────────────────
    local Window = {
        Gui = gui,
        Root = WindowRoot,
        Tabs = {},
        CurrentTab = nil,
        _pageHistory = {},
        _uiVisible = true,
        _minimized = false,
        _overlay = { PopupHost=PopupHost, TooltipHost=TooltipHost, ToastHost=ToastHost,
                     DragOverlay=DragOverlay, ModalHost=ModalHost },
    }

    function Window:SetSubtitle(text)
        topbarSubtitleLabel.Text = tostring(text or "")
    end

    function Window:SetStatus(status)
        local running = status == true or tostring(status):lower() == "running"
        statusLabel.Text = running and "Running" or "Idle"
        statusDot.BackgroundColor3 = running and T.Accent or T.TextMuted
    end

    local function showAvatar(view, version)
        local image=view.Image
        if not image or not image.Parent or not alive or version~=avatarVersion then return end
        Tween(image,0.18,{ImageTransparency=0})
        if view.LoadedConnection then
            Untrack(view.LoadedConnection)
            view.LoadedConnection=nil
        end
    end

    local function setAvatarImage(view, imageUrl, version)
        local image=view.Image
        if not image or not image.Parent then return end
        if view.LoadedConnection then Untrack(view.LoadedConnection);view.LoadedConnection=nil end
        image.ImageTransparency=1
        image.Image=imageUrl
        if image.IsLoaded then
            showAvatar(view,version)
        else
            local connection
            connection=image.Loaded:Connect(function()
                showAvatar(view,version)
            end)
            view.LoadedConnection=Track(connection)
        end
    end

    local function updateAvatarViews()
        avatarVersion+=1
        local version=avatarVersion
        local displayName=tostring(initialUser.DisplayName or initialUser.Name or "Player")
        local imageUrl=initialUser.Image
        local userId=tonumber(initialUser.UserId)
        local thumbnail="rbxthumb://type=AvatarBust&id="..tostring(userId or 0).."&w=150&h=150"
        for _,view in ipairs(AvatarViews) do
            view.Fallback.Text=string.sub(displayName,1,1):upper()
            if imageUrl and tostring(imageUrl)~="" and tostring(imageUrl)~="rbxassetid://0" then
                setAvatarImage(view,tostring(imageUrl),version)
            elseif userId and userId>0 then
                setAvatarImage(view,thumbnail,version)
            else
                view.Image.ImageTransparency=1
                if view.LoadedConnection then Untrack(view.LoadedConnection);view.LoadedConnection=nil end
            end
        end
        if imageUrl and tostring(imageUrl)~="" and tostring(imageUrl)~="rbxassetid://0" then return end
        if not userId or userId<=0 then return end
        -- This owned background task stops after five attempts or when the window/user changes.
        task.defer(function()
            for attempt=1,5 do
                if not alive or version~=avatarVersion then return end
                local ok,url,isReady=pcall(function()
                    return Players:GetUserThumbnailAsync(userId,Enum.ThumbnailType.AvatarBust,Enum.ThumbnailSize.Size150x150)
                end)
                if ok and isReady and type(url)=="string" and url~="" then
                    if not alive or version~=avatarVersion then return end
                    for _,view in ipairs(AvatarViews) do setAvatarImage(view,url,version) end
                    return
                end
                if attempt<5 then task.wait(0.5) end
            end
        end)
    end

    function Window:SetUser(user)
        if type(user)~="table" then return end
        initialUser.UserId=tonumber(user.UserId) or initialUser.UserId
        initialUser.Name=tostring(user.Name or initialUser.Name or "Player")
        initialUser.DisplayName=tostring(user.DisplayName or initialUser.DisplayName or initialUser.Name)
        initialUser.Image=user.Image or initialUser.Image
        profileDisplayName.Text=initialUser.DisplayName
        profileName.Text="@"..initialUser.Name
        for _,nameLabel in ipairs(initialUser.NameLabels or {}) do nameLabel.Text=initialUser.DisplayName end
        for _,fallback in ipairs(initialUser.AvatarFallbacks or {}) do
            fallback.Text=string.sub(initialUser.DisplayName,1,1):upper()
        end
        updateAvatarViews()
    end

    function Window:GetUser()
        return {UserId=initialUser.UserId,Name=initialUser.Name,DisplayName=initialUser.DisplayName}
    end

    updateAvatarViews()

    local function animatePage()
        PageCanvas.GroupTransparency = 1
        Tween(PageCanvas, 0.12, {GroupTransparency = 0})
    end
    Window.Animate = animatePage

    -- ── Toast notification ────────────────────────────────────────────────────
    function Window:Toast(text, duration)
        duration = duration or 2.5
        Window._toastItems = Window._toastItems or {}
        local t = New("Frame", {
            Size = UDim2.fromOffset(220,32),
            Position = UDim2.new(1,-236,1,-48),
            BackgroundColor3 = T.CardHeader,
            BorderSizePixel = 0,
            BackgroundTransparency = 0,
            Parent = ToastHost,
        }, {Corner(6), Stroke(T.Divider,0,1)})
        local item={Frame=t}
        table.insert(Window._toastItems,item)
        local function layoutToasts()
            for index,toast in ipairs(Window._toastItems) do
                if toast.Frame and toast.Frame.Parent then
                    Tween(toast.Frame,0.12,{Position=UDim2.new(1,-236,1,-48-((index-1)*38))})
                end
            end
        end
        layoutToasts()
        New("TextLabel", {Text=text, Font=F.Regular, TextSize=11, TextColor3=T.TextPrimary,
            BackgroundTransparency=1, Size=UDim2.fromScale(1,1), TextXAlignment=Enum.TextXAlignment.Center, Parent=t})
        Tween(t, 0.15, {BackgroundTransparency=0})
        task.delay(duration, function()
            if not alive or not t.Parent then return end
            Tween(t, 0.25, {BackgroundTransparency=1})
            task.delay(0.3, function()
                if t and t.Parent then t:Destroy() end
                for index,toast in ipairs(Window._toastItems) do
                    if toast==item then table.remove(Window._toastItems,index);break end
                end
                if alive then layoutToasts() end
            end)
        end)
    end

    -- ── Close confirmation modal ──────────────────────────────────────────────
    function Window:ShowCloseConfirm(onConfirm)
        if Window._closeConfirmOpen then return end
        Window._closeConfirmOpen=true
        local bg = New("Frame", {
            Size = UDim2.fromScale(1,1), BackgroundColor3 = Color3.new(0,0,0),
            BackgroundTransparency = 0.5, Parent = ModalHost,
        })
        local box = New("Frame", {
            Size = UDim2.fromOffset(280,120),
            Position = UDim2.new(0.5,-140,0.5,-60),
            BackgroundColor3 = T.CardHeader,
            Parent = ModalHost,
        }, {Corner(10), Stroke(T.Divider,0,1)})
        New("TextLabel", {Text="Close Yenz?", Font=F.SemiBold, TextSize=14, TextColor3=T.TextPrimary,
            BackgroundTransparency=1, Size=UDim2.fromOffset(248,20), Position=UDim2.fromOffset(16,16),
            TextXAlignment=Enum.TextXAlignment.Left, Parent=box})
        New("TextLabel", {Text="Close this window and return to the game.", Font=F.Regular, TextSize=11, TextColor3=T.TextSecondary,
            BackgroundTransparency=1, Size=UDim2.fromOffset(248,32), Position=UDim2.fromOffset(16,38),
            TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=box})
        local cancelBtn = New("TextButton", {
            Text="Cancel", Font=F.Medium, TextSize=12, TextColor3=T.TextSecondary,
            BackgroundColor3=T.InputBackground, AutoButtonColor=false,
            Size=UDim2.fromOffset(110,28), Position=UDim2.fromOffset(16,82), Parent=box,
        }, {Corner(5)})
        local confirmBtn = New("TextButton", {
            Text="Close", Font=F.SemiBold, TextSize=12, TextColor3=Color3.new(0.1,0.1,0.1),
            BackgroundColor3=T.Danger, AutoButtonColor=false,
            Size=UDim2.fromOffset(110,28), Position=UDim2.fromOffset(154,82), Parent=box,
        }, {Corner(5)})
        local function dismiss()
            Window._closeConfirmOpen=false
            bg:Destroy()
            box:Destroy()
        end
        cancelBtn.MouseButton1Click:Connect(dismiss)
        confirmBtn.MouseButton1Click:Connect(function()
            dismiss()
            if onConfirm then
                task.spawn(function()
                    local ok, err = pcall(onConfirm)
                    if not ok then warn("[YenzUI] Close confirmation callback failed: " .. tostring(err)) end
                end)
            end
        end)
    end
    closeBtn.MouseButton1Click:Connect(function()
        Window:ShowCloseConfirm(function()
            if type(cfg.OnSave)=="function" then
                local ok, err = pcall(cfg.OnSave)
                if not ok then warn("[YenzUI] OnSave callback failed: " .. tostring(err)) end
            end
            Window:Destroy()
        end)
    end)

    -- ── Tooltip ───────────────────────────────────────────────────────────────
    local _activeTooltip = nil
    function Window:ShowTooltip(text, anchorInstance)
        if _activeTooltip then _activeTooltip:Destroy(); _activeTooltip = nil end
        if not text or text == "" then return end
        local tip = New("Frame", {
            BackgroundColor3 = T.CardHeader, BorderSizePixel=0,
            AutomaticSize = Enum.AutomaticSize.XY, Parent = TooltipHost,
        }, {Corner(5), Stroke(T.Divider,0,1), Padding(4,8,4,8)})
        New("TextLabel", {Text=text, Font=F.Regular, TextSize=11, TextColor3=T.TextSecondary,
            BackgroundTransparency=1, AutomaticSize=Enum.AutomaticSize.XY, Parent=tip})
        _activeTooltip = tip
        if anchorInstance then
            local ap = anchorInstance.AbsolutePosition
            local as = anchorInstance.AbsoluteSize
            local rp = WindowRoot.AbsolutePosition
            tip.Position = UDim2.fromOffset(ap.X - rp.X, ap.Y - rp.Y + as.Y + 4)
        end
    end
    function Window:HideTooltip()
        if _activeTooltip then _activeTooltip:Destroy(); _activeTooltip = nil end
    end

    -- ── Dragging (topbar only) ────────────────────────────────────────────────
    do
        local dragging, dragStart, startPos
        local dragTarget = Topbar
        dragTarget.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = WindowRoot.Position
                input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
            end
        end)
        Track(UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                local vp = workspace.CurrentCamera.ViewportSize
                local xScale, yScale = startPos.X.Scale, startPos.Y.Scale
                local nx = math.clamp(xScale * vp.X + startPos.X.Offset + d.X,
                    -WindowRoot.AbsoluteSize.X + 60, vp.X - 60)
                local ny = math.clamp(yScale * vp.Y + startPos.Y.Offset + d.Y, 0, vp.Y - 40)
                WindowRoot.Position = UDim2.new(xScale, nx - xScale * vp.X, yScale, ny - yScale * vp.Y)
            end
        end))
        local cursorOverWindow, cursorEnabledBefore = false, nil
        local function restoreCursor()
            if cursorOverWindow then
                cursorOverWindow = false
                UserInputService.MouseIconEnabled = cursorEnabledBefore
                cursorEnabledBefore = nil
            end
        end
        local cursorBindingName = "YenzCursor_" .. HttpService:GenerateGUID(false)
        RunService:BindToRenderStep(cursorBindingName, Enum.RenderPriority.Last.Value + 1, function()
            if not alive or not gui.Enabled or not WindowRoot.Visible then restoreCursor(); return end
            local point = UserInputService:GetMouseLocation()
            local position, size = WindowRoot.AbsolutePosition, WindowRoot.AbsoluteSize
            local inside = point.X >= position.X and point.X <= position.X + size.X
                and point.Y >= position.Y and point.Y <= position.Y + size.Y
            if inside then
                if not cursorOverWindow then
                    cursorEnabledBefore = UserInputService.MouseIconEnabled
                    cursorOverWindow = true
                end
                if not UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = true end
            else
                restoreCursor()
            end
        end)
        Window._stopCursor = function()
            RunService:UnbindFromRenderStep(cursorBindingName)
            restoreCursor()
        end
    end

    -- ── Minimize / Restore badge ──────────────────────────────────────────────
    local RestoreBadge
    local function buildRestoreBadge()
        if RestoreBadge then return end
        RestoreBadge = New("TextButton", {
            Text = "Yenz",
            Font = F.Bold,
            TextSize = 13,
            TextColor3 = Color3.new(0,0,0),
            BackgroundColor3 = T.Accent,
            AutoButtonColor = false,
            Size = UDim2.fromOffset(68,28),
            Position = UDim2.fromOffset(20, 20),
            Parent = gui,
        }, {Corner(8)})
        -- Dragging the badge
        local bd, bs, bp
        RestoreBadge.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                bd=true; bs=i.Position; bp=RestoreBadge.Position
                i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then bd=false end end)
            end
        end)
        Track(UserInputService.InputChanged:Connect(function(i)
            if bd and i.UserInputType==Enum.UserInputType.MouseMovement then
                local d = i.Position-bs
                RestoreBadge.Position = UDim2.fromOffset(bp.X.Offset+d.X, bp.Y.Offset+d.Y)
            end
        end))
        RestoreBadge.MouseButton1Click:Connect(function()
            Window._minimized = false; Window._uiVisible = true
            WindowRoot.Visible = true; RestoreBadge:Destroy(); RestoreBadge = nil
            if blurEffect then blurEffect.Enabled=true end
        end)
    end

    minimizeBtn.MouseButton1Click:Connect(function()
        Window._minimized = true; Window._uiVisible = false
        WindowRoot.Visible = false
        if blurEffect then blurEffect.Enabled=false end
        buildRestoreBadge()
    end)

    -- ── Visibility toggle (hotkey) ────────────────────────────────────────────
    Track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp or UserInputService:GetFocusedTextBox() then return end
        if input.KeyCode == Library.ToggleKey then
            if Window._minimized then
                Window._minimized = false; Window._uiVisible = true
                WindowRoot.Visible = true
                if blurEffect then blurEffect.Enabled=true end
                if RestoreBadge then RestoreBadge:Destroy(); RestoreBadge = nil end
            else
                Window._uiVisible = not Window._uiVisible
                WindowRoot.Visible = Window._uiVisible
                if blurEffect then blurEffect.Enabled=Window._uiVisible end
            end
        end
    end))

    -- ── Navigation helper: category labels ───────────────────────────────────
    local _navOrder = 0
    local function navOrder() _navOrder += 1; return _navOrder end

    function Window:AddCategory(name)
        if _navOrder > 0 then
            New("Frame", {Size=UDim2.new(1,0,0,6), BackgroundTransparency=1, LayoutOrder=navOrder(), Parent=NavScroll})
        end
        New("TextLabel", {
            Text = name,
            Font = F.Medium,
            TextSize = 10,
            TextColor3 = T.TextMuted,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,18),
            LayoutOrder = navOrder(),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = NavScroll,
        }, {Padding(0,0,0,4)})
    end

    -- ── AddTab: navigation item ───────────────────────────────────────────────
    function Window:AddTab(name, icon, options)
        options = options or {}
        local Tab = {Subtabs={}, Current=nil}
        local lo = navOrder()

        -- Nav row
        local navRow = New("TextButton", {
            Name = name,
        Size = UDim2.new(1,0,0,36),
            BackgroundColor3 = T.SidebarBackground,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = lo,
            Parent = NavScroll,
        }, {Corner(7)})
        -- Left indicator bar
        local indicator = New("Frame", {
            Size = UDim2.fromOffset(3,18),
            Position = UDim2.new(0,0,0.5,-9),
            BackgroundColor3 = T.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = navRow,
        }, {Corner(2)})
        -- Icon
        local navIcon = New("ImageLabel", {
            Size = UDim2.fromOffset(16,16),
            Position = UDim2.new(0,10,0.5,-8),
            BackgroundTransparency = 1,
            Image = icon or "",
            ImageColor3 = T.TextMuted,
            ScaleType = Enum.ScaleType.Fit,
            Parent = navRow,
        })
        -- Label
        local navLabel = New("TextLabel", {
            Text = name,
            Font = F.Medium,
            TextSize = 11,
            TextColor3 = T.TextSecondary,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, options.Badge and -66 or -34,1,0),
            Position = UDim2.fromOffset(30,0),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = navRow,
        })

        local navBadge
        if options.Badge then
            navBadge = New("TextLabel", {
                Name="NavigationBadge",Text=tostring(options.Badge),Font=F.Medium,TextSize=9,
                TextColor3=options.Badge == "Soon" and T.Warning or T.TextSecondary,
                BackgroundColor3=T.InputBackground,BorderSizePixel=0,
                Size=UDim2.fromOffset(30,16),Position=UDim2.new(1,-36,0.5,-8),
                TextXAlignment=Enum.TextXAlignment.Center,Parent=navRow,
            }, {Corner(4),Stroke(T.Divider,0,1)})
        end

        -- Page area in PageBody
        local tabPage = New("Frame", {
            Name = "TabPage_"..name,
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = PageBody,
        })

        -- Subtab bar holder for this tab
        local tabSubBar = New("Frame", {
            Name = "SubBar_"..name,
            Size = UDim2.fromScale(1,1),
            BackgroundTransparency = 1,
            Visible = false,
            Parent = subBarList,
        }, {ListLayout(6, Enum.FillDirection.Horizontal)})

        Tab.Button = navRow; Tab.TabPage = tabPage; Tab.SubBarHolder = tabSubBar; Tab.Badge = navBadge
        Window.Tabs[#Window.Tabs+1] = Tab

        local function activateTab()
            if Window.CurrentTab == Tab then return end
            -- Deactivate all
            for _, t in ipairs(Window.Tabs) do
                t.Button.BackgroundTransparency = 1
                if t._navIndicator then Tween(t._navIndicator, 0.1, {BackgroundTransparency=1}) end
                if t._navIcon then t._navIcon.ImageColor3 = T.TextMuted end
                if t._navLabel then t._navLabel.TextColor3 = T.TextSecondary end
                if t.TabPage then t.TabPage.Visible = false end
                if t.SubBarHolder then t.SubBarHolder.Visible = false end
            end
            Window.CurrentTab = Tab
            Tween(navRow, 0.1, {BackgroundColor3=T.SelectedSurface, BackgroundTransparency=0})
            Tween(indicator, 0.1, {BackgroundTransparency=0})
            navIcon.ImageColor3 = T.Accent
            navLabel.TextColor3 = T.Accent
            topbarPageLabel.Text = name
            Window:SetStatus(options.Status == true or tostring(options.Status):lower() == "running")
            tabPage.Visible = true
            tabSubBar.Visible = not options.noSubtabBar
            SubtabBar.Visible = not options.noSubtabBar
            PageBody.Position = options.noSubtabBar and UDim2.fromOffset(0,0) or UDim2.fromOffset(0,34)
            PageBody.Size = options.noSubtabBar and UDim2.fromScale(1,1) or UDim2.new(1,0,1,-34)
            if Tab.Current then Tab.Current.Page.Visible = true
            elseif Tab.Subtabs[1] then Tab.Subtabs[1]:Select() end
            animatePage()
        end
        Tab._navIndicator = indicator
        Tab._navIcon = navIcon
        Tab._navLabel = navLabel
        Tab.Select = activateTab
        navRow.MouseButton1Click:Connect(activateTab)
        navRow.MouseEnter:Connect(function()
            if Window.CurrentTab ~= Tab then Tween(navRow, 0.08, {BackgroundColor3=T.HoverSurface, BackgroundTransparency=0}) end
        end)
        navRow.MouseLeave:Connect(function()
            if Window.CurrentTab ~= Tab then Tween(navRow, 0.08, {BackgroundTransparency=1}) end
        end)

        -- ── AddSubtab ─────────────────────────────────────────────────────────
        function Tab:AddSubtab(sname)
            local Sub = {}

            -- Subtab button with the active underline used in the HTML reference.
            local pill = New("TextButton", {
                Text = sname,
                Font = F.Medium,
                TextSize = 11,
                TextColor3 = T.TextSecondary,
                BackgroundColor3 = T.InputBackground,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Size = UDim2.fromOffset(0,34),
                AutomaticSize = Enum.AutomaticSize.X,
                LayoutOrder = #Tab.Subtabs+1,
                ZIndex = 11,
                Parent = tabSubBar,
            }, {Padding(0,12,0,12)})
            local subUnderline = New("Frame", {
                Name="ActiveUnderline",
                Size=UDim2.new(1,0,0,2),
                Position=UDim2.new(0,0,1,-2),
                BackgroundColor3=T.Accent,
                BorderSizePixel=0,
                Visible=false,
                Parent=pill,
                ZIndex=12,
            })

            -- Sub page inside the tab page
            local page = New("Frame", {
                Name = "SubPage_"..sname,
                Size = UDim2.fromScale(1,1),
                Position = UDim2.fromOffset(0,0),
                BackgroundTransparency = 1,
                Visible = false,
                Parent = tabPage,
            })

            -- Two independent scroll columns
            local function column(xOff, width)
                return New("ScrollingFrame", {
                    Size = UDim2.new(0, width, 1, 0),
                    Position = UDim2.fromOffset(xOff, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = T.Accent,
                    ScrollBarImageTransparency = 0.7,
                    CanvasSize = UDim2.new(),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    Parent = page,
                }, {ListLayout(10), Padding(8,0,8,0)})
            end

            -- Two padded columns: 268px each with a 10px gap.
            Sub.Left  = column(16, 268)
            Sub.Right = column(294, 268)
            Sub.Button = pill
            Sub.Page = page
            Sub._tab = Tab
            Sub._nameLabels = {}
            Tab.Subtabs[#Tab.Subtabs+1] = Sub

            function Sub:UseThreeColumns()
                Sub.Left.Size=UDim2.new(0,170,1,0)
                if not Sub.Middle then Sub.Middle=column(196,183) end
                Sub.Right.Position=UDim2.fromOffset(389,0)
                Sub.Right.Size=UDim2.new(0,173,1,0)
                return Sub
            end

            function Sub:AddBanner(options)
                options=options or {}
                local banner=New("Frame", {
                    Name="WelcomeBanner",
                    Size=UDim2.new(1,-32,0,112),
                    Position=UDim2.fromOffset(16,14),
                    BackgroundColor3=T.CardBackground,
                    BorderSizePixel=0,
                    ClipsDescendants=true,
                    Parent=page,
                }, {Corner(8),Stroke(T.Divider,0,1)})
                New("Frame", {
                    Name="BannerGlow",Size=UDim2.new(0.75,0,1,0),
                    BackgroundColor3=T.AccentDark,BackgroundTransparency=0.3,
                    BorderSizePixel=0,Parent=banner,
                }, {Corner(8),New("UIGradient",{
                    Rotation=0,
                    Transparency=NumberSequence.new({
                        NumberSequenceKeypoint.new(0,0.15),
                        NumberSequenceKeypoint.new(1,1),
                    }),
                })})
                local avatarRing=New("Frame", {
                    Name="WelcomeAvatarRing",Size=UDim2.fromOffset(84,84),
                    Position=UDim2.fromOffset(14,14),BackgroundColor3=T.Accent,
                    BorderSizePixel=0,ZIndex=2,Parent=banner,
                }, {Corner(100),Stroke(T.Accent,0,1.5)})
                local avatarClip=New("Frame", {
                    Size=UDim2.fromOffset(80,80),Position=UDim2.fromOffset(2,2),
                    BackgroundColor3=T.SelectedSurface,BorderSizePixel=0,
                    ClipsDescendants=true,ZIndex=3,Parent=avatarRing,
                }, {Corner(100)})
                local fallback=New("TextLabel", {
                    Name="AvatarFallback",
                    Text=string.sub(initialUser.DisplayName or initialUser.Name or "P",1,1):upper(),
                    Font=F.Bold,TextSize=28,TextColor3=T.TextPrimary,
                    BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=4,Parent=avatarClip,
                })
                initialUser.AvatarFallbacks=initialUser.AvatarFallbacks or {}
                initialUser.AvatarFallbacks[#initialUser.AvatarFallbacks+1]=fallback
                local image=New("ImageLabel", {
                    Name="WelcomeAvatar",Size=UDim2.fromScale(1,1),
                    BackgroundTransparency=1,ImageTransparency=1,
                    Image=initialUser.Image or "rbxthumb://type=AvatarBust&id="..tostring(initialUser.UserId).."&w=150&h=150",
                    ScaleType=Enum.ScaleType.Crop,ZIndex=4,Parent=avatarClip,
                }, {Corner(100)})
                AvatarViews[#AvatarViews+1]={Image=image,Fallback=fallback}
                local textX=112
                New("TextLabel", {
                    Text="WELCOME BACK",Font=F.SemiBold,TextSize=11,
                    TextColor3=T.AccentBright,BackgroundTransparency=1,
                    Size=UDim2.new(1,-textX-14,0,14),Position=UDim2.fromOffset(textX,14),
                    TextXAlignment=Enum.TextXAlignment.Left,ZIndex=2,Parent=banner,
                })
                local nameLabel=New("TextLabel", {
                    Name="WelcomeDisplayName",Text=options.User or initialUser.DisplayName,
                    Font=F.Bold,TextSize=20,TextColor3=T.TextPrimary,
                    BackgroundTransparency=1,Size=UDim2.new(1,-textX-14,0,27),
                    Position=UDim2.fromOffset(textX,29),TextXAlignment=Enum.TextXAlignment.Left,
                    TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=2,Parent=banner,
                })
                Sub._nameLabels[#Sub._nameLabels+1]=nameLabel
                initialUser.NameLabels=initialUser.NameLabels or {}
                initialUser.NameLabels[#initialUser.NameLabels+1]=nameLabel
                New("TextLabel", {
                    Text=options.Subtitle or "Ready to farm? Pick a feature from the sidebar.",
                    Font=F.Regular,TextSize=11,TextColor3=T.TextSecondary,
                    BackgroundTransparency=1,Size=UDim2.new(1,-textX-14,0,16),
                    Position=UDim2.fromOffset(textX,58),TextXAlignment=Enum.TextXAlignment.Left,
                    TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=2,Parent=banner,
                })
                local function chip(text,x,width,color)
                    local frame=New("Frame", {
                        Size=UDim2.fromOffset(width,18),Position=UDim2.fromOffset(x,82),
                        BackgroundColor3=color,BorderSizePixel=0,ZIndex=2,Parent=banner,
                    }, {Corner(9),Stroke(T.Divider,0,1)})
                    New("TextLabel", {Text=text,Font=F.Medium,TextSize=9,
                        TextColor3=T.TextSecondary,BackgroundTransparency=1,
                        Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,
                        ZIndex=3,Parent=frame})
                end
                chip("Pixel Lineage",textX,82,T.AccentDark)
                chip("Yenz v2.0",textX+88,64,T.InputBackground)
                Sub.Left.Position=UDim2.fromOffset(16,128)
                Sub.Left.Size=UDim2.new(0,268,1,-136)
                Sub.Right.Position=UDim2.fromOffset(294,128)
                Sub.Right.Size=UDim2.new(0,268,1,-136)
                Sub.Banner=banner
                return banner
            end

            function Sub:Select()
                for _, s in ipairs(Tab.Subtabs) do
                    s.Page.Visible = false
                    s.Button.TextColor3 = T.TextSecondary
                    s._underline.Visible = false
                end
                Tab.Current = Sub
                page.Visible = true
                pill.TextColor3 = T.Accent
                subUnderline.Visible = true
                animatePage()
            end
            pill.MouseButton1Click:Connect(function() Sub:Select() end)
            Sub._underline = subUnderline

            -- ── AddGroup: collapsible card ─────────────────────────────────────
            function Sub:AddGroup(gname, gicon, side, _height)
                local col = side == "Right" and Sub.Right or (side == "Middle" and Sub.Middle or Sub.Left)
                local G = {_expanded = true}

                -- Outer card frame
                local card = New("Frame", {
                    Name = "Card_"..gname,
                    Size = UDim2.new(1,0,0,30),
                    BackgroundColor3 = T.CardBackground,
                    BorderSizePixel = 0,
                    AutomaticSize = Enum.AutomaticSize.None,
                    LayoutOrder = #col:GetChildren(),
                    Parent = col,
                }, {Corner(8), Stroke(T.Divider,0,1)})

                -- Header (30px, always visible)
                local header = New("TextButton", {
                    Size = UDim2.new(1,0,0,30),
                    BackgroundColor3 = T.CardHeader,
                    AutoButtonColor = false,
                    Text = "",
                    Parent = card,
                }, {Corner(8)})
                -- Square off bottom corners when expanded
                New("Frame", {Size=UDim2.fromOffset(card.AbsoluteSize.X,8), Position=UDim2.fromOffset(0,22),
                    BackgroundColor3=T.CardHeader, BorderSizePixel=0, Parent=header})

                -- Group icon
                if gicon then
                    New("ImageLabel", {
                        Size = UDim2.fromOffset(12,12),
                        Position = UDim2.fromOffset(10,9),
                        BackgroundTransparency = 1,
                        Image = gicon,
                        ImageColor3 = T.Accent,
                        ScaleType = Enum.ScaleType.Fit,
                        Parent = header,
                    })
                end
                local iconOff = gicon and 28 or 12
                local groupTitle = New("TextLabel", {
                    Text = gname,
                    Font = F.SemiBold,
                    TextSize = 11,
                    TextColor3 = T.TextPrimary,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1,-iconOff-24,0,30),
                    Position = UDim2.fromOffset(iconOff,0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = header,
                })
                function G:SetBadge(text)
                    if G._badge then G._badge:Destroy() end
                    if not text or text=="" then
                        G._badge=nil
                        groupTitle.Size=UDim2.new(1,-iconOff-24,0,30)
                        return G
                    end
                    groupTitle.Size=UDim2.new(1,-iconOff-106,0,30)
                    G._badge=New("TextLabel", {
                        Name="GroupBadge",Text=tostring(text),Font=F.Medium,TextSize=9,
                        TextColor3=T.Warning,BackgroundColor3=T.InputBackground,
                        Size=UDim2.fromOffset(78,16),
                        Position=UDim2.new(1,-101,0.5,-8),Parent=header,
                    }, {Corner(8),Stroke(T.Warning,0.6,1)})
                    return G
                end
                -- Collapse chevron
                local chevron = New("TextLabel", {
                    Text = "▾",
                    Font = F.Regular,
                    TextSize = 11,
                    TextColor3 = T.TextMuted,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(20,30),
                    Position = UDim2.new(1,-22,0,0),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    Parent = header,
                })

                -- Body frame (holds controls)
                local body = New("Frame", {
                    Size = UDim2.new(1,-8,0,0),
                    Position = UDim2.fromOffset(4,30),
                    BackgroundTransparency = 1,
                    ClipsDescendants = true,
                    AutomaticSize = Enum.AutomaticSize.None,
                    Parent = card,
                })
                local bodyList = New("Frame", {
                    Size = UDim2.new(1,0,0,0),
                    BackgroundTransparency = 1,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = body,
                }, {ListLayout(4), Padding(6,4,6,4)})

                -- Track natural height
                local _bodyHeight = 0
                bodyList:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                    _bodyHeight = bodyList.AbsoluteSize.Y
                    if G._expanded then
                        body.Size = UDim2.new(1,-8,0,_bodyHeight)
                        card.Size = UDim2.new(1,0,0,30 + _bodyHeight)
                    end
                end)

                -- Collapse/expand toggle
                header.MouseButton1Click:Connect(function()
                    G._expanded = not G._expanded
                    if G._expanded then
                        chevron.Text = "▾"
                        Tween(body, 0.16, {Size=UDim2.new(1,-8,0,_bodyHeight)})
                        Tween(card, 0.16, {Size=UDim2.new(1,0,0,30+_bodyHeight)})
                    else
                        chevron.Text = "▸"
                        Tween(body, 0.16, {Size=UDim2.new(1,-8,0,0)})
                        Tween(card, 0.16, {Size=UDim2.new(1,0,0,30)})
                    end
                end)

                -- ── Control helpers ────────────────────────────────────────────
                local _rowN = 0
                local function row(h)
                    _rowN += 1
                    return New("Frame", {
                        Size = UDim2.new(1,0,0,h),
                        BackgroundTransparency = 1,
                        LayoutOrder = _rowN,
                        Parent = bodyList,
                    })
                end
                local function flagSet(f, v)
                    if not f then return end
                    if typeof(v)=="Color3" then
                        Library.Flags[f]={r=v.R,g=v.G,b=v.B}
                    elseif typeof(v)=="EnumItem" then
                        Library.Flags[f]=v.Name
                    else
                        Library.Flags[f]=v
                    end
                end

                -- AddCheckbox (toggle)
                function G:AddCheckbox(o)
                    o = type(o) == "string" and {Name=o} or o
                    local state = o.Default
                    if state == nil then state = false end
                    local r = row(28)
                    local lbl = New("TextLabel", {
                        Text = o.Name,
                        Font = F.Regular,
                        TextSize = 11,
                        TextColor3 = state and T.TextPrimary or T.TextSecondary,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1,-56,1,0),
                        Position = UDim2.fromOffset(0,0),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = r,
                    })
                    -- Toggle track
                    local track = New("TextButton", {
                        Size = UDim2.fromOffset(28,16),
                        Position = UDim2.new(1,-36,0.5,-8),
                        BackgroundColor3 = state and T.Accent or T.ToggleOff,
                        AutoButtonColor = false,
                        Text = "",
                        Parent = r,
                    }, {Corner(100)})
                    local thumb = New("Frame", {
                        Size = UDim2.fromOffset(12,12),
                        Position = UDim2.new(0, state and 14 or 2, 0.5, -6),
                        BackgroundColor3 = T.ToggleThumb,
                        BorderSizePixel = 0,
                        Parent = track,
                    }, {Corner(100)})
                    local obj = {}
                    function obj:Set(v)
                        state = v
                        Tween(track, 0.12, {BackgroundColor3 = v and T.Accent or T.ToggleOff})
                        Tween(thumb, 0.12, {Position = UDim2.new(0, v and 14 or 2, 0.5, -6)})
                        lbl.TextColor3 = v and T.TextPrimary or T.TextSecondary
                        flagSet(o.Flag, v)
                        InvokeCallback(o.Name, o.Callback, v)
                    end
                    function obj:Get() return state end
                    track.MouseButton1Click:Connect(function()
                        if not o.Disabled then obj:Set(not state) end
                    end)
                    flagSet(o.Flag, state)
                    return obj
                end

                -- AddSlider
                function G:AddSlider(o)
                    local min, max = o.Min or 0, o.Max or 100
                    local val = math.clamp(o.Default or min, min, max)
                    local suffix = o.Suffix or ""
                    local r = row(40)
                    -- Label row
                    New("TextLabel", {
                        Text = o.Name,
                        Font = F.Regular,
                        TextSize = 11,
                        TextColor3 = T.TextSecondary,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1,-50,0,18),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = r,
                    })
                    local valLabel = New("TextBox", {
                        ClearTextOnFocus = false,
                        Text = tostring(val)..suffix,
                        Font = F.Medium,
                        TextSize = 11,
                        TextColor3 = T.TextPrimary,
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(48,18),
                        Position = UDim2.new(1,-48,0,0),
                        TextXAlignment = Enum.TextXAlignment.Right,
                        Parent = r,
                    })
                    -- Track
                    local trackBg = New("Frame", {
                        Size = UDim2.new(1,-8,0,4),
                        Position = UDim2.fromOffset(0,24),
                        BackgroundColor3 = T.ToggleOff,
                        BorderSizePixel = 0,
                        Parent = r,
                    }, {Corner(2)})
                    local fill = New("Frame", {
                        Size = UDim2.new(0,0,1,0),
                        BackgroundColor3 = T.Accent,
                        BorderSizePixel = 0,
                        Parent = trackBg,
                    }, {Corner(2)})
                    local grab = New("Frame", {
                        Size = UDim2.fromOffset(10,10),
                        AnchorPoint = Vector2.new(0.5,0.5),
                        Position = UDim2.new(0,0,0.5,0),
                        BackgroundColor3 = T.Accent,
                        BorderSizePixel = 0,
                        Parent = trackBg,
                    }, {Corner(100)})
                    local obj = {}
                    local initialized = false
                    function obj:Set(v, instant)
                        v = tonumber(v)
                        if not v or v ~= v or math.abs(v) == math.huge then
                            valLabel.Text = tostring(val)..suffix
                            return
                        end
                        v = math.clamp(v, min, max)
                        if not o.Decimals then v = math.floor(v+0.5)
                        else v = math.floor(v*10^o.Decimals+.5)/10^o.Decimals end
                        local changed = val ~= v
                        if initialized and not changed then
                            if valLabel.Text ~= tostring(v)..suffix then valLabel.Text = tostring(v)..suffix end
                            return
                        end
                        initialized = true
                        val = v
                        local p = max > min and (v-min)/(max-min) or 0
                        local t2 = instant and 0 or 0.1
                        Tween(fill, t2, {Size=UDim2.new(p,0,1,0)})
                        Tween(grab, t2, {Position=UDim2.new(p,0,0.5,0)})
                        valLabel.Text = tostring(v)..suffix
                        flagSet(o.Flag, v)
                        InvokeCallback(o.Name, o.Callback, v)
                    end
                    function obj:Get() return val end
                    valLabel.FocusLost:Connect(function()
                        local text = valLabel.Text:match("^%s*(.-)%s*$")
                        if suffix ~= "" and text:sub(-#suffix) == suffix then text = text:sub(1, -#suffix-1) end
                        obj:Set(tonumber(text))
                    end)
                    obj.Input = valLabel
                    local sliding = false
                    local function updateSlider(x)
                        local bx = trackBg.AbsolutePosition.X
                        local bw = trackBg.AbsoluteSize.X
                        if bw <= 0 then return end
                        obj:Set(min + (max-min)*math.clamp((x-bx)/bw,0,1))
                    end
                    local inputBtn = New("TextButton", {Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",ZIndex=2,Parent=trackBg})
                    inputBtn.InputBegan:Connect(function(i)
                        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
                            sliding=true; updateSlider(i.Position.X)
                        end
                    end)
                    Track(UserInputService.InputEnded:Connect(function(i)
                        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sliding=false end
                    end))
                    Track(UserInputService.InputChanged:Connect(function(i)
                        if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
                            updateSlider(i.Position.X) end
                    end))
                    obj:Set(val, true)
                    return obj
                end

                -- AddDropdown
                function G:AddDropdown(o)
                    local items = o.Items or {}
                    local sel = o.Default or items[1]
                    local r = row(28)
                    New("TextLabel", {
                        Text = o.Name,
                        Font = F.Regular,
                        TextSize = 11,
                        TextColor3 = T.TextSecondary,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0.42,-4,1,0),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = r,
                    })
                    local box = New("TextButton", {
                        Size = UDim2.new(0.58,-4,0,24),
                        Position = UDim2.new(0.42,4,0.5,-12),
                        BackgroundColor3 = T.InputBackground,
                        AutoButtonColor = false,
                        Text = "",
                        Parent = r,
                    }, {Corner(5), Stroke(T.Divider,0,1)})
                    local selLabel = New("TextLabel", {
                        Text = tostring(sel or ""),
                        Font = F.Regular,
                        TextSize = 11,
                        TextColor3 = T.TextPrimary,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1,-20,1,0),
                        Position = UDim2.fromOffset(6,0),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = box,
                    })
                    New("TextLabel", {Text="▾",Font=F.Regular,TextSize=11,TextColor3=T.TextMuted,
                        BackgroundTransparency=1,Size=UDim2.fromOffset(16,24),Position=UDim2.new(1,-16,0,0),
                        TextXAlignment=Enum.TextXAlignment.Center,Parent=box})

                    -- Popup
                    local popup = New("ScrollingFrame", {
                        Visible=false, ZIndex=200,
                        Size=UDim2.fromOffset(0,0),
                        BackgroundColor3=T.CardHeader, BorderSizePixel=0,
                        ScrollBarThickness=2, ScrollBarImageColor3=T.Accent,
                        CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
                        Parent=PopupHost,
                    }, {Corner(6), Stroke(T.Divider,0,1), ListLayout(0)})

                    local obj2, open2 = {}, false
                    local function build2()
                        for _, c in ipairs(popup:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                        for i, it in ipairs(items) do
                            local b = New("TextButton", {
                                Size=UDim2.new(1,0,0,24),
                                BackgroundColor3 = it==sel and T.SelectedSurface or T.CardHeader,
                                BackgroundTransparency=0,
                                AutoButtonColor=false,
                                Text="  "..tostring(it),
                                Font=F.Regular, TextSize=11,
                                TextColor3=it==sel and T.TextPrimary or T.TextSecondary,
                                TextXAlignment=Enum.TextXAlignment.Left,
                                TextTruncate=Enum.TextTruncate.AtEnd,
                                LayoutOrder=i, ZIndex=201, Parent=popup,
                            })
                            b.MouseEnter:Connect(function() if it~=sel then b.BackgroundColor3=T.HoverSurface; b.TextColor3=T.TextPrimary end end)
                            b.MouseLeave:Connect(function() if it~=sel then b.BackgroundColor3=T.CardHeader; b.TextColor3=T.TextSecondary end end)
                            b.MouseButton1Click:Connect(function() obj2:Set(it); obj2:Close() end)
                        end
                    end
                    function obj2:Close()
                        open2 = false
                        Tween(popup, 0.12, {Size=UDim2.fromOffset(popup.AbsoluteSize.X,0)}).Completed:Connect(function()
                            if not open2 then popup.Visible=false end
                        end)
                    end
                    function obj2:Open()
                        open2 = true; build2()
                        local ap = box.AbsolutePosition
                        local rp = WindowRoot.AbsolutePosition
                        local vpH = workspace.CurrentCamera.ViewportSize.Y
                        local w = box.AbsoluteSize.X
                        local maxH = math.min(#items*24, 160)
                        local yPos = ap.Y - rp.Y + box.AbsoluteSize.Y + 2
                        if ap.Y + box.AbsoluteSize.Y + maxH > vpH then
                            yPos = ap.Y - rp.Y - maxH - 2
                        end
                        popup.Position = UDim2.fromOffset(ap.X - rp.X, yPos)
                        popup.Size = UDim2.fromOffset(math.max(w, 120), 0)
                        popup.Visible = true
                        Tween(popup, 0.15, {Size=UDim2.fromOffset(math.max(w,120), maxH)})
                    end
                    function obj2:Set(v)
                        sel=v; selLabel.Text=tostring(v)
                        flagSet(o.Flag, v)
                        InvokeCallback(o.Name, o.Callback, v)
                    end
                    function obj2:Refresh(newItems)
                        items=newItems
                        -- preserve selection if still valid
                        local found=false
                        for _,it in ipairs(items) do if it==sel then found=true;break end end
                        if not found and #items>0 then sel=items[1]; selLabel.Text=tostring(sel); flagSet(o.Flag,sel) end
                        if open2 then build2() end
                    end
                    function obj2:Get() return sel end
                    box.MouseEnter:Connect(function() Tween(box,0.08,{BackgroundColor3=T.HoverSurface}) end)
                    box.MouseLeave:Connect(function() Tween(box,0.08,{BackgroundColor3=T.InputBackground}) end)
                    box.MouseButton1Click:Connect(function() if open2 then obj2:Close() else obj2:Open() end end)
                    Track(UserInputService.InputBegan:Connect(function(i)
                        if open2 and i.UserInputType==Enum.UserInputType.MouseButton1 then
                            local m=i.Position
                            local pp,ps=popup.AbsolutePosition,popup.AbsoluteSize
                            local bp,bs=box.AbsolutePosition,box.AbsoluteSize
                            local inP = m.X>=pp.X and m.X<=pp.X+ps.X and m.Y>=pp.Y and m.Y<=pp.Y+ps.Y
                            local inB = m.X>=bp.X and m.X<=bp.X+bs.X and m.Y>=bp.Y and m.Y<=bp.Y+bs.Y
                            if not inP and not inB then obj2:Close() end
                        end
                    end))
                    flagSet(o.Flag, sel)
                    return obj2
                end
                G.AddCombo = G.AddDropdown

                -- AddTextbox
                function G:AddTextbox(o)
                    local r = row(28)
                    New("TextLabel", {
                        Text=o.Name, Font=F.Regular, TextSize=11, TextColor3=T.TextSecondary,
                        BackgroundTransparency=1, Size=UDim2.new(0.45,-4,1,0),
                        TextXAlignment=Enum.TextXAlignment.Left, Parent=r,
                    })
                    local frame = New("Frame", {
                        Size=UDim2.new(0.55,-4,0,24), Position=UDim2.new(0.45,4,0.5,-12),
                        BackgroundColor3=T.InputBackground, Parent=r,
                    }, {Corner(5), Stroke(T.Divider,0,1)})
                    local tb = New("TextBox", {
                        Size=UDim2.new(1,-8,1,0), Position=UDim2.fromOffset(4,0),
                        BackgroundTransparency=1, Text=o.Default or "",
                        PlaceholderText=o.Placeholder or "", ClearTextOnFocus=false,
                        Font=F.Regular, TextSize=11, TextColor3=T.TextPrimary,
                        PlaceholderColor3=T.TextMuted, TextXAlignment=Enum.TextXAlignment.Left,
                        ClipsDescendants=true, Parent=frame,
                    })
                    tb.Focused:Connect(function() Tween(frame,0.1,{BackgroundColor3=T.HoverSurface}); Stroke(T.Accent,0,1).Parent=frame end)
                    tb.FocusLost:Connect(function(enter)
                        Tween(frame,0.1,{BackgroundColor3=T.InputBackground})
                        flagSet(o.Flag, tb.Text)
                        InvokeCallback(o.Name, o.Callback, tb.Text, enter)
                    end)
                    flagSet(o.Flag, o.Default or "")
                    return {Set=function(_,v)
                        tb.Text=tostring(v or "")
                        flagSet(o.Flag,tb.Text)
                        InvokeCallback(o.Name,o.Callback,tb.Text,false)
                    end, Get=function() return tb.Text end}
                end
                G.AddInput = G.AddTextbox

                -- AddButton
                function G:AddButton(o)
                    o = type(o)=="string" and {Name=o} or o
                    local r = row(28)
                    local isPrimary = o.Primary
                    local btn = New("TextButton", {
                        Text=o.Name,
                        Font=F.SemiBold, TextSize=11,
                        TextColor3 = isPrimary and Color3.new(0,0,0) or T.TextPrimary,
                        BackgroundColor3 = isPrimary and T.Accent or T.InputBackground,
                        AutoButtonColor=false,
                        Size=UDim2.new(1,0,0,26),
                        Parent=r,
                    }, {Corner(5), Stroke(T.Divider,0,1)})
                    btn.MouseEnter:Connect(function() Tween(btn,0.08,{BackgroundColor3= isPrimary and T.AccentBright or T.HoverSurface}) end)
                    btn.MouseLeave:Connect(function() Tween(btn,0.08,{BackgroundColor3= isPrimary and T.Accent or T.InputBackground}) end)
                    btn.MouseButton1Click:Connect(function() InvokeCallback(o.Name, o.Callback) end)
                    return btn
                end

                function G:AddButtonRow(buttons)
                    assert(type(buttons)=="table", "AddButtonRow expects an array")
                    local r=row(26)
                    local offset=0
                    local result={}
                    for _,option in ipairs(buttons) do
                        local title=tostring(option.Name or "Button")
                        local width=math.max(58,#title*5+18)
                        local base=option.Danger and T.InputBackground or T.HoverSurface
                        local button=New("TextButton", {
                            Text=title,Font=F.SemiBold,TextSize=10,
                            TextColor3=option.Danger and T.Danger or T.TextPrimary,
                            BackgroundColor3=base,AutoButtonColor=false,
                            Size=UDim2.fromOffset(width,24),Position=UDim2.fromOffset(offset,0),
                            Parent=r,
                        }, {Corner(8),Stroke(option.Danger and T.Danger or T.Divider,option.Danger and 0.5 or 0,1)})
                        button.MouseEnter:Connect(function() Tween(button,0.08,{BackgroundColor3=T.HoverSurface}) end)
                        button.MouseLeave:Connect(function() Tween(button,0.08,{BackgroundColor3=base}) end)
                        button.MouseButton1Click:Connect(function() InvokeCallback(title,option.Callback) end)
                        result[#result+1]=button
                        offset+=width+5
                    end
                    return result
                end

                function G:AddColorSwatches(o)
                    assert(type(o)=="table" and type(o.Items)=="table", "AddColorSwatches expects Items")
                    local r=row(28)
                    local selected=o.Default or (o.Items[1] and o.Items[1].Name)
                    local entries={}
                    New("TextLabel", {
                        Text=tostring(o.Name or "Accent Color"),Font=F.Regular,TextSize=11,
                        TextColor3=T.TextSecondary,BackgroundTransparency=1,
                        Size=UDim2.new(1,-120,1,0),TextXAlignment=Enum.TextXAlignment.Left,
                        Parent=r,
                    })
                    local function paint()
                        for _,entry in ipairs(entries) do
                            local active=entry.Name==selected
                            entry.Stroke.Color=active and T.Accent or T.Divider
                            entry.Stroke.Thickness=active and 1.5 or 1
                        end
                    end
                    for index,item in ipairs(o.Items) do
                        local color=typeof(item.Color)=="Color3" and item.Color or T.Accent
                        local stroke=Stroke(T.Divider,0,1)
                        local button=New("TextButton", {
                            Name="ColorSwatch_"..tostring(item.Name or index),Text="",
                            Size=UDim2.fromOffset(14,14),
                            Position=UDim2.fromOffset(120+(index-1)*20,7),
                            BackgroundColor3=color,AutoButtonColor=false,Parent=r,
                        }, {Corner(100),stroke})
                        local entry={Name=tostring(item.Name or index),Color=color,Stroke=stroke}
                        entries[#entries+1]=entry
                        button.MouseButton1Click:Connect(function()
                            selected=entry.Name
                            paint()
                            flagSet(o.Flag,selected)
                            InvokeCallback(o.Name,o.Callback,entry.Color,selected)
                        end)
                        button.MouseEnter:Connect(function() Window:ShowTooltip(entry.Name,button) end)
                        button.MouseLeave:Connect(function() Window:HideTooltip() end)
                    end
                    paint()
                    flagSet(o.Flag,selected)
                    return {Get=function() return selected end,Set=function(_,name)
                        for _,entry in ipairs(entries) do
                            if entry.Name==name then
                                selected=name
                                paint()
                                flagSet(o.Flag,selected)
                                InvokeCallback(o.Name,o.Callback,entry.Color,selected)
                                return
                            end
                        end
                    end}
                end

                -- AddLabel
                function G:AddLabel(text)
                    local r = row(28)
                    New("TextLabel", {
                        Text=text, Font=F.Regular, TextSize=11, TextColor3=T.TextMuted,
                        BackgroundTransparency=1, Size=UDim2.fromScale(1,1),
                        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true,
                        Parent=r,
                    })
                end

                function G:AddBadgeRow(label, badge)
                    local r = row(20)
                    local badgeText = tostring(badge or "")
                    local badgeWidth = math.max(46, #badgeText * 5 + 12)
                    New("TextLabel", {
                        Text=tostring(label or ""), Font=F.Regular, TextSize=11,
                        TextColor3=T.TextSecondary, BackgroundTransparency=1,
                        Size=UDim2.new(1,-badgeWidth-8,1,0),
                        TextXAlignment=Enum.TextXAlignment.Left, Parent=r,
                    })
                    local badgeFrame=New("Frame", {
                        BackgroundColor3=T.InputBackground, BorderSizePixel=0,
                        Size=UDim2.fromOffset(badgeWidth,16),
                        Position=UDim2.new(1,-badgeWidth,0.5,-8), Parent=r,
                    }, {Corner(8),Stroke(T.Divider,0,1)})
                    New("TextLabel", {
                        Text=badgeText, Font=F.Regular, TextSize=9,
                        TextColor3=T.TextMuted, BackgroundTransparency=1,
                        Size=UDim2.fromScale(1,1), Parent=badgeFrame,
                    })
                    return r
                end

                -- AddSeparator
                function G:AddSeparator()
                    local r = row(10)
                    New("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.fromOffset(0,5),
                        BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=r})
                end

                -- AddKeybind
                function G:AddKeybind(o)
                    local r = row(28)
                    local function asKey(value)
                        if typeof(value)=="EnumItem" and value.EnumType==Enum.KeyCode then return value end
                        if type(value)=="string" then
                            local ok,key=pcall(function() return Enum.KeyCode[value] end)
                            if ok and key then return key end
                        end
                        return Enum.KeyCode.Unknown
                    end
                    local function displayKey(key)
                        if key==Enum.KeyCode.RightControl then return "RCtrl" end
                        if key==Enum.KeyCode.LeftControl then return "LCtrl" end
                        return key.Name
                    end
                    local bound = asKey(o.Default)
                    New("TextLabel", {
                        Text=o.Name, Font=F.Regular, TextSize=11, TextColor3=T.TextSecondary,
                        BackgroundTransparency=1, Size=UDim2.new(0.55,-4,1,0),
                        TextXAlignment=Enum.TextXAlignment.Left, Parent=r,
                    })
                    local kbBtn = New("TextButton", {
                        Text=displayKey(bound),
                        Font=F.Medium, TextSize=11, TextColor3=T.TextPrimary,
                        BackgroundColor3=T.InputBackground, AutoButtonColor=false,
                        Size=UDim2.new(0.45,-4,0,24), Position=UDim2.new(0.55,4,0.5,-12),
                        Parent=r,
                    }, {Corner(5), Stroke(T.Divider,0,1)})
                    local listening = false
                    kbBtn.MouseButton1Click:Connect(function()
                        if listening then return end
                        listening = true; kbBtn.Text = "…"
                        local conn
                        conn = Track(UserInputService.InputBegan:Connect(function(i, gp)
                            if gp then return end
                            if i.UserInputType == Enum.UserInputType.Keyboard then
                                bound = i.KeyCode
                                kbBtn.Text = displayKey(i.KeyCode)
                                listening = false
                                conn:Disconnect()
                                flagSet(o.Flag,bound)
                                InvokeCallback(o.Name, o.Callback, i.KeyCode)
                            end
                        end))
                    end)
                    flagSet(o.Flag,bound)
                    return {Get=function() return bound end, Set=function(_,k)
                        bound=asKey(k)
                        kbBtn.Text=displayKey(bound)
                        flagSet(o.Flag,bound)
                        InvokeCallback(o.Name,o.Callback,bound)
                    end}
                end

                -- AddColorPicker (basic — opens a simple hue/sv picker)
                function G:AddColorPicker(o)
                    local h2, s2, v2 = (o.Default or Color3.new(1,1,1)):ToHSV()
                    local r = row(28)
                    New("TextLabel", {
                        Text=o.Name, Font=F.Regular, TextSize=11, TextColor3=T.TextSecondary,
                        BackgroundTransparency=1, Size=UDim2.new(1,-30,1,0),
                        TextXAlignment=Enum.TextXAlignment.Left, Parent=r,
                    })
                    local prev = New("TextButton", {
                        Size=UDim2.fromOffset(22,22), Position=UDim2.new(1,-26,0.5,-11),
                        BackgroundColor3=Color3.fromHSV(h2,s2,v2), AutoButtonColor=false, Text="",
                        Parent=r,
                    }, {Corner(5)})
                    -- Minimal popup with hue strip + sv box
                    local pop = New("Frame", {
                        Visible=false, ZIndex=200,
                        Size=UDim2.fromOffset(180,120),
                        BackgroundColor3=T.CardHeader, BorderSizePixel=0,
                        Parent=PopupHost,
                    }, {Corner(8), Stroke(T.Divider,0,1)})
                    local sv2 = New("ImageButton", {
                        ZIndex=201, Size=UDim2.fromOffset(160,80), Position=UDim2.fromOffset(10,10),
                        BackgroundColor3=Color3.fromHSV(h2,1,1), AutoButtonColor=false, Image="", Parent=pop,
                    }, {Corner(4)})
                    New("Frame",{ZIndex=202,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),Parent=sv2},{
                        Corner(4),New("UIGradient",{Transparency=NumberSequence.new(0,1)})})
                    New("Frame",{ZIndex=203,Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),Parent=sv2},{
                        Corner(4),New("UIGradient",{Rotation=90,Transparency=NumberSequence.new(1,0)})})
                    local svK = New("Frame",{ZIndex=204,Size=UDim2.fromOffset(8,8),AnchorPoint=Vector2.new(.5,.5),
                        BackgroundTransparency=1,Parent=sv2},{Corner(4),Stroke(Color3.new(1,1,1),0)})
                    local hueBar = New("ImageButton", {
                        ZIndex=201, Size=UDim2.fromOffset(160,12), Position=UDim2.fromOffset(10,98),
                        BackgroundColor3=Color3.new(1,1,1), AutoButtonColor=false, Image="", Parent=pop,
                    }, {Corner(4), New("UIGradient",{Color=ColorSequence.new({
                        ColorSequenceKeypoint.new(0,Color3.fromHSV(0,1,1)),ColorSequenceKeypoint.new(1/6,Color3.fromHSV(1/6,1,1)),
                        ColorSequenceKeypoint.new(2/6,Color3.fromHSV(2/6,1,1)),ColorSequenceKeypoint.new(3/6,Color3.fromHSV(3/6,1,1)),
                        ColorSequenceKeypoint.new(4/6,Color3.fromHSV(4/6,1,1)),ColorSequenceKeypoint.new(5/6,Color3.fromHSV(5/6,1,1)),
                        ColorSequenceKeypoint.new(1,Color3.fromHSV(1,1,1))})})})
                    local hK = New("Frame",{ZIndex=202,Size=UDim2.fromOffset(10,16),AnchorPoint=Vector2.new(.5,.5),
                        Position=UDim2.new(h2,0,.5,0),BackgroundColor3=Color3.fromHSV(h2,1,1),Parent=hueBar},{Corner(3)})

                    local obj3 = {}
                    local function refresh3()
                        local c = Color3.fromHSV(h2,s2,v2)
                        prev.BackgroundColor3=c; sv2.BackgroundColor3=Color3.fromHSV(h2,1,1)
                        svK.Position=UDim2.fromScale(s2,1-v2)
                        hK.Position=UDim2.new(h2,0,.5,0); hK.BackgroundColor3=Color3.fromHSV(h2,1,1)
                        flagSet(o.Flag, c)
                        InvokeCallback(o.Name, o.Callback, c, 1)
                    end
                    function obj3:Set(c,_)
                        if type(c)=="table" then
                            c=Color3.new(tonumber(c.r or c.R) or 1,tonumber(c.g or c.G) or 1,tonumber(c.b or c.B) or 1)
                        end
                        if typeof(c)~="Color3" then return end
                        h2,s2,v2=c:ToHSV()
                        refresh3()
                    end
                    function obj3:Get() return Color3.fromHSV(h2,s2,v2) end
                    -- SV pick
                    local svDrag=false
                    sv2.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then svDrag=true end end)
                    Track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then svDrag=false end end))
                    Track(UserInputService.InputChanged:Connect(function(i)
                        if svDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                            local ap=sv2.AbsolutePosition; local as=sv2.AbsoluteSize
                            s2=math.clamp((i.Position.X-ap.X)/as.X,0,1)
                            v2=1-math.clamp((i.Position.Y-ap.Y)/as.Y,0,1)
                            refresh3()
                        end
                    end))
                    -- Hue pick
                    local hueDrag=false
                    hueBar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=true end end)
                    Track(UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then hueDrag=false end end))
                    Track(UserInputService.InputChanged:Connect(function(i)
                        if hueDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
                            local ap=hueBar.AbsolutePosition; local as=hueBar.AbsoluteSize
                            h2=math.clamp((i.Position.X-ap.X)/as.X,0,1); refresh3()
                        end
                    end))
                    local popOpen=false
                    prev.MouseButton1Click:Connect(function()
                        popOpen=not popOpen
                        if popOpen then
                            local ap=prev.AbsolutePosition; local rp=WindowRoot.AbsolutePosition
                            pop.Position=UDim2.fromOffset(ap.X-rp.X-80, ap.Y-rp.Y-130)
                            pop.Visible=true; refresh3()
                        else pop.Visible=false end
                    end)
                    Track(UserInputService.InputBegan:Connect(function(i)
                        if popOpen and i.UserInputType==Enum.UserInputType.MouseButton1 then
                            local m=i.Position; local pp=pop.AbsolutePosition; local ps=pop.AbsoluteSize
                            local pv2=prev.AbsolutePosition; local pvs=prev.AbsoluteSize
                            local inPop=m.X>=pp.X and m.X<=pp.X+ps.X and m.Y>=pp.Y and m.Y<=pp.Y+ps.Y
                            local inPrev=m.X>=pv2.X and m.X<=pv2.X+pvs.X and m.Y>=pv2.Y and m.Y<=pv2.Y+pvs.Y
                            if not inPop and not inPrev then popOpen=false; pop.Visible=false end
                        end
                    end))
                    flagSet(o.Flag, Color3.fromHSV(h2,s2,v2))
                    return obj3
                end

                -- AddChips — horizontal pill-toggle row (multi-select supported)
                -- o = { Name="label", Items={"a","b","c"}, Default="a" or {"a","b"},
                --        Multi=bool, Flag="flag_name", Callback=function(selected) end }
                function G:AddChips(o)
                    local multi = o.Multi == true
                    local items  = o.Items or {}
                    -- normalise default: always a set {value=true}
                    local selSet = {}
                    if multi then
                        local defs = type(o.Default)=="table" and o.Default or {o.Default}
                        for _, v in ipairs(defs) do selSet[v] = true end
                    else
                        selSet[o.Default or items[1]] = true
                    end

                    -- label row
                    local labelRow = row(16)
                    New("TextLabel", {
                        Text = o.Name, Font = F.Regular, TextSize = 11,
                        TextColor3 = T.TextSecondary, BackgroundTransparency = 1,
                        Size = UDim2.fromScale(1,1),
                        TextXAlignment = Enum.TextXAlignment.Left, Parent = labelRow,
                    })

                    -- chip row (wrapping)
                    local chipRow = row(30)
                    chipRow.Size = UDim2.new(1, 0, 0, 30)  -- auto-height via layout
                    chipRow.AutomaticSize = Enum.AutomaticSize.Y
                    New("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 4),
                        Wraps = true,
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Parent = chipRow,
                    })
                    New("UIPadding", {PaddingBottom=UDim.new(0,4), Parent=chipRow})

                    local chipBtns = {}
                    local obj4 = {}

                    local function refreshChip(item, btn)
                        local active = selSet[item] == true
                        Tween(btn, 0.1, {
                            BackgroundColor3 = active and T.Accent or T.InputBackground,
                        })
                        btn.TextColor3 = active and T.WindowBackground or T.TextSecondary
                        -- stroke colour via UIStroke
                        local s = btn:FindFirstChildOfClass("UIStroke")
                        if s then s.Color = active and T.Accent or T.Divider end
                    end

                    local function currentValue()
                        if multi then
                            local r2 = {}
                            for _, it in ipairs(items) do if selSet[it] then r2[#r2+1]=it end end
                            return r2
                        else
                            for _, it in ipairs(items) do if selSet[it] then return it end end
                            return items[1]
                        end
                    end

                    for idx, item in ipairs(items) do
                        local btn = New("TextButton", {
                            Text = "  "..tostring(item).."  ",
                            Font = F.Medium, TextSize = 11,
                            TextColor3 = selSet[item] and T.WindowBackground or T.TextSecondary,
                            BackgroundColor3 = selSet[item] and T.Accent or T.InputBackground,
                            AutoButtonColor = false,
                            Size = UDim2.fromOffset(0, 22),
                            AutomaticSize = Enum.AutomaticSize.X,
                            LayoutOrder = idx, Parent = chipRow,
                        }, {Corner(11), Stroke(selSet[item] and T.Accent or T.Divider, 0, 1)})
                        chipBtns[item] = btn

                        btn.MouseButton1Click:Connect(function()
                            if multi then
                                selSet[item] = not selSet[item]
                            else
                                selSet = {}; selSet[item] = true
                            end
                            for it2, b2 in pairs(chipBtns) do refreshChip(it2, b2) end
                            local val = currentValue()
                            flagSet(o.Flag, multi and table.concat(val, ",") or val)
                            InvokeCallback(o.Name, o.Callback, val)
                        end)
                        btn.MouseEnter:Connect(function()
                            if not selSet[item] then Tween(btn,0.08,{BackgroundColor3=T.HoverSurface}) end
                        end)
                        btn.MouseLeave:Connect(function()
                            if not selSet[item] then Tween(btn,0.08,{BackgroundColor3=T.InputBackground}) end
                        end)
                    end

                    function obj4:Set(v)
                        selSet = {}
                        if multi then
                            local vals = type(v)=="table" and v or {v}
                            for _, it in ipairs(vals) do selSet[it] = true end
                        else
                            selSet[v] = true
                        end
                        for it2, b2 in pairs(chipBtns) do refreshChip(it2, b2) end
                        local val = currentValue()
                        flagSet(o.Flag, multi and table.concat(type(val)=="table" and val or {val}, ",") or val)
                        InvokeCallback(o.Name,o.Callback,val)
                    end
                    function obj4:Get() return currentValue() end

                    -- set initial flag
                    local initVal = currentValue()
                    flagSet(o.Flag, multi and table.concat(type(initVal)=="table" and initVal or {initVal}, ",") or initVal)
                    return obj4
                end
                G.AddChipBar = G.AddChips  -- alias

                -- AddPriorityList (ordered, enabled skill list)
                function G:AddPriorityList(o)
                    assert(type(o) == "table", "AddPriorityList expects an options table")
                    local sourceItems = type(o.Items) == "table" and o.Items or {}
                    local items = {}
                    local rowById = {}
                    local dragState = nil
                    local settleTween = nil
                    local itemCount = 0
                    local widget = {}
                    local container = New("Frame", {
                        Name = "PriorityList_" .. tostring(o.Name or "Items"),
                        Size = UDim2.new(1,0,0,0),
                        BackgroundTransparency = 1,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Parent = bodyList,
                    }, {ListLayout(4)})
                    local title = New("TextLabel", {
                        Name = "PriorityListTitle",
                        Text = tostring(o.Name or "Priority"),
                        Font = F.SemiBold,
                        TextSize = 11,
                        TextColor3 = T.TextPrimary,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1,0,0,18),
                        LayoutOrder = 1,
                        Parent = container,
                    })
                    local list = New("Frame", {
                        Name = "PriorityRows",
                        Size = UDim2.new(1,0,0,0),
                        BackgroundTransparency = 1,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = 2,
                        Parent = container,
                    }, {ListLayout(4)})
                    local dropLine = New("Frame", {
                        Name = "PriorityDropIndicator",
                        Size = UDim2.new(1,-8,0,2),
                        BackgroundColor3 = T.AccentBright,
                        BorderSizePixel = 0,
                        Visible = false,
                        ZIndex = 101,
                        Parent = OverlayLayer,
                    }, {Corner(2)})
                    local ghost = New("TextLabel", {
                        Name = "PriorityDragGhost",
                        Size = UDim2.fromOffset(190,24),
                        BackgroundColor3 = T.CardHeader,
                        BackgroundTransparency = 0.08,
                        BorderSizePixel = 0,
                        Text = "",
                        TextColor3 = T.TextPrimary,
                        TextSize = 11,
                        Font = F.Medium,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Visible = false,
                        ZIndex = 101,
                        Parent = OverlayLayer,
                    }, {Corner(4), Stroke(T.Accent,0,1)})
                    local function snapshot()
                        local result = {}
                        for index, item in ipairs(items) do
                            result[index] = {id=item.Id, enabled=item.Enabled}
                        end
                        return result
                    end
                    local function writeFlag(notify)
                        local value = snapshot()
                        if o.Flag then Library.Flags[o.Flag] = value end
                        if notify and type(o.Callback) == "function" then
                            task.spawn(function()
                                local ok, err = pcall(o.Callback, value)
                                if not ok then warn("[YenzUI] AddPriorityList callback failed: " .. tostring(err)) end
                            end)
                        end
                    end
                    local function disconnectRow(rowData)
                        for _, conn in ipairs(rowData.Connections) do
                            pcall(function() conn:Disconnect() end)
                            for index = #_allConnections, 1, -1 do
                                if _allConnections[index] == conn then
                                    table.remove(_allConnections,index)
                                    break
                                end
                            end
                        end
                        rowData.Connections = {}
                    end
                    local function connectRow(rowData, signal, callback)
                        local conn = Track(signal:Connect(callback))
                        rowData.Connections[#rowData.Connections+1] = conn
                    end
                    local function findDropIndex(screenY)
                        for index, item in ipairs(items) do
                            local rowData = rowById[item.Id]
                            if rowData and screenY < rowData.Frame.AbsolutePosition.Y + rowData.Frame.AbsoluteSize.Y * 0.5 then
                                return index
                            end
                        end
                        return #items + 1
                    end
                    local function setDragPosition(screenX, screenY)
                        if not dragState then return end
                        local rootPos = WindowRoot.AbsolutePosition
                        ghost.Position = UDim2.fromOffset(screenX-rootPos.X+8, screenY-rootPos.Y+10)
                        local index = findDropIndex(screenY)
                        local targetY
                        if index <= #items then
                            local target = rowById[items[index].Id]
                            targetY = target and target.Frame.AbsolutePosition.Y or list.AbsolutePosition.Y
                        else
                            targetY = list.AbsolutePosition.Y + list.AbsoluteSize.Y
                        end
                        dropLine.Position = UDim2.fromOffset(list.AbsolutePosition.X-rootPos.X+4, targetY-rootPos.Y-1)
                    end
                    local function finishDrag(screenY)
                        if not dragState then return end
                        local oldIndex = dragState.Index
                        local moved = table.remove(items, oldIndex)
                        local newIndex = findDropIndex(screenY)
                        if newIndex > oldIndex then newIndex -= 1 end
                        newIndex = math.clamp(newIndex,1,#items+1)
                        table.insert(items,newIndex,moved)
                        for index, item in ipairs(items) do rowById[item.Id].Frame.LayoutOrder = index end
                        dropLine.Visible = false
                        local targetRow = rowById[moved.Id]
                        if settleTween then pcall(function() settleTween:Cancel() end) end
                        if targetRow then
                            local rootPos = WindowRoot.AbsolutePosition
                            settleTween = Tween(ghost,0.13,{
                                Position=UDim2.fromOffset(targetRow.Frame.AbsolutePosition.X-rootPos.X,targetRow.Frame.AbsolutePosition.Y-rootPos.Y),
                                BackgroundTransparency=1,
                                TextTransparency=1,
                            })
                            if settleTween then
                                local settlingTween=settleTween
                                local completedConn
                                local cancelHandle={Disconnect=function() pcall(function() settlingTween:Cancel() end) end}
                                Track(cancelHandle)
                                completedConn=settlingTween.Completed:Connect(function()
                                    if settleTween==settlingTween then
                                        ghost.Visible=false
                                        ghost.BackgroundTransparency=0.08
                                        ghost.TextTransparency=0
                                        settleTween=nil
                                    end
                                    for index=#_allConnections,1,-1 do
                                        if _allConnections[index]==completedConn or _allConnections[index]==cancelHandle then
                                            table.remove(_allConnections,index)
                                        end
                                    end
                                    completedConn:Disconnect()
                                end)
                                Track(completedConn)
                            else
                                ghost.Visible=false
                            end
                        else
                            ghost.Visible=false
                        end
                        dragState = nil
                        writeFlag(true)
                    end
                    local function createRow(item, order)
                        local frame = New("Frame", {
                            Name = "PriorityItem_" .. item.Id,
                            Size = UDim2.new(1,0,0,26),
                            BackgroundColor3 = T.InputBackground,
                            BorderSizePixel = 0,
                            LayoutOrder = order,
                            Parent = list,
                        }, {Corner(4),Stroke(T.Divider,0,1)})
                        local rowData = {Frame=frame, Connections={}}
                        local handle = New("TextButton", {
                            Name="DragHandle", Text="⠿", Font=F.Regular, TextSize=14,
                            TextColor3=T.TextMuted, BackgroundTransparency=1,
                            AutoButtonColor=false, Size=UDim2.fromOffset(27,26),
                            Parent=frame,
                        })
                        local label = New("TextLabel", {
                            Name="ItemName", Text=item.Name, Font=F.Medium, TextSize=11,
                            TextColor3=T.TextSecondary, BackgroundTransparency=1,
                            Position=UDim2.fromOffset(29,0), Size=UDim2.new(1,-65,1,0),
                            TextXAlignment=Enum.TextXAlignment.Left,
                            TextTruncate=Enum.TextTruncate.AtEnd, Parent=frame,
                        })
                        local toggle = New("TextButton", {
                            Name="Enabled", Text=item.Enabled and "✓" or "", Font=F.Bold,
                            TextSize=10, TextColor3=T.WindowBackground,
                            BackgroundColor3=item.Enabled and T.Accent or T.InputBackground,
                            AutoButtonColor=false, Size=UDim2.fromOffset(12,12),
                            Position=UDim2.new(1,-22,0.5,-6), Parent=frame,
                        }, {Corner(3),Stroke(item.Enabled and T.Accent or T.Divider,0,1)})
                        connectRow(rowData,handle.InputBegan,function(input)
                            if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
                            local currentIndex,currentItem
                            for index,candidate in ipairs(items) do if candidate.Id==item.Id then currentIndex=index;currentItem=candidate;break end end
                            if not currentIndex then return end
                            if settleTween then
                                local previousTween=settleTween
                                settleTween=nil
                                pcall(function() previousTween:Cancel() end)
                            end
                            dragState={Id=item.Id,Index=currentIndex,Input=input,InputType=input.UserInputType}
                            ghost.Text="  ⠿  "..currentItem.Name
                            ghost.BackgroundTransparency=0.08
                            ghost.TextTransparency=0
                            ghost.Visible=true
                            dropLine.Visible=true
                            setDragPosition(input.Position.X,input.Position.Y)
                        end)
                        connectRow(rowData,toggle.Activated,function()
                            local current
                            for _,candidate in ipairs(items) do if candidate.Id==item.Id then current=candidate;break end end
                            if not current then return end
                            current.Enabled=not current.Enabled
                            toggle.Text=current.Enabled and "✓" or ""
                            toggle.BackgroundColor3=current.Enabled and T.Accent or T.InputBackground
                            local stroke=toggle:FindFirstChildOfClass("UIStroke")
                            if stroke then stroke.Color=current.Enabled and T.Accent or T.Divider end
                            writeFlag(true)
                        end)
                        connectRow(rowData,frame.MouseEnter,function() if not dragState then Tween(frame,0.12,{BackgroundColor3=T.HoverSurface}) end end)
                        connectRow(rowData,frame.MouseLeave,function() if not dragState then Tween(frame,0.12,{BackgroundColor3=T.InputBackground}) end end)
                        return rowData
                    end
                    local function normalize(inputItems)
                        local normalized, seen = {}, {}
                        for _, entry in ipairs(inputItems) do
                            if type(entry)=="table" and entry.Id~=nil then
                                local id=tostring(entry.Id)
                                if id~="" and not seen[id] then
                                    seen[id]=true
                                    normalized[#normalized+1]={Id=id,Name=tostring(entry.Name or id),Enabled=entry.Enabled==true}
                                end
                            end
                        end
                        return normalized
                    end
                    local function renderRows()
                        local wanted={}
                        for index,item in ipairs(items) do
                            wanted[item.Id]=true
                            local rowData=rowById[item.Id]
                            if not rowData then
                                rowData=createRow(item,index)
                                rowById[item.Id]=rowData
                            else
                                rowData.Frame.LayoutOrder=index
                                rowData.Frame.Name="PriorityItem_"..item.Id
                                rowData.Frame:FindFirstChild("ItemName").Text=item.Name
                                local toggle=rowData.Frame:FindFirstChild("Enabled")
                                toggle.Text=item.Enabled and "✓" or ""
                                toggle.BackgroundColor3=item.Enabled and T.Accent or T.InputBackground
                                local stroke=toggle:FindFirstChildOfClass("UIStroke")
                                if stroke then stroke.Color=item.Enabled and T.Accent or T.Divider end
                            end
                        end
                        for id,rowData in pairs(rowById) do
                            if not wanted[id] then
                                if dragState and dragState.Id==id then dragState=nil;ghost.Visible=false;dropLine.Visible=false end
                                disconnectRow(rowData)
                                rowData.Frame:Destroy()
                                rowById[id]=nil
                            end
                        end
                    end
                    Track(UserInputService.InputChanged:Connect(function(input)
                        if dragState and (input.UserInputType==Enum.UserInputType.MouseMovement or (dragState.InputType==Enum.UserInputType.Touch and input==dragState.Input)) then
                            setDragPosition(input.Position.X,input.Position.Y)
                        end
                    end))
                    -- One widget-owned release handler serves every current and future row.
                    Track(UserInputService.InputEnded:Connect(function(input)
                        if dragState and ((dragState.InputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1) or (dragState.InputType==Enum.UserInputType.Touch and input==dragState.Input)) then
                            finishDrag(input.Position.Y)
                        end
                    end))
                    function widget:SetItems(newItems)
                        assert(type(newItems)=="table","SetItems expects an array")
                        if dragState then dragState=nil;ghost.Visible=false;dropLine.Visible=false end
                        items=normalize(newItems)
                        itemCount=#items
                        renderRows()
                        writeFlag(false)
                    end
                    function widget:GetItems()
                        local result={}
                        for index,item in ipairs(items) do result[index]={Id=item.Id,Name=item.Name,Enabled=item.Enabled} end
                        return result
                    end
                    widget:SetItems(sourceItems)
                    writeFlag(false)
                    return widget
                end

                G._bodyList = bodyList
                return G
            end -- AddGroup

            return Sub
        end -- AddSubtab

        Window.Tabs[#Window.Tabs] = Tab
        return Tab
    end -- AddTab

    -- ── Window:Destroy ────────────────────────────────────────────────────────
    function Window:Destroy()
        alive = false
        avatarVersion += 1
        if Window._stopCursor then Window._stopCursor() end
        DisconnectAll()
        if RestoreBadge then RestoreBadge:Destroy(); RestoreBadge=nil end
        if blurEffect then blurEffect:Destroy(); blurEffect=nil end
        gui:Destroy()
    end

    -- Select first tab automatically
    task.defer(function()
        if Window.Tabs[1] then Window.Tabs[1]:Select() end
    end)
    task.delay(2, function()
        if previousGui and previousGui.Parent then previousGui:Destroy() end
    end)

    return Window
end -- CreateWindow

-- ==============================================================================
--  SECTION 6 — PENDING CONTROLS UI PRESENTER
--  (shows disabled toggle + "Planned" badge instead of a live checkbox)
-- ==============================================================================
-- pendingSwitch is defined later in the runtime section (it needs `controls` table)

return Library
