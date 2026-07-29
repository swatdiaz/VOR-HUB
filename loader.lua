-- VOR Hub immutable modular loader.
-- Release tooling replaces the placeholder with the audited module commit.

local COMMIT = "400999c37f88b2203d2bace0709532754204b070"
local REPOSITORY = "swatdiaz/VOR-HUB"

local function sourceUrl(path)
    return "https://raw.githubusercontent.com/" .. REPOSITORY .. "/" .. COMMIT .. "/" .. path
end

local function loadModule(path)
    local ok, result = xpcall(function()
        local source = game:HttpGet(sourceUrl(path))
        local chunk, compileError = loadstring(source)
        assert(chunk, "Compile failed for " .. path .. ": " .. tostring(compileError))
        return chunk()
    end, debug.traceback)
    return ok, result
end

local function runBuilder(path, builder, context)
    return xpcall(function()
        assert(type(builder) == "function", path .. " must return one builder function")
        return builder(context)
    end, debug.traceback)
end

local function emergencyError(path, message)
    warn("[VOR Hub] " .. tostring(path) .. " failed:\n" .. tostring(message))
    local player = game:GetService("Players").LocalPlayer
    local parent = player and player:FindFirstChildOfClass("PlayerGui")
    if not parent then
        return
    end
    local old = parent:FindFirstChild("VORHubEmergencyError")
    if old then
        old:Destroy()
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "VORHubEmergencyError"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10000
    gui.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromOffset(620, 280)
    label.Position = UDim2.new(0.5, -310, 0.5, -140)
    label.BackgroundColor3 = Color3.fromRGB(17, 8, 27)
    label.TextColor3 = Color3.fromRGB(245, 238, 255)
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Font = Enum.Font.Code
    label.TextSize = 15
    label.Text = "VOR HUB BUILD ERROR\n\n" .. tostring(path) .. "\n\n" .. tostring(message)
    label.Parent = gui
end

assert(COMMIT:match("^[0-9a-f]+$") and #COMMIT == 40, "VOR Hub loader has no valid audited module commit")

local runtime = {
    Commit = COMMIT,
    Repository = REPOSITORY,
    PlaceId = game.PlaceId,
    UniverseId = game.GameId,
}

local ok, settingsBuilder = loadModule("core/settings.lua")
if not ok then
    emergencyError("core/settings.lua", settingsBuilder)
    return
end
ok, runtime.SETTINGS = runBuilder("core/settings.lua", settingsBuilder, runtime)
if not ok then
    emergencyError("core/settings.lua", runtime.SETTINGS)
    return
end

local utilitiesBuilder
ok, utilitiesBuilder = loadModule("core/utilities.lua")
if not ok then
    emergencyError("core/utilities.lua", utilitiesBuilder)
    return
end
ok, runtime.Utilities = runBuilder("core/utilities.lua", utilitiesBuilder, runtime)
if not ok then
    emergencyError("core/utilities.lua", runtime.Utilities)
    return
end

local uiBuilder
ok, uiBuilder = loadModule("core/ui.lua")
if not ok then
    emergencyError("core/ui.lua", uiBuilder)
    return
end
ok, runtime.UI = runBuilder("core/ui.lua", uiBuilder, runtime)
if not ok then
    emergencyError("core/ui.lua", runtime.UI)
    return
end

local context = {
    Window = runtime.UI.Window,
    SETTINGS = runtime.SETTINGS,
    COLORS = runtime.UI.Colors,
    Colors = runtime.UI.Colors,
    Gui = runtime.UI.Gui,
    Track = runtime.UI.Track,
    Services = runtime.Utilities.Services,
    Utilities = runtime.Utilities,
    CreateCategoryHomePage = runtime.UI.CreateCategoryHomePage,
    CategoryDecals = runtime.UI.CategoryDecals,
    CATEGORY_DECALS = runtime.UI.CategoryDecals,
    Create = runtime.UI.Create,
    AddCorner = runtime.UI.AddCorner,
    AddStroke = runtime.UI.AddStroke,
    PlayToggleClick = runtime.UI.PlayToggleClick,
    ReadableStatusColor = runtime.UI.ReadableStatusColor,
    Runtime = runtime,
}

local function installCore(path)
    local loaded, builder = loadModule(path)
    if not loaded then
        context.Window:ShowBuildError(path, builder)
        return false
    end
    local built, result = runBuilder(path, builder, context)
    if not built then
        context.Window:ShowBuildError(path, result)
        return false
    end
    return true
end

local profilesReady = installCore("core/profiles.lua")
local accessReady = installCore("core/access.lua")
local gameInfo = runtime.SETTINGS.ActiveGame

if gameInfo then
    context.Window:SetModuleIdentity(gameInfo.DisplayName, runtime.SETTINGS.Version, true)
    local loaded, gameBuilder = loadModule(gameInfo.Module)
    if not loaded then
        context.Window:ShowBuildError(gameInfo.Module, gameBuilder)
    else
        local built, buildError = runBuilder(gameInfo.Module, gameBuilder, context)
        if not built then
            context.Window:ShowBuildError(gameInfo.Module, buildError)
        else
            context.Window:SetContextStatus(gameInfo.DisplayName .. "  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢  module ready")
            runtime.Utilities.SetActivity({Kind = "Module", Message = gameInfo.Module .. " loaded"})
        end
    end
else
    context.Window:SetModuleIdentity("Unsupported Game", runtime.SETTINGS.Version, false)
    local page = context.Window:AddPage("Unsupported")
    local section = page:AddSection("Game not supported", "Left")
    section:AddLabel("Game not supported")
    section:AddLabel("PlaceId: " .. tostring(game.PlaceId))
    section:AddLabel("UniverseId: " .. tostring(game.GameId))
    local info = page:AddSection("What now?", "Right")
    info:AddParagraph({
        Title = "Unsupported experience",
        Content = "VOR loaded safely, but no game module matches this place. The loader did not download any game code.",
    })
    context.Window:SelectPage("Unsupported")
end

local pendingAutoLoad
if profilesReady and context.Window.BuildGlobalSettingsPage then
    local built, result = xpcall(function()
        return context.Window:BuildGlobalSettingsPage()
    end, debug.traceback)
    if built then
        pendingAutoLoad = result
    else
        context.Window:ShowBuildError("core/profiles.lua:BuildGlobalSettingsPage", result)
    end
end

if gameInfo and context.Window.BuildHomeDashboard then
    local built, result = xpcall(function()
        return context.Window:BuildHomeDashboard()
    end, debug.traceback)
    if not built then
        context.Window:ShowBuildError("core/ui.lua:BuildHomeDashboard", result)
    end
end

context.Window:SetPanelBackground(runtime.SETTINGS.DefaultPanelBackground)
context.Window:SetMinimizeStyle(runtime.SETTINGS.MinimizedStyleDefault)
context.Window:SetThemeIntensity(runtime.SETTINGS.ThemeIntensity)

if pendingAutoLoad then
    task.defer(function()
        local loaded, message = context.Window:LoadProfile(pendingAutoLoad)
        context.Window:Notify("Auto Load", message, loaded and 3 or 6)
    end)
end

context.Gui:SetAttribute("VORModuleCommit", COMMIT)
context.Gui:SetAttribute("VORModulePath", gameInfo and gameInfo.Module or "unsupported")
context.Gui:SetAttribute("VORModularBuild", true)

if accessReady and context.Window.RequestKeyAccess then
    context.Window:RequestKeyAccess(function()
        context.Window:PlayIntro()
    end)
else
    context.Window.Main.Visible = true
end

return context.Window
