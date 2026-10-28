--!strict
local G=require(script.Parent.Geometry)
local Route=require(script.Parent.BiomeRoute)
local Layout=require(script.Parent.Layout)
local Tanks=require(script.Parent.Tanks)
local Water=require(script.Parent.WaterVolume)

local Generator={}
function Generator.build(config)
 local existing=workspace:FindFirstChild(config.RootName)
 if existing then
  assert(existing:GetAttribute("GeneratorOwner")=="BabyBeasts", "Refusing to replace an unowned map")
  if existing:GetAttribute("BuildComplete") and existing:GetAttribute("Seed")==config.Seed and existing:GetAttribute("Version")==config.Version then
   Water.ensure(existing, config)
   return existing
  end
  -- Owned map with a stale Seed/Version: tear down and rebuild so gameplay systems can start.
  existing:Destroy()
 end
 -- Native Universal surfaces render the studs/inlets. An empty custom variant suppresses them.
 local root=G.folder(workspace,config.RootName)
 root:SetAttribute("GeneratorOwner","BabyBeasts"); root:SetAttribute("Seed",config.Seed); root:SetAttribute("Version",config.Version)
 Route.build(root,config)
 Tanks.build(root,config,Layout.tanks())
 Water.ensure(root, config)
 root:SetAttribute("BuildComplete",true)
 return root
end
return Generator
