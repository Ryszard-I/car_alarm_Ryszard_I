local M = {}

M.previous_parked_vehs_data = {}

local function executeActionOnVehicleVM(veh, command)
  veh:queueLuaCommand("for _,v in pairs(controller.getControllersByType('car_alarm_Ryszard_I')) do "..command.." end")
end

local function onParkingSpotChanged(vehId)
  print('onParkingSpotChanged()')
  print('vehId: '..tostring(vehId))
  -- local parked_veh = be:getObjectByID(vehId)
  -- -- executeActionOnVehicleVM(parked_veh, 'v.reset()')
  -- -- toggle(parked_veh)
  
  -- -- executeActionOnVehicleVM(parked_veh, 'v.onReset()')
  -- -- executeActionOnVehicleVM(parked_veh, 'v.toggle("outside")')

  -- executeActionOnVehicleVM(parked_veh, 'v.onAIReset()')

  -- -- executeActionOnVehicleVM(parked_veh, 
  -- --     'v.disableAlarmAlert()'
  -- --     ..' '.. 
  -- --     'v.init()'
  -- --     ..' '..   
  -- --     'v.vehicle_security_system.central_lock_system.state = 1' 
  -- --     ..' '..   
  -- --     'v.vehicle_security_system.alarm_system.armed = true')
  -- print("onParkingSpotChanged() parked_veh: "..tostring(parked_veh:getJBeamFilename()))
  -- executeActionOnVehicleVM(parked_veh, 'print(dumps(v.getSystemState()))')
  -- executeActionOnVehicleVM(parked_veh, 'print("LOL")')
  -- -- executeActionOnVehicleVM(parked_veh, 
  -- --     'print(v.vehicle_security_system.central_lock_system.state)' 
  -- --     ..' '..   
  -- --     'print(v.vehicle_security_system.alarm_system.armed)')


  -- -- executeActionOnVehicleVM(parked_veh, 'v.resetBatteryManager()')
end

local function parkedVehiclesWatcher()
  local parked_vehs_data = extensions.gameplay_parking.getParkedCarsData()
  -- print('parkedVehiclesWatcher()')
  -- print(dumps(parked_vehs_data))
  -- print(dumps(previous_parked_vehs_data))
  for vehId,_ in pairs(parked_vehs_data) do
    if M.previous_parked_vehs_data[vehId] == nil then
      print('M.previous_parked_vehs_data[vehId] is nil')         
      onParkingSpotChanged(vehId)
    elseif parked_vehs_data[vehId].parkingSpotId ~= M.previous_parked_vehs_data[vehId] then 

      print(parked_vehs_data[vehId].parkingSpotId)
      print(M.previous_parked_vehs_data[vehId])
      onParkingSpotChanged(vehId) 
    end
    print('M.previous_parked_vehs_data[vehId]: '..tostring(M.previous_parked_vehs_data[vehId]))
    print('parked_vehs_data[vehId]: '..tostring(parked_vehs_data[vehId].parkingSpotId))
    M.previous_parked_vehs_data[vehId] = parked_vehs_data[vehId].parkingSpotId
    -- print(previous_parked_vehs_data[vehId] == parked_vehs_data[vehId].parkingSpotId)
  end
end

local i=0
local function onUpdate()
  -- if i < 10 then
  --     parkedVehiclesWatcher()
  --     i = i+1
  -- end
  -- parkedVehiclesWatcher()
end

M.parkedVehiclesWatcher = parkedVehiclesWatcher
M.onUpdate = onUpdate

return M