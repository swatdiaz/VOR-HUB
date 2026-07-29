-- VOR Hub shared utilities. Game modules receive this table through context so
-- they do not need to capture hundreds of loader-scope locals.

return function(runtime)
    runtime = runtime or {}

    local services = {
        Players = game:GetService("Players"),
        HttpService = game:GetService("HttpService"),
        MarketplaceService = game:GetService("MarketplaceService"),
        TweenService = game:GetService("TweenService"),
        UserInputService = game:GetService("UserInputService"),
        RunService = game:GetService("RunService"),
        SoundService = game:GetService("SoundService"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        ContentProvider = game:GetService("ContentProvider"),
        GuiService = game:GetService("GuiService"),
        ContextActionService = game:GetService("ContextActionService"),
        TeleportService = game:GetService("TeleportService"),
        VirtualUser = game:GetService("VirtualUser"),
        Lighting = game:GetService("Lighting"),
        CollectionService = game:GetService("CollectionService"),
    }

    local utilities = {
        Services = services,
        LocalPlayer = services.Players.LocalPlayer,
        Connections = {},
        CleanupCallbacks = {},
        PauseCallbacks = {},
        ActivityListeners = {},
        NotificationListeners = {},
        Paused = false,
        StartedAt = os.clock(),
    }

    function utilities.Track(connection)
        if connection then
            table.insert(utilities.Connections, connection)
        end
        return connection
    end

    function utilities.OnCleanup(callback)
        if type(callback) == "function" then
            table.insert(utilities.CleanupCallbacks, callback)
        end
        return callback
    end

    function utilities.Cleanup()
        for index = #utilities.CleanupCallbacks, 1, -1 do
            pcall(utilities.CleanupCallbacks[index])
        end
        table.clear(utilities.CleanupCallbacks)

        for index = #utilities.Connections, 1, -1 do
            local connection = utilities.Connections[index]
            pcall(function()
                connection:Disconnect()
            end)
        end
        table.clear(utilities.Connections)
    end

    function utilities.OnPause(callback)
        if type(callback) == "function" then
            table.insert(utilities.PauseCallbacks, callback)
        end
        return callback
    end

    function utilities.SetPaused(paused, reason)
        utilities.Paused = paused == true
        for _, callback in ipairs(utilities.PauseCallbacks) do
            task.spawn(function()
                local ok, err = xpcall(function()
                    callback(utilities.Paused, reason)
                end, debug.traceback)
                if not ok then
                    warn("[VOR Hub] pause callback failed: " .. tostring(err))
                end
            end)
        end
        return utilities.Paused
    end

    function utilities.IsPaused()
        return utilities.Paused
    end

    function utilities.OnActivity(callback)
        if type(callback) == "function" then
            table.insert(utilities.ActivityListeners, callback)
        end
        return callback
    end

    function utilities.SetActivity(activity)
        activity = type(activity) == "table" and activity or {Message = tostring(activity)}
        activity.At = activity.At or os.clock()
        for _, callback in ipairs(utilities.ActivityListeners) do
            task.spawn(callback, activity)
        end
        return activity
    end

    function utilities.OnNotification(callback)
        if type(callback) == "function" then
            table.insert(utilities.NotificationListeners, callback)
        end
        return callback
    end

    function utilities.EmitNotification(entry)
        for _, callback in ipairs(utilities.NotificationListeners) do
            task.spawn(callback, entry)
        end
    end

    function utilities.SafeCall(label, callback, ...)
        local arguments = table.pack(...)
        local ok, result = xpcall(function()
            return callback(table.unpack(arguments, 1, arguments.n))
        end, debug.traceback)
        if not ok then
            warn(string.format("[VOR Hub] %s failed: %s", tostring(label), tostring(result)))
        end
        return ok, result
    end

    function utilities.ClampNumber(value, minimum, maximum, fallback)
        value = tonumber(value)
        if value == nil then
            value = tonumber(fallback) or minimum
        end
        return math.clamp(value, minimum, maximum)
    end

    function utilities.MakeFlag(value)
        return tostring(value or "control")
            :lower()
            :gsub("[^%w]+", "_")
            :gsub("^_+", "")
            :gsub("_+$", "")
    end

    function utilities.SanitizeProfileName(value)
        local name = tostring(value or "")
            :gsub("[^%w%-%_ ]", "")
            :gsub("^%s+", "")
            :gsub("%s+$", "")
        if #name > 48 then
            name = name:sub(1, 48)
        end
        return name
    end

    function utilities.FileApiAvailable()
        return type(isfolder) == "function"
            and type(makefolder) == "function"
            and type(isfile) == "function"
            and type(readfile) == "function"
            and type(writefile) == "function"
    end

    function utilities.EnsureFolder(path)
        if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
            return false
        end
        local current = ""
        for part in tostring(path):gmatch("[^/\\]+") do
            current = current == "" and part or (current .. "/" .. part)
            if not isfolder(current) then
                makefolder(current)
            end
        end
        return true
    end

    function utilities.CopyText(value)
        local copy = setclipboard or toclipboard
        if type(copy) ~= "function" then
            return false
        end
        return pcall(copy, tostring(value or ""))
    end

    function utilities.GetGuiParent()
        local player = utilities.LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            return playerGui
        end
        local ok, coreGui = pcall(game.GetService, game, "CoreGui")
        return ok and coreGui or nil
    end

    return utilities
end
