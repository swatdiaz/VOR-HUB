-- VOR Hub - Blox Fruits runtime adapter
--
-- When the compatible Blox function engine is already running, its public
-- control objects remain available in memory. This adapter imports those live
-- callbacks into VOR controls without copying its interface or private key.

return function(context)
    local Window = assert(context.Window, "Blox Fruits: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Blox Fruits: category builder is required")
    local CATEGORY_DECALS = assert(context.CategoryDecals, "Blox Fruits: category decals are required")
    local COLORS = assert(context.Colors, "Blox Fruits: colors are required")
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local LEGACY_WINDOW_TITLE = "Solix Hub | Blox Fruit | discord.gg/solixhub"
    local UI_ONLY_FLAGS = {
        ["Accent"] = true,
        ["Auto Execute"] = true,
        ["Auto Load Script"] = true,
        ["Auto Minimize"] = true,
        ["Auto Save Config"] = true,
        ["Background"] = true,
        ["Background Transparency"] = true,
        ["Border"] = true,
        ["Config Name"] = true,
        ["Config Select"] = true,
        ["Element"] = true,
        ["Floating Button Position"] = true,
        ["Inactive Text"] = true,
        ["Inline"] = true,
        ["Menu Fade Time"] = true,
        ["Menu Keybind"] = true,
        ["Menu Scale"] = true,
        ["Menu Tween Time"] = true,
        ["Paste Shared Config"] = true,
        ["Shadow"] = true,
        ["Show Floating Button"] = true,
        ["Show Keybind List"] = true,
        ["Show Watermark"] = true,
        ["Solix Id"] = true,
        ["Text"] = true,
        ["Theme Name"] = true,
    }

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local FarmPage = addHomeCategory("Farming", 1, CATEGORY_DECALS.Overnight)
    local CombatPage = addHomeCategory("Combat", 2, CATEGORY_DECALS.Combat)
    local ProgressPage = addHomeCategory("Progress", 3, CATEGORY_DECALS.Progress)
    local SeaPage = addHomeCategory("Sea & Raids", 4, CATEGORY_DECALS.Weapons)
    local PlayerPage = addHomeCategory("Player", 5, CATEGORY_DECALS.Player)
    selectHomeCategory("Farming")

    local categoryPages = {
        Farming = FarmPage,
        Combat = CombatPage,
        Progress = ProgressPage,
        ["Sea & Raids"] = SeaPage,
        Player = PlayerPage,
    }

    local state = {
        Alive = true,
        Built = false,
        Building = false,
        LegacyGui = nil,
        LegacyGuiWasEnabled = nil,
        Imported = 0,
        RuntimeItems = 0,
        LastError = nil,
    }

    local EngineSection = FarmPage:AddSection("Blox Fruits Functions", "Left")
    local RuntimeSection = FarmPage:AddSection("Function Status", "Right")
    local engineLabel = EngineSection:AddLabel("Blox functions: Scanning the running client...")
    local importLabel = RuntimeSection:AddLabel("Imported controls: 0")
    local actionLabel = RuntimeSection:AddLabel("Last action: Waiting")
    RuntimeSection:AddLabel("Available Blox Fruits controls are organized into VOR categories.")

    local function setLabelColor(label, color)
        if label then
            label.TextColor3 = color
        end
    end

    local function setEngineStatus(message, success)
        engineLabel.Text = "Engine: " .. tostring(message)
        setLabelColor(engineLabel, success == true and COLORS.success or (success == false and COLORS.error or COLORS.muted))
    end

    local function setActionStatus(message, success)
        actionLabel.Text = "Last action: " .. tostring(message)
        setLabelColor(actionLabel, success == true and COLORS.success or (success == false and COLORS.error or COLORS.muted))
    end

    local function slug(value)
        local text = string.lower(tostring(value or "control"))
        text = text:gsub("[^%w]+", "_"):gsub("_+", "_")
        text = text:gsub("^_+", ""):gsub("_+$", "")
        return text ~= "" and text or "control"
    end

    local function primitiveOption(value)
        local valueType = type(value)
        return valueType == "string" or valueType == "number" or valueType == "boolean"
    end

    local function extractOptions(options)
        local result = {}
        local seen = {}
        if type(options) ~= "table" then
            return result
        end

        for key, value in pairs(options) do
            local option
            if type(key) == "string" then
                option = key
            elseif primitiveOption(value) then
                option = tostring(value)
            else
                option = tostring(key)
            end
            if option ~= "" and not seen[option] then
                seen[option] = true
                table.insert(result, option)
            end
        end

        table.sort(result, function(left, right)
            return string.lower(tostring(left)) < string.lower(tostring(right))
        end)
        return result
    end

    local function findLegacyGui()
        local root = nil
        pcall(function()
            if type(gethui) == "function" then
                root = gethui()
            end
        end)
        root = root or game:GetService("CoreGui")

        for _, descendant in ipairs(root:GetDescendants()) do
            if (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
                and descendant.Text == LEGACY_WINDOW_TITLE then
                local current = descendant.Parent
                while current and current ~= root do
                    if current:IsA("LayerCollector") and current.Name ~= "RobloxGui" then
                        return current
                    end
                    current = current.Parent
                end
            end
        end
        return nil
    end

    local function getLegacyWindowName(item)
        local window = rawget(item, "Window")
        return type(window) == "table" and tostring(rawget(window, "Name") or "") or ""
    end

    local function readLegacyRecords()
        if type(getgc) ~= "function" then
            return nil, "This executor does not expose getgc"
        end

        local records = {}
        local seen = {}
        local runtimeItems = 0
        local ok, objects = pcall(getgc, true)
        if not ok or type(objects) ~= "table" then
            return nil, "Could not inspect the running control registry"
        end

        for _, item in ipairs(objects) do
            if type(item) == "table" and not seen[item] and getLegacyWindowName(item) == LEGACY_WINDOW_TITLE then
                seen[item] = true
                runtimeItems += 1

                local page = rawget(item, "Page")
                local section = rawget(item, "Section")
                local name = rawget(item, "Name")
                local flag = rawget(item, "Flag")
                local callback = rawget(item, "Callback")
                local setter = rawget(item, "Set")
                local getter = rawget(item, "Get")
                local pageName = type(page) == "table" and tostring(rawget(page, "Name") or "") or ""
                local sectionName = type(section) == "table" and tostring(rawget(section, "Name") or "") or ""

                if pageName ~= ""
                    and pageName ~= "Settings"
                    and sectionName ~= ""
                    and type(name) == "string"
                    and name ~= ""
                    and type(callback) == "function"
                    and type(setter) == "function"
                    and type(getter) == "function"
                    and not UI_ONLY_FLAGS[tostring(flag or name)] then
                    table.insert(records, {
                        Item = item,
                        Name = name,
                        Flag = tostring(flag or name),
                        Page = pageName,
                        Section = sectionName,
                        Tooltip = tostring(rawget(item, "Tooltip") or rawget(item, "Description") or ""),
                    })
                end
            end
        end

        table.sort(records, function(left, right)
            if left.Page ~= right.Page then
                return string.lower(left.Page) < string.lower(right.Page)
            end
            if left.Section ~= right.Section then
                return string.lower(left.Section) < string.lower(right.Section)
            end
            if left.Name ~= right.Name then
                return string.lower(left.Name) < string.lower(right.Name)
            end
            return left.Flag < right.Flag
        end)

        state.RuntimeItems = runtimeItems
        return records
    end

    local function chooseCategory(pageName, sectionName)
        local combined = string.lower(tostring(pageName) .. " " .. tostring(sectionName))
        local function includes(value)
            return string.find(combined, value, 1, true) ~= nil
        end

        if includes("sea event") or includes("raiding") or includes("law raid") or includes("dungeon")
            or includes("mirage") or includes("kitsune") or includes("leviathan") or includes("prehistoric") then
            return "Sea & Raids"
        end
        if includes("pvp") or includes("melee") or includes("use items") or includes("mob aura")
            or includes("exploit") then
            return "Combat"
        end
        if includes("sub") or includes("shop") or includes("teleport") or includes("stats")
            or includes("mastery") or includes("sword mastery") then
            return "Progress"
        end
        if includes("player state") or includes("visual") or includes("removal")
            or includes("miscellaneous") or includes("settings") then
            return "Player"
        end
        return "Farming"
    end

    local function cleanSectionTitle(pageName, sectionName)
        local title = tostring(sectionName)
        title = title:gsub("%s*%[Main Function%]", "")
        title = title:gsub("%s*%[Single%]", "")
        title = title:gsub("%s*%[Beta%]", "")
        title = title:gsub("%s+$", "")
        if pageName ~= "Main" and not string.find(string.lower(title), string.lower(pageName), 1, true) then
            title = tostring(pageName) .. " - " .. title
        end
        return title
    end

    local function legacyValue(item)
        local getter = rawget(item, "Get")
        if type(getter) == "function" then
            local ok, value = pcall(getter, item)
            if ok and value ~= nil then
                return value
            end
        end
        local value = rawget(item, "Value")
        if value == nil then
            value = rawget(item, "Default")
        end
        return value
    end

    local function applyLegacyValue(record, value)
        local item = record.Item
        local ok, result = pcall(function()
            item:Set(value)
            return true
        end)
        if not ok then
            local callback = rawget(item, "Callback")
            local fallbackOk, fallbackError = pcall(function()
                rawset(item, "Value", value)
                callback(value)
            end)
            if not fallbackOk then
                state.LastError = tostring(fallbackError or result)
                setActionStatus(record.Name .. " failed: " .. state.LastError, false)
                return false
            end
        end
        setActionStatus(record.Name .. " updated", true)
        return true
    end

    local function selectedSet(value)
        local result = {}
        if type(value) ~= "table" then
            return result
        end
        for key, entry in pairs(value) do
            if type(key) == "string" then
                if entry == true then
                    result[key] = true
                end
            elseif primitiveOption(entry) then
                result[tostring(entry)] = true
            end
        end
        return result
    end

    local function selectedArray(selection)
        local values = {}
        for option, enabled in pairs(selection) do
            if enabled then
                table.insert(values, option)
            end
        end
        table.sort(values, function(left, right)
            return string.lower(left) < string.lower(right)
        end)
        return values
    end

    local function formatColor(value)
        if typeof(value) ~= "Color3" then
            return tostring(value or "#FFFFFF")
        end
        return string.format(
            "#%02X%02X%02X",
            math.floor(value.R * 255 + 0.5),
            math.floor(value.G * 255 + 0.5),
            math.floor(value.B * 255 + 0.5)
        )
    end

    local function parseColor(text, fallback)
        local value = tostring(text or "")
        local hex = value:match("^#?(%x%x%x%x%x%x)$")
        if hex then
            return Color3.fromRGB(
                tonumber(hex:sub(1, 2), 16),
                tonumber(hex:sub(3, 4), 16),
                tonumber(hex:sub(5, 6), 16)
            )
        end
        local red, green, blue = value:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
        if red then
            return Color3.fromRGB(
                math.clamp(tonumber(red) or 255, 0, 255),
                math.clamp(tonumber(green) or 255, 0, 255),
                math.clamp(tonumber(blue) or 255, 0, 255)
            )
        end
        return fallback
    end

    local sectionCache = {}
    local sectionCounts = {
        Farming = 1,
        Combat = 0,
        Progress = 0,
        ["Sea & Raids"] = 0,
        Player = 0,
    }
    local persistentFlagCounts = {}

    local function getSection(record)
        local category = chooseCategory(record.Page, record.Section)
        local title = cleanSectionTitle(record.Page, record.Section)
        local cacheKey = category .. "\0" .. record.Page .. "\0" .. title
        if not sectionCache[cacheKey] then
            sectionCounts[category] = (sectionCounts[category] or 0) + 1
            local side = sectionCounts[category] % 2 == 1 and "Left" or "Right"
            sectionCache[cacheKey] = categoryPages[category]:AddSection(title, side)
        end
        return sectionCache[cacheKey], category
    end

    local function nextFlag(record, suffix)
        local parts = {
            "blox",
            slug(record.Page),
            slug(record.Section),
            slug(record.Flag),
        }
        if suffix ~= nil then
            table.insert(parts, slug(suffix))
        end
        local base = table.concat(parts, "_")
        persistentFlagCounts[base] = (persistentFlagCounts[base] or 0) + 1
        if persistentFlagCounts[base] > 1 then
            return base .. "_" .. tostring(persistentFlagCounts[base])
        end
        return base
    end

    local function addImportedControl(record)
        local section = getSection(record)
        local item = record.Item
        local current = legacyValue(item)
        local options = rawget(item, "Options")
        local tooltip = record.Tooltip

        if type(options) == "table" then
            local values = extractOptions(options)
            if rawget(item, "Multi") == true then
                local selection = selectedSet(current)
                section:AddLabel(record.Name .. " (multi-select)")
                for _, option in ipairs(values) do
                    local optionName = tostring(option)
                    section:AddToggle({
                        Name = optionName,
                        Description = "Selection for " .. record.Name,
                        Default = selection[optionName] == true,
                        Flag = nextFlag(record, optionName),
                        Callback = function(enabled)
                            selection[optionName] = enabled == true
                            applyLegacyValue(record, selectedArray(selection))
                        end,
                    })
                end
                return 1 + #values
            end

            local optionLookup = {}
            for _, value in ipairs(values) do
                optionLookup[tostring(value)] = true
            end
            local selected = primitiveOption(current) and tostring(current) or nil
            if not selected or not optionLookup[selected] then
                local default = rawget(item, "Default")
                selected = primitiveOption(default) and tostring(default) or nil
            end
            if selected and not optionLookup[selected] then
                selected = nil
            end

            section:AddDropdown({
                Name = record.Name,
                Options = values,
                Default = selected,
                Flag = nextFlag(record),
                Callback = function(value)
                    applyLegacyValue(record, value)
                end,
            })
            return 1
        end

        local minimum = rawget(item, "Min")
        local maximum = rawget(item, "Max")
        if type(minimum) == "number" and type(maximum) == "number" then
            local step = tonumber(rawget(item, "Decimals")) or 1
            if step <= 0 then
                step = 1
            end
            section:AddSlider({
                Name = record.Name,
                Min = minimum,
                Max = maximum,
                Step = step,
                Default = tonumber(current) or minimum,
                Flag = nextFlag(record),
                Callback = function(value)
                    applyLegacyValue(record, value)
                end,
            })
            return 1
        end

        if type(current) == "boolean" or type(rawget(item, "Default")) == "boolean" then
            section:AddToggle({
                Name = record.Name,
                Description = tooltip,
                Default = current == true,
                Flag = nextFlag(record),
                Callback = function(enabled)
                    applyLegacyValue(record, enabled)
                end,
            })
            return 1
        end

        local originalType = type(current)
        local isColor = typeof(current) == "Color3" or typeof(rawget(item, "Default")) == "Color3"
        local initialText = isColor and formatColor(current) or tostring(current or "")
        local inputControl
        local function submit(value)
            local converted = value
            if isColor then
                converted = parseColor(value, current)
            elseif originalType == "number" then
                converted = tonumber(value) or current
            end
            applyLegacyValue(record, converted)
        end
        inputControl = section:AddInput({
            Name = record.Name,
            Placeholder = isColor and "#RRGGBB or R,G,B" or "Enter value...",
            Default = initialText,
            Flag = nextFlag(record),
            Callback = submit,
        })

        -- VOR's regular input callback fires on FocusLost. Override Set as well
        -- so loading a saved VOR profile also reaches the adopted game callback.
        local baseSet = inputControl.Set
        function inputControl:Set(value, silent)
            baseSet(self, value)
            if not silent then
                submit(value)
            end
        end
        return 1
    end

    local function importLegacyControls(applyAutoLoadAfterImport)
        if state.Built then
            setEngineStatus("Blox functions ready", true)
            setActionStatus("All available controls are already imported", true)
            return true
        end
        if state.Building then
            return false
        end
        state.Building = true

        local records, readError = readLegacyRecords()
        if not records or #records == 0 then
            state.Building = false
            setEngineStatus(readError or "compatible Blox function engine not detected", false)
            importLabel.Text = "Imported controls: 0 | Start the compatible Blox engine, then import"
            return false
        end

        state.LegacyGui = findLegacyGui()
        if state.LegacyGui then
            pcall(function()
                state.LegacyGuiWasEnabled = state.LegacyGui.Enabled
                state.LegacyGui.Enabled = false
            end)
        end

        local imported = 0
        for _, record in ipairs(records) do
            local ok, amountOrError = pcall(addImportedControl, record)
            if ok then
                imported += tonumber(amountOrError) or 1
            else
                warn("[VOR Hub] Could not import Blox control " .. tostring(record.Name) .. ": " .. tostring(amountOrError))
            end
        end

        state.Imported = imported
        state.Built = imported > 0
        state.Building = false
        importLabel.Text = string.format(
            "Imported controls: %d VOR rows | %d live game controls | %d runtime items",
            imported,
            #records,
            state.RuntimeItems
        )
        setLabelColor(importLabel, state.Built and COLORS.success or COLORS.error)
        if state.Built then
            setEngineStatus("Blox functions ready", true)
            setActionStatus("Ready", true)
            Window:Notify("VOR Hub", "Blox Fruits functions imported into VOR", 4)

            -- The normal VOR autoload runs after an immediate module build. If
            -- The function engine appeared later during the retry window. Replay
            -- the saved profile now that
            -- the adopted controls finally exist.
            if applyAutoLoadAfterImport == true then
                task.defer(function()
                    if not state.Alive then
                        return
                    end
                    local enabled, profile = Window:GetAutoLoad()
                    if enabled and profile ~= "" then
                        local loaded, message = Window:LoadProfile(profile)
                        setActionStatus(message, loaded)
                    end
                end)
            end
        else
            setEngineStatus("no compatible game controls were imported", false)
        end

        if gui then
            gui:SetAttribute("BloxFruitsImportedControls", imported)
            gui:SetAttribute("BloxFruitsRuntimeItems", state.RuntimeItems)
            gui:SetAttribute("BloxFruitsLegacyBridgeReady", state.Built)
        end
        return state.Built
    end

    EngineSection:AddButton({
        Name = "Import Running Blox Functions",
        Description = "Finds the already-executed callbacks and imports them into VOR",
        Persist = false,
        Callback = function()
            importLegacyControls(true)
        end,
    })

    if gui then
        gui:SetAttribute("BloxFruitsModule", true)
        gui:SetAttribute("BloxFruitsUniverseId", 994732206)
        track(gui.Destroying:Connect(function()
            state.Alive = false
            if state.LegacyGui and state.LegacyGui.Parent and state.LegacyGuiWasEnabled ~= nil then
                pcall(function()
                    state.LegacyGui.Enabled = state.LegacyGuiWasEnabled
                end)
            end
        end))
    end

    if not importLegacyControls(false) then
        task.spawn(function()
            local started = os.clock()
            while state.Alive and not state.Built and os.clock() - started < 30 do
                task.wait(1)
                importLegacyControls(true)
            end
        end)
    end
end
