local M = {}


local batteryManager = require("lua/vehicle/batteryManager")
local audioUtils = require("scripts/car_alarm_Ryszard_I/audioUtils")

local isAmericanCar = nil

-- Sound variables
local SOUND_FOLDER_PATH = "art/sound/"
local AUDIO_FILE_FORMAT = "wav"
local sound_effects_tab = {
  ['central_lock'] = -1,
  ['handle'] = -1,
  ['car_alarm_alert'] = -1,
  ['car_alarm_unlock'] = -1,
  ['car_alarm_lock'] = -1
  -- ['silence'] = -1
}
M.name_of_current_sfx = nil

-- General variables
M.alarm_alert_length = audioUtils.getWavFileLength(v.data.soundscape.car_alarm_alert.src..'.wav')
M.horn = v.data.variables["$horn"].val
M.siren = v.data.variables["$siren"].val
-- M.alarm_alert_length = audioUtils.getWavFileLength(SOUND_FOLDER_PATH..'car_alarm_alert.wav')
-- M.alarm_alert_length = 33   -- car_alarm_alert.wav length -> no proper way of checking the time length because game LUA is missing "WAVE" library || --!UPDATE 27.02.2023: scratch that - found a working function
-- local acousticAlertStopper = nop
M.sound_pitch = nil
local timer = 0

-- =============================================================================
-- US Sound functions
-- =============================================================================
local blip_pulse = true
local blip_timer_threshold = 0.3
local blip_timer = 0
local blip_counter = 0
local blip_counter_threshold = nil
local generateBlipPulse = nop
local blipStopper = nop

local function blipHorn()
	electrics.horn(true)
	electrics.horn(false)
	-- print('HORN')
end

local function generateBlipPulseFun(dt)
	blip_timer = blip_timer + dt
	if blip_timer > blip_timer_threshold then
		if blip_pulse then
			-- print('BLIP PULSE')
			blipHorn()
			blip_counter = blip_counter + 1
		end
		blip_pulse = not blip_pulse
		blip_timer = 0
	end
end

local function blipStopperFun()
	if blip_counter >= blip_counter_threshold then
		generateBlipPulse = nop
		blipStopper = nop
		blip_counter = 0
		blip_timer = 0
		blip_counter_threshold = nil

		batteryManager.removeBatteryPowerConsumer()
		batteryManager.updateBatteryPower()
		print('blipStopperFun')
		M.name_of_current_sfx = nil
	end
end

local function alarmAlertAmerican()
	print(" ")
	batteryManager.addBatteryPowerConsumer()
	batteryManager.updateBatteryPower()
	blip_counter = 0
	blip_counter_threshold = M.alarm_alert_length / (blip_timer_threshold * 2)
	generateBlipPulse = generateBlipPulseFun
	blipStopper = blipStopperFun
end

local function alarmUnlockAmerican()
	print(" ")
	print('alarmUnlockAmerican()')
	batteryManager.addBatteryPowerConsumer()
	batteryManager.updateBatteryPower()
	blip_counter = 0
	blip_timer = blip_timer_threshold -- so it honks without delay
	blip_counter_threshold = 2
	generateBlipPulse = generateBlipPulseFun
	blipStopper = blipStopperFun
end

local function alarmLockAmerican()
	print(" ")
	print('alarmLockAmerican()')
	batteryManager.addBatteryPowerConsumer()
	batteryManager.updateBatteryPower()
	blip_counter = 0
	blip_timer = blip_timer_threshold -- so it honks without delay
	blip_counter_threshold = 1
	generateBlipPulse = generateBlipPulseFun
	blipStopper = blipStopperFun
end

-- =============================================================================
-- EU Sound functions
-- =============================================================================
local function playSoundEffect(name, volume)
	if name == 'handle' or name == 'central_lock' or not isAmericanCar then
		volume = volume or 1
		-- print(dumps(sound_effects_tab))
		-- print(sound_effects_tab[name])
		obj:setVolume(sound_effects_tab[name], volume)
		obj:playSFX(sound_effects_tab[name])
		M.name_of_current_sfx = name
	else
		print('playSoundEffect() USA')
		M.name_of_current_sfx = name..'_us'
		sound_effects_tab[name]()
	end
