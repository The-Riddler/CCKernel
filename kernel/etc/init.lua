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
    error("Error running sheel")
end