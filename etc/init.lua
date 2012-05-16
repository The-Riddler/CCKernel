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

local filename = "/etc/programs.txt"

print("Default kernel init script running")

if fs.exists(filename) and not fs.isDir(filename) then
    local file = fs.open(filename, "r")
    if file ~= nil then
        local programs = file:readAll()
        file.close()
        if programs ~= nil then
            print("Starting programs from file: "..filename)
            for prog in string.gmatch(programs, "[^\r\n]+") do
                local path = procman.resolve(prog)
                if path ~= nil then
                    print("Running: "..path)
                    local stat, err = procman.runSimple(path)
                    if stat == false then
                        error("Error running program: "..path.." ["..err.."]")
                    end
                else
                    error("Error locating program: "..prog)
                end
            end
        end
    else
        error("Could not open file")
    end
end

print("Starting shell")
if procman.runSimple(procman.resolve("shell.lua")) == false then
    error("Error running shell")
end