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

--- *Corky* interface to *Cairo*.
--
--  This module may be used to clean up the global namespace and remove all `cairo_*` and `CAIRO_*` variables and
--  functions. All of these variables/functions may then be accessed using the table returned by this module (with
--  or without `"cairo_"`/`"CAIRO_"` prefix).
--
--  *Conky*'s `cairo` module will be `require`d by this module automatically.
--
--  Usage example:
--
--    local cairo = require "corky.cairo"
--
--    -- Initialize surface and context:
--    cairo.init ()
--
--    -- Using long names:
--    cairo.cairo_show_text (cairo.context, "Some text…")
--
--    -- The same using short names:
--    cairo.show_text (cairo.c, "Some text…")
--
--    -- Clean up:
--    cairo.clean_up ()
--
--  **Cairo Surface And Context Properties:**
--
--  The properties `surface` (alias `s`) and `context` (alias `c`) will be provided by this module, see the example
--  above. They may be initialized by calling the @{cairo.init|init()} function, and destroyed by calling the
--  function @{cairo.clean_up|clean_up()}. It is of course possible to manually create another surface and/or
--  context, if required.
--
--  **Note:** If the @{corky|main module} is used, @{cairo.init|init()} and @{cairo.clean_up|clean_up()} will be
--  called before and after the draw hooks, respectively.
--
--  @MO corky.cairo
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this
--  @SE sort=false

-------------------------------------------------------------------------------------------------------------------

local _       = require "cairo"                                               -- Conky's Cairo module.
local conky   = require "corky.conky"                                         -- Required to create the surface.
local utils   = require "corky.utils"                                         -- For string.startswith().

local surface = nil
local context = nil

local cairo   = {}
local this    = {}

-------------------------------------------------------------------------------------------------------------------

--- Setup the *Cairo* functions and variables.
--
--  **This function will be called automatically when the module is loaded!**
--
--  This function will remove all global variables and functions with a name starting with `"cairo_"` or `"CAIRO_"`
--  from the global namespace. They will be available in the table returned by this module.
--
--  Calling this function multiple times is allowed, but usually not necessary.

this.setup = function ()

   for k, v in pairs (_G) do
      if k:startswith ("cairo_") or k:startswith ("CAIRO_") then
         cairo [k] = v
         _G    [k] = nil
      end
   end

end

-------------------------------------------------------------------------------------------------------------------

--- Initialize a *Cairo* surface and context.
--
--  This function will create a *Cairo* surface and a context that may be used for drawing to the *Conky* window.
--
--  After the initialization the surface may be accessed using the `surface` property (or the alias `s`), the
--  context may be accessed using the `context` property (alias `c`). Both may be `nil` if they are not yet
--  initialized or the initialization failed. It is recommended to check this before using them.
--
--  The @{cairo.clean_up|clean_up()} function may be used to destroy both the surface and the context.

this.init = function ()

   if surface or context then
      return
   end

   if not conky.window then
      return
   end

   surface = this.xlib_surface_create (
      conky.window.display,
      conky.window.drawable,
      conky.window.visual,
      conky.window.width,
      conky.window.height
   )

   context = this.create (surface)

end

--- Free the resources used by the surface and context.
--
--  This function will call *Cairo*'s `destroy()` function for the context and the `surface_destroy()` function for
--  the surface created by the @{cairo.init|init()} function. After that, the `context` and `surface` properties
--  will be `nil` and can no longer be used for drawing.

this.clean_up = function ()

   if context then
      this.destroy (context)
      context = nil
   end

   if surface then
      this.surface_destroy (surface)
      surface = nil
   end

end

-------------------------------------------------------------------------------------------------------------------

do

   this.setup ()

   --- The meta table for the `corky.cairo` table.
   --
   --  Provides a custom indexer to access the `cairo_*` stuff.
   --
   --  @l meta

   local meta = {}

   --- Return a `cairo_*` variable/function, or the surface or context.
   --
   --  The key parameter specifies the name of the variable or function to return. It may include the `"cairo_"`
   --  (or `"CAIRO_"`) prefix, it will be automatically added if it does not (with the exception of the keys
   --  `"surface"`, `"s"`, `"context"` and `"c"`).
   --
   --  @t self The `corky.cairo` table.
   --  @s key The name of the variable or function to return.
   --  @r The requested variable or function, or `nil` if it does not exist.
   --  @L

   meta.__index = function (self, key)
      if key == "context" or key == "c" then
         return context
      elseif key == "surface" or key == "s" then
         return surface
      elseif key:startswith ("cairo_") or key:startswith ("CAIRO_") then
         return cairo [key]
      end
      if cairo ["cairo_" .. key] then
         return cairo ["cairo_" .. key]
      end
      return cairo ["CAIRO_" .. key]
   end

   setmetatable (this, meta)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: