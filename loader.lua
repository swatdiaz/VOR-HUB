-- VOR Hub audited-release loader.
-- This deliberately does not follow `main`. Updating the repository cannot
-- change what this loader executes until its pinned release is reviewed and
-- this file is intentionally updated.

local auditedRelease = "90cfa60d2bbc8f9ab7ff577fe39af2e4a70a0328"
local scriptUrl = "https://raw.githubusercontent.com/swatdiaz/VOR-HUB/"
    .. auditedRelease .. "/VOR_HUB.lua"
local source = game:HttpGet(scriptUrl)
local chunk, compileError = loadstring(source)
assert(chunk, "VOR Hub compile failed: " .. tostring(compileError))

return chunk()
