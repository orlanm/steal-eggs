local Shared = script.Parent
local Biomes = require(Shared.BiomeConfig)
local Eggs = require(Shared.GameEgg)
local Catalog = require(Shared.PetCatalog)
local EggScale = require(Shared.EggScale)
local EggSources = require(Shared.EggSources)
local Reference = require(Shared.PetIndexReference)
local C = { Sections = {}, ById = {}, ByAlias = {}, CashSeconds = 100, SpeedMultiplier = 1 }
local function key(s)
	return string.lower((s:gsub("[^%w]", "")))
end
local refKeys = {}
for n, v in Reference do
	refKeys[key(n)] = v
end
local function add(name, section)
	local pet = Catalog.get(name)
	local id = pet and pet.Id or name
	if C.ById[id] then
		local e = C.ById[id]
		C.ByAlias[key(name)] = e
		if not table.find(section.Entries, e) then
			table.insert(section.Entries, e)
		end
		return e
	end
	local ref = Reference[name]
		or refKeys[key(name)]
		or refKeys[key(name:gsub(" Egg$", ""))]
		or (pet and (refKeys[key(pet.GameName)] or refKeys[key(pet.DisplayName)]))
	local income = Eggs.profile(name).Income
	local e = {
		Id = id,
		Name = pet and pet.DisplayName or (ref and ref.Name) or name:gsub(" Egg$", ""),
		SourceName = name,
		Section = section.Id,
		Icon = ref and ref.Icon or "",
		Model = pet and pet.Model or 0,
		Income = income,
		Rarity = EggScale.rarityOf(name),
		CashReward = math.floor(income * C.CashSeconds),
		SpeedReward = math.max(
			1,
			math.floor(((ref and ref.Speed and ref.Speed > 0) and ref.Speed or income * 420) * C.SpeedMultiplier)
		),
	}
	C.ById[id] = e
	C.ByAlias[key(name)] = e
	C.ByAlias[key(id)] = e
	if pet then
		for _, n in { pet.GameName, pet.DisplayName, table.unpack(pet.Aliases or {}) } do
			C.ByAlias[key(n)] = e
		end
	end
	table.insert(section.Entries, e)
	return e
end
for _, b in Biomes do
	if b.ZoneIndex > 0 then
		local section = { Id = b.Name, Name = b.Name, Color = b.Accent or b.Floor, Entries = {}, Limited = false }
		table.insert(C.Sections, section)
		-- the biome's own nest table (the eggs that really spawn there), commonest first
		local rows = table.clone(EggSources.Biomes[b.Name] or {})
		table.sort(rows, function(x, y)
			return x[2] > y[2]
		end)
		for _, row in rows do
			add(row[1], section)
		end
	end
end
local extras = {
	Id = "Special Collection",
	Name = "Special Collection",
	Color = Color3.fromRGB(255, 180, 55),
	Entries = {},
	Limited = true,
}
for _, pet in Catalog.all() do
	if not C.ById[pet.Id] then
		add(pet.GameName, extras)
	end
end
if #extras.Entries > 0 then
	table.insert(C.Sections, extras)
end
function C.resolve(name)
	if typeof(name) ~= "string" then
		return nil
	end
	return C.ById[name] or C.ByAlias[key(name)]
end
return C
