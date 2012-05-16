
local util = {}

local keycodes = {
    [2] = 49, --1
    [3] = 50, --2
    [4] = 51, --3
    [5] = 52, --4
    [6] = 53, --5
    [7] = 54, --6
    [8] = 55, --7
    [9] = 56, --8
    [10] = 57, --9
    [11] = 48, --0
    [16] = 113, --q
    [17] = 119, --w
    [18] = 101, --e
    [19] = 114, --r
    [20] = 116, --t
    [21] = 121, --y
    [22] = 117, --u
    [23] = 105, --i
    [24] = 111, --o
    [25] = 112, --p
    [30] = 97, --a
    [31] = 115, --s
    [32] = 100, --d
    [33] = 102, --f
    [34] = 103, --g
    [35] = 104, --h
    [36] = 106, --j
    [37] = 107, --k
    [38] = 108, --l
    [44] = 122, --z
    [45] = 120, --x
    [46] = 99, --c
    [47] = 118, --v
    [48] = 98, --b
    [49] = 110, --n
    [50] = 109, --m
    [26] = 91, --[
    [27] = 93 --]
}

function util.ccToAscii(code)
    return keycodes[code]
end

function util.createDirs(path)
    if string.sub(path, 1, 1) ~= "/" then
        return false, "Absolute dir's only"
    end
    
    local pos = string.find(path, "/", 2)
    while pos ~= nil do
        if fs.makeDir(string.sub(path, 1, pos)) == false then return false end
        print(string.sub(path, 1, pos-1))
        pos = string.find(path, "/", pos+1)
    end
    print(string.sub(path, 1, pos))
    if fs.makeDir(path) == false then return false end
    
    return true
end

function util.lockfile(name)
    local name = "/var/lock/"..name..".lock"
    if fs.exists(name) then return false end
    
    local file = fs.open(name)
    if file == nil then return false end
        file.write(tostring(procman.getPID()))
    end
    file.close()
    
    return fs.exists(name)
end

_G["util"] = util