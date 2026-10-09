local function check(ok,msg) assert(ok,"NA TEST FAIL: "..msg); log("NA TEST PASS: "..msg) end
local function inspect(e) return remote.call("nuclear-accumulator","inspect",e.unit_number) end
local function station(surface,x,y)
 return surface.create_entity{name="nuclear-accumulator",position={x,y},force="player",raise_built=true}
end
script.on_init(function()
 local s=game.surfaces[1]
 s.request_to_generate_chunks({0,0},14); s.force_generate_chunk_requests()
 for _,e in ipairs(s.find_entities_filtered{area={{-450,-450},{450,450}},type={"tree","cliff","unit-spawner","unit"}}) do e.destroy() end
 local tiles={}
 for x=-450,450 do for y=-450,450 do tiles[#tiles+1]={name="grass-1",position={x,y}} end end
 s.set_tiles(tiles)
 local e=station(s,0,0); local a=inspect(e)
 storage.e=e
 check(a.energy==36e9,"new station 36 GJ")
 check(a.battery.electric_network_id==a.radar.electric_network_id,"native battery and radar share electrical network")
 check(a.battery.electric_network_id~=nil,"helpers join substation")
 storage.start=a.energy
 local load=s.create_entity{name="na-test-load",position={3,0},force="player"}
 load.power_production=0; load.power_usage=100000000; storage.load=load
 storage.snapshot=inspect(e)
 storage.phase="power"
end)
script.on_event(defines.events.on_tick,function(ev)
 if ev.tick==60 then
  local a=inspect(storage.e); local diff=storage.start-a.energy
  log("NA MEASURE discharge J/s="..diff)
  check(diff>4.8e6 and diff<5.2e6,"native output limit 5 MW under excess demand")
  storage.load.destroy(); storage.start=a.energy
 elseif ev.tick==180 then
  local a=inspect(storage.e); local diff=storage.start-a.energy
  log("NA MEASURE radar J/s="..diff/2)
  check(diff>500000 and diff<700000,"isolated radar consumes ~300 kW from real battery")
  storage.radar_progress=a.radar.energy
  local src=game.surfaces[1].create_entity{name="na-test-source",position={3,0},force="player"}
  src.power_usage=0; src.power_production=100000000
  storage.src=src; storage.start=a.energy
 elseif ev.tick==240 then
  local a=inspect(storage.e); local diff=a.energy-storage.start
  log("NA MEASURE charge J/s="..diff)
  check(diff>4.8e6 and diff<5.2e6,"native input limit 5 MW")
  storage.src.destroy()
  local out=storage.e.get_signal({type="virtual",name="signal-E"},defines.wire_connector_id.circuit_red)
  check(math.abs(out-math.floor(a.energy/1e6))<=3,"E reads native stored MJ")
  check(storage.e.get_signal({type="virtual",name="signal-H"},defines.wire_connector_id.circuit_green)==1000,"H output")
  check(storage.e.get_signal({type="virtual",name="signal-P"},defines.wire_connector_id.circuit_green)>=99,"P output")
  -- Ordinary removal with raised destroy must clean helpers without a blast.
  local id=storage.e.unit_number; local b=a.battery
  storage.e.destroy{raise_destroy=true}
  check(not b.valid and not remote.call("nuclear-accumulator","inspect",id),"normal script removal cleans helpers without death")
  local e=station(game.surfaces[1],0,0); local a=inspect(e); a.battery.energy=0
  storage.e=e
  local targets={}
  for _,x in ipairs({10,25,50,150,300,390}) do
   targets[x]={}
   for y=-3,3 do
    local t=game.surfaces[1].create_entity{name="stone-wall",position={x,y*2},force="player"}
    targets[x][#targets[x]+1]=t
   end
  end
  storage.targets=targets; storage.first={}; storage.blast_tick=ev.tick
  e.die("enemy")
  storage.phase="blast0"
 elseif ev.tick==600 then
  check(storage.first[10] and storage.first[25],"zero charge blast destroys friendly walls within vanilla wave")
  check(not storage.first[50],"zero charge leaves 50-tile target intact")
  check(storage.first[25]>storage.first[10],"damage arrives later at farther targets")
  local e=station(game.surfaces[1],0,0); local a=inspect(e); a.battery.energy=18e9
  e.die("enemy"); storage.phase="blast50"; storage.first={}
 elseif ev.tick==1400 then
  check(storage.first[150],"50% wave reaches friendly walls at 150 tiles")
  check(not storage.first[300],"50% wave leaves 300-tile targets intact")
  local e=station(game.surfaces[1],0,0)
  local second=station(game.surfaces[1],100,20); inspect(second).battery.energy=0
  storage.second=second
  e.die("enemy"); storage.phase="blast100"; storage.first={}
 elseif ev.tick==2800 then
  check(storage.first[300],"100% wave reaches friendly walls at 300 tiles")
  check(not storage.first[390],"100% wave leaves 390-tile targets intact")
  check(not storage.second.valid,"native shockwave triggers station chain reaction")
  local e=station(game.surfaces[1],-100,-100); storage.e=e
  local c=game.surfaces[1].create_entity{name="constant-combinator",position={-103,-100},force="player"}
  local section=c.get_or_create_control_behavior().get_section(1)
  section.set_slot(1,{value={type="virtual",name="signal-D",quality="normal"},min=1})
  c.get_wire_connector(defines.wire_connector_id.circuit_green,true).connect_to(e.get_wire_connector(defines.wire_connector_id.circuit_green,true))
 elseif ev.tick==2840 then
  check(not storage.e.valid,"green D positive detonates")
  log("NA TEST COMPLETE")
 end
 if storage.phase and storage.phase:find("blast") then
  for x,ts in pairs(storage.targets) do
   if not storage.first[x] then
    for _,t in ipairs(ts) do if not t.valid or t.health<350 then storage.first[x]=ev.tick; log("NA MEASURE "..storage.phase.." first damage at "..x.." tick "..ev.tick); break end end
   end
  end
 end
end)
