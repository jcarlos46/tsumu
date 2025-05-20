#!/usr/bin/env lua
-- tsumu.lua
local lexer = require("lexer")
local vm = require("vm")

-- Máquina Virtual
local process
local run
local import

local function eval(token)
    if token.value == "--" then return end
    if token.type == "NUMBER" then
        vm.push(tonumber(token.value))
    elseif token.type == "STRING" then
        vm.push(token.value)
    elseif token.type == "NAME" then
        if vm.NAMES[token.value] ~= nil then
            if vm.DEBUG_MODE then print("DEFINING: " .. token.value) end
            vm.NAMES[token.value]()
        else
	    vm.error_msg("NAME not found: " .. token.value)
	    return
        end
    elseif token.type == "EXPR" then
        vm.push(token.value)
    end
end

function process(tokens)
    for _, token in ipairs(tokens) do
	if vm.EXIT then return end
        eval(token)
    end
end

function run(code)
    local tokens = lexer.tokenize(code)
    process(tokens)
end

local function _import()
    local a = tostring(vm.pop())
    if a then
        import(a)
    end
end

local function def()
    local body = vm.pop()
    local name = vm.pop()
    vm.NAMES[name] = function() run(body) end
    if vm.INT_MODE then
        print("Tsumu: name "..name.." defined.")
    end
end

local function _while()
    local body = vm.pop()
    local cond = vm.pop()
    while true do
        vm.TOTAL_LOOP = vm.TOTAL_LOOP + 1
        if vm.TOTAL_LOOP >= vm.MAX_LOOP then 
            vm.error_msg("You reached the maximum loop quantity allowed")
            break
        end
        run(cond)
        if vm.pop() ~= 1 then break end
        run(body)
    end
    vm.TOTAL_LOOP = 0
end

local function _eval()
    local expr = vm.pop()
    run(expr)
end

vm.NAMES["def"] = def
vm.NAMES["while"] = _while
vm.NAMES["eval"] = _eval
vm.NAMES["import"] = _import

---@param filename string
function import(filename)
    -- Normaliza nodo do arquivo
    if string.sub(filename, -4) ~= ".tsu" then
        filename = filename .. ".tsu"
    end
    -- Abre o arquivo para leitura
    local file = io.open(filename, "r")
    if not file then
        vm.error_msg("Não foi possível abrir o arquivo de entrada.")
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

    if vm.INT_MODE then
        print("Tsumu: "..filename.." imported.")
    end

    local code = table.concat(table_code, " ")
    run(code)
end

if (arg[1] ~= nil) then
    for i, u in ipairs(arg) do
        vm.push(u)
    end
end

import("cli.tsu")

