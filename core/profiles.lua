-- VOR Hub profile persistence and the shared Settings page.

return function(context)
    local Window = assert(context.Window, "profiles requires Window")
    local SETTINGS = assert(context.SETTINGS, "profiles requires SETTINGS")
    local Utilities = assert(context.Utilities, "profiles requires Utilities")
    local HttpService = Utilities.Services.HttpService
    local COLORS = SETTINGS.COLORS
    local PROFILE_VERSION = 4

    local function hasFileApi()
        return type(isfolder) == "function"
            and type(makefolder) == "function"
            and type(isfile) == "function"
            and type(readfile) == "function"
            and type(writefile) == "function"
    end

    local function profileName(value)
        return Utilities.SanitizeProfileName(value)
    end

    local function profilePath(name)
        return SETTINGS.ProfileFolder .. "/" .. profileName(name) .. ".json"
    end

    local function normalizeProfileData(metadata)
        if type(metadata) ~= "table" or type(metadata.values) ~= "table" then
            return false
        end
        local changed = false
        if SETTINGS.ActiveGame ~= nil
            and SETTINGS.ActiveGame.Key == "PracticalBasketball"
            and (tonumber(metadata.version) or 0) < PROFILE_VERSION then
            metadata.values.practical_basketball_vertical_perfect_offset = "-1.46824694"
            metadata.values.practical_basketball_release_delay = 0
            changed = true
        end
        if tonumber(metadata.version) ~= PROFILE_VERSION then
            metadata.version = PROFILE_VERSION
            changed = true
        end
        return changed
    end

    local function migrateLegacyConfigs()
        if not hasFileApi() or type(listfiles) ~= "function"
            or type(SETTINGS.LegacyConfigRoots) ~= "table" then
            return 0
        end
        local migrated = 0
        Utilities.EnsureFolder(SETTINGS.ProfileFolder)
        for _, legacyRoot in ipairs(SETTINGS.LegacyConfigRoots) do
            local legacyProfileFolder = tostring(legacyRoot) .. "/Profiles"
            local listed, files = pcall(function()
                if not isfolder(legacyProfileFolder) then
                    return {}
                end
                return listfiles(legacyProfileFolder)
            end)
            if listed and type(files) == "table" then
                for _, legacyPath in ipairs(files) do
                    local legacyName = profileName(tostring(legacyPath):match("([^/\\]+)%.json$") or "")
                    local destination = legacyName ~= "" and profilePath(legacyName) or nil
                    if destination and not isfile(destination) then
                        local decoded, metadata = pcall(function()
                            return HttpService:JSONDecode(readfile(legacyPath))
                        end)
                        if decoded and type(metadata) == "table" and type(metadata.values) == "table" then
                            normalizeProfileData(metadata)
                            metadata.scopeId = SETTINGS.ConfigScopeId
                            metadata.universeId = game.GameId
                            metadata.profile = legacyName
                            local copied = pcall(writefile, destination, HttpService:JSONEncode(metadata))
                            if copied then
                                migrated += 1
                            end
                        end
                    end
                end
            end

            if not isfile(SETTINGS.AutoLoadFile) then
                local legacyAutoLoad = tostring(legacyRoot) .. "/autoload.json"
                if isfile(legacyAutoLoad) then
                    local decoded, metadata = pcall(function()
                        return HttpService:JSONDecode(readfile(legacyAutoLoad))
                    end)
                    if decoded and type(metadata) == "table" then
                        metadata.scopeId = SETTINGS.ConfigScopeId
                        metadata.universeId = game.GameId
                        pcall(function()
                            Utilities.EnsureFolder(SETTINGS.ConfigRoot)
                            writefile(SETTINGS.AutoLoadFile, HttpService:JSONEncode(metadata))
                        end)
                    end
                end
            end
        end
        if migrated > 0 then
            warn(string.format("[VOR Hub] Migrated %d Practical Basketball profile(s) into the shared universe scope", migrated))
        end
        return migrated
    end

    migrateLegacyConfigs()

    local function encodeValue(value, seen)
        local kind = typeof(value)
        if kind == "Color3" then
            return {__vorType = "Color3", r = value.R, g = value.G, b = value.B}
        end
        if kind == "EnumItem" then
            return {__vorType = "EnumItem", value = tostring(value)}
        end
        if kind ~= "table" then
            return value
        end
        seen = seen or {}
        if seen[value] then
            return nil
        end
        seen[value] = true
        local result = {}
        for key, child in pairs(value) do
            local encoded = encodeValue(child, seen)
            if encoded ~= nil and (type(key) == "string" or type(key) == "number") then
                result[key] = encoded
            end
        end
        seen[value] = nil
        return result
    end

    local function decodeValue(value)
        if type(value) ~= "table" then
            return value
        end
        if value.__vorType == "Color3" then
            return Color3.new(tonumber(value.r) or 0, tonumber(value.g) or 0, tonumber(value.b) or 0)
        end
        if value.__vorType == "EnumItem" then
            return tostring(value.value or "")
        end
        local result = {}
        for key, child in pairs(value) do
            result[key] = decodeValue(child)
        end
        return result
    end

    local function resolveControl(flag)
        local direct = Window.PersistentControls[flag]
        if direct then
            return direct, flag
        end
        for canonical, aliases in pairs(SETTINGS.FlagAliases or {}) do
            local related = flag == canonical
            if not related then
                for _, alias in ipairs(aliases) do
                    if alias == flag then
                        related = true
                        break
                    end
                end
            end
            if related then
                if Window.PersistentControls[canonical] then
                    return Window.PersistentControls[canonical], canonical
                end
                for _, alias in ipairs(aliases) do
                    if Window.PersistentControls[alias] then
                        return Window.PersistentControls[alias], alias
                    end
                end
            end
        end
        return nil, nil
    end

    function Window:ProfilesAvailable()
        return hasFileApi()
    end

    function Window:GetProfileNames()
        if not hasFileApi() or type(listfiles) ~= "function" then
            return {}
        end
        local ok, files = pcall(function()
            Utilities.EnsureFolder(SETTINGS.ProfileFolder)
            return listfiles(SETTINGS.ProfileFolder)
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
            return tonumber(metadata.scopeId) == tonumber(SETTINGS.ConfigScopeId)
        end
        if metadata.placeId ~= nil then
            return tonumber(metadata.placeId) == game.PlaceId
        end
        return true
    end

    function Window:SaveProfile(name)
        if not hasFileApi() then
            return false, "Executor file API is unavailable"
        end
        local cleanName = profileName(name)
        if cleanName == "" then
            return false, "Enter a profile name"
        end
        local values = {}
        for flag, control in pairs(self.PersistentControls) do
            if control.Persist ~= false and type(control.Get) == "function" then
                local ok, value = pcall(control.Get, control)
                if ok and value ~= nil then
                    values[flag] = encodeValue(value)
                end
            end
        end
        local ok, err = pcall(function()
            Utilities.EnsureFolder(SETTINGS.ProfileFolder)
            writefile(profilePath(cleanName), HttpService:JSONEncode({
                version = PROFILE_VERSION,
                scopeId = SETTINGS.ConfigScopeId,
                placeId = game.PlaceId,
                universeId = game.GameId,
                profile = cleanName,
                values = values,
            }))
        end)
        if not ok then
            return false, "Could not save profile: " .. tostring(err)
        end
        self.Dirty = false
        self:SetProfileState(cleanName, "SAVED")
        self:AddActivity("Profile", "Saved " .. cleanName, COLORS.success)
        return true, "Saved / Overwrote profile: " .. cleanName, cleanName
    end

    function Window:LoadProfile(name)
        if not hasFileApi() then
            return false, "Executor file API is unavailable"
        end
        local cleanName = profileName(name)
        if cleanName == "" then
            return false, "Choose a profile to load"
        end
        local path = profilePath(cleanName)
        if not isfile(path) then
            return false, "Profile not found: " .. cleanName
        end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if not ok or type(data) ~= "table" or type(data.values) ~= "table" then
            return false, "Profile data is invalid"
        end
        if normalizeProfileData(data) then
            pcall(writefile, path, HttpService:JSONEncode(data))
        end
        if not self:ProfileScopeMatches(data) then
            return false, "Profile belongs to a different game"
        end

        local loaded = 0
        local appliedControls = {}
        for flag, storedValue in pairs(data.values) do
            local control, resolvedFlag = resolveControl(flag)
            if control and type(control.Set) == "function" and not appliedControls[control] then
                appliedControls[control] = true
                loaded += 1
                task.spawn(function()
                    local applied, applyError = pcall(control.Set, control, decodeValue(storedValue))
                    if not applied then
                        warn(string.format("[VOR Hub] Profile flag %s (%s) failed: %s", tostring(flag), tostring(resolvedFlag), tostring(applyError)))
                    end
                end)
            end
        end
        self.Dirty = false
        self:SetProfileState(cleanName, "SAVED")
        self:AddActivity("Profile", "Loaded " .. cleanName .. " with " .. tostring(loaded) .. " settings", COLORS.success)
        return true, "Loaded " .. cleanName .. " (" .. tostring(loaded) .. " settings)", cleanName
    end

    function Window:DeleteProfile(name)
        if not hasFileApi() or type(delfile) ~= "function" then
            return false, "Profile deletion is unavailable"
        end
        local cleanName = profileName(name)
        if cleanName == "" then
            return false, "Choose a profile to delete"
        end
        local path = profilePath(cleanName)
        if not isfile(path) then
            return false, "Profile not found: " .. cleanName
        end
        local ok, err = pcall(delfile, path)
        if not ok then
            return false, "Could not delete profile: " .. tostring(err)
        end
        self:AddActivity("Profile", "Deleted " .. cleanName, COLORS.warning)
        return true, "Deleted profile: " .. cleanName
    end

    function Window:SetAutoLoad(enabled, name)
        if not hasFileApi() then
            return false, "Executor file API is unavailable"
        end
        local cleanName = profileName(name)
        if enabled and (cleanName == "" or not isfile(profilePath(cleanName))) then
            return false, "Save or select a profile first"
        end
        local ok, err = pcall(function()
            Utilities.EnsureFolder(SETTINGS.ConfigRoot)
            writefile(SETTINGS.AutoLoadFile, HttpService:JSONEncode({
                enabled = enabled == true,
                scopeId = SETTINGS.ConfigScopeId,
                placeId = game.PlaceId,
                universeId = game.GameId,
                profile = cleanName,
            }))
        end)
        if not ok then
            return false, "Could not update Auto Load: " .. tostring(err)
        end
        return true, enabled and ("Auto Load enabled for: " .. cleanName) or "Auto Load disabled"
    end

    function Window:GetAutoLoad()
        if not hasFileApi() or not isfile(SETTINGS.AutoLoadFile) then
            return false, ""
        end
        local ok, metadata = pcall(function()
            return HttpService:JSONDecode(readfile(SETTINGS.AutoLoadFile))
        end)
        if not ok or type(metadata) ~= "table" or not self:ProfileScopeMatches(metadata) then
            return false, ""
        end
        return metadata.enabled == true, profileName(metadata.profile)
    end

    function Window:BuildGlobalSettingsPage()
        local page = self.Pages.Settings or self:AddPage("Settings")
        local appearance = page:AddSection("Interface", "Left")
        local profiles = page:AddSection("Profiles", "Right")
        local access = page:AddSection("Access & Community", "Left")
        local runtime = page:AddSection("Runtime", "Right")

        appearance:AddDropdown({
            Name = "UI Background",
            Description = "Changes the artwork behind the VOR panels",
            Flag = "vor_panel_background",
            Options = {"VOR Signature (557862299)", "VOR Void", "VOR Purple"},
            Default = SETTINGS.DefaultPanelBackground,
            Callback = function(value)
                self:SetPanelBackground(value)
            end,
        })
        appearance:AddToggle({
            Name = "Animated Background Shine",
            Description = "Rotates a glossy reflection across the selected UI artwork",
            Flag = "vor_background_motion",
            Default = SETTINGS.BackgroundMotionEnabled,
            Callback = function(value)
                self:SetBackgroundMotion(value)
            end,
        })
        appearance:AddSlider({
            Name = "Background Shine Speed",
            Description = "Controls how quickly the reflected band circles the background",
            Flag = "vor_background_motion_speed",
            Min = 8,
            Max = 100,
            Default = SETTINGS.BackgroundMotionSpeed,
            Step = 1,
            Callback = function(value)
                self:SetBackgroundMotionSpeed(value)
            end,
        })
        appearance:AddSlider({
            Name = "Background Shine Strength",
            Description = "Controls how bright the moving reflection appears over the picture",
            Flag = "vor_background_motion_strength",
            Min = 0.06,
            Max = 0.42,
            Default = SETTINGS.BackgroundMotionStrength,
            Step = 0.01,
            Callback = function(value)
                self:SetBackgroundMotionStrength(value)
            end,
        })
        appearance:AddDropdown({
            Name = "VOR Accent Color",
            Description = "Recolors active controls, borders, highlights, and navigation",
            Flag = "frozen_accent_preset",
            Persist = false,
            Options = {"VOR Violet", "Royal Purple", "Neon Amethyst", "Abyss Purple", "Void Magenta", "Silver Violet", "Blacklight", "Imperial Plum"},
            Default = "VOR Violet",
            Callback = function(value)
                self:SetAccentPreset(value)
            end,
        })
        appearance:AddSlider({
            Name = "Hub Transparency",
            Description = "Controls transparency across the complete shell and its panels",
            Flag = "hub_transparency",
            Min = 0.10,
            Max = 0.80,
            Default = 0.24,
            Step = 0.05,
            Callback = function(value)
                self:SetHubTransparency(value)
            end,
        })
        appearance:AddDropdown({
            Name = "Minimized Style",
            Description = "Choose a floating crest or a labeled compact reopen bar",
            Flag = "hub_minimized_style",
            Options = {"Void Crest", "Compact Bar"},
            Default = SETTINGS.MinimizedStyleDefault,
            Callback = function(value)
                self:SetMinimizeStyle(value)
            end,
        })
        self.PersistentControls["hub_minimized_position"] = {
            Name = "Minimized Position",
            Flag = "hub_minimized_position",
            Persist = true,
            Get = function()
                return self:GetMinimizedPosition()
            end,
            Set = function(_, value)
                self:SetMinimizedPosition(value)
            end,
        }
        appearance:AddButton({
            Name = "Reset Minimized Position",
            Description = "The cat crest and compact bar can both be dragged anywhere",
            Persist = false,
            Callback = function()
                self:SetMinimizedPosition("0.0800,0.5000")
                self:MarkDirty()
            end,
        })
        appearance:AddDropdown({
            Name = "Visual Detail",
            Description = "Full Effects shows artwork, Void Glass darkens it, Performance removes artwork",
            Flag = "vor_theme_intensity",
            Options = {"Full Effects", "Void Glass", "Performance"},
            Default = SETTINGS.ThemeIntensity,
            Callback = function(value)
                self:SetThemeIntensity(value)
            end,
        })

        -- Preserve the old saved flag without wasting Settings-page space on
        -- a slider that never changed Roblox's render rate.
        self.PersistentControls["vor_ui_animation_rate"] = {
            Name = "Legacy UI Animation Rate",
            Flag = "vor_ui_animation_rate",
            Persist = true,
            Get = function()
                return SETTINGS.UIAnimationRate
            end,
            Set = function(_, value)
                SETTINGS.UIAnimationRate = math.clamp(tonumber(value) or 240, 30, 240)
            end,
        }
        appearance:AddToggle({
            Name = "Reduced Motion",
            Flag = "vor_reduced_motion",
            Default = SETTINGS.ReducedMotion,
            Callback = function(value)
                self:SetReducedMotion(value)
            end,
        })
        appearance:AddSlider({
            Name = "UI Scale",
            Flag = "vor_ui_scale",
            Min = 0.70,
            Max = 1.30,
            Default = SETTINGS.UIScale,
            Step = 0.05,
            Callback = function(value)
                self:SetUIScale(value)
            end,
        })

        local paletteLeft = page:AddSection("Color Studio - Surfaces", "Left")
        local paletteRight = page:AddSection("Color Studio - Text & States", "Right")
        local paletteControls = {}
        local paletteDefinitions = {
            {"logoBackground", "Logo Background", paletteLeft},
            {"shell", "Shell", paletteLeft},
            {"rail", "Navigation Rail", paletteLeft},
            {"surface", "Panel Surface", paletteLeft},
            {"surfaceRaised", "Raised Surface", paletteLeft},
            {"surfaceHover", "Hover Surface", paletteLeft},
            {"control", "Control", paletteLeft},
            {"controlHover", "Control Hover", paletteLeft},
            {"border", "Border", paletteLeft},
            {"borderBright", "Bright Border", paletteLeft},
            {"toggleOff", "Toggle Off", paletteLeft},
            {"text", "Primary Text", paletteRight},
            {"muted", "Muted Text", paletteRight},
            {"dim", "Dim Text", paletteRight},
            {"accent", "Accent", paletteRight},
            {"accentBright", "Bright Accent", paletteRight},
            {"accentDark", "Dark Accent", paletteRight},
            {"success", "Success", paletteRight},
            {"warning", "Warning", paletteRight},
            {"error", "Danger / Error", paletteRight},
            {"white", "Pure Light", paletteRight},
            {"black", "Pure Dark", paletteRight},
        }
        for _, definition in ipairs(paletteDefinitions) do
            local key, displayName, section = definition[1], definition[2], definition[3]
            paletteControls[key] = section:AddColorPicker({
                Name = displayName,
                Description = "Click the swatch for the full picker or type any #RRGGBB hex color",
                Flag = "vor_color_" .. key,
                Default = COLORS[key],
                Callback = function(value)
                    self:SetPaletteColor(key, value)
                end,
            })
        end
        paletteRight:AddButton({
            Name = "Reset Complete VOR Palette",
            Description = "Restores every UI color while keeping your other settings",
            Persist = false,
            Callback = function()
                for key, control in pairs(paletteControls) do
                    control:Set(SETTINGS.DefaultColors[key])
                end
            end,
        })

        local nameControl = profiles:AddInput({
            Name = "Profile Name",
            Placeholder = "Example: Main Setup",
            Persist = false,
        })
        local savedControl
        savedControl = profiles:AddDropdown({
            Name = "Saved Profiles",
            Options = {},
            Persist = false,
            Callback = function(value)
                if value then
                    nameControl:Set(value, true)
                end
            end,
        })
        local profileStatus = profiles:AddLabel("Checking profile storage...")

        local function chosenProfile()
            local typed = profileName(nameControl:Get())
            return typed ~= "" and typed or profileName(savedControl:Get())
        end
        local function refreshProfiles(preferred)
            local names = self:GetProfileNames()
            savedControl:SetOptions(names)
            local wanted = profileName(preferred or chosenProfile())
            if wanted ~= "" then
                for _, name in ipairs(names) do
                    if name == wanted then
                        savedControl:Set(name, true)
                        nameControl:Set(name, true)
                        break
                    end
                end
            end
            return names
        end
        local function showProfileResult(ok, message)
            profileStatus.Text = tostring(message)
            profileStatus.TextColor3 = ok and COLORS.success or COLORS.error
        end

        profiles:AddButton({Name = "Save / Overwrite", Callback = function()
            local ok, message, savedName = self:SaveProfile(chosenProfile())
            showProfileResult(ok, message)
            if ok then
                refreshProfiles(savedName)
                self:Notify("Settings", message, 2.5)
            end
        end})
        profiles:AddButton({Name = "Load Profile", Callback = function()
            local ok, message, loadedName = self:LoadProfile(chosenProfile())
            showProfileResult(ok, message)
            if ok then
                nameControl:Set(loadedName, true)
                savedControl:Set(loadedName, true)
                self:Notify("Settings", message, 2.5)
            end
        end})
        local pendingDelete = ""
        local pendingUntil = 0
        profiles:AddButton({Name = "Delete Profile", Description = "Click twice within four seconds", Callback = function()
            local chosen = chosenProfile()
            if chosen == "" then
                showProfileResult(false, "Choose a profile to delete")
            elseif pendingDelete ~= chosen or os.clock() > pendingUntil then
                pendingDelete = chosen
                pendingUntil = os.clock() + 4
                showProfileResult(false, "Click Delete Profile again to confirm: " .. chosen)
            else
                local ok, message = self:DeleteProfile(chosen)
                pendingDelete = ""
                pendingUntil = 0
                showProfileResult(ok, message)
                if ok then
                    nameControl:Set("", true)
                    refreshProfiles()
                end
            end
        end})
        profiles:AddButton({Name = "Refresh Profile List", Callback = function()
            local names = refreshProfiles()
            showProfileResult(true, "Found " .. tostring(#names) .. " saved profile(s)")
        end})

        local autoLoadControl
        autoLoadControl = profiles:AddToggle({
            Name = "Auto Load Selected Profile",
            Persist = false,
            Default = false,
            Callback = function(enabled)
                local ok, message = self:SetAutoLoad(enabled, chosenProfile())
                if not ok then
                    autoLoadControl:Set(false, true)
                end
                showProfileResult(ok, message)
            end,
        })

        access:AddLabel("Keys, support, updates, and the supported-game list live in the VOR Hub Discord.")
        access:AddButton({Name = "Copy VOR Hub Discord", Persist = false, Callback = function()
            if Utilities.CopyText(SETTINGS.DiscordInviteURL) then
                self:Notify("Discord", "Invite copied", 2)
            else
                self:Notify("Discord", SETTINGS.Discord, 4)
            end
        end})
        access:AddButton({Name = "Forget Remembered Key", Persist = false, Callback = function()
            if self.ForgetKeyAccess then
                self:ForgetKeyAccess()
                self:Notify("Access", "Remembered access cleared", 3)
            end
        end})

        runtime:AddLabel("Module: " .. tostring(SETTINGS.ActiveGame and SETTINGS.ActiveGame.Module or "unsupported"))
        runtime:AddLabel("PlaceId: " .. tostring(game.PlaceId))
        runtime:AddLabel("UniverseId: " .. tostring(game.GameId))
        runtime:AddButton({Name = "Open Activity Drawer", Persist = false, Callback = function()
            self:SetDrawer(true, "Activity")
        end})
        runtime:AddButton({Name = "Open Notification History", Persist = false, Callback = function()
            self:SetDrawer(true, "Notifications")
        end})

        local pendingAutoLoad = nil
        if self:ProfilesAvailable() then
            refreshProfiles()
            local enabled, autoName = self:GetAutoLoad()
            if enabled and autoName ~= "" then
                nameControl:Set(autoName, true)
                savedControl:Set(autoName, true)
                autoLoadControl:Set(true, true)
                pendingAutoLoad = autoName
                profileStatus.Text = "Auto-loading: " .. autoName
            else
                profileStatus.Text = "Enter a profile name to save or load"
            end
        else
            showProfileResult(false, "Executor file API is unavailable")
        end

        return pendingAutoLoad
    end

    return Window
end
