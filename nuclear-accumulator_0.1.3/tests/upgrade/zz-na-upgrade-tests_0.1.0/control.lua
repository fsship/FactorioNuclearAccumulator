local function check(ok,msg) assert(ok,"NA TEST FAIL: "..msg);log("NA TEST PASS: "..msg) end
script.on_init(function()
 local s=game.surfaces[1]
 local active=s.create_entity{name="nuclear-accumulator",position={100,100},force="player",raise_built=true}
 storage.active=active;storage.energy=17123456789.123
 remote.call("nuclear-accumulator","inspect",active.unit_number).battery.energy=storage.energy
 local pending=s.create_entity{name="nuclear-accumulator",position={0,0},force="player",raise_built=true}
 remote.call("nuclear-accumulator","inspect",pending.unit_number).battery.energy=0
 pending.die("enemy")
 check(#s.find_entities_filtered{name="na-blast-0"}==1,"old save contains a carrier awaiting impact")
end)
script.on_event(defines.events.on_tick,function(event)
 local a=remote.call("nuclear-accumulator","blast_status")
 if event.tick==1 then
  local e=remote.call("nuclear-accumulator","inspect",storage.active.unit_number)
  check(e and math.abs(e.energy-storage.energy)<1e5,"configuration upgrade retains the existing real battery charge")
  check(a.emitted>0 and a.emitted<=2*a.budget,"upgrade restores pending legacy carrier as a bounded queue")
 end
 if event.tick==100 then
  check(a.emitted==2000 and a.completed==1 and a.queued==0,"legacy detonation emits its exact population once")
  log("NA UPGRADE COMPLETE")
 end
end)
