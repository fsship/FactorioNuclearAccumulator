-- Native vehicle physics require a burner/void source in both supported engines.
-- A private electrical fuel category is credited only after real equipment energy is debited.
local MAIN="na-enhanced-tank"
local function copy(kind,name,new)
 local p=table.deepcopy(assert(data.raw[kind][name]));p.name=new;return p
end
local icons={{icon="__base__/graphics/icons/tank.png",icon_size=64},
 {icon="__base__/graphics/icons/fission-reactor-equipment.png",icon_size=64,scale=0.25,shift={8,8}}}
local tank=copy("car","tank",MAIN)
tank.icons=icons;tank.icon=nil;tank.minable={mining_time=0.5,result=MAIN}
tank.max_health=data.raw.car.tank.max_health*5
tank.equipment_grid="na-tank-grid";tank.allow_remote_driving=true
tank.energy_source={type="burner",fuel_categories={"na-electric-drive"},fuel_inventory_size=0,effectivity=1}
tank.guns=table.deepcopy(data.raw.car.tank.guns);tank.guns[1]="na-tank-cannon"
local cannon=copy("gun","tank-cannon","na-tank-cannon")
cannon.attack_parameters.range=data.raw.gun["tank-cannon"].attack_parameters.range*4
local item=copy("item-with-entity-data","tank",MAIN)
item.icons=icons;item.icon=nil;item.place_result=MAIN;item.stack_size=1
local reactor=copy("generator-equipment","fission-reactor-equipment","na-tank-reactor")
reactor.power="10MW";reactor.categories={"na-tank-internal"}
local battery=copy("battery-equipment","battery-mk2-equipment","na-tank-battery")
battery.energy_source.buffer_capacity="100MJ";battery.categories={"na-tank-internal"}
local laser=copy("active-defense-equipment","personal-laser-defense-equipment","na-tank-laser")
laser.categories={"na-tank-internal"};laser.automatic=true
laser.attack_parameters=table.deepcopy(data.raw["electric-turret"]["laser-turret"].attack_parameters)
laser.attack_parameters.range=laser.attack_parameters.range*3
laser.attack_parameters.damage_modifier=laser.attack_parameters.damage_modifier*10
laser.attack_parameters.ammo_type.action.action_delivery.max_length=laser.attack_parameters.range
laser.energy_source={type="electric",usage_priority="secondary-input",buffer_capacity="801kJ"}
local internal_items={}
for _,e in ipairs({reactor,battery,laser}) do
 internal_items[#internal_items+1]={type="item",name=e.name,hidden=true,stack_size=1,
  icon="__base__/graphics/icons/"..(e==reactor and "fission-reactor-equipment" or e==battery and "battery-mk2-equipment" or "personal-laser-defense-equipment")..".png",
  icon_size=64,place_as_equipment_result=e.name}
end
local core=copy("car","tank","na-tank-core")
core.flags={"placeable-off-grid","not-on-map","not-blueprintable","not-deconstructable","not-flammable","not-in-kill-statistics"}
core.hidden=true;core.selectable_in_game=false;core.is_military_target=false;core.allow_remote_driving=false
core.collision_box={{0,0},{0,0}};core.collision_mask={layers={}};core.selection_box={{0,0},{0,0}}
core.minable=nil;core.corpse=nil;core.dying_explosion=nil
core.energy_source={type="void"};core.consumption="0W";core.guns={}
core.equipment_grid="na-tank-internal-grid";core.inventory_size=0;core.trash_inventory_size=0
local empty={filename="__core__/graphics/empty.png",width=1,height=1,direction_count=1}
core.animation=table.deepcopy(empty);core.turret_animation=table.deepcopy(empty)
core.light=nil;core.light_animation=nil;core.working_sound=nil;core.water_reflection=nil
local radar=copy("radar","radar","na-tank-radar")
radar.flags=table.deepcopy(core.flags);radar.hidden=true;radar.selectable_in_game=false
radar.minable=nil;radar.collision_box={{0,0},{0,0}};radar.collision_mask={layers={}};radar.selection_box={{0,0},{0,0}}
radar.corpse=nil;radar.dying_explosion=nil;radar.working_sound=nil;radar.integration_patch=nil;radar.circuit_connector=nil
radar.pictures=table.deepcopy(empty)
radar.energy_source={type="electric",usage_priority="secondary-input",input_flow_limit="0W",buffer_capacity="600kJ"}
local tech=copy("technology","fission-reactor-equipment",MAIN)
tech.icons={{icon="__base__/graphics/technology/tank.png",icon_size=256},
 {icon="__base__/graphics/technology/fission-reactor-equipment.png",icon_size=256,scale=0.25,shift={64,64}}}
