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

--- Parameter validation for *Corky*.
--
--  This class provides methods for validating a value.
--
--  Usage example:
--
--    -- The module will return the constructor:
--    local validator = require "corky.validator"
--
--    -- Create a new validator instance for a value:
--    local instance = validator (some_value)
--
--    -- Validate it (the value must pass all tests):
--    instance.number       (   )
--    instance.less_than    ( 10)
--    instance.greater_than (-10)
--    instance.not_equals   (  0)
--
--    -- Get the value and the validation result:
--    local valid, value = instance.get ()
--
--  A short form exists, too. You can write the code above like this:
--
--    -- Get the constructor:
--    local v = require "corky.validator"
--
--    -- Same validations as above, plus getting the results, in one line:
--    local valid, value = v (some_value) . n . lt (10) . gt (-10) . ne (0) . get ()
--
--    -- Same as above, using the "constructor" instead of get():
--    local valid, value = v{v (some_value) . n . lt (10) . gt (-10) . ne (0) }
--
--  **General information:**
--
--  A validator instance basically contains a *value* and a validation result.
--
--  The first parameter passed to the @{validator.validator|constructor} specifies the (initial) value of the
--  *value*. The second (optional) parameter specifies the initial value of the validation result. If it is not
--  specified, it defaults to `true`.
--
--  The validation methods may change both the *value* and the validation result, see the description of the
--  individual methods for details.
--
--  If a validation fails (and thus the validation result is set to `false`), this validation result is final!
--  Actual validation (or conversion) code will be skipped after that, no matter what methods are called. This also
--  means that if the initial validation state is set to `false` via the constructor, no validation/conversion code
--  will be run for that instance at all.
--
--  The final result (i.e. the final, possibly modified *value*), and the validation result (either `true` or
--  `false`) may be retrieved using the @{validator.get|get()} method, or by calling the
--  @{validator.validator|"constructor"} function with one parameter, which must be an array with one element,
--  which must be the validator instance:
--
--    local instance = validator (some_value)
--
--    -- Validation method calls omitted…
--
--    local valid, value = validator ({ instance })
--
--  Parentheses may be omitted in this case:
--
--    local valid, value = validator { instance }
--
--  Methods may be called one after the other as multiple statements, as shown in the very first example above. In
--  that case, method notation, i.e. `instance.<method> ()`, is required, no matter if a method expects parameters
--  or not.
--
--  Validation and conversion methods return the instance, and thus methods may also be chained. For example:
--
--    instance.number ().less_than (10)
--
--  In that case, parentheses may be ommitted for methods that do not expect any parameters (unless the method is
--  the last one in the statement):
--
--    instance.number.less_than (10)
--
--  For most methods there are short aliases defined, e.g. the @{validator.number|number()} method may also be
--  called as `num` or `n`. All these features combined allow the short format mentioned above (with `v` being the
--  @{validator.validator|"constructor"}):
--
--    local valid, value = v{v (some_value) . n . lt (10) . gt (-10) . ne (0) }
--
--  Methods are named after the condition the *value* has to fulfill to pass the validation, e.g. the validation
--
--    instance.number.less_than (10).not_equal (0)
--
--  will only succeed if the *value* is a number (or a value that can be converted to a number), and if the value
--  is less than `10`, and if the value is not `0`.
--
--  To only retrieve the (possibly modified) *value* or the validation result, the two properties `value` and
--  `valid` may be used. These are not methods:
--
--    local value = instance.value
--    local valid = instance.valid
--
--  As a shortcut to get the validation result, the unary minus operator may be used:
--
--    local valid = - instance
--
--  This allows for omitting the outer @{validator.validator|"constructor"} call, for example if the validation is
--  done in an `if` statement:
--
--    if - v (some_value) . n . lt (10) . ne (0) then
--       -- Do some stuff if some_value is valid…
--    end
--
--  With Lua 5.2 or later, the length operator (`#`) may be used as a shortcut to get the *value*:
--
--    local value = # instance
--
--  @MO corky.validator
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL methods
--  @SE sort=false

