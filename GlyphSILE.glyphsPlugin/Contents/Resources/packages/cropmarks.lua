local outcounter = 1
local date = SILE.require("packages.date").exports

local outputMarks = function()
  local page = SILE.getFrame("page")
  SILE.outputter.rule(page:left() - 10, page:top(), -10, 0.5)
  SILE.outputter.rule(page:left(), page:top() - 10, 0.5, -10)
  SILE.outputter.rule(page:right() + 10, page:top(), 10, 0.5)
  SILE.outputter.rule(page:right(), page:top() - 10, 0.5, -10)
  SILE.outputter.rule(page:left() - 10, page:bottom(), -10, 0.5)
  SILE.outputter.rule(page:left(), page:bottom() + 10, 0.5, 10)
  SILE.outputter.rule(page:right() + 10, page:bottom(), 10, 0.5)
  SILE.outputter.rule(page:right(), page:bottom() + 10, 0.5, 10)

  SILE.call("hbox", {}, function()
    SILE.settings.temporarily(function()
      SILE.call("noindent")
      SILE.call("font", { size="6pt" })
      SILE.call("crop:header")
    end)
  end)
  local hbox = SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes]
  SILE.typesetter.state.nodes[#SILE.typesetter.state.nodes] = nil

  SILE.typesetter.frame.state.cursorX = page:left() + 10
  SILE.typesetter.frame.state.cursorY = page:top() - 13
  outcounter = outcounter + 1

  if hbox then
    for i=1,#(hbox.value) do hbox.value[i]:outputYourself(SILE.typesetter, {ratio=1}) end
  end
end

local function reconstrainFrameset(fs)
  for n,f in pairs(fs) do
    if n ~= "page" then
      if f:isAbsoluteConstraint("right") then
        f.constraints.right = "left(page) + (" .. f.constraints.right .. ")"
      end
      if f:isAbsoluteConstraint("left") then
        f.constraints.left = "left(page) + (" .. f.constraints.left .. ")"
      end
      if f:isAbsoluteConstraint("top") then
        f.constraints.top = "top(page) + (" .. f.constraints.top .. ")"
      end
      if f:isAbsoluteConstraint("bottom") then
        f.constraints.bottom = "top(page) + (" .. f.constraints.bottom .. ")"
      end
      f:invalidate()
    end
  end
end

SILE.registerCommand("crop:header", function (o, c)
  local info = SILE.masterFilename .. " - " .. date.date("%x %X") .. " -  " .. outcounter
  SILE.typesetter:typeset(info)
end)

SILE.registerCommand("crop:setup", function (o,c)
  local papersize = SU.required(o, "papersize", "setting up crop marks")
  local size = SILE.paperSizeParser(papersize)
  local oldsize = SILE.documentState.paperSize
  SILE.documentState.paperSize = size
  local offsetx = ( SILE.documentState.paperSize[1] - oldsize[1] ) /2
  local offsety = ( SILE.documentState.paperSize[2] - oldsize[2] ) /2
  local page = SILE.getFrame("page")
  page:constrain("right", page:right() + offsetx)
  page:constrain("left", offsetx)
  page:constrain("bottom", page:bottom() + offsety)
  page:constrain("top", offsety)
  if SILE.scratch.masters then
    for k,v in pairs(SILE.scratch.masters) do
      reconstrainFrameset(v.frames)
    end
  else
    reconstrainFrameset(SILE.documentState.documentClass.pageTemplate.frames)
  end
  if SILE.typesetter.frame then SILE.typesetter.frame:init() end

  local oldEndPage = SILE.documentState.documentClass.endPage
  SILE.documentState.documentClass.endPage = function(self)
    oldEndPage(self)
    outputMarks()
  end
end)
