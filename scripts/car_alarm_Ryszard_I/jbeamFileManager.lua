local M = {}

local template_file = 'vehicles/common/template_entry.jbeam'
local dynamic_file = 'vehicles/common/car_alarm_Ryszard_I.jbeam'

local jbeamIO = require('jbeam/io')
-- local test_file = 'vehicles/common/test_file.jbeam'
-- local written_file = 'vehicles/common/car_alarm_Ryszard_I.jbeam'
-- local dynamic_file = 'vehicles/common/write_test.jbeam'
-- local writeJson_test_file = 'vehicles/common/writeJson_test_file.jbeam'

local function printElem(elem, indent)
    print(string.rep(" ", indent)..elem)
end

local function printTree(tree_structure, current_indent)
  if tree_structure ~= nil then
    for i,e in pairs(tree_structure) do
      printElem(i,current_indent)
      -- printElem(e,current_indent)
      if e ~= nil then
        if type(e) == 'table' then 
          printTree(e, current_indent+3)
        else
          printElem(e, current_indent+3)
        end
      end
    end
  end
end

local function readFileContent(filepath)
  local json_file = readJsonFile(filepath)
  print(json_file)
  for i,e in pairs(json_file) do
    print(i)
    print(e)
  end
  -- dumps(json_file)
  -- printTree(json_file, 0)
  return json_file
end

local function copyToFile(content, filepath)
  writeJsonFile(filepath, content, true)
end

local function writeMissingEntriesToFile()
    -- writeJsonFile(filename, obj, pretty, numberPrecision)

end

local stage_1_done = false
local stage_2_done = false

local function performPerformanceTest(veh_list)
  -- readFileContent(written_file)
  if not stage_1_done then 
    readFileContent(writeJson_test_file)
    stage_1_done = true
    print('Stage 1 DONE')
    return
  end
  if not stage_2_done then 
    copyToFile(readFileContent(test_file), writeJson_test_file)
    readFileContent(writeJson_test_file)
    stage_2_done = true
    print('Stage 2 DONE')
    return
  end
  readFileContent(writeJson_test_file)
  print('Stage 3 DONE')
end

local function updateGFX(dt)

end



local function printFileContent()
  -- local filepath = 'vehicles/common/template.jbeam'
  -- local content = readFileContent('vehicles/common/old_template.txt')
  local content = readFileContent(dynamic_file)
  print(dumps(content))
end

local function checkIfEntryExists(veh_name)
  -- local filepath = 'vehicles/common/template.jbeam'
  local content = readFileContent(dynamic_file)
  return content[veh_name..'_car_alarm_Ryszard_I'] ~= nil
end

local function appendToFile(veh_name)
  -- local filepath = 'vehicles/common/write_test.jbeam'
  -- local filepath = 'vehicles/common/template.jbeam'
  local template_entry = readFileContent(template_file)
  local content = readFileContent(dynamic_file)
  -- if not content then (function() {init() appendToFile(veh_name)} end) end
  content[veh_name..'_car_alarm_Ryszard_I'] = template_entry['template_car_alarm_Ryszard_I']
  content[veh_name..'_car_alarm_Ryszard_I']['slotType'] = veh_name..'_mod'
  -- content[veh_name..'_car_alarm_Ryszard_I']['slotType'] = veh_name..'_alarm'


  -- content_to_append['car_alarm_Ryszard_I']['slotType'] = veh_name..'_mod'
  print(dumps(content))
  copyToFile(content, dynamic_file)
  print('FILE APPENDED!')

  -- jbeamIO.onFileChanged(dynamic_file, 'jbeam')
  -- extensions.core_vehicles.onFileChanged('car_alarm_Ryszard_I', 'jbeam')
  extensions.core_vehicles.clearCache()
  -- jbeamIO.onFileChanged('car_alarm_Ryszard_I', 'jbeam')
end

local function init()
  print('jbeamFileManager init!!!')
  -- Clear dynamic file
  io.open(dynamic_file,"w"):close()
  local content = readFileContent(template_file)
  print(dumps(content))
  local dyn_content = readFileContent(dynamic_file)
  print(dumps(dyn_content))

  -- copyToFile(content, dynamic_file)
  -- printFileContent()
end

M.performPerformanceTest = performPerformanceTest
M.updateGFX = updateGFX
M.readFileContent = readFileContent
M.checkIfEntryExists = checkIfEntryExists
M.appendToFile = appendToFile

M.printFileContent = printFileContent
M.init = init

return M