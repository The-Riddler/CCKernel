local targs = { ... }
local filename = table.remove(targs, 1)

assert(modulemanager.require("trash"), "Error loading trash api")

if filename == "-l" then
    for k, v in pairs(trash.list()) do
        print("["..v["id"].."]"..v["name"].."  -  "..v["path"])
    end
elseif filename == "-r" then
    filename = table.remove(targs, 1)
    trash.restore(filename)
else
    if trash.trash(filename) then
        print("Trashed: "..filename)
    else
        print("Error trashing file: "..filename)
    end
end