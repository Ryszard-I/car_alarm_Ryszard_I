local M = {}
M.type = "auxiliary"

local securitySensors = require("lua/vehicle/securitySensors")
local visualSignals = require("lua/vehicle/visualSignals")
local acousticSignals = require("lua/vehicle/acousticSignals")
local batteryManager = require("lua/vehicle/batteryManager")

local veh_country = nil
local alarms_counter_threshold = 2
local alarms_counter = 0

local initial_delay = 1
local timer = 0

-- Sounds
local are_sounds_loaded = false


-- Electrics
M.vehicle_security_system = {
  central_lock_system = {
    state = 0,
    breached = false
  },
  alarm_system = {
    armed = false,
    alert_state = 0,
    activated_while_armed = false   -- memory of alarm activation during armed period
  }
}

local function updateGELua(new_data)
  obj:queueGameEngineLua("result_from_vlua = ("..new_data..")")
end

-- =============================================================================
-- Alarm functions
-- =============================================================================
local alarm_timer = 0

local function enableAlarmAlert()
  print('inside enableAlarmAlert()')
  acousticSignals.playSoundEffect('car_alarm_alert')
  visualSignals.turnHazardLightsOn()
  M.vehicle_security_system.alarm_system.alert_state = 1
  print('M.vehicle_security_system.alarm_system.alert_state: '..tostring(M.vehicle_security_system.alarm_system.alert_state))
end

local function disableAlarmAlert(instantly)
  print('inside disableAlarmAlert()')
  if instantly then
      acousticSignals.stopSoundEffect('car_alarm_alert')
  end
  visualSignals.turnHazardLightsOff()
  M.vehicle_security_system.alarm_system.alert_state = 0
  print('M.vehicle_security_system.alarm_system.alert_state: '..tostring(M.vehicle_security_system.alarm_system.alert_state))
end

local function alarmSystemMainLoop(dt)
  local alarm_alert_length = acousticSignals.alarm_alert_length > 30 and acousticSignals.alarm_alert_length or 30

  -- If at least one of the doors is open
  if not securitySensors.areDoorsClosed() or securitySensors.shock_sensor_triggered or securitySensors.tilt_sensor_triggered then 
    -- If alarm alert hasn't been triggered yet 
    if M.vehicle_security_system.alarm_system.alert_state == 0 then
      if not securitySensors.areDoorsClosed() and alarms_counter < alarms_counter_threshold then
        alarms_counter = alarms_counter + 1
        enableAlarmAlert()
        print('Alarm reason: doors are not closed!')
        -- Doors have been breached
        M.vehicle_security_system.central_lock_system.breached = true
      elseif securitySensors.shock_sensor_triggered or securitySensors.tilt_sensor_triggered then
        enableAlarmAlert()
        if securitySensors.shock_sensor_triggered then 
          print('Alarm reason: shock sensor triggered!')
        else
          print('Alarm reason: tilt sensor triggered!')
        end
      end
    else
      alarm_timer = alarm_timer + dt
      if alarm_timer % 5 < 0.03 then 
        print('alarm_timer: '..tostring(alarm_timer))
      end

      if alarm_timer > alarm_alert_length / acousticSignals.sound_pitch and acousticSignals.name_of_current_sfx == nil then

        disableAlarmAlert(true)
        print('Disabled alarm: alarm_timer > alarm_timer_length')
        alarm_timer = 0
      end
      -- playSoundEffect('car_alarm_alert')
    end

  -- All doors are closed
  else
    -- If alarm alert hasn't been disabled yet
    if M.vehicle_security_system.alarm_system.alert_state == 1 then
      if alarm_timer > alarm_alert_length / acousticSignals.sound_pitch and acousticSignals.name_of_current_sfx == nil then

        disableAlarmAlert(true)
        alarm_timer = 0
    -- elseif alarm_timer % (acousticSignals.alarm_alert_length + 1) > acousticSignals.alarm_alert_length then
    --     enableAlarmAlert()
      else
        alarm_timer = alarm_timer + dt
        if alarm_timer % 5 < 0.03 then 
            print('alarm_timer: '..tostring(alarm_timer))
        end
      end
    -- if alarm_timer > 32.5 then
    --     disableAlarmAlert(true)
    --     alarm_timer = 0
    -- else
    --     alarm_timer = alarm_timer + dt
    --     if alarm_timer % 5 < 0.03 then 
    --         print('alarm_timer: '..tostring(alarm_timer))
    --     end
    -- end
    end
    -- If alert was disabled before = do nothing
  end

