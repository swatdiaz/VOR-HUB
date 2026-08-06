-- VOR Hub compatibility bootstrap.
-- This follows one reviewed loader commit, never the writable main branch.
local LOADER_COMMIT = "7025050e656aff3ad20c4da37b93d06ae46bfb98"
local url = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. LOADER_COMMIT .. "/loader.lua"
local source = game:HttpGet(url)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub loader compile failed: " .. tostring(compileError))
return chunk()