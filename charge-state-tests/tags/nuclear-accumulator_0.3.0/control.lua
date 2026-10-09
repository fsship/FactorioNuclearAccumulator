local MAIN, CAP = "nuclear-accumulator", 36000000000
local W = defines.wire_connector_id
local function ismain(e) return e.name==MAIN end
local function init()
 storage.stations=storage.stations or {}; storage.buckets=storage.buckets or {}
 storage.destroyed=storage.destroyed or {}; storage.gui=storage.gui or {}; storage.pending_build=storage.pending_build or {}
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
local function create(e,initial_energy)
 if not valid(e) or not ismain(e) or storage.stations[e.unit_number] then return end
 local s={main=e,id=e.unit_number}
 storage.stations[s.id]=s; storage.buckets[s.id%30][s.id]=true
 s.battery=helper(s,"na-battery"); s.battery.energy=math.max(0,math.min(CAP,initial_energy==true and CAP or tonumber(initial_energy) or 0))
 s.radar=helper(s,"na-radar"); s.output=helper(s,"na-output")
 link(s); output(s); map_tag(s)
 s.registration=script.register_on_object_destroyed(e)
 storage.destroyed[s.registration]=s.id
end
local function blast(s)
 if not s or s.fired or not valid(s.main) then return end
 s.fired=true -- Set before any destruction or native damage can raise nested events.
 local e=s.main
 local surface,position,force=e.surface,{x=e.position.x,y=e.position.y},e.force
 local level=tier(s)
 clear(s)
 e.destroy({raise_destroy=false})
 surface.create_entity{name="na-blast-"..level,position=position,target=position,speed=1,force=force}
end
-- Item-state serialization is independent of the real electrical simulation.
local function item_energy(stack)
 if stack and stack.valid_for_read and stack.name==MAIN then
  local value=stack.get_tag("na-energy-joules")
  if value==nil then return CAP end -- Untagged recipe output is factory new.
  if type(value)~="number" then return 0 end
  return math.max(0,math.min(CAP,value))
 end
end
script.on_event(defines.events.on_pre_build,function(event)
 local player=game.get_player(event.player_index)
 local amount=player and item_energy(player.cursor_stack)
 storage.pending_build[event.player_index]=amount and {tick=event.tick,energy=amount} or nil
end)
local function built(event)
 local e=event.entity
 if not valid(e) or not ismain(e) then return end
 local amount
 -- 2.1 player events expose consumed_items; robot events and older events expose stack.
 if event.consumed_items then
  for i=1,#event.consumed_items do
   amount=item_energy(event.consumed_items[i]); if amount~=nil then break end
  end
 end
 if amount==nil then amount=item_energy(event.stack) end
 if event.player_index then
  local pending=storage.pending_build[event.player_index]
  if amount==nil and pending and pending.tick==event.tick then amount=pending.energy end
  storage.pending_build[event.player_index]=nil
 end
 if amount==nil then
  if event.name==defines.events.script_raised_built or event.name==defines.events.script_raised_revive then amount=CAP
  else amount=0 end -- Never assume full charge for an unrecognized consumed player/robot item.
 end
 create(e,amount)
end
script.on_init(function() init() end)
script.on_configuration_changed(function()
 init()
 for _,surface in pairs(game.surfaces) do
  for _,e in ipairs(surface.find_entities_filtered{name=MAIN}) do create(e,false) end
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
 if valid(e) and ismain(e) then
  local s=storage.stations[e.unit_number]
  if s then
   if event.buffer then
    local saved_energy=math.max(0,math.min(CAP,energy(s)))
    for i=1,#event.buffer do
     local stack=event.buffer[i]
     if stack.valid_for_read and stack.name==MAIN then stack.set_tag("na-energy-joules",saved_energy) end
    end
   end
   clear(s)
  end
 end
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
-- Read-only integration interface, also used by the included acceptance scenario.
remote.add_interface("nuclear-accumulator",{
 inspect=function(id)
  local s=storage.stations[id]; if not s then return nil end
  return {energy=energy(s),battery=s.battery,radar=s.radar,output=s.output,main=s.main,map_tag=s.map_tag,tier=tier(s)}
 end
})
