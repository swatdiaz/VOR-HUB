-- VOR Hub compatibility bootstrap.
-- This follows one reviewed loader commit, never the writable main branch.
local LOADER_COMMIT = "d27004005dea649886c64b9166c041c9440373c0"
local url = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. LOADER_COMMIT .. "/loader.lua"
local source = game:HttpGet(url)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub loader compile failed: " .. tostring(compileError))
return chunk()