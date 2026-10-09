local MAIN="nuclear-accumulator"
local function check(ok,msg) assert(ok,"NA TEST FAIL: "..msg); log("NA TEST PASS: "..msg) end
local function inspect(e) return remote.call(MAIN,"inspect",e.unit_number) end
local function station(pos) return storage.surface.find_entities_filtered{name=MAIN,position=pos}[1] end
local function ammo_inventory(chest)
 local inv=chest.get_inventory(defines.inventory.chest)
 for i=1,#inv do if inv[i].valid_for_read and inv[i].name==MAIN then return inv[i] end end
end
local function ghost(pos)
 storage.surface.create_entity{name="entity-ghost",inner_name=MAIN,position=pos,force="player"}
end
script.on_init(function()
 local surface=game.create_surface("na-ammo",{width=256,height=128})
 surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
 for _,e in ipairs(surface.find_entities()) do e.destroy() end
 local tiles={}; for x=-127,127 do for y=-63,63 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
 storage.surface=surface; storage.robot_builds=0;storage.recoveries=0
 game.forces.player.technologies["construction-robotics"].researched=true
 game.forces.player.technologies["logistic-robotics"].researched=true
 game.forces.player.technologies["atomic-bomb"].researched=true
 local seed=surface.create_entity{name=MAIN,position={-8,0},force="player",raise_built=true}
 storage.seed=seed
 local port=surface.create_entity{name="roboport",position={0,0},force="player"};port.energy=100e6
 port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=10}
 storage.cases={}
 for i,ammo in ipairs({36001,18001,1}) do
  local pos={8,(i-2)*7}
  local chest=surface.create_entity{name="storage-chest",position={3,(i-2)*7},force="player"}
  chest.insert{name=MAIN,count=1};local stack=ammo_inventory(chest)
  if i==1 then check(stack.ammo==36001,"new ammo item defaults to factory full (36001)") end
  stack.ammo=ammo;check(stack.ammo==ammo,"native stack stores ammo "..ammo)
  local c={pos=pos,chest=chest,start_ammo=ammo};storage.cases[i]=c
  ghost(pos)
 end
 local machine=surface.create_entity{name="assembling-machine-3",position={-4,5},force="player"}
 machine.set_recipe(MAIN)
 machine.insert{name="processing-unit",count=20};machine.insert{name="explosives",count=20};machine.insert{name="uranium-235",count=60}
 storage.machine=machine
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
 if event.entity.name~=MAIN then return end
 local ammo
 if event.stack and event.stack.valid_for_read then ammo=event.stack.ammo end
 if not ammo and event.consumed_items then
  for i=1,#event.consumed_items do
   local stack=event.consumed_items[i];if stack.valid_for_read and stack.name==MAIN then ammo=stack.ammo;break end
  end
 end
 check(ammo~=nil,"native robot build event exposes consumed magazine state")
 local a=inspect(event.entity)
 check(a.energy==(ammo-1)*1e6,"restored real battery equals consumed ammo mapping: "..ammo)
 storage.robot_builds=storage.robot_builds+1
 log("NA AMMO EVENT tick="..event.tick.." ammo="..ammo.." energy="..a.energy)