end


-- local function alarmSystemMainLoop()
--     -- If at least one of the doors is open
--     if not securitySensors.areDoorsClosed() then 
--         -- If alarm alert hasn't been triggered yet 
--         if M.vehicle_security_system.alarm_system.alert_state == 0 then
--             enableAlarmAlert()
--         -- If alert was enabled before but doors still not closed
--         else
--             playSoundEffect('car_alarm_alert')
--         end
    
--     -- All doors are closed
--     else
--         -- If alarm alert hasn't been disabled yet
--         if M.vehicle_security_system.alarm_system.alert_state == 1 then
--             disableAlarmAlert()
--         end
--         -- If alert was disabled before = do nothing
--     end
-- end

-- =============================================================================
-- Central lock functions
-- =============================================================================
local function lockDoors()
  acousticSignals.playSoundEffect('central_lock')
  M.vehicle_security_system.central_lock_system.state = 1
end

local function unlockDoors()
  acousticSignals.playSoundEffect('central_lock')
  M.vehicle_security_system.central_lock_system.state = 0
end

local function getCentralLockState()
  -- return true
  if M.vehicle_security_system.central_lock_system.breached == true then 
      print('Vehicle doors breached!')
      return true
  else    
      return M.vehicle_security_system.central_lock_system.state
  end
  -- obj:queueGameEngineLua("vehicle_infront.locked = M.vehicle_security_system.central_lock_system.state")
  -- obj:queueGameEngineLua("vehicle_infront_locked = ('..M.vehicle_security_system.central_lock_system.state..')")
end

-- =============================================================================
-- Control functions
-- =============================================================================
local function lockVehicle()
  if not securitySensors.areDoorsClosed() then
    -- guihooks.message('You need to close all the doors!')
    obj:queueGameEngineLua('ui_message("You need to close all the doors!")')
    return
  end
  -- was_engine_turned_off = electrics.values.ignitionLevel == 0
  was_engine_turned_off = true

  -- playSoundEffect('central_lock')
  lockDoors()
  print('lockVehicle was_engine_turned_off = '..tostring(was_engine_turned_off))
  if was_engine_turned_off == true then
    batteryManager.reset()
    visualSignals.flashHazardLights(1)
    acousticSignals.playSoundEffect('car_alarm_lock')
  end
  M.vehicle_security_system.alarm_system.armed = true
  obj:queueGameEngineLua('ui_message("Car is now locked.")')
  -- guihooks.message('Car is now locked!')

end

local function unlockVehicle()
  -- was_engine_turned_off = electrics.values.ignitionLevel == 0
  -- playSoundEffect('central_lock')
  unlockDoors()
  -- print('unlockVehicle was_engine_turned_off = '..tostring(was_engine_turned_off))
  if was_engine_turned_off == true or M.vehicle_security_system.alarm_system.alert_state == 1 then
    if M.vehicle_security_system.alarm_system.alert_state == 1 then
      -- stopSoundEffect('car_alarm_alert')
      -- electrics.set_warn_signal(false)
      disableAlarmAlert(true)
    end
    batteryManager.reset()
    acousticSignals.playSoundEffect('car_alarm_unlock')
    visualSignals.flashHazardLights(2)
  end
  M.vehicle_security_system.alarm_system.armed = false
  obj:queueGameEngineLua('ui_message("Car is now unlocked.")')
      -- guihooks.message('Car is now unlocked!')
end

local function toggle(player_location)
  print('TOGGLE')
  print("___")
  -- securitySensors.printSensorsState()
  if M.vehicle_security_system.central_lock_system.state == 0 then 
    if player_location == 'outside' then
        lockVehicle()
    else 
        lockDoors()
    end
    -- guihooks.message('Car is now locked!')
  else
    if player_location == 'outside' then
        unlockVehicle() 
    else
        unlockDoors()
    end
    alarms_counter = 0 
    -- guihooks.message('Car is now unlocked!')
  end
  -- for i,e in pairs(nodeData) do
  --     print(i,e)
  -- end
  updateGELua(getCentralLockState())
  print(string.rep('_', 20))
end


