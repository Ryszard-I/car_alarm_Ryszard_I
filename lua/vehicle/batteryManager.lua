local M = {}

local current_battery_power_usage = 0 --number of subsystems currently using battery power

-- =============================================================================
-- Battery power functions
-- =============================================================================
local function updateBatteryPower()
  print('inside updateBatteryPower()')
  if current_battery_power_usage == 1 then 
    if electrics.values.ignitionLevel == 0 then
      electrics.setIgnitionLevel(1)
      print('Battery power is ON!')
    end
  elseif current_battery_power_usage == 0 then
    if electrics.values.ignitionLevel ~= 0 then
      electrics.setIgnitionLevel(0)
      print('Battery power is OFF!')
    end
  elseif current_battery_power_usage < 0 then 
    log('E', '', 'current_battery_power_usage is below 0! Current state: '..tostring(current_battery_power_usage))
  end
  -- print('was_engine_turned_off: '..tostring(was_engine_turned_off))
  -- if was_engine_turned_off == true then
  --     if current_battery_power_usage == 1 then 
  --         if electrics.values.ignitionLevel == 0 then
  --             electrics.setIgnitionLevel(1)
  --             print('Battery power is ON!')
  --         end
  --     elseif current_battery_power_usage == 0 then
  --         if electrics.values.ignitionLevel ~= 0 then
  --             electrics.setIgnitionLevel(0)
  --             print('Battery power is OFF!')
  --         end
  --     elseif current_battery_power_usage < 0 then 
  --         log('E', '', 'current_battery_power_usage is below 0! Current state: '..tostring(current_battery_power_usage))
  --     end
  -- end
  print('out off updateBatteryPower()')

end

local function addBatteryPowerConsumer()
  current_battery_power_usage = current_battery_power_usage + 1
  print('Added battery power consumer!')
  print('Battery power consumers: '..tostring(current_battery_power_usage))
  updateBatteryPower()
end

local function removeBatteryPowerConsumer()
  current_battery_power_usage = current_battery_power_usage - 1
  print('Removed battery power consumer!')
  print('Battery power consumers: '..tostring(current_battery_power_usage))
  updateBatteryPower()
end

local function reset()
  current_battery_power_usage = 0
  -- electrics.setIgnitionLevel(0)
  print('Battery reseted!')
end

M.updateBatteryPower = updateBatteryPower
M.addBatteryPowerConsumer = addBatteryPowerConsumer
M.removeBatteryPowerConsumer = removeBatteryPowerConsumer
M.reset = reset

return M