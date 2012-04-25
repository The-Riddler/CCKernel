local hook = ...

return {
    ["hooks"] = function(procdata, hooktbl)
        if type(hooktbl) == "table" then
            for event, funcs in pairs(hooktbl) do --Key is event name
                if type(funcs) == "table" then --Support multiple functions for same event
                    for _,func in pairs(funcs) do
                        hook.add(procdata, event, func) --add it to the hooks list (stored in procdata)
                    end
                elseif type(funcs) == "function" then --Just one function
                    hook.add(procdata, event, funcs) --add it to the hooks list (stored in procdata)
                else
                    syslog:logString("procman", "Unknown entry in hook table: '"..tostring(funcs).."'")
                end
            end
        else
            syslog:logString("procman", "Hooks table not a table?")
        end
    end,
    ["name"] = function(procdata, name) --Let the program pick a name instead of PID if the parent did not
        if tostring(procdata["pid"]) == procdata["name"] then
            procdata["name"] = name
        end
    end,
    ["main"] = function(procdata, func) --Setup the main function
        if type(func) == "function" then
            procdata["main"] = coroutine.create(func) --Set main function
        else
            syslog:logString("procman", "Main function not a function?")
        end
    end
}