local targs = {...}

local dirtolist = ""
local cwd = procman.getCWD()
--print("CWD: "..cwd)

if type(targs[1]) == "string" then
    dirtolist = targs[1]
else
    dirtolist = cwd
end

local names, relative = kernel.fs.list(dirtolist)
if names == nil then
    if relative == kernel.fs.status.FNF then
        error("Directory does not exist: "..dirtolist)
    else
        error("Unknown error")
    end
end

local maxlen = 20
local bigestlen = 0

for k, v in pairs(names) do
    bigestlen = math.min(math.max(bigestlen, string.len(v)), maxlen)
end

for k, v in pairs(names) do
    local str = v
    local path = dirtolist.."/"..v
    
    --padding
    str = str..string.rep(" ",3+bigestlen-string.len(v))
    --print("DEBUG: "..fullpath)
    --Directory and size
    if kernel.fs.isDir(path) then
        str = "d "..str.."*"
    else
        str = "f "..str..kernel.fs.size(path)
    end
    
    print(str)
end