local targs = {...}
local pid = table.remove(targs, 1)

local cwd = procman.getCWD()

if type(targs[1]) == "string" then
    if string.find(targs[1], "/") then
        cwd = targs[1]
    else
        cwd = procman.getCWD()..targs[1]
    end
end

local names = fs.list(cwd)
local maxlen = 20
local bigestlen = 0

for k, v in pairs(names) do
    bigestlen = math.min(math.max(bigestlen, string.len(v)), maxlen)
end

for k, v in pairs(names) do
    local fullpath = cwd.."/"..v
    local str = v
    
    --padding
    str = str..string.rep(" ",3+bigestlen-string.len(v))

    --Directory and size
    if fs.isDir(fullpath) then
        str = "d "..str.."*"
    else
        str = "f "..str..fs.getSize(fullpath)
    end
    
    print(str)
end