--[[
Copyright (C) 2012  Jordan (Riddler)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    Contact: PM Riddler80 on http://www.minecraftforum.net
]]--


--[[
local hook = {}
local hook = ...
print(tostring(...))
print("Start")
]]--
local hook = {}

local run = false
--local hooks = {}
local debugEnable = false
--local terminateEnabled = true
local hookHandles = {}

function hook:termEnable(enable)
    terminateEnabled = enable == true
end
--[[
local function getNextFreeHandle()
    local i = 0
    while i < 65535 do
        if hookHandles[i] == nil then
            hookHandles[i] = true
            return i
        end
    end
    return nil
end
]]--
function hook.add(procData, event, func)
    if procData["hooks"] == nil then
        procData["hooks"] = {}
    end
    
    local hooktbl = procData["hooks"]
    
    --local handler = getNextFreeHandle()
    
    syslog:debugString(debugEnable, "hook", "Adding hook to process '"..procData["name"].."' event '"..event.."'")
    
    if hooktbl[event] == nil then hooktbl[event] = {} end
    table.insert(hooktbl[event], func)
end

--[[
function hook:remove(event, handler)
    hooks[event][handler] = nil
    hookHandles[handler] = nil
end
]]--

local function callHooks(hooklist, errorname,  ...)
    if hooklist ~= nil then
        for k, v in pairs(hooklist) do
            if v ~= nil then
                syslog:debugString(debugEnable, "hook", "--calling: "..k)
                local ok, err = pcall(v, ...)
                err = err or "n/a"
                if ok == false and string.find(err, "PROCMANTERM") == nil then --Ignore it throwing an error to terminate
                    print("Error calling hook '"..k.."' for '"..errorname.."' "..err)
                    syslog:logString("hook", "Error calling hook '"..k.."' for '"..errorname.."' "..err)
                end
            end
        end
    end
end

function hook.call(procdata, event, ...)   
   local hooktbl = procdata["hooks"]
   if hooktbl == nil then return end
   
   syslog:logString("hook", "Calling hooks for '"..procdata["name"].."' event '"..event.."'")

    if hooktbl[event] ~= nil then
        callHooks(hooktbl[event], procdata["name"], ...)
    end
    
    if hooktbl["catchAll"] ~= nil then
        callHooks(hooktbl["catchAll"], procdata["name"], event, ...)
    end
end

--[[
function hook:init()
    run = true
    repeat
        local event, param = coroutine.yield() --pullEvent
        if event == "terminate" then
            run = false
        else
            self:call(event, param)
        end
    until run == false
    --Weve just stopped running
    hook:call("terminate")
end

function hook:stop()
    run = false
end
]]--

function hook:debugEnable(enable)
    if enable then
        debugEnable = true
        --[[self:addGlobal("redstone", "hookForceClose", function()
            if redstone.getInput("left") == true then
                hook:stop()
            end
        end)]]--
    else
        debugEnable = false
        --self:removeGlobal("redstone", "hookForceClose")
    end
end
--print("hookenv: "..tostring(_G))
return hook