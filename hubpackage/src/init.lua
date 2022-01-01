--[[
  Copyright 2021 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  SmartThings WLED Edge Driver:  Send commands to an WLED Server on the LAN
  
  This is a port of a SmartThings DTH originally created by Wesley Menezes (@w35l3y in the SmartThings Community)

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"
local socket = require "cosock.socket"
local http = cosock.asyncify "socket.http"                              --non blocking calls
http.TIMEOUT = 3
local ltn12 = require "ltn12"
local log = require "log"


-- Custom Capabiities
local capdefs = require "capabilitydefs"
local cap_requestpath = capabilities.build_cap_from_json_string(capdefs.requestpath)
capabilities["valleyboard16460.httprequestpath"] = cap_requestpath
local cap_effectmode = capabilities.build_cap_from_json_string(capdefs.effectmode)
capabilities["partyvoice23922.wledeffectmode2"] = cap_effectmode
local cap_createdev = capabilities.build_cap_from_json_string(capdefs.createdev_cap)
capabilities["partyvoice23922.createanother"] = cap_createdev


-- Module variables
local thisDriver = {}
local initialized = false
local lastinfochange = socket.gettime()


local function disptable(table, tab, maxlevels, currlevel)

	if not currlevel then; currlevel = 0; end
  currlevel = currlevel + 1
  for key, value in pairs(table) do
    if type(key) ~= 'table' then
      log.debug (tab .. '  ' .. key, value)
    else
      log.debug (tab .. '  ', key, value)
    end
    if (type(value) == 'table') and (currlevel < maxlevels) then
      disptable(value, '  ' .. tab, maxlevels, currlevel)
    end
  end
end

function split(str, pat)
  local t = {}
  local fpat = "(.-)" .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= "" then
      table.insert(t, cap)
    end
    last_end = e+1
    s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
  end
  return t
end

function split_path(str)
   return split(str,'[\\/]+')
end


local function create_device(driver)

  local MFG_NAME = 'SmartThings Community'
  local MODEL = 'WLED Device'
  local VEND_LABEL = 'WLED Device'
  local ID = 'WLED_' .. socket.gettime()
  local PROFILE = 'wled.v1'

  log.info (string.format('Creating new device: label=<%s>, id=<%s>', VEND_LABEL, ID))

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


local function handle_createdev(driver, device, command)

  create_device(driver)

end


local function send_request(addr, path)

  local responsechunks = {}
  
  local body, code, headers, status
  local sendurl = 'http://' .. addr .. path
  
  log.debug('SENDING:', sendurl)
  
  local body, code, headers, status = http.request {
    method = 'GET',
    url = sendurl,
    sink = ltn12.sink.table(responsechunks)
  }

  local response = table.concat(responsechunks)
  
  log.info(string.format("response code=<%s>, status=<%s>", code, status))
  
  local returnstatus = 'unknown'
  
  if code ~= nil then

    if string.find(code, "closed") then
      log.warn ("Socket closed unexpectedly")
      returnstatus = string.format("No response")
    elseif string.find(code, "refused") then
      log.warn("Connection refused: ", addr)
      returnstatus = "Refused"
    elseif string.find(code, "timeout") then
      log.warn("HTTP request timed out: ", addr)
      returnstatus = "Timeout"
    elseif code ~= 200 then
      log.warn (string.format("HTTP %s request to %s failed with code %s, status: %s", req_method, addr, tostring(code), status))
      if type(code) == 'number' then
        returnstatus = string.format('HTTP error %s', tostring(code))
      else
        returnstatus = 'Failed'
      end
      
    else
      log.debug ('OK 200 Response:')
      log.debug (response)
      return true, response
    end
  end

  return false, returnstatus

end


local off       -- forward reference
local request   -- forward reference

local function setlevel(device, level)

  if level == 0 then
    off(device)
    device:emit_event(capabilities.switchLevel.level(0))
    
  else
    device:set_field('latestLevel', level)
    device:emit_event(capabilities.switchLevel.level(level))
    device:emit_event(capabilities.switch.switch('on'))
    request(device)
  end
end

local function on(device)
  setlevel(device, device:get_field('latestLevel') or 100)
end

off = function(device)

  device:emit_event(capabilities.switch.switch('off'))
  request(device)
  
end

local function formatRequest (device, field)

  --disptable(device.state_cache.main, '  ', 3)
  
  local capname = { 
                    ['hue'] = 'colorControl',
                    ['saturation'] = 'colorControl',
                    ['switch'] = 'switch',
                    ['level'] = 'switchLevel',
                    ['effectMode'] = 'partyvoice23922.wledeffectmode2',
                  }

  local value = device.state_cache.main[capname[field]][field].value
  
  if field == 'hue' then
    return (math.floor((655.35 * value) + 0.5))
  elseif (field == 'saturation') or (field == 'level') then
    return (math.floor((2.55 * value) + 0.5))
  elseif field == 'switch' then
    return value == 'on' and 1 or 0
  else
    return value
  end
end


request = function(device)

  local pathstring = ''
  for k, v in string.gmatch(device.preferences.ppath, '(%w+)=([%w_]+)&*') do
		local fieldname = string.gsub(v, "__", "")
    if pathstring ~= '' then; pathstring = pathstring .. '&'; end
    pathstring = pathstring .. string.format('%s=%s', k, formatRequest (device, fieldname))
	end
  
  local userpath = device.state_cache.main['valleyboard16460.httprequestpath'].path.value
  
  if userpath then
    if string.sub(userpath, 1, 1) == '&' then
      pathstring = pathstring .. userpath
    else
      pathstring = pathstring .. '&' .. userpath
    end
  end

  pathstring = '/win&' .. pathstring
  
  local success, response = send_request(device.preferences.phost, pathstring)

  if success then
    log.info ('HTTP Request successfully sent')
  else
    log.error ('HTTP Request failed:', response)
  end
  
end


-- CAPABILITY HANDLERS

local function handle_switch(driver, device, command)

  log.info ('Switch pressed')
  
  if command.command == 'on' then
    on(device)
  else
    off(device)
  end
  
end

local function handle_level(driver, device, command)

  log.info ('Virtual level changed to >> ' .. command.args.level .. ' <<')
  
  setlevel(device, command.args.level)

end

local function handle_colorcontrol(driver, device, command)

  log.debug (string.format('Color control handler invoked with command %s', command.command))
  
  if command.command == 'setColor' then
    log.debug (string.format('\thue:%s saturation:%s', command.args.color.hue, command.args.color.saturation))
    device:emit_event(capabilities.colorControl.hue(command.args.color.hue))
    device:emit_event(capabilities.colorControl.saturation(command.args.color.saturation))
  elseif command.command == 'setHue' then
    log.debug (string.format('\thue:%s', command.args.hue))
    device:emit_event(capabilities.colorControl.hue(command.args.hue))
  elseif command.command == 'setSaturation' then
    log.debug (string.format('\tsaturation:%s', command.args.saturation))
    device:emit_event(capabilities.colorControl.saturation(command.args.saturation))
  end
  
  on(device)
  
end

local function handle_effectmode(driver, device, command)

  log.info ('Effect mode selection:', command.args.effectMode)
  device:emit_event(cap_effectmode.effectMode(command.args.effectMode))
  on(device)

end

local function handle_requestpath(driver, device, command)

  log.info ('Request Path Command / value:', command.command, command.args.value)
  device:emit_event(cap_requestpath.path(command.args.value))
  request(device)

end

local function handle_createdev(driver, device, command)

  create_device(driver)

end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
    log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")
  
    log.debug('Exiting device initialization')
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")

  device:set_field('latestLevel', 0)

  device:emit_event(capabilities.switch.switch('off'))
  device:emit_event(capabilities.switchLevel.level(0))
  device:emit_event(capabilities.colorControl.hue(0))
  device:emit_event(capabilities.colorControl.saturation(0))
  device:emit_event(cap_requestpath.path('RV=0&SS=0&SV=1'))
  device:emit_event(cap_effectmode.effectMode(0))
  
  initialized = true
      
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  log.info ('Device doConfigure lifecycle invoked')

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  local device_list = driver:get_devices()
  
  if #device_list == 0 then
    log.warn ('All devices removed; driver disabled')
  end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  local timenow = socket.gettime()
  local timesincelast = timenow - lastinfochange

  log.debug('Time since last info_changed:', timesincelast)
  
  lastinfochange = timenow
  
  -- Did preferences change?
  if args.old_st_store.preferences then
  
    if args.old_st_store.preferences.phost ~= device.preferences.phost then
      log.info ('Host address changed to: ', device.preferences.phost)
      
    elseif args.old_st_store.preferences.ppath ~= device.preferences.ppath then 
      log.info ('Path changed to: ', device.preferences.ppath)
--[[    
    else
      -- Assume driver is restarting - shutdown everything
      log.debug ('****** DRIVER RESTART ASSUMED ******')
      
--]]      
    end
  end
end


-- Create Initial Device
local function discovery_handler(driver, _, should_continue)
  
  log.debug("Device discovery invoked")
  
  if not initialized then
    create_device(driver)
  end
  
  log.debug("Exiting discovery")
  
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
  
  capability_handlers = {
    [cap_requestpath.ID] = {
      [cap_requestpath.commands.setPath.NAME] = handle_requestpath,
    },
    [cap_effectmode.ID] = {
      [cap_effectmode.commands.setEffectMode.NAME] = handle_effectmode,
    },
    [capabilities.switch.ID] = {
      [capabilities.switch.commands.on.NAME] = handle_switch,
      [capabilities.switch.commands.off.NAME] = handle_switch,
    },
    [capabilities.switchLevel.ID] = {
      [capabilities.switchLevel.commands.setLevel.NAME] = handle_level,
    },
    [capabilities.colorControl.ID] = {
      [capabilities.colorControl.commands.setColor.NAME] = handle_colorcontrol,
      [capabilities.colorControl.commands.setHue.NAME] = handle_colorcontrol,
      [capabilities.colorControl.commands.setSaturation.NAME] = handle_colorcontrol,
    },
    [cap_createdev.ID] = {
      [cap_createdev.commands.push.NAME] = handle_createdev,
    },
  }
})

log.info ('WLED Driver v0.1 Started')


thisDriver:run()
