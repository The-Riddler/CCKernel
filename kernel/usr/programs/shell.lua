local targs = {...}
local pid = table.remove(targs,1)

local commandHistory = {}
local run = true
local errorinfo = {}

local settings = {
    ["PS1"] = "\\w", --expanded
    ["PS2"] = ">", --not expanded
    ["RepeatHistory"] = false,
    ["aliases"] = {
        ["ls"] = "ls.lua"
    }
}

local expansions = {
    ["\\W"] = function() return  procman.getCWD() end,
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
            if  procman.setCWD(string.gsub(procman.getCWD(), "/%w*$", "")) then return true end
        elseif string.sub(cmdList[2],1,1) == "/" then --abolute dir
            if  procman.setCWD(cmdList[2]) then return true end
        else
            if  procman.setCWD(procman.getCWD().."/"..cmdList[2]) then return true end
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
    if stat ~= procman.status.STAT_OK and stat ~= procman.status.STAT_OK_RET then
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
        
        checkAliases(parts)
        
        if not checkInternalCommands(parts) then
            --check current directory
            if not checkExternalProgram(parts) then
                print("Error, could not locate program")
            end
        end
    end
end

return {
    ["name"] = "shell",
    ["main"] = main
}