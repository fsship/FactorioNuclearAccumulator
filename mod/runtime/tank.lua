-- Every transferred joule is first removed from a real native equipment battery.
-- Target acquisition, laser damage, equipment generation and vehicle physics remain native.
local M={}
local MAIN="na-enhanced-tank"
local REPAIR_DELAY=600 -- Ten seconds since the most recent damage or weapon activity.
local REPAIR_INTERVAL=6
local REPAIR_PER_SECOND=50
local metadata
local laser_positions={{5,0},{5,2},{0,4},{2,4},{4,4},{6,4}}
local function valid(e)return e and e.valid end
function M.init()
 storage.tank_system=storage.tank_system or {vehicles={},destroyed={}}
 storage.tank_system.cores=storage.tank_system.cores or {}
end
local function helper(t,name)
 local e=t.main.surface.create_entity{name=name,position=t.main.position,force=t.main.force,quality="normal"}
 assert(e,"Enhanced tank: cannot create "..name)
 e.destructible=false;e.operable=false
 return e
end
local function core(t)
 if t.core_id then storage.tank_system.cores[t.core_id]=nil end
 t.core=helper(t,"na-tank-core")
 t.core_id=t.core.unit_number;storage.tank_system.cores[t.core_id]=t.id
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
 local t={main=e,id=e.unit_number,motor_debit=0,radar_debit=0,equipment_debit=0,last_combat_tick=game.tick}
 e.burner.remaining_burning_fuel=0 -- Rebuilds/clones never reinterpret an old fuel record as fresh power.
 storage.tank_system.vehicles[t.id]=t
 core(t);t.radar=helper(t,"na-tank-radar");t.radar.energy=0
 t.registration=script.register_on_object_destroyed(e)
 storage.tank_system.destroyed[t.registration]=t.id
end
local function clear(t)
 storage.tank_system.vehicles[t.id]=nil
 storage.tank_system.destroyed[t.registration]=nil
 if t.core_id then storage.tank_system.cores[t.core_id]=nil end
 for _,name in ipairs({"core","radar"})do if valid(t[name])then t[name].destroy() end end
end
function M.build(event)create(event.entity)end
function M.configuration()
 M.init()
 for _,t in pairs(storage.tank_system.vehicles)do
  t.last_combat_tick=t.last_combat_tick or game.tick
  if valid(t.core)then
   t.core_id=t.core.unit_number;storage.tank_system.cores[t.core_id]=t.id
  end
 end
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
function M.damaged(event)
 local e=event.entity
 -- Shielded/resisted incoming hits also count as combat; a zero-damage call does not.
 if not valid(e)or event.original_damage_amount<=0 then return end
 local t=storage.tank_system.vehicles[e.unit_number]
 if t then t.last_combat_tick=event.tick end
end
function M.weapon_fired(event)
 if event.effect_id~="na-tank-weapon-fired"or not valid(event.source_entity)then return end
 local id=storage.tank_system.cores[event.source_entity.unit_number]
 local t=id and storage.tank_system.vehicles[id]
 if t then t.last_combat_tick=event.tick end
end
local function shooting(operator)
 return valid(operator)and operator.shooting_state.state~=defines.shooting.not_shooting
end
local function repair(t,tick)
 -- Read native driver/passenger input also while reloading or shooting at empty terrain.
 if shooting(t.main.get_driver())or shooting(t.main.get_passenger())then t.last_combat_tick=tick end
 t.last_combat_tick=t.last_combat_tick or tick
 if tick%REPAIR_INTERVAL~=t.id%REPAIR_INTERVAL or tick-t.last_combat_tick<REPAIR_DELAY then return end
 local health=t.main.health
 if health and health>0 then
  local maximum=t.main.prototype.get_max_health(t.main.quality)
  if health<maximum then t.main.health=math.min(maximum,health+REPAIR_PER_SECOND*REPAIR_INTERVAL/60)end
 end
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
   repair(t,event.tick)
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
  motor_debit=t.motor_debit,radar_debit=t.radar_debit,equipment_debit=t.equipment_debit,
  last_combat_tick=t.last_combat_tick,repair_delay_ticks=REPAIR_DELAY,repair_hp_per_second=REPAIR_PER_SECOND}
end})
return M
