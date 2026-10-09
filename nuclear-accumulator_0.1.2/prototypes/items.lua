local icons = table.deepcopy(data.raw["electric-pole"]["nuclear-accumulator"].icons)
for _, name in ipairs({"nuclear-accumulator", "nuclear-accumulator-used"}) do
 data:extend({{type="item", name=name, icons=icons, subgroup="energy", order=(name=="nuclear-accumulator" and "e[accumulator]-z[a]" or "e[accumulator]-z[b]"),
 place_result=name, stack_size=10, localised_description={"item-description."..name}}})
end
local source = data.raw.recipe["atomic-bomb"]
local ingredients = table.deepcopy(source.ingredients)
for _, ingredient in ipairs(ingredients) do ingredient.amount = ingredient.amount * 2 end
data:extend({{type="recipe", name="nuclear-accumulator", enabled=false, energy_required=source.energy_required,
 ingredients=ingredients, results={{type="item",name="nuclear-accumulator",amount=1}}}})
