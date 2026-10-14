local NAME="na-enhanced-tank"
local function check(ok,text)assert(ok,"NA TEST FAIL: "..text);log("NA TEST PASS: "..text)end
local function inspect(e)return remote.call(NAME,"inspect",e.unit_number)end
local function make(surface,pos)
 return surface.create_entity{name=NAME,position=pos,force="player",raise_built=true}
end
local function drive(e)
 e.orientation=0.25
 local c=e.surface.create_entity{name="character",position=e.position,force="player"};e.set_driver(c)
 e.riding_state={acceleration=defines.riding.acceleration.accelerating,direction=defines.riding.direction.straight}
 return c
end
script.on_init(function()
 local s=game.create_surface("na-tank-tests",{width=1024,height=512})
 s.request_to_generate_chunks({0,0},16);s.force_generate_chunk_requests()
 for _,e in ipairs(s.find_entities())do e.destroy()end
 local tiles={};for x=-511,511 do for y=-255,255 do tiles[#tiles+1]={name="grass-1",position={x,y}}end end;s.set_tiles(tiles)
 storage.surface=s;storage.scans=0;storage.laser_hits=0;storage.cannon_hits=0
 storage.base=s.create_entity{name="tank",position={-200,-50},force="player"}
 storage.base.get_fuel_inventory().insert{name="coal",count=100};drive(storage.base)
 storage.mobile=make(s,{-200,-100});drive(storage.mobile)
 check(storage.mobile.grid.width==15 and storage.mobile.grid.height==17,"real player equipment grid is fully usable 15x17")
 check(#storage.mobile.grid.equipment==0,"built-in reactor/lasers do not occupy player grid slots")
 check(storage.mobile.health==10000,"normal-quality health is 5x vanilla, 10000 HP")
 local a=inspect(storage.mobile);check(#a.lasers==6,"six separate native automatic defense modules exist")
 storage.user_battery=assert(storage.mobile.grid.put{name="battery-mk2-equipment",position={0,0}})
 storage.user_battery.energy=0
 storage.empty=make(s,{-200,-150});drive(storage.empty)
 local a=inspect(storage.empty);a.core.grid.take{position={0,0}};a.battery.energy=0
 storage.empty.speed=0;storage.empty.burner.remaining_burning_fuel=0
 storage.laser_tank=make(s,{-200,40})
 storage.repair=make(s,{-350,180})
 storage.protected=make(s,{-350,140})
 storage.near=s.create_entity{name="na-tank-test-target",position={-140,40},force="enemy"}
 storage.far=s.create_entity{name="na-tank-test-target",position={-115,40},force="enemy"}
 storage.friend=s.create_entity{name="na-tank-test-target",position={-170,45},force="player"}
 storage.cannon=make(s,{-200,160});storage.gunner=drive(storage.cannon)
 storage.cannon.riding_state={acceleration=defines.riding.acceleration.nothing,direction=defines.riding.direction.straight}
 storage.cannon.get_inventory(defines.inventory.car_ammo).insert{name="na-long-range-cannon-shell",count=100}
 storage.gunner.shooting_state={state=defines.shooting.shooting_enemies,position={-90,160}}
 for y=140,180 do s.create_entity{name="stone-wall",position={-100,y},force="enemy"}end
 local a=inspect(storage.laser_tank);storage.old_bank=a.battery.energy
 game.forces.player.technologies[NAME].researched=true
 check(game.forces.player.recipes[NAME].enabled,"new technology actually unlocks tank manufacturing")
 local source=s.create_entity{name="na-tank-test-source",position={396,-200},force="player"}
 source.power_usage=0;source.power_production=100000000
 s.create_entity{name="substation",position={396,-203},force="player"}
 storage.factory=s.create_entity{name="assembling-machine-3",position={400,-200},force="player"}
 storage.factory.set_recipe(NAME)
 for _,ingredient in ipairs(prototypes.recipe[NAME].ingredients)do storage.factory.insert{name=ingredient.name,count=ingredient.amount}end
end)
script.on_event(defines.events.on_sector_scanned,function(event)
 if event.radar.name=="na-tank-radar"then storage.scans=storage.scans+1 end
end)
script.on_event(defines.events.on_entity_damaged,function(event)
 if event.entity==storage.near then
  assert(event.damage_type.name=="laser" and math.abs(event.final_damage_amount-200)<0.001,"NA TEST FAIL: laser damage differs from native turret base x10")
  if storage.laser_hits==0 then log("NA TEST PASS: native automatic laser hit is exactly 10x base turret damage, 200 laser")end
  storage.laser_hits=storage.laser_hits+1
 elseif event.entity.name=="stone-wall"then storage.cannon_hits=storage.cannon_hits+1 end
end)
script.on_event(defines.events.on_tick,function(event)
 local tick=event.tick
 if tick==1 and game.is_multiplayer()then game.speed=4 end
 if tick==60 then
  local a=inspect(storage.mobile)
  check(a.core.valid and a.radar.valid and a.battery.valid,"separate-process save/load retains internal equipment and helpers")
  check(a.motor_debit>0 and a.radar_debit>0,"motor and isolated radar receive only debited real battery joules")
  check(storage.empty.speed==0 and inspect(storage.empty).energy==0,"no reactor and no stored energy means no electric acceleration")
 elseif tick==100 then
  for _,e in ipairs({storage.repair,storage.protected,storage.laser_tank,storage.cannon})do
   e.damage(1000,"enemy","electric")
   check(e.health==9000,"real electric damage is applied before passive repair")
  end
 elseif tick==400 then
  check(storage.repair.health==9000,"recent damage prevents immediate repair")
  storage.repair.damage(1000,"enemy","electric")
  check(inspect(storage.repair).last_combat_tick==400,"a repeated hit restarts the full out-of-combat cooldown")
 elseif tick==999 then
  check(storage.repair.health==8000,"no repair occurs during the full 600-tick cooldown after the last hit")
 elseif tick==1120 then
  local healed=storage.repair.health-8000
  log("NA TANK REPAIR MEASURE 120-tick heal="..healed)
  check(healed>=99.95 and healed<=105.05,"out-of-combat regeneration is 50 HP per game second")
  check(storage.laser_tank.health==9000 and inspect(storage.laser_tank).last_combat_tick>1080,
   "native automatic laser firing prevents passive healing even without incoming attacks")
  check(storage.cannon.health==9000 and inspect(storage.cannon).last_combat_tick==1120,
   "native driver weapon input prevents passive healing while attacking")
  storage.protected.damage(100,"enemy","fire")
  storage.protected_health=storage.protected.health
  check(inspect(storage.protected).last_combat_tick==1120,"an incoming hit fully blocked by native resistance still restarts combat cooldown")
 elseif tick==1150 then
  storage.repair.damage(200,"enemy","electric");storage.repair_waiting_health=storage.repair.health
 elseif tick==1200 then
  local ratio=storage.mobile.speed/storage.base.speed
  log("NA TANK MEASURE steady_speed base="..storage.base.speed.." electric="..storage.mobile.speed.." ratio="..ratio)
  check(math.abs(ratio-0.75)<0.002,"native electric driving steady speed is 75% of vanilla coal tank")
  check(storage.user_battery.energy>0,"internal fission accessory bus powers equipment in the independent user grid")
  log("NA TANK MEASURE automatic_laser_hits="..storage.laser_hits)
  check(storage.laser_hits>=165,"six parked unoccupied automatic lasers sustain native fire at 60 tiles")
  check(storage.far.health==1000000 and storage.friend.health==1000000,"72-tile laser range leaves 85-tile enemy and friendly targets undamaged")
  check(storage.cannon_hits>0,"actual long-range cannon projectiles hit walls 100 tiles away")
  local a=inspect(storage.mobile);a.battery.energy=42123456.789
  storage.saved_energy=a.battery.energy
  if game.is_multiplayer()then game.server_save("na-tank-moving")end
  storage.mobile.riding_state={acceleration=defines.riding.acceleration.braking,direction=defines.riding.direction.straight}
  storage.base.riding_state={acceleration=defines.riding.acceleration.braking,direction=defines.riding.direction.straight}
  storage.gunner.shooting_state={state=defines.shooting.not_shooting}
 elseif tick==1201 then
  local a=inspect(storage.mobile)
  check(a.core.valid and a.radar.valid and a.battery.valid and math.abs(a.energy-storage.saved_energy)<1000000,
   "mid-run partially charged moving vehicle state and all native equipment references survive save/load")
  check(inspect(storage.repair).last_combat_tick==1150 and storage.repair.health==storage.repair_waiting_health,
   "saved repair cooldown retains the last-hit tick and wounded health after process restart")
 elseif tick==1210 then
  storage.near.destroy()
 elseif tick==1700 then
  check(storage.protected.health==storage.protected_health,"resisted attacks pause repair despite causing no HP loss")
 elseif tick==1749 then
  check(storage.repair.health==storage.repair_waiting_health,"damage during regeneration immediately stops healing for another ten seconds")
 elseif tick==1810 then
  check(storage.repair.health>=storage.repair_waiting_health+49.95 and storage.repair.health<=storage.repair_waiting_health+55.05,
   "healing resumes at the same slow rate after a new damage cooldown")
 elseif tick==2100 then
  storage.repair_saved_health=storage.repair.health
  check(storage.repair_saved_health>storage.repair_waiting_health+250,"active regeneration has progressed before the second real save")
  if game.is_multiplayer()then game.server_save("na-tank-repairing")end
 elseif tick==2101 then
  check(storage.repair.health>=storage.repair_saved_health and storage.repair.health<=storage.repair_saved_health+5,
   "saving during active regeneration neither resets the cooldown nor grants offline repair")
 elseif tick==2400 then
  check(storage.laser_tank.health>9000 and storage.cannon.health>9000,"automatic lasers and driver fire stopping both allow delayed repair")
  check(storage.scans>0,"moving battery-powered radar completes genuine native sector scans without external grid")
  local a=inspect(storage.laser_tank)
  check(a.core.grid.get({0,0}).name=="na-tank-reactor","native built-in reactor remains installed")
  local before=a.battery.energy
  -- Shut off every native internal generator and laser, then measure the actual radar debit.
  a.core.grid.take{position={0,0}}
  for _,position in ipairs({{5,0},{5,2},{0,4},{2,4},{4,4},{6,4}})do a.core.grid.take{position=position}end
  a.battery.energy=10000000;storage.measure_start=a.battery.energy
  storage.radar_debit=a.radar_debit;storage.motor_debit=a.motor_debit
 elseif tick==2460 then
  local a=inspect(storage.laser_tank);local used=storage.measure_start-a.battery.energy
  log("NA TANK MEASURE isolated_radar_plus_idle_drive J/s="..used)
  check(used>290000 and used<330000,"radar consumes approximately 300kW of stored internal energy with reactor removed")
  check(math.abs(used-(a.radar_debit-storage.radar_debit)-(a.motor_debit-storage.motor_debit))<0.001,"energy credited to radar and motor exactly equals battery energy debited")
  local clone=storage.mobile.clone{position={-250,-100},surface=storage.surface,force="player"}
  check(clone and inspect(clone).energy==0,"cloning does not duplicate built-in stored energy")
  local id=clone.unit_number;local a=inspect(clone);clone.destroy{raise_destroy=true}
  check(not a.core.valid and not a.radar.valid and not remote.call(NAME,"inspect",id),"ordinary removal cleans all internal helpers without a nuclear explosion")
  local a=inspect(storage.mobile)
  local clone=a.core.clone{position={-250,-120},surface=storage.surface,force="player"}
  check(not clone or not clone.valid,"cloned internal helper is discarded without reading a destroyed LuaEntity")
  local a=inspect(storage.mobile);storage.move_energy=a.battery.energy
  local s=game.create_surface("na-tank-cross-surface",{width=128,height=128})
  s.request_to_generate_chunks({0,0},2);s.force_generate_chunk_requests()
  for _,e in ipairs(s.find_entities())do e.destroy()end
  local tiles={};for x=-63,63 do for y=-63,63 do tiles[#tiles+1]={name="grass-1",position={x,y}}end end;s.set_tiles(tiles)
  storage.destination=s;storage.mobile.teleport({0,0},s)
 elseif tick==2490 then
  local a=inspect(storage.mobile)
  check(a.core.surface==storage.destination and a.radar.surface==storage.destination,"cross-surface movement relocates internal grid and radar safely")
  check(a.core.position.x==storage.mobile.position.x and a.core.position.y==storage.mobile.position.y,"native internal laser source follows vehicle position")
  local id=storage.mobile.unit_number;local a=inspect(storage.mobile)
  storage.mobile.die("enemy")
  check(not a.core.valid and not a.radar.valid and not remote.call(NAME,"inspect",id),"vehicle death cleans internal system")
  local e=make(storage.surface,{-350,-200})
  local cell=e.grid.put{name="battery-mk2-equipment",position={0,0}};cell.energy=1234567.89
  local inv=game.create_inventory(32);local a=inspect(e)
  check(e.mine{inventory=inv,force=true,raise_destroyed=true},"native vehicle mining returns its item-with-entity-data")
  check(inv[1].valid_for_read and inv[1].name==NAME and inv[1].grid.width==15 and inv[1].grid.height==17,
   "mined native vehicle item retains the full equipment grid")
  check(inv[1].grid.equipment[1].energy==1234567.89,"native vehicle item retains exact user equipment energy on mining")
  check(not a.core.valid and not a.radar.valid,"native mining cleans private reactor/weapon/radar helpers")
  inv.destroy()
 elseif tick==2500 then
  storage.repair.health=9998
 elseif tick==2512 then
  check(storage.repair.health==storage.repair.prototype.get_max_health(storage.repair.quality),"repair stops exactly at the real maximum health")
  check(storage.empty.health==10000,"different tanks keep independent repair and combat state")
  local a=inspect(storage.repair);local id=storage.repair.unit_number
  storage.repair.damage(100000,"enemy","electric")
  check(not a.core.valid and not a.radar.valid and not remote.call(NAME,"inspect",id),"lethal damage removes the vehicle and repair state without resurrection")
 elseif tick==3300 then
  local inv=storage.factory.get_inventory(defines.inventory.crafter_output or defines.inventory.assembling_machine_output)
  check(inv[1].valid_for_read and inv[1].name==NAME,"actual assembling machine manufactures the enhanced tank from its complete recipe")
  log("NA TANK COMPLETE")
 end
end)
