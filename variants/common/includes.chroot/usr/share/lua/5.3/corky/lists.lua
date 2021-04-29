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

--- Define lists in the configuration.
--
--  **Loading the module:**
--
--    #: include, corky.lists
--
--  **Adding a list:**
--
--    #: list, <name>[, <item>[, <item> […]]]
--
--  Name must be a non-empty string identifying the list. Items may be arbitrary values, empty lists are allowed.
--
--  @MO corky.lists
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)

-------------------------------------------------------------------------------------------------------------------

--- Stores the lists.
--
--  The keys in the table are the list names. The values are the lists (tables, as arrays).
--
--  @l lists

-------------------------------------------------------------------------------------------------------------------

local utils = require "corky.utils"                                           -- For table.pack() and .unpack().
local lists = {}

-------------------------------------------------------------------------------------------------------------------

--- Get a list.
--
--  @s name The name of the list.
--  @T The list, or `nil` if it doesn't exist.

local function get (name)
   if name then
      return lists [name]
   end
   return nil
end

-------------------------------------------------------------------------------------------------------------------

--- Add an entry to the cache, or replace an existing entry.
--
--  **Note:** The array will be created using @{table.pack|table.pack()}, so it will include the key `n`.
--
--  @s name The name of the list.
--  @p ... The list elements.

local function set (name, ...)
   if name then
      lists [name] = table.pack (...)
   end
end

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for list settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `list` directive in the configuration file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)

      local name = setting [2]

      if not name or name == "" then
         return false
      end

      set (select (2, table.unpack (setting)))

      return true

   end

   local config = require "corky.config"
   config.handler ("list", config_handler)

end

-------------------------------------------------------------------------------------------------------------------
-- @export

return {
   set = set,
   get = get,
}

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: