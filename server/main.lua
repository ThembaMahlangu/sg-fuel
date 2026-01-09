QBCore = exports["qb-core"]:GetCoreObject()
local PRICE_PER_LITRE = Config.FuelPrice

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

local function Notify(source, message, type, duration)
    if Config.NotificationProvider == 'ox_lib' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Fuel Station',
            description = message,
            type = type or 'info',
            position = MapNotificationPosition(Config.NotificationPosition),
            duration = duration or 5000
        })
    else
        TriggerClientEvent('QBCore:Notify', source, message, type, duration)
    end
end

CreateThread(function()
	MySQL.query([[
		CREATE TABLE IF NOT EXISTS `business_fuel` (
			`business` VARCHAR(50) NOT NULL,
			`business_name` VARCHAR(100) NOT NULL DEFAULT '',
			`fuel_litres` FLOAT NOT NULL DEFAULT 0,
			`price_per_litre` FLOAT NULL DEFAULT NULL,
			PRIMARY KEY (`business`)
		)
	]])

	MySQL.query('SELECT business FROM business_fuel WHERE business_name = \'\' OR business_name IS NULL', {}, function(results)
		if results then
			for _, row in ipairs(results) do
				local business = row.business
				local businessName = QBCore.Shared.Jobs[business] and QBCore.Shared.Jobs[business].label or business:gsub("^%l", string.upper)
				MySQL.update('UPDATE business_fuel SET business_name = ? WHERE business = ?', {businessName, business})
			end
		end
	end)
end)

local function Debug(message)
	if Config.Debug then
		print('SG-FUEL: ' .. message)
	end
end

local function EnsureBusinessExists(business)
	if not business then return false end
	
	local result = MySQL.scalar.await('SELECT 1 FROM business_fuel WHERE business = ?', {business})
	if not result then
		local businessName = QBCore.Shared.Jobs[business] and QBCore.Shared.Jobs[business].label or business:gsub("^%l", string.upper)
		
		MySQL.insert.await('INSERT INTO business_fuel (business, business_name, fuel_litres) VALUES (?, ?, ?)', {
			business, businessName, 0
		})
	end
	return true
end

local function GetBusinessFuel(business)
	if not business then return 0 end
	EnsureBusinessExists(business)
	local result = MySQL.scalar.await('SELECT fuel_litres FROM business_fuel WHERE business = ?', {business})
	return tonumber(result) or 0
end

local function UpdateBusinessFuel(business, newAmount)
	if not business then return false end
	
	newAmount = tonumber(newAmount) or 0
	if newAmount < 0 then newAmount = 0 end
	
	MySQL.update('UPDATE business_fuel SET fuel_litres = ? WHERE business = ?', {
		newAmount, business
	})
	return true
end

local function GetBusinessFuelPrice(business)
	if not business then return PRICE_PER_LITRE end
	local result = MySQL.scalar.await('SELECT price_per_litre FROM business_fuel WHERE business = ?', {business})
	return tonumber(result) or PRICE_PER_LITRE
end

local function SetBusinessFuelPrice(business, price)
	if not business then return false end
	if price < PRICE_PER_LITRE then return false end
	
	MySQL.update('UPDATE business_fuel SET price_per_litre = ? WHERE business = ?', {
		price, business
	})
	return true
end

local function GetBusinessBalance(business)
    local result = exports['qb-banking']:GetAccountBalance(business)
    return result or 0
end

local function GetTodayIncome(business)
    local today = os.date('%Y-%m-%d')
    local result = MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount), 0) as total 
        FROM bank_statements 
        WHERE account_name = ? 
        AND statement_type = 'deposit' 
        AND DATE(date) = ?
    ]], {business, today})
    return tonumber(result) or 0
end

local function GetWeeklyIncome(business)
    local result = MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount), 0) as total 
        FROM bank_statements 
        WHERE account_name = ? 
        AND statement_type = 'deposit' 
        AND date >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], {business})
    return tonumber(result) or 0
end

local function GetRecentTransactions(business)
    local result = MySQL.query.await([[
        SELECT amount, reason as description, date as created, statement_type
        FROM bank_statements 
        WHERE account_name = ? 
        ORDER BY date DESC 
        LIMIT 10
    ]], {business})
    
    for i, transaction in ipairs(result) do
        if transaction.statement_type == 'withdraw' then
            transaction.amount = -transaction.amount
        end
    end
    
    return result or {}
