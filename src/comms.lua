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
  
  HTTP Communications driver

--]]


local cosock = require "cosock"
local socket = require "cosock.socket"
local http = cosock.asyncify "socket.http"
local ltn12 = require "ltn12"
local log = require "log"


local function validate_address(lanAddress)

  local valid = true
  
  if lanAddress then
    local chunks = {lanAddress:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")}
    if #chunks == 4 then
      for _, v in pairs(chunks) do
        if tonumber(v) > 255 then; return; end
      end
      return lanAddress
    end
  end
  
  return
      
end


local function addheaders(headerlist)

  local found_accept = false
  local headers = {}

  if headerlist then
    
    local items = {}
    
    for element in string.gmatch(headerlist, '([^,]+)') do
      table.insert(items, element);
    end
    
    local i = 0
    for _, header in ipairs(items) do
      key, value = header:match('([^=]+)=([^=]+)$')
      key = key:gsub("%s+", "")
      value = value:match'^%s*(.*)'
      if key and value then
        headers[key] = value
        if string.lower(key) == 'accept' then; found_accept = true; end
      end
    end
  end
  
  if not found_accept then
    headers["Accept"] = '*/*'
  end
  
  return headers
end

-- Send http or https request and emit response, or handle errors
local function issue_request(device, req_method, req_url, sendbody, optheaders)

  local responsechunks = {}
  local body, code, headers, status
  
  local protocol = req_url:match('^(%a+):')
  
  http.TIMEOUT = device.preferences.timeout
  
  local sendheaders = addheaders(optheaders)
  
  if sendbody then
    sendheaders["Content-Length"] = string.len(sendbody)
  end

  if protocol == 'http' and sendbody then
    body, code, headers, status = http.request{
      method = req_method,
      url = req_url,
      headers = sendheaders,
      source = ltn12.source.string(sendbody),
      sink = ltn12.sink.table(responsechunks)
     }
     
  else
    body, code, headers, status = http.request{
      method = req_method,
      url = req_url,
      headers = sendheaders,
      sink = ltn12.sink.table(responsechunks)
     }
  end

  local response = table.concat(responsechunks)
  
  log.info(string.format("response code=<%s>, status=<%s>", code, status))
  
  local returnstatus = 'unknown'
  local httpcode_str
  local httpcode_num
  
  if type(code) == 'number' then
    httpcode_num = code
  else
    httpcode_str = code
  end
  
  if httpcode_num then
    if (httpcode_num >= 200) and (httpcode_num < 300) then
      returnstatus = 'OK'
      --log.debug (string.format('Response:\n%s', response))
      
    else
      log.warn (string.format("HTTP %s request to %s failed with http code %s, status: %s", req_method, req_url, tostring(httpcode_num), status))
      returnstatus = 'Failed'
    end
  
  else
    
    if httpcode_str then
      if string.find(httpcode_str, "closed") then
        log.warn ("Socket closed unexpectedly")
        returnstatus = "No response"
      elseif string.find(httpcode_str, "refused") then
        log.warn("Connection refused: ", req_url)
        returnstatus = "Refused"
      elseif string.find(httpcode_str, "timeout") then
        log.warn("HTTP request timed out: ", req_url)
        returnstatus = "Timeout"
      else
        log.error (string.format("HTTP %s request to %s failed with code: %s, status: %s", req_method, req_url, httpcode_str, status))
        returnstatus = 'Failed'
      end
    else
      log.warn ("No response code returned")
      returnstatus = "No response code"
    end

  end

  return returnstatus, response
  
end

return  {
          issue_request = issue_request,
          validate = validate_address,
        }