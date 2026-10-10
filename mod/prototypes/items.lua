local icons = table.deepcopy(data.raw["electric-pole"]["nuclear-accumulator"].icons)
data:extend({{type="item-with-tags", name="nuclear-accumulator", icons=icons, subgroup="energy",
 order="e[accumulator]-z[a]", place_result="nuclear-accumulator", stack_size=1, flags={"not-stackable"},
 localised_description={"item-description.nuclear-accumulator"}}})
local source = data.raw.recipe["atomic-bomb"]
local ingredients = table.deepcopy(source.ingredients)
for _, ingredient in ipairs(ingredients) do ingredient.amount = ingredient.amount * 2 end
data:extend({{type="recipe", name="nuclear-accumulator", enabled=false, energy_required=source.energy_required,
 ingredients=ingredients, results={{type="item",name="nuclear-accumulator",amount=1}}}})
