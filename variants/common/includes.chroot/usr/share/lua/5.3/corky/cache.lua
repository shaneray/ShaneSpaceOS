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

--- A `conky_parse()` cache for *Corky*.
--
--  **Loading the module:**
--
--    #: include, corky.cache
--
--  **General options:**
--
--    #: option, corky.cache.default_update_interval, <number>
--
--  The `corky.cache.default_update_interval` option sets the update value for cache entries that are not
--  explicitely added in the configuration file or via @{cache.set|set()}. It must be a numerical (integer) value
--  greater than or equal to zero. The default is `1`.
--
--  **Adding cache entries:**
--
--    #: cache, <text>, <update>[, <min>[, <max>]]
--
--  The `<text>` parameter specifies the text to be parsed by `conky_parse()` (e.g. `"${cpu cpu1}"`). Every valid
--  string for `conky_parse()` is allowed, as long as it is not empty.
--
--  The `<update>` parameter specifies the update interval of the value. If this is set to `1`, it will be updated
--  on every *Conky* update cycle, if it is set to `2` it will be updated every two cycles etc. If `<update>` is
--  set to `0`, it will be updated only once when the value is first requested. `<update>` must be an integer
--  greater than or equal to zero.
--
--  The first two parameters are mandatory.
--
--  The two parameters `<min>` and `<max>` are optional. They may be used to set the minimum and maximum values for
--  the specified (parsed) `<text>`, which can be used to convert the raw value into a percentage value. This
--  obviously only works if the parsed `<text>` is a pure numerical value. To specify only the `max` value, leave
--  the `min` field empty. If both are specified, the `max` value must be greater than the `min` value. Both values
--  must be valid numbers. Note that if the actual value for the parsed `<text>` is outside of the spcified
--  [`<min>`, `<max>`] range, or if no `min` and/or no `max` values have been set, the minimum and/or the maximum
--  value will be adjusted when @{cache.percent|percent()} is called as required.
--
--  If a value is requested that has not been explicitely added to the cache via the configuration file (or in a
--  Lua script by using the @{cache.set|set()} function), it will be added automatically. Its update interval will
--  be set to the value of the `corky.cache.default_update_interval` option, see above. The minimum and maximum
--  values will be adjusted at runtime as required.
--
--  **Develper information:**
--
--  The cache must know the current number of *Conky* updates and maintains an internal update counter. This
--  counter is not updated automatically! To increase the counter, the @{corky|main module} must call the
--  @{cache:update|update()} function, preferably in the `lua_draw_hook_pre` function, before any values are
--  retrieved during the current update cycle. The cached values however will only be updated (if required
--  according to their update interval) when they are actually requested from the cache. For a value that is never
--  requested, `conky_parse()` will never be called!
--
--  @MO corky.cache
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the cache entries.
--
--  The keys in the table are the texts that should be parsed by `conky_parse()`. The values are tables with the
--  following keys:
--
--  * `last`   - The value of the update counter at the last update of the value, or `nil` before the first update.
--  * `min`    - The minimum value, may be `nil` if not set and @{cache.percent|percent()} has not been called yet.
--  * `max`    - The maximum value, may be `nil` if not set and @{cache.percent|percent()} has not been called yet.
--  * `update` - The update interval.
--  * `value`  - The cached value, as returned by `conky_parse()`, or `nil` before the first update.
--
--  @l cache

-------------------------------------------------------------------------------------------------------------------

local updates = 0
local this    = {}
local cache   = {}

-------------------------------------------------------------------------------------------------------------------

--- Increase (or set) the internal update counter.
--
--  This function should be called by the main module **once** per *Conky* update cycle, preferably before any
--  values are retrieved from the cache. If the parameter is specified, the update counter will be set to its
--  value. If it is not specified, the update counter will be increased by one. The initial value of the counter is
--  `0`.
--
--  @i[opt] count The new value of the internal update counter. Must be an integer greater than or equal to zero.

this.update = function (count)
   if not count then
      updates = updates + 1
   else
      updates = count
   end
end

-------------------------------------------------------------------------------------------------------------------

--- Get the value of the internal update counter.
--
--  Depending on the main module's usage of the @{cache.update|update()} function the value should roughly equal
--  *Conky*'s `${updates}`.
--
--  @I The value of the cache's internal update counter. Will be `0` if `update()` has never been called.

this.updates = function ()
   return updates
end

-------------------------------------------------------------------------------------------------------------------

