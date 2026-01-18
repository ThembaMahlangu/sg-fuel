local QBCore = exports['qb-core']:GetCoreObject()
local CurrentPump = nil
local CurrentObjects = { nozzle = nil, rope = nil }
local CurrentVehicle = nil

local Debug = function(message)
    if Config.Debug then
        print('SG-FUEL: ' .. message)
    end
end

-- Notification System
-- Map qb-core notification positions to ox_lib positions
local function MapNotificationPosition(qbPosition)
    local positionMap = {
        ['left-center'] = 'center-left',
        ['right-center'] = 'center-right',
        ['top-center'] = 'top',
        ['bottom-center'] = 'bottom',
        ['top-left'] = 'top-left',
        ['top-right'] = 'top-right',
        ['bottom-left'] = 'bottom-left',
        ['bottom-right'] = 'bottom-right',
    }
    return positionMap[qbPosition] or qbPosition or 'top'
end

local Notify = function(message, type, duration)
    if Config.NotificationProvider == 'ox_lib' then
        lib.notify({
            title = 'Fuel Station',
            description = message,
            type = type or 'info',
            position = MapNotificationPosition(Config.NotificationPosition),
            duration = duration or 5000
        })
    else
        QBCore.Functions.Notify(message, type, duration)
    end
end

-- Forward declarations
local continueJerryCanRefuel
local continueNozzlePickup
local continueEmergencyRefuel
local CheckLoadshedding = function(callback)
    if not Config.Loadshedding or not Config.Loadshedding.Enabled then
        if callback then callback(false) end
        return false
    end
    
    QBCore.Functions.TriggerCallback('sg-fuel:server:checkLoadshedding', function(isActive)
        Debug('Loadshedding status from server: ' .. tostring(isActive))
        if callback then callback(isActive) end
    end)
end
local currentProgressData = {
    isActive = false,
    onFinish = nil,
    onCancel = nil
}

