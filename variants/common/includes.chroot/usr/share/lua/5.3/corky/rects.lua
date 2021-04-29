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

--- Rectangular meters for *Corky*.
--
--  **Loading the module:**
--
--    #: include, corky.rects
--
--  **Adding a rectangular meter:**
--
--  _**Note:** This is only one line in the actual configuration. Do not add the line break!_
--
--    #: rect, <name>, <value>, <x>, <y>, <length>, <width>, <rotation>, <fcol>
--       [, <bcol>[, <scale>[, <scol>[, <min>[, <max>[, <hook>]]]]]]
--
--  **Parameters:**
--
--  *`<name>`*
--
--  * The name of the meter, may be any arbitrary string. It is currently not used and may be left empty. Multiple
--  meters with the same name are allowed.
--
--  *`<value>`*
--
--  * The value to display, e.g. `${cpu cpu1}` for a rectangular meter showing the current CPU usage of the first
--  CPU. The value will be retrieved using the @{corky.cache} module's @{corky.cache.percent|percent()} function.
--  To get correct values, it is necessary to manually add the value to the cache and define its minimum and
--  maximum value (either in a Lua script using @{corky.cache.set|set()} or using the `cache` directive in the
--  configuration file), even if the value itself is already a percentage (like `${cpu cpu1}`)! Please see the
--  @{corky.cache} module for more details.
--
--  *`<x>`*
--
--  * The X coordinate of the starting point of the meter. Must be a valid integer greater than or equal to `0`.
--
--  *`<y>`*
--
--  * The Y coordinate of the starting point of the meter. Must be a valid integer greater than or equal to `0`.
--
--  * **Note:** The meter will be drawn using *Cairo*'s `cairo_line_to()` function, starting at (`<x>`, `<y>`).
--  This coordinate is not located at a corner of the meter, but at the center of the starting edge.
--
--  *`<length>`*
--
--  * The length of the meter. Must be a valid integer greater than `0`.
--
--  *`<width>`*
--
--  * The width of the meter. Must be a valid integer greater than `0`.
--
--  *`<rotation>`*
--
--  * The rotation of the meter, in degrees. Must be a valid number greater than or equal to `0` and less than
--  `360`. For an angle of `0` the meter is drawn in the direction of the positive X axis. The angle increases in
--  clockwise direction, e.g. if set to `90` the meter is drawn downwards, if set to `180` the meter is drawn from
--  right to left, and for `270` it is drawn upwards.
--
--  *`<fcol>`*
--
--  * The foreground color, i.e. the color used to draw the meter from 0% (or the `<min>` value) to the value. The
--  @{corky.dcolors} module will be used to resolve the color, so any named color (see @{corky.colors}), fixed
--  dynamic color or gradient color (see @{corky.dcolors}) may be used, or a `0x<AARRGGBB>` value (or in fact any
--  valid number between `0` and `0xffffffff`, see the @{corky.colors|colors module}) may be used directly.
--
--  * **Note:** There will be no gradient displayed on the meter, i.e. the foreground color will be one color
--  across the length of the meter. The gradient (or fixed dynamic color), if one is used, will just be used to
--  calculate this one color based on the value. If dynamic colors are used, the threshold values must be specified
--  in percent. See @{corky.dcolors} for more details.
--
--  *`<bcol>`*
--
--  * Optional. The background color. If specified, the part of the meter between the value and the 100% position
--  (or the `<max>` value) will be filled with this color. The same notes as for the foreground color apply, please
--  see above.
--
--  *`<scale>`*
--
--  * Optional. The name of a list of scale positions. See the @{corky.lists} module on how to define a list. If
--  this is specified, the list must contain an arbitrary number of numeric values between `0` and `100`
--  (inclusive), in ascending order. These values specify the positions (in percent) of scale marks to be drawn
--  over the meter. To enable these marks, the parameter `<scol>` has to be specified, too.
--
--  *`<scol>`*
--
--  * Optional. The color for the scale marks. The same notes as for the foreground color apply, see above. Note
--  that the `<scale>` has to be a valid list as described above for marks to be drawn.
--
--  *`<min>`*
--
--  * Optional. The minimum value in percent, defaults to `0` if not specified.
--
--  *`<max>`*
--
--  * Optional. The maximum value in percent, defaults to `100` if not specified.
--
--  *`<hook>`*
--
--  * Optional. Specifies when to draw the meter. It must be either `"pre"` (to draw it during the pre-draw hook)
--  or `"post"` (to draw it during the post-draw hook). The default value is "post".
--
--  **Examples:**
--
--  Display the (total) CPU usage. Colors are defined using the `color` (see @{corky.colors}) and `dcolor` (see
--  @{corky.dcolors}) directives, and scale marks will be shown in 10% steps.
--
--  Note that optional values at the end may be left out completely, while the optional name of the meter may be
--  left empty, but the (empty) field itself has to be included!
--
--    #: cache, ${cpu}, 1, 0, 100
--
--    #: color,  black, 0x000000
--    #: color,  grey,  0x444444
--    #: dcolor, fg,    0x00ff00, 50, 0xffff00, 0xff0000
--
--    #: list, scale, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90
--
--    #: rect,, ${cpu}, 50, 50, 100, 10, 0, fg, grey, scale, black
--
--  Display the (total) CPU usage using two meters:
--
--    #: cache, ${cpu}, 1, 0, 100
--
--    #: rect,, ${cpu}, 50, 150, 50, 8, 270, 0xff0000, 0x444444,,,  0,  50
--    #: rect,, ${cpu}, 60, 150, 50, 8, 270, 0xff0000, 0x444444,,, 50, 100
--
--  This example will display two meters for the CPU usage. Values between 0% and 50% will be shown in the first
--  meter, i.e. if the CPU usage is 25%, the first meter will display a 50% value, while the second meter will show
--  0%. Values between 50% and 100% will be shown in the second meter, i.e. for a CPU usage of 75% the first meter
--  will show a 100% value, and the second meter will show a 50% value.
--
--  If you want to use scale marks on the meters, note that these are defined *per meter*. If in the example above
--  a list containing a single value of `50` is specified as `<scale>` parameter, a scale mark at the 50% position
--  of *both* meters will be drawn (i.e. at the 25% and 75% CPU usage positions)!
--
--  @MO corky.rects
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the defined meters.
--
--  The keys are the meter names, the values are arrays containing tables with the meter data defined under that
--  name, in the order they are added. The meter data tables contain the following keys: `value`, `x`, `y`,
--  `length`, `width`, `rotation`, `fcol`, `bcol`, `scale`, `scol`, `min`, `max`, `hook`. The scale will already be
--  resolved to the appropriate list, all colors will be strings (or numbers) and will be resolved at runtime to
--  allow for dynamic colors.
--
--  @l rects

