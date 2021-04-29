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

--- Dynamic loading of other *Corky* modules.
--
--  **Loading a module:**
--
--    #: include, <module>
--
--  This will load the specified module. Note that you have to load a module before you can use any of its
--  configuration options. The module name has to be the full name of the module, e.g. `"corky.colors"`.
--
--  **Note:** The call to `require` used to load a module in the @{include.config_handler|configuration handler}
--  will be wrapped in a `pcall`, so you will not see any error messages. Use a manual call to `require`, e.g. in
--  the @{corky|main module}, when testing your own modules.
--
--  @MO corky.include
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for include settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `include` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)

      if #setting ~= 2 then
         return false
      end

      local name = setting [2]
      if not name or name == "" then
         return false
      end

      return pcall (require, setting [2])

   end

   local config = require "corky.config"
   config.handler ("include", config_handler)

end

-------------------------------------------------------------------------------------------------------------------
--- @export

return {}

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: