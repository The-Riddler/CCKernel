local trashapi = {}
local rootpath = "/trash"
local filepath = rootpath.."/files"
local infopath = rootpath.."/info"

local function getid()
    local id = 0
    local path = ""
    
    repeat
        id = id + 1
    until not kernel.fs.exists(filepath.."/"..tostring(id)..".trash")
    
    return tostring(id)
end

local function makeinfo(file, id)
    local path = infopath.."/"..id..".trashinfo"
    local filehandle = kernel.fs.open(path, "w")
    if filehandle == nil then return false end
    
    filehandle.write(file)
    filehandle.close()
    
    return true
end

function trashapi.trash(file)
    if not kernel.fs.exists(file) then return false end
    
    local id = getid()
    
    if not makeinfo(file, id) then error("Couldnt create info") end
    if not kernel.fs.move(file, filepath.."/"..id..".trash") then error("Couldn't move file") end
end

_G["trash"] = trashapi