local M = {}

-- require("lua/vehicle/batteryManager")
local batteryManager = require("lua/vehicle/batteryManager")

local blinkTimerThreshold = 0.4 -- copied from electrics.lua
local count_timer = 0
local state_changes_count = 0
local flash_count = 0
local flash_count_threshold = nil

local countFlashes = nop
local flashStopper = nop

local last_warn_signal_state = 0

-- =============================================================================
-- Hazard light indication functions
-- =============================================================================
local function turnHazardLightsOn()
  batteryManager.addBatteryPowerConsumer()
  electrics.set_warn_signal(true)
  print('turnHazardLightsOn()')
  print('electrics.values.hazard_enabled: '..tostring(electrics.values.hazard_enabled))
end

local function turnHazardLightsOff()
  electrics.set_warn_signal(false)
  batteryManager.removeBatteryPowerConsumer()
  print('turnHazardLightsOff()')
  print('electrics.values.hazard_enabled: '..tostring(electrics.values.hazard_enabled))
end

local function countFlashesFun(dt)
  -- print('countFlashes  count_timer: '..tostring(count_timer))
  count_timer = count_timer + dt
  if electrics.values.hazard ~= last_warn_signal_state then
    state_changes_count = state_changes_count + 1
    -- print('state_changes_count : '..tostring(state_changes_count))
    last_warn_signal_state = electrics.values.hazard 
  end
end

local function flashStopperFun()
  -- print('flashStopperFun')
  flash_count = state_changes_count / 2
  -- print('flash_count '..tostring(flash_count))
  -- print('flash_count_threshold '..tostring(flash_count_threshold))
  if flash_count >= flash_count_threshold then
    countFlashes = nop
    flashStopper = nop
    count_timer = 0
    state_changes_count = 0
    flash_count = 0
    turnHazardLightsOff()
    flash_count_threshold = nil

    -- was_engine_turned_off = nil
    batteryManager.updateBatteryPower()
    print('flashStopperFun')
  end
end

local function flashHazardLights(count_threshold)
  turnHazardLightsOn()
  flash_count_threshold = count_threshold
  countFlashes = countFlashesFun
  flashStopper = flashStopperFun
end

local function reset()
  state_changes_count = 0
  flash_count = 0
  flash_count_threshold = nil
  count_timer = 0

  countFlashes = nop
  flashStopper = nop

  electrics.set_warn_signal(false)
  print('visualSignals reseted!')
end

local function init()
  reset()
end

local function updateGFX(dt)
  countFlashes(dt)
  flashStopper()
end

M.reset = reset
M.init = init
M.updateGFX = updateGFX

M.flashHazardLights = flashHazardLights
M.turnHazardLightsOn = turnHazardLightsOn
M.turnHazardLightsOff = turnHazardLightsOff

return M