local t=assert(data.raw.car["na-enhanced-tank"])
local g=assert(data.raw["equipment-grid"][t.equipment_grid])
assert(g.width==15 and g.height==17 and t.max_health==data.raw.car.tank.max_health*5)
assert(t.allow_remote_driving and t.energy_source.fuel_inventory_size==0)
assert(t.energy_source.fuel_categories[1]=="na-electric-drive")
assert(data.raw.gun["na-tank-cannon"].attack_parameters.range==data.raw.gun["tank-cannon"].attack_parameters.range*4)
local laser=data.raw["active-defense-equipment"]["na-tank-laser"].attack_parameters
local ordinary=data.raw["electric-turret"]["laser-turret"].attack_parameters
assert(laser.range==ordinary.range*3 and laser.damage_modifier==ordinary.damage_modifier*10)
assert(laser.ammo_type.energy_consumption==ordinary.ammo_type.energy_consumption)
assert(data.raw["generator-equipment"]["na-tank-reactor"].power=="10MW")
assert(data.raw.radar["na-tank-radar"].energy_source.input_flow_limit=="0W")
for _,name in ipairs({"cannon-shell","explosive-cannon-shell","uranium-cannon-shell","explosive-uranium-cannon-shell"})do
 local a=data.raw.ammo["na-long-range-"..name];local b=data.raw.ammo[name]
 local original=b.ammo_type.action.action_delivery
 if original.max_range then assert(a.ammo_type.action.action_delivery.max_range==original.max_range*4)
 else assert(a.ammo_type.action.action_delivery.max_range==nil and a.ammo_type.target_type==b.ammo_type.target_type)end
 assert(a.ammo_type.action.action_delivery.projectile==b.ammo_type.action.action_delivery.projectile)
end
local target=table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
target.name="na-tank-test-target";target.max_health=1000000;target.resistances={};target.minable=nil
data:extend({target})
log("NA TANK STATIC PASS: 15x17, health x5, remote driving, electric-only buffer, native six-laser parameters, long cannon rounds")
local source=table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
source.name="na-tank-test-source"
source.energy_source={type="electric",usage_priority="primary-output",buffer_capacity="1GJ",input_flow_limit="0W",output_flow_limit="100MW"}
source.energy_production="100MW";source.energy_usage="0W"
data:extend({source})
