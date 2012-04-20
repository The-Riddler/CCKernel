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

local function wrap(func)
    return function(arg)
        stringcheck(arg)
        
        --No need for custom stuff
        if newfs.isabs(arg) then
            return catcherr(func, arg), false
        end
        
        local cwd = procman.getCWD()
        if cwd ~= nil then
            return catcherr(func, cwd.."/"..arg), true
        end
    end
end

--[[-----------------------------------------
New functions
--]]-----------------------------------------
function newfs.isabs(dir)
    return (string.sub(dir, 1, 1) == "/")
end

newfs.list = wrap(fs.list)
newfs.getSize = wrap(fs.getSize)
newfs.isDir = wrap(fs.isDir)
newfs.mkdir = function(arg)
    stringcheck(arg)
    
    --No need for custom stuff
    if newfs.isabs(arg) then
        fs.makeDir(arg)
        return fs.exists(arg), false --makeDir doesn't return weather it worked or not, wtf?
    end
    
    local cwd = procman.getCWD()
    if cwd ~= nil then
        local dir = cwd.."/"..arg
        fs.makeDir(dir)
        return fs.exists(dir), true
    end
end
newfs.delete = function(arg)
    stringcheck(arg)
    
    --No need for custom stuff
    if newfs.isabs(arg) then
        fs.delete(arg)
        return not fs.exists(arg), false --delete also doesn't return weather it worked or not
    end
    
    local cwd = procman.getCWD()
    if cwd ~= nil then
        local dir = cwd.."/"..arg
        fs.delete(dir)
        return not fs.exists(dir), true
    end
end


--[[
function newfs.list(dir) 
    stringcheck(dir)
    
    --No need for custom stuff
    if newfs.isabs(dir) then 
        return catcherr(fs.list, dir), false 
    end
    
    local cwd = procman.getCWD()
    if cwd ~= nil then
        return catcherr(fs.list, cwd.."/"..dir), true
    end
end
]]--
--[[
function newfs.mkdir(dir)
    stringcheck(dir)
    
    if newfs.isabs(dir) then
        return catcherr(fs.list
]]--
return newfs