# SG-Fuel

A modern fuel system for FiveM combining the best of **qb-fuel** and **LegacyFuel**, featuring an enhanced NUI, player-owned gas stations, and flexible fuel consumption options.

## 📋 Description

SG-Fuel is an advanced fuel management script that provides seamless compatibility with both qb-fuel and LegacyFuel. Choose between traditional qb-fuel consumption mechanics or the more realistic RPM-based consumption system from LegacyFuel, all while enjoying a sleek, modern user interface.

## ✨ Features

### Core Features
- **Dual Consumption Systems**: Switch between qb-fuel style or RPM-based LegacyFuel consumption
- **Enhanced Modern NUI**: Beautiful, responsive user interface for all fuel interactions
- **Full Export Compatibility**: Drop-in replacement for both LegacyFuel and qb-fuel
- **Player-Owned Gas Stations**: Business ownership system with configurable job integration
- **Fuel Synchronization**: Real-time fuel sync between players

### Fuel Management
- **Jerry Cans**: Purchase, refill, and use portable fuel containers
- **Emergency Refuel**: Gas station employees can refuel vehicles on-site
- **Custom Fuel Pricing**: Configurable per-liter costs and wholesale pricing
- **Fuel Ordering**: Owners can order fuel for their stations
- **Vehicle Class Multipliers**: Different consumption rates for vehicle types

### User Experience
- **Multiple Interaction Methods**: Choose between qb-target, ox_target, or 3D text prompts
- **Smart Blip System**: Show nearest station only or all stations
- **Flexible Notifications**: Configurable notification provider (qb-core or ox_lib)
- **Configurable Currency**: Customize currency symbols

### Advanced Features
- **Loadshedding Integration**: Compatible with power outage systems (optional)
- **Debug Mode**: Built-in debugging tools for troubleshooting
- **Highly Configurable**: Extensive configuration options via `config.lua`

## 🔌 Exports

SG-Fuel provides the same exports as both LegacyFuel and qb-fuel, making it a perfect drop-in replacement.

### Available Exports

```lua
-- Get vehicle fuel level (0-100)
local fuel = exports['sg-fuel']:GetFuel(vehicle)
-- or for LegacyFuel compatibility
local fuel = exports['LegacyFuel']:GetFuel(vehicle)
-- or for qb-fuel compatibility
local fuel = exports['qb-fuel']:GetFuel(vehicle)

-- Set vehicle fuel level (0-100)
exports['sg-fuel']:SetFuel(vehicle, amount)
-- or for LegacyFuel compatibility
exports['LegacyFuel']:SetFuel(vehicle, amount)
-- or for qb-fuel compatibility
exports['qb-fuel']:SetFuel(vehicle, amount)
```

## 📦 Dependencies

