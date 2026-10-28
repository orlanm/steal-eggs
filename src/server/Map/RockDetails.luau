--!strict
local G=require(script.Parent.Geometry)
local D={}
function D.wedge(parent,name,size,cf,color)
 local p=Instance.new("WedgePart")
 p.Name=name; p.Size=size; p.CFrame=cf; p.Color=color; p.Anchored=true
 p.Material=Enum.Material.Plastic; p.MaterialVariant=""; p.CanTouch=false
 for _,face in {"Top","Bottom","Left","Right","Front","Back"} do p[face.."Surface"]=Enum.SurfaceType.Universal end
 p.Parent=parent; return p
end
function D.crack(part,rng,color,lit)
 local function point(pos)
  local a=Instance.new("Attachment"); a.Name="FissurePoint"; a.Position=pos; a.Parent=part; return a
 end
 local function line(a,b,width)
  local beam=Instance.new("Beam"); beam.Name="GlowingCrack"; beam.Attachment0=a; beam.Attachment1=b
  beam.Width0=width; beam.Width1=width*.6; beam.Color=ColorSequence.new(color); beam.Transparency=NumberSequence.new(.35)
  beam.FaceCamera=true; beam.LightEmission=.8; beam.LightInfluence=.2; beam.Segments=1; beam.Parent=part
 end
 -- Short branching mineral veins; bounded random walks avoid evenly spaced lightning stripes.
 local x=rng:NextNumber(-.2,.2)*part.Size.X
 local y=rng:NextNumber(-.25,.05)*part.Size.Y
 local z=-part.Size.Z/2-.08
 local a=point(Vector3.new(x,y,z))
 for i=1,9 do
  x=math.clamp(x+rng:NextNumber(-.12,.12)*part.Size.X,-part.Size.X*.42,part.Size.X*.42)
  y=math.min(y+rng:NextNumber(.018,.065)*part.Size.Y,part.Size.Y*.43)
  local b=point(Vector3.new(x,y,z)); line(a,b,rng:NextNumber(.09,.19))
  if i==3 or i==6 then
   local branch=b; local side=if i==3 then -1 else 1
   for j=1,3 do
    local v=branch.Position+Vector3.new(side*rng:NextNumber(.025,.09)*part.Size.X,rng:NextNumber(-.025,.035)*part.Size.Y,0)
    v=Vector3.new(math.clamp(v.X,-part.Size.X*.46,part.Size.X*.46),v.Y,z)
    local tip=point(v); line(branch,tip,.10-j*.022); branch=tip
   end
  end
  a=b
 end
 if lit then
  local light=Instance.new("PointLight"); light.Color=color; light.Brightness=.3; light.Range=16; light.Shadows=false; light.Parent=a
 end
end
function D.spike(parent,name,frame,x,y,z,height,width,color,down)
 local p=script.Parent.MineralTemplate:Clone()
 p.Name=name; p.Size=Vector3.new(width*1.7,height,width*1.5)
 local turn=(x*17+z*23)%360
 p.CFrame=frame*CFrame.new(x,y,z)*CFrame.Angles(0,math.rad(turn),if down then math.pi else 0)
 p.Color=color:Lerp(Color3.fromRGB(163,151,126),.18); p.Material=Enum.Material.Plastic; p.MaterialVariant=""
 p.Anchored=true; p.CanTouch=false; p.Parent=parent
end
return D
