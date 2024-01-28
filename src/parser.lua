--[[
  Copyright 2023 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  Youless return data parser module
  
  Reference:  http://wiki.td-er.nl/index.php?title=YouLess

--]]

local log = require "log"
local json = require "dkjson"


local function jsonparse(device, response)

  local dataobj, pos, err = json.decode (response, 1, nil)
  if err then
    log.error ("JSON decode error:", err)
    device:emit_component_event(device.profile.components.info, cap_status.status('Data error'))
    return nil
  else
    return dataobj
  end

end


return {

  parsedata = function(device, response)
  
    local parsed_data = {
                          ['power'] = 0,
                          ['energy'] = 0,
                          ['phase1_power'] = 0,
                          ['phase2_power'] = 0,
                          ['phase3_power'] = 0,
                        }
    if response then
      local datatbl = jsonparse(device, response)
      
      if datatbl then
        
        if type(datatbl.active_power_w) == 'number' then
          parsed_data['power'] = math.floor(datatbl.active_power_w * 1000) / 1000
        end

        if type(datatbl.total_power_import_kwh) == 'number' then
          parsed_data['energy'] = math.floor(datatbl.total_power_import_kwh * 1000) / 1000
        end

        if type(datatbl.active_power_l1_w) == 'number' then
          parsed_data['phase1_power'] = math.floor(datatbl.active_power_l1_w * 1000) / 1000
        end

        if type(datatbl.active_power_l2_w) == 'number' then
          parsed_data['phase2_power'] = math.floor(datatbl.active_power_l2_w * 1000) / 1000
        end

        if type(datatbl.active_power_l3_w) == 'number' then
          parsed_data['phase3_power'] = math.floor(datatbl.active_power_l3_w * 1000) / 1000
        end
      end
    end
      
    return parsed_data

  end, 
  
  
  parseinfo = function(device, response)
  
    local datatbl = jsonparse(device, response)

    if datatbl then
    
      local infotable = {}
      
      table.insert(infotable, "Model: " .. datatbl.product_type)
      table.insert(infotable, "MAC: " .. datatbl.serial)
      
      return infotable
      
    end
  
  end

}