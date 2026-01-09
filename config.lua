-- NB!!
-- DO NOT RESTART THE SCRIPT, IT WILL BREAK COMPATIBILITY WITH OTHER SCRIPTS THAT USE THIS SCRIPT FOR ALL PLAYERS CONNECTED TO THE SERVER AND WILL REQUIRE ALL PLAYERS TO RECONNECT TO THE SERVER
-- DO NOT CHANGE THE NAME OF THE SCRIPT AS THAT WILL MAKE IT NOT WORK FULLY
-- PLEASE DO NOT OPEN A SUPPORT TICKET IF YOU BROKE ANY OF THE ABOVE, JUST ABIDE BY THESE RULES AND RESTART THE SERVER TO FIX IT

Config = Config or {}

-- LegacyFuel-style consumption system if you want to use the old consumption system
Config.UseLegacyFuelConsumption = true       -- Use RPM-based consumption like LegacyFuel
-- time_step * revolutions_per_minute * vehicle_fuel_consumption_multiplier * global_fuel_consumption_multiplier
Config.GlobalFuelConsumptionMultiplier = 14.0 -- Not used with legacy consumption
Config.SyncFuelBetweenPlayers = true         -- Sync fuel between players (if you want to sync fuel between players)
Config.FuelSyncTime = 10                     -- Time between syncs in seconds
Config.FuelPrice = 50            -- Price of the fuel per litre
Config.Currency = 'R'                 -- Currency symbol, example price will show R1000
Config.Debug = false                         -- Debug mode

-- Notification System ('qb' for qb-core notifications or 'ox_lib' for ox_lib notifications)
Config.NotificationProvider = 'ox_lib' -- 'qb' or 'ox_lib' (requires ox_lib if set to 'ox_lib')
-- Position names are automatically mapped between qb-core and ox_lib formats
-- Use qb-core format: 'left-center', 'right-center', 'top-center', 'bottom-center', 'top-left', 'top-right', 'bottom-left', 'bottom-right'
Config.NotificationPosition = 'left-center'

-- Fuel consumption based on RPM (LegacyFuel style)
-- The left part is at percentage RPM, and the right is how much fuel (divided by 10) you want to remove from the tank every second
Config.FuelUsage = {
	[1.0] = 1.4,
	[0.9] = 1.2,
	[0.8] = 1.0,
	[0.7] = 0.9,
	[0.6] = 0.8,
	[0.5] = 0.7,
	[0.4] = 0.5,
	[0.3] = 0.4,
	[0.2] = 0.2,
	[0.1] = 0.1,
	[0.0] = 0.0,
}

-- Class multipliers. If you want SUVs to use less fuel, you can change it to anything under 1.0, and vise versa.
Config.Classes = {
	[0] = 1.0, -- Compacts
	[1] = 1.0, -- Sedans
	[2] = 1.0, -- SUVs
	[3] = 1.0, -- Coupes
	[4] = 1.0, -- Muscle
	[5] = 1.0, -- Sports Classics
	[6] = 1.0, -- Sports
	[7] = 1.0, -- Super
	[8] = 1.0, -- Motorcycles
	[9] = 1.0, -- Off-road
	[10] = 1.0, -- Industrial
	[11] = 1.0, -- Utility
	[12] = 1.0, -- Vans
	[13] = 0.0, -- Cycles
	[14] = 1.0, -- Boats
	[15] = 1.0, -- Helicopters
	[16] = 1.0, -- Planes
	[17] = 1.0, -- Service
	[18] = 1.0, -- Emergency
	[19] = 1.0, -- Military
	[20] = 1.0, -- Commercial
	[21] = 1.0, -- Trains
}

-- Vehicle interaction method: 'target' for target systems (auto-detects qb-target or ox_target), '3dtext' for 3D text prompts
Config.VehicleInteractionMethod = '3dtext'  -- Options: 'target' or '3dtext'
-- Note: The script automatically detects which target resource you have (qb-target or ox_target)

Config.JerryCanCost = 5000                                                   -- Cost of the Jerry Can
Config.JerryCanLitre = 50                                                   -- Litres of the Jerry Can
Config.JerryCanRefillCost = Config.FuelPrice * Config.JerryCanLitre         -- Cost of the Jerry Can Rifill
Config.OrderFuelCost = 10000 -- Cost of the fuel per litre when ordering fuel (wholesale price) if you don't have the fuel tanker delivery jobs that works with this script.
Config.RefillTimePerLitre = 0.5 -- Time in seconds to refill 1 litre of fuel

