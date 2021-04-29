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

--- Functions dealing with general options for *Corky* modules.
--
--  **Setting an option:**
--
--    #: config, <option>, <value>
--
--  All parameters are mandatory, additional parameters are not allowed. No validation is performed, values will be
--  set as they appear in the configuration file (as strings). The name of the option must already be known to this
--  module, trying to set an unknown option in the configuration file is not possible.
--
--  **Developer information:**
--
--  An option must have been set using the @{options.set|set()} function before it is used in the configuration
--  file, else it will be ignored!
--
--  It is recommended to use the full module name as prefix for an option. For example, the @{corky.cache} module
--  defines the `corky.cache.default_update_interval` option.
--
--  See the source of the @{corky.cache} module for an example.
--
--  @MO corky.options
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)

-------------------------------------------------------------------------------------------------------------------

--- Stores the general configuration options.
--
--  The keys are the options names (arbitrary non-empty strings), the values are the option values.
--
--  @l options

--- Stores the callbacks.
--
--  The keys are the options names (same as in `options`), the values are the callback functions.
--
--  @l callbacks

-------------------------------------------------------------------------------------------------------------------

local options   = {}
local callbacks = {}

-------------------------------------------------------------------------------------------------------------------

--- Set the specified option to the specified value.
--
--  Note that setting an option to `nil` will effectively delete this option.
--
--  A callback function may be provided as third parameter. The function will be called when the option is set in
--  the configuration file. It will be called with two parameters: the option name and the new value of the option,
--  in that order. If a callback is set, the value will not be set automatically when the configuration is parsed,
--  it has to be set in the callback function using `set()`! The callback function has to return `true` for valid
--  options, or `false` for invalid options (in which case an error message will be displayed).
--
--  A callback function may be removed by setting the third parameter to `false`. Not setting the third parameter
--  will not change the currently set (or not set) callback function.
--
--  @s option The name of the option to set.
--  @p value The value of the option.
--  @p[opt] callback Either a function, or `false`. See above for details.

local function set (option, value, callback)

   options [option] = value

   if callback ~= nil then
      if callback then
         callbacks [option] = callback
      else
         callbacks [option] = nil
      end
   end

end

-------------------------------------------------------------------------------------------------------------------

--- Get the current value of the specified option.
--
--  @s option The name of the option.
--  @r The current value of the option.

local function get (option)
   return options [option]
end

-------------------------------------------------------------------------------------------------------------------

do

   --- Configuration handler for cache settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `option` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --  @c corky

   local function config_handler (setting)

      if #setting ~= 3 then
         return false
      end

      local option = setting [2]
      local value  = setting [3]

      if option == "" or get (option) == nil then
         return false
      end

      if callbacks [option] then
         return callbacks [option] (option, value)
      else
         set (option, value)
      end

      return true

   end

   local config = require "corky.config"
   config.handler ("option", config_handler)

end

-------------------------------------------------------------------------------------------------------------------
--- @export

return {
   get = get,
   set = set,
}

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: