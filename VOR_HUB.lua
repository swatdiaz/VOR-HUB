-- VOR Hub compatibility bootstrap.
-- This follows one reviewed loader commit, never the writable main branch.
local LOADER_COMMIT = "3e1551275247cdb4e9ae49f291de1fca93489023"
local url = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. LOADER_COMMIT .. "/loader.lua"
local source = game:HttpGet(url)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub loader compile failed: " .. tostring(compileError))
return chunk()