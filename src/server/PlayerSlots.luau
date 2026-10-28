--!strict
local Players=game:GetService('Players')
local MapConfig=require(game.ReplicatedStorage.BabyBeastsShared.MapConfig)
local Signs=require(script.Parent.TankSigns)
local Boards=require(script.Parent.LaneBoards)
local Slots={}
function Slots.start(root)
 local owners={}
 local assigned={}
 local function join(player)
  if assigned[player] then return end
  local slot=nil
  for i=1,MapConfig.PlayerSlots do if not owners[i] then slot=i; break end end
  if not slot then player:Kick('This map supports seven players. Please join another server.'); return end
  local tank=root.PlayerTanks:FindFirstChild('Tank'..slot)
  assert(tank,'Missing tank slot')
  owners[slot]=player; assigned[player]=slot
  tank:SetAttribute('OwnerUserId',player.UserId)
  player:SetAttribute('TankSlot',slot)
  Signs.setOwner(tank, player)
  Boards.setOwner(root, slot, player)
  if player:GetAttribute('GameLevel') == nil then
   player:SetAttribute('GameLevel', 1)
  end
  player.RespawnLocation=tank.PlayerSpawn
  player:SetAttribute('MovementMode','RUN')
  local function place(character)
   Signs.placeCharacter(player, character, tank)
  end
  player.CharacterAdded:Connect(place)
  if player.Character then task.spawn(place,player.Character) end
 end
 Players.PlayerRemoving:Connect(function(player)
  local slot=assigned[player]
  if slot then
   owners[slot]=nil; assigned[player]=nil
   local tank=root.PlayerTanks:FindFirstChild('Tank'..slot)
   if tank then
    tank:SetAttribute('OwnerUserId',nil)
    Signs.setOwner(tank, nil)
    Boards.setOwner(root, slot, nil)
   end
  end
 end)
 Players.PlayerAdded:Connect(join)
 for _,player in Players:GetPlayers() do join(player) end
end
return Slots
