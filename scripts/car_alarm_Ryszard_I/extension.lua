local M = {}

-- Action filters
local action_filters_list = {
  carAlarmBaseActionBlacklist = core_input_actionFilter.createActionTemplate({"walkingMode"}),
  carAlarmVehicleTriggers = core_input_actionFilter.createActionTemplate({"vehicleTriggers"})
}

local parkedVehicles = require("scripts/car_alarm_Ryszard_I/parkedVehicles")
local jbeamFileMgr = require("scripts/car_alarm_Ryszard_I/jbeamFileManager")

local vehicle_list = {}

local max_distance = 2
local vehicle_infront = {veh = nil, locked = 0, dist = max_distance}
-- vehicle_infront_l
local traffic_enabled = false
local parking_vehicles_ids = {}


local function findAllCars()
	-- clear vehicle list
	vehicle_list = {}
	for name, model_data in pairs(extensions.core_vehicles.getModelList().models) do
		if model_data.Type ~= 'Prop' and model_data.Type ~= 'Trailer' then
			-- vehicle_list[#vehicle_list+1] = i
			vehicle_list[name] = model_data
			-- local model = vehicles.getModel()
			-- for name, config in pairs(model.configs) do
			--     print('Config name: '..name)
			--     config[]
			--     model_data[]
			-- end
		end
	end
	table.sort(vehicle_list)
	-- --print(dumps(vehicle_list))
	--print('Total vehicle count: '..tostring(#vehicle_list))
end

-- =============================================================================
-- Getters
-- =============================================================================
local function getAdditionalModSlotName(veh_data)
	local mod_slot_name = nil
	for name, selected_part in pairs(veh_data.chosenParts) do
		if string.find(tostring(name), "_mod") then
			mod_slot_name = name
			return mod_slot_name
		end
	end
	-- No '_mod' entry -> try simply mainPartName
	mod_slot_name = veh_data.mainPartName.."_mod"

	return mod_slot_name
end

local function getVehicleManufacturingInfo(veh_name)
	local veh = vehicle_list[veh_name]
	local manu_info = { Country = veh['Country'], Years = veh['Years']}
	if manu_info.Country == nil then
		log('W', 'car_alarm_Ryszard_I.extension.getVehicleManufacturingInfo()', 'Unable to retreive value "Country" from vehicle "'..veh_name..'"!')
		manu_info.Country = 'Germany'
	elseif manu_info.Years == nil then
		log('W', 'car_alarm_Ryszard_I.extension.getVehicleManufacturingInfo()', 'Unable to retreive value "Years" from vehicle "'..veh_name..'"!')
		manu_info.Years = {min = 1990, max = 1990}
	end
	return manu_info
end

-- =============================================================================
-- Setters
-- =============================================================================
local actions_to_block = {base = 'carAlarmBaseActionBlacklist', triggers = 'carAlarmVehicleTriggers'}

local function setBlockedActions(action_type, state)
	-- --print("Inside setBlockedActions("..action_type..','..tostring(state)..')')
	if not actions_to_block[action_type] then return end
	local selected_filter = actions_to_block[action_type]
	-- --print(selected_filter)
	core_input_actionFilter.setGroup(selected_filter, action_filters_list[selected_filter])
	core_input_actionFilter.addAction(0, selected_filter, state)
	-- --print("Out of setBlockedActions()")
end

-- =============================================================================
-- Boolean functions
-- =============================================================================
local function checkIfVehicleIsDrivable(veh_data)
	--print('checkIfVehicleIsDrivable()    '..tostring(vehicle_list[veh_data.config.model]))
	return vehicle_list[veh_data.config.model]
end

local function checkIfPartExists(veh_obj, mod_slot_name)
	local vehId = veh_obj:getID()

	local veh_data = extensions.core_vehicle_manager.getVehicleData(vehId)
	mod_slot_name = mod_slot_name or getAdditionalModSlotName(veh_data)

	if not veh_data then return false end

	--Only change status if part actually installed
	local parts = veh_data.chosenParts

	-- local mod_slot_name = getAdditionalModSlotName(veh_data)

	local installed_part = parts[mod_slot_name]

	if not installed_part then return false end
	-- print('installed_part name: '..tostring(installed_part))
	-- print('checkIfPartExists returns: '..tostring(string.endswith(installed_part, 'car_alarm_Ryszard_I')))
	return string.endswith(installed_part, 'car_alarm_Ryszard_I') 
end


-- =============================================================================
-- Communication between GElua and Vlua
-- =============================================================================
local function executeFunctionOnVehicleVM(veh, fun)
	veh:queueLuaCommand("controller.getControllerSafe('car_alarm_Ryszard_I')."..fun)
	-- veh:queueLuaCommand("for _,v in pairs(controller.getControllersByType('car_alarm_Ryszard_I')) do "..command.." end")
end

local function updateLockState(veh)
	executeFunctionOnVehicleVM(veh, "updateGELua(getCentralLockState())")
end

-- =============================================================================
-- Interactions
-- =============================================================================
local function test()
	print('\nextension.test()')
	jbeamFileMgr.printFileContent()
	
	local audioUtils = require("scripts/car_alarm_Ryszard_I/audioUtils")
	print('TEST')
	print('Alarm alert file length: '..tostring(audioUtils.getWavFileLength("art/sound/car_alarm_alert.wav")))
end

local function toggle(selected_veh)
	--print('\nextension.toggle()')
	if not selected_veh then
		local veh = be:getPlayerVehicle(0)
		local unicycle = extensions.gameplay_walk.getPlayerUnicycle(veh)
		if not unicycle then
			executeFunctionOnVehicleVM(veh, "toggle('inside')")
		elseif vehicle_infront.veh then
			executeFunctionOnVehicleVM(vehicle_infront.veh, "toggle('outside')")
		else
			ui_message('Key signal did not reach the car. Try closer!')
		end
	else
		executeFunctionOnVehicleVM(selected_veh, "toggle('outside')")  
	end
end

-- =============================================================================
-- Base functions
-- =============================================================================
local castRayTest = 0
function testRaycasting(dtReal)
  castRayTest = castRayTest + dtReal

  local a = vec3(4 + math.sin(castRayTest) * 3,-2+math.cos(castRayTest) * 3,10)
  local b = vec3(4 + math.cos(castRayTest) * 3,-2+math.sin(castRayTest) * 3,-10)
  castRayDebug(a, b, false, false)
end

-- return the point where we hit something on the way from origin to target
-- if nothing is hit, return nil
local function castRayLocation(origin, target)
	local result = vec3()
	local dir = target-origin
	local dist = dir:length()
	local ret = castRayStatic(origin, dir, dist)
	if ret >= dist then return end -- default to zero distance from origin
	result = origin + (dir:normalized()*ret)
	return result
end

local function updateVehicleInFrontDebug(cam_pos, target, veh_pos)
	castRayDebug(cam_pos, target, false, true)
	debugDrawer:drawSphere(veh_pos + vec3(0,0,2), 0.1, ColorF(0,1,0,1))
end

local function updateVehicleInFront(unicycle, max_distance)
	local cam_pos = getCameraPosition()
	local cam_dir = quat(getCameraQuat()) * vec3(0,1,0)
	local uni_pos = unicycle:getPosition()

	local ray_dist = 20
	local target = cam_dir*ray_dist + cam_pos

	local cam_data = core_camera.getCameraDataById(unicycle:getId())

	local closest_veh = nil
	local min_dist = 9999
	local pos
	local dist_to_pos

	if castRay(cam_pos, target, false, true) then 
		local hit = castRay(cam_pos, target, false, true)
		pos = hit.pt
		dist_to_pos = hit.dist
-- castRay returned nil == nothing was hit
	else
		pos = target
		dist_to_pos = ray_dist
	end

	if not pos then return end
	for vehId, veh in activeVehiclesIterator() do
		if veh:getJBeamFilename() ~= "unicycle" then
			local veh_pos = veh:getPosition()
			-- debugDrawer:drawSphere(veh_pos + vec3(0,0,2), 0.1, ColorF(0,1,0,1))
			
			-- updateVehicleInFrontDebug(cam_pos, target, veh_pos)

			local dist_veh_unicycle = vec3(veh_pos):distance(vec3(uni_pos))
			local dist_cam_veh = vec3(veh_pos):distance(vec3(cam_pos))
			local third_side = veh_pos:distanceToLine(cam_pos, pos)

			local dist_cam_pos = vec3(cam_pos):distance(vec3(pos))

			if dist_cam_veh > third_side and third_side < 1.2 then
				closest_veh = veh
				min_dist = third_side
			end
		end
	end
	-- print(closest_veh:getJBeamFilename())
	vehicle_infront.veh = closest_veh
	vehicle_infront.dist = min_dist
	if vehicle_infront.veh then
		ui_message('Vehicle infront: '..vehicle_infront.veh:getJBeamFilename()..'      at distance: '..tostring(min_dist))
	else ui_message('Vehicle infront: nil') end
end

local hit   -- result of raycast
local highlighted_trigger 

local function updateTriggersStatus()
	hit = be:triggerRaycastClosest(true)
	if not hit then return end

	local vData = extensions.core_vehicle_manager.getVehicleData(hit.v)
	if vData and vData.vdata and type(vData.vdata.triggers) == 'table' then
		if highlighted_trigger == vData.vdata.triggers[hit.t] then 
			if extensions.core_input_actionFilter.isActionBlocked('triggerAction0') then
				if string.find(highlighted_trigger.name, 'door') or string.find(highlighted_trigger.name, 'hood') or string.find(highlighted_trigger.name, 'tailgate') or string.find(highlighted_trigger.name, 'boot') then
            
						ui_message("Doors are locked!")
				end
			end
			return
		else
			ui_message('New highlighted_trigger set!', 2)
			highlighted_trigger = vData.vdata.triggers[hit.t]
		end
		-- local highlighted_trigger = vData.vdata.triggers[hit.t]
		-- triggerEvent('action' .. tostring(num), state, hit, highlighted_trigger, vData.vdata)
		
		-- ui_message("If clicked, this action will be scheduled: "..tostring(highlighted_trigger.name), 2)
		-- ui_message(dumps(highlighted_trigger))
		if string.find(highlighted_trigger.name, 'door') or string.find(highlighted_trigger.name, 'hood') or string.find(highlighted_trigger.name, 'tailgate') or string.find(highlighted_trigger.name, 'boot') then

			-- ui_message("Don't run this!")
			-- extensions.core_vehicleTriggers.onCefVisibilityChanged(false)
			setBlockedActions('triggers', true)
			print('Triggers disabled!')
      -- if extensions.core_vehicleTriggers.state.cefVisible == true then 
      --   extensions.core_vehicleTriggers.onCefVisibilityChanged(false)
      -- end
			ui_message("Doors are locked!")
		else
			setBlockedActions('triggers', false)
      -- if extensions.core_vehicleTriggers.state.cefVisible == false then 
      --   extensions.core_vehicleTriggers.onCefVisibilityChanged(true)
      -- end
			print('Triggers enabled!')
		end
-- else
--     setBlockedActions('triggers', false)
	end
end

local done_once = false
local function onPreRender(dtReal, dtSim, dtRaw)
	if not done_once then print('onPreRender()') done_once = true end
	local veh = be:getPlayerVehicle(0)
	local unicycle = extensions.gameplay_walk.getPlayerUnicycle(veh)

	if vehicle_infront.veh then
		if vehicle_infront.locked == 1 then
			updateTriggersStatus()
		else
			setBlockedActions('triggers', false)
		end
	end
end

local function onVehicleSpawned(new_vehId)
  print('onVehicleSpawned('..tostring(be:getObjectByID(new_vehId):getJBeamFilename())..')')
	local veh = be:getObjectByID(new_vehId)
	if not veh then return end

	print('Vehicle: '..veh:getJBeamFilename())
	local unicycle = extensions.gameplay_walk.getPlayerUnicycle(veh)
	-- print('Unicycle: '..tostring(unicycle))
	if not unicycle then
		local veh_data = extensions.core_vehicle_manager.getVehicleData(veh:getID())

		-- If vehicle is not drivable (prop or trailer f.ex.) -> do nothing
		-- if not checkIfVehicleIsDrivable(veh_data) then return end

		local mod_slot_name = getAdditionalModSlotName(veh_data)
		local mod_slot_model_name = string.sub(mod_slot_name, 0, -5)

		if not checkIfPartExists(veh, mod_slot_name) then
			print('Part car_alarm_Ryszard_I NOT installed!')

			if mod_slot_name ~= nil then  
				-- If part not found in file - append
				print(mod_slot_model_name)
				if not jbeamFileMgr.checkIfEntryExists(mod_slot_model_name) then
          print('Part not found in file!')
          jbeamFileMgr.appendToFile(mod_slot_model_name)
				end

				veh_data.config.parts[mod_slot_name] = mod_slot_model_name..'_car_alarm_Ryszard_I'

				local veh_manufactoring_info = getVehicleManufacturingInfo(veh:getJBeamFilename())
				if (veh_manufactoring_info.Years.min + veh_manufactoring_info.Years.max)/2 > 2005 and veh_manufactoring_info.Country == 'Germany' then 
						
          veh_data.config.parts['2car_alarm_class_Ryszard_I'] = 'premium_car_alarm_Ryszard_I'
          veh_data.config.parts["1car_alarm_type_Ryszard_I"] = 	"siren_car_alarm_Ryszard_I"
          veh_data.config.parts['car_alarm_sound_Ryszard_I'] = 'bmw_car_alarm_sound_Ryszard_I'
				
				else
          veh_data.config.parts['2car_alarm_class_Ryszard_I'] = 'standard_car_alarm_Ryszard_I'
          veh_data.config.parts["1car_alarm_type_Ryszard_I"] = 	"siren_car_alarm_Ryszard_I"
          veh_data.config.parts['car_alarm_sound_Ryszard_I'] = 'cobra_car_alarm_sound_Ryszard_I'
				end
				-- veh_data.config.parts['1car_alarm_class_Ryszard_I'] = 

				-- veh_data.config.parts[veh:getJBeamFilename()..'_mod'] = veh:getJBeamFilename()..'_car_alarm_Ryszard_I'

				veh:respawn(serialize(veh_data.config))
        -- veh_data.chosenParts = veh_data.config.parts
        -- extensions.core_vehicles.reloadVehicle(new_vehId)
        -- veh:reset()
				print('onVehicleSpawned() veh:respawn(serialize(veh_data.config))')
        -- print(dumpsz(veh_data.config.parts, 1))
				-- extensions.core_vehicles.replaceVehicle(veh_data.vdata.model, veh_data)
			else
				-- log('W', 'car_alarm_Ryszard_I.extension.onVehicleSpawned()', 'mod_slot_name was nil !!!')
				-- Log('mod_slot_name was nil !!!')
				print('mod_slot_name was nil !!!')
			end
		else
			print('Part car_alarm_Ryszard_I already installed!')
      -- extensions.core_vehicles.reloadVehicle(new_vehId)
		end
    
    -- veh:queueLuaCommand('v.init()')
    -- print(dumpsz(veh_data.config.parts, 1))
    -- veh:respawn(serialize(veh_data.config))
    -- print('onVehicleSpawned() veh:respawn(serialize(veh_data.config))')
    -- veh_data = extensions.core_vehicle_manager.getPlayerVehicleData()
    -- if veh_data then print(dumpsz(veh_data.config.parts, 1)) end

		-- Assign country of origin to local variable in car_alarm_Ryszard_I.lua
		local veh_country = getVehicleManufacturingInfo(veh:getJBeamFilename()).Country
		print(veh_country)
		executeFunctionOnVehicleVM(veh, 'setVehicleCountry("'..veh_country..'")')
		-- local isAmerican = veh_country == "United States"
		-- if isAmerican then executeFunctionOnVehicleVM(veh, 'v.isAmericanCar = true')
		-- else executeFunctionOnVehicleVM(veh, 'v.isAmericanCar = false') end

		-- executeFunctionOnVehicleVM(veh, 'v.isAmericanCar = isAmerican')

		-- executeFunctionOnVehicleVM(veh, 'v.setVehicleCountry(veh_country)')
		-- executeFunctionOnVehicleVM(veh, 'v.isAmericanCar = veh_country == "United States"')
		-- executeFunctionOnVehicleVM(veh, 'print(v.isAmericanCar)')

		-- executeFunctionOnVehicleVM(veh, 'print("Executed on VM: "..veh_country)')
		-- veh:queueLuaCommand('v.setVehicleCountry(veh_country)')
	end
end

local function onUpdate()
	local veh = be:getPlayerVehicle(0)
	-- ui_message(vec3(veh:getPosition()))
	
	local unicycle = extensions.gameplay_walk.getPlayerUnicycle(veh)
	if unicycle then
		local last_veh_infront = vehicle_infront.veh
		updateVehicleInFront(unicycle, max_distance)		
	end

	if result_from_vlua then
		vehicle_infront.locked = result_from_vlua
		result_from_vlua = nil
		ui_message('Vehicle is '..(vehicle_infront.locked == 1 and 'locked' or 'unlocked')..'!')
		--print('vehicle_infront.locked: '..vehicle_infront.locked)
		if vehicle_infront.locked == 1 then setBlockedActions('base', true)
		else setBlockedActions('base', false) end
	end


	parkedVehicles.onUpdate()
end

local function init()
	print('On init!')
	jbeamFileMgr.init()
	findAllCars()

	-- Reload all cars
	-- extensions.core_vehicle_manager.reloadAllVehicles()
	-- for id, veh in activeVehiclesIterator() do
	--     be:reloadAllVehicles()
	--     core_vehicles.reloadVehicle(0)
	--     -- extensions.core_vehicle_manager.reloadVehicle(id)
	--     print(id)
	--     print(veh:getJBeamFilename())
	--     print(veh.vData)
	--     print(veh.data)
	--     print(dumpsz(veh, 2))
	--     print(extensions.core_vehicle_manager.getVehicleData(veh:getID()))
	--     -- onVehicleSpawned(id)
	-- end

	-- local audioChannels = scenetree.findClassObjects('SFXSourceChannel')
	-- for id, elem in pairs(audioChannels) do
	--     print(" ")
	--     print(id)
	--     print(dumpsz(elem,1))
	--     local channel = scenetree.findObject(elem)
	--     if channel then
	--         channel = Sim.upcast(channel)
	--         print(channel:getVolume())
	--     end
	-- end
end

local function onVehicleGroupSpawned(vehList, gid, gName)
	print('onVehicleGroupSpawned()')
	--print(dumps(vehList))
	if gName == 'autoParking' then
		local vehId = vehList[1]
		local veh_obj = be:getObjectByID(vehId)
		--print(veh_obj:getJBeamFilename())
		local veh_data = extensions.core_vehicle_manager.getVehicleData(vehId)
		-- --print(dumps(veh_data.chosenParts))
		-- --print(dumps(veh_data))
		-- --print(dumps(veh_obj))

		



		--print(" ")
		for i,e in pairs(veh_data) do
			print(i)
			-- --print(e)
		end
		--print(" ")
		for i,e in pairs(veh_data.vdata) do
			print(i)
				-- --print(e)
		end
		--print(" ")
		--print(veh_data.vdata.model)
		-- vehicle_list[veh_data.model]
		-- for i,e in pairs(veh_obj) do
				-- --print(i)
				-- --print(e)
		-- end
		--print('============DONE============')
		--print('VEHICLE_LIST')
		for i,_ in pairs(vehicle_list) do
			print(i)
		end
		--print('========================')
		for i,e in pairs(veh_data.config) do
			print(i)
				--print(e)
		end

		-- --print(dumps(veh_data.vdata.information))

		for i=1, #vehList do
			print(be:getObjectByID(vehList[i]):getJBeamFilename())
			local parked_veh = be:getObjectByID(vehList[i])

			if not checkIfPartExists(parked_veh) then
				print('Part car_alarm_Ryszard_I NOT installed!')
		-- toggle(parked_veh)
			else
		--     executeFunctionOnVehicleVM(parked_veh, 'v.onAIReset()')
				-- executeFunctionOnVehicleVM(parked_veh, 
				--     'v.vehicle_security_system.central_lock_system.state = 1' 
				--     ..' '..   
				--     'v.vehicle_security_system.alarm_system.armed = true'
				--     ..' '..
				--     'v.printSystemState()')
				toggle(parked_veh)
				executeFunctionOnVehicleVM(parked_veh, 
          'resetBatteryManager()' 
          ..' '..   
          'resetVisualSignals()'
          ..' '..
          'resetAcousticSignals()')
				executeFunctionOnVehicleVM(parked_veh, 'printSystemState()')
			end
				

				-- -- executeFunctionOnVehicleVM(parked_veh, 'v.batteryManager.resetState()')
				-- executeFunctionOnVehicleVM(parked_veh, 'v.resetBatteryManager()')
				-- executeFunctionOnVehicleVM(parked_veh, 'v.resetVisualSignals()')
				-- --print('parked_veh:isReady(): '..tostring(parked_veh:isReady()))


				-- be:getObjectByID(vehList[i]):queueLuaCommand("electrics.horn(true)")
				-- be:getObjectByID(vehList[i]):queueLuaCommand("electrics.horn(false)")
		end
	end
end

M.test = test
M.toggle = toggle
M.onVehicleSpawned = onVehicleSpawned
M.onPreRender = onPreRender
M.onUpdate = onUpdate

M.init = init
M.onVehicleGroupSpawned = onVehicleGroupSpawned


return M