-- Dragon Ball Legendary Powers - VOR owner administration bridge
-- Install this Script in ServerScriptService from Roblox Studio.
-- Every privileged request is validated here; the client is never trusted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ADMIN_USER_IDS = {
    [433080653] = true, -- lTomiii / experience creator
    [33876608] = true, -- HEISON12 / owner test account
}

local VALID_STATS = {
    PL = true,
    phys = true,
    ki = true,
    agi = true,
    def = true,
    physEX = true,
    kiEX = true,
    agiEX = true,
    defEX = true,
    ssj = true,
    kaio = true,
    mult = true,
    zeni = true,
}

local VALID_UNLOCKS = {
    kame = true,
    korin = true,
    kami = true,
    kai = true,
    shenron = true,
    grav = true,
    potara = true,
    god = true,
    nova = true,
    highMax = true,
    weightedGi = true,
    isLeg = true,
    hasGodded = true,
}

local SAFE_UNLOCK_ALL = {
    "kame",
    "korin",
    "kami",
    "kai",
    "shenron",
    "grav",
    "potara",
    "god",
    "nova",
    "highMax",
    "weightedGi",
    "isLeg",
    "hasGodded",
}

local remote = ReplicatedStorage:FindFirstChild("VOROwnerAdmin")
if remote and not remote:IsA("RemoteFunction") then
    error("ReplicatedStorage.VOROwnerAdmin exists but is not a RemoteFunction")
end
if not remote then
    remote = Instance.new("RemoteFunction")
    remote.Name = "VOROwnerAdmin"
    remote.Parent = ReplicatedStorage
end

local rateState = {}

local function reply(success, message, data)
    return {
        Success = success == true,
        Message = tostring(message),
        Data = data,
    }
end

local function authorized(player)
    return player ~= nil and ADMIN_USER_IDS[player.UserId] == true
end

local function rateAllowed(player)
    local now = os.clock()
    local state = rateState[player]
    if not state or now - state.StartedAt >= 1 then
        rateState[player] = {StartedAt = now, Count = 1}
        return true
    end
    state.Count += 1
    return state.Count <= 20
end

local function targetPlayer(userId)
    userId = tonumber(userId)
    if not userId then
        return nil
    end
    return Players:GetPlayerByUserId(userId)
end

local function statsModel(player)
    return player and player:FindFirstChild("statsModel")
end

local function characterState(player)
    local character = player and player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
    return character, humanoid, root
end