-- Emergency Refuel System Configuration
Config.EmergencyRefuel = {
    Enabled = true,                 -- Enable/disable emergency refuel system
    RequireEmployeeJob = true,      -- Require player to be a gas station employee
    MaxDistance = 5.0,              -- Maximum distance to detect vehicles
    RequireFuelTankSide = true,     -- Require player to be on fuel tank side (left side) of vehicle
    MinFuelToRefuel = 1,            -- Minimum fuel level difference to allow refuel (prevents refueling already full vehicles)
    Command = 'emergencyrefuel',    -- Command to start emergency refuel
    HelpCommand = 'emergencyrefuelhelp', -- Command to show emergency refuel help
}

-- Loadshedding Integration Configuration
-- This prevents players from using gas pumps during loadshedding (power outages)
-- Set Enabled to false if you don't have the sg-loadshedding resource
Config.Loadshedding = {
    Enabled = false,                 -- Enable/disable loadshedding integration
    ResourceName = 'sg-loadshedding', -- Name of the loadshedding resource
    ExportName = 'isLoadsheddingActive', -- Export function name to check if loadshedding is active
}

-- Configure blips here. Turn both to false to disable blips all together.
-- ShowNearestGasStationOnly = Shows only the closest gas station blip (recommended)
-- ShowAllGasStations = Shows all gas stations on the map at once
Config.ShowNearestGasStationOnly = true
Config.ShowAllGasStations = false

-- Blip settings for the gas stations
-- see https://docs.fivem.net/docs/game-references/blips/
Config.Blip = {
    Sprite = 361,
    Color = 5,
    Scale = 0.7,
    Display = 4,
    ShortRange = true,
    Text = 'Gas Station'
}

-- All known pump models in game (I think)
Config.PumpModels = {
	-2007231801, 1339433404, 1694452750, 1933174915,
    -462817101, -469694731, -164877493
}

-- Gas stations with business ownership (business job name associated with each station)
Config.GasStations = {
	[vector3(49.4187, 2778.793, 58.043)] = 'express1', -- Not Real
	[vector3(263.894, 2606.463, 44.983)] = 'express1', -- Not Real
	[vector3(1039.958, 2671.134, 39.550)] = 'express1', -- Not Real
	[vector3(1207.260, 2660.175, 37.899)] = 'express1', -- Not Real
	[vector3(2539.685, 2594.192, 37.944)] = 'express1', -- Not Real
	[vector3(2679.858, 3263.946, 55.240)] = 'express1', -- Not Real
	[vector3(2005.055, 3773.887, 32.403)] = 'express1', -- Not Real
	[vector3(1687.156, 4929.392, 42.078)] = 'express1', -- Has Interior Not Real
	[vector3(1701.314, 6416.028, 32.763)] = 'express1', -- No Interior, Nice Outside
	[vector3(179.857, 6602.839, 31.868)] = 'express1', -- Engen Nkululeko/ Paleto
	[vector3(-94.4619, 6419.594, 31.489)] = 'express1', -- Not Real
	[vector3(-2554.996, 2334.40, 33.078)] = 'express1', -- No Interior
	[vector3(-1800.375, 803.661, 138.651)] = 'express1', -- Has Interior
	[vector3(-1437.622, -276.747, 46.207)] = 'express1', -- Has Interior
	[vector3(-2096.243, -320.286, 13.168)] = 'express1', -- Has Interior
	[vector3(-724.619, -935.1631, 19.213)] = 'express1', -- Has Interior, InCity
	[vector3(-526.019, -1211.003, 18.184)] = 'express1', -- Has Interior, InCity
	[vector3(-70.2148, -1761.792, 29.534)] = 'express1', -- Has Interior, InCity - Grove
	[vector3(265.648, -1261.309, 29.292)] = 'express1', -- InCity - Bridge
	[vector3(819.653, -1028.846, 26.403)] = 'express1', -- InCity - No Interior
	[vector3(1208.951, -1402.567, 35.224)] = 'express1', -- InCity - No Interior
	[vector3(1181.381, -330.847, 69.316)] = 'express1', -- Has Interior, Mirror Park
	[vector3(620.843, 269.100, 103.089)] = 'express1', -- No Interior, InCity
	[vector3(2581.321, 362.039, 108.468)] = 'express1', -- With 24/7 Interior
	[vector3(176.631, -1562.025, 29.263)] = 'express1', -- No Interior, InCity
	[vector3(-319.292, -1471.715, 30.549)] = 'express1', -- No Interior, InCity
	[vector3(-66.48, -2532.57, 6.14)] = 'express1', -- Not Real
	[vector3(1784.324, 3330.55, 41.253)] = 'express1', -- Not Real
	-- [vector3(229.32, -878.78, 29.4)] = 'express1', -- Legion Square
	-- [vector3(1119.45, -753.04, 57.81)] = 'express1', -- Autos
}
