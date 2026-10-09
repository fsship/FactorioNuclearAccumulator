local MAIN, CAP = "nuclear-accumulator", 36000000000
local W = defines.wire_connector_id
local function ismain(e) return e.name==MAIN or e.name=="nuclear-accumulator-used" end
local function init()
 storage.stations=storage.stations or {}; storage.buckets=storage.buckets or {}
 storage.destroyed=storage.destroyed or {}; storage.gui=storage.gui or {}
 storage.blast_queue=storage.blast_queue or {jobs={},head=1,tail=0,emitted=0,completed=0}
 for i=0,29 do storage.buckets[i]=storage.buckets[i] or {} end
end
local function valid(e) return e and e.valid end
local function energy(s) return valid(s.battery) and s.battery.energy or 0 end
local function tier(s) return math.max(0,math.min(100,math.floor(energy(s)/CAP*100+0.5))) end
local function clear(s)
 storage.stations[s.id]=nil; storage.buckets[s.id%30][s.id]=nil
 if s.registration then storage.destroyed[s.registration]=nil end
 if valid(s.map_tag) then s.map_tag.destroy() end
 for _,key in ipairs({"battery","radar","output"}) do
  if valid(s[key]) then s[key].destroy() end
 end
end
local function helper(s,name)
 local e=s.main.surface.create_entity{name=name,position=s.main.position,force=s.main.force,quality="normal"}
 assert(e, "Nuclear Accumulator: failed to create "..name)
 e.destructible=false
 return e
end
local function link(s)
 for _,id in ipairs({W.circuit_red,W.circuit_green}) do
  local a=s.main.get_wire_connector(id,true)
  local b=s.output.get_wire_connector(id,true)
  assert(a and b, "Nuclear Accumulator: missing circuit connector")
  a.connect_to(b,false,defines.wire_origin.script)
 end
end
local function output(s)
 local cb=s.output.get_or_create_control_behavior()
 local section=cb.get_section(1) or cb.add_section()
 section.active=true; section.multiplier=1
 for i,sig in ipairs({{"signal-E",math.floor(energy(s)/1000000)},
  {"signal-H",math.floor(s.main.health or 0)}, {"signal-P",math.floor(energy(s)/CAP*100)}}) do
  section.set_slot(i,{value={type="virtual",name=sig[1],quality="normal"},min=sig[2]})
 end
end
local function map_tag(s)
 if valid(s.map_tag) and (s.tag_surface~=s.main.surface.index or s.tag_force~=s.main.force.index or
  s.tag_x~=s.main.position.x or s.tag_y~=s.main.position.y) then s.map_tag.destroy() end
 if not valid(s.map_tag) then
  s.map_tag=s.main.force.add_chart_tag(s.main.surface,{position=s.main.position,icon={type="item",name=MAIN},text=""})
  s.tag_surface=s.main.surface.index; s.tag_force=s.main.force.index
  s.tag_x=s.main.position.x; s.tag_y=s.main.position.y
 end
end
local function create(e,charged)
 if not valid(e) or not ismain(e) or storage.stations[e.unit_number] then return end
 local s={main=e,id=e.unit_number}
 storage.stations[s.id]=s; storage.buckets[s.id%30][s.id]=true
 s.battery=helper(s,"na-battery"); s.battery.energy=(charged and e.name==MAIN) and CAP or 0
 s.radar=helper(s,"na-radar"); s.output=helper(s,"na-output")
 link(s); output(s); map_tag(s)
 s.registration=script.register_on_object_destroyed(e)
 storage.destroyed[s.registration]=s.id
end
-- Queue plain state and LuaObject references in storage, so saving mid-explosion resumes it.
-- One job gets a turn per tick; incomplete jobs return to the tail for fair chain reactions.
local function schedule_blast(surface,position,force,level)
 local q=storage.blast_queue
 local m=1+9*level/100; local remaining={}
 for i,wave in ipairs(prototypes.mod_data["na-wave-metadata"].data.waves) do
  remaining[i]=math.floor(wave.count*m*m+0.5)
 end
 q.tail=q.tail+1
 q.jobs[q.tail]={surface=surface,position=position,force=force,level=level,remaining=remaining}
