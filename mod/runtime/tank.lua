-- Every transferred joule is first removed from a real native equipment battery.
-- Target acquisition, laser damage, equipment generation and vehicle physics remain native.
local M={}
local MAIN="na-enhanced-tank"
local metadata
local laser_positions={{5,0},{5,2},{0,4},{2,4},{4,4},{6,4}}
local function valid(e)return e and e.valid end
function M.init()
 storage.tank_system=storage.tank_system or {vehicles={},destroyed={}}
end
local function helper(t,name)
 local e=t.main.surface.create_entity{name=name,position=t.main.position,force=t.main.force,quality="normal"}
 assert(e,"Enhanced tank: cannot create "..name)
 e.destructible=false;e.operable=false
 return e
end
local function core(t)
 t.core=helper(t,"na-tank-core")
 local grid=t.core.grid
 local reactor=assert(grid.put{name="na-tank-reactor",position={0,0}});reactor.energy=0
 t.battery=assert(grid.put{name="na-tank-battery",position={4,0}});t.battery.energy=0
 t.lasers={}
 for _,position in ipairs(laser_positions) do
  local e=assert(grid.put{name="na-tank-laser",position=position});e.energy=0;t.lasers[#t.lasers+1]=e
 end
end
local function create(e)
 if not valid(e) or e.name~=MAIN or storage.tank_system.vehicles[e.unit_number] then return end
 local t={main=e,id=e.unit_number,motor_debit=0,radar_debit=0,equipment_debit=0}
 e.burner.remaining_burning_fuel=0 -- Rebuilds/clones never reinterpret an old fuel record as fresh power.
 storage.tank_system.vehicles[t.id]=t
 core(t);t.radar=helper(t,"na-tank-radar");t.radar.energy=0
 t.registration=script.register_on_object_destroyed(e)
 storage.tank_system.destroyed[t.registration]=t.id
end
local function clear(t)
 storage.tank_system.vehicles[t.id]=nil
 storage.tank_system.destroyed[t.registration]=nil
 for _,name in ipairs({"core","radar"})do if valid(t[name])then t[name].destroy() end end
end
function M.build(event)create(event.entity)end
function M.configuration()
 M.init()
 for _,surface in pairs(game.surfaces)do
  for _,e in ipairs(surface.find_entities_filtered{name=MAIN})do create(e)end
 end
end
function M.remove(event)
 local e=event.entity
 if valid(e) and e.name==MAIN then
  local t=storage.tank_system.vehicles[e.unit_number];if t then clear(t)end
 end
end
function M.cloned(event)
 local e=event.destination
 if e.name==MAIN then create(e);return true
 elseif e.name=="na-tank-core" or e.name=="na-tank-radar" then e.destroy();return true end
end
function M.object_destroyed(event)
 local id=storage.tank_system.destroyed[event.registration_number]
 local t=id and storage.tank_system.vehicles[id];if t then clear(t)end
end
local function debit(t,request)
 local amount=math.max(0,math.min(request,t.battery.energy))
 t.battery.energy=t.battery.energy-amount
 return amount
end
local function move(t,e)
 if e.surface~=t.main.surface then
  if e.name=="na-tank-radar" then
   local amount=e.energy;e.destroy();e=helper(t,"na-tank-radar");e.energy=amount
  else assert(e.teleport(t.main.position,t.main.surface),"Enhanced tank: core surface teleport failed")end
 elseif e.position.x~=t.main.position.x or e.position.y~=t.main.position.y then
  assert(e.teleport(t.main.position),"Enhanced tank: helper teleport failed")
 end
 if e.force~=t.main.force then e.force=t.main.force end
 return e
end
function M.tick(event)
 for _,t in pairs(storage.tank_system.vehicles)do
  if not valid(t.main)then clear(t)
  else
   if not valid(t.core)or not valid(t.battery)then
    if valid(t.core)then t.core.destroy()end
    core(t) -- Missing energy is lost, never replenished by repair.
   end
   if not valid(t.radar)then t.radar=helper(t,"na-tank-radar");t.radar.energy=0 end
   t.core=move(t,t.core);t.radar=move(t,t.radar);t.core.orientation=t.main.orientation
   metadata=metadata or prototypes.mod_data["na-tank-metadata"].data
   local meta=metadata
   local burner=t.main.burner
   local capacity=meta.motor_watts/60*2
   local credit=debit(t,math.max(0,capacity-burner.remaining_burning_fuel))
   if credit>0 then
    local remaining=burner.remaining_burning_fuel
    burner.currently_burning=prototypes.item["na-electric-drive-fuel"]
    burner.remaining_burning_fuel=remaining+credit
    t.motor_debit=t.motor_debit+credit
   end
   local credit=debit(t,math.max(0,meta.radar_watts/60*2-t.radar.energy))
   t.radar.energy=t.radar.energy+credit;t.radar_debit=t.radar_debit+credit
   -- A bounded 1.5 MW accessory bus powers ordinary equipment without occupying player slots.
   if event.tick%5==t.id%5 then
    local budget=1500000/60*5
    for _,e in pairs(t.main.grid.equipment)do
     if e.type~="generator-equipment" and e.type~="solar-panel-equipment" and e.max_energy>0 then
      local credit=debit(t,math.min(budget,math.max(0,e.max_energy-e.energy)))
      e.energy=e.energy+credit;budget=budget-credit;t.equipment_debit=t.equipment_debit+credit
      if budget<=0 then break end
     end
    end
   end
  end
 end
end
remote.add_interface(MAIN,{inspect=function(id)
 local t=storage.tank_system and storage.tank_system.vehicles[id];if not t or not valid(t.main)then return nil end
 return {main=t.main,core=t.core,radar=t.radar,battery=t.battery,lasers=t.lasers,
  energy=valid(t.battery)and t.battery.energy or 0,motor_buffer=t.main.burner.remaining_burning_fuel,
  motor_debit=t.motor_debit,radar_debit=t.radar_debit,equipment_debit=t.equipment_debit}
end})
return M
