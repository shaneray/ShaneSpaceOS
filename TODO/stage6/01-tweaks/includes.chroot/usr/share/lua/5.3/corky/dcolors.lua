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

--- Dynamic color handling for *Corky*.
--
--  This module may be used to store and retrieve dynamic colors — i.e. colors that change depending on some value.
--
--  There are two kinds of dynamic colors supported by this module. In both cases, the color depends on a value,
--  this is usually some value returned by `conky_parse()`. The two terms used in this documentation are:
--
--  * *Fixed dynamic colors*: If fixed dynamic colors are used, the actual color will be determined by a threshold.
--  Each dynamic color definition may contain an arbitrary number of thresholds, and for each threshold a color is
--  defined in the configuration file. The color assigned to the largest threshold that is smaller than or equal to
--  the value will be used. The color will be the same for all values between two thresholds.
--  * *Gradient colors*: If these are used, the configuration file determines a start and a stop color, and the
--  actual color will be determined by interpolating between these two to get the color for a given value.
--
--  **Loading the module:**
--
--    #: include, corky.dcolors
--
--  **Adding a dynamic color:**
--
--    #: dcolor, <name>, <color>[, <threshold>, <color> […]][, <color>]
--
--  The first parameter is the dynamic color's name (an arbitrary, non-empty string), the second parameter the
--  default or start color.
--
--  After the first two parameters an arbitrary number (zero or more) of parameters in pairs of two may appear: the
--  `<threshold>` specifies the value at which the *fixed dynamic color* will be changed to the following
--  `<color>`. These thresholds must be in ascending order, i.e. the first threshold value must be less than the
--  second one, which must be less than the third one etc. Arbitrary values may be used as thresholds, depending on
--  the actual value for which the fixed dynamic color should be used.
--
--  If after these (zero or more) threshold/color pairs another color is specified, the dynamic color will be used
--  as a *gradient*. This last color then specifies the stop color of the gradient (the color for a 100% value). In
--  this case, the threshold values must be between `0` and `100`. If specified, they will be used to split the
--  gradient into several different gradients (i.e. start color to first threshold color will be used for a value
--  from zero percent to the first threshold, etc.).
--
--  The color specifications may either be the usual (hexadecimal, RGB or ARGB format) number, or named colors
--  defined by a `color` directive (see the @{corky.colors} module). Gradient interpolation will include the alpha
--  value. Using a named color is required if you want to include a color with an alpha value of zero (again, see
--  @{corky.colors} for more details)!
--
--  **Note:** When using a named color it has to be defined before it is used in a `dcolor` directive! Named colors
--  will be resolved when the configuration is read, changing a named color after that will not change a dynamic
--  color that included it!
--
--  @MO corky.dcolors
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the user-defined dynamic colors.
--
--  The keys are the names of the dynamic colors. The values are arrays with the color information, in the same
--  format used in the configuration:
--
--  `{ <color>[, <threshold>, <color> […]][, <color>] }`.
--
--  @l dcolors

-------------------------------------------------------------------------------------------------------------------

local utils   = require "corky.utils"                                         -- For table.pack() and .unpack().
local colors  = require "corky.colors"
local dcolors = {}
local this    = {}

-------------------------------------------------------------------------------------------------------------------

--- Add a dynamic color entry, or change an existing entry.
--
--  The parameters to this function are exactly the same as for the `dcolor` configuration directive described
--  above:
--
--    set (<name>, <color>[, <threshold>, <color> […]][, <color>])
--
--  Please see the configuration section above for more details on these parameters.
--
--  @p ... See above for details about the parameters.
--  @B Returns `true` if the entry could be added or modified, `false` in case of any error (all parameters will be
--  checked for validity). Note that if an error occurs the dynamic color will not be added, and an existing one by
--  the specified name will not be changed.

this.set = function (...)

   local args = table.pack (...)
   local name = args [1]

   if args.n < 2 or not name or name == "" then                               -- Invalid parameters.
      return false
   end

   local start = colors.get (args [2])                                        -- Check for valid start color.
   if not start then
      return false
   end

   local stop = nil                                                           -- Check for valid stop color if one
   if args.n % 2 == 1 then                                                    --   is specified.
      stop = colors.get (args [args.n])
      if not stop then
         return false
      end
   end

   local d = { start }

   local max  = args.n - args.n % 2
   local last = nil

   for i = 3, max do
      if i % 2 == 1 then                                                      -- Threshold.
         local val = tonumber (args [i])
         if not val or (last and val <= last) then                            -- Must be greater than previous one.
            return false
         end
         if stop and (val <= 0 or val >= 100) then                            -- Gradient, threshold out of range.
            return false
         end
         last = val
         d [#d + 1] = val
      else                                                                    -- Color.
         local col = colors.get (args [i])
         if not col then
            return false
         end
         d [#d + 1] = col
      end
   end

   if stop then
      d [#d + 1] = stop
   end

   dcolors [name] = d

   return true

end

-------------------------------------------------------------------------------------------------------------------

--- Get a gradient color.
--
--  Uses linear interpolation in RGB space between the start and the stop color.
--
--  @t start The start color (for a value of 0%) of the gradient, as an array: `{<r>,<g>,<b>,<a>}`. All values must
--  be floats between `0` and `1` (inclusive).
--  @t stop The stop color (for a value of 100%) of the gradient, as an array: `{<r>,<g>,<b>,<a>}`. All values must
--  be floats between `0` and `1` (inclusive).
--  @n percent The position in the gradient, in percent - a number between `0` and `100` (inclusive).
--  @T Returns the gradient color at the specified position, as an array: `{<r>,<g>,<b>,<a>}`. All values will
--  be floats between `0` and `1` (inclusive).

this.gradient = function (start, stop, percent)
   local c = { 0, 0, 0, 0 }
   local p = percent / 100
   for i = 1, 4 do
      c [i] = (1 - p) * start [i] + p * stop [i]
   end
   return c
end

-------------------------------------------------------------------------------------------------------------------

--- Get the color for some value.
--
--  If no dynamic color by the name specified by the first parameter exists, this function will simply pass this
--  parameter to the @{colors.get|colors.get()} function and return the result. If a dynamic color exists, this
--  function will determine the requested color based on the supplied value (second parameter) and return it.
--
--  **Note:** The type of dynamic color - a *fixed dynamic color* or *gradient color* - will be determined based on
--  the definition of the color, see the configuration section above.
--
--  @p color The name of the dynamic color entry (assumed to be a fixed color specification if no dynamic color by
--  that name exists).
--  @n value The value used to select the color from a fixed dynamic color table or a color gradient. For gradients
--  the value has to be a number between `0` and `100` (inclusive). For fixed dynamic colors the value may be any
--  arbitrary number.
--  @T Returns an array containing the values for the red, green, blue and alpha channels, in that order. All
--  values are floating point numbers between `0` and `1` (inclusive). If an error occurs, `nil` will be returned
--  instead of the array.

this.get = function (color, value)

   if not color then
      return nil
   end

   if not dcolors [color] then
      return colors.get (color)
   end

   local v = tonumber (value)
   if not v then
      return nil
   end

   local c = dcolors [color]

   local i = 2                                                                -- Get the index of the threshold
   while i < #c and v >= c [i] do                                             --   entry for the value.
      i = i + 2
   end

   if #c % 2 == 0 then                                                        -- Gradient color.

      if v < 0 or v > 100 then
         return nil
      end

      local start_color = c [i - 1]                                           -- Gradient start color.
      local stop_color  = c [i + 1] or c [i]                                  -- Gradient stop color.
      local start_value = c [i - 2] or 0                                      -- Gradient start value.
      local stop_value  = c [i    ]                                           -- Gradient stop value.

      if i == #c then
         stop_value = 100
      end

      return this.gradient (
         start_color,
         stop_color,
         (v - start_value) * 100 / (stop_value - start_value)
      )

   else                                                                       -- Fixed dynamic color.

      return c [i - 1]

   end

end

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for dynamic color settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `dcolor` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)
      return this.set (select (2, table.unpack (setting)))
   end

   local config = require "corky.config"
   config.handler ("dcolor", config_handler)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: