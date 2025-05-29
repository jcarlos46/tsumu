#!/usr/bin/env lua

-- Stack-based Language REPL inspired by Joy/Cat/Factor
-- Usage: lua stack_repl.lua

local has_ffi, ffi = pcall(require, "ffi")
if not has_ffi then
    ffi = nil
end

local Stack = {}
Stack.__index = Stack

function Stack:new()
    local stack = {items = {}}
    setmetatable(stack, Stack)
    return stack
end

function Stack:push(value)
    table.insert(self.items, value)
end

function Stack:pop()
    if #self.items == 0 then
        error("Stack underflow")
    end
    return table.remove(self.items)
end

function Stack:peek()
    if #self.items == 0 then
        return nil
    end
    return self.items[#self.items]
end

function Stack:size()
    return #self.items
end

function Stack:clear()
    self.items = {}
end

function Stack:tostring()
    local result = "["
    for i, v in ipairs(self.items) do
        if i > 1 then result = result .. " " end
        if type(v) == "string" then
            result = result .. '"' .. v .. '"'
        elseif type(v) == "table" and v.type == "quote" then
            result = result .. "[" .. table.concat(v.value, " ") .. "]"
        elseif type(v) == "table" and v.type == "list" then
            result = result .. format_list(v)
        else
            result = result .. tostring(v)
        end
    end
    return result .. "]"
end

-- Helper function to format lists
function format_list(list)
    local result = "("
    for i, item in ipairs(list.items) do
        if i > 1 then result = result .. " " end
        if type(item) == "string" then
            result = result .. '"' .. item .. '"'
        elseif type(item) == "table" and item.type == "list" then
            result = result .. format_list(item)
        elseif type(item) == "table" and item.type == "quote" then
            result = result .. "[" .. table.concat(item.value, " ") .. "]"
        else
            result = result .. tostring(item)
        end
    end
    return result .. ")"
end

-- Global stack and dictionary
local stack = Stack:new()
local dictionary = {}
local imported_files = {} -- Track imported files to prevent circular imports
local globals = {}

-- Basic arithmetic operations
dictionary["+"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a + b)
end

dictionary["-"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a - b)
end

dictionary["*"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a * b)
end

dictionary["/"] = function()
    local b = stack:pop()
    local a = stack:pop()
    if b == 0 then
        error("Division by zero")
    end
    stack:push(a / b)
end

dictionary["mod"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a % b)
end

-- Stack manipulation
dictionary["dup"] = function()
    local a = stack:peek()
    if a == nil then
        error("Stack empty")
    end
    stack:push(a)
end

dictionary["drop"] = function()
    stack:pop()
end

dictionary["swap"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(b)
    stack:push(a)
end

dictionary["rot"] = function()
    local c = stack:pop()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(b)
    stack:push(c)
    stack:push(a)
end

dictionary["over"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a)
    stack:push(b)
    stack:push(a)
end

-- Comparison operations
dictionary["="] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a == b)
end

dictionary[">"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a > b)
end

dictionary["<"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a < b)
end

-- Logical operations
dictionary["and"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a and b)
end

dictionary["or"] = function()
    local b = stack:pop()
    local a = stack:pop()
    stack:push(a or b)
end

dictionary["not"] = function()
    local a = stack:pop()
    stack:push(not a)
end

-- Definir variável global: valor "nome" set
dictionary["set"] = function()
    local name = stack:pop()
    local value = stack:pop()
    if type(name) ~= "string" then
        error("set requires a string name")
    end
    globals[name] = value
end

-- Obter variável global: "nome" get
dictionary["get"] = function()
    local name = stack:pop()
    if type(name) ~= "string" then
        error("get requires a string name")
    end
    local value = globals[name]
    if value == nil then
        error("global '" .. name .. "' is not set")
    end
    stack:push(value)
end

-- Conditional execution
dictionary["if"] = function()
    local else_quote = stack:pop()
    local then_quote = stack:pop()
    local condition = stack:pop()
    
    if condition then
        if then_quote.type == "quote" then
            evaluate_tokens(then_quote.value)
        end
    else
        if else_quote.type == "quote" then
            evaluate_tokens(else_quote.value)
        end
    end
end

-- Quote operations
dictionary["i"] = function() -- execute quote
    local quote = stack:pop()
    if quote.type == "quote" then
        evaluate_tokens(quote.value)
    end
end

dictionary["dip"] = function() -- execute quote with second element removed
    local quote = stack:pop()
    local x = stack:pop()
    evaluate_tokens(quote.value)
    stack:push(x)
end

-- List operations
dictionary["list"] = function() -- create empty list
    stack:push({type = "list", items = {}})
end

dictionary["cons"] = function() -- add element to front of list
    local list = stack:pop()
    local element = stack:pop()
    if list.type ~= "list" then
        error("cons requires a list")
    end
    local new_list = {type = "list", items = {element}}
    for _, item in ipairs(list.items) do
        table.insert(new_list.items, item)
    end
    stack:push(new_list)
end

dictionary["uncons"] = function() -- remove first element from list
    local list = stack:pop()
    if list.type ~= "list" then
        error("uncons requires a list")
    end
    if #list.items == 0 then
        error("uncons on empty list")
    end
    local first = list.items[1]
    local rest = {type = "list", items = {}}
    for i = 2, #list.items do
        table.insert(rest.items, list.items[i])
    end
    stack:push(rest)
    stack:push(first)
end

dictionary["append"] = function() -- add element to end of list
    local list = stack:pop()
    local element = stack:pop()
    if list.type ~= "list" then
        error("append requires a list")
    end
    local new_list = {type = "list", items = {}}
    for _, item in ipairs(list.items) do
        table.insert(new_list.items, item)
    end
    table.insert(new_list.items, element)
    stack:push(new_list)
end

dictionary["length"] = function() -- get list length
    local list = stack:pop()
    if list.type ~= "list" then
        error("length requires a list")
    end
    stack:push(#list.items)
end

dictionary["empty?"] = function() -- check if list is empty
    local list = stack:pop()
    if list.type ~= "list" then
        error("empty? requires a list")
    end
    stack:push(#list.items == 0)
end

dictionary["first"] = function() -- get first element
    local list = stack:pop()
    if list.type ~= "list" then
        error("first requires a list")
    end
    if #list.items == 0 then
        error("first on empty list")
    end
    stack:push(list.items[1])
end

dictionary["rest"] = function() -- get all but first element
    local list = stack:pop()
    if list.type ~= "list" then
        error("rest requires a list")
    end
    local new_list = {type = "list", items = {}}
    for i = 2, #list.items do
        table.insert(new_list.items, list.items[i])
    end
    stack:push(new_list)
end

dictionary["last"] = function() -- get last element
    local list = stack:pop()
    if list.type ~= "list" then
        error("last requires a list")
    end
    if #list.items == 0 then
        error("last on empty list")
    end
    stack:push(list.items[#list.items])
end

dictionary["nth"] = function() -- get nth element (0-indexed)
    local list = stack:pop()
    local n = stack:pop()
    if list.type ~= "list" then
        error("nth requires a list")
    end
    if n < 0 or n >= #list.items then
        error("nth index out of bounds")
    end
    stack:push(list.items[n + 1])
end

dictionary["reverse"] = function() -- reverse list
    local list = stack:pop()
    if list.type ~= "list" then
        error("reverse requires a list")
    end
    local new_list = {type = "list", items = {}}
    for i = #list.items, 1, -1 do
        table.insert(new_list.items, list.items[i])
    end
    stack:push(new_list)
end

dictionary["concat"] = function() -- concatenate two lists
    local list2 = stack:pop()
    local list1 = stack:pop()
    if list1.type ~= "list" or list2.type ~= "list" then
        error("concat requires two lists")
    end
    local new_list = {type = "list", items = {}}
    for _, item in ipairs(list1.items) do
        table.insert(new_list.items, item)
    end
    for _, item in ipairs(list2.items) do
        table.insert(new_list.items, item)
    end
    stack:push(new_list)
end

dictionary["map"] = function() -- apply quote to each element
    local list = stack:pop()
    local quote = stack:pop()
    if list.type ~= "list" then
        error("map requires a list")
    end
    if quote.type ~= "quote" then
        error("map requires a quote")
    end
    
    local new_list = {type = "list", items = {}}
    for _, item in ipairs(list.items) do
        stack:push(item)
        evaluate_tokens(quote.value)
        table.insert(new_list.items, stack:pop())
    end
    stack:push(new_list)
end

dictionary["filter"] = function() -- filter list with predicate
    local list = stack:pop()
    local predicate = stack:pop()
    if list.type ~= "list" then
        error("filter requires a list")
    end
    if predicate.type ~= "quote" then
        error("filter requires a quote")
    end
    
    local new_list = {type = "list", items = {}}
    for _, item in ipairs(list.items) do
        stack:push(item)
        evaluate_tokens(predicate.value)
        local result = stack:pop()
        if result then
            table.insert(new_list.items, item)
        end
    end
    stack:push(new_list)
end

dictionary["fold"] = function() -- fold list with accumulator and binary function
    local list = stack:pop()
    local quote = stack:pop()
    local accumulator = stack:pop()
    if list.type ~= "list" then
        error("fold requires a list")
    end
    if quote.type ~= "quote" then
        error("fold requires a quote")
    end
    
    local result = accumulator
    for _, item in ipairs(list.items) do
        stack:push(result)
        stack:push(item)
        evaluate_tokens(quote.value)
        result = stack:pop()
    end
    stack:push(result)
end

dictionary["each"] = function() -- execute quote for each element
    local list = stack:pop()
    local quote = stack:pop()
    if list.type ~= "list" then
        error("each requires a list")
    end
    if quote.type ~= "quote" then
        error("each requires a quote")
    end
    
    for _, item in ipairs(list.items) do
        stack:push(item)
        evaluate_tokens(quote.value)
    end
end

dictionary["range"] = function() -- create list of numbers from 0 to n-1
    local n = stack:pop()
    if type(n) ~= "number" or n < 0 then
        error("range requires a non-negative number")
    end
    local new_list = {type = "list", items = {}}
    for i = 0, n - 1 do
        table.insert(new_list.items, i)
    end
    stack:push(new_list)
end

-- String operations

dictionary["split"] = function()
    local sep = stack:pop()
    local str = stack:pop()
    if type(str) ~= "string" or type(sep) ~= "string" then
        error("split requires a string and a separator string")
    end
    local items = {}
    if sep == "" then
        -- Split every character
        for i = 1, #str do
            table.insert(items, str:sub(i, i))
        end
    else
        local pattern = "([^" .. sep:gsub("(%W)","%%%1") .. "]+)"
        for part in str:gmatch(pattern) do
            table.insert(items, part)
        end
    end
    stack:push({type = "list", items = items})
end

dictionary["join"] = function()
    local sep = stack:pop()
    local list = stack:pop()
    if type(sep) ~= "string" or type(list) ~= "table" or list.type ~= "list" then
        error("join requires a list and a separator string")
    end
    local str_items = {}
    for _, v in ipairs(list.items) do
        table.insert(str_items, tostring(v))
    end
    stack:push(table.concat(str_items, sep))
end

dictionary["upper"] = function()
    local str = stack:pop()
    if type(str) ~= "string" then error("upper requires a string") end
    stack:push(str:upper())
end

dictionary["lower"] = function()
    local str = stack:pop()
    if type(str) ~= "string" then error("lower requires a string") end
    stack:push(str:lower())
end

dictionary["len"] = function()
    local str = stack:pop()
    if type(str) == "string" then
        stack:push(#str)
    elseif type(str) == "table" and str.type == "list" then
        stack:push(#str.items)
    else
        error("len requires a string or list")
    end
end

-- File operations
dictionary["import"] = function() -- import another script
    local filename = stack:pop()
    if type(filename) ~= "string" then
        error("import requires a filename string")
    end
    
    -- Check if already imported
    if imported_files[filename] then
        return -- Already imported, skip
    end
    
    load_and_execute_file(filename)
    imported_files[filename] = true
end

dictionary["load"] = function() -- load and execute file (always executes, even if imported before)
    local filename = stack:pop()
    if type(filename) ~= "string" then
        error("load requires a filename string")
    end
    
    load_and_execute_file(filename)
end
dictionary["clear"] = function()
    stack:clear()
end

dictionary["size"] = function()
    stack:push(stack:size())
end

dictionary["."] = function() -- print top of stack
    print(stack:pop())
end

dictionary["print"] = function() -- print string from stack
    local str = stack:pop()
    io.write(str)
end

dictionary["println"] = function() -- print string with newline
    local str = stack:pop()
    print(str)
end

-- Define new words
dictionary["define"] = function()
    local body = stack:pop()
    local name = stack:pop()
    dictionary[name] = function()
        if body.type == "quote" then
            evaluate_tokens(body.value)
        end
    end
end

-- FFI
dictionary["cdef"] = function()
    if not ffi then error("LuaJIT FFI not available") end
    local cdef_str = stack:pop()
    if type(cdef_str) ~= "string" then
        error("cdef requires a string with C declarations")
    end
    ffi.cdef(cdef_str)
end

dictionary["ccall"] = function()
	if not ffi then error("LuaJIT FFI not available") end
	local func_name = stack:pop()
	local lib_name = stack:pop()
	if type(func_name) ~= "string" then
		error("ccall requires a string with the C function name")
	end
	if type(lib_name) ~= "string" then
		error("ccall requires a string with the library name (use 'C' for default)")
	end
	-- Para simplicidade, só suporta funções da libc (ffi.C) ou de bibliotecas carregadas
	local args = {}
	while stack:size() > 0 do
		table.insert(args, 1, stack:pop())
	end
	local lib
	if lib_name == "C" then
		lib = ffi.C
	else
		if not globals._ffi_libs then globals._ffi_libs = {} end
		if not globals._ffi_libs[lib_name] then
			globals._ffi_libs[lib_name] = ffi.load(lib_name)
		end
		lib = globals._ffi_libs[lib_name]
	end
	local func = lib[func_name]
	if not func then error("C function not found: " .. func_name .. " in library: " .. lib_name) end
	local result = func(table.unpack(args))
	stack:push(result)
end

-- Tokenizer
function tokenize(input)
	-- Remove comentários iniciados por --
    input = input:gsub("%-%-.*", "")
    local tokens = {}
    local i = 1
    
    while i <= #input do
        local char = input:sub(i, i)
        
        if char:match("%s") then
            i = i + 1
        elseif char == '"' then
            -- String literal
            local str = ""
            i = i + 1
            while i <= #input and input:sub(i, i) ~= '"' do
                str = str .. input:sub(i, i)
                i = i + 1
            end
            i = i + 1 -- skip closing quote
            table.insert(tokens, str)
        elseif char == '(' then
            -- List literal
            local list_content = ""
            local depth = 1
            i = i + 1
            while i <= #input and depth > 0 do
                local c = input:sub(i, i)
                if c == '(' then
                    depth = depth + 1
                elseif c == ')' then
                    depth = depth - 1
                end
                if depth > 0 then
                    list_content = list_content .. c
                end
                i = i + 1
            end
            local list_tokens = tokenize(list_content)
            local list_items = {}
            -- Evaluate tokens to get actual values for list
            local temp_stack = Stack:new()
            local original_stack = stack
            stack = temp_stack
            evaluate_tokens(list_tokens)
            for _, item in ipairs(temp_stack.items) do
                table.insert(list_items, item)
            end
            stack = original_stack
            table.insert(tokens, {type = "list", items = list_items})
        elseif char == '[' then
            -- Quote literal
            local quote = ""
            local depth = 1
            i = i + 1
            while i <= #input and depth > 0 do
                local c = input:sub(i, i)
                if c == '[' then
                    depth = depth + 1
                elseif c == ']' then
                    depth = depth - 1
                end
                if depth > 0 then
                    quote = quote .. c
                end
                i = i + 1
            end
            local quote_tokens = tokenize(quote)
            table.insert(tokens, {type = "quote", value = quote_tokens})
        else
            -- Regular token
            local token = ""
            while i <= #input and not input:sub(i, i):match("%s") and input:sub(i, i) ~= '[' and input:sub(i, i) ~= ']' and input:sub(i, i) ~= '(' and input:sub(i, i) ~= ')' do
                token = token .. input:sub(i, i)
                i = i + 1
            end
            if token ~= "" then
                table.insert(tokens, token)
            end
        end
    end
    
    return tokens
end

-- Evaluator
function evaluate_tokens(tokens)
    for _, token in ipairs(tokens) do
        if type(token) == "number" then
            stack:push(token)
        elseif type(token) == "string" then
            -- Try to convert to number
            local num = tonumber(token)
            if num then
                stack:push(num)
            elseif dictionary[token] then
                dictionary[token]()
            else
                stack:push(token)
            end
        elseif type(token) == "table" and token.type == "list" then
            stack:push(token)
        elseif type(token) == "table" and token.type == "quote" then
            stack:push(token)
        elseif type(token) == "boolean" then
            stack:push(token)
        end
    end
end

function evaluate(input)
    local success, err = pcall(function()
        local tokens = tokenize(input)
        evaluate_tokens(tokens)
    end)
    
    if not success then
        print("Error: " .. err)
    end
end

-- File loading and execution
function load_and_execute_file(filename)
    local file, err = io.open(filename, "r")
    if not file then
        error("Could not open file: " .. filename .. " (" .. (err or "unknown error") .. ")")
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content then
        error("Could not read file: " .. filename)
    end
    
    print("Loading: " .. filename)
    evaluate(content)
end

-- Execute file if provided as command line argument
function execute_file_if_provided()
    if arg and arg[1] then
        local filename = arg[1]
        print("Executing file: " .. filename)
        load_and_execute_file(filename)
        return true -- File was executed
    end
    return false -- No file provided
end

-- REPL
function repl()
    print("Stack-based Language REPL v1.0")
    print("Inspired by Joy, Cat, and Factor")
    print("Type 'help' for commands, 'quit' to exit")
    print("Stack: " .. stack:tostring())
    
    while true do
        io.write("> ")
        local input = io.read()
        
        if not input or input == "quit" or input == "exit" then
            print("Goodbye!")
            break
        elseif input == "help" then
            print([[
Basic commands:
  Numbers: 1 2 3.14 -5
  Arithmetic: + - * / mod
  Stack: dup drop swap rot over clear size
  Comparison: = > < 
  Logic: and or not
  Conditionals: [then] [else] if
  Quotes: [code] i dip
  Lists: (1 2 3) list cons uncons append length empty?
  List ops: first rest last nth reverse concat
  Higher-order: map filter fold each
  I/O: . print println
  Files: "filename.stack" import load
  Define: "name" [body] define
  
Examples:
  2 3 +                    --> 5
  5 dup *                  --> 25
  (1 2 3) [2 *] map        --> (2 4 6)
  (1 2 3 4 5) [2 >] filter --> (3 4 5)
  (1 2 3) 0 [+] fold       --> 6
  5 range                  --> (0 1 2 3 4)
  "math.stack" import      --> import file once
  "utils.stack" load       --> load file (always)
  "double" [2 *] define    --> define new word
]])
        elseif input == "stack" then
            print("Stack: " .. stack:tostring())
        elseif input:match("^%s*$") then
            -- Empty input, just show stack
            print("Stack: " .. stack:tostring())
        else
            evaluate(input)
            print("Stack: " .. stack:tostring())
        end
    end
end

-- Main execution
function main()
    -- Try to execute file if provided as argument
    local file_executed = execute_file_if_provided()
    
    -- Start REPL if no file was executed, or if file execution completed
    if not file_executed then
        repl()
    else
        -- File was executed, ask if user wants to enter REPL
        print("\nFile execution completed.")
        print("Final stack: " .. stack:tostring())
        io.write("Enter REPL? (y/n): ")
        local response = io.read()
        if response and (response:lower() == "y" or response:lower() == "yes") then
            repl()
        end
    end
end

-- Start the program
main()