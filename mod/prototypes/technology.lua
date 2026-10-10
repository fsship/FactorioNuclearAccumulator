-- Unlock on the existing atomic bomb technology; never mutate its recipe or ammo.
table.insert(data.raw.technology["atomic-bomb"].effects, {type="unlock-recipe",recipe="nuclear-accumulator"})
