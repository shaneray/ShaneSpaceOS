-- Coypright 2015-2017 Stefan Göbel.
--
-- This file is part of Corky.
--
-- Corky is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
-- License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- Corky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
-- details.
--
-- You should have received a copy of the GNU General Public License along with Corky. If not, see
-- <http://www.gnu.org/licenses/>.

-------------------------------------------------------------------------------------------------------------------

--- Miscellaneous utility functions.
--
--  In addition to the functions listed below this module will set up @{table.unpack|table.unpack()} if it does not
--  exist, and @{table.pack|table.pack()} if it does not exist.
--
--  The string functions below will be added to the global @{string} table.
--
--  Output buffering will be disabled for `STDERR`.
--
--  @MO corky.utils
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)

-------------------------------------------------------------------------------------------------------------------

-- The unpack() function has been moved to table.unpack() in recent Lua versions. If running on an older version,
-- this will be done manually here, so table.unpack() can be used everywhere.

table.unpack = table.unpack or unpack

-------------------------------------------------------------------------------------------------------------------

-- table.pack is available in Lua 5.2 or later.

if not table.pack then
   table.pack = function (...)
      return { n = select ("#", ...), ... }
   end
end

-------------------------------------------------------------------------------------------------------------------

-- Disable buffering of STDERR:

io.stderr:setvbuf ("no")

-------------------------------------------------------------------------------------------------------------------

do

   local L = require "lpeg"

   local space    = L.S (" \t\n\v\f\r")
   local no_space = 1 - space
   local ptrim    = space ^ 0 * L.C ((space ^ 0 * no_space ^ 1) ^ 0)
   local match    = L.match

   --- Remove all spaces at the beginning and at the end of a string.
   --
   --  Characters removed are `[ \t\n\v\f\r]`. The returned string will be empty if the original does not contain
   --  any other characters.
   --
   --  See [http://lua-users.org/wiki/StringTrim](http://lua-users.org/wiki/StringTrim).
   --
   --  @s str The string to trim.
   --  @S The trimmed string.

   function string.trim (str)
      return match (ptrim, str)
   end

end

-------------------------------------------------------------------------------------------------------------------

do

   local L = require "lpeg"

   local space        = L.S (" \t\n\v\f\r")
   local field_end    = 1 - L.S (', \t\n\v\f\r\n"')
   local quoted_field = space ^ 0 * '"' * L.Cs (((L.P (1) - '"') + L.P ('""') / '"') ^ 0) * '"' * space ^ 0
   local raw_field    = space ^ 0 * L.C ((space ^ 0 * field_end ^ 1) ^ 0) * space ^ 0
   local field        = quoted_field + raw_field
   local record       = L.Ct (field * ("," * field) ^ 0) * (L.P ("\n") + -1)
   local match        = L.match

   --- Split a string into comma-separated values (CSV).
   --
   --  Quotes will be handled correctly. To include a quote inside a quoted field escape it with another quote
   --  (i.e. `"` becomes `""` inside a quoted field). Quotes are only needed if a field contains one or more
   --  commas. Spaces around commas are allowed and will be stripped, all spaces inside quotes will be preserved.
   --  Empty fields are allowed.
   --
   --  This function uses the LPeg module and is based on the CSV example found at
   --  [http://www.inf.puc-rio.br/~roberto/lpeg/](http://www.inf.puc-rio.br/~roberto/lpeg/#ex).
   --
   --  @s str The string to split.
   --  @T Array containing the individual fields (as strings). Fields may be empty. If there is any error parsing
   --  the string, `nil` will be returned.

   function string.split_csv (str)
      return match (record, str)
   end

end

-------------------------------------------------------------------------------------------------------------------

--- Check if a string A starts with a string B.
--
--  See [http://lua-users.org/wiki/StringRecipes](http://lua-users.org/wiki/StringRecipes).
--
--  @s str The string A to check.
--  @s start The string B.
--  @B Returns `true` if the string specified by the first parameter starts with the string specified as the second
--  parameter, else `false`.

function string.startswith (str, start)
   return string.sub (str, 1, string.len (start)) == start
end

-------------------------------------------------------------------------------------------------------------------

--- Print a warning message to STDERR.
--
--  The warning message printed is a formatted version of the function's variable number of arguments following the
--  description given in its first argument (which must be a string), like @{string.format|string.format()}. The
--  prefix `"Corky: "` will be added to the message, as will a newline character at the end.
--
--  @c string.format
--  @s format The format to use.
--  @p ... Substitutions for the format string.

local function warn (format, ...)
   io.stderr:write (string.format ("Corky: " .. format .. "\n", table.unpack (arg)))
end

-------------------------------------------------------------------------------------------------------------------

--- Get a percentage value relative to an interval.
--
--  If the value is less than or equal to the minimum value the return value will be `0`. If the value is greater
--  than or equal to the maximum value the return value will be `100`. In every other case the return value will be
--  the percentage value in the interval.
--
--  @n value The original value.
--  @n min The minimum value of the interval.
--  @n max The maximum value of the interval.
--  @N The percentage value relative to the interval, a float between `0` and `100` (inclusive).

local function percent (value, min, max)
   if value >= max then return 100 end
   if value <= min then return   0 end
   return (value - min) * 100 / (max - min)
end

-------------------------------------------------------------------------------------------------------------------
-- @export

return {
   percent = percent,
   warn    = warn,
}

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: