-- VOR Hub - Bid for Anime game module
-- Uses only the experience's normal, server-validated gameplay endpoints.

return function(context)
    local Window = assert(context.Window, "Bid for Anime: Window is required")
    local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Bid for Anime: category builder is required")
    local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
    local COLORS = context.Colors or context.COLORS or {}
    local track = context.Track or function(connection)
        return connection
    end
    local gui = context.Gui

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    local HomePage, addHomeCategory, selectHomeCategory = createCategoryHomePage()
    local FarmPage = addHomeCategory("Auto Farm", 1, CATEGORY_DECALS.Overnight)
    local EconomyPage = addHomeCategory("Economy", 2, CATEGORY_DECALS.Progress)
    local UpgradePage = addHomeCategory("Upgrades", 3, CATEGORY_DECALS.Weapons)
    local RewardPage = addHomeCategory("Rewards", 4, CATEGORY_DECALS.Visuals)
    local StatusPage = addHomeCategory("Status", 5, CATEGORY_DECALS.Player)
    selectHomeCategory("Auto Farm")

    local MainFarmSection = FarmPage:AddSection("Full Auto Farm", "Left")
    local MatchSection = FarmPage:AddSection("Match Controller", "Left")
    local BidSection = FarmPage:AddSection("Auction Strategy", "Right")
    local FarmStatusSection = FarmPage:AddSection("Farm Status", "Right")
    local CashSection = EconomyPage:AddSection("Cash Collection", "Left")
    local InventorySection = EconomyPage:AddSection("Inventory", "Right")
    local SellSection = EconomyPage:AddSection("Protected Auto Sell", "Right")
    local LuckSection = UpgradePage:AddSection("Luck Upgrades", "Left")
    local RebirthSection = UpgradePage:AddSection("Rebirth", "Right")
    local SpinSection = RewardPage:AddSection("Spin Wheel", "Left")
    local ClaimSection = RewardPage:AddSection("Reward Claims", "Right")
    local AccountSection = StatusPage:AddSection("Account Snapshot", "Left")
    local EndpointSection = StatusPage:AddSection("Adapter", "Right")

    local state = {
        Alive = true,
        FullAuto = false,
        AutoJoin = false,
        MatchMode = "Play With AI",
        JoinInterval = 4,
        AutoBid = false,
        BidStrategy = "High",
        CashReserve = 0,
        MaxBidPercent = 100,
        PassWhenBlocked = true,
        AutoCollectCash = false,
        CollectInterval = 3,
        AutoEquipBest = false,
        AutoSellRarity = false,
        SellRarity = "Common",
        AutoLuck = false,
        LuckAmount = 100,
        AutoRebirth = false,
        AutoSpin = false,
        AutoRewards = false,
        AntiAfk = true,
        LastJoin = 0,
        LastCollect = 0,
        LastEquip = 0,
        LastSell = 0,
        LastLuck = 0,
        LastRebirth = 0,
        LastReward = 0,
        LastClaimButtons = 0,
        LastPromptKey = nil,
        SpinBusy = false,
        SpinStarted = 0,
        BidCount = 0,
        Status = "Initializing adapter...",
        LastError = nil,
    }

    local statusLabel = FarmStatusSection:AddLabel("Status: Initializing...")
    local matchLabel = FarmStatusSection:AddLabel("Match: Reading...")
    local bidLabel = FarmStatusSection:AddLabel("Bids submitted: 0")
    local moneyLabel = AccountSection:AddLabel("Money: Reading...")
    local winsLabel = AccountSection:AddLabel("Wins: Reading...")
    local rebirthLabel = AccountSection:AddLabel("Rebirth: Reading...")
    local streakLabel = AccountSection:AddLabel("Streak: Reading...")
    local spinLabel = SpinSection:AddLabel("Spins: Reading...")
    local adapterLabel = EndpointSection:AddLabel("Adapter: Resolving endpoints...")
    EndpointSection:AddLabel("All actions are normal server-credited gameplay requests.")

    local function setStatus(message, success)
        state.Status = tostring(message)
        statusLabel.Text = "Status: " .. state.Status
        statusLabel.TextColor3 = success == false and (COLORS.error or Color3.fromRGB(255, 95, 125))
            or (success == true and (COLORS.success or Color3.fromRGB(85, 255, 170))
                or (COLORS.muted or Color3.fromRGB(190, 180, 210)))
    end

    local function setError(message)
        state.LastError = tostring(message)
        setStatus(state.LastError, false)
    end

    local BrainrotsThings = ReplicatedStorage:FindFirstChild("BrainrotsThings")
    local Misc = BrainrotsThings and BrainrotsThings:FindFirstChild("Misc")
    local Events = Misc and Misc:FindFirstChild("Events")
    local TableEvents = Events and Events:FindFirstChild("Tables")
    local PlayerEvents = Events and Events:FindFirstChild("Player")
    local SpinEvents = ReplicatedStorage:FindFirstChild("SpinWheelRemotes")

    local endpoints = {
        QuickJoin = PlayerEvents and PlayerEvents:FindFirstChild("QuickJoin"),
        PlayWithAI = TableEvents and TableEvents:FindFirstChild("PlayWithAIRequest"),
        AuctionPrompt = TableEvents and TableEvents:FindFirstChild("AuctionPrompt"),
        BidSubmitted = TableEvents and TableEvents:FindFirstChild("BidSubmitted"),
        MatchEnded = TableEvents and TableEvents:FindFirstChild("MatchEnded"),
        MatchResolved = TableEvents and TableEvents:FindFirstChild("MatchResolved"),
        TableReset = TableEvents and TableEvents:FindFirstChild("TableReset"),
        CollectCash = PlayerEvents and PlayerEvents:FindFirstChild("CollectCash"),
        EquipBest = PlayerEvents and PlayerEvents:FindFirstChild("EquipBestBrainrots"),
        SellAll = PlayerEvents and PlayerEvents:FindFirstChild("SellAll"),
        PurchaseLuck = PlayerEvents and PlayerEvents:FindFirstChild("PurchaseLuckUpgrade"),
        Rebirth = PlayerEvents and PlayerEvents:FindFirstChild("RebirthRequest"),
        ClaimOffline = PlayerEvents and PlayerEvents:FindFirstChild("ClaimOfflineEarnings"),
        ClaimGroup = PlayerEvents and PlayerEvents:FindFirstChild("ClaimGroupReward"),
        Spin = SpinEvents and SpinEvents:FindFirstChild("SpinRequest"),
        SpinResult = SpinEvents and SpinEvents:FindFirstChild("SpinResult"),
        SpinError = SpinEvents and SpinEvents:FindFirstChild("SpinError"),
    }

    local requiredEndpointNames = {
        "QuickJoin",
        "PlayWithAI",
        "AuctionPrompt",
        "BidSubmitted",
        "CollectCash",
        "EquipBest",
        "PurchaseLuck",
        "Rebirth",
    }
    local missingEndpoints = {}
    for _, name in ipairs(requiredEndpointNames) do
        if not endpoints[name] then
            missingEndpoints[#missingEndpoints + 1] = name
        end
    end
    if #missingEndpoints > 0 then
        adapterLabel.Text = "Adapter: Missing " .. table.concat(missingEndpoints, ", ")
        setError("Game endpoints are incomplete")
    else
        adapterLabel.Text = "Adapter: Native auction and economy endpoints ready"
        setStatus("Bid for Anime support ready", true)
    end

    local PriceTables
    local priceModule = Misc and Misc:FindFirstChild("PriceTables")
    if priceModule then
        local ok, result = pcall(require, priceModule)
        if ok and type(result) == "table" then
            PriceTables = result
        end
    end
    local rebirthCosts = PriceTables and PriceTables.REBIRTH_COSTS or {}

    local function getStat(name)
        local leaderstats = LocalPlayer and LocalPlayer:FindFirstChild("leaderstats")
        local value = leaderstats and leaderstats:FindFirstChild(name)
        return value and tonumber(value.Value) or 0
    end

    local function formatNumber(value)
        value = tonumber(value) or 0
        local absolute = math.abs(value)
        if absolute >= 1e15 then
            return string.format("%.2fQ", value / 1e15)
        elseif absolute >= 1e12 then
            return string.format("%.2fT", value / 1e12)
        elseif absolute >= 1e9 then
            return string.format("%.2fB", value / 1e9)
        elseif absolute >= 1e6 then
            return string.format("%.2fM", value / 1e6)
        elseif absolute >= 1e3 then
            return string.format("%.2fK", value / 1e3)
        end
        return tostring(math.floor(value))
    end

    local function fire(endpoint, ...)
        if not endpoint then
            return false, "endpoint unavailable"
        end
        local arguments = table.pack(...)
        local ok, result = pcall(function()
            endpoint:FireServer(table.unpack(arguments, 1, arguments.n))
        end)
        return ok, result
    end

    local function inMatch()
        return LocalPlayer:GetAttribute("BidInDuel") == true
            or LocalPlayer:GetAttribute("ClientInDuel") == true
    end

    local function requestMatch(force)
        local now = os.clock()
        if not force and now - state.LastJoin < state.JoinInterval then
            return false, "join cooldown"
        end
        if inMatch() and not force then
            return false, "already in match"
        end
        state.LastJoin = now
        if state.MatchMode == "Play With AI" and endpoints.PlayWithAI then
            local ok, result = fire(endpoints.PlayWithAI)
            if ok then
                setStatus("Requested an AI match", true)
            end
            return ok, result
        end
        local ok, result = fire(endpoints.QuickJoin)
        if ok then
            setStatus("Requested quick join", true)
        end
        return ok, result
    end

    local strategyOrders = {
        Cheapest = {1, 2, 3, 4},
        Medium = {2, 1, 3, 4},
        High = {3, 2, 4, 1},
        Extreme = {4, 3, 2, 1},
    }

    local function selectBidOption(prompt)
        local options = type(prompt) == "table" and prompt.options or nil
        if type(options) ~= "table" then
            return nil
        end
        local balance = getStat("Money")
        local reserve = math.max(0, tonumber(state.CashReserve) or 0)
        local percentCap = balance * math.clamp((tonumber(state.MaxBidPercent) or 100) / 100, 0.01, 1)
        local spendCap = math.min(percentCap, math.max(0, balance - reserve))
        local order = strategyOrders[state.BidStrategy] or strategyOrders.High
        for _, index in ipairs(order) do
            local option = options[index]
            local amount = option and tonumber(option.amount)
            if option and option.canAfford == true and amount and amount <= spendCap then
                return option
            end
        end
        return nil
    end

    local function submitAuctionChoice(prompt)
        if type(prompt) ~= "table" or prompt.active ~= true then
            return false, "not our turn"
        end
        local promptKey = tostring(prompt.auctionId) .. ":" .. tostring(prompt.promptId)
        if state.LastPromptKey == promptKey then
            return false, "prompt already handled"
        end
        state.LastPromptKey = promptKey

        local option = selectBidOption(prompt)
        local payload
        if option then
            payload = {
                action = "bid",
                auctionId = prompt.auctionId,
                promptId = prompt.promptId,
                amount = option.amount,
            }
        elseif prompt.canPass == true and state.PassWhenBlocked then
            payload = {
                action = "pass",
                auctionId = prompt.auctionId,
                promptId = prompt.promptId,
            }
        else
            return false, "no affordable bid"
        end

        local ok, result = fire(endpoints.BidSubmitted, payload)
        if ok then
            state.BidCount = state.BidCount + 1
            bidLabel.Text = "Bids submitted: " .. tostring(state.BidCount)
            setStatus(payload.action == "bid"
                and ("Bid " .. formatNumber(payload.amount))
                or "Passed unaffordable auction", true)
        end
        return ok, result
    end

    local function collectCash()
        local ok, result = fire(endpoints.CollectCash)
        if ok then
            state.LastCollect = os.clock()
        end
        return ok, result
    end

    local function equipBest()
        local ok, result = fire(endpoints.EquipBest)
        if ok then
            state.LastEquip = os.clock()
        end
        return ok, result
    end

    local function sellSelectedRarity()
        local ok, result = fire(endpoints.SellAll, state.SellRarity)
        if ok then
            state.LastSell = os.clock()
        end
        return ok, result
    end

    local function buyLuck()
        local ok, result = fire(endpoints.PurchaseLuck, tostring(state.LuckAmount))
        if ok then
            state.LastLuck = os.clock()
        end
        return ok, result
    end

    local function requestRebirth(force)
        local rebirth = getStat("Rebirth")
        local nextCost = tonumber(rebirthCosts[rebirth + 1])
        if not force and (not nextCost or getStat("Money") < nextCost) then
            return false, "rebirth not affordable"
        end
        local ok, result = fire(endpoints.Rebirth)
        if ok then
            state.LastRebirth = os.clock()
            setStatus("Rebirth requested", true)
        end
        return ok, result
    end

    local function spinOnce(force)
        if state.SpinBusy and os.clock() - state.SpinStarted < 50 then
            return false, "spin already running"
        end
        local rounds = tonumber(LocalPlayer:GetAttribute("SpinRounds")) or 0
        if not force and rounds <= 0 then
            return false, "no spins available"
        end
        local ok, result = fire(endpoints.Spin)
        if ok then
            state.SpinBusy = true
            state.SpinStarted = os.clock()
            setStatus("Spin requested", true)
        end
        return ok, result
    end

    local function isVisible(guiObject)
        local node = guiObject
        while node and node ~= LocalPlayer.PlayerGui do
            if node:IsA("GuiObject") and node.Visible == false then
                return false
            end
            if node:IsA("LayerCollector") and node.Enabled == false then
                return false
            end
            node = node.Parent
        end
        return true
    end

    local function activateClaimButtons()
        if type(firesignal) ~= "function" then
            return 0
        end
        local count = 0
        for _, descendant in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
            if descendant:IsA("GuiButton") and descendant.Active and isVisible(descendant) then
                local normalized = string.lower(descendant.Name):gsub("%s+", "")
                if normalized == "claimbutton" or normalized == "claimcash" then
                    pcall(firesignal, descendant.Activated)
                    count = count + 1
                end
            end
            if count >= 12 then
                break
            end
        end
        return count
    end

    local function claimRewards()
        fire(endpoints.ClaimOffline)
        fire(endpoints.ClaimGroup)
        local clicked = activateClaimButtons()
        state.LastReward = os.clock()
        state.LastClaimButtons = clicked
        setStatus("Reward sweep completed (" .. tostring(clicked) .. " buttons)", true)
    end

    if endpoints.AuctionPrompt then
        track(endpoints.AuctionPrompt.OnClientEvent:Connect(function(prompt)
            if state.Alive and (state.FullAuto or state.AutoBid) then
                task.defer(submitAuctionChoice, prompt)
            end
        end))
    end

    local function scheduleNextMatch()
        state.LastPromptKey = nil
        if state.Alive and (state.FullAuto or state.AutoJoin) then
            task.delay(1.5, function()
                if state.Alive and (state.FullAuto or state.AutoJoin) and not inMatch() then
                    requestMatch(false)
                end
            end)
        end
    end

    for _, endpoint in ipairs({endpoints.MatchEnded, endpoints.MatchResolved, endpoints.TableReset}) do
        if endpoint then
            track(endpoint.OnClientEvent:Connect(scheduleNextMatch))
        end
    end

    if endpoints.SpinResult then
        track(endpoints.SpinResult.OnClientEvent:Connect(function()
            state.SpinBusy = false
            setStatus("Spin credited", true)
        end))
    end
    if endpoints.SpinError then
        track(endpoints.SpinError.OnClientEvent:Connect(function(message)
            state.SpinBusy = false
            if message then
                setError("Spin: " .. tostring(message))
            end
        end))
    end

    track(LocalPlayer.Idled:Connect(function()
        if state.Alive and state.AntiAfk then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                task.wait(0.1)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        end
    end))

    MainFarmSection:AddToggle({
        Name = "Full Auto Farm",
        Description = "AI matches, bidding, cash, best equip, luck, rebirth, spins, and rewards",
        Flag = "bid_anime_full_auto",
        Default = false,
        Callback = function(enabled)
            state.FullAuto = enabled
            state.LastJoin = 0
            if enabled then
                requestMatch(false)
            else
                setStatus("Full Auto disabled", true)
            end
        end,
    })
    MainFarmSection:AddToggle({
        Name = "Anti AFK",
        Flag = "bid_anime_anti_afk",
        Default = true,
        Callback = function(enabled)
            state.AntiAfk = enabled
        end,
    })
    MainFarmSection:AddLabel("Full Auto deliberately excludes auto sell so it cannot erase valuable inventory.")

    MatchSection:AddToggle({
        Name = "Auto Join Matches",
        Flag = "bid_anime_auto_join",
        Default = false,
        Callback = function(enabled)
            state.AutoJoin = enabled
            state.LastJoin = 0
            if enabled then
                requestMatch(false)
            end
        end,
    })
    MatchSection:AddDropdown({
        Name = "Match Mode",
        Flag = "bid_anime_match_mode",
        Options = {"Play With AI", "Quick Join"},
        Default = "Play With AI",
        Callback = function(value)
            state.MatchMode = value or "Play With AI"
        end,
    })
    MatchSection:AddSlider({
        Name = "Join Retry Delay",
        Flag = "bid_anime_join_interval",
        Min = 2,
        Max = 15,
        Step = 0.5,
        Default = 4,
        Callback = function(value)
            state.JoinInterval = tonumber(value) or 4
        end,
    })
    MatchSection:AddButton({
        Name = "Join Now",
        Callback = function()
            requestMatch(true)
        end,
    })

    BidSection:AddToggle({
        Name = "Auto Bid",
        Flag = "bid_anime_auto_bid",
        Default = false,
        Callback = function(enabled)
            state.AutoBid = enabled
        end,
    })
    BidSection:AddDropdown({
        Name = "Bid Strategy",
        Flag = "bid_anime_bid_strategy",
        Options = {"Cheapest", "Medium", "High", "Extreme"},
        Default = "High",
        Callback = function(value)
            state.BidStrategy = value or "High"
        end,
    })
    BidSection:AddInput({
        Name = "Cash Reserve",
        Flag = "bid_anime_cash_reserve",
        Placeholder = "Money never spent on bids",
        Default = "0",
        Callback = function(value)
            state.CashReserve = math.max(0, tonumber(value) or 0)
        end,
    })
    BidSection:AddSlider({
        Name = "Maximum Balance Per Bid",
        Flag = "bid_anime_max_bid_percent",
        Min = 1,
        Max = 100,
        Step = 1,
        Default = 100,
        Suffix = "%",
        Callback = function(value)
            state.MaxBidPercent = tonumber(value) or 100
        end,
    })
    BidSection:AddToggle({
        Name = "Pass When Bid Is Blocked",
        Flag = "bid_anime_pass_blocked",
        Default = true,
        Callback = function(enabled)
            state.PassWhenBlocked = enabled
        end,
    })

    CashSection:AddToggle({
        Name = "Auto Collect Cash",
        Flag = "bid_anime_auto_collect",
        Default = false,
        Callback = function(enabled)
            state.AutoCollectCash = enabled
        end,
    })
    CashSection:AddSlider({
        Name = "Collect Interval",
        Flag = "bid_anime_collect_interval",
        Min = 1,
        Max = 15,
        Step = 0.5,
        Default = 3,
        Callback = function(value)
            state.CollectInterval = tonumber(value) or 3
        end,
    })
    CashSection:AddButton({
        Name = "Collect Cash Now",
        Callback = collectCash,
    })

    InventorySection:AddToggle({
        Name = "Auto Equip Best",
        Flag = "bid_anime_auto_equip_best",
        Default = false,
        Callback = function(enabled)
            state.AutoEquipBest = enabled
        end,
    })
    InventorySection:AddButton({
        Name = "Equip Best Now",
        Callback = equipBest,
    })

    SellSection:AddDropdown({
        Name = "Sell Rarity",
        Flag = "bid_anime_sell_rarity",
        Options = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"},
        Default = "Common",
        Callback = function(value)
            state.SellRarity = value or "Common"
        end,
    })
    SellSection:AddToggle({
        Name = "Auto Sell Selected Rarity",
        Description = "Never enabled by Full Auto",
        Flag = "bid_anime_auto_sell_rarity",
        Default = false,
        Callback = function(enabled)
            state.AutoSellRarity = enabled
        end,
    })
    SellSection:AddButton({
        Name = "Sell Selected Rarity Once",
        Callback = sellSelectedRarity,
    })

    LuckSection:AddToggle({
        Name = "Auto Buy Luck",
        Flag = "bid_anime_auto_luck",
        Default = false,
        Callback = function(enabled)
            state.AutoLuck = enabled
        end,
    })
    LuckSection:AddDropdown({
        Name = "Luck Purchase Amount",
        Flag = "bid_anime_luck_amount",
        Options = {"10", "50", "100"},
        Default = "100",
        Callback = function(value)
            state.LuckAmount = tonumber(value) or 100
        end,
    })
    LuckSection:AddButton({
        Name = "Buy Luck Once",
        Callback = buyLuck,
    })

    RebirthSection:AddToggle({
        Name = "Auto Rebirth When Affordable",
        Flag = "bid_anime_auto_rebirth",
        Default = false,
        Callback = function(enabled)
            state.AutoRebirth = enabled
        end,
    })
    RebirthSection:AddButton({
        Name = "Request Rebirth Now",
        Callback = function()
            local ok, message = requestRebirth(true)
            if not ok then
                setError(message)
            end
        end,
    })

    SpinSection:AddToggle({
        Name = "Auto Use Free Spins",
        Flag = "bid_anime_auto_spin",
        Default = false,
        Callback = function(enabled)
            state.AutoSpin = enabled
        end,
    })
    SpinSection:AddButton({
        Name = "Spin Once",
        Callback = function()
            local ok, message = spinOnce(true)
            if not ok then
                setError(message)
            end
        end,
    })

    ClaimSection:AddToggle({
        Name = "Auto Claim Rewards",
        Description = "Offline earnings, group reward, daily, and playtime claim buttons",
        Flag = "bid_anime_auto_rewards",
        Default = false,
        Callback = function(enabled)
            state.AutoRewards = enabled
        end,
    })
    ClaimSection:AddButton({
        Name = "Claim Available Rewards",
        Callback = claimRewards,
    })

    task.spawn(function()
        while state.Alive do
            local now = os.clock()
            local fullAuto = state.FullAuto

            if (fullAuto or state.AutoJoin) and not inMatch() and now - state.LastJoin >= state.JoinInterval then
                requestMatch(false)
            end
            if (fullAuto or state.AutoCollectCash) and now - state.LastCollect >= state.CollectInterval then
                collectCash()
            end
            if (fullAuto or state.AutoEquipBest) and now - state.LastEquip >= 12 then
                equipBest()
            end
            if state.AutoSellRarity and not inMatch() and now - state.LastSell >= 25 then
                sellSelectedRarity()
            end
            if (fullAuto or state.AutoLuck) and not inMatch() and now - state.LastLuck >= 3 then
                buyLuck()
            end
            if (fullAuto or state.AutoRebirth) and not inMatch() and now - state.LastRebirth >= 4 then
                requestRebirth(false)
            end
            if (fullAuto or state.AutoSpin) and not inMatch() and now - state.SpinStarted >= 2 then
                spinOnce(false)
            end
            if (fullAuto or state.AutoRewards) and not inMatch() and now - state.LastReward >= 30 then
                claimRewards()
            end

            local money = getStat("Money")
            local wins = getStat("Wins")
            local rebirth = getStat("Rebirth")
            local streak = getStat("Streak")
            local nextCost = tonumber(rebirthCosts[rebirth + 1])
            moneyLabel.Text = "Money: " .. formatNumber(money)
            winsLabel.Text = "Wins: " .. formatNumber(wins)
            rebirthLabel.Text = "Rebirth: " .. formatNumber(rebirth)
                .. (nextCost and (" | Next: " .. formatNumber(nextCost)) or " | MAX")
            streakLabel.Text = "Streak: " .. formatNumber(streak)
            spinLabel.Text = "Spins: " .. tostring(tonumber(LocalPlayer:GetAttribute("SpinRounds")) or 0)
            matchLabel.Text = inMatch()
                and "Match: Active duel"
                or ("Match: Lobby | " .. state.MatchMode)

            if gui then
                pcall(function()
                    gui:SetAttribute("BidForAnimeMoney", money)
                    gui:SetAttribute("BidForAnimeWins", wins)
                    gui:SetAttribute("BidForAnimeRebirth", rebirth)
                    gui:SetAttribute("BidForAnimeStreak", streak)
                    gui:SetAttribute("BidForAnimeInMatch", inMatch())
                    gui:SetAttribute("BidForAnimeStatus", state.Status)
                end)
            end
            task.wait(0.5)
        end
    end)

    if gui then
        pcall(function()
            gui:SetAttribute("BidForAnimeAdapter", true)
        end)
        track(gui.Destroying:Connect(function()
            state.Alive = false
        end))
    end
end
