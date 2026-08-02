-- VOR Hub compatibility bootstrap.
-- This follows one reviewed loader commit, never the writable main branch.
local LOADER_COMMIT = "a9ffc246e9de97b55f416b2a202a0af8fd865961"
local url = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. LOADER_COMMIT .. "/loader.lua"
local source = game:HttpGet(url)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub loader compile failed: " .. tostring(compileError))
return chunk()