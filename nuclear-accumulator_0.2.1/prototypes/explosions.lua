local rocket = assert(data.raw.projectile["atomic-rocket"], "Nuclear Accumulator: atomic-rocket missing")
local names = {"atomic-bomb-ground-zero-projectile", "atomic-bomb-wave"}
local damaging = {}; for _,name in ipairs(names) do damaging[name]=true end
local BATCH = 512 -- two native damage waves: at most 1,024 projectiles per tick globally
local function walk(t, fn)
 if type(t) ~= "table" then return end
 fn(t)
 for _, v in pairs(t) do if type(v)=="table" then walk(v,fn) end end
end
local found = {}
walk(rocket.action, function(t)
 if t.type=="area" and t.action_delivery and damaging[t.action_delivery.projectile] then
  assert(t.target_entities==false and t.repeat_count and t.radius, "Nuclear Accumulator: unsupported wave layout")
  assert(not found[t.action_delivery.projectile], "Nuclear Accumulator: duplicate damage wave")
  found[t.action_delivery.projectile]=table.deepcopy(t)
 end
end)
for _,name in ipairs(names) do assert(found[name], "Nuclear Accumulator: damage wave not found: "..name) end
local function carrier(name)
 local p=table.deepcopy(rocket); p.name=name
 p.animation=nil; p.shadow=nil; p.smoke=nil; p.acceleration=0
 p.turning_speed_increases_exponentially_with_projectile_speed=false
 p.collision_box=nil; p.collision_mask={layers={}}
 return p
end
for percent=0,100 do
 local m=1+9*percent/100
 local visual=carrier("na-blast-"..percent)
 -- Preserve the original center/visual effects, but never launch the damage population here.
 -- They are scheduled separately by control.lua, including deaths caused by another wave.
 walk(visual.action,function(t)
  if t.type=="nested-result" and t.action and t.action.type=="area" and
   t.action.action_delivery and damaging[t.action.action_delivery.projectile] then
   t.action.repeat_count=0
  elseif t.type=="area" and t.target_entities==false and t.action_delivery and
   t.action_delivery.type=="projectile" and not damaging[t.action_delivery.projectile] then
   t.radius=t.radius*m
  end
 end)
 data:extend({visual})
 for index,name in ipairs(names) do
  local wave=table.deepcopy(data.raw.projectile[name]); wave.name="na-"..name.."-"..percent
  walk(wave.action,function(t)
   if t.type=="damage" then
    if t.lower_distance_threshold then t.lower_distance_threshold=math.floor(t.lower_distance_threshold*m+0.5) end
    if t.upper_distance_threshold then t.upper_distance_threshold=math.floor(t.upper_distance_threshold*m+0.5) end
   end
  end)
  data:extend({wave})
  local total=math.floor(found[name].repeat_count*m*m+0.5)
  local counts={full=BATCH,tail=total%BATCH}
  for suffix,count in pairs(counts) do
   if count>0 then
    local launcher=carrier("na-batch-"..percent.."-"..index.."-"..suffix)
    local area=table.deepcopy(found[name])
    area.radius=area.radius*m; area.repeat_count=count
    area.action_delivery.projectile=wave.name
    launcher.action={type="direct",action_delivery={type="instant",target_effects={
     {type="nested-result",action=area}
    }}}
    launcher.final_action=nil -- no copied final effect may launch an unscheduled population
    data:extend({launcher})
   end
  end
 end
end
local waves={}
for i,name in ipairs(names) do waves[i]={count=found[name].repeat_count,radius=found[name].radius} end
data:extend({{type="mod-data",name="na-wave-metadata",data={
 inner=waves[1].radius,outer=waves[2].radius,batch_size=BATCH,waves=waves
}}})
