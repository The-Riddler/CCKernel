local targs = { ... }
local filename = table.remove(targs, 1)

assert(modulemanager.require("trash"), "Error loading trash api")

if trash.trash(filename) then
    print("Trashed: "..filename)
else
    print("Error trashing file: "..filename)
end
