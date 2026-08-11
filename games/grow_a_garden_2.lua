--[[
	VOR HUB | Grow a Garden 2 | v11
	Live-audited against place version 250.
	Catalogs are discovered from the current game modules and stock folders.
	Networking remains deferred so the interface always builds first.
]]

return function(context)
local Window = assert(context.Window, "Grow a Garden 2: Window is required")
local createCategoryHomePage = assert(context.CreateCategoryHomePage, "Grow a Garden 2: category builder is required")
local CATEGORY_DECALS = context.CategoryDecals or context.CATEGORY_DECALS or {}
local COLORS = context.Colors or context.COLORS or {}
local track = context.Track or function(connection) return connection end
local gui = context.Gui

--========================== SERVICES ==========================--
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local LP                = Players.LocalPlayer

--========================== KILL OLD ==========================--
if _G.__VOR_GAG2 and _G.__VOR_GAG2.Destroy then pcall(_G.__VOR_GAG2.Destroy) end
-- Clean up an older NightFall build during migration.
if _G.__NF and _G.__NF.Destroy then pcall(_G.__NF.Destroy) end
local SELF = {}; _G.__VOR_GAG2 = SELF
local ALIVE = true
SELF.Destroy = function() ALIVE = false end

--========================== HELPERS ==========================--
local function getParentGui()
	local ok, g
	ok, g = pcall(function() return gethui() end);           if ok and g then return g end
	ok, g = pcall(function() return game:GetService("CoreGui") end); if ok and g then return g end
	return LP:WaitForChild("PlayerGui", 10)
end

