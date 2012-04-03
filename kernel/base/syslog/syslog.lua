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

local log = {}
local logdir = "/var/log/"
local attachmentdir = logdir.."atts/"
local logall = "everything.log"

local function appendfile(file, str)
    local path = logdir..file
    local file = nil
    
    if fs.isDir(path) then
        error("FATAL: logfile is directory ["..path.."]")
    else
        local file = fs.open(path, "a")
        if file == nil then
            error("FATAL: Could not open logfile ["..path.."]")
        else
            file.write(str)
            file.close()
            return true
        end
    end
end

function log:logString(proc, str)
    str = tostring(math.floor(os.clock(), 1)).." ["..proc.."] "..str.."\n"
    appendfile(logall, str)
    appendfile(proc..".log", str)
end

function log:debugString(dbg, proc, str)
    if dbg == true then
        self:logString(proc, str)
    end
end

local function tblHasEntry(tbl)
    for k, v in pairs(tbl) do
        return true
    end
    return false
end

function log:logTable(proc, str, tbl)
    if tbl == nil or not tblHasEntry(tbl) then 
        self:logString(proc, str.." <Table was nil/empty>")
        return
    elseif #tbl == 1 and type(tbl[1]) ~= "table" then
        self:logString(proc, str.." <[1] = "..tostring(tbl[1])..">")
        return
    end
    local i = 0
    local attachfile = nil
    repeat
        attachfile = attachmentdir..tostring(i)..".dat"
        i = i + 1
    until fs.exists(attachfile) == false
    local file = fs.open(attachfile, "w")
    if file ~= nil then
        local function writetbl(tbl, level)
            for k, v in pairs(tbl) do
                file.write(string.rep(" ", level*2))
                if type(v) ~= "table" then
                    file.write(tostring(k).." = "..tostring(v).."\n")
                else
                    file.write(tostring(k)..":\n")
                    if v ~= tbl then
                        writetbl(v, level+1)
                    end
                end
            end
        end
        
        writetbl(tbl, 0)
        file.close()
        
        self:logString(proc, str.." <Attached "..attachfile..">")
    else
        error("Could not create datafile for log")
    end
end

function log:debugTable(dbg, proc, str, tbl)
    if dbg == true then
        self:logTable(proc, str, tbl)
    end
end

--[[
Check that the nessesary directorys exist (otherwise dan's filesystem craps out)
]]--
if not fs.isDir(logdir) then
    fs.makeDir(logdir)
end

if not fs.isDir(attachmentdir) then
    fs.makeDir(attachmentdir)
end

--[[
Cycle log files each startup
]]--
for _, file in pairs(fs.list(logdir)) do
    if not fs.isDir(logdir..file) then
        local i = 0
        local currentfile = logdir..file
        local newfile = nil
        repeat
            newfile =string.sub(currentfile, 0, string.len(currentfile)-4)..tostring(i)..".log"
            i = i + 1
        until fs.exists(newfile) == false
        
        fs.move(currentfile, newfile)
    end
end

--Uppon trying to list these files, until we get a "more" or "less" type program, just delete them
for _, file in pairs(fs.list(logdir)) do
    if not fs.isDir(logdir..file) then
        fs.delete(logdir..file)
    end
end
return log