-------------------------------------------------------------------------------------------------------------------

local utils  = require "corky.utils"                                          -- For table.pack() and .unpack().
local cache  = require "corky.cache"
local cairo  = require "corky.cairo"
local colors = require "corky.dcolors"
local lists  = require "corky.lists"
local v      = require "corky.validator"
local rects  = {}
local this   = {}

-------------------------------------------------------------------------------------------------------------------

--- Add a rectangular meter.
--
--  The parameters are the same as the parameters for the configuration directive, in the same order. Please see
--  above for more details.
--
--  This function will add the new meter to the list of meters, it will not draw it!
--
--  @p ...
--  * `name`: (@{string|*string*}) Name of the meter.
--  * `value`: (@{string|*string*}) Value of the meter.
--  * `x`: (**_int_**) X coordinate of the starting point (`x >= 0`).
--  * `y`: (**_int_**) Y coordinate of the starting point (`y >= 0`).
--  * `length`: (**_int_**) The length of the meter (`length > 0`).
--  * `width`: (**_int_**) The width of the meter (`width > 0`).
--  * `rotation`: (**_number_**) The rotation of the meter, in degrees (`0 <= rotation < 360`).
--  * `fcol`: The foreground color, uses @{corky.dcolors} to get the actual color.
--  * `bcol`: The background color, uses @{corky.dcolors} to get the actual color. (*optional*)
--  * `scale`: (@{string|*string*}) Name of a list with scale mark positions, see @{corky.lists}. (*optional*)
--  * `scol`: Scale color, uses @{corky.dcolors} to get the actual color. (*optional*)
--  * `min`: (**_number_**) Minimum value for the meter (`0 <= min < 100`). (*optional*)
--  * `max`: (**_number_**) Maximum value for the meter (`0 < max <= 100`). (*optional*)
--  * `hook`: (@{string|*string*}) When to draw the meter (either `"pre"` or `"post"`). (*optional*)
--  @B Returns `true` if the meter could be added, `false` in case of any error.

