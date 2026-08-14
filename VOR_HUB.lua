-- VOR Hub compatibility bootstrap.
-- This follows one reviewed loader commit, never the writable main branch.
local LOADER_COMMIT = "4299e14464f3cce0a950155bb573fd1a7f87185d"
local url = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. LOADER_COMMIT .. "/loader.lua"
local source = game:HttpGet(url)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub loader compile failed: " .. tostring(compileError))
return chunk()