do

   local conky   = require "corky.conky"
   local options = require "corky.options"

   local function update_cache (text)
      cache [text].last  = updates
      cache [text].value = conky.parse (text)
   end

   --- Retrieve a value from the cache.
   --
   --  The parameter specifies the value to be parsed by `conky_parse()`. The value will be updated if required,
   --  else the cached value will be returned. If there is no cache entry for the specified text, it will be added,
   --  with the update interval set to the default value (`1` by default, may be changed using the configuration
   --  option `corky.cache.default_update_interval`, see above).
   --
   --  @s text The text to be parsed by `conky_parse()` to get the desired value.
   --  @r The return value of `conky_parse` (either the cached value from a previous call to @{cache.get|get()} or
   --  the current value, depending on the entry's update interval and the time of the last update).

   this.get = function (text)

      if not cache [text] then
         this.set (text, options.get ("corky.cache.default_update_interval"))
      end

      if not cache [text].last then
         update_cache (text)
      elseif cache [text].update > 0 and updates - cache [text].last >= cache [text].update then
         update_cache (text)
      end

      return cache [text].value

   end

end

-------------------------------------------------------------------------------------------------------------------

--- Return a cached value in percent.
--
--  Like @{cache.get|get()}, but instead of returning the raw value of the parsed text this function returns the
--  value in percent (based on the range of the value set by the `min` and `max` options in the configuration file
--  or supplied to @{cache.set|set()}, or automatically determined minimum and maximum values).
--
--  If the current value exceeds the currently set range, or no range has been set yet, the minimum and/or maximum
--  value will be adjusted automatically. If, as a result of this, the minimum and maximum values are the same (and
--  thus the same as the current raw value), this function will return `100`.
--
--  This function internally uses @{cache.get|get()} to retrieve the raw value, see there for some more details. If
--  the raw value can not be converted to a number, this function returns `nil`.
--
--  @s text The text to be parsed by `conky_parse()` to get the desired value.
--  @N The return value of `conky_parse` in percent of its range, or `nil` if there was an error.

this.percent = function (text)

   local value = tonumber (this.get (text))

   if not value then
      return nil
   end

   local min = cache [text].min
   local max = cache [text].max

   if not min or min > value then                                             -- Adjust the minimum value if it has
      min = value                                                             --    has not been set or is greater
      cache [text].min = min                                                  --    than the current value.
   end

   if not max or max < value then                                             -- As above, for the maximum value.
      max = value
      cache [text].max = max
   end

   if min == max then                                                         -- Only happens if no range was set
      return 100                                                              --    min = max = value => 100%.
   end

   if min == 0 and max == 100 then                                            -- No need to calculate anything in
      return value                                                            --    that case.
   end

   return (value - min) * 100 / (max - min)

end

-------------------------------------------------------------------------------------------------------------------

--- Add an entry to the cache, or change an existing entry.
--
--  The parameters are the same as for the `cache` configuration directive. Please see the configuration section
--  above for a detailed description. The same restrictions mentioned there apply to this function. Note that, like
--  an entry in the configuration file, this function merely adds an entry to the cache (or changes an existing
--  entry), it will be parsed the first time by `conky_parse()` when it is first requested by calling either the
--  @{cache.get|get()} or @{cache.percent|percent()} function.
--
--  When the entry already exists in the cache, the values for the update interval, minimum and maximum will be set
--  to the new values (if no `min` or `max` parameter is specified the currently set values will be removed). The
--  currently cached `conky_parse`d value (if any) will also be removed, so the next call to @{cache.get|get()} or
--  @{cache.percent|percent()} will run `conky_parse` for the `<text>` regardless of the time of any previous
--  update.
--
--  @s text The text to be parsed by `conky_parse()`.
--  @i update The update interval for this cache entry. Must be an integer greater than or equal to zero.
--  @n[opt] min The minimum value for this cache entry. Must be a valid number, or `nil`. If it is specified and
--  `max` is specified, too, then `min` must be less than `max`.
--  @n[opt] max The maximum value for this cache entry. Must be a valid number, or `nil`. If it is specified and
--  `min` is specified, too, then `max` must be greater than `min`.

this.set = function (text, update, min, max)

   cache [text] = {
      update = update,
      min    = min or false,
      max    = max or false,
      last   =        false,
      value  =        false,
   }

end

-------------------------------------------------------------------------------------------------------------------

do

   local config  = require "corky.config"
   local options = require "corky.options"
   local v       = require "corky.validator"

   --- Check the default update interval for validity.
   --
   --  This handler will be called when the `corky.cache.default_update_interval` option is set in the config file.
   --  It will return `true` (and set the option to the new value) if the value is a valid integer greater than or
   --  equal to zero, else `false`.
   --
   --  @s opt The option name, will be `"corky.cache.default_update_interval"`.
   --  @s val The new value.
   --  @B Returns `true` on success, `false` in case of an error.
   --
   --  @c corky.config
   --  @c corky.options

   local function check_default_update_interval (opt, val)
      local valid, value = v { v (val) . n . ge (0) . d (1) }
      if valid then
         options.set (opt, value)
      end
      return valid
   end

   options.set ("corky.cache.default_update_interval", 1, check_default_update_interval)

   --- Configuration handler for cache settings.
   --
   --  This handler will be @{corky.config|called automatically} for every `cache` directive in the configuration
   --  file.
   --
   --  @t setting Array containing the configuration directive split into its individual parts.
   --  @B If successful `true`, `false` in case of any error.
   --
   --  @c corky
   --  @c corky.config

   local function config_handler (setting)

      local valid, text, update, min, max, _ = true

      valid, _      = v { v (#setting,    valid) . ir (3, 5)                        }
      valid, text   = v { v (setting [2], valid) . nm                               }
      valid, update = v { v (setting [3], valid) . n  . ge (0) . d (1)              }
      valid, min    = v { v (setting [4], valid) . en . o . n                       }
      valid, max    = v { v (setting [5], valid) . en . o . n . ni (min) . gt (min) }

      if not valid then
         return false
      end

      this.set (text, update, min, max)

      return true

   end

   config.handler ("cache", config_handler)

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: