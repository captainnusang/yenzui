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

-- Font fallback — Gotham family (built-in Roblox, no download needed)
local F = {
    Regular  = Enum.Font.Gotham,
    Medium   = Enum.Font.GothamMedium,
    SemiBold = Enum.Font.GothamSemibold,
    Bold     = Enum.Font.GothamBlack,
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
local function DisconnectAll()
    for _, c in ipairs(_allConnections) do pcall(function() c:Disconnect() end) end
    table.clear(_allConnections)
end

-- ==============================================================================
--  SECTION 4 — LIBRARY TABLE
-- ==============================================================================
local Library = { Flags = {}, Icons = Icons, ToggleKey = Enum.KeyCode.Insert }
Library.__index = Library

-- ==============================================================================
--  SECTION 5 — NEW LIBRARY:CREATEWINDOW  (Spotify-Inspired Shell)
-- ==============================================================================
function Library:CreateWindow(cfg)
    cfg = cfg or {}

    -- ── ScreenGui ────────────────────────────────────────────────────────────
    local gui = New("ScreenGui", {
        Name = "YenzUI",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        IgnoreGuiInset = true,
        Parent = GetParentGui(),
    })

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

    -- ── Sidebar (152px) ───────────────────────────────────────────────────────
    local Sidebar = New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 152, 1, 0),
        BackgroundColor3 = T.SidebarBackground,
        BorderSizePixel = 0,
        Parent = WindowRoot,
    }, {Corner(10)})
    -- Clip right corners of sidebar
    New("Frame", {Size=UDim2.fromOffset(10,540), Position=UDim2.fromOffset(142,0), BackgroundColor3=T.SidebarBackground, BorderSizePixel=0, Parent=Sidebar})

    -- Brand header
    local BrandHeader = New("Frame", {
        Name = "BrandHeader",
        Size = UDim2.new(1,0,0,52),
        BackgroundTransparency = 1,
        Parent = Sidebar,
    })
    local brandWordmark = New("TextLabel", {
        Text = "Yenz",
        Font = F.Bold,
        TextSize = 22,
        TextColor3 = T.Accent,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(130,28),
        Position = UDim2.fromOffset(14, 10),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = BrandHeader,
    })
    New("TextLabel", {
        Text = "Pixel Lineage",
        Font = F.Regular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(130,14),
        Position = UDim2.fromOffset(14, 34),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = BrandHeader,
    })

    -- Divider under brand
    New("Frame", {Size=UDim2.new(1,-24,0,1), Position=UDim2.fromOffset(12,52), BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=Sidebar})

    -- Navigation scroll area
    local NavScroll = New("ScrollingFrame", {
        Name = "NavigationScroll",
        Size = UDim2.new(1,0,1,-108),
        Position = UDim2.fromOffset(0,54),
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

    -- Profile footer (bottom of sidebar)
    local ProfileFooter = New("Frame", {
        Name = "UserProfileFooter",
        Size = UDim2.new(1,0,0,52),
        Position = UDim2.new(0,0,1,-54),
        BackgroundColor3 = T.SidebarBackground,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })
    New("Frame", {Size=UDim2.new(1,-24,0,1), Position=UDim2.fromOffset(12,0), BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=ProfileFooter})
    local profileAv = New("ImageLabel", {
        Size = UDim2.fromOffset(32,32),
        Position = UDim2.fromOffset(10,10),
        BackgroundColor3 = T.CardBackground,
        Image = cfg.Avatar or Icons.avatar,
        Parent = ProfileFooter,
    }, {Corner(100)})
    if (cfg.Avatar or Icons.avatar) == "rbxassetid://0" then
        pcall(function()
            profileAv.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        end)
    end
    New("TextLabel", {
        Text = LocalPlayer.Name,
        Font = F.Medium,
        TextSize = 12,
        TextColor3 = T.TextPrimary,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(96,16),
        Position = UDim2.fromOffset(48, 12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = ProfileFooter,
    })
    New("TextLabel", {
        Text = "Pixel Lineage",
        Font = F.Regular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(96,14),
        Position = UDim2.fromOffset(48, 28),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ProfileFooter,
    })

    -- ── Main content area (608px) ─────────────────────────────────────────────
    local MainArea = New("Frame", {
        Name = "MainArea",
        Size = UDim2.new(1,-152,1,0),
        Position = UDim2.fromOffset(152,0),
        BackgroundColor3 = T.ContentBackground,
        BorderSizePixel = 0,
        Parent = WindowRoot,
    }, {Corner(10)})
    -- Left clip (square left edge)
    New("Frame", {Size=UDim2.fromOffset(10,540), Position=UDim2.fromOffset(0,0), BackgroundColor3=T.ContentBackground, BorderSizePixel=0, Parent=MainArea})

    -- Topbar (42px)
    local Topbar = New("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1,0,0,42),
        BackgroundColor3 = T.ContentBackground,
        BorderSizePixel = 0,
        Parent = MainArea,
    })
    New("Frame", {Size=UDim2.new(1,0,0,1), Position=UDim2.fromOffset(0,42), BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=MainArea})

    -- Back chevron (navigation history)
    local backBtn = New("TextButton", {
        Text = "‹",
        Font = F.Bold,
        TextSize = 18,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28,42),
        Position = UDim2.fromOffset(8,0),
        AutoButtonColor = false,
        Parent = Topbar,
    })

    -- Page name label
    local topbarPageLabel = New("TextLabel", {
        Text = "Farm",
        Font = F.SemiBold,
        TextSize = 14,
        TextColor3 = T.TextPrimary,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(200,42),
        Position = UDim2.fromOffset(40,0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Topbar,
    })

    -- Config selector (compact dropdown area in topbar)
    local cfgSelectorFrame = New("Frame", {
        Size = UDim2.fromOffset(110,24),
        Position = UDim2.new(1,-200,0.5,-12),
        BackgroundColor3 = T.InputBackground,
        BorderSizePixel = 0,
        Parent = Topbar,
    }, {Corner(5), Stroke(T.Divider,0,1)})
    local cfgSelectorLabel = New("TextLabel", {
        Text = "default",
        Font = F.Regular,
        TextSize = 11,
        TextColor3 = T.TextSecondary,
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-18,1,0),
        Position = UDim2.fromOffset(6,0),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = cfgSelectorFrame,
    })
    New("TextLabel", {Text="▾", Font=F.Regular, TextSize=10, TextColor3=T.TextMuted,
        BackgroundTransparency=1, Size=UDim2.fromOffset(16,24), Position=UDim2.new(1,-16,0,0),
        TextXAlignment=Enum.TextXAlignment.Center, Parent=cfgSelectorFrame})

    -- Minimize button
    local minimizeBtn = New("TextButton", {
        Text = "−",
        Font = F.Bold,
        TextSize = 16,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28,42),
        Position = UDim2.new(1,-56,0,0),
        AutoButtonColor = false,
        Parent = Topbar,
    })
    -- Close button
    local closeBtn = New("TextButton", {
        Text = "×",
        Font = F.Bold,
        TextSize = 18,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(28,42),
        Position = UDim2.new(1,-28,0,0),
        AutoButtonColor = false,
        Parent = Topbar,
    })
    minimizeBtn.MouseEnter:Connect(function() minimizeBtn.TextColor3 = T.TextPrimary end)
    minimizeBtn.MouseLeave:Connect(function() minimizeBtn.TextColor3 = T.TextMuted end)
    closeBtn.MouseEnter:Connect(function() closeBtn.TextColor3 = T.Danger end)
    closeBtn.MouseLeave:Connect(function() closeBtn.TextColor3 = T.TextMuted end)

    -- Page viewport (between topbar and footer)
    local PageViewport = New("Frame", {
        Name = "PageViewport",
        Size = UDim2.new(1,0,1,-68),
        Position = UDim2.fromOffset(0,43),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = MainArea,
    })
    local PageCanvas = New("CanvasGroup", {
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
        Parent = PageViewport,
    })

    -- Subtab bar (lives just below topbar, inside PageViewport top padding)
    local SubtabBar = New("Frame", {
        Name = "SubtabBar",
        Size = UDim2.new(1,0,0,32),
        BackgroundTransparency = 1,
        Parent = PageCanvas,
        ZIndex = 10,
    })
    local subBarList = New("Frame", {
        Size = UDim2.new(1,-32,1,0),
        Position = UDim2.fromOffset(16,0),
        BackgroundTransparency = 1,
        Parent = SubtabBar,
    }, {ListLayout(6, Enum.FillDirection.Horizontal)})

    -- Page body (scrollable content area below subtab bar)
    local PageBody = New("Frame", {
        Name = "PageBody",
        Size = UDim2.new(1,0,1,-32),
        Position = UDim2.fromOffset(0,32),
        BackgroundTransparency = 1,
        Parent = PageCanvas,
    })

    -- Status footer (26px)
    local StatusFooter = New("Frame", {
        Name = "StatusFooter",
        Size = UDim2.new(1,0,0,26),
        Position = UDim2.new(0,0,1,-26),
        BackgroundColor3 = T.ContentBackground,
        BorderSizePixel = 0,
        Parent = MainArea,
    })
    New("Frame", {Size=UDim2.new(1,0,0,1), BackgroundColor3=T.Divider, BorderSizePixel=0, Parent=StatusFooter})
    local footerConfigLabel = New("TextLabel", {
        Text = "Config: default",
        Font = F.Regular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(200,26),
        Position = UDim2.fromOffset(16,0),
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = StatusFooter,
    })
    New("TextLabel", {
        Text = "Insert · Show / Hide",
        Font = F.Regular,
        TextSize = 10,
        TextColor3 = T.TextMuted,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(160,26),
        Position = UDim2.new(1,-176,0,0),
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = StatusFooter,
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

    local function animatePage()
        PageCanvas.GroupTransparency = 1
        Tween(PageCanvas, 0.12, {GroupTransparency = 0})
    end
    Window.Animate = animatePage

    -- ── Toast notification ────────────────────────────────────────────────────
    function Window:Toast(text, duration)
        duration = duration or 2.5
        local t = New("Frame", {
            Size = UDim2.fromOffset(220,32),
            Position = UDim2.new(0.5,-110,1,-48),
            BackgroundColor3 = T.CardHeader,
            BorderSizePixel = 0,
            BackgroundTransparency = 0,
            Parent = ToastHost,
        }, {Corner(6), Stroke(T.Divider,0,1)})
        New("TextLabel", {Text=text, Font=F.Regular, TextSize=11, TextColor3=T.TextPrimary,
            BackgroundTransparency=1, Size=UDim2.fromScale(1,1), TextXAlignment=Enum.TextXAlignment.Center, Parent=t})
        Tween(t, 0.15, {BackgroundTransparency=0})
        task.delay(duration, function()
            Tween(t, 0.25, {BackgroundTransparency=1})
            task.delay(0.3, function() if t and t.Parent then t:Destroy() end end)
        end)
    end

    -- ── Close confirmation modal ──────────────────────────────────────────────
    function Window:ShowCloseConfirm(onConfirm)
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
        New("TextLabel", {Text="Unload Yenz?", Font=F.SemiBold, TextSize=14, TextColor3=T.TextPrimary,
            BackgroundTransparency=1, Size=UDim2.fromOffset(248,20), Position=UDim2.fromOffset(16,16),
            TextXAlignment=Enum.TextXAlignment.Left, Parent=box})
        New("TextLabel", {Text="This stops automation and removes the UI.", Font=F.Regular, TextSize=11, TextColor3=T.TextSecondary,
            BackgroundTransparency=1, Size=UDim2.fromOffset(248,32), Position=UDim2.fromOffset(16,38),
            TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true, Parent=box})
        local cancelBtn = New("TextButton", {
            Text="Cancel", Font=F.Medium, TextSize=12, TextColor3=T.TextSecondary,
            BackgroundColor3=T.InputBackground, AutoButtonColor=false,
            Size=UDim2.fromOffset(110,28), Position=UDim2.fromOffset(16,82), Parent=box,
        }, {Corner(5)})
        local confirmBtn = New("TextButton", {
            Text="Unload", Font=F.SemiBold, TextSize=12, TextColor3=Color3.new(0.1,0.1,0.1),
            BackgroundColor3=T.Danger, AutoButtonColor=false,
            Size=UDim2.fromOffset(110,28), Position=UDim2.fromOffset(154,82), Parent=box,
        }, {Corner(5)})
        local function dismiss() bg:Destroy(); box:Destroy() end
        cancelBtn.MouseButton1Click:Connect(dismiss)
        confirmBtn.MouseButton1Click:Connect(function() dismiss(); if onConfirm then onConfirm() end end)
    end

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
                local nx = math.clamp(startPos.X.Offset + d.X, -WindowRoot.AbsoluteSize.X + 60, vp.X - 60)
                local ny = math.clamp(startPos.Y.Offset + d.Y, 0, vp.Y - 40)
                WindowRoot.Position = UDim2.fromOffset(nx, ny)
            end
        end))
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
        end)
    end

    minimizeBtn.MouseButton1Click:Connect(function()
        Window._minimized = true; Window._uiVisible = false
        WindowRoot.Visible = false
        buildRestoreBadge()
    end)

    -- ── Visibility toggle (hotkey) ────────────────────────────────────────────
    Track(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Library.ToggleKey then
            if Window._minimized then
                Window._minimized = false; Window._uiVisible = true
                WindowRoot.Visible = true
                if RestoreBadge then RestoreBadge:Destroy(); RestoreBadge = nil end
            else
                Window._uiVisible = not Window._uiVisible
                WindowRoot.Visible = Window._uiVisible
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
    function Window:AddTab(name, icon)
        local Tab = {Subtabs={}, Current=nil}
        local lo = navOrder()

        -- Nav row
        local navRow = New("TextButton", {
            Name = name,
            Size = UDim2.new(1,0,0,28),
            BackgroundColor3 = T.SidebarBackground,
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = lo,
            Parent = NavScroll,
        }, {Corner(7)})
        -- Left indicator bar
        local indicator = New("Frame", {
            Size = UDim2.fromOffset(3,16),
            Position = UDim2.new(0,0,0.5,-8),
            BackgroundColor3 = T.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = navRow,
        }, {Corner(2)})
        -- Icon
        local navIcon = New("ImageLabel", {
            Size = UDim2.fromOffset(16,16),
            Position = UDim2.fromOffset(10,6),
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
            TextSize = 12,
            TextColor3 = T.TextSecondary,
            BackgroundTransparency = 1,
            Size = UDim2.new(1,-34,1,0),
            Position = UDim2.fromOffset(30,0),
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = navRow,
        })

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

        Tab.Button = navRow; Tab.TabPage = tabPage; Tab.SubBarHolder = tabSubBar
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
            navLabel.TextColor3 = T.TextPrimary
            topbarPageLabel.Text = name
            tabPage.Visible = true
            tabSubBar.Visible = true
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

            -- Subtab pill button
            local pill = New("TextButton", {
                Text = sname,
                Font = F.Medium,
                TextSize = 12,
                TextColor3 = T.TextSecondary,
                BackgroundColor3 = T.InputBackground,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Size = UDim2.fromOffset(0,26),
                AutomaticSize = Enum.AutomaticSize.X,
                LayoutOrder = #Tab.Subtabs+1,
                Parent = tabSubBar,
            }, {Corner(100), Padding(0,10,0,10)})

            -- Sub page inside the tab page
            local page = New("Frame", {
                Name = "SubPage_"..sname,
                Size = UDim2.new(1,0,1,-32),
                Position = UDim2.fromOffset(0,36),
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
                }, {ListLayout(10), Padding(8,8,8,16)})
            end

            -- Two columns: left at x=0, right at x=294 (each 282px, gap=12)
            Sub.Left  = column(0, 282)
            Sub.Right = column(294, 282)
            Sub.Button = pill
            Sub.Page = page
            Sub._tab = Tab
            Tab.Subtabs[#Tab.Subtabs+1] = Sub

            function Sub:Select()
                for _, s in ipairs(Tab.Subtabs) do
                    s.Page.Visible = false
                    Tween(s.Button, 0.1, {BackgroundColor3=T.InputBackground, BackgroundTransparency=1})
                    s.Button.TextColor3 = T.TextSecondary
                end
                Tab.Current = Sub
                page.Visible = true
                Tween(pill, 0.1, {BackgroundColor3=T.Accent, BackgroundTransparency=0})
                pill.TextColor3 = Color3.new(0,0,0)
                animatePage()
            end
            pill.MouseButton1Click:Connect(function() Sub:Select() end)

            -- ── AddGroup: collapsible card ─────────────────────────────────────
            function Sub:AddGroup(gname, gicon, side, _height)
                local col = (side == "Right") and Sub.Right or Sub.Left
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
                        Size = UDim2.fromOffset(14,14),
                        Position = UDim2.fromOffset(10,8),
                        BackgroundTransparency = 1,
                        Image = gicon,
                        ImageColor3 = T.TextSecondary,
                        ScaleType = Enum.ScaleType.Fit,
                        Parent = header,
                    })
                end
                local iconOff = gicon and 28 or 12
                New("TextLabel", {
                    Text = gname,
                    Font = F.SemiBold,
                    TextSize = 12,
                    TextColor3 = T.TextPrimary,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1,-iconOff-24,0,30),
                    Position = UDim2.fromOffset(iconOff,0),
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = header,
                })
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
                local function flagSet(f, v) if f then Library.Flags[f] = v end end

                -- AddCheckbox (toggle)
                function G:AddCheckbox(o)
                    o = type(o) == "string" and {Name=o} or o
                    local state = o.Default
                    if state == nil then state = false end
                    local r = row(28)
                    local lbl = New("TextLabel", {
                        Text = o.Name,
                        Font = F.Regular,
                        TextSize = 12,
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
                        Size = UDim2.fromOffset(32,18),
                        Position = UDim2.new(1,-40,0.5,-9),
                        BackgroundColor3 = state and T.Accent or T.ToggleOff,
                        AutoButtonColor = false,
                        Text = "",
                        Parent = r,
                    }, {Corner(100)})
                    local thumb = New("Frame", {
                        Size = UDim2.fromOffset(14,14),
                        Position = UDim2.new(0, state and 16 or 2, 0.5, -7),
                        BackgroundColor3 = T.ToggleThumb,
                        BorderSizePixel = 0,
                        Parent = track,
                    }, {Corner(100)})
                    local obj = {}
                    function obj:Set(v)
                        state = v
                        Tween(track, 0.12, {BackgroundColor3 = v and T.Accent or T.ToggleOff})
                        Tween(thumb, 0.12, {Position = UDim2.new(0, v and 16 or 2, 0.5, -7)})
                        lbl.TextColor3 = v and T.TextPrimary or T.TextSecondary
                        flagSet(o.Flag, v)
                        if o.Callback then task.spawn(o.Callback, v) end
                    end
                    function obj:Get() return state end
                    track.MouseButton1Click:Connect(function() obj:Set(not state) end)
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
                        TextSize = 12,
                        TextColor3 = T.TextSecondary,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1,-50,0,18),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = r,
                    })
                    local valLabel = New("TextLabel", {
                        Text = tostring(val)..suffix,
                        Font = F.Medium,
                        TextSize = 12,
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
                    function obj:Set(v, instant)
                        v = math.clamp(v, min, max)
                        if not o.Decimals then v = math.floor(v+0.5)
                        else v = math.floor(v*10^o.Decimals+.5)/10^o.Decimals end
                        val = v
                        local p = (v-min)/(max-min)
                        local t2 = instant and 0 or 0.1
                        Tween(fill, t2, {Size=UDim2.new(p,0,1,0)})
                        Tween(grab, t2, {Position=UDim2.new(p,0,0.5,0)})
                        valLabel.Text = tostring(v)..suffix
                        flagSet(o.Flag, v)
                        if o.Callback then task.spawn(o.Callback, v) end
                    end
                    function obj:Get() return val end
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
                        TextSize = 12,
                        TextColor3 = T.TextSecondary,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0.5,-4,1,0),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = r,
                    })
                    local box = New("TextButton", {
                        Size = UDim2.new(0.5,-4,0,24),
                        Position = UDim2.new(0.5,4,0.5,-12),
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
                    New("TextLabel", {Text="▾",Font=F.Regular,TextSize=10,TextColor3=T.TextMuted,
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
                        if o.Callback then task.spawn(o.Callback, v) end
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
                        Text=o.Name, Font=F.Regular, TextSize=12, TextColor3=T.TextSecondary,
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
                        if o.Callback then task.spawn(o.Callback, tb.Text, enter) end
                    end)
                    flagSet(o.Flag, o.Default or "")
                    return {Set=function(_,v) tb.Text=v; flagSet(o.Flag,v) end, Get=function() return tb.Text end}
                end
                G.AddInput = G.AddTextbox

                -- AddButton
                function G:AddButton(o)
                    o = type(o)=="string" and {Name=o} or o
                    local r = row(28)
                    local isPrimary = o.Primary
                    local btn = New("TextButton", {
                        Text=o.Name,
                        Font=F.SemiBold, TextSize=12,
                        TextColor3 = isPrimary and Color3.new(0,0,0) or T.TextPrimary,
                        BackgroundColor3 = isPrimary and T.Accent or T.InputBackground,
                        AutoButtonColor=false,
                        Size=UDim2.new(1,0,0,26),
                        Parent=r,
                    }, {Corner(5), Stroke(T.Divider,0,1)})
                    btn.MouseEnter:Connect(function() Tween(btn,0.08,{BackgroundColor3= isPrimary and T.AccentBright or T.HoverSurface}) end)
                    btn.MouseLeave:Connect(function() Tween(btn,0.08,{BackgroundColor3= isPrimary and T.Accent or T.InputBackground}) end)
                    btn.MouseButton1Click:Connect(function() if o.Callback then task.spawn(o.Callback) end end)
                    return btn
                end

                -- AddLabel
                function G:AddLabel(text)
                    local r = row(18)
                    New("TextLabel", {
                        Text=text, Font=F.Regular, TextSize=10, TextColor3=T.TextMuted,
                        BackgroundTransparency=1, Size=UDim2.fromScale(1,1),
                        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true,
                        Parent=r,
                    })
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
                    local bound = o.Default or Enum.KeyCode.Unknown
                    New("TextLabel", {
                        Text=o.Name, Font=F.Regular, TextSize=12, TextColor3=T.TextSecondary,
                        BackgroundTransparency=1, Size=UDim2.new(0.55,-4,1,0),
                        TextXAlignment=Enum.TextXAlignment.Left, Parent=r,
                    })
                    local kbBtn = New("TextButton", {
                        Text=tostring(bound.Name),
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
                                kbBtn.Text = i.KeyCode.Name
                                listening = false
                                conn:Disconnect()
                                if o.Callback then task.spawn(o.Callback, i.KeyCode) end
                            end
                        end))
                    end)
                    return {Get=function() return bound end, Set=function(_,k) bound=k; kbBtn.Text=tostring(k.Name) end}
                end

                -- AddColorPicker (basic — opens a simple hue/sv picker)
                function G:AddColorPicker(o)
                    local h2, s2, v2 = (o.Default or Color3.new(1,1,1)):ToHSV()
                    local r = row(28)
                    New("TextLabel", {
                        Text=o.Name, Font=F.Regular, TextSize=12, TextColor3=T.TextSecondary,
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
                        if o.Callback then task.spawn(o.Callback, c, 1) end
                    end
                    function obj3:Set(c,_) h2,s2,v2=c:ToHSV(); refresh3() end
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
                            if o.Callback then task.spawn(o.Callback, val) end
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
                    end
                    function obj4:Get() return currentValue() end

                    -- set initial flag
                    local initVal = currentValue()
                    flagSet(o.Flag, multi and table.concat(type(initVal)=="table" and initVal or {initVal}, ",") or initVal)
                    return obj4
                end
                G.AddChipBar = G.AddChips  -- alias

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
        DisconnectAll()
        if RestoreBadge then RestoreBadge:Destroy(); RestoreBadge=nil end
        gui:Destroy()
    end

    -- Select first tab automatically
    task.defer(function()
        if Window.Tabs[1] then Window.Tabs[1]:Select() end
    end)

    return Window
end -- CreateWindow

-- ==============================================================================
--  SECTION 6 — PENDING CONTROLS UI PRESENTER
--  (shows disabled toggle + "Planned" badge instead of a live checkbox)
-- ==============================================================================
-- pendingSwitch is defined later in the runtime section (it needs `controls` table)

return Library