end

local function stopSoundEffect(name)
	if name == 'handle' or name == 'central_lock' or not isAmericanCar then
		-- print('stopSoundEffect('..name..')')
		obj:setVolume(sound_effects_tab[name], 0)
		obj:cutSFX(sound_effects_tab[name])
		if M.name_of_current_sfx and string.find(M.name_of_current_sfx, name) then M.name_of_current_sfx = nil end
		-- -- cutSFX doesn't stop alarm alert for some reason; workaround below
		-- obj:playSFX(sound_effects_tab['silence'])
	else
		if blip_counter > 0 then blip_counter = blip_counter_threshold end
		print('Do something when american')
	end
end

local function findEngineNode()
	for _, n in pairs(v.data.nodes) do
		if string.find(n.partOrigin, 'engine') then
			return n.cid
		end
	end
	-- Engine node wasn't found - most likely simple traffic version
	for _, n in pairs(v.data.nodes) do
		if string.find(n.partOrigin, 'hood') then
			return n.cid
		end
		-- print("partOrigin")
		-- print(n.partOrigin)
		-- for i, e in pairs(n) do
	--     print(i)
	--     print(e)
		-- end
		-- if string.find(n.partOrigin, 'hood') then
			-- print('!!!!!!!!!!!!!')
		-- end
	end

	print()
	-- return nil
end

local function findSteeringWheelNode()
  -- for _, n in pairs(v.data.props) do 
  --   if string.find(n.partOrigin, 'steer') then
  --     print(dumpsz(n, 1)) 
  --   end 
  -- end

	for _, n in pairs(v.data.props) do
		if string.find(n.partOrigin, 'steer') then
			return n.idRef
		end
	end
  -- Steering wheel node wasn't found - most likely simple traffic version
	for _, n in pairs(v.data.props) do
		if string.find(n.func, 'steer') then
			return n.idRef
		end
		-- print("partOrigin")
		-- print(n.partOrigin)
		-- for i, e in pairs(n) do
	--     print(i)
	--     print(e)
		-- end
		-- if string.find(n.partOrigin, 'hood') then
			-- print('!!!!!!!!!!!!!')
		-- end
	end
	print()
	-- return nil
end

local function findDoorLatchNodes()

  -- for _, n in pairs(v.data.beams) do 
  --   if n.breakGroup ~= nil and string.find(n.breakGroup, 'latch') then 
  --     print(dumpsz(n, 1)) 
  --   end 
  -- end

  local nodes = {} 
  for _, n in pairs(v.data.beams) do 
		if n.breakGroup ~= nil and string.find(n.breakGroup, 'latch') then 
      if nodes[n.breakGroup] == nil then 
        nodes[n.breakGroup] = n.id1 
      end 
		end 
	end

  if #nodes == 0 then
    for _, n in pairs(v.data.beams) do 
      if n.breakGroup ~= nil and string.find(n.breakGroup, 'hinge') then 
        if nodes[n.breakGroup] == nil then 
          nodes[n.breakGroup] = n.id1 
        end 
      end 
    end
  end

  return nodes
end

