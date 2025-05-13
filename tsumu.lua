#!/usr/bin/env lua
-- tsumu.lua
local lexer = require("lexer")

-- Máquina Virtual
STACK = {}
STASH = {}
NAMES = {}
VARS  = {}
local process
local run
local import
local MAX_LOOP = 128
local TOTAL_LOOP = 0
local DEBUG_MODE = false
local EXIT = false
local INT_MODE = false

local function error_msg(msg) 
    if int_mode then
        print(msg)
    else
        error(msg)
    end
end

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function push(val)
    table.insert(STACK, val)
end

local function pop()
    if #STACK == 0 then
        error_msg("POP: STACK UNDERFLOW!")
        return 0
    end
    return table.remove(STACK)
end

local function eval(token)
    if token.value == "--" then return end
    if token.type == "NUMBER" then
        push(tonumber(token.value))
    elseif token.type == "STRING" then
        push(token.value)
    elseif token.type == "NAME" then
        if NAMES[token.value] ~= nil then
            if DEBUG_MODE then print("DEFINING: " .. token.value) end
            NAMES[token.value]()
        else
	    error_msg("NAME not found: " .. token.value)
	    return
        end
    elseif token.type == "EXPR" then
        push(token.value)
    end
end

function process(tokens)
    for _, token in ipairs(tokens) do
	if EXIT then return end
        eval(token)
    end
end

function run(code)
    local tokens = lexer.tokenize(code)
    process(tokens)
end

local function def()
    local body = pop()
    local name = pop()
    NAMES[name] = function() run(body) end
    if INT_MODE then
        print("Tsumu: name "..name.." defined.")
    end
end

local function eq () 
    if pop() == pop() then push(1) else push(0) end
end

local function gt ()
    local a = pop()
    local b = pop()
    if b > a then push(1) else push(0) end
end

local function lt()
    local a = pop()
    local b = pop()
    if b < a then push(1) else push(0) end
end

local function _not()
	if pop ~= 0 then push(0) else push(1) end
end

local function len() push(#STACK) end

local function number()
    if tonumber(pop()) ~= nil then push(1) else push(0) end
end

local function pick()
    local len = pop()
    if len > #STACK then
        error_msg("PICK: STACK UNDERFLOW")
	return
    else
        local i = #STACK - len
        local a = STACK[i]
        table.insert(STACK, a)
    end
end

local function cond()
   local f = pop()
   local t = pop()
   local cond = pop()
   if cond > 0 then push(t) else push(f) end
end

local function swap()
   local a = pop()
   local b = pop()
   push(b) push(a)
end

local function compose()
   local a = pop()
   local b = pop()
   push(b.." "..a)
end

local function _while()
    local body = pop()
    local cond = pop()
    while true do
        TOTAL_LOOP = TOTAL_LOOP + 1
        if TOTAL_LOOP >= MAX_LOOP then 
            error_msg("You reached the maximum loop quantity allowed")
            break
        end
        run(cond)
        if pop() ~= 1 then break end
        run(body)
    end
    TOTAL_LOOP = 0
end

local function rot()
    local last = table.remove(STACK)
    table.insert(STACK, 1, last)
end

local function _rot()
    local first = table.remove(STACK,1)
    table.insert(STACK, first)
end

local function max_loop_def()
   local a = pop()
   if tonumber(a) then MAX_LOOP = a end
end

local function stash_in()  table.insert(STASH, pop()) end
local function stash_out() local a = table.remove(STASH) push(a) end

local function _eval()
    local expr = pop()
    run(expr)
end

local function emit()
    local a = pop()
    io.write(string.char(a))
end

local function ps()
    for _,i in pairs(STACK) do
        io.write("["..i.."]")
    end
    io.write("\n")
end

local function _import()
    local a = tostring(pop())
    if a then
        import(a)
    end
end

local function _print()
    if #STACK == 0 then
        error_msg("PRINT: STACK UNDERFLOW")
        return
    end
    print(pop())
end

local function exit()
   EXIT = true
end

local function os_execute()
    local handle = io.popen(pop())
    local result = handle:read("*a")
    handle:close()
    push(trim(result))
end

-- Operações disponíveis
NAMES["def"] = def
NAMES["pop"] = pop
NAMES["+"] = function()
        local a = pop()
        local b = pop()
        push(a + b)
    end
NAMES["*"] = function() push(pop() * pop()) end
NAMES["/"] = function() push(pop() / pop()) end
NAMES["%"] = function() local b = pop() push(pop() % b) end
NAMES["-"] = function()
        local a = pop()
        local b = pop()
        push(b-a)
    end
NAMES["="] = eq
NAMES[">"] = gt
NAMES["<"] = lt
NAMES["not"] = _not
NAMES["len"] = len
NAMES["number?"] = number
NAMES["eval"] = _eval
NAMES["pick"] = pick
NAMES["cond"] = cond
NAMES["while"] = _while
NAMES["compose"] = compose
NAMES["stash>"] = stash_in
NAMES["<stash"] = stash_out
NAMES["rot"] = rot
NAMES["-rot"] = _rot
NAMES["io-write"] = function() io.write(pop()) end
NAMES["io-read"] = function() push(io.read()) end
NAMES["emit"] = emit
NAMES["import"] = _import
NAMES["trim"] = import
NAMES["debug-mode"] = function() DEBUG_MODE = true end
NAMES["max-loop-def"] = max_loop_def
NAMES["print"] = _print
NAMES["ps"] = ps
NAMES["exit"] = exit
NAMES["error-msg"] = function() error_msg(pop()) end
NAMES["os-execute"] = os_execute
NAMES["int-mode"] = function() INT_MODE = true end

-- Strings
local function reverse_array(arr)
    local rev = {}
    for i=#arr, 1, -1 do
        rev[#rev+1] = arr[i]
    end
    return rev
end
NAMES["split"] = function()
    local delimiter = pop()
    local match = "([^" .. delimiter .. "]+)"
    if delimiter == "" then match = "." end
    local str = pop()
    local str_table = {}
    for part in string.gmatch(str, match) do
        table.insert(str_table, part)
    end
    for _,u in pairs(reverse_array(str_table)) do
        push(u)
    end
end
NAMES["concat"] = function()
    local b = tostring(pop())
    push(b .. tostring(pop()))
end
NAMES["string?"] = function()
    if tonumber(pop()) == nil then push(1) else push(0) end
end

---@param filename string
function import(filename)
    -- Normaliza nodo do arquivo
    if string.sub(filename, -4) ~= ".tsu" then
        filename = filename .. ".tsu"
    end
    -- Abre o arquivo para leitura
    local file = io.open(filename, "r")
    if not file then
        error_msg("Não foi possível abrir o arquivo de entrada.")
	return
    end
    local table_code = {}
    for line in file:lines() do
        -- Remove linhas que começam com espaços/tabs seguidos de --
        if not line:match("^%s*%-%-") then
            table.insert(table_code, line)
        end
    end
    file:close()

    if int_mode then
        print("Tsumu: "..filename.." imported.")
    end

    local code = table.concat(table_code, " ")
    run(code)
end

if (arg[1] ~= nil) then
    local filename = table.remove(arg,1)
    for i, u in ipairs(arg) do
	push(u)
    end
end
import("cli.tsu")

