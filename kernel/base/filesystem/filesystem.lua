local newfs = {}

--[[-----------------------------------------
status codes
--]]-----------------------------------------
newfs["statuscodes"] = {
    ["FNF"] = 0
}

--[[-----------------------------------------
Helper functions
--]]-----------------------------------------
local function stringcheck(dir)
    if not type(dir) == "string" then
        error("Filesystem functions only take a string")
    end
end

local function catcherr(func, arg)
    if not fs.exists(arg) then
        return nil, newfs["statuscodes"]["FNF"]
    end
    return func(arg)
end

function newfs.isabs(dir)
    return (string.sub(dir, 1, 1) == "/")
end

function newfs.getabs(dir)
    if newfs.isabs(dir) then
        return dir, false
    end
    return procman.getCWD().."/"..dir, true
end

local function wrap(func, catcherrors)
    if catcherrors == false then
        return function(arg)
            stringcheck(arg)
            local dir, relative = newfs.getabs(arg)
            return func(dir), relative
        end
    else
        return function(arg)
            stringcheck(arg)
            local dir, relative = newfs.getabs(arg)
            return catcherr(func, dir), relative
        end
    end
end

--[[-----------------------------------------
New functions
--]]-----------------------------------------
newfs.list = wrap(fs.list)
newfs.getSize = wrap(fs.getSize)
newfs.isDir = wrap(fs.isDir)

newfs.mkdir = function(arg)
    stringcheck(arg)
    
    local dir, relative = newfs.getabs(arg)
    fs.makeDir(dir)
    
    return fs.exists(dir), relative --fs.makeDir doesnt return if it worked, wtf?
end

newfs.delete = function(arg)
    stringcheck(arg)
    
    local dir, relative = newfs.getabs(arg)
    fs.delete(dir)
    
    return not fs.exists(dir), relative --fs.delete doesnt return if it worked, wtf?
end

return newfs