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

local targs = {...}

local commandHistory = {}
local run = true
local errorinfo = {}

local settings = {
    ["PS1"] = "\\w", --expanded
    ["PS2"] = ">", --not expanded
    ["RepeatHistory"] = false,
    ["aliases"] = {
        ["ls"] = "ls.lua",
        ["mkdir"] = "mkdir.lua",
        ["rm"] = "rm.lua",
        ["trash"] = "trash.lua"
    }
}

local expansions = {
    ["\\W"] = function() return procman.getCWD() end,
    ["\\w"] = function()
        local str = string.match(procman.getCWD(), "/%w*$")
        if string.len(str) > 1 then
            str = string.sub(str, 2, -1) 
        end
        return str
    end,
    ["\\i"] = function() return os.getComputerID() end,
    ["\\l"] = function() return os.getComputerLabel() or "n/a" end 
}

local internalCommands = {
    ["exit"] = function() run = false end,
    ["cd"] = function(cmdList)
        if cmdList[2] == "../" then
            local newdir = string.gsub(procman.getCWD(), "/%w*$", "")
            if newdir == "" then newdir = "/" end
            
            if  procman.setCWD(newdir) then return true end
        elseif kernel.fs.isabs(cmdList[2]) then --abolute dir
            if  procman.setCWD(cmdList[2]) then return true end
        else
            local cwd = procman.getCWD()
            local isroot = (cwd == "/")
            local newdir = ""
            
            if isroot then 
                newdir = cwd..cmdList[2]
            else
                newdir = cwd.."/"..cmdList[2]
            end
            if  procman.setCWD(newdir) then return true end
        end
        print("Directory not found: "..cmdList[2])
    end,
    ["dump"] = function()
        print("*****Error dump*****")
        for k, v in pairs(errorinfo) do
            print("["..k.."] "..v)
        end
        print("*****End error dump*****")
        return true
    end,
    ["pwd"] = function() print(procman.getCWD()) end
}

local function writePS()
    local PS1 = settings["PS1"]
    
    for k, v in pairs(expansions) do
        --print("DEBUG: "..PS1.." : "..k.." : "..v())
        PS1 = string.gsub(PS1, k, v)
    end
    
    write(PS1..settings["PS2"])
end

local function formatDir(dir)
    if string.sub(dir, -1) ~= "/" then
        dir = dir.."/"
    end
    
    return dir
end

local function checkInternalCommands(cmdList)
    local func = internalCommands[cmdList[1]]
    if func ~= nil then
        func(cmdList)
        return true
    end
    return false
end

local function runProgram(file, ...)
    local stat, err = procman.run(file, nil, nil, false, ...)
    if not procman.isOk(stat) then
        errorinfo["statuscode"] = stat
        errorinfo["errorstring"] = procman.errorToString(stat) or "n/a"
        errorinfo["info"] = err or ""
        print("Error running program, type 'dump' to see more info")
    end
end

local function checkExternalProgram(parts)
    --check current directory
    local program = table.remove(parts, 1)
    
    local file =  procman.getCWD().."/"..program
    if fs.exists(file) and not fs.isDir(file) then
        runProgram(file, unpack(parts))
        return true
    end
    
    --check default folders
    local file = procman.resolve(program)
    if file ~= nil then
        runProgram(file, unpack(parts))
        return true
    end
    
    return false
end

local function checkAliases(parts)
    for k, v in pairs(parts) do
        local newcmd = settings["aliases"][v]
        if newcmd ~= nil then
            parts[k] = newcmd
        end
    end
end
    

local function main()
    while run == true do
        writePS()
        local command = read(nil, commandHistory)
        
        if commandHistory[#commandHistory] ~= command or settings["RepeatHistory"] == true then
            table.insert(commandHistory, command)
        end
        
        local parts = {}
        
        for word in string.gmatch(command, "[^ ]+") do
            table.insert(parts, word)
        end
        
        if next(parts) ~= nil then
            checkAliases(parts)
            
            if not checkInternalCommands(parts) then
                --check current directory
                if not checkExternalProgram(parts) then
                    print("Error, could not locate program")
                end
            end
        end
    end
end

return {
    ["name"] = "shell",
    ["main"] = main
}