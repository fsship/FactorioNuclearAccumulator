local load=table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
load.name="na-test-load"
load.energy_source={type="electric",usage_priority="secondary-input",buffer_capacity="1MJ",input_flow_limit="100MW",output_flow_limit="0W"}
load.energy_production="0W"; load.energy_usage="100MW"
local source=table.deepcopy(load); source.name="na-test-source"
source.energy_source={type="electric",usage_priority="primary-output",buffer_capacity="1GJ",input_flow_limit="0W",output_flow_limit="100MW"}
source.energy_production="100MW"; source.energy_usage="0W"
data:extend({load,source})
