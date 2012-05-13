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

local function catcherr(func, ...)
    local targs = {...}
    if not fs.exists(targs[1]) then
        return nil, newfs["statuscodes"]["FNF"]
    end
    return func(unpack(targs))
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
            if type(arg) ~= "string" then return nil end
            if not fs.exists(arg) then return nil end
            local dir, relative = newfs.getabs(arg)
            return func(dir), relative
        end
    end
end

--[[-----------------------------------------
New functions
--]]-----------------------------------------
newfs.list = wrap(fs.list)
newfs.size = wrap(fs.getSize)
newfs.isDir = wrap(fs.isDir)
newfs.exists = wrap(fs.exists)

newfs.basename = function(name) 
    local str = string.match(name, "/[.%w]*$")
    if string.len(str) > 1 then
        str = string.sub(str, 2, -1)
    end
    return str
end

newfs.open = function(file, mode)
    stringcheck(file)
    
    local dir, relative = newfs.getabs(file)
    return fs.open(file, mode)
end

newfs.move = function(arg1, arg2)
    stringcheck(arg1)
    stringcheck(arg2)
    
    local dir1, relative1 = newfs.getabs(arg1)
    local dir2, relative2 = newfs.getabs(arg2)
    
    local ok, err = catcherr(fs.move, dir1, dir2)
    
    return ((not fs.exists(dir1)) and fs.exists(dir2)), relative1, relative2
end

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