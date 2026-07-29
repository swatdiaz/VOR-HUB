-- VOR Hub luxury interface.
-- The UI intentionally exposes the legacy Window/Page/Section control API so
-- existing game integrations can move into modules without changing flags.

return function(context)
    local SETTINGS = assert(context.SETTINGS, "VOR UI requires SETTINGS")
    local Utilities = assert(context.Utilities, "VOR UI requires Utilities")
    local Services = Utilities.Services
    local COLORS = SETTINGS.COLORS
    local LocalPlayer = Utilities.LocalPlayer
    local BASE_WIDTH = 900
    local BASE_HEIGHT = 574
    local RAIL_COLLAPSED_WIDTH = 74
    local RAIL_EXPANDED_WIDTH = 214
    local RAIL_EXPANSION = RAIL_EXPANDED_WIDTH - RAIL_COLLAPSED_WIDTH

    local function create(className, properties, parent)
        local object = Instance.new(className)
        for property, value in pairs(properties or {}) do
            object[property] = value
        end
        object.Parent = parent
        return object
    end

    local function corner(parent, radius)
        return create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
    end

    local function stroke(parent, color, thickness, transparency)
        return create("UIStroke", {
            Color = color or COLORS.border,
            Thickness = thickness or 1,
            Transparency = transparency or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, parent)
    end

    local function padding(parent, left, right, top, bottom)
        return create("UIPadding", {
            PaddingLeft = UDim.new(0, left or 0),
            PaddingRight = UDim.new(0, right or left or 0),
            PaddingTop = UDim.new(0, top or 0),
            PaddingBottom = UDim.new(0, bottom or top or 0),
        }, parent)
    end

    local function label(parent, text, size, position, color, textSize, font)
        return create("TextLabel", {
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Size = size or UDim2.fromScale(1, 1),
            Position = position or UDim2.fromOffset(0, 0),
            TextColor3 = color or COLORS.text,
            TextSize = textSize or 13,
            Font = font or Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        }, parent)
    end

    local function tween(object, duration, properties, style, direction)
        if SETTINGS.ReducedMotion then
            for property, value in pairs(properties) do
                object[property] = value
            end
            return nil
        end
        local info = TweenInfo.new(
            duration or 0.18,
            style or Enum.EasingStyle.Quart,
            direction or Enum.EasingDirection.Out
        )
        local animation = Services.TweenService:Create(object, info, properties)
        animation:Play()
        return animation
    end

    local function safeCallback(name, callback, ...)
        if type(callback) ~= "function" then
            return true
        end
        local arguments = table.pack(...)
        local ok, err = xpcall(function()
            callback(table.unpack(arguments, 1, arguments.n))
        end, debug.traceback)
        if not ok then
            warn(string.format("[VOR Hub] %s callback failed: %s", tostring(name), tostring(err)))
        end
        return ok, err
    end

    local parent = Utilities.GetGuiParent()
    assert(parent, "VOR UI could not find a Gui parent")

    for _, container in ipairs({parent, game:GetService("CoreGui")}) do
        local old = container and container:FindFirstChild(SETTINGS.GuiName)
        if old then
            old:Destroy()
        end
    end

    local gui = create("ScreenGui", {
        Name = SETTINGS.GuiName,
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9876,
    }, parent)

    local toggleClickSound = create("Sound", {
        Name = "VORToggleClick",
        SoundId = SETTINGS.ToggleClickSoundId or "rbxasset://sounds/volume_slider.ogg",
        Volume = 0,
        Looped = false,
        PlayOnRemove = false,
    }, gui)

    local function playToggleClick(enabled)
        if not SETTINGS.InterfaceSoundsEnabled then
            return
        end
        pcall(function()
            toggleClickSound:Stop()
            toggleClickSound.TimePosition = 0
            toggleClickSound.SoundId = SETTINGS.ToggleClickSoundId or "rbxasset://sounds/volume_slider.ogg"
            toggleClickSound.Volume = math.clamp(tonumber(SETTINGS.ToggleClickVolume) or 0.24, 0, 1)
            toggleClickSound.PlaybackSpeed = math.clamp(tonumber(
                enabled and SETTINGS.ToggleOnPlaybackSpeed or SETTINGS.ToggleOffPlaybackSpeed
            ) or 1, 0.25, 3)
            toggleClickSound:Play()
        end)
    end

    local overlay = create("Frame", {
        Name = "Overlay",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 1,
    }, gui)

    local main = create("Frame", {
        Name = "LuxuryWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT),
        BackgroundColor3 = COLORS.shell,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 2,
    }, overlay)
    corner(main, 13)
    local mainStroke = stroke(main, COLORS.borderBright, 1, 0.38)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(17, 12, 27)),
            ColorSequenceKeypoint.new(0.5, COLORS.shell),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(11, 8, 18)),
        }),
        Rotation = 18,
    }, main)

    local panelBackground = create("ImageLabel", {
        Name = "PanelBackground",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = SETTINGS.PanelBackgrounds[SETTINGS.DefaultPanelBackground],
        ImageColor3 = Color3.fromRGB(184, 139, 255),
        ImageTransparency = 0.68,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 2,
    }, main)

    local scaleObject = create("UIScale", {Scale = SETTINGS.UIScale or 1}, main)

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(RAIL_COLLAPSED_WIDTH, 0),
        Size = UDim2.new(1, -RAIL_COLLAPSED_WIDTH, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 3,
    }, main)

    local topbar = create("Frame", {
        Name = "Topbar",
        Size = UDim2.new(1, 0, 0, 66),
        BackgroundColor3 = COLORS.surface,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, content)
    create("Frame", {
        Name = "TopbarDivider",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.border,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, topbar)

    local identity = label(
        topbar,
        (SETTINGS.ActiveGame and SETTINGS.ActiveGame.DisplayName or "Unsupported") .. "  •  " .. tostring(game.PlaceId),
        UDim2.new(0, 220, 0, 22),
        UDim2.fromOffset(20, 10),
        COLORS.muted,
        12,
        Enum.Font.GothamMedium
    )
    identity.Name = "ModuleIdentity"

    local title = label(
        topbar,
        "VOR HUB  /  " .. (SETTINGS.ActiveGame and SETTINGS.ActiveGame.Key or "UNSUPPORTED"),
        UDim2.new(0, 220, 0, 24),
        UDim2.fromOffset(20, 31),
        COLORS.text,
        15,
        Enum.Font.GothamBold
    )
    title.Name = "ProductTitle"

    local searchBox = create("TextBox", {
        Name = "CommandSearch",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.43, 0, 0.5, 0),
        Size = UDim2.fromOffset(210, 36),
        BackgroundColor3 = COLORS.control,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "Search commands…",
        PlaceholderColor3 = COLORS.dim,
        Text = "",
        TextColor3 = COLORS.text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 8,
    }, topbar)
    corner(searchBox, 9)
    stroke(searchBox, COLORS.border, 1, 0.35)
    padding(searchBox, 34, 12, 0, 0)
    label(searchBox, "⌕", UDim2.fromOffset(22, 36), UDim2.fromOffset(-25, 0), COLORS.accentBright, 17, Enum.Font.GothamBold)

    local function iconButton(name, text, xOffset, width)
        local button = create("TextButton", {
            Name = name,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOffset, 0.5, 0),
            Size = UDim2.fromOffset(width or 38, 36),
            BackgroundColor3 = COLORS.control,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = text,
            TextColor3 = COLORS.muted,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            ZIndex = 8,
        }, topbar)
        corner(button, 9)
        stroke(button, COLORS.border, 1, 0.45)
        return button
    end

    local minimizeButton = iconButton("Minimize", "—", -16, 34)
    local notificationButton = iconButton("Notifications", "🔔", -56, 34)
    local activityButton = iconButton("Activity", "LOG", -96, 54)
    local pauseButton = iconButton("GlobalPause", "PAUSE", -156, 52)
    local connectionChip = create("TextLabel", {
        Name = "ConnectionChip",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -214, 0.5, 0),
        Size = UDim2.fromOffset(90, 34),
        BackgroundColor3 = Color3.fromRGB(14, 29, 24),
        BorderSizePixel = 0,
        Text = "●  CONNECTED",
        TextColor3 = COLORS.success,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        ZIndex = 8,
    }, topbar)
    corner(connectionChip, 9)
    stroke(connectionChip, COLORS.success, 1, 0.68)

    local pagesHost = create("Frame", {
        Name = "Pages",
        Position = UDim2.fromOffset(0, 66),
        Size = UDim2.new(1, 0, 1, -94),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
    }, content)

    local statusFooter = create("Frame", {
        Name = "ContextStatus",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = COLORS.surface,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, content)
    local statusText = label(
        statusFooter,
        "Ready  •  No automation running",
        UDim2.new(1, -150, 1, 0),
        UDim2.fromOffset(16, 0),
        COLORS.dim,
        10,
        Enum.Font.GothamMedium
    )
    local buildText = label(
        statusFooter,
        "v" .. SETTINGS.Version,
        UDim2.fromOffset(120, 28),
        UDim2.new(1, -132, 0, 0),
        COLORS.dim,
        10,
        Enum.Font.GothamBold
    )
    buildText.TextXAlignment = Enum.TextXAlignment.Right

    local rail = create("Frame", {
        Name = "VoidRail",
        Size = UDim2.new(0, RAIL_COLLAPSED_WIDTH, 1, 0),
        BackgroundColor3 = COLORS.rail,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 30,
    }, main)
    create("Frame", {
        Name = "RailDivider",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = COLORS.border,
        BorderSizePixel = 0,
        ZIndex = 31,
    }, rail)

    local crest = create("TextButton", {
        Name = "VORCrest",
        Position = UDim2.fromOffset(11, 12),
        Size = UDim2.fromOffset(52, 52),
        BackgroundColor3 = COLORS.surfaceRaised,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "✦",
        TextColor3 = COLORS.accentBright,
        TextSize = 28,
        Font = Enum.Font.GothamBold,
        ZIndex = 34,
    }, rail)
    corner(crest, 15)
    stroke(crest, COLORS.accent, 1, 0.22)
    local crestGlow = create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.5, COLORS.accentBright),
            ColorSequenceKeypoint.new(1, COLORS.accentDark),
        }),
        Rotation = 25,
    }, crest)

    local brandTitle = label(rail, "VOR HUB", UDim2.fromOffset(112, 24), UDim2.fromOffset(82, 18), COLORS.text, 16, Enum.Font.GothamBold)
    local brandSub = label(rail, "VOID OPERATIONS", UDim2.fromOffset(115, 18), UDim2.fromOffset(82, 40), COLORS.dim, 9, Enum.Font.GothamBold)

    local navScroll = create("ScrollingFrame", {
        Name = "Navigation",
        Position = UDim2.fromOffset(8, 78),
        Size = UDim2.new(1, -16, 1, -156),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 33,
    }, rail)
    create("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, navScroll)

    local profile = create("Frame", {
        Name = "ProfileCard",
        Position = UDim2.new(0, 8, 1, -70),
        Size = UDim2.new(1, -16, 0, 58),
        BackgroundColor3 = COLORS.surfaceRaised,
        BorderSizePixel = 0,
        ZIndex = 34,
    }, rail)
    corner(profile, 11)
    stroke(profile, COLORS.border, 1, 0.42)
    local avatar = create("ImageLabel", {
        Name = "Avatar",
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(42, 42),
        BackgroundColor3 = COLORS.control,
        BorderSizePixel = 0,
        Image = "",
        ZIndex = 35,
    }, profile)
    corner(avatar, 13)
    stroke(avatar, COLORS.accent, 1, 0.3)
    local profileName = label(profile, LocalPlayer and LocalPlayer.DisplayName or "Player", UDim2.fromOffset(118, 21), UDim2.fromOffset(60, 7), COLORS.text, 11, Enum.Font.GothamBold)
    local profileState = label(profile, "DEFAULT  •  SAVED", UDim2.fromOffset(124, 18), UDim2.fromOffset(60, 29), COLORS.accentBright, 9, Enum.Font.GothamBold)

    task.spawn(function()
        if not LocalPlayer then
            return
        end
        local ok, image = pcall(function()
            return Services.Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size100x100
            )
        end)
        if ok and avatar.Parent then
            avatar.Image = image
        end
    end)

    local minimized = create("TextButton", {
        Name = "VoidCrestMinimized",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.08, 0.5),
        Size = UDim2.fromOffset(58, 58),
        BackgroundColor3 = COLORS.shell,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "✦",
        TextColor3 = COLORS.accentBright,
        TextSize = 29,
        Font = Enum.Font.GothamBold,
        Visible = false,
        ZIndex = 90,
    }, overlay)
    corner(minimized, 17)
    stroke(minimized, COLORS.accentBright, 1.2, 0.15)

    local drawer = create("Frame", {
        Name = "CommandDrawer",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 350, 0, 66),
        Size = UDim2.new(0, 336, 1, -94),
        BackgroundColor3 = COLORS.surface,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50,
    }, content)
    corner(drawer, 11)
    stroke(drawer, COLORS.borderBright, 1, 0.3)
    local drawerTitle = label(drawer, "ACTIVITY", UDim2.new(1, -52, 0, 46), UDim2.fromOffset(16, 0), COLORS.text, 13, Enum.Font.GothamBold)
    local drawerClose = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 9),
        Size = UDim2.fromOffset(30, 30),
        BackgroundColor3 = COLORS.control,
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = COLORS.muted,
        TextSize = 19,
        Font = Enum.Font.GothamBold,
        ZIndex = 52,
    }, drawer)
    corner(drawerClose, 8)
    local drawerList = create("ScrollingFrame", {
        Name = "Items",
        Position = UDim2.fromOffset(10, 50),
        Size = UDim2.new(1, -20, 1, -60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 51,
    }, drawer)
    create("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, drawerList)

    local searchResults = create("Frame", {
        Name = "SearchResults",
        Position = UDim2.new(searchBox.Position.X.Scale, -130, 0, 56),
        Size = UDim2.fromOffset(320, 0),
        BackgroundColor3 = COLORS.surfaceRaised,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 70,
    }, topbar)
    corner(searchResults, 9)
    stroke(searchResults, COLORS.borderBright, 1, 0.28)
    create("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, searchResults)
    padding(searchResults, 5, 5, 5, 5)

    local Window = {
        Gui = gui,
        Main = main,
        PanelBackground = panelBackground,
        Rail = rail,
        Content = content,
        PagesHost = pagesHost,
        Controls = {},
        ControlsByFlag = {},
        PersistentControls = {},
        SearchItems = {},
        Pages = {},
        PageOrder = {},
        Notifications = {},
        Activities = {},
        CurrentPage = nil,
        Dirty = false,
        ProfileName = "Default",
        Minimized = false,
        RailExpanded = false,
        CollapsedPosition = main.Position,
        DrawerOpen = false,
        ActivityMode = "Activity",
        Destroyed = false,
        HubTransparency = 0.24,
        ThemeImageTransparency = 0.68,
        TransparencyBases = setmetatable({}, {__mode = "k"}),
    }

    local iconMap = {
        Home = "🏠",
        Farming = "🌾",
        Combat = "⚔️",
        Mastery = "⭐",
        Shop = "🛒",
        ["Sea & Raids"] = "🌊",
        Player = "👤",
        Settings = "⚙️",
        Tools = "🛠️",
        Overnight = "🌙",
        Weapons = "🗡️",
        Progress = "📈",
        Visuals = "👁️",
        Shooting = "🎯",
        Dribble = "🏀",
        Exploits = "⚠️",
        Dungeons = "🏰",
        AFK = "💤",
        Missions = "📜",
        Summon = "✨",
        Units = "👥",
    }

    local function setProfileState(text, color)
        profileState.Text = string.upper(tostring(text or "SAVED"))
        profileState.TextColor3 = color or COLORS.accentBright
    end

    function Window:SetProfileState(name, state)
        if name and tostring(name) ~= "" then
            self.ProfileName = tostring(name)
        end
        profileName.Text = LocalPlayer and LocalPlayer.DisplayName or "Player"
        setProfileState(self.ProfileName .. "  •  " .. tostring(state or "SAVED"), state == "UNSAVED" and COLORS.warning or COLORS.accentBright)
    end

    function Window:MarkDirty()
        self.Dirty = true
        self:SetProfileState(self.ProfileName, "UNSAVED")
    end

    function Window:SetContextStatus(message, tone)
        statusText.Text = tostring(message or "Ready")
        statusText.TextColor3 = tone == "error" and COLORS.error
            or (tone == "warning" and COLORS.warning)
            or (tone == "success" and COLORS.success)
            or COLORS.dim
        gui:SetAttribute("VORContextStatus", statusText.Text)
    end

    function Window:SetModuleIdentity(name, version, verified)
        identity.Text = string.format("%s  •  v%s%s", tostring(name or "Unknown module"), tostring(version or SETTINGS.Version), verified and "  •  VERIFIED" or "")
        identity.TextColor3 = verified and COLORS.success or COLORS.muted
    end

    function Window:SetConnected(connected, detail)
        connectionChip.Text = connected and "●  CONNECTED" or "●  OFFLINE"
        connectionChip.TextColor3 = connected and COLORS.success or COLORS.error
        connectionChip.BackgroundColor3 = connected and Color3.fromRGB(14, 29, 24) or Color3.fromRGB(35, 15, 22)
        if detail then
            connectionChip:SetAttribute("Detail", tostring(detail))
        end
    end

    local function refreshDrawer(mode)
        for _, child in ipairs(drawerList:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        Window.ActivityMode = mode or Window.ActivityMode
        drawerTitle.Text = string.upper(Window.ActivityMode)
        local entries = Window.ActivityMode == "Notifications" and Window.Notifications or Window.Activities
        if #entries == 0 then
            local empty = label(drawerList, "Nothing here yet.", UDim2.new(1, 0, 0, 42), nil, COLORS.dim, 11, Enum.Font.GothamMedium)
            empty.LayoutOrder = 1
            return
        end
        for reverseIndex = #entries, math.max(1, #entries - 39), -1 do
            local entry = entries[reverseIndex]
            local card = create("Frame", {
                Size = UDim2.new(1, -2, 0, 58),
                BackgroundColor3 = COLORS.control,
                BorderSizePixel = 0,
                LayoutOrder = #entries - reverseIndex + 1,
                ZIndex = 52,
            }, drawerList)
            corner(card, 8)
            local dot = create("Frame", {
                Position = UDim2.fromOffset(10, 12),
                Size = UDim2.fromOffset(6, 34),
                BackgroundColor3 = entry.Color or COLORS.accent,
                BorderSizePixel = 0,
                ZIndex = 53,
            }, card)
            corner(dot, 3)
            label(card, entry.Title or entry.Kind or "VOR", UDim2.new(1, -34, 0, 20), UDim2.fromOffset(27, 6), COLORS.text, 11, Enum.Font.GothamBold)
            local body = label(card, entry.Message or "", UDim2.new(1, -34, 0, 28), UDim2.fromOffset(27, 25), COLORS.muted, 10, Enum.Font.GothamMedium)
            body.TextWrapped = true
            body.TextYAlignment = Enum.TextYAlignment.Top
        end
    end

    function Window:SetDrawer(open, mode)
        self.DrawerOpen = open == true
        if mode then
            self.ActivityMode = mode
        end
        if self.DrawerOpen then
            refreshDrawer(self.ActivityMode)
            drawer.Visible = true
            drawer.Position = UDim2.new(1, 350, 0, 66)
            tween(drawer, 0.22, {Position = UDim2.new(1, -8, 0, 66)})
        else
            local animation = tween(drawer, 0.18, {Position = UDim2.new(1, 350, 0, 66)})
            if animation then
                animation.Completed:Once(function()
                    if not Window.DrawerOpen then
                        drawer.Visible = false
                    end
                end)
            else
                drawer.Visible = false
            end
        end
    end

    function Window:AddActivity(kind, message, color)
        table.insert(self.Activities, {
            Kind = tostring(kind or "Activity"),
            Title = tostring(kind or "Activity"),
            Message = tostring(message or ""),
            Color = color or COLORS.accent,
            At = os.clock(),
        })
        if #self.Activities > 80 then
            table.remove(self.Activities, 1)
        end
        self:SetContextStatus(string.format("%s  •  %s", tostring(kind or "Activity"), tostring(message or "")))
        if self.DrawerOpen and self.ActivityMode == "Activity" then
            refreshDrawer("Activity")
        end
    end

    function Window:Notify(titleText, message, duration)
        local entry = {
            Title = tostring(titleText or "VOR Hub"),
            Message = tostring(message or ""),
            Color = COLORS.accent,
            At = os.clock(),
        }
        table.insert(self.Notifications, entry)
        if #self.Notifications > 80 then
            table.remove(self.Notifications, 1)
        end
        Utilities.EmitNotification(entry)
        if self.DrawerOpen and self.ActivityMode == "Notifications" then
            refreshDrawer("Notifications")
        end

        local toast = create("Frame", {
            Name = "Toast",
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 350, 0, 22 + math.min(4, #self.Notifications % 5) * 72),
            Size = UDim2.fromOffset(320, 62),
            BackgroundColor3 = COLORS.surfaceRaised,
            BorderSizePixel = 0,
            ZIndex = 120,
        }, overlay)
        corner(toast, 10)
        stroke(toast, COLORS.borderBright, 1, 0.2)
        create("Frame", {
            Size = UDim2.fromOffset(5, 62),
            BackgroundColor3 = COLORS.accent,
            BorderSizePixel = 0,
            ZIndex = 121,
        }, toast)
        label(toast, entry.Title, UDim2.new(1, -28, 0, 22), UDim2.fromOffset(17, 7), COLORS.text, 11, Enum.Font.GothamBold)
        local toastMessage = label(toast, entry.Message, UDim2.new(1, -28, 0, 27), UDim2.fromOffset(17, 28), COLORS.muted, 10, Enum.Font.GothamMedium)
        toastMessage.TextWrapped = true
        toastMessage.TextYAlignment = Enum.TextYAlignment.Top
        tween(toast, 0.23, {Position = UDim2.new(1, -18, toast.Position.Y.Scale, toast.Position.Y.Offset)})
        task.delay(tonumber(duration) or 3.5, function()
            if not toast.Parent then
                return
            end
            local animation = tween(toast, 0.2, {Position = UDim2.new(1, 350, toast.Position.Y.Scale, toast.Position.Y.Offset)})
            if animation then
                animation.Completed:Once(function()
                    if toast.Parent then
                        toast:Destroy()
                    end
                end)
            else
                toast:Destroy()
            end
        end)
    end

    function Window:SetRailExpanded(expanded)
        expanded = expanded == true
        if self.RailExpanded == expanded then
            return
        end
        self.RailExpanded = expanded
        local width = expanded and RAIL_EXPANDED_WIDTH or RAIL_COLLAPSED_WIDTH
        local targetWidth = BASE_WIDTH + (expanded and RAIL_EXPANSION or 0)
        local collapsedPosition = self.CollapsedPosition or UDim2.fromScale(0.5, 0.5)
        local targetPosition = expanded and UDim2.new(
            collapsedPosition.X.Scale,
            collapsedPosition.X.Offset - RAIL_EXPANSION * 0.5,
            collapsedPosition.Y.Scale,
            collapsedPosition.Y.Offset
        ) or collapsedPosition
        tween(rail, 0.2, {Size = UDim2.new(0, width, 1, 0)})
        tween(main, 0.2, {
            Position = targetPosition,
            Size = UDim2.fromOffset(targetWidth, BASE_HEIGHT),
        })
        tween(content, 0.2, {
            Position = UDim2.fromOffset(width, 0),
            Size = UDim2.new(1, -width, 1, 0),
        })
        for _, page in ipairs(self.PageOrder) do
            if page.NavLabel then
                tween(page.NavLabel, 0.14, {TextTransparency = expanded and 0 or 1})
            end
        end
        tween(brandTitle, 0.14, {TextTransparency = expanded and 0 or 1})
        tween(brandSub, 0.14, {TextTransparency = expanded and 0 or 1})
        tween(profileName, 0.14, {TextTransparency = expanded and 0 or 1})
        tween(profileState, 0.14, {TextTransparency = expanded and 0 or 1})
    end

    local function bindHover(object, entered, left)
        Utilities.Track(object.MouseEnter:Connect(entered))
        Utilities.Track(object.MouseLeave:Connect(left))
    end

    bindHover(rail, function()
        Window:SetRailExpanded(true)
    end, function()
        if not Services.UserInputService.TouchEnabled then
            Window:SetRailExpanded(false)
        end
    end)

    Utilities.Track(crest.Activated:Connect(function()
        if Services.UserInputService.TouchEnabled then
            Window:SetRailExpanded(not Window.RailExpanded)
        else
            Window:SetMinimized(true)
        end
    end))

    Utilities.Track(minimized.Activated:Connect(function()
        Window:SetMinimized(false)
    end))
    Utilities.Track(minimizeButton.Activated:Connect(function()
        Window:SetMinimized(true)
    end))
    Utilities.Track(drawerClose.Activated:Connect(function()
        Window:SetDrawer(false)
    end))
    Utilities.Track(activityButton.Activated:Connect(function()
        Window:SetDrawer(not Window.DrawerOpen or Window.ActivityMode ~= "Activity", "Activity")
    end))
    Utilities.Track(notificationButton.Activated:Connect(function()
        Window:SetDrawer(not Window.DrawerOpen or Window.ActivityMode ~= "Notifications", "Notifications")
    end))
    Utilities.Track(pauseButton.Activated:Connect(function()
        local paused = Utilities.SetPaused(not Utilities.IsPaused(), "Global pause button")
        pauseButton.Text = paused and "RESUME" or "PAUSE"
        pauseButton.TextColor3 = paused and COLORS.warning or COLORS.muted
        Window:AddActivity("Global", paused and "All registered automation paused" or "Automation resumed", paused and COLORS.warning or COLORS.success)
    end))

    function Window:SetVisible(visible)
        gui.Enabled = visible == true
    end

    function Window:ToggleVisible()
        self:SetVisible(not gui.Enabled)
    end

    function Window:SetMinimized(value)
        self.Minimized = value == true
        if self.Minimized then
            if self.RailExpanded then
                self:SetRailExpanded(false)
            end
            minimized.Visible = true
            tween(main, 0.2, {Size = UDim2.fromOffset(BASE_WIDTH - 110, BASE_HEIGHT - 74), BackgroundTransparency = 1})
            task.delay(SETTINGS.ReducedMotion and 0 or 0.16, function()
                if Window.Minimized then
                    main.Visible = false
                end
            end)
        else
            main.Visible = true
            main.Position = self.CollapsedPosition or UDim2.fromScale(0.5, 0.5)
            main.Size = UDim2.fromOffset(BASE_WIDTH - 110, BASE_HEIGHT - 74)
            main.BackgroundTransparency = 0
            minimized.Visible = false
            tween(main, 0.22, {Size = UDim2.fromOffset(BASE_WIDTH, BASE_HEIGHT)}, Enum.EasingStyle.Back)
        end
    end

    function Window:GetMinimizeStyle()
        return SETTINGS.MinimizedStyleDefault
    end

    function Window:SetMinimizeStyle(value)
        value = tostring(value or "Void Crest")
        if value == "Minimize Bar" then
            value = "Compact Bar"
        elseif value == "Spiral Circle" then
            value = "Void Crest"
        end
        SETTINGS.MinimizedStyleDefault = value
        if value == "Compact Bar" then
            minimized.Size = UDim2.fromOffset(176, 44)
            minimized.Text = "VOR HUB  |  OPEN"
            minimized.TextSize = 12
        else
            minimized.Size = UDim2.fromOffset(58, 58)
            minimized.Text = "✦"
            minimized.TextSize = 29
        end
        return SETTINGS.MinimizedStyleDefault
    end

    local dragState = {Active = false, Start = nil, Origin = nil}
    Utilities.Track(topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragState.Active = true
            dragState.Start = input.Position
            dragState.Origin = main.Position
        end
    end))
    Utilities.Track(Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragState.Active then
                if Window.RailExpanded then
                    Window.CollapsedPosition = UDim2.new(
                        main.Position.X.Scale,
                        main.Position.X.Offset + RAIL_EXPANSION * 0.5,
                        main.Position.Y.Scale,
                        main.Position.Y.Offset
                    )
                else
                    Window.CollapsedPosition = main.Position
                end
            end
            dragState.Active = false
        end
    end))
    Utilities.Track(Services.UserInputService.InputChanged:Connect(function(input)
        if dragState.Active and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragState.Start
            main.Position = UDim2.new(
                dragState.Origin.X.Scale,
                dragState.Origin.X.Offset + delta.X,
                dragState.Origin.Y.Scale,
                dragState.Origin.Y.Offset + delta.Y
            )
        end
    end))

    function Window:UpdateScale()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local safeWidth = math.max(360, viewport.X - 20)
        local safeHeight = math.max(320, viewport.Y - 20)
        local scale = math.min(1, safeWidth / BASE_WIDTH, safeHeight / BASE_HEIGHT)
            * (SETTINGS.UIScale or 1)
        scaleObject.Scale = math.clamp(scale, 0.48, 1.3)
        gui:SetAttribute("VORResponsiveMode", viewport.X < 760 and "Compact" or "Desktop")
    end

    Utilities.Track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        task.defer(function()
            Window:UpdateScale()
        end)
    end))
    Utilities.Track(Services.UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == SETTINGS.ToggleKey then
            Window:ToggleVisible()
        end
    end))

    local SectionMethods = {}
    SectionMethods.__index = SectionMethods
    local PageMethods = {}
    PageMethods.__index = PageMethods

    local function makeRow(section, height, name, description)
        local row = create("Frame", {
            Name = Utilities.MakeFlag(name),
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = COLORS.control,
            BorderSizePixel = 0,
            LayoutOrder = section.NextOrder,
            ZIndex = 8,
        }, section.Content)
        section.NextOrder += 1
        corner(row, 8)
        stroke(row, COLORS.border, 1, 0.58)
        if name then
            label(row, name, UDim2.new(1, -100, 0, 23), UDim2.fromOffset(12, description and 5 or math.floor((height - 23) / 2)), COLORS.text, 12, Enum.Font.GothamSemibold)
        end
        if description and description ~= "" then
            local descriptionLabel = label(row, description, UDim2.new(1, -24, 0, height - 29), UDim2.fromOffset(12, 27), COLORS.dim, 10, Enum.Font.Gotham)
            descriptionLabel.TextWrapped = true
            descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
        end
        bindHover(row, function()
            tween(row, 0.12, {BackgroundColor3 = COLORS.controlHover})
        end, function()
            tween(row, 0.12, {BackgroundColor3 = COLORS.control})
        end)
        return row
    end

    local function registerControl(section, control, options, row)
        options = options or {}
        local baseFlag = options.Flag or Utilities.MakeFlag(section.Page.Name .. "_" .. section.Title .. "_" .. tostring(options.Name or "control"))
        control.Flag = baseFlag
        control.Persist = options.Persist ~= false
        control.Name = tostring(options.Name or baseFlag)
        control.Description = tostring(options.Description or "")
        control.Page = section.Page
        control.Section = section
        control.Row = row
        Window.Controls[baseFlag] = control
        Window.ControlsByFlag[baseFlag] = control
        if control.Persist then
            Window.PersistentControls[baseFlag] = control
        end
        table.insert(Window.SearchItems, control)
        return control
    end

    function SectionMethods:AddLabel(text)
        local row = makeRow(self, 38, nil, nil)
        row.BackgroundTransparency = 0.42
        local value = label(row, tostring(text or ""), UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), COLORS.muted, 11, Enum.Font.Gotham)
        value.TextWrapped = true
        local control = {Row = row, ValueLabel = value, Persist = false}
        function control:Set(newText)
            value.Text = tostring(newText or "")
        end
        function control:Get()
            return value.Text
        end
        -- Legacy builders treated AddLabel's result like a TextLabel, while
        -- newer builders call Set/Get. The proxy preserves both contracts.
        return setmetatable(control, {
            __index = function(_, key)
                local own = rawget(control, key)
                if own ~= nil then
                    return own
                end
                return value[key]
            end,
            __newindex = function(_, key, newValue)
                local ok = pcall(function()
                    value[key] = newValue
                end)
                if not ok then
                    rawset(control, key, newValue)
                end
            end,
        })
    end

    function SectionMethods:AddParagraph(options)
        options = type(options) == "table" and options or {Content = tostring(options or "")}
        local row = makeRow(self, 64, options.Name or options.Title or "Information", options.Content or options.Description or "")
        return {Row = row, Persist = false}
    end

    function SectionMethods:AddButton(options)
        options = type(options) == "table" and options or {Name = tostring(options or "Button")}
        local row = makeRow(self, options.Description and 52 or 42, options.Name or "Button", options.Description)
        local arrow = label(row, "›", UDim2.fromOffset(28, 42), UDim2.new(1, -36, 0, 0), COLORS.accentBright, 21, Enum.Font.GothamBold)
        arrow.TextXAlignment = Enum.TextXAlignment.Center
        local button = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            ZIndex = 12,
        }, row)
        local control = registerControl(self, {Persist = false}, options, row)
        control.Persist = false
        Utilities.Track(button.Activated:Connect(function()
            tween(row, 0.08, {BackgroundColor3 = COLORS.accentDark})
            task.delay(0.09, function()
                if row.Parent then
                    tween(row, 0.12, {BackgroundColor3 = COLORS.control})
                end
            end)
            local ok, err = safeCallback(control.Name, options.Callback)
            if not ok then
                Window:Notify("Control Error", control.Name .. ": " .. tostring(err), 5)
            end
        end))
        return control
    end

    function SectionMethods:AddToggle(options)
        options = options or {}
        local row = makeRow(self, options.Description and 54 or 44, options.Name or "Toggle", options.Description)
        local track = create("Frame", {
            Name = "Track",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(46, 24),
            BackgroundColor3 = COLORS.toggleOff,
            BorderSizePixel = 0,
            ZIndex = 10,
        }, row)
        corner(track, 12)
        local core = create("Frame", {
            Name = "Core",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(18, 18),
            BackgroundColor3 = COLORS.white,
            BorderSizePixel = 0,
            ZIndex = 11,
        }, track)
        corner(core, 9)
        local button = create("TextButton", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            ZIndex = 12,
        }, row)
        local control = registerControl(self, {Value = options.Default == true}, options, row)
        control.RuntimePaused = false
        function control:Set(value, silent)
            value = value == true
            self.Value = value
            tween(track, 0.15, {BackgroundColor3 = value and COLORS.accent or COLORS.toggleOff})
            tween(core, 0.18, {
                Position = value and UDim2.new(1, -12, 0.5, 0) or UDim2.new(0, 12, 0.5, 0),
                BackgroundColor3 = value and COLORS.white or COLORS.muted,
            })
            if not silent then
                Window:MarkDirty()
                safeCallback(self.Name, options.Callback, value and not self.RuntimePaused)
            end
        end
        function control:Get()
            return self.Value
        end
        function control:SetRuntimePaused(paused)
            paused = paused == true
            if self.RuntimePaused == paused then
                return
            end
            self.RuntimePaused = paused
            if self.Value then
                safeCallback(self.Name .. " runtime pause", options.Callback, not paused)
            end
        end
        Utilities.Track(button.Activated:Connect(function()
            control:Set(not control.Value)
        end))
        control:Set(control.Value, true)
        return control
    end

    function SectionMethods:AddSlider(options)
        options = options or {}
        local minimum = tonumber(options.Min) or 0
        local maximum = tonumber(options.Max) or 100
        local round = options.Round
        local increment = tonumber(options.Increment or options.Step)
        if not increment then
            increment = round and (10 ^ -round) or 1
        end
        local row = makeRow(self, options.Description and 72 or 62, options.Name or "Slider", options.Description)
        local valueLabel = label(row, "", UDim2.fromOffset(76, 22), UDim2.new(1, -88, 0, 7), COLORS.accentBright, 11, Enum.Font.GothamBold)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        local bar = create("Frame", {
            Position = UDim2.new(0, 12, 1, -17),
            Size = UDim2.new(1, -24, 0, 4),
            BackgroundColor3 = COLORS.toggleOff,
            BorderSizePixel = 0,
            ZIndex = 10,
        }, row)
        corner(bar, 2)
        local fill = create("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = COLORS.accent,
            BorderSizePixel = 0,
            ZIndex = 11,
        }, bar)
        corner(fill, 2)
        local diamond = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(12, 12),
            Rotation = 45,
            BackgroundColor3 = COLORS.white,
            BorderSizePixel = 0,
            ZIndex = 12,
        }, bar)
        corner(diamond, 2)
        stroke(diamond, COLORS.accentBright, 1, 0)
        local input = create("TextButton", {
            Position = UDim2.new(0, -5, 0, -12),
            Size = UDim2.new(1, 10, 1, 24),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 13,
        }, bar)
        local control = registerControl(self, {Value = tonumber(options.Default) or minimum}, options, row)
        local dragging = false
        local function normalize(value)
            value = math.clamp(tonumber(value) or minimum, minimum, maximum)
            value = math.floor((value / increment) + 0.5) * increment
            if round then
                local factor = 10 ^ round
                value = math.floor(value * factor + 0.5) / factor
            end
            return math.clamp(value, minimum, maximum)
        end
        function control:Set(value, silent)
            value = normalize(value)
            self.Value = value
            local alpha = maximum == minimum and 0 or ((value - minimum) / (maximum - minimum))
            fill.Size = UDim2.fromScale(alpha, 1)
            diamond.Position = UDim2.fromScale(alpha, 0.5)
            valueLabel.Text = tostring(value) .. tostring(options.Suffix or options.Type or "")
            if not silent then
                Window:MarkDirty()
                safeCallback(self.Name, options.Callback, value)
            end
        end
        function control:Get()
            return self.Value
        end
        local function setFromX(x)
            local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
            control:Set(minimum + (maximum - minimum) * alpha)
        end
        Utilities.Track(input.InputBegan:Connect(function(event)
            if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                setFromX(event.Position.X)
            end
        end))
        Utilities.Track(Services.UserInputService.InputChanged:Connect(function(event)
            if dragging and (event.UserInputType == Enum.UserInputType.MouseMovement or event.UserInputType == Enum.UserInputType.Touch) then
                setFromX(event.Position.X)
            end
        end))
        Utilities.Track(Services.UserInputService.InputEnded:Connect(function(event)
            if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
        control:Set(control.Value, true)
        return control
    end

    function SectionMethods:AddInput(options)
        options = options or {}
        local row = makeRow(self, options.Description and 58 or 48, options.Name or "Input", options.Description)
        local box = create("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.fromOffset(145, 30),
            BackgroundColor3 = COLORS.surfaceRaised,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            PlaceholderText = tostring(options.Placeholder or "Type here"),
            PlaceholderColor3 = COLORS.dim,
            Text = tostring(options.Default or ""),
            TextColor3 = COLORS.text,
            TextSize = 10,
            Font = Enum.Font.GothamMedium,
            ZIndex = 11,
        }, row)
        corner(box, 7)
        stroke(box, COLORS.border, 1, 0.45)
        padding(box, 8, 8, 0, 0)
        local control = registerControl(self, {Value = box.Text}, options, row)
        function control:Set(value, silent)
            value = tostring(value or "")
            self.Value = value
            box.Text = value
            if not silent then
                Window:MarkDirty()
                safeCallback(self.Name, options.Callback, value)
            end
        end
        function control:Get()
            return self.Value
        end
        Utilities.Track(box.FocusLost:Connect(function()
            control:Set(box.Text)
        end))
        return control
    end

    function SectionMethods:AddDropdown(options)
        options = options or {}
        local values = options.Options or options.Values or {}
        local multi = options.Multi == true
        local default = options.Default
        if default == nil then
            default = multi and {} or values[1]
        end
        local row = makeRow(self, options.Description and 58 or 48, options.Name or "Dropdown", options.Description)
        row.ClipsDescendants = true
        local display = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -10, 0, 9),
            Size = UDim2.fromOffset(160, 30),
            BackgroundColor3 = COLORS.surfaceRaised,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            ZIndex = 12,
        }, row)
        corner(display, 7)
        stroke(display, COLORS.border, 1, 0.45)
        local displayText = label(display, "", UDim2.new(1, -28, 1, 0), UDim2.fromOffset(9, 0), COLORS.muted, 10, Enum.Font.GothamMedium)
        local arrow = label(display, "⌄", UDim2.fromOffset(22, 30), UDim2.new(1, -24, 0, 0), COLORS.accentBright, 13, Enum.Font.GothamBold)
        arrow.TextXAlignment = Enum.TextXAlignment.Center
        local optionHolder = create("Frame", {
            Position = UDim2.fromOffset(10, 46),
            Size = UDim2.new(1, -20, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 14,
        }, row)
        local optionLayout = create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, optionHolder)
        local control = registerControl(self, {Value = default, Values = values, Open = false}, options, row)

        local function selectionText()
            if not multi then
                return tostring(control.Value or "None")
            end
            local selected = {}
            for key, enabled in pairs(control.Value or {}) do
                if enabled then
                    table.insert(selected, tostring(key))
                end
            end
            table.sort(selected)
            return #selected == 0 and "None" or table.concat(selected, ", ")
        end

        local function close()
            control.Open = false
            arrow.Text = "⌄"
            row.Size = UDim2.new(1, 0, 0, options.Description and 58 or 48)
            optionHolder.Size = UDim2.new(1, -20, 0, 0)
        end

        local function rebuild()
            for _, child in ipairs(optionHolder:GetChildren()) do
                if child:IsA("GuiObject") then
                    child:Destroy()
                end
            end
            local shown = math.min(#control.Values, 7)
            for index, value in ipairs(control.Values) do
                local optionButton = create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = COLORS.surfaceRaised,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    Text = tostring(value),
                    TextColor3 = COLORS.muted,
                    TextSize = 10,
                    Font = Enum.Font.GothamMedium,
                    LayoutOrder = index,
                    ZIndex = 15,
                }, optionHolder)
                corner(optionButton, 6)
                Utilities.Track(optionButton.Activated:Connect(function()
                    if multi then
                        local selected = control.Value
                        if type(selected) ~= "table" then
                            selected = {}
                            control.Value = selected
                        end
                        selected[value] = not selected[value]
                        Window:MarkDirty()
                        safeCallback(control.Name, options.Callback, selected)
                        displayText.Text = selectionText()
                        optionButton.TextColor3 = selected[value] and COLORS.accentBright or COLORS.muted
                    else
                        control:Set(value)
                        close()
                    end
                end))
            end
        end

        function control:Set(value, silent)
            if multi and type(value) ~= "table" then
                local converted = {}
                if value ~= nil then
                    converted[value] = true
                end
                value = converted
            end
            self.Value = value
            displayText.Text = selectionText()
            if not silent then
                Window:MarkDirty()
                safeCallback(self.Name, options.Callback, value)
            end
        end

        function control:Get()
            return self.Value
        end

        function control:SetOptions(newValues)
            self.Values = type(newValues) == "table" and newValues or {}
            rebuild()
            displayText.Text = selectionText()
        end

        Utilities.Track(display.Activated:Connect(function()
            control.Open = not control.Open
            arrow.Text = control.Open and "⌃" or "⌄"
            if control.Open then
                rebuild()
                local shown = math.min(#control.Values, 7)
                local height = shown * 32
                row.Size = UDim2.new(1, 0, 0, (options.Description and 58 or 48) + height + 5)
                optionHolder.Size = UDim2.new(1, -20, 0, height)
            else
                close()
            end
        end))
        control:Set(default, true)
        return control
    end

    function SectionMethods:AddColorPicker(options)
        options = options or {}
        local palette = {
            COLORS.accent,
            COLORS.accentBright,
            COLORS.success,
            COLORS.warning,
            COLORS.error,
            Color3.fromRGB(255, 255, 255),
        }
        local current = options.Default or palette[1]
        local row = makeRow(self, 44, options.Name or "Color", options.Description)
        local swatch = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.fromOffset(30, 24),
            BackgroundColor3 = current,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 11,
        }, row)
        corner(swatch, 7)
        stroke(swatch, COLORS.white, 1, 0.65)
        local control = registerControl(self, {Value = current, Index = 1}, options, row)
        function control:Set(value, silent)
            if typeof(value) == "Color3" then
                self.Value = value
                swatch.BackgroundColor3 = value
                if not silent then
                    Window:MarkDirty()
                    safeCallback(self.Name, options.Callback, value)
                end
            end
        end
        function control:Get()
            return self.Value
        end
        Utilities.Track(swatch.Activated:Connect(function()
            control.Index = (control.Index % #palette) + 1
            control:Set(palette[control.Index])
        end))
        return control
    end

    function PageMethods:AddSection(titleText, side)
        side = tostring(side or "Left")
        local column = side:lower() == "right" and self.RightColumn or self.LeftColumn
        local sectionFrame = create("Frame", {
            Name = Utilities.MakeFlag(titleText),
            Size = UDim2.new(1, -4, 0, 54),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = COLORS.surface,
            BorderSizePixel = 0,
            LayoutOrder = #self.Sections + 1,
            ZIndex = 6,
        }, column)
        corner(sectionFrame, 11)
        stroke(sectionFrame, COLORS.border, 1, 0.45)
        local sectionHeader = label(sectionFrame, tostring(titleText or "Section"), UDim2.new(1, -28, 0, 42), UDim2.fromOffset(14, 0), COLORS.accentBright, 12, Enum.Font.GothamBold)
        local line = create("Frame", {
            Position = UDim2.fromOffset(12, 41),
            Size = UDim2.new(1, -24, 0, 1),
            BackgroundColor3 = COLORS.border,
            BorderSizePixel = 0,
            ZIndex = 7,
        }, sectionFrame)
        local sectionContent = create("Frame", {
            Name = "Controls",
            Position = UDim2.fromOffset(10, 50),
            Size = UDim2.new(1, -20, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex = 7,
        }, sectionFrame)
        create("UIListLayout", {
            Padding = UDim.new(0, 7),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, sectionContent)
        padding(sectionContent, 0, 0, 0, 10)
        local section = setmetatable({
            Title = tostring(titleText or "Section"),
            Page = self,
            Frame = sectionFrame,
            Header = sectionHeader,
            Divider = line,
            Content = sectionContent,
            NextOrder = 1,
        }, SectionMethods)
        table.insert(self.Sections, section)
        return section
    end

    function Window:AddPage(name, options)
        name = tostring(name or "Page")
        if self.Pages[name] then
            return self.Pages[name]
        end
        options = options or {}
        local pageFrame = create("Frame", {
            Name = Utilities.MakeFlag(name),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 4,
        }, pagesHost)
        local pageTitle = label(pageFrame, name, UDim2.new(1, -24, 0, 48), UDim2.fromOffset(18, 2), COLORS.text, 20, Enum.Font.GothamBold)
        local leftColumn = create("ScrollingFrame", {
            Name = "LeftColumn",
            Position = UDim2.fromOffset(14, 52),
            Size = UDim2.new(0.5, -20, 1, -60),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.accentDark,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.fromOffset(0, 0),
            ZIndex = 5,
        }, pageFrame)
        create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, leftColumn)
        padding(leftColumn, 0, 3, 0, 10)
        local rightColumn = create("ScrollingFrame", {
            Name = "RightColumn",
            Position = UDim2.new(0.5, 6, 0, 52),
            Size = UDim2.new(0.5, -20, 1, -60),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = COLORS.accentDark,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.fromOffset(0, 0),
            ZIndex = 5,
        }, pageFrame)
        create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, rightColumn)
        padding(rightColumn, 0, 3, 0, 10)

        local page = setmetatable({
            Name = name,
            Frame = pageFrame,
            Title = pageTitle,
            LeftColumn = leftColumn,
            RightColumn = rightColumn,
            Sections = {},
            LayoutOrder = #self.PageOrder + 1,
        }, PageMethods)

        local navButton = create("TextButton", {
            Name = Utilities.MakeFlag(name) .. "_nav",
            Size = UDim2.new(1, 0, 0, 45),
            BackgroundColor3 = COLORS.rail,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "",
            LayoutOrder = page.LayoutOrder,
            ZIndex = 34,
        }, navScroll)
        corner(navButton, 9)
        local beam = create("Frame", {
            Position = UDim2.fromOffset(0, 10),
            Size = UDim2.fromOffset(3, 25),
            BackgroundColor3 = COLORS.accent,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 35,
        }, navButton)
        corner(beam, 2)
        local iconBadge = create("Frame", {
            Name = "IconBadge",
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.fromOffset(29, 29),
            BackgroundColor3 = COLORS.surfaceRaised,
            BackgroundTransparency = 0.62,
            BorderSizePixel = 0,
            ZIndex = 35,
        }, navButton)
        corner(iconBadge, 8)
        local iconStroke = stroke(iconBadge, COLORS.border, 1, 0.35)
        local iconText = iconMap[name] or tostring(options.Icon or string.sub(name, 1, 1)):upper()
        local icon = label(iconBadge, iconText, UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), COLORS.dim, 15, Enum.Font.Gotham)
        icon.TextXAlignment = Enum.TextXAlignment.Center
        local navLabel = label(navButton, name, UDim2.fromOffset(124, 45), UDim2.fromOffset(62, 0), COLORS.muted, 11, Enum.Font.GothamSemibold)
        navLabel.TextTransparency = 1
        page.NavButton = navButton
        page.NavBeam = beam
        page.NavIcon = icon
        page.NavIconBadge = iconBadge
        page.NavIconStroke = iconStroke
        page.NavLabel = navLabel
        self.Pages[name] = page
        table.insert(self.PageOrder, page)

        Utilities.Track(navButton.Activated:Connect(function()
            self:SelectPage(name)
            if Services.UserInputService.TouchEnabled then
                self:SetRailExpanded(false)
            end
        end))
        bindHover(navButton, function()
            if self.CurrentPage ~= page then
                tween(navButton, 0.12, {BackgroundTransparency = 0.35, BackgroundColor3 = COLORS.surfaceHover})
            end
        end, function()
            if self.CurrentPage ~= page then
                tween(navButton, 0.12, {BackgroundTransparency = 1, BackgroundColor3 = COLORS.rail})
            end
        end)

        if not self.CurrentPage then
            self:SelectPage(name)
        end
        return page
    end

    function Window:SelectPage(name)
        local target = self.Pages[tostring(name or "")]
        if not target then
            return false
        end
        for _, page in ipairs(self.PageOrder) do
            local active = page == target
            page.Frame.Visible = active
            page.NavBeam.Visible = active
            page.NavIcon.TextColor3 = active and COLORS.accentBright or COLORS.dim
            page.NavIconBadge.BackgroundTransparency = active and 0.12 or 0.62
            page.NavIconStroke.Color = active and COLORS.accent or COLORS.border
            page.NavLabel.TextColor3 = active and COLORS.accentBright or COLORS.muted
            page.NavButton.BackgroundTransparency = active and 0 or 1
            page.NavButton.BackgroundColor3 = active and COLORS.surfaceHover or COLORS.rail
        end
        self.CurrentPage = target
        self:SetContextStatus("Page  •  " .. target.Name)
        gui:SetAttribute("VORCurrentPage", target.Name)
        return true
    end

    local function clearSearchResults()
        for _, child in ipairs(searchResults:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        searchResults.Visible = false
        searchResults.Size = UDim2.fromOffset(320, 0)
    end

    local function refreshSearch(query)
        clearSearchResults()
        query = tostring(query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if query == "" then
            return
        end
        local matches = {}
        for _, control in ipairs(Window.SearchItems) do
            local haystack = string.lower(control.Name .. " " .. control.Description .. " " .. control.Page.Name .. " " .. control.Section.Title)
            if haystack:find(query, 1, true) then
                table.insert(matches, control)
            end
        end
        table.sort(matches, function(a, b)
            return a.Name < b.Name
        end)
        for index = 1, math.min(7, #matches) do
            local control = matches[index]
            local result = create("TextButton", {
                Size = UDim2.new(1, -10, 0, 39),
                BackgroundColor3 = COLORS.control,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Text = "",
                LayoutOrder = index,
                ZIndex = 72,
            }, searchResults)
            corner(result, 7)
            label(result, control.Name, UDim2.new(1, -18, 0, 20), UDim2.fromOffset(9, 3), COLORS.text, 10, Enum.Font.GothamBold)
            label(result, control.Page.Name .. "  /  " .. control.Section.Title, UDim2.new(1, -18, 0, 15), UDim2.fromOffset(9, 20), COLORS.dim, 8, Enum.Font.GothamMedium)
            Utilities.Track(result.Activated:Connect(function()
                Window:SelectPage(control.Page.Name)
                searchBox.Text = ""
                clearSearchResults()
                tween(control.Row, 0.1, {BackgroundColor3 = COLORS.accentDark})
                task.delay(0.6, function()
                    if control.Row.Parent then
                        tween(control.Row, 0.25, {BackgroundColor3 = COLORS.control})
                    end
                end)
            end))
        end
        if #matches == 0 then
            local noResult = label(searchResults, "No matching VOR command", UDim2.new(1, -10, 0, 38), UDim2.fromOffset(10, 0), COLORS.dim, 10, Enum.Font.GothamMedium)
            noResult.LayoutOrder = 1
        end
        local shown = math.max(1, math.min(7, #matches))
        searchResults.Size = UDim2.fromOffset(320, shown * 42 + 10)
        searchResults.Visible = true
    end

    Utilities.Track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        refreshSearch(searchBox.Text)
    end))
    Utilities.Track(searchBox.FocusLost:Connect(function()
        task.delay(0.15, function()
            if searchBox.Text == "" then
                clearSearchResults()
            end
        end)
    end))

    function Window:CreateCategoryHomePage(options)
        options = options or {}
        local home = self.Pages.Home or self:AddPage("Home")
        local categories = {}
        local function addCategory(name, order, decal)
            local page = self:AddPage(name, {Icon = iconMap[name]})
            page.CategoryOrder = order
            page.CategoryDecal = decal
            categories[name] = page
            return page
        end
        local function selectCategory(name)
            return self:SelectPage(name)
        end
        return home, addCategory, selectCategory
    end

    function Window:BuildHomeDashboard()
        local home = self.Pages.Home or self:AddPage("Home")
        if home.DashboardBuilt then
            self:SelectPage("Home")
            return home
        end
        home.DashboardBuilt = true

        local overview = home:AddSection("VOR Command Center", "Left")
        overview:AddLabel("Welcome back, " .. tostring(LocalPlayer and LocalPlayer.DisplayName or "Player"))
        overview:AddLabel("Game module: " .. tostring(SETTINGS.ActiveGame and SETTINGS.ActiveGame.DisplayName or "Unsupported"))
        overview:AddLabel("Version: " .. tostring(SETTINGS.Version) .. " | Module commit: " .. string.sub(tostring(context.Commit or "local"), 1, 8))
        overview:AddLabel("Runtime: immutable, modular, and verified")

        local updates = home:AddSection("Latest Build", "Left")
        updates:AddLabel("Only the current game's module is downloaded and compiled.")
        updates:AddLabel("Blox farming now uses one shared X / Y / Z position controller.")
        updates:AddLabel("Navigation now uses Roblox-compatible emoji badges.")
        updates:AddLabel("Background, accent, transparency, and minimize styles are live settings.")

        local launch = home:AddSection("Quick Launch", "Right")
        local launchOrder = {"Farming", "Combat", "Sea & Raids", "Dungeons", "Player", "Settings", "Mastery", "Shop"}
        for _, pageName in ipairs(launchOrder) do
            if self.Pages[pageName] then
                launch:AddButton({
                    Name = "Open " .. pageName,
                    Persist = false,
                    Callback = function()
                        self:SelectPage(pageName)
                    end,
                })
            end
        end

        local session = home:AddSection("Live Session", "Right")
        local pageStatus = session:AddLabel("Page: Home")
        local profileStatus = session:AddLabel("Profile: " .. tostring(self.ProfileName or "Default"))
        local pauseStatus = session:AddLabel("Automation: Running")
        local controlStatus = session:AddLabel("Registered controls: 0")
        local accumulator = 0
        local function updateSession()
            local count = 0
            for _ in pairs(self.PersistentControls) do
                count = count + 1
            end
            pageStatus.Text = "Page: " .. tostring(self.CurrentPage and self.CurrentPage.Name or "Home")
            profileStatus.Text = "Profile: " .. tostring(self.ProfileName or "Default")
            pauseStatus.Text = Utilities.IsPaused() and "Automation: Globally paused" or "Automation: Running"
            pauseStatus.TextColor3 = Utilities.IsPaused() and COLORS.warning or COLORS.success
            controlStatus.Text = "Registered controls: " .. tostring(count)
        end
        updateSession()
        Utilities.Track(Services.RunService.Heartbeat:Connect(function(deltaTime)
            accumulator = accumulator + deltaTime
            if accumulator >= 0.5 then
                accumulator = 0
                updateSession()
            end
        end))

        self:SelectPage("Home")
        return home
    end

    function Window:ShowBuildError(modulePath, err)
        local page = self.Pages["Build Error"] or self:AddPage("Build Error", {Icon = "!"})
        local section = page:AddSection("Module Build Failure", "Left")
        section:AddLabel("VOR kept the interface alive, but this module failed:")
        section:AddLabel(tostring(modulePath or "Unknown module"))
        local errorControl = section:AddLabel(tostring(err or "Unknown error"))
        errorControl.ValueLabel.TextColor3 = COLORS.error
        section:AddButton({
            Name = "Copy Full Error",
            Callback = function()
                if Utilities.CopyText(tostring(err or "Unknown error")) then
                    self:Notify("Build Error", "Copied full error", 2)
                else
                    self:Notify("Build Error", "Clipboard access is unavailable", 3)
                end
            end,
        })
        section:AddButton({
            Name = "Retry Current Module",
            Callback = function()
                self:Notify("Build Error", "Re-execute the audited loader to retry safely", 4)
            end,
        })
        self:SelectPage("Build Error")
        self:SetContextStatus("Build failed  •  " .. tostring(modulePath), "error")
        gui:SetAttribute("VORBuildError", tostring(err))
        return page
    end

    function Window:ShowOnboarding()
        if gui:GetAttribute("VOROnboardingShown") then
            return
        end
        gui:SetAttribute("VOROnboardingShown", true)
        self:Notify("Welcome to VOR", "Use Search to find any control. Save a profile when your setup is ready.", 6)
    end

    function Window:SetPanelBackground(value)
        value = tostring(value or SETTINGS.DefaultPanelBackground)
        local image = SETTINGS.PanelBackgrounds[value]
        if image then
            panelBackground.Image = image
        end
        gui:SetAttribute("VORPanelBackground", value)
    end

    function Window:SetAccentPreset(value)
        value = tostring(value or "VOR Violet")
        local nextAccent = SETTINGS.AccentPresets[value]
        if typeof(nextAccent) ~= "Color3" then
            return false
        end
        local oldAccent = COLORS.accent
        local oldDark = COLORS.accentDark
        local oldBright = COLORS.accentBright
        local oldBorder = COLORS.borderBright
        local nextDark = nextAccent:Lerp(COLORS.black, 0.52)
        local nextBright = nextAccent:Lerp(COLORS.white, 0.30)
        local nextBorder = nextAccent:Lerp(COLORS.surface, 0.62)
        local function swap(valueToCheck)
            if valueToCheck == oldAccent then
                return nextAccent
            elseif valueToCheck == oldDark then
                return nextDark
            elseif valueToCheck == oldBright then
                return nextBright
            elseif valueToCheck == oldBorder then
                return nextBorder
            end
            return valueToCheck
        end
        for _, object in ipairs(gui:GetDescendants()) do
            if object:IsA("GuiObject") then
                object.BackgroundColor3 = swap(object.BackgroundColor3)
            end
            if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
                object.TextColor3 = swap(object.TextColor3)
            end
            if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                object.ImageColor3 = swap(object.ImageColor3)
            elseif object:IsA("UIStroke") then
                object.Color = swap(object.Color)
            elseif object:IsA("UIGradient") then
                local points = {}
                for _, point in ipairs(object.Color.Keypoints) do
                    table.insert(points, ColorSequenceKeypoint.new(point.Time, swap(point.Value)))
                end
                object.Color = ColorSequence.new(points)
            end
        end
        COLORS.accent = nextAccent
        COLORS.accentDark = nextDark
        COLORS.accentBright = nextBright
        COLORS.borderBright = nextBorder
        panelBackground.ImageColor3 = nextBright
        gui:SetAttribute("VORAccentPreset", value)
        return true
    end

    function Window:SetHubTransparency(value)
        value = math.clamp(tonumber(value) or 0.24, 0.04, 0.80)
        self.HubTransparency = value
        for _, object in ipairs(gui:GetDescendants()) do
            if object:IsA("GuiObject") and object ~= panelBackground then
                local base = self.TransparencyBases[object]
                if base == nil then
                    base = object.BackgroundTransparency
                    self.TransparencyBases[object] = base
                end
                if base < 1 then
                    object.BackgroundTransparency = base + (1 - base) * value
                end
            end
        end
        local imageBase = self.ThemeImageTransparency or 0.68
        panelBackground.ImageTransparency = imageBase + (1 - imageBase) * value
        gui:SetAttribute("VORHubTransparency", value)
    end

    function Window:SetThemeIntensity(value)
        value = tostring(value or "Full Effects")
        if value == "Luxury" then
            value = "Full Effects"
        elseif value == "Void" then
            value = "Void Glass"
        elseif value == "Minimal" then
            value = "Performance"
        end
        SETTINGS.ThemeIntensity = value
        if value == "Performance" then
            self.ThemeImageTransparency = 1
            mainStroke.Transparency = 0.62
        elseif value == "Void Glass" then
            self.ThemeImageTransparency = 0.84
            mainStroke.Transparency = 0.18
        else
            self.ThemeImageTransparency = 0.68
            mainStroke.Transparency = 0.38
        end
        self:SetHubTransparency(self.HubTransparency)
        gui:SetAttribute("VORThemeIntensity", value)
    end

    function Window:SetReducedMotion(value)
        SETTINGS.ReducedMotion = value == true
        gui:SetAttribute("VORReducedMotion", SETTINGS.ReducedMotion)
    end

    function Window:SetUIScale(value)
        SETTINGS.UIScale = math.clamp(tonumber(value) or 1, 0.7, 1.3)
        self:UpdateScale()
    end

    function Window:Destroy()
        if self.Destroyed then
            return
        end
        self.Destroyed = true
        Utilities.Cleanup()
        if gui.Parent then
            gui:Destroy()
        end
        if _G.VORHub == self then
            _G.VORHub = nil
        end
    end

    Utilities.OnActivity(function(activity)
        Window:AddActivity(activity.Kind or "Activity", activity.Message or "", activity.Color)
    end)
    Utilities.OnPause(function(paused)
        for _, control in pairs(Window.PersistentControls) do
            if control.Page and control.Page.Name ~= "Settings" and control.SetRuntimePaused then
                control:SetRuntimePaused(paused)
            end
        end
        gui:SetAttribute("VORGlobalPaused", paused)
    end)
    Utilities.OnCleanup(function()
        Window.Destroyed = true
    end)

    -- A restrained living-void pulse gives VOR a recognizable state signal.
    local pulseStarted = os.clock()
    Utilities.Track(Services.RunService.RenderStepped:Connect(function()
        if SETTINGS.ReducedMotion or Window.Destroyed then
            return
        end
        local phase = (os.clock() - pulseStarted) * (Utilities.IsPaused() and 0.8 or 1.55)
        crestGlow.Rotation = (phase * 22) % 360
        local alpha = (math.sin(phase) + 1) * 0.5
        crest.TextColor3 = Utilities.IsPaused()
            and COLORS.warning:Lerp(COLORS.white, alpha * 0.25)
            or COLORS.accent:Lerp(COLORS.accentBright, alpha * 0.55)
        minimized.Rotation = (phase * 9) % 360
    end))

    Window:UpdateScale()
    Window:SetModuleIdentity(SETTINGS.ActiveGame and SETTINGS.ActiveGame.DisplayName or "Unsupported", SETTINGS.Version, true)
    Window:SetContextStatus("Ready  •  Waiting for module")
    Window:SetProfileState("Default", "SAVED")

    _G.VORHub = Window
    return {
        Window = Window,
        Gui = gui,
        Track = Utilities.Track,
        CreateCategoryHomePage = function(options)
            return Window:CreateCategoryHomePage(options)
        end,
        Colors = COLORS,
        CategoryDecals = SETTINGS.CATEGORY_DECALS,
        Create = create,
        AddCorner = corner,
        AddStroke = stroke,
        PlayToggleClick = playToggleClick,
        ReadableStatusColor = function(color)
            local sample = color or COLORS.muted
            local brightness = (sample.R * 0.299) + (sample.G * 0.587) + (sample.B * 0.114)
            if brightness < 0.24 then
                return sample:Lerp(COLORS.white, 0.55)
            end
            return sample
        end,
    }
end
