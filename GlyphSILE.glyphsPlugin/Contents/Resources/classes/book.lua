local plain = SILE.require("plain", "classes")
local book = plain { id = "book" }

book:loadPackage("masters")
book:defineMaster({
    id = "right",
    firstContentFrame = "content",
    frames = {
      content = {
        left = "8.3%pw",
        right = "86%pw",
        top = "11.6%ph",
        bottom = "top(footnotes)"
      },
      folio = {
        left = "left(content)",
        right = "right(content)",
        top = "bottom(footnotes)+3%ph",
        bottom = "bottom(footnotes)+5%ph"
      },
      runningHead = {
        left = "left(content)",
        right = "right(content)",
        top = "top(content)-8%ph",
        bottom = "top(content)-3%ph"
      },
      footnotes = {
        left = "left(content)",
        right = "right(content)",
        height = "0",
        bottom = "83.3%ph"
      }
    }
  })

book:loadPackage("twoside", { oddPageMaster = "right", evenPageMaster = "left" })

book:loadPackage("tableofcontents")

if not SILE.scratch.headers then SILE.scratch.headers = {} end

book.init = function (self)
  book:mirrorMaster("right", "left")
  book.pageTemplate = SILE.scratch.masters["right"]
  book:loadPackage("footnotes", { insertInto = "footnotes", stealFrom = { "content" } })
  return plain.init(self)
end

book.newPage = function (self)
  book:switchPage()
  book:newPageInfo()
  return plain.newPage(self)
end

book.finish = function ()
  local ret = plain.finish(book)
  book:writeToc()
  return ret
end

book.endPage = function (self)
  book:moveTocNodes()

  if (book:oddPage() and SILE.scratch.headers.right) then
    SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
      SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
      SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
      SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
      -- SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
      SILE.process(SILE.scratch.headers.right)
      SILE.call("par")
    end)
  elseif (not(book:oddPage()) and SILE.scratch.headers.left) then
      SILE.typesetNaturally(SILE.getFrame("runningHead"), function ()
        SILE.settings.set("current.parindent", SILE.nodefactory.zeroGlue)
        SILE.settings.set("document.lskip", SILE.nodefactory.zeroGlue)
        SILE.settings.set("document.rskip", SILE.nodefactory.zeroGlue)
          -- SILE.settings.set("typesetter.parfillskip", SILE.nodefactory.zeroGlue)
        SILE.process(SILE.scratch.headers.left)
        SILE.call("par")
      end)
  end
  return plain.endPage(book)
end

SILE.registerCommand("left-running-head", function (options, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.left = function () closure(content) end
end, "Text to appear on the top of the left page")

SILE.registerCommand("right-running-head", function (options, content)
  local closure = SILE.settings.wrap()
  SILE.scratch.headers.right = function () closure(content) end
end, "Text to appear on the top of the right page")

SILE.registerCommand("book:sectioning", function (options, content)
  local content = SU.subContent(content)
  local level = SU.required(options, "level", "book:sectioning")
  SILE.call("increment-multilevel-counter", {id = "sectioning", level = options.level})
  SILE.call("tocentry", {level = options.level}, content)
  local lang = SILE.settings.get("document.language")
  if options.numbering == nil or options.numbering == "yes" then
    if options.prenumber then
      if SILE.Commands[options.prenumber .. ":"  .. lang] then
        options.prenumber = options.prenumber .. ":" .. lang
      end
      SILE.call(options.prenumber)
    end
    SILE.call("show-multilevel-counter", {id="sectioning"})
    if options.postnumber then
      if SILE.Commands[options.postnumber .. ":" .. lang] then
        options.postnumber = options.postnumber .. ":" .. lang
      end
      SILE.call(options.postnumber)
    end
  end
end)

book.registerCommands = function ()
  plain.registerCommands()
SILE.doTexlike([[%
\define[command=book:chapter:pre]{}%
\define[command=book:chapter:post]{\par}%
\define[command=book:section:post]{ }%
\define[command=book:subsection:post]{ }%
\define[command=book:left-running-head-font]{\font[size=9pt]}%
\define[command=book:right-running-head-font]{\font[size=9pt,style=italic]}%
]])
end

SILE.registerCommand("chapter", function (options, content)
  SILE.call("open-double-page")
  SILE.call("noindent")
  SILE.scratch.headers.right = nil
  SILE.call("set-counter", {id = "footnote", value = 1})
  SILE.call("book:chapterfont", {}, function ()
    SILE.call("book:sectioning", {
      numbering = options.numbering,
      level = 1,
      prenumber = "book:chapter:pre",
      postnumber = "book:chapter:post"
    }, content)
  end)
  SILE.Commands["book:chapterfont"]({}, content)
  SILE.Commands["left-running-head"]({}, function ()
    SILE.settings.temporarily(function ()
      SILE.call("book:left-running-head-font")
      SILE.process(content)
    end)
  end)
  SILE.call("bigskip")
  SILE.call("nofoliosthispage")
end, "Begin a new chapter")

SILE.registerCommand("section", function (options, content)
  SILE.typesetter:leaveHmode()
  SILE.call("goodbreak")
  SILE.call("bigskip")
  SILE.call("noindent")
  SILE.Commands["book:sectionfont"]({}, function ()
    SILE.call("book:sectioning", {
      numbering = options.numbering,
      level = 2,
      postnumber = "book:section:post"
    }, content)
    SILE.process(content)
  end)
  if not SILE.scratch.counters.folio.off then
    SILE.Commands["right-running-head"]({}, function ()
      SILE.call("book:right-running-head-font")
      SILE.call("rightalign", {}, function ()
        SILE.settings.temporarily(function ()
          SILE.call("show-multilevel-counter", { id = "sectioning", level = 2 })
          SILE.typesetter:typeset(" ")
          SILE.process(content)
        end)
      end)
    end)
  end
  SILE.call("novbreak")
  SILE.call("bigskip")
  SILE.call("novbreak")
  SILE.typesetter:inhibitLeading()
end, "Begin a new section")

SILE.registerCommand("subsection", function (options, content)
  SILE.typesetter:leaveHmode()
  SILE.call("goodbreak")
  SILE.call("noindent")
  SILE.call("medskip")
  SILE.Commands["book:subsectionfont"]({}, function ()
    SILE.call("book:sectioning", {
          numbering = options.numbering,
          level = 3,
          postnumber = "book:subsection:post"
        }, content)
    SILE.process(content)
  end)
  SILE.typesetter:leaveHmode()
  SILE.call("novbreak")
  SILE.call("medskip")
  SILE.call("novbreak")
  SILE.typesetter:inhibitLeading()
end, "Begin a new subsection")

SILE.registerCommand("book:chapterfont", function (options, content)
  SILE.settings.temporarily(function ()
    SILE.Commands["font"]({ weight = 800, size = "22pt" }, content)
  end)
end)
SILE.registerCommand("book:sectionfont", function (options, content)
  SILE.settings.temporarily(function ()
    SILE.Commands["font"]({ weight = 800, size = "15pt" }, content)
  end)
end)

SILE.registerCommand("book:subsectionfont", function (options, content)
  SILE.settings.temporarily(function ()
    SILE.Commands["font"]({ weight = 800, size = "12pt" }, content)
  end)
end)

return book