local function finiteNumber(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return nil
    end
    return value
end

local function clampStat(value)
    return math.clamp(value, 0, 1000000000000000)
end

local function audit(actor, operation, target, detail)
    print(string.format(
        "[VOROwnerAdmin] %s (%d) -> %s -> %s (%d) %s",
        actor.Name,
        actor.UserId,
        tostring(operation),
        target and target.Name or "none",
        target and target.UserId or 0,
        tostring(detail or "")
    ))
end

remote.OnServerInvoke = function(actor, request)
    if not authorized(actor) then
        warn(string.format("[VOROwnerAdmin] denied %s (%d)", actor.Name, actor.UserId))
        return reply(false, "Owner authorization required")
    end
    if not rateAllowed(actor) then
        return reply(false, "Admin request rate limit reached")
    end
    if type(request) ~= "table" then
        return reply(false, "Malformed request")
    end

    local operation = tostring(request.Operation or "")
    if operation == "Ping" then
        return reply(true, "Owner bridge ready", {
            PlaceId = game.PlaceId,
            UniverseId = game.GameId,
        })
    end

    local target = targetPlayer(request.TargetUserId)
    if not target then
        return reply(false, "Target player is no longer in the server")
    end

    if operation == "SetStat" or operation == "AddStat" then
        local statName = tostring(request.Stat or "")
        if not VALID_STATS[statName] then
            return reply(false, "Unknown or protected stat")
        end
        local model = statsModel(target)
        local valueObject = model and model:FindFirstChild(statName)
        if not valueObject or not valueObject:IsA("NumberValue") then
            return reply(false, "Stat is unavailable on the target")
        end
        local amount = finiteNumber(request.Value)
        if not amount then
            return reply(false, "Amount must be a finite number")
        end
        if operation == "SetStat" then
            valueObject.Value = clampStat(amount)
        else
            valueObject.Value = clampStat(valueObject.Value + amount)
        end
        audit(actor, operation, target, statName .. "=" .. tostring(valueObject.Value))
        return reply(true, statName .. " is now " .. tostring(valueObject.Value), valueObject.Value)
    end

    if operation == "SetUnlock" then
        local unlockName = tostring(request.Unlock or "")
        if not VALID_UNLOCKS[unlockName] then
            return reply(false, "Unknown or protected unlock")
        end
        local model = statsModel(target)
        local valueObject = model and model:FindFirstChild(unlockName)
        if not valueObject or not valueObject:IsA("BoolValue") then
            return reply(false, "Unlock is unavailable on the target")
        end
        valueObject.Value = request.Value == true
        audit(actor, operation, target, unlockName .. "=" .. tostring(valueObject.Value))
        return reply(true, unlockName .. " set to " .. tostring(valueObject.Value))
    end

    if operation == "UnlockAll" then
        local model = statsModel(target)
        if not model then
            return reply(false, "Target stats are unavailable")
        end
        local changed = 0
        for _, unlockName in ipairs(SAFE_UNLOCK_ALL) do
            local valueObject = model:FindFirstChild(unlockName)
            if valueObject and valueObject:IsA("BoolValue") then
                valueObject.Value = true
                changed += 1
            end
        end
        audit(actor, operation, target, tostring(changed) .. " flags")
        return reply(true, "Enabled " .. tostring(changed) .. " safe unlock flags")
    end

    if operation == "Heal" then
        local _, humanoid = characterState(target)
        if not humanoid then
            return reply(false, "Target character is unavailable")
        end
        humanoid.Health = humanoid.MaxHealth
        audit(actor, operation, target)
        return reply(true, "Player healed")
    end

    if operation == "RefillEnergy" then
        local playerGui = target:FindFirstChildOfClass("PlayerGui")
        local statsGui = playerGui and playerGui:FindFirstChild("stats")
        local energy = statsGui and statsGui:FindFirstChild("energy")
        if not energy or not energy:IsA("NumberValue") then
            return reply(false, "Target energy value is unavailable")
        end
        energy.Value = math.max(100, energy.Value)
        audit(actor, operation, target)
        return reply(true, "Energy refilled")
    end

    if operation == "Freeze" or operation == "Unfreeze" then
        local _, _, root = characterState(target)
        if not root then
            return reply(false, "Target character is unavailable")
        end
        root.Anchored = operation == "Freeze"
        audit(actor, operation, target)
        return reply(true, operation == "Freeze" and "Player frozen" or "Player unfrozen")
    end

    if operation == "Bring" then
        local _, _, actorRoot = characterState(actor)
        local _, _, targetRoot = characterState(target)
        if not actorRoot or not targetRoot then
            return reply(false, "One of the characters is unavailable")
        end
        targetRoot.CFrame = actorRoot.CFrame * CFrame.new(3, 0, 0)
        targetRoot.AssemblyLinearVelocity = Vector3.zero
        audit(actor, operation, target)
        return reply(true, "Player brought to owner")
    end

    if operation == "Goto" then
        local _, _, actorRoot = characterState(actor)
        local _, _, targetRoot = characterState(target)
        if not actorRoot or not targetRoot then
            return reply(false, "One of the characters is unavailable")
        end
        actorRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
        actorRoot.AssemblyLinearVelocity = Vector3.zero
        audit(actor, operation, target)
        return reply(true, "Teleported to player")
    end

    if operation == "Kick" then
        if target == actor then
            return reply(false, "Owner self-kick is blocked")
        end
        local reason = tostring(request.Reason or "Removed by the owner")
        reason = string.sub(reason, 1, 180)
        audit(actor, operation, target, reason)
        target:Kick(reason)
        return reply(true, "Player removed")
    end

    return reply(false, "Unknown admin operation")
end

Players.PlayerRemoving:Connect(function(player)
    rateState[player] = nil
end)

print("[VOROwnerAdmin] Dragon Ball Legendary Powers owner bridge ready")
