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

--- Functions dealing with the configuration file.
--
--  This module provides a function to read the configuration file (usually *Conky*'s configuration file) and call
--  registered functions of other modules to process the configuration directives.
--
--  For *Corky*, all configuration directives may be included in *Conky*'s configuration file, though parsing other
--  files is supported.
--
--  A directive always starts with the characters `"#:"` (without quotes), which must be the first non-whitespace
--  characters on a line, and continues  until the end of the line (a directive may not span multiple lines). The
--  `"#:"` must then be followed by a keyword and zero or more parameters. Whitespace characters before (and after)
--  the keyword are allowed. Keyword and parameters have to be separated by commas, i.e. there must be a comma
--  between the keyword and the first parameter and before any subsequent parameters. A configuration directive
--  looks like this (brackets denote optional parameters):
--
--      #: <keyword>[, <parameter>[, <parameter> […]]]
--
--  If a parameter contains a comma, the parameter must be quoted using `"`. Quotes may be included inside a quoted
--  parameter string by escaping them with another quote (i.e. `"` becomes `""` inside a quoted string). Whitespace
--  at the beginning or end of a parameter will be removed, to preserve all whitespace, quotes may be used (any
--  whitespace around the quoted string will still be removed). Empty parameters are allowed.
--
--  All lines in the file that do not match the format described above will be ignored! See the individual modules
--  for a description of their configuration options.
--
--  **Note:** Configuration files are parsed as text files, so *Corky* is compatible with *Conky* configuration
--  files for versions before 1.10 (using the old configuration style), and with configuration files for version
--  1.10 and later. Starting with version 1.10 *Conky* uses a Lua file for its configuration. Since *Corky*'s
--  configuration is not valid Lua, it has to be included in a multi-line Lua comment (or more then one multiline
--  comment, *Corky* doesn't care, as long as the configuration matches the syntax described above). For example:
--
--    --[[
--
--       This is a Lua comment. Corky configuration follows:
--
--       #: some, config, options
--
--    --]]
--
--  @MO corky.config
--  @CO © 2015-2017 Stefan Göbel
--  @RE 2017033001
--  @LI [GPLv3](http://www.gnu.org/copyleft/gpl.html)
--  @AU Stefan Göbel [[⌂]](http://subtype.de/) [[✉]](mailto:corky@subtype.de)
--  @AL this

-------------------------------------------------------------------------------------------------------------------

--- Stores the configuration handlers for the keywords.
--
--  The keys are the keywords, the values are functions to be called when the keyword is found in the config file.
--  Configuration handlers are registered using the @{config.handler|handler()} function.
--
--  @l handlers

-------------------------------------------------------------------------------------------------------------------

local handlers = {}
local this     = {}

-------------------------------------------------------------------------------------------------------------------

--- Register a configuration handler.
--
--  A configuration handler is responsible for processing a (pre-processed) configuration directive. For all
--  directives found in the configuration file the assigned handler will be called. It will be called with one
--  parameter: a @{table} (array) containing the keyword and all parameters, in the order specified in the config
--  file. The handler must return either `true` if the configuration directive is valid, or `false` if there is
--  something wrong with it (if there is something wrong the directive should be ignored by the handler).
--
--  @s keyword The keyword in the configuration file that will trigger the handler.
--  @f func The function that will process the configuration directive.

this.handler = function (keyword, func)
   handlers [keyword] = func
end

-------------------------------------------------------------------------------------------------------------------

do

   local conky = require "corky.conky"
   local utils = require "corky.utils"

   --- Process the configuration file.
   --
   --  The specified configuration file will be parsed according to the rules mentioned above. Errors will cause
   --  warning messages to be printed to `STDERR`. The actual processing of the options is done by the registered
   --  handlers, see @{config.handler|handler()}. If no configuration file is specified, `conky_config` will be
   --  used.
   --
   --  @s[opt] file Path of the configuration file. Defaults to `conky_config` if not specified.

   this.read = function (file)

      if not file then
         file = conky.config
      end

      local conf = io.open (file, "r")
      if not conf then
         utils.warn ("Could not open the configuration file: %s", file)
         return
      end

      local lnum, line = 0

      for line in conf:lines () do

         lnum = lnum + 1

         local setting = line:match ("^%s*#:%s*(.+)")

         if setting then

            local arguments = setting:split_csv ()

            if arguments then
               if handlers [arguments [1]] then
                  if not handlers [arguments [1]] (arguments) then
                     utils.warn ("Error processing config option '%s' on line %i", arguments [1], lnum)
                  end
               else
                  utils.warn ("Unknown configuration option '%s' on line %i", arguments [1], lnum)
               end
            else
               utils.warn ("Invalid configuration option '%s' on line %i", setting, lnum)
            end

         end

      end

      conf:close ()

   end

end

-------------------------------------------------------------------------------------------------------------------

return this

--                                                     :indentSize=3:tabSize=3:noTabs=true:mode=lua:maxLineLen=115: