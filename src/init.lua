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
  
  HomeWizard P1 energy meter driver

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                 -- just for time
local socket = require "cosock.socket"          -- just for time
local comms = require "comms"
local parser = require "parser"
local log = require "log"

-- Module variables
local thisDriver = {}
local initialized = false

-- Constants
local DEVICE_PROFILE = 'homewizard-p1.v1'

-- Custom capabilities

local cap_info = capabilities["partyvoice23922.infotable"]
local cap_status = capabilities["partyvoice23922.status"]
local cap_newdev = capabilities["partyvoice23922.createanother"]


local function create_device(driver)

  log.info("Creating device")
  
  local devices = driver:get_devices()

  local MFG_NAME = 'danieldk'
  local MODEL = 'HomeWizard P1 Meter'
  local VEND_LABEL = 'HomeWizard P1 Meter #' .. tostring(#devices + 1)
  local ID = 'HomeWizardP1V1' .. tostring(socket.gettime())
  local PROFILE = DEVICE_PROFILE

  -- Create device

  local create_device_msg = {
                              type = "LAN",
                              device_network_id = ID,
                              label = VEND_LABEL,
                              profile = PROFILE,
                              manufacturer = MFG_NAME,
                              model = MODEL,
                              vendor_provided_label = VEND_LABEL,
                            }

  assert (driver:try_create_device(create_device_msg), "failed to create device")

end

local function build_html(list)

  if #list > 0 then
  
    local html_list = ''

    for _, item in ipairs(list) do
      html_list = html_list .. '<tr><td>' .. item .. '</td></tr>\n'
    end

    local html =  {
                    '<!DOCTYPE html>\n',
                    '<HTML>\n',
                    '<HEAD>\n',
                    '<style>\n',
                    'table, td {\n',
                    '  border: 1px solid black;\n',
                    '  border-collapse: collapse;\n',
                    '  font-size: 14px;\n',
                    '  padding: 3px;\n',
                    '}\n',
                    '</style>\n',
                    '</HEAD>\n',
                    '<BODY>\n',
                    '<table>\n',
                    html_list,
                    '</table>\n',
                    '</BODY>\n',
                    '</HTML>\n'
                  }
      
    return (table.concat(html))
    
  else
    return (' ')
  end
end

local function update_device_data(device, data)

  if data then
    if data.power then; device:emit_event(capabilities.powerMeter.power(data.power)); end
    if data.energy then; device:emit_event(capabilities.energyMeter.energy({value=data.energy, unit='kWh'})); end
    if data.phase1_power then; device:emit_component_event(device.profile.components.phase1, capabilities.powerMeter.power(data.phase1_power)); end
    if data.phase2_power then; device:emit_component_event(device.profile.components.phase2, capabilities.powerMeter.power(data.phase2_power)); end
    if data.phase3_power then; device:emit_component_event(device.profile.components.phase3, capabilities.powerMeter.power(data.phase3_power)); end
  end

end


local function update_device_info(device, info)

  device:emit_component_event(device.profile.components.info, cap_info.info(build_html(info)))

end


local function fetch_device_data(device, url)

  local ret, response
  local addr = comms.validate(device.preferences.deviceaddr)
  if addr then
    ret, response = comms.issue_request(device, "GET", url, nil, "Accept=application/json")
  else
    log.warn('IP Address not yet configured')
    ret = 'IP not configured'
  end
  
  device:emit_component_event(device.profile.components.info, cap_status.status(ret))
  
  return ret, response

end


local function get_device_info(device)

  local ret, response = fetch_device_data(device, "http://" .. device.preferences.deviceaddr .. "/api")

  if ret == 'OK' then
    update_device_info(device, parser.parseinfo(device, response))
  end
    
end

local function do_refresh(device)

  local ret, e_response, g_response

  ret, response = fetch_device_data(device, "http://" .. device.preferences.deviceaddr .. "/api/v1/data")

  if ret == 'OK' then
    update_device_data(device, parser.parsedata(device, response))
  end
    
end


local function setup_periodic_refresh(driver, device)

  if device:get_field('refreshtimer') then
    driver:cancel_timer(device:get_field('refreshtimer'))
  end

  local refreshtimer = driver:call_on_schedule(device.preferences.refreshfreq, function()
      do_refresh(device)
    end)
    
  device:set_field('refreshtimer', refreshtimer)

end


local function init_data(driver, device)
  if comms.validate(device.preferences.deviceaddr) then
    device.thread:queue_event(get_device_info, device)
    device.thread:queue_event(do_refresh, device)
    setup_periodic_refresh(driver, device)
  end
end

-----------------------------------------------------------------------
--                    COMMAND HANDLERS
-----------------------------------------------------------------------

local function handle_refresh(_, device, command)

  get_device_info(device)
  do_refresh(device)
  
end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
  log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")

  if comms.validate(device.preferences.deviceaddr) then
    init_data(driver, device)
  else
    log.warn('Device IP Address not configured')
  end
  
  initialized = true
  
end

local function handle_createdev(driver, _, _)

  create_device(driver)

end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")

  local init_datatbl = {
          ['energy'] = 0,
          ['power'] = 0,
        }
  
  update_device_data(device, init_datatbl)
  
  device:emit_component_event(device.profile.components.info, cap_status.status("None"))
  device:emit_component_event(device.profile.components.info, cap_info.info(build_html({})))
  
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  -- Nothing to do here!

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  if device:get_field('refreshtimer') then
    driver:cancel_timer(device:get_field('refreshtimer'))
  end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end

local function shutdown_handler(driver, event)

  log.info ('*** Driver being shut down ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  -- Did preferences change?
  if args.old_st_store.preferences then
  
    if args.old_st_store.preferences.deviceaddr ~= device.preferences.deviceaddr then 
      log.info ('IP Address changed to: ', device.preferences.deviceaddr)
      
      init_data(driver, device)
      
    elseif args.old_st_store.preferences.refreshfreq ~= device.preferences.refreshfreq then 
      log.info ('Refresh fequency changed to: ', device.preferences.refreshfreq)
      
      setup_periodic_refresh(driver, device)
    end
  else
    log.warn ('Old preferences missing')
  end  
     
end


-- Create Device
local function discovery_handler(driver, _, should_continue)

  if not initialized then

    create_device(driver)

  else
    log.info ('HomeWizard device already created')
  end
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  driver_lifecycle = shutdown_handler,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = handle_refresh,
    },
    [cap_newdev.ID] = {
      [cap_newdev.commands.push.NAME] = handle_createdev,
    },
  }
})

log.info ('HomeWizard WiFi P1 Meter v1.0 Started')

thisDriver:run()