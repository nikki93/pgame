doc = {}

doc._last_doc = nil

-- returns a 'doc object' d, which contains the documentation string, and is
-- initially 'unclaimed' (not attached to any entity/slot/method) -- d:claim()
-- claims it and returns the documentation string, or nil if already claimed --
-- can be used to prevent accidentally assigning the same doc to multiple things
--
-- also 'fixes' indentation in the string: indentation on the first line is
-- removed, and the rest of the string is shifted left as far as possible while
-- maintaining relative indentation between lines
function DOC(str)
  -- fix documentation indentation
  local min = math.huge
  for c in str:gmatch('\n +') do if #c - 1 < min then min = #c - 1 end end
  str = str:gsub('^ *', ''):gsub('\n' .. string.rep(' ', min), '\n')

  -- create doc object, save it as last doc, return
  local d = {
    claimed = false,
    str = str,
    claim = function (self)
      if self.claimed then return nil end
      self.claimed = true
      return str
    end
  }
  doc._last_doc = d
  return d
end

-- claim and return the last documentation defined by DOC(...) -- useful when
-- there is no direct reference to the related documentation object, such as
-- when defining methods using 'function name(...) ... end' syntax
function doc.pop_doc()
  if not doc._last_doc then return nil end
  local str = doc._last_doc:claim()
  doc._last_doc = nil
  return str
end
