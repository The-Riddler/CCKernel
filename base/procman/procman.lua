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
struct procdata:
    hooks = { [event] = {func1, func2, ...} }
    pid = {}
    name = string
    children = {}
    parent = number(pid)
    suspended = bool
    state = string
    file = string(dir)
]]--

--[[
Set up our directory
]]--
local procmanDIR = kernel.dir.."base/procman/"

--[[
Load hook lib
]]--
syslog:logString("procman", "Loading hook lib")
local hook = assert(loadfile(procmanDIR.."hook.lua"))
if hook == nil then 
    syslog:logString("procman", "Unable to load hook lib, terminating") 
    error("Unable to load hook lib, terminating") 
else
    setfenv(hook, getfenv(1)) --Run in our environment
    hook = hook()
end

--[[
Load parse functions
]]--
syslog:logString("procman", "Loading return parse functions")
local retvalParseFunctions = assert(loadfile(procmanDIR.."parsefunctions.lua"))
if retvalParseFunctions == nil then
    syslog:logString("procman", "Unable to load parse functions, terminating") 
    error("Unable to load parse functions, terminating") 
else
    setfenv(retvalParseFunctions, getfenv(1)) --Run in our environment
    retvalParseFunctions = retvalParseFunctions(hook)
end

--CURRENT always points to the current process
local CURRENT = nil

--Statuscodes, I hate functions that just return "nil", that's not helpful
local statuscodes = {}
statuscodes.STAT_OK = 0
statuscodes.STAT_404 = 1
statuscodes.STAT_CALL = 2
statuscodes.STAT_LOAD = 3
statuscodes.STAT_OK_RET = 4
statuscodes.STAT_DATAERROR = 5
statuscodes.STAT_ALLOCPID = 6
statuscodes.STAT_OK_RUNNING = 7
statuscodes.STAT_RUNTIME_ERROR = 8

--PID -> procdata list
local procHandlers = {}