### Required
- **[qb-core](https://github.com/qbcore-framework/qb-core)** - QBCore Framework
- **[oxmysql](https://github.com/overextended/oxmysql)** - MySQL wrapper

### Optional
- **[qb-target](https://github.com/qbcore-framework/qb-target)** or **[ox_target](https://github.com/overextended/ox_target)** - For target interaction method
- **[ox_lib](https://github.com/overextended/ox_lib)** - For ox_lib notifications (if using `ox_lib` as notification provider)

## 🚀 Installation

1. **Download** the resource and place it in your `resources` folder
2. **Rename** the folder to `sg-fuel` (important for compatibility)
3. **Import** the database tables from `install/jobs.lua` if needed
4. **Choose your optional dependencies** (install if desired):
   - **ox_lib** - If you want to use ox_lib notifications
   - **qb-target** or **ox_target** - If you want to use target interaction instead of 3D text
5. **Configure** the script in `config.lua` to your preferences:
   - Set `Config.NotificationProvider` to 'qb' or 'ox_lib'
   - Set `Config.VehicleInteractionMethod` to 'target' or '3dtext'
6. **Add** to your `server.cfg`:
```cfg
ensure sg-fuel
```

## ⚙️ Configuration

### Provider Auto-Detection

SG-Fuel automatically detects your installed resources:
- **Target System**: Automatically detects and uses either `qb-target` or `ox_target`
- **Notifications**: Configure to use either `qb-core` or `ox_lib` notifications

No additional setup required - just install your preferred resources and configure in `config.lua`!

### Fuel Consumption Modes

Choose your preferred fuel consumption system:

```lua
-- Use RPM-based consumption (LegacyFuel style)
Config.UseLegacyFuelConsumption = true

-- Or use qb-fuel style consumption
Config.UseLegacyFuelConsumption = false
```

### Key Configuration Options

```lua
Config.FuelPrice = 50                          -- Price per liter
Config.Currency = 'R'                          -- Currency symbol
Config.SyncFuelBetweenPlayers = true           -- Enable fuel sync
Config.ShowNearestGasStationOnly = true        -- Smart blip system
```

### Notification Provider

Choose between QBCore or ox_lib notifications:

```lua
Config.NotificationProvider = 'qb'             -- Options: 'qb' or 'ox_lib'
Config.NotificationPosition = 'left-center'    -- Notification position on screen
```

**Position Options**: `'left-center'`, `'right-center'`, `'top-center'`, `'bottom-center'`, `'top-left'`, `'top-right'`, `'bottom-left'`, `'bottom-right'`

**Note**: Position names are automatically mapped between qb-core and ox_lib formats. Just use the qb-core format names, and they will work with both notification systems!

### Interaction Method

Choose your preferred interaction system:

```lua
Config.VehicleInteractionMethod = '3dtext'     -- Options: 'target' or '3dtext'
-- If using 'target', the script automatically detects qb-target or ox_target
```

**Note**: The script automatically detects which target resource you have installed (qb-target or ox_target). No additional configuration needed!

### Emergency Refuel

Configure the emergency refuel system for gas station employees:

```lua
Config.EmergencyRefuel = {
    Enabled = true,
    RequireEmployeeJob = true,
    MaxDistance = 5.0,
    Command = 'emergencyrefuel',
}
```

### Player-Owned Stations

Set up business ownership for each gas station:

```lua
Config.GasStations = {
    [vector3(49.4187, 2778.793, 58.043)] = 'express1',
    [vector3(263.894, 2606.463, 44.983)] = 'express1',
    -- Add more stations...
}
```

## 🎮 Commands

- `/emergencyrefuel` - Gas station employees can refuel nearby vehicles
- `/emergencyrefuelhelp` - Display emergency refuel help

## ⚠️ Important Notes

- **DO NOT RESTART** the script while the server is running - it will break compatibility with other resources. Players will need to reconnect.
- **DO NOT RENAME** the resource folder from `sg-fuel` - this will break functionality
- If you encounter issues after breaking these rules, restart the entire server

## 🔄 Compatibility

This script is designed to work seamlessly with:

### Export Compatibility
- Resources calling **LegacyFuel** exports
- Resources calling **qb-fuel** exports

### Framework & Integrations
- **QBCore** framework (required)
- **qb-target** or **ox_target** (optional - required only if using 'target' interaction method)
- **ox_lib** (optional - required only if using 'ox_lib' as notification provider)
- **sg-loadshedding** (optional - for power outage integration)

## 📝 Credits

- **Original Base**: qb-fuel
- **Enhanced By**: sgMAGLERA
- **Combines Features From**: LegacyFuel & qb-fuel

## 📄 License

This resource is provided as-is. Refer to the fxmanifest.lua for escrow information.

## 🆘 Support

For support, please ensure you:
1. Have not renamed the resource
2. Have not restarted the script mid-session
3. Have correctly configured the `config.lua`
4. Have all required dependencies

---

**Version**: 1.0.0  
**Author**: sgMAGLERA