local ShowProgressBar = function(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    if currentProgressData.isActive then return end
    
    currentProgressData.isActive = true
    currentProgressData.onFinish = onFinish
    currentProgressData.onCancel = onCancel
    
    local ped = PlayerPedId()
    if animation and animation.animDict and animation.anim then
        loadAnimDict(animation.animDict)
        TaskPlayAnim(ped, animation.animDict, animation.anim, 2.0, 8.0, -1, animation.flags or 50, 0, false, false, false)
    end
    
    local propEntity = nil
    if prop and prop.model then
        local propModel = type(prop.model) == "string" and GetHashKey(prop.model) or prop.model
        RequestModel(propModel)
        while not HasModelLoaded(propModel) do
            Wait(10)
        end
        
        local coords = GetEntityCoords(ped)
        propEntity = CreateObject(propModel, coords.x, coords.y, coords.z, true, true, true)
        
        local bone = prop.bone or 60309
        local pos = prop.pos or vector3(0.0, 0.0, 0.0)
        local rot = prop.rot or vector3(0.0, 0.0, 0.0)
        
        AttachEntityToEntity(propEntity, ped, GetPedBoneIndex(ped, bone), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    end
    
    local disableThread = nil
    if disableControls then
        disableThread = CreateThread(function()
            while currentProgressData.isActive do
                if disableControls.disableMovement then
                    DisableControlAction(0, 30, true) -- MoveLeftRight
                    DisableControlAction(0, 31, true) -- MoveUpDown
                end
                if disableControls.disableCarMovement then
                    DisableControlAction(0, 63, true) -- VehicleMoveLeftRight
                    DisableControlAction(0, 64, true) -- VehicleMoveUpDown
                end
                if disableControls.disableMouse then
                    DisableControlAction(0, 1, true) -- LookLeftRight
                    DisableControlAction(0, 2, true) -- LookUpDown
                end
                if disableControls.disableCombat then
                    DisableControlAction(0, 24, true) -- Attack
                    DisableControlAction(0, 25, true) -- Aim
                    DisableControlAction(0, 47, true) -- Weapon
                end
                Wait(0)
            end
        end)
    end
    
    SendNUIMessage({
        action = 'show-progress',
        label = label,
        duration = duration,
        canCancel = canCancel or false
    })
    
    CreateThread(function()
        Wait(duration)
        if currentProgressData.isActive then
            currentProgressData.isActive = false
            
            ClearPedTasks(ped)
            if propEntity then
                DeleteEntity(propEntity)
            end
            
            SendNUIMessage({ action = 'hide-progress' })
            
            if currentProgressData.onFinish then
                currentProgressData.onFinish()
            end
            
            currentProgressData = { isActive = false, onFinish = nil, onCancel = nil }
        end
    end)
end

RegisterNUICallback('progress-complete', function(data, cb)
    if not currentProgressData.isActive then
        cb('ok')
        return
    end
    
    currentProgressData.isActive = false
    
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    
    if data.completed and currentProgressData.onFinish then
        currentProgressData.onFinish()
    elseif not data.completed and currentProgressData.onCancel then
        currentProgressData.onCancel()
    end
    
    currentProgressData = { isActive = false, onFinish = nil, onCancel = nil }
    cb('ok')
end)

local function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        
        local enum = {handle = iter, destructor = disposeFunc}
        setmetatable(enum, {
            __gc = function(enum)
                enum.destructor(enum.handle)
            end
        })
        
        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next
        
        enum.destructor(iter)
    end)
end

local function EnumerateObjects()
    return EnumerateEntities(FindFirstObject, FindNextObject, EndFindObject)
end

local DrawText3D = function(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

local loadAnimDict = function (dict)
    if not DoesAnimDictExist(dict) then return end
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(20)
    end
end

local removeObjects = function ()
    if currentFuelingData and currentFuelingData.isActive then
        SendNUIMessage({ action = 'stop-pump' })
        SetNuiFocus(false, false)
    end
    CurrentPump = nil
    if CurrentVehicle then
        Entity(CurrentVehicle).state:set('nozzleAttached', false, true)
        FreezeEntityPosition(CurrentVehicle, false)
        CurrentVehicle = nil
    end
    if CurrentObjects.nozzle then
        DeleteEntity(CurrentObjects.nozzle)
        CurrentObjects.nozzle = nil
        local ped = PlayerPedId()
        ClearPedTasks(ped)
        ResetPedMovementClipset(ped, 0)
        ResetPedWeaponMovementClipset(ped)
        ResetPedStrafeClipset(ped)
        ClearPedSecondaryTask(ped)
    end
    if CurrentObjects.rope then
        DeleteRope(CurrentObjects.rope)
        RopeUnloadTextures()
        CurrentObjects.rope = nil
    end
    LocalPlayer.state:set('hasNozzle', false, true)
end

local refuelVehicle = function (veh)
    if not veh or not DoesEntityExist(veh) then return Notify(Lang:t('error.no_vehicle')) end

    CheckLoadshedding(function(isActive)
        if isActive then
            Notify(Lang:t('loadshedding.active'), 'error')
            Notify(Lang:t('loadshedding.pumps_offline'), 'error')
            return
        end
        
        continueJerryCanRefuel(veh)
    end)
end

continueJerryCanRefuel = function(veh)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    local canLiter = GetAmmoInPedWeapon(ped, `WEAPON_PETROLCAN`)
    local vehFuel = math.floor(exports['sg-fuel']:GetFuel(veh) or 0)

    if canLiter == 0 then return Notify(Lang:t('error.no_fuel_can'), 'error') end
    if vehFuel == 100 then return Notify(Lang:t('error.vehicle_full'), 'error') end

    local liter = canLiter + vehFuel > 100 and 100 - vehFuel or canLiter

    loadAnimDict('timetable@gardener@filling_can')
    TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 2.0, 8.0, -1, 50, 0, false, false, false)

    ShowProgressBar('fueling_vehicle', Lang:t('progress.refueling'), Config.RefillTimePerLitre * liter * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('sg-fuel:server:setCanFuel', canLiter - liter)
        SetPedAmmo(ped, `WEAPON_PETROLCAN`, canLiter - liter)
        exports['sg-fuel']:SetFuel(veh, vehFuel + liter)
        Notify(Lang:t('success.refueled'), 'success')
        ClearPedTasks(ped)
    end, function() end)
end

local grabFuelFromPump = function(ent)
    CurrentPump = ent
    if not CurrentPump then return end

    CheckLoadshedding(function(isActive)
        if isActive then
            CurrentPump = nil
            Notify(Lang:t('loadshedding.active'), 'error')
            Notify(Lang:t('loadshedding.pumps_offline'), 'error')
            Notify(Lang:t('loadshedding.try_later'), 'primary')
            return
        end
        
        continueNozzlePickup()
    end)
end

continueNozzlePickup = function()
local pumpCoords = GetEntityCoords(CurrentPump)
    local pumpCoords = GetEntityCoords(CurrentPump)
    local business = nil
    for coords, biz in pairs(Config.GasStations) do
        if #(pumpCoords - coords) < 30.0 then
            business = biz
            break
        end
    end

    if business then
        local maxFuelNeeded = 100 -- Maximum possible fuel that could be needed
        local validationResult = nil
        
        QBCore.Functions.TriggerCallback('sg-fuel:server:validateBusinessFuelCallback', function(success)
            validationResult = success
        end, business, maxFuelNeeded)
        
        local timeout = 0
        while validationResult == nil and timeout < 50 do -- 5 second timeout
            Wait(100)
            timeout = timeout + 1
        end
        
        if not validationResult then
            CurrentPump = nil
            if validationResult == false then
                Notify('This gas station is out of fuel!', 'error')
            else
                Notify('Gas station unavailable!', 'error')
            end
            return
        end
    end

	local ped = PlayerPedId()
	local pump = GetEntityCoords(CurrentPump)
    loadAnimDict('anim@am_hold_up@male')
    TaskPlayAnim(ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, -1, 50, 0, false, false, false)
    Wait(300)

    CurrentObjects.nozzle = CreateObject('prop_cs_fuel_nozle', 0, 0, 0, true, true, true)

    AttachEntityToEntity(CurrentObjects.nozzle, ped, GetPedBoneIndex(ped, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)
    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
    end

    CurrentObjects.rope = AddRope(pump.x, pump.y, pump.z - 1.0, 0.0, 0.0, 0.0, 3.5, 3, 2000.0, 0.0, 2.0, false, false, false, 1.0, true)
    ActivatePhysics(CurrentObjects.rope)
    Wait(50)

    local nozzlePos = GetOffsetFromEntityInWorldCoords(CurrentObjects.nozzle, 0.0, -0.033, -0.195)
    AttachEntitiesToRope(CurrentObjects.rope, CurrentPump, CurrentObjects.nozzle, pump.x, pump.y, pump.z + 1.45, nozzlePos.x, nozzlePos.y + 0.02, nozzlePos.z, 5.0, false, false, '', '')
    LocalPlayer.state:set('hasNozzle', true, true)

    CreateThread(function()
        while DoesRopeExist(CurrentObjects.rope) do
            Wait(500)
            if RopeGetDistanceBetweenEnds(CurrentObjects.rope) > 8.0 then
                Notify(Lang:t('error.too_far'), 'error')
                break
            end
        end

        removeObjects()
    end)
end

local showFuelInputMenu = function()
    if not CurrentPump then return end
    local veh, dis = QBCore.Functions.GetClosestVehicle()
    if not veh or veh == -1 then return end
    if dis > 5 then return end
    
    local pumpCoords = GetEntityCoords(CurrentPump)
    local business = nil
    local stationName = "Gas Station"
    for coords, biz in pairs(Config.GasStations) do
        if #(pumpCoords - coords) < 30.0 then
            business = biz
            stationName = QBCore.Shared.Jobs[biz] and QBCore.Shared.Jobs[biz].label or biz:gsub("^%l", string.upper) .. " Station"
            break
        end
    end

    if business then
        local maxPossibleFuel = 100 - math.floor(exports['sg-fuel']:GetFuel(veh) or 0)
        local validationResult = nil
        
        QBCore.Functions.TriggerCallback('sg-fuel:server:validateBusinessFuelCallback', function(success)
            validationResult = success
        end, business, maxPossibleFuel)
        
        local timeout = 0
        while validationResult == nil and timeout < 30 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if not validationResult then
            if validationResult == false then
                Notify('This gas station is out of fuel!', 'error')
            end
            return
        end
    end

    -- Get business price if available
    local fuelPrice = Config.FuelPrice
    if business then
        QBCore.Functions.TriggerCallback('sg-fuel:server:getCurrentPrice', function(price)
            SendNUIMessage({
                action = 'show-input',
                price = price,
                currentFuel = math.floor(exports['sg-fuel']:GetFuel(veh) or 0),
                stationName = stationName,
                currency = Config.Currency,
            })
            SetNuiFocus(true, true)
        end, business)
    else
        SendNUIMessage({
            action = 'show-input',
            price = fuelPrice,
            currentFuel = math.floor(exports['sg-fuel']:GetFuel(veh) or 0),
            stationName = stationName,
            currency = Config.Currency,
        })
        SetNuiFocus(true, true)
    end
end

local getVehicleCurrentSide = function(veh)
    local pump = CurrentPump
    if not pump or not DoesEntityExist(pump) then return end

    local pumpPos = GetEntityCoords(pump)
    local vehPos = GetEntityCoords(veh)
    local vehForward = GetEntityForwardVector(veh)

    local toPump = {
        x = pumpPos.x - vehPos.x,
        y = pumpPos.y - vehPos.y
    }

    local crossZ = vehForward.x * toPump.y - vehForward.y * toPump.x

    if crossZ > 0 then
        return "left"
    else
        return "right"
    end
end

local nozzleToVehicle = function (veh)
    if getVehicleCurrentSide(veh) ~= 'left' then return Notify(Lang:t('error.wrong_side'), 'error') end

    if GetIsVehicleEngineRunning(veh) then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local vehCoords = GetEntityCoords(veh)
        
        removeObjects()
        AddExplosion(vehCoords.x, vehCoords.y, vehCoords.z, 2, 100.0, true, false, true)
        SetEntityHealth(ped, 0)
        Notify('The engine was running! The fuel ignited and caused an explosion!', 'error')
        
        return
    end

    local ped = PlayerPedId()
    
    ResetPedMovementClipset(ped, 0)
    ResetPedWeaponMovementClipset(ped)
    ResetPedStrafeClipset(ped)
    ClearPedSecondaryTask(ped)
    
    local isBike = false
    local nozzleModifiedPosition = {
        x = 0.0,
        y = 0.0,
        z = 0.0
    }
    local tankBone = -1
    local vehClass = GetVehicleClass(veh)

    if vehClass == 8 then
        tankBone = GetEntityBoneIndexByName(veh, "petrolcap")
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(veh, "petroltank")
        end
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(veh, "engine")
        end
        isBike = true
    elseif vehClass ~= 13 then
        tankBone = GetEntityBoneIndexByName(veh, "petrolcap")
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(veh, "petroltank_l")
        end
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(veh, "hub_lr")
        end
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(veh, "handle_dside_r")
            nozzleModifiedPosition.x = 0.1
            nozzleModifiedPosition.y = -0.5
            nozzleModifiedPosition.z = -0.6
        end
    end

    local wheelPos = GetWorldPositionOfEntityBone(veh, GetEntityBoneIndexByName(veh, "wheel_lr"))
    local wheelRPos = GetOffsetFromEntityGivenWorldCoords(veh, wheelPos.x, wheelPos.y, wheelPos.z)

    DetachEntity(CurrentObjects.nozzle, false, true)
    local dimMin, dimMax = GetModelDimensions(GetEntityModel(veh))

    local diff = dimMax.z - wheelRPos.z

    local divisor = (dimMax - dimMin).z < 1.4 and (1.87 * (dimMax - dimMin).z) / 1.24 or (2.7 * (dimMax - dimMin).z) / 2.3
    local zCoords = diff / divisor

    LocalPlayer.state:set('hasNozzle', false, true)

    if isBike then
        AttachEntityToEntity(CurrentObjects.nozzle, veh, tankBone, 0.0 + nozzleModifiedPosition.x, -0.2 + nozzleModifiedPosition.y, 0.2 + nozzleModifiedPosition.z, -80.0, 0.0, 0.0, true, true, false, false, 1, true)
    else
        AttachEntityToEntity(CurrentObjects.nozzle, veh, tankBone, -0.18 + nozzleModifiedPosition.x, 0.0 + nozzleModifiedPosition.y, zCoords, -125.0, -90.0, -90.0, true, true, false, false, 1, true)
    end

    Entity(veh).state:set('nozzleAttached', true, true)
    CurrentVehicle = veh
    FreezeEntityPosition(CurrentObjects.nozzle, true)
    FreezeEntityPosition(CurrentVehicle, true)

    Wait(500)
    showFuelInputMenu()

    CreateThread((function ()
        while DoesEntityExist(CurrentObjects.nozzle) and DoesEntityExist(CurrentVehicle) and Entity(veh).state.nozzleAttached do
            Wait(1000)
        end

        removeObjects()
    end))
end

local refillVehicleFuel = function (liter)
    if not liter then return end
    if not CurrentPump then return end
    local veh, dis = QBCore.Functions.GetClosestVehicle()
    if not veh or veh == -1 or not DoesEntityExist(veh) then return Notify(Lang:t('error.no_nozzle'), 'error') end
    if not Entity(veh).state['nozzleAttached'] then return Notify(Lang:t('error.no_nozzle'), 'error') end
    if dis > 5 then return end

    local pumpCoords = GetEntityCoords(CurrentPump)
    local business = nil
    for coords, biz in pairs(Config.GasStations) do
        if #(pumpCoords - coords) < 30.0 then
            business = biz
            break
        end
    end

    if business then
        local validationResult = nil
        
        QBCore.Functions.TriggerCallback('sg-fuel:server:validateBusinessFuelCallback', function(success)
            validationResult = success
        end, business, liter)
        
        -- Wait for validation
        local timeout = 0
        while validationResult == nil and timeout < 30 do -- 3 second timeout
            Wait(100)
            timeout = timeout + 1
        end
        
        if not validationResult then
            if validationResult == false then
                Notify('This gas station is out of fuel!', 'error')
            else
                Notify('Validation timeout!', 'error')
            end
            return
        end
    end

    -- Get business price if available
    local fuelPrice = Config.FuelPrice
    if business then
        local priceResult = nil
        QBCore.Functions.TriggerCallback('sg-fuel:server:getCurrentPrice', function(price)
            priceResult = price
        end, business)
        
        local timeout = 0
        while priceResult == nil and timeout < 30 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if priceResult then
            fuelPrice = priceResult
        end
    end

    local totalCost = liter * fuelPrice
    local cash = QBCore.PlayerData.money.cash or 0
    local bank = QBCore.PlayerData.money.bank or 0
    local totalMoney = cash + bank
    
    Debug('Fuel refill check - Litres: ' .. liter .. ', Price per litre: ' .. fuelPrice .. ', Total cost: ' .. totalCost .. ', Cash: ' .. cash .. ', Bank: ' .. bank .. ', Total: ' .. totalMoney)
    
    if totalMoney < totalCost then 
        return Notify(Lang:t('error.no_money'), 'error') 
    end

    local ped = PlayerPedId()
    ClearPedTasks(ped)
    TaskTurnPedToFaceEntity(ped, veh, 1000)

    TaskGoStraightToCoordRelativeToEntity(ped, CurrentObjects.nozzle, 0.0, 0.0, 0.0, 1.0, 1000)
    Wait(1500)

    QBCore.Functions.LookAtEntity(veh, 5000, 5.0)
    Wait(500)

    loadAnimDict('timetable@gardener@filling_can')
    TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 2.0, 8.0, -1, 50, 0, false, false, false)

    ShowProgressBar('fueling_vehicle', Lang:t('progress.refueling'), Config.RefillTimePerLitre * liter * 1000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        local success = nil
    QBCore.Functions.TriggerCallback('sg-fuel:server:refillVehicle', function(result)
            success = result
        end, liter, business)
        
        -- Wait for server response
        local timeout = 0
        while success == nil and timeout < 30 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if not success then 
            return Notify(Lang:t('error.no_money'), 'error') 
        end
        
        exports['sg-fuel']:SetFuel(veh, math.floor(exports['sg-fuel']:GetFuel(veh) or 0) + liter)
        Notify(Lang:t('success.refueled_remove_nozzle'), 'success')
        ClearPedTasks(ped)
    end, function()
        removeObjects()
    end)
end

local showFuelMenu = function ()
    showFuelInputMenu()
end

local hideFuelMenu = function ()
    SendNUIMessage({
        action = 'hide'
    })
    SetNuiFocus(false, false)
end

local createBlip = function(coords)
	local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

	SetBlipSprite(blip, Config.Blip.Sprite)
	SetBlipScale(blip, Config.Blip.Scale)
	SetBlipColour(blip, Config.Blip.Color)
	SetBlipDisplay(blip, Config.Blip.Display)
	SetBlipAsShortRange(blip, Config.Blip.ShortRange)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(Config.Blip.Text)
	EndTextCommandSetBlipName(blip)

	return blip
end


-- Target System Compatibility
local targetResource = nil
local function GetTargetResource()
    if targetResource then return targetResource end
    
    if GetResourceState('ox_target') == 'started' then
        targetResource = 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then
        targetResource = 'qb-target'
    end
    
    return targetResource
end

local function AddTargetModel(models, options, distance)
    local target = GetTargetResource()
    if not target or not options or #options == 0 then return end

    if target == 'ox_target' then
        local oxOptions = {}

        for i, opt in ipairs(options) do
            oxOptions[#oxOptions + 1] = {
                name = opt.name or ('sg_fuel_model_' .. i),
                label = opt.label,
                icon = opt.icon,
                distance = distance or opt.distance or 2.0,
                canInteract = opt.canInteract,
                onSelect = function(data)
                    if opt.action then
                        opt.action(data.entity)
                    end
                end
            }
        end

        exports.ox_target:addModel(models, oxOptions)

    else
        exports['qb-target']:AddTargetModel(models, {
            options = options,
            distance = distance or 2.0
        })
    end
end

local function AddGlobalVehicle(options, distance)
    local target = GetTargetResource()
    if not target or not options or #options == 0 then return end

    if target == 'ox_target' then
        local oxOptions = {}

        for i, opt in ipairs(options) do
            oxOptions[#oxOptions + 1] = {
                name = opt.name or ('sg_fuel_vehicle_' .. i),
                label = opt.label,
                icon = opt.icon,
                distance = distance or opt.distance or 3.0,
                canInteract = opt.canInteract,
                onSelect = function(data)
                    if opt.action then
                        opt.action(data.entity)
                    end
                end
            }
        end

        exports.ox_target:addGlobalVehicle(oxOptions)

    else
        exports['qb-target']:AddGlobalVehicle({
            options = options,
            distance = distance or 3.0
        })
    end
end

local function RemoveGlobalVehicle(name)
    local target = GetTargetResource()
    if not target then return end

    if target == 'ox_target' then
        exports.ox_target:removeGlobalVehicle(name)
    else
        exports['qb-target']:RemoveGlobalVehicle(name)
    end
end

local setUpTarget = function ()
    local pumpOptions = {
        {
            num = 1,
            icon = 'fa-solid fa-gas-pump',
            label = Lang:t('target.get_nozzle'),
            canInteract = function()
                return CurrentObjects.nozzle == nil
            end,
            action = grabFuelFromPump,
            onSelect = grabFuelFromPump  -- ox_target compatibility
        },
        {
            num = 2,
            icon = 'fa-solid fa-gas-pump',
            label = Lang:t('target.return_nozzle'),
            canInteract = function()
                return LocalPlayer.state['hasNozzle']
            end,
            action = removeObjects,
            onSelect = removeObjects  -- ox_target compatibility
        },
        {
            num = 3,
            icon = 'fa-solid fa-gas-pump',
            label = Lang:t('target.put_fuel'),
            canInteract = function()
                return CurrentPump ~= nil
            end,
            action = showFuelMenu,
            onSelect = showFuelMenu  -- ox_target compatibility
        },
        {
            num = 4,
            type = 'server',
            event = 'sg-fuel:server:buyJerryCan',
            icon = 'fa-solid fa-jar',
            label = Lang:t('target.buy_jerrycan', { price = Config.JerryCanCost, currency = Config.Currency }),
        },
        {
            num = 5,
            type = 'server',
            event = 'sg-fuel:server:refillJerryCan',
            icon = 'fa-solid fa-arrows-rotate',
            label = Lang:t('target.refill_jerrycan', { price = Config.JerryCanCost, currency = Config.Currency }),
            canInteract = function()
                return GetSelectedPedWeapon(PlayerPedId()) == `WEAPON_PETROLCAN`
            end
        }
    }

    for _, hash in pairs(Config.PumpModels) do
        AddTargetModel(hash, pumpOptions, 1.5)
    end

    if Config.VehicleInteractionMethod == 'target' then
        local vehicleOptions = {
            name = 'sg-fuel-vehicle-targets',
            options = {
                {
                    num = 1,
                    icon = 'fa-solid fa-gas-pump',
                    label = Lang:t('target.refill_fuel'),
                    action = refuelVehicle,
                    onSelect = refuelVehicle,  -- ox_target compatibility
                    canInteract = function()
                        return GetSelectedPedWeapon(PlayerPedId()) == `WEAPON_PETROLCAN`
                    end
                },
                {
                    num = 2,
                    icon = 'fa-solid fa-gas-pump',
                    label = Lang:t('target.nozzle_put'),
                    action = nozzleToVehicle,
                    onSelect = nozzleToVehicle,  -- ox_target compatibility
                    canInteract = function()
                        return LocalPlayer.state['hasNozzle']
                    end
                },
                {
                    num = 3,
                    icon = 'fa-solid fa-gas-pump',
                    label = Lang:t('target.nozzle_remove'),
                    action = removeObjects,
                    onSelect = removeObjects,  -- ox_target compatibility
                    canInteract = function(ent)
                        return Entity(ent).state['nozzleAttached']
                    end
                }
            },
            distance = 3
        }
        
        AddGlobalVehicle(vehicleOptions.options, vehicleOptions.distance)
    end
end

local Round = function(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(num * mult + 0.5) / mult
end

local ManageFuelUsage = function(vehicle)
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    
    if IsVehicleEngineOn(vehicle) then
        local currentFuel = GetVehicleFuelLevel(vehicle)
        local rpmValue = Round(GetVehicleCurrentRpm(vehicle), 1)
        local fuelUsage = Config.FuelUsage[rpmValue] or 0
        local classMultiplier = Config.Classes[GetVehicleClass(vehicle)] or 1.0
        local newFuel = currentFuel - (fuelUsage * classMultiplier / 10)
        
        if newFuel < 0 then newFuel = 0 end
        if newFuel > 100 then newFuel = 100 end
        
        SetVehicleFuelLevel(vehicle, newFuel)
        if Config.SyncFuelBetweenPlayers then 
            Entity(vehicle).state:set('sg-fuel', newFuel + 0.0, true) 
        end
    end
end

local init = function ()
    if Config.UseLegacyFuelConsumption then
        Debug('Using LegacyFuel-style RPM-based consumption')
    else
        SetFuelConsumptionState(true)
        SetFuelConsumptionRateMultiplier(Config.GlobalFuelConsumptionMultiplier)
    end

    if Config.VehicleInteractionMethod == '3dtext' then
        RemoveGlobalVehicle('sg-fuel-vehicle-targets')
    end

    setUpTarget()

    SendNUIMessage({
        action = 'setLanguage',
        language = GetConvar('qb_locale', 'en')
    })
end

if Config.VehicleInteractionMethod == '3dtext' then
    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            local vehicle = QBCore.Functions.GetClosestVehicle()
            if vehicle and vehicle ~= -1 then
                local vehCoords = GetEntityCoords(vehicle)
                local distance = #(coords - vehCoords)
                
                if distance < 3.0 then
                    sleep = 0
                    local canInteract = false
                    local interactionText = ""
                    
                    if GetSelectedPedWeapon(ped) == `WEAPON_PETROLCAN` then
                        local canLiter = GetAmmoInPedWeapon(ped, `WEAPON_PETROLCAN`)
                        local vehFuel = math.floor(exports['sg-fuel']:GetFuel(vehicle) or 0)
                        
                        if canLiter > 0 and vehFuel < 100 then
                            canInteract = true
                            interactionText = "Press ~g~E~w~ to refuel vehicle"
                        elseif canLiter == 0 then
                            interactionText = "~r~Jerry can is empty"
                        elseif vehFuel == 100 then
                            interactionText = "~r~Vehicle is full"
                        end
                    end
                    
                    if LocalPlayer.state['hasNozzle'] then
                        if not Entity(vehicle).state['nozzleAttached'] then
                            canInteract = true
                            interactionText = "Press ~g~E~w~ to attach nozzle"
                        end
                    end
                    
                    if Entity(vehicle).state['nozzleAttached'] then
                        canInteract = true
                        interactionText = "Press ~g~E~w~ to remove nozzle"
                    end
                    
                    if interactionText ~= "" then
                        DrawText3D(vehCoords.x, vehCoords.y, vehCoords.z + 1.0, interactionText)
                        
                        if canInteract and IsControlJustReleased(0, 38) then
                            if GetSelectedPedWeapon(ped) == `WEAPON_PETROLCAN` then
                                refuelVehicle(vehicle)
                            elseif LocalPlayer.state['hasNozzle'] and not Entity(vehicle).state['nozzleAttached'] then
                                nozzleToVehicle(vehicle)
                            elseif Entity(vehicle).state['nozzleAttached'] then
                                local maxDistance = 10.0
                                local playerCoords = GetEntityCoords(ped)
                                local vehCoords = GetEntityCoords(vehicle)
                                local nozzleRemoved = false
                                
                                for obj in EnumerateObjects() do
                                    if DoesEntityExist(obj) then
                                        local model = GetEntityModel(obj)
                                        if model == GetHashKey('prop_cs_fuel_nozle') then
                                            local objCoords = GetEntityCoords(obj)
                                            if #(vehCoords - objCoords) < maxDistance then
                                                DeleteEntity(obj)
                                                nozzleRemoved = true
                                                break
                                            end
                                        end
                                    end
                                end
                                
                                Entity(vehicle).state:set('nozzleAttached', false, true)
                                FreezeEntityPosition(vehicle, false)
                                RopeUnloadTextures()
                                
                                if nozzleRemoved then
                                    Notify('Nozzle removed and returned to pump', 'success')
                                else
                                    Notify('Nozzle disconnected from vehicle', 'success')
                                end

                                if CurrentVehicle and CurrentVehicle == vehicle then
                                    if currentFuelingData and currentFuelingData.isActive then
                                        SendNUIMessage({ action = 'stop-pump' })
                                        SetNuiFocus(false, false)
                                    end
                                    removeObjects()
                                end
                            end
                        end
                    end
                end
            end
            
            Wait(sleep)
        end
    end)
end

local currentFuelingData = {
    isActive = false,
    targetLitres = 0,
    business = nil,
    pricePerLitre = 0
}

local startFuelingProcess = function(liter)
    if not CurrentPump or not CurrentVehicle then return end
    if not Entity(CurrentVehicle).state['nozzleAttached'] then return end
    
    local pumpCoords = GetEntityCoords(CurrentPump)
    local business = nil
    local stationName = "Gas Station"
    for coords, biz in pairs(Config.GasStations) do
        if #(pumpCoords - coords) < 30.0 then
            business = biz
            stationName = QBCore.Shared.Jobs[biz] and QBCore.Shared.Jobs[biz].label or biz:gsub("^%l", string.upper) .. " Station"
            break
        end
    end

    if business then
        local validationResult = nil
        
        QBCore.Functions.TriggerCallback('sg-fuel:server:validateBusinessFuelCallback', function(success)
            validationResult = success
        end, business, liter)
        
        -- Wait for validation
        local timeout = 0
        while validationResult == nil and timeout < 30 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if not validationResult then
            if validationResult == false then
                Notify('This gas station is out of fuel!', 'error')
            else
                Notify('Validation timeout!', 'error')
            end
            hideFuelMenu()
            return
        end
    end

    -- Get business price if available
    local fuelPrice = Config.FuelPrice
    if business then
        QBCore.Functions.TriggerCallback('sg-fuel:server:getCurrentPrice', function(price)
            if price then
                fuelPrice = price
            end
            
            currentFuelingData = {
                isActive = true,
                targetLitres = liter,
                business = business,
                pricePerLitre = fuelPrice,
                vehicle = CurrentVehicle
            }
            
            SendNUIMessage({
                action = 'start-pump',
                targetLitres = liter,
                pricePerLitre = fuelPrice,
                stationName = stationName,
                currency = Config.Currency,
            })
            SetNuiFocus(false, false)
        end, business)
    else
        currentFuelingData = {
            isActive = true,
            targetLitres = liter,
            business = business,
            pricePerLitre = fuelPrice,
            vehicle = CurrentVehicle
        }
        
        SendNUIMessage({
            action = 'start-pump',
            targetLitres = liter,
            pricePerLitre = fuelPrice,
            stationName = stationName,
            currency = Config.Currency,
        })
        SetNuiFocus(false, false)
    end
end

local completeFuelingProcess = function(actualLitres, completed)
    currentFuelingData.isActive = false
    local veh = currentFuelingData.vehicle or CurrentVehicle
    
    if actualLitres > 0 then
        local success = nil
        local pumpedLitres = math.floor(actualLitres)
        local pricePerLitre = currentFuelingData.pricePerLitre or Config.FuelPrice
        local totalCost = pumpedLitres * pricePerLitre
        QBCore.Functions.TriggerCallback('sg-fuel:server:refillVehicle', function(result)
            success = result
        end, pumpedLitres, currentFuelingData.business)
        
        local timeout = 0
        while success == nil and timeout < 30 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if success and veh and DoesEntityExist(veh) then
            local currentFuel = math.floor(exports['sg-fuel']:GetFuel(veh) or 0)
            exports['sg-fuel']:SetFuel(veh, currentFuel + pumpedLitres)
            
            if completed then
                Notify(('Refueled %d litres for %s%d - Please remove the nozzle manually'):format(pumpedLitres, Config.Currency, totalCost), 'success')
            else
                Notify(('Fueling stopped. Added %d litres for %s%d'):format(pumpedLitres, Config.Currency, totalCost), 'success')
            end
        else
            Notify(Lang:t('error.no_money'), 'error')
        end
    end
    
    currentFuelingData = {
        isActive = false,
        targetLitres = 0,
        business = nil,
        pricePerLitre = 0,
        vehicle = nil
    }
end

CreateThread(function()
    while true do
        if currentFuelingData.isActive then
            if CurrentObjects.rope and RopeGetDistanceBetweenEnds(CurrentObjects.rope) > 8.0 then
                SendNUIMessage({
                    action = 'hide'
                })
                SetNuiFocus(false, false)
                Notify(Lang:t('error.too_far'), 'error')
                removeObjects()
                currentFuelingData.isActive = false
            else
                if not CurrentVehicle or not Entity(CurrentVehicle).state['nozzleAttached'] then
                    SendNUIMessage({ action = 'stop-pump' })
                    SetNuiFocus(false, false)
                    currentFuelingData.isActive = false
                end
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

RegisterNuiCallback('close', function (_, cb)
    hideFuelMenu()
    cb('ok')
end)

RegisterNuiCallback('start-fueling', function (data, cb)
    if not data or not data.liter then return end
    
    local liter = tonumber(data.liter)
    if not liter or liter <= 0 then return end
    
    startFuelingProcess(liter)
    cb('ok')
end)

-- New callback for when fueling is completed (either stopped or finished)
RegisterNuiCallback('pump-complete', function (data, cb)
    if not data or not data.litres then return end
    
    local actualLitres = tonumber(data.litres)
    if actualLitres and actualLitres > 0 then
        completeFuelingProcess(actualLitres, data.completed or false)
    end
    
    hideFuelMenu()
    cb('ok')
end)

RegisterNuiCallback('refill', function (data, cb)
    if not data or not data.liter then return end
    hideFuelMenu()
    refillVehicleFuel(data.liter)
    cb('ok')
end)

local emergencyRefuelVehicle = function(veh)
    if not veh or not DoesEntityExist(veh) then return Notify(Lang:t('emergency.no_vehicle'), 'error') end

    CheckLoadshedding(function(isActive)
        if isActive then
            Notify(Lang:t('loadshedding.active'), 'error')
            Notify(Lang:t('loadshedding.pumps_offline'), 'error')
            return
        end
        
        continueEmergencyRefuel(veh)
    end)
end

continueEmergencyRefuel = function(veh)
    local ped = PlayerPedId()
    local vehFuel = math.floor(exports['sg-fuel']:GetFuel(veh) or 0)
    local maxFuel = 100
    local fuelNeeded = maxFuel - vehFuel

    local minFuelDiff = Config.EmergencyRefuel.MinFuelToRefuel or 1
    if fuelNeeded < minFuelDiff then return Notify(Lang:t('emergency.vehicle_full'), 'error') end

    local vehCoords = GetEntityCoords(veh)
    local pedCoords = GetEntityCoords(ped)
    local distance = #(vehCoords - pedCoords)
    
    if distance > 3.0 then
        return Notify(Lang:t('emergency.too_far'), 'error')
    end

    if Config.EmergencyRefuel.RequireFuelTankSide then
        local vehForward = GetEntityForwardVector(veh)
        local vehRight = vector3(-vehForward.y, vehForward.x, 0.0)
        local toPlayer = pedCoords - vehCoords
        local rightDot = toPlayer.x * vehRight.x + toPlayer.y * vehRight.y

        if rightDot > 0 then
            return Notify(Lang:t('emergency.wrong_side'), 'error')
        end
    end

    QBCore.Functions.TriggerCallback('sg-fuel:server:emergencyRefuel', function(success, message)
        if not success then
            return Notify(message or Lang:t('emergency.failed'), 'error')
        end

        ClearPedTasks(ped)
        TaskTurnPedToFaceEntity(ped, veh, 1000)
        Wait(1000)

        loadAnimDict('timetable@gardener@filling_can')
        TaskPlayAnim(ped, 'timetable@gardener@filling_can', 'gar_ig_5_filling_can', 2.0, 8.0, -1, 50, 0, false, false, false)

        ShowProgressBar('emergency_refueling', Lang:t('emergency.refueling'), Config.RefillTimePerLitre * fuelNeeded * 1000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            exports['sg-fuel']:SetFuel(veh, maxFuel)
            Notify(Lang:t('emergency.success', {litres = fuelNeeded}), 'success')
            Notify(Lang:t('emergency.collect_payment'), 'primary', 8000)
            ClearPedTasks(ped)
        end, function()
            ClearPedTasks(ped)
            Notify(Lang:t('emergency.cancelled'), 'error')
        end)
    end, fuelNeeded)
end

RegisterCommand(Config.EmergencyRefuel.Command, function()
    if not Config.EmergencyRefuel or not Config.EmergencyRefuel.Enabled then
        return Notify('Emergency refuel system is disabled', 'error')
    end

    local PlayerData = QBCore.Functions.GetPlayerData()
    local jobName = PlayerData.job.name
    
    if Config.EmergencyRefuel.RequireEmployeeJob then
        local isGasStationEmployee = false
        for _, business in pairs(Config.GasStations) do
            if jobName == business then
                isGasStationEmployee = true
                break
            end
        end
        
        if not isGasStationEmployee then
            return Notify(Lang:t('emergency.not_employee'), 'error')
        end
    end

    local maxDistance = Config.EmergencyRefuel.MaxDistance or 5.0
    local veh, distance = QBCore.Functions.GetClosestVehicle()
    if not veh or veh == -1 or distance > maxDistance then
        return Notify(Lang:t('emergency.no_vehicle'), 'error')
    end

    emergencyRefuelVehicle(veh)
end)

RegisterCommand(Config.EmergencyRefuel.HelpCommand, function()
    Notify('Emergency Refuel Help:', 'primary', 10000)
    Notify('1. Walk to the left side of a vehicle (fuel tank side)', 'primary', 8000)
    Notify('2. Use /emergencyrefuel command', 'primary', 8000)
    Notify('3. Wait for the refueling animation to complete', 'primary', 8000)
    Notify('4. Collect payment from the customer', 'primary', 8000)
    Notify('Note: Fuel will be deducted from your gas station reserves', 'error', 10000)
end)

AddEventHandler('onResourceStop', function (res)
    if GetCurrentResourceName() ~= res then return end
    removeObjects()
    
    if Config.VehicleInteractionMethod == 'target' then
        RemoveGlobalVehicle('sg-fuel-vehicle-targets')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    removeObjects()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(pData)
    QBCore.PlayerData = pData
end)

if Config.UseLegacyFuelConsumption then
    CreateThread(function()
        while true do
            Wait(1000)
            
            local ped = PlayerPedId()
            
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                if GetPedInVehicleSeat(vehicle, -1) == ped then
                    ManageFuelUsage(vehicle)
                end
            end
        end
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    init()
end)

CreateThread(function()
    Wait(500)
    if LocalPlayer.state.isLoggedIn then
        init()
    end
end)

if Config.ShowNearestGasStationOnly then
	CreateThread(function()
		local currentGasBlip = 0

		while true do
			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords

			for coordsVec, businessName in pairs(Config.GasStations) do
				local dstcheck = #(coords - coordsVec)

				if dstcheck < closest then
					closest = dstcheck
					closestCoords = coordsVec
				end
			end

			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end

			if closestCoords then currentGasBlip = createBlip(closestCoords) end

			Wait(10000)
		end
	end)
elseif Config.ShowAllGasStations then
	CreateThread(function()
		for coordsVec, businessName in pairs(Config.GasStations) do
			createBlip(coordsVec)
		end
	end)
end

local function formatNumber(number)
	local formatted = tostring(math.floor(number))
	local k = 3
	while k <= #formatted do
		formatted = formatted:sub(1, #formatted - k) .. "," .. formatted:sub(#formatted - k + 1)
		k = k + 4
	end
	return formatted
end

local function formatDate(input)
	if not input then return "N/A" end
	
	if type(input) == "number" then
		local time = input
		local year = math.floor(time / (365 * 24 * 60 * 60)) + 1970
		time = time % (365 * 24 * 60 * 60)
		local month = math.floor(time / (30 * 24 * 60 * 60)) + 1
		time = time % (30 * 24 * 60 * 60)
		local day = math.floor(time / (24 * 60 * 60)) + 1
		time = time % (24 * 60 * 60)
		local hour = math.floor(time / (60 * 60))
		time = time % (60 * 60)
		local min = math.floor(time / 60)
		
		return string.format("%04d-%02d-%02d %02d:%02d", year, month, day, hour, min)
	end
	
	if type(input) == "string" then
		local year, month, day, hour, min = input:match("(%d+)-(%d+)-(%d+) (%d+):(%d+)")
		if year then
			return string.format("%04d-%02d-%02d %02d:%02d", 
				tonumber(year), tonumber(month), tonumber(day), 
				tonumber(hour), tonumber(min))
		end
	end
	
	return tostring(input)
end

local lastBusinessData = nil

local function OpenFuelManagementMenu(businessData)
	lastBusinessData = businessData
	
	SendNUIMessage({
		action = 'show-management',
		business = businessData.business,
		businessName = businessData.business_name or businessData.business:gsub("^%l", string.upper),
		fuelLitres = businessData.fuel_litres,
		balance = businessData.balance,
		todayIncome = businessData.today_income or 0,
		weeklyIncome = businessData.weekly_income or 0,
		fuelPrice = businessData.fuel_price,
		isBoss = businessData.is_boss,
		deliveryStatus = businessData.delivery_status,
		currency = Config.Currency,
	})
	SetNuiFocus(true, true)
end

RegisterCommand('managefuel', function()
	local PlayerData = QBCore.Functions.GetPlayerData()
	local jobName = PlayerData.job.name
	
	local hasPermission = false
	for _, business in pairs(Config.GasStations) do
		if jobName == business then
			hasPermission = true
			break
		end
	end
	
	if hasPermission then
		TriggerServerEvent('sg-fuel:server:requestBusinessData', jobName)
	else
		Notify('You do not have permission to manage fuel stations', 'error')
	end
end)

RegisterNetEvent('sg-fuel:client:openManagement', function(businessData)
	OpenFuelManagementMenu(businessData)
end)

RegisterNetEvent('sg-fuel:client:showTransactions', function(transactions)
	SendNUIMessage({
		action = 'show-transactions',
		transactions = transactions
	})
end)

RegisterNetEvent('sg-fuel:client:showStatistics', function(stats)
	SendNUIMessage({
		action = 'show-statistics',
		stats = stats
	})
end)

RegisterNuiCallback('close-management', function(_, cb)
	SetNuiFocus(false, false)
	cb('ok')
end)

RegisterNuiCallback('set-fuel-price', function(data, cb)
	if data and data.price and data.business then
		TriggerServerEvent('sg-fuel:server:setFuelPrice', data.business, tonumber(data.price))
	end
	cb('ok')
end)

RegisterNuiCallback('order-fuel', function(data, cb)
	if data and data.amount and data.business then
		local amount = tonumber(data.amount)
		if amount and amount > 0 then
			TriggerServerEvent('sg-fuel:server:orderFuel', data.business, amount)
		end
	end
	cb('ok')
end)

RegisterNuiCallback('request-transactions', function(data, cb)
	if data and data.business then
		TriggerServerEvent('sg-fuel:server:getTransactions', data.business)
	end
	cb('ok')
end)

RegisterNuiCallback('request-statistics', function(data, cb)
	if data and data.business then
		TriggerServerEvent('sg-fuel:server:getStatistics', data.business)
	end
	cb('ok')
end)

local nozzleValidationPending = false
local nozzleValidationResult = false

RegisterNetEvent('sg-fuel:client:businessFuelValidated', function(success)
    nozzleValidationResult = success
    nozzleValidationPending = false
    
    if success then
        Debug('Business fuel validation SUCCESS')
    else
        Debug('Business fuel validation FAILED')
        if CurrentObjects.nozzle then
            removeObjects()
        end
        CurrentPump = nil
    end
end)