--Run (so we can stop procman")
local listenForEvents = false

--errortostring
local function errorToString(errcode)
    for k, v in pairs(statuscodes) do
        if v == errcode then
            return k
        end
    end
    return nil
end


--Setup any values that NEED to be initialized
local function setupProcdata(procdata)
    procdata["suspended"] = false
    procdata["children"] = {}
    return procdata
end

--Get the next free PID and return a iniialized procdata table
local function getNextFreeHandle()
    local i = 1
    while i < 256 do --Limit to 256, why the hell would you need more?
        if procHandlers[i] == nil then
            local procdata = setupProcdata({["pid"] = i})
            procHandlers[i] = procdata
            return procdata
        end
        i = i + 1
    end
    return nil
end

local function sendEvent(pid, event, ...)
    os.queueEvent("PROCMAN-CEvent", pid, event, ... )
end

--[[--------------------------------------------------
Name: removeProcdata
Called: Internally
Job: 
-Remove a procdata struct
-Mark it as a "zombie" (Z) if we cant kill it yet (it has children)
-Clean up any parent "zombie" processes that can now be killed
Returns: true if it was deleted, false if its been marked as "Z"
-]]---------------------------------------------------
local function removeProcdata(procdata, resumestring)
    syslog:logString("procman", "Removing procdata for "..procdata["name"])
    
    if next(procdata["children"]) == nil then --if we have no children
        --Clean up a parent that was waiting for us
        if procdata["parent"] ~= nil then
            
            local parentproc = procHandlers[procdata["parent"]]
            local children = parentproc["children"] --Remove us from the list, as were now dead
            for k, v in ipairs(children) do
                if v == procdata["pid"] then
                    table.remove(children, k)
                    break
                end
            end
                
            if parentproc["state"] == "Z" then
                syslog:logString("procman", "Cleaning up parent data")
                if next(children) == nil then --If we where the last, remove the parent
                    syslog:logString("procman", "Removing parent: "..parentproc["name"])
                    removeProcdata(parentproc)
                end
            elseif parentproc["state"] == "WaitingForChild" then --Resume a waiting parent
                if parentproc["statemetadata"] == procdata["pid"] then
                    syslog:logString("procman", "Resuming waiting parent")
                    parentproc["state"] = nil
                    parentproc["suspended"] = false
                    parentproc["statemetadata"] = nil
                    sendEvent(parentproc["pid"], resumestring or "ok")
                end
            end
        end
        procHandlers[procdata["pid"]] = nil --set it to nil (remove our procdata)
        return true
    else
        --Mark us as waiting        
        procdata["state"] = "Z"
        procdata["suspended"] = true
        local children = 
        syslog:logString("procman", procdata["name"].." waiting for children: ")
        return false
    end
end

--Add a child to a procdata struct
local function addChild(procdata, child)
    table.insert(procdata["children"], child["pid"])
end

--[[--------------------------------------------------
Name: Terminate
Called: By a porgram
Job: terminate the process
returns: 
--]]--------------------------------------------------
local function terminate(pid)
    if pid == nil then --kill ourself
        syslog:logString("procman", "Process '["..CURRENT["pid"].."]"..CURRENT["name"].."' terminated itself")
        --Call terminate event
        hook.call(CURRENT, "terminate")
        
        --remove the procdata
        if removeProcdata(CURRENT) == false then
            syslog:logString("procman", "Process '"..CURRENT["name"].."' marked as 'Z'")
        else
            syslog:logString("procman", "Process '"..CURRENT["name"].."' removed")
        end
        error("PROCMANTERM") --Easiest way to terminate it then and there, without continueing following code.
    else
        if procHandlers[pid] ~= nil then
            local procdata = procHandlers[pid]
            hook.call(procdata, "terminate")
            if procdata["parent"] == CURRENT["pid"] then
                syslog:logString("procman", "Process '"..CURRENT["name"].."' terminated '"..pid.."'")
                return true, removeProcdata(procdata)
            end
        else
            return false
        end
    end
end

--[[--------------------------------------------------
Name: getPID
Called: By a porgram
Job: get its PID
returns: PID
--]]--------------------------------------------------
local function getPID()
    return CURRENT["pid"]
end

--[[--------------------------------------------------
Name: getCWD
Called: By a porgram
Job: get its CWD
returns: CWD
--]]--------------------------------------------------
local function getCWD()
    if CURRENT == nil then
        return nil
    end
    return CURRENT["cwd"]
end

--[[--------------------------------------------------
Name: setCWD
Called: By a porgram
Job: set its CWD
returns: bool - success
--]]--------------------------------------------------
local function setCWD(dir) --Abolute plx
    if type(dir) == "string" and dir ~= "" and fs.exists(dir) and fs.isDir(dir) then
        CURRENT["cwd"] = dir
        return true
    end
    return false
end

--[[--------------------------------------------------
Name: procdataInheritInfo
Called: internally
Job: Inherit information from parent if nessesary
returns:
--]]--------------------------------------------------
local function procdataInheritInfo(procdata, background)
    if CURRENT ~= nil then --If were a child process setup data to reflect as much. Also suspend parent if it wants us in foreground
        procdata["parent"] = CURRENT["pid"] --Assign us as X's child
        procdata["cwd"] = CURRENT["cwd"] --Copy parents cwd
        if background == false then --suspend parent
            syslog:logString("procman", "Suspending parent process, child created in foreground")
            CURRENT["suspended"] = true
            CURRENT["state"] = "WaitingForChild"
            CURRENT["statemetadata"] = procdata["pid"]
        end
    else
        procdata["parent"] = nil
        procdata["cwd"] = "/"
    end
end

--[[--------------------------------------------------
Name: parseProgramReturn
Called: internally
Job: parse the return and do whatever is nessesary
returns:
--]]--------------------------------------------------
local function parseProgramReturn(procdata, retval)
    local rettype = type(retval)
    if rettype == "nil" then --One shot
        --If we can't remove the procdata suspend the parent if we need to
        if removeProcdata(procdata) == false and background == false then
            coroutine.yield()
        end
        return statuscodes.STAT_OK
    elseif rettype ~= "table" then --Not process info, pass it on
        --If we can't remove the procdata suspend the parent if we need to
        if removeProcdata(procdata) == false and background == false then
            coroutine.yield()
        end
        return statusCodes.STAT_OK_RET
    else --Table, process it
        for k, v in pairs(retvalParseFunctions) do --Run the parse functions
            if retval[k] ~= nil then
                v(procdata, retval[k])
            end
        end
        return statuscodes.STAT_OK_RUNNING
    end
end

--[[--------------------------------------------------
Name: Run
Called: By a porgram
Job: Spawn a new process from a file
returns:statuscode, error(if applicable)
--]]--------------------------------------------------
--FIXME: This function can be split up into smaller functions to allow people other than me to read it easily.
local function run(path, name, env, background, ...)
    syslog:logString("procman", "Spawning process from file: "..path)

    if not fs.exists(path) or fs.isDir(path) then 
        syslog:logString("procman", "Error: could not locate file: "..path)
        return statuscodes.STAT_404 --Let the caller know why we failed
    end 
    
    --We want this used outside of the if statement that pcalls the code
    local retval
    
    --Create a procdata struct for us
    local procdata = getNextFreeHandle()
    if procdata == nil then
        syslog:logString("procman", "Error: could not allocate PID. What do you think think I am, a supercomputer?")
        return statuscodes.STAT_ALLOCPID --Let the caller know why we failed
    end
    
    --Fill in the data (PID is automatically assigned)
    procdata["name"] = name or tostring(procdata["pid"]) --Name if supplied or PID
    procdata["file"] = path --Set the file variable to the file code is in
    procdataInheritInfo(procdata, background)

    --Load the file
    local code, err = loadfile(path)
    
    --If its loaded correctly then run it
    if code ~= nil then
        --Use given env or the environment of the process calling run
        setfenv(code, env or getfenv(2)) --Set to env or our callers environment

        --keep current pointer up to date (set it to the process  being spawned as we are about to run it)
        local oldcurrent = CURRENT
        CURRENT = procdata
        
        --Call the code
        local ok, err = pcall(code, ...) 
        
        if not ok then --Problem?
            syslog:logString("procman", "Error calling file: "..path.." error: "..tostring(err))
            
            --Cleanup the unneeded entry
            removeProcdata(procdata)
            
            --restore current
            CURRENT = oldcurrent
            
            return statuscodes.STAT_CALL, err --Let them know we failed when calling
        end
        retval = err
        
        --Keep current pointer up to date (set it back to the previous value)
        CURRENT = oldcurrent
        
        --Add the current process as a child of the parent (if there was one)
        if CURRENT ~= nil then addChild(CURRENT, procdata) end
    else
        --Couldn't load the file? Rare, but it happens.
        syslog:logString("procman", "Error loading file: "..path.." error: "..err)
        removeProcdata(procdata)
        return statuscodes.STAT_LOAD, err
    end
    
    --Parse return, info about the process
    local status = parseProgramReturn(procdata, retval)

    
    syslog:logString("procman", "Spawned process pid: "..procdata["pid"].." name: "..procdata["name"])
    if background == false then
        --child isn't dead and caller wanted it in foreground
        local resumeevent = coroutine.yield()
        syslog:logString("procman", "Parent["..CURRENT["pid"].."] resume event: "..resumeevent)
        if resumeevent ~= "ok" then
            return statuscodes.STAT_RUNTIME_ERROR, resumeevent
        end
    end
    
    if status == statuscodes.STAT_OK then --just finished
        return status, procdata["pid"]
    elseif status == statuscodes.STAT_OK_RET then --It returned with a non-table return
        return status, retval, procdata["pid"]
    else
        return statuscodes.STAT_OK_RUNNING, procdata["pid"] --Were done, YAY!
    end
end

--[[--------------------------------------------------
Name: isOk
Called: By a program/internally
Job: return if the statuscode is an "ok" one
returns: ok
--]]--------------------------------------------------
local function isOk(stat)
    return stat == statuscodes.STAT_OK or 
    stat == statuscodes.STAT_OK_RET or
    stat == statuscodes.STAT_OK_RUNNING
end


--[[--------------------------------------------------
Name: runSimple
Called: By a program
Job: Spawn a new process from a file -- simplify return status
returns: ok
--]]--------------------------------------------------
local function runSimple(path, name, env, background,  ...)
    local stat, err = run(path, name, env, background, ...)
    if not isOk(stat) then
        return false, tostring(stat).."::"..tostring(err)
    end
    return true, err
end

--[[--------------------------------------------------
Name: resolve
Called: By a program
Job: check standard paths for the program
returns: path or nil
--]]--------------------------------------------------
local function resolve(name)
    local paths = {
        "/usr/local/programs",
        "/usr/programs/",
        kernel.dir.."usr/programs/"
        }

    for k, v in ipairs(paths) do
        local fname = v..name
        if fs.exists(fname) and not fs.isDir(fname) then
            return fname
        end
    end
    return nil
end

--[[--------------------------------------------------
Name: callProcess
Called: internally
Job: call hooks/main thread
returns:
--]]--------------------------------------------------
local function callProcess(procdata, event, eventinfo)
    if procdata["suspended"] ~= true then --If it's not suspended, run it
        local oldcurrent = CURRENT --Keep CURRENT up to date
        CURRENT = procdata
        
        hook.call(procdata, event, unpack(eventinfo)) --Call hook for that event
        
        --Call main thread
        if procdata["main"] ~= nil then
            local returns = { coroutine.resume(procdata["main"], event, unpack(eventinfo)) }
            if coroutine.status(procdata["main"]) == "dead" then
                procdata["main"] = nil
                
                --Check for if it errord
                if returns[1] == false and not string.find(returns[2], "PROCMANTERM") then --it errored
                    --show error
                    syslog:logString("procman", "Process '"..CURRENT["name"].."' error in main thread: '"..returns[2].."' terminating")
                end
                
                --Kill program
                removeProcdata(CURRENT, returns[2])
            end
        end
        
        --Update current again
        CURRENT = oldcurrent
    end
end

--[[--------------------------------------------------
Name: init
Called: By kernel
Job: Create initial process (init) and then listen for events
returns:
--]]--------------------------------------------------
local function init(path, env)
    if next(procHandlers) ~= nil then
        --Init already called? Serious code error to cause this to happen. KERNEL ONLY KTHX BAI
        error("Danger, Will Robinson!, Danger!")
    end
    
    --Spawn init process, it's fatal if this doesn't work
    local stat, err = run(path, "init", env)
    if not isOk(stat) then
        error("Error: clould not spawn init process <"..stat..","..tostring(err)..">")
    end
    
    --table:print(procHandlers)
    
    syslog:logString("procman", "Listening for events")
    listenForEvents = true --Defined global to the script
    
    local thinkHandle = os.startTimer(1) --Think event triggered every second
    repeat
        local eventinfo = { coroutine.yield() }
        local event = table.remove(eventinfo, 1)
        local arg = eventinfo[1]
        
        --Think event handleing
        if event == "timer" and arg == thinkHandle then
            event = "think"
            --Set one for next time
            thinkHandle = os.startTimer(1)
        end
        
        --call custom events
        if event == "PROCMAN-CEvent" then 
            local pid = table.remove(eventinfo, 1)
            event = table.remove(eventinfo, 1)
            syslog:logString("procman", "Calling custom event: "..pid.." "..event)
            if procHandlers[pid] ~= nil then
                callProcess(procHandlers[pid], event, eventinfo)
            end
        else
            --Do the work and call each process in turn
            --for k, procdata in pairs(procHandlers) do --pairs() avoided because next() doesn't handle talbes modified while being iterated over
            for i=1, 256 do --maxPID's
                if procHandlers[i] ~= nil then
                    callProcess(procHandlers[i], event, eventinfo)
                end
            end
        end
    until listenForEvents == false or event == "terminate" or next(procHandlers) == nil
end

return {
    ["status"] = statuscodes,
    ["run"] = run,
    ["init"] = init,
    ["getPID"] = getPID,
    ["runSimple"] = runSimple,
    ["terminate"] = terminate,
    ["sendEvent"] = sendEvent,
    ["resolve"] = resolve,
    ["errorToString"] = errorToString,
    ["getCWD"] = getCWD,
    ["setCWD"] = setCWD,
    ["isOk"] = isOk
}