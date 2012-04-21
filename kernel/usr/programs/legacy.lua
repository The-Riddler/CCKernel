local targs = { ... }
local filename = table.remove(targs, 1)

if filename == nil then 
    error("Requires filename as argument")
end

local oldprogram = loadfile(filename)

local function calloldprog()
    term.clear()
    term.setCursorPos(1,1)
    print([[Please be aware that none of the following: 
    1) Riddler (Black Mesa Research Facility, New Mexico)
    2) Cloudhunter (Aperture Science, Inc. Michigan.)
    Can be held responsible for any damage or destruction resulting from, but not limited to:
    1) Nuclear meltdown
    2) Improper use of the kernel
    3) Playing with fireworks
    4) Xen invasion 
    5) Legacy programs interacting with the kernel unexpectedly
    ]])
    print("Press any key to continue")
    
    repeat 
    until os.pullEvent() == "key"
    
    print("Executing: "..filename)
    setfenv(oldprogram, getfenv())
    oldprogram(unpack(targs))
end

if oldprogram ~= nil then 
    return {
        ["name"] = "lagacy: "..filename,
        ["main"] = calloldprog
    }
else
    error("Error loading file: "..filename)
end