local function tw(inst, props, dur)
	TweenService:Create(inst, TweenInfo.new(dur or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function mkCorner(p, r)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 10); c.Parent = p; return c
end
local function mkStroke(p, col, th)
	local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(44,46,58)
	s.Thickness = th or 1; s.Transparency = 0.45; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function mkPad(p, t, r, b, l)
	local u = Instance.new("UIPadding")
	u.PaddingTop    = UDim.new(0, t)
	u.PaddingBottom = UDim.new(0, b or t)
	u.PaddingLeft   = UDim.new(0, l or r or t)
	u.PaddingRight  = UDim.new(0, r or t)
	u.Parent = p
end

--========================== COLOURS ==========================--
local C = {
	bg         = Color3.fromRGB(13,14,18),
	sidebar    = Color3.fromRGB(16,17,23),
	surface    = Color3.fromRGB(22,24,31),
	surfaceHov = Color3.fromRGB(28,30,40),
	elevated   = Color3.fromRGB(34,36,46),
	border     = Color3.fromRGB(44,46,58),
	accent     = Color3.fromRGB(99,102,241),
	accentHov  = Color3.fromRGB(129,140,248),
	success    = Color3.fromRGB(52,211,153),
	danger     = Color3.fromRGB(239,68,68),
	txt        = Color3.fromRGB(236,237,242),
	sub        = Color3.fromRGB(128,132,150),
	off        = Color3.fromRGB(55,58,72),
	Common     = Color3.fromRGB(180,180,180),
	Uncommon   = Color3.fromRGB(80,210,100),
	Rare       = Color3.fromRGB(80,160,240),
	Epic       = Color3.fromRGB(180,90,255),
	Legendary  = Color3.fromRGB(255,175,40),
	Mythic     = Color3.fromRGB(255,80,130),
	Super      = Color3.fromRGB(120,230,255),
	Godly      = Color3.fromRGB(255,96,72),
	Divine     = Color3.fromRGB(255,225,96),
	Secret     = Color3.fromRGB(255,255,255),
	Prismatic  = Color3.fromRGB(120,255,220),
}

--========================== PERSISTENT SETTINGS ==========================--
-- Preserve settings from NightFall once, then use the VOR HUB namespace.
if not _G.VOR_GAG2_Settings then _G.VOR_GAG2_Settings = _G.NFSettings or {} end
local S = _G.VOR_GAG2_Settings
local function sg(k,d) if S[k]==nil then S[k]=d end; return S[k] end
local function ss(k,v) S[k]=v end

--========================== STATE ==========================--
local F = {}
local FKEYS = {"harvest","prioHarvest","plant","sell","antiSteal","eventSeeds","buySeeds","buyGears","buyPets"}
local FDEFAULT = {}
for _,k in ipairs(FKEYS) do FDEFAULT[k]=false; F[k]=sg(k,false) end
-- Retire offensive stealing/scouting settings from older builds.
S.steal=nil; S.prioSteal=nil; S.autoScan=nil

local SHOP = { maxSeeds=sg("maxSeeds",200), moneyFloor=sg("moneyFloor",0) }
local PET = {
	moneyFloor = sg("petMoneyFloor",0),
	retryDelay = math.clamp(sg("petRetryDelay",0.15),0.1,2),
	targetTimeout = math.clamp(sg("petTargetTimeout",20),5,60),
}
local PLANT = {
	spacing       = sg("plantSpacing", 2.5),
	zone          = nil,
	zoneSize      = Vector3.new(sg("zoneX",20), 0.1, sg("zoneZ",20)),
	zoneAngle     = sg("zoneAngle",0),
	zoneScale     = math.clamp(sg("zoneScale",1),0.15,1),
	stopUnder     = sg("plantStopUnder",0),
	stopMoneyOver = sg("plantStopMoneyOver",0),
}

local seedSel       = sg("seedSel",       {})
local plantSeedSel  = sg("plantSeedSel",  {})
local gearSel       = sg("gearSel",       {})
local petSel        = sg("petSel",        {})

--========================== LIVE ITEM DATA ==========================--
-- The old build hard-coded a tiny launch-era catalog.  The current game ships
-- authoritative SeedData/GearShopData modules and mirrors purchasable entries
-- under StockValues, so build the UI from those sources on every execution.
local RARITY_RANK = {Common=1,Uncommon=2,Rare=3,Epic=4,Legendary=5,Mythic=6,Super=7,Godly=8,Divine=9,Secret=10,Prismatic=11}
local function cleanRarity(value)
	value = tostring(value or "Common")
	if value == "Mythical" then value = "Mythic" end
	return RARITY_RANK[value] and value or "Common"
end

local function stockNameSet(shopName)
	local set = {}
	local stocks = ReplicatedStorage:FindFirstChild("StockValues")
	local shop = stocks and stocks:FindFirstChild(shopName)
	local items = shop and shop:FindFirstChild("Items")
	if items then for _,item in ipairs(items:GetChildren()) do set[item.Name] = true end end
	return set
end

local function sortCatalog(list)
	table.sort(list,function(a,b)
		if a.order or b.order then
			local ao,bo=a.order or math.huge,b.order or math.huge
			if ao~=bo then return ao<bo end
		end
		local ar,br = RARITY_RANK[a.rarity] or 0,RARITY_RANK[b.rarity] or 0
		return ar == br and a.name < b.name or ar < br
	end)
	return list
end

local function loadSeedCatalog()
	local result,seen,stock = {},{},stockNameSet("SeedShop")
	local ok,data = pcall(require,ReplicatedStorage.SharedModules.SeedData)
	local worldsOk,Worlds = pcall(require,ReplicatedStorage.SharedModules.Worlds)
	local enabledOk,SeedShopEnabled = pcall(require,ReplicatedStorage.SharedModules.SeedShopEnabled)
	if ok and type(data)=="table" then
		for _,entry in ipairs(data) do
			local name = type(entry)=="table" and entry.SeedName
			local inWorld = not worldsOk or Worlds.EntryAvailableHere(entry)
			local enabled = name and (not enabledOk or SeedShopEnabled.IsSeedEnabled(name))
			-- This exactly mirrors SeedShop/NormalShop/GenerateItems.
			if name and not seen[name] and entry.RestockShop and inWorld and enabled and (stock[name] or next(stock)==nil) then
				seen[name]=true
				result[#result+1]={name=name,rarity=cleanRarity(entry.Rarity),order=entry.SeedShopDisplayOrder or math.huge,cost=entry.PurchasePrice or 0}
			end
		end
	end
	if #result==0 then result={{name="Carrot",rarity="Common"},{name="Strawberry",rarity="Common"},{name="Blueberry",rarity="Common"}} end
	return sortCatalog(result)
end

local function loadGearCatalog()
	local result,seen,stock = {},{},stockNameSet("GearShop")
	local ok,module = pcall(require,ReplicatedStorage.SharedModules.GearShopData)
	local data = ok and type(module)=="table" and module.Data or nil
	local worldsOk,Worlds=pcall(require,ReplicatedStorage.SharedModules.Worlds)
	local abOk,GearShopABTest=pcall(require,ReplicatedStorage.SharedModules.GearShopABTest)
	if type(data)=="table" then
		for _,entry in ipairs(data) do
			local name = type(entry)=="table" and entry.ItemName
			local inWorld=true
			if worldsOk then local callOk,value=pcall(Worlds.EntryAvailableHere,entry); inWorld=not callOk or value==true end
			local enabled=name~=nil
			if enabled and abOk then local callOk,value=pcall(GearShopABTest.IsGearEnabled,LP,name); enabled=not callOk or value==true end
			-- Mirrors GearShop/ScrollingFrame/GenerateItems before its shop-order sort.
			if name and not seen[name] and not entry.RobuxOnly and not entry.HideFromShop and inWorld and enabled and (entry.RestockChance or entry.EquippableGear) then
				seen[name]=true
				result[#result+1]={name=name,rarity=cleanRarity(entry.Rarity),cost=entry.Cost or 0,sortPriority=entry.SortPriority or 0,equippable=entry.EquippableGear==true,restockChance=entry.RestockChance or 0}
			end
		end
	end
	if #result==0 then result={{name="Common Watering Can",rarity="Common"},{name="Common Sprinkler",rarity="Common"}} end
	table.sort(result,function(a,b)
		local ar,br=RARITY_RANK[a.rarity] or 0,RARITY_RANK[b.rarity] or 0
		if ar~=br then return ar<br end
		if a.sortPriority~=b.sortPriority then return a.sortPriority<b.sortPriority end
		if a.equippable and not b.equippable then return false end
		if b.equippable and not a.equippable then return true end
		if a.equippable and b.equippable then return a.cost<b.cost end
		return a.restockChance>b.restockChance
	end)
	for i,item in ipairs(result) do item.order=i end
	return result
end

local function loadPetCatalog()
	local result,seen = {},{}
	local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
	local module = sharedData and sharedData:FindFirstChild("PetData")
	local ok,data = pcall(require,module)
	if ok and type(data)=="table" then
		for name,entry in pairs(data) do
			local cost = type(entry)=="table" and (tonumber(entry.BasePrice) or 0) or 0
			local spawnChance = type(entry)=="table" and (tonumber(entry.SpawnChance) or 0) or 0
			-- Only show pets that can naturally appear as purchasable wild pets.
			-- Clan, chest, reward, and event-only pets use zero for one or both fields.
			if type(name)=="string" and type(entry)=="table" and entry.DisplayName and not seen[name] and cost>0 and spawnChance>0 then
				seen[name]=true
				result[#result+1]={
					name=name,
					displayName=tostring(entry.DisplayName),
					rarity=cleanRarity(entry.Rarity),
					cost=cost,
					spawnChance=spawnChance,
					image=entry.Image,
				}
			end
		end
	end
	return sortCatalog(result)
end

local SEEDS = loadSeedCatalog()
local GEARS = loadGearCatalog()
local PETS = loadPetCatalog()

-- Older builds selected every item on first run. Clear that inherited default
-- once so every multi-select starts empty and remains entirely user-controlled.
if (tonumber(sg("multiSelectDefaultsVersion",0)) or 0)<2 then
	table.clear(seedSel)
	table.clear(plantSeedSel)
	table.clear(gearSel)
	table.clear(petSel)
	ss("multiSelectDefaultsVersion",2)
end

-- Remove stale selections when an item is no longer present in the live shop
-- catalog (including pets that cannot spawn naturally).
local function pruneSelection(selection,catalog)
	local allowed={}
	for _,entry in ipairs(catalog) do allowed[entry.name]=true end
	for name in pairs(selection) do if not allowed[name] then selection[name]=nil end end
end
pruneSelection(seedSel,SEEDS)
pruneSelection(plantSeedSel,SEEDS)
pruneSelection(gearSel,GEARS)
pruneSelection(petSel,PETS)
ss("seedSel",seedSel); ss("plantSeedSel",plantSeedSel); ss("gearSel",gearSel); ss("petSel",petSel)

--========================== NETWORKING (deferred) ==========================--
local Net, FruitValueCalc
task.spawn(function()
	for i=1,60 do
		local ok,err = pcall(function()
			Net            = require(ReplicatedStorage.SharedModules.Networking)
			FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
		end)
		if ok then print("[VOR HUB] Networking ready (attempt "..i..")"); return end
		task.wait(1)
	end
	warn("[VOR HUB] Networking unavailable after 60s")
end)

--========================== UTILITY ==========================--
local function getPlayerMoney()
	local v = LP:GetAttribute("Cash") or LP:GetAttribute("Coins") or LP:GetAttribute("Money") or LP:GetAttribute("Gold")
	if type(v)=="number" then return v end
	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		for _,name in ipairs({"Sheckles","Cash","Coins","Money","Gold"}) do
			local value=ls:FindFirstChild(name); if value and value:IsA("ValueBase") and type(value.Value)=="number" then return value.Value end
		end
		for _,c in ipairs(ls:GetChildren()) do if (c:IsA("NumberValue") or c:IsA("IntValue")) and type(c.Value)=="number" then return c.Value end end
	end
	return 0
end
local function valueOf(m)
	if not FruitValueCalc then return 0 end
	local name = m:GetAttribute("CorePartName") or m:GetAttribute("SeedName")
	if not name then return 0 end
	local ok,v = pcall(FruitValueCalc, name, m:GetAttribute("SizeMulti") or 1, m:GetAttribute("Mutation"), LP, m:GetAttribute("DecayAlpha"))
	return (ok and type(v)=="number") and v or 0
end
local function formatVal(n)
	if n>=1e9 then return string.format("%.1fB",n/1e9) elseif n>=1e6 then return string.format("%.1fM",n/1e6) elseif n>=1e3 then return string.format("%.1fK",n/1e3) else return tostring(math.floor(n)) end
end
local function totalSeedsInBag()
	local n=0
	local function scan(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SeedTool")~=nil then n=n+(t:GetAttribute("Count") or 1) end end end end
	scan(LP:FindFirstChildOfClass("Backpack")); scan(LP.Character); return n
end
local function countSeed(name)
	local n=0
	local function scan(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SeedTool")==name then n=n+(t:GetAttribute("Count") or 1) end end end end
	scan(LP:FindFirstChildOfClass("Backpack")); scan(LP.Character); return n
end
local function stockFolder(shop)
	local sv=ReplicatedStorage:FindFirstChild("StockValues"); local sh=sv and sv:FindFirstChild(shop); return sh and sh:FindFirstChild("Items")
end
local function getHRP() local c=LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local busy=false
local function acquire() local t0=os.clock(); while busy and ALIVE and os.clock()-t0<30 do task.wait() end; busy=true end
local function release() busy=false end
--========================== FEATURE LOOPS ==========================--

-- HARVEST
local hDebounce={}
task.spawn(function()
	while ALIVE do
		if F.harvest and Net then
			local myId=LP.UserId
			local tagged=CollectionService:GetTagged("HarvestPrompt")
			local list={}
			for _,p in ipairs(tagged) do
				if p:IsA("ProximityPrompt") and p.Parent and p:IsDescendantOf(workspace) then
					local m=p.Parent:FindFirstAncestorWhichIsA("Model")
					if m and tonumber(m:GetAttribute("UserId"))==myId and m:GetAttribute("PlantId") then
						list[#list+1]={m=m,v=F.prioHarvest and valueOf(m) or 0}
					end
				end
			end
			if F.prioHarvest then table.sort(list,function(a,b) return a.v>b.v end) end
			for _,e in ipairs(list) do
				if not F.harvest then break end
				local m=e.m; local pid=m:GetAttribute("PlantId"); local fid=m:GetAttribute("FruitId")
				local key=tostring(pid).."|"..tostring(fid); local now=os.clock()
				if not hDebounce[key] or now-hDebounce[key]>0.15 then
					hDebounce[key]=now; pcall(function() Net.Garden.CollectFruit:Fire(pid, fid or "") end)
				end
			end
			if #tagged==0 then table.clear(hDebounce) end
		end
		RunService.Heartbeat:Wait()
	end
end)

-- SELL
task.spawn(function()
	while ALIVE do
		if F.sell and Net then
			-- PreviewSellAll became a response packet; :Fire() now returns its reply.
			local ok,preview=pcall(function() return Net.NPCS.PreviewSellAll:Fire() end)
			if ok and preview and (preview.FruitCount or 0)>0 then pcall(function() Net.NPCS.SellAll:Fire() end) end
		end
		task.wait(0.3)
	end
end)

-- PLANT
local function groundPointUnder(pos)
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances=CollectionService:GetTagged("PlantArea")
	local r=workspace:Raycast(pos+Vector3.new(0,12,0),Vector3.new(0,-60,0),params)
	return r and r.Position
end
local function getPlotAreaPart()
	local plotId=LP:GetAttribute("PlotId")
	local gardens=workspace:FindFirstChild("Gardens")
	local plot=plotId and gardens and gardens:FindFirstChild("Plot"..tostring(plotId))
	local visual=plot and plot:FindFirstChild("Visual")
	return (visual and visual:FindFirstChild("GardenTotalArea")) or (plot and plot:FindFirstChild("PlotSizeReference"))
end
local function syncZoneToPlot()
	local area=getPlotAreaPart()
	if not (area and area:IsA("BasePart")) then return false end
	local scale=math.clamp(PLANT.zoneScale or 1,0.15,1)
	local x=math.max(2,area.Size.X*scale-0.5)
	local z=math.max(2,area.Size.Z*scale-0.5)
	PLANT.zoneSize=Vector3.new(x,0.1,z)
	-- Copy the plot's center and rotation exactly; only lift the preview above it.
	PLANT.zone=area.CFrame*CFrame.new(0,area.Size.Y/2+0.12,0)
	ss("zoneX",x); ss("zoneZ",z); ss("zoneScale",scale)
	return true
end
local function clampZoneToPlot(zoneCF,zoneSize)
	local area=getPlotAreaPart()
	if not (area and area:IsA("BasePart")) then return zoneCF,zoneSize end
	local maxSizeX=math.max(2,area.Size.X-0.5)
	local maxSizeZ=math.max(2,area.Size.Z-0.5)
	zoneSize=Vector3.new(math.clamp(zoneSize.X,2,maxSizeX),0.1,math.clamp(zoneSize.Z,2,maxSizeZ))
	local localPos=area.CFrame:PointToObjectSpace(zoneCF.Position)
	local maxX=math.max(0,(area.Size.X-zoneSize.X)/2)
	local maxZ=math.max(0,(area.Size.Z-zoneSize.Z)/2)
	local localY=area.Size.Y/2+0.12
	local clampedLocal=Vector3.new(math.clamp(localPos.X,-maxX,maxX),localY,math.clamp(localPos.Z,-maxZ,maxZ))
	local worldPos=area.CFrame:PointToWorldSpace(clampedLocal)
	return CFrame.new(worldPos)*area.CFrame.Rotation,zoneSize
end
local function resizeZoneSide(startCF,startSize,axis,dir,worldDelta)
	local area=getPlotAreaPart()
	if not (area and area:IsA("BasePart")) then return startCF,startSize end
	local localPos=area.CFrame:PointToObjectSpace(startCF.Position)
	local axisVector=axis=="x" and area.CFrame.RightVector or area.CFrame.LookVector
	local centerCoord=axis=="x" and localPos.X or -localPos.Z
	local oldSize=axis=="x" and startSize.X or startSize.Z
	local fixedOpposite=centerCoord-dir*(oldSize/2)
	local usableHalf=((axis=="x" and area.Size.X or area.Size.Z)-0.5)/2
	local maxSize=math.max(2,dir*((dir*usableHalf)-fixedOpposite))
	local wanted=oldSize+worldDelta:Dot(axisVector)*dir
	local newSize=math.clamp(wanted,2,maxSize)
	local newCenter=fixedOpposite+dir*(newSize/2)
	local newLocal=axis=="x"
		and Vector3.new(newCenter,area.Size.Y/2+0.12,localPos.Z)
		or Vector3.new(localPos.X,area.Size.Y/2+0.12,-newCenter)
	local worldPos=area.CFrame:PointToWorldSpace(newLocal)
	local size=axis=="x" and Vector3.new(newSize,0.1,startSize.Z) or Vector3.new(startSize.X,0.1,newSize)
	return CFrame.new(worldPos)*area.CFrame.Rotation,size
end
local function generateSlots()
	if not PLANT.zone then syncZoneToPlot() else PLANT.zone,PLANT.zoneSize=clampZoneToPlot(PLANT.zone,PLANT.zoneSize) end
	local gap=PLANT.spacing; local slots={}
	if PLANT.zone then
		local cf=PLANT.zone; local szX=PLANT.zoneSize.X; local szZ=PLANT.zoneSize.Z
		local nx=math.max(1,math.floor(szX/gap)); local nz=math.max(1,math.floor(szZ/gap))
		for iz=0,nz-1 do
			local cols={}; for ix=0,nx-1 do cols[#cols+1]=ix end
			if iz%2==1 then local r2={}; for i=#cols,1,-1 do r2[#r2+1]=cols[i] end; cols=r2 end
			for _,ix in ipairs(cols) do
				local lx=(-szX/2)+gap*0.5+ix*gap; local lz=(-szZ/2)+gap*0.5+iz*gap
				local wp=cf:PointToWorldSpace(Vector3.new(lx,0,lz)); local gp=groundPointUnder(wp)
				if gp then slots[#slots+1]=gp end
			end
		end
		return slots
	end
	local plotId=LP:GetAttribute("PlotId"); local plot=plotId and workspace:FindFirstChild("Gardens") and workspace.Gardens:FindFirstChild("Plot"..tostring(plotId))
	if not plot then return slots end
	local CELL=2; local MIN2=gap*gap*0.9; local bkts={}
	local function bk(cx,cz) return cx..","..cz end
	local function addPt(p) local cx,cz=math.floor(p.X/CELL),math.floor(p.Z/CELL); local k=bk(cx,cz); if not bkts[k] then bkts[k]={} end; table.insert(bkts[k],p) end
	local function tooClose(p) local cx,cz=math.floor(p.X/CELL),math.floor(p.Z/CELL); for dx=-1,1 do for dz=-1,1 do local b=bkts[bk(cx+dx,cz+dz)]; if b then for _,q in ipairs(b) do local ax,az=p.X-q.X,p.Z-q.Z; if ax*ax+az*az<MIN2 then return true end end end end end; return false end
	local pf=plot:FindFirstChild("Plants"); if pf then for _,pl in ipairs(pf:GetChildren()) do local ok2,cf2=pcall(function() return pl:GetPivot() end); local p2=ok2 and cf2.Position or (pl:IsA("BasePart") and pl.Position); if p2 then addPt(p2) end end end
	for _,pa in ipairs(CollectionService:GetTagged("PlantArea")) do
		if pa:IsA("BasePart") and pa.Size.Y<1 and pa:IsDescendantOf(plot) then
			local sx,sz=pa.Size.X,pa.Size.Z; local lx=-sx/2+gap/2
			while lx<sx/2 do local lz=-sz/2+gap/2; while lz<sz/2 do local world=(pa.CFrame*CFrame.new(lx,pa.Size.Y/2+0.05,lz)).Position; if not tooClose(world) then addPt(world); slots[#slots+1]=world end; lz=lz+gap end; lx=lx+gap end
		end
	end
	return slots
end
task.spawn(function()
	while ALIVE do
		if F.plant and Net then
			pcall(function()
				if PLANT.stopUnder>0 and totalSeedsInBag()<PLANT.stopUnder then return end
				if PLANT.stopMoneyOver>0 and getPlayerMoney()>PLANT.stopMoneyOver then return end
				local tools={}
				local function scan(c) if c then for _,t in ipairs(c:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("SeedTool")~=nil and plantSeedSel[t:GetAttribute("SeedTool")] then tools[#tools+1]=t end end end end
				scan(LP:FindFirstChildOfClass("Backpack")); scan(LP.Character)
				if #tools==0 then return end
				local slots=generateSlots(); if #slots==0 then return end
				local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); local si=1
				for _,tool in ipairs(tools) do
					if not F.plant or si>#slots then break end
					local sn=tool:GetAttribute("SeedTool"); local count=tool:GetAttribute("Count") or 1
					if hum then pcall(function() hum:EquipTool(tool) end) end
					for _=1,count do
						if not F.plant or si>#slots or not tool.Parent then break end
						if PLANT.stopUnder>0 and totalSeedsInBag()<PLANT.stopUnder then return end
						if PLANT.stopMoneyOver>0 and getPlayerMoney()>PLANT.stopMoneyOver then return end
						pcall(function() Net.Plant.PlantSeed:Fire(slots[si], sn, tool) end); si=si+1; task.wait(0.07)
					end
				end
			end)
		end
		task.wait(0.6)
	end
end)

-- BUY SEEDS
task.spawn(function()
	while ALIVE do
		if F.buySeeds and Net and getPlayerMoney()>=SHOP.moneyFloor then
			pcall(function()
				local f=stockFolder("SeedShop"); if not f then return end
				for _,v in ipairs(f:GetChildren()) do
					if not F.buySeeds then break end
					if v:IsA("ValueBase") and v.Value>0 and seedSel[v.Name] then
						local need=math.max(0,(SHOP.maxSeeds>0 and SHOP.maxSeeds or math.huge)-countSeed(v.Name))
						for _=1,math.min(v.Value,need,50) do
							if not F.buySeeds or getPlayerMoney()<SHOP.moneyFloor then break end
							pcall(function() Net.SeedShop.PurchaseSeed:Fire(v.Name) end); task.wait(0.06)
						end
					end
				end
			end)
		end
		task.wait(1.5)
	end
end)

-- BUY GEARS
task.spawn(function()
	while ALIVE do
		if F.buyGears and Net then
			pcall(function()
				local f=stockFolder("GearShop"); if not f then return end
				for _,v in ipairs(f:GetChildren()) do
					if v:IsA("ValueBase") and v.Value>0 and gearSel[v.Name] then
						for _=1,math.min(v.Value,50) do pcall(function() Net.GearShop.PurchaseGear:Fire(v.Name) end); task.wait(0.06) end
					end
				end
			end)
		end
		task.wait(1.5)
	end
end)

-- BUY SELECTED WILD PETS
local petRuntimeStatus="Idle"
local function findSelectedWildPet()
	local map=workspace:FindFirstChild("Map")
	local refs=map and map:FindFirstChild("WildPetRef")
	local hrp=getHRP()
	if not refs or not hrp then return nil end
	local best,bestRank,bestDistance
	for _,ref in ipairs(refs:GetChildren()) do
		local name=ref:GetAttribute("PetName")
		local rarity=cleanRarity(ref:GetAttribute("Rarity"))
		local price=tonumber(ref:GetAttribute("Price")) or 0
		local unowned=(tonumber(ref:GetAttribute("OwnerUserId")) or 0)==0
		if ref:IsA("BasePart") and unowned and type(name)=="string" and petSel[name] and getPlayerMoney()-price>=PET.moneyFloor then
			local rank=RARITY_RANK[rarity] or 0
			local distance=(ref.Position-hrp.Position).Magnitude
			if not best or rank>bestRank or (rank==bestRank and distance<bestDistance) then
				best,bestRank,bestDistance=ref,rank,distance
			end
		end
	end
	return best
end
task.spawn(function()
	while ALIVE do
		if F.buyPets and Net then
			local target=findSelectedWildPet()
			if target then
				local hrp=getHRP()
				local saved=hrp and hrp.CFrame
				acquire()
				local ok,err=pcall(function()
					local started=os.clock()
					petRuntimeStatus="Buying "..tostring(target:GetAttribute("PetName"))
					while ALIVE and F.buyPets and target.Parent and (tonumber(target:GetAttribute("OwnerUserId")) or 0)==0 and os.clock()-started<PET.targetTimeout do
						local price=tonumber(target:GetAttribute("Price")) or 0
						if getPlayerMoney()-price<PET.moneyFloor then petRuntimeStatus="Waiting for reserve"; break end
						local h2=getHRP(); if h2 then h2.CFrame=CFrame.new(target.Position+Vector3.new(0,3,2)) end
						Net.Pets.WildPetTame:Fire(target)
						task.wait(PET.retryDelay)
					end
				end)
				local hb=getHRP(); if hb and saved then hb.CFrame=saved end
				release()
				if not ok then petRuntimeStatus="Pet route error"; warn("[VOR HUB] Wild pet purchase failed: "..tostring(err))
				elseif target.Parent and (tonumber(target:GetAttribute("OwnerUserId")) or 0)==0 then petRuntimeStatus="Waiting for selected pet"
				else petRuntimeStatus="Pet purchased" end
			else
				petRuntimeStatus="Waiting for selected pet in budget"
			end
		else
			petRuntimeStatus="Idle"
		end
		task.wait(0.5)
	end
end)

local eventSeedRuntimeStatus="Idle"
local defenseRuntimeStatus="Idle"

-- EVENT SEEDS
task.spawn(function()
	while ALIVE do
		if F.eventSeeds and Net then
			pcall(function()
				local map=workspace:FindFirstChild("Map"); local locs=map and map:FindFirstChild("SeedPackSpawnServerLocations")
				local locations=locs and locs:GetChildren() or {}
				if #locations==0 then eventSeedRuntimeStatus="Waiting for spawn"; return end
				local hrp=getHRP(); if not hrp then eventSeedRuntimeStatus="Waiting for character"; return end
				eventSeedRuntimeStatus="Collecting "..tostring(#locations)
				acquire(); local saved=hrp.CFrame
				for _,m in ipairs(locations) do
					if not F.eventSeeds then break end
					local cf=m:IsA("BasePart") and m.CFrame or (m:IsA("Model") and pcall(function() return m:GetPivot() end) and m:GetPivot())
					if cf then hrp.CFrame=cf+Vector3.new(0,3,0); task.wait(0.25) end
				end
				local h2=getHRP(); if h2 then h2.CFrame=saved end; release()
				eventSeedRuntimeStatus="Waiting for spawn"
			end)
		else eventSeedRuntimeStatus="Idle" end
		task.wait(0.5)
	end
end)

-- ANTI-STEAL
local function findShovel()
	local function scan(container)
		if container then for _,tool in ipairs(container:GetChildren()) do if tool:IsA("Tool") and tool:GetAttribute("Shovel")~=nil then return tool end end end
	end
	return scan(LP.Character) or scan(LP:FindFirstChildOfClass("Backpack"))
end
local function findIntruders()
	local plotId=LP:GetAttribute("PlotId"); if plotId==nil then return {} end
	local zoneData=ReplicatedStorage:FindFirstChild("GardenZoneData"); if not zoneData then return {} end
	local origin=getHRP(); local result={}
	for _,player in ipairs(Players:GetPlayers()) do
		if player~=LP then
			local zone=zoneData:FindFirstChild(player.Name); local character=player.Character
			local root=character and character:FindFirstChild("HumanoidRootPart"); local humanoid=character and character:FindFirstChildOfClass("Humanoid")
			if zone and tostring(zone.Value)==tostring(plotId) and root and (not humanoid or humanoid.Health>0) then
				result[#result+1]={player=player,root=root,distance=origin and (root.Position-origin.Position).Magnitude or math.huge}
			end
		end
	end
	table.sort(result,function(a,b) return a.distance<b.distance end)
	return result
end
local defenseLastHit={}
task.spawn(function()
	while ALIVE do
		if F.antiSteal and Net then
			local intruders=findIntruders(); local shovel=findShovel(); local hrp=getHRP()
			if #intruders==0 then defenseRuntimeStatus="Armed - plot clear"
			elseif not shovel then defenseRuntimeStatus="Need a shovel"
			elseif not hrp then defenseRuntimeStatus="Waiting for character"
			else
				defenseRuntimeStatus="Responding to "..tostring(#intruders)
				acquire(); local saved=hrp.CFrame
				local ok,err=pcall(function()
					local humanoid=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then humanoid:EquipTool(shovel) end
					for _,entry in ipairs(intruders) do
						if not F.antiSteal then break end
						local player,targetRoot=entry.player,entry.root
						if not (player.Parent and targetRoot.Parent) then continue end
						local now=os.clock(); if now-(defenseLastHit[player] or 0)<0.52 then continue end
						local targetPosition=targetRoot.Position; local current=getHRP()
						if current and (current.Position-targetPosition).Magnitude>10 then current.CFrame=CFrame.lookAt(targetPosition+Vector3.new(0,0,3),targetPosition) end
						task.wait(0.04)
						pcall(function() Net.Shovel.SwingShovel:Fire() end)
						pcall(function() Net.Shovel.HitPlayer:Fire(player.UserId) end)
						defenseLastHit[player]=now; task.wait(0.52)
					end
				end)
				local current=getHRP(); if current and saved then current.CFrame=saved end; release()
				if not ok then defenseRuntimeStatus="Defense error"; warn("[VOR HUB] Anti-steal defense: "..tostring(err)) end
			end
		else defenseRuntimeStatus="Idle" end
		task.wait(F.antiSteal and 0.1 or 0.5)
	end
end)

-- PLANT ZONE
-- ======= PLANT ZONE — CUSTOM HANDLES (PC + MOBILE) =======
--[[
	Uses plain Neon Parts as handle orbs. Drag is detected through
	UserInputService so it works identically with touch and mouse.

	Move  (blue)   : drag the +X / -X / +Z / -Z orbs to slide the zone
	Scale (orange) : drag the same faces to grow/shrink that dimension
	Rotate (purple): drag left/right anywhere on the zone body to spin it

	The approach:
	  1. Each orb's position is updated every frame while it exists.
	  2. On touch/click-begin we raycast from screen to find which orb
	     (or the zone body for Rotate) was hit.
	  3. On move we project the cursor onto the appropriate world plane
	     and compute the delta from drag-start.
]]

local cam = workspace.CurrentCamera

-- Project a screen position onto a horizontal plane at worldY
local function screenRayToPlaneY(screenPos, worldY)
	local unitRay = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local dY = unitRay.Direction.Y
	if math.abs(dY) < 1e-4 then return nil end
	local t = (worldY - unitRay.Origin.Y) / dY
	if t < 0 then return nil end
	return unitRay.Origin + unitRay.Direction * t
end

-- Raycast from screen against a specific part
local function screenHitsPart(screenPos, part)
	local unitRay = cam:ScreenPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {part}
	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
	return result ~= nil
end

local zoneGhost   = nil   -- the purple zone Part
local zoneHandles = {}    -- {part, axis, dir}  — the orb Parts
local zoneActive  = false
local zoneMode    = "Move"

-- Drag state
local dragInfo = nil  -- set when a drag begins

local function updateHandlePositions()
	if not zoneGhost then return end
	local cf  = zoneGhost.CFrame
	local szX = zoneGhost.Size.X / 2 + 1.8
	local szZ = zoneGhost.Size.Z / 2 + 1.8
	for _, h in ipairs(zoneHandles) do
		if h.part and h.part.Parent then
			local offset
			if     h.axis == "x" and h.dir ==  1 then offset = cf.RightVector  * szX
			elseif h.axis == "x" and h.dir == -1 then offset = -cf.RightVector * szX
			elseif h.axis == "z" and h.dir ==  1 then offset = cf.LookVector   * szZ
			elseif h.axis == "z" and h.dir == -1 then offset = -cf.LookVector  * szZ
			end
			if offset then
				h.part.CFrame = CFrame.new(zoneGhost.Position + offset)
			end
		end
	end
end

local function destroyHandles()
	for _, h in ipairs(zoneHandles) do
		if h.part and h.part.Parent then h.part:Destroy() end
		if h.shaft and h.shaft.Parent then h.shaft:Destroy() end
	end
	table.clear(zoneHandles)
end

local function buildHandles()
	destroyHandles()
	if not zoneGhost then return end

	local modeColors = {
		Move   = Color3.fromRGB(80,  160, 255),
		Scale  = Color3.fromRGB(255, 140,  40),
		Rotate = Color3.fromRGB(200,  80, 255),
	}
	local col = modeColors[zoneMode]

	-- For Move and Scale: 4 axis orbs.  For Rotate: 2 rotation-hint orbs.
	local axes
	if zoneMode == "Rotate" then
		axes = {
			{axis="x", dir= 1},
			{axis="x", dir=-1},
		}
	else
		axes = {
			{axis="x", dir= 1},
			{axis="x", dir=-1},
			{axis="z", dir= 1},
			{axis="z", dir=-1},
		}
	end

	local cf  = zoneGhost.CFrame
	local szX = zoneGhost.Size.X / 2 + 1.8
	local szZ = zoneGhost.Size.Z / 2 + 1.8

	for _, ax in ipairs(axes) do
		-- Orb
		local orb = Instance.new("Part")
		orb.Shape    = Enum.PartType.Ball
		orb.Size     = Vector3.new(1.4, 1.4, 1.4)
		orb.Material = Enum.Material.Neon
		orb.Color    = col
		orb.Anchored    = true
		orb.CanCollide  = false
		orb.CastShadow  = false
		orb.Parent = workspace

		-- Label billboard
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(28, 18)
		bb.StudsOffset = Vector3.new(0, 1.2, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = orb
		bb.Parent = workspace
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.fromScale(1,1)
		lbl.TextColor3 = Color3.new(1,1,1)
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = 12
		lbl.Text = zoneMode == "Move" and "✥"
			or (zoneMode == "Scale" and (ax.axis=="x" and "↔" or "↕"))
			or "↻"
		lbl.Parent = bb

		table.insert(zoneHandles, {part=orb, axis=ax.axis, dir=ax.dir, bb=bb})
	end

	updateHandlePositions()
end

-- Every frame: keep handle orbs glued to zone edges
RunService.RenderStepped:Connect(function()
	if zoneActive and zoneGhost then updateHandlePositions() end

	if not dragInfo then return end
	local ip = dragInfo.latestInput
	if not ip then return end

	if dragInfo.type == "handle" then
		local h = dragInfo.handle
		local planeY = dragInfo.planeY
		local worldNow = screenRayToPlaneY(ip, planeY)
		if not worldNow then return end
		local delta = worldNow - dragInfo.worldStart

		if zoneMode == "Move" then
			local candidate=dragInfo.startCF
			if h.axis == "x" then
				local right = dragInfo.startCF.RightVector
				local proj  = delta:Dot(right)
				candidate=CFrame.new(dragInfo.startCF.Position+right*proj)*dragInfo.startCF.Rotation
			elseif h.axis == "z" then
				local look = dragInfo.startCF.LookVector
				local proj  = delta:Dot(look)
				candidate=CFrame.new(dragInfo.startCF.Position+look*proj)*dragInfo.startCF.Rotation
			elseif h.axis == "free" then
				candidate=CFrame.new(dragInfo.startCF.Position+delta)*dragInfo.startCF.Rotation
			end
			PLANT.zone,PLANT.zoneSize=clampZoneToPlot(candidate,PLANT.zoneSize)
			zoneGhost.CFrame=PLANT.zone

		elseif zoneMode == "Scale" then
			PLANT.zone,PLANT.zoneSize=resizeZoneSide(dragInfo.startCF,dragInfo.startSz,h.axis,h.dir,delta)
			PLANT.zone,PLANT.zoneSize=clampZoneToPlot(PLANT.zone,PLANT.zoneSize)
			zoneGhost.CFrame=PLANT.zone; zoneGhost.Size=Vector3.new(PLANT.zoneSize.X,0.22,PLANT.zoneSize.Z)
			ss("zoneX", PLANT.zoneSize.X); ss("zoneZ", PLANT.zoneSize.Z)
		end

	elseif dragInfo.type == "rotate" then
		-- Use screen-X delta to rotate
		local screenDX = ip.X - dragInfo.screenStart.X
		local newAngle = (dragInfo.startAngle + screenDX * 0.55) % 360
		PLANT.zoneAngle = newAngle
		zoneGhost.CFrame = CFrame.new(zoneGhost.Position)
			* CFrame.Angles(0, math.rad(newAngle), 0)
		PLANT.zone = zoneGhost.CFrame
		ss("zoneAngle", newAngle)
	end
end)

-- Input began: find what was hit and start a drag
local function onInputBegan(input)
	if not zoneActive or not zoneGhost then return end
	local isMouse  = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch  = input.UserInputType == Enum.UserInputType.Touch
	if not isMouse and not isTouch then return end

	local screenPos = Vector2.new(input.Position.X, input.Position.Y)
	local planeY    = zoneGhost.Position.Y

	-- Check each handle orb
	for _, h in ipairs(zoneHandles) do
		if h.part and h.part.Parent and screenHitsPart(screenPos, h.part) then
			local worldStart = screenRayToPlaneY(screenPos, planeY)
			if worldStart then
				dragInfo = {
					type        = "handle",
					handle      = h,
					planeY      = planeY,
					worldStart  = worldStart,
					startCF     = zoneGhost.CFrame,
					startSz     = zoneGhost.Size,
					latestInput = screenPos,
				}
			end
			return
		end
	end

	-- Check zone body (for rotate, or free-move the whole zone in Move mode)
	if screenHitsPart(screenPos, zoneGhost) then
		if zoneMode == "Rotate" then
			dragInfo = {
				type        = "rotate",
				screenStart = screenPos,
				startAngle  = PLANT.zoneAngle,
				latestInput = screenPos,
			}
		elseif zoneMode == "Move" then
			-- drag the whole body on the horizontal plane
			local worldStart = screenRayToPlaneY(screenPos, planeY)
			if worldStart then
				dragInfo = {
					type        = "handle",
					handle      = {axis="free", dir=1},
					planeY      = planeY,
					worldStart  = worldStart,
					startCF     = zoneGhost.CFrame,
					startSz     = zoneGhost.Size,
					latestInput = screenPos,
					freeMove    = true,
				}
			end
		end
	end
end

local function onInputChanged(input)
	if not dragInfo then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement
	or input.UserInputType == Enum.UserInputType.Touch then
		dragInfo.latestInput = Vector2.new(input.Position.X, input.Position.Y)
	end
end

local function onInputEnded(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		if dragInfo and dragInfo.freeMove then
			-- commit free-move
			if zoneGhost then
				local planeY = dragInfo.planeY
				local worldNow = screenRayToPlaneY(dragInfo.latestInput, planeY)
				if worldNow then
					local delta = worldNow - dragInfo.worldStart
					local candidate=CFrame.new(dragInfo.startCF.Position+delta)*dragInfo.startCF.Rotation
					PLANT.zone,PLANT.zoneSize=clampZoneToPlot(candidate,PLANT.zoneSize)
					zoneGhost.CFrame=PLANT.zone
				end
			end
		end
		dragInfo = nil
	end
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	onInputBegan(input)
end)
UserInputService.InputChanged:Connect(onInputChanged)
UserInputService.InputEnded:Connect(onInputEnded)

local function destroyZone()
	destroyHandles()
	dragInfo = nil
	if zoneGhost and zoneGhost.Parent then zoneGhost:Destroy() end
	zoneGhost = nil; zoneActive = false
end

local function attachHandles()
	buildHandles()
end

local function refreshZonePreview()
	if not syncZoneToPlot() then return false end
	if zoneGhost then
		zoneGhost.Size=Vector3.new(PLANT.zoneSize.X,0.22,PLANT.zoneSize.Z)
		zoneGhost.CFrame=PLANT.zone
	end
	return true
end

local function createZone()
	destroyZone()
	local p = Instance.new("Part"); p.Name = "GAG2_PlantZone"
	p.Anchored = true; p.CanCollide = false; p.CastShadow = false
	p.Material = Enum.Material.Neon; p.Color = Color3.fromRGB(130,80,220); p.Transparency = 0.55
	if not syncZoneToPlot() then p:Destroy(); return false end
	p.Size=Vector3.new(PLANT.zoneSize.X,0.22,PLANT.zoneSize.Z); p.CFrame=PLANT.zone
	p.Parent = workspace; zoneGhost = p; zoneActive = true
	buildHandles()
	return true
end

SELF.Destroy = function()
	ALIVE=false; destroyZone()
	local host=getParentGui()
	for _,name in ipairs({"VORHUB_GAG2","GAG2NightFall"}) do local old=host:FindFirstChild(name); if old then old:Destroy() end end
end

--========================== SHARED VOR UI ==========================--
local _,addHomeCategory,selectHomeCategory=createCategoryHomePage()
local FarmPage=addHomeCategory("🌾 Farm",1,CATEGORY_DECALS.Farming or CATEGORY_DECALS.Progress)
local PlantPage=addHomeCategory("🌱 Plant",2,CATEGORY_DECALS.Mastery or CATEGORY_DECALS.Farming)
local ShopPage=addHomeCategory("🛒 Shop",3,CATEGORY_DECALS.Shop or CATEGORY_DECALS.Progress)
local PetPage=addHomeCategory("🐾 Pets",4,CATEGORY_DECALS.Player or CATEGORY_DECALS.Mastery)

local HarvestSection=FarmPage:AddSection("Harvest Automation","Left")
local EconomySection=FarmPage:AddSection("Economy","Right")
local EventSection=FarmPage:AddSection("Protection & Events","Left")
local FarmStatusSection=FarmPage:AddSection("Runtime","Right")
local ZoneSection=PlantPage:AddSection("Plant Zone","Left")
local PlantSection=PlantPage:AddSection("Planting","Right")
local SeedShopSection=ShopPage:AddSection("Seed Shop","Left")
local GearShopSection=ShopPage:AddSection("Gear Shop","Right")
local ShopStatusSection=ShopPage:AddSection("Live Catalog","Left")
local PetBuySection=PetPage:AddSection("Wild Pet Buying","Left")
local PetSelectionSection=PetPage:AddSection("Pet Selection","Right")
local PetStatusSection=PetPage:AddSection("Live Wild Pets","Left")

local function setLabel(control,text)
	if control and type(control.Set)=="function" then control:Set(tostring(text))
	elseif control then control.Text=tostring(text) end
end

local function notify(message,color)
	Window:Notify("Grow a Garden 2",tostring(message),4,color or COLORS.accentBright)
end

local function addToggle(section,name,key,description)
	return section:AddToggle({
		Name=name,Description=description,Flag="gag2_"..key,Default=F[key],
		Callback=function(value) F[key]=value==true; ss(key,F[key]) end,
	})
end

local function namesOf(catalog)
	local values={}
	for _,entry in ipairs(catalog) do values[#values+1]=entry.name end
	return values
end

local function selectedDefaults(catalog,store)
	local defaults={}
	for _,entry in ipairs(catalog) do if store[entry.name] then defaults[entry.name]=true end end
	return defaults
end

local function replaceSelection(catalog,store,selection)
	for _,entry in ipairs(catalog) do store[entry.name]=false end
	for name,enabled in pairs(type(selection)=="table" and selection or {}) do if enabled then store[name]=true end end
end

addToggle(HarvestSection,"Auto Harvest","harvest","Harvests ready fruit using the current tagged-fruit route")
addToggle(HarvestSection,"Highest Value First","prioHarvest")
addToggle(EconomySection,"Auto Sell Inventory","sell","Previews the sale before using the native SellAll packet")
addToggle(EventSection,"Anti-Steal Defense","antiSteal","Continuously guards your plot and pushes intruders away with your shovel")
addToggle(EventSection,"Auto Collect Event Seeds","eventSeeds","Collects current and newly spawned event seed packs")
local defenseStatus=EventSection:AddLabel("Defense: Idle")
local eventSeedStatus=EventSection:AddLabel("Event seeds: Idle")
local farmStatus=FarmStatusSection:AddLabel("Build 250 routes: Ready")
FarmStatusSection:AddLabel("Harvestable tags: live")
FarmStatusSection:AddLabel("Sell route: NPCS.PreviewSellAll → SellAll")

ZoneSection:AddButton({Name="Show / Hide Plant Zone",Callback=function()
	if zoneActive then destroyZone(); notify("Plant zone hidden",COLORS.muted)
	elseif createZone() then notify("Plant zone ready",COLORS.success)
	else notify("Your plot is not ready",COLORS.warning) end
end})
ZoneSection:AddDropdown({Name="Edit Mode",Flag="gag2_zone_mode",Values={"Move","Scale"},Default=zoneMode,Callback=function(value)
	zoneMode=value=="Scale" and "Scale" or "Move"; if zoneActive then attachHandles() end
end})
ZoneSection:AddSlider({Name="Zone Size",Description="Percentage of your plot; always clamped inside it",Flag="gag2_zone_scale",Min=15,Max=100,Step=5,Default=math.floor(PLANT.zoneScale*100+0.5),Suffix="%",Callback=function(value)
	PLANT.zoneScale=math.clamp((tonumber(value) or 100)/100,0.15,1); ss("zoneScale",PLANT.zoneScale); refreshZonePreview()
end})
ZoneSection:AddButton({Name="Recenter and Fit Plot",Callback=function()
	local fitted=refreshZonePreview()
	notify(fitted and "Zone fitted to your plot" or "Plot is not ready",fitted and COLORS.success or COLORS.warning)
end})

PlantSection:AddDropdown({Name="Seeds to Plant",Flag="gag2_plant_seeds",Values=namesOf(SEEDS),Multi=true,Default=selectedDefaults(SEEDS,plantSeedSel),Callback=function(value)
	replaceSelection(SEEDS,plantSeedSel,value); ss("plantSeedSel",plantSeedSel)
end})
PlantSection:AddInput({Name="Stop Below Seed Count",Flag="gag2_plant_stop_under",Default=tostring(PLANT.stopUnder),Placeholder="0",Callback=function(value) PLANT.stopUnder=math.max(0,tonumber(value) or 0); ss("plantStopUnder",PLANT.stopUnder) end})
PlantSection:AddInput({Name="Stop Above Money",Flag="gag2_plant_stop_money",Default=tostring(PLANT.stopMoneyOver),Placeholder="0",Callback=function(value) PLANT.stopMoneyOver=math.max(0,tonumber(value) or 0); ss("plantStopMoneyOver",PLANT.stopMoneyOver) end})
addToggle(PlantSection,"Auto Plant Selected Seeds","plant")

addToggle(SeedShopSection,"Auto Buy Selected Seeds","buySeeds")
SeedShopSection:AddInput({Name="Maximum Per Seed",Flag="gag2_max_seeds",Default=tostring(SHOP.maxSeeds),Placeholder="0 = unlimited",Callback=function(value) SHOP.maxSeeds=math.max(0,tonumber(value) or 0); ss("maxSeeds",SHOP.maxSeeds) end})
SeedShopSection:AddInput({Name="Money Reserve",Flag="gag2_shop_reserve",Default=tostring(SHOP.moneyFloor),Placeholder="0",Callback=function(value) SHOP.moneyFloor=math.max(0,tonumber(value) or 0); ss("moneyFloor",SHOP.moneyFloor) end})
SeedShopSection:AddDropdown({Name="Seeds",Flag="gag2_buy_seeds",Values=namesOf(SEEDS),Multi=true,Default=selectedDefaults(SEEDS,seedSel),Callback=function(value)
	replaceSelection(SEEDS,seedSel,value); ss("seedSel",seedSel)
end})
addToggle(GearShopSection,"Auto Buy Selected Gear","buyGears")
GearShopSection:AddDropdown({Name="Gear",Flag="gag2_buy_gear",Values=namesOf(GEARS),Multi=true,Default=selectedDefaults(GEARS,gearSel),Callback=function(value)
	replaceSelection(GEARS,gearSel,value); ss("gearSel",gearSel)
end})
ShopStatusSection:AddLabel("Seeds discovered: "..tostring(#SEEDS))
ShopStatusSection:AddLabel("Gear discovered: "..tostring(#GEARS))
local moneyStatus=ShopStatusSection:AddLabel("Sheckles: Reading...")

local petLabels,petLabelToName,petDefaults={},{},{}
for _,entry in ipairs(PETS) do
	local labelText=string.format("%s [%s]",entry.displayName or entry.name,entry.rarity)
	petLabels[#petLabels+1]=labelText; petLabelToName[labelText]=entry.name
	if petSel[entry.name] then petDefaults[labelText]=true end
end
addToggle(PetBuySection,"Auto Buy Selected Wild Pets","buyPets")
PetBuySection:AddInput({Name="Sheckles Reserve",Flag="gag2_pet_reserve",Default=tostring(PET.moneyFloor),Placeholder="0",Callback=function(value) PET.moneyFloor=math.max(0,tonumber(value) or 0); ss("petMoneyFloor",PET.moneyFloor) end})
PetBuySection:AddSlider({Name="Purchase Retry Delay",Flag="gag2_pet_retry",Min=0.1,Max=2,Step=0.1,Default=PET.retryDelay,Suffix="s",Callback=function(value) PET.retryDelay=tonumber(value) or 0.15; ss("petRetryDelay",PET.retryDelay) end})
PetBuySection:AddSlider({Name="Target Timeout",Flag="gag2_pet_timeout",Min=5,Max=60,Step=1,Default=PET.targetTimeout,Suffix="s",Callback=function(value) PET.targetTimeout=tonumber(value) or 20; ss("petTargetTimeout",PET.targetTimeout) end})
PetSelectionSection:AddDropdown({Name="Pets",Description=tostring(#PETS).." pets discovered from live PetData",Flag="gag2_selected_pets",Values=petLabels,Multi=true,Default=petDefaults,Callback=function(value)
	for _,entry in ipairs(PETS) do petSel[entry.name]=false end
	for labelText,enabled in pairs(type(value)=="table" and value or {}) do local name=petLabelToName[labelText]; if name and enabled then petSel[name]=true end end
	ss("petSel",petSel)
end})
local petStatus=PetStatusSection:AddLabel("Wild pets: Reading...")
local petBudgetStatus=PetStatusSection:AddLabel("In budget: Reading...")
PetStatusSection:AddLabel("Route: Pets.WildPetTame")

task.spawn(function()
	while ALIVE do
		setLabel(defenseStatus,"Defense: "..defenseRuntimeStatus)
		setLabel(eventSeedStatus,"Event seeds: "..eventSeedRuntimeStatus)
		setLabel(moneyStatus,"Sheckles: "..formatVal(getPlayerMoney()))
		local total,selected,affordable=0,0,0
		local map=workspace:FindFirstChild("Map"); local refs=map and map:FindFirstChild("WildPetRef")
		for _,ref in ipairs(refs and refs:GetChildren() or {}) do
			if ref:IsA("BasePart") and (tonumber(ref:GetAttribute("OwnerUserId")) or 0)==0 then
				total+=1; local name=ref:GetAttribute("PetName"); local price=tonumber(ref:GetAttribute("Price")) or 0
				if type(name)=="string" and petSel[name] then selected+=1; if getPlayerMoney()-price>=PET.moneyFloor then affordable+=1 end end
			end
		end
		setLabel(petStatus,string.format("Wild: %d  •  Selected: %d",total,selected))
		setLabel(petBudgetStatus,string.format("In budget: %d  •  %s",affordable,petRuntimeStatus))
		setLabel(farmStatus,"Build "..tostring(game.PlaceVersion).." routes: Ready")
		task.wait(0.5)
	end
end)

if context.Utilities and type(context.Utilities.OnCleanup)=="function" then context.Utilities.OnCleanup(function() SELF.Destroy() end) end
selectHomeCategory("🌾 Farm")
pcall(function()
	gui:SetAttribute("GrowAGarden2ModuleReady",true)
	gui:SetAttribute("GrowAGarden2UniverseId",10200395747)
	gui:SetAttribute("GrowAGarden2PlaceId",97598239454123)
	gui:SetAttribute("GrowAGarden2Build",game.PlaceVersion)
end)
Window:SetContextStatus("Grow a Garden 2 | module ready")
notify("Grow a Garden 2 module ready",COLORS.success)
end
