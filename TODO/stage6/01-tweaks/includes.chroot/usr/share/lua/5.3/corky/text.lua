-- Coypright 2015-2019 Stefan Göbel.
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

--- Text drawing for *Corky*.
--
--  **Loading the module:**
--
--    #: include, corky.text
--
--  **Adding a font:**
--
--    #: list, <font_name>, <font_family>[, <font_slant>[, <font_weight>]]
--
--  **Note:** The @{corky.lists} module will automatically be loaded when @{corky.text} is loaded.
--
--  **Parameters:**
--
--  *`<font_name>`*
--
--  * The name for this font, will be used to reference the font in the `text` configuration directive (see below).
--  May be any arbitrary non-empty string.
--
--  *`<font_family>`*, *`<font_slant>`*, *`<font_weight>`*
--
--  * Specifies the font to be used, its slant and weight. These parameters will be passed to *Cairo*'s
--  `cairo_select_font_face` function. For more details please see *Cairo*'s documentation on
--  ["Rendering text and glyphs"](http://cairographics.org/manual/cairo-text.html#cairo-select-font-face).
--
--  * Note that `<font_slant>` and `<font_weight>` are optional parameters and may be left empty, the default
--  values are `CAIRO_FONT_SLANT_NORMAL` and `CAIRO_FONT_WEIGHT_NORMAL`, respectively. The `CAIRO_` prefix may be
--  omitted.
--
--  **Adding some text:**
--
--    #: text, <name>, <x>, <y>, <font_name>, <size>, <color>, <text>[, <parameter> …]
--
--  **Parameters:**
--
--  *`<name>`*
--
--  * The name of this text, may be any arbitrary string. It is currently not used and may be left empty. Multiple
--  texts with the same name are allowed.
--
--  *`<x>`*
--
--  * The X coordinate of the text. Must be a valid integer greater than or equal to `0`.
--
--  *`<y>`*
--
--  * The Y coordinate of the text. Must be a valid integer greater than or equal to `0`.
--
--  *`<font_name>`*
--
--  * The font to be used. It has to be defined using a `list` directive (as explained above) before the `text`
--  directive!
--
--  *`<size>`*
--
--  * The font size to use for the text. Must be a valid integer greater than `0`.
--
--  *`<color>`*
--
--  * The text color. The @{corky.dcolors} module will be used to resolve the color, so any named color (see
--  @{corky.colors}), fixed dynamic color or gradient color (see @{corky.dcolors}) may be used, or a `0x<AARRGGBB>`
--  value (or in fact any valid number between `0` and `0xffffffff`, see the @{corky.colors|colors module}) may be
--  used directly.
--
--  *`<text>`*, *`<parameter>`*
--
--  * The text to display. If only the `<text>` is specified without any more parameters, the `<text>` will be
--  drawn as is (`conky_parse` will not be called). If one or more parameters follow the `<text>`, these will be
--  parsed by `conky_parse` (via @{corky.cache}), and the text to print will be constructed using @{string.format},
--  with the `<text>` describing the format of the string, and the parsed parameter values as the format arguments.
--  Any arbitrary number of parameters (`> 0`) is supported.
--
--  * For dynamic colors, the value to determine the text color if no parameters are specified is `0`, if
--  parameters are specified the value of the last parameter will be used.
--
--  **Examples:**
--
--    #: list, fnt,   DejaVu Sans Mono
--    #: list, fnt_b, DejaVu Sans Mono, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD
--
--    #: cache, ${cpu}, 1, 0, 100
--
--    #: dcolor, color, 0x00ff00, 50, 0xffff00, 0xff0000
--
--    #: text,, 10, 10, fnt,   14, color,    %s,               ${cpu}
--    #: text,, 10, 30, fnt_b, 14, 0xabcdef, CPU: %s%% / %s%%, ${cpu cpu1}, ${cpu cpu2}
--
--  @MO corky.text
--  @CO © 2015-2019 Stefan Göbel
--  @RE 2019021401
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the defined texts.
--
--  The keys are the text names, the values are arrays containing tables with the text data defined under that
--  name, in the order they are added. The data tables contain the following keys: `x`, `y`, `font`, `slant`,
--  `weight`, `size`, `color`, `text` and `params`. `params` is an array containing the optional parameters.
--
--  @l texts

local utils  = require "corky.utils"                                          -- For table.pack() and .unpack().
local cache  = require "corky.cache"
local cairo  = require "corky.cairo"
local colors = require "corky.dcolors"
local lists  = require "corky.lists"
local v      = require "corky.validator"
local texts  = {}
local this   = {}

-------------------------------------------------------------------------------------------------------------------

--- Add a text.
--
--  The parameters are the same as the parameters for the configuration directive, in the same order. Please see
--  above for more details.
--
--  This function will add the text to the list of texts, it will not draw it!
--
--  @s name Name of the text.
--  @i x X coordinate of the text (`x >= 0`).
--  @i y Y coordinate of the text (`y >= 0`).
--  @s font_name Name of the font definition list, see @{corky.lists}.
--  @i size Font size (`size > 0`).
--  @p color The text color, uses @{corky.dcolors} to get the actual color.
--  @s text The text.
--  @p ... Additional parameters (enable @{string.format} text handling).
--  @B Returns `true` if the text could be added, `false` in case of any error.

function this.add (name, x, y, font_name, size, color, text, ...)

   local valid = true

   valid, name      = v { v (name,      valid) . en . dv ("") }
   valid, x         = v { v (x,         valid) . n . ge (0)   }
   valid, y         = v { v (y,         valid) . n . ge (0)   }
   valid, font_name = v { v (font_name, valid) . r            }
   valid, size      = v { v (size,      valid) . n . gt (0)   }
   valid, color     = v { v (color,     valid) . en . r       }
   valid, text      = v { v (text,      valid) . r            }

   if not valid then
      return false
   end

   local font = lists.get (font_name)

   if not font or font.n > 3 then
      return false
   end

   local f_family = font [1]
   local f_slant  = cairo.FONT_SLANT_NORMAL
   local f_weight = cairo.FONT_WEIGHT_NORMAL

   if font.n > 1 and font [2] and font [2] ~= "" then
      f_slant = cairo [font [2]]
      if not f_slant then
         return false
      end
   end

   if font.n > 2 and font [3] and font [3] ~= "" then
      f_weight = cairo [font [3]]
      if not f_weight then
         return false
      end
   end

   local txt = {
      x      = x,
      y      = y,
      font   = f_family,
      slant  = f_slant,
      weight = f_weight,
      size   = size,
      color  = color,
      text   = text,
      params = table.pack (...),
   }

   if texts [name] then
      texts [name] [#(texts [name]) + 1] = txt
   else
      texts [name] = { txt }
   end

   return true

end

-------------------------------------------------------------------------------------------------------------------

--- Draw some text.
--
--  **Note:** If the color can not be resolved the text will not be drawn!
--
--  **Note:** This function assumes that @{cairo.init|corky.cairo.init()} has been called and a valid surface and
--  context are available!
--
--  @i x X coordinate of the text.
--  @i y Y coordinate of the text.
--  @s font_family Font family.
--  @p font_slant Font slant (e.g. `cairo.FONT_SLANT_NORMAL`)
--  @p font_weight Font weight (e.g. `cairo.FONT_WEIGHT_NORMAL`).
--  @i size Font size.
--  @p color Text color (string or number).
--  @s text Text.
--  @p params Additional parameters.
--  @B Returns `true` if the text could be added, `false` in case of any error.

function this.text (x, y, font_family, font_slant, font_weight, size, color, text, params)

   local percent, result, output

   if params.n == 0 then
      color = colors.get (color, 0)
   else
      local values = {}
      for i = 1, params.n do
         values [i] = cache.get (params [i])
      end
      result, output = pcall (string.format, text, table.unpack (values))
      if not result then
         io.stderr:write (
            "Error formatting text: '" .. text .. "'"
               .. " for '" .. table.concat (params, ", ")
               .. "' => '" .. table.concat (values, ", ")
               .. "'\n"
         )
         return false
      end
      color = colors.get (color, cache.percent (params [params.n]))
   end

   if not color then
      return false
   end

   cairo.select_font_face (cairo.c, font_family, font_slant, font_weight)
   cairo.set_font_size    (cairo.c, size)
   cairo.set_source_rgba  (cairo.c, table.unpack (color))
   cairo.move_to          (cairo.c, x, y)
   cairo.show_text        (cairo.c, output)
   cairo.stroke           (cairo.c)

   return true

end

-------------------------------------------------------------------------------------------------------------------

--- Draw the texts.

local function draw ()

   for _, entry in pairs (texts) do
      for i = 1, #entry do
         local t = entry [i]
         this.text (t.x, t.y, t.font, t.slant, t.weight, t.size, t.color, t.text, t.params)
      end
   end

end

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for text settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `text` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)

      if #setting < 8 then                                                    -- Wrong number of parameters.
         return false
      end

      return this.add (select (2, table.unpack (setting)))

   end

   local config = require "corky.config"
   config.handler ("text", config_handler)

   local hooks = require "corky.hooks"
   hooks.add ("post_draw", draw)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: