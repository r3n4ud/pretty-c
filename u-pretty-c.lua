if not modules then modules = { } end modules ['u-pretty-c'] = {
    version   = 1.5,
    comment   = "companion to u-pretty-c.mkiv",
    author    = "",
    copyright = "",
    license   = ""
}

-- borrowed from scite
--
-- depricated:
--
-- gcinfo unpack getfenv setfenv loadlib
-- table.maxn table.getn table.setn
-- math.log10 math.mod math.modf math.fmod

local format, tohash = string.format, table.tohash
local P, S, V, patterns = lpeg.P, lpeg.S, lpeg.V, lpeg.patterns
local C, Cs, Cg, Cb, Cmt, Carg = lpeg.C, lpeg.Cs, lpeg.Cg, lpeg.Cb, lpeg.Cmt, lpeg.Carg

local keyword = tohash {
   "auto", "break", "case", "const", "continue", "default", "do",
   "else", "enum", "extern", "for", "goto", "if", "register", "return",
   "sizeof", "static", "struct", "switch", "typedef", "union", "volatile",
   "while",
}

-- base to types
local type = tohash {
   "char", "double", "float", "int", "long", "short", "signed", "unsigned",
   "void",
}

-- new hash
local preproc = tohash {
   "define", "include", "pragma", "if", "ifdef", "ifndef", "elif", "endif",
   "defined",
}


-- local libraries = {
--     coroutine = tohash {
--         "create", "resume", "status", "wrap", "yield", "running",
--     },
--     package = tohash{
--         "cpath", "loaded", "loadlib", "path", "config", "preload", "seeall",
--     },
--     io = tohash{
--         "close", "flush", "input", "lines", "open", "output", "read", "tmpfile",
--         "type", "write", "stdin", "stdout", "stderr", "popen",
--     },
--     math = tohash{
--         "abs", "acos", "asin", "atan", "atan2", "ceil", "cos", "deg", "exp",
--         "floor ", "ldexp", "log", "max", "min", "pi", "pow", "rad", "random",
--         "randomseed", "sin", "sqrt", "tan", "cosh", "sinh", "tanh", "huge",
--     },
--     string = tohash{
--         "byte", "char", "dump", "find", "len", "lower", "rep", "sub", "upper",
--         "format", "gfind", "gsub", "gmatch", "match", "reverse",
--     },
--     table = tohash{
--         "concat", "foreach", "foreachi", "sort", "insert", "remove", "pack",
--         "unpack",
--     },
--     os = tohash{
--         "clock", "date", "difftime", "execute", "exit", "getenv", "remove",
--         "rename", "setlocale", "time", "tmpname",
--     },
--     lpeg = tohash{
--         "print", "match", "locale", "type", "version", "setmaxstack",
--         "P", "R", "S", "C", "V", "Cs", "Ct", "Cs", "Cp", "Carg",
--         "Cg", "Cb", "Cmt", "Cf", "B",
--     },
--     -- bit
--     -- debug
-- }

local context               = context
local verbatim              = context.verbatim
local makepattern           = visualizers.makepattern

local CSnippet              = context.CSnippet
local startCSnippet         = context.startCSnippet
local stopCSnippet          = context.stopCSnippet

local CSnippetBoundary      = verbatim.CSnippetBoundary
local CSnippetSpecial       = verbatim.CSnippetSpecial
local CSnippetComment       = verbatim.CSnippetComment
local CSnippetKeyword       = verbatim.CSnippetKeyword
local CSnippetType          = verbatim.CSnippetType
local CSnippetPreproc       = verbatim.CSnippetPreproc
local CSnippetName          = verbatim.CSnippetName
local CSnippetString        = verbatim.CSnippetString

local namespace

local function visualizename_a(s)
   if s=="#" then
      CSnippetPreproc(s)
   elseif keyword[s] then
      namespace = nil
      CSnippetKeyword(s)
   elseif type[s] then
      namespace = nil
      CSnippetType(s)
   elseif preproc[s] then
      namespace = nil
      CSnippetPreproc(s)
   else 
      CSnippetName(s)
      -- else
      --     namespace = libraries[s]
      --     if namespace then
      --         LuaSnippetNameLibraries(s)
      --     else
      --         LuaSnippetName(s)
      --     end
   end
end

local function visualizename_b(s)
    if namespace and namespace[s] then
        namespace = nil
        CSnippetNameLibraries(s)
    else
        CSnippetName(s)
    end
end

local function visualizename_c(s)
    CSnippetName(s)
end

local handler = visualizers.newhandler {
    startinline  = function() CSnippet(false,"{") end,
    stopinline   = function() context("}") end,
    startdisplay = function() startCSnippet() end,
    stopdisplay  = function() stopCSnippet() end ,
    boundary     = function(s) CSnippetBoundary(s) end,
    special      = function(s) CSnippetSpecial (s) end,
    comment      = function(s) CSnippetComment (s) end,
    period       = function(s) verbatim(s) end,
    string       = function(s) CSnippetString (s) end,
    name_a       = visualizename_a,
    name_b       = visualizename_b,
    name_c       = visualizename_c,
}

local space       = patterns.space
local anything    = patterns.anything
local newline     = patterns.newline
local emptyline   = patterns.emptyline
local beginline   = patterns.beginline
local somecontent = patterns.somecontent

local comment     = P("//") * patterns.space^0 * (1 - patterns.newline)^0
local incomment_open = P("/*")
local incomment_close = P("*/")

local name        = (patterns.letter + patterns.underscore)
                  * (patterns.letter + patterns.underscore + patterns.digit)^0
local boundary    = S('()[]{}')
--local special     = S("-+/*^%=#") + P("..")

local grammar = visualizers.newgrammar("default", { "visualizer",

    sstring =
         makepattern(handler,"string",patterns.dquote)
      * (V("whitespace") + makepattern(handler,"string",(P("\\")*P(1))+1-patterns.dquote))^0
       * makepattern(handler,"string",patterns.dquote),

    dstring =
         makepattern(handler,"string",patterns.squote)
      * (V("whitespace") + makepattern(handler,"string",(P("\\")*P(1))+1-patterns.squote))^0
       * makepattern(handler,"string",patterns.squote),

    comment =
         makepattern(handler,"comment",comment),
--       * (V("space") + V("content"))^0,

    incomment =
         makepattern(handler,"comment",incomment_open)
       * (V("whitespace") + makepattern(handler,"comment",1-incomment_close))^0
       * makepattern(handler,"comment",incomment_close),

    name =
       (makepattern(handler,"name_a",P("#")) *
     V("optionalwhitespace"))^0 *
        makepattern(handler,"name_a",name)
      * (   V("optionalwhitespace")
          * makepattern(handler,"default",patterns.period)
          * V("optionalwhitespace")
          * makepattern(handler,"name_b",name)
        )^-1
      * (   V("optionalwhitespace")
          * makepattern(handler,"default",patterns.period)
          * V("optionalwhitespace")
          * makepattern(handler,"name_c",name)
        )^0
   ,

    pattern =
      V("incomment")
      + V("comment")
      + V("dstring")
      + V("sstring")
      + V("name")
      + makepattern(handler,"boundary",boundary)
--      + makepattern(handler,"special",special)

      + V("space")
      + V("line")
      + V("default"),

    visualizer =
        V("pattern")^1
} )

local parser = P(grammar)

visualizers.register("c", { parser = parser, handler = handler, grammar = grammar } )
