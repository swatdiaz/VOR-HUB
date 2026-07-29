-- VOR Hub access gate and intro. The clear-text key is never stored.

return function(context)
    local Window = assert(context.Window, "access requires Window")
    local SETTINGS = assert(context.SETTINGS, "access requires SETTINGS")
    local Utilities = assert(context.Utilities, "access requires Utilities")
    local Gui = assert(context.Gui or Window.Gui, "access requires Gui")
    local COLORS = SETTINGS.COLORS
    local TweenService = Utilities.Services.TweenService
    local HttpService = Utilities.Services.HttpService

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

        local gate = create("CanvasGroup", {
            Name = "VORAccessGate",
            Active = true,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(3, 1, 7),
            BackgroundTransparency = 0.06,
            GroupTransparency = 1,
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
            Size = UDim2.fromOffset(530, 360),
            BackgroundColor3 = COLORS.surface,
            BackgroundTransparency = 0.04,
            BorderSizePixel = 0,
            ZIndex = 901,
        }, gate)
        corner(card, 18)
        local cardStroke = stroke(card, COLORS.accent, 0.08, 1.5)
        local cardScale = create("UIScale", {Scale = 0.9}, card)

        local crest = label(card, "✦", UDim2.fromOffset(68, 68), UDim2.new(0.5, -34, 0, 20), COLORS.accentBright, 45, Enum.Font.GothamBold)
        crest.BackgroundColor3 = COLORS.surfaceRaised
        crest.BackgroundTransparency = 0.05
        corner(crest, 17)
        stroke(crest, COLORS.accentBright, 0.2, 1)

        local title = label(card, "VOR HUB ACCESS", UDim2.new(1, -48, 0, 34), UDim2.fromOffset(24, 96), COLORS.text, 25, Enum.Font.GothamBold)
        title.TextXAlignment = Enum.TextXAlignment.Center
        local description = label(card, "Join Discord for the current key, supported games, updates, and support.", UDim2.new(1, -70, 0, 38), UDim2.fromOffset(35, 128), COLORS.muted, 11, Enum.Font.GothamMedium)
        description.TextWrapped = true

        local keyBox = create("TextBox", {
            Name = "DiscordKeyInput",
            Position = UDim2.fromOffset(40, 178),
            Size = UDim2.new(1, -80, 0, 46),
            BackgroundColor3 = COLORS.control,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = Enum.Font.GothamSemibold,
            PlaceholderText = "Enter the key from Discord",
            PlaceholderColor3 = COLORS.dim,
            Text = "",
            TextColor3 = COLORS.text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 904,
        }, card)
        corner(keyBox, 10)
        stroke(keyBox, COLORS.borderBright, 0.28, 1)
        create("UIPadding", {PaddingLeft = UDim.new(0, 13), PaddingRight = UDim.new(0, 13)}, keyBox)

        local status = label(card, "The key itself is never saved—only its one-way hash.", UDim2.new(1, -80, 0, 24), UDim2.fromOffset(40, 229), COLORS.dim, 10, Enum.Font.GothamMedium)

        local unlock = create("TextButton", {
            Position = UDim2.fromOffset(40, 266),
            Size = UDim2.new(0.57, -6, 0, 50),
            BackgroundColor3 = COLORS.accent,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "UNLOCK VOR HUB",
            TextColor3 = COLORS.white,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            ZIndex = 904,
        }, card)
        corner(unlock, 10)

        local discord = create("TextButton", {
            Position = UDim2.new(0.57, 42, 0, 266),
            Size = UDim2.new(0.43, -82, 0, 50),
            BackgroundColor3 = COLORS.surfaceRaised,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Text = "COPY DISCORD",
            TextColor3 = COLORS.text,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            ZIndex = 904,
        }, card)
        corner(discord, 10)
        stroke(discord, COLORS.borderBright, 0.25, 1)

        local footer = label(card, SETTINGS.Discord .. "  •  Right Ctrl toggles the hub", UDim2.new(1, -50, 0, 22), UDim2.fromOffset(25, 328), COLORS.dim, 9, Enum.Font.GothamMedium)
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
            tween(gate, 0.28, {GroupTransparency = 1})
            tween(cardScale, 0.28, {Scale = 1.08})
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

        tween(gate, 0.28, {GroupTransparency = 0})
        tween(cardScale, 0.36, {Scale = 1})
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
        local intro = create("CanvasGroup", {
            Name = "VORIntro",
            Active = true,
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.fromRGB(3, 1, 7),
            GroupTransparency = 0,
            ZIndex = 800,
        }, Gui)
        create("UIGradient", {
            Rotation = 118,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(2, 1, 5)),
                ColorSequenceKeypoint.new(0.5, Color3.fromRGB(36, 11, 60)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 3, 15)),
            }),
        }, intro)
        local crest = label(intro, "✦", UDim2.fromOffset(130, 130), UDim2.new(0.5, -65, 0.5, -92), COLORS.accentBright, 80, Enum.Font.GothamBold)
        crest.BackgroundColor3 = COLORS.surface
        crest.BackgroundTransparency = 0.25
        corner(crest, 32)
        stroke(crest, COLORS.accentBright, 0.12, 2)
        local title = label(intro, "VOR HUB", UDim2.fromOffset(460, 58), UDim2.new(0.5, -230, 0.5, 50), COLORS.text, 38, Enum.Font.GothamBold)
        local sub = label(intro, SETTINGS.ActiveGame and SETTINGS.ActiveGame.DisplayName or "Unsupported Game", UDim2.fromOffset(520, 32), UDim2.new(0.5, -260, 0.5, 103), COLORS.muted, 13, Enum.Font.GothamMedium)
        crest.TextTransparency = 1
        title.TextTransparency = 1
        sub.TextTransparency = 1
        tween(crest, 0.35, {TextTransparency = 0})
        tween(title, 0.4, {TextTransparency = 0})
        tween(sub, 0.45, {TextTransparency = 0})
        task.delay(math.max(1.4, tonumber(SETTINGS.IntroDuration) or 3.25), function()
            local animation = tween(intro, 0.5, {GroupTransparency = 1})
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