tech.icon=nil;tech.prerequisites={"tank","fission-reactor-equipment","laser-turret","battery-mk2-equipment"}
tech.effects={{type="unlock-recipe",recipe=MAIN}}
local fuel=copy("item","coal","na-electric-drive-fuel")
fuel.hidden=true;fuel.stack_size=1;fuel.icon="__base__/graphics/icons/battery.png";fuel.icon_size=64;fuel.icons=nil
fuel.pictures=nil;fuel.dark_background_icon=nil;fuel.random_tint_color=nil
-- Native steady speed scales with sqrt(thrust) on identical terrain. Keep the fuel
-- top-speed factor neutral: 2.0 and 2.1 treat factors below one differently.
fuel.fuel_value="1MJ";fuel.fuel_top_speed_multiplier=1;fuel.fuel_acceleration_multiplier=0.75*0.75
if fuel.fuel_categories then fuel.fuel_categories={"na-electric-drive"}else fuel.fuel_category="na-electric-drive"end
local shells={}
local function scale_delivery(t)
 if type(t)~="table"then return end
 if t.type=="projectile"and t.max_range then t.max_range=t.max_range*4 end
 for _,v in pairs(t)do if type(v)=="table"then scale_delivery(v)end end
end
for _,name in ipairs({"cannon-shell","explosive-cannon-shell","uranium-cannon-shell","explosive-uranium-cannon-shell"})do
 local ammo=copy("ammo",name,"na-long-range-"..name)
 ammo.icons={{icon=ammo.icon,icon_size=64},{icon="__base__/graphics/icons/tank-cannon.png",icon_size=64,scale=0.2,shift={8,8}}}
 ammo.icon=nil
 scale_delivery(ammo.ammo_type)
 shells[#shells+1]=ammo
 shells[#shells+1]={type="recipe",name=ammo.name,enabled=false,energy_required=1,
  ingredients={{type="item",name=name,amount=1}},results={{type="item",name=ammo.name,amount=1}}}
 tech.effects[#tech.effects+1]={type="unlock-recipe",recipe=ammo.name}
end
data:extend({tank,cannon,item,reactor,battery,laser,core,radar,tech,
 {type="equipment-category",name="na-tank-internal"},
 {type="equipment-grid",name="na-tank-grid",width=15,height=17,equipment_categories={"armor"}},
 {type="equipment-grid",name="na-tank-internal-grid",width=8,height=6,equipment_categories={"na-tank-internal"}},
 {type="fuel-category",name="na-electric-drive"},
 fuel,
 {type="recipe",name=MAIN,enabled=false,energy_required=60,ingredients={
  {type="item",name="tank",amount=1},{type="item",name="fission-reactor-equipment",amount=1},
  {type="item",name="laser-turret",amount=6},{type="item",name="radar",amount=1},
  {type="item",name="battery-mk2-equipment",amount=1},{type="item",name="electric-engine-unit",amount=40},
  {type="item",name="processing-unit",amount=100},{type="item",name="low-density-structure",amount=50}},
  results={{type="item",name=MAIN,amount=1}}}})
data:extend(internal_items)
data:extend(shells)
data:extend({{type="mod-data",name="na-tank-metadata",data={
 grid_width=15,grid_height=17,reactor_watts=10000000,motor_watts=600000,radar_watts=300000,
 cannon_range=cannon.attack_parameters.range,laser_range=laser.attack_parameters.range,lasers=6,
 base_health=data.raw.car.tank.max_health,max_health=tank.max_health,laser_damage_modifier=laser.attack_parameters.damage_modifier,
 base_laser_damage_modifier=data.raw["electric-turret"]["laser-turret"].attack_parameters.damage_modifier,speed_multiplier=0.75}}})
