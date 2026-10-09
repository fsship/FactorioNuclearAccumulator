local function check(ok,msg) assert(ok,"NA TEST FAIL: "..msg); log("NA TEST PASS: "..msg) end
local function inspect(e) return remote.call("nuclear-accumulator","inspect",e.unit_number) end
local function target() return storage.surface.find_entities_filtered{name={"nuclear-accumulator","nuclear-accumulator-used"},position={8,5}}[1] end
script.on_init(function()
 local surface=game.create_surface("na-lifecycle",{width=128,height=128})
 surface.request_to_generate_chunks({0,0},2);surface.force_generate_chunk_requests()
 for _,e in ipairs(surface.find_entities()) do if e.type~="resource" then e.destroy() end end
 local tiles={}; for x=-63,63 do for y=-63,63 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end;surface.set_tiles(tiles)
 check(prototypes.mod_data["na-wave-metadata"].data.outer>0,"runtime GUI wave metadata exists")
 storage.surface=surface
 game.forces.player.technologies["construction-robotics"].researched=true
 game.forces.player.technologies["logistic-robotics"].researched=true
 local seed=surface.create_entity{name="nuclear-accumulator",position={-8,0},force="player",raise_built=true}
 storage.seed=seed
 local port=surface.create_entity{name="roboport",position={0,0},force="player"}
 port.energy=100e6; storage.port=port
 port.get_inventory(defines.inventory.roboport_robot).insert{name="construction-robot",count=5}
 local chest=surface.create_entity{name="storage-chest",position={3,0},force="player"}
 chest.insert{name="nuclear-accumulator",count=1};storage.chest=chest
 surface.create_entity{name="entity-ghost",inner_name="nuclear-accumulator",position={8,5},force="player"}
 storage.scan_count=0
end)
script.on_event(defines.events.on_sector_scanned,function(event)
 if event.radar.name=="na-radar" then storage.scan_count=storage.scan_count+1 end
end)
script.on_event(defines.events.on_tick,function(ev)
 if ev.tick==1 then
  local a=inspect(storage.seed)
  check(a and a.battery.valid and a.radar.valid and a.output.valid and a.energy>35.99e9,"save/load retains helper references and real energy")
 elseif ev.tick==1200 then
  log("NA DEBUG ghosts="..#storage.surface.find_entities_filtered{type="entity-ghost"}.." chest fresh="..storage.chest.get_item_count("nuclear-accumulator"))
  log("NA DEBUG port energy="..storage.port.energy.." robot count="..storage.port.get_inventory(defines.inventory.roboport_robot).get_item_count("construction-robot"))
  log("NA DEBUG placeable="..serpent.line(prototypes.entity["nuclear-accumulator"].items_to_place_this))
  local e=target();check(e~=nil,"native robots build station ghost")
  storage.e=e;local a=inspect(e)
  check(a and a.energy>35.9e9,"robot-built factory item starts full")
  local inv=game.create_inventory(1);inv[1].set_stack{name="blueprint"}
  inv[1].create_blueprint{surface=storage.surface,force="player",area={{6,3},{10,7}}}
  local entries=inv[1].get_blueprint_entities()
  check(entries and #entries==1 and entries[1].name=="nuclear-accumulator","real blueprint contains main only")
  inv.destroy()
  check(a.map_tag and a.map_tag.valid,"automatic nuclear station map icon appears on charted map")
  storage.old_tag=a.map_tag
  a.battery.energy=12e9;e.health=456
  storage.seed.destroy{raise_destroy=true}
  local cloned=e.clone{position={30,30},surface=storage.surface,force="player"}
  check(cloned and inspect(cloned).energy==0,"clone cannot duplicate charge");storage.cloned=cloned
  storage.surface.create_entity{name="iron-ore",position={11,8},amount=10000}
  storage.drill=storage.surface.create_entity{name="electric-mining-drill",position={11,8},force="player",direction=defines.direction.north}
  storage.surface.create_entity{name="steel-chest",position={11,6},force="player"}
 elseif ev.tick==2520 then
  local e=storage.e;local a=inspect(e)
  check(storage.drill.energy>0 and storage.drill.is_connected_to_electric_network(),"isolated station powers actual mining drill")
  check(e.get_signal({type="virtual",name="signal-H"},defines.wire_connector_id.circuit_red)==456,"H follows actual health")
  check(inspect(storage.cloned).energy==0,"separate station remains empty")
  storage.old_battery=a.battery;storage.old_id=e.unit_number
  e.order_deconstruction("player")
 elseif ev.tick==3600 then
  check(not storage.e.valid,"native robot mining removes station without blast")
  check(not storage.old_tag.valid,"mining removes automatic map icon")
  check(not storage.old_battery.valid and not remote.call("nuclear-accumulator","inspect",storage.old_id),"robot mining cleans helpers")
  check(storage.chest.get_item_count("nuclear-accumulator-used")==1,"robot recovery returns used item")
  storage.surface.create_entity{name="entity-ghost",inner_name="nuclear-accumulator-used",position={8,5},force="player"}
 elseif ev.tick==4800 then
  local e=target();check(e~=nil,"robots can rebuild ghost using recovered used item")
  check(inspect(e).energy<1e8,"recovered used item never resets to 36 GJ")
  storage.e=e
  check(storage.scan_count>0,"hidden radar completes real sector scans")
  local c=storage.surface.create_entity{name="constant-combinator",position={11,5},force="player"}
  c.get_or_create_control_behavior().get_section(1).set_slot(1,{value={type="virtual",name="signal-D",quality="normal"},min=1})
  c.get_wire_connector(defines.wire_connector_id.circuit_red,true).connect_to(e.get_wire_connector(defines.wire_connector_id.circuit_red,true))
 elseif ev.tick==4840 then
  check(not storage.e.valid,"red D positive detonates")
  log("NA LIFECYCLE COMPLETE")
 end
end)