end)
script.on_event(defines.events.on_robot_mined_entity,function(event)
 if event.entity.name~=MAIN then return end
 for i=1,#event.buffer do
  local stack=event.buffer[i]
  if stack.valid_for_read and stack.name==MAIN then
   check(stack.ammo>=1 and stack.ammo<=36001,"native mining buffer has serialized charge")
   storage.recoveries=storage.recoveries+1
   log("NA AMMO RECOVERY tick="..event.tick.." ammo="..stack.ammo)
  end
 end
end)
script.on_event(defines.events.on_tick,function(event)
 local t=event.tick
 if t==1 then
  for _,c in ipairs(storage.cases) do check(ammo_inventory(c.chest).ammo==c.start_ammo,"save/load preserves partial magazine state "..c.start_ammo) end
 elseif t==1200 then
  check(storage.robot_builds==3,"robots built full, partial and empty magazines using same ghost prototype")
  for i,c in ipairs(storage.cases) do
   c.e=station(c.pos);check(c.e~=nil,"case "..i.." robot construction succeeds")
   local a=inspect(c.e)
   if i==1 then check(a.energy>35.9e9,"full magazine restores 36 GJ")
   elseif i==2 then check(a.energy>17.9e9 and a.energy<=18e9,"partial magazine restores 18 GJ without reset")
   else check(a.energy==0,"sentinel ammo=1 restores empty battery") end
   local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"}
   inv[1].create_blueprint{surface=storage.surface,force="player",area={{c.pos[1]-1,c.pos[2]-1},{c.pos[1]+1,c.pos[2]+1}}}
   local entries=inv[1].get_blueprint_entities()
   check(entries and #entries==1 and entries[1].name==MAIN,"all charge states serialize to same one-entity blueprint")
   if i==2 then storage.blueprint=inv[1].export_stack() end
   inv.destroy()
   -- Exercise a non-integer MJ charge, guaranteeing serialization must round downward.
   if i==2 then a.battery.energy=12345.6789e6 end
   c.before_mine=a.energy
   c.e.order_deconstruction("player")
  end
 elseif t==2400 then
  check(storage.recoveries==3,"robots mined every state without a nuclear explosion")
  for _,c in ipairs(storage.cases) do
   check(not c.e.valid,"normal robot mining removes original station")
   local stack=ammo_inventory(c.chest)
   -- Logistics may choose a different storage chest, so inspect all storage inventories collectively below.
  end
  local values={};for _,chest in ipairs(storage.surface.find_entities_filtered{name="storage-chest"}) do
   local inv=chest.get_inventory(defines.inventory.chest)
   for i=1,#inv do if inv[i].valid_for_read and inv[i].name==MAIN then values[#values+1]=inv[i].ammo end end
  end
  table.sort(values);log("NA STORAGE AMMO="..serpent.line(values));check(#values==3 and values[1]==1,"empty recovered item survives storage, remains ammo=1")
  check(values[2]>1 and values[2]<18001,"partial recovered magazine carries remaining real energy")
  check(values[3]<36001 and values[3]>35000,"used full item no longer factory-full after consumption")
  storage.recovered_ammo=values
  -- Same original blueprint builds from any of these magazines without requiring a used-item type.
  local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"};inv[1].import_stack(storage.blueprint)
  inv[1].build_blueprint{surface=storage.surface,force="player",position={20,0},force_build=true}
  inv.destroy()
  ghost({20,-10});ghost({20,10})
 elseif t==3600 then
  check(storage.robot_builds==6,"native blueprint and ghosts rebuild all recovered magazines")
  local targets=storage.surface.find_entities_filtered{name=MAIN,area={{18,-12},{22,12}}}
  check(#targets==3,"one prototype rebuilds from all three charge states")
  local amounts={}
  for _,e in ipairs(targets) do amounts[#amounts+1]=inspect(e).energy end
  table.sort(amounts)
  for i,amount in ipairs(amounts) do
   check(amount<=(storage.recovered_ammo[i]-1)*1e6,"rebuild cannot add energy, state "..i)
  end
  local e=station({20,0});check(e~=nil,"blueprint centers on intended recycle position");local a=inspect(e);a.battery.energy=12000.987654e6
  storage.cycle_e=e;storage.last_energy=12000.987654e6
  e.order_deconstruction("player")
 elseif t==4200 or t==5400 or t==6600 then
  check(not storage.cycle_e.valid,"cycle mining succeeds")
  local stack
  for _,chest in ipairs(storage.surface.find_entities_filtered{name="storage-chest"}) do
   local s=ammo_inventory(chest);if s then stack=s;break end
  end
  check(stack~=nil,"cycle item returned to logistics storage")
  storage.last_serialized=(stack.ammo-1)*1e6
  check(storage.last_serialized<=storage.last_energy,"cycle recovery never rounds energy upward")
  ghost({20,0})
 elseif t==4800 or t==6000 or t==7200 then
  local e=station({20,0});check(e~=nil,"cycle rebuild succeeds")
  local a=inspect(e)
  check(a.energy<=storage.last_serialized,"repeated rebuild cannot reset to full")
  storage.last_energy=a.energy;storage.cycle_e=e
  if t<7200 then e.order_deconstruction("player") end
 elseif t==7800 then
  local inv=storage.machine.get_inventory(defines.inventory.assembling_machine_output)
  check(inv[1].valid_for_read and inv[1].name==MAIN and inv[1].ammo==36001,"actual recipe crafting outputs a factory-full magazine")
  check(storage.robot_builds==9,"three complete extra recycle/build cycles tested")
  log("NA AMMO COMPLETE")
 end
end)
