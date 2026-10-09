local rocket = assert(data.raw.projectile["atomic-rocket"], "Nuclear Accumulator: atomic-rocket missing")
local damaging = { ["atomic-bomb-ground-zero-projectile"]=true, ["atomic-bomb-wave"]=true }
local function walk(t, fn)
 if type(t) ~= "table" then return end
 fn(t)
 for _, v in pairs(t) do if type(v)=="table" then walk(v,fn) end end
end
local found = {}
walk(rocket.action, function(t)
 if t.type=="area" and t.action_delivery and damaging[t.action_delivery.projectile] then
  assert(t.target_entities==false and t.repeat_count and t.radius, "Nuclear Accumulator: unsupported wave layout")
  found[t.action_delivery.projectile] = t.radius
 end
end)
for name in pairs(damaging) do assert(found[name], "Nuclear Accumulator: damage wave not found: "..name) end
-- repeat_count is uint16. Split large populations into equivalent independent native area triggers.
local function split(t)
 for key,v in pairs(t) do
  if type(v)=="table" then
   if v[1] then
    local rebuilt = {}
    for _,entry in ipairs(v) do
     if type(entry)=="table" then
      split(entry)
      if entry.type=="nested-result" and entry.action and (entry.action.repeat_count or 0)>65535 then
       local left = entry.action.repeat_count
       while left>0 do
        local part=table.deepcopy(entry); part.action.repeat_count=math.min(left,65535)
        rebuilt[#rebuilt+1]=part; left=left-part.action.repeat_count
       end
      else rebuilt[#rebuilt+1]=entry end
     else rebuilt[#rebuilt+1]=entry end
    end
    t[key]=rebuilt
   else split(v) end
  end
 end
end
for percent=0,100 do
 local m=1+9*percent/100
 local carrier=table.deepcopy(rocket)
 carrier.name="na-blast-"..percent
 carrier.animation=nil; carrier.shadow=nil; carrier.smoke=nil; carrier.acceleration=0; carrier.turning_speed_increases_exponentially_with_projectile_speed=false
 carrier.collision_box=nil; carrier.collision_mask={layers={}}
 for name in pairs(damaging) do
  local wave=table.deepcopy(data.raw.projectile[name]); wave.name="na-"..name.."-"..percent
  -- Preserve absolute per-hit damage and local radius, stretch the falloff across the enlarged wave.
  walk(wave.action, function(t)
   if t.type=="damage" then
    if t.lower_distance_threshold then t.lower_distance_threshold=t.lower_distance_threshold*m end
    if t.upper_distance_threshold then t.upper_distance_threshold=t.upper_distance_threshold*m end
   end
  end)
  data:extend({wave})
 end
 walk(carrier.action, function(t)
  if t.type=="area" and t.action_delivery and damaging[t.action_delivery.projectile] then
   local name=t.action_delivery.projectile
   t.radius=t.radius*m; t.repeat_count=math.floor(t.repeat_count*m*m+0.5)
   t.action_delivery.projectile="na-"..name.."-"..percent
  elseif t.type=="area" and t.target_entities==false and t.action_delivery and t.action_delivery.type=="projectile" then
   -- Visual branches spread farther without multiplying their population.
   t.radius=t.radius*m
  end
 end)
 split(carrier)
 data:extend({carrier})
end
-- A data-only metadata prototype avoids assuming that base radii remain 7 / 35 at runtime.
data:extend({{type="mod-data",name="na-wave-metadata",data={inner=found["atomic-bomb-ground-zero-projectile"],outer=found["atomic-bomb-wave"]}}})
