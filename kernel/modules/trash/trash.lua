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

local function getinfo(id)
    local filehandle = kernel.fs.open(infopath.."/"..id..".trashinfo", "r")
    if filehandle == nil then
        error("Error opening file: "..infopath.."/"..id..".trashinfo")
    end
    local str = filehandle.readAll()
    filehandle.close()
    
    return str
end

function trashapi.trash(file)
    if not kernel.fs.exists(file) then return false end
    
    local id = getid()
    
    if not makeinfo(file, id) then error("Couldnt create info") end
    if not kernel.fs.move(file, filepath.."/"..id..".trash") then error("Couldn't move file") end
    return true
end

function trashapi.restore(id)
    local filepos = filepath.."/"..id..".trash"
    
    if not kernel.fs.exists(filepos) or not kernel.fs.exists(infopath.."/"..id..".trashinfo") then error("Specified ID does not exist") end
    
    local fileinfo = getinfo(id)
    return kernel.fs.move(filepos, fileinfo)
end

function trashapi.list()
    local list = {}
    
    for k, v in pairs(kernel.fs.list(filepath)) do
        local id = string.match(v, "%w")
        local path = getinfo(id)
        table.insert(list,  {
            ["id"] = id,
            ["path"] = path,
            ["name"] = kernel.fs.basename(path)
        })
    end
    
    return list
end

_G["trash"] = trashapi