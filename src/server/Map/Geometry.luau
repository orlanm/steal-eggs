--!strict
local G = {}
function G.part(parent, name, size, cf, color, collide)
 local p = Instance.new("Part")
 p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
 p.Anchored = true; p.Material = Enum.Material.Plastic; p.MaterialVariant = ""
 for _,face in {"Top", "Bottom", "Left", "Right", "Front", "Back"} do p[face.."Surface"] = Enum.SurfaceType.Universal end
 p.CanCollide = collide ~= false; p.CanTouch = false; p.CanQuery = collide ~= false
 p.CastShadow = collide ~= false; p.Parent = parent
 return p
end
function G.folder(parent, name)
 local f = Instance.new("Model"); f.Name = name; f.Parent = parent; return f
end
function G.edge(parent, name, a, b, height, width, color)
 local midpoint = (a+b)/2 + Vector3.new(0,height/2,0)
 return G.part(parent,name,Vector3.new(width,height,(b-a).Magnitude),CFrame.lookAt(midpoint,midpoint+(b-a)),color,true)
end
function G.disk(parent, name, center, radius, depth, color)
 local p=G.part(parent,name,Vector3.new(depth,radius*2,radius*2),CFrame.new(center)*CFrame.Angles(0,0,math.pi/2),color,true)
 p.Shape=Enum.PartType.Cylinder; return p
end
function G.hexFloor(parent, center, radius, color)
 -- Narrow strips follow the true hex outline; all rest directly on the seabed.
 local step=radius*2/32
 for i=1,32 do
  local z=-radius+(i-.5)*step
  local edgeZ=math.abs(z)+step/2
  local half=math.sqrt(3)*math.min(radius/2,radius-edgeZ)
  G.part(parent,"SandBottom",Vector3.new(math.max(half*2,.1),2,step+.025),CFrame.new(center+Vector3.new(0,-1,z)),color,true)
 end
end
return G