end

local function GetFuelAnalytics(business)
    local customerPurchases = MySQL.query.await([[
        SELECT 
            COUNT(*) as transaction_count,
            COALESCE(SUM(amount), 0) as total_amount,
            COALESCE(SUM(
                CASE 
                    WHEN reason LIKE 'Fuel Purchase - %' 
                    THEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(reason, ' - ', -1), ' litres', 1) AS DECIMAL(10,2))
                    ELSE 0 
                END
            ), 0) as total_litres
        FROM bank_statements 
        WHERE account_name = ? 
        AND reason LIKE 'Fuel Purchase - %'
        AND statement_type = 'deposit'
        AND date >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], {business})

    local deliveries = MySQL.query.await([[
        SELECT 
            COUNT(*) as delivery_count,
            COALESCE(SUM(amount), 0) as total_cost,
            COALESCE(SUM(
                CASE 
                    WHEN reason LIKE 'Fuel Purchase - %' 
                    THEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(reason, ' - ', -1), ' litres', 1) AS DECIMAL(10,2))
                    ELSE 0 
                END
            ), 0) as total_litres
        FROM bank_statements 
        WHERE account_name = ? 
        AND reason LIKE 'Fuel Delivery%'
        AND statement_type = 'withdraw'
        AND date >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], {business})

    local transactions = tonumber(customerPurchases[1].transaction_count) or 0
    local totalSales = tonumber(customerPurchases[1].total_amount) or 0
    local litresSold = tonumber(customerPurchases[1].total_litres) or 0
    local deliveryCount = tonumber(deliveries[1].delivery_count) or 0
    local deliveryCost = tonumber(deliveries[1].total_cost) or 0
    local deliveryLitres = tonumber(deliveries[1].total_litres) or 0

    local analytics = {
        customer_transactions = transactions,
        total_sales = totalSales,
        litres_sold = litresSold,
        delivery_count = deliveryCount,
        delivery_cost = deliveryCost,
        delivery_litres = deliveryLitres,
        profit = totalSales - math.abs(deliveryCost),
        avg_transaction = transactions > 0 and (totalSales / transactions) or 0,
        avg_litres_per_sale = transactions > 0 and (litresSold / transactions) or 0
    }
    
    return analytics
end

-- ====================|| EXPORTS || ==================== --

-- Export to refill business fuel
exports('RefillBusinessFuel', function(business, amount)
	if not business or type(amount) ~= 'number' or amount <= 0 then return false end
	
	EnsureBusinessExists(business)
	local currentFuel = GetBusinessFuel(business)
	UpdateBusinessFuel(business, currentFuel + amount)
	return true
end)

-- Export to get business fuel level
exports('GetBusinessFuelLevel', function(business)
	return GetBusinessFuel(business)
end)

-- Export to get business fuel price
exports('GetBusinessFuelPrice', function(business)
	return GetBusinessFuelPrice(business)
end)

-- Export to set business fuel price (for external scripts)
exports('SetBusinessFuelPrice', function(business, price)
	return SetBusinessFuelPrice(business, price)
end)

-- Export to get business balance (for external scripts)
exports('GetBusinessBalance', function(business)
	return GetBusinessBalance(business)
end)

-- Export to add money to business account (for external scripts)
exports('AddBusinessMoney', function(business, amount, reason)
	if not business or not amount or amount <= 0 then return false end
	local success = exports['qb-banking']:AddMoney(business, amount, reason or 'External Deposit')
	return success
end)

-- Export to remove money from business account (for external scripts)
exports('RemoveBusinessMoney', function(business, amount, reason)
	if not business or not amount or amount <= 0 then return false end
	local success = exports['qb-banking']:RemoveMoney(business, amount, reason or 'External Withdrawal')
	return success
end)

-- Export to ensure a business exists in the database
exports('EnsureBusinessExists', function(business)
	return EnsureBusinessExists(business)
end)

