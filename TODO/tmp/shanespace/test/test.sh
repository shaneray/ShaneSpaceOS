#!/bin/bash

# enable_debugging
# elevate

ss_functions()
{
	echo $(declare -F | cut  -f 3 -d ' ')
}

ss_functions
