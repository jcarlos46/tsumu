-- vm.lua
local M = {}

M.STACK = {}
STASH = {}
M.NAMES = {}
M.MAX_LOOP = 128
M.TOTAL_LOOP = 0
M.DEBUG_MODE = false
M.INT_MODE = false
M.EXIT = false

function M.error_msg(msg) 
    if M.INT_MODE then
        print(msg)
    else
        error(msg)
    end
end

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function M.push(val)
    table.insert(M.STACK, val)
end

function M.pop()
    if #M.STACK == 0 then
        M.error_msg("POP: STACK UNDERFLOW!")
        return 0
    end
    return table.remove(M.STACK)
end

local function eq () 
    if M.pop() == M.pop() then
        M.push(1)
    else
        M.push(0)
    end
end

local function gt ()
    local a = M.pop()
    local b = M.pop()
    if b > a then M.push(1) else M.push(0) end
end

local function lt()
    local a = M.pop()
    local b = M.pop()
    if b < a then M.push(1) else M.push(0) end
end

local function _not()
	if M.pop() ~= 0 then M.push(0) else M.push(1) end
end

local function len() M.push(#M.STACK) end

local function number()
    if tonumber(M.pop()) ~= nil then
        M.push(1)
    else
        M.push(0)
    end
end

local function pick()
    local len = M.pop()
    if len > #M.STACK then
        M.error_msg("PICK: STACK UNDERFLOW")
        return
    else
        local i = #M.STACK - len
        local a = M.STACK[i]
        table.insert(M.STACK, a)
    end
end

local function cond()
   local f = M.pop()
   local t = M.pop()
   local cond = M.pop()
   if cond > 0 then M.push(t) else M.push(f) end
end

local function swap()
   local a = M.pop()
   local b = M.pop()
   M.push(a)
   M.push(b)
end

local function compose()
   local a = M.pop()
   local b = M.pop()
   M.push(b.." "..a)
end


local function max_loop_def()
   local a = M.pop()
   if tonumber(a) then M.MAX_LOOP = a end
end

local function stash_in()  table.insert(STASH, M.pop()) end
local function stash_out() local a = table.remove(STASH) M.push(a) end

local function emit()
    local a = M.pop()
    io.write(string.char(a))
end

local function ps()
    for _,i in pairs(M.STACK) do
        io.write("["..i.."]")
    end
    io.write("\n")
end


local function _print()
    if #M.STACK == 0 then
        M.error_msg("PRINT: STACK UNDERFLOW")
        return
    end
    print(M.pop())
end

local function exit()
   M.EXIT = true
end

local function contains()
   local value = M.pop()
   local qnt = 0
    for _, v in pairs(M.STACK) do
        if v == value then
	   qnt = qnt + 1
        end
    end
    return M.push(qnt)
end

local function _trim()
   local a = M.pop()
   a = trim(a)
   if tonumber(a) then
      M.push(tonumber(a))
    else
      M.push(tostring(a))
    end
end

-- Operações disponíveis
M.NAMES["pop"] = M.pop
M.NAMES["+"] = function()
        local a = M.pop()
        local b = M.pop()
        M.push(a + b)
    end
M.NAMES["*"] = function() M.push(M.pop() * M.pop()) end
M.NAMES["/"] = function()
   local a = M.pop ()
   local b = M.pop ()
   M.push(b / a)
end
M.NAMES["%"] = function() local b = M.pop() M.push(M.pop() % b) end
M.NAMES["-"] = function()
        local a = M.pop()
        local b = M.pop()
        M.push(b-a)
    end
M.NAMES["="] = eq
M.NAMES[">"] = gt
M.NAMES["<"] = lt
M.NAMES["not"] = _not
M.NAMES["len"] = len
M.NAMES["number?"] = number
M.NAMES["pick"] = pick
M.NAMES["cond"] = cond
M.NAMES["compose"] = compose
M.NAMES["swap"] = swap
M.NAMES["stash>"] = stash_in
M.NAMES["<stash"] = stash_out
M.NAMES["contains?"] = contains
M.NAMES["io-write"] = function() io.write(M.pop()) end
M.NAMES["io-read"] = function() M.push(io.read()) end
M.NAMES["emit"] = emit
M.NAMES["trim"] = _trim
M.NAMES["debug-mode"] = function() M.DEBUG_MODE = true end
M.NAMES["max-loop-def"] = max_loop_def
M.NAMES["print"] = _print
M.NAMES["ps"] = ps
M.NAMES["exit"] = exit
M.NAMES["error-msg"] = function() M.error_msg(M.pop()) end
M.NAMES["os-execute"] = function() os.execute() end
M.NAMES["random"] = function()
   math.randomseed(os.time() + os.clock() * 1000000)
   M.push(math.random(M.pop()))
end
M.NAMES["int-mode"] = function() M.INT_MODE = true end
M.NAMES["rot"] = function()
    local last = table.remove(M.STACK)
    table.insert(M.STACK, 1, last)
end
M.NAMES["-rot"] = function()
    local first = table.remove(M.STACK,1)
    table.insert(M.STACK, first)
end
-- Strings
local function reverse_array(arr)
    local rev = {}
    for i=#arr, 1, -1 do
        rev[#rev+1] = arr[i]
    end
    return rev
end
M.NAMES["split"] = function()
    local delimiter = M.pop()
    local match = "([^" .. delimiter .. "]+)"
    if delimiter == "" then match = "." end
    local str = M.pop()
    local str_table = {}
    for part in string.gmatch(str, match) do
        table.insert(str_table, part)
    end
    for _,u in pairs(reverse_array(str_table)) do
        M.push(u)
    end
end
M.NAMES["concat"] = function()
    local b = tostring(M.pop())
    M.push(b .. tostring(M.pop()))
end
M.NAMES["string?"] = function()
    if tonumber(M.pop()) == nil then M.push(1) else M.push(0) end
end

return M