-- Export to get business statistics (for external scripts)
exports('GetBusinessStatistics', function(business)
	if not business then return nil end
	return {
		today_income = GetTodayIncome(business),
		weekly_income = GetWeeklyIncome(business),
		fuel_level = GetBusinessFuel(business),
		fuel_analytics = GetFuelAnalytics(business),
		balance = GetBusinessBalance(business),
		fuel_price = GetBusinessFuelPrice(business)
	}
end)

exports('refillBusinessFuel', function(business, amount)
	return exports['sg-fuel']:RefillBusinessFuel(business, amount)
end)

exports('getBusinessFuelLevel', function(business) -- lowercase version
	return exports['sg-fuel']:GetBusinessFuelLevel(business)
end)

-- Additional business management exports for delivery scripts, etc.
exports('DeductBusinessFuel', function(business, amount)
	if not business or not amount or amount <= 0 then return false end
	local currentFuel = GetBusinessFuel(business)
	if currentFuel < amount then return false end
	UpdateBusinessFuel(business, currentFuel - amount)
	return true
end)

exports('SetBusinessFuelLevel', function(business, amount)
	if not business or not amount or amount < 0 then return false end
	return UpdateBusinessFuel(business, amount)
end)

QBCore.Functions.CreateCallback('sg-fuel:server:refillVehicle', function (src, cb, litres, business)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        Debug('DEBUG: Player not found for refillVehicle')
        return cb(false) 
    end
    if not litres then 
        Debug('DEBUG: No litres specified for refillVehicle')
        return cb(false) 
    end

    -- Get the business fuel price or use default
    local fuelPrice = business and GetBusinessFuelPrice(business) or Config.FuelPrice
    local finalPrice = litres * fuelPrice
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    local totalMoney = cash + bank

    Debug('DEBUG: Server refillVehicle - Player:', Player.PlayerData.name, 'Litres:', litres, 'Price per litre:', fuelPrice, 'Total cost:', finalPrice, 'Cash:', cash, 'Bank:', bank, 'Total:', totalMoney)

    if totalMoney >= finalPrice then
        local moneyRemoved = false
        
        -- Try to remove from cash first, then bank
        if cash >= finalPrice then
            -- Pay with cash only
            if Player.Functions.RemoveMoney('cash', finalPrice, 'refuel-vehicle') then
                moneyRemoved = true
                Debug('DEBUG: Paid with cash')
            end
        elseif bank >= finalPrice then
            -- Pay with bank only
            if Player.Functions.RemoveMoney('bank', finalPrice, 'refuel-vehicle') then
                moneyRemoved = true
                Debug('DEBUG: Paid with bank')
            end
        else
            -- Pay with both cash and bank
            local remainingAfterCash = finalPrice - cash
            if Player.Functions.RemoveMoney('cash', cash, 'refuel-vehicle') and 
               Player.Functions.RemoveMoney('bank', remainingAfterCash, 'refuel-vehicle') then
                moneyRemoved = true
                Debug('DEBUG: Paid with cash and bank - Cash:', cash, 'Bank:', remainingAfterCash)
            end
        end
        
        if moneyRemoved then
            Debug('DEBUG: Money removed successfully')
            -- If business is specified, transfer money to business account and deduct fuel
            if business then
                local success = exports['qb-banking']:AddMoney(business, finalPrice, 'Fuel Purchase - ' .. math.floor(litres) .. ' litres')
                if success then
                    -- Deduct fuel from business storage
                    local businessFuel = GetBusinessFuel(business)
                    UpdateBusinessFuel(business, businessFuel - litres)
                    Debug('DEBUG: Business fuel updated - New level:', businessFuel - litres)
                end
            end
            cb(true)
        else
            Debug('DEBUG: Failed to remove money from player')
            cb(false)
        end
    else
        Debug('DEBUG: Player does not have enough money')
        cb(false)
    end
end)

