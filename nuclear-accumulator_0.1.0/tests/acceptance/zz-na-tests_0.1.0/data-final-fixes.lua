local damaging={["atomic-bomb-wave"]=true,["atomic-bomb-ground-zero-projectile"]=true}
local function walk(t,fn)
 if type(t)~="table" then return end
 fn(t);for _,v in pairs(t) do if type(v)=="table" then walk(v,fn) end end
end
local base={}
walk(data.raw.projectile["atomic-rocket"].action,function(t)
 if t.type=="area" and t.action_delivery and damaging[t.action_delivery.projectile] then
  base[t.action_delivery.projectile]={radius=t.radius,count=t.repeat_count,delivery=table.deepcopy(t.action_delivery)}
 end
end)
for p=0,100 do
 local m=1+9*p/100;local counts={}
 walk(data.raw.projectile["na-blast-"..p].action,function(t)
  if t.type=="area" and t.action_delivery and t.action_delivery.type=="projectile" then
   for name,b in pairs(base) do
    if t.action_delivery.projectile=="na-"..name.."-"..p then
     assert(math.abs(t.radius-b.radius*m)<1e-9)
     assert(t.repeat_count<=65535)
     assert(t.action_delivery.starting_speed==b.delivery.starting_speed)
     assert(t.action_delivery.starting_speed_deviation==b.delivery.starting_speed_deviation)
     counts[name]=(counts[name] or 0)+t.repeat_count
    end
   end
  end
 end)
 for name,b in pairs(base) do
  assert(counts[name]==math.floor(b.count*m*m+0.5))
  local wave=data.raw.projectile["na-"..name.."-"..p];local original=data.raw.projectile[name]
  assert(wave.acceleration==original.acceleration)
  assert(serpent.line(wave.speed_modifier)==serpent.line(original.speed_modifier))
  local a=wave.action[1];local o=original.action[1]
  assert(a.radius==o.radius and a.ignore_collision_condition==o.ignore_collision_condition)
  local d=a.action_delivery.target_effects;local od=o.action_delivery.target_effects
  assert(d.damage.amount==od.damage.amount and d.damage.type==od.damage.type)
  assert(d.lower_damage_modifier==od.lower_damage_modifier and d.upper_damage_modifier==od.upper_damage_modifier)
  assert(d.upper_distance_threshold==od.upper_distance_threshold*m)
 end
end
local recipe=data.raw.recipe["nuclear-accumulator"]
for i,ingredient in ipairs(data.raw.recipe["atomic-bomb"].ingredients) do
 assert(recipe.ingredients[i].name==ingredient.name and recipe.ingredients[i].amount==2*ingredient.amount)
end
log("NA STATIC PASS: 101 tiers, area-scaled populations, uint16 splitting, native speed/damage/radius/falloff, recipe")
