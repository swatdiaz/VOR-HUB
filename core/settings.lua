-- VOR Hub shared settings and immutable game registry.
-- This module is deliberately data-heavy and behavior-light so it compiles in
-- its own register scope before the UI or a game integration is loaded.

return function(runtime)
    runtime = runtime or {}

    local placeId = tonumber(runtime.PlaceId) or game.PlaceId
    local universeId = tonumber(runtime.UniverseId) or game.GameId

    local supportedGames = {
        Revive = {
            Key = "Revive",
            DisplayName = "+1 DMG Per Revive",
            UniverseId = 10171934713,
            RootPlaceId = 110806816173057,
            PlaceIds = {
                [110806816173057] = true,
            },
            Module = "games/revive.lua",
        },
        MyPark = {
            Key = "MyPark",
            DisplayName = "NEW MyPark",
            UniverseId = 4931927012,
            RootPlaceId = 14386691987,
            PlaceIds = {
                [14386691987] = true,
                [124914780116925] = true,
            },
            Module = "games/mypark.lua",
        },
        AnimeExpeditions = {
            Key = "AnimeExpeditions",
            DisplayName = "Anime Expeditions",
            UniverseId = 7613921865,
            RootPlaceId = 84515722934860,
            PlaceIds = {
                [84515722934860] = true,
            },
            Module = "games/anime_expeditions.lua",
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
            },
            Module = "games/blox_fruits.lua",
        },
        BloxFruitsDungeons = {
            Key = "BloxFruitsDungeons",
            DisplayName = "Blox Fruits Dungeons",
            UniverseId = 994732206,
            RootPlaceId = 73902483975735,
            PlaceIds = {
                [73902483975735] = true,
            },
            Module = "games/blox_fruits_dungeons.lua",
        },
    }

    local activeGame = nil
    if placeId == 73902483975735 then
        activeGame = supportedGames.BloxFruitsDungeons
    else
        for _, gameInfo in pairs(supportedGames) do
            if gameInfo.Key ~= "BloxFruitsDungeons"
                and (universeId == gameInfo.UniverseId or gameInfo.PlaceIds[placeId] == true) then
                activeGame = gameInfo
                break
            end
        end
    end

    local settings = {
        GuiName = "VORHub",
        Title = "VOR HUB",
        Version = "3.0.0",
        Creator = "Vor",
        Discord = "discord.gg/w7gXUUZEp",
        DiscordInviteURL = "https://discord.gg/w7gXUUZEp",
        AccessKeyHash = 1961304013,
        RememberKey = true,
        ToggleKey = Enum.KeyCode.RightControl,
        IntroEnabled = true,
        IntroDuration = 3.25,
        InterfaceSoundsEnabled = true,
        ToggleClickSoundId = "rbxasset://sounds/volume_slider.ogg",
        ToggleClickVolume = 0.24,
        ToggleOnPlaybackSpeed = 1.18,
        ToggleOffPlaybackSpeed = 0.88,
        UIAnimationRate = 240,
        MinimizedStyleDefault = "Void Crest",
        MinimizedCircleSize = 58,
        ThemeIntensity = "Luxury",
        ReducedMotion = false,
        HighContrast = false,
        UIScale = 1,
        TextScale = 1,
        ActiveGame = activeGame,
        SupportedGames = supportedGames,
        IsBloxFruits = activeGame ~= nil
            and (activeGame.Key == "BloxFruits" or activeGame.Key == "BloxFruitsDungeons"),
        IsDungeon = activeGame ~= nil and activeGame.Key == "BloxFruitsDungeons",
    }

    settings.ConfigScopeId = settings.IsBloxFruits and universeId or placeId
    settings.ConfigRoot = "VORHub/Configs/" .. tostring(settings.ConfigScopeId)
    settings.ProfileFolder = settings.ConfigRoot .. "/Profiles"
    settings.AutoLoadFile = settings.ConfigRoot .. "/autoload.json"
    settings.AccessFile = "VORHub/Configs/access.json"

    settings.COLORS = {
        shell = Color3.fromRGB(8, 6, 13),
        rail = Color3.fromRGB(10, 7, 17),
        surface = Color3.fromRGB(15, 11, 24),
        surfaceRaised = Color3.fromRGB(21, 15, 34),
        surfaceHover = Color3.fromRGB(29, 20, 47),
        control = Color3.fromRGB(18, 13, 29),
        controlHover = Color3.fromRGB(31, 22, 49),
        border = Color3.fromRGB(67, 53, 88),
        borderBright = Color3.fromRGB(125, 88, 176),
        text = Color3.fromRGB(244, 241, 249),
        muted = Color3.fromRGB(185, 177, 200),
        dim = Color3.fromRGB(132, 119, 153),
        accent = Color3.fromRGB(126, 55, 255),
        accentBright = Color3.fromRGB(188, 133, 255),
        accentDark = Color3.fromRGB(70, 27, 132),
        success = Color3.fromRGB(74, 225, 144),
        warning = Color3.fromRGB(245, 186, 73),
        error = Color3.fromRGB(255, 93, 126),
        white = Color3.fromRGB(255, 255, 255),
        black = Color3.fromRGB(0, 0, 0),
        toggleOff = Color3.fromRGB(54, 45, 67),
    }

    settings.CATEGORY_DECALS = {
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

    -- Profile migrations are aliases, never destructive renames. Existing
    -- saved flags continue to load while the shared controller becomes the
    -- canonical runtime state for every Blox Fruits farming consumer.
    settings.FlagAliases = {
        blox_farm_position_height = {
            "blox_mob_aura_height",
            "blox_farm_height",
        },
        blox_farm_position_orbit = {
            "blox_mob_aura_orbit",
        },
        blox_farm_position_orbit_radius = {
            "blox_mob_aura_orbit_radius",
        },
        blox_farm_position_orbit_speed = {
            "blox_mob_aura_orbit_speed",
        },
        blox_farm_position_random_square = {
            "blox_mob_aura_random_square",
        },
        blox_farm_position_square_size = {
            "blox_mob_aura_square_size",
        },
        blox_farm_position_square_interval = {
            "blox_mob_aura_square_interval",
        },
    }

    return settings
end
