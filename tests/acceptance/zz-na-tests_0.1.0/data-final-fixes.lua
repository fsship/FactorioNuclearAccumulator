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
local meta=data.raw["mod-data"]["na-wave-metadata"].data
assert(meta.batch_size==512 and #meta.waves==2)
local names={"atomic-bomb-ground-zero-projectile","atomic-bomb-wave"}
for p=0,100 do
 local m=1+9*p/100
 walk(data.raw.projectile["na-blast-"..p].action,function(t)
  if t.type=="area" and t.action_delivery and damaging[t.action_delivery.projectile] then
   assert(t.repeat_count==0,"Visual carrier must not launch damaging projectiles")
  end
 end)
 for index,name in ipairs(names) do
  local b=base[name];local total=math.floor(b.count*m*m+0.5)
  local remainder=total%meta.batch_size
  local full=data.raw.projectile["na-batch-"..p.."-"..index.."-full"]
  local tail=data.raw.projectile["na-batch-"..p.."-"..index.."-tail"]
  local function verify(launcher,count)
   local a=launcher.action.action_delivery.target_effects[1].action
   assert(a.radius==b.radius*m and a.repeat_count==count)
   assert(a.target_entities==false and a.trigger_from_target==true)
   assert(a.action_delivery.projectile=="na-"..name.."-"..p)
   assert(a.action_delivery.starting_speed==b.delivery.starting_speed)
   assert(a.action_delivery.starting_speed_deviation==b.delivery.starting_speed_deviation)
  end
  verify(full,meta.batch_size)
  if remainder>0 then verify(tail,remainder) else assert(not tail) end
  assert(math.floor(total/meta.batch_size)*meta.batch_size+remainder==total)
  local wave=data.raw.projectile["na-"..name.."-"..p];local original=data.raw.projectile[name]
  assert(wave.acceleration==original.acceleration)
  assert(serpent.line(wave.speed_modifier)==serpent.line(original.speed_modifier))
  local a=wave.action[1];local o=original.action[1]
  assert(a.radius==o.radius and a.ignore_collision_condition==o.ignore_collision_condition)
  local d=a.action_delivery.target_effects;local od=o.action_delivery.target_effects
  assert(d.damage.amount==od.damage.amount and d.damage.type==od.damage.type)
  assert(d.lower_damage_modifier==od.lower_damage_modifier and d.upper_damage_modifier==od.upper_damage_modifier)
  assert(d.upper_distance_threshold==math.floor(od.upper_distance_threshold*m+0.5))
 end
end
local recipe=data.raw.recipe["nuclear-accumulator"]
for i,ingredient in ipairs(data.raw.recipe["atomic-bomb"].ingredients) do
 assert(recipe.ingredients[i].name==ingredient.name and recipe.ingredients[i].amount==2*ingredient.amount)
end
log("NA STATIC PASS: 101 tiers, exact area-scaled populations, bounded native batch launchers, native speed/damage/radius/falloff, recipe")