end
local function advance_blast()
 local q=storage.blast_queue
 if q.head>q.tail then return end
 local job=q.jobs[q.head]; q.jobs[q.head]=nil; q.head=q.head+1
 if job.surface.valid and job.force.valid then
  local batch=prototypes.mod_data["na-wave-metadata"].data.batch_size
  local unfinished=false
  for i,left in ipairs(job.remaining) do
   if left>0 then
    local count=math.min(left,batch)
    job.surface.create_entity{name="na-batch-"..job.level.."-"..i.."-"..(count==batch and "full" or "tail"),
     position=job.position,target=job.position,speed=1,force=job.force}
    job.remaining[i]=left-count; q.emitted=q.emitted+count
    if job.remaining[i]>0 then unfinished=true end
   end
  end
  if unfinished then q.tail=q.tail+1; q.jobs[q.tail]=job else q.completed=q.completed+1 end
 end
 -- Reset indices as soon as the last job finishes; removed slots never accumulate.
 if q.head>q.tail then q.jobs={}; q.head=1; q.tail=0 end
end
local function blast(s)
 if not s or s.fired or not valid(s.main) then return end
 s.fired=true -- Set before any destruction or native damage can raise nested events.
 local e=s.main
 local surface,position,force=e.surface,{x=e.position.x,y=e.position.y},e.force
 local level=tier(s)
 clear(s)
 e.destroy({raise_destroy=false})
 schedule_blast(surface,position,force,level)
 surface.create_entity{name="na-blast-"..level,position=position,target=position,speed=1,force=force}
end
local function built(event)
 local e=event.entity
 if not valid(e) or not ismain(e) then return end
 local charged=true
 if event.stack and event.stack.valid_for_read then charged=event.stack.name~="nuclear-accumulator-used"
 elseif event.item then charged=event.item.name~="nuclear-accumulator-used" end
 create(e,charged)
