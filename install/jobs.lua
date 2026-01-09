-- =====================================================
-- SG-Fuel Gas Station Jobs for QBCore
-- =====================================================
-- Add these jobs to your qb-core/shared/jobs.lua file
-- Copy and paste the jobs below into your existing jobs table
-- =====================================================

-- Example jobs for gas stations (modify names as needed) You will need a job for each station or you can have one job controlling more than one station
-- =====================================================

express1 = {
    label = 'Express 1 Gas Station',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = {
            name = 'Attendant',
            payment = 500
        },
        ['1'] = {
            name = 'Supervisor',
            payment = 750
        },
        ['2'] = {
            name = 'Manager',
            payment = 1000,
            isboss = true
        },
    },
},
express2 = {
    label = 'Express 2 Gas Station',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = {
            name = 'Attendant',
            payment = 500
        },
        ['1'] = {
            name = 'Supervisor',
            payment = 750
        },
        ['2'] = {
            name = 'Manager',
            payment = 1000,
            isboss = true
        },
    },
},
express3 = {
    label = 'Express 3 Gas Station',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = {
            name = 'Attendant',
            payment = 500
        },
        ['1'] = {
            name = 'Supervisor',
            payment = 750
        },
        ['2'] = {
            name = 'Manager',
            payment = 1000,
            isboss = true
        },
    },
},

-- =====================================================
-- Installation Instructions:
-- =====================================================
-- 1. Open your qb-core/shared/jobs.lua file
-- 2. Copy the job definitions you want from above
-- 3. Paste them into your existing QBShared.Jobs table
-- 4. Save the file and restart qb-core (or your server)
-- 5. The script will automatically create business bank accounts
-- 6. Assign players to these jobs using your admin menu
-- =====================================================
