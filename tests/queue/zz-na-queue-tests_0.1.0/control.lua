local function check(ok,msg) assert(ok,"NA TEST FAIL: "..msg);log("NA TEST PASS: "..msg) end
local function status() return remote.call("nuclear-accumulator","blast_status") end
local function explode(surface,force,joules)
 local e=surface.create_entity{name="nuclear-accumulator",position={0,0},force=force,raise_built=true}
 remote.call("nuclear-accumulator","inspect",e.unit_number).battery.energy=joules
 e.die("enemy")
end
script.on_init(function()
 local s=game.surfaces[1];s.request_to_generate_chunks({0,0},13);s.force_generate_chunk_requests()
 for _,e in ipairs(s.find_entities()) do e.destroy() end
 for _,amount in ipairs({0,18e9,36e9}) do explode(s,"player",amount) end
 local force=game.create_force("na-merge-test");explode(s,force,0);game.merge_forces(force,"player")
 local temporary=game.create_surface("na-deleted");explode(temporary,"player",0);game.delete_surface(temporary)
 storage.before=status();storage.previous=0
 check(storage.before.queued==5 and storage.before.emitted==0,"detonations enqueue without emitting 200k native projectiles immediately")
end)
script.on_event(defines.events.on_tick,function(event)
 local a=status();local delta=a.emitted-storage.previous
 check(delta>=0 and delta<=1024,"global scheduled population never exceeds 1024 in tick "..event.tick)
 storage.previous=a.emitted
 if event.tick==1 then check(a.queued>0 and a.completed==0,"load resumes saved explosion queue") end
 if event.tick==25 then
  storage.saved=status();check(storage.saved.emitted>0 and storage.saved.queued>0,"save point contains a partially emitted explosion")
  if game.is_multiplayer() then game.server_save("na-inflight") end
 elseif event.tick==26 then
  check(a.emitted>=storage.saved.emitted and a.emitted-storage.saved.emitted<=1024,"partially emitted save retains its queue cursor and population")
 end
 if event.tick==300 then
  check(a.queued==0 and a.emitted==264500 and a.completed==4,"exact total populations, merged force, deleted surface, and queue cleanup")
  log("NA QUEUE COMPLETE")
 end
end)