RegisterServerEvent('sg-fuel:server:buyJerryCan', function ()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cost = Config.JerryCanCost
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    local totalMoney = cash + bank

    if totalMoney >= cost then
        local moneyRemoved = false
        
        -- Try to remove from cash first, then bank
        if cash >= cost then
            if Player.Functions.RemoveMoney('cash', cost, 'buy-jerry-can') then
                moneyRemoved = true
            end
        elseif bank >= cost then
            if Player.Functions.RemoveMoney('bank', cost, 'buy-jerry-can') then
                moneyRemoved = true
            end
        else
            local remainingAfterCash = cost - cash
            if Player.Functions.RemoveMoney('cash', cash, 'buy-jerry-can') and 
               Player.Functions.RemoveMoney('bank', remainingAfterCash, 'buy-jerry-can') then
                moneyRemoved = true
            end
        end
        
        if moneyRemoved then
            Player.Functions.AddItem('weapon_petrolcan', 1, nil, { fuel = Config.JerryCanLitre, ammo = Config.JerryCanLitre })
        end
    end
end)

RegisterServerEvent('sg-fuel:server:refillJerryCan', function ()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jerryCan = Player.Functions.GetItemByName('weapon_petrolcan')
    if not jerryCan then return Player.Functions.Notify(Lang:t('error.no_jerrycan'), 'error') end

    local cost = Config.JerryCanRefillCost
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    local totalMoney = cash + bank

    if totalMoney >= cost then
        local moneyRemoved = false
        
        -- Try to remove from cash first, then bank
        if cash >= cost then
            if Player.Functions.RemoveMoney('cash', cost, 'refill-jerry-can') then
                moneyRemoved = true
            end
        elseif bank >= cost then
            if Player.Functions.RemoveMoney('bank', cost, 'refill-jerry-can') then
                moneyRemoved = true
            end
        else
            local remainingAfterCash = cost - cash
            if Player.Functions.RemoveMoney('cash', cash, 'refill-jerry-can') and 
               Player.Functions.RemoveMoney('bank', remainingAfterCash, 'refill-jerry-can') then
                moneyRemoved = true
            end
        end
        
        if moneyRemoved then
            jerryCan.info.fuel = Config.JerryCanLitre
            jerryCan.info.ammo = Config.JerryCanLitre
            Player.Functions.RemoveItem('weapon_petrolcan', 1, jerryCan.slot)
            Player.Functions.AddItem('weapon_petrolcan', 1, nil, jerryCan.info)
        end
    end
end)

