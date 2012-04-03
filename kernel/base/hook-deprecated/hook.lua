

--[[
local hook = {}
local hook = ...
print(tostring(...))
print("Start")
]]--
local hook = {}

local run = false
local globalHooks = {}
local hooks = {}
local debugEnable = false
local terminateEnabled = true

function hook:termEnable(enable)
    terminateEnabled = enable == true
end

function hook:add(event, name, func)
    syslog:debugString(debugEnable, "hook", "Adding hook '"..name.."' to '"..event.."'")
    if hooks[event] == nil then hooks[event] = {} end
    hooks[event][name] = func
end

function hook:addGlobal(event, name, func)
   syslog:debugString(debugEnable, "hook", "Adding hook '"..name.."' to '"..event.."' level -1")
    if globalHooks[event] == nil then globalHooks[event] = {} end
    globalHooks[event][name] = func
end

function hook:remove(event, name)
    hooks[event][name] = nil
end

function hook:removeGlobal(event, name)
    globalHooks[event][name] = nil
end

function hook:callHooks(hooklist, ...)
    if hooklist ~= nil then
        for k, v in pairs(hooklist) do
            if v ~= nil then
                syslog:debugString(debugEnable, "hook", "--calling: "..k)
                local ok, err = pcall(v, ...)
                if ok == false then
                    print("Error calling hook '"..k.."' "..err)
                    syslog:logString("hook", "Error calling hook '"..k.."' "..err)
                end
            end
        end
    end
end

function hook:call(event, ...)
    
   syslog:debugTable(debugEnable, "hook", "Hook call received for: "..event, { ... })
    
    if globalHooks[event] ~= nil then
        self:callHooks(globalHooks[event], ...)
    end
    
    if globalHooks["catchAll"] ~= nil then
        self:callHooks(globalHooks["catchAll"], event, ...)
    end
    
    if hooks[event] ~= nil then
        self:callHooks(hooks[event], ...)
    end
    
    if hooks["catchAll"] ~= nil then
        self:callHooks(hooks["catchAll"], event, ...)
    end
end

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
        self:removeGlobal("redstone", "hookForceClose")
    end
end
--print("hookenv: "..tostring(_G))
return hook