function this.add (name, value, x, y, length, width, rotation, fcol, bcol, scale, scol, min, max, hook)

   local valid = true

   valid, name     = v { v (name,     valid) . en . dv ("")                            }
   valid, value    = v { v (value,    valid) . r . s . ne ("")                         }
   valid, x        = v { v (x,        valid) . n . ge (0)                              }
   valid, y        = v { v (y,        valid) . n . ge (0)                              }
   valid, length   = v { v (length,   valid) . n . gt (0)                              }
   valid, width    = v { v (width,    valid) . n . gt (0)                              }
   valid, rotation = v { v (rotation, valid) . n . ge (0) . lt (360)                   }
   valid, fcol     = v { v (fcol,     valid) . en . r                                  }
   valid, bcol     = v { v (bcol,     valid) . en                                      }
   valid, scale    = v { v (scale,    valid) . en                                      }
   valid, scol     = v { v (scol,     valid) . en                                      }
   valid, min      = v { v (min,      valid) . en . dv (  0) . n . ge (  0) . lt (100) }
   valid, max      = v { v (max,      valid) . en . dv (100) . n . gt (min) . le (100) }
   valid, hook     = v { v (hook,     valid) . en . dv ("post") . eq ("pre", "post")   }

   if not valid then
      return false
   end

   if scale then
      scale = lists.get (scale)
      if not scale then
         return false
      end
      local last = nil
      for i = 1, #scale do
         valid, scale [i] =  v { v (scale [i]) . n . ir (0, 100) . ni (last) . gt (last) }
         if not valid then
            return false
         end
         last = scale [i]
      end
   end

   local rect = {
      value    = value,
      x        = x,
      y        = y,
      length   = length,
      width    = width,
      rotation = rotation,
      fcol     = fcol,
      bcol     = bcol,
      scale    = scale,
      scol     = scol,
      min      = min,
      max      = max,
      hook     = hook
   }

   if rects [name] then
      rects [name] [#(rects [name]) + 1] = rect
   else
      rects [name] = { rect }
   end

   return true

end

-------------------------------------------------------------------------------------------------------------------

--- Draw a rectangular meter.
--
--  **Note:** This function assumes that @{cairo.init|corky.cairo.init()} has been called and a valid surface and
--  context are available!
--
--  @i x X coordinate of the starting point.
--  @i y Y coordinate of the starting point.
--  @i length The length of the meter.
--  @i width The width of the meter.
--  @n rotation The rotation of the meter, in degrees.
--  @n p The percent value, relative to the meter.
--  @t fcol The foreground color, as `{ r, g, b, a }`, all values between `0` and `1` (inclusive).
--  @t[opt] bcol The background color, as `{ r, g, b, a }`, all values between `0` and `1` (inclusive).
--  @t[opt] scale Array containing the scale mark positions, in percent.
--  @t[opt] scol The scale marks' color, as `{ r, g, b, a }`, all values between `0` and `1` (inclusive).

function this.rect (x, y, length, width, rotation, p, fcol, bcol, scale, scol)

   cairo.save (cairo.c)

   cairo.translate (cairo.c, x, y)
   if rotation ~= 0 then
      cairo.rotate (cairo.c, rotation * (math.pi / 180))
   end

   local val_x = length * p / 100

   cairo.set_line_width (cairo.c, width)

   if bcol and p ~= 100 then
      cairo.move_to (cairo.c, val_x, 0)
      cairo.set_source_rgba (cairo.c, table.unpack (bcol))
      cairo.line_to (cairo.c, length, 0)
      cairo.stroke (cairo.c)
   end

   if p ~= 0 then
      cairo.move_to (cairo.c, 0, 0)
      cairo.set_source_rgba (cairo.c, table.unpack (fcol))
      cairo.rel_line_to (cairo.c, val_x, 0)
      cairo.stroke (cairo.c)
   end

   if scale and scol then

      cairo.set_source_rgba (cairo.c, table.unpack (scol))

      for i, pos in ipairs (scale) do

         cairo.move_to (cairo.c, math.floor (length * pos / 100 + 0.5), 0)
         cairo.rel_line_to (cairo.c, 1, 0)
         cairo.stroke (cairo.c)

      end

   end

   cairo.restore (cairo.c)

end

-------------------------------------------------------------------------------------------------------------------

--- Draw the meters.
--
--  @s hook Which meters to draw, either `"pre"` or `"post"`.

local function draw (hook)

   for _, entry in pairs (rects) do
      for i = 1, #entry do
         local c = entry [i]
         if c.hook == hook then
            local valid, p, fcol, bcol, scol = true, cache.percent (c.value)
            if p then
               valid, fcol = v { v (c.fcol, valid) . r . ch (colors.get (c.fcol, p)) . r }
               valid, bcol = v { v (c.bcol, valid) . o . ch (colors.get (c.bcol, p)) . r }
               valid, scol = v { v (c.scol, valid) . o . ch (colors.get (c.scol, p)) . r }
               if valid then
                  if c.min ~= 0 or c.max ~= 100 then
                     p = utils.percent (p, c.min, c.max)
                  end
                  this.rect (c.x, c.y, c.length, c.width, c.rotation, p, fcol, bcol, c.scale, scol)
               end
            end
         end
      end
   end

end

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for rect settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `rect` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)

      if #setting < 9 or #setting > 15 then                                      -- Wrong number of parameters.
         return false
      end

      return this.add (select (2, table.unpack (setting)))

   end

   local config = require "corky.config"
   config.handler ("rect", config_handler)

   local hooks = require "corky.hooks"
   hooks.add ("pre_draw",  function () draw ("pre" ) end)
   hooks.add ("post_draw", function () draw ("post") end)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: