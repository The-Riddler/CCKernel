local targs = { ... }
local filename = table.remove(targs, 1)

modulemanager.load("trash")

trash.trash(filename)