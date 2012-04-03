local include = assert(loadfile("rom/lib/include/include.lua"))()

include.debug = true

local hook = include:add("hook")
local net = include:add("net")

hook:debugEnable(true)
hook.debug = false
net.debug = true


local data = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101}
net:sendArray("back", data)
print("initializing")
net:init()

hook:init()
print("Done")


--print(tostring(hook))
--net:init("back")

--hook:init()