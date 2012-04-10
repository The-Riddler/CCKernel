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

local KERNEL_ROOT_DIR = "/rom/riddler/kernel/"

--Setup params, syntax: parameter value
local modulesToLoad = {}
local loadModuleManager = true

local params = {
    ["modules"] = function(arg) 
        modulesToLoad = {}
        for word in string.gmatch(arg, "[^,]+") do
            table.insert(modulesToLoad, word)
        end
    end,
    ["addmod"] = function(arg)
        for word in string.gmatch(arg, "[^,]+") do
            table.insert(modulesToLoad, word)
        end
    end,
    ["modman"] = function(arg)
        loadModuleManager = arg == "true"
    end
}

--Record start time
local startTime = os.clock()

--Setup the screen
term.clear()
term.setCursorPos(1,1)
term.setCursorBlink(true)

--Print info
print("Riddler's kernel - PC:"..os.getComputerID()..", "..(os.getComputerLabel() or ""))
print("Copyright (C) 2012  Jordan (Riddler)")
print("-------------------")

--[[
Create custom run function
]]--
local function kernelLoadFile(path, env)
    if string.find(path, "/") ~= 1 then
        error("KernelLoadFile requires an absolute path")
    end
    if not fs.exists(path) or fs.isDir(path) then error("[kernel] File not found: "..path) end 
     
    local code, err = loadfile(path)
    if code == nil then
        error("[Kernel] Error loading code"..tostring(err))
    end
    
    setfenv(code, env or getfenv(1))
    
    local ok, err
    for retries=1, 3 do
        ok, err = pcall(code)
        
        if not ok then
            if retries == 3 then
                error("[Kernel] <"..retries.. ">Error calling code: "..err)
            else
                print("[Kernel] <"..retries.. ">Error calling code: "..err)
            end
            sleep(1)
        else
            break
        end
    end
    
    return err
end


--[[
Start loading stuff!
]]--
print("Loading syslog")
local syslog = kernelLoadFile(KERNEL_ROOT_DIR.."base/syslog/syslog.lua")

--[[
Setup status display to show what were doing
]]--
print("Setting up status display")
local function status(str)
    local width, height = term.getSize()
    local len = string.len(str)
    local targetlen = width-6
    
    syslog:logString("boot", str)
    
    if len > targetlen then
        str = string.sub(str, 0, width-7)
        str = str.."-"
    elseif len < targetlen then
        str = str..string.rep(".", targetlen-len)
    end
    
    term.write(str.."[BUSY]")
    local x, y = term.getCursorPos()
    if y >= height then
        term.scroll(1)
        y = y - 1
    end
    term.setCursorPos(1, y+1)
end

local function statusDone()
    local x, y = term.getCursorPos()
    local xs, ys = term.getSize()
    
    term.setCursorPos(xs-5, y-1)
    
    term.write("[DONE]")
    term.setCursorPos(x, y)
end

--[[
Load config files
]]--

status("Checking config files")
    local cfile = "/etc/modules.txt"
    if fs.exists(cfile) and not fs.isDir(cfile) then
        local data = fs.open(cfile, "r").readAll()
        for line in string.gmatch(data, "%a+") do
            if line ~= nil then table.insert(modulesToLoad, line) end
        end
    end
statusDone()


--[[
Parse startup parameters (overides config files where nessesary)
]]--
local arg = { ... }
if arg ~= nil then
    status("Processing boot arguments")
        local i = 1
        local curarg = arg[i]
        
        while curarg ~= nil do
            local paramfunc = params[curarg]
            if paramfunc == nil then
                error("Invalid parameter: "..curarg)
            else
                paramfunc(arg[i+1])
            end
            i = i + 2
            curarg = arg[i]
        end
    statusDone()
end

--[[
Load table module, we will need the functions in a second
]]--
status("loading table extension")
    local tbladv = kernelLoadFile(KERNEL_ROOT_DIR.."base/table/table.lua")
statusDone()

--[[
Clone the global environment.
We want a new table we can edit as we please without having to bypass his stupid write protection
]]--
status("cloneing global environment")
    local kernelEnvironment = tbladv.clone(_G)
statusDone()

--[[
Set thekernel info
]]--
status("Setting kernel info")
    kernelEnvironment["kernel"] = {}
    kernelEnvironment["kernel"]["version"] = 2
    kernelEnvironment["kernel"]["dir"] = KERNEL_ROOT_DIR
statusDone()

--[[
Add the table functions we loaded into the table library into the new environment
]]--
status("Adding preloaded functions to global")
    tbladv.merge(kernelEnvironment["table"], tbladv)
    kernelEnvironment["syslog"] = syslog
statusDone()

--[[
Load program management module
]]--
status("Loading program management module")
    --syslog:logTable("kernel", "Kernel environment:", kernelEnvironment)
    kernelEnvironment["procman"] = kernelLoadFile(KERNEL_ROOT_DIR.."base/procman/procman.lua", kernelEnvironment)
statusDone()

--[[
Load the module manager
]]--
status("Loading module manager")
    local modulemanager = kernelLoadFile(KERNEL_ROOT_DIR.."base/modulemanager/modulemanager.lua", kernelEnvironment)
    if loadModuleManager ~= false then
        kernelEnvironment["modulemanager"] = modulemanager
        statusDone()
    else
        statusDone()
        print("Warning: not adding module manager to kernel")
    end
--end section
for k, v in pairs(modulesToLoad) do
    status("--Loading module: "..v)
        local stat, err = modulemanager.load(v)
        if stat ~= modulemanager.STAT_OK then
            if err ~= nil then
                error(err)
            else
                error(tostring(stat))
            end
        end
    statusDone()
end

print("Done, took "..os.clock()-startTime.." seconds")

print("Checking for init script")
    local filename = "etc/init.lua"
    if fs.exists(filename) and not fs.isDir(filename) then
        print("Running startup script: "..filename)
        kernelEnvironment["procman"]["init"]("/etc/init.lua", kernelEnvironment)
    end
print("***Init process terminated, kernel unloading***")
print("***Total runtime: "..math.ceil((os.clock()-startTime)).."***")
syslog:logString("kernel", "Init process terminated, kernel unloading")


--[[    
if fs.exists(startupfile) and fs.isDir(startupfile) == false then
    local code = assert(loadfile(startupfile))
    setfenv(code, kernelEnvironment)
    if kernelEnvironment["debug"] ~= nil then
        print("Running startup script with custom error handler")
        local ok, msg = xpcall(code, kernelEnvironment["debug"]["error"])
        print("Script executed, returning computer to origional state")
    else
        --For compatability
        kernelEnvironment["debug"] = setmetatable({}, {__index = function() return function() print("Warning: calling debug function without debug present") return "Nobody here but us chickens!" end end})
        print("Running startup script")
        print(pcall(code()))
    end
    print("Running startup script")
    kernelEnvironment["procman"]["init"]("/etc/init.lua", kernelEnvironment)
end
]]--
    