local function loadSounds(veh_country)
	print('LOAD SOUNDS')

	print('veh_country: '..veh_country)
	isAmericanCar = (veh_country == 'United States')

	local engine_node_cid = findEngineNode()
  local name, latch_node_cid = next(findDoorLatchNodes())
  local steering_wheel_node_cid = findSteeringWheelNode()
	local sample_type = ''
	-- sound_effects_tab['central_lock'] = obj:createSFXSource(SOUND_FOLDER_PATH..'central_lock'..'.'..AUDIO_FILE_FORMAT, sample_type, "", node_cid)
	-- sound_effects_tab['handle'] = obj:createSFXSource(SOUND_FOLDER_PATH..'handle'..'.'..AUDIO_FILE_FORMAT, sample_type, "", node_cid)
	








	-- Specific SFX
	print('isAmericanCar: '..tostring(isAmericanCar))
	M.sound_pitch = 1
	if not isAmericanCar then
		-- M.sound_pitch = math.random(8,12) / 10
		-- local sample_type = ''
		for name, _ in pairs(sound_effects_tab) do
			
			if name == 'car_alarm_alert' then 
				sample_type = 'AudioDefaultLoop3D'
			else
				sample_type = 'AudioDefault3D'
			end
			print(name)

      if name == 'central_lock' then
        node_cid = steering_wheel_node_cid
      else
        node_cid = engine_node_cid
      end
			-- sound_effects_tab[name] = obj:createSFXSource(SOUND_FOLDER_PATH..name..'.'..AUDIO_FILE_FORMAT, sample_type, "", node_cid)
			-- sound_effects_tab[name] = sounds.createSoundscapeSound(name)
			-- sound_effects_tab[name] = obj:createSFXSource(name, sample_type, "", node_cid)
			local sound = v.data.soundscape[name]
			sound_effects_tab[name] = obj:createSFXSource(sound.src, sample_type, "", node_cid)

			-- obj:setVolumePitch(sound_effects_tab[name], 1, M.sound_pitch)
			print(sound_effects_tab[name])
			stopSoundEffect(name)
    end
	else
		sound_effects_tab['car_alarm_alert'] = function() alarmAlertAmerican() end
		sound_effects_tab['car_alarm_unlock'] = function() alarmUnlockAmerican() end
		sound_effects_tab['car_alarm_lock'] = function() alarmLockAmerican() end
	end
	print(dumps(sound_effects_tab))
	return true
end


-- =============================================================================
-- General
-- =============================================================================
-- local function acousticAlertStopperFun(dt)
--     timer = timer + dt
--     if timer >= (M.alarm_alert_length-0.5) then   -- substracting 0.5s for safety buffer (so it doesn't start another loop)
--         acousticAlertStopper = nop
--         timer = 0
--         stopSoundEffect(name_of_current_sfx)
--         name_of_current_sfx = nil

--         print('acousticAlertStopperFun')
--     end
-- end

local function reset()
	blip_pulse = true
	blip_timer = 0
	blip_counter = 0
	blip_counter_threshold = nil
	generateBlipPulse = nop
	blipStopper = nop

	timer = 0
	M.name_of_current_sfx = nil
	M.alarm_alert_length = audioUtils.getWavFileLength(v.data.soundscape.car_alarm_alert.src..'.wav')
	print('Car_alarm_alert.scr: '..tostring(v.data.soundscape.car_alarm_alert.src))
	print('getWavFileLength(): '..tostring(audioUtils.getWavFileLength(v.data.soundscape.car_alarm_alert.src..'.wav')))
	-- if name_of_current_sfx then
	--     stopSoundEffect(name_of_current_sfx)
	--     name_of_current_sfx = nil
	-- end
	-- print(dumps(sound_effects_tab))
	for name, sfx in pairs(sound_effects_tab) do
		-- print('RESET')
		-- print(name)
		stopSoundEffect(name)
	end
	print('accousticSignals reseted!')
end

local function init()
	-- isAmericanCar = v
	-- sound_effects_tab = {
	--     ['car_alarm_alert'] = -1,
	--     ['car_alarm_unlock'] = -1,
	--     ['car_alarm_lock'] = -1,
	--     ['central_lock'] = -1,
	--     ['handle'] = -1
	--     -- ['silence'] = -1
	-- }

	reset()
	-- acousticAlertStopper = nop
	-- timer = 0
	-- name_of_current_sfx = nil

	-- for name, sfx in pairs(sound_effects_tab) do
	--     print('RESET')
	--     print(name)
	--     stopSoundEffect(name)
	-- end
	playSoundEffect('car_alarm_unlock')
	print('accousticSignals init()!')
end

local function updateGFX(dt)
	if isAmericanCar then
		generateBlipPulse(dt)
		blipStopper()
	else
		if M.name_of_current_sfx == 'car_alarm_alert' then
			timer = timer + dt
			if timer >= M.alarm_alert_length then 
				M.name_of_current_sfx = nil
				timer = 0
			end
		end
	end

	-- acousticAlertStopperFun(dt)
end


M.reset = reset
M.init = init
M.loadSounds = loadSounds
M.playSoundEffect = playSoundEffect
M.stopSoundEffect = stopSoundEffect

M.updateGFX = updateGFX

return M