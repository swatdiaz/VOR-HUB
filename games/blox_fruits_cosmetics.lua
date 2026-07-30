-- Client-only Blox Fruits cosmetics. No inventory, damage, or real Tool is changed.
return function(context)
    local Window = assert(context.Window, "cosmetics module requires Window")
    local gui = assert(context.Gui, "cosmetics module requires Gui")
    local track = assert(context.Track, "cosmetics module requires Track")
    local page = assert(context.Page, "cosmetics module requires Page")
    local helpers = assert(context.Helpers, "cosmetics module requires Helpers")
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    local KNOWN_WEAPONS = {
        "Acidum Rifle", "Bazooka", "Bizarre Rifle", "Bisento", "Buddy Sword",
        "Cannon", "Canvander", "Cursed Dual Katana", "Cutlass", "Dark Blade",
        "Dark Dagger", "Dragon Trident", "Dragonheart", "Dragonstorm", "Dual Katana",
        "Dual-Headed Blade", "Flintlock", "Fox Lamp", "Gravity Cane", "Hallow Scythe",
        "Iron Mace", "Jitte", "Kabucha", "Katana", "Koko", "Longsword",
        "Midnight Blade", "Musket", "Pipe", "Pole (1st Form)", "Pole (2nd Form)",
        "Refined Flintlock", "Refined Slingshot", "Rengoku", "Saber", "Saddi",
        "Serpent Bow", "Shark Anchor", "Shark Saw", "Shisui", "Slingshot",
        "Soul Cane", "Soul Guitar", "Spikey Trident", "Trident", "Triple Katana",
        "True Triple Katana", "Tushita", "Twin Hooks", "Wando", "Warden's Sword", "Yama",
    }

    local state = {
        Enabled = false,
        Selected = "Dark Blade",
        Offset = Vector3.zero,
        Rotation = Vector3.zero,
        Scale = 1,
        Glow = false,
        OriginalParts = setmetatable({}, {__mode = "k"}),
        Visual = nil,
        RealTool = nil,
        SourcePath = nil,
        LastApply = 0,
    }

    local statusLabel
    local weaponDropdown

    local function normalize(value)
        return string.lower(tostring(value or "")):gsub("[^%w]", "")
    end

    local function notify(message)
        Window:Notify("Visual Weapon", tostring(message), 3)
    end

    local function equippedTool()
        local character = helpers.Character()
        if not character then
            return nil
        end
        for _, object in ipairs(character:GetChildren()) do
            if object:IsA("Tool") then
                return object
            end
        end
        return nil
    end

    local function equipVisualBaseTool()
        local current = equippedTool()
        if current then
            return current
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        local body = helpers.Humanoid and helpers.Humanoid() or nil
        if not backpack or not body then
            return nil
        end
        local fallback
        for _, object in ipairs(backpack:GetChildren()) do
            if object:IsA("Tool") then
                local tooltip = string.lower(tostring(object.ToolTip or ""))
                if tooltip == "sword" then
                    fallback = object
                    break
                elseif not fallback and (tooltip == "melee" or tooltip == "gun" or tooltip == "blox fruit") then
                    fallback = object
                end
            end
        end
        if fallback then
            pcall(function()
                body:EquipTool(fallback)
            end)
            task.wait()
        end
        return equippedTool()
    end

    local function weaponBody(tool)
        if not tool then
            return nil
        end
        if tool:IsA("BasePart") or tool:FindFirstChildWhichIsA("BasePart", true) then
            return tool
        end
        for _, pointerName in ipairs({
            "LocalEquippedWeaponPointer", "ServerEquippedWeaponPointer",
            "LocalUnequippedWeaponPointer", "ServerUnequippedWeaponPointer",
        }) do
            for _, pointer in ipairs(tool:GetChildren()) do
                if pointer.Name == pointerName and pointer:IsA("ObjectValue")
                    and pointer.Value and pointer.Value.Parent
                    and pointer.Value:FindFirstChildWhichIsA("BasePart", true) then
                    return pointer.Value
                end
            end
        end
        local character = helpers.Character()
        local equipped = character and character:FindFirstChild("EquippedWeapon")
        if equipped and equipped:FindFirstChildWhichIsA("BasePart", true) then
            return equipped
        end
        return tool
    end

    local function toolParts(tool)
        local result = {}
        local body = weaponBody(tool)
        if body then
            if body:IsA("BasePart") then
                table.insert(result, body)
            end
            for _, object in ipairs(body:GetDescendants()) do
                if object:IsA("BasePart") then
                    table.insert(result, object)
                end
            end
        end
        return result
    end

    local function visibleWeaponOptions()
        local result, seen = {}, {}
        local function add(name)
            name = tostring(name or "")
            local key = normalize(name)
            if name ~= "" and key ~= "" and not seen[key] then
                seen[key] = true
                table.insert(result, name)
            end
        end
        for _, name in ipairs(KNOWN_WEAPONS) do
            add(name)
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        for _, container in ipairs({helpers.Character(), backpack}) do
            if container then
                for _, object in ipairs(container:GetChildren()) do
                    if object:IsA("Tool") then add(object.Name) end
                end
            end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            if character then
                for _, object in ipairs(character:GetChildren()) do
                    if object:IsA("Tool") then add(object.Name) end
                end
            end
        end
        table.sort(result)
        return result
    end

    local function basePartCount(object)
        local count = 0
        if object:IsA("BasePart") then count = 1 end
        for _, descendant in ipairs(object:GetDescendants()) do
            if descendant:IsA("BasePart") then count += 1 end
        end
        return count
    end

    local function candidateScore(object, selectedKey)
        if normalize(object.Name) ~= selectedKey then
            return -math.huge
        end
        local count = basePartCount(object)
        if count < 1 or count > 80 then
            return -math.huge
        end
        local path = string.lower(object:GetFullName())
        local score = 1000 - count
        if object:IsA("Tool") then score += 300 end
        if object:IsA("Model") then score += 200 end
        if path:find("equipped", 1, true) then score += 100 end
        if path:find("anim", 1, true) then score += 40 end
        if path:find("sound", 1, true) then score -= 400 end
        return score
    end

    local function visualSource()
        local selectedKey = normalize(state.Selected)
        local best, bestScore
        for _, player in ipairs(Players:GetPlayers()) do
            local character = player.Character
            if character then
                for _, object in ipairs(character:GetChildren()) do
                    local score = candidateScore(object, selectedKey)
                    if not bestScore or score > bestScore then
                        best, bestScore = object, score
                    end
                end
            end
        end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, object in ipairs(backpack:GetChildren()) do
                local score = candidateScore(object, selectedKey)
                if not bestScore or score > bestScore then
                    best, bestScore = object, score
                end
            end
        end
        for _, object in ipairs(ReplicatedStorage:GetDescendants()) do
            if object:IsA("Model") or object:IsA("Tool") or object:IsA("Folder") then
                local score = candidateScore(object, selectedKey)
                if not bestScore or score > bestScore then
                    best, bestScore = object, score
                end
            end
        end
        return best
    end

    local function restore()
        if state.Visual and state.Visual.Parent then
            state.Visual:Destroy()
        end
        state.Visual = nil
        for part, transparency in pairs(state.OriginalParts) do
            if part and part.Parent then
                part.LocalTransparencyModifier = transparency
            end
        end
        table.clear(state.OriginalParts)
        state.RealTool = nil
        state.SourcePath = nil
        gui:SetAttribute("BloxVisualWeaponActive", false)
    end

    local function prepareClone(source)
        local wrapper = Instance.new("Model")
        wrapper.Name = "VORVisualWeapon_" .. state.Selected
        local clone = source:Clone()
        clone.Parent = wrapper
        for _, object in ipairs(wrapper:GetDescendants()) do
            if object:IsA("LuaSourceContainer") or object:IsA("Sound") then
                object:Destroy()
            elseif object:IsA("BasePart") then
                object.Anchored = false
                object.CanCollide = false
                object.CanQuery = false
                object.CanTouch = false
                object.Massless = true
                object.LocalTransparencyModifier = 0
                if state.Glow then
                    object.Material = Enum.Material.Neon
                    object.Color = Color3.fromRGB(166, 71, 255)
                end
            end
        end
        if state.Scale ~= 1 then
            pcall(function() wrapper:ScaleTo(state.Scale) end)
        end
        return wrapper
    end

    local function apply()
        restore()
        if not state.Enabled then
            statusLabel.Text = "Visual swap: Off"
            return false
        end
        local realTool = equipVisualBaseTool()
        if not realTool then
            statusLabel.Text = "Visual swap: No usable combat Tool found"
            return false
        end
        local realBody = weaponBody(realTool)
        local realParts = toolParts(realTool)
        local realHandle = realBody and (realBody:FindFirstChild("Handle", true)
            or realBody:FindFirstChild("Main", true)
            or realBody:FindFirstChild("Blade", true)) or realParts[1]
        if not realHandle then
            statusLabel.Text = "Visual swap: Equipped Tool has no visible handle"
            return false
        end
        local source = visualSource()
        if not source then
            statusLabel.Text = state.Selected .. " model is not streamed; refresh after it appears"
            return false
        end
        local wrapper = prepareClone(source)
        local visualParts = toolParts(wrapper)
        local visualHandle = wrapper:FindFirstChild("Handle", true)
            or wrapper:FindFirstChild("Hold", true)
            or visualParts[1]
        if not visualHandle then
            wrapper:Destroy()
            statusLabel.Text = state.Selected .. " source has no usable model parts"
            return false
        end
        wrapper.Parent = helpers.Character()
        local transform = CFrame.new(state.Offset)
            * CFrame.Angles(
                math.rad(state.Rotation.X),
                math.rad(state.Rotation.Y),
                math.rad(state.Rotation.Z)
            )
        local sourceFrame = visualHandle.CFrame
        -- Snapshot every relative transform before touching the cloned
        -- assembly. Moving one still-welded part used to drag the remaining
        -- parts, so each later relative CFrame was calculated from corrupted
        -- coordinates and the visual exploded into enormous white blocks.
        local relativeFrames = {}
        for _, part in ipairs(visualParts) do
            relativeFrames[part] = sourceFrame:ToObjectSpace(part.CFrame)
        end
        for _, object in ipairs(wrapper:GetDescendants()) do
            if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
                object:Destroy()
            end
        end
        for _, part in ipairs(visualParts) do
            part.CFrame = realHandle.CFrame * transform * relativeFrames[part]
            local weld = Instance.new("WeldConstraint")
            weld.Name = "VORVisualWeld"
            weld.Part0 = realHandle
            weld.Part1 = part
            weld.Parent = part
        end
        for _, part in ipairs(realParts) do
            state.OriginalParts[part] = part.LocalTransparencyModifier
            part.LocalTransparencyModifier = 1
        end
        state.Visual = wrapper
        state.RealTool = realTool
        state.SourcePath = source:GetFullName()
        statusLabel.Text = string.format("Visual swap: %s over %s", state.Selected, realTool.Name)
        gui:SetAttribute("BloxVisualWeaponActive", true)
        gui:SetAttribute("BloxVisualWeaponName", state.Selected)
        gui:SetAttribute("BloxVisualWeaponSource", state.SourcePath)
        return true
    end

    local section = page:AddSection("Visual Weapon Swap", "Left")
    section:AddLabel("Cosmetic only: your real Tool, damage, mastery, and abilities never change.")
    statusLabel = section:AddLabel("Visual swap: Off")
    weaponDropdown = section:AddDropdown({
        Name = "Visual Weapon",
        Flag = "blox_visual_weapon_name",
        Options = visibleWeaponOptions(),
        Default = "Dark Blade",
        Callback = function(value)
            state.Selected = tostring(value or "Dark Blade")
            if state.Enabled then task.defer(apply) end
        end,
    })
    section:AddButton({
        Name = "Refresh Weapon Models",
        Callback = function()
            weaponDropdown:SetOptions(visibleWeaponOptions(), true)
            local ok = apply()
            notify(ok and (state.Selected .. " visual loaded") or statusLabel.Text)
        end,
    })
    section:AddToggle({
        Name = "Enable Visual Weapon Swap",
        Flag = "blox_visual_weapon_enabled",
        Default = false,
        Callback = function(enabled)
            state.Enabled = enabled == true
            task.defer(apply)
        end,
    })
    section:AddToggle({
        Name = "VOR Void Glow",
        Flag = "blox_visual_weapon_glow",
        Default = false,
        Callback = function(enabled)
            state.Glow = enabled == true
            if state.Enabled then task.defer(apply) end
        end,
    })
    section:AddSlider({
        Name = "Visual Scale", Flag = "blox_visual_weapon_scale",
        Min = 0.4, Max = 2.5, Step = 0.05, Default = 1,
        Callback = function(value)
            state.Scale = tonumber(value) or 1
            if state.Enabled then task.defer(apply) end
        end,
    })

    local offsets = page:AddSection("Weapon Visual Alignment", "Left")
    local function addAxis(name, flag, axis, minimum, maximum)
        offsets:AddSlider({
            Name = name, Flag = flag, Min = minimum, Max = maximum, Step = 0.1, Default = 0,
            Callback = function(value)
                if axis == "X" then state.Offset = Vector3.new(value, state.Offset.Y, state.Offset.Z)
                elseif axis == "Y" then state.Offset = Vector3.new(state.Offset.X, value, state.Offset.Z)
                else state.Offset = Vector3.new(state.Offset.X, state.Offset.Y, value) end
                if state.Enabled then task.defer(apply) end
            end,
        })
    end
    local function addRotation(name, flag, axis)
        offsets:AddSlider({
            Name = name, Flag = flag, Min = -180, Max = 180, Step = 5, Default = 0,
            Callback = function(value)
                if axis == "X" then state.Rotation = Vector3.new(value, state.Rotation.Y, state.Rotation.Z)
                elseif axis == "Y" then state.Rotation = Vector3.new(state.Rotation.X, value, state.Rotation.Z)
                else state.Rotation = Vector3.new(state.Rotation.X, state.Rotation.Y, value) end
                if state.Enabled then task.defer(apply) end
            end,
        })
    end
    addAxis("Offset X", "blox_visual_weapon_offset_x", "X", -5, 5)
    addAxis("Offset Y", "blox_visual_weapon_offset_y", "Y", -5, 5)
    addAxis("Offset Z", "blox_visual_weapon_offset_z", "Z", -5, 5)
    addRotation("Pitch", "blox_visual_weapon_pitch", "X")
    addRotation("Yaw", "blox_visual_weapon_yaw", "Y")
    addRotation("Roll", "blox_visual_weapon_roll", "Z")

    track(RunService.Heartbeat:Connect(function()
        if not state.Enabled or os.clock() - state.LastApply < 0.5 then
            return
        end
        state.LastApply = os.clock()
        local current = equippedTool()
        if current ~= state.RealTool or not state.Visual or not state.Visual.Parent then
            apply()
        end
    end))
    track(gui.Destroying:Connect(restore))

    gui:SetAttribute("BloxVisualWeaponModule", true)
    gui:SetAttribute("BloxVisualWeaponModuleVersion", "2")
end
