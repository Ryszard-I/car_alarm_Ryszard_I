local M = {}

local sensors_created = false

local sensors_name_to_id_map = {}
local sensors_id_to_name_map = {}
local sensors_id_to_type = {}
local sensors_state = {}  -- (nodeId -> state) where false=closed and true=open

M.shock_sensor_threshold = 2 * v.data.variables["$sensor_sensitivity"].val--3--1.5
M.shock_sensor_baseline = 0
M.shock_sensor_triggered = false
M.tilt_sensor_threshold = 0.1 * v.data.variables["$sensor_sensitivity"].val--0.07
M.tilt_sensor_triggered = false
-- M.roll_sensor_threshold = 0.2--0.07
-- M.roll_sensor_triggered = false

local door_state = {}


local function createBeamTypeSensors()
  for i, beam_tab in pairs(v.data.beams) do
    -- print(i)
    -- if beam_tab.breakGroup ~= nil then print(beam_tab.breakGroup) end
    if string.find(tostring(beam_tab.breakGroup), "latch") or string.find(tostring(beam_tab.breakGroup), "glass") then

      sensors_name_to_id_map[beam_tab.breakGroup] = beam_tab.cid
      sensors_id_to_name_map[beam_tab.cid] = beam_tab.breakGroup
      -- print(beam_tab.breakGroup)
      sensors_state[beam_tab.cid] = obj:beamIsBroken(beam_tab.cid)
      sensors_id_to_type[beam_tab.cid] = 'beam'

      print('ADDED')
    end

    -- if node.couplerLock == true then dump(node) end
  end
  sensors_created = true
end

local function updateBeamTypeSensors()
  for id,_ in pairs(sensors_state) do
    if sensors_id_to_type[id] == 'beam' then
      sensors_state[id] = obj:beamIsBroken(id)
    end
  end
end

local function onCouplerFound(nodeId, obj2id, obj2nodeId)
  -- If coupler hasn't been added as a sensor yet
  if sensors_name_to_id_map[nodeId] == nil then
    local coupler_node = v.data.nodes[nodeId]
    local coupler_name = coupler_node.partOrigin
    
    -- We are looking for door couplers
    if string.find(coupler_name, 'door') then
      sensors_name_to_id_map[nodeId] = coupler_name
      sensors_state[nodeId] = false
      sensors_id_to_type[nodeId] = 'node'
      print('\nCOUPLER ADDED!!!')
    end
  end

  -- print('\nCOUPLER FOUND!!!')
  -- print('nodeId: '..tostring(nodeId))
  -- print('obj2id: '..tostring(obj2id))
  -- print('obj2nodeId: '..tostring(obj2nodeId))
  -- print(' ')

  -- for i, n in pairs(v.data.nodes) do
  --     if n.cid == nodeId then
  --         print(i)
  --         for c_name,c in pairs(n) do
  --             print(tostring(c_name)..' '..tostring(c))
  --         end
  --         print(' ')
  --         -- print('Node name: '..tostring(n.name))
  --         -- print('Node breakGroup: '..tostring(n.breakGroup))
  --         break
  --     end
  -- end
end

local function onCouplerDetached(nodeId, obj2id, obj2nodeId, breakForce)
  sensors_state[nodeId] = true
end

local function onCouplerAttached(nodeId, obj2id, obj2nodeId, attachSpeed, attachEnergy)

  sensors_state[nodeId] = false
end

-- local function getSensorsState()
--     for name, cid in pairs(sensors_cid) do
--         print(name)
--     end
--     return shallowcopy(sensor_state)
-- end

local function areDoorsClosed()
  for id, state in pairs(sensors_state) do
    if sensors_id_to_name_map[id] and string.find(sensors_id_to_name_map[id], 'latch') then 
      if state == true then return false end
    end
  end
  return true
end


local function tiltSensors()
  -- roll, pitch, yaw = obj:getRollPitchYaw()
  local roll_rate = obj:getRollAngularVelocity()
  local pitch_rate = obj:getPitchAngularVelocity()
  if math.abs(roll_rate) > M.tilt_sensor_threshold or math.abs(pitch_rate) > M.tilt_sensor_threshold then
    print('roll_rate: '..tostring(roll_rate))
    print('pitch_rate: '..tostring(pitch_rate))
    M.tilt_sensor_triggered = true
  else
    M.tilt_sensor_triggered = false
  end
end

local function shockSensors()
  local acc = -vec3(obj:getSensorX(), obj:getSensorY(), obj:getSensorZ())
  if acc:length() > M.shock_sensor_threshold + M.shock_sensor_baseline then
  -- if acc.z > M.shock_sensor_threshold then
    -- print(acc:length())
    print('shockSensors()')
    print('acc_X: '..tostring(acc.x))
    print('acc_Y: '..tostring(acc.y))
    print('acc_Z: '..tostring(acc.z))

    -- print('Shock sensor triggered! '..tostring(acc:length()))
    -- print('M.shock_sensor_baseline + M.shock_sensor_threshold: '..tostring(M.shock_sensor_threshold + M.shock_sensor_baseline))
    -- print('M.shock_sensor_baseline: '..tostring(M.shock_sensor_baseline))
    -- print('obj:getSensorX(): '..tostring(obj:getSensorX()))
    -- print('obj:getSensorY(): '..tostring(obj:getSensorY()))
    -- print('obj:getSensorZ(): '..tostring(obj:getSensorZ()))
    M.shock_sensor_triggered = true
  else
    M.shock_sensor_triggered = false
  end
end

local function printSensorsState()
  print('DEBUG: ')
  -- print(#sensor_state)
  -- print(#sensor_cids)
  -- createSensors()
  for name, state in pairs(sensors_state) do
    print('name: '..name)
    print('state: '..tostring(state))
  end
  print('shock_sensor_triggered: '..tostring(M.shock_sensor_triggered))
  print('DEBUG END')
end

local function init()
  createBeamTypeSensors()
  local acc = -vec3(obj:getSensorX(), obj:getSensorY(), obj:getSensorZ())
  print('Init!')
  print('acc_X: '..tostring(acc.x))
  print('acc_Y: '..tostring(acc.y))
  print('acc_Z: '..tostring(acc.z))
  print('==================================')
  M.shock_sensor_baseline = acc:length()
end

local function updateGFX(dt)
  if not sensors_created then init() end
  updateBeamTypeSensors()
  shockSensors()
  tiltSensors()
end

-- M.init = nop
M.printSensorsState = printSensorsState
-- M.getSensorsState = getSensorsState
M.onCouplerFound = onCouplerFound
M.onCouplerDetached = onCouplerDetached
M.onCouplerAttached = onCouplerAttached
M.areDoorsClosed = areDoorsClosed
M.updateGFX = updateGFX

return M