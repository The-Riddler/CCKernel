
local cwd = procman.getCWD()
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