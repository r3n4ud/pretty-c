if not modules then modules = { } end modules ['pret-c'] = {
        version   = 1.4,
        comment   = "companion to buff-ver.mkiv",
        author    = "Peter Münster",
        copyright = "Peter Münster",
        license   = "see context related readme files"
}

--[[ Usage:
\installprettytype[C][C]               % loading the file
\definetyping[C][option=C]             % defining \startC ... \stopC
\definetype[typeC][option=C, style=tt] % defining \typeC{}
\definecolor[Ccomment][...]            % change color for comments
--]]

local visualizer = buffers.newvisualizer("c")

local format = string.format

-- The colors are configurable by the user.
-- Example: \definecolor[Ccomment][darkblue]
local colors = {
        {name = "comment",                      color = "darkred"},
        {name = "funcdef",                      color = "blue"},
        {name = "preproc",                      color = "orchid"},
        {name = "string",                       color = "rosybrown"},
        {name = "type",                         color = "forestgreen"},
        {name = "keyword",                      color = "purple"},
        {name = "define",                       color = "darkgoldenrod"}
}

-- Helper functions and variables:
local color, buf, state, string_delimiter, deep_flush_line
local color_by_name = {}
local incomment, infuncdef, inescape = false, false, false
local inpreproc = 0
local texwrite = tex.write
local utfcharacters = string.utfcharacters
local function texsprint(s)
        tex.sprint(tex.ctxcatcodes, s)
end
local function change_color(n)
        color = buffers.changestate(color_by_name[n], color)
end
local function finish_color()
        color = buffers.finishstate(color)
end
local function flush_verbatim(str)
        for c in utfcharacters(str) do
                if c == " " then
                        texsprint("\\obs")
                else
                        texwrite(c)
                end
        end
end

-- Needed by buffers.change_state:
for i, c in ipairs(colors) do
        color_by_name[c.name] = i
end
local function color_init()
        color = 0
        local def_colors = -- \setupcolor[ema] introduces new line...
        "\\definecolor [darkred]       [r=.545098]" ..
        "\\definecolor [orchid]        [r=.854902,g=.439216,b=.839216]" ..
        "\\definecolor [rosybrown]     [r=.737255,g=.560784,b=.560784]" ..
        "\\definecolor [forestgreen]   [r=.133333,g=.545098,b=.133333]" ..
        "\\definecolor [purple]        [r=.627451,g=.12549,b=.941176]"  ..
        "\\definecolor [darkgoldenrod] [r=.721569,g=.52549,b=.043137]"
        local palet = "\\definepalet[Ccolorpretty]["
        for _, c in ipairs(colors) do
                def_colors = format(
                        "%s\\doifcolorelse{C%s}{}{\\definecolor[C%s][%s]}",
                        def_colors, c.name, c.name, c.color)
                        palet = format("%s%s=C%s,", palet, c.name, c.name)
        end
        palet = palet:gsub("(.+),$", "%1]")
        print("XXX", def_colors)
        print("XXX", palet)
        texsprint(def_colors)
        texsprint(palet)
        buffers.currentcolors = {}
        for i, c in ipairs(colors) do
                buffers.currentcolors[i] = c.name
        end
end

-- Keywords:
local keywords = {}
keywords.core = {
        "auto", "break", "case", "const", "continue", "default", "do",
        "else", "enum", "extern", "for", "goto", "if", "register", "return",
        "sizeof", "static", "struct", "switch", "typedef", "union", "volatile",
        "while"
}
keywords.types = {
        "char", "double", "float", "int", "long", "short", "signed", "unsigned",
        "void"
}
keywords.preproc = {
        "define", "include", "pragma", "if", "ifdef", "ifndef", "elif", "endif",
        "defined"
}

local keyword_colors = {}
for _, n in ipairs(keywords.core) do
        keyword_colors[n] = "keyword"
end
for _, n in ipairs(keywords.types) do
        keyword_colors[n] = "type"
end

-- The hooks:
function visualizer.begin_of_display()
        incomment = false
        color_init()
end
visualizer.begin_of_inline = visualizer.begin_of_display

visualizer.end_of_display = finish_color
visualizer.end_of_inline = visualizer.end_of_display

local function in_comment(str)
        change_color("comment")
        local comment, rest = str:match("^(.-%*/)(.*)$")
        if comment then
                flush_verbatim(comment)
                finish_color()
                incomment = false
                deep_flush_line(rest, true)
        else
                flush_verbatim(str)
        end
end

local function in_preproc(str)
        change_color("preproc")
        inpreproc = 1
        deep_flush_line(str, true)
end

local function in_funcdef(str)
        infuncdef = true
        deep_flush_line(str, true)
end

local function flush_word(w, c)
        if c then
                change_color(c)
        elseif keyword_colors[w] then
                change_color(keyword_colors[w])
        end
        flush_verbatim(w)
        finish_color()
end

local st_start, st_comment

local function st_inword(c)
        if c:match("[%w_]") then
                buf = buf .. c
        else
                local col = nil
                if c == "(" and infuncdef then
                        if not keyword_colors[buf] then
                                col = "funcdef"
                        end
                        inpreproc = 0
                        infuncdef = false
                elseif inpreproc == 1 then
                        col = "preproc"
                        if buf == "define" then
                                inpreproc = 2
                                infuncdef = true
                        else
                                inpreproc = 0
                                infuncdef = true
                        end
                elseif inpreproc == 2 then
                        col = "define"
                        inpreproc = 0
                        infuncdef = false
                end
                flush_word(buf, col)
                buf = ""
                state = st_start
                state(c)
        end
end

local function st_instring(c)
        if c == string_delimiter and not inescape or c == "" then
                flush_word(buf .. c, "string")
                buf = ""
                state = st_start
        else
                buf = buf .. c
                if c == '\\' then
                        inescape = not inescape
                else
                        inescape = false
                end
        end
end

local st_cpp_comment = flush_verbatim

local function st_first_star(c)
        flush_verbatim(c)
        if c == "/" then
                finish_color()
                incomment = false
                state = st_start
        else
                state = st_comment
        end
end

function st_comment(c)
        flush_verbatim(c)
        if c == "*" then
                state = st_first_star
        end
end

local function st_first_slash(c)
        if c == "/" then
                state = st_cpp_comment
        elseif c == "*" then
                incomment = true
                state = st_comment
        else
                flush_verbatim(buf)
                state = st_start
                state(c)
                return
        end
        change_color("comment")
        flush_verbatim(buf .. c)
        buf = ""
end

function st_start(c)
        buf = buf .. c
        if c == "/" then
                state = st_first_slash
        elseif c:match("[%w_]") then
                state = st_inword
        elseif c:match("[\"']") then
                string_delimiter = c
                state = st_instring
        else
                flush_verbatim(c)
                buf = ""
        end
end

function deep_flush_line(str, nested)
        if incomment then
                in_comment(str)
        elseif not nested and str:match("^ *#") then
                in_preproc(str)
        elseif not nested and str:match("^[%w_]+.*[%w_]+%(") then
                in_funcdef(str)
        else
                buf = ""
                state = st_start
                for c in utfcharacters(str) do
                        state(c)
                end
                if buf ~= "" then
                        state("")
                end
                inpreproc = 0
                infuncdef = false
                inescape = false
                finish_color()
        end
end

function visualizer.flush_line(str, nested)
        deep_flush_line(str, nested)
end