-- =============================================================================
-- Utils
-- =============================================================================
-- OBSOLETE FOR NOW
local function updateLastElectricsState()
  if electrics.values.ignitionLevel > 0 then
    -- print('ignition level > 0')
    last_electrics_state.ignition_level = electrics.values.ignitionLevel
    last_electrics_state.lights_state = electrics.values.lights
    last_electrics_state.fog_lights_state = electrics.values.fog
    last_electrics_state.lightbar_state = electrics.values.lightbar
    last_electrics_state.warn_lights_state = electrics.values.hazard_enabled
    last_electrics_state.brake_lights = electrics.values.brakelights
  end
end

local function getSystemState()
  return M.vehicle_security_system
end

local function printSystemState()
  print('M.vehicle_security_system.central_lock_system.state = '..tostring(M.vehicle_security_system.central_lock_system.state))
  print('M.vehicle_security_system.central_lock_system.breached = '..tostring(M.vehicle_security_system.central_lock_system.breached))
  print('M.vehicle_security_system.alarm_system.armed = '..tostring(M.vehicle_security_system.alarm_system.armed))
  print('M.vehicle_security_system.alarm_system.alert_state = '..tostring(M.vehicle_security_system.alarm_system.alert_state))
  print('M.vehicle_security_system.alarm_system.activated_while_armed = '..tostring(M.vehicle_security_system.alarm_system.activated_while_armed))
end

local function setVehicleCountry(country)
  print(country)
  veh_country = country
  -- acousticSignals.isAmericanCar = veh_country == 'United States'
  print("veh_country == 'United States': "..tostring(veh_country == 'United States'))
  print('veh_country set!')
end
-- =============================================================================
-- Main
-- =============================================================================
local function reset()
  print('VARS: ')
  print('$sensor_sensitivity: '..tostring(v.data.variables["$sensor_sensitivity"].val))
  -- print(dumpsz(jbeamData))
  -- print(jbeamData.car_alarm_alert)

  -- if true then print(dumps(v.data.soundscape)) return end

  print('electrics.values.ignitionLevel == 0: '..tostring(electrics.values.ignitionLevel == 0))
  -- if electrics.values.ignitionLevel == 0 then
  --     M.vehicle_security_system.alarm_system.armed = true
  --     M.vehicle_security_system.central_lock_system.state = 1
  -- else
  --     M.vehicle_security_system.alarm_system.armed = false
  --     M.vehicle_security_system.central_lock_system.state = 0
  -- end

  M.vehicle_security_system.central_lock_system.breached = false
  M.vehicle_security_system.alarm_system.alert_state = 0
  M.vehicle_security_system.alarm_system.activated_while_armed = false

  batteryManager.reset()
  visualSignals.reset()
  acousticSignals.reset()

  printSystemState()

  was_engine_turned_off = electrics.values.ignitionLevel == 0
  alarms_counter = 0
  alarm_timer = 0
  timer = 0
  print('                         car_alarm_Ryszard_I reset()')
end

local function init()
  print('car_alarm_Ryszard_I init()')
  reset()
end


local function updateGFX(dt)
  if timer < initial_delay then 
    timer = timer + dt
    return
  end
  if not are_sounds_loaded and veh_country then are_sounds_loaded = acousticSignals.loadSounds(veh_country) end
  
  -- Normally these below would be updated from main.lua (like electrics f.ex.)
  visualSignals.updateGFX(dt)
  acousticSignals.updateGFX(dt)

  -- If alarm_system is armed
  if M.vehicle_security_system.alarm_system.armed == true then
    securitySensors.updateGFX(dt)
    alarmSystemMainLoop(dt)
  end
end

M.resetBatteryManager = batteryManager.reset
M.resetVisualSignals = visualSignals.reset
M.resetAcousticSignals = acousticSignals.reset
M.disableAlarmAlert = disableAlarmAlert

M.test = test
-- M.init = nop
M.toggle = toggle
M.getSystemState = getSystemState
M.printSystemState = printSystemState
M.getCentralLockState = getCentralLockState
M.onCouplerFound = securitySensors.onCouplerFound
M.onCouplerDetached = securitySensors.onCouplerDetached
M.onCouplerAttached = securitySensors.onCouplerAttached
M.playSoundEffect = acousticSignals.playSoundEffect
M.stopSoundEffect = acousticSignals.stopSoundEffect
M.init = init
M.reset = reset
-- M.onReset = onReset
M.onAIReset = onAIReset
M.updateGFX = updateGFX

M.updateGELua = updateGELua
M.setVehicleCountry = setVehicleCountry

return M