RegisterServerEvent('sg-fuel:server:setCanFuel', function (fuel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local jerryCan = Player.Functions.GetItemByName('weapon_petrolcan')
    if not jerryCan then return Player.Functions.Notify(Lang:t('error.no_jerrycan'), 'error') end

    jerryCan.info.fuel = fuel
    jerryCan.info.ammo = fuel
    Player.Functions.RemoveItem('weapon_petrolcan', 1, jerryCan.slot)
    Player.Functions.AddItem('weapon_petrolcan', 1, nil, jerryCan.info)
end)

RegisterNetEvent('sg-fuel:server:validateBusinessFuel', function(business, litresNeeded)
	local source = source
	litresNeeded = tonumber(litresNeeded) or 0
	
	if not business or litresNeeded <= 0 then
		Notify(source, 'Invalid fuel request!', 'error')
		TriggerClientEvent('sg-fuel:client:businessFuelValidated', source, false)
		return
	end

	-- Ensure business exists and has enough fuel
	if not EnsureBusinessExists(business) then
		Notify(source, 'Invalid gas station!', 'error')
		TriggerClientEvent('sg-fuel:client:businessFuelValidated', source, false)
		return
	end

	-- Check if business has enough fuel
	local businessFuel = GetBusinessFuel(business)
	if businessFuel < litresNeeded then
		Notify(source, 'This gas station is out of fuel!', 'error')
		TriggerClientEvent('sg-fuel:client:businessFuelValidated', source, false)
		return
	end

	TriggerClientEvent('sg-fuel:client:businessFuelValidated', source, true)
end)

-- Get current fuel price for a business
QBCore.Functions.CreateCallback('sg-fuel:server:getCurrentPrice', function(source, cb, business)
    cb(GetBusinessFuelPrice(business))
end)

-- Validate business fuel using callback (cleaner than events)
QBCore.Functions.CreateCallback('sg-fuel:server:validateBusinessFuelCallback', function(source, cb, business, litresNeeded)
    litresNeeded = tonumber(litresNeeded) or 0
    
    if not business or litresNeeded <= 0 then
        Debug('DEBUG: Invalid fuel request - business:', business, 'litres:', litresNeeded)
        cb(false)
        return
    end

    -- Ensure business exists and has enough fuel
    if not EnsureBusinessExists(business) then
        Debug('DEBUG: Business does not exist:', business)
        cb(false)
        return
    end

    -- Check if business has enough fuel
    local businessFuel = GetBusinessFuel(business)
    Debug('DEBUG: Business', business, 'has', businessFuel, 'litres, needs', litresNeeded)
    
    if businessFuel < litresNeeded then
        Debug('DEBUG: Not enough fuel - has:', businessFuel, 'needs:', litresNeeded)
        cb(false)
        return
    end

    Debug('DEBUG: Fuel validation successful for business:', business)
    cb(true)
end)

-- Request business data for management menu
RegisterNetEvent('sg-fuel:server:requestBusinessData', function(business)
	local source = source
	local Player = QBCore.Functions.GetPlayer(source)
	
	if not Player then return end
	
	-- Verify player has correct job
	if Player.PlayerData.job.name ~= business then
		Notify(source, 'You do not have permission to manage this business', 'error')
		return
	end
	
	-- Get business data
	local fuelLevel = GetBusinessFuel(business)
	local balance = GetBusinessBalance(business)
	local businessName = MySQL.scalar.await('SELECT business_name FROM business_fuel WHERE business = ?', {business}) or business:gsub("^%l", string.upper)
	local todayIncome = GetTodayIncome(business)
	local weeklyIncome = GetWeeklyIncome(business)
	local fuelPrice = GetBusinessFuelPrice(business)
	local isBoss = Player.PlayerData.job.isboss
	
	-- Check for active delivery status (if sg-fuel-truck-job is available)
	local deliveryStatus = nil
	if GetResourceState('sg-fuel-truck-job') == 'started' then
		local success, result = pcall(function()
			return exports['sg-fuel-truck-job']:GetDeliveryStatus(business)
		end)
		if success and result then
			deliveryStatus = result
		end
	end
	
	-- Send data to client
	TriggerClientEvent('sg-fuel:client:openManagement', source, {
		business = business,
		business_name = businessName,
		fuel_litres = fuelLevel,
		balance = balance,
		today_income = todayIncome,
		weekly_income = weeklyIncome,
		fuel_price = fuelPrice,
		is_boss = isBoss,
		delivery_status = deliveryStatus
	})
end)

-- Set fuel price (boss only)
RegisterNetEvent('sg-fuel:server:setFuelPrice', function(business, price)
	local source = source
	local Player = QBCore.Functions.GetPlayer(source)
	
	if not Player then return end
	
	-- Check if player is boss of the business
	if Player.PlayerData.job.name ~= business or not Player.PlayerData.job.isboss then
		Notify(source, 'You do not have permission to set fuel prices', 'error')
		return
	end
	
	-- Validate price
	price = tonumber(price)
	if not price or price < PRICE_PER_LITRE then
        Notify(source, 'Price cannot be lower than ' .. Config.Currency .. PRICE_PER_LITRE .. ' per litre', 'error')
		return
	end
	
	if SetBusinessFuelPrice(business, price) then
        Notify(source, 'Fuel price updated to ' .. Config.Currency .. price .. ' per litre', 'success')
		-- Refresh management menu
		TriggerEvent('sg-fuel:server:requestBusinessData', business)
	else
		Notify(source, 'Failed to update fuel price', 'error')
	end
end)

-- Get transaction history
RegisterNetEvent('sg-fuel:server:getTransactions', function(business)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or Player.PlayerData.job.name ~= business then return end
    
    local transactions = GetRecentTransactions(business)
    TriggerClientEvent('sg-fuel:client:showTransactions', source, transactions)
end)

-- Get business statistics
RegisterNetEvent('sg-fuel:server:getStatistics', function(business)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or Player.PlayerData.job.name ~= business then return end
    
    -- Get various statistics
    local stats = {
        today_income = GetTodayIncome(business),
        weekly_income = GetWeeklyIncome(business),
        fuel_level = GetBusinessFuel(business),
        fuel_analytics = GetFuelAnalytics(business)
    }
    
    TriggerClientEvent('sg-fuel:client:showStatistics', source, stats)
end)


-- Loadshedding status callback
QBCore.Functions.CreateCallback('sg-fuel:server:checkLoadshedding', function(source, cb)
    if not Config.Loadshedding or not Config.Loadshedding.Enabled then
        return cb(false)
    end
    
    local resourceName = Config.Loadshedding.ResourceName or 'sg-loadshedding'
    local exportName = Config.Loadshedding.ExportName or 'isLoadsheddingActive'
    
    if GetResourceState(resourceName) ~= 'started' then
        Debug('Loadshedding resource not found or not started: ' .. resourceName)
        return cb(false)
    end
    
    local success, result = pcall(function()
        return exports[resourceName][exportName]()
    end)
    
    if not success then
        Debug('Failed to call loadshedding export: ' .. exportName)
        return cb(false)
    end
    
    Debug('Loadshedding status check: ' .. tostring(result))
    cb(result or false)
end)

QBCore.Functions.CreateCallback('sg-fuel:server:emergencyRefuel', function(source, cb, fuelNeeded)
    if not Config.EmergencyRefuel or not Config.EmergencyRefuel.Enabled then
        return cb(false, 'Emergency refuel system is disabled')
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then 
        return cb(false, 'Player not found')
    end

    local jobName = Player.PlayerData.job.name
    fuelNeeded = tonumber(fuelNeeded) or 0

    if fuelNeeded <= 0 then
        return cb(false, 'Invalid fuel amount')
    end

    local employeeBusiness = nil
    if Config.EmergencyRefuel.RequireEmployeeJob then
        local isGasStationEmployee = false
        for _, business in pairs(Config.GasStations) do
            if jobName == business then
                isGasStationEmployee = true
                employeeBusiness = business
                break
            end
        end

        if not isGasStationEmployee then
            return cb(false, 'You must be a gas station employee to use emergency refuel')
        end
    else
        employeeBusiness = next(Config.GasStations) or 'admin'
    end

    if not EnsureBusinessExists(employeeBusiness) then
        return cb(false, 'Business not found in database')
    end

    local businessFuel = GetBusinessFuel(employeeBusiness)
    if businessFuel < fuelNeeded then
        return cb(false, 'Your gas station does not have enough fuel reserves (' .. math.floor(businessFuel) .. ' litres available)')
    end

    local newFuelLevel = businessFuel - fuelNeeded
    if UpdateBusinessFuel(employeeBusiness, newFuelLevel) then
        Debug('DEBUG: Emergency refuel - Deducted ' .. fuelNeeded .. ' litres from ' .. employeeBusiness .. '. New level: ' .. newFuelLevel)
        
        local businessName = MySQL.scalar.await('SELECT business_name FROM business_fuel WHERE business = ?', {employeeBusiness}) or employeeBusiness:gsub("^%l", string.upper)
        local reason = 'Emergency Refuel Service - ' .. math.floor(fuelNeeded) .. ' litres by ' .. Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        
        exports['qb-banking']:AddMoney(employeeBusiness, 0, reason)
        
        return cb(true, 'Emergency refuel authorized')
    else
        return cb(false, 'Failed to update business fuel reserves')
    end
end)

-- Order fuel for business (wholesale)
RegisterNetEvent('sg-fuel:server:orderFuel', function(business, amount)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then return end
    
    if Player.PlayerData.job.name ~= business or not Player.PlayerData.job.isboss then
        Notify(source, 'You do not have permission to order fuel for this business', 'error')
        return
    end
    
    local cost = amount * Config.OrderFuelCost
    
    local balance = GetBusinessBalance(business)
    if balance < cost then
        Notify(source, 'Business cannot afford this order! Cost: ' .. Config.Currency .. cost, 'error')
        return
    end
    
    local success = exports['qb-banking']:RemoveMoney(business, cost, 'Fuel Delivery - ' .. amount .. ' litres')
    if success then
        local currentFuel = GetBusinessFuel(business)
        UpdateBusinessFuel(business, currentFuel + amount)
        
        Notify(source, 'Successfully ordered ' .. amount .. ' litres of fuel for ' .. Config.Currency .. cost, 'success')
        
        TriggerEvent('sg-fuel:server:requestBusinessData', business)
    else
        Notify(source, 'Failed to process payment', 'error')
    end
end)
