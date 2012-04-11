local targs = {...}
local pid = table.remove(targs,1)

local commandHistory = {}
local CWD = "/"
local run = true
local errorinfo = {}

local settings = {
    ["PS1"] = "\\w", --expanded
    ["PS2"] = ">", --not expanded
    ["RepeatHistory"] = false
}

local expansions = {
    ["\\W"] = function() return CWD end,
    ["\\w"] = function() return string.sub(string.match(CWD, "/%w*/$") or "///", 2, -2) end, --three "/" to allow it to cut the end off, cheaper than an if statement and stuff
    ["\\i"] = function() return os.getComputerID() end,
    ["\\l"] = function() return os.getComputerLabel() or "n/a" end 
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

local function changeDir(dir)
    if fs.exists(dir) and fs.isDir(dir) then 
        CWD = formatDir(dir)
        return true
    end
    return false
end

local function checkInternalCommands(cmdList)
    if cmdList[1] == "exit" then 
        run = false 
        return true
    elseif cmdList[1] == "cd" then
        if cmdList[2] == "../" then
            if changeDir(string.gsub(CWD, "%w+/$", "")) then return true end
        elseif string.sub(cmdList[2],1,1) == "/" then --abolute dir
            if changeDir(cmdList[2]) then return true end
        else
            if changeDir(CWD..cmdList[2]) then return true end
        end
        print("Directory not found: "..cmdList[2])
        return true
    elseif cmdList[1] == "dump" then
        print("*****Error dump*****")
        for k, v in pairs(errorinfo) do
            print("["..k.."] "..v)
        end
        print("*****End error dump*****")
        return true
    end
    return false
end

local function runProgram(file, args)
    local stat, err = procman.run(file, nil, nil, false, args)
    if stat ~= procman.status.STAT_OK and stat ~= procman.status.STAT_OK_RET then
        errorinfo["statuscode"] = stat
        errorinfo["errorstring"] = procman.errorToString(stat) or "n/a"
        errorinfo["info"] = err or ""
        print("Error running program, type 'dump' to see more info")
    end
end

local function checkExternalProgram(parts)
    --check current directory
    local file = CWD..parts[1]
    if fs.exists(file) and not fs.isDir(file) then
        runProgram(file)
        return true
    end
    
    --check default folders
    local file = procman.resolve(parts[1])
    if file ~= nil then
        runProgram(file)
        return true
    end
    
    return false
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