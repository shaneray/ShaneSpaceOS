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

--- Color handling for *Corky*.
--
--  This module may be used to store and retrieve colors using custom names.
--
--  **Loading the module:**
--
--    #: include, corky.colors
--
--  **Adding a named color:**
--
--  These configuration directives will add the specified color to the color table. It may then be accessed by its
--  name. In all the directives the `<name>` may be any arbitrary, non-empty string.
--
--    #: color, <name>, <red>, <green>, <blue>[, <alpha>]
--
--  The `<red>`, `<green>`, `<blue>` and `<alpha>` values specify the color. These must be floating point numbers
--  between `0` and `1` (inclusive). The `<alpha>` parameter is optional, it defaults to `1` if omitted.
--
--    #: color, <name>, <rgb>[, <alpha>]
--
--  The `<rgb>` parameter specifies the color. It must be a valid number, usually the hexadecimal representation of
--  the color (i.e. `0xRRGGBB`). It may include the alpha value (ARGB format: `0xAARRGGBB`). The alpha value may
--  also be specified by an additional parameter, in that case it has to be a floating point number between `0` and
--  `1` (inclusive). If no alpha value is specified at all, it defaults to `1`. If an alpha value is specified via
--  both parameters, the optional alpha parameter will override the alpha value of `<rgb>`. Note that to specify an
--  alpha value of `0`, it has to be supplied as the extra alpha parameter!
--
--  @MO corky.colors
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the user-defined colors.
--
--  The keys are the names of the colors, or the numbers/strings supplied to @{colors.get|get()} for automatically
--  added color entries. The values are tables with the color information `{<R>, <G>, <B>, <A>}`. Note that every
--  color accessed with @{colors.get|get()} will be cached in the table!
--
--  @l colors

-------------------------------------------------------------------------------------------------------------------

local utils  = require "corky.utils"                                          -- For table.pack() and .unpack().
local v      = require "corky.validator"
local colors = {}
local this   = {}

-------------------------------------------------------------------------------------------------------------------

do

   local function extract (s, p)                                              -- Extract a byte from a hex string
      return tonumber (string.sub (s, 2 * p - 1, 2 * p), 16) / 255            --   (2 chars -> "00" .. "ff") and
   end                                                                        --   convert it to 0 <= value <= 1.

   --- Get the individual R, G, B and A channels for a specified color.
   --
   --  There are two ways to call this function:
   --
   --  * If called with **one or two parameters**, the first parameter will be treated as a number, defining the
   --  color. This is usually a hexadecimal representation in the form `0xRRGGBB` (RGB) or `0xAARRGGBB` (ARGB),
   --  though any value that can be converted to a valid number between `0` and `0xffffffff` (inclusive) will work.
   --  The (optional) second parameter may be used to specify the alpha value, it must be a float between `0` and
   --  `1` (inclusive). If the first parameter includes an alpha value (i.e. if it is greater than `0x00ffffff`,
   --  ARGB format), the second parameter will override it! Note that for an alpha value of zero you have to use
   --  the two parameter form! If there is no value specified for alpha, it defaults to `1`.
   --  * If called with **three or four parameters**, the first three parameters will be treated as the R, G and B
   --  channel values (in that order), and the fourth (optional) parameter as the alpha value. All values must be
   --  floats between `0` and `1` (inclusive). If alpha is omitted, it defaults to `1`.
   --
   --  **Note:** All parameters will be validated, on error this function returns `nil`.
   --
   --  @p ... See above for a description of the parameters.
   --  @T An array containing the values for the red, green, blue and alpha channels, in that order. All values are
   --  floating point numbers between `0` and `1` (inclusive). Returns `nil` on error.

   this.to_rgba = function (...)

      local args = table.pack (...)

      if args.n == 1 or args.n == 2 then                                      -- <color>[, <alpha>]

         local valid, color, alpha = true

         valid, color = v { v (args [1], valid)          . n . ir (0, 0xffffffff) . d (1) }
         valid, alpha = v { v (args [2], valid) . dv (1) . n . ir (0,          1)         }

         if not valid then
            return nil
         end

         local hex = string.format ("%08x", color)                            -- As hexadecimal string: 0xAARRGGBB.

         if color > 0x00ffffff and args.n == 1 then                           -- Get alpha from c unless specified
            alpha = extract (hex, 1)                                          --    explicitely.
         end

         return { extract (hex, 2), extract (hex, 3), extract (hex, 4), alpha }

      elseif args.n == 3 or args.n == 4 then                                  -- <red>, <green>, <blue>[, <alpha>]

         local valid, r, g, b, a = true

         valid, r = v { v (args [1], valid)          . n . ir (0, 1) }        -- Check for valid values.
         valid, g = v { v (args [2], valid)          . n . ir (0, 1) }
         valid, b = v { v (args [3], valid)          . n . ir (0, 1) }
         valid, a = v { v (args [4], valid) . dv (1) . n . ir (0, 1) }

         if not valid then
            return nil
         end

         return { r, g, b, a }

      end

      return nil

   end

end

-------------------------------------------------------------------------------------------------------------------

--- Add a color to the color cache, or change an existing entry.
--
--  This function may be used to add a named or unnamed color to the color cache, or change an existing color.
--
--  * If called with only **one parameter**, this parameter is assumed to be a single color specification (usually
--  a hexadecimal string, but any value that can be converted to a valid integer between `0` and `0xffffffff` will
--  work). It will be processed by @{colors.to_rgba|to_rgba()} and added to the color cache, the key will be the
--  color as it is specified (i.e. no conversion will be performed for the key, it may be a string or a number).
--  * If called with **more than one parameter**, the first parameter will be used as the name of the color, and
--  all remaining parameters will be passed to @{colors.to_rgba|to_rgba()} to be processed, please see there for a
--  description of possible values. The color will be added to the cache with the color name (first parameter) as
--  the key.
--
--  Note: If the key already exists in the cache the existing entry will be overridden with the new color!
--
--  @p ... See above for a description of the parameters.
--  @T Returns an array containing the values for the red, green, blue and alpha channels of the color, in that
--  order. All values are floating point numbers between `0` and `1` (inclusive). Returns `nil` on error.

this.set = function (...)

   local args  = table.pack (...)
   local name  = args [1]
   local color = nil

   if args.n == 1 then
      color = this.to_rgba (name)
   else
      color = this.to_rgba (select (2, ...))
   end

   colors [name] = color

   return color

end

-------------------------------------------------------------------------------------------------------------------

--- Get a color from the cache.
--
--  This function will return the cached color, i.e. an array containg the R, G, B and alpha values, if it exists
--  in the color cache. If it does not exist, the specified name is assumed to be a color specification, usually a
--  hexadecimal representation in RGB or ARGB format (any other value that can be converted to a valid number may
--  be used though), and it is automatically converted to `{ <r>, <g>, <b>, <a> }`, added to the cache and then
--  returned. Note that the key to access it is the unaltered parameter value, that means that - for example - the
--  two parameters `0xabcdef` (a number) and `"0xabcdef"` (a string) will result in two cache entries, even though
--  the color will be the same.
--
--  @p color The name of the color or a color specification.
--  @T Returns an array containing the values for the red, green, blue and alpha channels of the requested color,
--  in that order. All values are floats between `0` and `1` (inclusive). Returns `nil` on error.

this.get = function (color)

   if colors [color] then
      return colors [color]
   else
      return this.set (color)
   end

end

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for color settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `color` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)

      local valid, _ = true

      valid, _ = v { v (#setting,    valid) . ir (3, 6) }                        -- Basic validation of the number
      valid, _ = v { v (setting [2], valid) . nm        }                        --    of parameters and the name.

      if not valid then
         return false
      end

      if not this.set (select (2, table.unpack (setting))) then                  -- Everything else is checked in
         return false                                                            --    to_rgba() which is called by
      end                                                                        --    set().

      return true

   end

   local config = require "corky.config"
   config.handler ("color", config_handler)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: