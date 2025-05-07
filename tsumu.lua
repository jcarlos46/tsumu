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
local int_mode = false

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
            -- print("EXECUTING: " .. token.value)
            NAMES[token.value]()
        else
	    error_msg("Function not found: " .. token.value)
	    return
        end
    elseif token.type == "EXPR" then
        push(token.value)
    end
end

function process(tokens)
    for _, token in ipairs(tokens) do
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
    if int_mode then
        print("Tsumu: function "..name.." defined.")
    end
end

-- Operações disponíveis
NAMES["def"] = def
NAMES["pop"] = pop
NAMES["+"] = function() push(pop() + pop()) end
NAMES["*"] = function() push(pop() * pop()) end
NAMES["/"] = function() push(pop() / pop()) end
NAMES["%"] = function() local b = pop() push(pop() % b) end
NAMES["-"] = function() local b = pop() push(pop()-b) end
NAMES["="] = function() 
    if pop() == pop() then 
        push(1) 
    else 
        push(0) 
    end
end
NAMES[">"] = function()
    local a = pop()
    local b = pop()
    if b > a then 
        push(1) 
    else 
        push(0) 
    end
end
NAMES["<"] = function()
    local a = pop()
    local b = pop()
    if b < a then 
        push(1) 
    else 
        push(0) 
    end
end
NAMES["not"] = function()
	if pop ~= 0 then push(0) else push(1) end
end
NAMES["len"] = function() push(#STACK) end
NAMES["io-write"] = function() io.write(pop()) end
NAMES["import"] = function() import(pop()) end
NAMES["os-execute"] = function()
    local handle = io.popen(pop())
    local result = handle:read("*a")
    handle:close()
    push(trim(result))
end
NAMES["eval"] = function() run(pop()) end
NAMES["pick"] = function()
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
NAMES["if"] = function()
    local body = pop()
    local cond = pop()
    if cond == 1 then run(body) end
end
NAMES["ifelse"] = function()
    local else_ = pop()
    local then_ = pop()
    local cond = pop()
    if cond == 1 then run(then_) else run(else_) end
end
NAMES["while"] = function()
    local body = pop()
    local cond = pop()
    while true do
        run(cond)
        if pop() ~= 1 then break end
        run(body)
    end
end
NAMES["->"] = function() table.insert(STASH, pop()) end
NAMES["<-"] = function() local a = table.remove(STASH) push(a) end
NAMES["print-stack"] = function()
    for _,i in pairs(STACK) do
        io.write("["..i.."]")
    end
    io.write("\n")
end
NAMES["clear"] = function() STACK = {} end
NAMES["print"] = function()
    if #STACK == 0 then
        error_msg("PRINT: STACK UNDERFLOW")
        return
    end
    print(pop())
end
NAMES["rot"] = function()
    local last = table.remove(STACK)
    table.insert(STACK, 1, last)
end
NAMES["-rot"] = function()
    local first = table.remove(STACK,1)
    table.insert(STACK, first)
end

-- Strings
local function reverse_array(arr)
    rev = {}
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
    local b = pop()
    push(b .. pop())
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

if arg[1] == nil then
    int_mode = true
    local welcome = "Tsumu: Interactive mode (ctrl+c or 'exit' to quit)"
    print(welcome)
    while true do
        io.write("> ")
        local input = io.read("*line")
        if input then
            if trim(input) == "cls" then
                os.execute("clear")
                print(welcome)
            elseif trim(input) == "exit" then
                print("Tsumu: See you soon!") break
            elseif input ~= "" then run(input) end
        end
    end
else
    local filename = table.remove(arg,1)
    for i, u in ipairs(arg) do
        push(u)
    end
    import(filename)
end