local function validator (value, valid)

   ----------------------------------------------------------------------------------------------------------------

   local self      = {}
   local methods   = {}
   local metatable = {}
   local done      = false
   local skip_next = 0
   local last_func = nil
   local pack      = table.pack

   if valid == nil then
      valid = true
   end

   ----------------------------------------------------------------------------------------------------------------

   if not pack then
      pack = function (...)
         return { n = select ("#", ...), ... }
      end
   end

   ----------------------------------------------------------------------------------------------------------------

   local function exec_last (...)
      if last_func then
         last_func (...)
         last_func = nil
      end
   end

   ----------------------------------------------------------------------------------------------------------------

   function metatable.__call (t, ...)
      exec_last (...)
      return self
   end

   ----------------------------------------------------------------------------------------------------------------

   --- Properties
   --
   --  @section properties

   --- The following list shows the instance properties that are available. Note that these are read-only, trying
   --  to set them will be silently ignored.
   --
   --  @table instance
   --  @field valid The current validation result, either `true` or `false`.
   --  @field value The current validation *value*.

   ----------------------------------------------------------------------------------------------------------------

   --- Methods
   --
   --  @section methods

   --- Get the validation status and the *value*.
   --
   --  @function get
   --  @r The validation result, either `true` or `false`.
   --  @r The current *value*.

   function metatable.__index (t, k)
      exec_last ()
      if k == "get" then
         return function () return valid, value end
      elseif k == "value" then
         return value
      elseif k == "valid" then
         return valid
      elseif not valid or done then
         return self
      elseif methods [k] then
         if skip_next > 0 then
            skip_next = skip_next - 1
         else
            last_func = methods [k]
         end
         return self
      end
   end

   ----------------------------------------------------------------------------------------------------------------

   function metatable.__unm (t)
      exec_last ()
      return valid
   end

   ----------------------------------------------------------------------------------------------------------------

   function metatable.__len (t)
      exec_last ()
      return value
   end

   ----------------------------------------------------------------------------------------------------------------

   function metatable.__newindex (t, k, v)
   end

   ----------------------------------------------------------------------------------------------------------------

   metatable.__metatable = "validator"

   ----------------------------------------------------------------------------------------------------------------

   --- General
   --
   --  @section general

   ----------------------------------------------------------------------------------------------------------------

   --- Check if a required *value* is `nil`.
   --
   --  If the *value* is `nil`, it will be marked as invalid.
   --
   --  **Aliases:** `r`, `req`

   function methods.required ()
      if value == nil then
         valid = false
      end
   end

   methods.req = methods.required
   methods.r   = methods.required

   ----------------------------------------------------------------------------------------------------------------

   --- Check if an optional *value* is `nil`.
   --
   --  If the *value* is `nil`, it will be considered valid, but all following validation methods will be skipped
   --  (the result is final).
   --
   --  **Aliases:** `o`, `opt`

   function methods.optional ()
      if value == nil then
         done = true
      end
   end

   methods.opt = methods.optional
   methods.o   = methods.optional

   ----------------------------------------------------------------------------------------------------------------

   --- Set a default value.
   --
   --  **This method will modify the *value*!**
   --
   --  If the *value* is `nil`, it will be set to the specified default value. This will be considered valid. All
   --  following validation methods will be skipped (the result is final).
   --
   --  **Aliases:** `dv`, `def`
   --
   --  @p default The default value.

   function methods.default_value (default)
      if value == nil then
         value = default
         done  = true
      end
   end

   methods.def = methods.default_value
   methods.dv  = methods.default_value

   ----------------------------------------------------------------------------------------------------------------

   --- Changes the *value*.
   --
   --  **This method will modify the *value*!**
   --
   --  **This method will not modify the validation result.**
   --
   --  Changes the *value* to the value specified by the parameter.
   --
   --  **Aliases:** `ch`
   --
   --  @p new_value The new value.

   function methods.change_value (new_value)
      value = new_value
   end

   methods.ch = methods.change_value

   ----------------------------------------------------------------------------------------------------------------

   --- Check the type of the *value*.
   --
   --  If the type of the *value* matches one of the parameters, the validation passes. Else the *value* will be
   --  marked as invalid.
   --
   --  **Aliases:** `t`
   --
   --  @p ... An arbitrary number of strings specifying the allowed types for the *value*. Valid type names are
   --  `"nil"`, `"boolean"`, `"number"`, `"string"`, `"userdata"`, `"function"`, `"thread"`, and `"table"`.

   function methods.type (...)
      local t = type (value)
      local p = pack (...)
      for i = 1, p.n do
         if t == p [i] then
            return
         end
      end
      valid = false
   end

   methods.t = methods.type

   ----------------------------------------------------------------------------------------------------------------

   --- Call an external validation function.
   --
   --  The first parameter must be a function. It will be called with the *value* as the first parameter, all
   --  remaining parameters will be passed to the function after the *value*. The return value of the function will
   --  be used in boolean context, if it evaluates to `false`, e.g. if it is `false` or `nil`, the *value* will be
   --  marked as invalid.
   --
   --  **Aliases:** `x`, `ext`
   --
   --  @f func The function to call.
   --  @p ... Additional parameters to pass to the function.

   function methods.external (func, ...)
      if not func (value, ...) then
         valid = false
      end
   end

   methods.ext = methods.external
   methods.x   = methods.external

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* equals one of the parameters.
   --
   --  An arbitrary number of parameters may be specified. If the *value* matches one of these, the validation
   --  passes, if it does not match one of the parameters, it will be marked as invalid.
   --
   --  Note: If called without any parameters the *value* will be marked as invalid!
   --
   --  **Aliases:** `e`, `eq`
   --
   --  @p ... An arbitrary number of arbitrary values against which the *value* will be checked.

   function methods.equal (...)
      local p = pack (...)
      for i = 1, p.n do
         if value == p [i] then
            return
         end
      end
      valid = false
   end

   methods.eq = methods.equal
   methods.e  = methods.equal

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* does not equal the parameter.
   --
   --  If the *value* equals the parameter, it will be marked as invalid.
   --
   --  **Aliases:** `ne`, `neq`
   --
   --  @p match An arbitrary value to check against.

   function methods.not_equal (match)
      if value == match then
         valid = false
      end
   end

   methods.neq = methods.not_equal
   methods.ne  = methods.not_equal

   ----------------------------------------------------------------------------------------------------------------

   --- Numbers
   --
   --  @section numbers

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* can be converted to a number.
   --
   --  **This method will modify the *value*!**
   --
   --  This method will convert the *value* to a number (by calling @{tonumber|tonumber()}). If this fails, the
   --  *value* will be marked as invalid.
   --
   --  Note: For a type check without conversion the @{validator.type|type()} method may be used. To check if the
   --  *value* can be converted to a number without converting it the @{validator.external|external()} method may
   --  be used with @{tonumber} as parameter.
   --
   --  **Aliases:** `n`, `num`
   --
   --  @n[opt] base Will be passed to @{tonumber|tonumber()}, see there for more details.

   function methods.number (base)
      value = tonumber (value, base)
      if not value then
         valid = false
      end
   end

   methods.num = methods.number
   methods.n   = methods.number

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* is in the specified range.
   --
   --  This method will mark the *value* as invalid if it is less than the specified minimum or greater than the
   --  specified maximum value.
   --
   --  **Aliases:** `ir`, `range`
   --
   --  @n min The minimum value.
   --  @n max The maximum value.

   function methods.in_range (min, max)
      if value < min or value > max then
         valid = false
      end
   end

   methods.range = methods.in_range
   methods.ir    = methods.in_range

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* is greater than the parameter.
   --
   --  If the *value* is greater than the parameter, the validation passes, else it will be marked as invalid.
   --
   --  **Aliases:** `gt`
   --
   --  @n number The value to compare.

   function methods.greater_than (number)
      if value <= number then
         valid = false
      end
   end

   methods.gt = methods.greater_than

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* is less than the parameter.
   --
   --  If the *value* is less than the parameter, the validation passes, else it will be marked as invalid.
   --
   --  **Aliases:** `lt`
   --
   --  @n number The value to compare.

   function methods.less_than (number)
      if value >= number then
         valid = false
      end
   end

   methods.lt = methods.less_than

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* is greater than or equal to the parameter.
   --
   --  If the *value* is greater than or equal to the parameter, the validation passes, else it will be marked as
   --  invalid.
   --
   --  **Aliases:** `ge`
   --
   --  @n number The value to compare.

   function methods.greater_or_equal (number)
      if value < number then
         valid = false
      end
   end

   methods.ge = methods.greater_or_equal

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* is less than or equal to the parameter.
   --
   --  If the *value* is less than or equal to the parameter, the validation passes, else it will be marked as
   --  invalid.
   --
   --  **Aliases:** `le`
   --
   --  @n number The value to compare.

   function methods.less_or_equal (number)
      if value > number then
         valid = false
      end
   end

   methods.le = methods.less_or_equal

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* is divisible by one of the parameters.
   --
   --  If the *value* is divisible by one of the parameters, the check passes, else it will be marked as invalid.
   --
   --  **Aliases:** `d`, `div`
   --
   --  @p ... An arbitrary number of numbers to check against.

   function methods.divisible (...)
      local p = pack (...)
      for i = 1, p.n do
         if value % p [i] == 0 then
            return
         end
      end
      valid = false
   end

   methods.div = methods.divisible
   methods.d   = methods.divisible

   ----------------------------------------------------------------------------------------------------------------

   --- Strings
   --
   --  @section strings

   ----------------------------------------------------------------------------------------------------------------

   --- Check if the *value* can be converted to a string.
   --
   --  **This method will modify the *value*!**
   --
   --  This method will convert the *value* to a string (by calling @{tostring|tostring()}). If this fails, the
   --  *value* will be marked as invalid *[not sure if this can happen]*.
   --
   --  Note: For a type check without conversion the @{validator.type|type()} method may be used.

   function methods.string ()
      value = tostring (value)
      if not value then
         valid = false
      end
   end

   methods.str = methods.string
   methods.s   = methods.string

   ----------------------------------------------------------------------------------------------------------------

   --- Check if an optional *value* is an empty string.
   --
   --  If the *value* is an empty string (`""`), it will be considered valid, and all following validation methods
   --  will be skipped (the result is final).
   --
   --  **Aliases:** `oe`, `oem`

   function methods.optional_empty ()
      if value == "" then
         done = true
      end
   end

   methods.oe = methods.optional_empty

   ----------------------------------------------------------------------------------------------------------------

   --- Check for an empty string.
   --
   --  If the *value* (which must be a string, this is not checked by this method) is empty (i.e. `""`), it will be
   --  marked as invalid.
   --
   --  **Aliases:** `nm`, `nem`

   function methods.not_empty ()
      if value == "" then
         valid = false
      end
   end

   methods.nem = methods.not_empty
   methods.nm  = methods.not_empty

   ----------------------------------------------------------------------------------------------------------------

   --- Set the *value* to `nil` if it is an empty string.
   --
   --  **This method will modify the *value*!**
   --
   --  **This method will not modify the validation result.**
   --
   --  **Aliases:** `en`, `etn`

   function methods.empty_to_nil ()
      if value == "" then
         value = nil
      end
   end

   methods.etn = methods.empty_to_nil
   methods.en  = methods.empty_to_nil

   ----------------------------------------------------------------------------------------------------------------

   --- Change the *value* to its string length.
   --
   --  **This method will modify the *value*!**
   --
   --  **This method will not modify the validation result.**
   --
   --  @{string.len|string.len()} will be called for the current *value*, and the value will be changed to the
   --  result.
   --
   --  **Aliases:** `l`, `len`

   function methods.length ()
      value = string.len (value)
   end

   methods.len = methods.length
   methods.l   = methods.length

   ----------------------------------------------------------------------------------------------------------------

   --- Conditional
   --
   --  @section conditional

   ----------------------------------------------------------------------------------------------------------------

   --- Skip the next check(s) if a condition is met.
   --
   --  **This method will not modify the validation result.**
   --
   --  The first parameter will be evaluated in boolean context. If it is a false value, the following validation
   --  methods will be skipped, if it is a true value nothing will be done and processing continues with the next
   --  method. The number of methods to skip may be specified using the second parameter, it must be an integer
   --  greater than or equal to `1`. It defaults to `1` if not specified. The `next_if()` method itself does not
   --  modify the validation result or the *value*.
   --
   --  **Aliases:** `ni`, `nif`
   --
   --  @b condition The condition, its value will be evaluated in boolean context.
   --  @i[opt] number The number of validations to skip.

   function methods.next_if (condition, number)
      if not number then
         number = 1
      end
      if not condition then
         skip_next = skip_next + number
      end
   end

   methods.nif = methods.next_if
   methods.ni  = methods.next_if

   --- @section end
   ----------------------------------------------------------------------------------------------------------------

   return setmetatable (self, metatable)

   ----------------------------------------------------------------------------------------------------------------

end

-------------------------------------------------------------------------------------------------------------------

--- Constructor, or getter.
--
--  This function is returned by the module:
--
--    local validator = require "corky.validator"
--
--  If the first parameter of this function is an array with one element (at position `1`), and this one element is
--  a validator instance, the function will return the current validation result and the current *value* of that
--  instance, in that order. This is just syntactic sugar, it may be used instead of the @{validator.get|get()}
--  method. Please see above for usage examples.
--
--  In all other cases, this function will return a new validator instance, with the current *value* set to the
--  value specified as the first parameter. The optional second parameter may be used to set the initial validation
--  result, it must be either `true` or `false`.
--
--  @function validator
--  @p value The initial *value* of a new validator instance, or an array containing an existing instance when used
--  as a getter.
--  @b[opt] valid The initial validation result.
--  @r Either the new validator instance, or the instance's validation result and *value* when used as a getter.

return function (value, valid)
   if type (value) == "table" and #value == 1 and type (value [1]) == "table" then
      local meta = getmetatable (value [1])
      if type (meta) == "string" and meta == "validator" then
         return value [1].get ()
      end
   end
   return validator (value, valid)
end

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: