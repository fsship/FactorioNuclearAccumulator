-- Logic test with API doubles; this does NOT claim a graphical client test.
local handlers,init_fn={},nil
storage={};defines={events={},wire_connector_id={circuit_red=1,circuit_green=2},wire_origin={script=1}}
for _,n in ipairs({'on_built_entity','on_robot_built_entity','script_raised_built','script_raised_revive','on_entity_cloned','on_player_mined_entity','on_robot_mined_entity','script_raised_destroy','on_entity_died','on_object_destroyed','on_gui_opened','on_gui_closed','on_gui_click','on_tick'}) do defines.events[n]=n end
script={on_init=function(f)init_fn=f end,on_configuration_changed=function()end,
 on_event=function(ids,f) if type(ids)=='table' then for _,id in ipairs(ids)do handlers[id]=f end else handlers[ids]=f end end,
 register_on_object_destroyed=function(e)return e.unit_number end}
remote={add_interface=function()end}; prototypes={mod_data={['na-wave-metadata']={data={inner=7,outer=35}}}}
local count,blasts=0,0
local surface={index=1}
local force={index=1,add_chart_tag=function()return nil end}
local function connector()return {connect_to=function()end}end
surface.create_entity=function(spec)
 if spec.name:find('na%-blast%-') then blasts=blasts+1 end
 count=count+1
 local e={valid=true,name=spec.name,position=spec.position,force=spec.force,surface=surface,unit_number=count,health=1000,energy=0}
 e.destroy=function()e.valid=false end
 e.get_wire_connector=connector
 e.get_or_create_control_behavior=function()return {get_section=function()return {set_slot=function()end}end}end
 e.get_signal=function()return 0 end
 return e
end
local function gui(parent,spec)
 local e={valid=true,visible=spec.visible~=false,name=spec.name,caption=spec.caption}
 if parent and e.name then parent[e.name]=e end
 e.add=function(s)return gui(e,s)end
 e.destroy=function()e.valid=false;if parent then parent[e.name]=nil end end
 return e
end
local screen=gui(nil,{name='screen'})
local p={index=1,valid=true,force=force,surface=surface,gui={screen=screen}}
game={tick=0,get_player=function()return p end}
dofile(arg[1] or 'control.lua');init_fn()
local e=surface.create_entity{name='nuclear-accumulator',position={x=0,y=0},force=force}
handlers.script_raised_built{entity=e};p.selected=e
handlers['na-open']{player_index=1}
local f=screen.na_window
assert(f and f.na_status.caption[1]=='na.status')
handlers.on_gui_click{player_index=1,element=f.na_confirm}
assert(e.valid and blasts==0,'unarmed confirmation must do nothing')
handlers.on_gui_click{player_index=1,element=f.na_arm}
assert(e.valid and f.na_confirm.visible)
game.tick=630;handlers.on_tick{tick=630}
assert(not f.na_confirm.visible)
handlers.on_gui_click{player_index=1,element=f.na_confirm}
assert(e.valid and blasts==0,'expired arm must not detonate')
handlers.on_gui_click{player_index=1,element=f.na_arm}
handlers.on_gui_click{player_index=1,element=f.na_confirm}
assert(not e.valid and blasts==1 and not screen.na_window,'confirmed detonation happens once and closes GUI')
handlers.on_entity_died{entity=e}
assert(blasts==1,'repeat death event cannot repeat blast')
print('PASS: GUI open, actual telemetry caption, confirmation gate, expiry, manual one-shot detonation (API doubles)')
