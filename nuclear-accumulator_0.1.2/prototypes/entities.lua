local function copy(kind, original, name)
  local p = table.deepcopy(data.raw[kind][original]); p.name = name
  return p
end
local icons = {{icon="__base__/graphics/icons/substation.png",icon_size=64},
 {icon="__base__/graphics/icons/atomic-bomb.png",icon_size=64,scale=0.25,shift={8,8}}}
local main = copy("electric-pole", "substation", "nuclear-accumulator")
main.icons = icons; main.icon = nil
main.localised_description = {"entity-description.nuclear-accumulator"}
main.max_health = 1000
main.minable = {mining_time=1, result="nuclear-accumulator-used"}
main.placeable_by = {item="nuclear-accumulator",count=1}
main.fast_replaceable_group = nil; main.next_upgrade = nil
main.map_color = {r=0.2,g=1,b=0.3}
local empty = {filename="__core__/graphics/empty.png",width=1,height=1}
local function hide(p)
  p.flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "not-in-kill-statistics"}
  p.hidden = true; p.selectable_in_game = false
  p.minable = nil; p.fast_replaceable_group = nil; p.next_upgrade = nil
  p.collision_box = {{0,0},{0,0}}; p.collision_mask = {layers={}}
  p.selection_box = {{0,0},{0,0}}
  p.corpse = nil; p.dying_explosion = nil; p.water_reflection = nil
  p.working_sound = nil; p.damaged_trigger_effect = nil
end
local battery = copy("accumulator", "accumulator", "na-battery"); hide(battery)
battery.energy_source.buffer_capacity = "36GJ"
battery.energy_source.input_flow_limit = "5MW"; battery.energy_source.output_flow_limit = "5MW"
battery.chargable_graphics = {picture=empty}; battery.circuit_connector = nil
local radar = copy("radar", "radar", "na-radar"); hide(radar)
radar.pictures = table.deepcopy(empty); radar.pictures.direction_count=1; radar.integration_patch = nil; radar.circuit_connector = nil
local output = copy("constant-combinator", "constant-combinator", "na-output"); hide(output)
output.sprites = {north=empty,east=empty,south=empty,west=empty}
output.activity_led_sprites = {north=empty,east=empty,south=empty,west=empty}
local used=table.deepcopy(main)
used.name="nuclear-accumulator-used"
used.localised_name={"entity-name.nuclear-accumulator"}
used.placeable_by={item="nuclear-accumulator-used",count=1}
data:extend({main,used,battery,radar,output})
