-- VOR Hub access gate and intro. The clear-text key is never stored.

return function(context)
    local Window = assert(context.Window, "access requires Window")
    local SETTINGS = assert(context.SETTINGS, "access requires SETTINGS")
    local Utilities = assert(context.Utilities, "access requires Utilities")
    local Gui = assert(context.Gui or Window.Gui, "access requires Gui")
    local COLORS = SETTINGS.COLORS
    local TweenService = Utilities.Services.TweenService
    local HttpService = Utilities.Services.HttpService
    local function optionalFont(name, fallback)
        local ok, value = pcall(function()
            return Enum.Font[name]
        end)
        return ok and value or fallback
    end
    local readableFont = optionalFont("Nunito", Enum.Font.GothamMedium)

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

    local function stroke(parent, color, transparency, thickness)
        return create("UIStroke", {
            Color = color or COLORS.border,
            Transparency = transparency or 0,
            Thickness = thickness or 1,
        }, parent)
    end

    local function tween(object, duration, properties)
        if SETTINGS.ReducedMotion then
            for key, value in pairs(properties) do
                object[key] = value
            end
            return nil
        end
        local animation = TweenService:Create(object, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), properties)
        animation:Play()
        return animation
    end

    local function label(parent, text, size, position, color, textSize, font)
        if font == Enum.Font.Gotham
            or font == Enum.Font.GothamMedium
            or font == Enum.Font.GothamSemibold
            or font == Enum.Font.GothamBold then
            font = readableFont
        end
        return create("TextLabel", {
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            Size = size,
            Position = position,
            TextColor3 = color or COLORS.text,
            TextSize = textSize or 12,
            Font = font or Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 904,
        }, parent)
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

    local function remembered()
        if _G.VORHubAccessHash == SETTINGS.AccessKeyHash then
            return true
        end
        if not SETTINGS.RememberKey or not Utilities.FileApiAvailable() or not isfile(SETTINGS.AccessFile) then
            return false
        end
        local ok, metadata = pcall(function()
            return HttpService:JSONDecode(readfile(SETTINGS.AccessFile))
        end)
        return ok and type(metadata) == "table" and tonumber(metadata.keyHash) == SETTINGS.AccessKeyHash
    end

    local function remember()
        _G.VORHubAccessHash = SETTINGS.AccessKeyHash
        if not SETTINGS.RememberKey or not Utilities.FileApiAvailable() then
            return
        end
        pcall(function()
            Utilities.EnsureFolder("VORHub/Configs")
            writefile(SETTINGS.AccessFile, HttpService:JSONEncode({version = 1, keyHash = SETTINGS.AccessKeyHash}))
        end)
    end

    function Window:ForgetKeyAccess()
        _G.VORHubAccessHash = nil
        if type(isfile) == "function" and type(delfile) == "function" and isfile(SETTINGS.AccessFile) then
            pcall(delfile, SETTINGS.AccessFile)
        end
        Gui:SetAttribute("AccessGateState", "Forgotten")
    end

    function Window:RequestKeyAccess(onGranted)
        if remembered() then
            Gui:SetAttribute("AccessGateState", "Remembered")
            task.defer(function()
                if type(onGranted) == "function" then
                    onGranted()
                end
            end)
            return true
        end

        self.Main.Visible = false
        Gui:SetAttribute("AccessGateState", "Locked")
        Gui:SetAttribute("DiscordInviteURL", SETTINGS.DiscordInviteURL)

        local gate = create("Frame", {
            Name = "VORAccessGate",
            Active = true,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(5, 2, 10),
            BackgroundTransparency = 0.44,
            ZIndex = 900,
        }, Gui)
        create("UIGradient", {
            Rotation = 122,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(3, 2, 7)),
                ColorSequenceKeypoint.new(0.52, Color3.fromRGB(25, 8, 43)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 2, 13)),
            }),
        }, gate)

        local card = create("Frame", {
            Name = "AccessCard",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(650, 450),
            BackgroundColor3 = COLORS.surface:Lerp(COLORS.text, 0.08),
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 901,
        }, gate)
        corner(card, 20)
        local cardStroke = stroke(card, COLORS.accentBright, 0, 2)
        local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local accessScale = math.clamp(math.min((viewportSize.X - 24) / 650, (viewportSize.Y - 24) / 450), 0.68, 1)
        local cardScale = create("UIScale", {Scale = accessScale * 0.94}, card)

        local crest = create("ImageLabel", {
            Name = "AccessBrandLogo",
            Size = UDim2.fromOffset(78, 78),
            Position = UDim2.new(0.5, -39, 0, 20),
            BackgroundColor3 = COLORS.surfaceRaised,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            Image = SETTINGS.BrandLogoImage,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 904,
        }, card)
        corner(crest, 19)
        stroke(crest, COLORS.accentBright, 0, 1.5)

        local title = label(card, "VOR HUB ACCESS", UDim2.new(1, -48, 0, 38), UDim2.fromOffset(24, 107), COLORS.text, 30, Enum.Font.GothamBold)
        title.TextXAlignment = Enum.TextXAlignment.Center
        local description = label(card, "Join Discord for the current key, supported games, updates, and support.", UDim2.new(1, -80, 0, 42), UDim2.fromOffset(40, 148), COLORS.muted, 14, Enum.Font.GothamMedium)
        description.TextWrapped = true
        local steps = label(card, "1  COPY DISCORD     •     2  PASTE KEY     •     3  UNLOCK", UDim2.new(1, -80, 0, 24), UDim2.fromOffset(40, 187), COLORS.accentBright, 12, Enum.Font.GothamBold)
        steps.TextXAlignment = Enum.TextXAlignment.Center

        local keyBox = create("TextBox", {
            Name = "DiscordKeyInput",
            Position = UDim2.fromOffset(42, 220),
            Size = UDim2.new(1, -84, 0, 56),
            BackgroundColor3 = COLORS.control:Lerp(COLORS.text, 0.06),
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = readableFont,
            PlaceholderText = "Enter the key from Discord",
            PlaceholderColor3 = COLORS.muted,
            Text = "",
            TextColor3 = COLORS.text,
            TextSize = 17,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 904,
        }, card)
        corner(keyBox, 11)
        stroke(keyBox, COLORS.accentBright, 0.15, 1.5)
        create("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}, keyBox)

        local status = label(card, "Your key is never saved; only its one-way hash is remembered.", UDim2.new(1, -84, 0, 28), UDim2.fromOffset(42, 282), COLORS.muted, 12, Enum.Font.GothamMedium)

        local unlock = create("TextButton", {
            Position = UDim2.fromOffset(42, 322),
            Size = UDim2.new(0.60, -50, 0, 58),
            BackgroundColor3 = COLORS.accent,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "UNLOCK VOR HUB",
            TextColor3 = COLORS.white,
            TextSize = 15,
            Font = readableFont,
            ZIndex = 904,
        }, card)
        corner(unlock, 10)

        local discord = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -42, 0, 322),
            Size = UDim2.new(0.40, -2, 0, 58),
            BackgroundColor3 = COLORS.surfaceRaised,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "COPY DISCORD",
            TextColor3 = COLORS.text,
            TextSize = 15,
            Font = readableFont,
            ZIndex = 904,
        }, card)
        corner(discord, 10)
        stroke(discord, COLORS.borderBright, 0.25, 1)

        local footer = label(card, SETTINGS.Discord .. "  •  Right Ctrl toggles the hub", UDim2.new(1, -60, 0, 26), UDim2.fromOffset(30, 405), COLORS.muted, 11, Enum.Font.GothamMedium)
        footer.TextXAlignment = Enum.TextXAlignment.Center

        local unlocking = false
        local function grant()
            if unlocking then
                return
            end
            local supplied = tostring(keyBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if hashAccessKey(supplied) ~= SETTINGS.AccessKeyHash then
                status.Text = "Invalid key. Copy the Discord invite and check the key channel."
                status.TextColor3 = COLORS.error
                tween(cardStroke, 0.12, {Color = COLORS.error, Transparency = 0})
                task.delay(0.5, function()
                    if cardStroke.Parent then
                        tween(cardStroke, 0.25, {Color = COLORS.accent, Transparency = 0.08})
                    end
                end)
                return
            end
            unlocking = true
            remember()
            Gui:SetAttribute("AccessGateState", "Granted")
            status.Text = "Access granted. Entering the void..."
            status.TextColor3 = COLORS.success
            tween(gate, 0.28, {BackgroundTransparency = 1})
            tween(cardScale, 0.28, {Scale = accessScale * 1.05})
            task.delay(0.3, function()
                if gate.Parent then
                    gate:Destroy()
                end
                if type(onGranted) == "function" then
                    onGranted()
                end
            end)
        end

        Utilities.Track(unlock.Activated:Connect(grant))
        Utilities.Track(keyBox.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                grant()
            end
        end))
        Utilities.Track(discord.Activated:Connect(function()
            if Utilities.CopyText(SETTINGS.DiscordInviteURL) then
                status.Text = "Discord invite copied."
                status.TextColor3 = COLORS.success
            else
                status.Text = SETTINGS.DiscordInviteURL
                status.TextColor3 = COLORS.warning
            end
        end))

        tween(cardScale, 0.36, {Scale = accessScale})
        task.delay(0.34, function()
            if keyBox.Parent then
                keyBox:CaptureFocus()
            end
        end)
        return false
    end

    function Window:PlayIntro()
        if not SETTINGS.IntroEnabled then
            self.Main.Visible = true
            self:ShowOnboarding()
            return
        end
        self.Main.Visible = false
        local duration = math.max(3, tonumber(SETTINGS.IntroDuration) or 5)
        local intro = create("CanvasGroup", {
            Name = "VORIntro",
            Active = true,
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            GroupTransparency = 0,
            ZIndex = 800,
        }, Gui)

        local chime = nil
        if SETTINGS.IntroSoundEnabled and tostring(SETTINGS.IntroSoundId or "") ~= "" then
            chime = create("Sound", {
                Name = "VORIntroChime",
                SoundId = tostring(SETTINGS.IntroSoundId),
                Volume = math.clamp(tonumber(SETTINGS.IntroSoundVolume) or 0.32, 0, 1),
                Looped = false,
            }, intro)
        end
        local music = nil
        if SETTINGS.IntroMusicEnabled and tostring(SETTINGS.IntroMusicSoundId or "") ~= "" then
            music = create("Sound", {
                Name = "VORIntroMusic",
                SoundId = tostring(SETTINGS.IntroMusicSoundId),
                Volume = math.clamp(tonumber(SETTINGS.IntroMusicVolume) or 0.52, 0, 1),
                Looped = false,
            }, intro)
        end

        local random = Random.new(math.floor(os.clock() * 1000) % 100000)
        local catCount = math.clamp(math.floor(tonumber(SETTINGS.IntroParticleCount) or 8), 4, 12)
        for index = 1, catCount do
            local size = random:NextInteger(78, 116)
            local startX = index % 2 == 0 and random:NextNumber(0.03, 0.16) or random:NextNumber(0.84, 0.97)
            local startY = random:NextNumber(-0.35, 0.25)
            local cat = create("ImageLabel", {
                Name = "WetCatParticle" .. tostring(index),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(startX, startY),
                Size = UDim2.fromOffset(size, size),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Image = SETTINGS.MinimizedCrestImage,
                ImageTransparency = random:NextNumber(0.08, 0.22),
                Rotation = random:NextInteger(-24, 24),
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 801,
            }, intro)
            if not SETTINGS.ReducedMotion then
                TweenService:Create(cat, TweenInfo.new(
                    duration + random:NextNumber(0.8, 2.2),
                    Enum.EasingStyle.Linear,
                    Enum.EasingDirection.Out,
                    0,
                    false,
                    random:NextNumber(0, 1.25)
                ), {
                    Position = UDim2.fromScale(math.clamp(startX + random:NextNumber(-0.05, 0.05), 0.03, 0.97), 1.18),
                    Rotation = cat.Rotation + random:NextInteger(80, 220),
                }):Play()
            end
        end

        local centerPlate = create("Frame", {
            Name = "IntroCenterPlate",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.fromOffset(900, 640),
            BackgroundColor3 = COLORS.surface,
            BackgroundTransparency = 0.22,
            BorderSizePixel = 0,
            ZIndex = 802,
        }, intro)
        corner(centerPlate, 30)
        stroke(centerPlate, COLORS.borderBright, 0.12, 2)
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        create("UIScale", {
            Scale = math.clamp(math.min((viewport.X - 28) / 900, (viewport.Y - 28) / 640), 0.42, 1),
        }, centerPlate)
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, COLORS.surfaceRaised),
                ColorSequenceKeypoint.new(0.55, COLORS.surface),
                ColorSequenceKeypoint.new(1, COLORS.accentDark),
            }),
        }, centerPlate)

        local logoGlow = create("ImageLabel", {
            Name = "LogoGlow",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.20),
            Size = UDim2.fromOffset(420, 420),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = "rbxasset://textures/particles/sparkles_main.dds",
            ImageColor3 = COLORS.accent,
            ImageTransparency = 1,
            ZIndex = 802,
        }, centerPlate)
        local logo = create("ImageLabel", {
            Name = "VORBrandLogo",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.20),
            Size = UDim2.fromOffset(218, 218),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Image = SETTINGS.BrandLogoImage,
            ImageTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 804,
        }, centerPlate)
        local eyebrow = label(centerPlate, "AUTHORIZED ACCESS  //  VOR NETWORK", UDim2.new(1, -70, 0, 30), UDim2.fromOffset(35, 232), COLORS.muted, 14, Enum.Font.Code)
        local title = label(centerPlate, "WELCOME TO VOR HUB", UDim2.new(1, -60, 0, 88), UDim2.fromOffset(30, 268), COLORS.text, 62, Enum.Font.GothamBold)
        local identity = label(centerPlate, tostring(Utilities.LocalPlayer and Utilities.LocalPlayer.DisplayName or "Player"), UDim2.new(1, -60, 0, 62), UDim2.fromOffset(30, 354), COLORS.accentBright, 42, Enum.Font.GothamBold)
        local gameName = SETTINGS.ActiveGame and SETTINGS.ActiveGame.DisplayName or "Unsupported Game"
        local divider = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 430),
            Size = UDim2.fromOffset(520, 3),
            BackgroundColor3 = COLORS.accent,
            BackgroundTransparency = 0.16,
            BorderSizePixel = 0,
            ZIndex = 804,
        }, centerPlate)
        corner(divider, 2)
        local sub = label(centerPlate, "MODULE READY  •  " .. gameName, UDim2.new(1, -60, 0, 36), UDim2.fromOffset(30, 454), COLORS.text, 18, Enum.Font.GothamSemibold)
        local discord = label(centerPlate, SETTINGS.Discord, UDim2.new(1, -60, 0, 34), UDim2.fromOffset(30, 500), COLORS.accentBright, 17, Enum.Font.GothamBold)
        local statusPlate = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 554),
            Size = UDim2.fromOffset(470, 48),
            BackgroundColor3 = Color3.fromRGB(9, 28, 21),
            BackgroundTransparency = 0.10,
            BorderSizePixel = 0,
            ZIndex = 803,
        }, centerPlate)
        corner(statusPlate, 21)
        stroke(statusPlate, COLORS.success, 0.42, 1)
        local status = label(statusPlate, "●  GAME DETECTED  •  INJECTED SUCCESSFULLY", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), COLORS.success, 14, Enum.Font.Code)
        eyebrow.TextTransparency = 1
        title.TextTransparency = 1
        identity.TextTransparency = 1
        sub.TextTransparency = 1
        discord.TextTransparency = 1
        status.TextTransparency = 1

        if chime then pcall(function() chime:Play() end) end
        if music then pcall(function() music:Play() end) end
        tween(logoGlow, 0.65, {ImageTransparency = 0.68, Size = UDim2.fromOffset(470, 470)})
        tween(logo, 0.55, {ImageTransparency = 0, Size = UDim2.fromOffset(248, 248)})
        tween(eyebrow, 0.42, {TextTransparency = 0})
        tween(title, 0.50, {TextTransparency = 0})
        task.delay(0.12, function() if identity.Parent then tween(identity, 0.45, {TextTransparency = 0}) end end)
        task.delay(0.22, function() if sub.Parent then tween(sub, 0.45, {TextTransparency = 0}) end end)
        task.delay(0.32, function() if discord.Parent then tween(discord, 0.45, {TextTransparency = 0}) end end)
        task.delay(0.44, function() if status.Parent then tween(status, 0.45, {TextTransparency = 0}) end end)

        task.delay(duration, function()
            if music and music.Parent then tween(music, 0.6, {Volume = 0}) end
            if chime and chime.Parent then tween(chime, 0.35, {Volume = 0}) end
            local animation = tween(intro, 0.65, {GroupTransparency = 1})
            local function finish()
                if intro.Parent then
                    intro:Destroy()
                end
                self.Main.Visible = true
                self:ShowOnboarding()
            end
            if animation then
                animation.Completed:Once(finish)
            else
                finish()
            end
        end)
    end

    return Window
end
