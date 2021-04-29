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

--- *Corky* main module.
--
--  This module is the one that should be loaded in *Conky*'s configuration file. It contains the startup, pre- and
--  post-draw and shutdown hooks.
--
--  To use it, include the following lines in the *Conky* configuration (assuming the file `corky.lua` and the
--  `corky` folder are placed in the `~/.conky/lua/` directory, modify the `lua_load` directive according to your
--  setup):
--
--    conky.config = {
--
--       -- […]
--
--       lua_load             = "~/.conky/lua/corky.lua",
--       lua_startup_hook     = "startup_hook",
--       lua_draw_hook_pre    = "draw_hook_pre",
--       lua_draw_hook_post   = "draw_hook_post",
--       lua_shutdown_hook    = "shutdown_hook",
--
--       -- […]
--
--    };
--
--  **Configuration of *Corky*:**
--
--  All settings for *Corky* are included in the *Conky* configuration file. There is usually no need to edit any
--  of the Lua source files. See the @{corky.config} module for a general syntax description, and the individual
--  modules for details about available configuration options. An example configuration file is included in the
--  `example` folder.
--
--  **Developer information:**
--
--  This module will add its parent directory to the global package search path. *Corky* modules are placed in the
--  `corky` folder (let's call it namespace). If you want to add your own modules, it is recommended to use the
--  `corkyx` namespace instead, to avoid possible clashes with future *Corky* modules.
--
--  This module will load the @{corky.conky} and @{corky.cairo} modules. These modules will clean up the global
--  namespace (`_G`) by removing (almost) all `conky_*`, `cairo_*` and `CAIRO_*` variables and functions. Please
--  refer to the individual module's documentation for more details.
--
--  A *Cairo* surface and context will be initialized before any of the *Corky* draw hooks are executed, so modules
--  may use @{cairo|corky.cairo} to draw stuff without having to setup these by themselves. The surface and context
--  will be created before the draw hooks are run, and destroyed afterwards, during every *Conky* update cycle.
--
--  **_Corky_ Hooks:**
--
--  During the `startup_hook`, `draw_hook_pre`, `draw_hook_post` and `shutdown_hook` (the three Lua hooks provided
--  by *Conky*) the following @{corky.hooks|*Corky* hooks} will be executed (in the specified order):
--
--  During the `startup_hook`:
--
--  * `before_startup`
--  * `startup`
--  * `after_startup`
--
--  During the `draw_hook_pre`:
--
--  * `before_pre_draw`
--  * `pre_draw`
--  * `after_pre_draw`
--
--  During `draw_hook_post`:
--
--  * `before_post_draw`
--  * `post_draw`
--  * `after_post_draw`
--
--  During the `shutdown_hook`:
--
--  * `before_shutdown`
--  * `shutdown`
--  * `after_shutdown`
--
--  Modules may register functions for these hooks as required, see @{corky.hooks}.
--
--  **Note:** It appears that *Conky* calls the `draw_hook_pre` and `draw_hook_post` hooks multiple times before it
--  calls the `startup_hook`. For *Corky* hooks, however, it is guaranteed that draw hooks will not be executed
--  before the startup hooks have been run.
--
--  @MO corky
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @SE sort=false

-------------------------------------------------------------------------------------------------------------------

-- Include the parent directory of this script in the package search paths:
package.path = debug.getinfo (1, "S").source:match ("^@(.*[\\/])[^\\/]*$") .. "?.lua;" .. package.path

-------------------------------------------------------------------------------------------------------------------

-- Load these two modules as early as possible for the global namespace clean-up:

local conky = require "corky.conky"
local cairo = require "corky.cairo"

conky.global ("startup_hook", "shutdown_hook", "draw_hook_pre", "draw_hook_post")

-------------------------------------------------------------------------------------------------------------------

local cache   = require "corky.cache"
local config  = require "corky.config"
local hooks   = require "corky.hooks"
local include = require "corky.include"

-------------------------------------------------------------------------------------------------------------------

local startup = false

-------------------------------------------------------------------------------------------------------------------

--- *Conky* startup hook.
--
--  This function should be set as `lua_startup_hook` in the *Conky* configuration.
--
--  It will read the *Corky* @{corky.config|configuration}, and after that it will run the following
--  @{corky.hooks|hook functions} (in that order):
--
--  * `before_startup`
--  * `startup`
--  * `after_startup`
--
--  @c corky.config
--  @c corky.hooks

function conky_startup_hook ()

   config.read ()

   hooks.run ("before_startup")
   hooks.run ("startup")
   hooks.run ("after_startup")

   startup = true

end

--- *Conky* shutdown hook.
--
--  This function should be set as `lua_shutdown_hook` in the *Conky* configuration.
--
--  It will run the following @{corky.hooks|hook functions} (in that order):
--
--  * `before_shutdown`
--  * `shutdown`
--  * `after_shutdown`
--
--  @c corky.hooks

function conky_shutdown_hook ()

   hooks.run ("before_shutdown")
   hooks.run ("shutdown")
   hooks.run ("after_shutdown")

end

-------------------------------------------------------------------------------------------------------------------

--- *Conky* pre-draw hook.
--
--  This function should be set as `lua_draw_hook_pre` in the *Conky* configuration.
--
--  It will increment the @{corky.cache|cache}'s update counter first, then it will initialize *Cairo* by calling
--  @{cairo.init|corky.cairo.init()}. When this is done, the following @{corky.hooks|hook functions} will be run
--  (in that order):
--
--  * `before_pre_draw`
--  * `pre_draw`
--  * `after_pre_draw`
--
--  Note that this function will not be called before the @{conky_startup_hook|conky_startup_hook()} has been run.
--
--  @c corky.cache
--  @c corky.cairo
--  @c corky.hooks

function conky_draw_hook_pre ()

   local function hook ()

      cache.update ()
      cairo.init   ()

      hooks.run ("before_pre_draw")
      hooks.run ("pre_draw")
      hooks.run ("after_pre_draw")

   end

   if startup then
      conky_draw_hook_pre = hook
      conky_draw_hook_pre ()
   end

end

-------------------------------------------------------------------------------------------------------------------

--- *Conky* post-draw hook.
--
--  This function should be set as `lua_draw_hook_post` in the *Conky* configuration.
--
--  It will run the following @{corky.hooks|hook functions} (in that order):
--
--  * `before_post_draw`
--  * `post_draw`
--  * `after_post_draw`
--
--  After that, it will execute @{cairo.clean_up|corky.cairo.clean_up()}.
--
--  Note that this function will not be called before the @{conky_startup_hook|conky_startup_hook()} has been run.
--
--  @c corky.cairo
--  @c corky.hooks

function conky_draw_hook_post ()

   local function hook ()

      hooks.run ("before_post_draw")
      hooks.run ("post_draw")
      hooks.run ("after_post_draw")

      cairo.clean_up ()

   end

   if startup then
      conky_draw_hook_post = hook
      conky_draw_hook_post ()
   end

end

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: