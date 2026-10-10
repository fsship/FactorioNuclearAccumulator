local MAIN="nuclear-accumulator"
local function check(ok,msg) assert(ok,"NA TEST FAIL: "..msg); log("NA TEST PASS: "..msg) end
local function inspect(e) return remote.call(MAIN,"inspect",e.unit_number) end
local function station(pos) return storage.surface.find_entities_filtered{name=MAIN,position=pos}[1] end
local function tagged_stack(chest)
 local inv=chest.get_inventory(defines.inventory.chest)
 for i=1,#inv do if inv[i].valid_for_read and inv[i].name==MAIN then return inv[i] end end
end
local function ghost(pos)
 storage.surface.create_entity{name="entity-ghost",inner_name=MAIN,position=pos,force="player"}
end
script.on_init(function()
 local surface=game.create_surface("na-tags",{width=256,height=128})
 surface.request_to_generate_chunks({0,0},5);surface.force_generate_chunk_requests()
 for _,e in ipairs(surface.find_entities()) do e.destroy() end
 local tiles={}; for x=-127,127 do for y=-63,63 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
 storage.surface=surface; storage.robot_builds=0;storage.recoveries=0
 game.forces.player.technologies["construction-robotics"].researched=true
 game.forces.player.technologies["logistic-robotics"].researched=true
 game.forces.player.technologies["atomic-bomb"].researched=true
 local seed=surface.create_entity{name=MAIN,position={-8,0},force="player",raise_built=true}
 storage.seed=seed
 storage.seed_charge=12345.678901234e6
 inspect(seed).battery.energy=storage.seed_charge
 storage.pre_mine={}

 local port=surface.create_entity{name="roboport",position={0,0},force="player"};port.energy=100e6
 port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=10}
 storage.cases={}
 for i,charge in ipairs({36000000000,18000000000,0}) do
  local pos={8,(i-2)*7}
  local chest=surface.create_entity{name="storage-chest",position={3,(i-2)*7},force="player"}
  chest.insert{name=MAIN,count=1};local stack=tagged_stack(chest)
  if i==1 then check(stack.get_tag("na-energy-joules")==nil,"new item defaults to untagged factory-new state") end
  stack.set_tag("na-energy-joules",charge);check(stack.get_tag("na-energy-joules")==charge,"native stack stores joules "..charge)
  local c={pos=pos,chest=chest,start_energy=charge};storage.cases[i]=c
  ghost(pos)
 end
 local machine=surface.create_entity{name="assembling-machine-3",position={-4,5},force="player"}
 machine.set_recipe(MAIN)
 machine.insert{name="processing-unit",count=20};machine.insert{name="explosives",count=20};machine.insert{name="uranium-235",count=60}
 storage.machine=machine
end)
script.on_event(defines.events.on_robot_built_entity,function(event)
 if event.entity.name~=MAIN then return end
 local stack=event.stack
 if (not stack or not stack.valid_for_read) and event.consumed_items then
  for i=1,#event.consumed_items do
   if event.consumed_items[i].valid_for_read and event.consumed_items[i].name==MAIN then
    stack=event.consumed_items[i];break
   end
  end
 end
 check(stack and stack.valid_for_read and stack.name==MAIN,"native robot event exposes the actual consumed tagged item")
 local charge=stack.get_tag("na-energy-joules")
 local a=inspect(event.entity)
 check(a.energy==(charge==nil and 36000000000 or charge),"native battery exactly restores consumed item energy")
 storage.robot_builds=storage.robot_builds+1
 log("NA TAG BUILD tick="..event.tick.." charge="..tostring(charge).." energy="..a.energy)
 if storage.wait_factory then
  check(charge==nil and a.energy==36000000000,"actual freshly crafted untagged item is placed factory-full by a robot")
  check(storage.robot_builds==10,"ten native robot builds include three extra recycle cycles and real crafted output")
  storage.factory_station=event.entity
 end
end)
script.on_event(defines.events.on_robot_pre_mined,function(event)
 if event.entity.name==MAIN then storage.pre_mine[event.entity.unit_number]=inspect(event.entity).energy end
end)
script.on_event(defines.events.on_robot_mined_entity,function(event)
 if event.entity.name~=MAIN then return end
 for i=1,#event.buffer do
  local stack=event.buffer[i]
  if stack.valid_for_read and stack.name==MAIN then
   local charge=stack.get_tag("na-energy-joules")
   check(type(charge)=="number" and charge>=0 and charge<=36000000000,"native mining buffer has serialized charge")
   check(charge==storage.pre_mine[event.entity.unit_number],"mining tag equals the actual immediately preceding battery energy, with no MJ rounding")
   storage.pre_mine[event.entity.unit_number]=nil
   storage.recoveries=storage.recoveries+1
   log("NA TAG RECOVERY tick="..event.tick.." charge="..charge)
  end
 end
end)
script.on_event(defines.events.on_tick,function(event)
 local t=event.tick
 if t==1 then
  if game.is_multiplayer() then game.speed=4 end -- Isolated local save test, never the user's save.
  check(inspect(storage.seed).energy<=storage.seed_charge and inspect(storage.seed).energy>storage.seed_charge-1e5,
   "separate-process save/load retains a partially charged station and its helper references")
  for _,c in ipairs(storage.cases) do check(tagged_stack(c.chest).get_tag("na-energy-joules")==c.start_energy,"save/load preserves exact item tag "..c.start_energy) end
 elseif t==1200 then
  check(storage.robot_builds==3,"robots built full, partial and empty items using same ghost prototype")
  for i,c in ipairs(storage.cases) do
   c.e=station(c.pos);check(c.e~=nil,"case "..i.." robot construction succeeds")
   local a=inspect(c.e)
   if i==1 then check(a.energy>35.9e9,"full item restores 36 GJ")
   elseif i==2 then check(a.energy>17.9e9 and a.energy<=18e9,"partial item restores 18 GJ without reset")
   else check(a.energy==0,"explicit zero tag restores empty battery") end
   local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"}
   inv[1].create_blueprint{surface=storage.surface,force="player",area={{c.pos[1]-1,c.pos[2]-1},{c.pos[1]+1,c.pos[2]+1}}}
   local entries=inv[1].get_blueprint_entities()
   check(entries and #entries==1 and entries[1].name==MAIN,"all charge states serialize to same one-entity blueprint")
   check(not entries[1].tags or entries[1].tags["na-energy-joules"]==nil,"blueprint does not copy the source battery charge")
   if i==2 then storage.blueprint=inv[1].export_stack() end
   inv.destroy()
   -- Exercise non-integer MJ and fractional joules; tags must not round to integer MJ.
   if i==2 then a.battery.energy=12345.6789e6 end
   c.before_mine=a.energy
   c.e.order_deconstruction("player")
  end
 elseif t==2400 then
  check(storage.recoveries==3,"robots mined every state without a nuclear explosion")
  for _,c in ipairs(storage.cases) do
   check(not c.e.valid,"normal robot mining removes original station")
   local stack=tagged_stack(c.chest)
   -- Logistics may choose a different storage chest, so inspect all storage inventories collectively below.
  end
  local values={};for _,chest in ipairs(storage.surface.find_entities_filtered{name="storage-chest"}) do
   local inv=chest.get_inventory(defines.inventory.chest)
   for i=1,#inv do if inv[i].valid_for_read and inv[i].name==MAIN then values[#values+1]=inv[i].get_tag("na-energy-joules") end end
  end
  table.sort(values);log("NA STORAGE ENERGY="..serpent.line(values));check(#values==3 and values[1]==0,"three distinct tagged items survive logistics storage, including zero charge")
  check(values[2]>0 and values[2]<18000000000,"partial recovered item carries remaining real energy")
  check(values[3]<36000000000 and values[3]>35000000000,"used full item no longer factory-full after consumption")
  storage.recovered_energy=values
  -- Same original blueprint builds from any of these items without requiring a used-item type.
  local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"};inv[1].import_stack(storage.blueprint)
  inv[1].build_blueprint{surface=storage.surface,force="player",position={20,0},force_build=true}
  inv.destroy()
  ghost({20,-10});ghost({20,10})
  storage.saved_charge=inspect(storage.seed).energy
  if game.is_multiplayer() then game.server_save("na-tags-recovered") end
 elseif t==2401 then
  local a=inspect(storage.seed)
  check(a.battery.valid and a.radar.valid and a.output.valid and a.energy<=storage.saved_charge and a.energy>0,
   "mid-run save retains partially discharged native battery and valid helper references")
 elseif t==3600 then
  check(storage.robot_builds==6,"native blueprint and ghosts rebuild all recovered items")
  local targets=storage.surface.find_entities_filtered{name=MAIN,area={{18,-12},{22,12}}}
  check(#targets==3,"one prototype rebuilds from all three charge states")
  local amounts={}
  for _,e in ipairs(targets) do amounts[#amounts+1]=inspect(e).energy end
  table.sort(amounts)
  for i,amount in ipairs(amounts) do
   check(amount<=storage.recovered_energy[i],"rebuild cannot add energy, state "..i)
  end
  local e=station({20,0});check(e~=nil,"blueprint centers on intended recycle position");local a=inspect(e);a.battery.energy=12000.987654e6
  storage.cycle_e=e;storage.last_energy=12000.987654e6
  e.order_deconstruction("player")
 elseif t>3600 and t%120==0 then
  if storage.complete then return end
  if storage.wait_factory then
   if not storage.factory_station then return end
   local poles=storage.surface.find_entities_filtered{name="small-electric-pole",area={{25,5},{40,15}}}
   if #poles~=1 then return end
   local pole=poles[1];local e=storage.factory_station;local W=defines.wire_connector_id
   check(pole.get_signal({type="virtual",name="signal-E"},W.circuit_red)>35000,
    "native blueprint restores the red-wire connection to main battery telemetry")
   check(pole.get_signal({type="virtual",name="signal-E"},W.circuit_green)>35000,
    "native blueprint restores the green-wire connection to main battery telemetry")
   check(pole.electric_network_id==inspect(e).battery.electric_network_id,
    "blueprint-built pole and hidden battery join the same real copper network")
   check(remote.call(MAIN,"blast_status").emitted==0,"all normal recovery cycles and blueprint builds remain non-explosive")
   storage.complete=true;log("NA TAG COMPLETE");return
  end
  if not storage.wait_build then
   if storage.cycle_e.valid then return end
   local stack
   for _,chest in ipairs(storage.surface.find_entities_filtered{name="storage-chest"}) do
    local candidate=tagged_stack(chest);if candidate then stack=candidate;break end
   end
   if not stack then return end
   storage.last_serialized=stack.get_tag("na-energy-joules")
   check(storage.last_serialized<=storage.last_energy,"cycle recovery preserves fractional joules without increase")
   ghost({20,0});storage.wait_build=true
  else
   local e=station({20,0});if not e then return end
   local a=inspect(e);check(a.energy<=storage.last_serialized,"repeated rebuild cannot reset to full")
   storage.cycles=(storage.cycles or 0)+1;storage.wait_build=false
   storage.last_energy=a.energy;storage.cycle_e=e
   if storage.cycles<3 then e.order_deconstruction("player")
   else
    local inv=storage.machine.get_inventory((defines.inventory.crafter_output or defines.inventory.assembling_machine_output))
    check(inv[1].valid_for_read and inv[1].name==MAIN and inv[1].get_tag("na-energy-joules")==nil,"actual recipe crafting produces untagged factory-new item")
    check(storage.robot_builds==9,"three extra native recycle/build cycles completed")
    storage.wait_factory=true
    -- Move the real recipe output, rather than spawning a substitute factory item.
    local dst=storage.cases[1].chest.get_inventory(defines.inventory.chest)
    local transferred=false
    for i=1,#dst do if not dst[i].valid_for_read then transferred=dst[i].transfer_stack(inv[1]);break end end
    check(transferred,"real crafted item transfers into native logistics storage without a charge tag")
    local pole=storage.surface.create_entity{name="small-electric-pole",position={-14,0},force="player"}
    local W=defines.wire_connector_id
    pole.get_wire_connector(W.pole_copper,true).disconnect_all()
    for _,id in ipairs({W.circuit_red,W.circuit_green,W.pole_copper}) do
     check(pole.get_wire_connector(id,true).connect_to(storage.seed.get_wire_connector(id,true)),
      "source blueprint has native wire connector "..id)
    end
    storage.cases[1].chest.insert{name="small-electric-pole",count=1}
    local bp=game.create_inventory(1);bp[1].set_stack{name="blueprint"}
    bp[1].create_blueprint{surface=storage.surface,force="player",area={{-16,-2},{-6,2}}}
    local entries=bp[1].get_blueprint_entities()
    check(entries and #entries==2,"wired blueprint contains only visible station and standard pole")
    bp[1].build_blueprint{surface=storage.surface,force="player",position={30,10},force_build=true}
    bp.destroy()
   end
  end
 end
end)