end
script.on_init(function() init() end)
script.on_configuration_changed(function(event)
 local had_queue=storage.blast_queue~=nil
 init()
 -- Old saves may contain a zero-distance carrier whose impact has not run yet.
 -- Its prototype is now visual-only: recover its encoded tier once, without replaying visuals.
 local change=event.mod_changes and event.mod_changes[MAIN]
 if not had_queue and change and change.old_version and change.old_version:match("^0%.1%.[01]$") then
  local names={};for percent=0,100 do names[#names+1]="na-blast-"..percent end
  for _,surface in pairs(game.surfaces) do
   for _,carrier in ipairs(surface.find_entities_filtered{name=names}) do
    schedule_blast(surface,{x=carrier.position.x,y=carrier.position.y},carrier.force,
     tonumber(carrier.name:match("(%d+)$")))
   end
  end
 end
 for _,surface in pairs(game.surfaces) do
  for _,e in ipairs(surface.find_entities_filtered{name={MAIN,"nuclear-accumulator-used"}}) do create(e,false) end
 end
 for _,force in pairs(game.forces) do
  if force.technologies["atomic-bomb"].researched then force.recipes[MAIN].enabled=true end
 end
end)
script.on_event({defines.events.on_built_entity,defines.events.on_robot_built_entity,
 defines.events.script_raised_built,defines.events.script_raised_revive},built)
script.on_event(defines.events.on_entity_cloned,function(event)
 if ismain(event.destination) then create(event.destination,false)
 elseif event.destination.name=="na-battery" or event.destination.name=="na-radar" or event.destination.name=="na-output" then
  event.destination.destroy()
 end
end)
script.on_event({defines.events.on_player_mined_entity,defines.events.on_robot_mined_entity,
 defines.events.script_raised_destroy},function(event)
 local e=event.entity
 if valid(e) and ismain(e) then local s=storage.stations[e.unit_number]; if s then clear(s) end end
end)
script.on_event(defines.events.on_entity_died,function(event)
 local e=event.entity
 if valid(e) and ismain(e) then blast(storage.stations[e.unit_number]) end
end)
script.on_event(defines.events.on_object_destroyed,function(event)
 local id=storage.destroyed[event.registration_number]
 local s=id and storage.stations[id]
 if s then clear(s) end
end)
local function close(player)
 local frame=player.gui.screen.na_window
 if frame then frame.destroy() end
 storage.gui[player.index]=nil
end
local function render(player,s)
 local frame=player.gui.screen.na_window
 if not frame or not valid(s.main) then close(player); return end
 local ratio=math.max(0,math.min(1,energy(s)/CAP)); local m=1+9*ratio
 local meta=prototypes.mod_data["na-wave-metadata"].data
 frame.na_status.caption={"na.status",string.format("%.2f",energy(s)/1000000),math.floor(s.main.health or 0),
 string.format("%.3f",m),string.format("%.2f",meta.inner*m),string.format("%.2f",meta.outer*m)}
end
local function open(player,e)
 close(player)
 if not valid(e) or not ismain(e) or e.force~=player.force then return end
 local s=storage.stations[e.unit_number]; if not s then return end
 local frame=player.gui.screen.add{type="frame",name="na_window",caption={"entity-name.nuclear-accumulator"},direction="vertical"}
 frame.auto_center=true
 frame.add{type="label",name="na_status",caption=""}
 frame.add{type="label",caption={"na.quantized"}}
 frame.add{type="button",name="na_arm",caption={"na.detonate"}}
 frame.add{type="button",name="na_confirm",caption={"na.confirm"},visible=false}
 frame.add{type="button",name="na_close",caption={"na.close"}}
 storage.gui[player.index]={id=s.id}; player.opened=frame; render(player,s)
end
script.on_event("na-open",function(event) local p=game.get_player(event.player_index); open(p,p.selected) end)
script.on_event(defines.events.on_gui_opened,function(event)
 if event.entity and ismain(event.entity) then open(game.get_player(event.player_index),event.entity) end
end)
script.on_event(defines.events.on_gui_closed,function(event)
 if event.element and event.element.valid and event.element.name=="na_window" then close(game.get_player(event.player_index)) end
end)
script.on_event(defines.events.on_gui_click,function(event)
 if not event.element.valid then return end
 local p=game.get_player(event.player_index); local view=storage.gui[p.index]
 local s=view and storage.stations[view.id]
 if event.element.name=="na_close" then close(p)
 elseif event.element.name=="na_arm" and s then
  view.armed_until=game.tick+600; p.gui.screen.na_window.na_confirm.visible=true
 elseif event.element.name=="na_confirm" and s and view.armed_until and game.tick<=view.armed_until then
  if valid(s.main) and s.main.force==p.force and p.surface==s.main.surface then close(p); blast(s) end
 end
end)
script.on_event(defines.events.on_tick,function(event)
 advance_blast()
 for id in pairs(storage.buckets[event.tick%30]) do
  local s=storage.stations[id]
  if not valid(s.main) then clear(s)
  else
   -- Repair helpers removed by other scripts; never restore missing energy as a full battery.
   local relocated=false
   for _,key in ipairs({"battery","radar","output"}) do
    local h=s[key]
    if valid(h) and (h.surface~=s.main.surface or h.position.x~=s.main.position.x or h.position.y~=s.main.position.y) then relocated=true end
   end
   if relocated then
    local amount=energy(s)
    for _,key in ipairs({"battery","radar","output"}) do if valid(s[key]) then s[key].destroy() end end
    s.battery=helper(s,"na-battery"); s.battery.energy=amount
    s.radar=helper(s,"na-radar"); s.output=helper(s,"na-output"); link(s)
   end
   if not valid(s.battery) then s.battery=helper(s,"na-battery") end
   if not valid(s.radar) then s.radar=helper(s,"na-radar") end
   if not valid(s.output) then s.output=helper(s,"na-output"); link(s) end
   for _,key in ipairs({"battery","radar","output"}) do
    if s[key].force~=s.main.force then s[key].force=s.main.force; if key=="output" then link(s) end end
   end
   output(s)
   if event.tick%300==s.id%300 then map_tag(s) end
   if s.main.get_signal({type="virtual",name="signal-D"},W.circuit_red,W.circuit_green)>0 then blast(s) end
  end
 end
 if event.tick%30==0 then
  for index,view in pairs(storage.gui) do
   local p=game.get_player(index); local s=storage.stations[view.id]
   if not p or not p.valid then storage.gui[index]=nil
   elseif not s then close(p)
   else
    render(p,s)
    if view.armed_until and event.tick>view.armed_until and p.gui.screen.na_window then
     p.gui.screen.na_window.na_confirm.visible=false; view.armed_until=nil
    end
   end
  end
 end
end)
-- Merged forces must not invalidate an explosion already in flight/queued.
script.on_event(defines.events.on_forces_merging,function(event)
 local q=storage.blast_queue; if not q then return end
 for _,job in pairs(q.jobs) do
  if job.force==event.source then job.force=event.destination end
 end
end)
-- Read-only integration interface, also used by the included acceptance scenario.
remote.add_interface("nuclear-accumulator",{
 blast_status=function()
  local q=storage.blast_queue
  return {queued=q.tail-q.head+1,emitted=q.emitted,completed=q.completed,
   budget=2*prototypes.mod_data["na-wave-metadata"].data.batch_size}
 end,
 inspect=function(id)
  local s=storage.stations[id]; if not s then return nil end
  return {energy=energy(s),battery=s.battery,radar=s.radar,output=s.output,main=s.main,map_tag=s.map_tag,tier=tier(s)}
 end
})
