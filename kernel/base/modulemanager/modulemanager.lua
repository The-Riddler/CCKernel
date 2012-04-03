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
local modulemanager = {}

local ModuleDirs = {
    "/sr/modules/",
    kernel.dir.."modules/"
}

local modules = {}

modulemanager.STAT_LOADED = 0
modulemanager.STAT_EXEC = 1
modulemanager.STAT_404 = 2
modulemanager.STAT_OK = 3

function modulemanager.load(name)
    if modules[name] == true then
        return modulemanager.STAT_LOADED
    end
    for k, path in ipairs(ModuleDirs) do
        local dir = path..name.."/"..name..".lua"
        if fs.exists(dir) and fs.isDir(dir) == false then
            syslog:logString("modman", "Loading module from: "..dir)
            local code, err = loadfile(dir)
            if code ~= nil then
                setfenv(code, getfenv(1)) --Set to modulemanagers environment
                --local ok, err = pcall(code) --cant do this because global environment gets returned to normal
                code()
                return modulemanager.STAT_OK
                -- if ok == true then 
                    -- return modulemanager.STAT_OK, err
                -- else
                    -- return modulemanager.STAT_EXEC, err
                -- end
            else
                return modulemanager.STAT_EXEC, err
            end
        end
    end
    
    return modulemanager.STAT_404
end

function modulemanager.require(name)
    if modules[name] == true then
        return true
    end
    
    local stat, err = modulemanager.load(name)
    if stat == modulemanager.STAT_OK then
        return true
    else
        syslog:logString("modman", "require: error loading '"..name.."' "..(err or tostring(stat))) 
        return false
    end
end
        
    

return modulemanager