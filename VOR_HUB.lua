-- VOR Hub UI Template (VOR_HUB.lua)
-- Clean reusable interface framework only.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local SCRIPT_STARTED_AT = os.clock()

-- Masked, serialized tab transitions prevent overlapping cards, blank flashes, and mobile tap races.
-- Change these values to customize the hub and welcome screen.
local SETTINGS = {
    GuiName = "VORHub",
    Title = "VOR Hub",
    Discord = "discord.gg/w7gXUUZEp",
    DiscordInviteURL = "https://discord.gg/w7gXUUZEp",
    AccessKeyHash = 1961304013, -- FNV-1a hash of the current Discord key; the plain key is never shown in the hub.
    RememberKey = true,
    Creator = "Vor",
    IntroEnabled = true,
    IntroDuration = 5,
    IntroName = nil, -- nil uses the current Roblox username; example: "Quarter"
    IntroRole = nil, -- example: "Helper"
    IntroSoundEnabled = true,
    IntroSoundId = "rbxassetid://1085317309", -- Public two-second chime from the Creator Store.
    IntroSoundVolume = 0.32,
    IntroSoundPlaybackSpeed = 1,
    IntroPianoEnabled = true, -- Kept as the existing setting name so saved configs stay compatible.
    IntroPianoSoundId = "rbxassetid://9045935780", -- Ambient Creator Store music for the VOR intro.
    IntroPianoVolume = 0.52,
    IntroMusicDuration = 5, -- The music gets its own exact playback window.
    IntroPianoPlaybackSpeed = 1,
    IntroLogoSpinSpeed = 52, -- Degrees per second; positive values spin the floating blue spiral clockwise.
    MinimizedStyleDefault = "Minimize Bar", -- "Minimize Bar" or "Spiral Circle". Saved profiles can override this.
    MinimizedCircleSize = 66,
    MinimizedCircleSpinSpeed = 52,
    InterfaceSoundsEnabled = true,
    ToggleClickSoundId = "rbxasset://sounds/volume_slider.ogg",
    ToggleClickVolume = 0.24,
    ToggleOnPlaybackSpeed = 1.18,
    ToggleOffPlaybackSpeed = 0.88,
    HubVisibilitySoundId = "rbxasset://sounds/volume_slider.ogg",
    HubVisibilitySoundVolume = 0.30,
    HubOpenPlaybackSpeed = 1.42,
    HubClosePlaybackSpeed = 0.68,
    ToggleKey = Enum.KeyCode.RightControl,
    -- Keep the polished VOR shell, but avoid repeating expensive gradients,
    -- corner armor, strokes, and UIScale objects on every individual control.
    -- Large games such as Blox Fruits can expose hundreds of controls at once;
    -- a clean flat row treatment keeps the menu responsive when it opens.
    LightweightRendering = true,
    UIAnimationRate = 240,
    SnowEnabled = true,
    -- Keep the animated background lightweight. The old 52-label storm created
    -- 52 concurrent tweens (plus 52 glow images) whenever the hub opened.
    SnowflakeCount = 8,
    AvatarPreviewEnabled = true,
    PlayerHeadshotEnabled = true,
    -- The decal is currently restricted, so use its public thumbnail until Asset Access is set to Open Use.
    ProfileLogoImageId = "rbxthumb://type=Asset&id=151878913&w=420&h=420", -- Clear to restore the Roblox avatar.
    PanelBackgroundImageId = "rbxthumb://type=Asset&id=287316330&w=768&h=432",
    SectionBackgroundImageId = "rbxthumb://type=Asset&id=134413735110455&w=768&h=432",
    StatusBackgroundImageId = "rbxthumb://type=Asset&id=2847346557&w=768&h=432",
}

local PANEL_BACKGROUNDS = {
    ["VOR Void (287316330)"] = "rbxthumb://type=Asset&id=287316330&w=768&h=432",
    ["VOR Purple (13223834035)"] = "rbxthumb://type=Asset&id=13223834035&w=768&h=432",
}

-- Shared category art stays outside individual game builders so future supported
-- games can reuse a matching Revive tab decal instead of duplicating asset IDs.
local CATEGORY_DECALS = {
    Overnight = 13613618140,
    Combat = 105099599251617,
    Weapons = 95898332716312,
    Progress = 139818999438291,
    Visuals = 5676602141,
    Shooting = 14446878271,
    Player = 14442807051,
    Dribble = 133800751776369,
    Exploits = 166575196,
}

-- Add each new supported experience here. Universe matching keeps support active
-- across that experience's own teleport places without leaking into other games.
local SUPPORTED_GAMES = {
    Revive = {
        Key = "Revive",
        DisplayName = "+1 DMG Per Revive",
        UniverseId = 10171934713,
        RootPlaceId = 110806816173057,
        PlaceIds = {
            [110806816173057] = true,
        },
    },
    Basketball = {
        Key = "Basketball",
        DisplayName = "NEW MyPark",
        UniverseId = 4931927012,
        RootPlaceId = 14386691987,
        PlaceIds = {
            [14386691987] = true,
            [124914780116925] = true,
        },
    },
    AnimeExpeditions = {
        Key = "AnimeExpeditions",
        DisplayName = "Anime Expeditions",
        UniverseId = 7613921865,
        RootPlaceId = 84515722934860,
        PlaceIds = {
            [84515722934860] = true,
        },
    },
    BloxFruits = {
        Key = "BloxFruits",
        DisplayName = "Blox Fruits",
        UniverseId = 994732206,
        RootPlaceId = 2753915549,
        PlaceIds = {
            [2753915549] = true,
            [4442272183] = true,
            [7449423635] = true,
            [100117331123089] = true,
            [73902483975735] = true,
        },
    },
}

local function resolveGameSupport()
    for _, support in pairs(SUPPORTED_GAMES) do
        if game.GameId == support.UniverseId or support.PlaceIds[game.PlaceId] == true then
            return support
        end
    end
    return nil
end

local ACTIVE_GAME_SUPPORT = resolveGameSupport()
local BLOX_FRUITS_DUNGEON_PLACE_ID = 73902483975735
local IS_BLOX_FRUITS_DUNGEON = ACTIVE_GAME_SUPPORT
    and ACTIVE_GAME_SUPPORT.Key == "BloxFruits"
    and game.PlaceId == BLOX_FRUITS_DUNGEON_PLACE_ID

-- Optional game modules are fetched from the exact GitHub commit that is live
-- when the hub starts. Keeping large integrations separate prevents one game's
-- controls and runtime hooks from leaking into another supported experience.
local function loadVORGameModule(fileName)
    local repository = "swatdiaz/VOR-HUB"
    local commitApi = "https://api.github.com/repos/" .. repository .. "/commits/main"
    local metadata = HttpService:JSONDecode(game:HttpGet(commitApi))
    local commit = metadata and metadata.sha
    assert(type(commit) == "string" and #commit >= 7, "Could not resolve the current VOR Hub commit")

    local url = "https://raw.githubusercontent.com/" .. repository .. "/" .. commit .. "/" .. tostring(fileName)
    local source = game:HttpGet(url)
    local chunk, compileError = loadstring(source)
    assert(chunk, "VOR game module compile failed: " .. tostring(compileError))
    local module = chunk()
    assert(type(module) == "function", "VOR game module did not return a builder")
    return module
end

-- Profiles are isolated by VOR game support scope so one game's settings never
-- leak into another supported game.
-- Blox Fruits profiles use its UniverseId so the same setup follows the player between seas.
-- Every other integration remains isolated by PlaceId.
SETTINGS.IsBloxFruits = ACTIVE_GAME_SUPPORT and ACTIVE_GAME_SUPPORT.Key == "BloxFruits"
if SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering then
    -- Blox Fruits already has a large translucent HUD. Layering a second
    -- animated intro, particle storm, and many blended decals over it causes
    -- severe GPU overdraw on some clients. The VOR shell remains branded and
    -- purple, but this integration opens immediately in its lean presentation.
    SETTINGS.IntroEnabled = false
    SETTINGS.SnowEnabled = false
    -- Blox Fruits is the text-tab integration: keep its panel surfaces clean
    -- and opaque enough to avoid costly full-window image blending. Decals for
    -- Revive, Basketball, and other supported games remain unchanged.
    SETTINGS.PanelBackgroundImageId = ""
    SETTINGS.SectionBackgroundImageId = ""
    SETTINGS.StatusBackgroundImageId = ""
end
SETTINGS.ConfigScopeId = SETTINGS.IsBloxFruits and game.GameId or game.PlaceId
local CONFIG_ROOT = SETTINGS.IsBloxFruits
    and ("VORHub/Configs/" .. tostring(SETTINGS.ConfigScopeId))
    or ("VORHub/Configs/" .. tostring(SETTINGS.ConfigScopeId))
local PROFILE_FOLDER = CONFIG_ROOT .. "/Profiles"
local AUTOLOAD_FILE = CONFIG_ROOT .. "/autoload.json"
local ACCESS_FILE = "VORHub/Configs/access.json"

-- VOR identity: blackened metal, deep violet energy, and restrained silver highlights.
-- The legacy constant name remains so saved configurations and older helpers stay compatible.
local SNOW_WHITE = Color3.fromRGB(232, 228, 242)

local COLORS = {
    shell = Color3.fromRGB(10, 6, 18),
    sidebar = Color3.fromRGB(8, 5, 15),
    surface = Color3.fromRGB(18, 11, 31),
    surface2 = Color3.fromRGB(27, 17, 45),
    row = Color3.fromRGB(34, 22, 55),
    dropdown = Color3.fromRGB(22, 14, 38),
    line = Color3.fromRGB(112, 65, 181),
    text = Color3.fromRGB(242, 238, 248),
    muted = Color3.fromRGB(198, 187, 216),
    dim = Color3.fromRGB(151, 133, 177),
    accent = Color3.fromRGB(151, 70, 255),
    accentDark = Color3.fromRGB(77, 31, 137),
    offTrack = Color3.fromRGB(69, 58, 84),
    knob = SNOW_WHITE,
    success = Color3.fromRGB(105, 255, 191),
    error = Color3.fromRGB(255, 100, 151),
    sectionRow = Color3.fromRGB(9, 6, 17),
    sectionText = Color3.fromRGB(245, 240, 252),
    sectionMuted = Color3.fromRGB(199, 184, 222),
    sectionDim = Color3.fromRGB(145, 123, 174),
    sectionSuccess = Color3.fromRGB(119, 255, 199),
    sectionError = Color3.fromRGB(255, 139, 177),
    toggleOn = Color3.fromRGB(126, 45, 255),
    toggleOnBright = Color3.fromRGB(201, 99, 255),
    toggleOnStroke = Color3.fromRGB(225, 176, 255),
}

local UI_FONT = Enum.Font.GothamBold
local hubTransparencyValue = SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering and 0.02 or 0.24

local function create(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = property == "Font" and UI_FONT or value
    end
    if SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering then
        if object:IsA("UIGradient") or object:IsA("UIStroke") then
            object.Enabled = false
        end
    end
    object.Parent = parent
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 5),
    }, parent)
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", {
        Color = color or COLORS.line,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, parent)
end

-- Shared VOR armor treatment. Applying this at the component-constructor level
-- keeps every supported game visually consistent without touching its controls.
local function addVorTrim(parent, radius, innerInset, outerTransparency)
    local outerStroke = addStroke(
        parent,
        SETTINGS.LightweightRendering and COLORS.accentDark or Color3.fromRGB(59, 43, 76),
        SETTINGS.LightweightRendering and 1.25 or 2.2,
        SETTINGS.LightweightRendering and math.max(outerTransparency or 0.10, 0.18) or (outerTransparency or 0.10)
    )
    outerStroke.LineJoinMode = Enum.LineJoinMode.Miter
    if SETTINGS.LightweightRendering then
        return outerStroke, nil, nil
    end
    create("UIGradient", {
        Name = "VorMetalEdge",
        Rotation = 24,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(28, 24, 38)),
            ColorSequenceKeypoint.new(0.20, Color3.fromRGB(205, 191, 222)),
            ColorSequenceKeypoint.new(0.42, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.68, COLORS.toggleOnBright),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(35, 27, 48)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.22),
            NumberSequenceKeypoint.new(0.35, 0.04),
            NumberSequenceKeypoint.new(0.70, 0.14),
            NumberSequenceKeypoint.new(1.00, 0.26),
        }),
    }, outerStroke)

    local inset = innerInset or 3
    local overlayZ = 4
    pcall(function()
        overlayZ = parent.ZIndex + 2
    end)
    local inner = create("Frame", {
        Name = "VorInnerTrim",
        Active = false,
        Position = UDim2.fromOffset(inset, inset),
        Size = UDim2.new(1, -(inset * 2), 1, -(inset * 2)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = overlayZ,
    }, parent)
    addCorner(inner, math.max(2, (radius or 8) - inset))
    local innerStroke = addStroke(inner, COLORS.accent, 1, 0.48)
    innerStroke.LineJoinMode = Enum.LineJoinMode.Miter
    return outerStroke, innerStroke, inner
end

local function addVorCornerArmor(parent, inset, size, transparency)
    if SETTINGS.LightweightRendering then
        return
    end
    local offset = inset or 5
    local span = size or 17
    local alpha = transparency or 0.08
    local baseZ = 6
    pcall(function()
        baseZ = parent.ZIndex + 3
    end)
    local corners = {
        {Name = "TL", Position = UDim2.fromOffset(offset, offset), Anchor = Vector2.new(0, 0), H = 0, V = 0},
        {Name = "TR", Position = UDim2.new(1, -offset, 0, offset), Anchor = Vector2.new(1, 0), H = 1, V = 0},
        {Name = "BL", Position = UDim2.new(0, offset, 1, -offset), Anchor = Vector2.new(0, 1), H = 0, V = 1},
        {Name = "BR", Position = UDim2.new(1, -offset, 1, -offset), Anchor = Vector2.new(1, 1), H = 1, V = 1},
    }
    for _, data in ipairs(corners) do
        local holder = create("Frame", {
            Name = "VorCorner" .. data.Name,
            Active = false,
            AnchorPoint = data.Anchor,
            Position = data.Position,
            Size = UDim2.fromOffset(span, span),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = baseZ,
        }, parent)
        create("Frame", {
            AnchorPoint = Vector2.new(data.H, data.V),
            Position = UDim2.fromScale(data.H, data.V),
            Size = UDim2.fromOffset(span, 2),
            BackgroundColor3 = COLORS.toggleOnBright,
            BackgroundTransparency = alpha,
            BorderSizePixel = 0,
            ZIndex = baseZ,
        }, holder)
        create("Frame", {
            AnchorPoint = Vector2.new(data.H, data.V),
            Position = UDim2.fromScale(data.H, data.V),
            Size = UDim2.fromOffset(2, span),
            BackgroundColor3 = COLORS.toggleOnBright,
            BackgroundTransparency = alpha,
            BorderSizePixel = 0,
            ZIndex = baseZ,
        }, holder)
        local jewel = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(data.H, data.V),
            Size = UDim2.fromOffset(5, 5),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = math.min(0.52, alpha + 0.12),
            BorderSizePixel = 0,
            Rotation = 45,
            ZIndex = baseZ + 1,
        }, holder)
        addCorner(jewel, 1)
    end
end

local function makeLabel(parent, text, position, size, color, textSize, font)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        Font = font or Enum.Font.GothamMedium,
        Text = text or "",
        TextColor3 = color or COLORS.text,
        TextSize = textSize or 14,
        TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
    if parent and parent:FindFirstAncestor("SectionCard") then
        local adapting = false
        local function adaptSectionColor()
            if adapting or not label.Parent then
                return
            end
            local current = label.TextColor3
            local replacement = current == COLORS.text and COLORS.sectionText
                or (current == COLORS.muted and COLORS.sectionMuted)
                or (current == COLORS.dim and COLORS.sectionDim)
                or (current == COLORS.success and COLORS.sectionSuccess)
                or (current == COLORS.error and COLORS.sectionError)
                or nil
            if replacement and current ~= replacement then
                adapting = true
                label.TextColor3 = replacement
                adapting = false
            end
        end
        label.TextStrokeColor3 = Color3.fromRGB(2, 10, 18)
        label.TextStrokeTransparency = 0.52
        adaptSectionColor()
        label:GetPropertyChangedSignal("TextColor3"):Connect(adaptSectionColor)
    end
    return label
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local ok, message = xpcall(callback, debug.traceback, ...)
    if not ok then
        warn("[VOR Hub] Callback error: " .. tostring(message))
    end
end

-- Executor compatibility: prefer an executor-owned UI container when one is
-- available, then fall back to CoreGui and finally PlayerGui.
local function parentScreenGui(screenGui)
    local huiOk, hui = pcall(function()
        return gethui()
    end)
    if huiOk and typeof(hui) == "Instance" then
        local parented = pcall(function()
            screenGui.Parent = hui
        end)
        if parented then
            return
        end
    end
    local coreOk = pcall(function()
        screenGui.Parent = game:GetService("CoreGui")
    end)
    if not coreOk then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end

local function destroyOldGui()
    local containers = {}
    pcall(function()
        table.insert(containers, game:GetService("CoreGui"))
    end)
    pcall(function()
        local hui = gethui()
        if hui and not table.find(containers, hui) then
            table.insert(containers, hui)
        end
    end)
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui and not table.find(containers, playerGui) then
        table.insert(containers, playerGui)
    end

    local guiNames = {
        SETTINGS.GuiName,
        SETTINGS.GuiName .. "_Snow",
        SETTINGS.GuiName .. "_Notifications",
        SETTINGS.GuiName .. "_Status",
        -- One-time cleanup compatibility for builds published before the VOR
        -- rebrand. These names are never created by the current hub.
        "CodexHub",
        "CodexHub_Snow",
        "CodexHub_Notifications",
        "CodexHub_Status",
    }
    for _, guiName in ipairs(guiNames) do
        for _, container in ipairs(containers) do
            while true do
                local oldGui = container:FindFirstChild(guiName)
                if not oldGui then
                    break
                end
                oldGui:Destroy()
            end
        end
    end
    for _, musicName in ipairs({"VORHubMusic", "CodexHubMusic"}) do
        local oldMusic = SoundService:FindFirstChild(musicName)
        if oldMusic then
            oldMusic:Stop()
            oldMusic:Destroy()
        end
    end
end

destroyOldGui()

local connections = {}
local function track(connection)
    table.insert(connections, connection)
    return connection
end

-- Shared motion primitives keep every control consistent. Short Quint/Back tweens
-- mirror the responsive reference library without turning the interface into noise.
local activeTweens = setmetatable({}, {__mode = "k"})
local function fluidTween(object, duration, properties, style, direction)
    if not object or not object.Parent then
        return nil
    end
    local previous = activeTweens[object]
    if previous then
        pcall(function()
            previous:Cancel()
        end)
    end
    local tween = TweenService:Create(
        object,
        TweenInfo.new(
            duration or 0.18,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        properties
    )
    activeTweens[object] = tween
    tween:Play()
    task.delay((duration or 0.18) + 0.04, function()
        if activeTweens[object] == tween then
            activeTweens[object] = nil
        end
    end)
    return tween
end

local function attachFluidScale(button, visual, hoverScale, pressedScale)
    if SETTINGS.LightweightRendering then
        return nil
    end
    visual = visual or button
    local scale = visual:FindFirstChild("FluidInteractionScale")
    if not scale then
        scale = create("UIScale", {Name = "FluidInteractionScale", Scale = 1}, visual)
    end
    local hovering = false
    track(button.MouseEnter:Connect(function()
        hovering = true
        fluidTween(scale, 0.18, {Scale = hoverScale or 1.018}, Enum.EasingStyle.Quint)
    end))
    track(button.MouseLeave:Connect(function()
        hovering = false
        fluidTween(scale, 0.20, {Scale = 1}, Enum.EasingStyle.Quint)
    end))
    track(button.MouseButton1Down:Connect(function()
        fluidTween(scale, 0.08, {Scale = pressedScale or 0.985}, Enum.EasingStyle.Quad)
    end))
    track(button.MouseButton1Up:Connect(function()
        fluidTween(scale, 0.20, {Scale = hovering and (hoverScale or 1.018) or 1}, Enum.EasingStyle.Back)
    end))
    return scale
end

local function attachPressRipple(button, surface)
    if SETTINGS.LightweightRendering then
        return
    end
    surface = surface or button
    surface.ClipsDescendants = true
    track(button.MouseButton1Down:Connect(function(x, y)
        if not surface.Parent then
            return
        end
        local diameter = math.max(surface.AbsoluteSize.X, surface.AbsoluteSize.Y) * 1.8
        local ripple = create("Frame", {
            Name = "PressRipple",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(x - surface.AbsolutePosition.X, y - surface.AbsolutePosition.Y),
            Size = UDim2.fromOffset(0, 0),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.50,
            BorderSizePixel = 0,
            ZIndex = math.max(1, button.ZIndex - 1),
        }, surface)
        addCorner(ripple, 999)
        fluidTween(ripple, 0.34, {
            Size = UDim2.fromOffset(diameter, diameter),
            BackgroundTransparency = 1,
        }, Enum.EasingStyle.Quint)
        task.delay(0.38, function()
            if ripple.Parent then
                ripple:Destroy()
            end
        end)
    end))
end

local gui = create("ScreenGui", {
    Name = SETTINGS.GuiName,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1000,
}, nil)

parentScreenGui(gui)

local toggleClickSound = create("Sound", {
    Name = "VORToggleClick",
    SoundId = SETTINGS.ToggleClickSoundId,
    Volume = 0,
    PlaybackSpeed = SETTINGS.ToggleOnPlaybackSpeed,
    Looped = false,
    PlayOnRemove = false,
}, gui)

local function playToggleClick(enabled)
    if not SETTINGS.InterfaceSoundsEnabled or tostring(SETTINGS.ToggleClickSoundId or "") == "" then
        return
    end

    pcall(function()
        toggleClickSound:Stop()
        toggleClickSound.TimePosition = 0
        toggleClickSound.SoundId = tostring(SETTINGS.ToggleClickSoundId)
        toggleClickSound.Volume = math.clamp(tonumber(SETTINGS.ToggleClickVolume) or 0.24, 0, 1)
        toggleClickSound.PlaybackSpeed = math.clamp(
            tonumber(enabled and SETTINGS.ToggleOnPlaybackSpeed or SETTINGS.ToggleOffPlaybackSpeed) or 1,
            0.25,
            3
        )
        toggleClickSound:Play()
    end)
end

local hubVisibilitySound = create("Sound", {
    Name = "VORHubVisibilitySound",
    SoundId = SETTINGS.HubVisibilitySoundId,
    Volume = 0,
    PlaybackSpeed = SETTINGS.HubOpenPlaybackSpeed,
    Looped = false,
    PlayOnRemove = false,
}, gui)

local function playHubVisibilitySound(opening)
    if not SETTINGS.InterfaceSoundsEnabled or tostring(SETTINGS.HubVisibilitySoundId or "") == "" then
        return
    end

    pcall(function()
        hubVisibilitySound:Stop()
        hubVisibilitySound.TimePosition = 0
        hubVisibilitySound.SoundId = tostring(SETTINGS.HubVisibilitySoundId)
        hubVisibilitySound.Volume = math.clamp(tonumber(SETTINGS.HubVisibilitySoundVolume) or 0.30, 0, 1)
        hubVisibilitySound.PlaybackSpeed = math.clamp(
            tonumber(opening and SETTINGS.HubOpenPlaybackSpeed or SETTINGS.HubClosePlaybackSpeed) or 1,
            0.25,
            3
        )
        hubVisibilitySound:Play()
    end)
end

local hubMusic = create("Sound", {
    Name = "VORHubMusic",
    SoundId = tostring(SETTINGS.IntroPianoSoundId or ""),
    Volume = 0,
    PlaybackSpeed = math.clamp(tonumber(SETTINGS.IntroPianoPlaybackSpeed) or 1, 0.25, 3),
    Looped = true,
    PlayOnRemove = false,
}, SoundService)
local hubMusicTween = nil
local hubMusicVisibilityToken = 0

task.spawn(function()
    local ok = pcall(function()
        ContentProvider:PreloadAsync({hubMusic})
    end)
    SETTINGS.HubMusicPreloaded = ok
    gui:SetAttribute("HubMusicPreloaded", ok)
end)

local function setHubMusicVisible(visible, restart)
    if not SETTINGS.IntroPianoEnabled or tostring(SETTINGS.IntroPianoSoundId or "") == "" or not hubMusic.Parent then
        return
    end
    hubMusicVisibilityToken += 1
    local token = hubMusicVisibilityToken
    if hubMusicTween then
        hubMusicTween:Cancel()
        hubMusicTween = nil
    end

    if visible then
        if restart then
            hubMusic.TimePosition = 0
        end
        if not hubMusic.IsPlaying then
            pcall(function()
                hubMusic:Resume()
            end)
            if not hubMusic.IsPlaying then
                hubMusic:Play()
            end
        end
        hubMusicTween = TweenService:Create(hubMusic, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Volume = math.clamp(tonumber(SETTINGS.IntroPianoVolume) or 0.52, 0, 1),
        })
        hubMusicTween:Play()
        gui:SetAttribute("HubMusicVisible", true)
        gui:SetAttribute("HubMusicPlaying", hubMusic.IsPlaying)
    else
        hubMusicTween = TweenService:Create(hubMusic, TweenInfo.new(0.40, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Volume = 0,
        })
        hubMusicTween:Play()
        gui:SetAttribute("HubMusicVisible", false)
        task.delay(0.42, function()
            if token == hubMusicVisibilityToken and hubMusic.Parent then
                hubMusic:Pause()
                gui:SetAttribute("HubMusicPlaying", false)
            end
        end)
    end
end

local snowGui = create("ScreenGui", {
    Name = SETTINGS.GuiName .. "_Snow",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    -- The intro owns the screen during startup; do not run a second particle
    -- storm underneath it. Global particles resume after the intro finishes.
    Enabled = SETTINGS.SnowEnabled and not SETTINGS.IntroEnabled,
}, gui.Parent)

local snowLayer = create("Frame", {
    Name = "SnowLayer",
    Active = false,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, snowGui)

local main = create("Frame", {
    Name = "VORHub",
    Active = true,
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(850, 560),
    BackgroundColor3 = COLORS.shell,
    BackgroundTransparency = hubTransparencyValue,
    BorderSizePixel = 0,
    ClipsDescendants = false,
}, gui)
addCorner(main, 8)
do
    local outerStroke = addStroke(main, COLORS.accentDark, 3, 0.02)
    outerStroke.LineJoinMode = Enum.LineJoinMode.Miter
    create("UIGradient", {
        Name = "ContinuousIceBorder",
        Rotation = 22,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.24, SNOW_WHITE),
            ColorSequenceKeypoint.new(0.52, COLORS.accent),
            ColorSequenceKeypoint.new(0.78, SNOW_WHITE),
            ColorSequenceKeypoint.new(1.00, COLORS.accentDark),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.08),
            NumberSequenceKeypoint.new(0.50, 0.28),
            NumberSequenceKeypoint.new(1.00, 0.08),
        }),
    }, outerStroke)
end
do
    local armorGlow = create("Frame", {
        Name = "VorArmorGlow",
        Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 18, 1, 18),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, main)
    addCorner(armorGlow, 12)
    local glowStroke = addStroke(armorGlow, COLORS.accent, 8, 0.72)
    glowStroke.LineJoinMode = Enum.LineJoinMode.Miter

    local armorPlate = create("Frame", {
        Name = "VorOuterArmor",
        Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 10, 1, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 88,
    }, main)
    addCorner(armorPlate, 10)
    addVorTrim(armorPlate, 10, 4, 0.02)
    addVorCornerArmor(armorPlate, 3, 24, 0.02)

    local topNotch = create("Frame", {
        Name = "VorTopNotch",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0, -5),
        Size = UDim2.fromOffset(34, 10),
        BackgroundColor3 = Color3.fromRGB(15, 8, 26),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Rotation = 0,
        ZIndex = 93,
    }, main)
    addCorner(topNotch, 2)
    addStroke(topNotch, COLORS.toggleOnBright, 1.4, 0.08)
    local notchJewel = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = COLORS.accent,
        BorderSizePixel = 0,
        Rotation = 45,
        ZIndex = 94,
    }, topNotch)
    addCorner(notchJewel, 1)
end
create("UIGradient", {
    Rotation = 28,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(5, 3, 11)),
        ColorSequenceKeypoint.new(0.48, Color3.fromRGB(20, 9, 34)),
        ColorSequenceKeypoint.new(0.72, Color3.fromRGB(34, 14, 54)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(8, 4, 16)),
    }),
}, main)

local panelBackground
if not (SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering) then
    panelBackground = create("ImageLabel", {
        Name = "PanelBackground",
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = SETTINGS.PanelBackgroundImageId,
        ImageColor3 = Color3.fromRGB(78, 38, 120),
        ImageTransparency = 0.62,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 1,
    }, main)
    addCorner(panelBackground, 7)
    create("UIGradient", {
        Name = "PanelImageVorFade",
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(126, 71, 177)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(75, 34, 116)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(31, 13, 50)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.16),
            NumberSequenceKeypoint.new(0.46, 0.30),
            NumberSequenceKeypoint.new(1.00, 0.18),
        }),
    }, panelBackground)
end

local HUB_DESIGN_SIZE = Vector2.new(850, 560)
local HUB_MIN_SCALE = 0.32
local HUB_EDGE_PADDING = 12

-- Viewport fitting and open/close animation must remain separate. The old
-- version animated the responsive UIScale back to 1, which made the desktop
-- size return after the intro, minimize button, or visibility toggle on mobile.
local uiScale = create("UIScale", {Name = "ResponsiveViewportScale", Scale = 1}, main)
local uiScaleAnimation = create("NumberValue", {
    Name = "ResponsiveAnimationFactor",
    Value = 1,
}, main)
local responsiveViewportScale = 1

local function getSafeViewportBounds()
    local camera = workspace.CurrentCamera
    if not camera then
        return nil
    end

    local viewport = camera.ViewportSize
    local topLeftInset = Vector2.new(0, 0)
    local bottomRightInset = Vector2.new(0, 0)
    pcall(function()
        topLeftInset, bottomRightInset = GuiService:GetGuiInset()
    end)

    -- Some mobile executors do not report rounded-corner/device cutout insets.
    local touchEdge = UserInputService.TouchEnabled and HUB_EDGE_PADDING or 0
    return viewport,
        math.max(0, topLeftInset.X) + touchEdge,
        math.max(0, topLeftInset.Y) + touchEdge,
        math.max(0, bottomRightInset.X) + touchEdge,
        math.max(0, bottomRightInset.Y) + touchEdge
end

local function applyMainScale()
    uiScale.Scale = responsiveViewportScale * math.max(0.01, uiScaleAnimation.Value)
end

track(uiScaleAnimation:GetPropertyChangedSignal("Value"):Connect(applyMainScale))
applyMainScale()

local MINIMIZE_BAR_STYLE = "Minimize Bar"
local MINIMIZE_CIRCLE_STYLE = "Spiral Circle"
local minimizedStyle = SETTINGS.MinimizedStyleDefault == MINIMIZE_CIRCLE_STYLE
    and MINIMIZE_CIRCLE_STYLE
    or MINIMIZE_BAR_STYLE

local function normalizeMinimizeStyle(value)
    local text = string.lower(tostring(value or ""))
    if string.find(text, "circle", 1, true) or string.find(text, "spiral", 1, true) then
        return MINIMIZE_CIRCLE_STYLE
    end
    return MINIMIZE_BAR_STYLE
end

-- Optional compact restore button. It is separate from the main window so the
-- desktop/mobile responsive scale cannot stretch the circle or make it oval.
local minimizedCircle = create("CanvasGroup", {
    Name = "VorMinimizedCircle",
    Active = true,
    Visible = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(SETTINGS.MinimizedCircleSize, SETTINGS.MinimizedCircleSize),
    BackgroundColor3 = COLORS.shell,
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    GroupTransparency = 1,
    ClipsDescendants = false,
    ZIndex = 260,
}, gui)
addCorner(minimizedCircle, math.floor(SETTINGS.MinimizedCircleSize * 0.5))
local minimizedCircleStroke = addStroke(minimizedCircle, COLORS.accent, 2.2, 0.04)
minimizedCircleStroke.LineJoinMode = Enum.LineJoinMode.Round

local minimizedCircleGlow = create("Frame", {
    Name = "CircleGlow",
    Active = false,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, 12, 1, 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 259,
}, minimizedCircle)
addCorner(minimizedCircleGlow, math.floor((SETTINGS.MinimizedCircleSize + 12) * 0.5))
addStroke(minimizedCircleGlow, COLORS.accent, 7, 0.72)

local minimizedCircleScale = create("UIScale", {
    Name = "CircleAnimationScale",
    Scale = 0.72,
}, minimizedCircle)

local minimizedCircleLogo = create("ImageLabel", {
    Name = "SpinningSpiral",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(1, -12, 1, -12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = tostring(SETTINGS.ProfileLogoImageId or ""),
    ImageTransparency = 0,
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 262,
}, minimizedCircle)

local minimizedCircleHitbox = create("TextButton", {
    Name = "RestoreHitbox",
    Active = true,
    AutoButtonColor = false,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    ZIndex = 264,
}, minimizedCircle)

track(RunService.RenderStepped:Connect(function(deltaTime)
    if minimizedCircle.Visible then
        local spinSpeed = math.max(0, tonumber(SETTINGS.MinimizedCircleSpinSpeed) or 52)
        minimizedCircleLogo.Rotation = (minimizedCircleLogo.Rotation + spinSpeed * deltaTime) % 360
    end
end))

local icicleLayer = create("Frame", {
    Name = "FrozenOuterEdge",
    Active = false,
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    ZIndex = 80,
}, main)

do
    local function makeIcicle(index, xScale, yScale, width, height)
        local icicle = create("Frame", {
            Name = "Icicle" .. tostring(index),
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(xScale, 0, yScale, -1),
            Size = SETTINGS.LightweightRendering
                and UDim2.fromOffset(math.max(4, width), math.max(7, height))
                or UDim2.fromOffset(width + 10, height + 8),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = SETTINGS.LightweightRendering and 0.18 or 1,
            BorderSizePixel = 0,
            ZIndex = 82,
        }, icicleLayer)

        if SETTINGS.LightweightRendering then
            addCorner(icicle, math.max(2, math.floor(width * 0.42)))
            return
        end

        local glow = create("Frame", {
            Name = "SoftGlow",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(width + 4, math.max(7, height - 5)),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.76,
            BorderSizePixel = 0,
            ZIndex = 81,
        }, icicle)
        addCorner(glow, math.max(3, math.floor(width * 0.5)))

        local body = create("Frame", {
            Name = "CrystalBody",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(width, math.max(6, math.floor(height * 0.58))),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.06,
            BorderSizePixel = 0,
            ZIndex = 82,
        }, icicle)
        addCorner(body, math.max(3, math.floor(width * 0.46)))
        create("UIGradient", {
            Name = "FrozenAccentGradient",
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, COLORS.toggleOnBright),
                ColorSequenceKeypoint.new(0.58, COLORS.accent),
                ColorSequenceKeypoint.new(1.00, COLORS.accentDark),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.02),
                NumberSequenceKeypoint.new(0.72, 0.20),
                NumberSequenceKeypoint.new(1.00, 0.38),
            }),
        }, body)

        local taper = create("Frame", {
            Name = "CrystalTaper",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, math.floor(height * 0.46)),
            Size = UDim2.fromOffset(math.max(4, math.floor(width * 0.62)), math.max(7, math.floor(height * 0.43))),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.10,
            BorderSizePixel = 0,
            ZIndex = 83,
        }, icicle)
        addCorner(taper, math.max(2, math.floor(width * 0.32)))

        local tipSize = math.max(4, math.floor(width * 0.52))
        local tip = create("Frame", {
            Name = "CrystalPoint",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, height - 2),
            Size = UDim2.fromOffset(tipSize, tipSize),
            BackgroundColor3 = COLORS.accentDark,
            BackgroundTransparency = 0.16,
            BorderSizePixel = 0,
            Rotation = 45,
            ZIndex = 84,
        }, icicle)
        addCorner(tip, math.max(1, math.floor(tipSize * 0.22)))

        local highlight = create("Frame", {
            Name = "IceHighlight",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, -math.max(1, math.floor(width * 0.18)), 0, 2),
            Size = UDim2.fromOffset(math.max(1, math.floor(width * 0.18)), math.max(4, math.floor(height * 0.30))),
            BackgroundColor3 = COLORS.toggleOnBright,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            ZIndex = 85,
        }, icicle)
        addCorner(highlight, 4)
    end

    local iceRandom = Random.new(20260721)
    if not (SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering) then
        for index = 1, 13 do
            local evenPosition = (index - 0.5) / 13
            local xScale = math.clamp(evenPosition + iceRandom:NextNumber(-0.024, 0.024), 0.040, 0.960)
            makeIcicle(index, xScale, 1, iceRandom:NextInteger(5, 9), iceRandom:NextInteger(13, 36))
        end

        local topPositions = {0.075, 0.115, 0.165, 0.835, 0.885, 0.925}
        for index, xScale in ipairs(topPositions) do
            makeIcicle(13 + index, xScale, 0, iceRandom:NextInteger(5, 8), iceRandom:NextInteger(9, 20))
        end
    end

    local function makeSideCrystal(index, side, yScale, scale)
        if SETTINGS.LightweightRendering then
            return
        end
        local leftSide = side == "Left"
        local holder = create("Frame", {
            Name = side .. "CrystalCluster" .. tostring(index),
            Active = false,
            AnchorPoint = Vector2.new(leftSide and 1 or 0, 0.5),
            Position = UDim2.new(leftSide and 0 or 1, leftSide and -5 or 5, yScale, 0),
            Size = UDim2.fromOffset(42 * scale, 82 * scale),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 86,
        }, icicleLayer)
        local direction = leftSide and -1 or 1
        for shardIndex = 1, 3 do
            local shardHeight = (30 + shardIndex * 9) * scale
            local shard = create("Frame", {
                Name = "Shard" .. shardIndex,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(
                    0.5,
                    direction * (3 + shardIndex * 3) * scale,
                    0.5,
                    (shardIndex - 2) * 15 * scale
                ),
                Size = UDim2.fromOffset((7 + shardIndex) * scale, shardHeight),
                BackgroundColor3 = shardIndex == 2 and COLORS.toggleOnBright or COLORS.accent,
                BackgroundTransparency = 0.06 + shardIndex * 0.04,
                BorderSizePixel = 0,
                Rotation = direction * (25 + shardIndex * 7),
                ZIndex = 88 + shardIndex,
            }, holder)
            addCorner(shard, 2)
            addStroke(shard, Color3.fromRGB(224, 181, 255), 1, 0.22)
            create("UIGradient", {
                Name = "VorCrystalFacet",
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(235, 207, 255)),
                    ColorSequenceKeypoint.new(0.35, COLORS.accent),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(43, 11, 82)),
                }),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0.00, 0.02),
                    NumberSequenceKeypoint.new(1.00, 0.30),
                }),
            }, shard)
        end
        local core = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(13 * scale, 13 * scale),
            BackgroundColor3 = COLORS.accentDark,
            BorderSizePixel = 0,
            Rotation = 45,
            ZIndex = 92,
        }, holder)
        addCorner(core, 2)
        addStroke(core, COLORS.toggleOnBright, 1, 0.04)
    end

    local sidePositions = {0.16, 0.34, 0.66, 0.84}
    for index, yScale in ipairs(sidePositions) do
        local scale = index % 2 == 0 and 0.76 or 1
        makeSideCrystal(index, "Left", yScale, scale)
        makeSideCrystal(index, "Right", yScale, scale)
    end
end

local header = create("Frame", {
    Name = "Header",
    Active = true,
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = COLORS.sidebar,
    BackgroundTransparency = 0.30,
    BorderSizePixel = 0,
    ZIndex = 20,
}, main)
addCorner(header, 7)
addVorTrim(header, 7, 3, 0.08)
addVorCornerArmor(header, 5, 14, 0.28)
create("UIGradient", {
    Rotation = 0,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(14, 8, 25)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(38, 16, 61)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(14, 7, 27)),
    }),
}, header)
do
    local headerJoin = create("Frame", {
        Name = "HeaderSquareJoin",
        Position = UDim2.new(0, 0, 1, -12),
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = COLORS.sidebar,
        BackgroundTransparency = 0.30,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, header)
    create("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(14, 8, 25)),
            ColorSequenceKeypoint.new(0.55, Color3.fromRGB(38, 16, 61)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(14, 7, 27)),
        }),
    }, headerJoin)
end

local brandLogo = create("Frame", {
    Name = "VORLogo",
    Position = UDim2.fromOffset(13, 10),
    Size = UDim2.fromOffset(26, 26),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 21,
}, header)

-- Asset-free VOR energy knot: six interlocking violet bars arranged as a pinwheel.
for segmentIndex = 1, 6 do
    local angle = math.rad((segmentIndex - 1) * 60)
    local segment = create("Frame", {
        Name = "KnotSegment" .. segmentIndex,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(13 + math.cos(angle) * 5.2, 13 + math.sin(angle) * 5.2),
        Size = UDim2.fromOffset(11, 4),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Rotation = math.deg(angle) + 34,
        ZIndex = 22,
    }, brandLogo)
    addCorner(segment, 2)
    create("UIGradient", {
        Name = "FrozenAccentGradient",
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.52, COLORS.accent),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(226, 201, 255)),
        }),
    }, segment)
end

local knotCore = create("Frame", {
    Name = "KnotCore",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(6, 6),
    BackgroundColor3 = Color3.fromRGB(213, 192, 235),
    BorderSizePixel = 0,
    Rotation = 45,
    ZIndex = 23,
}, brandLogo)
addCorner(knotCore, 2)
addStroke(knotCore, COLORS.accent, 1, 0.15)

local brandTitle = makeLabel(
    header,
    SETTINGS.Title,
    UDim2.fromOffset(47, 0),
    UDim2.fromOffset(105, 46),
    COLORS.text,
    15,
    Enum.Font.GothamSemibold
)
brandTitle.TextTruncate = Enum.TextTruncate.AtEnd
brandTitle.ZIndex = 21

local brandSubtitle = makeLabel(
    header,
    SETTINGS.Discord,
    UDim2.fromOffset(153, 1),
    UDim2.fromOffset(185, 44),
    COLORS.dim,
    11,
    Enum.Font.GothamMedium
)
brandSubtitle.ZIndex = 21

local minimizeButton = create("TextButton", {
    Name = "Minimize",
    AutoButtonColor = false,
    Position = UDim2.new(1, -76, 0, 7),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = COLORS.surface2,
    BackgroundTransparency = 0.38,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = COLORS.muted,
    TextSize = 20,
    ZIndex = 22,
}, header)
addCorner(minimizeButton, 8)
addVorTrim(minimizeButton, 8, 2, 0.18)

local closeButton = create("TextButton", {
    Name = "Close",
    AutoButtonColor = false,
    Position = UDim2.new(1, -40, 0, 7),
    Size = UDim2.fromOffset(32, 32),
    BackgroundColor3 = COLORS.surface2,
    BackgroundTransparency = 0.38,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "x",
    TextColor3 = COLORS.muted,
    TextSize = 17,
    ZIndex = 22,
}, header)
addCorner(closeButton, 8)
addVorTrim(closeButton, 8, 2, 0.18)

local sidebar = create("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(0, 46),
    Size = UDim2.new(0, 62, 1, -46),
    BackgroundColor3 = COLORS.sidebar,
    BackgroundTransparency = 0.36,
    BorderSizePixel = 0,
}, main)
addCorner(sidebar, 7)
addVorTrim(sidebar, 7, 3, 0.12)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(17, 9, 29)),
        ColorSequenceKeypoint.new(0.58, Color3.fromRGB(10, 6, 18)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 12, 45)),
    }),
}, sidebar)
do
    local sidebarTopJoin = create("Frame", {
        Name = "SidebarTopJoin",
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = COLORS.sidebar,
        BackgroundTransparency = 0.36,
        BorderSizePixel = 0,
    }, sidebar)
    local sidebarRightJoin = create("Frame", {
        Name = "SidebarRightJoin",
        Position = UDim2.new(1, -10, 0, 0),
        Size = UDim2.new(0, 10, 1, 0),
        BackgroundColor3 = COLORS.sidebar,
        BackgroundTransparency = 0.36,
        BorderSizePixel = 0,
    }, sidebar)
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(17, 9, 29)),
            ColorSequenceKeypoint.new(0.58, Color3.fromRGB(10, 6, 18)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(28, 12, 45)),
        }),
    }, sidebarRightJoin)
    sidebarTopJoin.ZIndex = sidebarRightJoin.ZIndex
end

create("Frame", {
    Position = UDim2.fromOffset(62, 46),
    Size = UDim2.new(0, 1, 1, -46),
    BackgroundColor3 = COLORS.line,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
}, main)

local contentBackdrop = create("Frame", {
    Name = "ConceptInterior",
    Position = UDim2.fromOffset(63, 46),
    Size = UDim2.new(1, -63, 1, -46),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.40,
    BorderSizePixel = 0,
    ZIndex = 1,
}, main)
addCorner(contentBackdrop, 7)
addVorTrim(contentBackdrop, 7, 4, 0.20)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(9, 5, 17)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(22, 10, 36)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(36, 14, 56)),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.08),
        NumberSequenceKeypoint.new(1.00, 0.30),
    }),
}, contentBackdrop)
do
    local function styleContentJoin(join)
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(9, 5, 17)),
                ColorSequenceKeypoint.new(0.55, Color3.fromRGB(22, 10, 36)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(36, 14, 56)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.08),
                NumberSequenceKeypoint.new(1.00, 0.30),
            }),
        }, join)
    end
    local contentTopJoin = create("Frame", {
        Name = "ContentTopJoin",
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = 0.40,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, contentBackdrop)
    local contentLeftJoin = create("Frame", {
        Name = "ContentLeftJoin",
        Size = UDim2.new(0, 12, 1, 0),
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = 0.40,
        BorderSizePixel = 0,
        ZIndex = 1,
    }, contentBackdrop)
    styleContentJoin(contentTopJoin)
    styleContentJoin(contentLeftJoin)
end

local featuresLabel = makeLabel(sidebar, "", UDim2.fromOffset(0, 0), UDim2.fromOffset(1, 1), COLORS.dim, 10, Enum.Font.GothamBold)
featuresLabel.Visible = false

local navHolder = create("ScrollingFrame", {
    Name = "Navigation",
    Position = UDim2.fromOffset(7, 10),
    Size = UDim2.new(0, 48, 1, -72),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = COLORS.accentDark,
}, sidebar)
create("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, navHolder)

local avatarCard = create("Frame", {
    Name = "FloatingAvatarCard",
    Position = UDim2.fromOffset(76, 61),
    Size = UDim2.fromOffset(76, 76),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.34,
    BorderSizePixel = 0,
    ClipsDescendants = false,
    Visible = SETTINGS.AvatarPreviewEnabled,
    ZIndex = 5,
}, main)
addCorner(avatarCard, 8)
addVorTrim(avatarCard, 8, 3, 0.12)
addVorCornerArmor(avatarCard, 4, 12, 0.28)
create("UIGradient", {
    Rotation = 90,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(40, 19, 64)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(18, 10, 31)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(60, 24, 92)),
    }),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.18),
        NumberSequenceKeypoint.new(1.00, 0.48),
    }),
}, avatarCard)

local avatarGlow = create("Frame", {
    Name = "AvatarGlow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(68, 68),
    BackgroundColor3 = COLORS.accent,
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    ZIndex = 6,
}, avatarCard)
addCorner(avatarGlow, 999)
create("UIGradient", {
    Name = "FrozenAccentGradient",
    Rotation = 45,
    Color = ColorSequence.new(
        SNOW_WHITE,
        COLORS.accentDark
    ),
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0.00, 0.28),
        NumberSequenceKeypoint.new(0.62, 0.62),
        NumberSequenceKeypoint.new(1.00, 1.00),
    }),
}, avatarGlow)

local avatarImage = create("ImageLabel", {
    Name = "AvatarPicture",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 4),
    Size = UDim2.fromOffset(68, 68),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 7,
}, avatarCard)

local avatarName = makeLabel(
    avatarCard,
    "@" .. LocalPlayer.Name,
    UDim2.new(0, 8, 1, -28),
    UDim2.new(1, -16, 0, 20),
    COLORS.text,
    11,
    Enum.Font.GothamSemibold
)
avatarName.TextXAlignment = Enum.TextXAlignment.Center
avatarName.TextTruncate = Enum.TextTruncate.AtEnd
avatarName.ZIndex = 8
avatarName.Visible = false

local currentHour = tonumber(os.date("%H")) or 12
local greetingText = currentHour < 12 and "Good morning" or (currentHour < 18 and "Good afternoon" or "Good evening")
local welcomeCard = create("Frame", {
    Name = "VORWelcomeCard",
    Position = UDim2.fromOffset(162, 67),
    Size = UDim2.new(1, -178, 0, 64),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.30,
    BorderSizePixel = 0,
    ZIndex = 5,
}, main)
addCorner(welcomeCard, 7)
addVorTrim(welcomeCard, 7, 3, 0.06)
addVorCornerArmor(welcomeCard, 5, 15, 0.34)
create("UIGradient", {
    Rotation = 0,
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(31, 16, 51)),
        ColorSequenceKeypoint.new(0.62, Color3.fromRGB(18, 10, 31)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(52, 21, 79)),
    }),
}, welcomeCard)

local headshotCard = create("Frame", {
    Name = "PlayerHeadshotCard",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -7, 0.5, 0),
    Size = UDim2.fromOffset(52, 52),
    BackgroundColor3 = COLORS.row,
    BackgroundTransparency = 0.26,
    BorderSizePixel = 0,
    Visible = SETTINGS.PlayerHeadshotEnabled,
    ZIndex = 7,
}, welcomeCard)
addCorner(headshotCard, 9)
addStroke(headshotCard, COLORS.accentDark, 1, 0.22)

local headshotImage = create("ImageLabel", {
    Name = "PlayerMugshot",
    Position = UDim2.fromOffset(3, 3),
    Size = UDim2.new(1, -6, 1, -6),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "",
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 8,
}, headshotCard)
addCorner(headshotImage, 7)

local welcomeTitle = makeLabel(
    welcomeCard,
    greetingText .. ", " .. LocalPlayer.DisplayName,
    UDim2.fromOffset(14, 8),
    UDim2.new(1, -88, 0, 27),
    COLORS.text,
    16,
    Enum.Font.GothamBold
)
welcomeTitle.ZIndex = 7
local welcomeSubtitle = makeLabel(
    welcomeCard,
    SETTINGS.Title .. " | Loading Game... | " .. SETTINGS.Discord,
    UDim2.fromOffset(14, 33),
    UDim2.new(1, -88, 0, 20),
    COLORS.muted,
    12,
    Enum.Font.GothamMedium
)
welcomeSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
welcomeSubtitle.ZIndex = 7

local sidebarBrand = makeLabel(sidebar, SETTINGS.Title, UDim2.new(0, 16, 1, -54), UDim2.fromOffset(160, 20), COLORS.text, 13, Enum.Font.GothamSemibold)
local sidebarDiscord = makeLabel(sidebar, SETTINGS.Discord, UDim2.new(0, 16, 1, -34), UDim2.fromOffset(170, 18), COLORS.dim, 10, Enum.Font.GothamMedium)
sidebarBrand.Visible = false
sidebarDiscord.Visible = false

local searchFrame = create("Frame", {
    Name = "Search",
    Position = UDim2.fromOffset(350, 7),
    Size = UDim2.new(1, -465, 0, 32),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = 0.48,
    BorderSizePixel = 0,
    ZIndex = 25,
}, header)
addCorner(searchFrame, 8)
addVorTrim(searchFrame, 8, 2, 0.20)

local searchCircle = create("Frame", {
    Position = UDim2.fromOffset(13, 9),
    Size = UDim2.fromOffset(12, 12),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 26,
}, searchFrame)
addCorner(searchCircle, 7)
addStroke(searchCircle, COLORS.muted, 2, 0)

create("Frame", {
    Position = UDim2.fromOffset(23, 20),
    Size = UDim2.fromOffset(7, 2),
    Rotation = 45,
    BackgroundColor3 = COLORS.muted,
    BorderSizePixel = 0,
    ZIndex = 26,
}, searchFrame)

local searchBox = create("TextBox", {
    Name = "SearchBox",
    Position = UDim2.fromOffset(38, 0),
    Size = UDim2.new(1, -48, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamMedium,
    PlaceholderText = "Search..",
    PlaceholderColor3 = COLORS.muted,
    Text = "",
    TextColor3 = COLORS.text,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 26,
}, searchFrame)

local pageHolder = create("Frame", {
    Name = "Pages",
    Position = UDim2.fromOffset(76, 151),
    Size = UDim2.new(1, -92, 1, -167),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, main)


-- Complex CanvasGroup cross-fades can briefly stack text and controls on mobile.
-- A fast glass curtain covers the content for the exact frame in which pages swap,
-- then reveals the next page with a small directional slide. Only one transition
-- is allowed at a time, so rapid taps are queued instead of fighting each other.
local function makeTransitionCurtain(parent, name, position, size, zIndex)
    local curtain = create("CanvasGroup", {
        Name = name,
        Position = position,
        Size = size,
        BackgroundColor3 = Color3.fromRGB(7, 3, 14),
        BackgroundTransparency = 0.035,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        Visible = false,
        ZIndex = zIndex,
    }, parent)
    addCorner(curtain, 6)
    addStroke(curtain, COLORS.accentDark, 1, 0.58)
    create("UIGradient", {
        Rotation = 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(7, 3, 14)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(22, 8, 37)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(7, 3, 14)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.02),
            NumberSequenceKeypoint.new(0.50, 0.00),
            NumberSequenceKeypoint.new(1.00, 0.02),
        }),
    }, curtain)

    local sweep = create("Frame", {
        Name = "AccentSweep",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, -8, 0.5, 0),
        Size = UDim2.new(0, 3, 1, 20),
        BackgroundColor3 = COLORS.toggleOnBright,
        BackgroundTransparency = 1,
        Visible = false,
        BorderSizePixel = 0,
        ZIndex = zIndex + 2,
    }, curtain)
    addCorner(sweep, 2)
    addStroke(sweep, SNOW_WHITE, 1, 0.32)
    return curtain, sweep
end

local function waitForTween(tween, fallback)
    if tween then
        local ok = pcall(function()
            tween.Completed:Wait()
        end)
        if ok then
            return
        end
    end
    task.wait(fallback or 0)
end

local function runMaskedSwap(curtain, sweep, direction, swapCallback)
    direction = direction or 1
    curtain.Visible = true
    curtain.GroupTransparency = 1
    sweep.BackgroundTransparency = 1
    sweep.Position = direction > 0 and UDim2.new(0, -8, 0.5, 0) or UDim2.new(1, 8, 0.5, 0)

    local coverTween = fluidTween(
        curtain,
        0.085,
        {GroupTransparency = 0.04},
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    waitForTween(coverTween, 0.085)

    swapCallback()

    sweep.BackgroundTransparency = 0.10
    fluidTween(
        sweep,
        0.22,
        {Position = direction > 0 and UDim2.new(1, 8, 0.5, 0) or UDim2.new(0, -8, 0.5, 0)},
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )
    local revealTween = fluidTween(
        curtain,
        0.22,
        {GroupTransparency = 1},
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )
    waitForTween(revealTween, 0.22)

    curtain.Visible = false
    sweep.BackgroundTransparency = 1
end

local pageTransitionCurtain, pageTransitionSweep = makeTransitionCurtain(
    pageHolder,
    "PageTransitionCurtain",
    UDim2.fromScale(0, 0),
    UDim2.fromScale(1, 1),
    90
)

local notificationGui = create("ScreenGui", {
    Name = SETTINGS.GuiName .. "_Notifications",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1002,
}, gui.Parent)

local notificationHolder = create("Frame", {
    Name = "Notifications",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.fromOffset(350, 520),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 400,
}, notificationGui)
create("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, notificationHolder)

local statusGui = create("ScreenGui", {
    Name = SETTINGS.GuiName .. "_Status",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
    DisplayOrder = 1003,
    Enabled = false,
}, gui.Parent)

local statusFrame = create("Frame", {
    Name = "FloatingLiveStatus",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -24, 0, 72),
    Size = UDim2.fromOffset(360, 236),
    BackgroundColor3 = Color3.fromRGB(7, 4, 14),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 500,
}, statusGui)
addCorner(statusFrame, 14)
local statusStroke = addStroke(statusFrame, COLORS.accentDark, 2, 0.08)
local statusBackground = create("ImageLabel", {
    Name = "StatusBackground",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = SETTINGS.StatusBackgroundImageId,
    ImageColor3 = Color3.fromRGB(111, 57, 158),
    ImageTransparency = 0.30,
    ScaleType = Enum.ScaleType.Crop,
    ZIndex = 500,
}, statusFrame)
addCorner(statusBackground, 14)
local statusShade = create("Frame", {
    Name = "StatusGlassShade",
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = Color3.fromRGB(8, 4, 16),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    ZIndex = 501,
}, statusFrame)
addCorner(statusShade, 14)

local statusHeader = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 44),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 503,
}, statusFrame)
local statusTitle = makeLabel(statusHeader, utf8.char(0x25C6) .. "  VOR LIVE STATUS", UDim2.fromOffset(14, 0), UDim2.new(1, -62, 1, 0), COLORS.text, 15, Enum.Font.GothamBold)
statusTitle.TextColor3 = COLORS.sectionText
statusTitle.TextStrokeColor3 = Color3.fromRGB(3, 1, 8)
statusTitle.TextStrokeTransparency = 0.35
statusTitle.ZIndex = 504
local statusMinimizeButton = create("TextButton", {
    Name = "Minimize",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(34, 30),
    BackgroundColor3 = COLORS.sectionRow,
    BackgroundTransparency = 0.30,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = COLORS.sectionText,
    TextSize = 20,
    ZIndex = 505,
}, statusHeader)
addCorner(statusMinimizeButton, 10)

local statusBody = create("Frame", {
    Name = "Body",
    Position = UDim2.fromOffset(10, 44),
    Size = UDim2.new(1, -20, 1, -54),
    BackgroundColor3 = Color3.fromRGB(10, 6, 19),
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 502,
}, statusFrame)
addCorner(statusBody, 10)
addStroke(statusBody, COLORS.line, 1, 0.35)

local statusWidgetLabels = {}
local function readableStatusColor(color)
    if color == COLORS.text then return COLORS.sectionText end
    if color == COLORS.muted then return COLORS.sectionMuted end
    if color == COLORS.dim then return COLORS.sectionDim end
    if color == COLORS.success then return COLORS.sectionSuccess end
    if color == COLORS.error then return COLORS.sectionError end
    return color
end
for index, key in ipairs({"General", "AFK", "Special", "Multi", "Farm", "Weapon"}) do
    local row = makeLabel(
        statusBody,
        key .. ": Waiting...",
        UDim2.fromOffset(12, 4 + (index - 1) * 29),
        UDim2.new(1, -24, 0, 27),
        index == 1 and COLORS.sectionText or COLORS.sectionMuted,
        index == 1 and 13 or 12,
        index == 1 and Enum.Font.GothamBold or Enum.Font.GothamSemibold
    )
    row.TextTruncate = Enum.TextTruncate.AtEnd
    row.TextStrokeColor3 = Color3.fromRGB(3, 1, 8)
    row.TextStrokeTransparency = 0.38
    row.ZIndex = 504
    statusWidgetLabels[key] = row
end

local statusMinimized = false
local statusFlakes = {}
SETTINGS.StatusParticleRandom = Random.new()
SETTINGS.StatusParticleSymbols = {utf8.char(0x25C6), utf8.char(0x25C7), utf8.char(0x2726), utf8.char(0x2727)}
for index = 1, (ACTIVE_GAME_SUPPORT and ACTIVE_GAME_SUPPORT.Key == "Revive" and 6 or 0) do
    local flake = makeLabel(statusFrame, SETTINGS.StatusParticleSymbols[((index - 1) % #SETTINGS.StatusParticleSymbols) + 1], UDim2.fromOffset(0, 0), UDim2.fromOffset(24, 24), COLORS.toggleOnBright, SETTINGS.StatusParticleRandom:NextInteger(13, 22), Enum.Font.GothamBold)
    flake.Name = "StatusVorParticle" .. index
    flake.TextXAlignment = Enum.TextXAlignment.Center
    flake.TextTransparency = 0.18
    flake.TextStrokeColor3 = COLORS.accentDark
    flake.TextStrokeTransparency = 0.56
    flake.ZIndex = 505
    table.insert(statusFlakes, flake)
    task.spawn(function()
        while statusGui.Parent and flake.Parent do
            flake.Position = UDim2.fromOffset(SETTINGS.StatusParticleRandom:NextInteger(4, 332), SETTINGS.StatusParticleRandom:NextInteger(-35, -10))
            flake.Rotation = SETTINGS.StatusParticleRandom:NextInteger(-35, 35)
            while statusGui.Parent and flake.Parent and (not statusGui.Enabled or statusMinimized) do
                flake.Visible = false
                task.wait(0.35)
            end
            if not statusGui.Parent or not flake.Parent then
                break
            end
            flake.Visible = true
            local tween = TweenService:Create(flake, TweenInfo.new(SETTINGS.StatusParticleRandom:NextNumber(4.2, 7.2), Enum.EasingStyle.Linear), {
                Position = UDim2.fromOffset(SETTINGS.StatusParticleRandom:NextInteger(4, 332), 240),
                Rotation = flake.Rotation + SETTINGS.StatusParticleRandom:NextInteger(80, 220),
            })
            tween:Play()
            tween.Completed:Wait()
            task.wait(SETTINGS.StatusParticleRandom:NextNumber(0.08, 0.55))
        end
    end)
end

local statusDragging = false
local statusDragMoved = false
local statusDragStart = nil
local statusDragPosition = nil
local function clampStatusWidget(position, size)
    local camera = workspace.CurrentCamera
    if not camera then return position end
    local viewport = camera.ViewportSize
    local width = size.X.Offset
    local height = size.Y.Offset
    local x = viewport.X * position.X.Scale + position.X.Offset
    local y = viewport.Y * position.Y.Scale + position.Y.Offset
    return UDim2.fromOffset(
        math.clamp(x, width + 8, viewport.X - 8),
        math.clamp(y, 8, math.max(8, viewport.Y - height - 8))
    )
end

local function setStatusMinimized(value)
    statusMinimized = value == true
    statusTitle.Visible = not statusMinimized
    statusBody.Visible = not statusMinimized
    for _, flake in ipairs(statusFlakes) do
        flake.Visible = not statusMinimized
    end
    if statusMinimized then
        statusFrame.Size = UDim2.fromOffset(58, 58)
        statusFrame.BackgroundTransparency = 0.05
        statusMinimizeButton.Parent = statusFrame
        statusMinimizeButton.AnchorPoint = Vector2.new(0, 0)
        statusMinimizeButton.Position = UDim2.fromOffset(0, 0)
        statusMinimizeButton.Size = UDim2.fromScale(1, 1)
        statusMinimizeButton.BackgroundTransparency = 1
        statusMinimizeButton.Text = utf8.char(0x2744)
        statusMinimizeButton.TextSize = 31
        statusStroke.Thickness = 2.5
    else
        statusFrame.Size = UDim2.fromOffset(360, 236)
        statusFrame.BackgroundTransparency = 0.13
        statusMinimizeButton.Parent = statusHeader
        statusMinimizeButton.AnchorPoint = Vector2.new(1, 0.5)
        statusMinimizeButton.Position = UDim2.new(1, -8, 0.5, 0)
        statusMinimizeButton.Size = UDim2.fromOffset(34, 30)
        statusMinimizeButton.BackgroundTransparency = 0.15
        statusMinimizeButton.Text = "-"
        statusMinimizeButton.TextSize = 20
        statusStroke.Thickness = 2
    end
    statusFrame.Position = clampStatusWidget(statusFrame.Position, statusFrame.Size)
end

local function beginStatusDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        statusDragging = true
        statusDragMoved = false
        statusDragStart = input.Position
        statusDragPosition = statusFrame.Position
    end
end
track(statusHeader.InputBegan:Connect(beginStatusDrag))
track(statusMinimizeButton.InputBegan:Connect(function(input)
    if statusMinimized then beginStatusDrag(input) end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if statusDragging and statusDragStart and statusDragPosition and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - statusDragStart
        if delta.Magnitude > 5 then
            statusDragMoved = true
        end
        local proposed = UDim2.new(statusDragPosition.X.Scale, statusDragPosition.X.Offset + delta.X, statusDragPosition.Y.Scale, statusDragPosition.Y.Offset + delta.Y)
        statusFrame.Position = clampStatusWidget(proposed, statusFrame.Size)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        statusDragging = false
        statusDragStart = nil
        statusDragPosition = nil
    end
end))
track(statusMinimizeButton.MouseButton1Click:Connect(function()
    if statusDragMoved then
        statusDragMoved = false
        return
    end
    playToggleClick(not statusMinimized)
    setStatusMinimized(not statusMinimized)
end))

local Window = {
    Gui = gui,
    SnowGui = snowGui,
    NotificationGui = notificationGui,
    StatusGui = statusGui,
    NotificationHolder = notificationHolder,
    Main = main,
    Pages = {},
    ActivePage = nil,
    PageOrderCounter = 0,
    PageTransitioning = false,
    QueuedPageName = nil,
    Minimized = false,
    PersistentControls = {},
}

local hubVisible = true
local hubVisibilityToken = 0
gui:SetAttribute("MinimizedStyle", minimizedStyle)

local function hubEffectsActive()
    return hubVisible and not Window.Minimized
end

function Window:SetVisible(visible)
    hubVisibilityToken += 1
    local token = hubVisibilityToken
    hubVisible = visible == true
    if hubVisible then
        gui.Enabled = true
        snowGui.Enabled = SETTINGS.SnowEnabled and not self.Minimized

        if self.Minimized and minimizedStyle == MINIMIZE_CIRCLE_STYLE then
            main.Visible = false
            minimizedCircle.Visible = true
            minimizedCircle.GroupTransparency = 1
            minimizedCircleScale.Scale = 0.82
            if self.ClampMinimizedCircle then
                self:ClampMinimizedCircle()
            end
            fluidTween(minimizedCircle, 0.22, {GroupTransparency = 0}, Enum.EasingStyle.Quint)
            fluidTween(minimizedCircleScale, 0.26, {Scale = 1}, Enum.EasingStyle.Back)
        else
            minimizedCircle.Visible = false
            main.Visible = true
            if self.ClampToViewport then
                self:ClampToViewport(self.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560))
            end
            if self.UpdateScale then
                self:UpdateScale()
            end
            uiScaleAnimation.Value = math.min(uiScaleAnimation.Value, 0.975)
            fluidTween(uiScaleAnimation, 0.28, {Value = 1}, Enum.EasingStyle.Back)
        end
    else
        if minimizedCircle.Visible then
            fluidTween(minimizedCircle, 0.18, {GroupTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            fluidTween(minimizedCircleScale, 0.18, {Scale = 0.88}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end
        if main.Visible then
            fluidTween(uiScaleAnimation, 0.18, {Value = 0.975}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end
        task.delay(0.19, function()
            if token == hubVisibilityToken and not hubVisible then
                gui.Enabled = false
                snowGui.Enabled = false
            end
        end)
    end
    setHubMusicVisible(hubEffectsActive(), false)
end

function Window:ToggleVisible()
    local opening = not hubVisible
    playHubVisibilitySound(opening)
    self:SetVisible(opening)
end

local function loadProfileImage()
    if not SETTINGS.AvatarPreviewEnabled then
        return
    end

    local logoImageId = tostring(SETTINGS.ProfileLogoImageId or "")
    if logoImageId ~= "" then
        avatarImage.Image = logoImageId
        return
    end

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.AvatarThumbnail,
                Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and avatarImage.Parent then
            avatarImage.Image = image
        end
    end)
end

loadProfileImage()
if tostring(SETTINGS.ProfileLogoImageId or "") == "" then
    track(LocalPlayer.CharacterAppearanceLoaded:Connect(loadProfileImage))
end

local function loadPlayerHeadshot()
    if not SETTINGS.PlayerHeadshotEnabled then
        return
    end

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size420x420
            )
        end)
        if ok and headshotImage.Parent then
            headshotImage.Image = image
        end
    end)
end

loadPlayerHeadshot()
track(LocalPlayer.CharacterAppearanceLoaded:Connect(loadPlayerHeadshot))

SETTINGS.AvatarFloatClock = 0
SETTINGS.AvatarFrameAccumulator = 0
track(RunService.RenderStepped:Connect(function(deltaTime)
    if not SETTINGS.AvatarPreviewEnabled or not hubVisible or not main.Visible or not sidebar.Visible or not avatarCard.Visible then
        return
    end

    SETTINGS.AvatarFrameAccumulator += deltaTime
    local frameInterval = 1 / math.clamp(tonumber(SETTINGS.UIAnimationRate) or 240, 30, 240)
    if SETTINGS.AvatarFrameAccumulator < frameInterval then
        return
    end
    SETTINGS.AvatarFloatClock = SETTINGS.AvatarFloatClock + math.min(SETTINGS.AvatarFrameAccumulator, 0.05)
    SETTINGS.AvatarFrameAccumulator = SETTINGS.AvatarFrameAccumulator % frameInterval
    local verticalFloat = math.sin(SETTINGS.AvatarFloatClock * 1.75) * 3
    local horizontalFloat = math.sin(SETTINGS.AvatarFloatClock * 0.82) * 2
    local sway = math.sin(SETTINGS.AvatarFloatClock * 0.95) * 1.8
    local glowPulse = (math.sin(SETTINGS.AvatarFloatClock * 1.45) + 1) * 0.5

    avatarImage.Position = UDim2.new(0.5, horizontalFloat, 0, 4 + verticalFloat)
    avatarImage.Rotation = sway
    avatarGlow.Size = UDim2.fromOffset(64 + glowPulse * 8, 64 + glowPulse * 8)
    avatarGlow.BackgroundTransparency = 0.82 - glowPulse * 0.12
end))

local function startSnowfall()
    if not SETTINGS.SnowEnabled or (SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering) then
        return
    end

    local random = Random.new()
    local symbols = {
        utf8.char(0x25C6),
        utf8.char(0x25C7),
        utf8.char(0x2726),
        utf8.char(0x2727),
        utf8.char(0x2756),
    }
    local count = math.clamp(math.floor(tonumber(SETTINGS.SnowflakeCount) or 12), 6, 24)

    for index = 1, count do
        local flake = create("TextLabel", {
            Name = "VorParticle" .. tostring(index),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(64, 64),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Enum.Font.Gotham,
            Text = symbols[random:NextInteger(1, #symbols)],
            TextColor3 = COLORS.toggleOnBright,
            TextStrokeColor3 = COLORS.accentDark,
            TextStrokeTransparency = 0.34,
            TextTransparency = random:NextNumber(0.08, 0.30),
            TextSize = random:NextInteger(18, 42),
            Visible = false,
            ZIndex = 2,
        }, snowLayer)
        -- Only the larger accent particles need a second glow object. Text
        -- stroke supplies the glow for the rest, cutting the animated object
        -- count by more than half without flattening the VOR look.
        if index % 5 == 0 then
            create("ImageLabel", {
                Name = "VorGlow",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromScale(1.45, 1.45),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Image = "rbxasset://textures/particles/sparkles_main.dds",
                ImageColor3 = COLORS.accent,
                ImageTransparency = 0.34,
                ZIndex = 1,
            }, flake)
        end

        task.spawn(function()
            task.wait(random:NextNumber(0, 2.5))
            while snowGui.Parent do
                while snowGui.Parent and not hubEffectsActive() do
                    flake.Visible = false
                    task.wait(0.35)
                end
                if not snowGui.Parent then
                    break
                end

                local startX = random:NextNumber(0.01, 0.99)
                local endX = math.clamp(startX + random:NextNumber(-0.18, 0.18), 0.01, 0.99)
                local duration = random:NextNumber(4.8, 9.2)
                flake.Text = symbols[random:NextInteger(1, #symbols)]
                flake.TextSize = random:NextInteger(18, 42)
                flake.TextTransparency = random:NextNumber(0.08, 0.30)
                flake.Position = UDim2.new(startX, 0, 0, -68)
                flake.Rotation = random:NextInteger(-35, 35)
                flake.Visible = true

                local fall = TweenService:Create(
                    flake,
                    TweenInfo.new(duration, Enum.EasingStyle.Linear),
                    {
                        Position = UDim2.new(endX, 0, 1, 68),
                        Rotation = flake.Rotation + random:NextInteger(90, 260),
                    }
                )
                fall:Play()

                while snowGui.Parent and hubEffectsActive() and fall.PlaybackState == Enum.PlaybackState.Playing do
                    task.wait(0.10)
                end
                if not hubEffectsActive() then
                    fall:Cancel()
                end
                flake.Visible = false
                task.wait(random:NextNumber(0.05, 0.45))
            end
        end)
    end
end

startSnowfall()

local function shadeColor(color, factor)
    return Color3.new(
        math.clamp(color.R * factor, 0, 1),
        math.clamp(color.G * factor, 0, 1),
        math.clamp(color.B * factor, 0, 1)
    )
end

local function replaceThemeColor(root, oldColor, newColor)
    local properties = {
        "BackgroundColor3",
        "TextColor3",
        "TextStrokeColor3",
        "ImageColor3",
        "ScrollBarImageColor3",
        "BorderColor3",
        "Color",
    }
    local objects = {root}
    for _, descendant in ipairs(root:GetDescendants()) do
        table.insert(objects, descendant)
    end

    for _, object in ipairs(objects) do
        for _, property in ipairs(properties) do
            local ok, current = pcall(function()
                return object[property]
            end)
            if ok and current == oldColor then
                pcall(function()
                    object[property] = newColor
                end)
            end
        end
    end
end

local function applyFrozenAccent(newAccent)
    local oldAccent = COLORS.accent
    local oldAccentDark = COLORS.accentDark
    local oldLine = COLORS.line
    local newAccentDark = shadeColor(newAccent, 0.58)
    local newLine = newAccent:Lerp(newAccentDark, 0.38)

    replaceThemeColor(gui, oldAccent, newAccent)
    replaceThemeColor(gui, oldAccentDark, newAccentDark)
    replaceThemeColor(gui, oldLine, newLine)
    replaceThemeColor(snowGui, oldAccent, newAccent)
    replaceThemeColor(snowGui, oldAccentDark, newAccentDark)
    replaceThemeColor(snowGui, oldLine, newLine)

    COLORS.accent = newAccent
    COLORS.accentDark = newAccentDark
    COLORS.line = newLine

    for _, root in ipairs({gui, snowGui}) do
        for _, descendant in ipairs(root:GetDescendants()) do
            if descendant:IsA("UIGradient") and descendant.Name == "FrozenAccentGradient" then
                descendant.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, newAccent:Lerp(Color3.new(1, 1, 1), 0.68)),
                    ColorSequenceKeypoint.new(0.55, newAccent),
                    ColorSequenceKeypoint.new(1.00, newAccentDark),
                })
            end
        end
    end
end

local function applyHubTransparency(value)
    hubTransparencyValue = math.clamp(tonumber(value) or 0.24, 0.04, 0.80)
    if SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering then
        -- Cap transparency in the large integration to prevent multiple
        -- full-screen blended layers from stalling the renderer.
        hubTransparencyValue = math.min(hubTransparencyValue, 0.12)
    end
    local offsets = {
        VORHub = 0.00,
        Header = 0.06,
        HeaderSquareJoin = 0.06,
        Sidebar = 0.12,
        SidebarTopJoin = 0.12,
        SidebarRightJoin = 0.12,
        ConceptInterior = 0.16,
        ContentTopJoin = 0.16,
        ContentLeftJoin = 0.16,
        FloatingAvatarCard = 0.10,
        PlayerHeadshotCard = 0.08,
        VORWelcomeCard = 0.00,
        Search = 0.08,
        HomeCategoryBar = 0.08,
        SectionCard = 0.20,
        ControlRow = 0.08,
        DropdownRow = 0.08,
    }

    local objects = {main}
    for _, descendant in ipairs(main:GetDescendants()) do
        table.insert(objects, descendant)
    end
    for _, object in ipairs(objects) do
        local offset = offsets[object.Name]
        if offset and object:IsA("GuiObject") then
            object.BackgroundTransparency = math.clamp(hubTransparencyValue + offset, 0, 0.92)
        end
    end
end


local function makeFlag(text)
    local flag = string.lower(tostring(text or "control"))
    flag = flag:gsub("[^%w_%-]", "_"):gsub("_+", "_")
    flag = flag:gsub("^_+", ""):gsub("_+$", "")
    return flag ~= "" and flag or "control"
end

local function registerPersistentControl(section, name, options, control)
    if options.Persist == false then
        return control
    end

    local baseFlag = makeFlag(options.Flag or (section.Page.Name .. "_" .. section.Title .. "_" .. name))
    local flag = baseFlag
    local suffix = 2
    while Window.PersistentControls[flag] do
        flag = baseFlag .. "_" .. tostring(suffix)
        suffix = suffix + 1
    end

    control.Flag = flag
    Window.PersistentControls[flag] = control
    return control
end

function Window:Notify(title, message, duration)
    duration = math.max(tonumber(duration) or 3, 1)
    local notification = create("Frame", {
        Size = UDim2.fromOffset(338, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(11, 6, 21),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ZIndex = 401,
    }, notificationHolder)
    addCorner(notification, 10)
    addStroke(notification, COLORS.toggleOnStroke, 1.5, 0.10)
    local frostGradient = create("UIGradient", {
        Rotation = 18,
        Offset = Vector2.new(-0.55, 0),
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(8, 4, 16)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(47, 18, 78)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(137, 55, 218)),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.02),
            NumberSequenceKeypoint.new(0.65, 0.18),
            NumberSequenceKeypoint.new(1.00, 0.38),
        }),
    }, notification)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingBottom = UDim.new(0, 11),
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
    }, notification)
    create("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, notification)

    local titleLabel = makeLabel(notification, utf8.char(0x25C6) .. "  " .. tostring(title or SETTINGS.Title), nil, UDim2.new(1, 0, 0, 22), COLORS.sectionText, 15, Enum.Font.GothamBold)
    titleLabel.LayoutOrder = 1
    titleLabel.ZIndex = 402

    local messageLabel = makeLabel(notification, message or "", nil, UDim2.new(1, 0, 0, 0), COLORS.sectionMuted, 12, Enum.Font.GothamMedium)
    messageLabel.LayoutOrder = 2
    messageLabel.AutomaticSize = Enum.AutomaticSize.Y
    messageLabel.TextWrapped = true
    messageLabel.ZIndex = 402

    local timerTrack = create("Frame", {
        LayoutOrder = 3,
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.fromRGB(59, 40, 76),
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        ZIndex = 402,
    }, notification)
    addCorner(timerTrack, 2)
    local timerBar = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLORS.toggleOnBright,
        BorderSizePixel = 0,
        ZIndex = 403,
    }, timerTrack)
    addCorner(timerBar, 2)
    local notificationScale = create("UIScale", {Scale = 0.92}, notification)

    notification.BackgroundTransparency = 1
    titleLabel.TextTransparency = 1
    messageLabel.TextTransparency = 1

    TweenService:Create(notification, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0.08}):Play()
    TweenService:Create(notificationScale, TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    TweenService:Create(titleLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play()
    TweenService:Create(messageLabel, TweenInfo.new(0.22), {TextTransparency = 0}):Play()
    TweenService:Create(frostGradient, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Offset = Vector2.new(0.55, 0)}):Play()
    TweenService:Create(timerBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 1, 0)}):Play()

    task.delay(duration, function()
        if not notification.Parent then
            return
        end

        local fade = TweenService:Create(notification, TweenInfo.new(0.20), {BackgroundTransparency = 1})
        fade:Play()
        TweenService:Create(notificationScale, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.95}):Play()
        TweenService:Create(titleLabel, TweenInfo.new(0.20), {TextTransparency = 1}):Play()
        TweenService:Create(messageLabel, TweenInfo.new(0.20), {TextTransparency = 1}):Play()
        fade.Completed:Wait()
        if notification.Parent then
            notification:Destroy()
        end
    end)
    return notification
end

local function registerSearchItem(page, object, text)
    table.insert(page.SearchItems, {
        Object = object,
        Text = string.lower(tostring(text or "")),
    })
end

local function makeControlRow(section, height)
    section.NextOrder = section.NextOrder + 1
    local row = create("Frame", {
        Name = "ControlRow",
        LayoutOrder = section.NextOrder,
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = COLORS.sectionRow,
        BackgroundTransparency = SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering and 0.02 or 0.18,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, section.Body)
    addCorner(row, 5)
    if not SETTINGS.LightweightRendering then
        addStroke(row, COLORS.accentDark, 1, 0.30)
        local rowAccent = create("Frame", {
            Name = "VorRowAccent",
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.new(0, 2, 1, -14),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.38,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, row)
        addCorner(rowAccent, 2)
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new(COLORS.toggleOnBright, COLORS.accentDark),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.16),
                NumberSequenceKeypoint.new(0.5, 0.02),
                NumberSequenceKeypoint.new(1, 0.48),
            }),
        }, rowAccent)
    end
    return row
end

local function attachControlMotion(button, row, hoverTransparency)
    if SETTINGS.LightweightRendering then
        return
    end
    attachFluidScale(button, row, 1.006, 0.994)
    track(button.MouseEnter:Connect(function()
        fluidTween(row, 0.16, {BackgroundTransparency = hoverTransparency or 0.18})
    end))
    track(button.MouseLeave:Connect(function()
        fluidTween(row, 0.20, {BackgroundTransparency = 0.18})
    end))
end

local SectionMethods = {}

function SectionMethods:AddLabel(text)
    local row = makeControlRow(self, 36)
    local label = makeLabel(row, text, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), COLORS.muted, 13, Enum.Font.GothamMedium)
    label.TextWrapped = true
    label.TextStrokeColor3 = Color3.fromRGB(3, 1, 8)
    label.TextStrokeTransparency = 0.52
    registerSearchItem(self.Page, row, text)
    return label
end

function SectionMethods:AddButton(options)
    options = options or {}
    local name = options.Name or "Button"
    local description = options.Description or ""
    local row = makeControlRow(self, description ~= "" and 52 or 40)

    local title = makeLabel(row, name, UDim2.fromOffset(12, description ~= "" and 5 or 0), UDim2.new(1, -50, 0, 30), COLORS.text, 13, Enum.Font.GothamSemibold)
    local descriptionLabel = nil
    if description ~= "" then
        descriptionLabel = makeLabel(row, description, UDim2.fromOffset(12, 31), UDim2.new(1, -50, 0, 18), COLORS.dim, 11, Enum.Font.GothamMedium)
        descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local arrow = makeLabel(row, ">", UDim2.new(1, -36, 0, 0), UDim2.fromOffset(24, row.Size.Y.Offset), COLORS.accent, 18, Enum.Font.GothamBold)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local button = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, row)

    attachControlMotion(button, row, 0.52)
    attachPressRipple(button, row)
    track(button.MouseEnter:Connect(function()
        fluidTween(arrow, 0.18, {Position = UDim2.new(1, -31, 0, 0), TextTransparency = 0})
    end))
    track(button.MouseLeave:Connect(function()
        fluidTween(arrow, 0.18, {Position = UDim2.new(1, -36, 0, 0), TextTransparency = 0.08})
    end))
    track(button.MouseButton1Click:Connect(function()
        safeCallback(options.Callback)
    end))

    registerSearchItem(self.Page, row, name .. " " .. description)

    return {
        Fire = function()
            safeCallback(options.Callback)
        end,
        SetText = function(_, newText)
            title.Text = tostring(newText)
        end,
        SetDescription = function(_, newDescription)
            if descriptionLabel then
                descriptionLabel.Text = tostring(newDescription)
            end
        end,
    }
end

function SectionMethods:AddToggle(options)
    options = options or {}
    local name = options.Name or "Toggle"
    local description = options.Description or ""
    local state = options.Default == true
    local row = makeControlRow(self, description ~= "" and 52 or 40)

    makeLabel(row, name, UDim2.fromOffset(12, description ~= "" and 5 or 0), UDim2.new(1, -80, 0, 30), COLORS.text, 13, Enum.Font.GothamSemibold)
    if description ~= "" then
        local descriptionLabel = makeLabel(row, description, UDim2.fromOffset(12, 31), UDim2.new(1, -90, 0, 18), COLORS.dim, 11, Enum.Font.GothamMedium)
        descriptionLabel.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local trackFrame = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(48, 24),
        BackgroundColor3 = COLORS.offTrack,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, row)
    addCorner(trackFrame, 12)
    local trackStroke = addStroke(trackFrame, COLORS.offTrack:Lerp(COLORS.sectionText, 0.35), 1.4, 0.48)
    local onGradient = nil
    if not SETTINGS.LightweightRendering then
        onGradient = create("UIGradient", {
            Enabled = false,
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, COLORS.toggleOn),
                ColorSequenceKeypoint.new(1, COLORS.toggleOnBright),
            }),
        }, trackFrame)
    end

    local onLabel = create("TextLabel", {
        Position = UDim2.fromOffset(4, 0),
        Size = UDim2.fromOffset(22, 24),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "ON",
        TextColor3 = Color3.fromRGB(249, 240, 255),
        TextSize = 8,
        TextStrokeColor3 = Color3.fromRGB(48, 10, 84),
        TextStrokeTransparency = 0.25,
        TextTransparency = 1,
        ZIndex = 3,
    }, trackFrame)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BackgroundColor3 = COLORS.knob,
        BorderSizePixel = 0,
        ZIndex = 4,
    }, trackFrame)
    addCorner(knob, 9)
    local knobStroke = addStroke(knob, Color3.fromRGB(221, 198, 239), 1, 0.30)

    local button = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, row)

    local control = {}
    function control:Set(value, silent)
        state = value == true
        local trackColor = state and COLORS.toggleOn or COLORS.offTrack
        local knobPosition = state and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if onGradient then
            onGradient.Enabled = state
        end
        fluidTween(trackFrame, 0.18, {BackgroundColor3 = trackColor})
        fluidTween(trackStroke, 0.18, {
            Color = state and COLORS.toggleOnStroke or COLORS.offTrack:Lerp(COLORS.sectionText, 0.35),
            Transparency = state and 0.08 or 0.48,
            Thickness = state and 2 or 1.4,
        })
        fluidTween(knob, 0.24, {
            Position = knobPosition,
            BackgroundColor3 = state and Color3.fromRGB(250, 244, 255) or COLORS.knob,
            Size = state and UDim2.fromOffset(19, 19) or UDim2.fromOffset(18, 18),
        }, Enum.EasingStyle.Back)
        fluidTween(knobStroke, 0.18, {
            Color = state and COLORS.toggleOnStroke or Color3.fromRGB(198, 177, 215),
            Transparency = state and 0.05 or 0.38,
        })
        fluidTween(onLabel, 0.14, {TextTransparency = state and 0 or 1})
        if not silent then
            safeCallback(options.Callback, state)
        end
    end
    function control:Get()
        return state
    end

    attachControlMotion(button, row, 0.59)
    attachPressRipple(button, row)
    track(button.MouseButton1Click:Connect(function()
        local nextState = not state
        playToggleClick(nextState)
        control:Set(nextState)
    end))
    control:Set(state, true)
    registerSearchItem(self.Page, row, name .. " " .. description)
    return registerPersistentControl(self, name, options, control)
end

function SectionMethods:AddDropdown(options)
    options = options or {}
    local name = options.Name or "Dropdown"
    local values = options.Options or {}
    local multiple = options.Multi == true
    local selected = options.Default
    local open = false

    local function normalizeSelection(value)
        if not multiple then
            return value
        end
        local result = {}
        if type(value) == "table" then
            for key, enabled in pairs(value) do
                if type(key) == "number" then
                    result[tostring(enabled)] = true
                elseif enabled == true then
                    result[tostring(key)] = true
                end
            end
        elseif value ~= nil then
            result[tostring(value)] = true
        end
        return result
    end

    selected = normalizeSelection(selected)

    local function selectionText()
        if not multiple then
            return selected and tostring(selected) or (options.Placeholder or "Select...")
        end
        local chosen = {}
        for _, value in ipairs(values) do
            if selected[tostring(value)] then
                table.insert(chosen, tostring(value))
            end
        end
        if #chosen == 0 then
            return options.Placeholder or "Select..."
        end
        if #chosen <= 2 then
            return table.concat(chosen, ", ")
        end
        return tostring(#chosen) .. " selected"
    end

    local function hasSelection()
        if multiple then
            return next(selected) ~= nil
        end
        return selected ~= nil
    end

    self.NextOrder = self.NextOrder + 1
    local row = create("Frame", {
        Name = "DropdownRow",
        LayoutOrder = self.NextOrder,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = COLORS.sectionRow,
        BackgroundTransparency = 0.18,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, self.Body)
    addCorner(row, 5)
    addStroke(row, COLORS.accentDark, 1, 0.30)
    create("UIListLayout", {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)

    local top = create("Frame", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, row)
    makeLabel(top, name, UDim2.fromOffset(12, 3), UDim2.new(1, -40, 0, 24), COLORS.text, 12, Enum.Font.GothamSemibold)
    local valueLabel = makeLabel(top, selectionText(), UDim2.fromOffset(12, 25), UDim2.new(1, -50, 0, 24), hasSelection() and COLORS.text or COLORS.dim, 13, Enum.Font.GothamMedium)
    local arrow = makeLabel(top, "v", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(24, 26), COLORS.accent, 14, Enum.Font.GothamBold)
    arrow.TextXAlignment = Enum.TextXAlignment.Center

    local topButton = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, top)

    local optionHolder = create("Frame", {
        LayoutOrder = 2,
        Visible = false,
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(12, 7, 22),
        BackgroundTransparency = 0.22,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, row)
    create("UIListLayout", {
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, optionHolder)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 4),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
    }, optionHolder)

    local control = {}
    local optionButtons = {}

    local function refreshOptionVisuals()
        for key, button in pairs(optionButtons) do
            local active = multiple and selected[key] == true or (not multiple and tostring(selected) == key)
            button.BackgroundTransparency = active and 0.08 or 0.30
            button.TextColor3 = active and COLORS.accent or COLORS.sectionMuted
        end
    end

    local function getOptionsHeight()
        local count = #values
        return count > 0 and (8 + count * 34 + math.max(0, count - 1) * 2) or 0
    end

    local function setOpen(value)
        open = value == true
        local optionsHeight = getOptionsHeight()
        if open then
            optionHolder.Visible = true
            optionHolder.Size = UDim2.new(1, 0, 0, 0)
            fluidTween(optionHolder, 0.22, {Size = UDim2.new(1, 0, 0, optionsHeight)})
            fluidTween(row, 0.22, {
                Size = UDim2.new(1, 0, 0, 50 + optionsHeight),
                BackgroundTransparency = 0.18,
            })
            fluidTween(arrow, 0.22, {Rotation = 180}, Enum.EasingStyle.Back)
        else
            fluidTween(optionHolder, 0.18, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            fluidTween(row, 0.20, {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 0.18,
            })
            fluidTween(arrow, 0.18, {Rotation = 0})
            task.delay(0.19, function()
                if not open and optionHolder.Parent then
                    optionHolder.Visible = false
                end
            end)
        end
    end

    local function rebuildOptions()
        for _, child in ipairs(optionHolder:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        table.clear(optionButtons)

        for index, value in ipairs(values) do
            local optionKey = tostring(value)
            local optionButton = create("TextButton", {
                LayoutOrder = index,
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 34),
                BackgroundColor3 = COLORS.sectionRow,
                BackgroundTransparency = 0.30,
                BorderSizePixel = 0,
                Font = Enum.Font.GothamMedium,
                Text = "  " .. tostring(value),
                TextColor3 = COLORS.sectionMuted,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, optionHolder)
            optionButtons[optionKey] = optionButton
            addCorner(optionButton, 4)
            attachFluidScale(optionButton, optionButton, 1.012, 0.985)
            attachPressRipple(optionButton, optionButton)
            track(optionButton.MouseEnter:Connect(function()
                fluidTween(optionButton, 0.14, {
                    BackgroundTransparency = 0.10,
                    TextColor3 = COLORS.sectionText,
                })
            end))
            track(optionButton.MouseLeave:Connect(function()
                refreshOptionVisuals()
            end))
            track(optionButton.MouseButton1Click:Connect(function()
                if multiple then
                    local nextSelection = table.clone(selected)
                    if nextSelection[optionKey] then
                        nextSelection[optionKey] = nil
                    else
                        nextSelection[optionKey] = true
                    end
                    control:Set(nextSelection)
                else
                    control:Set(value)
                    setOpen(false)
                end
            end))
        end
        refreshOptionVisuals()
    end

    function control:Set(value, silent)
        selected = normalizeSelection(value)
        valueLabel.Text = selectionText()
        valueLabel.TextColor3 = hasSelection() and COLORS.text or COLORS.dim
        refreshOptionVisuals()
        if not silent then
            safeCallback(options.Callback, selected)
        end
    end
    function control:Get()
        return selected
    end
    function control:SetOptions(newOptions, keepSelection)
        values = newOptions or {}
        if not keepSelection then
            control:Set(nil, true)
        end
        rebuildOptions()
        if open then
            local height = getOptionsHeight()
            optionHolder.Size = UDim2.new(1, 0, 0, height)
            row.Size = UDim2.new(1, 0, 0, 50 + height)
        end
    end
    function control:Close()
        setOpen(false)
    end

    attachFluidScale(topButton, top, 1.004, 0.992)
    attachPressRipple(topButton, top)
    track(topButton.MouseEnter:Connect(function()
        if not open then
            fluidTween(row, 0.16, {BackgroundTransparency = 0.20})
        end
    end))
    track(topButton.MouseLeave:Connect(function()
        if not open then
            fluidTween(row, 0.18, {BackgroundTransparency = 0.18})
        end
    end))
    track(topButton.MouseButton1Click:Connect(function()
        playToggleClick(not open)
        setOpen(not open)
    end))

    rebuildOptions()
    control:Set(selected, true)
    registerSearchItem(self.Page, row, name)
    return registerPersistentControl(self, name, options, control)
end

-- All sliders share one global drag router. The previous implementation added
-- two UserInputService connections per slider, which became a measurable open
-- menu cost in large games such as Blox Fruits.
local activeSliderDrag = nil
track(UserInputService.InputChanged:Connect(function(input)
    local drag = activeSliderDrag
    if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        drag.Update(input)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if activeSliderDrag
        and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local drag = activeSliderDrag
        activeSliderDrag = nil
        drag.Finish()
    end
end))

function SectionMethods:AddSlider(options)
    options = options or {}
    local name = options.Name or "Slider"
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    local step = math.max(tonumber(options.Step) or 1, 0.0001)
    local value = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)
    local dragging = false

    local row = makeControlRow(self, 64)
    makeLabel(row, name, UDim2.fromOffset(12, 4), UDim2.new(1, -90, 0, 28), COLORS.text, 13, Enum.Font.GothamSemibold)
    local valueLabel = makeLabel(row, "", UDim2.new(1, -82, 0, 4), UDim2.fromOffset(70, 28), COLORS.accent, 12, Enum.Font.GothamSemibold)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local bar = create("Frame", {
        Position = UDim2.fromOffset(12, 47),
        Size = UDim2.new(1, -24, 0, 6),
        BackgroundColor3 = COLORS.offTrack,
        BorderSizePixel = 0,
    }, row)
    addCorner(bar, 3)
    local fill = create("Frame", {
        Size = UDim2.fromScale(0, 1),
        BackgroundColor3 = COLORS.accent,
        BorderSizePixel = 0,
    }, bar)
    addCorner(fill, 3)
    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(14, 14),
        BackgroundColor3 = COLORS.knob,
        BorderSizePixel = 0,
    }, bar)
    addCorner(knob, 7)
    local knobStroke = addStroke(knob, COLORS.accent, 1, 0.34)

    local hitbox = create("TextButton", {
        AutoButtonColor = false,
        Position = UDim2.fromOffset(0, -10),
        Size = UDim2.new(1, 0, 1, 20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, bar)

    local function formatValue(number)
        if step >= 1 then
            return tostring(math.floor(number + 0.5))
        end
        local formatted = string.format("%.2f", number)
        formatted = formatted:gsub("0+$", ""):gsub("%.$", "")
        return formatted
    end

    local control = {}
    function control:Set(newValue, silent)
        local numeric = math.clamp(tonumber(newValue) or minimum, minimum, maximum)
        numeric = minimum + math.floor(((numeric - minimum) / step) + 0.5) * step
        value = math.clamp(numeric, minimum, maximum)
        local alpha = maximum == minimum and 0 or (value - minimum) / (maximum - minimum)
        if dragging then
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
        else
            fluidTween(fill, 0.18, {Size = UDim2.fromScale(alpha, 1)}, Enum.EasingStyle.Quint)
            fluidTween(knob, 0.22, {Position = UDim2.fromScale(alpha, 0.5)}, Enum.EasingStyle.Back)
        end
        valueLabel.Text = formatValue(value)
        if not silent then
            safeCallback(options.Callback, value)
        end
    end
    function control:Get()
        return value
    end

    local function updateFromInput(input)
        if bar.AbsoluteSize.X <= 0 then
            return
        end
        local alpha = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        control:Set(minimum + (maximum - minimum) * alpha)
    end

    local function finishDrag()
        dragging = false
        fluidTween(knob, 0.18, {Size = UDim2.fromOffset(14, 14), BackgroundColor3 = COLORS.knob}, Enum.EasingStyle.Back)
        fluidTween(knobStroke, 0.18, {Transparency = 0.34, Thickness = 1})
    end

    track(hitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if activeSliderDrag then
                activeSliderDrag.Finish()
            end
            dragging = true
            activeSliderDrag = {
                Update = updateFromInput,
                Finish = finishDrag,
            }
            fluidTween(knob, 0.14, {Size = UDim2.fromOffset(18, 18), BackgroundColor3 = SNOW_WHITE}, Enum.EasingStyle.Back)
            fluidTween(knobStroke, 0.14, {Transparency = 0.04, Thickness = 2})
            updateFromInput(input)
        end
    end))

    attachFluidScale(hitbox, row, 1.003, 0.997)
    track(hitbox.MouseEnter:Connect(function()
        fluidTween(row, 0.16, {BackgroundTransparency = 0.20})
        fluidTween(knob, 0.16, {Size = UDim2.fromOffset(16, 16)})
    end))
    track(hitbox.MouseLeave:Connect(function()
        if not dragging then
            fluidTween(row, 0.20, {BackgroundTransparency = 0.18})
            fluidTween(knob, 0.18, {Size = UDim2.fromOffset(14, 14)})
        end
    end))

    control:Set(value, true)
    registerSearchItem(self.Page, row, name)
    return registerPersistentControl(self, name, options, control)
end

function SectionMethods:AddInput(options)
    options = options or {}
    local name = options.Name or "Input"
    local row = makeControlRow(self, 68)
    makeLabel(row, name, UDim2.fromOffset(12, 2), UDim2.new(1, -24, 0, 27), COLORS.text, 12, Enum.Font.GothamSemibold)

    local box = create("TextBox", {
        Position = UDim2.fromOffset(10, 33),
        Size = UDim2.new(1, -20, 0, 34),
        BackgroundColor3 = Color3.fromRGB(12, 7, 22),
        BackgroundTransparency = 0.24,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearOnFocus == true,
        Font = Enum.Font.GothamMedium,
        PlaceholderText = options.Placeholder or "Enter text...",
        PlaceholderColor3 = COLORS.sectionDim,
        Text = tostring(options.Default or ""),
        TextColor3 = COLORS.sectionText,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    addCorner(box, 4)
    local boxStroke = addStroke(box, COLORS.accentDark, 1, 0.62)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, box)

    track(box.FocusLost:Connect(function(enterPressed)
        fluidTween(box, 0.18, {BackgroundTransparency = 0.24})
        fluidTween(boxStroke, 0.18, {Transparency = 0.62, Thickness = 1})
        fluidTween(row, 0.20, {BackgroundTransparency = 0.18})
        safeCallback(options.Callback, box.Text, enterPressed)
    end))
    track(box.Focused:Connect(function()
        fluidTween(box, 0.16, {BackgroundTransparency = 0.08})
        fluidTween(boxStroke, 0.16, {Transparency = 0.10, Thickness = 2})
        fluidTween(row, 0.16, {BackgroundTransparency = 0.18})
    end))

    registerSearchItem(self.Page, row, name)
    local control = {
        Get = function()
            return box.Text
        end,
        Set = function(_, value)
            box.Text = tostring(value or "")
        end,
        Box = box,
    }
    return registerPersistentControl(self, name, options, control)
end

local PageMethods = {}
local NAV_ICONS = {
    Home = utf8.char(0x2302),
    Tools = utf8.char(0x2692),
    Settings = utf8.char(0x2699),
}

function PageMethods:AddSection(title, side)
    local selectedSide = side
    if selectedSide ~= "Left" and selectedSide ~= "Right" then
        selectedSide = self.NextSide
        self.NextSide = self.NextSide == "Left" and "Right" or "Left"
    end

    local parentColumn = selectedSide == "Right" and self.RightColumn or self.LeftColumn
    local card = create("Frame", {
        Name = "SectionCard",
        Size = UDim2.new(1, -4, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(11, 7, 20),
        BackgroundTransparency = SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering and 0 or 0.04,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parentColumn)
    addCorner(card, 6)
    addVorTrim(card, 6, 3, 0.04)
    addVorCornerArmor(card, 4, 14, 0.38)

    if not (SETTINGS.IsBloxFruits and SETTINGS.LightweightRendering) then
        local sectionTexture = create("ImageLabel", {
            Name = "SectionBackground",
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = SETTINGS.SectionBackgroundImageId,
            ImageColor3 = Color3.fromRGB(75, 37, 118),
            ImageTransparency = 0.54,
            ScaleType = Enum.ScaleType.Crop,
            ZIndex = 1,
        }, card)
        addCorner(sectionTexture, 6)
        create("UIGradient", {
            Name = "SectionTextureShade",
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, Color3.fromRGB(115, 61, 172)),
                ColorSequenceKeypoint.new(0.50, Color3.fromRGB(62, 27, 100)),
                ColorSequenceKeypoint.new(1.00, Color3.fromRGB(20, 9, 34)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0.00, 0.18),
                NumberSequenceKeypoint.new(0.52, 0.10),
                NumberSequenceKeypoint.new(1.00, 0.24),
            }),
        }, sectionTexture)
    end

    local sectionContent = create("Frame", {
        Name = "SectionContent",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, card)
    create("UIListLayout", {
        Padding = UDim.new(0, 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, sectionContent)

    local sectionHeader = create("Frame", {
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Color3.fromRGB(9, 5, 17),
        BackgroundTransparency = 0.20,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, sectionContent)
    local sectionTitle = makeLabel(
        sectionHeader,
        title or "Section",
        UDim2.fromOffset(12, 0),
        UDim2.new(1, -24, 1, -2),
        COLORS.sectionText,
        14,
        Enum.Font.GothamBold
    )
    sectionTitle.TextStrokeColor3 = Color3.fromRGB(3, 1, 8)
    sectionTitle.TextStrokeTransparency = 0.24
    sectionTitle.ZIndex = 3
    create("Frame", {
        Position = UDim2.new(0, 12, 1, -1),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        ZIndex = 3,
    }, sectionHeader)
    local headerJewel = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 8, 1, -1),
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = COLORS.toggleOnBright,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Rotation = 45,
        ZIndex = 4,
    }, sectionHeader)
    addCorner(headerJewel, 1)

    local body = create("Frame", {
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 2,
    }, sectionContent)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, body)
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, body)

    local section = {
        Page = self,
        Title = title or "Section",
        Card = card,
        Body = body,
        NextOrder = 0,
    }
    return setmetatable(section, {__index = SectionMethods})
end

function Window:AddPage(name)
    assert(type(name) == "string" and name ~= "", "Page name must be a non-empty string")
    if self.Pages[name] then
        return self.Pages[name]
    end

    self.PageOrderCounter = (self.PageOrderCounter or 0) + 1
    local pageOrder = self.PageOrderCounter

    local navRow = create("Frame", {
        Size = UDim2.fromOffset(48, 44),
        BackgroundColor3 = COLORS.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, navHolder)
    addCorner(navRow, 5)
    local navStroke = addStroke(navRow, COLORS.accent, 1, 1)
    local accent = create("Frame", {
        Position = UDim2.fromOffset(0, 10),
        Size = UDim2.fromOffset(4, 24),
        BackgroundColor3 = COLORS.accentDark,
        BorderSizePixel = 0,
        Visible = false,
    }, navRow)
    addCorner(accent, 2)
    local navIconSize = name == "Home" and 30 or 20
    local navText = makeLabel(navRow, NAV_ICONS[name] or string.sub(name, 1, 1), UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), COLORS.muted, navIconSize, Enum.Font.GothamBold)
    navText.TextXAlignment = Enum.TextXAlignment.Center
    local navButton = create("TextButton", {
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 5,
    }, navRow)

    local pageFrame = create("Frame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, pageHolder)

    local leftColumn = create("ScrollingFrame", {
        Name = "LeftColumn",
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, pageFrame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, leftColumn)

    local rightColumn = create("ScrollingFrame", {
        Name = "RightColumn",
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, pageFrame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, rightColumn)

    local page = setmetatable({
        Name = name,
        Order = pageOrder,
        Frame = pageFrame,
        NavRow = navRow,
        NavAccent = accent,
        NavStroke = navStroke,
        NavText = navText,
        LeftColumn = leftColumn,
        RightColumn = rightColumn,
        SearchItems = {},
        NextSide = "Left",
    }, {__index = PageMethods})
    self.Pages[name] = page

    attachFluidScale(navButton, navRow, 1.045, 0.92)
    attachPressRipple(navButton, navRow)
    track(navButton.MouseEnter:Connect(function()
        if self.ActivePage ~= page then
            fluidTween(navRow, 0.16, {BackgroundTransparency = 0.56})
            fluidTween(navText, 0.16, {TextColor3 = COLORS.text})
        end
    end))
    track(navButton.MouseLeave:Connect(function()
        if self.ActivePage ~= page then
            fluidTween(navRow, 0.18, {BackgroundTransparency = 1})
            fluidTween(navText, 0.18, {TextColor3 = COLORS.muted})
        end
    end))

    track(navButton.MouseButton1Click:Connect(function()
        self:SelectPage(name)
    end))

    if not self.ActivePage then
        self:SelectPage(name)
    end
    return page
end

local function animatePageNavigation(window, target)
    for _, page in pairs(window.Pages) do
        local active = page == target
        page.NavAccent.Visible = true
        fluidTween(page.NavAccent, 0.22, {
            BackgroundTransparency = active and 0 or 1,
            Size = active and UDim2.fromOffset(4, 24) or UDim2.fromOffset(4, 8),
        }, Enum.EasingStyle.Quart)
        fluidTween(page.NavRow, 0.22, {
            BackgroundColor3 = active and Color3.fromRGB(39, 15, 67) or COLORS.surface,
            BackgroundTransparency = active and 0.08 or 1,
        }, Enum.EasingStyle.Quart)
        fluidTween(page.NavStroke, 0.22, {
            Color = active and COLORS.toggleOnBright or COLORS.accentDark,
            Transparency = active and 0.06 or 1,
            Thickness = active and 1.6 or 1,
        }, Enum.EasingStyle.Quart)
        fluidTween(page.NavText, 0.22, {
            TextColor3 = active and COLORS.text or COLORS.muted,
        }, Enum.EasingStyle.Quart)
        page.NavText.TextStrokeColor3 = SNOW_WHITE
        page.NavText.TextStrokeTransparency = active and 0.72 or 1
    end
end

function Window:SelectPage(name)
    local target = self.Pages[name]
    if not target then
        return false
    end

    if self.PageTransitioning then
        self.QueuedPageName = name
        return true
    end
    if self.ActivePage == target then
        return true
    end

    local previous = self.ActivePage
    local direction = 1
    if previous and (target.Order or 0) < (previous.Order or 0) then
        direction = -1
    end

    self.ActivePage = target
    animatePageNavigation(self, target)
    searchBox.Text = ""

    -- The first page appears immediately during construction. Every later change
    -- uses the masked transition so no half-faded controls can overlap.
    if not previous then
        for _, page in pairs(self.Pages) do
            page.Frame.Visible = page == target
            page.Frame.Position = UDim2.fromOffset(0, 0)
            page.Frame.ZIndex = page == target and 3 or 1
        end
        return true
    end

    self.PageTransitioning = true
    task.spawn(function()
        runMaskedSwap(pageTransitionCurtain, pageTransitionSweep, direction, function()
            -- Cancel all page movement before changing visibility. This is what
            -- prevents a rapid mobile tap from leaving a stale frame on screen.
            for _, page in pairs(self.Pages) do
                local staleTween = activeTweens[page.Frame]
                if staleTween then
                    pcall(function()
                        staleTween:Cancel()
                    end)
                    activeTweens[page.Frame] = nil
                end
                page.Frame.Visible = page == target
                page.Frame.ZIndex = page == target and 3 or 1
                page.Frame.Position = page == target
                    and UDim2.fromOffset(10 * direction, 0)
                    or UDim2.fromOffset(0, 0)
            end

            fluidTween(
                target.Frame,
                0.24,
                {Position = UDim2.fromOffset(0, 0)},
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out
            )
        end)

        if target.Frame.Parent then
            target.Frame.Visible = true
            target.Frame.Position = UDim2.fromOffset(0, 0)
            target.Frame.ZIndex = 3
        end

        self.PageTransitioning = false
        local queuedName = self.QueuedPageName
        self.QueuedPageName = nil
        if queuedName and self.Pages[queuedName] and self.ActivePage ~= self.Pages[queuedName] then
            self:SelectPage(queuedName)
        end
    end)

    return true
end

local function hasProfileFileApi()
    return type(isfolder) == "function"
        and type(makefolder) == "function"
        and type(isfile) == "function"
        and type(readfile) == "function"
        and type(writefile) == "function"
end

local function ensureFolder(path)
    local current = ""
    for segment in string.gmatch(path, "[^/]+") do
        current = current == "" and segment or (current .. "/" .. segment)
        if not isfolder(current) then
            makefolder(current)
        end
    end
end

local function sanitizeProfileName(name)
    local cleaned = tostring(name or "")
    cleaned = cleaned:gsub("[^%w%s_%-]", ""):gsub("%s+", " ")
    cleaned = cleaned:gsub("^%s+", ""):gsub("%s+$", "")
    return string.sub(cleaned, 1, 40)
end

local function getProfilePath(name)
    return PROFILE_FOLDER .. "/" .. sanitizeProfileName(name) .. ".json"
end

function Window:ProfilesAvailable()
    return hasProfileFileApi()
end

function Window:GetProfileNames()
    if not hasProfileFileApi() or type(listfiles) ~= "function" then
        return {}
    end

    local ok, files = pcall(function()
        ensureFolder(PROFILE_FOLDER)
        return listfiles(PROFILE_FOLDER)
    end)
    if not ok or type(files) ~= "table" then
        return {}
    end

    local names = {}
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\]+)%.json$")
        if name and name ~= "" then
            table.insert(names, name)
        end
    end
    table.sort(names, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    return names
end

function Window:ProfileScopeMatches(metadata)
    if type(metadata) ~= "table" then
        return false
    end
    if metadata.scopeId ~= nil then
        return tonumber(metadata.scopeId) == SETTINGS.ConfigScopeId
    end
    if metadata.placeId ~= nil then
        return tonumber(metadata.placeId) == game.PlaceId
    end
    return true
end

function Window:SaveProfile(name)
    if not hasProfileFileApi() then
        return false, "Executor file API is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if profile == "" then
        return false, "Enter a profile name"
    end

    local values = {}
    for flag, control in pairs(self.PersistentControls) do
        local ok, value = pcall(function()
            return control:Get()
        end)
        if ok and value ~= nil then
            values[flag] = value
        end
    end

    local ok, message = pcall(function()
        ensureFolder(PROFILE_FOLDER)
        local encoded = HttpService:JSONEncode({
            version = 2,
            scopeId = SETTINGS.ConfigScopeId,
            placeId = game.PlaceId,
            universeId = game.GameId,
            profile = profile,
            values = values,
        })
        writefile(getProfilePath(profile), encoded)
    end)
    if not ok then
        return false, "Could not save profile: " .. tostring(message)
    end
    return true, "Saved / Overwrote profile: " .. profile, profile
end

function Window:LoadProfile(name)
    if not hasProfileFileApi() then
        return false, "Executor file API is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if profile == "" then
        return false, "Choose a profile to load"
    end

    local path = getProfilePath(profile)
    if not isfile(path) then
        return false, "Profile not found: " .. profile
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" or type(data.values) ~= "table" then
        return false, "Profile data is invalid"
    end
    if not self:ProfileScopeMatches(data) then
        return false, "Profile belongs to a different game"
    end

    local loaded = 0
    for flag, value in pairs(data.values) do
        local control = self.PersistentControls[flag]
        if control then
            -- Run every persisted callback in its own task. A few Blox Fruits
            -- callbacks yield through protected game APIs, and some executors
            -- resume that coroutine with reduced Instance capabilities. Keeping
            -- each callback isolated prevents one setting from poisoning the
            -- rest of the profile load (or the hub's startup coroutine).
            local scheduled = pcall(function()
                task.spawn(function()
                    local applied, applyError = pcall(function()
                        control:Set(value)
                    end)
                    if not applied then
                        warn("[VOR Hub] Could not apply profile flag " .. tostring(flag) .. ": " .. tostring(applyError))
                    end
                end)
            end)
            if scheduled then
                loaded = loaded + 1
            end
        end
    end
    return true, "Loaded " .. profile .. " (" .. tostring(loaded) .. " settings)", profile
end

function Window:DeleteProfile(name)
    if not hasProfileFileApi() or type(delfile) ~= "function" then
        return false, "Profile deletion is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if profile == "" then
        return false, "Choose a profile to delete"
    end

    local path = getProfilePath(profile)
    if not isfile(path) then
        return false, "Profile not found: " .. profile
    end

    local ok, message = pcall(delfile, path)
    if not ok then
        return false, "Could not delete profile: " .. tostring(message)
    end
    return true, "Deleted profile: " .. profile
end

function Window:SetAutoLoad(enabled, name)
    if not hasProfileFileApi() then
        return false, "Executor file API is unavailable"
    end

    local profile = sanitizeProfileName(name)
    if enabled and (profile == "" or not isfile(getProfilePath(profile))) then
        return false, "Save or select a profile first"
    end

    local ok, message = pcall(function()
        ensureFolder(CONFIG_ROOT)
        writefile(AUTOLOAD_FILE, HttpService:JSONEncode({
            enabled = enabled == true,
            scopeId = SETTINGS.ConfigScopeId,
            placeId = game.PlaceId,
            universeId = game.GameId,
            profile = profile,
        }))
    end)
    if not ok then
        return false, "Could not update Auto Load: " .. tostring(message)
    end

    if enabled then
        return true, "Auto Load enabled for: " .. profile
    end
    return true, "Auto Load disabled"
end

function Window:GetAutoLoad()
    if not hasProfileFileApi() or not isfile(AUTOLOAD_FILE) then
        return false, ""
    end

    local ok, metadata = pcall(function()
        return HttpService:JSONDecode(readfile(AUTOLOAD_FILE))
    end)
    if not ok or type(metadata) ~= "table" then
        return false, ""
    end
    if not self:ProfileScopeMatches(metadata) then
        return false, ""
    end
    return metadata.enabled == true, sanitizeProfileName(metadata.profile)
end

local function multiplyUnsigned32(left, right)
    local leftLow = bit32.band(left, 0xFFFF)
    local leftHigh = bit32.rshift(left, 16)
    local rightLow = bit32.band(right, 0xFFFF)
    local rightHigh = bit32.rshift(right, 16)
    local low = leftLow * rightLow
    local middle = (leftHigh * rightLow + leftLow * rightHigh) * 65536
    return (low + middle) % 4294967296
end

local function hashAccessKey(value)
    local hash = 2166136261
    local text = tostring(value or "")
    for index = 1, #text do
        hash = multiplyUnsigned32(bit32.bxor(hash, string.byte(text, index)), 16777619)
    end
    return hash
end

local function hasRememberedAccess()
    if _G.VORHubAccessHash == SETTINGS.AccessKeyHash then
        return true
    end
    if not SETTINGS.RememberKey or not hasProfileFileApi() or not isfile(ACCESS_FILE) then
        return false
    end
    local ok, metadata = pcall(function()
        return HttpService:JSONDecode(readfile(ACCESS_FILE))
    end)
    return ok and type(metadata) == "table" and tonumber(metadata.keyHash) == SETTINGS.AccessKeyHash
end

local function rememberAccess()
    _G.VORHubAccessHash = SETTINGS.AccessKeyHash
    if not SETTINGS.RememberKey or not hasProfileFileApi() then
        return
    end
    pcall(function()
        ensureFolder("VORHub/Configs")
        writefile(ACCESS_FILE, HttpService:JSONEncode({
            version = 1,
            keyHash = SETTINGS.AccessKeyHash,
        }))
    end)
end

local function forgetRememberedAccess()
    _G.VORHubAccessHash = nil
    if type(isfile) == "function" and type(delfile) == "function" and isfile(ACCESS_FILE) then
        pcall(delfile, ACCESS_FILE)
    end
end

local function copyText(value)
    local textValue = tostring(value or "")
    local clipboardFunctions = {
        type(setclipboard) == "function" and setclipboard or nil,
        type(toclipboard) == "function" and toclipboard or nil,
        type(setrbxclipboard) == "function" and setrbxclipboard or nil,
    }
    for _, clipboardFunction in ipairs(clipboardFunctions) do
        if clipboardFunction and pcall(clipboardFunction, textValue) then
            return true
        end
    end
    local clipboardTable = type(Clipboard) == "table" and Clipboard or nil
    if clipboardTable and type(clipboardTable.set) == "function" and pcall(clipboardTable.set, textValue) then
        return true
    end
    return false
end

function Window:RequestKeyAccess(onGranted)
    if hasRememberedAccess() then
        gui:SetAttribute("AccessGateState", "Remembered")
        safeCallback(onGranted)
        return true
    end

    hubVisible = false
    main.Visible = false
    setHubMusicVisible(false, false)
    gui:SetAttribute("AccessGateState", "Locked")
    gui:SetAttribute("DiscordInviteURL", SETTINGS.DiscordInviteURL)

    local gate = create("CanvasGroup", {
        Name = "VORAccessGate",
        Active = true,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(3, 1, 7),
        BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 900,
    }, gui)
    create("UIGradient", {
        Rotation = 118,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(2, 1, 5)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(28, 9, 47)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 2, 13)),
        }),
    }, gate)

    local card = create("ImageLabel", {
        Name = "FrozenKeyCard",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(520, 356),
        BackgroundColor3 = Color3.fromRGB(11, 6, 20),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Image = SETTINGS.PanelBackgroundImageId,
        ImageColor3 = Color3.fromRGB(118, 61, 171),
        ImageTransparency = 0.34,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 901,
    }, gate)
    addCorner(card, 18)
    local cardStroke = addStroke(card, COLORS.accent, 2, 0.10)
    local cardScale = create("UIScale", {Scale = 0.90}, card)

    local shade = create("Frame", {
        Name = "ReadabilityShade",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(8, 4, 15),
        BackgroundTransparency = 0.14,
        BorderSizePixel = 0,
        ZIndex = 902,
    }, card)
    addCorner(shade, 18)

    local logo = create("ImageLabel", {
        Name = "VORLogo",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 19),
        Size = UDim2.fromOffset(64, 64),
        BackgroundColor3 = Color3.fromRGB(22, 10, 37),
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Image = SETTINGS.ProfileLogoImageId,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 904,
    }, card)
    addCorner(logo, 15)
    addStroke(logo, COLORS.accent, 1.5, 0.12)

    local title = makeLabel(card, "VOR HUB ACCESS", UDim2.fromOffset(0, 89), UDim2.new(1, 0, 0, 34), SNOW_WHITE, 25, Enum.Font.GothamBold)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextStrokeColor3 = Color3.fromRGB(3, 1, 8)
    title.TextStrokeTransparency = 0.22
    title.ZIndex = 904

    local description = makeLabel(
        card,
        "Join Discord to get the key, see supported games, and send feedback or suggestions.",
        UDim2.fromOffset(36, 123),
        UDim2.new(1, -72, 0, 42),
        COLORS.sectionMuted,
        12,
        Enum.Font.GothamMedium
    )
    description.TextWrapped = true
    description.TextXAlignment = Enum.TextXAlignment.Center
    description.ZIndex = 904

    local keyBox = create("TextBox", {
        Name = "DiscordKeyInput",
        Position = UDim2.fromOffset(38, 176),
        Size = UDim2.new(1, -76, 0, 48),
        BackgroundColor3 = Color3.fromRGB(10, 5, 18),
        BackgroundTransparency = 0.12,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamSemibold,
        PlaceholderText = "Enter the key from Discord",
        PlaceholderColor3 = COLORS.sectionDim,
        Text = "",
        TextColor3 = SNOW_WHITE,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 904,
    }, card)
    addCorner(keyBox, 10)
    local keyStroke = addStroke(keyBox, COLORS.accentDark, 1.5, 0.18)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 14),
        PaddingRight = UDim.new(0, 14),
    }, keyBox)

    local status = makeLabel(card, "The key is only posted inside the VOR Hub Discord.", UDim2.fromOffset(38, 226), UDim2.new(1, -76, 0, 24), COLORS.sectionMuted, 11, Enum.Font.GothamMedium)
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.ZIndex = 904

    local unlockButton = create("TextButton", {
        Name = "UnlockVORHub",
        Position = UDim2.fromOffset(38, 258),
        Size = UDim2.new(0.54, -5, 0, 52),
        AutoButtonColor = false,
        BackgroundColor3 = COLORS.toggleOn,
        BackgroundTransparency = 0.04,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "UNLOCK VOR HUB",
        TextColor3 = SNOW_WHITE,
        TextSize = 13,
        ZIndex = 904,
    }, card)
    addCorner(unlockButton, 11)
    addStroke(unlockButton, COLORS.toggleOnStroke, 1.5, 0.12)

    local discordButton = create("TextButton", {
        Name = "CopyDiscordInvite",
        Position = UDim2.new(0.54, 43, 0, 258),
        Size = UDim2.new(0.46, -81, 0, 52),
        AutoButtonColor = false,
        BackgroundColor3 = Color3.fromRGB(34, 15, 55),
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "COPY DISCORD",
        TextColor3 = COLORS.sectionText,
        TextSize = 13,
        ZIndex = 904,
    }, card)
    addCorner(discordButton, 11)
    addStroke(discordButton, COLORS.accentDark, 1.5, 0.14)

    local footer = makeLabel(card, SETTINGS.Discord .. "  |  Right Ctrl opens or closes the hub", UDim2.fromOffset(30, 319), UDim2.new(1, -60, 0, 22), COLORS.sectionDim, 10, Enum.Font.GothamMedium)
    footer.TextXAlignment = Enum.TextXAlignment.Center
    footer.ZIndex = 904

    attachFluidScale(unlockButton, unlockButton, 1.018, 0.965)
    attachPressRipple(unlockButton, unlockButton)
    attachFluidScale(discordButton, discordButton, 1.018, 0.965)
    attachPressRipple(discordButton, discordButton)

    track(keyBox.Focused:Connect(function()
        fluidTween(keyStroke, 0.16, {Transparency = 0.02, Thickness = 2})
        fluidTween(keyBox, 0.16, {BackgroundTransparency = 0.02})
    end))
    track(keyBox.FocusLost:Connect(function()
        fluidTween(keyStroke, 0.18, {Transparency = 0.18, Thickness = 1.5})
        fluidTween(keyBox, 0.18, {BackgroundTransparency = 0.12})
    end))

    local unlocking = false
    local function grantAccess()
        if unlocking then
            return
        end
        local supplied = tostring(keyBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if hashAccessKey(supplied) ~= SETTINGS.AccessKeyHash then
            playToggleClick(false)
            status.Text = "That key is not valid. Copy the Discord invite and check #get-script-and-key."
            status.TextColor3 = COLORS.sectionError
            fluidTween(cardStroke, 0.12, {Color = COLORS.error, Transparency = 0.02})
            local original = card.Position
            fluidTween(card, 0.06, {Position = original + UDim2.fromOffset(-8, 0)}, Enum.EasingStyle.Linear)
            task.delay(0.07, function()
                if card.Parent then
                    fluidTween(card, 0.10, {Position = original}, Enum.EasingStyle.Back)
                    fluidTween(cardStroke, 0.24, {Color = COLORS.accent, Transparency = 0.10})
                end
            end)
            return
        end

        unlocking = true
        rememberAccess()
        gui:SetAttribute("AccessGateState", "Granted")
        status.Text = "Access granted. Building VOR Hub..."
        status.TextColor3 = COLORS.sectionSuccess
        playToggleClick(true)
        fluidTween(gate, 0.30, {GroupTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        fluidTween(cardScale, 0.30, {Scale = 1.08}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.31, function()
            if gate.Parent then
                gate:Destroy()
            end
            hubVisible = true
            safeCallback(onGranted)
        end)
    end

    track(unlockButton.MouseButton1Click:Connect(grantAccess))
    track(keyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            grantAccess()
        end
    end))
    track(discordButton.MouseButton1Click:Connect(function()
        playToggleClick(true)
        if copyText(SETTINGS.DiscordInviteURL) then
            status.Text = "Discord invite copied. Join for the key, supported games, and support."
            status.TextColor3 = COLORS.sectionSuccess
        else
            status.Text = "Clipboard access is unavailable. Open " .. SETTINGS.Discord
            status.TextColor3 = COLORS.sectionError
        end
    end))

    fluidTween(gate, 0.28, {GroupTransparency = 0}, Enum.EasingStyle.Quint)
    fluidTween(cardScale, 0.36, {Scale = 1}, Enum.EasingStyle.Back)
    task.delay(0.34, function()
        if keyBox.Parent then
            keyBox:CaptureFocus()
        end
    end)
    return false
end

function Window:ForgetKeyAccess()
    forgetRememberedAccess()
    gui:SetAttribute("AccessGateState", "Forgotten")
end

function Window:Destroy()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
    if hubMusic.Parent then
        hubMusic:Stop()
        hubMusic:Destroy()
    end
    if gui.Parent then
        gui:Destroy()
    end
    if snowGui.Parent then
        snowGui:Destroy()
    end
    if notificationGui.Parent then
        notificationGui:Destroy()
    end
    if statusGui.Parent then
        statusGui:Destroy()
    end
end

function Window:PlayIntro()
    if not SETTINGS.IntroEnabled then
        main.Visible = true
        setHubMusicVisible(true, false)
        return
    end

    local duration = math.max(tonumber(SETTINGS.IntroDuration) or 5, 1.5)
    local fadeInDuration = math.min(0.35, duration * 0.15)
    -- Give the music and welcome screen room to resolve instead of cutting away abruptly.
    local fadeOutDuration = math.min(1.15, duration * 0.32)
    local blackDelay = math.min(0.65, duration * 0.25)
    local holdDuration = math.max(duration - blackDelay - fadeInDuration - fadeOutDuration, 0)

    local intro = create("Frame", {
        Name = "VORIntro",
        Active = true,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(3, 1, 8),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 500,
    }, gui)
    create("UIGradient", {
        Rotation = 115,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(2, 1, 6)),
            ColorSequenceKeypoint.new(0.48, Color3.fromRGB(31, 9, 51)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(7, 3, 15)),
        }),
    }, intro)

    local introSound = nil
    if SETTINGS.IntroSoundEnabled and tostring(SETTINGS.IntroSoundId or "") ~= "" then
        introSound = create("Sound", {
            Name = "FrozenIntroChime",
            SoundId = tostring(SETTINGS.IntroSoundId),
            Volume = 0,
            PlaybackSpeed = math.clamp(tonumber(SETTINGS.IntroSoundPlaybackSpeed) or 1, 0.25, 3),
            Looped = false,
            PlayOnRemove = false,
        }, intro)
    end

    local introPianoSound = SETTINGS.IntroPianoEnabled and hubMusic or nil

    local INTRO_DESIGN_SIZE = Vector2.new(900, 620)
    local introContent = create("Frame", {
        Name = "FloatingIntroContent",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(INTRO_DESIGN_SIZE.X, INTRO_DESIGN_SIZE.Y),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 501,
    }, intro)
    local introContentScale = create("UIScale", {
        Name = "ResponsiveIntroScale",
        Scale = 1,
    }, introContent)
    local introSafeCenter = Vector2.new(0, 0)

    local function updateIntroLayout()
        local viewport, leftInset, topInset, rightInset, bottomInset = getSafeViewportBounds()
        if not viewport then
            return
        end
        local availableWidth = math.max(1, viewport.X - leftInset - rightInset - 16)
        local availableHeight = math.max(1, viewport.Y - topInset - bottomInset - 16)
        introContentScale.Scale = math.clamp(math.min(
            availableWidth / INTRO_DESIGN_SIZE.X,
            availableHeight / INTRO_DESIGN_SIZE.Y
        ), 0.38, 1)
        introSafeCenter = Vector2.new(
            leftInset + (viewport.X - leftInset - rightInset) * 0.5,
            topInset + (viewport.Y - topInset - bottomInset) * 0.5
        )
        introContent.Position = UDim2.fromOffset(introSafeCenter.X, introSafeCenter.Y + 6)
    end
    updateIntroLayout()

    local introGlow = create("ImageLabel", {
        Name = "VorBloom",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -178),
        Size = UDim2.fromOffset(210, 210),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = "rbxasset://textures/particles/sparkles_main.dds",
        ImageColor3 = COLORS.accent,
        ImageTransparency = 1,
        Rotation = -18,
        ZIndex = 501,
    }, intro)

    local introLogo = create("Frame", {
        Name = "FloatingVORLogo",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, -180),
        Size = UDim2.fromOffset(108, 108),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Rotation = -8,
        ZIndex = 502,
    }, intro)

    local introLogoImage = create("ImageLabel", {
        Name = "UploadedVORLogo",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Image = tostring(SETTINGS.ProfileLogoImageId or ""),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 503,
    }, introLogo)

    -- Rotate the decal itself so the parent frame can keep handling the floating motion.
    -- RenderStepped keeps the clockwise rotation smooth at any frame rate.
    local introLogoSpinSpeed = math.max(0, tonumber(SETTINGS.IntroLogoSpinSpeed) or 52)
    local introLogoSpinConnection
    introLogoSpinConnection = RunService.RenderStepped:Connect(function(deltaTime)
        if not introLogoImage.Parent then
            if introLogoSpinConnection then
                introLogoSpinConnection:Disconnect()
                introLogoSpinConnection = nil
            end
            return
        end

        introLogoImage.Rotation = (introLogoImage.Rotation + introLogoSpinSpeed * math.min(deltaTime, 0.05)) % 360
    end)

    local introFlakes = {}
    local introRandom = Random.new(2026)
    local introSymbols = {utf8.char(0x25C6), utf8.char(0x25C7), utf8.char(0x2726), utf8.char(0x2727), utf8.char(0x2756)}
    for flakeIndex = 1, 22 do
        local startX = introRandom:NextNumber(0.03, 0.97)
        local startY = introRandom:NextNumber(-0.20, 0.82)
        local flake = create("TextLabel", {
            Name = "IntroFlake" .. flakeIndex,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(startX, 0, startY, 0),
            Size = UDim2.fromOffset(52, 52),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = introSymbols[introRandom:NextInteger(1, #introSymbols)],
            TextColor3 = COLORS.toggleOnBright,
            TextSize = introRandom:NextInteger(16, 34),
            TextStrokeColor3 = COLORS.accentDark,
            TextStrokeTransparency = 0.42,
            TextTransparency = introRandom:NextNumber(0.12, 0.48),
            Rotation = introRandom:NextInteger(-30, 30),
            ZIndex = 501,
        }, intro)
        table.insert(introFlakes, flake)
        TweenService:Create(
            flake,
            TweenInfo.new(duration + 1.2, Enum.EasingStyle.Linear),
            {
                Position = UDim2.new(math.clamp(startX + introRandom:NextNumber(-0.08, 0.08), 0.02, 0.98), 0, startY + 0.72, 0),
                Rotation = flake.Rotation + introRandom:NextInteger(80, 190),
            }
        ):Play()
    end

    local title = makeLabel(intro, "WELCOME", UDim2.new(0.5, 0, 0.5, -50), UDim2.new(1, -48, 0, 110), SNOW_WHITE, 84, Enum.Font.GothamBold)
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextTransparency = 1
    title.TextStrokeColor3 = COLORS.accentDark
    title.TextStrokeTransparency = 1
    title.ZIndex = 504
    local titleStroke = addStroke(title, COLORS.accent, 1.4, 1)

    local iceLine = create("Frame", {
        Name = "IceRevealLine",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 12),
        Size = UDim2.fromOffset(0, 2),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 0.10,
        BorderSizePixel = 0,
        ZIndex = 504,
    }, intro)
    addCorner(iceLine, 1)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, COLORS.accentDark),
            ColorSequenceKeypoint.new(0.50, SNOW_WHITE),
            ColorSequenceKeypoint.new(1.00, COLORS.accentDark),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 1),
            NumberSequenceKeypoint.new(0.18, 0),
            NumberSequenceKeypoint.new(0.82, 0),
            NumberSequenceKeypoint.new(1.00, 1),
        }),
    }, iceLine)

    local identityText = SETTINGS.IntroName or LocalPlayer.Name
    local identity = makeLabel(intro, identityText, UDim2.new(0.5, 0, 0.5, 76), UDim2.new(1, -48, 0, 76), COLORS.accent, 56, Enum.Font.GothamSemibold)
    identity.AnchorPoint = Vector2.new(0.5, 0.5)
    identity.TextXAlignment = Enum.TextXAlignment.Center
    identity.TextTransparency = 1
    identity.ZIndex = 504

    local discord = makeLabel(intro, SETTINGS.Discord, UDim2.new(0.5, 0, 0.5, 148), UDim2.new(1, -48, 0, 52), Color3.fromRGB(198, 163, 230), 30, Enum.Font.GothamSemibold)
    discord.AnchorPoint = Vector2.new(0.5, 0.5)
    discord.TextXAlignment = Enum.TextXAlignment.Center
    discord.TextTransparency = 1
    discord.ZIndex = 504

    -- Float the complete center composition while the VOR energy particles continue independently.
    for _, centerObject in ipairs({introGlow, introLogo, title, iceLine, identity, discord}) do
        centerObject.Parent = introContent
    end

    -- "Suit assembly" pieces: they converge while the actual hub powers on behind them.
    local assemblyPieces = {}
    local assemblyOffsets = {
        {-650, -220, -118, -66, 188, 6}, {650, -205, 124, -74, 164, -5},
        {-720, 8, -132, -8, 226, 4}, {720, 18, 138, 8, 204, -4},
        {-590, 248, -104, 74, 172, 7}, {590, 236, 112, 68, 194, -7},
    }
    for index, values in ipairs(assemblyOffsets) do
        local piece = create("Frame", {
            Name = "AssemblyShard" .. index,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, values[1], 0.5, values[2]),
            Size = UDim2.fromOffset(values[5], 3),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Rotation = values[6],
            ZIndex = 506,
        }, intro)
        addCorner(piece, 2)
        table.insert(assemblyPieces, {Object = piece, Target = UDim2.new(0.5, values[3], 0.5, values[4])})
    end

    if introPianoSound then
        pcall(function()
            setHubMusicVisible(true, true)
            gui:SetAttribute("IntroMusicStarted", true)
            gui:SetAttribute("IntroMusicAsset", tostring(SETTINGS.IntroPianoSoundId))
            gui:SetAttribute("IntroMusicLoaded", introPianoSound.IsLoaded)
            task.delay(0.20, function()
                if introPianoSound.Parent then
                    gui:SetAttribute("IntroMusicPlaying", introPianoSound.IsPlaying)
                end
            end)
        end)
    end

    task.wait(blackDelay)
    if introSound then
        pcall(function()
            introSound:Play()
            TweenService:Create(introSound, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Volume = math.clamp(tonumber(SETTINGS.IntroSoundVolume) or 0.32, 0, 1),
            }):Play()
        end)
    end
    local fadeInInfo = TweenInfo.new(fadeInDuration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local contentFloat = TweenService:Create(
        introContent,
        TweenInfo.new(1.20, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = UDim2.fromOffset(introSafeCenter.X, introSafeCenter.Y - 10)}
    )
    contentFloat:Play()
    TweenService:Create(introGlow, TweenInfo.new(fadeInDuration * 1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        ImageTransparency = 0.58,
        Size = UDim2.fromOffset(230, 230),
        Rotation = 8,
    }):Play()
    TweenService:Create(introLogo, TweenInfo.new(fadeInDuration * 1.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Rotation = 0,
        Size = UDim2.fromOffset(130, 130),
    }):Play()
    TweenService:Create(introLogoImage, fadeInInfo, {ImageTransparency = 0}):Play()
    local logoFloat = TweenService:Create(
        introLogo,
        TweenInfo.new(0.78, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = UDim2.new(0.5, 0, 0.5, -170)}
    )
    logoFloat:Play()
    TweenService:Create(iceLine, TweenInfo.new(fadeInDuration * 1.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(390, 2),
    }):Play()
    TweenService:Create(titleStroke, fadeInInfo, {Transparency = 0.25}):Play()
    local titleIn = TweenService:Create(title, fadeInInfo, {TextTransparency = 0, TextStrokeTransparency = 0.68})
    titleIn:Play()
    TweenService:Create(identity, fadeInInfo, {TextTransparency = 0}):Play()
    TweenService:Create(discord, fadeInInfo, {TextTransparency = 0}):Play()
    titleIn.Completed:Wait()

    task.wait(holdDuration)
    if main.Parent then
        -- Assemble the real interface pieces, rather than simply zooming in one flat window.
        if Window.UpdateScale then
            Window:UpdateScale()
        end
        local finalHubPosition = main.Position
        main.Visible = true
        uiScaleAnimation.Value = 0.92
        main.Position = UDim2.new(finalHubPosition.X.Scale, finalHubPosition.X.Offset, finalHubPosition.Y.Scale, finalHubPosition.Y.Offset + 14)
        TweenService:Create(uiScaleAnimation, TweenInfo.new(0.76, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Value = 1}):Play()
        TweenService:Create(main, TweenInfo.new(0.76, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position = finalHubPosition}):Play()

        local assemblyParts = {
            {Object = contentBackdrop, Start = Vector2.new(-212, 46), Delay = 0.00},
            {Object = header, Start = Vector2.new(-260, -192), Delay = 0.06},
            {Object = sidebar, Start = Vector2.new(-250, 156), Delay = 0.12},
            {Object = avatarCard, Start = Vector2.new(-188, -84), Delay = 0.18},
            {Object = welcomeCard, Start = Vector2.new(92, -104), Delay = 0.23},
            {Object = headshotCard, Start = Vector2.new(238, -82), Delay = 0.29},
            {Object = searchFrame, Start = Vector2.new(132, -170), Delay = 0.34},
            {Object = pageHolder, Start = Vector2.new(128, 110), Delay = 0.39},
        }
        for _, part in ipairs(assemblyParts) do
            local object = part.Object
            if object and object.Parent then
                local finalPosition = object.Position
                local assemblyScale = object:FindFirstChild("IntroAssemblyScale")
                if not assemblyScale then
                    assemblyScale = create("UIScale", {Name = "IntroAssemblyScale", Scale = 1}, object)
                end
                object.Position = UDim2.new(0.5, part.Start.X, 0.5, part.Start.Y)
                assemblyScale.Scale = 0.42
                task.delay(part.Delay, function()
                    if object.Parent then
                        TweenService:Create(object, TweenInfo.new(0.62, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                            Position = finalPosition,
                        }):Play()
                        TweenService:Create(assemblyScale, TweenInfo.new(0.62, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                            Scale = 1,
                        }):Play()
                    end
                end)
            end
        end
    end

    local fadeOutInfo = TweenInfo.new(fadeOutDuration, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
    local assemblyInfo = TweenInfo.new(math.min(0.78, fadeOutDuration * 0.74), Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    for _, assemblyPiece in ipairs(assemblyPieces) do
        assemblyPiece.Object.BackgroundTransparency = 0.18
        TweenService:Create(assemblyPiece.Object, assemblyInfo, {
            Position = assemblyPiece.Target,
            BackgroundTransparency = 1,
        }):Play()
    end
    local backgroundOut = TweenService:Create(intro, fadeOutInfo, {BackgroundTransparency = 1})
    backgroundOut:Play()
    contentFloat:Cancel()
    logoFloat:Cancel()
    TweenService:Create(introGlow, fadeOutInfo, {ImageTransparency = 1, Size = UDim2.fromOffset(300, 300)}):Play()
    TweenService:Create(introLogo, fadeOutInfo, {Rotation = 8, Size = UDim2.fromOffset(146, 146)}):Play()
    TweenService:Create(introLogoImage, fadeOutInfo, {ImageTransparency = 1}):Play()
    TweenService:Create(iceLine, fadeOutInfo, {BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 1)}):Play()
    TweenService:Create(titleStroke, fadeOutInfo, {Transparency = 1}):Play()
    TweenService:Create(title, fadeOutInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    TweenService:Create(identity, fadeOutInfo, {TextTransparency = 1}):Play()
    TweenService:Create(discord, fadeOutInfo, {TextTransparency = 1}):Play()
    local audioFadeOutInfo = TweenInfo.new(fadeOutDuration + 0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    if introSound then
        TweenService:Create(introSound, audioFadeOutInfo, {Volume = 0}):Play()
    end
    for _, flake in ipairs(introFlakes) do
        TweenService:Create(flake, fadeOutInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    end
    backgroundOut.Completed:Wait()
    task.wait(0.35) -- finish the gentle audio tail after the screen has cleared.

    if introLogoSpinConnection then
        introLogoSpinConnection:Disconnect()
        introLogoSpinConnection = nil
    end
    if intro.Parent then
        intro:Destroy()
    end
    snowGui.Enabled = SETTINGS.SnowEnabled and hubVisible and not Window.Minimized
    setHubMusicVisible(hubVisible and not Window.Minimized, false)
end

track(UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == SETTINGS.ToggleKey then
        Window:ToggleVisible()
    end
end))

track(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    if not Window.ActivePage then
        return
    end
    local query = string.lower(searchBox.Text)
    for _, item in ipairs(Window.ActivePage.SearchItems) do
        item.Object.Visible = query == "" or string.find(item.Text, query, 1, true) ~= nil
    end
end))

function Window:ClampToViewport(targetSize, targetPosition)
    local viewport, leftInset, topInset, rightInset, bottomInset = getSafeViewportBounds()
    if not viewport then
        return main.Position
    end

    local size = targetSize or main.Size
    local position = targetPosition or main.Position
    local scale = math.max(0.01, uiScale.Scale)
    local visualWidth = math.max(1, (viewport.X * size.X.Scale + size.X.Offset) * scale)
    local visualHeight = math.max(1, (viewport.Y * size.Y.Scale + size.Y.Offset) * scale)
    local anchorX = viewport.X * position.X.Scale + position.X.Offset
    local anchorY = viewport.Y * position.Y.Scale + position.Y.Offset
    local margin = 8

    local safeLeft = leftInset + margin
    local safeTop = topInset + margin
    local safeRight = viewport.X - rightInset - margin
    local safeBottom = viewport.Y - bottomInset - margin

    local minimumX = safeLeft + visualWidth * main.AnchorPoint.X
    local maximumX = safeRight - visualWidth * (1 - main.AnchorPoint.X)
    local minimumY = safeTop + visualHeight * main.AnchorPoint.Y
    local maximumY = safeBottom - visualHeight * (1 - main.AnchorPoint.Y)
    if minimumX > maximumX then
        minimumX, maximumX = (safeLeft + safeRight) * 0.5, (safeLeft + safeRight) * 0.5
    end
    if minimumY > maximumY then
        minimumY, maximumY = (safeTop + safeBottom) * 0.5, (safeTop + safeBottom) * 0.5
    end

    main.Position = UDim2.fromOffset(
        math.clamp(anchorX, minimumX, maximumX),
        math.clamp(anchorY, minimumY, maximumY)
    )
    return main.Position
end

function Window:ClampMinimizedCircle(targetPosition)
    local viewport, leftInset, topInset, rightInset, bottomInset = getSafeViewportBounds()
    if not viewport then
        return minimizedCircle.Position
    end

    local position = targetPosition or minimizedCircle.Position
    local diameter = math.max(44, tonumber(SETTINGS.MinimizedCircleSize) or 66)
    local radius = diameter * 0.5
    local margin = 8
    local x = viewport.X * position.X.Scale + position.X.Offset
    local y = viewport.Y * position.Y.Scale + position.Y.Offset

    minimizedCircle.Position = UDim2.fromOffset(
        math.clamp(x, leftInset + margin + radius, viewport.X - rightInset - margin - radius),
        math.clamp(y, topInset + margin + radius, viewport.Y - bottomInset - margin - radius)
    )
    return minimizedCircle.Position
end

function Window:BeginDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local pointer = input.Position
        for _, button in ipairs({minimizeButton, closeButton}) do
            local topLeft = button.AbsolutePosition
            local bottomRight = topLeft + button.AbsoluteSize
            if pointer.X >= topLeft.X and pointer.X <= bottomRight.X and pointer.Y >= topLeft.Y and pointer.Y <= bottomRight.Y then
                return
            end
        end
        self.Dragging = true
        self.DragStart = pointer
        self.DragStartPosition = main.Position
    end
end

for _, dragSurface in ipairs({header, sidebar, contentBackdrop, welcomeCard, avatarCard}) do
    dragSurface.Active = true
    track(dragSurface.InputBegan:Connect(function(input)
        Window:BeginDrag(input)
    end))
end

track(UserInputService.InputChanged:Connect(function(input)
    if Window.Dragging and Window.DragStart and Window.DragStartPosition and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - Window.DragStart
        local proposed = UDim2.new(
            Window.DragStartPosition.X.Scale,
            Window.DragStartPosition.X.Offset + delta.X,
            Window.DragStartPosition.Y.Scale,
            Window.DragStartPosition.Y.Offset + delta.Y
        )
        Window:ClampToViewport(Window.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560), proposed)
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Window.Dragging = false
        Window.DragStart = nil
        Window.DragStartPosition = nil
    end
end))

local minimizedAnimatedContent = {sidebar, searchFrame, pageHolder, welcomeCard, avatarCard, contentBackdrop, icicleLayer}
local minimizeTransitionToken = 0

local function setMainContentVisible(visible)
    for _, object in ipairs(minimizedAnimatedContent) do
        object.Visible = visible and (object ~= avatarCard or SETTINGS.AvatarPreviewEnabled) or false
    end
end

function Window:GetMinimizeStyle()
    return minimizedStyle
end

function Window:SetMinimizeStyle(value)
    local normalized = normalizeMinimizeStyle(value)
    if minimizedStyle == normalized then
        gui:SetAttribute("MinimizedStyle", minimizedStyle)
        return minimizedStyle
    end

    minimizedStyle = normalized
    gui:SetAttribute("MinimizedStyle", minimizedStyle)
    if self.Minimized then
        self:SetMinimized(true, true)
    end
    return minimizedStyle
end

function Window:SetMinimized(value, forceRefresh)
    value = value == true
    if self.Minimized == value and not forceRefresh then
        return
    end

    minimizeTransitionToken += 1
    local token = minimizeTransitionToken
    self.Minimized = value
    minimizeButton.Text = value and "+" or "-"
    playToggleClick(not value)
    snowGui.Enabled = SETTINGS.SnowEnabled and hubEffectsActive()
    setHubMusicVisible(hubEffectsActive(), false)
    gui:SetAttribute("HubEffectsPaused", value)
    gui:SetAttribute("MinimizedStyle", minimizedStyle)

    if value and minimizedStyle == MINIMIZE_CIRCLE_STYLE then
        -- Place the compact button where the hub currently lives, then let the
        -- user drag it anywhere inside the safe mobile/desktop viewport.
        minimizedCircle.Position = main.Position
        self:ClampMinimizedCircle()
        minimizedCircle.Visible = true
        minimizedCircle.GroupTransparency = 1
        minimizedCircleScale.Scale = 0.70
        fluidTween(minimizedCircle, 0.20, {GroupTransparency = 0}, Enum.EasingStyle.Quint)
        fluidTween(minimizedCircleScale, 0.26, {Scale = 1}, Enum.EasingStyle.Back)

        if main.Visible then
            fluidTween(uiScaleAnimation, 0.17, {Value = 0.90}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        end
        task.delay(0.18, function()
            if token == minimizeTransitionToken and self.Minimized and minimizedStyle == MINIMIZE_CIRCLE_STYLE then
                main.Visible = false
                main.Size = UDim2.fromOffset(850, 560)
                uiScaleAnimation.Value = 1
                main.ClipsDescendants = false
                setMainContentVisible(true)
            end
        end)
        return
    end

    if value then
        -- Original full-width minimize bar. This remains the default and keeps
        -- the exact PC behavior that was already working.
        if minimizedCircle.Visible then
            main.Position = minimizedCircle.Position
            fluidTween(minimizedCircle, 0.15, {GroupTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            fluidTween(minimizedCircleScale, 0.15, {Scale = 0.80}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
            task.delay(0.16, function()
                if token == minimizeTransitionToken and minimizedStyle == MINIMIZE_BAR_STYLE then
                    minimizedCircle.Visible = false
                end
            end)
        end

        main.Visible = true
        uiScaleAnimation.Value = math.min(uiScaleAnimation.Value, 0.985)
        setMainContentVisible(true)
        local targetSize = UDim2.fromOffset(850, 46)
        self:ClampToViewport(targetSize)
        main.ClipsDescendants = true
        fluidTween(main, 0.22, {Size = targetSize}, Enum.EasingStyle.Quint)
        fluidTween(uiScaleAnimation, 0.24, {Value = 0.985}, Enum.EasingStyle.Back)
        task.delay(0.23, function()
            if token == minimizeTransitionToken and self.Minimized and minimizedStyle == MINIMIZE_BAR_STYLE and main.Parent then
                setMainContentVisible(false)
                main.ClipsDescendants = false
                self:ClampToViewport(targetSize)
            end
        end)
        return
    end

    -- Restore from either compact style. When restoring from the circle, the
    -- full hub opens from the circle's dragged position and is then clamped.
    local restoringFromCircle = minimizedCircle.Visible
    if restoringFromCircle then
        main.Position = minimizedCircle.Position
        fluidTween(minimizedCircle, 0.16, {GroupTransparency = 1}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        fluidTween(minimizedCircleScale, 0.16, {Scale = 0.76}, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.17, function()
            if token == minimizeTransitionToken and not self.Minimized then
                minimizedCircle.Visible = false
            end
        end)
    end

    main.Visible = true
    main.Size = restoringFromCircle and UDim2.fromOffset(850, 560) or main.Size
    uiScaleAnimation.Value = restoringFromCircle and 0.88 or math.min(uiScaleAnimation.Value, 0.985)
    setMainContentVisible(true)
    local targetSize = UDim2.fromOffset(850, 560)
    self:ClampToViewport(targetSize)
    main.ClipsDescendants = true
    fluidTween(main, 0.30, {Size = targetSize}, Enum.EasingStyle.Quint)
    fluidTween(uiScaleAnimation, 0.28, {Value = 1}, Enum.EasingStyle.Back)
    task.delay(0.31, function()
        if token == minimizeTransitionToken and not self.Minimized and main.Parent then
            main.ClipsDescendants = false
            self:ClampToViewport(targetSize)
        end
    end)
end

track(minimizeButton.MouseButton1Click:Connect(function()
    Window:SetMinimized(not Window.Minimized)
end))

-- Dragging the compact circle does not restore it. A tap/click without a drag
-- restores the full hub, which is especially important for mobile users.
local circleDragging = false
local circleDragMoved = false
local circleDragStart = nil
local circleDragPosition = nil

track(minimizedCircleHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        circleDragging = true
        circleDragMoved = false
        circleDragStart = input.Position
        circleDragPosition = minimizedCircle.Position
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if circleDragging and circleDragStart and circleDragPosition
        and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - circleDragStart
        if delta.Magnitude > 5 then
            circleDragMoved = true
        end
        Window:ClampMinimizedCircle(UDim2.new(
            circleDragPosition.X.Scale,
            circleDragPosition.X.Offset + delta.X,
            circleDragPosition.Y.Scale,
            circleDragPosition.Y.Offset + delta.Y
        ))
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if circleDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        local shouldRestore = not circleDragMoved
        circleDragging = false
        circleDragMoved = false
        circleDragStart = nil
        circleDragPosition = nil
        if shouldRestore and Window.Minimized and minimizedStyle == MINIMIZE_CIRCLE_STYLE then
            Window:SetMinimized(false)
        end
    end
end))

track(closeButton.MouseButton1Click:Connect(function()
    Window:Destroy()
end))

track(minimizeButton.MouseEnter:Connect(function()
    minimizeButton.TextColor3 = COLORS.text
end))
track(minimizeButton.MouseLeave:Connect(function()
    minimizeButton.TextColor3 = COLORS.muted
end))
track(closeButton.MouseEnter:Connect(function()
    closeButton.TextColor3 = COLORS.error
end))
track(closeButton.MouseLeave:Connect(function()
    closeButton.TextColor3 = COLORS.muted
end))

function Window:UpdateScale()
    local viewport, leftInset, topInset, rightInset, bottomInset = getSafeViewportBounds()
    if not viewport then
        return
    end

    local availableWidth = math.max(1, viewport.X - leftInset - rightInset - 16)
    local availableHeight = math.max(1, viewport.Y - topInset - bottomInset - 16)
    responsiveViewportScale = math.clamp(math.min(
        availableWidth / HUB_DESIGN_SIZE.X,
        availableHeight / HUB_DESIGN_SIZE.Y
    ), HUB_MIN_SCALE, 1)
    applyMainScale()
    if self.Minimized and minimizedStyle == MINIMIZE_CIRCLE_STYLE then
        self:ClampMinimizedCircle()
    else
        self:ClampToViewport(self.Minimized and UDim2.fromOffset(850, 46) or UDim2.fromOffset(850, 560))
    end
end

local viewportSizeConnection = nil
local function bindViewportScaleWatcher()
    if viewportSizeConnection then
        viewportSizeConnection:Disconnect()
        viewportSizeConnection = nil
    end

    local camera = workspace.CurrentCamera
    if camera then
        viewportSizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            Window:UpdateScale()
        end)
        track(viewportSizeConnection)
    end
    Window:UpdateScale()
end

bindViewportScaleWatcher()
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewportScaleWatcher))

task.spawn(function()
    local experienceName = "Unknown Game"
    local ok, information = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and information and type(information.Name) == "string" and information.Name ~= "" then
        experienceName = information.Name
    end
    if brandTitle.Parent then
        brandTitle.Text = SETTINGS.Title
        brandSubtitle.Text = SETTINGS.Discord
        welcomeSubtitle.Text = SETTINGS.Title .. " | " .. experienceName .. " | " .. SETTINGS.Discord .. " | Created by " .. SETTINGS.Creator
    end
end)

-- BUILD YOUR MENU BELOW THIS LINE.
-- Game controls stay inside Home categories; Settings remains configuration-only.
local function createCategoryHomePage(options)
options = options or {}
local textOnlyTabs = options.TextOnly == true
local categoryBarHeight = textOnlyTabs and 54 or 96
local categoryContentTop = categoryBarHeight + 8
local HomePage = Window:AddPage("Home")

-- Home uses large frozen decal cards. The images work as the category tabs while
-- the selected card reveals its controls below without changing the page layout.
HomePage.LeftColumn.Visible = false
HomePage.RightColumn.Visible = false

local categoryBar = create("Frame", {
    Name = "HomeCategoryBar",
    Size = UDim2.new(1, 0, 0, categoryBarHeight),
    BackgroundColor3 = COLORS.surface,
    BackgroundTransparency = math.min(0.86, hubTransparencyValue + 0.08),
    BorderSizePixel = 0,
    ZIndex = 20,
}, HomePage.Frame)
addCorner(categoryBar, 6)
addVorTrim(categoryBar, 6, 3, 0.08)
addVorCornerArmor(categoryBar, 4, 15, 0.38)

-- Keep the functional layout in its own holder. VOR trim and corner armor use
-- GuiObjects, so placing a UIListLayout directly on categoryBar makes Roblox
-- count those decorative frames as extra tab cards and pushes the real tabs
-- beyond the right edge.
local categoryButtonsHolder = create(textOnlyTabs and "ScrollingFrame" or "Frame", {
    Name = "CategoryButtonsHolder",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = textOnlyTabs and UDim2.fromOffset(0, 0) or nil,
    AutomaticCanvasSize = textOnlyTabs and Enum.AutomaticSize.X or nil,
    ScrollingDirection = textOnlyTabs and Enum.ScrollingDirection.X or nil,
    ScrollBarThickness = textOnlyTabs and 3 or 0,
    ScrollBarImageColor3 = textOnlyTabs and COLORS.accent or COLORS.line,
    ZIndex = 20,
}, categoryBar)
create("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, categoryButtonsHolder)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = textOnlyTabs and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, categoryButtonsHolder)

local categoryTransitionCurtain, categoryTransitionSweep = makeTransitionCurtain(
    HomePage.Frame,
    "CategoryTransitionCurtain",
    UDim2.fromOffset(0, categoryContentTop),
    UDim2.new(1, 0, 1, -categoryContentTop),
    80
)

local homeCategories = {}
local activeHomeCategory = nil
local categoryTransitioning = false
local queuedHomeCategory = nil

local function animateHomeCategoryButtons(selected)
    for _, category in pairs(homeCategories) do
        local active = category == selected
        fluidTween(category.Button, 0.24, {
            BackgroundTransparency = active and 0.02 or 0.16,
            BackgroundColor3 = active and Color3.fromRGB(40, 15, 68) or COLORS.surface2,
            ImageTransparency = active and 0.02 or 0.14,
        }, Enum.EasingStyle.Quart)
        fluidTween(category.Label, 0.22, {
            TextColor3 = active and SNOW_WHITE or COLORS.sectionMuted,
            TextTransparency = active and 0 or 0.08,
        }, Enum.EasingStyle.Quart)
        fluidTween(category.Stroke, 0.22, {
            Color = active and COLORS.accentDark or COLORS.line,
            Thickness = active and 2 or 1,
            Transparency = active and 0.02 or 0.34,
        }, Enum.EasingStyle.Quart)

        category.Accent.Visible = true
        category.SelectedGlow.Visible = true
        fluidTween(category.Accent, 0.24, {
            BackgroundTransparency = active and 0 or 1,
            Size = active and UDim2.new(0.68, 0, 0, 4) or UDim2.new(0.18, 0, 0, 4),
        }, Enum.EasingStyle.Quart)
        fluidTween(category.SelectedGlow, 0.26, {
            BackgroundTransparency = active and 0.76 or 1,
            Size = active and UDim2.new(1, 10, 1, 10) or UDim2.new(0.92, 0, 0.92, 0),
        }, Enum.EasingStyle.Quart)
    end
end

local function selectHomeCategory(name)
    local selected = homeCategories[name]
    if not selected then
        return false
    end

    if categoryTransitioning then
        queuedHomeCategory = name
        return true
    end
    if activeHomeCategory == selected then
        return true
    end

    local previous = activeHomeCategory
    local direction = 1
    if previous and (selected.Order or 0) < (previous.Order or 0) then
        direction = -1
    end

    activeHomeCategory = selected
    animateHomeCategoryButtons(selected)
    HomePage.SearchItems = selected.SearchItems
    searchBox.Text = ""
    HomePage.Frame:SetAttribute("ActiveCategory", name)

    if not previous then
        for _, category in pairs(homeCategories) do
            category.Frame.Visible = category == selected
            category.Frame.Position = UDim2.fromOffset(0, categoryContentTop)
            category.Frame.ZIndex = category == selected and 3 or 1
        end
        return true
    end

    categoryTransitioning = true
    task.spawn(function()
        runMaskedSwap(categoryTransitionCurtain, categoryTransitionSweep, direction, function()
            for _, category in pairs(homeCategories) do
                local staleTween = activeTweens[category.Frame]
                if staleTween then
                    pcall(function()
                        staleTween:Cancel()
                    end)
                    activeTweens[category.Frame] = nil
                end
                category.Frame.Visible = category == selected
                category.Frame.ZIndex = category == selected and 3 or 1
                category.Frame.Position = category == selected
                    and UDim2.fromOffset(10 * direction, categoryContentTop)
                    or UDim2.fromOffset(0, categoryContentTop)
            end

            fluidTween(
                selected.Frame,
                0.24,
                {Position = UDim2.fromOffset(0, categoryContentTop)},
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out
            )
        end)

        if selected.Frame.Parent then
            selected.Frame.Visible = true
            selected.Frame.Position = UDim2.fromOffset(0, categoryContentTop)
            selected.Frame.ZIndex = 3
        end

        categoryTransitioning = false
        local queuedName = queuedHomeCategory
        queuedHomeCategory = nil
        if queuedName and homeCategories[queuedName] and activeHomeCategory ~= homeCategories[queuedName] then
            selectHomeCategory(queuedName)
        end
    end)

    return true
end

local function addHomeCategory(name, order, assetId)
    local button = create("ImageButton", {
        Name = name .. "Tab",
        LayoutOrder = order,
        Size = UDim2.fromOffset(textOnlyTabs and math.max(132, math.min(210, #name * 10 + 42)) or 142, textOnlyTabs and 42 or 84),
        AutoButtonColor = false,
        BackgroundColor3 = COLORS.surface2,
        BackgroundTransparency = 0.16,
        BorderSizePixel = 0,
        Image = textOnlyTabs and "" or ("rbxthumb://type=Asset&id=" .. tostring(assetId) .. "&w=420&h=420"),
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        ImageTransparency = textOnlyTabs and 1 or 0.14,
        ScaleType = Enum.ScaleType.Crop,
        ZIndex = 21,
    }, categoryButtonsHolder)
    addCorner(button, 6)
    local buttonStroke = addStroke(button, COLORS.line, 1, 0.34)
    addVorCornerArmor(button, 4, 12, 0.54)

    local selectedGlow = create("Frame", {
        Name = "SelectedGlow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 10, 1, 10),
        BackgroundColor3 = COLORS.accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 20,
    }, button)
    addCorner(selectedGlow, 8)

    local caption = create("Frame", {
        Name = "Caption",
        AnchorPoint = textOnlyTabs and Vector2.zero or Vector2.new(0, 1),
        Position = textOnlyTabs and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 1),
        Size = textOnlyTabs and UDim2.fromScale(1, 1) or UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Color3.fromRGB(10, 5, 18),
        BackgroundTransparency = textOnlyTabs and 0.42 or 0.14,
        BorderSizePixel = 0,
        ZIndex = 23,
    }, button)
    addCorner(caption, 9)
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.fromRGB(79, 31, 124), Color3.fromRGB(8, 4, 15)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.36),
            NumberSequenceKeypoint.new(1, 0.02),
        }),
    }, caption)

    local label = create("TextLabel", {
        Name = "CategoryName",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = name,
        TextColor3 = COLORS.sectionText,
        TextSize = textOnlyTabs and 16 or 13,
        TextStrokeColor3 = Color3.fromRGB(3, 1, 8),
        TextStrokeTransparency = 0.22,
        ZIndex = 24,
    }, caption)

    local accent = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, textOnlyTabs and -2 or -1),
        Size = UDim2.new(0.68, 0, 0, 4),
        BackgroundColor3 = COLORS.toggleOnBright,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = true,
        ZIndex = 25,
    }, button)
    addCorner(accent, 3)

    track(button.MouseEnter:Connect(function()
        if activeHomeCategory ~= homeCategories[name] then
            fluidTween(button, 0.16, {
                ImageTransparency = 0.04,
                BackgroundTransparency = 0.08,
            })
        end
    end))
    track(button.MouseLeave:Connect(function()
        if activeHomeCategory ~= homeCategories[name] then
            fluidTween(button, 0.18, {
                ImageTransparency = 0.14,
                BackgroundTransparency = 0.16,
            })
        end
    end))

    attachFluidScale(button, button, 1.018, 0.965)
    attachPressRipple(button, button)

    local frame = create("Frame", {
        Name = name .. "Category",
        Position = UDim2.fromOffset(0, categoryContentTop),
        Size = UDim2.new(1, 0, 1, -categoryContentTop),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
    }, HomePage.Frame)
    local leftColumn = create("ScrollingFrame", {
        Name = "LeftColumn",
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, leftColumn)
    local rightColumn = create("ScrollingFrame", {
        Name = "RightColumn",
        Position = UDim2.new(0.5, 6, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = COLORS.accentDark,
    }, frame)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, rightColumn)

    local category = setmetatable({
        Name = name,
        Order = order,
        Frame = frame,
        Button = button,
        Label = label,
        Stroke = buttonStroke,
        Accent = accent,
        SelectedGlow = selectedGlow,
        LeftColumn = leftColumn,
        RightColumn = rightColumn,
        SearchItems = {},
        NextSide = "Left",
    }, {__index = PageMethods})
    homeCategories[name] = category
    track(button.MouseButton1Click:Connect(function()
        playToggleClick(true)
        selectHomeCategory(name)
    end))
    return category
end

return HomePage, addHomeCategory, selectHomeCategory
end

local function buildReviveFeatures()
local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
local ToolsPage = Window:AddPage("Tools")

local OvernightPage = addHomeCategory("Overnight", 1, CATEGORY_DECALS.Overnight)
local CombatPage = addHomeCategory("Combat", 2, CATEGORY_DECALS.Combat)
local WeaponsPage = addHomeCategory("Weapons", 3, CATEGORY_DECALS.Weapons)
local ProgressPage = addHomeCategory("Progress", 4, CATEGORY_DECALS.Progress)
local VisualsPage = addHomeCategory("Visuals", 5, CATEGORY_DECALS.Visuals)

local OvernightSection = OvernightPage:AddSection("AFK Essentials", "Left")
local OvernightUpgradeSection = OvernightPage:AddSection("Overnight Upgrades", "Right")
local LiveSection = OvernightPage:AddSection("Live Status", "Right")
local CombatSection = CombatPage:AddSection("Combat Automation", "Left")
local CursedKingSection = CombatPage:AddSection("Special Bosses", "Left")
local SpecialPrioritySection = CombatPage:AddSection("Special Boss Priority", "Right")
local FarmSection = CombatPage:AddSection("Boss Progression Farm", "Right")
local TweenSection = CombatPage:AddSection("Enemy Tween", "Right")
local UpgradeSection = WeaponsPage:AddSection("Sword Automation", "Left")
local WeaponInfoSection = WeaponsPage:AddSection("Owned Weapons", "Right")
local ChallengeSection = ProgressPage:AddSection("Challenges", "Left")
local RebirthSection = ProgressPage:AddSection("Auto Rebirth", "Left")
local SoulRingSection = ProgressPage:AddSection("Soul Ring", "Right")
local RewardSection = ProgressPage:AddSection("Reward Automation", "Right")
local VisualSection = VisualsPage:AddSection("Character Visuals", "Left")
local VisualInfoSection = VisualsPage:AddSection("Visual Status", "Right")
local NotificationSection = VisualsPage:AddSection("Hub Notifications", "Right")
local OutfitSection = ToolsPage:AddSection("Local Outfit Preview", "Left")
local VoidArmorSection = ToolsPage:AddSection("VOR Void Armor", "Right")
local ToolsInfoSection = ToolsPage:AddSection("Tools Status", "Right")

selectHomeCategory("Overnight")

local statusLabel = LiveSection:AddLabel("Status: Loading Revive remotes...")
local remoteLabel = LiveSection:AddLabel("Remotes: Loading...")
local farmStatusLabel = LiveSection:AddLabel("Farm: Waiting")
local multiHitStatusLabel = LiveSection:AddLabel("Multi Hit: Disabled")
local reaperStatusLabel = LiveSection:AddLabel("Reaper: Reading unlock state...")
local cursedKingStatusLabel = LiveSection:AddLabel("Cursed King: Reading unlock state...")
local nightmareStatusLabel = LiveSection:AddLabel("Nightmare: Reading Death Tower state...")
local deathKingStatusLabel = LiveSection:AddLabel("Death King: Reading unlock state...")
local priorityStatusLabel = LiveSection:AddLabel("Special Priority: Disabled")
local tweenStatusLabel = LiveSection:AddLabel("Tween: Enemy 1 selected")
local weaponStatusLabel = WeaponInfoSection:AddLabel("Sword: Reading inventory...")
local visualStatusLabel = VisualInfoSection:AddLabel("Visuals: Local-only and reversible")
VisualInfoSection:AddLabel("All character effects are local-only, reversible, and reapplied after respawn.")
local discordReminderStatusLabel = NotificationSection:AddLabel("Discord Reminder: Every 15 minutes")
local outfitStatusLabel = ToolsInfoSection:AddLabel("Outfit: Your Roblox avatar")
local soulRingStatusLabel = SoulRingSection:AddLabel("Soul Ring: Reading slot 1...")
local soulRingCurrencyLabel = SoulRingSection:AddLabel("Soul Stones: Reading... | Rerolls: Reading...")
ToolsInfoSection:AddLabel("Catalog previews and VOR Void Armor are client-only. Other players keep seeing your server avatar.")

local function setReviveStatus(message, success)
    statusLabel.Text = "Status: " .. tostring(message)
    statusLabel.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
end

local REMOTE_NAMES = {
    "attack",
    "attackResult",
    "staticReaperReq",
    "staticReaperResp",
    "getGroupReward",
    "startTimeLimitChallengeReq",
    "timeLimitChallengeResult",
    "enterTimeLimitBossReq",
    "levelTimeLimitBossReq",
    "setAfkResumeReq",
    "enhanceWeapon",
    "equipWeapon",
    "getSignReward",
    "receiveOnlineTimeReward",
    "claimSoulSpawner",
    "claimTimeLimitBossReward",
    "claimChallengeReward",
    "rebirth",
    "SetAutoRebirth",
    "claimReaperPityReward",
    "rollSigil",
    "SetAutoSigilRarity",
    "enhanceSoulRing",
    "rerollSoulRing",
}

remoteLabel.Text = "Remotes: 0 / " .. tostring(#REMOTE_NAMES) .. " ready"

local remotes = {}
local confirmedAttackSerial = {}
local reaperLocalCooldownUntil = 0
local specialResultSerial = 0
local specialResultSuccess = false
local function getRemoContainer()
    local rbxtsInclude = ReplicatedStorage:WaitForChild("rbxts_include", 12)
    local nodeModules = rbxtsInclude and rbxtsInclude:WaitForChild("node_modules", 12)
    local rbxts = nodeModules and nodeModules:WaitForChild("@rbxts", 12)
    local remo = rbxts and rbxts:WaitForChild("remo", 12)
    local src = remo and remo:WaitForChild("src", 12)
    return src and src:WaitForChild("container", 12)
end

local function fireRemote(name, ...)
    local remote = remotes[name]
    if not remote or not remote.Parent then
        setReviveStatus(name .. " remote is not ready", false)
        return false
    end
    local arguments = table.pack(...)
    local ok, err = pcall(function()
        remote:FireServer(table.unpack(arguments, 1, arguments.n))
    end)
    if not ok then
        setReviveStatus(name .. " failed: " .. tostring(err), false)
    end
    return ok
end

task.spawn(function()
    local container = getRemoContainer()
    if not container then
        remoteLabel.Text = "Remotes: container not found"
        remoteLabel.TextColor3 = COLORS.error
        setReviveStatus("Revive remote container was not found", false)
        return
    end

    local ready = 0
    for _, name in ipairs(REMOTE_NAMES) do
        local remote = container:FindFirstChild(name)
        if remote and remote:IsA("RemoteEvent") then
            remotes[name] = remote
            ready = ready + 1
        end
    end
    if remotes.attackResult then
        track(remotes.attackResult.OnClientEvent:Connect(function(...)
            local arguments = table.pack(...)
            local confirmedLevel = tonumber(arguments[arguments.n])
            if confirmedLevel and confirmedLevel >= 1 and confirmedLevel <= 15 then
                confirmedAttackSerial[confirmedLevel] = (confirmedAttackSerial[confirmedLevel] or 0) + 1
            end
        end))
    end
    if remotes.staticReaperResp then
        track(remotes.staticReaperResp.OnClientEvent:Connect(function(maxHpRemoved)
            reaperLocalCooldownUntil = workspace:GetServerTimeNow() + 20
            reaperStatusLabel.Text = "Reaper: Confirmed -" .. tostring(maxHpRemoved) .. " Max HP | 20s cooldown"
            reaperStatusLabel.TextColor3 = COLORS.success
        end))
    end
    if remotes.timeLimitChallengeResult then
        track(remotes.timeLimitChallengeResult.OnClientEvent:Connect(function(...)
            local arguments = table.pack(...)
            local success = false
            for index = 1, arguments.n do
                if type(arguments[index]) == "boolean" then
                    success = arguments[index]
                    break
                end
            end
            specialResultSuccess = success
            specialResultSerial += 1
        end))
    end
    remoteLabel.Text = "Remotes: " .. tostring(ready) .. " / " .. tostring(#REMOTE_NAMES) .. " ready"
    remoteLabel.TextColor3 = ready == #REMOTE_NAMES and COLORS.success or COLORS.muted
    setReviveStatus("Revive-only controls are ready", true)
end)

local state = {
    antiAfk = false,
    autoAttack = false,
    multiHit = false,
    reaper = false,
    cursedKing = false,
    deathKing = false,
    nightmare = false,
    specialPriority = false,
    priorityMulti = false,
    groupReward = false,
    challengeOne = false,
    challengeFive = false,
    autoUpgrade = false,
    dailyReward = false,
    onlineReward = false,
    soulSpawner = false,
    starterRewards = false,
    bossRewards = false,
    bossFarm = false,
    autoTween = false,
    autoEquipBest = false,
    autoRebirth = false,
    autoSoulRing = false,
    demonRealm = false,
    discordReminder = true,
}

local discordReminderInterval = 15 * 60
local nextDiscordReminderAt = os.clock() + discordReminderInterval
local function showDiscordReminder()
    Window:Notify(
        "VOR Hub • Discord",
        "Enjoying VOR Hub? Join our Discord: " .. SETTINGS.Discord,
        8
    )
    nextDiscordReminderAt = os.clock() + discordReminderInterval
    discordReminderStatusLabel.Text = "Discord Reminder: Shown | Next in 15:00"
    discordReminderStatusLabel.TextColor3 = COLORS.success
end

NotificationSection:AddToggle({
    Name = "Discord Reminder",
    Description = "Shows the frozen bottom-right Discord invitation every 15 minutes",
    Default = true,
    Flag = "revive_discord_reminder",
    Callback = function(enabled)
        state.discordReminder = enabled
        nextDiscordReminderAt = os.clock() + discordReminderInterval
        discordReminderStatusLabel.Text = enabled and "Discord Reminder: Enabled | Next in 15:00" or "Discord Reminder: Disabled"
        discordReminderStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
    end,
})

NotificationSection:AddButton({
    Name = "Test Discord Reminder",
    Description = "Shows the themed bottom-right notification immediately",
    Persist = false,
    Callback = showDiscordReminder,
})

NotificationSection:AddLabel("The reminder stays visible even while the main hub is hidden with Right Ctrl.")

local antiAfkStatusLabel = OvernightSection:AddLabel("Anti-AFK: Disabled")
local antiAfkControl
antiAfkControl = OvernightSection:AddToggle({
    Name = "Anti-AFK / Anti-Idle",
    Description = "Responds when Roblox detects inactivity so overnight farming is not idle-kicked",
    Flag = "revive_anti_afk",
    Callback = function(enabled)
        state.antiAfk = enabled
        gui:SetAttribute("AntiAFKEnabled", enabled)
        antiAfkStatusLabel.Text = enabled and "Anti-AFK: Armed and waiting for an idle signal" or "Anti-AFK: Disabled"
        antiAfkStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and "Anti-AFK enabled" or "Anti-AFK disabled", enabled and true or nil)
    end,
})
gui:SetAttribute("AntiAFKEnabled", false)

task.spawn(function()
    while statusGui.Parent and gui.Parent do
        statusWidgetLabels.General.Text = statusLabel.Text
        statusWidgetLabels.General.TextColor3 = readableStatusColor(statusLabel.TextColor3)
        statusWidgetLabels.AFK.Text = antiAfkStatusLabel.Text
        statusWidgetLabels.AFK.TextColor3 = readableStatusColor(antiAfkStatusLabel.TextColor3)
        if state.demonRealm and state.demonRealmStatusLabel then
            statusWidgetLabels.Special.Text = state.demonRealmStatusLabel.Text
            statusWidgetLabels.Special.TextColor3 = readableStatusColor(state.demonRealmStatusLabel.TextColor3)
        else
            statusWidgetLabels.Special.Text = priorityStatusLabel.Text
            statusWidgetLabels.Special.TextColor3 = readableStatusColor(priorityStatusLabel.TextColor3)
        end
        statusWidgetLabels.Multi.Text = multiHitStatusLabel.Text
        statusWidgetLabels.Multi.TextColor3 = readableStatusColor(multiHitStatusLabel.TextColor3)
        statusWidgetLabels.Farm.Text = farmStatusLabel.Text .. " | " .. nightmareStatusLabel.Text
        statusWidgetLabels.Farm.TextColor3 = readableStatusColor(farmStatusLabel.TextColor3)
        statusWidgetLabels.Weapon.Text = weaponStatusLabel.Text
        statusWidgetLabels.Weapon.TextColor3 = readableStatusColor(weaponStatusLabel.TextColor3)
        task.wait(0.20)
    end
end)

local function performAntiAfkPulse()
    local camera = workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or CFrame.new()
    local ok = pcall(function()
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:Button2Down(Vector2.new(0, 0), cameraCFrame)
        task.wait(0.05)
        virtualUser:Button2Up(Vector2.new(0, 0), cameraCFrame)
    end)
    if ok then
        gui:SetAttribute("AntiAFKLastPulse", workspace:GetServerTimeNow())
        antiAfkStatusLabel.Text = "Anti-AFK: Idle pulse sent successfully"
        antiAfkStatusLabel.TextColor3 = COLORS.success
    else
        antiAfkStatusLabel.Text = "Anti-AFK: Virtual input was unavailable"
        antiAfkStatusLabel.TextColor3 = COLORS.error
    end
    return ok
end

track(LocalPlayer.Idled:Connect(function()
    if state.antiAfk and gui.Parent then
        performAntiAfkPulse()
    end
end))

OvernightSection:AddButton({
    Name = "Test Anti-AFK Pulse",
    Description = "Runs one harmless idle-protection pulse and updates the status above",
    Persist = false,
    Callback = function()
        if performAntiAfkPulse() then
            setReviveStatus("Anti-AFK test passed", true)
        else
            setReviveStatus("Anti-AFK test could not send virtual input", false)
        end
    end,
})

local overnightMultiHitControl
local overnightReaperControl
local overnightDeathKingControl
local overnightCursedKingControl
local overnightNightmareControl
local overnightSpecialPriorityControl
local overnightBossFarmControl
local overnightAutoEquipControl
local overnightAutoUpgradeControl
local overnightAutoRebirthControl
local overnightAutoSoulRingControl

local reaperBattleStore = nil
local rebirthStore = nil
local reaperUnlockLevel = 3
local reaperInterval = 20
local redDragonUnlockLevel = 5
local greenDragonUnlockLevel = 5
local nightmareUnlockLevel = 15
local rebirthTowerLevelRatio = 5
pcall(function()
    reaperBattleStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("battle"))
    rebirthStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("rebirth"))
    local globalConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbglobalconfig"))
    reaperUnlockLevel = tonumber(globalConfig.unlock_reaper_main_level_require) or reaperUnlockLevel
    reaperInterval = tonumber(globalConfig.static_reaper_interval_time) or reaperInterval
    redDragonUnlockLevel = tonumber(globalConfig.unlock_red_dragon_main_level_require) or redDragonUnlockLevel
    greenDragonUnlockLevel = tonumber(globalConfig.unlock_green_dragon_main_level_require) or greenDragonUnlockLevel
    nightmareUnlockLevel = tonumber(globalConfig.unlock_tower_main_level_require) or nightmareUnlockLevel
    rebirthTowerLevelRatio = tonumber(globalConfig.rebirth_tower_level_ratio) or rebirthTowerLevelRatio
end)

local function readAtomValue(store, name)
    local atom = store and store[name]
    if type(atom) ~= "function" then
        return nil
    end
    local ok, value = pcall(atom)
    if not ok then
        return nil
    end
    if type(value) == "function" then
        local readOk, currentValue = pcall(value)
        return readOk and currentValue or nil
    end
    return value
end

local function writeDirectAtom(store, name, value)
    local atom = store and store[name]
    if type(atom) ~= "function" then
        return false
    end
    return pcall(atom, value)
end

state.getDemonRealmState = function()
    local serverNow = workspace:GetServerTimeNow()
    local openEndTime = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossOpenEndTime")) or 0
    local nextOpenTime = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossNextOpenTime")) or 0
    local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
    local expEfficiency = tonumber(readAtomValue(reaperBattleStore, "AtomTimeLimitBossExpEfficiency")) or 0
    return {
        Open = openEndTime > serverNow,
        InRealm = battleState == 7,
        BattleState = battleState,
        OpenRemaining = math.max(0, math.ceil(openEndTime - serverNow)),
        NextRemaining = math.max(0, math.ceil(nextOpenTime - serverNow)),
        ExpEfficiency = expEfficiency,
    }
end

state.formatRealmCountdown = function(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainder = seconds % 60
    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, remainder)
    end
    return string.format("%02d:%02d", minutes, remainder)
end

state.demonRealmStatusLabel = CursedKingSection:AddLabel("Demon Realm: Reading global event window...")
state.refreshDemonRealmStatus = function()
    local info = state.getDemonRealmState()
    if info.InRealm then
        state.demonRealmStatusLabel.Text = "Demon Realm: Inside | Auto farming | "
            .. state.formatRealmCountdown(info.OpenRemaining) .. " left"
        state.demonRealmStatusLabel.TextColor3 = COLORS.success
    elseif info.Open then
        state.demonRealmStatusLabel.Text = (state.demonRealm and "Demon Realm: Open | Joining... | " or "Demon Realm: Open now | Auto join off | ")
            .. state.formatRealmCountdown(info.OpenRemaining) .. " left"
        state.demonRealmStatusLabel.TextColor3 = state.demonRealm and COLORS.success or COLORS.muted
    elseif state.demonRealm then
        state.demonRealmStatusLabel.Text = info.NextRemaining > 0
            and ("Demon Realm: Armed | Next global event in " .. state.formatRealmCountdown(info.NextRemaining))
            or "Demon Realm: Armed | Waiting for the next global event"
        state.demonRealmStatusLabel.TextColor3 = COLORS.success
    else
        state.demonRealmStatusLabel.Text = info.NextRemaining > 0
            and ("Demon Realm: Disabled | Next event in " .. state.formatRealmCountdown(info.NextRemaining))
            or "Demon Realm: Disabled | Global event is closed"
        state.demonRealmStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

state.demonRealmControl = CursedKingSection:AddToggle({
    Name = "Auto Demon Realm",
    Description = "Joins the global Demon Realm when it opens, attacks continuously, and re-enters while it stays open",
    Flag = "revive_auto_demon_realm",
    Callback = function(enabled)
        state.demonRealm = enabled
        state.refreshDemonRealmStatus()
        setReviveStatus(
            enabled and "Demon Realm armed; waiting for the server event window" or "Auto Demon Realm disabled",
            enabled and true or nil
        )
    end,
})
CursedKingSection:AddLabel("The realm timer and stat rewards are server-controlled; Auto Demon Realm waits and rejoins every valid opening.")
task.defer(state.refreshDemonRealmStatus)

local function getReaperState()
    local mainLevel = tonumber(readAtomValue(reaperBattleStore, "AtomMainLevel")) or 0
    local maxHp = tonumber(readAtomValue(reaperBattleStore, "AtomMaxHP")) or 0
    local nextValidTime = tonumber(readAtomValue(reaperBattleStore, "AtomReaperTime")) or 0
    return {
        Unlocked = mainLevel >= reaperUnlockLevel,
        MainLevel = mainLevel,
        MaxHP = maxHp,
        NextValidTime = nextValidTime,
        Remaining = math.max(0, math.ceil(nextValidTime - workspace:GetServerTimeNow())),
    }
end

local function refreshReaperStatus(prefix)
    local info = getReaperState()
    if not info.Unlocked then
        reaperStatusLabel.Text = "Reaper: Waiting for the game's unlock state"
        reaperStatusLabel.TextColor3 = COLORS.muted
    elseif info.MaxHP <= 1 then
        reaperStatusLabel.Text = "Reaper: Unlocked | No more Max HP can be taken"
        reaperStatusLabel.TextColor3 = COLORS.muted
    elseif info.Remaining > 0 then
        reaperStatusLabel.Text = "Reaper: Unlocked | Cooldown " .. info.Remaining .. "s"
        reaperStatusLabel.TextColor3 = COLORS.muted
    else
        reaperStatusLabel.Text = "Reaper: Unlocked | Ready"
        reaperStatusLabel.TextColor3 = COLORS.success
    end
    if prefix then
        setReviveStatus(prefix, true)
    end
    return info
end

task.defer(refreshReaperStatus)

local RED_DRAGON_MODE = 1
local GREEN_DRAGON_MODE = 2
local NIGHTMARE_MODE = 3
local deathKingLevelAdd = 0
local cursedKingLevelAdd = 0
local nightmareLevelAdd = 0
local specialLastStart = {[RED_DRAGON_MODE] = 0, [GREEN_DRAGON_MODE] = 0, [NIGHTMARE_MODE] = 0}
local multiHitNeedsBootstrap = true
local nightmarePortalPrimeRunning = false
local nightmarePortalPrimedCharacter = nil
local priority = {
    target = "Nightmare",
    levelAdd = 0,
    winsPerCycle = 1,
    multiSeconds = 5,
    phase = "special",
    wins = 0,
    nextMode = NIGHTMARE_MODE,
    activeMode = nil,
    activeLevelBefore = 0,
    lastLevels = {[RED_DRAGON_MODE] = 0, [GREEN_DRAGON_MODE] = 0, [NIGHTMARE_MODE] = 0},
    seenResultSerial = 0,
    nextStartAt = 0,
    multiEndAt = 0,
    quitDeadline = 0,
}

local function levelAddText(levelAdd)
    return levelAdd == 2 and "+10" or (levelAdd == 1 and "+5" or "+1")
end

local function getSpecialBossState(mode)
    local mainLevel = tonumber(readAtomValue(reaperBattleStore, "AtomMainLevel")) or 0
    local highestRebirth = tonumber(readAtomValue(rebirthStore, "AtomHighestReachedRebirth")) or 0
    local autoMode = tonumber(readAtomValue(reaperBattleStore, "AtomAutoChallengeMode")) or 0
    local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
    local isNightmare = mode == NIGHTMARE_MODE
    local isDeathKing = mode == RED_DRAGON_MODE
    local requiredMainLevel = isNightmare and nightmareUnlockLevel
        or (isDeathKing and redDragonUnlockLevel or greenDragonUnlockLevel)
    local atomName = isNightmare and "AtomTowerLevel"
        or (isDeathKing and "AtomRedDragonLevel" or "AtomGreenDragonLevel")
    return {
        Unlocked = mainLevel >= requiredMainLevel,
        MainLevel = mainLevel,
        RequiredMainLevel = requiredMainLevel,
        HighestRebirth = highestRebirth,
        NativeAutoAvailable = highestRebirth > 0,
        Level = tonumber(readAtomValue(reaperBattleStore, atomName)) or 0,
        RequiredTowerLevel = isNightmare and (rebirthTowerLevelRatio * (highestRebirth + 1)) or nil,
        AutoMode = autoMode,
        BattleState = battleState,
        Mode = mode,
    }
end

local function getDeathKingState()
    return getSpecialBossState(RED_DRAGON_MODE)
end

local function getCursedKingState()
    return getSpecialBossState(GREEN_DRAGON_MODE)
end

local function refreshDeathKingStatus()
    local info = getDeathKingState()
    if not info.Unlocked then
        deathKingStatusLabel.Text = "Death King: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        deathKingStatusLabel.TextColor3 = COLORS.error
    elseif state.deathKing then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        deathKingStatusLabel.Text = "Death King: " .. method .. " " .. levelAddText(deathKingLevelAdd) .. " | Level " .. info.Level
        deathKingStatusLabel.TextColor3 = COLORS.success
    else
        deathKingStatusLabel.Text = "Death King: Unlocked | Auto disabled | Level " .. info.Level
        deathKingStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function getNightmareState()
    return getSpecialBossState(NIGHTMARE_MODE)
end

local function findNightmarePortalPart()
    local bestPart = nil
    local bestScore = -math.huge
    for _, descendant in ipairs(workspace:GetDescendants()) do
        if descendant:IsA("BasePart") and descendant.Transparency < 1 then
            local parentName = descendant.Parent and descendant.Parent.Name or ""
            local identity = string.lower(descendant.Name .. " " .. parentName)
            local hue, saturation = Color3.toHSV(descendant.Color)
            local isPurple = hue >= 0.68 and hue <= 0.90 and saturation >= 0.22
            local score = 0
            if string.find(identity, "portal", 1, true) then score += 7 end
            if string.find(identity, "nightmare", 1, true) then score += 5 end
            if string.find(identity, "death", 1, true) then score += 3 end
            if string.find(identity, "tower", 1, true) then score += 3 end
            if isPurple then score += 4 end
            if descendant.CanTouch then score += 1 end
            if score > bestScore and score >= 8 then
                bestPart = descendant
                bestScore = score
            end
        end
    end
    return bestPart
end

local function prepareNightmareChallengeScene()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local scene = workspace:FindFirstChild("TowerBattle")
    if not scene then
        local assets = ReplicatedStorage:FindFirstChild("Assets")
        local model = assets and assets:FindFirstChild("Model")
        local sceneFolder = model and model:FindFirstChild("Scene")
        scene = sceneFolder and sceneFolder:FindFirstChild("TowerBattle")
    end
    if not scene or not scene:IsA("Model") then
        return false
    end
    local ok = pcall(function()
        if scene.Parent ~= workspace then
            scene.Parent = workspace
        end
        scene:PivotTo(CFrame.new(0, 300, 0))
        local posFolder = scene:FindFirstChild("Pos", true)
        local playerPoint = posFolder and posFolder:FindFirstChild("Player")
        if not playerPoint or not playerPoint:IsA("BasePart") then
            error("TowerBattle.Pos.Player was not found")
        end
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = playerPoint.CFrame
    end)
    if ok then
        nightmarePortalPrimedCharacter = character
        setReviveStatus("Death Tower arena prepared automatically", true)
    end
    return ok
end

local function primeNightmarePortal()
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not character or not root then
        return false
    end
    if nightmarePortalPrimedCharacter == character then
        return true
    end
    if nightmarePortalPrimeRunning then
        return false
    end

    if prepareNightmareChallengeScene() then
        return true
    end

    local portalPart = findNightmarePortalPart()
    if not portalPart then
        setReviveStatus("Nightmare is waiting for the purple Death Tower portal", nil)
        return false
    end

    nightmarePortalPrimeRunning = true
    local originalCFrame = root.CFrame
    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = portalPart.CFrame * CFrame.new(0, 0, -2.2)
        if type(firetouchinterest) == "function" then
            firetouchinterest(root, portalPart, 0)
            firetouchinterest(root, portalPart, 1)
        end
        task.wait(0.18)
        root.CFrame = portalPart.CFrame * CFrame.new(0, 0, 2.2)
        task.wait(0.18)
        root.CFrame = originalCFrame
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end)
    nightmarePortalPrimeRunning = false
    if ok then
        nightmarePortalPrimedCharacter = character
        setReviveStatus("Purple Death Tower portal primed automatically", true)
    end
    return ok
end

local function refreshCursedKingStatus()
    local info = getCursedKingState()
    if not info.Unlocked then
        cursedKingStatusLabel.Text = "Cursed King: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        cursedKingStatusLabel.TextColor3 = COLORS.error
    elseif state.cursedKing then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        cursedKingStatusLabel.Text = "Cursed King: " .. method .. " " .. levelAddText(cursedKingLevelAdd) .. " | Level " .. info.Level
        cursedKingStatusLabel.TextColor3 = COLORS.success
    else
        cursedKingStatusLabel.Text = "Cursed King: Unlocked | Auto disabled | Level " .. info.Level
        cursedKingStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function refreshNightmareStatus()
    local info = getNightmareState()
    if not info.Unlocked then
        nightmareStatusLabel.Text = "Nightmare: Requires Main Level " .. info.RequiredMainLevel .. " | Current " .. info.MainLevel
        nightmareStatusLabel.TextColor3 = COLORS.error
    elseif state.nightmare then
        local method = info.NativeAutoAvailable and "Native Auto" or "Hub Auto"
        nightmareStatusLabel.Text = "Nightmare: " .. method .. " " .. levelAddText(nightmareLevelAdd)
            .. " | Tower " .. info.Level .. " / " .. info.RequiredTowerLevel .. " for next Rebirth"
        nightmareStatusLabel.TextColor3 = COLORS.success
    else
        nightmareStatusLabel.Text = "Nightmare: Unlocked | Tower " .. info.Level .. " / " .. info.RequiredTowerLevel .. " for next Rebirth"
        nightmareStatusLabel.TextColor3 = COLORS.muted
    end
    return info
end

local function startSpecialBoss(mode, levelAdd, nativeAuto)
    local info = getSpecialBossState(mode)
    if not info.Unlocked then
        if mode == NIGHTMARE_MODE then
            refreshNightmareStatus()
        elseif mode == RED_DRAGON_MODE then
            refreshDeathKingStatus()
        else
            refreshCursedKingStatus()
        end
        return false
    end
    if mode == NIGHTMARE_MODE and info.BattleState == 0 and nightmarePortalPrimedCharacter ~= LocalPlayer.Character then
        primeNightmarePortal()
        task.wait(0.12)
    end
    local autoMode = nativeAuto and mode or 0
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeMode", autoMode)
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeLevelAdd", levelAdd)
    local resumeOk = fireRemote("setAfkResumeReq", autoMode, levelAdd)
    local startOk = fireRemote("startTimeLimitChallengeReq", mode, levelAdd)
    if resumeOk and startOk then
        specialLastStart[mode] = workspace:GetServerTimeNow()
        if mode == NIGHTMARE_MODE and info.BattleState == 0 and nightmarePortalPrimedCharacter ~= LocalPlayer.Character then
            task.delay(0.9, function()
                if not gui.Parent or getNightmareState().BattleState ~= 0 then
                    return
                end
                if primeNightmarePortal() then
                    task.wait(0.15)
                    fireRemote("setAfkResumeReq", autoMode, levelAdd)
                    fireRemote("startTimeLimitChallengeReq", mode, levelAdd)
                    specialLastStart[mode] = workspace:GetServerTimeNow()
                end
            end)
        end
        return true
    end
    return false
end

local function armDeathKingAuto()
    local info = getDeathKingState()
    local ok = startSpecialBoss(RED_DRAGON_MODE, deathKingLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Death King auto " .. levelAddText(deathKingLevelAdd) .. " armed", true)
    end
    refreshDeathKingStatus()
    return ok
end

local function armCursedKingAuto()
    local info = getCursedKingState()
    local ok = startSpecialBoss(GREEN_DRAGON_MODE, cursedKingLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Cursed King auto " .. levelAddText(cursedKingLevelAdd) .. " armed", true)
    end
    refreshCursedKingStatus()
    return ok
end

local function armNightmareAuto()
    local info = getNightmareState()
    local ok = startSpecialBoss(NIGHTMARE_MODE, nightmareLevelAdd, info.NativeAutoAvailable and not state.specialPriority)
    if ok then
        setReviveStatus("Nightmare auto " .. levelAddText(nightmareLevelAdd) .. " armed", true)
    end
    refreshNightmareStatus()
    return ok
end

local function disarmSpecialAuto()
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeMode", 0)
    writeDirectAtom(reaperBattleStore, "AtomAutoChallengeLevelAdd", 0)
    fireRemote("setAfkResumeReq", 0, 0)
end

priority.modeName = function(mode)
    return mode == NIGHTMARE_MODE and "Nightmare"
        or (mode == RED_DRAGON_MODE and "Death King" or "Cursed King")
end

priority.reset = function()
    priority.phase = "special"
    priority.wins = 0
    priority.nextMode = priority.target == "Cursed King" and GREEN_DRAGON_MODE
        or (priority.target == "Death King" and RED_DRAGON_MODE or NIGHTMARE_MODE)
    priority.activeMode = nil
    priority.activeLevelBefore = 0
    priority.lastLevels[RED_DRAGON_MODE] = getDeathKingState().Level
    priority.lastLevels[GREEN_DRAGON_MODE] = getCursedKingState().Level
    priority.lastLevels[NIGHTMARE_MODE] = getNightmareState().Level
    priority.seenResultSerial = specialResultSerial
    priority.nextStartAt = 0
    priority.multiEndAt = 0
    priority.quitDeadline = 0
    state.priorityMulti = false
end

priority.chooseMode = function()
    local deathInfo = getDeathKingState()
    local cursedInfo = getCursedKingState()
    local nightmareInfo = getNightmareState()
    if priority.target == "Nightmare" then
        return nightmareInfo.Unlocked and NIGHTMARE_MODE or nil
    end
    if priority.target == "Cursed King" then
        return cursedInfo.Unlocked and GREEN_DRAGON_MODE or nil
    end
    if priority.target == "Death King" then
        return deathInfo.Unlocked and RED_DRAGON_MODE or nil
    end
    if priority.target == "Cycle All" then
        local order = {RED_DRAGON_MODE, GREEN_DRAGON_MODE, NIGHTMARE_MODE}
        local startIndex = table.find(order, priority.nextMode) or 1
        for offset = 0, #order - 1 do
            local candidate = order[((startIndex + offset - 1) % #order) + 1]
            if getSpecialBossState(candidate).Unlocked then
                return candidate
            end
        end
        return nil
    end
    if nightmareInfo.Unlocked then
        return NIGHTMARE_MODE
    end
    if cursedInfo.Unlocked then
        return GREEN_DRAGON_MODE
    end
    return nil
end

priority.start = function()
    local mode = priority.chooseMode()
    if not mode then
        return false
    end
    local info = getSpecialBossState(mode)
    if startSpecialBoss(mode, priority.levelAdd, false) then
        priority.activeMode = mode
        priority.activeLevelBefore = info.Level
        priority.seenResultSerial = specialResultSerial
        priority.nextStartAt = os.clock() + 2.5
        priorityStatusLabel.Text = "Special Priority: Fighting " .. priority.modeName(mode)
        priorityStatusLabel.TextColor3 = COLORS.success
        return true
    end
    priority.nextStartAt = os.clock() + 2.5
    return false
end

priority.complete = function(success)
    local completedMode = priority.activeMode
    if not completedMode then
        return
    end
    priority.activeMode = nil
    priority.activeLevelBefore = 0
    priority.nextStartAt = os.clock() + 1
    if not success then
        priorityStatusLabel.Text = "Special Priority: " .. priority.modeName(completedMode) .. " retry queued"
        priorityStatusLabel.TextColor3 = COLORS.error
        return
    end

    priority.wins += 1
    if priority.target == "Cycle All" then
        priority.nextMode = completedMode == RED_DRAGON_MODE and GREEN_DRAGON_MODE
            or (completedMode == GREEN_DRAGON_MODE and NIGHTMARE_MODE or RED_DRAGON_MODE)
    end
    if priority.wins >= priority.winsPerCycle then
        priority.phase = "quit"
        priority.wins = 0
        priority.quitDeadline = os.clock() + 3.5
        state.priorityMulti = false
        multiHitNeedsBootstrap = true
        disarmSpecialAuto()
        for attempt = 0, 2 do
            task.delay(attempt * 0.16, function()
                if gui.Parent and state.specialPriority and priority.phase == "quit" then
                    fireRemote("levelTimeLimitBossReq")
                end
            end)
        end
        priorityStatusLabel.Text = "Special Priority: " .. priority.modeName(completedMode) .. " defeated | Exiting"
        priorityStatusLabel.TextColor3 = COLORS.success
    else
        priorityStatusLabel.Text = "Special Priority: " .. priority.wins .. " / " .. priority.winsPerCycle .. " special wins"
        priorityStatusLabel.TextColor3 = COLORS.success
    end
end

priority.observeProgress = function()
    for _, mode in ipairs({RED_DRAGON_MODE, GREEN_DRAGON_MODE, NIGHTMARE_MODE}) do
        local currentLevel = getSpecialBossState(mode).Level
        local previousLevel = priority.lastLevels[mode] or currentLevel
        priority.lastLevels[mode] = currentLevel
        if currentLevel < previousLevel then
            previousLevel = currentLevel
        end
        local matchesTarget = priority.target == "Cycle All"
            or (priority.target == "Nightmare" and mode == NIGHTMARE_MODE)
            or (priority.target == "Cursed King" and mode == GREEN_DRAGON_MODE)
            or (priority.target == "Death King" and mode == RED_DRAGON_MODE)
        if priority.phase == "special" and matchesTarget and currentLevel > previousLevel then
            if not priority.activeMode then
                priority.activeMode = mode
            end
            priority.complete(true)
            return true
        end
    end
    return false
end

priority.isMultiHitActive = function()
    if state.specialPriority then
        return state.priorityMulti
    end
    return state.multiHit
end

task.defer(refreshCursedKingStatus)
task.defer(refreshDeathKingStatus)
task.defer(refreshNightmareStatus)

local attackControl
local multiHitControl
local specialPriorityControl
local bossFarmControl
local multiHitDelay = 0.06
local multiHitTargetMode = "Unlocked Bosses Only"

attackControl = CombatSection:AddToggle({
    Name = "Auto Attack Latest Boss",
    Description = "Attacks your latest unlocked boss from anywhere",
    Flag = "revive_auto_attack",
    Callback = function(enabled)
        state.autoAttack = enabled
        if enabled and multiHitControl then
            state.multiHit = false
            multiHitControl:Set(false, true)
        end
        setReviveStatus(enabled and "Auto Attack Latest Boss enabled" or "Auto Attack Latest Boss disabled", enabled and true or nil)
    end,
})

multiHitControl = CombatSection:AddToggle({
    Name = "Multi Hit All Bosses",
    Description = "Attacks every selected boss level each cycle without moving your character",
    Flag = "revive_multi_hit_all_bosses",
    Callback = function(enabled)
        state.multiHit = enabled
        if enabled then
            multiHitNeedsBootstrap = true
        end
        if overnightMultiHitControl and overnightMultiHitControl:Get() ~= enabled then
            overnightMultiHitControl:Set(enabled, true)
        end
        if enabled and attackControl then
            state.autoAttack = false
            attackControl:Set(false, true)
        end
        multiHitStatusLabel.Text = enabled and "Multi Hit: Starting confirmed round-robin..." or "Multi Hit: Disabled"
        multiHitStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and ("Multi Hit enabled: " .. multiHitTargetMode) or "Multi Hit disabled", enabled and true or nil)
    end,
})

CombatSection:AddSlider({
    Name = "Multi Hit Retry Delay",
    Min = 0.03,
    Max = 0.30,
    Default = multiHitDelay,
    Step = 0.01,
    Flag = "revive_multi_hit_delay_fast_v3",
    Callback = function(value)
        multiHitDelay = math.clamp(tonumber(value) or 0.06, 0.03, 0.30)
    end,
})

CombatSection:AddDropdown({
    Name = "Multi Hit Targets",
    Options = {"Unlocked Bosses Only", "All 15 Bosses"},
    Default = "Unlocked Bosses Only",
    Flag = "revive_multi_hit_targets_v2",
    Callback = function(value)
        multiHitTargetMode = value == "All 15 Bosses" and value or "Unlocked Bosses Only"
        if state.multiHit then
            setReviveStatus("Multi Hit targets: " .. multiHitTargetMode, true)
        end
    end,
})

CombatSection:AddLabel("Waits for the server to confirm each boss before advancing. Your character never moves.")

local autoReaperControl
autoReaperControl = CombatSection:AddToggle({
    Name = "Auto Reaper",
    Description = "Uses the companion Reaper only when unlocked and its 20-second cooldown is ready",
    Flag = "revive_auto_reaper",
    Callback = function(enabled)
        state.reaper = enabled
        if overnightReaperControl and overnightReaperControl:Get() ~= enabled then
            overnightReaperControl:Set(enabled, true)
        end
        refreshReaperStatus()
        setReviveStatus(enabled and "Auto Reaper enabled (cooldown-aware)" or "Auto Reaper disabled", enabled and true or nil)
    end,
})

CombatSection:AddToggle({
    Name = "Auto Group Reward",
    Description = "Checks the group reward every 30 seconds",
    Flag = "revive_group_reward",
    Callback = function(enabled)
        state.groupReward = enabled
        setReviveStatus(enabled and "Group Reward checks enabled" or "Group Reward checks disabled", enabled and true or nil)
    end,
})

local challengeOneControl
local challengeFiveControl
local deathKingControl
local cursedKingControl
local nightmareControl
challengeOneControl = ChallengeSection:AddToggle({
    Name = "Challenge +1 Level",
    Description = "Repeats startTimeLimitChallengeReq(1, 0)",
    Flag = "revive_challenge_one",
    Callback = function(enabled)
        state.challengeOne = enabled
        if enabled and challengeFiveControl then
            state.challengeFive = false
            challengeFiveControl:Set(false, true)
        end
        if enabled and cursedKingControl then
            cursedKingControl:Set(false)
        end
        if enabled and nightmareControl then
            nightmareControl:Set(false)
        end
        if enabled and deathKingControl then
            deathKingControl:Set(false)
        end
    end,
})

challengeFiveControl = ChallengeSection:AddToggle({
    Name = "Challenge +5 Levels",
    Description = "Repeats startTimeLimitChallengeReq(1, 1)",
    Flag = "revive_challenge_five",
    Callback = function(enabled)
        state.challengeFive = enabled
        if enabled and challengeOneControl then
            state.challengeOne = false
            challengeOneControl:Set(false, true)
        end
        if enabled and cursedKingControl then
            cursedKingControl:Set(false)
        end
        if enabled and nightmareControl then
            nightmareControl:Set(false)
        end
        if enabled and deathKingControl then
            deathKingControl:Set(false)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Death King Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_death_king_level_gain",
    Callback = function(value)
        deathKingLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.deathKing and getDeathKingState().Unlocked then
            armDeathKingAuto()
        else
            refreshDeathKingStatus()
        end
    end,
})

deathKingControl = CursedKingSection:AddToggle({
    Name = "Auto Death King",
    Description = "Farms the RedDragon special boss continuously",
    Flag = "revive_auto_death_king",
    Callback = function(enabled)
        state.deathKing = enabled
        if overnightDeathKingControl and overnightDeathKingControl:Get() ~= enabled then
            overnightDeathKingControl:Set(enabled, true)
        end
        if enabled then
            if cursedKingControl then cursedKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshDeathKingStatus()
            if info.Unlocked then
                armDeathKingAuto()
            else
                setReviveStatus("Death King armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.cursedKing and not state.nightmare and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshDeathKingStatus()
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Death King Once",
    Description = "Starts one Death King run with the selected level gain",
    Persist = false,
    Callback = function()
        local info = refreshDeathKingStatus()
        if info.Unlocked then
            startSpecialBoss(RED_DRAGON_MODE, deathKingLevelAdd, false)
        else
            Window:Notify("Death King", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Cursed King Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_cursed_king_level_gain",
    Callback = function(value)
        cursedKingLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.cursedKing and getCursedKingState().Unlocked then
            armCursedKingAuto()
        else
            refreshCursedKingStatus()
        end
    end,
})

cursedKingControl = CursedKingSection:AddToggle({
    Name = "Auto Cursed King",
    Description = "Farms GreenDragon continuously; hub-managed before Rebirth 1 and native auto afterward",
    Flag = "revive_auto_cursed_king",
    Callback = function(enabled)
        state.cursedKing = enabled
        if overnightCursedKingControl and overnightCursedKingControl:Get() ~= enabled then
            overnightCursedKingControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshCursedKingStatus()
            if info.Unlocked then
                armCursedKingAuto()
            else
                setReviveStatus("Cursed King armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.deathKing and not state.nightmare and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshCursedKingStatus()
            setReviveStatus("Auto Cursed King disabled", nil)
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Cursed King Once",
    Description = "Starts one Cursed King run with the selected level gain when ownership is unlocked",
    Persist = false,
    Callback = function()
        local info = refreshCursedKingStatus()
        if info.Unlocked then
            startSpecialBoss(GREEN_DRAGON_MODE, cursedKingLevelAdd, false)
        else
            Window:Notify("Cursed King", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddDropdown({
    Name = "Nightmare Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_nightmare_level_gain",
    Callback = function(value)
        nightmareLevelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.nightmare and getNightmareState().Unlocked then
            armNightmareAuto()
        else
            refreshNightmareStatus()
        end
    end,
})

nightmareControl = CursedKingSection:AddToggle({
    Name = "Auto Nightmare",
    Description = "Farms Death Tower continuously so its level can reach the next Rebirth requirement",
    Flag = "revive_auto_nightmare",
    Callback = function(enabled)
        state.nightmare = enabled
        if overnightNightmareControl and overnightNightmareControl:Get() ~= enabled then
            overnightNightmareControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if cursedKingControl then cursedKingControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            local info = refreshNightmareStatus()
            if info.Unlocked then
                armNightmareAuto()
            else
                setReviveStatus("Nightmare armed; waiting for Main Level " .. info.RequiredMainLevel, nil)
            end
        else
            if not state.deathKing and not state.cursedKing and not state.specialPriority then
                disarmSpecialAuto()
            end
            refreshNightmareStatus()
            setReviveStatus("Auto Nightmare disabled", nil)
        end
    end,
})

CursedKingSection:AddButton({
    Name = "Start Nightmare Once",
    Description = "Starts one Death Tower run with the selected +1 / +5 / +10 level gain",
    Persist = false,
    Callback = function()
        local info = refreshNightmareStatus()
        if info.Unlocked then
            startSpecialBoss(NIGHTMARE_MODE, nightmareLevelAdd, false)
        else
            Window:Notify("Nightmare", "Requires Main Level " .. info.RequiredMainLevel .. ".", 4)
        end
    end,
})

CursedKingSection:AddLabel("Cursed King = GreenDragon mode 2 | Nightmare = Death Tower mode 3")

SpecialPrioritySection:AddDropdown({
    Name = "Priority Special Boss",
    Options = {"Nightmare", "Cursed King", "Death King", "Cycle All"},
    Default = "Nightmare",
    Flag = "revive_priority_special_target_v2",
    Callback = function(value)
        priority.target = (value == "Cursed King" or value == "Death King" or value == "Cycle All") and value or "Nightmare"
        if state.specialPriority then
            priority.reset()
            priorityStatusLabel.Text = "Special Priority: Target changed to " .. priority.target
            priorityStatusLabel.TextColor3 = COLORS.success
        end
    end,
})

SpecialPrioritySection:AddDropdown({
    Name = "Priority Level Gain",
    Options = {"+1 Level", "+5 Levels", "+10 Levels"},
    Default = "+1 Level",
    Flag = "revive_priority_level_gain_v2",
    Callback = function(value)
        priority.levelAdd = value == "+10 Levels" and 2 or (value == "+5 Levels" and 1 or 0)
        if state.specialPriority then
            priority.reset()
            setReviveStatus("Special priority level gain set to " .. levelAddText(priority.levelAdd), true)
        end
    end,
})

SpecialPrioritySection:AddSlider({
    Name = "Special Wins Per Cycle",
    Min = 1,
    Max = 5,
    Default = 1,
    Step = 1,
    Flag = "revive_priority_special_wins_v2",
    Callback = function(value)
        priority.winsPerCycle = math.clamp(math.floor((tonumber(value) or 1) + 0.5), 1, 5)
    end,
})

SpecialPrioritySection:AddSlider({
    Name = "Multi Hit Window",
    Min = 1,
    Max = 60,
    Default = 5,
    Step = 1,
    Suffix = "s",
    Flag = "revive_priority_multi_seconds_v2",
    Callback = function(value)
        priority.multiSeconds = math.clamp(math.floor((tonumber(value) or 5) + 0.5), 1, 60)
    end,
})

specialPriorityControl = SpecialPrioritySection:AddToggle({
    Name = "Special Boss Priority",
    Description = "Kills the selected special boss, runs timed Multi Hit, then repeats while advancing tower sections",
    Flag = "revive_special_boss_priority_v2",
    Callback = function(enabled)
        state.specialPriority = enabled
        if overnightSpecialPriorityControl and overnightSpecialPriorityControl:Get() ~= enabled then
            overnightSpecialPriorityControl:Set(enabled, true)
        end
        if enabled then
            if deathKingControl then deathKingControl:Set(false) end
            if cursedKingControl then cursedKingControl:Set(false) end
            if nightmareControl then nightmareControl:Set(false) end
            if attackControl then attackControl:Set(false) end
            if bossFarmControl then bossFarmControl:Set(false) end
            if challengeOneControl then challengeOneControl:Set(false) end
            if challengeFiveControl then challengeFiveControl:Set(false) end
            disarmSpecialAuto()
            priority.reset()
            multiHitNeedsBootstrap = true
            priorityStatusLabel.Text = "Special Priority: AFK climb armed for " .. priority.target
            priorityStatusLabel.TextColor3 = COLORS.success
            setReviveStatus("Special boss priority enabled: " .. priority.target, true)
        else
            priority.reset()
            if not state.deathKing and not state.cursedKing and not state.nightmare then
                disarmSpecialAuto()
            end
            priorityStatusLabel.Text = "Special Priority: Disabled"
            priorityStatusLabel.TextColor3 = COLORS.muted
            setReviveStatus("Special boss priority disabled", nil)
        end
    end,
})

SpecialPrioritySection:AddLabel("AFK loop: selected special wins -> timed Multi Hit -> next Death Tower / Cursed King section.")
SpecialPrioritySection:AddLabel("Nightmare progress raises Death Tower level; Rebirth 1 requires Death Tower 5.")

local dailyRewardControl
dailyRewardControl = RewardSection:AddToggle({
    Name = "Auto Daily Sign",
    Description = "Claims the daily sign reward when it becomes available",
    Flag = "revive_daily_sign",
    Callback = function(enabled)
        state.dailyReward = enabled
    end,
})

local onlineRewardControl
onlineRewardControl = RewardSection:AddToggle({
    Name = "Auto Online Rewards",
    Description = "Checks the online-time reward every five seconds",
    Flag = "revive_online_rewards",
    Callback = function(enabled)
        state.onlineReward = enabled
    end,
})

local soulSpawnerControl
soulSpawnerControl = RewardSection:AddToggle({
    Name = "Auto Soul Spawner",
    Description = "Claims accumulated Soul Spawner rewards when unlocked",
    Flag = "revive_soul_spawner",
    Callback = function(enabled)
        state.soulSpawner = enabled
    end,
})

local starterRewardControl
starterRewardControl = RewardSection:AddToggle({
    Name = "Auto Starter Rewards",
    Description = "Checks verified starter milestones 1 through 5",
    Flag = "revive_starter_rewards",
    Callback = function(enabled)
        state.starterRewards = enabled
    end,
})

local bossRewardControl
bossRewardControl = RewardSection:AddToggle({
    Name = "Auto Boss Rewards",
    Description = "Checks Time-Limit Boss reward indexes 1 through 6",
    Flag = "revive_boss_rewards",
    Callback = function(enabled)
        state.bossRewards = enabled
    end,
})

RewardSection:AddButton({
    Name = "Claim Available Rewards Now",
    Description = "Runs one safe claim pass without enabling any toggle",
    Persist = false,
    Callback = function()
        fireRemote("getSignReward")
        fireRemote("receiveOnlineTimeReward")
        fireRemote("claimSoulSpawner")
        fireRemote("getGroupReward")
        for index = 1, 5 do
            fireRemote("claimChallengeReward", index)
        end
        for index = 1, 6 do
            fireRemote("claimTimeLimitBossReward", index)
        end
        setReviveStatus("Reward claim pass sent", true)
    end,
})

local weaponStore = nil
local weaponConfig = nil
pcall(function()
    weaponStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("weapon"))
    weaponConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbweapon"))
end)

local function getOwnedWeapons()
    if not weaponStore or type(weaponStore.AtomWeapons) ~= "function" then
        return nil
    end
    local ok, owned = pcall(function()
        return weaponStore.AtomWeapons()()
    end)
    return ok and type(owned) == "table" and owned or nil
end

local function getEquippedWeaponId()
    if not weaponStore or type(weaponStore.AtomEquippedWeaponId) ~= "function" then
        return nil
    end
    local ok, equipped = pcall(function()
        return weaponStore.AtomEquippedWeaponId()()
    end)
    return ok and type(equipped) == "string" and equipped or nil
end

local function getWeaponInfo(weaponId)
    return weaponConfig and type(weaponConfig[weaponId]) == "table" and weaponConfig[weaponId] or nil
end

local function getWeaponDisplayName(weaponId)
    local info = getWeaponInfo(weaponId)
    return info and tostring(info.name or info.desc or weaponId) or tostring(weaponId or "N/A")
end

local function getLastUnlockedWeaponId()
    local owned = getOwnedWeapons()
    if not owned then
        return nil
    end
    local bestId = nil
    local bestSort = -math.huge
    for weaponId in pairs(owned) do
        local info = getWeaponInfo(weaponId)
        local order = info and tonumber(info.sort) or tonumber(tostring(weaponId):match("%d+")) or 0
        if order > bestSort then
            bestSort = order
            bestId = weaponId
        end
    end
    return bestId
end

local refreshWeaponStatus
local selectedOwnedWeaponId = nil
local ownedWeaponOptionToId = {}
local ownedWeaponDropdown = nil

local function refreshOwnedWeaponOptions()
    local owned = getOwnedWeapons() or {}
    local ordered = {}
    for weaponId, weaponState in pairs(owned) do
        local info = getWeaponInfo(weaponId)
        table.insert(ordered, {
            Id = weaponId,
            Name = getWeaponDisplayName(weaponId),
            Level = type(weaponState) == "table" and tonumber(weaponState.Level) or nil,
            Sort = info and tonumber(info.sort) or tonumber(tostring(weaponId):match("%d+")) or 0,
        })
    end
    table.sort(ordered, function(left, right)
        return left.Sort < right.Sort
    end)

    local options = {}
    ownedWeaponOptionToId = {}
    for _, entry in ipairs(ordered) do
        local label = entry.Name .. (entry.Level and (" | Lv." .. entry.Level) or "")
        table.insert(options, label)
        ownedWeaponOptionToId[label] = entry.Id
    end
    if #options == 0 then
        options = {"Inventory is still loading..."}
    end
    if ownedWeaponDropdown then
        ownedWeaponDropdown:SetOptions(options, false)
    end
    selectedOwnedWeaponId = nil
    return options
end

ownedWeaponDropdown = WeaponInfoSection:AddDropdown({
    Name = "Owned Weapon",
    Options = refreshOwnedWeaponOptions(),
    Placeholder = "Choose an owned weapon...",
    Persist = false,
    Callback = function(value)
        selectedOwnedWeaponId = ownedWeaponOptionToId[value]
    end,
})

WeaponInfoSection:AddButton({
    Name = "Equip Selected Weapon",
    Description = "Equips the owned sword selected above",
    Persist = false,
    Callback = function()
        if not selectedOwnedWeaponId then
            setReviveStatus("Choose an owned weapon first", false)
            return
        end
        if fireRemote("equipWeapon", selectedOwnedWeaponId) then
            refreshWeaponStatus("equipping " .. getWeaponDisplayName(selectedOwnedWeaponId))
            setReviveStatus("Selected sword equip request sent", true)
        end
    end,
})

WeaponInfoSection:AddButton({
    Name = "Refresh Owned Weapons",
    Description = "Refresh after a new sword unlocks while the hub is open",
    Persist = false,
    Callback = function()
        local options = refreshOwnedWeaponOptions()
        setReviveStatus("Found " .. tostring(#options) .. " owned weapon entries", true)
    end,
})

WeaponInfoSection:AddLabel("Only live inventory entries are listed, so locked swords are never auto-equipped.")

refreshWeaponStatus = function(extra)
    local equipped = getEquippedWeaponId()
    local best = getLastUnlockedWeaponId()
    local text = "Sword: " .. getWeaponDisplayName(equipped)
    if best then
        text ..= " | Last unlocked: " .. getWeaponDisplayName(best)
    end
    if extra then
        text ..= " | " .. tostring(extra)
    end
    weaponStatusLabel.Text = text
    weaponStatusLabel.TextColor3 = equipped and COLORS.success or COLORS.muted
end

local function equipLastUnlockedWeapon()
    local bestId = getLastUnlockedWeaponId()
    if not bestId then
        refreshWeaponStatus("inventory unavailable")
        return false
    end
    local equipped = getEquippedWeaponId()
    if equipped ~= bestId then
        if not fireRemote("equipWeapon", bestId) then
            return false
        end
        refreshWeaponStatus("equipping " .. getWeaponDisplayName(bestId))
    else
        refreshWeaponStatus("best equipped")
    end
    return true
end

local autoEquipBestControl
autoEquipBestControl = UpgradeSection:AddToggle({
    Name = "Auto Equip Last Unlocked",
    Description = "Equips the owned weapon with the highest order in the game's weapon data",
    Flag = "revive_auto_equip_best",
    Callback = function(enabled)
        state.autoEquipBest = enabled
        if overnightAutoEquipControl and overnightAutoEquipControl:Get() ~= enabled then
            overnightAutoEquipControl:Set(enabled, true)
        end
        if enabled then
            equipLastUnlockedWeapon()
        else
            refreshWeaponStatus()
        end
    end,
})

UpgradeSection:AddButton({
    Name = "Equip Last Unlocked Now",
    Description = "Runs one inventory check and equips your newest owned weapon",
    Persist = false,
    Callback = function()
        if equipLastUnlockedWeapon() then
            setReviveStatus("Last unlocked sword equip request sent", true)
        end
    end,
})

local autoUpgradeControl
autoUpgradeControl = UpgradeSection:AddToggle({
    Name = "Auto Upgrade Equipped Sword",
    Description = "Enhances the sword currently held; automatically follows equipment changes",
    Flag = "revive_auto_upgrade",
    Callback = function(enabled)
        state.autoUpgrade = enabled
        if overnightAutoUpgradeControl and overnightAutoUpgradeControl:Get() ~= enabled then
            overnightAutoUpgradeControl:Set(enabled, true)
        end
        refreshWeaponStatus(enabled and "auto upgrade on" or nil)
    end,
})

UpgradeSection:AddLabel("Special weapons marked non-enhanceable by the game are safely skipped.")
task.defer(refreshWeaponStatus)

local autoRebirthFloor = 1
local autoRebirthControl
local rebirthStatusLabel = RebirthSection:AddLabel("Auto Rebirth: Waiting for live Death Tower requirement")
RebirthSection:AddSlider({
    Name = "Rebirth Floor",
    Min = 1,
    Max = 100,
    Default = 1,
    Step = 1,
    Flag = "revive_rebirth_floor",
    Callback = function(value)
        autoRebirthFloor = math.floor(value)
        if state.autoRebirth then
            fireRemote("SetAutoRebirth", true, autoRebirthFloor)
        end
    end,
})

autoRebirthControl = RebirthSection:AddToggle({
    Name = "Auto Rebirth",
    Description = "Directly uses the game's rebirth request when your live Death Tower requirement is met",
    Flag = "revive_auto_rebirth",
    Callback = function(enabled)
        state.autoRebirth = enabled
        -- Also mirror the game's optional native setting when its gamepass exists,
        -- but the hub's direct requirement-aware loop does not depend on it.
        if remotes.SetAutoRebirth then
            fireRemote("SetAutoRebirth", enabled, autoRebirthFloor)
        end
        if overnightAutoRebirthControl and overnightAutoRebirthControl:Get() ~= enabled then
            overnightAutoRebirthControl:Set(enabled, true)
        end
        rebirthStatusLabel.Text = enabled and "Auto Rebirth: Armed" or "Auto Rebirth: Disabled"
        rebirthStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
        setReviveStatus(enabled and "Auto Rebirth armed from live tower progress" or "Auto Rebirth disabled", enabled and true or nil)
    end,
})

RebirthSection:AddLabel("The server validates Death Tower progress. Native gamepass auto is mirrored when available.")

do
local soulRingStore = nil
local soulRingUIStore = nil
local soulRingConfig = nil
pcall(function()
    soulRingStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("soulring"))
    soulRingUIStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("ui-store")).GetUIStore()
    soulRingConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbsoulring"))
end)

local function getSoulRingResourceCount(itemId)
    local playerData = soulRingUIStore and soulRingUIStore.playerData and soulRingUIStore.playerData()
    for _, item in ipairs(playerData and playerData.Inventory or {}) do
        if tostring(item.id) == itemId then
            return tonumber(item.count) or 0
        end
    end
    return 0
end

local function getSoulRingInfo()
    local rings = {}
    pcall(function()
        local atom = soulRingStore and soulRingStore.AtomSoulRings and soulRingStore.AtomSoulRings(0)
        rings = type(atom) == "function" and atom() or {}
    end)
    local ring = rings[1]
    local configEntry = nil
    if ring and soulRingConfig then
        configEntry = soulRingConfig[ring.Id]
        if not configEntry and type(soulRingConfig.get) == "function" then
            pcall(function()
                configEntry = soulRingConfig:get(ring.Id)
            end)
        end
    end
    return {
        Available = ring ~= nil,
        Id = ring and tostring(ring.Id) or "Locked",
        Name = configEntry and tostring(configEntry.name) or (ring and tostring(ring.Id) or "Locked"),
        Description = configEntry and tostring(configEntry.desc) or "Rebirth once to unlock Soul Ring slot 1.",
        Level = ring and (tonumber(ring.Level) or 0) or 0,
        Value = ring and (tonumber(ring.Value) or 0) or 0,
        SoulStones = getSoulRingResourceCount("SkillStone"),
        Rerolls = getSoulRingResourceCount("SkillRerollStone"),
    }
end

local function refreshSoulRingStatus(prefix)
    local info = getSoulRingInfo()
    if info.Available then
        soulRingStatusLabel.Text = string.format(
            "Soul Ring: %s | Level %d | %.2f%%",
            info.Name,
            info.Level,
            info.Value * 100
        )
        soulRingStatusLabel.TextColor3 = COLORS.success
        soulRingCurrencyLabel.Text = "Soul Stones: " .. info.SoulStones .. " | Rerolls: " .. info.Rerolls
        soulRingCurrencyLabel.TextColor3 = COLORS.muted
    else
        soulRingStatusLabel.Text = "Soul Ring: Slot 1 is locked until Rebirth 1"
        soulRingStatusLabel.TextColor3 = COLORS.error
        soulRingCurrencyLabel.Text = "Soul Stones: " .. info.SoulStones .. " | Rerolls: " .. info.Rerolls
    end
    if prefix then
        setReviveStatus(prefix, true)
    end
    return info
end

local soulRingUpgradeBatch = 1
state.soulRingUpgradeBatch = soulRingUpgradeBatch
SoulRingSection:AddDropdown({
    Name = "Upgrade Levels Per Request",
    Options = {"1", "10", "50", "100"},
    Default = "1",
    Flag = "revive_soul_ring_upgrade_batch",
    Callback = function(value)
        soulRingUpgradeBatch = tonumber(value) or 1
        state.soulRingUpgradeBatch = soulRingUpgradeBatch
    end,
})

SoulRingSection:AddButton({
    Name = "Upgrade Soul Ring Now",
    Description = "Upgrades page 1, slot 1 with the selected batch size",
    Persist = false,
    Callback = function()
        local info = refreshSoulRingStatus()
        if not info.Available then
            Window:Notify("Soul Ring", "Slot 1 unlocks after your first Rebirth.", 4)
            return
        end
        if fireRemote("enhanceSoulRing", 0, 0, soulRingUpgradeBatch) then
            task.delay(0.4, refreshSoulRingStatus)
        end
    end,
})

state.autoSoulRingControl = SoulRingSection:AddToggle({
    Name = "Auto Upgrade Soul Ring",
    Description = "Continuously upgrades page 1, slot 1 using your selected batch",
    Flag = "revive_auto_soul_ring",
    Callback = function(enabled)
        state.autoSoulRing = enabled
        if overnightAutoSoulRingControl and overnightAutoSoulRingControl:Get() ~= enabled then
            overnightAutoSoulRingControl:Set(enabled, true)
        end
        setReviveStatus(enabled and "Auto Soul Ring upgrade enabled" or "Auto Soul Ring upgrade disabled", enabled and true or nil)
    end,
})

SoulRingSection:AddButton({
    Name = "Reroll Soul Ring Once",
    Description = "Spends one reroll stone on page 1, slot 1",
    Persist = false,
    Callback = function()
        local info = refreshSoulRingStatus()
        if not info.Available or info.Rerolls < 1 then
            Window:Notify("Soul Ring", "No available Soul Ring reroll.", 4)
            return
        end
        if fireRemote("rerollSoulRing", 0, 0, 1) then
            task.delay(0.5, refreshSoulRingStatus)
        end
    end,
})

SoulRingSection:AddLabel("Tracks the live Soul Ring name, level, Soul Stones, and reroll stones. Reroll stays manual.")
state.refreshSoulRingStatus = refreshSoulRingStatus
task.defer(refreshSoulRingStatus)
end

local selectedEnemy = 1
local tweenSpeed = 90
local tweenOffsetX = 0
local tweenOffsetY = 0
local tweenOffsetZ = -4.5
local activeEnemyTween = nil
local controlledHumanoid = nil
local originalAutoRotate = nil
local lockedEnemyFacing = setmetatable({}, {__mode = "k"})
bossFarmControl = nil
local manualTweenControl = nil

local battleStore = nil
local mainChallengeConfig = nil
pcall(function()
    battleStore = require(ReplicatedStorage:WaitForChild("common"):WaitForChild("store"):WaitForChild("battle"))
    mainChallengeConfig = require(ReplicatedStorage:WaitForChild("gen_config"):WaitForChild("tbmainchallenge"))
end)

local function getLatestUnlockedBossLevel()
    if battleStore and type(battleStore.AtomMainLevel) == "function" then
        local ok, value = pcall(function()
            return battleStore.AtomMainLevel()()
        end)
        if ok and tonumber(value) then
            -- The store reports the last completed stage; the active/latest boss is the next slot.
            return math.clamp(math.floor(tonumber(value)) + 1, 1, 15)
        end
    end
    return math.clamp(selectedEnemy, 1, 15)
end

local function getBossName(level)
    local info = mainChallengeConfig and mainChallengeConfig[level]
    return info and tostring(info.name or ("Boss " .. level)) or ("Boss " .. level)
end

local function stopEnemyTween()
    if activeEnemyTween then
        activeEnemyTween:Cancel()
        activeEnemyTween = nil
    end
    if controlledHumanoid and controlledHumanoid.Parent and originalAutoRotate ~= nil then
        controlledHumanoid.AutoRotate = originalAutoRotate
    end
    controlledHumanoid = nil
    originalAutoRotate = nil
end

local function findEnemyPart(number)
    local folder = workspace:FindFirstChild("Enemies")
    local enemy = folder and folder:FindFirstChild(tostring(number))
    if not enemy then
        return nil
    end
    if enemy:IsA("BasePart") then
        return enemy
    end
    local preferred = enemy:FindFirstChild("HumanoidRootPart", true)
        or enemy:FindFirstChild("RootPart", true)
    if preferred and preferred:IsA("BasePart") then
        return preferred
    end
    if enemy:IsA("Model") and enemy.PrimaryPart then
        return enemy.PrimaryPart
    end
    return enemy:FindFirstChildWhichIsA("BasePart", true)
end

bossFarmControl = FarmSection:AddToggle({
    Name = "Auto Farm Latest Boss",
    Description = "Targets Main Level + 1, then follows the next boss as soon as it unlocks",
    Flag = "revive_boss_progression_farm",
    Callback = function(enabled)
        state.bossFarm = enabled
        if overnightBossFarmControl and overnightBossFarmControl:Get() ~= enabled then
            overnightBossFarmControl:Set(enabled, true)
        end
        if enabled and manualTweenControl then
            state.autoTween = false
            manualTweenControl:Set(false, true)
        end
        if not enabled then
            stopEnemyTween()
            farmStatusLabel.Text = "Farm: Disabled"
            farmStatusLabel.TextColor3 = COLORS.muted
        else
            local level = getLatestUnlockedBossLevel()
            farmStatusLabel.Text = "Farm: Level " .. level .. " - " .. getBossName(level)
            farmStatusLabel.TextColor3 = COLORS.success
        end
    end,
})

FarmSection:AddLabel("Uses Main Level + 1: store 5 targets boss 6, then store 6 targets boss 7.")
FarmSection:AddLabel("Combat position uses the Enemy Tween speed and X / Y / Z sliders below.")

local enemyOptions = {}
for index = 1, 15 do
    table.insert(enemyOptions, tostring(index))
end

TweenSection:AddDropdown({
    Name = "Enemy",
    Options = enemyOptions,
    Default = "1",
    Flag = "revive_enemy",
    Callback = function(value)
        selectedEnemy = tonumber(value) or 1
        tweenStatusLabel.Text = "Tween: Enemy " .. tostring(selectedEnemy) .. " selected"
    end,
})

manualTweenControl = TweenSection:AddToggle({
    Name = "Auto Tween",
    Description = "Smoothly follows the selected enemy, stays upright, and faces its center",
    Flag = "revive_auto_tween",
    Callback = function(enabled)
        state.autoTween = enabled
        if enabled and bossFarmControl then
            state.bossFarm = false
            bossFarmControl:Set(false, true)
            farmStatusLabel.Text = "Farm: Disabled (manual tween active)"
            farmStatusLabel.TextColor3 = COLORS.muted
        end
        if not enabled then
            stopEnemyTween()
        end
    end,
})

TweenSection:AddSlider({
    Name = "Tween Speed",
    Min = 20,
    Max = 240,
    Default = tweenSpeed,
    Step = 5,
    Flag = "revive_tween_speed",
    Callback = function(value)
        tweenSpeed = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset X",
    Min = -15,
    Max = 15,
    Default = tweenOffsetX,
    Step = 0.5,
    Flag = "revive_offset_x",
    Callback = function(value)
        tweenOffsetX = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset Y",
    Min = -10,
    Max = 15,
    Default = tweenOffsetY,
    Step = 0.5,
    Flag = "revive_offset_y",
    Callback = function(value)
        tweenOffsetY = value
    end,
})

TweenSection:AddSlider({
    Name = "Offset Z",
    Min = -15,
    Max = 15,
    Default = tweenOffsetZ,
    Step = 0.5,
    Flag = "revive_offset_z",
    Callback = function(value)
        tweenOffsetZ = value
    end,
})

local VISUAL_COLORS = {
    ["Void Purple"] = Color3.fromRGB(151, 70, 255),
    ["Royal Amethyst"] = Color3.fromRGB(196, 92, 255),
    ["Abyss Violet"] = Color3.fromRGB(92, 32, 180),
    ["Eclipse Magenta"] = Color3.fromRGB(232, 62, 255),
}
local visualColor = VISUAL_COLORS["Void Purple"]
local visualState = {outline = false, aura = false, trail = false, glow = false, wings = false, halo = false, nameplate = false, voidArmor = false}
local visualConnections = {}

local function markVisual(object)
    object:SetAttribute("VorReviveVisual", true)
    object:SetAttribute("VorReviveVisual", true)
    return object
end

local function trackVisualConnection(connection)
    table.insert(visualConnections, connection)
    return connection
end

local function makeNeonPart(name, size, cframe, parent, color, transparency, shape)
    local part = markVisual(Instance.new("Part"))
    part.Name = name
    part.Size = size
    part.CFrame = cframe
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Massless = true
    part.Material = Enum.Material.Neon
    part.Color = color or visualColor
    part.Transparency = transparency or 0
    part.Shape = shape or Enum.PartType.Block
    part.Parent = parent
    return part
end

local function weldVisualPart(part, basePart)
    local weld = markVisual(Instance.new("WeldConstraint"))
    weld.Name = "VORVisualWeld"
    weld.Part0 = basePart
    weld.Part1 = part
    weld.Parent = part
    return weld
end

local function makeWingSegment(model, core, localStart, localFinish, width, color, transparency)
    local worldStart = core.CFrame:PointToWorldSpace(localStart)
    local worldFinish = core.CFrame:PointToWorldSpace(localFinish)
    local length = (worldFinish - worldStart).Magnitude
    if length <= 0.01 then
        return nil
    end
    local segment = makeNeonPart(
        "IceFeather",
        Vector3.new(length, width, width),
        CFrame.lookAt((worldStart + worldFinish) * 0.5, worldFinish) * CFrame.Angles(0, math.rad(90), 0),
        model,
        color,
        transparency,
        Enum.PartType.Cylinder
    )
    weldVisualPart(segment, core)
    return segment
end

local function createVorVoidWings(character, torso)
    local wingModel = markVisual(Instance.new("Model"))
    wingModel.Name = "VORVoidWings"
    wingModel.Parent = character

    local highlight = markVisual(Instance.new("Highlight"))
    highlight.Name = "WingVoidBloom"
    highlight.Adornee = wingModel
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = visualColor
    highlight.FillTransparency = 0.72
    highlight.OutlineColor = Color3.fromRGB(215, 150, 255)
    highlight.OutlineTransparency = 0.18
    highlight.Parent = wingModel

    local wingMotors = {}
    local featherTips = {
        Vector3.new(1.15, 1.75, 0.02),
        Vector3.new(2.05, 2.05, 0.06),
        Vector3.new(2.95, 1.72, 0.10),
        Vector3.new(3.55, 1.05, 0.14),
        Vector3.new(3.62, 0.25, 0.18),
        Vector3.new(3.15, -0.55, 0.22),
        Vector3.new(2.35, -1.20, 0.26),
    }

    for _, side in ipairs({-1, 1}) do
        local core = makeNeonPart(
            side == -1 and "LeftWingCore" or "RightWingCore",
            Vector3.new(0.2, 0.2, 0.2),
            torso.CFrame * CFrame.new(0, 0.25, 0.62),
            wingModel,
            visualColor,
            1,
            Enum.PartType.Ball
        )
        local motor = markVisual(Instance.new("Motor6D"))
        motor.Name = side == -1 and "LeftWingMotor" or "RightWingMotor"
        motor.Part0 = torso
        motor.Part1 = core
        motor.C0 = CFrame.new(0, 0.25, 0.62)
        motor.Parent = torso
        wingMotors[side] = motor

        local previousTip = nil
        for index, baseTip in ipairs(featherTips) do
            local tip = Vector3.new(baseTip.X * side, baseTip.Y, baseTip.Z)
            local root = Vector3.new((0.20 + index * 0.075) * side, 0.46 - index * 0.07, 0)
            local middle = root:Lerp(tip, 0.48) + Vector3.new(0.12 * side, 0.30, -0.07)
            local width = 0.24 - index * 0.012
            local featherColor = index % 2 == 0 and visualColor:Lerp(Color3.fromRGB(218, 151, 255), 0.40) or visualColor
            makeWingSegment(wingModel, core, root, middle, width, featherColor, 0.05)
            makeWingSegment(wingModel, core, middle, tip, width * 0.72, featherColor:Lerp(Color3.fromRGB(221, 158, 255), 0.28), 0.10)

            local ribbonRoot = markVisual(Instance.new("Attachment"))
            ribbonRoot.Name = "FeatherRibbonRoot"
            ribbonRoot.Position = root
            ribbonRoot.Parent = core
            local ribbonTip = markVisual(Instance.new("Attachment"))
            ribbonTip.Name = "FeatherRibbonTip"
            ribbonTip.Position = tip
            ribbonTip.Parent = core
            local ribbon = markVisual(Instance.new("Beam"))
            ribbon.Name = "LuminousVoidFeather"
            ribbon.Attachment0 = ribbonRoot
            ribbon.Attachment1 = ribbonTip
            ribbon.Color = ColorSequence.new(featherColor, Color3.fromRGB(218, 151, 255))
            ribbon.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.28),
                NumberSequenceKeypoint.new(0.72, 0.40),
                NumberSequenceKeypoint.new(1, 0.78),
            })
            ribbon.Width0 = width * 1.9
            ribbon.Width1 = width * 0.42
            ribbon.LightEmission = 1
            ribbon.LightInfluence = 0
            ribbon.Segments = 5
            ribbon.FaceCamera = true
            ribbon.Parent = core

            local crystal = makeNeonPart(
                "FeatherCrystal",
                Vector3.new(width * 1.35, width * 1.35, width * 1.35),
                core.CFrame * CFrame.new(tip),
                wingModel,
                Color3.fromRGB(211, 123, 255),
                0.12,
                Enum.PartType.Ball
            )
            weldVisualPart(crystal, core)
            if previousTip then
                makeWingSegment(wingModel, core, previousTip, tip, 0.075, visualColor:Lerp(Color3.fromRGB(225, 169, 255), 0.52), 0.22)
            end
            previousTip = tip
        end

        local rootLight = markVisual(Instance.new("PointLight"))
        rootLight.Name = "WingRootGlow"
        rootLight.Color = visualColor
        rootLight.Brightness = 1.4
        rootLight.Range = 10
        rootLight.Shadows = false
        rootLight.Parent = core

        local sparkleAttachment = markVisual(Instance.new("Attachment"))
        sparkleAttachment.Name = "WingSparkleAttachment"
        sparkleAttachment.Parent = core
        local sparkles = markVisual(Instance.new("ParticleEmitter"))
        sparkles.Name = "WingVoidMotes"
        sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        sparkles.Color = ColorSequence.new(visualColor, Color3.fromRGB(222, 151, 255))
        sparkles.LightEmission = 1
        sparkles.Rate = 5
        sparkles.Lifetime = NumberRange.new(0.7, 1.35)
        sparkles.Speed = NumberRange.new(0.35, 1.1)
        sparkles.SpreadAngle = Vector2.new(80, 80)
        sparkles.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.20),
            NumberSequenceKeypoint.new(1, 0),
        })
        sparkles.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.10),
            NumberSequenceKeypoint.new(1, 1),
        })
        sparkles.Parent = sparkleAttachment
    end

    local animationStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if not wingModel.Parent then
            return
        end
        local phase = math.sin((os.clock() - animationStart) * 2.15)
        for side, motor in pairs(wingMotors) do
            if motor.Parent then
                motor.C0 = CFrame.new(0, 0.25, 0.62) * CFrame.Angles(
                    math.rad(phase * 1.2),
                    math.rad(side * phase * 4.2),
                    math.rad(side * phase * 2.4)
                )
            end
        end
    end))
end

local function createVorVoidHalo(character, head)
    local haloModel = markVisual(Instance.new("Model"))
    haloModel.Name = "VORVoidHalo"
    haloModel.Parent = character

    local haloHighlight = markVisual(Instance.new("Highlight"))
    haloHighlight.Name = "HaloVoidBloom"
    haloHighlight.Adornee = haloModel
    haloHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    haloHighlight.FillColor = visualColor
    haloHighlight.FillTransparency = 0.48
    haloHighlight.OutlineColor = Color3.fromRGB(220, 153, 255)
    haloHighlight.OutlineTransparency = 0.08
    haloHighlight.Parent = haloModel

    local core = makeNeonPart(
        "HaloCore",
        Vector3.new(0.16, 0.16, 0.16),
        head.CFrame * CFrame.new(0, 1.58, 0) * CFrame.Angles(math.rad(-32), 0, 0),
        haloModel,
        visualColor,
        1,
        Enum.PartType.Ball
    )
    local motor = markVisual(Instance.new("Motor6D"))
    motor.Name = "VORVoidHaloMotor"
    motor.Part0 = head
    motor.Part1 = core
    motor.C0 = CFrame.new(0, 1.58, 0) * CFrame.Angles(math.rad(-32), 0, 0)
    motor.Parent = head

    local segmentCount = 18
    local radius = 1.22
    local segmentLength = (math.pi * 2 * radius / segmentCount) * 1.12
    for index = 0, segmentCount - 1 do
        local angle = (index / segmentCount) * math.pi * 2
        local localPosition = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
        local segment = makeNeonPart(
            "HaloSegment",
            Vector3.new(segmentLength, 0.09, 0.14),
            core.CFrame * CFrame.new(localPosition) * CFrame.Angles(0, -angle - math.pi * 0.5, 0),
            haloModel,
            index % 2 == 0 and visualColor:Lerp(Color3.fromRGB(221, 154, 255), 0.42) or visualColor,
            0.04
        )
        weldVisualPart(segment, core)

        if index % 3 == 0 then
            local diamond = makeNeonPart(
                "HaloVoidDiamond",
                Vector3.new(0.16, 0.16, 0.16),
                core.CFrame * CFrame.new(localPosition * 1.08) * CFrame.Angles(math.rad(45), math.rad(45), 0),
                haloModel,
                Color3.fromRGB(213, 124, 255),
                0.05
            )
            weldVisualPart(diamond, core)
        end
    end

    local haloLight = markVisual(Instance.new("PointLight"))
    haloLight.Name = "HaloGlow"
    haloLight.Color = visualColor
    haloLight.Brightness = 1.65
    haloLight.Range = 9
    haloLight.Shadows = false
    haloLight.Parent = core

    local attachment = markVisual(Instance.new("Attachment"))
    attachment.Name = "HaloVoidAttachment"
    attachment.Parent = core
    local snow = markVisual(Instance.new("ParticleEmitter"))
    snow.Name = "HaloVoidMotes"
    snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    snow.Color = ColorSequence.new(visualColor, Color3.fromRGB(222, 151, 255))
    snow.LightEmission = 1
    snow.Rate = 7
    snow.Lifetime = NumberRange.new(0.8, 1.5)
    snow.Speed = NumberRange.new(0.15, 0.55)
    snow.SpreadAngle = Vector2.new(180, 180)
    snow.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.17),
        NumberSequenceKeypoint.new(1, 0),
    })
    snow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.04),
        NumberSequenceKeypoint.new(1, 1),
    })
    snow.Parent = attachment

    local animationStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if motor.Parent and haloModel.Parent then
            local elapsed = os.clock() - animationStart
            motor.C0 = CFrame.new(0, 1.58 + math.sin(elapsed * 1.7) * 0.055, 0)
                * CFrame.Angles(math.rad(-32), 0, 0)
                * CFrame.Angles(0, elapsed * 0.48, 0)
        end
    end))
end

local function createVorVoidArmor(character)
    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    if not torso or not head then
        return
    end

    local model = markVisual(Instance.new("Model"))
    model.Name = "VORVoidArmor"
    model.Parent = character

    local function armorPart(name, basePart, size, localCFrame, color, transparency, shape, material)
        if not basePart then return nil end
        local part = makeNeonPart(name, size, basePart.CFrame * localCFrame, model, color, transparency, shape)
        part.Material = material or Enum.Material.Metal
        weldVisualPart(part, basePart)
        return part
    end

    local voidBlack = Color3.fromRGB(5, 2, 11)
    local obsidian = Color3.fromRGB(15, 7, 27)
    local voidMetal = Color3.fromRGB(40, 15, 68)
    local voidViolet = visualColor
    local voidEnergy = Color3.fromRGB(208, 101, 255)

    -- The armor follows the avatar silhouette: blackened metal carries the
    -- weight while narrow violet seams supply the living VOR energy.
    armorPart(
        "VORVoidUndersuit",
        torso,
        torso.Size + Vector3.new(0.12, 0.10, 0.10),
        CFrame.new(0, -0.02, 0.02),
        voidBlack,
        0.30,
        nil,
        Enum.Material.SmoothPlastic
    )
    armorPart(
        "VORObsidianBreastplate",
        torso,
        Vector3.new(math.max(1.12, torso.Size.X * 0.62), math.max(1.12, torso.Size.Y * 0.60), 0.16),
        CFrame.new(0, 0.08, -(torso.Size.Z * 0.5 + 0.09)),
        obsidian,
        0.04
    )
    armorPart(
        "LeftVoidChestBlade",
        torso,
        Vector3.new(math.max(0.18, torso.Size.X * 0.13), math.max(0.82, torso.Size.Y * 0.45), 0.12),
        CFrame.new(-torso.Size.X * 0.34, 0.10, -(torso.Size.Z * 0.5 + 0.08)) * CFrame.Angles(0, 0, math.rad(-16)),
        voidMetal,
        0.06
    )
    armorPart(
        "RightVoidChestBlade",
        torso,
        Vector3.new(math.max(0.18, torso.Size.X * 0.13), math.max(0.82, torso.Size.Y * 0.45), 0.12),
        CFrame.new(torso.Size.X * 0.34, 0.10, -(torso.Size.Z * 0.5 + 0.08)) * CFrame.Angles(0, 0, math.rad(16)),
        voidMetal,
        0.06
    )
    local chestCore = armorPart(
        "VORVoidCore",
        torso,
        Vector3.new(0.34, 0.34, 0.13),
        CFrame.new(0, 0.10, -(torso.Size.Z * 0.5 + 0.20)) * CFrame.Angles(0, 0, math.rad(45)),
        voidEnergy,
        0.00,
        nil,
        Enum.Material.Neon
    )
    armorPart(
        "VORObsidianBelt",
        torso,
        Vector3.new(torso.Size.X + 0.18, 0.22, torso.Size.Z + 0.16),
        CFrame.new(0, -(torso.Size.Y * 0.5 - 0.13), 0.02),
        voidBlack,
        0.04
    )

    for _, sideInfo in ipairs({{"Left", -1}, {"Right", 1}}) do
        local side = sideInfo[1]
        local sign = sideInfo[2]
        armorPart(
            side .. "VORPauldron",
            torso,
            Vector3.new(0.58, 0.28, 0.72),
            CFrame.new(sign * (torso.Size.X * 0.5 + 0.22), torso.Size.Y * 0.32, -0.01)
                * CFrame.Angles(0, 0, math.rad(sign * 18)),
            obsidian,
            0.02
        )
        armorPart(
            side .. "VoidShoulderSpike",
            torso,
            Vector3.new(0.16, 0.54, 0.22),
            CFrame.new(sign * (torso.Size.X * 0.5 + 0.48), torso.Size.Y * 0.42, -0.05)
                * CFrame.Angles(0, 0, math.rad(sign * 32)),
            voidViolet,
            0.02,
            nil,
            Enum.Material.Neon
        )

        local lowerArm = character:FindFirstChild(side .. "LowerArm") or character:FindFirstChild(side .. " Arm")
        if lowerArm then
            armorPart(
                side .. "VORVoidBracer",
                lowerArm,
                lowerArm.Size + Vector3.new(0.12, -math.min(0.10, lowerArm.Size.Y * 0.08), 0.14),
                CFrame.new(0, -lowerArm.Size.Y * 0.12, -0.02),
                voidMetal,
                0.08
            )
        end

        local upperLeg = character:FindFirstChild(side .. "UpperLeg")
        if upperLeg then
            armorPart(
                side .. "VORLegArmor",
                upperLeg,
                Vector3.new(upperLeg.Size.X + 0.10, upperLeg.Size.Y * 0.72, upperLeg.Size.Z + 0.12),
                CFrame.new(0, -upperLeg.Size.Y * 0.08, -0.03),
                voidBlack,
                0.10
            )
        end

        local lowerLeg = character:FindFirstChild(side .. "LowerLeg") or character:FindFirstChild(side .. " Leg")
        if lowerLeg then
            armorPart(
                side .. "VORVoidBoot",
                lowerLeg,
                lowerLeg.Size + Vector3.new(0.16, 0.08, 0.22),
                CFrame.new(0, -lowerLeg.Size.Y * 0.16, -0.05),
                obsidian,
                0.06
            )
            armorPart(
                side .. "BootVoidRune",
                lowerLeg,
                Vector3.new(math.max(0.18, lowerLeg.Size.X * 0.30), math.max(0.38, lowerLeg.Size.Y * 0.32), 0.13),
                CFrame.new(0, -lowerLeg.Size.Y * 0.25, -(lowerLeg.Size.Z * 0.5 + 0.08)),
                voidViolet,
                0.03,
                nil,
                Enum.Material.Neon
            )
        end
    end

    -- A narrow crown sits above the eyes and keeps the avatar face readable.
    armorPart(
        "VORVoidCrownBand",
        head,
        Vector3.new(math.max(1.35, head.Size.X * 0.82), 0.12, 0.10),
        CFrame.new(0, head.Size.Y * 0.30, -(head.Size.Z * 0.5 + 0.04)),
        obsidian,
        0.02
    )
    for crownIndex = -2, 2 do
        local crownHeight = crownIndex == 0 and 0.50 or (math.abs(crownIndex) == 1 and 0.38 or 0.27)
        armorPart(
            "VORCrownSpike" .. tostring(crownIndex + 3),
            head,
            Vector3.new(0.12, crownHeight, 0.12),
            CFrame.new(crownIndex * 0.25, head.Size.Y * 0.5 + crownHeight * 0.32, -0.08)
                * CFrame.Angles(0, 0, math.rad(crownIndex * -7)),
            crownIndex == 0 and voidEnergy or voidViolet,
            0.02,
            nil,
            Enum.Material.Neon
        )
    end

    if chestCore then
        local coreLight = markVisual(Instance.new("PointLight"))
        coreLight.Name = "SuitCoreGlow"
        coreLight.Color = voidEnergy
        coreLight.Brightness = 1.65
        coreLight.Range = 9
        coreLight.Shadows = false
        coreLight.Parent = chestCore
        local glowStart = os.clock()
        trackVisualConnection(RunService.RenderStepped:Connect(function()
            if coreLight.Parent then
                coreLight.Brightness = 1.25 + (math.sin((os.clock() - glowStart) * 2.8) + 1) * 0.34
            end
        end))
    end

    local highlight = markVisual(Instance.new("Highlight"))
    highlight.Name = "VORVoidBloom"
    highlight.Adornee = model
    highlight.FillColor = visualColor
    highlight.FillTransparency = 0.82
    highlight.OutlineColor = voidEnergy
    highlight.OutlineTransparency = 0.14
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = model

    local attachment = markVisual(Instance.new("Attachment"))
    attachment.Name = "VORVoidMoteAttachment"
    attachment.Position = Vector3.new(0, torso.Size.Y * 0.5, 0)
    attachment.Parent = torso
    local voidMotes = markVisual(Instance.new("ParticleEmitter"))
    voidMotes.Name = "VORVoidMotes"
    voidMotes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    voidMotes.Color = ColorSequence.new(voidViolet, voidEnergy)
    voidMotes.LightEmission = 1
    voidMotes.Rate = 12
    voidMotes.Lifetime = NumberRange.new(0.9, 1.8)
    voidMotes.Speed = NumberRange.new(0.25, 1.15)
    voidMotes.Acceleration = Vector3.new(0, 1.8, 0)
    voidMotes.SpreadAngle = Vector2.new(180, 180)
    voidMotes.Rotation = NumberRange.new(0, 360)
    voidMotes.RotSpeed = NumberRange.new(-55, 55)
    voidMotes.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.10),
        NumberSequenceKeypoint.new(0.48, 0.22),
        NumberSequenceKeypoint.new(1, 0),
    })
    voidMotes.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.28),
        NumberSequenceKeypoint.new(0.45, 0.08),
        NumberSequenceKeypoint.new(1, 1),
    })
    voidMotes.Parent = attachment

    -- Four light shards orbit the torso like fragments pulled into the core.
    local orbitCore = makeNeonPart(
        "VOROrbitCore",
        Vector3.new(0.10, 0.10, 0.10),
        torso.CFrame,
        model,
        voidViolet,
        1,
        Enum.PartType.Ball
    )
    local orbitMotor = markVisual(Instance.new("Motor6D"))
    orbitMotor.Name = "VORVoidOrbitMotor"
    orbitMotor.Part0 = torso
    orbitMotor.Part1 = orbitCore
    orbitMotor.C0 = CFrame.new()
    orbitMotor.Parent = torso
    for shardIndex = 0, 3 do
        local angle = shardIndex * math.pi * 0.5
        local shard = makeNeonPart(
            "VOROrbitShard" .. tostring(shardIndex + 1),
            Vector3.new(0.10, 0.38, 0.10),
            orbitCore.CFrame
                * CFrame.new(math.cos(angle) * 1.35, (shardIndex % 2 == 0) and 0.42 or -0.30, math.sin(angle) * 1.35)
                * CFrame.Angles(math.rad(24), 0, math.rad(45)),
            model,
            shardIndex % 2 == 0 and voidEnergy or voidViolet,
            0.05
        )
        weldVisualPart(shard, orbitCore)
    end
    local orbitStart = os.clock()
    trackVisualConnection(RunService.RenderStepped:Connect(function()
        if orbitMotor.Parent and model.Parent then
            local elapsed = os.clock() - orbitStart
            orbitMotor.C0 = CFrame.new(0, math.sin(elapsed * 1.6) * 0.07, 0)
                * CFrame.Angles(0, elapsed * 0.72, 0)
        end
    end))
end

local function clearCharacterVisuals(character)
    character = character or LocalPlayer.Character
    if not character then
        return
    end
    for index = #visualConnections, 1, -1 do
        local connection = visualConnections[index]
        pcall(function()
            connection:Disconnect()
        end)
        visualConnections[index] = nil
    end
    for _, descendant in ipairs(character:GetDescendants()) do
        if descendant:GetAttribute("VorReviveVisual") == true or descendant:GetAttribute("CodexReviveVisual") == true then
            descendant:Destroy()
        end
    end
end

local function getLocalNameplateRoot()
    local worldGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    worldGui = worldGui and worldGui:FindFirstChild("World")
    return worldGui and worldGui:FindFirstChild(LocalPlayer.Name)
end

local function applyVorNameplate()
    local nameplateRoot = getLocalNameplateRoot()
    if not nameplateRoot then
        return false
    end
    local changed = false
    for _, descendant in ipairs(nameplateRoot:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local managed = descendant:GetAttribute("VORNameplateManaged") == true
                or descendant:GetAttribute("CodexNameplateManaged") == true
            local isPlayerName = descendant.Text == LocalPlayer.Name or descendant.Text == LocalPlayer.DisplayName
            if managed or isPlayerName then
                if not managed then
                    descendant:SetAttribute("VOROriginalNameplateText", descendant.Text)
                    descendant:SetAttribute("VORNameplateManaged", true)
                end
                if descendant.Text ~= "VOR" then
                    descendant.Text = "VOR"
                end
                changed = true
            end
        end
    end
    return changed
end

local function restoreVorNameplate()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local worldGui = playerGui and playerGui:FindFirstChild("World")
    if not worldGui then
        return
    end
    for _, descendant in ipairs(worldGui:GetDescendants()) do
        if descendant:IsA("TextLabel")
            and (descendant:GetAttribute("VORNameplateManaged") == true
                or descendant:GetAttribute("CodexNameplateManaged") == true) then
            descendant.Text = tostring(
                descendant:GetAttribute("VOROriginalNameplateText")
                or descendant:GetAttribute("CodexOriginalNameplateText")
                or LocalPlayer.DisplayName
            )
            descendant:SetAttribute("VOROriginalNameplateText", nil)
            descendant:SetAttribute("VORNameplateManaged", nil)
            descendant:SetAttribute("CodexOriginalNameplateText", nil)
            descendant:SetAttribute("CodexNameplateManaged", nil)
        end
    end
end

local function applyCharacterVisuals()
    if visualState.nameplate then
        applyVorNameplate()
    else
        restoreVorNameplate()
    end
    local character = LocalPlayer.Character
    if not character then
        return
    end
    clearCharacterVisuals(character)
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end

    if visualState.outline then
        local highlight = markVisual(Instance.new("Highlight"))
        highlight.Name = "VORVoidOutline"
        highlight.Adornee = character
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.FillColor = visualColor
        highlight.FillTransparency = 0.78
        highlight.OutlineColor = Color3.fromRGB(220, 151, 255)
        highlight.OutlineTransparency = 0.08
        highlight.Parent = character
    end

    if visualState.aura then
        local attachment = markVisual(Instance.new("Attachment"))
        attachment.Name = "VORVoidAuraAttachment"
        attachment.Parent = root
        local emitter = markVisual(Instance.new("ParticleEmitter"))
        emitter.Name = "VORVoidAura"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(visualColor, Color3.fromRGB(221, 151, 255))
        emitter.LightEmission = 0.75
        emitter.Rate = 22
        emitter.Lifetime = NumberRange.new(0.7, 1.4)
        emitter.Speed = NumberRange.new(1.5, 4)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.RotSpeed = NumberRange.new(-80, 80)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.28),
            NumberSequenceKeypoint.new(0.55, 0.16),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Parent = attachment
    end

    if visualState.trail then
        local attachment0 = markVisual(Instance.new("Attachment"))
        attachment0.Name = "VORTrailTop"
        attachment0.Position = Vector3.new(0, 1.7, 0)
        attachment0.Parent = root
        local attachment1 = markVisual(Instance.new("Attachment"))
        attachment1.Name = "VORTrailBottom"
        attachment1.Position = Vector3.new(0, -1.7, 0)
        attachment1.Parent = root
        local trail = markVisual(Instance.new("Trail"))
        trail.Name = "VORVoidTrail"
        trail.Attachment0 = attachment0
        trail.Attachment1 = attachment1
        trail.Color = ColorSequence.new(visualColor, Color3.fromRGB(222, 151, 255))
        trail.LightEmission = 0.8
        trail.Lifetime = 0.32
        trail.MinLength = 0.12
        trail.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.12),
            NumberSequenceKeypoint.new(1, 1),
        })
        trail.Parent = root
    end

    if visualState.glow then
        local light = markVisual(Instance.new("PointLight"))
        light.Name = "VORVoidGlow"
        light.Color = visualColor
        light.Brightness = 1.35
        light.Range = 12
        light.Shadows = false
        light.Parent = root
    end

    local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or root
    local head = character:FindFirstChild("Head")
    if visualState.wings and torso then
        createVorVoidWings(character, torso)
    end
    if visualState.halo and head then
        createVorVoidHalo(character, head)
    end
    if visualState.voidArmor then
        createVorVoidArmor(character)
    end

    local activeVisuals = {}
    for key, enabled in pairs(visualState) do
        if enabled then
            table.insert(activeVisuals, key)
        end
    end
    table.sort(activeVisuals)
    visualStatusLabel.Text = #activeVisuals > 0
        and ("Visuals: " .. table.concat(activeVisuals, ", "))
        or "Visuals: All effects disabled"
    visualStatusLabel.TextColor3 = COLORS.success
end

VisualSection:AddDropdown({
    Name = "Visual Color",
    Options = {"Void Purple", "Royal Amethyst", "Abyss Violet", "Eclipse Magenta"},
    Default = "Void Purple",
    Flag = "revive_visual_color",
    Callback = function(value)
        visualColor = VISUAL_COLORS[value] or VISUAL_COLORS["Void Purple"]
        applyCharacterVisuals()
    end,
})

for _, option in ipairs({
    {Name = "Void Outline", Key = "outline", Description = "Violet VOR character highlight"},
    {Name = "Void Aura", Key = "aura", Description = "Glowing purple void particles around your body"},
    {Name = "Void Trail", Key = "trail", Description = "Leaves a dark-violet energy trail while moving"},
    {Name = "Body Glow", Key = "glow", Description = "Soft colored light around your character"},
    {Name = "VOR Void Wings", Key = "wings", Description = "Layered violet energy wings with a gentle living motion"},
    {Name = "VOR Void Halo", Key = "halo", Description = "Floating rotating void halo with purple motes"},
    {Name = "VOR Nameplate", Key = "nameplate", Description = "Locally changes your overhead in-game name to VOR; your Roblox account name is untouched"},
}) do
    VisualSection:AddToggle({
        Name = option.Name,
        Description = option.Description,
        Flag = "revive_visual_" .. option.Key,
        Callback = function(enabled)
            visualState[option.Key] = enabled
            applyCharacterVisuals()
        end,
    })
end

VisualInfoSection:AddLabel("VOR wings, halo, and armor use asset-free local geometry, so every purple preset stays compatible.")
VisualInfoSection:AddLabel("VOR Nameplate is local-only and restores your real display name when disabled.")

local catalogOutfitId = ""
local originalAvatarDescription = nil
local activeCatalogDescription = nil
local voidArmorControl

local function getCharacterHumanoid()
    local character = LocalPlayer.Character
    return character and character:FindFirstChildWhichIsA("Humanoid") or nil
end

local function applyLocalDescription(description, statusText)
    local humanoid = getCharacterHumanoid()
    if not humanoid or not description then
        outfitStatusLabel.Text = "Outfit: Waiting for your character"
        outfitStatusLabel.TextColor3 = COLORS.error
        return false
    end
    if not originalAvatarDescription then
        local captured, currentDescription = pcall(function()
            return humanoid:GetAppliedDescription()
        end)
        if captured then
            originalAvatarDescription = currentDescription
        end
    end
    local ok = pcall(function()
        humanoid:ApplyDescription(description:Clone())
    end)
    outfitStatusLabel.Text = ok and ("Outfit: " .. statusText) or "Outfit: Preview was blocked by this game"
    outfitStatusLabel.TextColor3 = ok and COLORS.success or COLORS.error
    if ok then
        task.delay(0.55, function()
            if gui.Parent then applyCharacterVisuals() end
        end)
    end
    return ok
end

OutfitSection:AddInput({
    Name = "Marketplace Outfit ID",
    Placeholder = "Enter a public Roblox outfit ID...",
    Default = "",
    Flag = "codex_tools_marketplace_outfit_id",
    Callback = function(value)
        catalogOutfitId = tostring(value or ""):match("%d+") or ""
    end,
})

OutfitSection:AddButton({
    Name = "Preview Outfit Locally",
    Description = "Loads a public Roblox avatar outfit for your screen only; it does not grant ownership",
    Persist = false,
    Callback = function()
        local outfitId = tonumber(catalogOutfitId)
        if not outfitId or outfitId <= 0 then
            Window:Notify("Outfit Tools", "Enter a valid public outfit ID first", 4)
            return
        end
        outfitStatusLabel.Text = "Outfit: Loading marketplace outfit " .. outfitId .. "..."
        outfitStatusLabel.TextColor3 = COLORS.muted
        task.spawn(function()
            local ok, description = pcall(function()
                return Players:GetHumanoidDescriptionFromOutfitId(outfitId)
            end)
            if not ok or not description then
                outfitStatusLabel.Text = "Outfit: ID could not be loaded"
                outfitStatusLabel.TextColor3 = COLORS.error
                return
            end
            activeCatalogDescription = description:Clone()
            if applyLocalDescription(activeCatalogDescription, "Local marketplace preview " .. outfitId) then
                Window:Notify("Outfit Tools", "Local preview applied; no item was purchased", 4)
            end
        end)
    end,
})

OutfitSection:AddButton({
    Name = "Restore My Roblox Avatar",
    Description = "Removes the local marketplace preview and restores your real avatar appearance",
    Persist = false,
    Callback = function()
        task.spawn(function()
            activeCatalogDescription = nil
            local description = originalAvatarDescription
            if not description then
                local ok, fetched = pcall(function()
                    return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId)
                end)
                description = ok and fetched or nil
            end
            if voidArmorControl then voidArmorControl:Set(false) end
            if applyLocalDescription(description, "Your Roblox avatar restored") then
                originalAvatarDescription = nil
            end
        end)
    end,
})

voidArmorControl = VoidArmorSection:AddToggle({
    Name = "VOR Void Armor",
    Description = "Blackened metal armor, violet core, crown spikes, bracers, boots, void motes, and orbiting shards",
    Flag = "codex_tools_frozen_everest_outfit",
    Callback = function(enabled)
        visualState.voidArmor = enabled
        if enabled then
            visualColor = VISUAL_COLORS["Void Purple"]
        end
        applyCharacterVisuals()
        outfitStatusLabel.Text = enabled and "Outfit: VOR Void Armor equipped" or "Outfit: VOR Void Armor removed"
        outfitStatusLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
    end,
})

VoidArmorSection:AddButton({
    Name = "Equip Full VOR Armor",
    Description = "Equips the complete black-metal and violet-energy armor preset in one click",
    Persist = false,
    Callback = function()
        voidArmorControl:Set(true)
        Window:Notify("VOR Void Armor", "VOR Void Armor equipped locally", 4)
    end,
})

VoidArmorSection:AddLabel("Marketplace previews and VOR Void Armor are cosmetic only; they do not add items to your Roblox inventory.")

track(LocalPlayer.PlayerGui.DescendantAdded:Connect(function(descendant)
    if visualState.nameplate and descendant:IsA("TextLabel") then
        task.defer(applyVorNameplate)
    end
end))

-- Linked overnight controls mirror the real categorized controls. They are not
-- saved twice; the underlying controls keep the single persistent profile flag.
overnightMultiHitControl = OvernightSection:AddToggle({
    Name = "Multi Hit All Bosses",
    Description = "Fast confirmed round-robin combat while you remain anywhere",
    Persist = false,
    Callback = function(enabled)
        if multiHitControl and multiHitControl:Get() ~= enabled then
            multiHitControl:Set(enabled)
        end
    end,
})

overnightBossFarmControl = OvernightSection:AddToggle({
    Name = "Follow Latest Boss",
    Description = "Keeps your character positioned at the newest progression boss",
    Persist = false,
    Callback = function(enabled)
        if bossFarmControl and bossFarmControl:Get() ~= enabled then
            bossFarmControl:Set(enabled)
        end
    end,
})

overnightReaperControl = OvernightSection:AddToggle({
    Name = "Auto Reaper",
    Description = "Cooldown-aware companion Reaper automation without duplicate requests",
    Persist = false,
    Callback = function(enabled)
        if autoReaperControl and autoReaperControl:Get() ~= enabled then
            autoReaperControl:Set(enabled)
        end
    end,
})

overnightDeathKingControl = OvernightSection:AddToggle({
    Name = "Auto Death King",
    Description = "Continuously advances the Death King special boss",
    Persist = false,
    Callback = function(enabled)
        if deathKingControl and deathKingControl:Get() ~= enabled then
            deathKingControl:Set(enabled)
        end
    end,
})

overnightCursedKingControl = OvernightSection:AddToggle({
    Name = "Auto Cursed King",
    Description = "Continuously advances Cursed King levels, including before native auto-resume unlocks",
    Persist = false,
    Callback = function(enabled)
        if cursedKingControl and cursedKingControl:Get() ~= enabled then
            cursedKingControl:Set(enabled)
        end
    end,
})

overnightNightmareControl = OvernightSection:AddToggle({
    Name = "Auto Nightmare / Death Tower",
    Description = "AFK climbs each Death Tower section toward the next rebirth requirement",
    Persist = false,
    Callback = function(enabled)
        if nightmareControl and nightmareControl:Get() ~= enabled then
            nightmareControl:Set(enabled)
        end
    end,
})

overnightSpecialPriorityControl = OvernightSection:AddToggle({
    Name = "Special Boss Priority Loop",
    Description = "Runs the selected special wins, timed Multi Hit, and next tower section automatically",
    Persist = false,
    Callback = function(enabled)
        if specialPriorityControl and specialPriorityControl:Get() ~= enabled then
            specialPriorityControl:Set(enabled)
        end
    end,
})

overnightAutoEquipControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Equip Last Unlocked",
    Description = "Follows the newest sword in your live owned inventory",
    Persist = false,
    Callback = function(enabled)
        if autoEquipBestControl and autoEquipBestControl:Get() ~= enabled then
            autoEquipBestControl:Set(enabled)
        end
    end,
})

overnightAutoUpgradeControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Upgrade Equipped Sword",
    Description = "Continuously upgrades the sword currently being held",
    Persist = false,
    Callback = function(enabled)
        if autoUpgradeControl and autoUpgradeControl:Get() ~= enabled then
            autoUpgradeControl:Set(enabled)
        end
    end,
})

overnightAutoRebirthControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Rebirth",
    Description = "Rebirths as soon as the live Death Tower requirement is met",
    Persist = false,
    Callback = function(enabled)
        if autoRebirthControl and autoRebirthControl:Get() ~= enabled then
            autoRebirthControl:Set(enabled)
        end
    end,
})

overnightAutoSoulRingControl = OvernightUpgradeSection:AddToggle({
    Name = "Auto Upgrade Soul Ring",
    Description = "Uses the Soul Ring batch selected in Progress",
    Persist = false,
    Callback = function(enabled)
        if state.autoSoulRingControl and state.autoSoulRingControl:Get() ~= enabled then
            state.autoSoulRingControl:Set(enabled)
        end
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Tower AFK",
    Description = "Enables only Anti-AFK and Auto Nightmare; every non-tower feature stays optional",
    Persist = false,
    Callback = function()
        if specialPriorityControl:Get() then
            specialPriorityControl:Set(false)
        end
        if cursedKingControl:Get() then
            cursedKingControl:Set(false)
        end
        if deathKingControl:Get() then
            deathKingControl:Set(false)
        end
        antiAfkControl:Set(true)
        nightmareControl:Set(true)
        setReviveStatus("Tower-only AFK enabled", true)
        Window:Notify("Tower AFK", "Anti-AFK and Auto Nightmare are running; other features remain optional", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Multi-Hit AFK",
    Description = "Runs Anti-AFK plus standalone Multi Hit for the ground bosses",
    Persist = false,
    Callback = function()
        specialPriorityControl:Set(false)
        deathKingControl:Set(false)
        cursedKingControl:Set(false)
        nightmareControl:Set(false)
        antiAfkControl:Set(true)
        multiHitControl:Set(true)
        setReviveStatus("Standalone Multi-Hit AFK enabled", true)
        Window:Notify("Multi-Hit AFK", "Anti-AFK and all-boss Multi Hit are running", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Enable Priority AFK",
    Description = "Runs Anti-AFK plus the selected special boss and its built-in Multi Hit phase",
    Persist = false,
    Callback = function()
        antiAfkControl:Set(true)
        specialPriorityControl:Set(true)
        setReviveStatus("Special Priority AFK enabled for " .. priority.target, true)
        Window:Notify("Priority AFK", priority.target .. " will alternate with timed Multi Hit", 4)
    end,
})

OvernightUpgradeSection:AddButton({
    Name = "Stop Overnight Automation",
    Description = "Stops the linked overnight features without changing visual settings",
    Persist = false,
    Callback = function()
        antiAfkControl:Set(false)
        specialPriorityControl:Set(false)
        multiHitControl:Set(false)
        bossFarmControl:Set(false)
        autoReaperControl:Set(false)
        deathKingControl:Set(false)
        cursedKingControl:Set(false)
        nightmareControl:Set(false)
        autoEquipBestControl:Set(false)
        autoUpgradeControl:Set(false)
        state.autoSoulRingControl:Set(false)
        dailyRewardControl:Set(false)
        onlineRewardControl:Set(false)
        soulSpawnerControl:Set(false)
        starterRewardControl:Set(false)
        bossRewardControl:Set(false)
        setReviveStatus("Overnight automation stopped", nil)
    end,
})

OvernightUpgradeSection:AddLabel("Choose Tower AFK, standalone Multi-Hit AFK, or Priority AFK. Auto Rebirth remains optional.")

track(LocalPlayer.CharacterAdded:Connect(function()
    multiHitNeedsBootstrap = true
    nightmarePortalPrimedCharacter = nil
    task.wait(0.55)
    if activeCatalogDescription then
        local humanoid = getCharacterHumanoid()
        if humanoid then
            pcall(function()
                humanoid:ApplyDescription(activeCatalogDescription:Clone())
            end)
            task.wait(0.35)
        end
    end
    applyCharacterVisuals()
end))

local lastRun = {}
local function isDue(key, interval)
    local now = os.clock()
    if now - (lastRun[key] or 0) < interval then
        return false
    end
    lastRun[key] = now
    return true
end

task.spawn(function()
    while gui.Parent do
        if not state.specialPriority
            and (state.autoAttack or state.bossFarm)
            and not priority.isMultiHitActive()
            and (tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0) ~= 7
            and isDue("attack", 0.12)
        then
            fireRemote("attack", getLatestUnlockedBossLevel())
        end
        if state.demonRealm and isDue("demonRealmPoll", 0.10) then
            state.demonRealmInfo = state.refreshDemonRealmStatus()
            if state.demonRealmInfo.InRealm then
                if isDue("demonRealmAttack", 0.08) then
                    fireRemote("attack", nil)
                end
            elseif state.demonRealmInfo.Open and isDue("demonRealmEnter", 1.25) then
                if fireRemote("enterTimeLimitBossReq") then
                    state.demonRealmStatusLabel.Text = "Demon Realm: Entry requested | Waiting for server confirmation"
                    state.demonRealmStatusLabel.TextColor3 = COLORS.success
                end
            end
        elseif isDue("demonRealmStatusRefresh", 1) then
            state.refreshDemonRealmStatus()
        end
        if state.reaper and isDue("reaperPoll", 0.25) then
            local reaperInfo = refreshReaperStatus()
            local serverNow = workspace:GetServerTimeNow()
            if reaperInfo.Unlocked
                and reaperInfo.MaxHP > 1
                and reaperInfo.Remaining <= 0
                and serverNow >= reaperLocalCooldownUntil
                and isDue("reaperSend", 1)
            then
                if fireRemote("staticReaperReq") then
                    -- The battle atom can update a moment after the response. This local
                    -- gate prevents duplicate requests and the game's false locked toast.
                    reaperLocalCooldownUntil = serverNow + reaperInterval
                    reaperStatusLabel.Text = "Reaper: Request sent | Waiting for confirmation"
                    reaperStatusLabel.TextColor3 = COLORS.muted
                end
            end
        end
        if state.specialPriority then
            -- Priority owns combat while enabled. Persisted or newly-clicked
            -- conflicting controls are silently returned to off instead of
            -- being allowed to cancel the requested priority loop.
            if state.autoAttack then state.autoAttack = false; attackControl:Set(false, true) end
            if state.deathKing then state.deathKing = false; deathKingControl:Set(false, true) end
            if state.cursedKing then state.cursedKing = false; cursedKingControl:Set(false, true) end
            if state.nightmare then state.nightmare = false; nightmareControl:Set(false, true) end
            if state.challengeOne then state.challengeOne = false; challengeOneControl:Set(false, true) end
            if state.challengeFive then state.challengeFive = false; challengeFiveControl:Set(false, true) end
            if state.bossFarm then
                state.bossFarm = false
                bossFarmControl:Set(false, true)
                if overnightBossFarmControl then overnightBossFarmControl:Set(false, true) end
                stopEnemyTween()
            end
            local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
            local progressChanged = priority.observeProgress()
            if progressChanged then
                -- Let the multi-hit worker observe the new phase before doing more special work.
            elseif priority.phase == "quit" then
                local exitTimedOut = os.clock() >= priority.quitDeadline
                if battleState == 0 or exitTimedOut then
                    priority.phase = "multi"
                    priority.multiEndAt = os.clock() + priority.multiSeconds
                    state.priorityMulti = true
                    multiHitNeedsBootstrap = true
                    priorityStatusLabel.Text = (exitTimedOut and "Special Priority: Exit timeout | " or "Special Priority: Arena exited | ")
                        .. "Multi Hit for " .. priority.multiSeconds .. "s"
                    priorityStatusLabel.TextColor3 = COLORS.success
                elseif isDue("priorityQuitRetry", 0.35) then
                    fireRemote("levelTimeLimitBossReq")
                    priorityStatusLabel.Text = "Special Priority: Quitting Tower before bridge Multi Hit"
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif priority.phase == "multi" then
                local remaining = math.max(0, priority.multiEndAt - os.clock())
                state.priorityMulti = remaining > 0
                priorityStatusLabel.Text = string.format("Special Priority: Multi Hit %.1fs remaining", remaining)
                priorityStatusLabel.TextColor3 = COLORS.success
                if remaining <= 0 then
                    state.priorityMulti = false
                    priority.phase = "special"
                    priority.nextStartAt = os.clock() + 0.5
                    priorityStatusLabel.Text = "Special Priority: Returning to " .. priority.target
                end
            elseif priority.activeMode then
                local activeInfo = getSpecialBossState(priority.activeMode)
                if activeInfo.Level > priority.activeLevelBefore then
                    -- Death Tower and Cursed King can replace a defeated boss with the
                    -- next section without ever returning AtomBattleState to zero.
                    priority.complete(true)
                elseif specialResultSerial > priority.seenResultSerial then
                    priority.seenResultSerial = specialResultSerial
                    priority.complete(specialResultSuccess)
                elseif battleState == priority.activeMode then
                    if isDue("prioritySpecialAttack", 0.10) then
                        fireRemote("attack", nil)
                    end
                elseif battleState == 0 and os.clock() >= priority.nextStartAt then
                    priority.complete(false)
                end
            elseif battleState == RED_DRAGON_MODE or battleState == GREEN_DRAGON_MODE or battleState == NIGHTMARE_MODE then
                local matchesTarget = priority.target == "Cycle All"
                    or (priority.target == "Nightmare" and battleState == NIGHTMARE_MODE)
                    or (priority.target == "Cursed King" and battleState == GREEN_DRAGON_MODE)
                    or (priority.target == "Death King" and battleState == RED_DRAGON_MODE)
                if matchesTarget then
                    local activeInfo = getSpecialBossState(battleState)
                    priority.activeMode = battleState
                    priority.activeLevelBefore = activeInfo.Level
                    priority.seenResultSerial = specialResultSerial
                    priority.nextStartAt = os.clock() + 2.5
                    priorityStatusLabel.Text = "Special Priority: Resumed " .. priority.modeName(battleState) .. " section"
                    priorityStatusLabel.TextColor3 = COLORS.success
                elseif isDue("priorityWrongSpecial", 1) then
                    priorityStatusLabel.Text = "Special Priority: Waiting for the selected special battle"
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif battleState == 0 and os.clock() >= priority.nextStartAt then
                if not priority.start() and isDue("priorityWaiting", 2) then
                    local required = priority.target == "Cursed King" and greenDragonUnlockLevel
                        or (priority.target == "Death King" and redDragonUnlockLevel or nightmareUnlockLevel)
                    priorityStatusLabel.Text = "Special Priority: Waiting for Main Level " .. required
                    priorityStatusLabel.TextColor3 = COLORS.muted
                end
            elseif isDue("priorityBattleWait", 1) then
                priorityStatusLabel.Text = "Special Priority: Waiting for current battle to finish"
                priorityStatusLabel.TextColor3 = COLORS.muted
            end
        elseif state.deathKing and isDue("deathKingPoll", 0.25) then
            local deathInfo = refreshDeathKingStatus()
            local serverNow = workspace:GetServerTimeNow()
            if deathInfo.BattleState == RED_DRAGON_MODE and isDue("deathKingAttack", 0.10) then
                fireRemote("attack", nil)
            elseif deathInfo.Unlocked
                and deathInfo.BattleState == 0
                and serverNow - specialLastStart[RED_DRAGON_MODE] >= (deathInfo.NativeAutoAvailable and 5 or 2)
            then
                armDeathKingAuto()
            end
        elseif state.cursedKing and isDue("cursedKingPoll", 0.25) then
            local cursedInfo = refreshCursedKingStatus()
            local serverNow = workspace:GetServerTimeNow()
            if cursedInfo.BattleState == GREEN_DRAGON_MODE and isDue("cursedKingAttack", 0.10) then
                fireRemote("attack", nil)
            elseif cursedInfo.Unlocked
                and cursedInfo.BattleState == 0
                and serverNow - specialLastStart[GREEN_DRAGON_MODE] >= (cursedInfo.NativeAutoAvailable and 5 or 2)
            then
                armCursedKingAuto()
            end
        elseif state.nightmare and isDue("nightmarePoll", 0.25) then
            local nightmareInfo = refreshNightmareStatus()
            local serverNow = workspace:GetServerTimeNow()
            if nightmareInfo.BattleState == NIGHTMARE_MODE and isDue("nightmareAttack", 0.10) then
                fireRemote("attack", nil)
            elseif nightmareInfo.Unlocked
                and nightmareInfo.BattleState == 0
                and serverNow - specialLastStart[NIGHTMARE_MODE] >= (nightmareInfo.NativeAutoAvailable and 5 or 2)
            then
                armNightmareAuto()
            end
        end
        if state.autoRebirth and isDue("hubAutoRebirth", 0.75) then
            local currentRebirth = tonumber(readAtomValue(rebirthStore, "AtomRebirth")) or 0
            local towerLevel = tonumber(readAtomValue(reaperBattleStore, "AtomTowerLevel")) or 0
            local battleState = tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0
            local requiredTower = rebirthTowerLevelRatio * (currentRebirth + 1)
            rebirthStatusLabel.Text = string.format(
                "Auto Rebirth: Rebirth %d | Tower %d / %d",
                currentRebirth,
                towerLevel,
                requiredTower
            )
            rebirthStatusLabel.TextColor3 = towerLevel >= requiredTower and COLORS.success or COLORS.muted
            if towerLevel >= requiredTower and battleState == 0 and isDue("hubAutoRebirthSend", 2) then
                if fireRemote("rebirth") then
                    rebirthStatusLabel.Text = "Auto Rebirth: Requirement met | Request sent"
                    setReviveStatus("Rebirth request sent at Death Tower " .. towerLevel, true)
                end
            end
        end
        if state.autoSoulRing and isDue("autoSoulRingUpgrade", 0.75) then
            local ringInfo = state.refreshSoulRingStatus()
            if ringInfo.Available and ringInfo.SoulStones > 0 then
                fireRemote("enhanceSoulRing", 0, 0, state.soulRingUpgradeBatch)
            end
        elseif isDue("soulRingStatusRefresh", 2) then
            state.refreshSoulRingStatus()
        end
        if visualState.nameplate and isDue("codexNameplate", 0.25) then
            applyVorNameplate()
        end
        if state.discordReminder and isDue("discordReminder", 1) then
            local remaining = math.max(0, math.ceil(nextDiscordReminderAt - os.clock()))
            if remaining <= 0 then
                showDiscordReminder()
            else
                discordReminderStatusLabel.Text = string.format(
                    "Discord Reminder: Enabled | Next in %02d:%02d",
                    math.floor(remaining / 60),
                    remaining % 60
                )
                discordReminderStatusLabel.TextColor3 = COLORS.success
            end
        end
        if state.groupReward and isDue("group", 30) then
            fireRemote("getGroupReward")
        end
        if state.challengeOne and isDue("challenge", 0.75) then
            fireRemote("startTimeLimitChallengeReq", 1, 0)
        elseif state.challengeFive and isDue("challenge", 0.75) then
            fireRemote("startTimeLimitChallengeReq", 1, 1)
        end
        if state.autoEquipBest and isDue("equipBest", 0.80) then
            equipLastUnlockedWeapon()
        end
        if state.autoUpgrade and isDue("upgrade", 0.35) then
            local equippedId = getEquippedWeaponId()
            local info = equippedId and getWeaponInfo(equippedId) or nil
            if equippedId and (not info or info.canEnhance ~= false) then
                fireRemote("enhanceWeapon", equippedId)
            elseif equippedId and isDue("upgradeSkippedStatus", 2) then
                refreshWeaponStatus("not enhanceable")
            end
        end
        if state.dailyReward and isDue("daily", 30) then
            fireRemote("getSignReward")
        end
        if state.onlineReward and isDue("online", 5) then
            fireRemote("receiveOnlineTimeReward")
        end
        if state.soulSpawner and isDue("soul", 3) then
            fireRemote("claimSoulSpawner")
        end
        if state.starterRewards and isDue("starter", 10) then
            for index = 1, 5 do
                fireRemote("claimChallengeReward", index)
            end
        end
        if state.bossRewards and isDue("boss", 10) then
            for index = 1, 6 do
                fireRemote("claimTimeLimitBossReward", index)
            end
        end
        task.wait(0.05)
    end
end)

local function waitForBossConfirmation(level, startingSerial, duration)
    local deadline = os.clock() + duration
    repeat
        if (confirmedAttackSerial[level] or 0) > startingSerial then
            return true
        end
        task.wait(0.01)
    until not priority.isMultiHitActive() or not gui.Parent or os.clock() >= deadline
    return (confirmedAttackSerial[level] or 0) > startingSerial
end

local function bootstrapMultiHitSession()
    if not multiHitNeedsBootstrap then
        return true
    end

    local bootstrapLevel = 1
    local startingSerial = confirmedAttackSerial[bootstrapLevel] or 0
    multiHitStatusLabel.Text = "Multi Hit: Priming the bridge session automatically..."
    multiHitStatusLabel.TextColor3 = COLORS.muted

    for _ = 1, 3 do
        fireRemote("attack", bootstrapLevel)
        if waitForBossConfirmation(bootstrapLevel, startingSerial, 0.12) then
            multiHitNeedsBootstrap = false
            multiHitStatusLabel.Text = "Multi Hit: Remote session primed"
            multiHitStatusLabel.TextColor3 = COLORS.success
            return true
        end
    end

    local enemyPart = findEnemyPart(bootstrapLevel)
    local character = LocalPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not enemyPart or not root then
        multiHitStatusLabel.Text = "Multi Hit: Waiting for Enemy 1 to load"
        multiHitStatusLabel.TextColor3 = COLORS.muted
        return false
    end

    local originalCFrame = root.CFrame
    local moved = pcall(function()
        local flatForward = Vector3.new(enemyPart.CFrame.LookVector.X, 0, enemyPart.CFrame.LookVector.Z)
        if flatForward.Magnitude < 0.05 then
            flatForward = Vector3.new(0, 0, -1)
        else
            flatForward = flatForward.Unit
        end
        local targetPosition = enemyPart.Position + flatForward * 5 + Vector3.new(0, 0.5, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(targetPosition, enemyPart.Position)
    end)

    local confirmed = false
    if moved then
        task.wait(0.10)
        for _ = 1, 5 do
            fireRemote("attack", bootstrapLevel)
            if waitForBossConfirmation(bootstrapLevel, startingSerial, 0.12) then
                confirmed = true
                break
            end
        end
        pcall(function()
            root.CFrame = originalCFrame
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    multiHitNeedsBootstrap = not confirmed
    multiHitStatusLabel.Text = confirmed
        and "Multi Hit: Bridge session primed; attacking from anywhere"
        or "Multi Hit: Bridge activation retry queued"
    multiHitStatusLabel.TextColor3 = confirmed and COLORS.success or COLORS.error
    return confirmed
end

task.spawn(function()
    local currentBoss = 1
    while gui.Parent do
        if (tonumber(readAtomValue(reaperBattleStore, "AtomBattleState")) or 0) == 7 then
            currentBoss = 1
            multiHitStatusLabel.Text = "Multi Hit: Paused while Demon Realm is active"
            multiHitStatusLabel.TextColor3 = COLORS.muted
            task.wait(0.20)
            continue
        end
        if priority.isMultiHitActive() then
            if multiHitNeedsBootstrap and not bootstrapMultiHitSession() then
                task.wait(0.25)
                continue
            end
            local maxBoss = multiHitTargetMode == "Unlocked Bosses Only"
                and getLatestUnlockedBossLevel()
                or 15
            if currentBoss > maxBoss then
                currentBoss = 1
            end

            local startingSerial = confirmedAttackSerial[currentBoss] or 0
            local confirmationDeadline = os.clock() + 0.45
            local confirmed = false
            local multiPrefix = state.priorityMulti and "Priority Multi" or "Multi Hit"
            multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " / " .. maxBoss .. " - waiting for server"
            multiHitStatusLabel.TextColor3 = COLORS.muted

            repeat
                fireRemote("attack", currentBoss)
                local retryDeadline = math.min(confirmationDeadline, os.clock() + multiHitDelay)
                repeat
                    task.wait(0.01)
                    confirmed = (confirmedAttackSerial[currentBoss] or 0) > startingSerial
                until confirmed or not priority.isMultiHitActive() or not gui.Parent or os.clock() >= retryDeadline
            until confirmed or not priority.isMultiHitActive() or not gui.Parent or os.clock() >= confirmationDeadline

            if not priority.isMultiHitActive() or not gui.Parent then
                currentBoss = 1
                multiHitStatusLabel.Text = state.specialPriority and "Multi Hit: Waiting for special-boss phase" or "Multi Hit: Disabled"
                multiHitStatusLabel.TextColor3 = COLORS.muted
                continue
            end

            if confirmed then
                multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " confirmed - advancing"
                multiHitStatusLabel.TextColor3 = COLORS.success
            else
                multiHitStatusLabel.Text = multiPrefix .. ": Boss " .. currentBoss .. " did not confirm - skipped"
                multiHitStatusLabel.TextColor3 = COLORS.error
            end

            currentBoss += 1
            if currentBoss > maxBoss then
                currentBoss = 1
                if priority.isMultiHitActive() then
                    setReviveStatus("Multi Hit completed a confirmed boss round", true)
                end
            end
            task.wait(0.01)
        else
            currentBoss = 1
            if state.specialPriority then
                multiHitStatusLabel.Text = "Multi Hit: Waiting for special-boss phase"
                multiHitStatusLabel.TextColor3 = COLORS.muted
            end
            task.wait(0.05)
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        if not state.autoTween and not state.bossFarm then
            task.wait(0.10)
            continue
        end

        local targetEnemy = state.bossFarm and getLatestUnlockedBossLevel() or selectedEnemy
        local enemyPart = findEnemyPart(targetEnemy)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
        if not enemyPart or not root then
            stopEnemyTween()
            tweenStatusLabel.Text = not enemyPart and ("Tween: Waiting for Enemy " .. targetEnemy) or "Tween: Waiting for respawn"
            tweenStatusLabel.TextColor3 = COLORS.error
            if state.bossFarm then
                farmStatusLabel.Text = "Farm: Waiting for Level " .. targetEnemy .. " - " .. getBossName(targetEnemy)
                farmStatusLabel.TextColor3 = COLORS.error
            end
            task.wait(0.25)
            continue
        end

        if controlledHumanoid ~= humanoid then
            stopEnemyTween()
            controlledHumanoid = humanoid
            if humanoid then
                originalAutoRotate = humanoid.AutoRotate
                humanoid.AutoRotate = false
            end
        end

        local flatForward = lockedEnemyFacing[enemyPart]
        if not flatForward then
            flatForward = Vector3.new(enemyPart.CFrame.LookVector.X, 0, enemyPart.CFrame.LookVector.Z)
            flatForward = flatForward.Magnitude > 0.001 and flatForward.Unit or Vector3.new(0, 0, 1)
            lockedEnemyFacing[enemyPart] = flatForward
        end
        local stableEnemyCFrame = CFrame.lookAt(enemyPart.Position, enemyPart.Position + flatForward)
        local horizontalTarget = (stableEnemyCFrame * CFrame.new(tweenOffsetX, 0, tweenOffsetZ)).Position

        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {character, workspace:FindFirstChild("Enemies")}
        raycastParams.IgnoreWater = true
        local ground = workspace:Raycast(horizontalTarget + Vector3.new(0, 35, 0), Vector3.new(0, -100, 0), raycastParams)
        local standingY = enemyPart.Position.Y
        if ground and humanoid then
            standingY = ground.Position.Y + humanoid.HipHeight + (root.Size.Y * 0.5)
        end
        local targetPosition = Vector3.new(horizontalTarget.X, standingY + tweenOffsetY, horizontalTarget.Z)
        local lookAt = Vector3.new(enemyPart.Position.X, targetPosition.Y, enemyPart.Position.Z)
        local goal = (lookAt - targetPosition).Magnitude > 0.05
            and CFrame.lookAt(targetPosition, lookAt, Vector3.yAxis)
            or CFrame.new(targetPosition)
        local distance = (targetPosition - root.Position).Magnitude
        local duration = math.clamp(distance / math.max(tweenSpeed, 1), 0.05, 1.25)

        if activeEnemyTween then
            activeEnemyTween:Cancel()
        end
        if distance <= 0.12 then
            root.CFrame = goal
            root.AssemblyAngularVelocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.05)
        else
            activeEnemyTween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = goal})
            activeEnemyTween:Play()
        end
        tweenStatusLabel.Text = "Tween: Enemy " .. targetEnemy .. " | Front stance | " .. math.floor(distance + 0.5) .. " studs"
        tweenStatusLabel.TextColor3 = COLORS.success
        if state.bossFarm then
            farmStatusLabel.Text = "Farm: Level " .. targetEnemy .. " - " .. getBossName(targetEnemy)
            farmStatusLabel.TextColor3 = COLORS.success
        end
        if activeEnemyTween then
            activeEnemyTween.Completed:Wait()
            if root.Parent and (state.autoTween or state.bossFarm) then
                root.CFrame = goal
                root.AssemblyAngularVelocity = Vector3.zero
            end
            activeEnemyTween = nil
        end
    end
end)

track(gui.Destroying:Connect(function()
    local hadSpecialAutomation = state.cursedKing or state.nightmare or state.specialPriority
    state.autoTween = false
    state.bossFarm = false
    state.multiHit = false
    state.priorityMulti = false
    state.cursedKing = false
    state.nightmare = false
    state.specialPriority = false
    stopEnemyTween()
    clearCharacterVisuals()
    restoreVorNameplate()
    if state.autoRebirth and remotes.SetAutoRebirth then
        pcall(function()
            remotes.SetAutoRebirth:FireServer(false, autoRebirthFloor)
        end)
    end
    if hadSpecialAutomation and remotes.setAfkResumeReq then
        pcall(function()
            remotes.setAfkResumeReq:FireServer(0, 0)
        end)
    end
end))

end

local function buildBasketballFeatures()
local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()

local ShootingPage = addHomeCategory("Shooting", 1, CATEGORY_DECALS.Shooting)
local PlayerPage = addHomeCategory("Player", 2, CATEGORY_DECALS.Player)
local DribblePage = addHomeCategory("Dribble", 3, CATEGORY_DECALS.Dribble)
local ExploitsPage = addHomeCategory("Exploits", 4, CATEGORY_DECALS.Exploits)

local AutoShotSection = ShootingPage:AddSection("Perfect Release", "Left")
local MeterSection = ShootingPage:AddSection("Shot Meter", "Right")
local ShotStatusSection = ShootingPage:AddSection("Live Shot Status", "Right")
local DefenseSection = PlayerPage:AddSection("1v1 Defense Assist", "Left")
local PlayerUtilitySection = PlayerPage:AddSection("Player Utility", "Left")
local ScoringSection = PlayerPage:AddSection("Scoring Assist", "Right")
local CameraSection = PlayerPage:AddSection("Camera", "Right")
local PlayerStatusSection = PlayerPage:AddSection("Live Player Status", "Right")
local DribbleSection = DribblePage:AddSection("Dribble Automation", "Left")
local DribbleStatusSection = DribblePage:AddSection("Live Dribble Status", "Right")
local ExploitStealSection = ExploitsPage:AddSection("Extended Steal", "Left")
local ExploitDefenseSection = ExploitsPage:AddSection("Unfair Defense", "Right")
local ExploitMovementSection = ExploitsPage:AddSection("Ball & Aim Advantages", "Left")
local ExploitStatusSection = ExploitsPage:AddSection("Exploit Status", "Right")

selectHomeCategory("Shooting")

local basketballState = {
    AutoGreen = false,
    AntiAfk = false,
    AutoGuard = false,
    SmartSteal = false,
    SmartBlock = false,
    AutoRebound = false,
    AutoDunk = false,
    AutoCombo = false,
    CourtVision = false,
    RemoteStealAura = false,
    RemoteBlockAura = false,
    LooseBallMagnet = false,
    GoalAimLock = false,
    Calibration = 0.78,
    GuideEnabled = true,
    MeterScale = 1,
    GuardDistance = 22,
    StealDistance = 14,
    BlockDistance = 20,
    BlockReaction = 0.10,
    ReboundDistance = 20,
    ComboDistance = 12,
    ComboInterval = 2.25,
    ComboStyle = "Smart Mix",
    RemoteStealRange = 32,
    RemoteStealInterval = 0.40,
    RemoteBlockRange = 45,
    MagnetRange = 35,
    ReleasedThisShot = false,
    ForceNextShot = false,
    LastMeterValue = 0,
    WasMeterVisible = false,
    MobileShootHeld = false,
    MobileReleaseMethod = "None",
    LastStatusUpdate = 0,
    LastAssistUpdate = 0,
    LastSteal = 0,
    LastBlock = 0,
    LastRebound = 0,
    LastDunk = 0,
    LastCombo = 0,
    LastRemoteSteal = 0,
    LastRemoteBlock = 0,
    LastMagnet = 0,
}

local meterStatusLabel = ShotStatusSection:AddLabel("Meter: Waiting for a shot")
local releaseStatusLabel = ShotStatusSection:AddLabel("Release: Auto Green disabled")
local timingStatusLabel = ShotStatusSection:AddLabel("Target: 78% visual -> approximately 100% server read")
local playerCourtLabel = PlayerStatusSection:AddLabel("Court: Reading...")
local playerBallLabel = PlayerStatusSection:AddLabel("Basketball: Reading...")
local playerModeLabel = PlayerStatusSection:AddLabel("Place: " .. tostring(game.PlaceId))
local antiAfkStatusLabel = PlayerUtilitySection:AddLabel("Anti-AFK: Disabled")
local defenseStatusLabel = DefenseSection:AddLabel("Defense: All assists disabled")
local scoringStatusLabel = ScoringSection:AddLabel("Scoring: Auto Dunk disabled")
local dribbleStatusLabel = DribbleStatusSection:AddLabel("Dribble: Auto Combo disabled")
DribbleStatusSection:AddLabel("Behind Back: current-hand key + X")
DribbleStatusSection:AddLabel("Spin: double current-hand input | Between Legs: double X")
DribbleStatusSection:AddLabel("Smart Mix rotates through every supported combo automatically.")
local exploitStatusLabel = ExploitStatusSection:AddLabel("Exploits: Disabled — every option is opt-in")
ExploitStatusSection:AddLabel("Experimental controls may still be rejected by server-side distance validation.")
ExploitStatusSection:AddLabel("Use the normal Player assists if a remote option is inconsistent.")

local shootingGui = nil
local shootingBar = nil
local releaseGuide = nil
local meterScaleObject = nil
local guardHeld = false
local ballHighlight = nil
local opponentHighlight = nil
local highlightedBall = nil
local highlightedOpponent = nil
local CollectionService = game:GetService("CollectionService")

local controlServiceFolder = ReplicatedStorage:FindFirstChild("Packages")
controlServiceFolder = controlServiceFolder and controlServiceFolder:FindFirstChild("Knit")
controlServiceFolder = controlServiceFolder and controlServiceFolder:FindFirstChild("Services")
controlServiceFolder = controlServiceFolder and controlServiceFolder:FindFirstChild("ControlService")
local controlEvents = controlServiceFolder and controlServiceFolder:FindFirstChild("RE")
local stealRemote = controlEvents and controlEvents:FindFirstChild("Steal")
local blockRemote = controlEvents and controlEvents:FindFirstChild("Block")
local shootMeterStartEvent = controlEvents and controlEvents:FindFirstChild("ShootMeterStart")

local okSharedUtil, BasketballSharedUtil = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SharedUtil"))
end)
if not okSharedUtil then
    BasketballSharedUtil = nil
end

local okBasketballModule, BasketballModule = pcall(function()
    return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Basketball"))
end)
if not okBasketballModule then
    BasketballModule = nil
end

local okInput, VirtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not okInput then
    VirtualInputManager = nil
end

local fallbackVirtualKeys = {
    [Enum.KeyCode.E] = 0x45,
    [Enum.KeyCode.F] = 0x46,
    [Enum.KeyCode.R] = 0x52,
    [Enum.KeyCode.V] = 0x56,
    [Enum.KeyCode.X] = 0x58,
    [Enum.KeyCode.Z] = 0x5A,
    [Enum.KeyCode.C] = 0x43,
    [Enum.KeyCode.Space] = 0x20,
}

local function sendBasketballKey(keyCode, isDown)
    if VirtualInputManager then
        local ok = pcall(function()
            VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
        end)
        if ok then
            return true
        end
    end

    local virtualKey = fallbackVirtualKeys[keyCode]
    if not virtualKey then
        return false
    end
    if isDown and type(keypress) == "function" then
        return pcall(keypress, virtualKey)
    elseif not isDown and type(keyrelease) == "function" then
        return pcall(keyrelease, virtualKey)
    end
    return false
end

local function sendShootKey(isDown)
    return sendBasketballKey(Enum.KeyCode.E, isDown)
end

local function isTouchPrimary()
    if not UserInputService.TouchEnabled then
        return false
    end

    local preferredInput
    pcall(function()
        preferredInput = UserInputService.PreferredInput
    end)

    if preferredInput ~= nil then
        return preferredInput == Enum.PreferredInput.Touch
    end

    return not UserInputService.KeyboardEnabled
end

local activeTouchInputs = {}
local mobileShootButton = nil
local mobileShootTouch = nil
local mobileShootVirtualPress = false
local lastMobileShootScan = 0

local function pointInsideGui(guiObject, point)
    if not guiObject or not guiObject.Parent or not guiObject:IsA("GuiObject") then
        return false
    end

    local position = guiObject.AbsolutePosition
    local size = guiObject.AbsoluteSize
    return point.X >= position.X
        and point.Y >= position.Y
        and point.X <= position.X + size.X
        and point.Y <= position.Y + size.Y
end

local function isGuiActuallyVisible(guiObject)
    local current = guiObject
    while current do
        if current:IsA("GuiObject") and not current.Visible then
            return false
        end
        if current:IsA("LayerCollector") and not current.Enabled then
            return false
        end
        current = current.Parent
    end
    return true
end

local function containsShootWord(value)
    local lowered = string.lower(tostring(value or ""))
    return string.find(lowered, "shoot", 1, true) ~= nil
        or string.find(lowered, "shot", 1, true) ~= nil
        or string.find(lowered, "release", 1, true) ~= nil
end

local function actionInfoUsesShoot(actionName, actionInfo)
    if containsShootWord(actionName) then
        return true
    end

    local function inspect(value, depth)
        if depth > 4 then
            return false
        end
        if value == Enum.KeyCode.E then
            return true
        end
        if type(value) == "string" and containsShootWord(value) then
            return true
        end
        if type(value) == "table" then
            for key, child in pairs(value) do
                if inspect(key, depth + 1) or inspect(child, depth + 1) then
                    return true
                end
            end
        end
        return false
    end

    return inspect(actionInfo, 0)
end

local function scoreShootButton(button)
    if not button:IsA("GuiButton") or not isGuiActuallyVisible(button) then
        return -math.huge
    end
    if gui and button:IsDescendantOf(gui) then
        return -math.huge
    end

    local score = 0
    local signature = button.Name
    if button:IsA("TextButton") then
        signature = signature .. " " .. button.Text
    end

    local ancestor = button.Parent
    for _ = 1, 3 do
        if not ancestor then
            break
        end
        signature = signature .. " " .. ancestor.Name
        ancestor = ancestor.Parent
    end

    if containsShootWord(signature) then
        score += 150
    end

    for attributeName, attributeValue in pairs(button:GetAttributes()) do
        if containsShootWord(attributeName) or containsShootWord(attributeValue) or attributeValue == "E" then
            score += 80
        end
    end

    for _, descendant in ipairs(button:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            if containsShootWord(descendant.Text) then
                score += 110
                break
            end
        end
    end

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    if viewport then
        local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
        if center.X >= viewport.X * 0.52 then
            score += 10
        end
        if center.Y >= viewport.Y * 0.35 then
            score += 8
        end
    end

    if button.AbsoluteSize.X >= 42 and button.AbsoluteSize.Y >= 42 then
        score += 5
    end

    return score
end

local function findMobileShootButton(forceScan)
    if mobileShootButton and mobileShootButton.Parent and isGuiActuallyVisible(mobileShootButton) then
        return mobileShootButton
    end

    local now = os.clock()
    if not forceScan and now - lastMobileShootScan < 0.35 then
        return nil
    end
    lastMobileShootScan = now

    local bestButton = nil
    local bestScore = -math.huge

    -- Games that use ContextActionService normally expose the correct touch
    -- button here. Matching the E binding keeps the desktop control untouched.
    local okActions, actionInfo = pcall(function()
        return ContextActionService:GetAllBoundActionInfo()
    end)
    if okActions and type(actionInfo) == "table" then
        for actionName, info in pairs(actionInfo) do
            if actionInfoUsesShoot(actionName, info) then
                local okButton, actionButton = pcall(function()
                    return ContextActionService:GetButton(actionName)
                end)
                if okButton and actionButton and actionButton:IsA("GuiButton")
                    and isGuiActuallyVisible(actionButton) then
                    mobileShootButton = actionButton
                    return actionButton
                end
            end
        end
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        for _, descendant in ipairs(playerGui:GetDescendants()) do
            if descendant:IsA("GuiButton") then
                local score = scoreShootButton(descendant)
                if score > bestScore then
                    bestScore = score
                    bestButton = descendant
                end
            end
        end
    end

    if bestScore >= 100 then
        mobileShootButton = bestButton
    else
        mobileShootButton = nil
    end
    return mobileShootButton
end

local function captureMobileShootTouch()
    if not UserInputService.TouchEnabled then
        return nil, nil
    end

    local button = findMobileShootButton(true)
    if not button then
        return nil, nil
    end

    if mobileShootTouch and activeTouchInputs[mobileShootTouch]
        and pointInsideGui(button, mobileShootTouch.Position) then
        basketballState.MobileShootHeld = true
        return button, mobileShootTouch
    end

    for touch in pairs(activeTouchInputs) do
        if touch.UserInputType == Enum.UserInputType.Touch
            and touch.UserInputState ~= Enum.UserInputState.End
            and touch.UserInputState ~= Enum.UserInputState.Cancel
            and pointInsideGui(button, touch.Position) then
            mobileShootTouch = touch
            basketballState.MobileShootHeld = true
            return button, touch
        end
    end

    return button, nil
end

local function fireInputSignal(signal, ...)
    if not signal then
        return false
    end

    if type(firesignal) == "function" then
        local ok = pcall(firesignal, signal, ...)
        if ok then
            return true
        end
    end

    if type(getconnections) == "function" then
        local okConnections, connections = pcall(getconnections, signal)
        if okConnections and type(connections) == "table" then
            local fired = false
            for _, connection in ipairs(connections) do
                local callback
                pcall(function()
                    callback = connection.Function
                end)
                if type(callback) == "function" then
                    local ok = pcall(callback, ...)
                    fired = fired or ok
                end
            end
            return fired
        end
    end

    return false
end

local function releaseMobileShootInput()
    if not UserInputService.TouchEnabled then
        return false, nil
    end

    local button, touch = captureMobileShootTouch()
    if not button then
        return false, nil
    end

    local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
    local released = false
    local methods = {}

    -- Custom mobile controls commonly listen to the button signals directly.
    if touch then
        if fireInputSignal(button.InputEnded, touch) then
            released = true
            table.insert(methods, "Touch")
        end
        if fireInputSignal(UserInputService.TouchEnded, touch, false) then
            released = true
            table.insert(methods, "TouchService")
        end
        if fireInputSignal(UserInputService.InputEnded, touch, false) then
            released = true
            table.insert(methods, "InputService")
        end
    end

    if fireInputSignal(button.MouseButton1Up, center.X, center.Y) then
        released = true
        table.insert(methods, "ButtonUp")
    end

    -- This fallback handles touch buttons implemented through mouse-compatible
    -- GuiButton events. It does not replace the normal E release on PC.
    if VirtualInputManager then
        local okMouse = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                math.floor(center.X),
                math.floor(center.Y),
                0,
                false,
                game,
                0
            )
        end)
        if okMouse then
            released = true
            table.insert(methods, "VirtualButtonUp")
        end
    end

    basketballState.MobileShootHeld = false
    mobileShootTouch = nil
    mobileShootVirtualPress = false

    return released, (#methods > 0 and table.concat(methods, "+") or nil)
end

local function pressMobileShootInput()
    if not UserInputService.TouchEnabled then
        return false
    end

    local button = findMobileShootButton(true)
    if not button then
        return false
    end

    local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
    local pressed = fireInputSignal(button.MouseButton1Down, center.X, center.Y)

    if VirtualInputManager then
        local okMouse = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(
                math.floor(center.X),
                math.floor(center.Y),
                0,
                true,
                game,
                0
            )
        end)
        pressed = pressed or okMouse
    end

    mobileShootVirtualPress = pressed
    basketballState.MobileShootHeld = pressed
    return pressed
end

local function pressShootInput()
    if isTouchPrimary() and pressMobileShootInput() then
        basketballState.MobileReleaseMethod = "Mobile button"
        return true
    end

    local pressed = sendShootKey(true)
    if pressed then
        basketballState.MobileReleaseMethod = "Keyboard E"
    end
    return pressed
end

local function releaseShootInput()
    local mobileReleased, mobileMethod = false, nil
    if isTouchPrimary() or basketballState.MobileShootHeld or mobileShootTouch then
        mobileReleased, mobileMethod = releaseMobileShootInput()
    end

    -- Always send the desktop release too. On PC this remains the original
    -- behavior; on mobile it is a harmless fallback for executors that map E.
    local keyboardReleased = sendShootKey(false)

    if mobileReleased then
        basketballState.MobileReleaseMethod = mobileMethod or "Mobile touch"
    elseif keyboardReleased then
        basketballState.MobileReleaseMethod = "Keyboard E"
    else
        basketballState.MobileReleaseMethod = "Unsupported"
    end

    return mobileReleased or keyboardReleased, basketballState.MobileReleaseMethod
end

track(UserInputService.TouchStarted:Connect(function(touch)
    activeTouchInputs[touch] = true

    local button = findMobileShootButton(false)
    if button and pointInsideGui(button, touch.Position) then
        mobileShootButton = button
        mobileShootTouch = touch
        basketballState.MobileShootHeld = true
    end
end))

track(UserInputService.TouchEnded:Connect(function(touch)
    activeTouchInputs[touch] = nil
    if touch == mobileShootTouch then
        mobileShootTouch = nil
        basketballState.MobileShootHeld = false
    end
end))

local keyPulseBusy = {}
local function pulseBasketballKey(keyCode, holdTime)
    if keyPulseBusy[keyCode] then
        return false
    end
    keyPulseBusy[keyCode] = true
    task.spawn(function()
        sendBasketballKey(keyCode, true)
        task.wait(holdTime or 0.045)
        sendBasketballKey(keyCode, false)
        keyPulseBusy[keyCode] = nil
    end)
    return true
end

local function updateReleaseGuide()
    if not releaseGuide or not releaseGuide.Parent then
        return
    end
    releaseGuide.Position = UDim2.new(0, 0, 1 - basketballState.Calibration, 0)
    releaseGuide.Visible = basketballState.GuideEnabled
end

local function resolveShotMeter()
    if shootingGui and shootingGui.Parent and shootingBar and shootingBar.Parent then
        return shootingGui, shootingBar
    end

    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local visual = playerGui and playerGui:FindFirstChild("Visual")
    local candidate = visual and visual:FindFirstChild("Shooting")
    local bar = candidate and candidate:FindFirstChild("Bar")
    if not candidate or not bar or not candidate:IsA("GuiObject") or not bar:IsA("GuiObject") then
        shootingGui = nil
        shootingBar = nil
        return nil, nil
    end

    shootingGui = candidate
    shootingBar = bar

    meterScaleObject = shootingGui:FindFirstChild("VORMeterScale")
    if not meterScaleObject then
        meterScaleObject = create("UIScale", {
            Name = "VORMeterScale",
            Scale = basketballState.MeterScale,
        }, shootingGui)
    end
    meterScaleObject.Scale = basketballState.MeterScale

    releaseGuide = shootingGui:FindFirstChild("VORReleaseGuide")
    if not releaseGuide then
        releaseGuide = create("Frame", {
            Name = "VORReleaseGuide",
            Size = UDim2.new(1, 8, 0, 3),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 1 - basketballState.Calibration, 0),
            BackgroundColor3 = COLORS.toggleOnBright,
            BorderSizePixel = 0,
            ZIndex = math.max(shootingBar.ZIndex + 4, 12),
        }, shootingGui)
        addCorner(releaseGuide, 2)
        addStroke(releaseGuide, SNOW_WHITE, 1, 0.08)
    end
    updateReleaseGuide()
    return shootingGui, shootingBar
end

local function getCharacterRoot(player)
    local character = player and player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function isSameCourt(player)
    if not player or player == LocalPlayer then
        return false
    end
    local localCourt = LocalPlayer:GetAttribute("Court")
    local otherCourt = player:GetAttribute("Court")
    return localCourt == nil or otherCourt == nil or localCourt == otherCourt
end

local function isOpponent(player)
    if not isSameCourt(player) then
        return false
    end
    local localTeam = LocalPlayer:GetAttribute("Team")
    local otherTeam = player:GetAttribute("Team")
    return localTeam == nil or otherTeam == nil or localTeam ~= otherTeam
end

local function getNearestOpponent(maxDistance, mustHaveBall)
    local root = getCharacterRoot(LocalPlayer)
    if not root then
        return nil, math.huge
    end

    local nearest = nil
    local nearestDistance = tonumber(maxDistance) or math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if isOpponent(player) then
            local otherRoot = getCharacterRoot(player)
            local hasBall = player.Character and player.Character:FindFirstChild("Basketball") ~= nil
            if otherRoot and (not mustHaveBall or hasBall) then
                local distance = (root.Position - otherRoot.Position).Magnitude
                if distance <= nearestDistance then
                    nearest = player
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest, nearestDistance
end

local function getClosestCourtBall(looseOnly)
    local root = getCharacterRoot(LocalPlayer)
    if not root then
        return nil, math.huge
    end

    local nearest = nil
    local nearestDistance = math.huge
    for _, ball in ipairs(CollectionService:GetTagged("Ball")) do
        if ball:IsA("BasePart") and ball:IsDescendantOf(workspace) then
            local loose = ball.Parent == workspace
            if not looseOnly or loose then
                local distance = (root.Position - ball.Position).Magnitude
                if distance < nearestDistance then
                    nearest = ball
                    nearestDistance = distance
                end
            end
        end
    end
    return nearest, nearestDistance
end

local function getCurrentGoal()
    if not BasketballSharedUtil or not BasketballSharedUtil.Ball then
        return nil
    end
    local ok, goal = pcall(function()
        return BasketballSharedUtil.Ball:GetGoal(LocalPlayer)
    end)
    return ok and goal or nil
end

local function horizontalDistance(left, right)
    local delta = left - right
    return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

local function setGuardHeld(value)
    value = value == true
    if guardHeld == value then
        return
    end
    guardHeld = value
    sendBasketballKey(Enum.KeyCode.F, value)
end

local function destroyHighlight(highlight)
    if highlight and highlight.Parent then
        highlight:Destroy()
    end
end

local function updateCourtVision()
    if not basketballState.CourtVision then
        destroyHighlight(ballHighlight)
        destroyHighlight(opponentHighlight)
        ballHighlight = nil
        opponentHighlight = nil
        highlightedBall = nil
        highlightedOpponent = nil
        return
    end

    local ball = getClosestCourtBall(false)
    local opponent = getNearestOpponent(80, false)
    local opponentCharacter = opponent and opponent.Character

    if ball ~= highlightedBall then
        destroyHighlight(ballHighlight)
        ballHighlight = nil
        highlightedBall = ball
        if ball then
            ballHighlight = create("Highlight", {
                Name = "VORBasketballVision",
                Adornee = ball,
                FillColor = Color3.fromRGB(76, 224, 255),
                FillTransparency = 0.32,
                OutlineColor = SNOW_WHITE,
                OutlineTransparency = 0.02,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, ball)
        end
    end

    if opponentCharacter ~= highlightedOpponent then
        destroyHighlight(opponentHighlight)
        opponentHighlight = nil
        highlightedOpponent = opponentCharacter
        if opponentCharacter then
            opponentHighlight = create("Highlight", {
                Name = "VOROpponentVision",
                Adornee = opponentCharacter,
                FillColor = Color3.fromRGB(255, 92, 118),
                FillTransparency = 0.68,
                OutlineColor = Color3.fromRGB(255, 222, 230),
                OutlineTransparency = 0.06,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, opponentCharacter)
        end
    end
end

local function getBallHand()
    if not BasketballModule then
        return "Right"
    end
    local ok, _, values = pcall(function()
        local object, currentValues = BasketballModule:GetValues()
        return object, currentValues
    end)
    return ok and values and values.Hand or "Right"
end

local function runDribbleSequence(style)
    local handKey = getBallHand() == "Left" and Enum.KeyCode.Z or Enum.KeyCode.C
    local sequence
    if style == "Behind Back" then
        sequence = {handKey, Enum.KeyCode.X}
    elseif style == "Spin" then
        sequence = {handKey, handKey}
    elseif style == "Between Legs" then
        sequence = {Enum.KeyCode.X, Enum.KeyCode.X}
    elseif style == "Stepback" then
        sequence = {Enum.KeyCode.X}
    else
        local choices = {"Behind Back", "Spin", "Between Legs", "Stepback"}
        return runDribbleSequence(choices[math.random(1, #choices)])
    end

    task.spawn(function()
        for _, keyCode in ipairs(sequence) do
            pulseBasketballKey(keyCode, 0.035)
            task.wait(0.085)
        end
    end)
end

local function runBasketballAssists(now)
    if now - basketballState.LastAssistUpdate < 0.05 then
        return
    end
    basketballState.LastAssistUpdate = now

    local character = LocalPlayer.Character
    local root = getCharacterRoot(LocalPlayer)
    if not character or not root then
        setGuardHeld(false)
        return
    end

    local hasBall = character:FindFirstChild("Basketball") ~= nil
    local ballSearchDistance = math.max(
        basketballState.GuardDistance,
        basketballState.StealDistance,
        basketballState.RemoteStealRange
    )
    local ballOpponent, ballOpponentDistance = getNearestOpponent(ballSearchDistance, true)
    local nearestOpponent, nearestOpponentDistance = getNearestOpponent(80, false)
    local guardSuspended = now < (basketballState.GuardResumeAt or 0)
    local remoteStealFired = false

    if basketballState.RemoteStealAura and not hasBall and ballOpponent
        and ballOpponentDistance <= basketballState.RemoteStealRange
        and now - basketballState.LastRemoteSteal >= basketballState.RemoteStealInterval then
        basketballState.LastRemoteSteal = now
        remoteStealFired = true
        if stealRemote and stealRemote:IsA("RemoteEvent") then
            pcall(function()
                stealRemote:FireServer()
            end)
            exploitStatusLabel.Text = string.format(
                "Exploits: Steal Aura fired at %s from %.1f studs",
                ballOpponent.Name,
                ballOpponentDistance
            )
            exploitStatusLabel.TextColor3 = COLORS.success
        else
            exploitStatusLabel.Text = "Exploits: Steal remote was not found"
            exploitStatusLabel.TextColor3 = COLORS.warning
        end
    end

    if not remoteStealFired and basketballState.SmartSteal and not hasBall and ballOpponent
        and ballOpponentDistance <= basketballState.StealDistance
        and now - basketballState.LastSteal >= 4.15 then
        basketballState.LastSteal = now
        basketballState.GuardResumeAt = now + 0.95
        setGuardHeld(false)
        pulseBasketballKey(Enum.KeyCode.R, 0.05)
        defenseStatusLabel.Text = "Defense: Smart steal attempted on " .. ballOpponent.Name
        defenseStatusLabel.TextColor3 = COLORS.success
    elseif basketballState.AutoGuard and not hasBall and ballOpponent and not guardSuspended then
        setGuardHeld(true)
        defenseStatusLabel.Text = string.format("Defense: Guarding %s (%.1f studs)", ballOpponent.Name, ballOpponentDistance)
        defenseStatusLabel.TextColor3 = COLORS.success
    else
        setGuardHeld(false)
    end

    if basketballState.AutoRebound and not hasBall
        and now - basketballState.LastRebound >= 2.25
        and now - basketballState.LastBlock >= 1.10 then
        local looseBall, looseDistance = getClosestCourtBall(true)
        if looseBall and looseBall.Position.Y > 3 and looseDistance <= basketballState.ReboundDistance then
            basketballState.LastRebound = now
            basketballState.GuardResumeAt = now + 1
            setGuardHeld(false)
            pulseBasketballKey(Enum.KeyCode.Space, 0.05)
            defenseStatusLabel.Text = string.format("Defense: Rebound triggered (%.1f studs)", looseDistance)
            defenseStatusLabel.TextColor3 = COLORS.success
        end
    end

    if basketballState.LooseBallMagnet and not hasBall
        and now - basketballState.LastMagnet >= 0.30 then
        local looseBall, looseDistance = getClosestCourtBall(true)
        if looseBall and looseDistance > 3.5 and looseDistance <= basketballState.MagnetRange then
            basketballState.LastMagnet = now
            local targetPosition = looseBall.Position + Vector3.new(0, 2.65, 0)
            local flatLook = Vector3.new(looseBall.Position.X, targetPosition.Y, looseBall.Position.Z)
            root.CFrame = CFrame.lookAt(targetPosition, flatLook + root.CFrame.LookVector)
            root.AssemblyLinearVelocity = Vector3.zero
            exploitStatusLabel.Text = string.format("Exploits: Loose-ball magnet snapped %.1f studs", looseDistance)
            exploitStatusLabel.TextColor3 = COLORS.success
        end
    end

    if basketballState.GoalAimLock and hasBall then
        local goal = getCurrentGoal()
        if goal and goal:IsA("BasePart") then
            local lookPosition = Vector3.new(goal.Position.X, root.Position.Y, goal.Position.Z)
            if (lookPosition - root.Position).Magnitude > 0.1 then
                root.CFrame = CFrame.lookAt(root.Position, lookPosition)
            end
        end
    end

    if basketballState.AutoDunk and hasBall and now - basketballState.LastDunk >= 4.25 then
        local goal = getCurrentGoal()
        if goal and goal:IsA("BasePart") then
            local distance = horizontalDistance(root.Position, goal.Position)
            local dunkDistanceValue = ReplicatedStorage:FindFirstChild("DunkDistance")
            local dunkDistance = dunkDistanceValue and tonumber(dunkDistanceValue.Value) or 12.5
            if distance > 5 and distance <= dunkDistance and root.AssemblyLinearVelocity.Magnitude > 3 then
                basketballState.LastDunk = now
                pulseBasketballKey(Enum.KeyCode.Space, 0.05)
                scoringStatusLabel.Text = string.format("Scoring: Dunk assist triggered at %.1f studs", distance)
                scoringStatusLabel.TextColor3 = COLORS.success
            end
        end
    end

    if basketballState.AutoCombo and hasBall and nearestOpponent
        and nearestOpponentDistance <= basketballState.ComboDistance
        and now - basketballState.LastCombo >= basketballState.ComboInterval then
        local meter = resolveShotMeter()
        if not meter or not meter.Visible then
            basketballState.LastCombo = now
            runDribbleSequence(basketballState.ComboStyle)
            dribbleStatusLabel.Text = "Dribble: " .. basketballState.ComboStyle .. " used near " .. nearestOpponent.Name
            dribbleStatusLabel.TextColor3 = COLORS.success
        end
    end

    if now - basketballState.LastStatusUpdate < 0.06 then
        updateCourtVision()
    end
end

local autoGreenControl = AutoShotSection:AddToggle({
    Name = "Auto Green Jumpshots",
    Description = "Releases the active PC E key or mobile Shoot touch at the calibrated meter point",
    Default = false,
    Flag = "basketball_auto_green",
    Callback = function(value)
        basketballState.AutoGreen = value
        basketballState.ReleasedThisShot = false
        releaseStatusLabel.Text = value and "Release: Armed for the next shot" or "Release: Auto Green disabled"
        releaseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

AutoShotSection:AddSlider({
    Name = "Release Calibration",
    Min = 0.70,
    Max = 0.88,
    Step = 0.01,
    Default = 0.78,
    Flag = "basketball_release_calibration",
    Callback = function(value)
        basketballState.Calibration = value
        timingStatusLabel.Text = string.format(
            "Target: %.0f%% visual -> approximately 100%% server read",
            value * 100
        )
        updateReleaseGuide()
    end,
})

AutoShotSection:AddLabel("PC: hold E. Mobile: hold the game's Shoot button. VOR releases the active input at the calibrated point. Start at 0.78; adjust only if your connection lands early or late.")

AutoShotSection:AddButton({
    Name = "Test One Perfect Shot",
    Description = "Presses the PC E key or mobile Shoot button, then auto-releases the next detected meter cycle",
    Callback = function()
        playToggleClick(true)
        basketballState.ForceNextShot = true
        basketballState.ReleasedThisShot = false
        releaseStatusLabel.Text = "Release: Test shot armed"
        if not pressShootInput() then
            basketballState.ForceNextShot = false
            releaseStatusLabel.Text = "Release: This executor cannot press E or the mobile Shoot button"
            releaseStatusLabel.TextColor3 = COLORS.warning
            return
        end
        task.delay(1.25, function()
            if basketballState.ForceNextShot then
                basketballState.ForceNextShot = false
                releaseShootInput()
                if releaseStatusLabel.Parent then
                    releaseStatusLabel.Text = "Release: No valid shot meter appeared"
                    releaseStatusLabel.TextColor3 = COLORS.warning
                end
            end
        end)
    end,
})

MeterSection:AddToggle({
    Name = "Release Guide Line",
    Description = "Shows the calibrated trigger point directly on the game's shot meter",
    Default = true,
    Flag = "basketball_release_guide",
    Callback = function(value)
        basketballState.GuideEnabled = value
        resolveShotMeter()
        updateReleaseGuide()
    end,
})

MeterSection:AddSlider({
    Name = "Shot Meter Scale",
    Min = 0.75,
    Max = 1.50,
    Step = 0.05,
    Default = 1,
    Flag = "basketball_meter_scale",
    Callback = function(value)
        basketballState.MeterScale = value
        resolveShotMeter()
        if meterScaleObject and meterScaleObject.Parent then
            meterScaleObject.Scale = value
        end
    end,
})

MeterSection:AddButton({
    Name = "Rescan Shot Meter",
        Description = "Reconnects VOR Hub after the game's UI reloads",
    Callback = function()
        playToggleClick(true)
        shootingGui = nil
        shootingBar = nil
        releaseGuide = nil
        meterScaleObject = nil
        local found = resolveShotMeter() ~= nil
        meterStatusLabel.Text = found and "Meter: Connected" or "Meter: PlayerGui.Visual.Shooting not found"
        meterStatusLabel.TextColor3 = found and COLORS.success or COLORS.warning
    end,
})

local autoGuardControl = DefenseSection:AddToggle({
    Name = "Auto Guard Ball Handler",
    Description = "Holds the game's Guard action while the opposing ball handler is nearby",
    Default = false,
    Flag = "basketball_auto_guard",
    Callback = function(value)
        basketballState.AutoGuard = value
        if not value then
            setGuardHeld(false)
        end
        defenseStatusLabel.Text = value and "Defense: Auto Guard armed" or "Defense: Auto Guard disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DefenseSection:AddSlider({
    Name = "Guard Distance",
    Min = 10,
    Max = 25,
    Step = 1,
    Default = 22,
    Flag = "basketball_guard_distance",
    Callback = function(value)
        basketballState.GuardDistance = value
    end,
})

local smartStealControl = DefenseSection:AddToggle({
    Name = "Smart Steal",
    Description = "Drops Guard briefly and uses the normal steal action when the opponent is close",
    Default = false,
    Flag = "basketball_smart_steal",
    Callback = function(value)
        basketballState.SmartSteal = value
        defenseStatusLabel.Text = value and "Defense: Smart Steal armed" or "Defense: Smart Steal disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

local stealDistanceControl = DefenseSection:AddSlider({
    Name = "Steal Distance",
    Min = 4,
    Max = 40,
    Step = 0.5,
    Default = 14,
    Flag = "basketball_steal_distance",
    Callback = function(value)
        basketballState.StealDistance = value
    end,
})

local smartBlockControl = DefenseSection:AddToggle({
    Name = "Smart Block",
    Description = "Reacts to the opponent's real ShootMeterStart event and contests with Space",
    Default = false,
    Flag = "basketball_smart_block",
    Callback = function(value)
        basketballState.SmartBlock = value
        defenseStatusLabel.Text = value and "Defense: Smart Block listening for opponent shots" or "Defense: Smart Block disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DefenseSection:AddSlider({
    Name = "Block Reaction Delay",
    Min = 0,
    Max = 0.35,
    Step = 0.01,
    Default = 0.10,
    Flag = "basketball_block_reaction",
    Callback = function(value)
        basketballState.BlockReaction = value
    end,
})

DefenseSection:AddSlider({
    Name = "Block Distance",
    Min = 8,
    Max = 25,
    Step = 1,
    Default = 20,
    Flag = "basketball_block_distance",
    Callback = function(value)
        basketballState.BlockDistance = value
    end,
})

local autoReboundControl = DefenseSection:AddToggle({
    Name = "Auto Rebound",
    Description = "Uses the game's normal rebound jump when a loose ball rises nearby",
    Default = false,
    Flag = "basketball_auto_rebound",
    Callback = function(value)
        basketballState.AutoRebound = value
        defenseStatusLabel.Text = value and "Defense: Auto Rebound armed" or "Defense: Auto Rebound disabled"
        defenseStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DefenseSection:AddSlider({
    Name = "Rebound Distance",
    Min = 8,
    Max = 25,
    Step = 1,
    Default = 20,
    Flag = "basketball_rebound_distance",
    Callback = function(value)
        basketballState.ReboundDistance = value
    end,
})

local autoDunkControl = ScoringSection:AddToggle({
    Name = "Auto Dunk Assist",
    Description = "Triggers Space only inside the game's live dunk distance while running at the rim",
    Default = false,
    Flag = "basketball_auto_dunk",
    Callback = function(value)
        basketballState.AutoDunk = value
        scoringStatusLabel.Text = value and "Scoring: Auto Dunk armed" or "Scoring: Auto Dunk disabled"
        scoringStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

local autoComboControl = DribbleSection:AddToggle({
    Name = "Auto Dribble Combo",
    Description = "Runs the selected legal combo when a defender closes the gap",
    Default = false,
    Flag = "basketball_auto_dribble_combo",
    Callback = function(value)
        basketballState.AutoCombo = value
        dribbleStatusLabel.Text = value and "Dribble: Auto Combo armed" or "Dribble: Auto Combo disabled"
        dribbleStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

DribbleSection:AddDropdown({
    Name = "Dribble Combo Style",
    Options = {"Smart Mix", "Behind Back", "Spin", "Between Legs", "Stepback"},
    Default = "Smart Mix",
    Flag = "basketball_dribble_combo_style",
    Callback = function(value)
        basketballState.ComboStyle = value or "Smart Mix"
    end,
})

DribbleSection:AddSlider({
    Name = "Combo Trigger Distance",
    Min = 6,
    Max = 20,
    Step = 1,
    Default = 12,
    Flag = "basketball_combo_distance",
    Callback = function(value)
        basketballState.ComboDistance = value
    end,
})

DribbleSection:AddSlider({
    Name = "Combo Interval",
    Min = 1,
    Max = 5,
    Step = 0.25,
    Default = 2.25,
    Flag = "basketball_combo_interval",
    Callback = function(value)
        basketballState.ComboInterval = value
    end,
})

local courtVisionControl = PlayerUtilitySection:AddToggle({
    Name = "Court Vision ESP",
    Description = "Locally highlights the nearest ball and nearby opponent through visual clutter",
    Default = false,
    Flag = "basketball_court_vision",
    Callback = function(value)
        basketballState.CourtVision = value
        updateCourtVision()
    end,
})

local remoteStealControl = ExploitStealSection:AddToggle({
    Name = "Extended Remote Steal Aura",
    Description = "Fires the Steal remote directly and bypasses the client's four-second action cooldown",
    Default = false,
    Flag = "basketball_exploit_remote_steal",
    Callback = function(value)
        basketballState.RemoteStealAura = value
        exploitStatusLabel.Text = value and "Exploits: Extended Steal Aura armed" or "Exploits: Extended Steal Aura disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitStealSection:AddSlider({
    Name = "Remote Steal Range",
    Min = 10,
    Max = 75,
    Step = 1,
    Default = 32,
    Flag = "basketball_exploit_steal_range",
    Callback = function(value)
        basketballState.RemoteStealRange = value
    end,
})

ExploitStealSection:AddSlider({
    Name = "Remote Steal Interval",
    Min = 0.10,
    Max = 2,
    Step = 0.05,
    Default = 0.40,
    Flag = "basketball_exploit_steal_interval",
    Callback = function(value)
        basketballState.RemoteStealInterval = value
    end,
})

ExploitStealSection:AddButton({
    Name = "Test One Remote Steal",
    Description = "Sends one direct Steal request without enabling the repeating aura",
    Callback = function()
        playToggleClick(true)
        if stealRemote and stealRemote:IsA("RemoteEvent") then
            pcall(function()
                stealRemote:FireServer()
            end)
            exploitStatusLabel.Text = "Exploits: One remote Steal request sent"
            exploitStatusLabel.TextColor3 = COLORS.success
        else
            exploitStatusLabel.Text = "Exploits: Steal remote was not found"
            exploitStatusLabel.TextColor3 = COLORS.warning
        end
    end,
})

local remoteBlockControl = ExploitDefenseSection:AddToggle({
    Name = "Remote Block Aura",
    Description = "Sends Block directly when a nearby opponent starts charging a shot",
    Default = false,
    Flag = "basketball_exploit_remote_block",
    Callback = function(value)
        basketballState.RemoteBlockAura = value
        exploitStatusLabel.Text = value and "Exploits: Remote Block Aura listening" or "Exploits: Remote Block Aura disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitDefenseSection:AddSlider({
    Name = "Remote Block Range",
    Min = 10,
    Max = 75,
    Step = 1,
    Default = 45,
    Flag = "basketball_exploit_block_range",
    Callback = function(value)
        basketballState.RemoteBlockRange = value
    end,
})

local ballMagnetControl = ExploitMovementSection:AddToggle({
    Name = "Loose Ball Magnet",
    Description = "Snaps your character onto a nearby loose ball before normal rebound logic runs",
    Default = false,
    Flag = "basketball_exploit_ball_magnet",
    Callback = function(value)
        basketballState.LooseBallMagnet = value
        exploitStatusLabel.Text = value and "Exploits: Loose Ball Magnet armed" or "Exploits: Loose Ball Magnet disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitMovementSection:AddSlider({
    Name = "Ball Magnet Range",
    Min = 10,
    Max = 80,
    Step = 1,
    Default = 35,
    Flag = "basketball_exploit_magnet_range",
    Callback = function(value)
        basketballState.MagnetRange = value
    end,
})

local goalAimControl = ExploitMovementSection:AddToggle({
    Name = "Goal Aim Lock",
    Description = "Forces your character to face the current scoring goal while holding the ball",
    Default = false,
    Flag = "basketball_exploit_goal_aim",
    Callback = function(value)
        basketballState.GoalAimLock = value
        exploitStatusLabel.Text = value and "Exploits: Goal Aim Lock active" or "Exploits: Goal Aim Lock disabled"
        exploitStatusLabel.TextColor3 = value and COLORS.warning or COLORS.muted
    end,
})

ExploitStatusSection:AddButton({
    Name = "Disable Every Exploit",
    Description = "Turns off all direct-remote and movement advantage options",
    Callback = function()
        playToggleClick(false)
        remoteStealControl:Set(false)
        remoteBlockControl:Set(false)
        ballMagnetControl:Set(false)
        goalAimControl:Set(false)
        exploitStatusLabel.Text = "Exploits: All experimental options disabled"
        exploitStatusLabel.TextColor3 = COLORS.muted
    end,
})

if shootMeterStartEvent and shootMeterStartEvent:IsA("RemoteEvent") then
    track(shootMeterStartEvent.OnClientEvent:Connect(function(shooter)
        if not (basketballState.SmartBlock or basketballState.RemoteBlockAura)
            or typeof(shooter) ~= "Instance" or not shooter:IsA("Player")
            or not isOpponent(shooter) then
            return
        end

        local localRoot = getCharacterRoot(LocalPlayer)
        local shooterRoot = getCharacterRoot(shooter)
        local character = LocalPlayer.Character
        if not localRoot or not shooterRoot or not character or character:FindFirstChild("Basketball") then
            return
        end
        local shooterDistance = (localRoot.Position - shooterRoot.Position).Magnitude
        local allowedDistance = basketballState.RemoteBlockAura
            and basketballState.RemoteBlockRange
            or basketballState.BlockDistance
        if shooterDistance > allowedDistance then
            return
        end

        local requestedAt = os.clock()
        if basketballState.RemoteBlockAura then
            if requestedAt - basketballState.LastRemoteBlock < 0.30 then
                return
            end
            basketballState.LastRemoteBlock = requestedAt
            if blockRemote and blockRemote:IsA("RemoteEvent") then
                pcall(function()
                    blockRemote:FireServer()
                end)
                exploitStatusLabel.Text = string.format(
                    "Exploits: Remote Block fired at %s from %.1f studs",
                    shooter.Name,
                    shooterDistance
                )
                exploitStatusLabel.TextColor3 = COLORS.success
            else
                exploitStatusLabel.Text = "Exploits: Block remote was not found"
                exploitStatusLabel.TextColor3 = COLORS.warning
            end
            return
        end

        if requestedAt - basketballState.LastBlock < 3.05 then
            return
        end
        basketballState.LastBlock = requestedAt
        basketballState.GuardResumeAt = requestedAt + 1.20
        setGuardHeld(false)
        task.delay(basketballState.BlockReaction, function()
            if basketballState.SmartBlock and gui.Parent then
                pulseBasketballKey(Enum.KeyCode.Space, 0.055)
                if defenseStatusLabel.Parent then
                    defenseStatusLabel.Text = "Defense: Contested " .. shooter.Name .. "'s shot"
                    defenseStatusLabel.TextColor3 = COLORS.success
                end
            end
        end)
    end))
end

PlayerUtilitySection:AddButton({
    Name = "Enable Competitive 1v1 Preset",
    Description = "Turns on Auto Green, Guard, Steal, Block, Rebound, Dunk, Combo, and Court Vision",
    Callback = function()
        playToggleClick(true)
        autoGreenControl:Set(true)
        autoGuardControl:Set(true)
        smartStealControl:Set(true)
        stealDistanceControl:Set(14)
        smartBlockControl:Set(true)
        autoReboundControl:Set(true)
        autoDunkControl:Set(true)
        autoComboControl:Set(true)
        courtVisionControl:Set(true)
        defenseStatusLabel.Text = "Defense: Competitive 1v1 preset active"
        scoringStatusLabel.Text = "Scoring: Competitive 1v1 preset active"
        dribbleStatusLabel.Text = "Dribble: Competitive 1v1 preset active"
        defenseStatusLabel.TextColor3 = COLORS.success
        scoringStatusLabel.TextColor3 = COLORS.success
        dribbleStatusLabel.TextColor3 = COLORS.success
        Window:Notify("Basketball", "Competitive 1v1 preset enabled", 3)
    end,
})

PlayerUtilitySection:AddButton({
    Name = "Disable All 1v1 Assists",
    Description = "Stops every automatic basketball action while keeping visual/camera settings",
    Callback = function()
        playToggleClick(false)
        autoGuardControl:Set(false)
        smartStealControl:Set(false)
        smartBlockControl:Set(false)
        autoReboundControl:Set(false)
        autoDunkControl:Set(false)
        autoComboControl:Set(false)
        setGuardHeld(false)
        defenseStatusLabel.Text = "Defense: All assists disabled"
        scoringStatusLabel.Text = "Scoring: All assists disabled"
        dribbleStatusLabel.Text = "Dribble: All assists disabled"
        defenseStatusLabel.TextColor3 = COLORS.muted
        scoringStatusLabel.TextColor3 = COLORS.muted
        dribbleStatusLabel.TextColor3 = COLORS.muted
    end,
})

PlayerUtilitySection:AddToggle({
    Name = "Anti-AFK / Anti-Idle",
    Description = "Responds whenever Roblox sends an inactivity signal",
    Default = false,
    Flag = "basketball_anti_afk",
    Callback = function(value)
        basketballState.AntiAfk = value
        antiAfkStatusLabel.Text = value and "Anti-AFK: Armed and waiting for an idle signal" or "Anti-AFK: Disabled"
        antiAfkStatusLabel.TextColor3 = value and COLORS.success or COLORS.muted
    end,
})

local virtualUser = game:GetService("VirtualUser")
track(LocalPlayer.Idled:Connect(function()
    if not basketballState.AntiAfk then
        return
    end
    pcall(function()
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new(0, 0))
    end)
    antiAfkStatusLabel.Text = "Anti-AFK: Idle signal handled"
    antiAfkStatusLabel.TextColor3 = COLORS.success
end))

PlayerUtilitySection:AddButton({
    Name = "Test Anti-AFK Pulse",
    Description = "Runs one harmless idle-prevention pulse",
    Callback = function()
        playToggleClick(true)
        pcall(function()
            virtualUser:CaptureController()
            virtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        antiAfkStatusLabel.Text = "Anti-AFK: Test pulse completed"
        antiAfkStatusLabel.TextColor3 = COLORS.success
    end,
})

local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local originalZoom = LocalPlayer.CameraMaxZoomDistance
local cameraFov = originalFov

local function applyCameraSettings()
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = cameraFov
    end
end

CameraSection:AddSlider({
    Name = "Camera FOV",
    Min = 50,
    Max = 100,
    Step = 1,
    Default = originalFov,
    Flag = "basketball_camera_fov",
    Callback = function(value)
        cameraFov = value
        applyCameraSettings()
    end,
})

CameraSection:AddSlider({
    Name = "Maximum Camera Zoom",
    Min = 8,
    Max = 40,
    Step = 1,
    Default = math.clamp(originalZoom, 8, 40),
    Flag = "basketball_camera_zoom",
    Callback = function(value)
        LocalPlayer.CameraMaxZoomDistance = value
    end,
})

track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    task.defer(applyCameraSettings)
end))

PlayerStatusSection:AddButton({
    Name = "Refresh Player Status",
    Description = "Refreshes court, ball, and meter information now",
    Callback = function()
        playToggleClick(true)
        basketballState.LastStatusUpdate = 0
    end,
})

track(RunService.RenderStepped:Connect(function()
    local meter, bar = resolveShotMeter()
    local visible = meter and meter.Visible == true
    local value = bar and tonumber(bar.Size.Y.Scale) or 0
    local startedNewShot = visible and not basketballState.WasMeterVisible
    local rising = visible and value > basketballState.LastMeterValue + 0.0005

    if startedNewShot or value <= 0.02 or (visible and value + 0.08 < basketballState.LastMeterValue) then
        basketballState.ReleasedThisShot = false
        if startedNewShot and UserInputService.TouchEnabled then
            captureMobileShootTouch()
        end
    end

    if visible and rising and value >= basketballState.Calibration
        and not basketballState.ReleasedThisShot
        and (basketballState.AutoGreen or basketballState.ForceNextShot) then
        basketballState.ReleasedThisShot = true
        basketballState.ForceNextShot = false
        local released, releaseMethod = releaseShootInput()
        if released then
            releaseStatusLabel.Text = string.format(
                "Release: %s fired at %.0f%% visual for the delayed full-power read",
                releaseMethod or "Input",
                value * 100
            )
            releaseStatusLabel.TextColor3 = COLORS.success
        else
            releaseStatusLabel.Text = "Release: PC E and mobile Shoot release are unsupported by this executor"
            releaseStatusLabel.TextColor3 = COLORS.warning
        end
    end

    basketballState.LastMeterValue = value
    basketballState.WasMeterVisible = visible

    local now = os.clock()
    runBasketballAssists(now)
    if now - basketballState.LastStatusUpdate >= 0.20 then
        basketballState.LastStatusUpdate = now
        meterStatusLabel.Text = visible
            and string.format("Meter: %.0f%% %s", value * 100, rising and "(charging)" or "")
            or (meter and "Meter: Ready" or "Meter: Waiting for PlayerGui.Visual.Shooting")
        meterStatusLabel.TextColor3 = visible and COLORS.success or COLORS.muted

        local character = LocalPlayer.Character
        local hasBall = character and character:FindFirstChild("Basketball") ~= nil
        local court = LocalPlayer:GetAttribute("Court")
        playerCourtLabel.Text = "Court: " .. (court == nil and "Not assigned" or tostring(court))
        playerBallLabel.Text = "Basketball: " .. (hasBall and "Equipped" or "Not held")
        playerBallLabel.TextColor3 = hasBall and COLORS.success or COLORS.muted
        playerModeLabel.Text = "Place: " .. tostring(game.PlaceId) .. " | Universe: " .. tostring(game.GameId)
    end
end))

resolveShotMeter()

track(gui.Destroying:Connect(function()
    basketballState.AutoGreen = false
    basketballState.ForceNextShot = false
    basketballState.AutoGuard = false
    basketballState.SmartSteal = false
    basketballState.SmartBlock = false
    basketballState.AutoRebound = false
    basketballState.AutoDunk = false
    basketballState.AutoCombo = false
    basketballState.CourtVision = false
    basketballState.RemoteStealAura = false
    basketballState.RemoteBlockAura = false
    basketballState.LooseBallMagnet = false
    basketballState.GoalAimLock = false
    setGuardHeld(false)
    releaseShootInput()
    for keyCode in pairs(fallbackVirtualKeys) do
        sendBasketballKey(keyCode, false)
    end
    destroyHighlight(ballHighlight)
    destroyHighlight(opponentHighlight)
    if releaseGuide and releaseGuide.Parent then
        releaseGuide:Destroy()
    end
    if meterScaleObject and meterScaleObject.Parent then
        meterScaleObject:Destroy()
    end
    if workspace.CurrentCamera then
        workspace.CurrentCamera.FieldOfView = originalFov
    end
    LocalPlayer.CameraMaxZoomDistance = originalZoom
end))

gui:SetAttribute("BasketballShotMeterPath", "PlayerGui.Visual.Shooting")
gui:SetAttribute("BasketballAutoGreenPlatforms", "PC E + Mobile Shoot Touch")
gui:SetAttribute("BasketballReleaseCalibration", basketballState.Calibration)
gui:SetAttribute("BasketballShootingDecal", CATEGORY_DECALS.Shooting)
gui:SetAttribute("BasketballPlayerDecal", CATEGORY_DECALS.Player)
gui:SetAttribute("BasketballDribbleDecal", CATEGORY_DECALS.Dribble)
gui:SetAttribute("BasketballExploitsDecal", CATEGORY_DECALS.Exploits)
end

local function buildAnimeExpeditionsFeatures()
    local loaded, moduleOrError = pcall(loadVORGameModule, "anime_expeditions.lua")
    if not loaded then
        local HomePage = Window:AddPage("Home")
        local errorSection = HomePage:AddSection("Anime Expeditions", "Left")
        errorSection:AddLabel("The game module could not be loaded.")
        errorSection:AddLabel(tostring(moduleOrError))
        Window:Notify("VOR Hub", "Anime Expeditions module failed to load", 5)
        return
    end

    local built, buildError = xpcall(function()
        moduleOrError({
            Window = Window,
            CreateCategoryHomePage = createCategoryHomePage,
            CategoryDecals = CATEGORY_DECALS,
            Colors = COLORS,
            Track = track,
            Gui = gui,
        })
    end, debug.traceback)
    if not built then
        warn("[VOR Hub] Anime Expeditions controls failed: " .. tostring(buildError))
        pcall(function()
            gui:SetAttribute("AnimeExpeditionsBuildError", tostring(buildError))
        end)
        Window:Notify("VOR Hub", "Anime Expeditions controls failed: " .. tostring(buildError), 7)
    end
end

local function buildBloxFruitsDungeonFeatures()
    local loaded, moduleOrError = pcall(loadVORGameModule, "blox_fruits_dungeons.lua")
    if not loaded then
        local DungeonPage = Window:AddPage("Dungeons")
        Window:AddPage("Player")
        local errorSection = DungeonPage:AddSection("Dungeon Module", "Left")
        errorSection:AddLabel("The Blox Fruits dungeon module could not be loaded.")
        errorSection:AddLabel(tostring(moduleOrError))
        Window:Notify("VOR Hub", "Dungeon module failed to load", 5)
        return
    end

    local built, buildError = xpcall(function()
        moduleOrError({
            Window = Window,
            Colors = COLORS,
            Track = track,
            Gui = gui,
        })
    end, debug.traceback)
    if not built then
        warn("[VOR Hub] Blox Fruits dungeon controls failed: " .. tostring(buildError))
        pcall(function()
            gui:SetAttribute("BloxDungeonBuildError", tostring(buildError))
        end)
        Window:Notify("VOR Hub", "Dungeon controls failed: " .. tostring(buildError), 7)
    end
end

function Window:BuildBloxFruitsFeatures()
    local built, buildError = xpcall(function()
        local Players = game:GetService("Players")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")
        local TweenService = game:GetService("TweenService")
        local TeleportService = game:GetService("TeleportService")
        local VirtualUser = game:GetService("VirtualUser")
        local Lighting = game:GetService("Lighting")
        local HttpService = game:GetService("HttpService")
        local CollectionService = game:GetService("CollectionService")
        local LocalPlayer = Players.LocalPlayer

        local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage({TextOnly = true})
        local FarmingPage = addHomeCategory("Farming", 1)
        local CombatPage = addHomeCategory("Combat", 2)
        local MasteryPage = addHomeCategory("Mastery", 3)
        local ShopPage = addHomeCategory("Shop", 4)
        local SeaPage = addHomeCategory("Sea & Raids", 5)
        local PlayerPage = addHomeCategory("Player", 6)
        selectHomeCategory("Farming")

        local LevelSection = FarmingPage:AddSection("Auto Level", "Left")
        local FarmSettingsSection = FarmingPage:AddSection("Farm Settings", "Left")
        local WorldFarmSection = FarmingPage:AddSection("World Farming", "Right")
        local FarmStatusSection = FarmingPage:AddSection("Live Farm Status", "Right")

        local ExploitSection = CombatPage:AddSection("Exploit Options", "Left")
        local AttackSection = CombatPage:AddSection("Attack Controller", "Right")
        local BossSection = CombatPage:AddSection("Boss Farming", "Right")

        local StatsSection = MasteryPage:AddSection("Auto Stats", "Left")
        local FightingStyleSection = MasteryPage:AddSection("Fighting Styles", "Right")
        local FruitSection = ShopPage:AddSection("Fruit Utilities", "Left")
        local TravelSection = ShopPage:AddSection("Travel", "Right")

        local RaidSection = SeaPage:AddSection("Dungeon / Raid Automation", "Left")
        local SeaStatusSection = SeaPage:AddSection("Sea & Event Status", "Right")

        local PlayerStateSection = PlayerPage:AddSection("Player State", "Left")
        local VisualSection = PlayerPage:AddSection("Visuals", "Right")
        local SessionSection = PlayerPage:AddSection("Session", "Right")

        local function safeRequire(instance)
            if not instance then
                return nil
            end
            local ok, result = pcall(require, instance)
            return ok and result or nil
        end

        local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local CommF = Remotes and Remotes:FindFirstChild("CommF_")
        local CommE = Remotes and Remotes:FindFirstChild("CommE")
        local Redeem = Remotes and Remotes:FindFirstChild("Redeem")
        local Net = ReplicatedStorage:FindFirstChild("Modules")
        Net = Net and Net:FindFirstChild("Net")
        local ClaimBerry = Net and (Net:FindFirstChild("ClaimBerry", true) or Net:FindFirstChild("RF/ClaimBerry"))
        local Quests = safeRequire(ReplicatedStorage:FindFirstChild("Quests")) or {}
        local Guide = safeRequire(ReplicatedStorage:FindFirstChild("GuideModule"))
        local CombatUtil = safeRequire(ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("CombatUtil"))
        local FruitMouse = safeRequire(ReplicatedStorage:FindFirstChild("Mouse"))
        -- Calling Net:RemoteEvent from the executor's UI-building thread drops
        -- its CoreGui capability in current Blox Fruits, so the next control
        -- fails while parenting its Instance. RegisterAttack is non-virtual;
        -- use its already-replicated event directly and leave RegisterHit on
        -- CombatUtil's initialized internal sender.
        local RegisterAttackEvent = Net and Net:FindFirstChild("RE/RegisterAttack")
        local AURA_KILL_DEFAULT_RANGE = 10
        local AURA_KILL_MAX_RANGE = 70
        local AURA_KILL_HIT_DELAY = 0.13
        local AURA_KILL_NATIVE_COOLDOWN_SCALE = 0.8
        local NATIVE_FRUIT_M1_CADENCE = 0.32
        local NATIVE_FRUIT_MAX_RANGE = 25
        local DoubleAttackEngine = {
            HitRange = 38,
            SwordTargetLimit = 12,
            FruitTargetLimit = 3,
            FruitCadence = 0.055,
        }
        local DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION = 0.28
        local NATIVE_FRUIT_SETTLE_TIME = 0.24
        local MULTI_GRAB_LIMIT = 3
        local MULTI_GRAB_RANGE = 600
        local MULTI_ATTACK_TARGET_LIMIT = 2

        local state = {
            Alive = true,
            Status = "Native Blox Fruits module ready",
            LastError = nil,
            AutoFarmLevel = false,
            SelectedLevelQuest = "Best for My Level",
            CurrentSeaName = "Detecting",
            CurrentSeaQuestCount = 0,
            CurrentSeaMinimumLevel = 0,
            CurrentSeaMaximumLevel = 0,
            AutoChest = false,
            AutoBerry = false,
            LastBerryClaim = 0,
            BerriesClaimed = 0,
            AutoBoss = false,
            SelectedBoss = "None",
            AutoRaid = false,
            AutoStartRaid = false,
            AutoBuyRaidChip = false,
            AutoAwaken = false,
            RaidMultiGrab = false,
            RaidGathered = 0,
            RaidVoidKill = false,
            RaidVoidActive = false,
            RaidVoidMoved = 0,
            RaidVoidStaged = 0,
            RaidVoidKillCount = 0,
            RaidVoidTargets = setmetatable({}, {__mode = "k"}),
            RaidVoidOriginalCFrames = setmetatable({}, {__mode = "k"}),
            LastRaidVoidStep = 0,
            RaidSafeHeight = 35,
            RaidEnteredAt = 0,
            RaidEntryGrace = 8,
            RaidHasEntered = false,
            RaidLastInactiveAt = os.clock(),
            RaidCastleStart = CFrame.new(-5064, 314, -2938),
            SelectedRaid = "Flame",
            RaidIslandIndex = 0,
            RaidIslandName = nil,
            RaidTargetName = nil,
            SeaEvent = {
                Enabled = false,
                AutoSail = false,
                AutoKill = false,
                AutoStopSail = false,
                SelectedEvents = {
                    ["Piranha"] = true,
                    ["Shark"] = true,
                    ["Terror Shark"] = true,
                    ["Fish Crew Member"] = true,
                    ["Enemy Boat"] = true,
                    ["Sea Beast"] = true,
                },
                StopConditions = {},
                StopMatch = nil,
                LastStopScan = 0,
                SelectedBoat = "Guardian",
                BoatTweenSpeed = 295,
                BoatFloatHeight = 0,
                CombatHeight = 24,
                SpamAllSkills = true,
                ResetBrokenBoat = true,
                Boat = nil,
                BoatBaseY = nil,
                Target = nil,
                TargetKind = nil,
                Heading = nil,
                NextHeadingAt = 0,
                LastPurchase = 0,
                LastSeat = 0,
                LastSkill = 0,
                ToolIndex = 0,
                SkillIndex = 0,
                EffectiveSpeed = 295,
                SafeSpeed = 80,
                RejectedSpeed = nil,
                StableSince = 0,
                PauseUntil = 0,
                LastCommandedPosition = nil,
                Rubberbacks = 0,
                BoatCollisions = setmetatable({}, {__mode = "k"}),
                SafetyPart = nil,
                Phase = "Off",
                DangerLevel = 0,
                DangerDistance = 0,
                EventsCompleted = 0,
                LastError = nil,
            },
            AuraKill = false,
            AuraRange = AURA_KILL_DEFAULT_RANGE,
            FastAttack = false,
            AttackInterval = 0,
            LastAttack = 0,
            LastAuraScan = 0,
            AuraTargetCursor = 0,
            AuraHits = 0,
            AuraRequests = 0,
            AuraSwordRequests = 0,
            AuraFruitRequests = 0,
            AuraTargetCount = 0,
            AuraMultiTargetCount = 0,
            AuraAttackPending = false,
            AuraCombo = 0,
            AuraCombos = {},
            NativeFruitCombos = {},
            AuraStage = "idle",
            AuraPendingError = nil,
            AuraLastRequestAt = nil,
            AuraLastHitAt = nil,
            AuraWeaponName = nil,
            AuraWeaponType = nil,
            AuraAttackMode = nil,
            AuraFruitBusy = false,
            FruitDispatchPending = false,
            LastDoubleFruitAttack = 0,
            AuraFruitInRange = nil,
            AuraFruitLastDistance = nil,
            FruitM1ReadyAt = 0,
            DoubleAttack = false,
            FruitM1CooldownReduction = DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
            OriginalFruitTapCooldown = nil,
            MobAuraTp = false,
            MobAuraHeight = 20,
            MobAuraSearchRange = 500,
            MobAuraOrbit = false,
            MobAuraOrbitRadius = 8,
            MobAuraOrbitSpeed = 110,
            MobAuraOrbitStartedAt = os.clock(),
            MobAuraOrbitStartAngle = math.random() * math.pi * 2,
            MobAuraOrbitDirection = math.random(0, 1) == 0 and -1 or 1,
            MobAuraRandomSquare = false,
            MobAuraSquareSize = 8,
            MobAuraSquareInterval = 0.18,
            MobAuraSquareOffset = Vector3.zero,
            MobAuraSquareCorner = 0,
            MobAuraLastSquareStep = 0,
            MobAuraTarget = nil,
            MobAuraTargetName = nil,
            MobAuraDistance = nil,
            MobAuraPreTeleportDistance = nil,
            MobAuraAnchorTarget = nil,
            MobAuraStableAnchor = nil,
            SelectedMobFarm = false,
            SelectedMobName = "None",
            SelectedMobSearchRange = 30000,
            SelectedMobWaitingAtSpawn = false,
            RegisterHitClosure = nil,
            LastRegisterHitResolve = -math.huge,
            WeaponType = "Sword",
            AutoBuso = true,
            LastBuso = 0,
            AutoObservation = false,
            LastObservation = 0,
            GatherEnemies = false,
            GatherRange = MULTI_GRAB_RANGE,
            GatherDistance = 8,
            GatherQuestOnly = true,
            GatherMode = "Selected / Current Mob",
            GatherSelectedMob = "Current Farm Target",
            GatherLimit = MULTI_GRAB_LIMIT,
            Gathered = 0,
            GatherSingleFallbackEnemy = nil,
            GatherOriginalCFrames = setmetatable({}, {__mode = "k"}),
            AutoMagnet = false,
            MagnetRange = 300,
            TweenSpeed = 300,
            LastPositionJitterAt = 0,
            PositionJitterCorner = 0,
            PositionTarget = nil,
            PositionBasis = nil,
            PositionLockVertical = false,
            PositionAnchorY = nil,
            PositionJitter = Vector3.zero,
            ActiveFarmTarget = nil,
            ActiveFarmVerticalLock = false,
            ActiveFarmHeightOverride = nil,
            AntiRagdollApplied = false,
            AntiRagdollHumanoid = nil,
            SafeMode = false,
            SafeHealthPercent = 30,
            CurrentEnemyName = nil,
            CurrentQuestName = nil,
            MoveTween = nil,
            MoveGoal = nil,
            MoveToken = 0,
            MoveRoot = nil,
            MoveRootWasAnchored = false,
            MoveHumanoid = nil,
            MoveAutoRotate = nil,
            MovePlatformStand = nil,
            MoveVelocityGuard = nil,
            FarmHoldY = nil,
            Traveling = false,
            LastQuestRequest = 0,
            LastChestScan = 0,
            LastGatherScan = 0,
            LastStat = 0,
            AutoStats = false,
            StatBatch = 1,
            StatIndex = 0,
            Stats = {
                Melee = false,
                Defense = false,
                Sword = false,
                Gun = false,
                ["Demon Fruit"] = false,
            },
            AutoGacha = false,
            LastGacha = 0,
            GachaInterval = 30,
            GachaBusy = false,
            GachaRolls = 0,
            GachaStatus = "Ready anywhere",
            AutoStoreFruit = false,
            LastStore = 0,
            InventoryBusy = false,
            FruitsStored = 0,
            StoreStatus = "Waiting for a physical fruit",
            SelectedLocation = "None",
            SelectedNPC = "None",
            Noclip = false,
            InfiniteEnergy = false,
            WalkOnWater = true,
            AntiAfk = true,
            EnemyESP = false,
            PlayerESP = false,
            FpsBoost = false,
            LastGatherLabelText = nil,
            EnemyHighlights = setmetatable({}, {__mode = "k"}),
            PlayerHighlights = setmetatable({}, {__mode = "k"}),
            PlayerEspObjects = {},
            PlayerEspLastTextUpdate = 0,
            OriginalCollision = setmetatable({}, {__mode = "k"}),
            GraphicsBackup = setmetatable({}, {__mode = "k"}),
            WaterPlatform = nil,
        }

        local statusLabel = FarmStatusSection:AddLabel("Status: Initializing...")
        local questLabel = FarmStatusSection:AddLabel("Quest: Reading live quest data...")
        local targetLabel = FarmStatusSection:AddLabel("Target: None")
        local berryLabel = FarmStatusSection:AddLabel("Berries: Ready")
        local gatherLabel = ExploitSection:AddLabel("Gathered enemies: 0")
        ExploitSection:AddLabel("Target filter: active quest, boss, or raid target only")
        local raidLabel = SeaStatusSection:AddLabel("Raid: Idle")
        local seaLabel = SeaStatusSection:AddLabel("Sea: Detecting...")
        local playerLabel = PlayerStateSection:AddLabel("Player: Reading...")
        local auraLabel = AttackSection:AddLabel("Aura Kill: Off | Range: 10 studs")
        local mobAuraLabel = AttackSection:AddLabel("Mob Aura TP: Off | Distance: --")
        local selectedMobFarmLabel = AttackSection:AddLabel("Selected Mob Farm: Off | Enemy: None")
        local busoLabel = AttackSection:AddLabel("Buso: Detecting...")
        local observationLabel = AttackSection:AddLabel("Observation: Reading live state...")
        local fruitGachaLabel = FruitSection:AddLabel("Fruit Gacha: Ready anywhere")
        local fruitStoreLabel = FruitSection:AddLabel("Fruit Storage: Waiting for a physical fruit")

        local function setStatus(message, success)
            state.Status = tostring(message)
            statusLabel.Text = "Status: " .. state.Status
            statusLabel.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
        end

        local function setError(message)
            state.LastError = tostring(message)
            setStatus(state.LastError, false)
        end

        local function character()
            local value = LocalPlayer.Character
            if not value or not value.Parent then
                return nil
            end
            return value
        end

        local function rootPart()
            local value = character()
            return value and value:FindFirstChild("HumanoidRootPart") or nil
        end

        local function humanoid()
            local value = character()
            return value and value:FindFirstChildOfClass("Humanoid") or nil
        end

        local function invoke(command, ...)
            if not CommF then
                return false, "CommF_ is unavailable"
            end
            local arguments = table.pack(...)
            local ok, result = pcall(function()
                return CommF:InvokeServer(command, table.unpack(arguments, 1, arguments.n))
            end)
            if not ok then
                state.LastError = tostring(result)
                return false, result
            end
            return true, result
        end

        local function busoActive()
            local char = character()
            if not char then
                return false
            end
            local enabledAttribute = char:GetAttribute("BusoEnabled")
            if enabledAttribute ~= nil then
                return enabledAttribute == true
            end
            -- Aura is the always-present ability LocalScript and the Buso tag
            -- means the ability is owned; neither proves it is switched on.
            return char:FindFirstChild("HasBuso") ~= nil
        end

        local function refreshBusoStatus()
            local active = busoActive()
            gui:SetAttribute("BloxBusoActive", active)
            if not state.AutoBuso then
                busoLabel.Text = active and "Buso: Active | Auto: Off" or "Buso: Off | Auto: Off"
                busoLabel.TextColor3 = active and COLORS.success or COLORS.muted
            elseif active then
                busoLabel.Text = "Buso: Active | Auto: On"
                busoLabel.TextColor3 = COLORS.success
            else
                busoLabel.Text = "Buso: Activating..."
                busoLabel.TextColor3 = COLORS.muted
            end
            return active
        end

        local function sendBusoInput()
            local okService, inputManager = pcall(function()
                return game:GetService("VirtualInputManager")
            end)
            if okService and inputManager then
                local ok, message = pcall(function()
                    inputManager:SendKeyEvent(true, Enum.KeyCode.J, false, game)
                    inputManager:SendKeyEvent(false, Enum.KeyCode.J, false, game)
                end)
                if ok then
                    return true, "Virtual J"
                end
                state.LastError = tostring(message)
            end
            if type(keypress) == "function" and type(keyrelease) == "function" then
                local ok, message = pcall(function()
                    keypress(0x4A)
                    keyrelease(0x4A)
                end)
                if ok then
                    return true, "Executor J"
                end
                state.LastError = tostring(message)
            end
            -- Older Blox Fruits builds used CommF_ for Buso. Keep it only as
            -- a fallback; the current Aura Ability is driven by the J input.
            local ok, message = invoke("Buso")
            return ok, ok and "Legacy CommF" or message
        end

        local function ensureBuso(force)
            if refreshBusoStatus() then
                return true
            end
            if not state.AutoBuso and not force and not state.AuraKill then
                return false
            end
            local now = os.clock()
            if now - state.LastBuso < 1.25 then
                return false
            end
            state.LastBuso = now
            gui:SetAttribute("BloxLastBusoAttemptAt", now)
            local ok, message = sendBusoInput()
            gui:SetAttribute("BloxLastBusoRequestSucceeded", ok)
            gui:SetAttribute("BloxLastBusoInputMethod", ok and tostring(message) or "Failed")
            if not ok then
                busoLabel.Text = "Buso: Activation failed"
                busoLabel.TextColor3 = COLORS.error
                setError("Auto Buso failed: " .. tostring(message))
                return false
            end
            -- BusoEnabled and its visuals replicate asynchronously after J.
            task.delay(0.25, refreshBusoStatus)
            busoLabel.Text = "Buso: Activation requested"
            busoLabel.TextColor3 = COLORS.muted
            return true
        end

        local function normalizeEnemyName(value)
            local name = tostring(value or "")
            name = name:gsub("%s*%[Lv[^%]]*%]", "")
            name = name:gsub("%s*%[Boss%]", "")
            name = name:gsub("%s+$", "")
            return name
        end

        local function modelRoot(model)
            if not model or not model.Parent then
                return nil
            end
            return model.PrimaryPart
                or model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChildWhichIsA("BasePart")
        end

        local function modelAlive(model)
            local targetHumanoid = model and model:FindFirstChildOfClass("Humanoid")
            return targetHumanoid ~= nil and targetHumanoid.Health > 0
        end

        local function enemyMatches(model, targetName)
            return string.lower(normalizeEnemyName(model and model.Name)) == string.lower(normalizeEnemyName(targetName))
        end

        local function nearestEnemy(targetName, anyEnemy)
            local root = rootPart()
            local enemies = workspace:FindFirstChild("Enemies")
            if not root or not enemies then
                return nil
            end
            local best = nil
            local bestDistance = math.huge
            for _, enemy in ipairs(enemies:GetChildren()) do
                local enemyRoot = modelRoot(enemy)
                if enemyRoot and modelAlive(enemy) and (anyEnemy or enemyMatches(enemy, targetName)) then
                    local distance = (enemyRoot.Position - root.Position).Magnitude
                    if distance < bestDistance then
                        best = enemy
                        bestDistance = distance
                    end
                end
            end
            return best, bestDistance
        end

        local function nearestEnemySpawn(enemyName)
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            if not spawns then
                return nil
            end
            local root = rootPart()
            local best = nil
            local bestDistance = math.huge
            for _, descendant in ipairs(spawns:GetDescendants()) do
                if descendant:IsA("BasePart") and enemyMatches(descendant, enemyName) then
                    local distance = root and (descendant.Position - root.Position).Magnitude or 0
                    if distance < bestDistance then
                        best = descendant
                        bestDistance = distance
                    end
                end
            end
            return best, bestDistance
        end

        local function mobFarmOptions()
            local options = {"None"}
            local seen = {None = true}
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            if spawns then
                for _, descendant in ipairs(spawns:GetDescendants()) do
                    if descendant:IsA("BasePart") then
                        local name = normalizeEnemyName(descendant.Name)
                        if name ~= "" and not seen[name] then
                            seen[name] = true
                            table.insert(options, name)
                        end
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    local name = normalizeEnemyName(enemy.Name)
                    if name ~= "" and not seen[name] then
                        seen[name] = true
                        table.insert(options, name)
                    end
                end
            end
            table.sort(options, function(left, right)
                if left == "None" then
                    return true
                end
                if right == "None" then
                    return false
                end
                return string.lower(left) < string.lower(right)
            end)
            return options
        end

        local CURRENT_GATHER_TARGET = "Current Farm Target"

        local function gatherMobOptions()
            local options = {CURRENT_GATHER_TARGET}
            for _, name in ipairs(mobFarmOptions()) do
                if name ~= "None" then
                    table.insert(options, name)
                end
            end
            return options
        end

        local function selectedGatherEnemyName()
            local selected = tostring(state.GatherSelectedMob or CURRENT_GATHER_TARGET)
            if selected ~= CURRENT_GATHER_TARGET and selected ~= "None" then
                return selected
            end
            if state.SelectedMobFarm and state.SelectedMobName ~= "None" then
                return state.SelectedMobName
            end
            return state.CurrentEnemyName
        end

        local function movementStillNeedsNoclip()
            return state.Noclip or state.AutoFarmLevel or state.AutoBoss or state.AutoRaid
                or state.AutoChest or state.MobAuraTp or state.SelectedMobFarm
        end

        local FarmVertical = {}

        function FarmVertical.Release()
            state.FarmHoldY = nil
        end

        function FarmVertical.Ensure()
            local root = rootPart()
            if not root then
                FarmVertical.Release()
                return
            end
            if state.Traveling then
                state.FarmHoldY = nil
                return
            end
            state.FarmHoldY = state.FarmHoldY or root.Position.Y
            local velocity = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame += Vector3.new(0, state.FarmHoldY - root.Position.Y, 0)
        end

        function FarmVertical.RecoverBody()
            if state.Traveling then
                return
            end
            local root = rootPart()
            local body = humanoid()
            if not root or not body or body.Health <= 0 then
                return
            end
            local staleGuard = root:FindFirstChild("VORTravelVelocity")
            if staleGuard then
                pcall(function()
                    staleGuard:Destroy()
                end)
            end
            root.Anchored = false
            body.Sit = false
            body.PlatformStand = false
            body.AutoRotate = true
            local bodyState = body:GetState()
            if bodyState == Enum.HumanoidStateType.Physics
                or bodyState == Enum.HumanoidStateType.PlatformStanding
                or bodyState == Enum.HumanoidStateType.Ragdoll
                or bodyState == Enum.HumanoidStateType.FallingDown then
                pcall(function()
                    body:ChangeState(Enum.HumanoidStateType.GettingUp)
                end)
                task.defer(function()
                    if body.Parent and body.Health > 0 and not state.Traveling then
                        pcall(function()
                            body:ChangeState(Enum.HumanoidStateType.Running)
                        end)
                    end
                end)
            end
        end

        function FarmVertical.SetAntiRagdoll(enabled)
            local body = humanoid()
            enabled = enabled == true and body ~= nil and body.Health > 0
            if state.AntiRagdollHumanoid == body and state.AntiRagdollApplied == enabled then
                return
            end
            if state.AntiRagdollHumanoid and state.AntiRagdollHumanoid.Parent then
                pcall(function()
                    state.AntiRagdollHumanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    state.AntiRagdollHumanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                end)
            end
            state.AntiRagdollHumanoid = body
            state.AntiRagdollApplied = enabled
            if body then
                pcall(function()
                    body:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not enabled)
                    body:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not enabled)
                end)
                if enabled then
                    FarmVertical.RecoverBody()
                end
            end
        end

        local function releaseMoveRide()
            local root = state.MoveRoot
            local body = state.MoveHumanoid
            local velocityGuard = state.MoveVelocityGuard
            if velocityGuard then
                pcall(function()
                    velocityGuard:Destroy()
                end)
            end
            if root and root.Parent then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                if body and body.Parent and body.Health > 0 then
                    root.Anchored = false
                else
                    root.Anchored = state.MoveRootWasAnchored == true
                end
            end
            if body and body.Parent then
                body.Sit = false
                body.PlatformStand = false
                body.AutoRotate = state.MoveAutoRotate == nil and true or state.MoveAutoRotate
                if body.Health > 0 then
                    pcall(function()
                        body:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end)
                    task.defer(function()
                        if body.Parent and body.Health > 0 and not state.Traveling then
                            pcall(function()
                                body:ChangeState(Enum.HumanoidStateType.Running)
                            end)
                        end
                    end)
                end
            end
            state.MoveRoot = nil
            state.MoveHumanoid = nil
            state.MoveAutoRotate = nil
            state.MovePlatformStand = nil
            state.MoveVelocityGuard = nil
            state.MoveRootWasAnchored = false
            state.Traveling = false
            gui:SetAttribute("BloxTraveling", false)
            if not movementStillNeedsNoclip() then
                for part, original in pairs(state.OriginalCollision) do
                    if part and part.Parent then
                        part.CanCollide = original
                    end
                end
                table.clear(state.OriginalCollision)
            end
        end

        local function cancelMove(keepRide)
            state.MoveToken += 1
            local activeTween = state.MoveTween
            state.MoveTween = nil
            state.MoveGoal = nil
            if activeTween then
                pcall(function()
                    activeTween:Cancel()
                end)
            end
            if not keepRide then
                releaseMoveRide()
            end
        end

        local function moveTo(targetCFrame)
            local root = rootPart()
            if not root or typeof(targetCFrame) ~= "CFrame" then
                return false
            end
            local distance = (root.Position - targetCFrame.Position).Magnitude
            if distance <= 3 then
                cancelMove(false)
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.CFrame = targetCFrame
                return true
            end
            if state.MoveGoal and (state.MoveGoal - targetCFrame.Position).Magnitude < 5 and state.MoveTween then
                return true
            end

            if state.MoveRoot and state.MoveRoot ~= root then
                cancelMove(false)
            else
                cancelMove(true)
            end
            if not state.MoveRoot then
                state.MoveRoot = root
                state.MoveRootWasAnchored = root.Anchored
                state.MoveHumanoid = humanoid()
                state.MoveAutoRotate = state.MoveHumanoid and state.MoveHumanoid.AutoRotate or nil
                state.MovePlatformStand = state.MoveHumanoid and state.MoveHumanoid.PlatformStand or nil
            end
            state.Traveling = true
            gui:SetAttribute("BloxTraveling", true)
            gui:SetAttribute("BloxTravelGoal", targetCFrame.Position)
            if state.MoveHumanoid then
                state.MoveHumanoid.AutoRotate = false
                state.MoveHumanoid.Sit = false
                state.MoveHumanoid.PlatformStand = false
            end
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            -- Keep the player's root network-owned and unanchored. Anchoring
            -- makes the local tween look perfect, but the server can retain
            -- the departure position and rubber-band the player back when the
            -- root is released. BodyVelocity cancels gravity without hiding
            -- the ride from replication.
            root.Anchored = state.MoveRootWasAnchored == true
            if not state.MoveRootWasAnchored and not state.MoveVelocityGuard then
                local velocityGuard = Instance.new("BodyVelocity")
                velocityGuard.Name = "VORTravelVelocity"
                velocityGuard.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                velocityGuard.P = 20000
                velocityGuard.Velocity = Vector3.zero
                velocityGuard.Parent = root
                state.MoveVelocityGuard = velocityGuard
            end

            state.MoveGoal = targetCFrame.Position
            local duration = distance / math.max(state.TweenSpeed, 1)
            if duration <= 0.08 then
                root.CFrame = targetCFrame
                cancelMove(false)
                return true
            end

            state.MoveToken += 1
            local moveToken = state.MoveToken
            local activeTween = TweenService:Create(
                root,
                TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
                {CFrame = targetCFrame}
            )
            state.MoveTween = activeTween
            activeTween.Completed:Once(function(playbackState)
                if state.MoveToken ~= moveToken or state.MoveTween ~= activeTween then
                    return
                end
                state.MoveTween = nil
                state.MoveGoal = nil
                if playbackState == Enum.PlaybackState.Completed and root.Parent then
                    root.CFrame = targetCFrame
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    -- Keep the replicated, unanchored root settled at the
                    -- destination for a few frames before restoring normal
                    -- humanoid physics. This gives the server the final
                    -- position instead of a chance to restore the departure.
                    task.delay(0.22, function()
                        if state.MoveToken == moveToken and not state.MoveTween then
                            releaseMoveRide()
                        end
                    end)
                    return
                end
                releaseMoveRide()
            end)
            activeTween:Play()
            return true
        end

        local function groundLockedEnemyY(enemy, enemyRoot)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {LocalPlayer.Character, enemy}
            params.IgnoreWater = false
            local result = workspace:Raycast(
                enemyRoot.Position + Vector3.new(0, 30, 0),
                Vector3.new(0, -180, 0),
                params
            )
            if result then
                return result.Position.Y + math.max(enemyRoot.Size.Y * 0.5, 2.5)
            end
            return enemyRoot.Position.Y
        end

        local function positionAtEnemy(enemy, lockVertical, heightOverride)
            local enemyRoot = modelRoot(enemy)
            if not enemyRoot then
                return nil
            end
            -- Lock the enemy's facing basis once per target. Recomputing the
            -- offset from a boss that constantly turns toward the player is
            -- what caused the old circular/orbiting tween.
            lockVertical = lockVertical == true
            if state.PositionTarget ~= enemy
                or state.PositionBasis == nil
                or state.PositionLockVertical ~= lockVertical then
                state.PositionTarget = enemy
                state.PositionLockVertical = lockVertical
                if lockVertical then
                    local flatForward = Vector3.new(
                        enemyRoot.CFrame.LookVector.X,
                        0,
                        enemyRoot.CFrame.LookVector.Z
                    )
                    if flatForward.Magnitude < 0.05 then
                        flatForward = Vector3.new(0, 0, -1)
                    else
                        flatForward = flatForward.Unit
                    end
                    state.PositionBasis = CFrame.lookAt(Vector3.zero, flatForward)
                    state.PositionAnchorY = groundLockedEnemyY(enemy, enemyRoot)
                else
                    state.PositionBasis = enemyRoot.CFrame - enemyRoot.Position
                    state.PositionAnchorY = nil
                end
                state.PositionJitter = Vector3.zero
                state.PositionJitterCorner = 0
                state.LastPositionJitterAt = 0
            end
            local squareMovement = state.MobAuraRandomSquare == true
            local orbitMovement = state.MobAuraOrbit == true and not squareMovement
            local horizontalOffset = Vector3.zero
            if squareMovement then
                local now = os.clock()
                local interval = math.max(0.06, tonumber(state.MobAuraSquareInterval) or 0.18)
                if state.LastPositionJitterAt == 0 or now - state.LastPositionJitterAt >= interval then
                    local range = math.max(2, tonumber(state.MobAuraSquareSize) or 8)
                    local nextCorner = math.random(1, 4)
                    if nextCorner == state.PositionJitterCorner then
                        nextCorner = nextCorner % 4 + 1
                    end
                    local corners = {
                        Vector3.new(-range, 0, -range),
                        Vector3.new(range, 0, -range),
                        Vector3.new(range, 0, range),
                        Vector3.new(-range, 0, range),
                    }
                    state.PositionJitterCorner = nextCorner
                    state.PositionJitter = corners[nextCorner]
                    state.LastPositionJitterAt = now
                end
                horizontalOffset = state.PositionJitter
            elseif orbitMovement then
                state.PositionJitter = Vector3.zero
                local elapsed = os.clock() - state.MobAuraOrbitStartedAt
                local angle = state.MobAuraOrbitStartAngle
                    + elapsed * math.rad(state.MobAuraOrbitSpeed) * state.MobAuraOrbitDirection
                horizontalOffset = Vector3.new(
                    math.cos(angle) * state.MobAuraOrbitRadius,
                    0,
                    math.sin(angle) * state.MobAuraOrbitRadius
                )
            else
                state.PositionJitter = Vector3.zero
            end
            local localOffset = Vector3.new(
                horizontalOffset.X,
                math.max(3, tonumber(heightOverride) or tonumber(state.MobAuraHeight) or 20),
                horizontalOffset.Z
            )
            local worldOffset = state.PositionBasis:VectorToWorldSpace(localOffset)
            local gatheredFrom = state.GatherOriginalCFrames[enemy]
            local useGatherAnchor = typeof(gatheredFrom) == "CFrame" and (
                state.GatherEnemies
                or (state.RaidMultiGrab and state.AutoRaid and LocalPlayer:GetAttribute("IslandRaiding") == true)
            )
            local livePosition = useGatherAnchor and gatheredFrom.Position or enemyRoot.Position
            local enemyAnchor = lockVertical and Vector3.new(
                livePosition.X,
                state.PositionAnchorY or livePosition.Y,
                livePosition.Z
            ) or livePosition
            local position = enemyAnchor + worldOffset
            return CFrame.lookAt(position, enemyAnchor)
        end

        local function moveToFarmPosition(targetCFrame)
            if not state.MobAuraRandomSquare and not state.MobAuraOrbit then
                return moveTo(targetCFrame)
            end
            local root = rootPart()
            if not root or typeof(targetCFrame) ~= "CFrame" then
                return false
            end
            -- Combat movement owns every farm mode. Square uses distinct aim
            -- updates for Fruit M1, while orbit is refreshed on Heartbeat so
            -- it remains a real circle instead of a chain of stale tweens.
            cancelMove()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = targetCFrame
            state.FarmHoldY = targetCFrame.Position.Y
            return true
        end

        local function syncFarmAuraRange(heightOverride)
            local radius = state.MobAuraRandomSquare and (state.MobAuraSquareSize * math.sqrt(2))
                or (state.MobAuraOrbit and state.MobAuraOrbitRadius or 0)
            local height = math.max(3, tonumber(heightOverride) or tonumber(state.MobAuraHeight) or 20)
            local required = math.min(
                AURA_KILL_MAX_RANGE,
                math.ceil(math.sqrt(height * height + radius * radius) + 8)
            )
            if state.AuraRange < required then
                local rangeControl = Window.PersistentControls["blox_aura_kill_range"]
                if rangeControl then
                    rangeControl:Set(required)
                else
                    state.AuraRange = required
                    gui:SetAttribute("BloxAuraKillRange", required)
                end
            end
            return required
        end

        local function healthPercent()
            local body = humanoid()
            if not body or body.MaxHealth <= 0 then
                return 100
            end
            return (body.Health / body.MaxHealth) * 100
        end

        local function safeModeRetreat(enemy)
            if not state.SafeMode or healthPercent() > state.SafeHealthPercent then
                return false
            end
            state.ActiveFarmTarget = nil
            local enemyRoot = modelRoot(enemy)
            if enemyRoot then
                local retreatPosition = enemyRoot.Position + Vector3.new(0, 45, 0)
                moveTo(CFrame.lookAt(retreatPosition, enemyRoot.Position))
            else
                cancelMove()
            end
            setStatus(string.format(
                "Safe mode: recovering at %.0f%% health",
                healthPercent()
            ), nil)
            return true
        end

        local function weaponNameForTool(tool)
            if not tool then
                return nil
            end
            if type(CombatUtil) == "table" and type(CombatUtil.GetWeaponName) == "function" then
                local ok, weaponName = pcall(function()
                    return CombatUtil:GetWeaponName(tool)
                end)
                if ok and weaponName then
                    return tostring(weaponName)
                end
            end
            return tostring(tool:GetAttribute("WeaponName") or tool.Name)
        end

        local function weaponDataForTool(tool)
            if not tool or type(CombatUtil) ~= "table" or type(CombatUtil.GetWeaponData) ~= "function" then
                return nil
            end
            local weaponName = weaponNameForTool(tool)
            if not weaponName then
                return nil
            end
            local ok, weaponData = pcall(function()
                return CombatUtil:GetWeaponData(weaponName)
            end)
            return ok and type(weaponData) == "table" and weaponData or nil
        end

        local function weaponTypeForTool(tool, weaponData)
            if not tool then
                return ""
            end
            return tostring(
                (weaponData and weaponData.WeaponType)
                    or tool:GetAttribute("WeaponType")
                    or tool.ToolTip
                    or ""
            )
        end

        local function isFruitWeaponType(weaponType)
            return string.find(string.lower(tostring(weaponType or "")), "fruit", 1, true) ~= nil
        end

        local function hasRegisteredBasicMoveset(weaponData)
            local moveset = type(weaponData) == "table" and weaponData.Moveset or nil
            local basics = type(moveset) == "table" and moveset.Basic or nil
            return type(basics) == "table" and #basics > 0
        end

        local function toolForSelection(selection)
            local char = character()
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            local selected = string.lower(tostring(selection or ""))
            local selectingFruitM1 = selected == "m1 fruit" or selected == "blox fruit"
            local bestAvailable = nil
            for _, container in ipairs({char, backpack}) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") then
                            local weaponData = weaponDataForTool(tool)
                            local weaponType = weaponTypeForTool(tool, weaponData)
                            local lowered = string.lower(weaponType)
                            local fruitTool = isFruitWeaponType(weaponType)
                            local registeredTool = hasRegisteredBasicMoveset(weaponData)
                            if not bestAvailable and (registeredTool or fruitTool) then
                                bestAvailable = tool
                            end
                            if selected == "best available" and (registeredTool or fruitTool) then
                                return tool
                            end
                            -- Fruit Tools such as Kitsune use their own LocalScript
                            -- and native click remote instead of WeaponData. They must
                            -- still be selected and equipped even when GetWeaponData
                            -- returns nil.
                            if selectingFruitM1 and fruitTool then
                                return tool
                            end
                            if registeredTool and lowered == selected then
                                return tool
                            end
                        end
                    end
                end
            end
            -- Explicit Sword/Melee/Fruit choices never lie by returning another
            -- category. Best Available is the only mode allowed to fall back.
            return selected == "best available" and bestAvailable or nil
        end

        local function selectedTool()
            return toolForSelection(state.WeaponType)
        end

        local function equipTool(tool)
            local char = character()
            local hum = humanoid()
            local changed = false
            if tool and char and hum and tool.Parent ~= char then
                local ok = pcall(function()
                    hum:EquipTool(tool)
                end)
                changed = ok and tool.Parent == char
            end
            return tool, changed
        end

        local function updateAuraWeaponState(tool, mode)
            local weaponData = weaponDataForTool(tool)
            state.AuraWeaponName = tool and tool.Name or nil
            state.AuraWeaponType = tool and weaponTypeForTool(tool, weaponData) or nil
            state.AuraAttackMode = mode
        end

        local function equipSelectedTool()
            if state.DoubleAttack then
                local sword = toolForSelection("Sword")
                local fruit = toolForSelection("M1 Fruit")
                equipTool(sword)
                state.AuraWeaponName = sword and fruit and (sword.Name .. " + " .. fruit.Name) or nil
                state.AuraWeaponType = sword and fruit and "Sword + Blox Fruit" or nil
                state.AuraAttackMode = "Double Attack"
                return sword
            end
            local tool = selectedTool()
            equipTool(tool)
            updateAuraWeaponState(tool, state.WeaponType)
            return tool
        end

        local function applyFruitM1CooldownReduction(value)
            value = math.clamp(
                tonumber(value) or DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
                0,
                1
            )
            state.FruitM1CooldownReduction = value
            local char = character()
            if char then
                if state.OriginalFruitTapCooldown == nil then
                    state.OriginalFruitTapCooldown = tonumber(char:GetAttribute("FruitTAPCooldown")) or 0
                end
                char:SetAttribute("FruitTAPCooldown", value)
            end
            return value
        end

        local HIT_PART_NAMES = {
            "ModelHitbox",
            "UpperTorso",
            "LowerTorso",
            "Head",
            "RightUpperArm",
            "LeftUpperArm",
            "RightUpperLeg",
            "LeftUpperLeg",
        }

        local function enemyHitPart(enemy)
            for _, partName in ipairs(HIT_PART_NAMES) do
                local part = enemy:FindFirstChild(partName, true)
                if part and part:IsA("BasePart") then
                    return part
                end
            end
            return nil
        end

        local function nearbyAuraTargets()
            local root = rootPart()
            local enemies = workspace:FindFirstChild("Enemies")
            local targets = {}
            if not root or not enemies then
                return targets
            end
            local selectedFilter = nil
            if state.GatherEnemies then
                selectedFilter = selectedGatherEnemyName()
            elseif state.SelectedMobFarm and state.SelectedMobName ~= "None" then
                selectedFilter = state.SelectedMobName
            elseif state.AutoFarmLevel then
                selectedFilter = state.CurrentEnemyName
            end
            for _, enemy in ipairs(enemies:GetChildren()) do
                local enemyRoot = modelRoot(enemy)
                local hitPart = enemyHitPart(enemy)
                if enemyRoot and hitPart and modelAlive(enemy)
                    and (not selectedFilter or enemyMatches(enemy, selectedFilter)) then
                    local distance = (enemyRoot.Position - root.Position).Magnitude
                    if distance <= state.AuraRange then
                        table.insert(targets, {
                            Enemy = enemy,
                            HitPart = hitPart,
                            Distance = distance,
                        })
                    end
                end
            end
            table.sort(targets, function(left, right)
                return left.Distance < right.Distance
            end)
            return targets
        end

        function DoubleAttackEngine.Targets(maximum)
            local targets = {}
            local limit = math.max(math.floor(tonumber(maximum) or 1), 1)
            local hitRange = math.min(
                math.max(tonumber(state.AuraRange) or AURA_KILL_DEFAULT_RANGE, 0),
                DoubleAttackEngine.HitRange
            )
            for _, candidate in ipairs(nearbyAuraTargets()) do
                if candidate.Distance <= hitRange then
                    table.insert(targets, candidate)
                    if #targets >= limit then
                        break
                    end
                end
            end
            return targets
        end

        local function resolveRegisterHitClosure()
            if type(state.RegisterHitClosure) == "function" then
                return state.RegisterHitClosure
            end
            if os.clock() - state.LastRegisterHitResolve < 5 then
                return nil
            end
            state.LastRegisterHitResolve = os.clock()
            if type(CombatUtil) ~= "table"
                or type(CombatUtil.RunHitDetection) ~= "function"
                or type(debug) ~= "table"
                or type(debug.getupvalue) ~= "function" then
                return nil
            end
            local currentBuildFallback = nil
            for index = 1, 16 do
                local ok, first, second = pcall(debug.getupvalue, CombatUtil.RunHitDetection, index)
                if not ok then
                    break
                end
                -- Executor implementations return either the value alone or
                -- the stock name/value pair. Support both shapes.
                local value = type(second) == "function" and second or first
                if type(value) == "function" then
                    if index == 5 then
                        currentBuildFallback = value
                    end
                    local name = ""
                    if type(debug.info) == "function" then
                        pcall(function()
                            name = debug.info(value, "n")
                        end)
                    end
                    if name == "registerHit" then
                        state.RegisterHitClosure = value
                        return value
                    end
                end
            end
            -- Live Blox Fruits currently stores registerHit at upvalue 5. The
            -- named lookup above is preferred so updates do not depend on it.
            state.RegisterHitClosure = currentBuildFallback
            return currentBuildFallback
        end

        local function auraAttackProfile(tool, weaponData)
            if not tool or type(weaponData) ~= "table"
                or type(CombatUtil) ~= "table"
                or type(CombatUtil.GetMovesetAnimCache) ~= "function"
                or type(CombatUtil.GetWeaponName) ~= "function"
                or type(CombatUtil.GetPureWeaponName) ~= "function" then
                return nil, "combat animation data is unavailable"
            end

            local moveset = weaponData.Moveset
            local basics = type(moveset) == "table" and moveset.Basic or nil
            if type(basics) ~= "table" or #basics == 0 then
                return nil, "the equipped tool has no basic attack moveset"
            end

            local body = humanoid()
            if not body then
                return nil, "the local humanoid is unavailable"
            end
            local ok, profile = pcall(function()
                local weaponName = CombatUtil:GetWeaponName(tool)
                local pureName = CombatUtil:GetPureWeaponName(weaponName)
                local cache = CombatUtil:GetMovesetAnimCache(body)
                local comboKey = string.lower(tostring(weaponName))
                local combo = ((state.AuraCombos[comboKey] or 0) % #basics) + 1
                local track = cache and cache[pureName .. "-basic" .. combo]
                if not track then
                    error("basic attack track is not loaded")
                end
                local speedMultiplier = track:GetAttribute("SpeedMult") or 1
                local duration = tonumber(track.Length) / math.max(tonumber(speedMultiplier) or 1, 0.01)
                if duration <= 0 then
                    error("basic attack duration is invalid")
                end
                local char = character()
                local attackSpeed = char and tonumber(char:GetAttribute("AttackSpeedMultiplier")) or 1
                attackSpeed = math.max(attackSpeed or 1, 0.01)
                return {
                    Combo = combo,
                    ComboKey = comboKey,
                    Duration = duration,
                    NativeCadence = duration * AURA_KILL_NATIVE_COOLDOWN_SCALE / attackSpeed,
                }
            end)
            if not ok then
                return nil, tostring(profile)
            end
            return profile
        end

        function DoubleAttackEngine.SwordProfile(tool, weaponData)
            local moveset = type(weaponData) == "table" and weaponData.Moveset or nil
            local basics = type(moveset) == "table" and moveset.Basic or nil
            if type(basics) ~= "table" or #basics == 0 then
                return nil, "the Sword M1 moveset was not found"
            end

            local weaponName = weaponNameForTool(tool)
            local comboKey = string.lower(tostring(weaponName or tool.Name))
            local combo = ((state.AuraCombos[comboKey] or 0) % #basics) + 1
            local duration = nil
            if type(CombatUtil) == "table"
                and type(CombatUtil.GetMovesetAnimCache) == "function"
                and type(CombatUtil.GetPureWeaponName) == "function" then
                pcall(function()
                    local pureName = CombatUtil:GetPureWeaponName(weaponName)
                    local cache = CombatUtil:GetMovesetAnimCache(humanoid())
                    local animationTrack = cache and cache[pureName .. "-basic" .. combo]
                    if animationTrack then
                        local speedMultiplier = math.max(
                            tonumber(animationTrack:GetAttribute("SpeedMult")) or 1,
                            0.01
                        )
                        duration = tonumber(animationTrack.Length) / speedMultiplier
                    end
                end)
            end

            -- This is the same compatibility value used by the verified
            -- Dungeon engine when the Sword animation cache is not loaded.
            -- Zero gets rejected; the non-finite duration keeps the native
            -- registration window alive without playing the swing locally.
            if not duration or duration <= 0 then
                duration = 0 / 0
            end
            return {
                Combo = combo,
                ComboKey = comboKey,
                Duration = duration,
            }
        end

        local function registeredAttackCadence(attackProfile)
            if state.FastAttack then
                -- The RegisterAttack -> RegisterHit window itself already
                -- consumes AURA_KILL_HIT_DELAY. Adding half the animation
                -- length here made the "Turbo" toggle visibly pause even with
                -- Extra Aura Delay at zero.
                return AURA_KILL_HIT_DELAY
            end
            return math.max(AURA_KILL_HIT_DELAY, attackProfile.NativeCadence)
        end

        local function nativeFruitAttackCadence()
            local reducedCadence = math.max(
                0.04,
                NATIVE_FRUIT_M1_CADENCE - math.max(tonumber(state.FruitM1CooldownReduction) or 0, 0)
            )
            return state.FastAttack and math.max(0.04, reducedCadence * 0.55) or reducedCadence
        end

        local function transientAuraMiss(message)
            message = tostring(message or "")
            return message == "the target left before the hit window"
                or message == "the target left Aura range"
                or message == "the fruit M1 target left before activation"
        end

        local function sendRegisteredAuraHit(tool, weaponData, target, attackProfile, attackTargets)
            local _, changed = equipTool(tool)
            if changed then
                task.wait(0.04)
            end
            if not tool or tool.Parent ~= character() then
                return false, "the combat Tool could not be equipped"
            end
            if not attackProfile then
                local profileError
                attackProfile, profileError = auraAttackProfile(tool, weaponData)
                if not attackProfile then
                    return false, profileError
                end
            end

            local registerHit = resolveRegisterHitClosure()
            if not RegisterAttackEvent or type(registerHit) ~= "function" then
                return false, "combat registration is unavailable in this server build"
            end

            -- Match the exact duration sent by the native combat controller.
            -- Zero is rejected by the server.
            RegisterAttackEvent:FireServer(attackProfile.Duration)
            state.AuraStage = "attack-started"
            task.wait(AURA_KILL_HIT_DELAY)
            state.AuraStage = "hit-window"
            if not state.Alive or not state.AuraKill then
                return false, "the target left before the hit window"
            end

            local currentRoot = rootPart()
            if not currentRoot then
                return false, "the target left Aura range"
            end

            -- One native attack can register every enemy touched by the same
            -- melee window. Multi Grab uses that window for the entire stack so
            -- two or more NPCs take real damage together instead of waiting for
            -- the Aura cursor to visit them one by one.
            state.AuraStage = "queue-build"
            local validHits = {}
            for _, candidate in ipairs(attackTargets or {target}) do
                local enemy = candidate.Enemy
                local enemyRoot = modelRoot(enemy)
                local hitPart = enemyHitPart(enemy)
                if enemy and enemy.Parent and enemyRoot and hitPart and modelAlive(enemy)
                    and (enemyRoot.Position - currentRoot.Position).Magnitude <= state.AuraRange then
                    table.insert(validHits, {
                        Enemy = enemy,
                        HitPart = hitPart,
                    })
                end
            end
            local registered = #validHits
            if registered == 0 then
                return false, "the target left Aura range"
            end

            -- Native combat queues every rig touched during one swing, then
            -- flushes the queue once. Sending one flush per NPC makes the
            -- server accept the first target and discard the rest as duplicate
            -- attacks. Mirror CombatUtil's real batching shape here instead.
            local primary = validHits[1]
            local extraHits = {}
            for index = 2, registered do
                local hit = validHits[index]
                table.insert(extraHits, {hit.Enemy, hit.HitPart})
            end
            registerHit(character(), primary.Enemy, primary.HitPart, weaponData, extraHits)
            state.AuraStage = "queue-flush"
            registerHit(true)
            state.AuraCombos[attackProfile.ComboKey] = attackProfile.Combo
            state.AuraCombo = attackProfile.Combo
            state.AuraStage = registered > 1 and "registered-multi-hit-sent" or "registered-hit-sent"
            return true, nil, registered
        end

        function DoubleAttackEngine.SendSword(tool, weaponData, attackProfile)
            local _, changed = equipTool(tool)
            if changed then
                task.wait(0.04)
            end
            if not tool or tool.Parent ~= character() then
                return false, "the Sword could not be equipped"
            end
            if not weaponData then
                return false, "Sword combat data is unavailable"
            end
            if not attackProfile then
                local profileError
                attackProfile, profileError = DoubleAttackEngine.SwordProfile(tool, weaponData)
                if not attackProfile then
                    return false, profileError
                end
            end

            local registerHit = resolveRegisterHitClosure()
            if not RegisterAttackEvent or type(registerHit) ~= "function" then
                return false, "Double Attack combat registration is unavailable"
            end
            if #DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit) == 0 then
                return false, "No enemy is inside Double Attack range"
            end

            RegisterAttackEvent:FireServer(attackProfile.Duration)
            state.AuraStage = "double-sword-started"
            task.wait(AURA_KILL_HIT_DELAY)
            if not state.Alive or not state.AuraKill or not state.DoubleAttack then
                return false, "the target left before the hit window"
            end

            -- Re-scan at the actual server hit window. The old sea loop kept a
            -- stale two-target list from before the delay; the verified
            -- Dungeon/Solix pattern batches every current rig in one flush.
            local targets = DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit)
            if #targets == 0 then
                return false, "the target left Aura range"
            end
            local primary = targets[1]
            local extraHits = {}
            for index = 2, #targets do
                local hit = targets[index]
                table.insert(extraHits, {hit.Enemy, hit.HitPart})
            end
            registerHit(character(), primary.Enemy, primary.HitPart, weaponData, extraHits)
            registerHit(true)
            state.AuraCombos[attackProfile.ComboKey] = attackProfile.Combo
            state.AuraCombo = attackProfile.Combo
            state.AuraMultiTargetCount = #targets
            state.AuraStage = #targets > 1 and "double-sword-multi-sent" or "double-sword-sent"
            return true, nil, #targets
        end

        local function playingTrackSet()
            local tracks = {}
            local body = humanoid()
            local animator = body and body:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    tracks[track] = true
                end
            end
            return animator, tracks
        end

        local function stopNewActionTracks(animator, previousTracks)
            if not animator then
                return
            end
            pcall(function()
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if not previousTracks[track]
                        and track.Priority.Value >= Enum.AnimationPriority.Action.Value then
                        track:Stop(0)
                    end
                end
            end)
        end

        local function holdRoot(root, goalCFrame, duration, animator, previousTracks)
            local deadline = os.clock() + duration
            repeat
                if not root.Parent then
                    break
                end
                root.CFrame = goalCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                stopNewActionTracks(animator, previousTracks)
                task.wait()
            until os.clock() >= deadline
        end

        local function sendNativeFruitM1(tool, target, keepEquippedTool)
            local char = character()
            local root = rootPart()
            local enemyRoot = modelRoot(target.Enemy)
            local hitPart = enemyHitPart(target.Enemy)
            if not char or not root or not enemyRoot or not hitPart then
                return false, "the fruit M1 target is unavailable"
            end
            local nativeDistance = (enemyRoot.Position - root.Position).Magnitude
            state.AuraFruitLastDistance = nativeDistance
            state.AuraFruitInRange = nativeDistance <= NATIVE_FRUIT_MAX_RANGE
            if not state.AuraFruitInRange then
                return false, "fruit-out-of-range"
            end
            if os.clock() < (state.FruitM1ReadyAt or 0) then
                return false, "fruit-cooldown"
            end

            local silentRemote = tool:FindFirstChild("LeftClickRemote", true)
            silentRemote = silentRemote and silentRemote:IsA("RemoteEvent") and silentRemote or nil

            if silentRemote then
                -- Kitsune-style fruits expose the damage request directly. Fire
                -- it from the Backpack so the Sword stays visibly equipped and
                -- neither the player nor the NPC needs any CFrame manipulation.
                local comboKey = string.lower(tool.Name)
                local combo = ((state.NativeFruitCombos[comboKey] or 0) % 5) + 1
                local flatDirection = (enemyRoot.Position - root.Position) * Vector3.new(1, 0, 1)
                if flatDirection.Magnitude < 0.05 then
                    flatDirection = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                end
                flatDirection = flatDirection.Unit
                local fired, fireError = pcall(function()
                    silentRemote:FireServer(flatDirection, combo, false)
                end)
                if not fired then
                    return false, fireError
                end
                state.NativeFruitCombos[comboKey] = combo
                local nativeCooldown = (combo < 5 and 0.3 or 1)
                    - math.max(tonumber(state.FruitM1CooldownReduction) or 0, 0)
                state.FruitM1ReadyAt = os.clock() + math.max(0.02, nativeCooldown)
                state.AuraStage = "silent-fruit-m1-sent"
                return true
            end

            local originalParent = tool.Parent
            if keepEquippedTool then
                -- Parent the fruit beside the Sword instead of asking the
                -- Humanoid to equip it. The Sword never leaves Character.
                if tool.Parent ~= char then
                    tool.Parent = char
                    task.wait()
                end
            else
                local _, changed = equipTool(tool)
                if changed then
                    task.wait(0.04)
                end
            end
            if tool.Parent ~= char then
                return false, "the fruit Tool could not be armed"
            end

            local originalRootCFrame = root.CFrame
            local animator, previousTracks = playingTrackSet()

            -- Other native fruit controllers still need Tool.Activate. Keep the
            -- player at the current Mob Aura position only to cancel a local
            -- dash; the enemy is never written to or moved.
            if not state.Alive or not state.AuraKill or not modelAlive(target.Enemy) then
                if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                    tool.Parent = originalParent
                end
                return false, "the fruit M1 target left before activation"
            end

            if type(FruitMouse) ~= "table" then
                if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                    tool.Parent = originalParent
                end
                return false, "the native fruit mouse controller is unavailable"
            end

            state.AuraFruitBusy = true
            local oldHit = FruitMouse.Hit
            local oldTarget = FruitMouse.Target
            FruitMouse.Hit = CFrame.new(hitPart.Position)
            FruitMouse.Target = hitPart
            local activated, activationError = pcall(function()
                tool:Activate()
                tool:Deactivate()
            end)
            FruitMouse.Hit = oldHit
            FruitMouse.Target = oldTarget
            if keepEquippedTool and originalParent and tool.Parent ~= originalParent then
                tool.Parent = originalParent
            end
            if not activated then
                root.CFrame = originalRootCFrame
                state.AuraFruitBusy = false
                return false, activationError
            end

            state.AuraStage = "native-fruit-m1-sent"
            -- Fruit M1 LocalScripts often add a short dash and Action animation.
            -- Pinning only the original player position and stopping newly
            -- started Action tracks preserves the no-swing/no-movement Aura.
            holdRoot(root, originalRootCFrame, NATIVE_FRUIT_SETTLE_TIME, animator, previousTracks)
            state.AuraFruitBusy = false
            return true
        end

        function DoubleAttackEngine.SendFruit(tool)
            local root = rootPart()
            local targets = DoubleAttackEngine.Targets(DoubleAttackEngine.FruitTargetLimit)
            if not tool then
                return false, "No Blox Fruit Tool was found"
            end
            if not root or #targets == 0 then
                return false, "No enemy is inside Fruit M1 range"
            end

            local silentRemote = tool:FindFirstChild("LeftClickRemote", true)
            silentRemote = silentRemote and silentRemote:IsA("RemoteEvent") and silentRemote or nil
            if silentRemote then
                local comboKey = string.lower(tool.Name)
                local combo = ((state.NativeFruitCombos[comboKey] or 0) % 5) + 1
                local sent = 0
                local closestDistance = math.huge
                for _, target in ipairs(targets) do
                    local enemyRoot = modelRoot(target.Enemy)
                    if enemyRoot and modelAlive(target.Enemy) then
                        local direction = (enemyRoot.Position - root.Position) * Vector3.new(1, 0, 1)
                        if direction.Magnitude < 0.05 then
                            direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
                        end
                        if direction.Magnitude >= 0.05 then
                            silentRemote:FireServer(direction.Unit, combo)
                            sent += 1
                            closestDistance = math.min(closestDistance, target.Distance)
                        end
                    end
                end
                if sent == 0 then
                    return false, "the fruit M1 targets left Aura range"
                end
                state.NativeFruitCombos[comboKey] = combo
                state.AuraFruitLastDistance = closestDistance
                state.AuraFruitInRange = true
                state.AuraStage = sent > 1 and "double-fruit-multi-sent" or "double-fruit-sent"
                return true, nil, sent
            end

            -- Fruits without a direct click remote retain the native fallback.
            -- It temporarily arms the Fruit beside the Sword, restores it, and
            -- suppresses the local dash/animation without moving the enemy.
            local sent, sendError = sendNativeFruitM1(tool, targets[1], true)
            return sent, sendError, sent and 1 or 0
        end

        function DoubleAttackEngine.StepFruit()
            if not state.Alive
                or not state.AuraKill
                or not state.DoubleAttack
                or state.InventoryBusy
                or state.FruitDispatchPending then
                return false
            end
            if not busoActive() then
                ensureBuso(true)
                return false
            end

            local now = os.clock()
            local cadence = DoubleAttackEngine.FruitCadence
                + math.max(tonumber(state.AttackInterval) or 0, 0)
            if now - (state.LastDoubleFruitAttack or 0) < cadence then
                return false
            end
            if #DoubleAttackEngine.Targets(1) == 0 then
                return false
            end

            local sword = toolForSelection("Sword")
            local fruit = toolForSelection("M1 Fruit")
            if not sword or not fruit then
                return false
            end
            equipTool(sword)
            state.LastDoubleFruitAttack = now
            state.FruitDispatchPending = true
            task.spawn(function()
                local operationOk, sent, message, sentCount = pcall(DoubleAttackEngine.SendFruit, fruit)
                if operationOk and sent then
                    sentCount = math.max(tonumber(sentCount) or 1, 1)
                    state.AuraFruitRequests += sentCount
                    state.AuraRequests += sentCount
                else
                    local failure = operationOk and message or sent
                    local failureText = tostring(failure)
                    if not failureText:find("No enemy", 1, true)
                        and failure ~= "fruit-cooldown"
                        and not transientAuraMiss(failure) then
                        state.AuraPendingError = "Fruit M1 failed: " .. failureText
                    end
                end
                state.FruitDispatchPending = false
            end)
            return true
        end

        local function auraKillOnce()
            if not state.AuraKill or state.AuraAttackPending or state.InventoryBusy then
                return false
            end
            if not busoActive() then
                state.AuraStage = "waiting-for-buso"
                ensureBuso(true)
                return false
            end
            local now = os.clock()
            if now - state.LastAuraScan < 0.04 then
                return false
            end
            state.LastAuraScan = now

            local targets = nearbyAuraTargets()
            state.AuraTargetCount = #targets
            if #targets == 0 then
                state.AuraTargetCursor = 0
                state.AuraMultiTargetCount = 0
                return false
            end

            state.AuraTargetCursor = (state.AuraTargetCursor % #targets) + 1
            local target = targets[state.AuraTargetCursor]
            local attackTargets = {target}
            if state.DoubleAttack then
                -- Double Attack mirrors the Dungeon engine: every eligible
                -- nearby rig is part of the same Sword window even when Multi
                -- Grab is off. Fruit independently covers its nearest three.
                attackTargets = DoubleAttackEngine.Targets(DoubleAttackEngine.SwordTargetLimit)
                target = attackTargets[1] or target
            elseif (state.GatherEnemies or (
                state.RaidMultiGrab
                and state.AutoRaid
                and LocalPlayer:GetAttribute("IslandRaiding") == true
            )) and #targets > 1 then
                attackTargets = {}
                -- Non-Buddha melee validation accepts two rigs in one bundled
                -- hit but rejects oversized lists. Rotate pairs through the
                -- three-enemy pile so every NPC is covered without fake hits.
                local multiLimit = math.min(#targets, MULTI_ATTACK_TARGET_LIMIT)
                for offset = 0, multiLimit - 1 do
                    local index = ((state.AuraTargetCursor - 1 + offset) % #targets) + 1
                    table.insert(attackTargets, targets[index])
                end
                target = attackTargets[1]
            end
            state.AuraMultiTargetCount = #attackTargets
            local extraDelay = math.max(tonumber(state.AttackInterval) or 0, 0)
            local plan = {Double = state.DoubleAttack}

            if state.DoubleAttack then
                plan.Sword = toolForSelection("Sword")
                plan.Fruit = toolForSelection("M1 Fruit")
                if not plan.Sword or not plan.Fruit then
                    state.AuraPendingError = "Double Attack requires both a Sword and a Blox Fruit Tool"
                    return false
                end
                plan.SwordData = weaponDataForTool(plan.Sword)
                if not hasRegisteredBasicMoveset(plan.SwordData) then
                    state.AuraPendingError = "Double Attack could not resolve the Sword M1 moveset"
                    return false
                end
                local _, swordChanged = equipTool(plan.Sword)
                if swordChanged then
                    task.wait(0.04)
                end
                local swordProfile, swordError = DoubleAttackEngine.SwordProfile(plan.Sword, plan.SwordData)
                if not swordProfile then
                    state.AuraPendingError = "Double Attack could not read the Sword: " .. tostring(swordError)
                    return false
                end
                plan.SwordProfile = swordProfile
                plan.FruitData = weaponDataForTool(plan.Fruit)
                plan.FruitRegistered = isFruitWeaponType(weaponTypeForTool(plan.Fruit, plan.FruitData))
                    and hasRegisteredBasicMoveset(plan.FruitData)
                plan.Cadence = AURA_KILL_HIT_DELAY + extraDelay
                state.AuraWeaponName = plan.Sword.Name .. " + " .. plan.Fruit.Name
                state.AuraWeaponType = "Sword + Blox Fruit"
                state.AuraAttackMode = "Double Attack"
            else
                plan.Tool = selectedTool()
                if not plan.Tool then
                    state.AuraPendingError = "No " .. tostring(state.WeaponType) .. " Tool was found"
                    return false
                end
                plan.WeaponData = weaponDataForTool(plan.Tool)
                plan.WeaponType = weaponTypeForTool(plan.Tool, plan.WeaponData)
                plan.NativeFruit = isFruitWeaponType(plan.WeaponType)
                    and not hasRegisteredBasicMoveset(plan.WeaponData)
                if not plan.NativeFruit then
                    if not hasRegisteredBasicMoveset(plan.WeaponData) then
                        state.AuraPendingError = "The selected Tool has no M1 attack moveset"
                        return false
                    end
                    if string.lower(plan.WeaponType) == "gun" then
                        state.AuraPendingError = "Aura Kill needs a Sword, Melee, or M1 Fruit Tool"
                        return false
                    end
                    equipTool(plan.Tool)
                    local profileError
                    plan.Profile, profileError = auraAttackProfile(plan.Tool, plan.WeaponData)
                    if not plan.Profile then
                        state.AuraPendingError = "Aura Kill could not read the equipped Tool: " .. tostring(profileError)
                        return false
                    end
                    plan.Cadence = registeredAttackCadence(plan.Profile) + extraDelay
                    state.AuraAttackMode = isFruitWeaponType(plan.WeaponType)
                        and "Registered Fruit M1" or "Registered " .. plan.WeaponType
                else
                    plan.Cadence = nativeFruitAttackCadence() + extraDelay
                    state.AuraAttackMode = "Native Fruit M1"
                end
                updateAuraWeaponState(plan.Tool, state.AuraAttackMode)
            end

            if now - state.LastAttack < plan.Cadence then
                return false
            end

            state.AuraAttackPending = true
            state.LastAttack = now
            state.AuraStage = state.DoubleAttack and "double-queued" or "queued"
            state.AuraLastRequestAt = now
            state.CurrentEnemyName = normalizeEnemyName(target.Enemy.Name)
            state.AuraLastDistance = target.Distance

            local healthBefore = {}
            for _, attackTarget in ipairs(attackTargets) do
                local targetHumanoid = attackTarget.Enemy:FindFirstChildOfClass("Humanoid")
                if targetHumanoid then
                    healthBefore[targetHumanoid] = targetHumanoid.Health
                end
            end
            local dispatched = 0
            local fruitOutOfRange = false
            local hitOk, hitError = pcall(function()
                if plan.Double then
                    local swordSent, swordSendError, swordHitCount = DoubleAttackEngine.SendSword(
                        plan.Sword,
                        plan.SwordData,
                        plan.SwordProfile
                    )
                    if not swordSent then
                        if transientAuraMiss(swordSendError) then
                            state.AuraStage = "target-left-before-hit"
                            return
                        end
                        error("Sword M1 failed: " .. tostring(swordSendError))
                    end
                    swordHitCount = math.max(tonumber(swordHitCount) or 1, 1)
                    dispatched += swordHitCount
                    state.AuraSwordRequests += swordHitCount
                elseif plan.NativeFruit then
                    local sent, sendError = sendNativeFruitM1(plan.Tool, target)
                    if not sent then
                        if sendError == "fruit-out-of-range" then
                            fruitOutOfRange = true
                            state.AuraStage = "fruit-out-of-range"
                            return
                        end
                        if sendError == "fruit-cooldown" then
                            state.AuraStage = "fruit-cooldown"
                            return
                        end
                        if transientAuraMiss(sendError) then
                            state.AuraStage = "target-left-before-fruit"
                            return
                        end
                        error(sendError)
                    end
                    dispatched = 1
                    state.AuraFruitRequests += 1
                else
                    local sent, sendError, registeredCount = sendRegisteredAuraHit(
                        plan.Tool,
                        plan.WeaponData,
                        target,
                        plan.Profile,
                        attackTargets
                    )
                    if not sent then
                        if transientAuraMiss(sendError) then
                            state.AuraStage = "target-left-before-hit"
                            return
                        end
                        error(sendError)
                    end
                    registeredCount = math.max(tonumber(registeredCount) or 1, 1)
                    dispatched = registeredCount
                    if isFruitWeaponType(plan.WeaponType) then
                        state.AuraFruitRequests += registeredCount
                    elseif string.lower(plan.WeaponType) == "sword" then
                        state.AuraSwordRequests += registeredCount
                    end
                end
            end)
            state.AuraAttackPending = false
            state.AuraRequests += dispatched
            if not hitOk then
                state.AuraPendingError = "Aura Kill attack failed: " .. tostring(hitError)
                state.AuraStage = "error"
                return false
            end
            if dispatched == 0 then
                state.AuraStage = fruitOutOfRange and "fruit-out-of-range" or "target-left-range"
                return false
            end

            task.delay(0.35, function()
                local damaged = 0
                if state.Alive then
                    for targetHumanoid, before in pairs(healthBefore) do
                        if targetHumanoid.Parent and targetHumanoid.Health < before then
                            damaged += 1
                        end
                    end
                end
                if damaged > 0 then
                    state.AuraHits += damaged
                    state.AuraLastHitAt = os.clock()
                end
                state.AuraStage = "idle"
            end)
            return true
        end

        local function stepMobAuraTp()
            local selectedMode = state.SelectedMobFarm
            if (not state.MobAuraTp and not selectedMode) or state.AuraFruitBusy then
                return false
            end
            local root = rootPart()
            if not root then
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                return false
            end

            local selectedName = selectedMode and state.SelectedMobName or nil
            if selectedMode and (not selectedName or selectedName == "None") then
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                return false
            end
            local searchRange = selectedMode and state.SelectedMobSearchRange or state.MobAuraSearchRange

            local target = state.MobAuraTarget
            local targetRoot = modelRoot(target)
            if not targetRoot or not modelAlive(target)
                or (selectedMode and not enemyMatches(target, selectedName))
                or (targetRoot.Position - root.Position).Magnitude > searchRange then
                target = nil
            end
            if not target then
                local nearest, distance = nearestEnemy(selectedName, not selectedMode)
                state.MobAuraPreTeleportDistance = distance
                if not nearest or not distance or distance > searchRange then
                    state.MobAuraTarget = nil
                    state.MobAuraTargetName = nil
                    state.MobAuraAnchorTarget = nil
                    state.MobAuraStableAnchor = nil
                    state.MobAuraDistance = distance ~= math.huge and distance or nil
                    if selectedMode then
                        state.CurrentEnemyName = selectedName
                        local spawn, spawnDistance = nearestEnemySpawn(selectedName)
                        state.SelectedMobWaitingAtSpawn = spawn ~= nil
                        if spawn then
                            local height = math.clamp(state.MobAuraHeight, 3, AURA_KILL_MAX_RANGE - 10)
                            local goalPosition = spawn.Position + Vector3.new(0, height, 0)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            root.CFrame = CFrame.new(goalPosition)
                            state.MobAuraDistance = spawnDistance
                            return true
                        end
                    else
                        state.SelectedMobWaitingAtSpawn = false
                    end
                    return false
                end
                if nearest ~= state.MobAuraTarget then
                    state.MobAuraOrbitStartedAt = os.clock()
                    state.MobAuraOrbitStartAngle = math.random() * math.pi * 2
                    state.MobAuraOrbitDirection = math.random(0, 1) == 0 and -1 or 1
                end
                target = nearest
                state.MobAuraTarget = target
                targetRoot = modelRoot(target)
            end
            if not targetRoot then
                return false
            end

            local head = target:FindFirstChild("Head", true)
            local liveAnchor = head and head:IsA("BasePart") and head.Position or targetRoot.Position
            local singleFallback = state.GatherSingleFallbackEnemy == target
                and modelAlive(state.GatherSingleFallbackEnemy)
            if singleFallback then
                state.MobAuraAnchorTarget = target
                state.MobAuraStableAnchor = liveAnchor
            elseif state.MobAuraAnchorTarget ~= target then
                state.MobAuraAnchorTarget = target
                -- A replacement target may already be inside the grabbed pile.
                -- Retain the original ground anchor across target swaps or the
                -- new, raised NPC position feeds height back into the player.
                if not state.GatherEnemies or not state.MobAuraStableAnchor then
                    state.MobAuraStableAnchor = liveAnchor
                end
            elseif not state.GatherEnemies or not state.MobAuraStableAnchor then
                state.MobAuraStableAnchor = liveAnchor
            end
            -- Once Multi Grab moves the target underneath the player, keep
            -- using its original ground anchor. Following the moved NPC would
            -- add MobAuraHeight again every frame and launch the player upward.
            local anchor = state.GatherEnemies and not singleFallback
                and state.MobAuraStableAnchor or liveAnchor
            local height = math.clamp(state.MobAuraHeight, 3, AURA_KILL_MAX_RANGE - 10)
            local orbitOffset = Vector3.zero
            if state.MobAuraRandomSquare then
                local now = os.clock()
                local interval = math.max(0.06, tonumber(state.MobAuraSquareInterval) or 0.18)
                if state.MobAuraLastSquareStep == 0 or now - state.MobAuraLastSquareStep >= interval then
                    local size = math.max(2, tonumber(state.MobAuraSquareSize) or 8)
                    local nextCorner = math.random(1, 4)
                    if nextCorner == state.MobAuraSquareCorner then
                        nextCorner = nextCorner % 4 + 1
                    end
                    local corners = {
                        Vector3.new(-size, 0, -size),
                        Vector3.new(size, 0, -size),
                        Vector3.new(size, 0, size),
                        Vector3.new(-size, 0, size),
                    }
                    state.MobAuraSquareCorner = nextCorner
                    state.MobAuraSquareOffset = corners[nextCorner]
                    state.MobAuraLastSquareStep = now
                end
                orbitOffset = state.MobAuraSquareOffset
            elseif state.MobAuraOrbit then
                local elapsed = os.clock() - state.MobAuraOrbitStartedAt
                local angle = state.MobAuraOrbitStartAngle
                    + elapsed * math.rad(state.MobAuraOrbitSpeed) * state.MobAuraOrbitDirection
                orbitOffset = Vector3.new(
                    math.cos(angle) * state.MobAuraOrbitRadius,
                    0,
                    math.sin(angle) * state.MobAuraOrbitRadius
                )
            end
            local goalPosition = anchor + Vector3.new(0, height, 0) + orbitOffset
            local facing = Vector3.new(targetRoot.CFrame.LookVector.X, 0, targetRoot.CFrame.LookVector.Z)
            if facing.Magnitude < 0.05 then
                facing = Vector3.new(0, 0, -1)
            else
                facing = facing.Unit
            end

            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            if (state.MobAuraOrbit or state.MobAuraRandomSquare) and orbitOffset.Magnitude > 0.05 then
                root.CFrame = CFrame.lookAt(
                    goalPosition,
                    Vector3.new(anchor.X, goalPosition.Y, anchor.Z)
                )
            else
                root.CFrame = CFrame.lookAt(goalPosition, goalPosition + facing)
            end
            state.MobAuraTargetName = normalizeEnemyName(target.Name)
            state.MobAuraDistance = (targetRoot.Position - root.Position).Magnitude
            state.SelectedMobWaitingAtSpawn = false
            state.CurrentEnemyName = state.MobAuraTargetName
            return true
        end

        local function flushAuraTelemetry()
            gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
            gui:SetAttribute("BloxAuraKillTargets", state.AuraTargetCount)
            gui:SetAttribute("BloxAuraMultiTargetCount", state.AuraMultiTargetCount)
            gui:SetAttribute("BloxAuraKillStage", state.AuraStage)
            gui:SetAttribute("BloxAuraKillRequestCount", state.AuraRequests)
            gui:SetAttribute("BloxAuraKillHitCount", state.AuraHits)
            gui:SetAttribute("BloxAuraSwordRequestCount", state.AuraSwordRequests)
            gui:SetAttribute("BloxAuraFruitRequestCount", state.AuraFruitRequests)
            gui:SetAttribute("BloxAttackCount", state.AuraRequests)
            gui:SetAttribute("BloxAuraWeaponSelection", state.WeaponType)
            gui:SetAttribute("BloxAuraWeaponName", state.AuraWeaponName or "")
            gui:SetAttribute("BloxAuraWeaponType", state.AuraWeaponType or "")
            gui:SetAttribute("BloxAuraAttackMode", state.AuraAttackMode or "")
            gui:SetAttribute("BloxDoubleAttack", state.DoubleAttack)
            gui:SetAttribute("BloxFruitM1CooldownReduction", state.FruitM1CooldownReduction)
            gui:SetAttribute(
                "BloxAuraFruitNativeRange",
                state.DoubleAttack and DoubleAttackEngine.HitRange or NATIVE_FRUIT_MAX_RANGE
            )
            gui:SetAttribute("BloxAuraFruitInRange", state.AuraFruitInRange == true)
            gui:SetAttribute("BloxAuraFruitLastDistance", state.AuraFruitLastDistance or 0)
            if state.CurrentEnemyName then
                gui:SetAttribute("BloxAuraKillLastTarget", state.CurrentEnemyName)
            end
            if state.AuraLastDistance then
                gui:SetAttribute("BloxAuraKillLastDistance", state.AuraLastDistance)
            end
            if state.AuraLastRequestAt then
                gui:SetAttribute("BloxAuraKillLastRequestAt", state.AuraLastRequestAt)
                gui:SetAttribute("BloxLastAttackAt", state.AuraLastRequestAt)
            end
            if state.AuraLastHitAt then
                gui:SetAttribute("BloxAuraKillLastHitAt", state.AuraLastHitAt)
            end
            gui:SetAttribute("BloxMobAuraTp", state.MobAuraTp)
            gui:SetAttribute("BloxSelectedMobFarm", state.SelectedMobFarm)
            gui:SetAttribute("BloxSelectedMobName", state.SelectedMobName)
            gui:SetAttribute("BloxSelectedMobSearchRange", state.SelectedMobSearchRange)
            gui:SetAttribute("BloxSelectedMobWaitingAtSpawn", state.SelectedMobWaitingAtSpawn)
            gui:SetAttribute("BloxMobAuraMode", state.SelectedMobFarm and "Selected" or (state.MobAuraTp and "Nearest" or "Off"))
            gui:SetAttribute("BloxMobAuraHeight", state.MobAuraHeight)
            gui:SetAttribute("BloxMobAuraSearchRange", state.MobAuraSearchRange)
            gui:SetAttribute("BloxMobAuraOrbit", state.MobAuraOrbit)
            gui:SetAttribute("BloxMobAuraOrbitRadius", state.MobAuraOrbitRadius)
            gui:SetAttribute("BloxMobAuraOrbitSpeed", state.MobAuraOrbitSpeed)
            gui:SetAttribute("BloxMobAuraOrbitDirection", state.MobAuraOrbitDirection)
            gui:SetAttribute("BloxMobAuraRandomSquare", state.MobAuraRandomSquare)
            gui:SetAttribute("BloxMobAuraSquareSize", state.MobAuraSquareSize)
            gui:SetAttribute("BloxMobAuraSquareInterval", state.MobAuraSquareInterval)
            gui:SetAttribute("BloxMobAuraTarget", state.MobAuraTargetName or "")
            gui:SetAttribute("BloxMobAuraDistance", state.MobAuraDistance or 0)
            gui:SetAttribute("BloxMultiGrabEnemies", state.GatherEnemies)
            gui:SetAttribute("BloxMultiGrabFilter", state.GatherMode)
            gui:SetAttribute("BloxMultiGrabEnemy", state.GatherSelectedMob)
            gui:SetAttribute("BloxMultiGrabLimit", MULTI_GRAB_LIMIT)
            gui:SetAttribute("BloxMultiGrabRange", MULTI_GRAB_RANGE)
            gui:SetAttribute("BloxMultiGrabCount", state.Gathered)
            gui:SetAttribute("BloxRaidMultiGrab", state.RaidMultiGrab)
            gui:SetAttribute("BloxRaidMultiGrabCount", state.RaidGathered)
            gui:SetAttribute("BloxRaidVoidKill", state.RaidVoidKill)
            gui:SetAttribute("BloxRaidVoidActive", state.RaidVoidActive)
            gui:SetAttribute("BloxRaidVoidMoved", state.RaidVoidMoved)
            gui:SetAttribute("BloxRaidVoidStaged", state.RaidVoidStaged)
            gui:SetAttribute("BloxRaidVoidKillCount", state.RaidVoidKillCount)
            gui:SetAttribute("BloxRaidSafeHeight", state.RaidSafeHeight)
            gui:SetAttribute(
                "BloxMultiGrabSingleFallback",
                state.GatherSingleFallbackEnemy and normalizeEnemyName(state.GatherSingleFallbackEnemy.Name) or ""
            )
            gui:SetAttribute("BloxSelectedLevelQuest", state.SelectedLevelQuest)
            gui:SetAttribute("BloxCurrentSea", state.CurrentSeaName)
            gui:SetAttribute("BloxCurrentSeaQuestCount", state.CurrentSeaQuestCount)
            gui:SetAttribute("BloxCurrentSeaMinimumLevel", state.CurrentSeaMinimumLevel)
            gui:SetAttribute("BloxCurrentSeaMaximumLevel", state.CurrentSeaMaximumLevel)
            gui:SetAttribute("BloxAutoBoss", state.AutoBoss)
            gui:SetAttribute("BloxBossVerticalLocked", state.AutoBoss and state.PositionLockVertical)
            gui:SetAttribute("BloxBossAnchorY", state.PositionAnchorY or 0)
            gui:SetAttribute("BloxAutoGacha", state.AutoGacha)
            gui:SetAttribute("BloxGachaRetrySeconds", state.GachaInterval)
            gui:SetAttribute("BloxGachaBusy", state.GachaBusy)
            gui:SetAttribute("BloxGachaRollCount", state.GachaRolls)
            gui:SetAttribute("BloxGachaStatus", state.GachaStatus)
            gui:SetAttribute("BloxAutoStoreFruit", state.AutoStoreFruit)
            gui:SetAttribute("BloxFruitStoreBusy", state.InventoryBusy)
            gui:SetAttribute("BloxFruitStoredCount", state.FruitsStored)
            gui:SetAttribute("BloxFruitStoreStatus", state.StoreStatus)
            if state.AuraPendingError then
                local message = state.AuraPendingError
                state.AuraPendingError = nil
                setError(message)
            end
        end

        local function currentLevel()
            local data = LocalPlayer:FindFirstChild("Data")
            local level = data and data:FindFirstChild("Level")
            return level and tonumber(level.Value) or 0
        end

        local function currentPoints()
            local data = LocalPlayer:FindFirstChild("Data")
            local points = data and data:FindFirstChild("Points")
            return points and tonumber(points.Value) or 0
        end

        local function questNpcData(internalQuestName)
            local npcList = Guide and Guide.Data and Guide.Data.NPCList
            if type(npcList) ~= "table" then
                return nil
            end
            for _, data in pairs(npcList) do
                if type(data) == "table" and data.InternalQuestName == internalQuestName then
                    return data
                end
            end
            return nil
        end

        local AUTO_LEVEL_BEST_OPTION = "Best for My Level"
        local levelQuestByOption = {}

        local function questCandidate(internalName, index, quest)
            if type(quest) ~= "table" or type(quest.LevelReq) ~= "number" then
                return nil
            end
            local enemyName = type(quest.Task) == "table" and next(quest.Task) or nil
            if not enemyName then
                return nil
            end
            return {
                InternalName = internalName,
                Index = tonumber(index) or index,
                LevelReq = quest.LevelReq,
                DisplayName = tostring(quest.Name or enemyName),
                EnemyName = tostring(enemyName),
                Npc = questNpcData(internalName),
            }
        end

        local function bestQuest()
            local level = currentLevel()
            local best = nil
            for internalName, questList in pairs(Quests) do
                if type(questList) == "table" then
                    for index, quest in pairs(questList) do
                        local candidate = questCandidate(internalName, index, quest)
                        -- GuideModule only exposes quest givers from the current
                        -- sea. Requiring Npc prevents Auto Level from selecting a
                        -- higher-level quest whose giver exists in another sea.
                        if candidate and candidate.Npc and candidate.LevelReq <= level then
                            local candidateBoss = string.find(candidate.EnemyName, "Boss", 1, true) ~= nil
                            local bestBoss = best and string.find(best.EnemyName, "Boss", 1, true) ~= nil
                            if not best
                                or candidate.LevelReq > best.LevelReq
                                or (candidate.LevelReq == best.LevelReq and bestBoss and not candidateBoss) then
                                best = candidate
                            end
                        end
                    end
                end
            end
            return best
        end

        local function currentSeaQuestOptions()
            local options = {AUTO_LEVEL_BEST_OPTION}
            local candidates = {}
            local minimumLevel = math.huge
            local maximumLevel = 0
            table.clear(levelQuestByOption)
            for internalName, questList in pairs(Quests) do
                if type(questList) == "table" then
                    for index, quest in pairs(questList) do
                        local candidate = questCandidate(internalName, index, quest)
                        if candidate and candidate.Npc then
                            table.insert(candidates, candidate)
                            if candidate.LevelReq > 0 then
                                minimumLevel = math.min(minimumLevel, candidate.LevelReq)
                                maximumLevel = math.max(maximumLevel, candidate.LevelReq)
                            end
                        end
                    end
                end
            end
            table.sort(candidates, function(left, right)
                if left.LevelReq == right.LevelReq then
                    return string.lower(left.EnemyName) < string.lower(right.EnemyName)
                end
                return left.LevelReq < right.LevelReq
            end)
            for _, candidate in ipairs(candidates) do
                local label = string.format("Lv. %d | %s", candidate.LevelReq, candidate.EnemyName)
                if levelQuestByOption[label] then
                    label = string.format(
                        "Lv. %d | %s (%s:%s)",
                        candidate.LevelReq,
                        candidate.EnemyName,
                        candidate.InternalName,
                        tostring(candidate.Index)
                    )
                end
                levelQuestByOption[label] = candidate
                table.insert(options, label)
            end
            state.CurrentSeaQuestCount = #candidates
            state.CurrentSeaMinimumLevel = minimumLevel == math.huge and 0 or minimumLevel
            state.CurrentSeaMaximumLevel = maximumLevel
            if #candidates == 0 then
                state.CurrentSeaName = "Detecting"
            elseif maximumLevel <= 700 then
                state.CurrentSeaName = "First Sea"
            elseif state.CurrentSeaMinimumLevel >= 1500 then
                state.CurrentSeaName = "Third Sea"
            else
                state.CurrentSeaName = "Second Sea"
            end
            gui:SetAttribute("BloxCurrentSea", state.CurrentSeaName)
            gui:SetAttribute("BloxCurrentSeaQuestCount", state.CurrentSeaQuestCount)
            gui:SetAttribute("BloxCurrentSeaMinimumLevel", state.CurrentSeaMinimumLevel)
            gui:SetAttribute("BloxCurrentSeaMaximumLevel", state.CurrentSeaMaximumLevel)
            return options
        end

        local function selectedLevelQuest()
            if state.SelectedLevelQuest == AUTO_LEVEL_BEST_OPTION then
                return bestQuest()
            end
            local selected = levelQuestByOption[state.SelectedLevelQuest]
            if not selected then
                currentSeaQuestOptions()
                selected = levelQuestByOption[state.SelectedLevelQuest]
            end
            return selected
        end

        local function questVisible()
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local main = playerGui and playerGui:FindFirstChild("Main")
            local quest = main and main:FindFirstChild("Quest")
            return quest and quest.Visible == true, quest
        end

        local function questMatches(questGui, enemyName)
            if not questGui then
                return false
            end
            local lowered = string.lower(normalizeEnemyName(enemyName))
            local sawText = false
            for _, descendant in ipairs(questGui:GetDescendants()) do
                if descendant:IsA("TextLabel") and descendant.Text ~= "" then
                    sawText = true
                    if string.find(string.lower(descendant.Text), lowered, 1, true) then
                        return true
                    end
                end
            end
            return not sawText
        end

        local function enemySpawn(enemyName)
            return nearestEnemySpawn(enemyName)
        end

        local function stepAutoLevel()
            state.ActiveFarmHeightOverride = nil
            local quest = selectedLevelQuest()
            if not quest then
                state.ActiveFarmTarget = nil
                setError("Choose a valid quest available in this sea")
                return
            end
            state.CurrentQuestName = quest.DisplayName
            state.CurrentEnemyName = quest.EnemyName
            questLabel.Text = string.format("Quest: %s (Lv. %s)", quest.DisplayName, tostring(quest.LevelReq))

            local visible, questGui = questVisible()
            if visible and not questMatches(questGui, quest.EnemyName) then
                if os.clock() - state.LastQuestRequest >= 1 then
                    state.LastQuestRequest = os.clock()
                    invoke("AbandonQuest")
                end
                return
            end

            if not visible then
                local npcPosition = quest.Npc and quest.Npc.Position
                if typeof(npcPosition) ~= "Vector3" then
                    setError("Quest giver data is still loading")
                    return
                end
                local root = rootPart()
                local target = CFrame.new(npcPosition + Vector3.new(0, 3, 0))
                moveTo(target)
                if root and (root.Position - npcPosition).Magnitude <= 18 and os.clock() - state.LastQuestRequest >= 1 then
                    state.LastQuestRequest = os.clock()
                    local ok, result = invoke("StartQuest", quest.InternalName, quest.Index)
                    setStatus(ok and ("Started " .. quest.DisplayName) or tostring(result), ok)
                end
                return
            end

            local enemy, distance = nearestEnemy(quest.EnemyName, false)
            if enemy then
                state.ActiveFarmTarget = enemy
                state.ActiveFarmVerticalLock = false
                targetLabel.Text = string.format("Target: %s | %.0f studs", normalizeEnemyName(enemy.Name), distance or 0)
                if safeModeRetreat(enemy) then
                    return
                end
                syncFarmAuraRange()
                local targetCFrame = positionAtEnemy(enemy)
                if targetCFrame then
                    moveToFarmPosition(targetCFrame)
                end
                setStatus("Farming " .. normalizeEnemyName(enemy.Name), true)
                return
            end

            state.ActiveFarmTarget = nil
            local spawn = enemySpawn(quest.EnemyName)
            if spawn then
                targetLabel.Text = "Target: Waiting at " .. normalizeEnemyName(spawn.Name) .. " spawn"
                moveTo(CFrame.new(spawn.Position + Vector3.new(0, math.max(5, state.MobAuraHeight), 0)))
                setStatus("Waiting for quest enemies to spawn", nil)
            else
                setError("Enemy spawn data is still loading")
            end
        end

        local function bossNames()
            local names = {"None"}
            local seen = {None = true}
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            if spawns then
                for _, descendant in ipairs(spawns:GetDescendants()) do
                    if descendant:IsA("BasePart") and string.find(descendant.Name, "[Boss]", 1, true) then
                        local name = normalizeEnemyName(descendant.Name)
                        if name ~= "" and not seen[name] then
                            seen[name] = true
                            table.insert(names, name)
                        end
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    if string.find(enemy.Name, "[Boss]", 1, true) then
                        local name = normalizeEnemyName(enemy.Name)
                        if name ~= "" and not seen[name] then
                            seen[name] = true
                            table.insert(names, name)
                        end
                    end
                end
            end
            table.sort(names, function(left, right)
                if left == "None" then
                    return true
                end
                if right == "None" then
                    return false
                end
                return string.lower(left) < string.lower(right)
            end)
            return names
        end

        local function stepBossFarm()
            state.ActiveFarmHeightOverride = nil
            if state.SelectedBoss == "None" then
                state.ActiveFarmTarget = nil
                setError("Choose a boss first")
                return
            end
            state.CurrentEnemyName = state.SelectedBoss
            local enemy, distance = nearestEnemy(state.SelectedBoss, false)
            if enemy then
                state.ActiveFarmTarget = enemy
                state.ActiveFarmVerticalLock = true
                targetLabel.Text = string.format("Boss: %s | %.0f studs", state.SelectedBoss, distance or 0)
                if safeModeRetreat(enemy) then
                    return
                end
                syncFarmAuraRange()
                local targetCFrame = positionAtEnemy(enemy, true)
                if targetCFrame then
                    moveToFarmPosition(targetCFrame)
                end
                setStatus("Farming boss " .. state.SelectedBoss, true)
                return
            end
            state.ActiveFarmTarget = nil
            local spawn = enemySpawn(state.SelectedBoss)
            if spawn then
                moveTo(CFrame.new(spawn.Position + Vector3.new(0, 8, 0)))
                setStatus("Waiting for " .. state.SelectedBoss .. " to spawn", nil)
            else
                setError("Boss spawn is unavailable in this sea")
            end
        end

        local function loadedEnemies()
            local enemies = workspace:FindFirstChild("Enemies")
            return enemies and enemies:GetChildren() or {}
        end

        local RaidRuntime = {}

        function RaidRuntime.IslandParts()
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local locations = origin and origin:FindFirstChild("Locations")
            local islands = {}
            if not locations then
                return islands
            end
            for _, child in ipairs(locations:GetChildren()) do
                local index = tonumber(string.match(string.lower(child.Name), "^island%s*(%d+)$"))
                local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
                if index and index >= 1 and index <= 5 and part then
                    table.insert(islands, {
                        Index = index,
                        Name = child.Name,
                        Part = part,
                    })
                end
            end
            table.sort(islands, function(left, right)
                return left.Index < right.Index
            end)
            return islands
        end

        function RaidRuntime.Active()
            -- Numbered island markers are shared across the server, so another
            -- player's raid can leave Island 1 visible tens of thousands of
            -- studs away. Prefer the local raid state; otherwise Auto Raid
            -- happily kidnaps the player into somebody else's dungeon.
            local islandRaiding = LocalPlayer:GetAttribute("IslandRaiding")
            if islandRaiding ~= nil then
                return islandRaiding == true
            end
            local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            local main = playerGui and playerGui:FindFirstChild("Main")
            local timer = main and (main:FindFirstChild("Timer")
                or (main:FindFirstChild("TopHUDList") and main.TopHUDList:FindFirstChild("RaidTimer")))
            if timer and timer:IsA("GuiObject") then
                return timer.Visible == true
            end
            return #RaidRuntime.IslandParts() > 0
        end

        function RaidRuntime.LatestIsland()
            if not RaidRuntime.Active() then
                return nil
            end
            local islands = RaidRuntime.IslandParts()
            return islands[#islands]
        end

        function RaidRuntime.NearestEnemy(island)
            local root = rootPart()
            if not root then
                return nil, math.huge
            end
            local nearest = nil
            local nearestDistance = math.huge
            for _, enemy in ipairs(loadedEnemies()) do
                local enemyRoot = modelRoot(enemy)
                if enemyRoot and modelAlive(enemy) then
                    local insideRaidArea = not island
                        or (enemyRoot.Position - island.Part.Position).Magnitude <= 2500
                    local distance = (enemyRoot.Position - root.Position).Magnitude
                    if insideRaidArea and distance < nearestDistance then
                        nearest = enemy
                        nearestDistance = distance
                    end
                end
            end
            return nearest, nearestDistance
        end

        function RaidRuntime.RaidChip()
            for _, container in ipairs({character(), LocalPlayer:FindFirstChildOfClass("Backpack")}) do
                if container then
                    for _, child in ipairs(container:GetChildren()) do
                        if child:IsA("Tool") then
                            local name = string.lower(child.Name)
                            if string.find(name, "microchip", 1, true)
                                or string.find(name, "raid chip", 1, true) then
                                return child
                            end
                        end
                    end
                end
            end
            return nil
        end

        function RaidRuntime.StartStation()
            local map = workspace:FindFirstChild("Map")
            local root = rootPart()
            if not map or not root then
                return nil
            end
            local bestYellow = nil
            local bestDetector = nil
            local bestDistance = math.huge
            for _, station in ipairs(map:GetDescendants()) do
                if station:IsA("Model") and station.Name == "RaidSummon2" then
                    local mainRaid = station:FindFirstChild("MainRaid")
                    local yellow = mainRaid and (mainRaid:FindFirstChild("Color")
                        or mainRaid:FindFirstChildWhichIsA("BasePart"))
                    local button = station:FindFirstChild("Button")
                    local buttonPart = button and (button:FindFirstChild("Main")
                        or button:FindFirstChildWhichIsA("BasePart"))
                    local detector = buttonPart and buttonPart:FindFirstChildOfClass("ClickDetector")
                    if yellow and yellow:IsA("BasePart") and detector then
                        local distance = (yellow.Position - root.Position).Magnitude
                        if distance < bestDistance then
                            bestYellow = yellow
                            bestDetector = detector
                            bestDistance = distance
                        end
                    end
                end
            end
            return bestYellow, bestDetector, bestDistance
        end

        function RaidRuntime.VoidKillStep(island)
            local enabled = state.AutoRaid
                and state.RaidVoidKill
                and RaidRuntime.Active()
                and island
                and island.Index >= 5
            if not enabled then
                for enemy, originalCFrame in pairs(state.RaidVoidOriginalCFrames) do
                    local enemyRoot = modelRoot(enemy)
                    local enemyBody = enemy:FindFirstChildOfClass("Humanoid")
                    if enemyRoot and enemyBody and enemyBody.Health > 0 then
                        pcall(function()
                            enemyBody.PlatformStand = false
                            enemyRoot.CFrame = originalCFrame
                            enemyRoot.AssemblyLinearVelocity = Vector3.zero
                            enemyRoot.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                end
                table.clear(state.RaidVoidOriginalCFrames)
                state.RaidVoidActive = false
                state.RaidVoidMoved = 0
                state.RaidVoidStaged = 0
                return 0
            end
            state.RaidVoidActive = true
            if os.clock() - state.LastRaidVoidStep < 0.06 then
                return state.RaidVoidMoved
            end
            state.LastRaidVoidStep = os.clock()
            pcall(function()
                if type(sethiddenproperty) == "function" then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                end
            end)
            local playerRoot = rootPart()
            if not playerRoot then
                state.RaidVoidMoved = 0
                state.RaidVoidStaged = 0
                return 0
            end
            -- Solix's live Island 5 sequence is ownership-gated, not a raw void
            -- teleport: a full-health raid boss becomes network-owned, Health
            -- reaches server-visible zero, and the replicated corpse then falls
            -- naturally for several seconds before removal.
            local killed = 0
            local waitingForOwnership = 0
            for _, enemy in ipairs(loadedEnemies()) do
                local enemyRoot = modelRoot(enemy)
                local enemyBody = enemy:FindFirstChildOfClass("Humanoid")
                if enemyRoot and enemyBody and enemyBody.Health > 0
                    and (enemyRoot.Position - island.Part.Position).Magnitude <= 2500 then
                    local owned = false
                    if type(isnetworkowner) == "function" then
                        local ownerOk, ownerResult = pcall(isnetworkowner, enemyRoot)
                        owned = ownerOk and ownerResult == true
                    end
                    local actionOk = pcall(function()
                        if owned then
                            enemyBody.Health = -9e9
                        end
                    end)
                    if owned and actionOk then
                        if not state.RaidVoidTargets[enemy] then
                            state.RaidVoidTargets[enemy] = true
                            state.RaidVoidKillCount += 1
                        end
                        killed += 1
                    else
                        waitingForOwnership += 1
                    end
                end
            end
            state.RaidVoidMoved = killed
            state.RaidVoidStaged = waitingForOwnership
            state.RaidGathered = 0
            return killed
        end

        local function fireRaidButton()
            if type(fireclickdetector) ~= "function" then
                return false, "fireclickdetector is unavailable"
            end
            if RaidRuntime.Active() then
                return true, "Raid is already active"
            end
            local root = rootPart()
            if not root then
                return false, "Character is unavailable"
            end
            local chip = RaidRuntime.RaidChip()
            if not chip then
                return false, "No raid microchip found; buy one first"
            end
            local yellow, detector, distance = RaidRuntime.StartStation()
            if not yellow or not detector then
                moveTo(state.RaidCastleStart)
                return true, "Moving to Castle on the Sea raid room"
            end
            local standingCFrame = CFrame.new(
                yellow.Position + Vector3.new(0, yellow.Size.Y * 0.5 + 2.8, 0)
            )
            if distance > 7 then
                moveTo(standingCFrame)
                return true, "Moving to the nearest yellow raid pad"
            end
            cancelMove(false)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = standingCFrame
            local body = humanoid()
            if body and chip.Parent ~= character() then
                pcall(function()
                    body:EquipTool(chip)
                end)
            end
            if type(firetouchinterest) == "function" then
                pcall(firetouchinterest, root, yellow, 0)
                pcall(firetouchinterest, root, yellow, 1)
            end
            task.wait(0.15)
            local ok, result = pcall(fireclickdetector, detector)
            return ok, ok and "Green raid button activated" or result
        end

        local function stepRaid()
            local island = RaidRuntime.LatestIsland()
            if not island then
                state.ActiveFarmTarget = nil
                state.ActiveFarmHeightOverride = nil
                state.RaidIslandIndex = 0
                state.RaidIslandName = nil
                state.RaidTargetName = nil
                RaidRuntime.VoidKillStep(nil)
                raidLabel.Text = "Dungeon / Raid: Waiting to start"
                return
            end
            local entryRemaining = state.RaidEntryGrace - (os.clock() - state.RaidEnteredAt)
            if state.RaidEnteredAt > 0 and entryRemaining > 0 then
                state.ActiveFarmTarget = nil
                state.ActiveFarmHeightOverride = nil
                state.RaidIslandIndex = 0
                state.RaidIslandName = nil
                state.RaidTargetName = nil
                RaidRuntime.VoidKillStep(nil)
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Waiting for server teleport | %.1fs",
                    entryRemaining
                )
                return
            end
            state.RaidIslandIndex = island.Index
            state.RaidIslandName = island.Name
            local safeHeight = math.max(state.RaidSafeHeight, tonumber(state.MobAuraHeight) or 20)
            state.ActiveFarmHeightOverride = safeHeight
            local voided = RaidRuntime.VoidKillStep(island)
            if state.RaidVoidActive then
                state.ActiveFarmTarget = nil
                state.ActiveFarmVerticalLock = false
                state.RaidTargetName = nil
                moveTo(island.Part.CFrame + Vector3.new(0, safeHeight, 0))
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Island %d FORCE KILL | Waiting ownership: %d | Killed: %d | Total: %d",
                    island.Index,
                    state.RaidVoidStaged,
                    voided,
                    state.RaidVoidKillCount
                )
                return
            end
            local enemy, distance = RaidRuntime.NearestEnemy(island)
            if enemy then
                state.ActiveFarmTarget = enemy
                state.ActiveFarmVerticalLock = true
                state.CurrentEnemyName = normalizeEnemyName(enemy.Name)
                state.RaidTargetName = state.CurrentEnemyName
                if healthPercent() <= 50 then
                    state.ActiveFarmTarget = nil
                    local enemyRoot = modelRoot(enemy)
                    if enemyRoot then
                        local retreatHeight = math.max(55, safeHeight + 15)
                        moveTo(CFrame.lookAt(
                            enemyRoot.Position + Vector3.new(0, retreatHeight, 0),
                            enemyRoot.Position
                        ))
                    end
                    raidLabel.Text = string.format(
                        "Dungeon / Raid: Emergency recovery at %.0f%% health",
                        healthPercent()
                    )
                    return
                end
                if safeModeRetreat(enemy) then
                    raidLabel.Text = "Dungeon / Raid: Safe mode recovery"
                    return
                end
                syncFarmAuraRange(safeHeight)
                local targetCFrame = positionAtEnemy(enemy, true, safeHeight)
                if targetCFrame then
                    moveToFarmPosition(targetCFrame)
                end
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Island %d | Attacking %s | %.0f studs",
                    island.Index,
                    normalizeEnemyName(enemy.Name),
                    distance or 0
                )
            else
                state.ActiveFarmTarget = nil
                state.RaidTargetName = nil
                raidLabel.Text = string.format(
                    "Dungeon / Raid: Moving to latest island %d",
                    island.Index
                )
                moveTo(island.Part.CFrame + Vector3.new(0, safeHeight, 0))
            end
        end

        local function gatherStep()
            local now = os.clock()
            if now - state.LastGatherScan < 0.08 then
                return
            end
            state.LastGatherScan = now
            local root = rootPart()
            if not root then
                return
            end
            local raidIsland = state.AutoRaid and RaidRuntime.LatestIsland() or nil
            local raidVoidActive = state.RaidVoidKill and raidIsland and raidIsland.Index >= 5
            local raidGatherEnabled = state.RaidMultiGrab and state.AutoRaid
                and RaidRuntime.Active() and not raidVoidActive
            local multiGrabEnabled = state.GatherEnemies or raidGatherEnabled
            local enabled = not raidVoidActive and (
                multiGrabEnabled
                or (state.AutoMagnet and (state.AutoFarmLevel or state.AutoBoss or state.AutoRaid))
            )
            if not enabled then
                state.Gathered = 0
                state.RaidGathered = 0
                state.GatherSingleFallbackEnemy = nil
                for enemy, originalCFrame in pairs(state.GatherOriginalCFrames) do
                    local enemyRoot = modelRoot(enemy)
                    if enemyRoot and modelAlive(enemy) then
                        pcall(function()
                            enemyRoot.CFrame = originalCFrame
                        end)
                    end
                end
                table.clear(state.GatherOriginalCFrames)
                return
            end
            pcall(function()
                if type(sethiddenproperty) == "function" then
                    sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
                end
            end)
            local gatherRange = multiGrabEnabled and MULTI_GRAB_RANGE or state.MagnetRange
            local targetName = raidGatherEnabled and nil
                or (state.GatherEnemies and selectedGatherEnemyName() or state.CurrentEnemyName)
            -- Stack every grabbed NPC directly underneath the player. This
            -- keeps the pile inside Aura range while the player remains above
            -- it instead of dragging the enemies in front of the character.
            local targetCFrame = CFrame.new(root.Position - Vector3.new(0, state.GatherDistance, 0))
            local candidates = {}
            for _, enemy in ipairs(loadedEnemies()) do
                local enemyRoot = modelRoot(enemy)
                local distance = enemyRoot and (enemyRoot.Position - root.Position).Magnitude or math.huge
                local insideRaid = not raidGatherEnabled or (
                    raidIsland and enemyRoot
                        and (enemyRoot.Position - raidIsland.Part.Position).Magnitude <= 2500
                )
                if enemyRoot and modelAlive(enemy) and distance <= gatherRange and insideRaid then
                    if not targetName or enemyMatches(enemy, targetName) then
                        table.insert(candidates, {Enemy = enemy, Root = enemyRoot, Distance = distance})
                    end
                end
            end
            table.sort(candidates, function(left, right)
                return left.Distance < right.Distance
            end)
            if multiGrabEnabled then
                for _, candidate in ipairs(candidates) do
                    if state.GatherOriginalCFrames[candidate.Enemy] == nil then
                        state.GatherOriginalCFrames[candidate.Enemy] = candidate.Root.CFrame
                    end
                end
                if #candidates == 1 then
                    local remaining = candidates[1]
                    local originalCFrame = state.GatherOriginalCFrames[remaining.Enemy]
                    if originalCFrame then
                        pcall(function()
                            remaining.Root.CFrame = originalCFrame
                            remaining.Root.AssemblyLinearVelocity = Vector3.zero
                            remaining.Root.AssemblyAngularVelocity = Vector3.zero
                        end)
                    end
                    state.GatherSingleFallbackEnemy = remaining.Enemy
                    state.MobAuraAnchorTarget = nil
                    state.MobAuraStableAnchor = nil
                    state.Gathered = 0
                    return
                elseif #candidates > 1 then
                    state.GatherSingleFallbackEnemy = nil
                elseif not modelAlive(state.GatherSingleFallbackEnemy) then
                    state.GatherSingleFallbackEnemy = nil
                end
            end
            local gathered = 0
            local limit = multiGrabEnabled and MULTI_GRAB_LIMIT or math.huge
            for index, candidate in ipairs(candidates) do
                if index > limit then
                    break
                end
                pcall(function()
                    candidate.Root.CFrame = targetCFrame
                    candidate.Root.AssemblyLinearVelocity = Vector3.zero
                    candidate.Root.AssemblyAngularVelocity = Vector3.zero
                end)
                gathered += 1
            end
            state.Gathered = gathered
            state.RaidGathered = raidGatherEnabled and gathered or 0
        end

        state.SeaEvent.BoatNames = {
            "Guardian",
            "Pirate Grand Brigade",
            "Marine Grand Brigade",
            "Pirate Brigade",
            "Marine Brigade",
            "Pirate Sloop",
            "Marine Sloop",
            "Beast Hunter",
            "Lantern",
            "Miracle",
            "Sentinel",
            "Sleigh",
        }
        state.SeaEvent.BoatPurchaseNames = {
            ["Guardian"] = "Guardian",
            ["Pirate Grand Brigade"] = "PirateGrandBrigade",
            ["Marine Grand Brigade"] = "MarineGrandBrigade",
            ["Pirate Brigade"] = "PirateBrigade",
            ["Marine Brigade"] = "MarineBrigade",
            ["Pirate Sloop"] = "PirateBasic",
            ["Marine Sloop"] = "MarineBasic",
            ["Beast Hunter"] = "BeastHunter",
            ["Lantern"] = "Lantern",
            ["Miracle"] = "Miracle",
            ["Sentinel"] = "Sentinel",
            ["Sleigh"] = "Sleigh",
        }
        state.SeaEvent.SkillKeys = {
            Enum.KeyCode.Z,
            Enum.KeyCode.X,
            Enum.KeyCode.C,
            Enum.KeyCode.V,
            Enum.KeyCode.F,
        }
        state.SeaEvent.StopConditionPatterns = {
            ["Kitsune Island"] = {"kitsune island", "kitsune shrine"},
            ["Prehistoric Island"] = {"prehistoric island", "prehistoric"},
            ["Mirage Island"] = {"mirage island", "mystic island"},
            ["Frozen Dimension"] = {"frozen dimension", "frozen island"},
        }
        state.SeaEvent.TransformationSkillKeys = {
            ["kitsune"] = {V = true},
            ["leopard"] = {V = true},
            ["mammoth"] = {V = true},
            ["t-rex"] = {V = true},
            ["trex"] = {V = true},
            ["dragon"] = {V = true},
            ["gas"] = {V = true},
            ["yeti"] = {V = true},
            ["phoenix"] = {V = true},
            ["buddha"] = {Z = true},
            ["venom"] = {F = true},
            ["falcon"] = {Z = true},
        }
        state.SeaEvent.DangerDistanceFn = safeRequire(ReplicatedStorage:FindFirstChild("DangerDistance"))
        state.SeaEvent.GetDangerLevelFn = safeRequire(
            ReplicatedStorage:FindFirstChild("Util")
                and ReplicatedStorage.Util:FindFirstChild("GetDangerLevel")
        )

        function state.SeaEvent.TargetPart(target)
            if not target or not target.Parent then
                return nil
            end
            if target:IsA("BasePart") then
                return target
            end
            return (target:IsA("Model") and target.PrimaryPart or nil)
                or target:FindFirstChild("HumanoidRootPart", true)
                or target:FindFirstChild("RootPart", true)
                or target:FindFirstChild("Engine", true)
                or target:FindFirstChildWhichIsA("BasePart", true)
        end

        function state.SeaEvent.Health(target)
            if not target then
                return nil, nil
            end
            local body = target:FindFirstChildWhichIsA("Humanoid", true)
            if body then
                return body.Health, body.MaxHealth
            end
            for _, name in ipairs({"Humanoid", "Health", "HP"}) do
                local value = target:FindFirstChild(name, true)
                if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
                    local maximum = tonumber(target:GetAttribute("MaxHealth"))
                        or tonumber(target:GetAttribute("OriginalMaxHealth"))
                        or tonumber(value:GetAttribute("MaxHealth"))
                    return tonumber(value.Value), maximum
                end
            end
            local health = tonumber(target:GetAttribute("Health")) or tonumber(target:GetAttribute("HP"))
            local maximum = tonumber(target:GetAttribute("MaxHealth"))
            return health, maximum
        end

        function state.SeaEvent.IsAlive(target)
            if not target or not target.Parent then
                return false
            end
            local health = state.SeaEvent.Health(target)
            return health == nil or health > 0
        end

        function state.SeaEvent.Kind(target, sourceName)
            local name = string.lower(tostring(target and target.Name or ""))
            local fullName = string.lower(tostring(target and target:GetFullName() or ""))
            local combined = name .. " " .. fullName .. " " .. string.lower(tostring(sourceName or ""))
            if combined:find("leviathan", 1, true) then
                return "Sea Beast", 3
            end
            if combined:find("terror shark", 1, true) or combined:find("terrorshark", 1, true) then
                return "Terror Shark", 1
            end
            if combined:find("sea beast", 1, true)
                or combined:find("seabeast", 1, true)
                or string.lower(tostring(sourceName or "")) == "seabeasts" then
                return "Sea Beast", 2
            end
            if combined:find("piranha", 1, true) then
                return "Piranha", 4
            end
            if combined:find("shark", 1, true) then
                return "Shark", 4
            end
            if combined:find("fish crew", 1, true) then
                return "Fish Crew Member", 5
            end
            if combined:find("ship", 1, true)
                or combined:find("boat", 1, true)
                or combined:find("brigade", 1, true) then
                return "Enemy Boat", 6
            end
            return "Sea Event", 7
        end

        function state.SeaEvent.FindTarget()
            local origin = rootPart()
            local boat = state.SeaEvent.Boat
            local originPosition = origin and origin.Position
                or (boat and boat.Parent and boat:GetPivot().Position)
            if not originPosition then
                return nil
            end
            local candidates = {}
            local seen = setmetatable({}, {__mode = "k"})
            local function addCandidate(candidate, sourceName)
                if not candidate or seen[candidate] or candidate == boat then
                    return
                end
                local part = state.SeaEvent.TargetPart(candidate)
                local kind, priority = state.SeaEvent.Kind(candidate, sourceName)
                local allowed = state.SeaEvent.SelectedEvents[kind] == true
                if part and allowed and state.SeaEvent.IsAlive(candidate) then
                    seen[candidate] = true
                    table.insert(candidates, {
                        Target = candidate,
                        Part = part,
                        Kind = kind,
                        Priority = priority,
                        Distance = (part.Position - originPosition).Magnitude,
                    })
                end
            end

            for _, folderName in ipairs({"SeaBeasts", "SeaEvents"}) do
                local folder = workspace:FindFirstChild(folderName)
                if folder then
                    for _, child in ipairs(folder:GetChildren()) do
                        addCandidate(child, folderName)
                    end
                end
            end
            local enemies = workspace:FindFirstChild("Enemies")
            if enemies then
                for _, enemy in ipairs(enemies:GetChildren()) do
                    local lowered = string.lower(enemy.Name)
                    if lowered:find("terror", 1, true)
                        or lowered:find("shark", 1, true)
                        or lowered:find("piranha", 1, true)
                        or lowered:find("fish crew", 1, true)
                        or lowered:find("sea beast", 1, true) then
                        addCandidate(enemy, "Enemies")
                    end
                end
            end
            table.sort(candidates, function(left, right)
                if left.Priority == right.Priority then
                    return left.Distance < right.Distance
                end
                return left.Priority < right.Priority
            end)
            return candidates[1]
        end

        function state.SeaEvent.OwnedBoat()
            local boats = workspace:FindFirstChild("Boats")
            if not boats then
                return nil
            end
            for _, boat in ipairs(boats:GetChildren()) do
                local owner = boat:FindFirstChild("Owner")
                if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then
                    return boat
                end
            end
            return nil
        end

        function state.SeaEvent.BoatAlive(boat)
            if not boat or not boat.Parent then
                return false
            end
            local health = state.SeaEvent.Health(boat)
            return health == nil or health > 0
        end

        function state.SeaEvent.StopBoat(boat)
            if not boat or not boat.Parent then
                return
            end
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end

        function state.SeaEvent.ApplyBoatNoclip(boat)
            if not boat or not boat.Parent then
                return
            end
            for _, part in ipairs(boat:GetDescendants()) do
                if part:IsA("BasePart") then
                    if state.SeaEvent.BoatCollisions[part] == nil then
                        state.SeaEvent.BoatCollisions[part] = {
                            CanCollide = part.CanCollide,
                        }
                    end
                    part.CanCollide = false
                end
            end
        end

        function state.SeaEvent.RestoreBoatNoclip()
            for part, original in pairs(state.SeaEvent.BoatCollisions) do
                if part and part.Parent then
                    part.CanCollide = original.CanCollide
                end
            end
            state.SeaEvent.BoatCollisions = setmetatable({}, {__mode = "k"})
        end

        function state.SeaEvent.FindStopCondition()
            if not state.SeaEvent.AutoStopSail then
                state.SeaEvent.StopMatch = nil
                return nil
            end
            if os.clock() - state.SeaEvent.LastStopScan < 0.5 then
                return state.SeaEvent.StopMatch
            end
            state.SeaEvent.LastStopScan = os.clock()
            state.SeaEvent.StopMatch = nil
            local candidates = workspace:GetChildren()
            local worldOrigin = workspace:FindFirstChild("_WorldOrigin")
            local locations = worldOrigin and worldOrigin:FindFirstChild("Locations")
            local map = workspace:FindFirstChild("Map")
            local seaEvents = workspace:FindFirstChild("SeaEvents")
            for _, container in ipairs({locations, map, seaEvents}) do
                if container then
                    for _, child in ipairs(container:GetChildren()) do
                        table.insert(candidates, child)
                    end
                end
            end
            for condition, enabled in pairs(state.SeaEvent.StopConditions) do
                if enabled then
                    for _, candidate in ipairs(candidates) do
                        local lowered = string.lower(candidate.Name)
                        for _, pattern in ipairs(state.SeaEvent.StopConditionPatterns[condition] or {}) do
                            if lowered:find(pattern, 1, true) then
                                state.SeaEvent.StopMatch = condition
                                return condition
                            end
                        end
                    end
                end
            end
            return nil
        end

        function state.SeaEvent.DestroySafety()
            local part = state.SeaEvent.SafetyPart
            if part and part.Parent then
                part:Destroy()
            end
            state.SeaEvent.SafetyPart = nil
        end

        function state.SeaEvent.UpdateSafety(position)
            local part = state.SeaEvent.SafetyPart
            if not part or not part.Parent then
                part = Instance.new("Part")
                part.Name = "VORSeaEventWaterSafety"
                part.Size = Vector3.new(34, 1, 34)
                part.Anchored = true
                part.CanCollide = true
                part.CanTouch = false
                part.CanQuery = false
                part.Transparency = 1
                part.Parent = workspace
                state.SeaEvent.SafetyPart = part
            end
            part.CFrame = CFrame.new(position - Vector3.new(0, 4.5, 0))
        end

        function state.SeaEvent.ResetAdaptiveSpeed()
            state.SeaEvent.EffectiveSpeed = math.max(0, tonumber(state.SeaEvent.BoatTweenSpeed) or 295)
            state.SeaEvent.SafeSpeed = math.min(80, state.SeaEvent.EffectiveSpeed)
            state.SeaEvent.RejectedSpeed = nil
            state.SeaEvent.StableSince = os.clock()
            state.SeaEvent.PauseUntil = 0
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.Rubberbacks = 0
        end

        function state.SeaEvent.NearestDealer()
            local root = rootPart()
            local npcs = workspace:FindFirstChild("NPCs")
            local best, bestPart, bestDistance = nil, nil, math.huge
            if not root or not npcs then
                return nil
            end
            for _, npc in ipairs(npcs:GetChildren()) do
                local lowered = string.lower(npc.Name)
                if lowered == "boat dealer" or lowered == "luxury boat dealer" then
                    local part = npc:FindFirstChild("HumanoidRootPart")
                        or npc:FindFirstChild("Head")
                        or npc:FindFirstChildWhichIsA("BasePart")
                    local distance = part and (part.Position - root.Position).Magnitude or math.huge
                    if distance < bestDistance then
                        best, bestPart, bestDistance = npc, part, distance
                    end
                end
            end
            return best, bestPart, bestDistance
        end

        function state.SeaEvent.ResetCharacter(reason)
            if os.clock() - (state.SeaEvent.LastReset or 0) < 5 then
                return
            end
            state.SeaEvent.LastReset = os.clock()
            state.SeaEvent.Phase = reason or "Resetting for a new boat"
            state.SeaEvent.Boat = nil
            state.SeaEvent.BoatBaseY = nil
            state.SeaEvent.Heading = nil
            state.SeaEvent.LastCommandedPosition = nil
            local body = humanoid()
            if body then
                body.Health = 0
            end
        end

        function state.SeaEvent.EnsureBoat()
            local current = state.SeaEvent.OwnedBoat()
            if current and state.SeaEvent.BoatAlive(current) then
                if current ~= state.SeaEvent.Boat then
                    state.SeaEvent.Boat = current
                    -- Solix keeps the spawned boat at its exact native pivot Y.
                    -- WaterOrigin is not the model pivot and was lifting VOR boats
                    -- high enough for the server's movement security to reject them.
                    state.SeaEvent.BoatBaseY = current:GetPivot().Position.Y
                    state.SeaEvent.Heading = nil
                    state.SeaEvent.ResetAdaptiveSpeed()
                end
                return current
            end
            if current and not state.SeaEvent.BoatAlive(current) then
                if state.SeaEvent.ResetBrokenBoat then
                    state.SeaEvent.ResetCharacter("Boat destroyed - resetting")
                end
                return nil
            end
            state.SeaEvent.Boat = nil
            if os.clock() - state.SeaEvent.LastPurchase < 3 then
                state.SeaEvent.Phase = "Waiting for " .. state.SeaEvent.SelectedBoat
                return nil
            end

            local _, dealerPart, dealerDistance = state.SeaEvent.NearestDealer()
            if dealerPart and dealerDistance > 24 then
                state.SeaEvent.Phase = "Moving to Boat Dealer"
                moveTo(CFrame.new(dealerPart.Position + Vector3.new(0, 5, 8), dealerPart.Position))
                return nil
            end
            if not dealerPart then
                if state.SeaEvent.ResetBrokenBoat then
                    state.SeaEvent.ResetCharacter("Returning to Boat Dealer")
                end
                return nil
            end

            state.SeaEvent.LastPurchase = os.clock()
            state.SeaEvent.Phase = "Buying " .. state.SeaEvent.SelectedBoat
            local purchaseName = state.SeaEvent.BoatPurchaseNames[state.SeaEvent.SelectedBoat]
                or state.SeaEvent.SelectedBoat
            local ok, result = invoke("BuyBoat", purchaseName)
            if not ok then
                state.SeaEvent.LastError = tostring(result)
            end
            return nil
        end

        function state.SeaEvent.SeatBoat(boat)
            local body = humanoid()
            local char = character()
            local seat = boat and boat:FindFirstChildWhichIsA("VehicleSeat", true)
            if not body or not char or not seat then
                return false
            end
            if seat.Occupant ~= body and os.clock() - state.SeaEvent.LastSeat >= 0.15 then
                state.SeaEvent.LastSeat = os.clock()
                char:PivotTo(seat.CFrame + Vector3.new(0, 2.5, 0))
                body.Sit = false
                seat:Sit(body)
            end
            return seat.Occupant == body
        end

        function state.SeaEvent.ChooseHeading(boat)
            local position = boat:GetPivot().Position
            local dangerDistance = state.SeaEvent.DangerDistanceFn
            local previous = state.SeaEvent.Heading
            local bestDirection = previous or Vector3.new(0, 0, 1)
            local bestScore = -math.huge
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {workspace:FindFirstChild("Map")}
            params.IgnoreWater = true
            for index = 0, 15 do
                local angle = index * math.pi / 8
                local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
                local probe = position + direction * 8000
                local score = type(dangerDistance) == "function" and dangerDistance(probe) or 0
                if previous then
                    score += direction:Dot(previous) * 220
                end
                if workspace:FindFirstChild("Map")
                    and workspace:Raycast(position + Vector3.new(0, 18, 0), direction * 900, params) then
                    score -= 100000
                end
                if score > bestScore then
                    bestScore = score
                    bestDirection = direction
                end
            end
            state.SeaEvent.Heading = bestDirection
            state.SeaEvent.NextHeadingAt = os.clock() + 2.5
            return bestDirection
        end

        function state.SeaEvent.DetectRubberband(currentPosition, deltaTime)
            local commanded = state.SeaEvent.LastCommandedPosition
            if not commanded then
                return false
            end
            local horizontalError = ((currentPosition - commanded) * Vector3.new(1, 0, 1)).Magnitude
            local allowed = math.max(35, state.SeaEvent.EffectiveSpeed * math.max(deltaTime, 1 / 60) * 8)
            if horizontalError <= allowed then
                return false
            end

            state.SeaEvent.Rubberbacks += 1
            local rejected = math.max(tonumber(state.SeaEvent.EffectiveSpeed) or 0, 1)
            state.SeaEvent.RejectedSpeed = math.min(state.SeaEvent.RejectedSpeed or rejected, rejected)
            state.SeaEvent.EffectiveSpeed = math.max(
                25,
                math.floor((state.SeaEvent.SafeSpeed + state.SeaEvent.RejectedSpeed) * 0.5)
            )
            state.SeaEvent.PauseUntil = os.clock() + 0.85
            state.SeaEvent.StableSince = os.clock()
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.Heading = nil
            state.SeaEvent.Phase = string.format(
                "Snap-back stopped - testing %.0f speed",
                state.SeaEvent.EffectiveSpeed
            )
            return true
        end

        function state.SeaEvent.RaiseSafeSpeed()
            local requested = math.max(0, tonumber(state.SeaEvent.BoatTweenSpeed) or 0)
            if os.clock() - state.SeaEvent.StableSince < 4
                or state.SeaEvent.EffectiveSpeed >= requested then
                return
            end
            state.SeaEvent.SafeSpeed = math.max(state.SeaEvent.SafeSpeed, state.SeaEvent.EffectiveSpeed)
            if state.SeaEvent.RejectedSpeed then
                local nextSpeed = math.floor(
                    (state.SeaEvent.SafeSpeed + state.SeaEvent.RejectedSpeed) * 0.5
                )
                if nextSpeed <= state.SeaEvent.SafeSpeed + 1 then
                    state.SeaEvent.EffectiveSpeed = state.SeaEvent.SafeSpeed
                else
                    state.SeaEvent.EffectiveSpeed = math.min(requested, nextSpeed)
                end
            else
                state.SeaEvent.EffectiveSpeed = math.min(requested, state.SeaEvent.EffectiveSpeed + 25)
            end
            state.SeaEvent.StableSince = os.clock()
        end

        function state.SeaEvent.Sail(boat, deltaTime)
            state.SeaEvent.DestroySafety()
            state.SeaEvent.ApplyBoatNoclip(boat)
            state.SeaEvent.SeatBoat(boat)
            local pivot = boat:GetPivot()
            if state.SeaEvent.DetectRubberband(pivot.Position, deltaTime) then
                state.SeaEvent.StopBoat(boat)
                return
            end
            if os.clock() < state.SeaEvent.PauseUntil then
                state.SeaEvent.StopBoat(boat)
                return
            end
            state.SeaEvent.RaiseSafeSpeed()
            local direction = state.SeaEvent.Heading
            if not direction then
                direction = state.SeaEvent.ChooseHeading(boat)
            end
            local speed = math.max(0, tonumber(state.SeaEvent.EffectiveSpeed) or 0)
            local baseY = tonumber(state.SeaEvent.BoatBaseY) or pivot.Position.Y
            local nextPosition = pivot.Position + direction * speed * math.min(deltaTime, 0.05)
            nextPosition = Vector3.new(
                nextPosition.X,
                baseY + math.max(0, tonumber(state.SeaEvent.BoatFloatHeight) or 0),
                nextPosition.Z
            )
            local goal = CFrame.lookAt(nextPosition, nextPosition + direction)
            boat:PivotTo(goal)
            state.SeaEvent.StopBoat(boat)
            state.SeaEvent.LastCommandedPosition = nextPosition
            state.SeaEvent.SeatBoat(boat)

            local danger = type(state.SeaEvent.DangerDistanceFn) == "function"
                and state.SeaEvent.DangerDistanceFn(nextPosition) or 0
            local dangerData = type(state.SeaEvent.GetDangerLevelFn) == "function"
                and state.SeaEvent.GetDangerLevelFn(danger) or nil
            state.SeaEvent.DangerDistance = danger
            state.SeaEvent.DangerLevel = dangerData
                and math.max((tonumber(dangerData.level) or 1) - 1, 0) or 0
            state.SeaEvent.Phase = string.format(
                "Sailing | Danger %d | %.0f speed | +%.0f height",
                state.SeaEvent.DangerLevel,
                speed,
                state.SeaEvent.BoatFloatHeight
            )
        end

        function state.SeaEvent.CombatTools()
            local result = {}
            local seen = setmetatable({}, {__mode = "k"})
            for _, container in ipairs({character(), LocalPlayer:FindFirstChildOfClass("Backpack")}) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") and not seen[tool] then
                            local weaponData = weaponDataForTool(tool)
                            local weaponType = string.lower(weaponTypeForTool(tool, weaponData))
                            if weaponType:find("melee", 1, true)
                                or weaponType:find("sword", 1, true)
                                or weaponType:find("gun", 1, true)
                                or weaponType:find("fruit", 1, true) then
                                seen[tool] = true
                                table.insert(result, tool)
                            end
                        end
                    end
                end
            end
            return result
        end

        function state.SeaEvent.SpamSkill(targetPart)
            if not state.SeaEvent.SpamAllSkills
                or os.clock() - state.SeaEvent.LastSkill < 0.055 then
                return
            end
            local tools = state.SeaEvent.CombatTools()
            if #tools == 0 then
                state.SeaEvent.LastError = "No combat Tools found"
                return
            end
            state.SeaEvent.LastSkill = os.clock()
            state.SeaEvent.SkillIndex = state.SeaEvent.SkillIndex % #state.SeaEvent.SkillKeys + 1
            if state.SeaEvent.SkillIndex == 1 then
                state.SeaEvent.ToolIndex = state.SeaEvent.ToolIndex % #tools + 1
            end
            if state.SeaEvent.ToolIndex == 0 then
                state.SeaEvent.ToolIndex = 1
            end
            local tool = tools[state.SeaEvent.ToolIndex]
            local keyCode = state.SeaEvent.SkillKeys[state.SeaEvent.SkillIndex]
            local loweredToolName = string.lower(tool.Name)
            for pattern, blockedKeys in pairs(state.SeaEvent.TransformationSkillKeys) do
                if loweredToolName:find(pattern, 1, true) and blockedKeys[keyCode.Name] then
                    return
                end
            end
            equipTool(tool)
            if type(FruitMouse) == "table" and targetPart then
                FruitMouse.Hit = CFrame.new(targetPart.Position)
                FruitMouse.Target = targetPart
            end
            pcall(function()
                tool:Activate()
                tool:Deactivate()
            end)
            task.spawn(function()
                local input = game:GetService("VirtualInputManager")
                input:SendKeyEvent(true, keyCode, false, game)
                task.wait(0.045)
                input:SendKeyEvent(false, keyCode, false, game)
            end)
        end

        function state.SeaEvent.Fight(candidate)
            local target = candidate and candidate.Target
            local targetPart = candidate and state.SeaEvent.TargetPart(target)
            local root = rootPart()
            local body = humanoid()
            if not targetPart or not root or not body then
                return
            end
            state.SeaEvent.LastCommandedPosition = nil
            state.SeaEvent.StopBoat(state.SeaEvent.Boat)
            if body.SeatPart then
                body.Sit = false
                body.Jump = true
            end

            local height = math.max(8, tonumber(state.SeaEvent.CombatHeight) or 24)
            if candidate.Kind == "Sea Beast" then
                height = math.max(9, height * 0.5)
            elseif candidate.Kind == "Hostile Boats" then
                height = math.max(12, height * 0.65)
            end
            local position = targetPart.Position + Vector3.new(0, height, 0)
            root.CFrame = CFrame.lookAt(position, targetPart.Position)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            state.SeaEvent.UpdateSafety(position)
            ensureBuso(true)
            state.SeaEvent.SpamSkill(targetPart)
            local health, maximum = state.SeaEvent.Health(target)
            state.SeaEvent.Phase = string.format(
                "Fighting %s%s",
                candidate.Kind,
                health and string.format(" | %.0f / %.0f", health, maximum or health) or ""
            )
        end

        function state.SeaEvent.UpdateStatus()
            if os.clock() - (state.SeaEvent.LastStatusUpdate or 0) < 0.15 then
                return
            end
            state.SeaEvent.LastStatusUpdate = os.clock()
            if state.SeaEvent.StatusLabel then
                state.SeaEvent.StatusLabel.Text = "Sea Events: " .. tostring(state.SeaEvent.Phase)
                state.SeaEvent.StatusLabel.TextColor3 = state.SeaEvent.LastError and COLORS.warning
                    or (state.SeaEvent.Enabled and COLORS.success or COLORS.muted)
            end
            if state.SeaEvent.DetailLabel then
                state.SeaEvent.DetailLabel.Text = string.format(
                    "Boat: %s | Event: %s | Snap-backs: %d | Completed: %d",
                    state.SeaEvent.Boat and state.SeaEvent.Boat.Name or state.SeaEvent.SelectedBoat,
                    state.SeaEvent.TargetKind or "Searching",
                    state.SeaEvent.Rubberbacks,
                    state.SeaEvent.EventsCompleted
                )
            end
            gui:SetAttribute("BloxSeaEventAutoFarm", state.SeaEvent.Enabled)
            gui:SetAttribute("BloxSeaEventPhase", state.SeaEvent.Phase)
            gui:SetAttribute("BloxSeaEventBoat", state.SeaEvent.Boat and state.SeaEvent.Boat.Name or "")
            gui:SetAttribute("BloxSeaEventTarget", state.SeaEvent.Target and state.SeaEvent.Target.Name or "")
            gui:SetAttribute("BloxSeaEventTargetKind", state.SeaEvent.TargetKind or "")
            gui:SetAttribute("BloxSeaEventDangerLevel", state.SeaEvent.DangerLevel)
            gui:SetAttribute("BloxSeaEventEffectiveSpeed", state.SeaEvent.EffectiveSpeed)
            gui:SetAttribute("BloxSeaEventRubberbacks", state.SeaEvent.Rubberbacks)
        end

        function state.SeaEvent.Step(deltaTime)
            if not state.SeaEvent.Enabled then
                state.SeaEvent.Phase = "Off"
                state.SeaEvent.Target = nil
                state.SeaEvent.TargetKind = nil
                state.SeaEvent.DestroySafety()
                state.SeaEvent.UpdateStatus()
                return
            end
            local stopCondition = state.SeaEvent.FindStopCondition()
            if stopCondition then
                state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                state.SeaEvent.Phase = "Stopped at " .. stopCondition
                state.SeaEvent.UpdateStatus()
                return
            end
            local candidate = state.SeaEvent.AutoKill and state.SeaEvent.FindTarget() or nil
            if candidate then
                state.SeaEvent.Target = candidate.Target
                state.SeaEvent.TargetKind = candidate.Kind
                state.SeaEvent.Fight(candidate)
                state.SeaEvent.UpdateStatus()
                return
            end
            if state.SeaEvent.Target then
                state.SeaEvent.EventsCompleted += 1
            end
            state.SeaEvent.Target = nil
            state.SeaEvent.TargetKind = nil
            if not state.SeaEvent.AutoSail then
                state.SeaEvent.Phase = "Auto Kill waiting for a selected sea enemy"
                state.SeaEvent.UpdateStatus()
                return
            end
            local boat = state.SeaEvent.EnsureBoat()
            if boat then
                state.SeaEvent.Sail(boat, deltaTime)
            end
            state.SeaEvent.UpdateStatus()
        end

        local function chestPart()
            local root = rootPart()
            if not root then
                return nil
            end
            local best = nil
            local bestDistance = math.huge
            -- Blox Fruits registers live server chests with this tag. Reading
            -- that registry avoids a full Workspace descendant scan every
            -- second and skips chests already marked IsDisabled.
            for _, serverChest in ipairs(CollectionService:GetTagged("_ChestTagged")) do
                if serverChest:IsDescendantOf(workspace) and serverChest:GetAttribute("IsDisabled") ~= true then
                    local part = serverChest:IsA("BasePart") and serverChest
                        or serverChest:FindFirstChild("PushBox", true)
                        or serverChest:FindFirstChildWhichIsA("BasePart", true)
                    if part and part:IsA("BasePart") then
                        local distance = (part.Position - root.Position).Magnitude
                        if distance < bestDistance then
                            best = part
                            bestDistance = distance
                        end
                    end
                end
            end
            return best, bestDistance
        end

        local function stepChest()
            if os.clock() - state.LastChestScan < 1 then
                return
            end
            state.LastChestScan = os.clock()
            local chest, distance = chestPart()
            if not chest then
                setStatus("Waiting for a chest", nil)
                return
            end
            moveTo(chest.CFrame + Vector3.new(0, 3, 0))
            if distance and distance <= 10 and type(firetouchinterest) == "function" then
                local root = rootPart()
                if root then
                    pcall(firetouchinterest, root, chest, 0)
                    pcall(firetouchinterest, root, chest, 1)
                end
            end
            setStatus("Collecting nearest chest", true)
        end

        local function berryTarget()
            local root = rootPart()
            if not root then
                return nil
            end
            local best = nil
            local bestDistance = math.huge
            for _, streamed in ipairs(CollectionService:GetTagged("BerryBushStreamed")) do
                local berries = streamed:IsA("Configuration") and streamed
                    or streamed:FindFirstChild("Berries")
                    or streamed:FindFirstChildWhichIsA("Configuration")
                local bush = berries and berries.Parent
                if berries and bush and bush:IsDescendantOf(workspace) then
                    for key, berryName in pairs(berries:GetAttributes()) do
                        if string.sub(tostring(key), 1, 12) == "_BerryCFrame" and tostring(berryName) ~= "" then
                            local localCFrame = bush:GetAttribute(key)
                            if typeof(localCFrame) == "CFrame" then
                                local pivot = bush:IsA("Model") and bush:GetPivot()
                                    or (bush:IsA("BasePart") and bush.CFrame)
                                if pivot then
                                    local worldCFrame = pivot * localCFrame
                                    local distance = (worldCFrame.Position - root.Position).Magnitude
                                    if distance < bestDistance then
                                        bestDistance = distance
                                        best = {
                                            Bush = bush,
                                            Key = key,
                                            Name = tostring(berryName),
                                            CFrame = worldCFrame,
                                            Distance = distance,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return best
        end

        local function stepBerry()
            if os.clock() - state.LastBerryClaim < 0.35 then
                return
            end
            local target = berryTarget()
            if not target then
                berryLabel.Text = "Berries: Waiting for a streamed berry bush"
                setStatus("Waiting for a berry to spawn", nil)
                return
            end
            moveTo(target.CFrame + Vector3.new(0, 3, 0))
            berryLabel.Text = string.format("Berry: %s | %.0f studs", target.Name, target.Distance)
            if target.Distance <= 14 and ClaimBerry and ClaimBerry:IsA("RemoteFunction") then
                state.LastBerryClaim = os.clock()
                local ok, claimed = pcall(function()
                    return ClaimBerry:InvokeServer(target.Bush.Name, target.Key)
                end)
                if ok and claimed ~= false then
                    state.BerriesClaimed += 1
                    berryLabel.Text = string.format("Berries claimed: %d | Last: %s", state.BerriesClaimed, target.Name)
                    setStatus("Claimed " .. target.Name, true)
                elseif not ok then
                    setError("Berry claim failed: " .. tostring(claimed))
                end
            end
        end

        local function enabledStats()
            local values = {}
            for _, name in ipairs({"Melee", "Defense", "Sword", "Gun", "Demon Fruit"}) do
                if state.Stats[name] then
                    table.insert(values, name)
                end
            end
            return values
        end

        local function stepStats()
            if not state.AutoStats or currentPoints() <= 0 or os.clock() - state.LastStat < 0.35 then
                return
            end
            local stats = enabledStats()
            if #stats == 0 then
                return
            end
            state.LastStat = os.clock()
            state.StatIndex = state.StatIndex % #stats + 1
            invoke("AddPoint", stats[state.StatIndex], math.min(state.StatBatch, currentPoints()))
        end

        local function fruitTools()
            local result = {}
            for _, container in ipairs({LocalPlayer:FindFirstChildOfClass("Backpack"), character()}) do
                if container then
                    for _, tool in ipairs(container:GetChildren()) do
                        if tool:IsA("Tool") then
                            local name = string.lower(tool.Name)
                            if string.find(name, "fruit", 1, true) or tool:GetAttribute("OriginalName") then
                                table.insert(result, tool)
                            end
                        end
                    end
                end
            end
            return result
        end

        local function storeFruits()
            if state.InventoryBusy then
                return 0, "Fruit storage is already busy"
            end
            local tools = fruitTools()
            if #tools == 0 then
                state.StoreStatus = "No physical fruit is being carried"
                return 0, state.StoreStatus
            end

            state.InventoryBusy = true
            local stored = 0
            local lastMessage = nil
            local operationOk, operationError = xpcall(function()
                local deadline = os.clock() + 0.75
                while state.AuraAttackPending and os.clock() < deadline do
                    task.wait()
                end
                local char = character()
                local body = humanoid()
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                if not char or not body or not backpack then
                    error("character inventory is unavailable")
                end
                local previousTool = nil
                for _, child in ipairs(char:GetChildren()) do
                    if child:IsA("Tool") then
                        previousTool = child
                        break
                    end
                end

                for _, tool in ipairs(tools) do
                    if tool.Parent then
                        body:UnequipTools()
                        task.wait(0.10)
                        body:EquipTool(tool)
                        task.wait(0.18)
                        if tool.Parent and tool.Parent ~= char then
                            tool.Parent = char
                            task.wait(0.10)
                        end
                        if tool.Parent == char then
                            local originalName = tostring(tool:GetAttribute("OriginalName") or tool.Name)
                            local requestOk, requestResult = invoke("StoreFruit", originalName, tool)
                            task.wait(0.65)
                            local stillCarried = tool.Parent == char or tool.Parent == backpack
                            if requestOk and not stillCarried then
                                stored += 1
                                state.FruitsStored += 1
                                lastMessage = "Stored " .. originalName
                            else
                                lastMessage = stillCarried
                                    and ("Server kept " .. tool.Name .. " (storage full or duplicate)")
                                    or tostring(requestResult)
                            end
                        else
                            lastMessage = "Could not equip " .. tool.Name .. " for storage"
                        end
                    end
                end

                body:UnequipTools()
                task.wait(0.08)
                if previousTool and previousTool.Parent then
                    body:EquipTool(previousTool)
                elseif state.DoubleAttack then
                    local sword = toolForSelection("Sword")
                    if sword then
                        body:EquipTool(sword)
                    end
                end
            end, debug.traceback)
            state.InventoryBusy = false
            if not operationOk then
                state.StoreStatus = "Storage failed: " .. tostring(operationError)
                return stored, state.StoreStatus
            end
            state.StoreStatus = lastMessage or string.format("Stored %d fruit(s)", stored)
            return stored, state.StoreStatus
        end

        local function rollFruitOnce()
            if state.GachaBusy then
                return false, "Fruit Gacha is already checking the server"
            end
            state.GachaBusy = true
            local before = {}
            for _, tool in ipairs(fruitTools()) do
                before[tool] = true
            end
            local operationOk, requestOk, requestResult = pcall(function()
                -- The current server requires the gacha box name on CheckTime.
                -- The old missing argument raised "boxName is nil" and stopped
                -- every automatic roll before the purchase request.
                local timeOk, timeResult = invoke("Cousin", "CheckTime", "DLCBoxData")
                if not timeOk then
                    return false, timeResult
                end
                local loweredTime = string.lower(tostring(timeResult or ""))
                if string.find(loweredTime, "must wait", 1, true)
                    or string.find(loweredTime, "wait ", 1, true) then
                    return false, timeResult
                end

                local buyOk, buyResult = invoke("Cousin", "DLCBoxData")
                if not buyOk then
                    return false, buyResult
                end
                task.wait(0.45)
                local wonTool = nil
                for _, tool in ipairs(fruitTools()) do
                    if not before[tool] then
                        wonTool = tool
                        break
                    end
                end
                state.GachaRolls += 1
                return true, wonTool and ("Won " .. wonTool.Name) or tostring(buyResult)
            end)
            state.GachaBusy = false
            if not operationOk then
                state.GachaStatus = "Gacha failed: " .. tostring(requestOk)
                return false, state.GachaStatus
            end
            state.GachaStatus = tostring(requestResult)
            if requestOk and state.AutoStoreFruit then
                task.defer(storeFruits)
            end
            return requestOk, requestResult
        end

        local function locationOptions()
            local result = {"None"}
            local seen = {None = true}
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local locations = origin and origin:FindFirstChild("Locations")
            if locations then
                for _, location in ipairs(locations:GetChildren()) do
                    if location.Name ~= "" and not seen[location.Name] then
                        seen[location.Name] = true
                        table.insert(result, location.Name)
                    end
                end
            end
            table.sort(result, function(left, right)
                if left == "None" then
                    return true
                end
                if right == "None" then
                    return false
                end
                return string.lower(left) < string.lower(right)
            end)
            return result
        end

        local function npcOptions()
            local result = {"None"}
            local npcs = workspace:FindFirstChild("NPCs")
            if npcs then
                for _, npc in ipairs(npcs:GetChildren()) do
                    table.insert(result, npc.Name)
                end
            end
            table.sort(result)
            return result
        end

        local function prepareManualTravel()
            -- A manual destination must own player movement until arrival.
            -- Leaving Auto Level or Mob Aura active makes those loops overwrite
            -- the travel tween every frame and produces the visible stutter.
            for _, flag in ipairs({
                "blox_auto_level",
                "blox_auto_boss",
                "blox_auto_raid",
                "blox_auto_chest",
                "blox_mob_aura_tp",
                "blox_selected_mob_farm",
                "blox_enemy_gather",
            }) do
                local control = Window.PersistentControls[flag]
                if control and control:Get() then
                    control:Set(false)
                end
            end
            state.AutoFarmLevel = false
            state.AutoBoss = false
            state.AutoRaid = false
            state.AutoChest = false
            state.MobAuraTp = false
            state.SelectedMobFarm = false
            state.GatherEnemies = false
            state.ActiveFarmTarget = nil
            FarmVertical.Release()
            state.MobAuraTarget = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            cancelMove(false)
        end

        local function teleportToLocation(name)
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local locations = origin and origin:FindFirstChild("Locations")
            local target = locations and locations:FindFirstChild(name)
            if not target then
                return false
            end
            local targetCFrame = target:IsA("BasePart") and target.CFrame or target:GetPivot()
            -- Location markers are often island centers floating far above the
            -- actual ground. Ending at marker Y makes the player fall after a
            -- perfectly good tween, which looks like another snap-back. Land
            -- on the map surface at that X/Z whenever one is available.
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Include
            params.FilterDescendantsInstances = {
                workspace.Terrain,
                workspace:FindFirstChild("Map"),
            }
            params.IgnoreWater = true
            params.RespectCanCollide = true
            local ground = nil
            local groundScore = math.huge
            local markerPosition = targetCFrame.Position
            -- A marker can sit directly inside a tree, tower, or giant vine.
            -- Sample nearby columns and prefer a walkable surface close to the
            -- marker's intended elevation instead of landing on scenery.
            for _, offsetX in ipairs({0, -30, 30, -60, 60}) do
                for _, offsetZ in ipairs({0, -30, 30, -60, 60}) do
                    local result = workspace:Raycast(
                        markerPosition + Vector3.new(offsetX, 400, offsetZ),
                        Vector3.new(0, -1000, 0),
                        params
                    )
                    if result
                        and result.Normal.Y >= 0.45
                        and result.Position.Y >= markerPosition.Y - 300
                        and result.Position.Y <= markerPosition.Y + 180 then
                        local horizontalDistance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
                        local score = math.abs(result.Position.Y - markerPosition.Y) + horizontalDistance * 0.15
                        if score < groundScore then
                            ground = result
                            groundScore = score
                        end
                    end
                end
            end
            if ground then
                local root = rootPart()
                local body = humanoid()
                local clearance = (body and body.HipHeight or 2)
                    + (root and root.Size.Y * 0.5 or 1)
                    + 1
                local rotation = targetCFrame - targetCFrame.Position
                targetCFrame = CFrame.new(
                    ground.Position.X,
                    ground.Position.Y + clearance,
                    ground.Position.Z
                ) * rotation
            else
                targetCFrame += Vector3.new(0, 8, 0)
            end
            prepareManualTravel()
            return moveTo(targetCFrame)
        end

        local function teleportToNpc(name)
            local npcs = workspace:FindFirstChild("NPCs")
            local target = npcs and npcs:FindFirstChild(name)
            if not target then
                return false
            end
            prepareManualTravel()
            return moveTo(target:GetPivot() * CFrame.new(0, 0, -4))
        end

        local function applyNoclip()
            local char = character()
            if not char then
                return
            end
            for _, descendant in ipairs(char:GetDescendants()) do
                if descendant:IsA("BasePart") then
                    if state.OriginalCollision[descendant] == nil then
                        state.OriginalCollision[descendant] = descendant.CanCollide
                    end
                    descendant.CanCollide = false
                end
            end
        end

        local function restoreCollision()
            for part, original in pairs(state.OriginalCollision) do
                if part and part.Parent then
                    part.CanCollide = original
                end
            end
            table.clear(state.OriginalCollision)
        end

        local function updateEnergy()
            if not state.InfiniteEnergy then
                return
            end
            local char = character()
            local energy = char and char:FindFirstChild("Energy")
            if energy and energy:IsA("NumberValue") then
                energy.Value = math.max(energy.Value, energy:GetAttribute("MaxValue") or 10000)
            end
        end

        local function updateWaterPlatform()
            local automaticFarmSafety = state.AutoFarmLevel or state.AutoBoss or state.AutoRaid
                or state.MobAuraTp or state.SelectedMobFarm or state.Traveling
            local shouldSupportWater = state.WalkOnWater or automaticFarmSafety
            if shouldSupportWater and not state.WaterPlatform then
                -- Build this once from the privileged startup/UI callback even
                -- when the character is still on the team-selection screen.
                -- Heartbeat may update Instances but some executors refuse to
                -- create them from an event-resumed coroutine.
                local platform = Instance.new("Part")
                platform.Name = "VOR_WaterPlatform"
                platform.Size = Vector3.new(30, 1, 30)
                platform.Anchored = true
                platform.CanCollide = false
                platform.Transparency = 1
                platform.CFrame = CFrame.new(0, -10000, 0)
                platform.Parent = workspace
                state.WaterPlatform = platform
            end
            if not shouldSupportWater then
                if state.WaterPlatform then
                    state.WaterPlatform.CanCollide = false
                    state.WaterPlatform.CFrame = CFrame.new(0, -10000, 0)
                end
                return
            end
            local root = rootPart()
            if not root then
                return
            end
            state.WaterPlatform.CanCollide = true
            state.WaterPlatform.CFrame = CFrame.new(root.Position.X, 0, root.Position.Z)
        end

        local function backup(instance, values)
            if state.GraphicsBackup[instance] == nil then
                state.GraphicsBackup[instance] = values
            end
        end

        local function optimizeInstance(instance)
            if instance:IsA("BasePart") then
                backup(instance, {Material = instance.Material, Reflectance = instance.Reflectance})
                instance.Material = Enum.Material.Plastic
                instance.Reflectance = 0
            elseif instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam")
                or instance:IsA("Smoke") or instance:IsA("Fire") or instance:IsA("Sparkles") then
                backup(instance, {Enabled = instance.Enabled})
                instance.Enabled = false
            end
        end

        local function setFpsBoost(enabled)
            state.FpsBoost = enabled == true
            if state.FpsBoost then
                backup(Lighting, {GlobalShadows = Lighting.GlobalShadows, EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale, EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale})
                Lighting.GlobalShadows = false
                Lighting.EnvironmentDiffuseScale = 0
                Lighting.EnvironmentSpecularScale = 0
                for _, descendant in ipairs(workspace:GetDescendants()) do
                    pcall(optimizeInstance, descendant)
                end
            else
                for instance, values in pairs(state.GraphicsBackup) do
                    if instance and instance.Parent then
                        for property, value in pairs(values) do
                            pcall(function()
                                instance[property] = value
                            end)
                        end
                    end
                end
                table.clear(state.GraphicsBackup)
            end
        end

        local function clearHighlights(registry)
            for highlight in pairs(registry) do
                if highlight and highlight.Parent then
                    highlight:Destroy()
                end
                registry[highlight] = nil
            end
        end

        local function ensureHighlight(model, name, color, registry)
            if not model or not model.Parent then
                return
            end
            local highlight = model:FindFirstChild(name)
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = name
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.FillTransparency = 0.72
                highlight.OutlineTransparency = 0.08
                highlight.Parent = model
            end
            registry[highlight] = true
            highlight.FillColor = color
            highlight.OutlineColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
        end

        local PlayerEsp = {Bones = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
            {"Head", "Torso"},
            {"Torso", "Left Arm"},
            {"Torso", "Right Arm"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"},
        }}

        function PlayerEsp.Remove(player)
            local record = state.PlayerEspObjects[player]
            if not record then
                return
            end
            if record.Billboard then
                pcall(function()
                    record.Billboard:Destroy()
                end)
            end
            for _, line in ipairs(record.Lines or {}) do
                pcall(function()
                    line.Visible = false
                    line:Remove()
                end)
            end
            state.PlayerEspObjects[player] = nil
        end

        function PlayerEsp.Clear()
            for player in pairs(state.PlayerEspObjects) do
                PlayerEsp.Remove(player)
            end
        end

        function PlayerEsp.Count()
            local count = 0
            for _ in pairs(state.PlayerEspObjects) do
                count += 1
            end
            return count
        end

        function PlayerEsp.Create(player, playerCharacter)
            PlayerEsp.Remove(player)
            local head = playerCharacter and playerCharacter:FindFirstChild("Head")
            local root = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
            if not head and not root then
                return nil
            end

            local billboard = Instance.new("BillboardGui")
            billboard.Name = "VOR_PlayerNameESP_" .. tostring(player.UserId)
            billboard.Adornee = head or root
            billboard.AlwaysOnTop = true
            billboard.LightInfluence = 0
            billboard.MaxDistance = 10000000
            billboard.Size = UDim2.fromOffset(260, 48)
            billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
            billboard.Parent = gui

            local label = Instance.new("TextLabel")
            label.Name = "NameTag"
            label.BackgroundTransparency = 1
            label.Size = UDim2.fromScale(1, 1)
            label.Font = Enum.Font.GothamBold
            label.TextColor3 = COLORS.accent:Lerp(Color3.new(1, 1, 1), 0.28)
            label.TextSize = 14
            label.TextStrokeColor3 = Color3.new(0, 0, 0)
            label.TextStrokeTransparency = 0.05
            label.TextWrapped = true
            label.Parent = billboard

            local lines = {}
            if type(Drawing) == "table" and type(Drawing.new) == "function" then
                for _ = 1, #PlayerEsp.Bones do
                    local ok, line = pcall(Drawing.new, "Line")
                    if ok and line then
                        line.Color = COLORS.accent
                        line.Thickness = 2
                        line.Transparency = 0.95
                        line.ZIndex = 9
                        line.Visible = false
                        table.insert(lines, line)
                    end
                end
            end

            local record = {
                Character = playerCharacter,
                Billboard = billboard,
                Label = label,
                Lines = lines,
            }
            state.PlayerEspObjects[player] = record
            return record
        end

        function PlayerEsp.Update(allowCreate)
            if not state.PlayerESP then
                PlayerEsp.Clear()
                return
            end
            local camera = workspace.CurrentCamera
            local localRoot = rootPart()
            local now = os.clock()
            local updateText = now - state.PlayerEspLastTextUpdate >= 0.15
            if updateText then
                state.PlayerEspLastTextUpdate = now
            end

            for player, record in pairs(state.PlayerEspObjects) do
                if player.Parent ~= Players or not player.Character or record.Character ~= player.Character then
                    PlayerEsp.Remove(player)
                end
            end

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local record = state.PlayerEspObjects[player]
                    if allowCreate and (not record or record.Character ~= player.Character) then
                        record = PlayerEsp.Create(player, player.Character)
                    end
                    if record then
                        local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
                        local head = player.Character:FindFirstChild("Head") or targetRoot
                        record.Billboard.Adornee = head
                        record.Billboard.Enabled = head ~= nil
                        if updateText and targetRoot and localRoot then
                            local distance = (targetRoot.Position - localRoot.Position).Magnitude
                            record.Label.Text = string.format(
                                "%s  (@%s)\n%.0f studs",
                                player.DisplayName,
                                player.Name,
                                distance
                            )
                        end

                        if camera and #record.Lines > 0 then
                            for index, bone in ipairs(PlayerEsp.Bones) do
                                local line = record.Lines[index]
                                if line then
                                    local first = player.Character:FindFirstChild(bone[1])
                                    local second = player.Character:FindFirstChild(bone[2])
                                    if first and first:IsA("BasePart") and second and second:IsA("BasePart") then
                                        local firstPoint, firstVisible = camera:WorldToViewportPoint(first.Position)
                                        local secondPoint, secondVisible = camera:WorldToViewportPoint(second.Position)
                                        local visible = firstVisible and secondVisible
                                            and firstPoint.Z > 0 and secondPoint.Z > 0
                                        line.Visible = visible
                                        if visible then
                                            line.From = Vector2.new(firstPoint.X, firstPoint.Y)
                                            line.To = Vector2.new(secondPoint.X, secondPoint.Y)
                                        end
                                    else
                                        line.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local function updateEsp()
            if state.EnemyESP then
                for _, enemy in ipairs(loadedEnemies()) do
                    if modelAlive(enemy) then
                        ensureHighlight(enemy, "VOR_EnemyESP", COLORS.error, state.EnemyHighlights)
                    end
                end
            else
                clearHighlights(state.EnemyHighlights)
            end
            if state.PlayerESP then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        ensureHighlight(player.Character, "VOR_PlayerESP", COLORS.accent, state.PlayerHighlights)
                    end
                end
                PlayerEsp.Update(true)
            else
                clearHighlights(state.PlayerHighlights)
                PlayerEsp.Clear()
            end
        end

        local auraToggle
        local bossDropdown
        bossDropdown = BossSection:AddDropdown({
            Name = "Boss",
            Flag = "blox_boss",
            Options = bossNames(),
            Default = "None",
            Callback = function(value)
                state.SelectedBoss = tostring(value or "None")
                state.PositionTarget = nil
                state.PositionBasis = nil
                state.PositionAnchorY = nil
            end,
        })

        local levelQuestDropdown
        levelQuestDropdown = LevelSection:AddDropdown({
            Name = "Quest to Farm",
            Description = "Best automatically follows your level; manual choices list every quest giver available in this sea",
            Flag = "blox_level_quest",
            Options = currentSeaQuestOptions(),
            Default = AUTO_LEVEL_BEST_OPTION,
            Callback = function(value)
                state.SelectedLevelQuest = tostring(value or AUTO_LEVEL_BEST_OPTION)
                local quest = selectedLevelQuest()
                if quest then
                    questLabel.Text = string.format(
                        "Quest: %s | Target: %s | Lv. %d",
                        quest.DisplayName,
                        quest.EnemyName,
                        quest.LevelReq
                    )
                end
            end,
        })
        LevelSection:AddToggle({
            Name = "Auto Farm Level",
            Description = "Starts the selected current-sea quest and farms its required enemy",
            Flag = "blox_auto_level",
            Default = false,
            Callback = function(enabled)
                state.AutoFarmLevel = enabled
                state.ActiveFarmTarget = nil
                state.PositionTarget = nil
                if enabled then
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.PositionTarget = nil
                    state.LastPositionJitterAt = 0
                    for _, flag in ipairs({"blox_mob_aura_tp", "blox_selected_mob_farm"}) do
                        local control = Window.PersistentControls[flag]
                        if control and control:Get() then
                            control:Set(false)
                        end
                    end
                    if not state.AuraKill and auraToggle then
                        auraToggle:Set(true)
                    end
                else
                    state.CurrentQuestName = nil
                    state.CurrentEnemyName = nil
                    cancelMove()
                end
            end,
        })
        LevelSection:AddToggle({
            Name = "Auto Collect Chests",
            Description = "Moves to the nearest loaded chest and collects it",
            Flag = "blox_auto_chest",
            Default = false,
            Callback = function(enabled)
                state.AutoChest = enabled
            end,
        })

        FarmSettingsSection:AddSlider({
            Name = "Tween Speed",
            Flag = "blox_tween_speed",
            Min = 50,
            Max = 650,
            Step = 10,
            Default = 300,
            Callback = function(value)
                state.TweenSpeed = value
            end,
        })
        FarmSettingsSection:AddLabel("Combat tab controls Height, Fixed/Orbit movement, and Random Square for Auto Level, Boss Farm, Raid Farm, and Mob Aura.")
        FarmSettingsSection:AddToggle({
            Name = "Safe Mode",
            Description = "Retreats above the target until health recovers past the selected threshold",
            Flag = "blox_safe_mode",
            Default = false,
            Callback = function(enabled)
                state.SafeMode = enabled
            end,
        })
        FarmSettingsSection:AddSlider({
            Name = "Safe Mode Health %",
            Flag = "blox_safe_health",
            Min = 5,
            Max = 95,
            Step = 1,
            Default = 30,
            Callback = function(value)
                state.SafeHealthPercent = value
            end,
        })
        FarmSettingsSection:AddToggle({
            Name = "Auto Magnet Quest Enemies",
            Description = "Stacks matching quest, boss, or raid enemies at your attack position",
            Flag = "blox_auto_magnet",
            Default = false,
            Callback = function(enabled)
                state.AutoMagnet = enabled
            end,
        })
        FarmSettingsSection:AddSlider({
            Name = "Magnet Range",
            Flag = "blox_magnet_range",
            Min = 50,
            Max = 1500,
            Step = 25,
            Default = 300,
            Callback = function(value)
                state.MagnetRange = value
            end,
        })

        WorldFarmSection:AddButton({
            Name = "Refresh Live Quest Data",
            Description = "Refreshes every quest available in this sea and re-reads the selected quest",
            Callback = function()
                local options = currentSeaQuestOptions()
                if levelQuestDropdown then
                    levelQuestDropdown:SetOptions(options, true)
                end
                local quest = selectedLevelQuest()
                if quest then
                    questLabel.Text = string.format("Quest: %s | %s", quest.DisplayName, quest.EnemyName)
                    Window:Notify("Blox Fruits", "Selected quest: " .. quest.DisplayName, 3)
                else
                    setError("The selected quest is not available in this sea")
                end
            end,
        })

        ExploitSection:AddToggle({
            Name = "Multi Grab Enemies",
            Description = "Stacks several matching loaded enemies underneath you while Aura Kill attacks the pile",
            Flag = "blox_enemy_gather",
            Default = false,
            Callback = function(enabled)
                state.GatherEnemies = enabled
                if not enabled then
                    state.Gathered = 0
                end
                gui:SetAttribute("BloxMultiGrabEnemies", enabled)
            end,
        })
        ExploitSection:AddLabel("Locked: Selected / Current Mob | 3 enemies | 600 studs")
        local gatherMobDropdown = ExploitSection:AddDropdown({
            Name = "Multi Grab Enemy",
            Description = "Uses its own NPC choice; Current Farm Target follows Auto Level or Mob Farm",
            Flag = "blox_multi_grab_enemy",
            Options = gatherMobOptions(),
            Default = CURRENT_GATHER_TARGET,
            Callback = function(value)
                state.GatherSelectedMob = tostring(value or CURRENT_GATHER_TARGET)
                gui:SetAttribute("BloxMultiGrabEnemy", state.GatherSelectedMob)
            end,
        })
        ExploitSection:AddSlider({
            Name = "Grab Below Distance",
            Description = "How many studs underneath your character to hold the enemy stack",
            Flag = "blox_gather_distance",
            Min = 3,
            Max = 30,
            Step = 1,
            Default = 8,
            Callback = function(value)
                state.GatherDistance = math.clamp(tonumber(value) or 8, 3, 30)
            end,
        })
        local auraRangeSlider
        local mobAuraHeightSlider
        local mobAuraToggle
        local mobAuraSquareToggle
        local selectedMobFarmToggle
        local selectedMobDropdown

        local function resetMobAuraOrbit()
            state.MobAuraOrbitStartedAt = os.clock()
            state.MobAuraOrbitStartAngle = math.random() * math.pi * 2
            state.MobAuraOrbitDirection = math.random(0, 1) == 0 and -1 or 1
            state.MobAuraSquareOffset = Vector3.zero
            state.MobAuraSquareCorner = 0
            state.MobAuraLastSquareStep = 0
            state.PositionJitter = Vector3.zero
            state.PositionJitterCorner = 0
            state.LastPositionJitterAt = 0
        end

        local function requiredMobAuraRange()
            local radius = state.MobAuraRandomSquare and (state.MobAuraSquareSize * math.sqrt(2))
                or (state.MobAuraOrbit and state.MobAuraOrbitRadius or 0)
            local pathDistance = math.sqrt(state.MobAuraHeight ^ 2 + radius ^ 2)
            return math.min(AURA_KILL_MAX_RANGE, math.ceil(pathDistance + 8))
        end

        local function syncMobAuraRange()
            local requiredRange = requiredMobAuraRange()
            if (state.MobAuraTp or state.SelectedMobFarm)
                and state.AuraRange < requiredRange and auraRangeSlider then
                auraRangeSlider:Set(requiredRange)
            end
        end

        auraToggle = AttackSection:AddToggle({
            Name = "Aura Kill",
            Description = "Rapid silent tool hits on living NPCs inside the selected range; never swings your character",
            -- Keep the legacy flag so profiles that enabled Auto Attack now
            -- enable its Aura Kill replacement instead of losing the setting.
            Flag = "blox_auto_attack",
            Default = false,
            Callback = function(enabled)
                state.AuraKill = enabled
                state.LastAttack = 0
                state.LastAuraScan = 0
                state.AuraTargetCursor = 0
                if enabled then
                    resolveRegisterHitClosure()
                    local busoControl = Window.PersistentControls["blox_auto_buso"]
                    if busoControl and not busoControl:Get() then
                        busoControl:Set(true, true)
                    end
                    state.AutoBuso = true
                    task.defer(function()
                        if state.Alive and state.AutoBuso then
                            ensureBuso(true)
                        end
                    end)
                end
                auraLabel.Text = enabled
                    and string.format("Aura Kill: Armed | Range: %.0f studs", state.AuraRange)
                    or string.format("Aura Kill: Off | Range: %.0f studs", state.AuraRange)
                auraLabel.TextColor3 = enabled and COLORS.success or COLORS.muted
                gui:SetAttribute("BloxAuraKill", enabled)
                gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
                -- Compatibility for existing external status readers.
                gui:SetAttribute("BloxAutoAttack", enabled)
            end,
        })
        auraRangeSlider = AttackSection:AddSlider({
            Name = "Aura Kill Range",
            Description = "Server-tested silent-hit range in studs (70 is the safe maximum)",
            Flag = "blox_aura_kill_range",
            Min = 5,
            Max = AURA_KILL_MAX_RANGE,
            Step = 1,
            Default = AURA_KILL_DEFAULT_RANGE,
            Callback = function(value)
                state.AuraRange = math.clamp(tonumber(value) or AURA_KILL_DEFAULT_RANGE, 5, AURA_KILL_MAX_RANGE)
                if (state.MobAuraTp or state.SelectedMobFarm)
                    and state.MobAuraHeight > state.AuraRange - 8 then
                    local adjustedHeight = math.max(3, state.AuraRange - 8)
                    if mobAuraHeightSlider then
                        mobAuraHeightSlider:Set(adjustedHeight)
                    else
                        state.MobAuraHeight = adjustedHeight
                    end
                end
                auraLabel.Text = state.AuraKill
                    and string.format("Aura Kill: Armed | Range: %.0f studs", state.AuraRange)
                    or string.format("Aura Kill: Off | Range: %.0f studs", state.AuraRange)
                gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
                if state.MobAuraTp or state.SelectedMobFarm then
                    task.defer(syncMobAuraRange)
                end
            end,
        })
        AttackSection:AddToggle({
            Name = "Aura Kill Turbo",
            Description = "Uses the shortest validated silent-hit cadence instead of the tool's native cooldown",
            Flag = "blox_fast_attack",
            Default = false,
            Callback = function(enabled)
                state.FastAttack = enabled
                gui:SetAttribute("BloxFastAttack", enabled)
            end,
        })
        local weaponStatusLabel
        AttackSection:AddDropdown({
            Name = "Weapon",
            Flag = "blox_weapon_type",
            Options = {"Sword", "Melee", "M1 Fruit", "Best Available"},
            Default = "Sword",
            Callback = function(value)
                state.WeaponType = tostring(value)
                state.AuraCombo = 0
                table.clear(state.AuraCombos)
                local tool = selectedTool()
                if not tool then
                    state.AuraPendingError = "No " .. state.WeaponType .. " Tool was found"
                else
                    updateAuraWeaponState(tool, state.WeaponType)
                end
            end,
        })
        weaponStatusLabel = AttackSection:AddLabel("Weapon: waiting for selection")
        AttackSection:AddToggle({
            Name = "Double Attack (Sword + Fruit M1)",
            Description = "Dungeon-style engine: silent 12-target Sword batches plus independent 3-target Fruit M1",
            Flag = "blox_double_attack",
            Default = false,
            Callback = function(enabled)
                state.DoubleAttack = enabled
                state.LastAttack = 0
                state.LastDoubleFruitAttack = 0
                table.clear(state.AuraCombos)
                -- Write executor-owned GUI telemetry before touching live Tool
                -- Instances. Some executors downgrade the resumed coroutine's
                -- UI capability after crossing back into game-owned objects.
                gui:SetAttribute("BloxDoubleAttack", enabled)
                if enabled then
                    local sword = toolForSelection("Sword")
                    local fruit = toolForSelection("M1 Fruit")
                    if sword and fruit then
                        state.AuraWeaponName = sword.Name .. " + " .. fruit.Name
                        state.AuraWeaponType = "Sword + Blox Fruit"
                        state.AuraAttackMode = "Double Attack"
                    else
                        state.AuraPendingError = "Double Attack requires both a Sword and a Blox Fruit Tool"
                    end
                else
                    local tool = selectedTool()
                    updateAuraWeaponState(tool, state.WeaponType)
                end
            end,
        })
        AttackSection:AddSlider({
            Name = "Fruit M1 Cooldown Reduction",
            Description = "Subtracts 0.00-1.00 seconds from native fruit tap cooldowns; 0.28 is rapid",
            Flag = "blox_fruit_m1_cooldown_reduction",
            Min = 0,
            Max = 1,
            Step = 0.01,
            Default = DEFAULT_FRUIT_M1_COOLDOWN_REDUCTION,
            Callback = function(value)
                local reduction = applyFruitM1CooldownReduction(value)
                state.LastAttack = 0
                gui:SetAttribute("BloxFruitM1CooldownReduction", reduction)
            end,
        })
        applyFruitM1CooldownReduction(state.FruitM1CooldownReduction)
        AttackSection:AddSlider({
            Name = "Extra Aura Delay",
            Flag = "blox_attack_interval",
            Min = 0,
            Max = 0.50,
            Step = 0.01,
            Default = 0,
            Callback = function(value)
                state.AttackInterval = value
            end,
        })
        mobAuraToggle = AttackSection:AddToggle({
            Name = "Mob Aura TP",
            Description = "Teleports above the nearest living workspace.Enemies NPC and keeps Aura Kill armed",
            Flag = "blox_mob_aura_tp",
            Default = false,
            Callback = function(enabled)
                if enabled and state.SelectedMobFarm and selectedMobFarmToggle then
                    selectedMobFarmToggle:Set(false)
                end
                state.MobAuraTp = enabled
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                if enabled then
                    resetMobAuraOrbit()
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.AutoChest = false
                    cancelMove()
                    if not state.AuraKill and auraToggle then
                        auraToggle:Set(true)
                    end
                    syncMobAuraRange()
                    mobAuraLabel.Text = "Mob Aura TP: Searching for nearest NPC..."
                    mobAuraLabel.TextColor3 = COLORS.success
                else
                    mobAuraLabel.Text = "Mob Aura TP: Off | Distance: --"
                    mobAuraLabel.TextColor3 = COLORS.muted
                    if not state.SelectedMobFarm and not state.Noclip and not state.AutoFarmLevel and not state.AutoBoss
                        and not state.AutoRaid and not state.AutoChest then
                        restoreCollision()
                    end
                end
                gui:SetAttribute("BloxMobAuraTp", enabled)
            end,
        })
        AttackSection:AddSlider({
            Name = "Mob Aura Search Distance",
            Description = "Only teleports to the nearest living NPC inside this many studs",
            Flag = "blox_mob_aura_search_range",
            Min = 25,
            Max = 2500,
            Step = 25,
            Default = 500,
            Callback = function(value)
                state.MobAuraSearchRange = math.clamp(tonumber(value) or 500, 25, 2500)
                state.MobAuraTarget = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                gui:SetAttribute("BloxMobAuraSearchRange", state.MobAuraSearchRange)
            end,
        })
        selectedMobDropdown = AttackSection:AddDropdown({
            Name = "Mob Farm Enemy",
            Flag = "blox_selected_mob_name",
            Options = mobFarmOptions(),
            Default = "None",
            Callback = function(value)
                state.SelectedMobName = tostring(value or "None")
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                gui:SetAttribute("BloxSelectedMobName", state.SelectedMobName)
            end,
        })
        selectedMobFarmToggle = AttackSection:AddToggle({
            Name = "Selected Mob Farm TP",
            Description = "Farms only the chosen enemy and waits above its spawn when none are currently loaded",
            Flag = "blox_selected_mob_farm",
            Default = false,
            Callback = function(enabled)
                if enabled and state.MobAuraTp and mobAuraToggle then
                    mobAuraToggle:Set(false)
                end
                state.SelectedMobFarm = enabled
                state.MobAuraTarget = nil
                state.MobAuraTargetName = nil
                state.MobAuraDistance = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                state.SelectedMobWaitingAtSpawn = false
                if enabled then
                    resetMobAuraOrbit()
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                    state.AutoRaid = false
                    state.AutoChest = false
                    cancelMove()
                    if not state.AuraKill and auraToggle then
                        auraToggle:Set(true)
                    end
                    syncMobAuraRange()
                    selectedMobFarmLabel.Text = state.SelectedMobName == "None"
                        and "Selected Mob Farm: Choose an enemy"
                        or ("Selected Mob Farm: Searching for " .. state.SelectedMobName)
                    selectedMobFarmLabel.TextColor3 = state.SelectedMobName == "None"
                        and COLORS.warning or COLORS.success
                else
                    selectedMobFarmLabel.Text = "Selected Mob Farm: Off | Enemy: " .. state.SelectedMobName
                    selectedMobFarmLabel.TextColor3 = COLORS.muted
                    if not state.MobAuraTp and not state.Noclip and not state.AutoFarmLevel and not state.AutoBoss
                        and not state.AutoRaid and not state.AutoChest then
                        restoreCollision()
                    end
                end
                gui:SetAttribute("BloxSelectedMobFarm", enabled)
            end,
        })
        AttackSection:AddSlider({
            Name = "Selected Mob Search Distance",
            Description = "Maximum distance for the chosen loaded enemy; spawn waiting still works anywhere in this sea",
            Flag = "blox_selected_mob_search_range",
            Min = 500,
            Max = 30000,
            Step = 500,
            Default = 30000,
            Callback = function(value)
                state.SelectedMobSearchRange = math.clamp(tonumber(value) or 30000, 500, 30000)
                state.MobAuraTarget = nil
                state.MobAuraAnchorTarget = nil
                state.MobAuraStableAnchor = nil
                gui:SetAttribute("BloxSelectedMobSearchRange", state.SelectedMobSearchRange)
            end,
        })
        AttackSection:AddButton({
            Name = "Refresh Mob Farm Enemies",
            Description = "Re-reads enemy spawns and currently loaded workspace.Enemies names",
            Callback = function()
                selectedMobDropdown:SetOptions(mobFarmOptions(), true)
                if gatherMobDropdown then
                    gatherMobDropdown:SetOptions(gatherMobOptions(), true)
                end
                Window:Notify("Mob Farm", "Enemy list refreshed", 2.5)
            end,
        })
        mobAuraHeightSlider = AttackSection:AddSlider({
            Name = "Combat Farm Height",
            Description = "Shared height for Auto Level, Boss, Raid, Mob Aura, and Selected Mob Farm",
            Flag = "blox_mob_aura_height",
            Min = 3,
            Max = AURA_KILL_MAX_RANGE - 10,
            Step = 1,
            Default = 20,
            Callback = function(value)
                state.MobAuraHeight = math.clamp(tonumber(value) or 20, 3, AURA_KILL_MAX_RANGE - 10)
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraHeight", state.MobAuraHeight)
            end,
        })
        AttackSection:AddToggle({
            Name = "Combat Farm Random Orbit",
            Description = "Shared circular movement for every farm mode; the NPC itself never moves",
            Flag = "blox_mob_aura_orbit",
            Default = false,
            Callback = function(enabled)
                if enabled and state.MobAuraRandomSquare and mobAuraSquareToggle then
                    mobAuraSquareToggle:Set(false)
                end
                state.MobAuraOrbit = enabled
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraOrbit", enabled)
            end,
        })
        AttackSection:AddSlider({
            Name = "Combat Farm Orbit Radius",
            Description = "Shared horizontal circle size while Combat Farm Height controls elevation",
            Flag = "blox_mob_aura_orbit_radius",
            Min = 2,
            Max = 25,
            Step = 1,
            Default = 8,
            Callback = function(value)
                state.MobAuraOrbitRadius = math.clamp(tonumber(value) or 8, 2, 25)
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraOrbitRadius", state.MobAuraOrbitRadius)
            end,
        })
        AttackSection:AddSlider({
            Name = "Combat Farm Orbit Speed",
            Description = "Degrees per second to spin around the NPC",
            Flag = "blox_mob_aura_orbit_speed",
            Min = 20,
            Max = 720,
            Step = 10,
            Default = 110,
            Callback = function(value)
                state.MobAuraOrbitSpeed = math.clamp(tonumber(value) or 110, 20, 720)
                resetMobAuraOrbit()
                gui:SetAttribute("BloxMobAuraOrbitSpeed", state.MobAuraOrbitSpeed)
            end,
        })
        mobAuraSquareToggle = AttackSection:AddToggle({
            Name = "Combat Farm Random Square",
            Description = "Shared square movement for reliable Fruit M1 aim in Auto Level, Boss, Raid, and Mob Aura",
            Flag = "blox_mob_aura_random_square",
            Default = false,
            Callback = function(enabled)
                if enabled and state.MobAuraOrbit then
                    local orbitControl = Window.PersistentControls["blox_mob_aura_orbit"]
                    if orbitControl then
                        orbitControl:Set(false)
                    end
                end
                state.MobAuraRandomSquare = enabled
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraRandomSquare", enabled)
            end,
        })
        AttackSection:AddSlider({
            Name = "Combat Farm Square Size",
            Description = "Distance from the NPC center to each square corner",
            Flag = "blox_mob_aura_square_size",
            Min = 2,
            Max = 15,
            Step = 1,
            Default = 8,
            Callback = function(value)
                state.MobAuraSquareSize = math.clamp(tonumber(value) or 8, 2, 15)
                resetMobAuraOrbit()
                syncMobAuraRange()
                gui:SetAttribute("BloxMobAuraSquareSize", state.MobAuraSquareSize)
            end,
        })
        AttackSection:AddSlider({
            Name = "Combat Farm Square Step Delay",
            Description = "Seconds between square corner teleports; lower is faster",
            Flag = "blox_mob_aura_square_interval",
            Min = 0.06,
            Max = 0.80,
            Step = 0.02,
            Default = 0.18,
            Callback = function(value)
                state.MobAuraSquareInterval = math.clamp(tonumber(value) or 0.18, 0.06, 0.80)
                resetMobAuraOrbit()
                gui:SetAttribute("BloxMobAuraSquareInterval", state.MobAuraSquareInterval)
            end,
        })
        AttackSection:AddToggle({
            Name = "Auto Buso",
            Description = "Uses the real Aura Ability J input on PC and mobile, then restores Buso after respawn",
            Flag = "blox_auto_buso",
            Default = true,
            Callback = function(enabled)
                state.AutoBuso = enabled
                gui:SetAttribute("BloxAutoBuso", enabled)
                state.LastBuso = -math.huge
                if enabled then
                    task.defer(function()
                        if state.Alive and state.AutoBuso then
                            ensureBuso(true)
                        end
                    end)
                else
                    refreshBusoStatus()
                end
            end,
        })
        AttackSection:AddToggle({
            Name = "Auto Observation (Ken)",
            Description = "Keeps Instinct active through the verified CommE Ken controller",
            Flag = "blox_auto_observation",
            Default = false,
            Callback = function(enabled)
                state.AutoObservation = enabled
                state.LastObservation = 0
                if CommE then
                    task.defer(function()
                        pcall(function()
                            CommE:FireServer("Ken", enabled)
                        end)
                    end)
                end
            end,
        })

        BossSection:AddButton({
            Name = "Refresh Boss List",
            Callback = function()
                bossDropdown:SetOptions(bossNames(), false)
                Window:Notify("Boss Farm", "Boss list refreshed", 2.5)
            end,
        })
        BossSection:AddToggle({
            Name = "Auto Farm Selected Boss",
            Description = "Moves to the boss spawn, waits for it, and attacks when available",
            Flag = "blox_auto_boss",
            Default = false,
            Callback = function(enabled)
                state.AutoBoss = enabled
                state.ActiveFarmTarget = nil
                state.PositionTarget = nil
                state.PositionBasis = nil
                state.PositionAnchorY = nil
                if enabled then
                    state.AutoFarmLevel = false
                    state.AutoRaid = false
                else
                    cancelMove()
                end
                gui:SetAttribute("BloxAutoBoss", enabled)
            end,
        })

        StatsSection:AddToggle({
            Name = "Auto Stats",
            Flag = "blox_auto_stats",
            Default = false,
            Callback = function(enabled)
                state.AutoStats = enabled
            end,
        })
        StatsSection:AddSlider({
            Name = "Points Per Request",
            Flag = "blox_stat_batch",
            Min = 1,
            Max = 100,
            Step = 1,
            Default = 1,
            Callback = function(value)
                state.StatBatch = value
            end,
        })
        for _, statName in ipairs({"Melee", "Defense", "Sword", "Gun", "Demon Fruit"}) do
            StatsSection:AddToggle({
                Name = statName,
                Flag = "blox_stat_" .. string.lower((statName:gsub("%s+", "_"))),
                Default = state.Stats[statName] == true,
                Callback = function(enabled)
                    state.Stats[statName] = enabled
                end,
            })
        end

        FruitSection:AddButton({
            Name = "Roll Blox Fruit Once",
            Description = "Rolls remotely from your current position; no dealer teleport",
            Callback = function()
                task.spawn(function()
                    local ok, result = rollFruitOnce()
                    Window:Notify("Fruit Gacha", ok and tostring(result) or tostring(result), 4)
                end)
            end,
        })
        FruitSection:AddToggle({
            Name = "Auto Fruit Gacha",
            Description = "Checks and rolls remotely from anywhere without moving your character",
            Flag = "blox_auto_gacha",
            Default = false,
            Callback = function(enabled)
                state.AutoGacha = enabled
                if enabled then
                    state.LastGacha = -math.huge
                    state.GachaStatus = "Checking remote gacha..."
                end
                gui:SetAttribute("BloxAutoGacha", enabled)
            end,
        })
        FruitSection:AddSlider({
            Name = "Gacha Retry Seconds",
            Description = "How often Auto Gacha checks the server cooldown",
            Flag = "blox_gacha_interval",
            Min = 10,
            Max = 120,
            Step = 5,
            Default = 30,
            Callback = function(value)
                state.GachaInterval = math.clamp(tonumber(value) or 30, 10, 120)
                gui:SetAttribute("BloxGachaRetrySeconds", state.GachaInterval)
            end,
        })
        FruitSection:AddButton({
            Name = "Store Carried Fruits",
            Callback = function()
                task.spawn(function()
                    local stored, message = storeFruits()
                    Window:Notify("Fruit Storage", string.format("Stored: %d | %s", stored, tostring(message)), 4)
                end)
            end,
        })
        FruitSection:AddToggle({
            Name = "Auto Store Fruits",
            Flag = "blox_auto_store_fruit",
            Default = false,
            Callback = function(enabled)
                state.AutoStoreFruit = enabled
                if enabled then
                    state.LastStore = -math.huge
                end
                gui:SetAttribute("BloxAutoStoreFruit", enabled)
            end,
        })

        local locationDropdown
        local npcDropdown
        locationDropdown = TravelSection:AddDropdown({
            Name = "Island / Location",
            Flag = "blox_location",
            Options = locationOptions(),
            Default = "None",
            Callback = function(value)
                state.SelectedLocation = tostring(value or "None")
            end,
        })
        npcDropdown = TravelSection:AddDropdown({
            Name = "Loaded NPC",
            Flag = "blox_npc",
            Options = npcOptions(),
            Default = "None",
            Callback = function(value)
                state.SelectedNPC = tostring(value or "None")
            end,
        })
        TravelSection:AddButton({
            Name = "Teleport to Selected Location",
            Callback = function()
                local ok = state.SelectedLocation ~= "None" and teleportToLocation(state.SelectedLocation)
                Window:Notify("Travel", ok and ("Traveling to " .. state.SelectedLocation) or "Choose a valid location", 3)
            end,
        })
        TravelSection:AddButton({
            Name = "Teleport to Selected NPC",
            Callback = function()
                local ok = state.SelectedNPC ~= "None" and teleportToNpc(state.SelectedNPC)
                Window:Notify("Travel", ok and ("Traveling to " .. state.SelectedNPC) or "Choose a loaded NPC", 3)
            end,
        })
        TravelSection:AddButton({
            Name = "Refresh Travel Lists",
            Callback = function()
                locationDropdown:SetOptions(locationOptions(), false)
                npcDropdown:SetOptions(npcOptions(), false)
                Window:Notify("Travel", "Locations and NPCs refreshed", 2.5)
            end,
        })
        TravelSection:AddButton({Name = "Travel to First Sea", Callback = function() invoke("TravelMain") end})
        TravelSection:AddButton({Name = "Travel to Second Sea", Callback = function() invoke("TravelDressrosa") end})
        TravelSection:AddButton({Name = "Travel to Third Sea", Callback = function() invoke("TravelZou") end})

        local fightingStyles = {
            {"Superhuman", "BuySuperhuman"},
            {"Death Step", "BuyDeathStep"},
            {"Sharkman Karate", "BuySharkmanKarate"},
            {"Electric Claw", "BuyElectricClaw"},
            {"Dragon Talon", "BuyDragonTalon"},
            {"Godhuman", "BuyGodhuman"},
        }
        for _, entry in ipairs(fightingStyles) do
            FightingStyleSection:AddButton({
                Name = "Check / Buy " .. entry[1],
                Description = "Uses the game's own purchase endpoint; requirements still apply",
                Callback = function()
                    local ok, result = invoke(entry[2], true)
                    Window:Notify(entry[1], ok and tostring(result or "Request sent") or tostring(result), 3)
                end,
            })
        end

        local raidTypes = {"Flame", "Ice", "Sand", "Dark", "Light", "Magma", "Quake", "Buddha", "Spider", "Rumble", "Phoenix", "Dough"}
        RaidSection:AddDropdown({
            Name = "Raid Chip",
            Flag = "blox_raid_chip",
            Options = raidTypes,
            Default = "Flame",
            Callback = function(value)
                state.SelectedRaid = tostring(value)
            end,
        })
        RaidSection:AddButton({
            Name = "Buy Selected Raid Chip",
            Callback = function()
                local ok, result = invoke("RaidsNpc", "Select", state.SelectedRaid)
                Window:Notify("Raid Chip", ok and "Purchase request sent" or tostring(result), 3)
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Buy Raid Chip",
            Flag = "blox_auto_buy_raid_chip",
            Default = false,
            Callback = function(enabled)
                state.AutoBuyRaidChip = enabled
            end,
        })
        RaidSection:AddButton({
            Name = "Start Dungeon / Raid Once",
            Callback = function()
                local ok, result = fireRaidButton()
                Window:Notify("Raid", tostring(result), 3)
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Start Dungeon / Raid",
            Flag = "blox_auto_start_raid",
            Default = false,
            Callback = function(enabled)
                state.AutoStartRaid = enabled
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Farm Dungeon / Raid",
            Flag = "blox_auto_raid",
            Default = false,
            Callback = function(enabled)
                state.AutoRaid = enabled
                state.ActiveFarmTarget = nil
                state.PositionTarget = nil
                if enabled then
                    state.AutoFarmLevel = false
                    state.AutoBoss = false
                else
                    state.RaidIslandIndex = 0
                    state.RaidIslandName = nil
                    state.RaidTargetName = nil
                    state.ActiveFarmHeightOverride = nil
                    state.RaidVoidActive = false
                    state.RaidVoidMoved = 0
                    cancelMove()
                end
                gui:SetAttribute("BloxAutoRaid", enabled)
                gui:SetAttribute("BloxRaidIslandIndex", state.RaidIslandIndex)
                gui:SetAttribute("BloxRaidIslandName", state.RaidIslandName or "")
                gui:SetAttribute("BloxRaidTarget", state.RaidTargetName or "")
            end,
        })
        RaidSection:AddLabel("Raid farm stays at least 35 studs above NPCs. Combat Height can raise it, never lower it.")
        RaidSection:AddToggle({
            Name = "Raid Multi Grab",
            Description = "Stacks up to 3 living raid NPCs 8 studs below you; disabled automatically during final-island Void Kill",
            Flag = "blox_raid_multi_grab",
            Default = false,
            Callback = function(enabled)
                state.RaidMultiGrab = enabled
                if not enabled then
                    state.RaidGathered = 0
                end
                gui:SetAttribute("BloxRaidMultiGrab", enabled)
            end,
        })
        RaidSection:AddToggle({
            Name = "Force Kill Aura [Island 5]",
            Description = "Matches Solix: network-finishes Island 5 NPCs at full health and leaves each corpse replicated to fall naturally",
            Flag = "blox_raid_void_kill",
            Default = false,
            Callback = function(enabled)
                state.RaidVoidKill = enabled
                state.RaidVoidActive = false
                state.RaidVoidMoved = 0
                state.RaidVoidStaged = 0
                if enabled then
                    state.LastRaidVoidStep = 0
                    state.RaidVoidKillCount = 0
                    table.clear(state.RaidVoidTargets)
                    table.clear(state.RaidVoidOriginalCFrames)
                end
                gui:SetAttribute("BloxRaidVoidKill", enabled)
            end,
        })
        RaidSection:AddToggle({
            Name = "Auto Awakening",
            Flag = "blox_auto_awaken",
            Default = false,
            Callback = function(enabled)
                state.AutoAwaken = enabled
            end,
        })

        state.SeaEvent.Section = SeaPage:AddSection("Sea Event Automation", "Left")
        state.SeaEvent.Section:AddDropdown({
            Name = "Sea Monster Selection",
            Description = "Select several sea enemies; VOR kills each active target and returns to the boat",
            Flag = "blox_sea_event_priority",
            Options = {
                "Piranha",
                "Shark",
                "Terror Shark",
                "Fish Crew Member",
                "Enemy Boat",
                "Sea Beast",
            },
            Multi = true,
            Default = {
                "Piranha",
                "Shark",
                "Terror Shark",
                "Fish Crew Member",
                "Enemy Boat",
                "Sea Beast",
            },
            Callback = function(value)
                state.SeaEvent.SelectedEvents = type(value) == "table" and value or {}
            end,
        })
        state.SeaEvent.Section:AddDropdown({
            Name = "Selected Boat",
            Description = "The server must show this boat as owned/unlocked",
            Flag = "blox_sea_event_boat",
            Options = state.SeaEvent.BoatNames,
            Default = "Guardian",
            Callback = function(value)
                state.SeaEvent.SelectedBoat = tostring(value)
            end,
        })
        state.SeaEvent.Section:AddSlider({
            Name = "Boat Tween Speed",
            Description = "Requested speed from 0-500; snap-back detection automatically finds a lower server-safe limit",
            Flag = "blox_sea_event_boat_speed",
            Min = 0,
            Max = 500,
            Step = 10,
            Default = 295,
            Callback = function(value)
                state.SeaEvent.BoatTweenSpeed = math.clamp(tonumber(value) or 295, 0, 500)
                state.SeaEvent.ResetAdaptiveSpeed()
            end,
        })
        state.SeaEvent.Section:AddSlider({
            Name = "Boat Float Height",
            Description = "Extra height above the boat's native waterline; keep 0 for the server-safe Solix path",
            Flag = "blox_sea_event_boat_height",
            Min = 0,
            Max = 10,
            Step = 1,
            Default = 0,
            Callback = function(value)
                state.SeaEvent.BoatFloatHeight = math.clamp(tonumber(value) or 0, 0, 10)
            end,
        })
        state.SeaEvent.Section:AddDropdown({
            Name = "Stop Sail Condition",
            Description = "Select any event islands where Auto Stop Sail should freeze the boat",
            Flag = "blox_sea_event_stop_conditions",
            Options = {"Kitsune Island", "Prehistoric Island", "Mirage Island", "Frozen Dimension"},
            Multi = true,
            Default = {},
            Callback = function(value)
                state.SeaEvent.StopConditions = type(value) == "table" and value or {}
                state.SeaEvent.StopMatch = nil
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Auto Stop Sail",
            Description = "Stops the boat when any selected island condition is detected",
            Flag = "blox_sea_event_auto_stop",
            Default = false,
            Callback = function(enabled)
                state.SeaEvent.AutoStopSail = enabled == true
                state.SeaEvent.StopMatch = nil
            end,
        })
        state.SeaEvent.Section:AddSlider({
            Name = "Sea Combat Height",
            Description = "Terror Sharks and boats stay below you; Sea Beasts use half this height to keep you inside their hitbox",
            Flag = "blox_sea_event_combat_height",
            Min = 8,
            Max = 70,
            Step = 1,
            Default = 24,
            Callback = function(value)
                state.SeaEvent.CombatHeight = math.clamp(tonumber(value) or 24, 8, 70)
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Spam Every Tool Skill",
            Description = "Cycles every combat Tool and repeatedly fires M1 plus Z, X, C, V, and F",
            Flag = "blox_sea_event_all_skills",
            Default = true,
            Callback = function(enabled)
                state.SeaEvent.SpamAllSkills = enabled == true
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Reset When Boat Breaks",
            Description = "Respawns at the dock, buys the selected boat again, reseats, and resumes sailing",
            Flag = "blox_sea_event_reset_boat",
            Default = true,
            Callback = function(enabled)
                state.SeaEvent.ResetBrokenBoat = enabled == true
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Auto Kill Sea Enemy",
            Description = "Leaves the boat, kills every selected sea enemy without touching water, then reseats",
            Flag = "blox_auto_kill_sea_enemy",
            Default = false,
            Callback = function(enabled)
                state.SeaEvent.AutoKill = enabled == true
                state.SeaEvent.Enabled = state.SeaEvent.AutoSail or state.SeaEvent.AutoKill
                state.SeaEvent.Target = nil
                state.SeaEvent.TargetKind = nil
                if enabled then
                    prepareManualTravel()
                    state.SeaEvent.Phase = "Searching for selected sea enemies"
                else
                    state.SeaEvent.DestroySafety()
                    if not state.SeaEvent.Enabled then
                        state.SeaEvent.Phase = "Off"
                        state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                        state.SeaEvent.RestoreBoatNoclip()
                        state.SeaEvent.LastCommandedPosition = nil
                    end
                end
                state.SeaEvent.UpdateStatus()
            end,
        })
        state.SeaEvent.Section:AddToggle({
            Name = "Auto Sail",
            Description = "Buys the selected boat, seats normally, and sails straight at the server-safe waterline",
            Flag = "blox_auto_sea_events",
            Default = false,
            Callback = function(enabled)
                state.SeaEvent.AutoSail = enabled == true
                state.SeaEvent.Enabled = state.SeaEvent.AutoSail or state.SeaEvent.AutoKill
                state.SeaEvent.LastError = nil
                state.SeaEvent.Target = nil
                state.SeaEvent.TargetKind = nil
                if enabled then
                    prepareManualTravel()
                    state.SeaEvent.Phase = "Finding Boat Dealer"
                    state.SeaEvent.ResetAdaptiveSpeed()
                else
                    state.SeaEvent.Phase = state.SeaEvent.AutoKill and "Auto Kill waiting" or "Off"
                    state.SeaEvent.StopBoat(state.SeaEvent.Boat)
                    state.SeaEvent.RestoreBoatNoclip()
                    if not state.SeaEvent.AutoKill then
                        state.SeaEvent.DestroySafety()
                    end
                    state.SeaEvent.LastCommandedPosition = nil
                end
                state.SeaEvent.UpdateStatus()
            end,
        })
        state.SeaEvent.StatusLabel = state.SeaEvent.Section:AddLabel("Sea Events: Off")
        state.SeaEvent.DetailLabel = state.SeaEvent.Section:AddLabel(
            "Boat: Guardian | Event: Searching | Snap-backs: 0 | Completed: 0"
        )

        track(RunService.Heartbeat:Connect(function(deltaTime)
            if not state.Alive then
                return
            end
            local ok, message = pcall(state.SeaEvent.Step, deltaTime)
            if not ok then
                state.SeaEvent.LastError = tostring(message)
                state.SeaEvent.Phase = "Error: " .. tostring(message)
                state.SeaEvent.UpdateStatus()
            end
        end))

        PlayerStateSection:AddToggle({
            Name = "Noclip",
            Flag = "blox_noclip",
            Default = false,
            Callback = function(enabled)
                state.Noclip = enabled
                if not enabled then
                    restoreCollision()
                end
            end,
        })
        updateWaterPlatform()
        PlayerStateSection:AddToggle({
            Name = "Infinite Energy",
            Flag = "blox_infinite_energy",
            Default = false,
            Callback = function(enabled)
                state.InfiniteEnergy = enabled
            end,
        })
        PlayerStateSection:AddToggle({
            Name = "Walk on Water",
            Flag = "blox_walk_water",
            Default = true,
            Persist = false,
            Callback = function(enabled)
                state.WalkOnWater = enabled
                gui:SetAttribute("BloxWalkOnWater", enabled)
                updateWaterPlatform()
            end,
        })
        PlayerStateSection:AddToggle({
            Name = "Anti-AFK / Anti-Idle",
            Flag = "blox_anti_afk",
            Default = true,
            Callback = function(enabled)
                state.AntiAfk = enabled
            end,
        })

        VisualSection:AddToggle({
            Name = "Enemy ESP",
            Flag = "blox_enemy_esp",
            Default = false,
            Callback = function(enabled)
                state.EnemyESP = enabled
                updateEsp()
            end,
        })
        VisualSection:AddToggle({
            Name = "Player ESP",
            Description = "Unlimited-distance highlight, name and distance tag, plus an on-screen joint skeleton",
            Flag = "blox_player_esp",
            Default = false,
            Callback = function(enabled)
                state.PlayerESP = enabled
                gui:SetAttribute("BloxPlayerESP", enabled)
                updateEsp()
            end,
        })
        VisualSection:AddToggle({
            Name = "Reversible FPS Boost",
            Description = "Disables world effects and restores them when switched off",
            Flag = "blox_fps_boost",
            Default = false,
            Callback = function(enabled)
                setFpsBoost(enabled)
            end,
        })

        SessionSection:AddButton({
            Name = "Rejoin Current Server",
            Callback = function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            end,
        })
        SessionSection:AddButton({
            Name = "Server Hop",
            Description = "Finds a different non-full public server",
            Callback = function()
                task.spawn(function()
                    local ok, message = pcall(function()
                        local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
                        local data = HttpService:JSONDecode(game:HttpGet(url))
                        for _, server in ipairs(data.data or {}) do
                            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                                return
                            end
                        end
                        error("No open server was found")
                    end)
                    if not ok then
                        Window:Notify("Server Hop", tostring(message), 4)
                    end
                end)
            end,
        })

        track(LocalPlayer.Idled:Connect(function()
            if state.AntiAfk then
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
                    task.wait(0.05)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new())
                end)
            end
        end))

        track(LocalPlayer.CharacterAdded:Connect(function(newCharacter)
            cancelMove(false)
            FarmVertical.Release()
            state.LastAttack = 0
            state.LastAuraScan = 0
            state.LastBuso = -math.huge
            state.AuraTargetCursor = 0
            state.AuraCombo = 0
            table.clear(state.AuraCombos)
            table.clear(state.NativeFruitCombos)
            state.FruitM1ReadyAt = 0
            state.AuraFruitBusy = false
            state.FruitDispatchPending = false
            state.LastDoubleFruitAttack = 0
            state.InventoryBusy = false
            state.AuraFruitInRange = nil
            state.AuraFruitLastDistance = nil
            state.OriginalFruitTapCooldown = tonumber(newCharacter:GetAttribute("FruitTAPCooldown")) or 0
            newCharacter:SetAttribute("FruitTAPCooldown", state.FruitM1CooldownReduction)
            resetMobAuraOrbit()
            state.MobAuraTarget = nil
            state.MobAuraTargetName = nil
            state.MobAuraDistance = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            state.GatherSingleFallbackEnemy = nil
            table.clear(state.GatherOriginalCFrames)
            state.ActiveFarmTarget = nil
            state.ActiveFarmHeightOverride = nil
            state.AntiRagdollApplied = false
            state.AntiRagdollHumanoid = nil
            if state.AutoBuso then
                task.delay(0.5, function()
                    if state.Alive and state.AutoBuso then
                        ensureBuso(true)
                    end
                end)
            end
            task.delay(0.15, function()
                if state.Alive and newCharacter.Parent then
                    FarmVertical.RecoverBody()
                end
            end)
        end))

        track(LocalPlayer:GetAttributeChangedSignal("IslandRaiding"):Connect(function()
            cancelMove(false)
            FarmVertical.Release()
            state.ActiveFarmTarget = nil
            state.ActiveFarmHeightOverride = nil
            state.PositionTarget = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            state.RaidVoidActive = false
            state.RaidVoidMoved = 0
            state.RaidVoidStaged = 0
            state.RaidGathered = 0
            if LocalPlayer:GetAttribute("IslandRaiding") == true then
                local now = os.clock()
                local freshRaid = not state.RaidHasEntered
                    or now - state.RaidLastInactiveAt >= 3
                state.RaidHasEntered = true
                state.RaidEnteredAt = freshRaid and now or 0
                if freshRaid then
                    state.RaidVoidKillCount = 0
                    state.LastRaidVoidStep = 0
                    table.clear(state.RaidVoidTargets)
                    table.clear(state.RaidVoidOriginalCFrames)
                end
            else
                state.RaidEnteredAt = 0
                state.RaidLastInactiveAt = os.clock()
            end
            task.defer(function()
                if state.Alive then
                    FarmVertical.RecoverBody()
                end
            end)
        end))

        track(RunService.Heartbeat:Connect(function()
            if not state.Alive then
                return
            end
            if state.MobAuraTp or state.SelectedMobFarm then
                applyNoclip()
                stepMobAuraTp()
            end
            local attackBlocked = state.SafeMode and healthPercent() <= state.SafeHealthPercent
            if not attackBlocked and state.AuraKill then
                if state.DoubleAttack then
                    DoubleAttackEngine.StepFruit()
                end
                auraKillOnce()
            end
            local combatFarmEnabled = state.AutoFarmLevel or state.AutoBoss or state.AutoRaid
            FarmVertical.SetAntiRagdoll(combatFarmEnabled)
            local activeCombatFarm = combatFarmEnabled and modelAlive(state.ActiveFarmTarget)
            -- Noclip remains enabled while waiting at a quest/boss/raid spawn.
            -- Keep a vertical hold for that entire session or gravity sends the
            -- player through the map the moment the current NPC disappears.
            if combatFarmEnabled then
                applyNoclip()
                if not state.Traveling then
                    FarmVertical.RecoverBody()
                end
            end
            if activeCombatFarm
                and not attackBlocked
                and not state.AuraFruitBusy then
                local farmTarget = state.ActiveFarmTarget
                if modelAlive(farmTarget) then
                    local targetCFrame = positionAtEnemy(
                        farmTarget,
                        state.ActiveFarmVerticalLock,
                        state.ActiveFarmHeightOverride
                    )
                    if targetCFrame then
                        if state.MobAuraOrbit or state.MobAuraRandomSquare then
                            moveToFarmPosition(targetCFrame)
                        elseif not state.Traveling then
                            -- The fixed-above mode still needs to own the exact
                            -- farm altitude. Otherwise FarmVertical can remember
                            -- a gravity-sagged frame and fight the main farm loop,
                            -- which was the visible boss up/down bounce.
                            state.FarmHoldY = targetCFrame.Position.Y
                        end
                    end
                end
            end
            if combatFarmEnabled then
                FarmVertical.Ensure()
            else
                FarmVertical.Release()
            end
            gatherStep()
            if state.Noclip or state.Traveling or state.MobAuraTp or state.SelectedMobFarm
                or state.AutoFarmLevel or state.AutoBoss or state.AutoRaid or state.AutoChest then
                applyNoclip()
            end
            updateEnergy()
            updateWaterPlatform()
        end))

        track(RunService.RenderStepped:Connect(function()
            if state.Alive and state.PlayerESP then
                PlayerEsp.Update(false)
            end
        end))

        track(workspace.DescendantAdded:Connect(function(descendant)
            if state.FpsBoost then
                task.defer(function()
                    if descendant.Parent then
                        pcall(optimizeInstance, descendant)
                    end
                end)
            end
        end))

        task.spawn(function()
            local lastRaidPurchase = 0
            local lastRaidStart = 0
            local lastAwaken = 0
            local lastEsp = 0
            local lastQuestDataRefresh = 0
            local lastQuestDataFingerprint = ""
            while state.Alive do
                local ok, message = pcall(function()
                    flushAuraTelemetry()
                    gui:SetAttribute("BloxAutoLevel", state.AutoFarmLevel)
                    gui:SetAttribute("BloxAutoBoss", state.AutoBoss)
                    gui:SetAttribute("BloxAutoRaid", state.AutoRaid)
                    gui:SetAttribute("BloxAutoBuso", state.AutoBuso)
                    gui:SetAttribute("BloxWalkOnWater", state.WalkOnWater)
                    gui:SetAttribute("BloxPlayerESP", state.PlayerESP)
                    if os.clock() - lastQuestDataRefresh >= 6 then
                        lastQuestDataRefresh = os.clock()
                        local options = currentSeaQuestOptions()
                        local fingerprint = table.concat({
                            state.CurrentSeaName,
                            tostring(state.CurrentSeaQuestCount),
                            tostring(state.CurrentSeaMinimumLevel),
                            tostring(state.CurrentSeaMaximumLevel),
                        }, "|")
                        if fingerprint ~= lastQuestDataFingerprint then
                            lastQuestDataFingerprint = fingerprint
                            if levelQuestDropdown then
                                levelQuestDropdown:SetOptions(options, true)
                            end
                            if state.SelectedLevelQuest ~= AUTO_LEVEL_BEST_OPTION
                                and not levelQuestByOption[state.SelectedLevelQuest] then
                                state.SelectedLevelQuest = AUTO_LEVEL_BEST_OPTION
                                if levelQuestDropdown then
                                    levelQuestDropdown:Set(AUTO_LEVEL_BEST_OPTION)
                                end
                            end
                        end
                    end
                    if weaponStatusLabel then
                        if state.AuraWeaponName then
                            local weaponText = string.format(
                                "Weapon: %s | %s",
                                state.AuraWeaponName,
                                state.AuraAttackMode or state.AuraWeaponType or state.WeaponType
                            )
                            local mode = string.lower(tostring(state.AuraAttackMode or state.WeaponType))
                            local fruitActive = state.DoubleAttack or string.find(mode, "fruit", 1, true) ~= nil
                            if fruitActive then
                                if state.AuraFruitLastDistance then
                                    weaponText = weaponText .. string.format(
                                        state.AuraFruitInRange
                                            and " | Fruit %.1f / %d studs"
                                            or " | Fruit OUT OF RANGE %.1f / %d studs",
                                        state.AuraFruitLastDistance,
                                        NATIVE_FRUIT_MAX_RANGE
                                    )
                                else
                                    weaponText = weaponText .. string.format(
                                        " | Fruit native reach: %d studs",
                                        NATIVE_FRUIT_MAX_RANGE
                                    )
                                end
                            end
                            weaponStatusLabel.Text = weaponText
                            weaponStatusLabel.TextColor3 = fruitActive and state.AuraFruitInRange == false
                                and COLORS.warning or COLORS.success
                        else
                            weaponStatusLabel.Text = "Weapon: No " .. tostring(state.WeaponType) .. " Tool found"
                            weaponStatusLabel.TextColor3 = COLORS.muted
                        end
                    end
                    if state.SelectedMobFarm then
                        if state.SelectedMobName == "None" then
                            selectedMobFarmLabel.Text = "Selected Mob Farm: Choose an enemy"
                            selectedMobFarmLabel.TextColor3 = COLORS.warning
                        elseif state.MobAuraTargetName and state.MobAuraDistance then
                            selectedMobFarmLabel.Text = string.format(
                                "Selected Mob Farm: %s | Distance: %.1f | Height: %.0f%s",
                                state.MobAuraTargetName,
                                state.MobAuraDistance,
                                state.MobAuraHeight,
                                state.MobAuraRandomSquare and string.format(" | Square: %.0f", state.MobAuraSquareSize)
                                    or (state.MobAuraOrbit and string.format(" | Orbit: %.0f", state.MobAuraOrbitRadius) or "")
                            )
                            selectedMobFarmLabel.TextColor3 = COLORS.success
                        elseif state.SelectedMobWaitingAtSpawn then
                            selectedMobFarmLabel.Text = string.format(
                                "Selected Mob Farm: Waiting above %s spawn | Height: %.0f",
                                state.SelectedMobName,
                                state.MobAuraHeight
                            )
                            selectedMobFarmLabel.TextColor3 = COLORS.muted
                        else
                            selectedMobFarmLabel.Text = "Selected Mob Farm: No spawn found for " .. state.SelectedMobName
                            selectedMobFarmLabel.TextColor3 = COLORS.warning
                        end
                    elseif state.MobAuraTp then
                        if state.MobAuraTargetName and state.MobAuraDistance then
                            if state.MobAuraRandomSquare then
                                mobAuraLabel.Text = string.format(
                                    "Mob Aura TP: %s | Distance: %.1f | Height: %.0f | Square: %.0f @ %.2fs",
                                    state.MobAuraTargetName,
                                    state.MobAuraDistance,
                                    state.MobAuraHeight,
                                    state.MobAuraSquareSize,
                                    state.MobAuraSquareInterval
                                )
                            elseif state.MobAuraOrbit then
                                mobAuraLabel.Text = string.format(
                                    "Mob Aura TP: %s | Distance: %.1f | Height: %.0f | Orbit: %.0f @ %.0f deg/s",
                                    state.MobAuraTargetName,
                                    state.MobAuraDistance,
                                    state.MobAuraHeight,
                                    state.MobAuraOrbitRadius,
                                    state.MobAuraOrbitSpeed
                                )
                            else
                                mobAuraLabel.Text = string.format(
                                    "Mob Aura TP: %s | Distance: %.1f | Height: %.0f | Fixed above",
                                    state.MobAuraTargetName,
                                    state.MobAuraDistance,
                                    state.MobAuraHeight
                                )
                            end
                            mobAuraLabel.TextColor3 = COLORS.success
                        elseif state.MobAuraDistance then
                            mobAuraLabel.Text = string.format(
                                "Mob Aura TP: No NPC within %.0f | Nearest: %.1f",
                                state.MobAuraSearchRange,
                                state.MobAuraDistance
                            )
                            mobAuraLabel.TextColor3 = COLORS.muted
                        else
                            mobAuraLabel.Text = string.format(
                                "Mob Aura TP: Waiting for NPC | Search: %.0f",
                                state.MobAuraSearchRange
                            )
                            mobAuraLabel.TextColor3 = COLORS.muted
                        end
                    end
                    if state.AutoRaid then
                        stepRaid()
                    elseif state.AutoBoss then
                        stepBossFarm()
                    elseif state.AutoFarmLevel then
                        stepAutoLevel()
                    elseif state.AutoChest then
                        stepChest()
                    elseif state.AuraKill then
                        local targets = nearbyAuraTargets()
                        local target = targets[1]
                        if target then
                            state.CurrentEnemyName = normalizeEnemyName(target.Enemy.Name)
                            targetLabel.Text = string.format("Aura target: %s | %.1f / %.0f studs", state.CurrentEnemyName, target.Distance, state.AuraRange)
                        else
                            targetLabel.Text = string.format("Aura target: No living NPC within %.0f studs", state.AuraRange)
                        end
                        auraLabel.Text = string.format(
                            "Aura Kill: Armed | In range: %d | Damage hits: %d | Requests: %d",
                            #targets,
                            state.AuraHits,
                            state.AuraRequests
                        )
                        auraLabel.TextColor3 = #targets > 0 and COLORS.success or COLORS.muted
                    end

                    if state.AutoBuso then
                        ensureBuso(false)
                    else
                        refreshBusoStatus()
                    end

                    if state.AutoObservation and CommE and os.clock() - state.LastObservation >= 2 then
                        state.LastObservation = os.clock()
                        pcall(function()
                            CommE:FireServer("Ken", true)
                        end)
                    end

                    stepStats()

                    if state.AutoGacha and os.clock() - state.LastGacha >= state.GachaInterval then
                        state.LastGacha = os.clock()
                        task.spawn(rollFruitOnce)
                    end
                    if state.AutoStoreFruit and os.clock() - state.LastStore >= 8 then
                        state.LastStore = os.clock()
                        task.spawn(storeFruits)
                    end
                    fruitGachaLabel.Text = string.format(
                        "Fruit Gacha: %s | Rolls this session: %d | Retry: %.0fs",
                        state.GachaStatus,
                        state.GachaRolls,
                        state.GachaInterval
                    )
                    fruitGachaLabel.TextColor3 = state.GachaBusy and COLORS.warning
                        or (state.GachaRolls > 0 and COLORS.success or COLORS.muted)
                    fruitStoreLabel.Text = string.format(
                        "Fruit Storage: %s | Stored this session: %d",
                        state.StoreStatus,
                        state.FruitsStored
                    )
                    fruitStoreLabel.TextColor3 = state.InventoryBusy and COLORS.warning
                        or (state.FruitsStored > 0 and COLORS.success or COLORS.muted)

                    if state.AutoBuyRaidChip and not RaidRuntime.Active()
                        and not RaidRuntime.RaidChip()
                        and os.clock() - lastRaidPurchase >= 15 then
                        lastRaidPurchase = os.clock()
                        invoke("RaidsNpc", "Select", state.SelectedRaid)
                    end
                    if state.AutoStartRaid and not RaidRuntime.Active() and os.clock() - lastRaidStart >= 5 then
                        lastRaidStart = os.clock()
                        fireRaidButton()
                    end
                    if state.AutoAwaken and os.clock() - lastAwaken >= 4 then
                        lastAwaken = os.clock()
                        invoke("Awakener", "Awaken")
                    end

                    local gatherText = string.format(
                        "Multi Grab: %d / %d | %s | Range: %d | Below: %.0f%s",
                        state.Gathered,
                        MULTI_GRAB_LIMIT,
                        state.GatherSelectedMob,
                        MULTI_GRAB_RANGE,
                        state.GatherDistance,
                        state.GatherSingleFallbackEnemy and " | Last NPC: actual position" or ""
                    )
                    if gatherText ~= state.LastGatherLabelText then
                        state.LastGatherLabelText = gatherText
                        gatherLabel.Text = gatherText
                    end

                    if os.clock() - lastEsp >= 1 then
                        lastEsp = os.clock()
                        if state.EnemyESP or state.PlayerESP then
                            updateEsp()
                        end
                        seaLabel.Text = string.format(
                            "Sea: %s | Quests: %d (Lv. %d-%d) | Loaded enemies: %d",
                            state.CurrentSeaName,
                            state.CurrentSeaQuestCount,
                            state.CurrentSeaMinimumLevel,
                            state.CurrentSeaMaximumLevel,
                            #loadedEnemies()
                        )
                        playerLabel.Text = string.format("Player: Level %d | Stat points %d", currentLevel(), currentPoints())
                        observationLabel.Text = string.format(
                            "Observation: %s | Dodges: %s / %s",
                            state.AutoObservation and "Auto" or "Manual",
                            tostring(LocalPlayer:GetAttribute("KenDodgesLeft") or "N/A"),
                            tostring(LocalPlayer:GetAttribute("KenMaxDodges") or "N/A")
                        )
                        gui:SetAttribute("BloxPlayerESPCount", PlayerEsp.Count())
                        gui:SetAttribute(
                            "BloxPlayerESPSkeletonSupported",
                            type(Drawing) == "table" and type(Drawing.new) == "function"
                        )
                        gui:SetAttribute("BloxRaidActive", RaidRuntime.Active())
                        gui:SetAttribute("BloxRaidIslandIndex", state.RaidIslandIndex)
                        gui:SetAttribute("BloxRaidIslandName", state.RaidIslandName or "")
                        gui:SetAttribute("BloxRaidTarget", state.RaidTargetName or "")
                        gui:SetAttribute("BloxRaidMultiGrab", state.RaidMultiGrab)
                        gui:SetAttribute("BloxRaidMultiGrabCount", state.RaidGathered)
                        gui:SetAttribute("BloxRaidVoidKill", state.RaidVoidKill)
                        gui:SetAttribute("BloxRaidVoidActive", state.RaidVoidActive)
                        gui:SetAttribute("BloxRaidVoidMoved", state.RaidVoidMoved)
                        gui:SetAttribute("BloxRaidVoidStaged", state.RaidVoidStaged)
                        gui:SetAttribute("BloxRaidVoidKillCount", state.RaidVoidKillCount)
                        gui:SetAttribute("BloxRaidSafeHeight", state.RaidSafeHeight)
                    end
                end)
                if not ok then
                    setError(message)
                end
                task.wait(0.12)
            end
        end)

        local cleaned = false
        local function cleanup()
            if cleaned then
                return
            end
            cleaned = true
            state.Alive = false
            state.AuraKill = false
            state.MobAuraTp = false
            state.SelectedMobFarm = false
            state.AuraFruitBusy = false
            state.FruitDispatchPending = false
            state.GachaBusy = false
            state.InventoryBusy = false
            state.MobAuraTarget = nil
            state.MobAuraAnchorTarget = nil
            state.MobAuraStableAnchor = nil
            state.GatherSingleFallbackEnemy = nil
            state.ActiveFarmTarget = nil
            state.ActiveFarmHeightOverride = nil
            state.RaidMultiGrab = false
            state.RaidVoidKill = false
            state.RaidVoidActive = false
            state.RaidVoidMoved = 0
            state.RaidVoidStaged = 0
            state.SeaEvent.Enabled = false
            state.SeaEvent.StopBoat(state.SeaEvent.Boat)
            state.SeaEvent.RestoreBoatNoclip()
            state.SeaEvent.DestroySafety()
            FarmVertical.SetAntiRagdoll(false)
            FarmVertical.Release()
            for enemy, originalCFrame in pairs(state.GatherOriginalCFrames) do
                local enemyRoot = modelRoot(enemy)
                if enemyRoot and modelAlive(enemy) then
                    pcall(function()
                        enemyRoot.CFrame = originalCFrame
                    end)
                end
            end
            table.clear(state.GatherOriginalCFrames)
            for enemy, originalCFrame in pairs(state.RaidVoidOriginalCFrames) do
                local enemyRoot = modelRoot(enemy)
                local enemyBody = enemy:FindFirstChildOfClass("Humanoid")
                if enemyRoot and enemyBody and enemyBody.Health > 0 then
                    pcall(function()
                        enemyBody.PlatformStand = false
                        enemyRoot.CFrame = originalCFrame
                        enemyRoot.AssemblyLinearVelocity = Vector3.zero
                        enemyRoot.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            end
            table.clear(state.RaidVoidTargets)
            table.clear(state.RaidVoidOriginalCFrames)
            local char = character()
            if char and state.OriginalFruitTapCooldown ~= nil then
                char:SetAttribute("FruitTAPCooldown", state.OriginalFruitTapCooldown)
            end
            cancelMove()
            restoreCollision()
            state.WalkOnWater = false
            updateWaterPlatform()
            if state.WaterPlatform then
                pcall(function()
                    state.WaterPlatform:Destroy()
                end)
                state.WaterPlatform = nil
            end
            PlayerEsp.Clear()
            if state.AutoObservation and CommE then
                pcall(function()
                    CommE:FireServer("Ken", false)
                end)
            end
            if state.FpsBoost then
                setFpsBoost(false)
            end
            clearHighlights(state.EnemyHighlights)
            clearHighlights(state.PlayerHighlights)
        end

        if gui then
            gui:SetAttribute("BloxFruitsModule", true)
            gui:SetAttribute("BloxFruitsNative", true)
            gui:SetAttribute("BloxFruitsUniverseId", 994732206)
            gui:SetAttribute("BloxFruitsRuntimeDependency", "None")
            gui:SetAttribute("RuntimeDependency", "None")
            gui:SetAttribute("BloxFruitsEnemyGatherSource", "NativeVOR")
            gui:SetAttribute("BloxTraveling", false)
            gui:SetAttribute("BloxTravelGoal", Vector3.zero)
            gui:SetAttribute("BloxAuraKill", state.AuraKill)
            gui:SetAttribute("BloxAuraKillRange", state.AuraRange)
            gui:SetAttribute("BloxAuraKillTargets", 0)
            gui:SetAttribute("BloxAuraMultiTargetCount", 0)
            gui:SetAttribute("BloxAuraKillHitCount", state.AuraHits)
            gui:SetAttribute("BloxAuraKillRequestCount", state.AuraRequests)
            gui:SetAttribute("BloxAuraKillStage", state.AuraStage)
            gui:SetAttribute("BloxAuraSwordRequestCount", state.AuraSwordRequests)
            gui:SetAttribute("BloxAuraFruitRequestCount", state.AuraFruitRequests)
            gui:SetAttribute("BloxAuraKillLastTarget", "")
            gui:SetAttribute("BloxAuraKillLastDistance", 0)
            gui:SetAttribute("BloxAuraKillLastRequestAt", 0)
            gui:SetAttribute("BloxAuraKillLastHitAt", 0)
            gui:SetAttribute("BloxAuraWeaponSelection", state.WeaponType)
            gui:SetAttribute("BloxAuraWeaponName", state.AuraWeaponName or "")
            gui:SetAttribute("BloxAuraWeaponType", state.AuraWeaponType or "")
            gui:SetAttribute("BloxAuraAttackMode", state.AuraAttackMode or "")
            gui:SetAttribute("BloxDoubleAttack", state.DoubleAttack)
            gui:SetAttribute("BloxFruitM1CooldownReduction", state.FruitM1CooldownReduction)
            gui:SetAttribute("BloxAuraFruitNativeRange", NATIVE_FRUIT_MAX_RANGE)
            gui:SetAttribute("BloxAuraFruitInRange", false)
            gui:SetAttribute("BloxAuraFruitLastDistance", 0)
            gui:SetAttribute("BloxMobAuraTp", state.MobAuraTp)
            gui:SetAttribute("BloxSelectedMobFarm", state.SelectedMobFarm)
            gui:SetAttribute("BloxSelectedMobName", state.SelectedMobName)
            gui:SetAttribute("BloxSelectedMobSearchRange", state.SelectedMobSearchRange)
            gui:SetAttribute("BloxSelectedMobWaitingAtSpawn", false)
            gui:SetAttribute("BloxMobAuraMode", "Off")
            gui:SetAttribute("BloxMobAuraHeight", state.MobAuraHeight)
            gui:SetAttribute("BloxMobAuraSearchRange", state.MobAuraSearchRange)
            gui:SetAttribute("BloxMobAuraOrbit", state.MobAuraOrbit)
            gui:SetAttribute("BloxMobAuraOrbitRadius", state.MobAuraOrbitRadius)
            gui:SetAttribute("BloxMobAuraOrbitSpeed", state.MobAuraOrbitSpeed)
            gui:SetAttribute("BloxMobAuraOrbitDirection", state.MobAuraOrbitDirection)
            gui:SetAttribute("BloxMobAuraRandomSquare", state.MobAuraRandomSquare)
            gui:SetAttribute("BloxMobAuraSquareSize", state.MobAuraSquareSize)
            gui:SetAttribute("BloxMobAuraSquareInterval", state.MobAuraSquareInterval)
            gui:SetAttribute("BloxMobAuraTarget", "")
            gui:SetAttribute("BloxMobAuraDistance", 0)
            gui:SetAttribute("BloxMultiGrabEnemies", state.GatherEnemies)
            gui:SetAttribute("BloxMultiGrabFilter", state.GatherMode)
            gui:SetAttribute("BloxMultiGrabEnemy", state.GatherSelectedMob)
            gui:SetAttribute("BloxMultiGrabLimit", MULTI_GRAB_LIMIT)
            gui:SetAttribute("BloxMultiGrabRange", MULTI_GRAB_RANGE)
            gui:SetAttribute("BloxMultiGrabCount", 0)
            gui:SetAttribute("BloxMultiGrabSingleFallback", "")
            gui:SetAttribute("BloxSelectedLevelQuest", state.SelectedLevelQuest)
            gui:SetAttribute("BloxCurrentSea", state.CurrentSeaName)
            gui:SetAttribute("BloxCurrentSeaQuestCount", state.CurrentSeaQuestCount)
            gui:SetAttribute("BloxCurrentSeaMinimumLevel", state.CurrentSeaMinimumLevel)
            gui:SetAttribute("BloxCurrentSeaMaximumLevel", state.CurrentSeaMaximumLevel)
            gui:SetAttribute("BloxAutoBoss", state.AutoBoss)
            gui:SetAttribute("BloxAutoLevel", state.AutoFarmLevel)
            gui:SetAttribute("BloxAutoRaid", state.AutoRaid)
            gui:SetAttribute("BloxRaidActive", false)
            gui:SetAttribute("BloxRaidIslandIndex", state.RaidIslandIndex)
            gui:SetAttribute("BloxRaidIslandName", "")
            gui:SetAttribute("BloxRaidTarget", "")
            gui:SetAttribute("BloxRaidMultiGrab", state.RaidMultiGrab)
            gui:SetAttribute("BloxRaidMultiGrabCount", 0)
            gui:SetAttribute("BloxRaidVoidKill", state.RaidVoidKill)
            gui:SetAttribute("BloxRaidVoidActive", false)
            gui:SetAttribute("BloxRaidVoidMoved", 0)
            gui:SetAttribute("BloxRaidVoidStaged", 0)
            gui:SetAttribute("BloxRaidVoidKillCount", 0)
            gui:SetAttribute("BloxRaidSafeHeight", state.RaidSafeHeight)
            gui:SetAttribute("BloxBossVerticalLocked", false)
            gui:SetAttribute("BloxBossAnchorY", 0)
            gui:SetAttribute("BloxAutoBuso", state.AutoBuso)
            gui:SetAttribute("BloxWalkOnWater", state.WalkOnWater)
            gui:SetAttribute("BloxPlayerESP", state.PlayerESP)
            gui:SetAttribute("BloxPlayerESPCount", 0)
            gui:SetAttribute(
                "BloxPlayerESPSkeletonSupported",
                type(Drawing) == "table" and type(Drawing.new) == "function"
            )
            gui:SetAttribute("BloxAutoGacha", state.AutoGacha)
            gui:SetAttribute("BloxGachaRetrySeconds", state.GachaInterval)
            gui:SetAttribute("BloxGachaBusy", false)
            gui:SetAttribute("BloxGachaRollCount", 0)
            gui:SetAttribute("BloxGachaStatus", state.GachaStatus)
            gui:SetAttribute("BloxAutoStoreFruit", state.AutoStoreFruit)
            gui:SetAttribute("BloxFruitStoreBusy", false)
            gui:SetAttribute("BloxFruitStoredCount", 0)
            gui:SetAttribute("BloxFruitStoreStatus", state.StoreStatus)
            gui:SetAttribute("BloxAutoAttack", false)
            gui:SetAttribute("BloxLastAttackAt", 0)
            gui:SetAttribute("BloxAttackCount", state.AuraRequests)
            track(gui.Destroying:Connect(cleanup))
        end

        setStatus("Native Blox Fruits functions ready", true)
        refreshBusoStatus()
        local quest = selectedLevelQuest()
        if quest then
            questLabel.Text = string.format("Quest: %s | Target: %s", quest.DisplayName, quest.EnemyName)
        else
            questLabel.Text = "Quest: Waiting for live quest data"
        end
    end, debug.traceback)
    if not built then
        warn("[VOR Hub] Native Blox Fruits controls failed: " .. tostring(buildError))
        pcall(function()
            gui:SetAttribute("BloxFruitsBuildError", tostring(buildError))
        end)
        pcall(function()
            Window:Notify("VOR Hub", "Native Blox Fruits controls failed: " .. tostring(buildError), 7)
        end)
    end
end

local function buildUnsupportedGameShell()
    local HomePage = Window:AddPage("Home")
    local supportSection = HomePage:AddSection("Game Support", "Left")
    supportSection:AddLabel("This game is not supported yet.")
    supportSection:AddLabel("VOR Hub loaded without any game-specific scripts.")
    supportSection:AddLabel(
        "PlaceId: " .. tostring(game.PlaceId) .. " | UniverseId: " .. tostring(game.GameId)
    )
end

if ACTIVE_GAME_SUPPORT and ACTIVE_GAME_SUPPORT.Key == "Revive" then
    statusGui.Enabled = true
    gui:SetAttribute("GameSupported", true)
    gui:SetAttribute("GameSupportKey", ACTIVE_GAME_SUPPORT.Key)
    gui:SetAttribute("SupportedUniverseId", ACTIVE_GAME_SUPPORT.UniverseId)
    buildReviveFeatures()
elseif ACTIVE_GAME_SUPPORT and ACTIVE_GAME_SUPPORT.Key == "Basketball" then
    statusGui.Enabled = false
    gui:SetAttribute("GameSupported", true)
    gui:SetAttribute("GameSupportKey", ACTIVE_GAME_SUPPORT.Key)
    gui:SetAttribute("SupportedUniverseId", ACTIVE_GAME_SUPPORT.UniverseId)
    buildBasketballFeatures()
elseif ACTIVE_GAME_SUPPORT and ACTIVE_GAME_SUPPORT.Key == "AnimeExpeditions" then
    statusGui.Enabled = false
    gui:SetAttribute("GameSupported", true)
    gui:SetAttribute("GameSupportKey", ACTIVE_GAME_SUPPORT.Key)
    gui:SetAttribute("SupportedUniverseId", ACTIVE_GAME_SUPPORT.UniverseId)
    buildAnimeExpeditionsFeatures()
elseif ACTIVE_GAME_SUPPORT and ACTIVE_GAME_SUPPORT.Key == "BloxFruits" then
    statusGui.Enabled = false
    gui:SetAttribute("GameSupported", true)
    gui:SetAttribute("GameSupportKey", ACTIVE_GAME_SUPPORT.Key)
    gui:SetAttribute("SupportedUniverseId", ACTIVE_GAME_SUPPORT.UniverseId)
    if IS_BLOX_FRUITS_DUNGEON then
        buildBloxFruitsDungeonFeatures()
    else
        Window:BuildBloxFruitsFeatures()
    end
else
    statusGui.Enabled = false
    gui:SetAttribute("GameSupported", false)
    gui:SetAttribute("GameSupportKey", "Unsupported")
    gui:SetAttribute("SupportedUniverseId", 0)
    buildUnsupportedGameShell()
end

-- Generic Settings page. Keep this below your feature controls so Auto Load can restore them.
local SettingsPage = Window:AddPage("Settings")
local ProfilesSection = SettingsPage:AddSection("Saved Profiles", "Left")
local AutoLoadSection = SettingsPage:AddSection("Auto Load", "Right")
local AppearanceSection = SettingsPage:AddSection("VOR Appearance", "Right")
local CommunitySection = SettingsPage:AddSection("Access & Community", "Left")

if SETTINGS.IsBloxFruits then
    (function()
    local CosmeticsSection = SettingsPage:AddSection("Blox Fruits Cosmetics", "Right")
    local voidKitsuneState = {
        Enabled = false,
        Originals = setmetatable({}, {__mode = "k"}),
        GalaxyMarkers = setmetatable({}, {__mode = "k"}),
        GalaxyRigs = setmetatable({}, {__mode = "k"}),
        Accumulator = 0,
    }
    local identityMaskState = {
        Mode = "Original",
        Humanoids = setmetatable({}, {__mode = "k"}),
        Labels = setmetatable({}, {__mode = "k"}),
        Accumulator = 0,
    }
    local kitsuneFloatState = {
        Enabled = false,
        Motors = setmetatable({}, {__mode = "k"}),
        StartedAt = 0,
    }
    local voidDarkBladeState = {
        Enabled = false,
        WeaponModels = setmetatable({}, {__mode = "k"}),
        Originals = setmetatable({}, {__mode = "k"}),
        Accumulator = 0,
    }
    local VOID_KITSUNE_COLORS = {
        Color3.fromRGB(151, 70, 255),
        Color3.fromRGB(31, 7, 54),
        Color3.fromRGB(205, 77, 255),
    }

    local function collectKitsuneTools()
        local tools = {}
        local seen = setmetatable({}, {__mode = "k"})
        local function scanTools(container)
            if not container then
                return
            end
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool")
                    and string.find(string.lower(child.Name), "kitsune", 1, true)
                    and not seen[child] then
                    seen[child] = true
                    table.insert(tools, child)
                end
            end
        end
        scanTools(LocalPlayer:FindFirstChildOfClass("Backpack"))
        scanTools(LocalPlayer.Character)
        return tools
    end

    local function collectKitsuneShiftedFolders(kitsuneTools)
        local found = {}
        local seen = setmetatable({}, {__mode = "k"})
        local function addColorFolder(colorFolder)
            local shifted = colorFolder and colorFolder:FindFirstChild("Shifted")
            if shifted and shifted:IsA("Folder") and not seen[shifted] then
                seen[shifted] = true
                table.insert(found, shifted)
            end
        end

        addColorFolder(LocalPlayer:FindFirstChild("KitsuneFruitVFXColor"))
        for _, tool in ipairs(kitsuneTools) do
            addColorFolder(tool:FindFirstChild("VFXColor"))
        end
        return found
    end

    local function enableGalaxyTool(tool)
        local marker = tool:FindFirstChild("IsGalaxy")
        if marker and not marker:IsA("BoolValue") then
            return
        end
        if not marker then
            marker = Instance.new("BoolValue")
            marker.Name = "IsGalaxy"
            marker.Value = true
            marker.Parent = tool
            voidKitsuneState.GalaxyMarkers[marker] = {Created = true}
        elseif not voidKitsuneState.GalaxyMarkers[marker] then
            voidKitsuneState.GalaxyMarkers[marker] = {Created = false, Value = marker.Value}
            marker.Value = true
        elseif marker.Value ~= true then
            marker.Value = true
        end
    end

    local function applyGalaxyTransformation(tool)
        local transformedObject = tool:FindFirstChild("TransformedRigObject")
        local rig = transformedObject and transformedObject:IsA("ObjectValue") and transformedObject.Value or nil
        if not rig or not rig.Parent or voidKitsuneState.GalaxyRigs[rig] then
            return
        end

        local visualNames = {"Body", "Accessory", "Mouth", "Eyes", "Neon"}
        local record = {
            Parts = {},
            Glow = nil,
            GalaxyApplied = false,
        }
        for _, part in ipairs(rig:GetDescendants()) do
            if part:IsA("BasePart") and part.Transparency < 0.95 then
                local appearances = {}
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("SurfaceAppearance") then
                        table.insert(appearances, child:Clone())
                    end
                end
                record.Parts[part] = {
                    Color = part.Color,
                    Material = part.Material,
                    Appearances = appearances,
                }
            end
        end

        local compatible = false
        for _, name in ipairs(visualNames) do
            local part = rig:FindFirstChild(name)
            if part and part:IsA("BasePart") then
                compatible = true
            end
        end

        if compatible then
            record.GalaxyApplied = pcall(function()
                local SkinUtil = require(ReplicatedStorage.Modules.SkinUtil)
                SkinUtil.applySkin("Galaxy", {
                    [rig] = "Transformations.Empyrean (Kitsune)-Empyrean (Kitsune)",
                })
            end)
        end

        for part in pairs(record.Parts) do
            if part and part.Parent then
                local isArmor = string.find(string.lower(part.Name), "armor", 1, true) ~= nil
                local color = isArmor and VOID_KITSUNE_COLORS[3] or VOID_KITSUNE_COLORS[1]
                part.Material = Enum.Material.Neon
                part.Color = color
                for _, child in ipairs(part:GetChildren()) do
                    if child:IsA("SurfaceAppearance") then
                        pcall(function()
                            child.Color = color
                        end)
                        pcall(function()
                            child.EmissiveStrength = isArmor and 2.5 or 1.8
                        end)
                    end
                end
            end
        end

        local glow = Instance.new("Folder")
        glow.Name = "VORVoidGalaxyGlow"
        glow.Parent = rig
        record.Glow = glow

        local highlight = Instance.new("Highlight")
        highlight.Name = "VORVoidOutline"
        highlight.Adornee = rig
        highlight.FillColor = VOID_KITSUNE_COLORS[1]
        highlight.FillTransparency = 0.72
        highlight.OutlineColor = VOID_KITSUNE_COLORS[3]
        highlight.OutlineTransparency = 0.05
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.Parent = glow

        local root = rig:FindFirstChild("RootPart", true) or rig:FindFirstChildWhichIsA("BasePart", true)
        if root and root:IsA("BasePart") then
            local anchor = Instance.new("Part")
            anchor.Name = "VORVoidEmitterAnchor"
            anchor.Size = Vector3.new(0.2, 0.2, 0.2)
            anchor.Transparency = 1
            anchor.Anchored = false
            anchor.CanCollide = false
            anchor.CanTouch = false
            anchor.CanQuery = false
            anchor.Massless = true
            anchor.CFrame = root.CFrame
            anchor.Parent = glow
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = root
            weld.Part1 = anchor
            weld.Parent = anchor

            local attachment = Instance.new("Attachment")
            attachment.Name = "VORVoidEmitter"
            attachment.Parent = anchor
            local source = ReplicatedStorage:FindFirstChild("FX")
            source = source and source:FindFirstChild("Kitsune")
            source = source and source:FindFirstChild("KitsuneTailSpawn")
            source = source and source:FindFirstChildWhichIsA("ParticleEmitter", true)
            if source then
                local emitter = source:Clone()
                emitter.Name = "VORVoidEmbers"
                emitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, VOID_KITSUNE_COLORS[1]),
                    ColorSequenceKeypoint.new(0.55, VOID_KITSUNE_COLORS[3]),
                    ColorSequenceKeypoint.new(1, VOID_KITSUNE_COLORS[2]),
                })
                emitter.LightEmission = 1
                emitter.Rate = math.max(18, emitter.Rate)
                emitter.Enabled = true
                emitter.Parent = attachment
            end

            local light = Instance.new("PointLight")
            light.Name = "VORVoidLight"
            light.Color = VOID_KITSUNE_COLORS[1]
            light.Brightness = 2.4
            light.Range = 20
            light.Shadows = false
            light.Parent = anchor
        end

        voidKitsuneState.GalaxyRigs[rig] = record
        gui:SetAttribute(
            "BloxVoidKitsuneGalaxyRigStatus",
            record.GalaxyApplied and "Galaxy model + void glow active" or "Void glow active on standard Kitsune rig"
        )
    end

    local function applyVoidKitsuneColors()
        local kitsuneTools = collectKitsuneTools()
        for _, shifted in ipairs(collectKitsuneShiftedFolders(kitsuneTools)) do
            if not voidKitsuneState.Originals[shifted] then
                voidKitsuneState.Originals[shifted] = {
                    shifted:GetAttribute("Shifted_Color1"),
                    shifted:GetAttribute("Shifted_Color2"),
                    shifted:GetAttribute("Shifted_Color3"),
                }
            end
            for index, color in ipairs(VOID_KITSUNE_COLORS) do
                local attribute = "Shifted_Color" .. tostring(index)
                if shifted:GetAttribute(attribute) ~= color then
                    shifted:SetAttribute(attribute, color)
                end
            end
        end
        for _, tool in ipairs(kitsuneTools) do
            enableGalaxyTool(tool)
            applyGalaxyTransformation(tool)
        end
        gui:SetAttribute("BloxVoidKitsuneTheme", true)
    end

    local function restoreKitsuneColors()
        for shifted, originals in pairs(voidKitsuneState.Originals) do
            if shifted and shifted.Parent then
                for index = 1, 3 do
                    shifted:SetAttribute("Shifted_Color" .. tostring(index), originals[index])
                end
            end
        end
        voidKitsuneState.Originals = setmetatable({}, {__mode = "k"})
        for marker, original in pairs(voidKitsuneState.GalaxyMarkers) do
            if marker and marker.Parent then
                if original.Created then
                    marker:Destroy()
                else
                    marker.Value = original.Value == true
                end
            end
        end
        voidKitsuneState.GalaxyMarkers = setmetatable({}, {__mode = "k"})
        for rig, record in pairs(voidKitsuneState.GalaxyRigs) do
            if rig and rig.Parent then
                if record.Glow and record.Glow.Parent then
                    record.Glow:Destroy()
                end
                for part, data in pairs(record.Parts) do
                    if part and part.Parent then
                        part.Color = data.Color
                        part.Material = data.Material
                        for _, child in ipairs(part:GetChildren()) do
                            if child:IsA("SurfaceAppearance") then
                                child:Destroy()
                            end
                        end
                        for _, appearance in ipairs(data.Appearances) do
                            appearance.Parent = part
                        end
                    end
                end
            end
        end
        voidKitsuneState.GalaxyRigs = setmetatable({}, {__mode = "k"})
        gui:SetAttribute("BloxVoidKitsuneTheme", false)
        gui:SetAttribute("BloxVoidKitsuneGalaxyRigStatus", "Off")
    end

    local function restoreIdentityMask()
        for humanoid, original in pairs(identityMaskState.Humanoids) do
            if humanoid and humanoid.Parent then
                humanoid.DisplayName = original.DisplayName
                humanoid.NameDisplayDistance = original.NameDisplayDistance
            end
        end
        for label, originalText in pairs(identityMaskState.Labels) do
            if label and label.Parent then
                label.Text = originalText
            end
        end
        identityMaskState.Humanoids = setmetatable({}, {__mode = "k"})
        identityMaskState.Labels = setmetatable({}, {__mode = "k"})
        gui:SetAttribute("BloxIdentityMask", "Original")
    end

    local function restoreKitsuneFloat()
        for motor, originalTransform in pairs(kitsuneFloatState.Motors) do
            if motor and motor.Parent then
                motor.Transform = originalTransform
            end
        end
        kitsuneFloatState.Motors = setmetatable({}, {__mode = "k"})
        gui:SetAttribute("BloxVoidKitsuneFloat", false)
        gui:SetAttribute("BloxVoidKitsuneFloatStatus", "Off")
    end

    local function animateKitsuneFloat()
        if not kitsuneFloatState.Enabled then
            return
        end
        local foundMotor = false
        for _, tool in ipairs(collectKitsuneTools()) do
            local transformedObject = tool:FindFirstChild("TransformedRigObject")
            local rig = transformedObject and transformedObject:IsA("ObjectValue") and transformedObject.Value or nil
            if rig and rig.Parent then
                for _, descendant in ipairs(rig:GetDescendants()) do
                    if descendant:IsA("Motor6D")
                        and (descendant.Name == "KitsuneMotor6D" or descendant.Name == "ArmorMotor6D") then
                        foundMotor = true
                        if kitsuneFloatState.Motors[descendant] == nil then
                            kitsuneFloatState.Motors[descendant] = descendant.Transform
                        end
                    end
                end
            end
        end

        local elapsed = os.clock() - kitsuneFloatState.StartedAt
        local height = 0.85 + math.sin(elapsed * 2.15) * 0.24
        local pitch = math.rad(math.sin(elapsed * 1.45) * 1.8)
        local roll = math.rad(math.sin(elapsed * 1.8) * 2.5)
        local offset = CFrame.new(0, height, 0) * CFrame.Angles(pitch, 0, roll)
        for motor, originalTransform in pairs(kitsuneFloatState.Motors) do
            if motor and motor.Parent then
                motor.Transform = originalTransform * offset
            end
        end
        gui:SetAttribute("BloxVoidKitsuneFloat", true)
        gui:SetAttribute(
            "BloxVoidKitsuneFloatStatus",
            foundMotor and "Floating transformed rig" or "Waiting for Kitsune transformation"
        )
    end

    local function setVoidVisualProperty(object, property, value)
        local original = voidDarkBladeState.Originals[object]
        if not original then
            original = {}
            voidDarkBladeState.Originals[object] = original
        end
        if original[property] == nil then
            local readable, current = pcall(function()
                return object[property]
            end)
            if not readable then
                return
            end
            original[property] = current
        end
        pcall(function()
            object[property] = value
        end)
    end

    local function recolorVoidVisual(object)
        local sequence = ColorSequence.new({
            ColorSequenceKeypoint.new(0, VOID_KITSUNE_COLORS[1]),
            ColorSequenceKeypoint.new(0.55, VOID_KITSUNE_COLORS[3]),
            ColorSequenceKeypoint.new(1, VOID_KITSUNE_COLORS[2]),
        })
        if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
            setVoidVisualProperty(object, "Color", sequence)
            if object:IsA("ParticleEmitter") then
                setVoidVisualProperty(object, "LightEmission", math.max(0.75, object.LightEmission))
            end
        elseif object:IsA("BasePart") then
            local lowerName = string.lower(object.Name)
            local dark = string.find(lowerName, "black", 1, true)
                or string.find(lowerName, "shadow", 1, true)
            setVoidVisualProperty(object, "Color", dark and VOID_KITSUNE_COLORS[2] or VOID_KITSUNE_COLORS[1])
        elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
            setVoidVisualProperty(object, "Color", VOID_KITSUNE_COLORS[1])
        elseif object:IsA("Decal") or object:IsA("Texture") then
            setVoidVisualProperty(object, "Color3", VOID_KITSUNE_COLORS[3])
        elseif object:IsA("SurfaceAppearance") then
            setVoidVisualProperty(object, "Color", VOID_KITSUNE_COLORS[1])
            setVoidVisualProperty(object, "EmissiveStrength", 2)
        elseif object:IsA("Highlight") then
            setVoidVisualProperty(object, "FillColor", VOID_KITSUNE_COLORS[1])
            setVoidVisualProperty(object, "OutlineColor", VOID_KITSUNE_COLORS[3])
        elseif object:IsA("Color3Value") then
            setVoidVisualProperty(object, "Value", VOID_KITSUNE_COLORS[1])
        elseif object:IsA("ColorCorrectionEffect") then
            setVoidVisualProperty(object, "TintColor", VOID_KITSUNE_COLORS[1])
        elseif object:IsA("UIGradient") then
            setVoidVisualProperty(object, "Color", sequence)
        elseif object:IsA("ImageLabel") or object:IsA("ImageButton") then
            setVoidVisualProperty(object, "ImageColor3", VOID_KITSUNE_COLORS[1])
        elseif object:IsA("Smoke") then
            setVoidVisualProperty(object, "Color", VOID_KITSUNE_COLORS[2])
        elseif object:IsA("Fire") then
            setVoidVisualProperty(object, "Color", VOID_KITSUNE_COLORS[1])
            setVoidVisualProperty(object, "SecondaryColor", VOID_KITSUNE_COLORS[3])
        elseif object:IsA("Sparkles") then
            setVoidVisualProperty(object, "SparkleColor", VOID_KITSUNE_COLORS[3])
        end
    end

    local function recolorMidnightBladeEffects()
        local fx = ReplicatedStorage:FindFirstChild("FX")
        for _, root in ipairs({
            fx and fx:FindFirstChild("MidnightBlade"),
            fx and fx:FindFirstChild("PortalEffects"),
        }) do
            if root then
                recolorVoidVisual(root)
                for _, descendant in ipairs(root:GetDescendants()) do
                    recolorVoidVisual(descendant)
                end
            end
        end
    end

    local function midnightBladeVisualModels()
        local found = {}
        local character = LocalPlayer.Character
        if not character then
            return found
        end
        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Model")
                and string.lower(tostring(child:GetAttribute("WeaponName") or "")) == "midnightblade" then
                table.insert(found, child)
            end
        end
        return found
    end

    local function applyVoidDarkBladeModel(weaponModel)
        if voidDarkBladeState.WeaponModels[weaponModel] then
            return
        end
        local right = weaponModel:FindFirstChild("Right")
        local handle = right and right:FindFirstChild("Handle")
        local cutscene = ReplicatedStorage:FindFirstChild("Effect")
        cutscene = cutscene and cutscene:FindFirstChild("Container")
        cutscene = cutscene and cutscene:FindFirstChild("IndraCutscene")
        cutscene = cutscene and cutscene:FindFirstChild("IndraIsland")
        cutscene = cutscene and cutscene:FindFirstChild("anim")
        cutscene = cutscene and cutscene:FindFirstChild("mygame43")
        local darkBlade = cutscene and cutscene:FindFirstChild("DarkBlade")
        local template = darkBlade and darkBlade:FindFirstChild("Right")
        if not right or not handle or not template then
            return
        end

        local oldTest = right:FindFirstChild("VORVoidDarkBlade")
        if oldTest then
            oldTest:Destroy()
        end
        local record = {
            Transparencies = setmetatable({}, {__mode = "k"}),
            Clone = nil,
        }
        for _, child in ipairs(right:GetChildren()) do
            if child:IsA("MeshPart") then
                record.Transparencies[child] = child.Transparency
                child.Transparency = 1
            end
        end

        local clone = template:Clone()
        clone.Name = "VORVoidDarkBladeV3"
        clone:SetAttribute("VORCosmetic", true)
        clone.Parent = right
        record.Clone = clone
        local hold = clone:FindFirstChild("Hold")
        for _, descendant in ipairs(clone:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Anchored = false
                descendant.CanCollide = false
                descendant.CanTouch = false
                descendant.CanQuery = false
                descendant.Massless = true
                descendant.CastShadow = false
                local lowerName = string.lower(descendant.Name)
                if lowerName == "runes" or lowerName == "gems" then
                    descendant.Color = VOID_KITSUNE_COLORS[3]
                    descendant.Material = Enum.Material.Neon
                elseif lowerName == "tape" or lowerName == "hold" then
                    descendant.Color = VOID_KITSUNE_COLORS[2]
                    descendant.Material = Enum.Material.SmoothPlastic
                else
                    descendant.Color = VOID_KITSUNE_COLORS[1]
                    descendant.Material = Enum.Material.Neon
                end
            end
        end
        if hold and hold:IsA("BasePart") then
            hold.CFrame = handle.CFrame * CFrame.Angles(math.rad(90), 0, 0)
            local weld = Instance.new("WeldConstraint")
            weld.Name = "VORGripWeld"
            weld.Part0 = handle
            weld.Part1 = hold
            weld.Parent = hold
            local light = Instance.new("PointLight")
            light.Name = "VORDarkBladeLight"
            light.Color = VOID_KITSUNE_COLORS[1]
            light.Brightness = 2.2
            light.Range = 14
            light.Shadows = false
            light.Parent = hold
        end
        local highlight = Instance.new("Highlight")
        highlight.Name = "VORDarkBladeOutline"
        highlight.Adornee = clone
        highlight.FillColor = VOID_KITSUNE_COLORS[1]
        highlight.FillTransparency = 0.75
        highlight.OutlineColor = VOID_KITSUNE_COLORS[3]
        highlight.OutlineTransparency = 0.05
        highlight.DepthMode = Enum.HighlightDepthMode.Occluded
        highlight.Parent = clone

        local auraModel = right:FindFirstChild("AuraModel")
        if auraModel then
            for _, descendant in ipairs(auraModel:GetDescendants()) do
                recolorVoidVisual(descendant)
            end
        end
        voidDarkBladeState.WeaponModels[weaponModel] = record
        gui:SetAttribute("BloxVoidDarkBladeStatus", "Dark Blade V3 model + Midnight abilities active")
    end

    local function applyVoidDarkBlade()
        if not voidDarkBladeState.Enabled then
            return
        end
        for _, weaponModel in ipairs(midnightBladeVisualModels()) do
            applyVoidDarkBladeModel(weaponModel)
        end
        gui:SetAttribute("BloxVoidDarkBlade", true)
    end

    local function restoreVoidDarkBlade()
        for weaponModel, record in pairs(voidDarkBladeState.WeaponModels) do
            if record.Clone and record.Clone.Parent then
                record.Clone:Destroy()
            end
            if weaponModel and weaponModel.Parent then
                for part, transparency in pairs(record.Transparencies) do
                    if part and part.Parent then
                        part.Transparency = transparency
                    end
                end
            end
        end
        voidDarkBladeState.WeaponModels = setmetatable({}, {__mode = "k"})
        for object, original in pairs(voidDarkBladeState.Originals) do
            if object and object.Parent then
                for property, value in pairs(original) do
                    pcall(function()
                        object[property] = value
                    end)
                end
            end
        end
        voidDarkBladeState.Originals = setmetatable({}, {__mode = "k"})
        gui:SetAttribute("BloxVoidDarkBlade", false)
        gui:SetAttribute("BloxVoidDarkBladeStatus", "Off")
    end

    local function applyIdentityMask()
        if identityMaskState.Mode == "Original" then
            return
        end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if not identityMaskState.Humanoids[humanoid] then
                identityMaskState.Humanoids[humanoid] = {
                    DisplayName = humanoid.DisplayName,
                    NameDisplayDistance = humanoid.NameDisplayDistance,
                }
            end
            local original = identityMaskState.Humanoids[humanoid]
            if identityMaskState.Mode == "Hide Name" then
                humanoid.NameDisplayDistance = 0
            else
                humanoid.DisplayName = "VOR Hub"
                humanoid.NameDisplayDistance = original.NameDisplayDistance
            end
        end

        if character then
            local username = string.lower(LocalPlayer.Name)
            local displayName = string.lower(LocalPlayer.DisplayName)
            for _, descendant in ipairs(character:GetDescendants()) do
                if descendant:IsA("TextLabel") then
                    local currentText = string.lower(tostring(descendant.Text))
                    if identityMaskState.Labels[descendant]
                        or currentText == username
                        or currentText == displayName then
                        if not identityMaskState.Labels[descendant] then
                            identityMaskState.Labels[descendant] = descendant.Text
                        end
                        descendant.Text = identityMaskState.Mode == "Hide Name" and "" or "VOR Hub"
                    end
                end
            end
        end
        gui:SetAttribute("BloxIdentityMask", identityMaskState.Mode)
    end

    CosmeticsSection:AddLabel("Uses Kitsune's native three-channel VFX system plus its Galaxy mutation hooks, so the model, tails, and local abilities stay synchronized.")
    CosmeticsSection:AddToggle({
        Name = "Void Kitsune Theme",
        Description = "Galaxy mutation model with VOR violet, abyss purple, and void magenta VFX",
        Flag = "blox_void_kitsune_theme",
        Default = false,
        Callback = function(enabled)
            voidKitsuneState.Enabled = enabled == true
            if voidKitsuneState.Enabled then
                applyVoidKitsuneColors()
                Window:Notify("Void Kitsune", "Your fox has joined the evil purple department.", 3)
            else
                restoreKitsuneColors()
            end
        end,
    })
    CosmeticsSection:AddToggle({
        Name = "VOR Hub Name Mask",
        Description = "Replace your overhead display name with VOR Hub on this client",
        Flag = "blox_vor_name_mask",
        Default = false,
        Callback = function(enabled)
            restoreIdentityMask()
            identityMaskState.Mode = enabled and "VOR Hub" or "Original"
            applyIdentityMask()
        end,
    })
    CosmeticsSection:AddToggle({
        Name = "Void Kitsune Float",
        Description = "Smooth visual hover for the transformed fox without moving your real root",
        Flag = "blox_void_kitsune_float",
        Default = false,
        Callback = function(enabled)
            restoreKitsuneFloat()
            kitsuneFloatState.Enabled = enabled == true
            kitsuneFloatState.StartedAt = os.clock()
            if kitsuneFloatState.Enabled then
                animateKitsuneFloat()
            end
        end,
    })
    CosmeticsSection:AddToggle({
        Name = "Void Dark Blade V3",
        Description = "Replace Midnight Blade's local model and recolor its abilities to the VOR theme",
        Flag = "blox_void_dark_blade_v3",
        Default = false,
        Callback = function(enabled)
            restoreVoidDarkBlade()
            voidDarkBladeState.Enabled = enabled == true
            if voidDarkBladeState.Enabled then
                recolorMidnightBladeEffects()
                applyVoidDarkBlade()
            end
        end,
    })

    track(RunService.RenderStepped:Connect(function()
        animateKitsuneFloat()
    end))

    track(RunService.Heartbeat:Connect(function(deltaTime)
        if voidKitsuneState.Enabled then
            voidKitsuneState.Accumulator = voidKitsuneState.Accumulator + deltaTime
            if voidKitsuneState.Accumulator >= 0.35 then
                voidKitsuneState.Accumulator = 0
                applyVoidKitsuneColors()
            end
        end
        if identityMaskState.Mode ~= "Original" then
            identityMaskState.Accumulator = identityMaskState.Accumulator + deltaTime
            if identityMaskState.Accumulator >= 0.35 then
                identityMaskState.Accumulator = 0
                applyIdentityMask()
            end
        end
        if voidDarkBladeState.Enabled then
            voidDarkBladeState.Accumulator = voidDarkBladeState.Accumulator + deltaTime
            if voidDarkBladeState.Accumulator >= 0.35 then
                voidDarkBladeState.Accumulator = 0
                applyVoidDarkBlade()
            end
        end
    end))
    end)()
end

CommunitySection:AddLabel("Discord provides the current key, supported-game list, updates, feedback, and suggestions.")
CommunitySection:AddButton({
    Name = "Copy VOR Hub Discord",
    Description = SETTINGS.DiscordInviteURL,
    Persist = false,
    Callback = function()
        if copyText(SETTINGS.DiscordInviteURL) then
            Window:Notify("Discord", "Invite copied to your clipboard.", 3)
        else
            Window:Notify("Discord", "Clipboard access is unavailable. Open " .. SETTINGS.Discord, 4)
        end
    end,
})
CommunitySection:AddButton({
    Name = "Forget Remembered Key",
    Description = "Requires the Discord key again the next time the hub launches",
    Persist = false,
    Callback = function()
        Window:ForgetKeyAccess()
        Window:Notify("Access", "Remembered access was cleared for the next launch.", 3)
    end,
})

local frozenPresets = {
    ["VOR Violet"] = Color3.fromRGB(151, 70, 255),
    ["Royal Purple"] = Color3.fromRGB(129, 46, 226),
    ["Neon Amethyst"] = Color3.fromRGB(199, 91, 255),
    ["Abyss Purple"] = Color3.fromRGB(91, 35, 167),
    ["Void Magenta"] = Color3.fromRGB(174, 46, 211),
    ["Silver Violet"] = Color3.fromRGB(188, 164, 226),
    ["Blacklight"] = Color3.fromRGB(104, 52, 255),
    ["Imperial Plum"] = Color3.fromRGB(119, 44, 143),
}

local panelBackgroundControl = AppearanceSection:AddDropdown({
    Name = "UI Background",
    Flag = "vor_panel_background",
    Options = {"VOR Void (287316330)", "VOR Purple (13223834035)"},
    Default = "VOR Void (287316330)",
    Callback = function(value)
        local image = PANEL_BACKGROUNDS[value]
        if image then
            SETTINGS.PanelBackgroundImageId = image
            if panelBackground and panelBackground.Parent then
                panelBackground.Image = image
            end
        end
    end,
})

local frozenAccentControl = AppearanceSection:AddDropdown({
    Name = "VOR Accent Color",
    Flag = "frozen_accent_preset",
    Options = {"VOR Violet", "Royal Purple", "Neon Amethyst", "Abyss Purple", "Void Magenta", "Silver Violet", "Blacklight", "Imperial Plum"},
    Default = "VOR Violet",
    Callback = function(value)
        local color = frozenPresets[value]
        if color then
            applyFrozenAccent(color)
        end
    end,
})

local transparencyControl = AppearanceSection:AddSlider({
    Name = "Hub Transparency",
    Flag = "hub_transparency",
    Min = 0.10,
    Max = 0.80,
    Default = hubTransparencyValue,
    Step = 0.05,
    Callback = function(value)
        applyHubTransparency(value)
    end,
})

AppearanceSection:AddSlider({
    Name = "UI Animation Rate",
    Description = "Caps VOR's manual animations at 30-240 FPS; Roblox still limits the final result to the game's render rate",
    Flag = "vor_ui_animation_rate",
    Min = 30,
    Max = 240,
    Default = 240,
    Step = 30,
    Callback = function(value)
        SETTINGS.UIAnimationRate = math.clamp(tonumber(value) or 240, 30, 240)
    end,
})

local minimizedStyleControl = AppearanceSection:AddDropdown({
    Name = "Minimized Style",
    Flag = "hub_minimized_style",
    Options = {MINIMIZE_BAR_STYLE, MINIMIZE_CIRCLE_STYLE},
    Default = minimizedStyle,
    Callback = function(value)
        Window:SetMinimizeStyle(value)
    end,
})

AppearanceSection:AddButton({
    Name = "Reset VOR Theme",
    Description = "Restore the obsidian glass and signature VOR violet accent",
    Persist = false,
    Callback = function()
        panelBackgroundControl:Set("VOR Void (287316330)")
        frozenAccentControl:Set("VOR Violet")
        transparencyControl:Set(0.24)
    end,
})

local profileNameControl = ProfilesSection:AddInput({
    Name = "Profile Name",
    Placeholder = "Example: Main Setup",
    Persist = false,
})

local savedProfileControl = nil
savedProfileControl = ProfilesSection:AddDropdown({
    Name = "Saved Profiles",
    Placeholder = "Select a profile...",
    Options = {},
    Persist = false,
    Callback = function(value)
        if value then
            profileNameControl:Set(value)
        end
    end,
})

local settingsStatus = AutoLoadSection:AddLabel("Checking profile storage...")
local function setSettingsStatus(message, success)
    settingsStatus.Text = tostring(message)
    settingsStatus.TextColor3 = success == false and COLORS.error or (success == true and COLORS.success or COLORS.muted)
end

local function getChosenProfile()
    local typed = sanitizeProfileName(profileNameControl:Get())
    if typed ~= "" then
        return typed
    end
    return sanitizeProfileName(savedProfileControl:Get())
end

local function refreshProfiles(preferred)
    local profiles = Window:GetProfileNames()
    savedProfileControl:SetOptions(profiles, false)

    local target = sanitizeProfileName(preferred or getChosenProfile())
    if target ~= "" then
        for _, profile in ipairs(profiles) do
            if profile == target then
                savedProfileControl:Set(profile, true)
                profileNameControl:Set(profile)
                break
            end
        end
    end
    return profiles
end

ProfilesSection:AddButton({
    Name = "Save / Overwrite",
    Description = "Save every persistent control in this game",
    Callback = function()
        local ok, message, profile = Window:SaveProfile(getChosenProfile())
        setSettingsStatus(message, ok)
        if ok then
            profileNameControl:Set(profile)
            refreshProfiles(profile)
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

ProfilesSection:AddButton({
    Name = "Load Profile",
    Description = "Apply the selected values and their callbacks",
    Callback = function()
        local ok, message, profile = Window:LoadProfile(getChosenProfile())
        setSettingsStatus(message, ok)
        if ok then
            profileNameControl:Set(profile)
            savedProfileControl:Set(profile, true)
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

local pendingDeleteProfile = nil
local pendingDeleteUntil = 0
ProfilesSection:AddButton({
    Name = "Delete Profile",
    Description = "Requires a second click for confirmation",
    Callback = function()
        local profile = getChosenProfile()
        if profile == "" then
            setSettingsStatus("Choose a profile to delete", false)
            return
        end

        if pendingDeleteProfile ~= profile or os.clock() > pendingDeleteUntil then
            pendingDeleteProfile = profile
            pendingDeleteUntil = os.clock() + 4
            setSettingsStatus("Click Delete Profile again to confirm: " .. profile, false)
            return
        end

        local ok, message = Window:DeleteProfile(profile)
        pendingDeleteProfile = nil
        pendingDeleteUntil = 0
        setSettingsStatus(message, ok)
        if ok then
            profileNameControl:Set("")
            refreshProfiles()
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

ProfilesSection:AddButton({
    Name = "Refresh Profile List",
    Callback = function()
        local profiles = refreshProfiles()
        setSettingsStatus("Found " .. tostring(#profiles) .. " saved profile(s)", true)
    end,
})

AutoLoadSection:AddLabel(
    SETTINGS.IsBloxFruits
        and ("Storage is shared across Blox Fruits seas (UniverseId " .. tostring(SETTINGS.ConfigScopeId) .. ")")
        or ("Storage is isolated to PlaceId " .. tostring(SETTINGS.ConfigScopeId))
)
AutoLoadSection:AddLabel("Only toggles, dropdowns, sliders, and inputs are saved.")

local autoLoadControl = nil
autoLoadControl = AutoLoadSection:AddToggle({
    Name = "Auto Load Selected Profile",
    Description = "Loads this profile when the hub starts in this game",
    Default = false,
    Persist = false,
    Callback = function(enabled)
        local ok, message = Window:SetAutoLoad(enabled, getChosenProfile())
        if not ok then
            autoLoadControl:Set(false, true)
        end
        setSettingsStatus(message, ok)
        if ok then
            Window:Notify("Settings", message, 2.5)
        end
    end,
})

local pendingAutoLoadProfile = nil
if Window:ProfilesAvailable() then
    refreshProfiles()
    local autoLoadEnabled, autoLoadProfile = Window:GetAutoLoad()
    if autoLoadEnabled and autoLoadProfile ~= "" then
        profileNameControl:Set(autoLoadProfile)
        savedProfileControl:Set(autoLoadProfile, true)
        autoLoadControl:Set(true, true)
        pendingAutoLoadProfile = autoLoadProfile
        setSettingsStatus("Loading profile: " .. autoLoadProfile, nil)
    else
        setSettingsStatus("Enter a profile name to Save / Overwrite or Load", nil)
    end
else
    setSettingsStatus("Profile saving is unavailable: executor file API not found", false)
end

Window:SelectPage(IS_BLOX_FRUITS_DUNGEON and "Dungeons" or "Home")
-- Optional global reference for adding controls later from the same environment.
_G.VORHub = Window
Window:RequestKeyAccess(function()
    Window:PlayIntro()
end)
gui:SetAttribute("VORBuildSeconds", os.clock() - SCRIPT_STARTED_AT)
gui:SetAttribute("VORBuildCompleted", true)

if pendingAutoLoadProfile then
    task.defer(function()
        local ok, message = Window:LoadProfile(pendingAutoLoadProfile)
        pcall(setSettingsStatus, message, ok)
        pcall(function()
            gui:SetAttribute("VORAutoLoadCompleted", true)
            gui:SetAttribute("VORAutoLoadProfile", pendingAutoLoadProfile)
            gui:SetAttribute("VORAutoLoadStatus", tostring(message))
        end)
    end)
end
