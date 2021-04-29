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

--- Hooks for *Corky* modules.
--
--  Hooks provide a way for modules to have certain functions called automatically at certain points. However, this
--  module does not define any hooks itself. See the @{corky|main module} for the available hooks.
--
--  @MO corky.hooks
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)

-------------------------------------------------------------------------------------------------------------------

--- Stores the hooks.
--
--  The keys are the names of the hooks (arbitrary strings), the values are tables (arrays) containing a list of
--  functions to run when the hook is executed. To add a hook handler use @{hooks.add|add()}.
--
--  @l hooks

-------------------------------------------------------------------------------------------------------------------

local hooks = {}

-------------------------------------------------------------------------------------------------------------------

--- Register a function for a hook.
--
--  @s name The name of the hook.
--  @f hook Function to call when the hook is executed. It will be called without any parameters, its return value
--  will be ignored.

local function add (name, hook)

   if hooks [name] then
      hooks [name] [#(hooks [name]) + 1] = hook
   else
      hooks [name] = { hook }
   end

end

-------------------------------------------------------------------------------------------------------------------

--- Run all registered functions for the specified hook.
--
--  Functions will be run in the order they were added. They will be called without any parameters, and their
--  return value will be ignored. This function does nothing if no function has been registered for the specified
--  hook.
--
--  @s name The name of the hook.

local function run (name)

   if not hooks [name] then
      return
   end

   for i = 1, #(hooks [name]) do
      hooks [name] [i] ()
   end

end

-------------------------------------------------------------------------------------------------------------------
-- @export

return {
   add = add,
   run = run,
}

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: