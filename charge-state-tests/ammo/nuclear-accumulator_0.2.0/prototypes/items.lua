local icons=table.deepcopy(data.raw["electric-pole"]["nuclear-accumulator"].icons)
data:extend({{type="ammo-category",name="na-stored-charge"},
 {type="ammo",name="nuclear-accumulator",icons=icons,subgroup="energy",order="e[accumulator]-z[a]",
 place_result="nuclear-accumulator",stack_size=1,flags={"not-stackable"},magazine_size=36001,ammo_category="na-stored-charge",
 ammo_type={action={type="direct",action_delivery={type="instant",target_effects={type="damage",damage={amount=0,type="explosion"}}}}},
 localised_description={"item-description.nuclear-accumulator"}}})
local source = data.raw.recipe["atomic-bomb"]
local ingredients = table.deepcopy(source.ingredients)
for _, ingredient in ipairs(ingredients) do ingredient.amount = ingredient.amount * 2 end
data:extend({{type="recipe", name="nuclear-accumulator", enabled=false, energy_required=source.energy_required,
 ingredients=ingredients, results={{type="item",name="nuclear-accumulator",amount=1}}}})
