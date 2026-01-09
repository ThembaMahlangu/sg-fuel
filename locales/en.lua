local Translations = {
    progress = {
        refueling = 'Refueling...',
    },
    success = {
        refueled = 'Vehicle refueled',
        refueled_remove_nozzle = 'Vehicle refueled - Please remove the nozzle manually',
    },
    error = {
        no_money = 'You do not have enough money',
        no_vehicle = 'No vehicle found nearby',
        no_vehicles = 'No vehicles nearby',
        no_jerrycan = 'You do not have a jerry can',
        vehicle_full = 'The vehicle is already full of fuel',
        no_fuel_can = 'You do not have fuel in the jerry can',
        no_nozzle = 'There is no vehicle with the nozzle attached nearby',
        too_far = 'You are too far from the pump, the nozzle has been returned',
        wrong_side = 'The vehicle tank is on the other side',
    },
    target = {
        put_fuel = 'Put fuel',
        get_nozzle = 'Get nozzle',
        buy_jerrycan = 'Buy Jerry Can %{currency}%{price}',
        refill_jerrycan = 'Refill Jerry Can %{currency}%{price}',
        refill_fuel = 'Refill Fuel',
        nozzle_put = 'Attach Nozzle',
        nozzle_remove = 'Remove Nozzle',
        return_nozzle = 'Return Nozzle',
    },
    emergency = {
        refueling = 'Emergency Refueling Vehicle...',
        success = 'Vehicle refueled to full tank (%{litres} litres used)',
        collect_payment = 'Remember to collect payment from the customer',
        not_employee = 'You must be a gas station employee to use emergency refuel',
        no_vehicle = 'No vehicle found nearby',
        too_far = 'You need to be closer to the vehicle',
        wrong_side = 'You need to be on the left side of the vehicle (fuel tank side)',
        vehicle_full = 'Vehicle is already full of fuel',
        no_fuel = 'Your gas station does not have enough fuel reserves (%{available} litres available)',
        cancelled = 'Emergency refuel cancelled',
        authorized = 'Emergency refuel authorized',
        failed = 'Emergency refuel failed',
    },
    loadshedding = {
        active = 'Loadshedding is currently active! Gas pumps are offline.',
        pumps_offline = 'The gas pumps are currently offline due to loadshedding.',
        try_later = 'Please try again when power is restored.',
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})