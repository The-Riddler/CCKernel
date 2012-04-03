local include = assert(loadfile("rom/lib/include/include.lua"))()

include.debug = true

local hook = include:add("hook")
local net = include:add("net")

hook:debugEnable(true)
net.debug = true

print(tostring(hook))
net:init()
net:listen("back")


hook:init()