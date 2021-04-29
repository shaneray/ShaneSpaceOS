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

--- *Corky* interface to *Conky*.
--
--  This module will clean up the global namespace and remove all `conky_*` variables and functions (with the
--  exception of `conky_window`). All of these variables/functions may then be accessed using the table returned
--  by this module:
--
--    local conky = require "corky.conky"
--
--    -- Use conky.build_info instead of conky_build_info:
--    print (conky.build_info)
--
--    -- The "conky_" prefix is allowed:
--    print (conky.conky_build_info)
--
--  The `conky_window` table must be available globally for *Conky*'s *Cairo* interface to work, so it will not be
--  removed. It can be accessed as global variable or like the other variables via the table returned by this
--  module.
--
--  @MO corky.conky
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the `conky_*` variables and functions.
--
--  The keys in the table are the original names (including the `"conky_"` prefix). The values are the
--  corresponding variables and functions.
--
--  @l conky

-------------------------------------------------------------------------------------------------------------------

local utils = require "corky.utils"                                           -- For table.pack() and .unpack().
local this  = {}
local conky = {}
local keep  = {}

-------------------------------------------------------------------------------------------------------------------

--- Setup the *Conky* functions and variables.
--
--  **This function will be called automatically when the module is loaded!**
--
--  After calling this function all global variables and functions with a name starting with `"conky_"` will be
--  removed from the global namespace. Instead, they will be available in the table returned by this module.
--
--  Since *Conky* requires some functions to be available globally, an arbitrary number of parameters may be
--  specified to keep these functions (or variables) in `_G`. The parameters must be strings, specifying the names
--  of the functions or variables, without the `"conky_"` prefix. If @{conky.global|global()} has been called for
--  some functions or variables before `setup()`, all these functions or variables will be excluded, too.
--
--  **Note:** There is a built-in exception: the `conky_window` table will not be removed from the global
--  namespace. It appears that removing it breaks *Conky*'s *Cairo* interface. All variables that are kept in `_G`
--  will still be copied to this module's table and - depending on the variable type - may be accessed both ways.
--
--  Calling this function multiple times is allowed, but usually not necessary.
--
--  @p ... An arbitrary number of strings, specifying which functions or variables to keep in the global namespace.
--  The names must not include the `"conky_"` prefix.

this.setup = function (...)

   local args = table.pack (...)

   for i = 1, args.n do
      keep ["conky_" .. args [i]] = true
   end

   for k, v in pairs (_G) do
      if k:startswith ("conky_") then
         conky [k] = v
         if not keep [k] and k ~= "conky_window" then
            _G [k] = nil
         end
      end
   end

end

-------------------------------------------------------------------------------------------------------------------

--- Make `conky_*` functions or variables global.
--
--  Once a name has been marked as global by this function, @{conky.setup|setup()} will not remove it from the
--  global namespace. If @{conky.setup|setup()} has been called already, all specified functions or variables will
--  be copied back into the global namespace.
--
--  **Note:** Variables or functions will be copied to `_G`, and will still be available in the table returned by
--  this module. Keep in mind that changing value type variables (e.g. strings or numbers) will only change one of
--  the copies!
--
--  @p ... Names of the functions or variables to keep in or copy back to the global namespace. Names must not
--  include the `"conky_"` prefix, it will be added automatically!

this.global = function (...)

   local args = table.pack (...)

   for i = 1, args.n do
      local name = "conky_" .. args [i]
      keep [name] = true
      if conky [name] then
         _G [name] = conky [name]
      end
   end

end

-------------------------------------------------------------------------------------------------------------------

do

   this.setup ()

   --- The meta table for the corky.conky table.
   --
   --  Provides a custom indexer to access the `conky_*` stuff.
   --
   --  @l meta

   local meta = {}

   --- Return a `conky_*` variable/function.
   --
   --  The key parameter specifies the name of the variable or function to return. It may include the `"conky_"`
   --  prefix, it will be automatically added if it does not.
   --
   --  @t self The `corky.conky` table.
   --  @s key The name of the variable or function to return.
   --  @r The requested variable or function, or `nil` if it does not exist.
   --  @L

   meta.__index = function (self, key)
      if key == "conky_window" or key == "window" then
         return _G ["conky_window"]
      end
      if key:startswith ("conky_") then
         return conky [key]
      end
      return conky ["conky_" .. key]
   end

   setmetatable (this, meta)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: