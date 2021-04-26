#!/bin/bash

#######################################
# Script Functions
#######################################
build()
{
	echo_info "Build Started"
	build_init
	
	SS_DISTRO_BUILD_COMMAND="build_debian"
	case "$SS_DISTRO" in
		"debian") :;;
		"raspbian") SS_DISTRO_BUILD_COMMAND="build_raspbian";;
		*)
			echo_warning "Unknown distrobution defined, or distrobution not set.  Defaulting to \"debian\" distrobution!"
			SS_DISTRO="debian"
		;;
	esac
	
	$SS_DISTRO_BUILD_COMMAND
	echo_success "Build Completed Successfully"
}

build_init()
{
	# configure and update apt
	echo_info "Starting APT configuration and update"
	local apt_cache_file="/etc/apt/apt.conf.d/01-ssos-apt-cache"
	[[ ! -f "$apt_cache_file" ]] && esudo file_write "$apt_cache_file" "Binary::apt::APT::Keep-Downloaded-Packages \"true\";"
	esudo apt update
	
	# install common dependencies
	echo_info "Installing common dependencies"
	esudo apt install -y git rsync
	
	# create directories
	echo_info "Creating directories"
	directory_create "$WORK_DIR"
	directory_create "$DEPLOY_DIR"
	directory_create "$SECURE_DIR"
	
	# cleaning directories
	echo_info "Cleaning directories"
	esudo directory_empty "$WORK_DIR"
	esudo directory_empty "$DEPLOY_DIR"
}

build_debian()
{
	# get dependencies
	esudo apt install -y live-build
	cd "${WORK_DIR}"

	# copy core variant files
	echo_info "Applying ShaneSpace Debian customizations"
	cp -r ../variants/debian/* ./

	if [[ -f "$CONFIG_DIR/wpa_supplicant.conf" ]]
	then
		mkdir -p "./config/includes.chroot/etc/wpa_supplicant"
		cp "$CONFIG_DIR/wpa_supplicant.conf" "./config/includes.chroot/etc/wpa_supplicant/wpa_supplicant.conf"
		echo_success "WPA supplicant file added added to image."
	else
		echo_warning "WPA supplicant file not found at \"$CONFIG_DIR/wpa_supplicant.conf\", wifi will not be auto configured."
	fi
	
	# run debian live-build script
	esudo lb build
	
	# copy image to deploy directory
	cp "${WORK_DIR}/live-image-amd64.hybrid.iso" "${DEPLOY_DIR}/${IMG_NAME}.iso" && echo_success "ShaneSpaceOS image copied to \"${RESET}${DEPLOY_DIR}/${IMG_NAME}.iso${COLOR_TEXT_SUCCESS}\"."
}

build_raspbian()
{
	# get dependencies
	esudo apt install -y coreutils quilt parted qemu-user-static debootstrap zerofree zip dosfstools bsdtar libcap2-bin grep xz-utils file curl bc xxd qemu-utils kpartx
	
	git clone https://github.com/RPi-Distro/pi-gen.git "${WORK_DIR}"
	cd "${WORK_DIR}"
	chmod +x "./build.sh"
	touch "./stage3/SKIP" "./stage4/SKIP" "./stage5/SKIP"
	touch "./stage4/SKIP_IMAGES" "./stage5/SKIP_IMAGES"
	
	# config
	local respbian_config="IMG_NAME=\"${IMG_NAME}\"${LF}DEPLOY_ZIP=0${LF}ENABLE_SSH=1"
	file_write "./config" "${respbian_config}"
	
	# run raspbian build script
	esudo "./build.sh"
}

config()
{
	echo_info "Configuration Started"
	config_default_values
	config_load
	config_command_line
	config_echo
	echo_success "Configuration Completed"
	echo_time
}

config_default_values()
{
	# default config values
	SS_DISTRO="debian"
	SS_DEBUG="false"
	SAVE_CONFIG="false"
	
	# If these are updated must modify .gitignore also
	WORK_DIR="./work"
	DEPLOY_DIR="./dist"
	SECURE_DIR="./private"
	CONFIG_NAME="SSOS_DEFAULT"
	CONFIG_DIR="${SECURE_DIR}/config/${CONFIG_NAME}"
	CONFIG_FILE="${CONFIG_DIR}/ssos_config"
	
	# Localization
	COUNTRY="us"
	LOCALE_DEFAULT="en_US.UTF-8"
	TIMEZONE_DEFAULT="America/New_York"
	KEYBOARD_KEYMAP="us"
	KEYBOARD_LAYOUT="us"
	
	# System Parameters
	RELEASE="buster"
	TARGET_HOSTNAME="SSOS"
	FIRST_USER_NAME="admin"
	FIRST_USER_PASS="admin"
	
	# Output Image Name
	IMG_NAME="ShaneSpaceOS"
}

config_command_line()
{
	SS_DISTRO="${SCRIPT_ARGS[distro]:-$SS_DISTRO}"
}

config_value_prompt()
{
	local -n config_var="$1"
	local prompt_message="$2"
	shift 2
	config_var="$(prompt "PROMPT" "$prompt_message" "$config_var" "${@}")"
}

config_prompt()
{
	SAVE_CONFIG="$(prompt_boolean "Save config for future use?")"
	if [[ "$SAVE_CONFIG" == "true" ]]
	then
		CONFIG_NAME="$(prompt "Config name?")"
		CONFIG_DIR="${SECURE_DIR}/config/$CONFIG_NAME"
		CONFIG_FILE="${CONFIG_DIR}/ssos_config"
	else
		CONFIG_NAME="SSOS_CUSTOM"
		CONFIG_FILE=""
	fi
	
	# shanespace build config values
	config_value_prompt SS_DISTRO "ShaneSpace OS Core Distrobution?" "debian" "raspbian"
	
	# If these are updated must modify .gitignore also
	config_value_prompt WORK_DIR "Work directory?"
	config_value_prompt DEPLOY_DIR "Deploy directory?"
	config_value_prompt SECURE_DIR "Secure directory?"
	
	# Localization
	config_value_prompt COUNTRY "Country Code (2 letter ISO 3166-1)?"
	config_value_prompt LOCALE_DEFAULT "Locale?"
	config_value_prompt TIMEZONE_DEFAULT "Timezone?"
	config_value_prompt KEYBOARD_KEYMAP "Keyboard Keymap?"
	config_value_prompt KEYBOARD_LAYOUT "Keyboard Layout?"
	
	# System Parameters
	config_value_prompt RELEASE "Debian Version?"
	config_value_prompt TARGET_HOSTNAME "Hostname?"
	config_value_prompt FIRST_USER_NAME "Username?"
	config_value_prompt FIRST_USER_PASS "Password?"
	config_value_prompt WIFI_SSID "WIFI SSID?"
	variable_not_empty WIFI_SSID && config_value_prompt WIFI_PSK "WIFI Passphrase?"
	variable_not_empty WIFI_PSK && config_wifi
	
	[[ ! -z "$WIFI_PSK" ]] && config_wifi
	
	# save configuration file if requested
	[[ "$SAVE_CONFIG" == "true" ]] && config_save "$CONFIG_NAME"
	return 0
}

config_wifi()
{
	! command_exists &&
	{
		echo_info "wpasupplicant missing, installing..."
		esudo apt install wpasupplicant -y
	}
	
	local psk="$(wpa_passphrase "$WIFI_SSID" "$WIFI_PSK" | grep -E "^\W(psk)")"
	WIFI_PSK="$(ltrim "$psk" "" "psk=")"
	
	# /etc/wpa_supplicant/wpa_supplicant.conf
	local config_values=""
	read -r -d '' config_values <<-EOF || true
		ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
		update_config=1
		country=$COUNTRY
		
		network={
			ssid="$WIFI_SSID"
			psk="$WIFI_PSK"
		}
	EOF
	
	file_write "$CONFIG_DIR/wpa_supplicant.conf" "$config_values"
}

config_save()
{
	local config_name="$1"
	local config_values=""
	read -r -d '' config_values <<-EOF || true
		# Build
		SS_DISTRO="$SS_DISTRO"
		
		# If these are updated must modify .gitignore also
		WORK_DIR="$WORK_DIR"
		DEPLOY_DIR="$DEPLOY_DIR"
		SECURE_DIR="$SECURE_DIR"
		
		# Localization
		LOCALE_DEFAULT="$LOCALE_DEFAULT"
		TIMEZONE_DEFAULT="$TIMEZONE_DEFAULT"
		KEYBOARD_KEYMAP="$KEYBOARD_KEYMAP"
		KEYBOARD_LAYOUT="$KEYBOARD_LAYOUT"
		
		# System Parameters
		RELEASE="$RELEASE"
		TARGET_HOSTNAME="$TARGET_HOSTNAME"
		FIRST_USER_NAME="$FIRST_USER_NAME"
		FIRST_USER_PASS="$FIRST_USER_PASS"
		
		# WIFI
		WIFI_SSID="$WIFI_SSID"
		WIFI_PSK="$WIFI_PSK"
	EOF
	
	CONFIG_NAME="${config_name}"
	CONFIG_DIR="$SECURE_DIR/config/${CONFIG_NAME}"
	CONFIG_FILE="${CONFIG_DIR}/ssos_config"
	file_write "$CONFIG_FILE" "$config_values"
}

config_load()
{
	[[ "${SCRIPT_ARGS[new_config]}" == "true" ]] && config_prompt
	
	CONFIG_NAME="${SCRIPT_ARGS[config]:-$CONFIG_NAME}"
	local config_files=( $(directory_list_basename "$SECURE_DIR/config") )
	variable_not_empty CONFIG_NAME && [[ "${CONFIG_NAME}" != "SSOS_DEFAULT" && "${CONFIG_NAME}" != "SSOS_CUSTOM" ]] &&
	{
		CONFIG_DIR="${SECURE_DIR}/config/$CONFIG_NAME"
		CONFIG_FILE="${CONFIG_DIR}/ssos_config"
		[[ ! -f "$CONFIG_FILE" ]] && throw "An error occurred trying to load configuration file \"$CONFIG_FILE\"."
		config_files=( "$CONFIG_NAME" )
	}
	
	if [[ "$CONFIG_NAME" == "SSOS_CUSTOM" ]]
	then
		:
	elif [[ "${#config_files[@]}" -gt 1 ]]
	then
		echo_warning "${#config_files[@]} configuration files found."
		for i in "${!config_files[@]}"; do
			echo_time "${COLOR_TEXT_PROMPT}[${RESET}PROMPT OPTION${COLOR_TEXT_PROMPT}] [${RESET}${i}${COLOR_TEXT_PROMPT}]:${RESET} ${config_files[$i]}"
		done
		
		# add array items and index to list for acceptable options
		local config_file_options=()
		config_file_options+=( "${!config_files[@]}" )
		config_file_options+=( "${config_files[@]}" )
		
		# ask user which config
		CONFIG_NAME="$(prompt "PROMPT" "Which config file do you want to use?" "$config_files" "${config_file_options[@]}")"
		
		# check if user referenced index rather than name
		if array_contains config_files "$CONFIG_NAME"
		then
			CONFIG_DIR="${SECURE_DIR}/config/$CONFIG_NAME"
		else
			CONFIG_NAME="${config_files[${CONFIG_NAME}]}"
			CONFIG_DIR="${SECURE_DIR}/config/$CONFIG_NAME"
		fi
	elif [[ "${#config_files[@]}" -eq 1 ]]
	then
		CONFIG_NAME="${config_files}"
		CONFIG_DIR="${SECURE_DIR}/config/$CONFIG_NAME"
		echo_info "1 config file found \"${CONFIG_FILE}\"."
	else
		echo_warning "Configuration file not found, would you like to use defaults?  If you choose not to use default values you will be prompted for configuration values."
		USE_DEFAULT_CONFIG="$(prompt_boolean "Use Default Config?")"
		if [[ "$USE_DEFAULT_CONFIG" == "true" ]]
		then
			echo_info "Using default configuration values"
		else
			config_prompt
		fi
	fi
	
	# read config
	[[ "${CONFIG_NAME}" != "SSOS_DEFAULT" && "${CONFIG_NAME}" != "SSOS_CUSTOM" ]] &&
	{
		CONFIG_FILE="${CONFIG_DIR}/ssos_config"
		[[ ! -f "$CONFIG_FILE" ]] && throw "An error occurred trying to load configuration file \"$(realpath $CONFIG_FILE)\"."
		source "$CONFIG_FILE"
		echo_success "Configuration file for \"$CONFIG_NAME\" loaded from \"${RESET}$(realpath $CONFIG_FILE)${COLOR_TEXT_SUCCESS}\"."
	}
	
	[[ "${CONFIG_NAME}" == "SSOS_DEFAULT" ]] &&
	{
		config_value_prompt WIFI_SSID "WIFI SSID?"
		variable_not_empty WIFI_SSID && config_value_prompt WIFI_PSK "WIFI Passphrase?"
		variable_not_empty WIFI_PSK && config_wifi
		
		CONFIG_FILE=""
	}
	
	IMG_NAME+="-${CONFIG_NAME//SSOS_/}"
	
	variable_not_empty WORK_DIR && WORK_DIR="$(realpath "${WORK_DIR}")"
	variable_not_empty DEPLOY_DIR && DEPLOY_DIR="$(realpath "${DEPLOY_DIR}")"
	variable_not_empty SECURE_DIR && SECURE_DIR="$(realpath "${SECURE_DIR}")"
	variable_not_empty CONFIG_DIR && CONFIG_DIR="$(realpath "${CONFIG_DIR}")"
	
	return 0
}

config_echo()
{
	echo_header "ShaneSpace OS Build Config"
	echo_var "SS_DISTRO"
	echo_var "SS_DEBUG"
	echo_var "CONFIG_NAME"
	echo_var "CONFIG_FILE" realpath
	echo_var "WORK_DIR" realpath
	echo_var "DEPLOY_DIR" realpath
	echo_var "SECURE_DIR" realpath
	
	echo_header "Localization Config"
	echo_var "LOCALE_DEFAULT"
	echo_var "TIMEZONE_DEFAULT"
	echo_var "LOCALE_DEFAULT"
	echo_var "KEYBOARD_KEYMAP"
	echo_var "KEYBOARD_LAYOUT"
	
	echo_header "System Config"
	echo_var "RELEASE"
	echo_var "TARGET_HOSTNAME"
	echo_var "FIRST_USER_NAME"
	echo_var "FIRST_USER_NAME"
	echo_var "WIFI_SSID"
	echo_var "WIFI_PSK"
}

config_colors()
{
	RED="$(tput setaf 1)"
	GREEN="$(tput setaf 2)"
	YELLOW="$(tput setaf 3)"
	BLUE="$(tput setaf 4)"
	LIGHTBLUE="$(tput setaf 12)"
	RESET="$(tput sgr0)" # no color
	
	COLOR_TEXT_SUCCESS="${GREEN}"
	COLOR_TEXT_INFO="${BLUE}"
	COLOR_TEXT_WARNING="${YELLOW}"
	COLOR_TEXT_ERROR="${RED}"
	COLOR_TEXT_PROMPT="${LIGHTBLUE}"
}

#######################################
# General Functions
#######################################

echo_color()
{
	local message="$1"
	local color="$2"
	echo_time "${color}${message}${RESET}"
}

echo_line_prefix()
{
	local prefix="$1"
	shift
	
	echo "$@" | while IFS="" read -r line
	do
		echo "${prefix} ${line}${RESET}"
	done
}

echo_time()
{
	echo "[$(time_now)] $@"
}

echo_var()
{
	[[ -z "$1" ]] &&
	{
		echo_error "echo_var: must provide a variable_name to echo."
		return 1
	}
	
	local -n variable="$1"
	local type="$(variable_type "${!variable}")"
	local output=""
	case "$type" in
		*"array")
			[[ "${#variable[@]}" -eq 0 ]] && echo_time "${BLUE}${!variable}[]${RESET}: '(Empty Array)'"
			for i in ${!variable[@]}
			do
				local value="${variable[$i]}"
				[[ ! -z "$2" ]] && value="$($2 "${value}")"
				echo_time "${BLUE}${!variable}[${RESET}$i${BLUE}]${RESET}: ${variable[$i]@Q}"
			done
		;;
		*)
			local value="${variable}"
			variable_not_empty variable && [[ ! -z "$2" ]] && value="$($2 "${value[@]}")"
			echo_time "${BLUE}${!variable}${RESET}: ${value[@]@Q}"
		;;
	esac
}

echo_header()
{
	[[ -z "$1" ]] &&
	{
		echo_error "echo_header: must provide a header name to echo."
		return 1;
	}
	
	local header="$1"
	echo_time ""
	echo_time "${BLUE}[${RESET}${header}${BLUE}]${RESET}"
	echo_time "${BLUE}---------------------------------------${RESET}"
}

echo_error()
{
	echo_line_prefix "$(echo_time ${RED}[${RESET}ERROR${RED}])" "${@}${RESET}" >&2
}

echo_warning()
{
	echo_line_prefix "$(echo_time ${YELLOW}[${RESET}WARNING${YELLOW}])" "${@}${RESET}" >&2
}

echo_success()
{
	echo_line_prefix "$(echo_time ${GREEN}[${RESET}SUCCESS${GREEN}])" "${@}${RESET}"
}

echo_info()
{
	echo_line_prefix "$(echo_time ${BLUE}[${RESET}INFO${BLUE}])" "${@}${RESET}"
}

time_now()
{
	date '+%H:%M:%S'
}

prompt()
{
	local prompt_message="$1"
	local prompt_type="PROMPT"
	case "$prompt_message" in
		"PROMPT"|"INFO"|"WARNING"|"ERROR")
			prompt_type="$prompt_message"
			shift
			prompt_message="$1"
		;;
	esac
	local color="${RESET}"
	local final_message="${prompt_message}"
	[[ ! -z "$prompt_type" ]] &&
	{
		local -n color="COLOR_TEXT_${prompt_type}"
		final_message="${color}[${RESET}$prompt_type${color}]${RESET} ${color}${prompt_message}"
	}
	local default_value="$2"
	shift;
	[[ ! -z "$default_value" ]] && shift;
	local default_value_string=" [${RESET}$default_value${color}]"
	local acceptable_values=( "${@}" )
	local acceptable_values_string="$(string_join "/" "acceptable_values")"
	local output_variable
	
	# verify default value is acceptable, if not remove it
	arrray_is_empty "${acceptable_values[@]}" || { ! array_contains "acceptable_values" "$default_value" && default_value=""; }
	
	# get input from stdin
	[[ -z "$default_value" ]] && default_value_string=""
	local final_message="$(echo_color "${final_message}${default_value_string}" "$color")"
	
	read -p "$final_message " output_variable
	[[ -z "$output_variable" && ! -z "$default_value" ]] && output_variable="$default_value"
	
	# if acceptable values are set, ensure the provided value is acceptable
	arrray_is_empty "${acceptable_values[@]}" ||
	{
		! array_contains "acceptable_values" "$default_value" && default_value=""
		
		while ! array_contains "acceptable_values" "$output_variable"
		do
			echo_error "Invalid input.  Please choose from one of the following values: ${RESET}$acceptable_values_string"
			output_variable="$(prompt "$prompt_type" "$prompt_message" "$default_value" "$@")"
		done
	}
	
	echo "$output_variable"
}

prompt_boolean()
{
	local output_variable
	local prompt_message="$1"
	local prompt_type="PROMPT"
	case "$prompt_message" in
		"PROMPT"|"INFO"|"WARNING"|"ERROR")
			prompt_type="$prompt_message"
			shift
			prompt_message="$1"
		;;
	esac
	
	local default_value="${2:-No}"
	local true_values=( "yes" "true" "y" "t" "1")
	local false_values=( "no" "false" "f" "n" "0" )
	local acceptable_values=()
	acceptable_values+=( "${true_values[@]}" )
	acceptable_values+=( "${false_values[@]}" )
	
	output_variable="$(prompt "$prompt_type" "$prompt_message" "$default_value" "${acceptable_values[@]}")"
	
	array_contains "true_values" "$output_variable" && output_variable="true"
	array_contains "false_values" "$output_variable" && output_variable="false"
	
	echo "$output_variable"
}

arrray_is_empty()
{
	local array_values="${*}"
	[[ -z "${array_values// /}" ]] && return 0
	return 1
}

array_contains()
{
	local -n array="$1"
	local searchTerm="$2"
	for array_item in ${array[@]}
		do [[ "${array_item,,}}" == "${searchTerm,,}}" ]] && return 0
	done
	return 1
}

string_join()
{
	local delimeter="$1"
	local -n array="${2}"
	local output="$array"
	[[ "${#array[@]}" -gt 1 ]] &&
	{
		output+="$(printf "${delimeter}%s" "${array[@]:1}")"
	}
	echo "$output"
}

string_startswith()
{
	case "$1" in
		"$2"*) true;;
		*) false;;
	esac
}

string_contains()
{
	case "$1" in
		*"$2"*) true;;
		*) false;;
	esac
}

string_endswith()
{
	case "$1" in
		*"$2") true;;
		*) false;;
	esac
}

string_indent()
{
	local count="${1:-1}"
	echo $2 | sed -e "s/^/$(string_repeat "${TAB}" $count)/"
}

string_indent_block()
{
	local count="${1:-1}"
	echo_line_prefix "$(string_repeat "${TAB}" $count)" "$2"
}

string_repeat()
{
	input="$1"
	template="$(printf "%${2}s")"
	echo "${template//?/$input}"
}

trim()
{
	local string="$1"
	shift
	local trim_strings=( "$@" )
		
	string="$(rtrim "$string" "${trim_strings[@]}")"
	string="$(ltrim "$string" "${trim_strings[@]}")"
	echo "$string"
}

rtrim()
{
	local string="$1"
	shift
	local trim_strings=( "$@" )
	[[ -z "${trim_strings[@]}" ]] && trim_strings=( " " $'\t' )
	
	# todo: while loop
	for trim_string in "${trim_strings[@]}"
	do
		if [[ -z "$trim_string" ]]
		then
			string="$(rtrim "$string")"
		else
			while string_endswith "$string" "$trim_string"
			do
				string="${string%$trim_string}"
			done
		fi
	done
	
	echo "$string"
}

ltrim()
{
	local string="$1"
	shift
	local trim_strings=( "$@" )
	[[ -z "${trim_strings[@]}" ]] && trim_strings=( " " $'\t' )
	
	# todo: while loop
	for trim_string in "${trim_strings[@]}"
	do
		if [[ -z "$trim_string" ]]
		then
			string="$(ltrim "$string")"
		else
			while string_startswith "$string" "$trim_string"
			do
				string="${string#$trim_string}"
			done
		fi
	done
	
	echo "$string"
}

throw()
{
	local exception_message="$1"
	[[ -z "$exception_message" ]] && exception_message="An unknown exception has occurred."
	[[ "$exception_message" == "not_implemented_excepion" ]] &&
	{
		exception_message="Method or operation not implemented."
		shift
	}
	local additional_details="$2"	
	local stack_index="${3:-1}"
	EXCEPTION_SRC="${BASH_SOURCE[${stack_index}]}"
	EXCEPTION_FUNCNAME="${FUNCNAME[${stack_index}]}"
	EXCEPTION_FUNCNAME_PARENT="${EXCEPTION_FUNCNAME}"
	EXCEPTION_LINENO="${BASH_LINENO[((${stack_index}-1))]}"
	echo_error "Exception thrown from script ${RESET}${EXCEPTION_SRC}${RED} method ${RESET}${EXCEPTION_FUNCNAME}()${RED} at line ${RESET}${EXCEPTION_LINENO}${RED}."
	echo_error "Exception Message: ${RESET}$exception_message"
	variable_not_empty additional_details &&
	{
		if variable_contains additional_details "${LF}"
		then
			echo_error "Additional Details: ${RESET}${additional_details}"
		else
			echo_error "Additional Details:"
			echo_error "$(echo_line_prefix "${RESET}${TAB}" "${additional_details}")"
		fi
	}
	echo_error
	EXCEPTION_FUNCNAME="throw"
	stacktrace 2
	return 1
}

trap_handler()
{
	local trap_type="$1"
	local last_exit_code="$2"
	local line_no="${EXCEPTION_LINENO:-$3}"
	local function_name="$4"
	local command_line="$5"
	
	local source="$BASH_SOURCE"
	local command_parent="${FUNCNAME[1]}()${RED} -> ${RESET}"
	local command="${EXCEPTION_FUNCNAME:-${command_line%% *}}"
	local command_args="${command_line#* }"
	local previous_funcname="${FUNCNAME[1]}"
	local stack_size="${#DEBUG_STACK[@]}"
	local command_key
	
	_trap_build()
	{
		local trap="$1"
		local trap_prefix_additional="$2"
		local trap_params='"${EXITCODE}" "${LINENO}" "${FUNCNAME}" "${BASH_COMMAND}"'
		local trap_prefix='EXITCODE=$?;'
		local trap_handler='trap_handler'
		local trap_cmd="trap '${trap_prefix} ${trap_prefix_additional} ${trap_handler} ${trap} ${trap_params};' ${trap};"
		eval "$trap_cmd"
	}
	#echo "${BLUE} ${trap_type} // ${last_exit_code} // ${function_name} // ${*} ${RESET}"> /dev/tty
	case "$trap_type" in
		"ENABLE")
			DEBUG_STACK=()
			_trap_build "INT"
			_trap_build "TERM"
			_trap_build "EXIT"
			_trap_build "ERR"
			# this breaks error handling
			#_trap_build "DEBUG" '[[ "${FUNCNAME[@]}" != *" trap_handler "* && "${FUNCNAME}" != "trap_handler" && "${BASH_COMMAND}" != "trap_handler "* ]] && '
			#_trap_build "RETURN"
		;;
		"EXIT")
			if [[ "${last_exit_code}" = 0 ]] 
			then
				echo_success "[${RESET}EXIT${GREEN}]: Script Executed Successfully!${RESET}"
			else
				# default exit message
				local exit_message="Script Failed! (Exit Code: ${RESET}${2}${RED})"
				
				# override exit_message
				[[ ! -z "$SIGNAL_MESSAGE" ]] && exit_message="${SIGNAL_MESSAGE//%exit_code%/${2}}"
				[[ ! -z "$FATAL_MESSAGE" ]] && exit_message="$FATAL_MESSAGE"
				
				echo_error "[${RESET}EXIT${RED}]: $exit_message"
			fi
			exit "${last_exit_code}"
		;;
		"ERR")
			#echo "${RED} ${trap_type} // ${last_exit_code} // ${function_name} // ${command_line} // $*" > /dev/tty
			[[ "${last_exit_code}" != 0 ]] &&
			{
				[[ -z "$SIGNAL_MESSAGE" ]] &&
				{
					FATAL_MESSAGE="Script Failed due to a fatal error! (File: ${RESET}${source}${RED}, Method: ${RESET}${command_parent}${command_line}${RED}, Line: ${RESET}${line_no}${RED}, Exit Code: ${RESET}${last_exit_code}${RED})"
				}
				#exit "${last_exit_code}"
			}
		;;
		"DEBUG")
			#local func_stack=("${FUNCNAME[@]:1}")
			#[[ "${func_stack[*]}" == *" ${FUNCNAME} "* || "$function_name" == "$FUNCNAME" || "$command" == "$FUNCNAME" ]] && return 0;
			
			#echo "${trap_type} // ${last_exit_code}:${last_exit_code} // ${command_line} // ${*} "> /dev/tty
			#[[ "${previous_funcname}" != "${command}" ]] && return 0;
			#[[ "${#DEBUG_STACK[@]}" -gt 0 && "${func_stack[*]}" == "${DEBUG_STACK[-1]}" ]] && return 0;
			#[[ "$command_args" == "$command" ]] && command_args=""
			
			
			#command_key="$command ($command_args)"
			#DEBUG_STACK+=("${func_stack[*]}")
			#[[ "${#DEBUG_STACK[@]}" -gt 0 ]] && echo_time "${DEBUG_STACK[-1]}" > /dev/tty
			#return "${last_exit_code}"
			# [[ ! -z "$function_name" && ! -z ${BLOCK_FUNCTION_HANDLERS[$function_name]} ]] &&
			# {
			# 	echo "${BLUE} ${trap_type} // ${last_exit_code} // ${function_name} // ${*} ${RESET}"> /dev/tty
			# 	for v in ${!BLOCK_FUNCTION_HANDLERS[@]}
			# 	do
			# 		${BLOCK_FUNCTION_HANDLERS[$v]} "${command_line}"
			# 	done
			# }
			#return ${last_exit_code}	
		;;
		"RETURN")
			#local func_stack=("${FUNCNAME[@]:1}")
			#[[ "${func_stack[*]}" == *" ${FUNCNAME} "* || "$function_name" == "$FUNCNAME" || "$command" == "$FUNCNAME" ]] && return 0;
			#unset DEBUG_STACK[-1]
			#[[ "${#DEBUG_STACK[@]}" -gt 0 ]] && echo_time "${DEBUG_STACK[-1]}" > /dev/tty
			#echo "$function_name" > /dev/tty
			
			#local funcation_name_reversed="$(reverse "$function_name")"
			#[[ ! -z ${BLOCK_FUNCTION_HANDLERS[$funcation_name_reversed]} ]] &&
			#{
			#	echo "block close" > /dev/tty
			#	echo "${BLUE} ${trap_type} // ${last_exit_code} // ${function_name} // ${*} ${RESET}"> /dev/tty
			#}
		;;
		*)
			local x="$(cursor_position_x)"
			[[ "$x" -gt 1 ]] && echo ""
			SIGNAL_MESSAGE="Signal Received! (Signal: ${RESET}${1}${RED}, Exit Code: ${RESET}%exit_code%${RED})"
		;;
	esac
	#echo "${BLUE} ${trap_type} // ${last_exit_code}:${LAST_EXIT_CODE} // ${LAST_COMMAND} // ${*} ${RESET}"> /dev/tty
	return 0
}

stacktrace()
{	
	local stack_size="${#FUNCNAME[@]}"
	local funcname lineno src skip_count output stack i seperator
	# to avoid noise we skip $skipCount
	skip_count="((${1:-1}+1))"
	[[ ! -z "$EXCEPTION_FUNCNAME" ]] && stack+="\t ${RED}[${RESET}${EXCEPTION_SRC##*/}:${EXCEPTION_LINENO}${RED}] ${RESET}${EXCEPTION_FUNCNAME_PARENT}()${RESET}${RED}->${RESET}${EXCEPTION_FUNCNAME}()${RESET}\n"
	for (( i=$skip_count; i<$stack_size; i++ )); do
		lineno="${BASH_LINENO[$(( i - 1 ))]}"
		
		local srctest="${FUNCNAME[$i]}()"
		[[ "$srctest" == "source()" ]] && srctest="${BASH_SOURCE[$i]##*/}"
		[[ "$srctest" == "main()" && "${#BASH_SOURCE[@]}" == "$stack_size" ]] && srctest="${BASH_SOURCE[$i]##*/}"
		[[ "$srctest" == "()" ]] && srctest="" && seperator=""
		[[ "$srctest" != "" ]] && seperator="->"
		
		funcname="${FUNCNAME[$i-1]}()"
		[[ "$funcname" == "source()" ]] && funcname="${BASH_SOURCE[$i]##*/}"
		[[ "$funcname" == "main()" && "${#BASH_SOURCE[@]}" == "$stack_size" ]] && funcname="${BASH_SOURCE[$i]##*/}"

		src="${BASH_SOURCE[$i]##*/}"
		[[ -z "$src" ]] && src="non_file_source"
				
		stack+="\t ${RED}[${RESET}$src:$lineno${RED}] ${RESET}$srctest${RESET}${RED}${seperator}${RESET}$funcname${RESET}\n"
	done
	output="$(echo -e "$stack" | column -t | sed 's/.*/\t&/')"
	
	echo_error "Stacktrace:"
	echo_error "${output//->/ -> }"
}
	
file_write()
{
	local file="$1"
	shift
	local data=( "$@" )
	
	[[ -d "$file" ]] &&
	{
		throw "$(realpath $file) is a directory"
	}
	
	[[ -e "$file" ]] &&
	{
		local full_filename="$(realpath $file)"
		local continue="false"
		continue="$(prompt_boolean "WARNING" "File \"${RESET}$full_filename${COLOR_TEXT_WARNING}\" already exists, would you like to overwrite?")"
		[[ "$continue" != "true" ]] && return 1
	}

	mkdir -p "$(dirname $file)"
	echo "${data[@]}" > "$file" || throw "An error occurred while trying to write file \"$(realpath $file)\"."
}

file_append()
{
	local file="$1"
	shift
	local data="$@"
	
	echo "$data" >> "$file"
}

directory_create()
{
	local directory_to_create="$1"
	[[ -z "$directory_to_create" ]] && throw "Must provide a directory to create."
	
	[[ -d "$directory_to_create" ]] &&
	{
		echo_info "Directory already exists: ${RESET}$(realpath "$directory_to_create")"
		return 0
	}
	
	mkdir -p "$directory_to_create" && echo_success "Created directory: ${RESET}$(realpath $directory_to_create)"
}

directory_empty()
{
	local directory_to_empty="$1"
	[[ -z "$directory_to_empty" ]] && throw "Must provide a directory to empty."
	
	[[ ! -d "$directory_to_empty" ]] &&
	{
		echo_error "Directory does not exists: ${RESET}$(realpath "$directory_to_empty")"
		return 1
	}
	
	rm -rf "${directory_to_empty}/"{,.[!.],..?}*
	echo_success "Directory emptied: ${RESET}$(realpath $directory_to_empty)"
}

directory_list()
{
	local directory_name="$1"
	[[ ! -e "$directory_name" ]] && { echo ""; return 0; }  
	local directory_full_name="$(realpath "$directory_name")"
	[[ -L "$directory_full_name" && -f "$directory_full_name" ]] && throw "$directory_full_name is a  symbolic link to a file, not a directory"
	[[ -f "$directory_full_name" ]] && throw "$directory_full_name is a file, not a directory"
	local file_list=("$directory_full_name"/*)
	array_contains "file_list" "$directory_full_name/*" && { echo ""; return 0; }
	echo "${file_list[@]}"
}

directory_list_basename()
{
	local directory_name="$1"
	local fullname_file_list=( $(directory_list "$directory_name") )
	local file_list=()
	for fullname_file in ${fullname_file_list[@]}
	do
		file_list+=( "${fullname_file##*/}" )
	done
	
	echo "${file_list[@]}"
}

cursor_position_x()
{
	# https://github.com/dylanaraps/pure-bash-bible#get-the-current-cursor-position
	IFS='[;' read -p $'\e[6n' -d R -rs _ y x _
    echo "$x"
}

cursor_position_y()
{
	# https://github.com/dylanaraps/pure-bash-bible#get-the-current-cursor-position
	IFS='[;' read -p $'\e[6n' -d R -rs _ y x _
    echo "$y"
}

command_exists()
{
	command -v wpa_passphrase &> /dev/null
}

esudo()
{
	command="$1"
	shift
	args=( "$@" )
	if [ "$(type -t $command)" == "function" ]
	then
		local sudo_cmd="$command ${args[@]@Q}"
		
		local error_trap="$(trap | grep ERR$)"
		local sudo_script="set -${-}; $(declare -p | grep -v 'declare .*r ')${LF}$(declare -f)${LF}"
		sudo_script+="echo_warning \"The following command is being ran with elevated permission!!!${LF}Command: ${RESET}${sudo_cmd}\"${LF}"
		sudo_script+="echo_warning \"Current Working Directory: ${RESET}${PWD@Q}\"${LF}"
		sudo_script+="${sudo_cmd}${LF}"
		sudo_script+="echo_success \"Command has completed running with elevated permissions: ${RESET}${sudo_cmd}\""

		EXCEPTION_FUNCNAME="${sudo_cmd}"
		EXCEPTION_LINENO="${BASH_LINENO}"
		sudo -E bash -c "${sudo_script}"
	else
		sudo -E $command ${@}
	fi
}

params_declare()
{
	# define arguments manually
	declare -A FUNC_params_declare_PARAMS=(
		[1]="name"
		[2]="required"
		[3]="short"
		[4]="long"
		[5]="type"
		[6]="explanation"
		[7]="default"
		[8]="dependancies"
		[0]="validation"
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_name=(
		[short]="n" [required]=true
		[explanation]="Name of the argument. Will be used to set the variable name and long option if not set."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_required=(
		[short]="r" [type]="bool"
		[explanation]="Indicates if the argument is required or not."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_short=(
		[short]="s" [type]="char" [required]="true"
		[explanation]="The short name to use when calling script/function (prefixed with single dash, example: -s)."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_long=(
		[short]="l" [default]="FUNC_params_declare_PARAMS[name]"
		[explanation]="The long name to use when calling script/function (prefixed with two dashes, example: --long). If not set the arg_name will also be used as a default."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_type=(
		[short]="t" [default]="string"
		[explanation]="The type of the argument. Valid types: bool, string, char, int."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_explanation=(
		[short]="e" [default]="Description not available."
		[explanation]="A description of the argument to be displayed on the help screen."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_default=(
		[short]="z"
		[explanation]="The default value of the argument if not supplied."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_dependancies=(
		[short]="d"
		[explanation]="A list of parameters that this parameter depends on."
	)
	declare -A FUNC_params_declare_PARAMS_OPTION_validation=(
		[short]="v"
		[explanation]="Regex pattern to be used when performing validation on the argument value."
	)
	
	# process arguments
	declare -A args
	args_process args "$@"
	
	# build args variable
	local args_var_name="FUNC_${FUNCNAME[1]}_PARAMS"
	[[ "${#FUNCNAME[@]}" -eq 2 && "${FUNCNAME[1]}" == "main" ]] && args_var_name="SCRIPT_PARAMS"
	local -n args_var="$args_var_name"
	[[ "${#args_var[@]}" -eq 0 ]] && declare -Ag "$args_var_name"

	# set args variable value
	local args_var_index="${#args_var[@]}"
	local arg_name="${args[name]}"
	arg_name="${arg_name//-/_}"
	arg_name="${arg_name// /_}"
	
	args_var[$((++args_var_index))]="${arg_name}"

	# create options variable
	local arg_opt_name="${args_var_name}_OPTION_${arg_name}"
			
	local -n args_option_var="${arg_opt_name}"
	declare -Ag "${arg_opt_name}"
	
	# set options variable value
	args_option_var["name"]="${arg_name}"
	args_option_var["required"]="${args[required]}"
	args_option_var["short"]="${args[short]}"
	args_option_var["long"]="${args[long]}"
	args_option_var["type"]="${args[type]}"
	args_option_var["explanation"]="${args[explanation]}"
	args_option_var["default"]="${args[default]}"
	args_option_var["validation"]="${args[validation]}"
	
	return 0
}

args_process()
{
	########################################
	# args_process nested functions
	########################################
	parse_error_add()
	{
		[[ -z "$1" ]] && return 0
		[[ "${parse_error}" == "false" ]] && parse_error="${1}" || parse_error+="${LF}${1}"
		local arg_string="${LF}${LF}${#arguments[@]} Arguments passed to ${arg_configs_type}: ${arguments[@]@Q}"
		parse_error="${parse_error//$arg_string/}${arg_string}"
	}
	
	########################################
	# init
	########################################
	local arg_configs_type="function"
	local func_name="${FUNCNAME[1]}"
	local arg_configs_name="FUNC_${func_name}_PARAMS"
	[[ "${#FUNCNAME[@]}" -eq 2 && "${func_name}" == "main" ]] &&
	{
		arg_configs_name="SCRIPT_PARAMS"
		func_name="$(realpath "${BASH_SOURCE}")"
		arg_configs_type="script"
	}
	local parse_error_message="An error occurred trying to parse arguments for $arg_configs_type \"$func_name\""
	local parse_error="false"
	
	########################################
	# input validation
	########################################
	local -n args_process_output_var="$1" 2> /dev/null || parse_error="\"$1\" does not appear to be a valid argument output variable."
	local args_process_output_var_type="$(variable_type ${!args_process_output_var})"
	[[ "${args_process_output_var_type}" != "associative array" ]] && parse_error="Argument output variable \"${!args_process_output_var}\" has invalid type of \"$args_process_output_var_type\", expected type is \"associative array\""
	[[ "${parse_error}" != "false" ]] && throw "${parse_error_message}" "${parse_error}"
	shift
	
	local -n arg_configs="$arg_configs_name" 2> /dev/null || parse_error="Argument configuration variable required, \"${arg_configs_name}\" does not appear to be a valid argument configuration variable."
	local arg_configs_var_type="$(variable_type ${!arg_configs})"
	[[ "${arg_configs_var_type}" != "associative array" ]] && parse_error="Argument configuration variable \"${arg_configs_name}\" has invalid type of \"$arg_configs_var_type\", expected type is \"associative array\""
	[[ "${parse_error}" != "false" ]] && throw "${parse_error_message}" "${parse_error}"
	
	local arguments=( "${@}" )
	########################################
	# build arg options
	########################################
	declare -A arg_options_name
	declare -A arg_options_type
	declare -A arg_options_long
	declare -A arg_options_short
	declare -A arg_options_default
	declare -A arg_options_validation
	declare -A arg_options_long_map
	local arg_options_required=()
	
	# add defaults
	local default_option_name="help"
	arg_configs[$(("${#arg_configs[@]}"+1))]="$default_option_name"
	local default_option_prefix="SCRIPT"
	[[ "$arg_configs_type" == "function" ]] && default_option_prefix="FUNC"
	local default_option_var_name="${arg_configs_name}_OPTION_${default_option_name}"
	local -n default_option_var="$default_option_var_name"
	[[ "${#default_option_var[@]}" -eq 0 ]] && declare -Ag "$default_option_var_name"	
	default_option_var=(
		[short]="h" [type]=bool
		[explanation]="Access help information."
	)	
	local arg_opt_string=":"
	for arg_name in ${arg_configs[@]}
	do
		local arg_config_name="${arg_configs_name}_OPTION_${arg_name}"
		
		# arg configuration validation
		local -n arg_config_options="${arg_config_name}" 2> /dev/null ||
		{
			throw "$parse_error_message" "Missing param configuration options: \"${arg_config_name}\""
		}
		[[ -z "${arg_config_options[*]}" ]] &&
		{
			throw "$parse_error_message" "Missing param configuration options: \"${arg_config_name}\""
		}
		
		local arg_config_options_type="$(variable_type "${arg_config_name}")"
		[[ "$arg_config_options_type" != "associative array" ]] &&
		{
			throw "$parse_error_message" "Param configuration options \"$arg_config_name\" has invalid type of \"$arg_config_options_type\", expected type is \"associative array\""
		}
		
		# populate arg options arrays
		local arg_short_key="${arg_config_options[short]}"
		local arg_long_key="${arg_config_options[long]}"
		local arg_required="${arg_config_options[required]}"
		local arg_type="${arg_config_options[type]}"
		local arg_default_value="${arg_config_options[default]}"
		local arg_validation="${arg_config_options[validation]}"
				
		[[ -z "$arg_long_key" ]] && arg_long_key="${arg_name}"
		arg_long_key="${arg_long_key//_/-}"
		arg_long_key="${arg_long_key// /-}"
		
		[[ "$arg_required" == "true" ]] &&
		{
			arg_options_required+=("$arg_short_key")
			# if an argument is required default value should not be set
			[[ ! -z "$arg_default_value" ]] &&
			{
				arg_default_value=""
				echo_warning "Default value ignored for \"${arg_name}\" since it is a required argument."
			}
		}
		
		arg_options_short[$arg_name]="${arg_short_key}"
		arg_options_name[$arg_short_key]="${arg_name}"
		arg_options_type[$arg_short_key]="${arg_type:-string}"
		arg_options_long[$arg_short_key]="${arg_long_key}"
		arg_options_default[$arg_short_key]="${arg_default_value}"
		arg_options_validation[$arg_short_key]="${arg_validation}"
		arg_options_long_map["--${arg_long_key}"]="-${arg_short_key}"
		
		# build arg_opt_string
		arg_opt_string+="$arg_short_key"
		[[ "${arg_type}" != "bool" ]] && arg_opt_string+=":"
		
		# build args object with default values to be populated later
		args_process_output_var["${arg_name}"]="${arg_default_value}"
	done
		
	########################################
	# parse args
	########################################
	local opt
	local arg_translations
	for opt in "${arguments[@]}"
	do
		case "$opt" in
			"${opt%%=*}="*)
				local parsed_opt="${opt%%=*}"
				local parsed_value="${opt##*=}"
				
				case "$parsed_opt" in
					"--"*)
						# handles --varA="value"
						local arg_translation="${arg_options_long_map[$parsed_opt]}"
						[[ -z "${arg_translation}" ]] &&
						{
							arg_translations+=("$opt")
							continue #parse_error_add "Invalid Argument: ${opt}"
						}
						
						arg_translations+=("$arg_translation")
						arg_translations+=("$parsed_value")
					;;
					*)
						# handles --a="value"
						arg_translations+=("$parsed_opt")
						arg_translations+=("$parsed_value")
					;;
				esac
			;;
			"--"*)
				# handles --varA "value"
				local arg_translation="${arg_options_long_map[$opt]}"
				[[ -z "${arg_translation}" ]] &&
				{
					arg_translations+=("$opt")
					continue #parse_error_add "Invalid Argument: ${opt}"
				}
				
				arg_translations+=("$arg_translation")
			;;
			*)
				# handles everything else
				arg_translations+=("$opt")
			;;
		esac
	done
	
	set -- "${arg_translations[@]}"
	
	local OPTIND
	while getopts "${arg_opt_string}" opt
	do
		local key="${arg_options_name[$opt]}"
		local type="${arg_options_type[$opt]}"
		local value="${OPTARG}"
		
		[[ "$type" == "bool" ]] && value="true"
		
		#echo "OPTIND: $OPTIND, OPT: $opt, OPTION: $OPTION, OPTARG: $OPTARG"
		case "$opt" in
			\?)
				parse_error_add "Invalid Argument: -$value"
			;;
			:)
				parse_error_add "Option -$value requires an argument."
			;;
			*)
				args_process_output_var[$key]="$value"
			;;
		esac
	done
	
	[[ "${parse_error}" != "false" ]] &&
	{
		params_help "$arg_configs_type" "$func_name"
		throw "${parse_error_message}" "${parse_error}"
	}
	
	########################################
	# populate default values
	########################################
	for arg_name in ${arg_configs[@]}
	do
		local arg_value="${args_process_output_var[$arg_name]}"
		local arg_short_key="${arg_options_short[$arg_name]}"
		local arg_type="${arg_options_type[$arg_short_key]}"
		local arg_default_value="${arg_options_default[$arg_short_key]}"
		
		[[ -z "$arg_value" || "$arg_value" == "$arg_default_value" ]] &&
		{
			string_startswith "${arg_default_value}" "${arg_configs_name}[" &&
			{
				local -n arg_default_value_ref="${arg_default_value//${arg_configs_name}[/args[}"
				args_process_output_var["${arg_name}"]="$arg_default_value_ref"
			}
		}
		
		local is_required="$(array_contains arg_options_required "$arg_short_key" && echo "true" || echo "false")"
		#echo "$arg_name ($arg_short_key): is_required: $is_required"
		[[ is_required != "true" && -z "$arg_value" ]] &&
		{
			[[ "${arg_type}" == "bool" ]] && args_process_output_var["${arg_name}"]="false"
			[[ "${arg_type}" == "int" ]] && args_process_output_var["${arg_name}"]="0"
		}
	done
	
	########################################
	# argument validation
	########################################
	# required values
	for required_arg in ${arg_options_required[@]}
	do
		local arg_name="${arg_options_name[$required_arg]}"
		
		[[ -z "${args_process_output_var[$arg_name]}" ]] &&
		{
			parse_error_add "Missing required argument \"$arg_name\": -${required_arg}, --${arg_options_long[${required_arg}]}"
		}
	done
	
	# type and regex validation
	for arg_name in ${!args_process_output_var[@]}
	do
		local arg_short_key="${arg_options_short[$arg_name]}"
		local arg_type="${arg_options_type[$arg_short_key]}"
		local arg_long_key="${arg_options_long[$arg_short_key]}"
		local arg_validation="${arg_options_validation[$arg_short_key]}"
		local arg_value="${args_process_output_var[$arg_name]}"
		local type_error_message="Invalid value \"${arg_value}\" for argument with data type \"$arg_type\", argument name \"$arg_name\": -${arg_short_key}, --${arg_long_key}"
		
		# type validation
		! variable_validation arg_value "$arg_type" &&
		{
			parse_error_add "$type_error_message"
		}
		
		# custom regex validation
		[[ ! -z "$arg_value" && ! -z "$arg_validation" ]] &&
		{
			! variable_validation arg_value "regex" "$arg_validation" &&
			{
				parse_error_add "Invalid value \"${arg_value}\" for argument, did not match validation rule \"$arg_validation\", argument name \"$arg_name\": -${arg_short_key}, --${arg_long_key}"
			}
		}
	done
	
	###################################
	# Output
	###################################
	[[ "$parse_error" != "false" ]] &&
	{
		params_help "$arg_configs_type" "$func_name"
		throw "$parse_error_message" "${parse_error}"
	}
	
	[[ "${args_process_output_var[help]}" == "true" ]] &&
	{
		params_help "$arg_configs_type" "$func_name"
		exit 0
	}
	
	return 0
}

params_help()
{
	########################################
	# init
	########################################
	local arg_configs_type="$1"
	local func_name="${2}"
	local arg_configs_name="FUNC_${func_name}_PARAMS"
	
	[[ "${arg_configs_type}" == "script" ]] &&
	{
		arg_configs_name="SCRIPT_PARAMS"
		func_name="$(realpath "${BASH_SOURCE}")"
		arg_configs_type="script"
	}
	local parse_error_message="An error occurred trying to parse arguments for $arg_configs_type \"$func_name\""
	local parse_error="false"
		
	########################################
	# input validation
	########################################
	local -n arg_configs="$arg_configs_name" 2> /dev/null || parse_error="Argument configuration variable required, \"${arg_configs_name}\" does not appear to be a valid argument configuration variable."
	local arg_configs_var_type="$(variable_type ${!arg_configs})"
	[[ "${arg_configs_var_type}" != "associative array" ]] && parse_error="Argument configuration variable \"${arg_configs_name}\" has invalid type of \"$arg_configs_var_type\", expected type is \"associative array\""
	[[ "${parse_error}" != "false" ]] && throw "${parse_error_message}" "${parse_error}"
	
	local arguments=( "${@}" )
	########################################
	# build arg options
	########################################
	declare -A arg_options_name
	declare -A arg_options_type
	declare -A arg_options_long
	declare -A arg_options_short
	declare -A arg_options_default
	declare -A arg_options_validation
	declare -A arg_options_description
	declare -A arg_options_long_map
	local arg_options_required=()
	
	# add defaults
	local default_option_name="help"
	arg_configs["${#arg_configs[@]}"]="$default_option_name"
	local default_option_prefix="SCRIPT"
	[[ "$arg_configs_type" == "function" ]] && default_option_prefix="FUNC"
	local default_option_var_name="${arg_configs_name}_OPTION_${default_option_name}"
	local -n default_option_var="$default_option_var_name"
	[[ "${#default_option_var[@]}" -eq 0 ]] && declare -Ag "$default_option_var_name"	
	default_option_var=(
		[short]="h" [type]=bool
		[explanation]="Access help information."
	)	
	local arg_opt_string=":"
	for arg_name in ${arg_configs[@]}
	do
		local arg_config_name="${arg_configs_name}_OPTION_${arg_name}"
		
		# arg configuration validation
		local -n arg_config_options="${arg_config_name}" 2> /dev/null ||
		{
			throw "$parse_error_message" "Missing param configuration options: \"${arg_config_name}\""
		}
		[[ -z "${arg_config_options[*]}" ]] &&
		{
			throw "$parse_error_message" "Missing param configuration options: \"${arg_config_name}\""
		}
		
		local arg_config_options_type="$(variable_type "${arg_config_name}")"
		[[ "$arg_config_options_type" != "associative array" ]] &&
		{
			throw "$parse_error_message" "Param configuration options \"$arg_config_name\" has invalid type of \"$arg_config_options_type\", expected type is \"associative array\""
		}
		
		# populate arg options arrays
		local arg_short_key="${arg_config_options[short]}"
		local arg_long_key="${arg_config_options[long]}"
		local arg_required="${arg_config_options[required]}"
		local arg_type="${arg_config_options[type]}"
		local arg_default_value="${arg_config_options[default]}"
		local arg_validation="${arg_config_options[validation]}"
		local arg_description="${arg_config_options[explanation]}"
				
		[[ -z "$arg_long_key" ]] && arg_long_key="${arg_name}"
		arg_long_key="${arg_long_key//_/-}"
		arg_long_key="${arg_long_key// /-}"
		
		[[ "$arg_required" == "true" ]] &&
		{
			arg_options_required+=("$arg_short_key")
			# if an argument is required default value should not be set
			[[ ! -z "$arg_default_value" ]] &&
			{
				arg_default_value=""
				echo_warning "Default value ignored for \"${arg_name}\" since it is a required argument."
			}
		}
		
		arg_options_short[$arg_name]="${arg_short_key}"
		arg_options_name[$arg_short_key]="${arg_name}"
		arg_options_type[$arg_short_key]="${arg_type:-string}"
		arg_options_long[$arg_short_key]="${arg_long_key}"
		arg_options_default[$arg_short_key]="${arg_default_value}"
		arg_options_validation[$arg_short_key]="${arg_validation}"
		arg_options_description[$arg_short_key]="${arg_description}"
		arg_options_long_map["--${arg_long_key}"]="-${arg_short_key}"
		
		# build arg_opt_string
		arg_opt_string+="$arg_short_key"
		[[ "${arg_type}" != "bool" ]] && arg_opt_string+=":"
		
		# build args object with default values to be populated later
		args_process_output_var["${arg_name}"]="${arg_default_value}"
	done
	
	echo_info "[${arg_configs_type^} Usage Information]"
	local output="Args|~|Type|~|Required|~|Description${LF}------|~|------|~|----------|~|-------------${LF}"
	for arg_name in $(reverse ${arg_configs[@]})
	do
		local arg_short_key="${arg_options_short[$arg_name]}"
		output+="-${arg_short_key}"
		variable_not_empty arg_options_long[$arg_short_key] && output+=", --${arg_options_long[$arg_short_key]}" || " "
		output+="|~|${arg_options_type[$arg_short_key]}"
		local is_required="false"
		array_contains arg_options_required "$arg_short_key" && is_required="true"
		output+="|~|${is_required}"
		output+="|~|${arg_options_description[$arg_short_key]}"
		output+="${LF}"
	done
	echo_info "$(echo "$output" | column -t -s '|~|')${LF}"
}

variable_type()
{
    local type_signature="$(declare -p "$1" 2>/dev/null || echo "")"
	
	if [[ "$type_signature" == "" ]]
	then
        echo "unset"
    elif [[ "$type_signature" =~ "declare --" ]]
	then
        echo "string"
    elif [[ "$type_signature" =~ "declare -a" ]]
	then
        echo "array"
	elif [[ "$type_signature" =~ "declare -i" ]]
	then
        echo "int"
    elif [[ "$type_signature" =~ "declare -A" ]]
	then
        echo "associative array"
	elif [[ "$type_signature" =~ "declare -n" ]]
	then
        echo "indirect reference"
    else
        echo "unknown ($type_signature)"
    fi
}

variable_validation()
{
	local -n input_var="$1"
	local validation_rule="$2"
	shift; shift;
	local validation_rule_options="$@"
	
	case "$validation_rule" in
		"bool"|"boolean")
			# normalize boolean value
			local true_values=( "yes" "true" "y" "t" "1")
			local false_values=( "no" "false" "f" "n" "0" )
			array_contains "true_values" "$output_variable" && arg_value="true"
			array_contains "false_values" "$output_variable" && arg_value="false"
			args["$arg_name"]="$arg_value"
			
			# validate boolean
			local acceptable_values=("true" "false")
			! array_contains acceptable_values "$arg_value" && return 1
		;;
		"char")
			[[ "${#input_var}" -gt 1 ]] && return 1
		;;
		"int")
			[[ ! "${input_var}" =~ ^[0-9]+$ ]] && return 1
		;;
		"regex")
			[[ ! "${input_var}" =~ $validation_rule_options ]] && return 1
		;;
		"string")
			:
		;;
		*)
			echo_warning "Unknown validation rule \"$validation_rule\"."
			return 0
		;;
	esac
		
	return 0
}

reverse()
{
	reverse_array()
	{
		local input=( "$@" )
		local len="$(len "$@")"
		local output=()
		for (( i="$len"-1; i>=0; i-- ))
		do
			output+=( ${input[i]} )
		done
		echo "${output[@]}"
	}
	
	reverse_string()
	{
		local input="${@}"
		local len="$(len "$@")"
		local output=()
		for((i="$len"-1;i>=0;i--))
		do
			output+="${input:$i:1}"
		done
		echo "$output"
	}

	if [[ "${#@}" -gt 1 ]]
	then
		reverse_array "$@"
	else
		reverse_string "$@"
	fi
}

len()
{
	if [[ "${#@}" -gt 1 ]]
	then
		echo "${#@}" 
	else
		echo "${#1}"
	fi
}

variable_is_empty()
{
	local -n input="$1"
	local no_trim="${2:-false}"
	local test_string="${input}${input[*]}"
	[[ "$no_trim" != "true" ]] && test_string="$(trim "$test_string")"
	[[ -z "${test_string}" ]]
}

variable_not_empty()
{
	! variable_is_empty "$@"
}

variable_is_declared()
{
	local -n input="$1"
	[[ "$(variable_type "${!input}")" != "unset" ]]
}

variable_contains()
{
	local -n input="$1"
	if [[ "$(variable_type "${!input}")" == "array"* ]]
	then
		array_contains "${!input}" "$2"
	else
		string_contains "$2" "$1"
	fi
}

test_case()
{
	params_declare --short "n" --name "name"      --required    --explanation "The name of the test case."
	params_declare --short "f" --name "function"                --explanation "The name of the function to test."
	params_declare --short "v" --name "variable"                --explanation "The name of the variable to test."
	params_declare --short "a" --name "arguments"               --explanation "A list of arguments to pass to the function being tested."
	params_declare --short "e" --name "exit-code" --type "int"  --explanation "Expected exit code, defaults to 0 if not set."
	params_declare --short "o" --name "output"                  --explanation "Expected output of the function or value of the variable being tested."
	
	declare -A args
	args_process args "$@"
	
	#echo_var args
	local test_subject=""
	[[ -n "${args[function]}" ]] && test_subject="function"
	
	local test_failures=()
	local test_results=""
	case "$test_subject" in
		"function")
			local exit_code=-999
			local output=""
			local arguments
			mapfile -t arguments < <(xargs -n 1 printf '%s\n' <<<"${args[arguments]}")
			local command_line="(TIMEFORMAT=\"#test_case# %3lR\"; set -o errexit; set -o errtrace; set -o functrace; set -o pipefail; time ${args[function]} ${arguments[@]@Q} )"
			local command_duration="unknown"
			local opts="$-"
			set +o errexit
			set +o errtrace
			set +o functrace
			set +o pipefail
			output=$(eval "${command_line} 2>&1")
			exit_code="$?"
			set -"$opts"
			[[ "$output" == *"#test_case#"* ]] &&
			{
				command_duration="${output##*#test_case# }"
				output="$(trim "${output%%#test_case#*}")"
			}
			[[ "$exit_code" != "${args[exit_code]}" ]] && test_failures+=( "Unexpected Exit code" )
			[[ "${args[output]}" != "*" && "$output" != "${args[output]}" ]] && test_failures+=( "Unexpected Output Value" )
			
			[[ "${SCRIPT_ARGS[verbose]}" == "true" ]] &&
			{
				test_results+="${LF}Function:${RESET} ${args[function]}${LF}"
				test_results+="${#arguments[@]} Arguments:${RESET} ${arguments[@]@Q}${LF}"
				test_results+="Exit Code:${LF}"
				test_results+="${TAB}Expected:${RESET} ${args[exit_code]}${LF}"
				test_results+="${TAB}Actual:${RESET} ${exit_code}${LF}"
				test_results+="Output:${LF}"
				test_results+="${TAB}Expected:${RESET} ${args[output]@Q}${LF}"
				string_contains "${output}" "${LF}" && output="${LF}$(echo_line_prefix "${RESET}" "$(string_indent_block 2 "${output}")")" || output="${output@Q}"
				test_results+="${TAB}Actual:${RESET} ${output}${LF}"
			}
		;;
		"variable")
			throw not_implemented_excepion
		;;
		*) throw "Unknown Condition Type" "Condition type \"$test_subject\" does not exist."
	esac
	
	if [[ "${#test_failures[@]}" -eq 0 ]]
	then
		test_results="[${RESET}${args[name]}${COLOR_TEXT_SUCCESS}] Duration:${RESET} ${command_duration} ${COLOR_TEXT_SUCCESS}${test_results}"
		test_results+="Test Status:${RESET} Passed!"
		
		echo_success "$test_results"
		[[ "${SCRIPT_ARGS[verbose]}" == "true" ]] && echo_success
	else
		test_results="[${RESET}${args[name]}${COLOR_TEXT_ERROR}] Duration:${RESET} ${command_duration} ${COLOR_TEXT_ERROR}${test_results}"
		test_results+="Test Status:${RESET} Failed!"
		test_results+="${COLOR_TEXT_ERROR} ${#test_failures[@]} Failure(s):${RESET} $(string_join ", " test_failures)"
		
		echo_error "$test_results"
		[[ "${SCRIPT_ARGS[verbose]}" == "true" ]] && echo_error
	fi
	return 0
}

test_cases()
{
	# define test collections
	test_cases_random()
	{
		test_case --name "test_case: fails on command not found" --function "dsfsdfsd" --arguments "sdfsdds" --exit-code "127" --output "*"
	}
	
	test_cases_variable_is_empty()
	{
		test_case --name "variable_is_empty: empty string" --function "variable_is_empty" --arguments "string_empty" --exit-code "0" --output ""
		test_case --name "variable_is_empty: white space string" --function "variable_is_empty" --arguments "string_white_space" --exit-code "0" --output ""
		test_case --name "variable_is_empty: non-empty string" --function "variable_is_empty" --arguments "string_notempty" --exit-code "1" --output ""
		test_case --name "variable_is_empty: non-declared string" --function "variable_is_empty" --arguments "string_notdeclared" --exit-code "0" --output ""
		test_case --name "variable_is_empty: empty array" --function "variable_is_empty" --arguments "array_empty" --exit-code "0" --output ""
		test_case --name "variable_is_empty: white space array" --function "variable_is_empty" --arguments "array_white_space" --exit-code "0" --output ""
		test_case --name "variable_is_empty: non-empty array" --function "variable_is_empty" --arguments "array_notempty" --exit-code "1" --output ""
		test_case --name "variable_is_empty: non-declared array" --function "variable_is_empty" --arguments "array_notdeclared" --exit-code "0" --output ""
		test_case --name "variable_is_empty: empty associative array" --function "variable_is_empty" --arguments "associative_array_empty" --exit-code "0" --output ""
		test_case --name "variable_is_empty: non-empty associative array" --function "variable_is_empty" --arguments "associative_array_simple" --exit-code "1" --output ""
		test_case --name "variable_is_empty: associative array value" --function "variable_is_empty" --arguments "associative_array_simple[a]" --exit-code "1" --output ""
	}
	
	test_cases_variable_is_declared()
	{
		test_case --name "variable_is_declared: empty string" --function "variable_is_declared" --arguments "string_empty" --exit-code "0" --output ""
		test_case --name "variable_is_declared: white space string" --function "variable_is_declared" --arguments "string_white_space" --exit-code "0" --output ""
		test_case --name "variable_is_declared: non-empty string" --function "variable_is_declared" --arguments "string_notempty" --exit-code "0" --output ""
		test_case --name "variable_is_declared: non-declared string" --function "variable_is_declared" --arguments "string_notdeclared" --exit-code "1" --output ""
		test_case --name "variable_is_declared: empty array" --function "variable_is_declared" --arguments "array_empty" --exit-code "0" --output ""
		test_case --name "variable_is_declared: white space array" --function "variable_is_declared" --arguments "array_white_space" --exit-code "0" --output ""
		test_case --name "variable_is_declared: non-empty array" --function "variable_is_declared" --arguments "array_notempty" --exit-code "0" --output ""
		test_case --name "variable_is_declared: non-declared array" --function "variable_is_declared" --arguments "array_notdeclared" --exit-code "1" --output ""
		test_case --name "variable_is_declared: empty associative array" --function "variable_is_declared" --arguments "associative_array_empty" --exit-code "0" --output ""
		test_case --name "variable_is_declared: non-empty associative array" --function "variable_is_declared" --arguments "associative_array_simple" --exit-code "0" --output ""
	}
	
	test_cases_params()
	{
		test_case_params_declare_simple()
		{
			params_declare --short "a" --name "alpha"               --explanation "random explanation"
			params_declare --short "b" --name "boy"   --type "bool" --explanation "random explanation"
			params_declare --short "c" --name "cat"   --type "int"  --explanation "random explanation"
			params_declare --short "d" --name "dog"   --required    --explanation "random explanation"
			params_declare --short "e" --name "echo"                --explanation "random explanation"
		}
		
		test_case_args_process()
		{
			params_declare --short "a" --name "alpha"                 --explanation "random explanation"
			params_declare --short "b" --name "bravo"   --type "bool" --explanation "random explanation"
			params_declare --short "c" --name "charlie" --type "int"  --explanation "random explanation"
			params_declare --short "d" --name "delta"   --required    --explanation "random explanation"
			params_declare --short "e" --name "echo"                  --explanation "random explanation"
			params_declare --short "f" --name "foxtrot"               --explanation "random explanation"
			
			declare -A args
			args_process args "$@"
			echo "${args[alpha]},${args[bravo]},${args[charlie]},${args[delta]},${args[echo]},${args[foxtrot]}"
		}
	
		local short_args='-a "val 1" -b -c "3" -d "val 4" -e "val 5" -f "val 6"'
		local long_args='--alpha "val 1" --bravo --charlie "3" --delta "val 4" --echo "val 5" --foxtrot "val 6"'
		local expected_arg_values='val 1,true,3,val 4,val 5,val 6'
		test_case --name "params_declare: simple declare" --function "test_case_params_declare_simple" --exit-code "0" --output ""
		test_case --name "args_process: throws on missing required argument" --function "test_case_args_process" --exit-code "1" --output "*"
		test_case --name "args_process: can parse short arguments" --function "test_case_args_process" --arguments "${short_args}" --exit-code "0" --output "${expected_arg_values}"
		test_case --name "args_process: can parse long arguments" --function "test_case_args_process" --arguments "${long_args}" --exit-code "0" --output "${expected_arg_values}"
		# test for param required text
	}

	# handle args
	params_declare --short "g" --name "group" --explanation "The test group to run."
	declare -A args
	args_process args "$@"

	# define generic test data
	local string_empty=""
	local string_white_space="  "
	local string_notempty="some string"
	local array_empty=()
	local array_white_space=( "  " )
	local array_notempty=( "some string" )
	declare -A associative_array_empty
	declare -A associative_array_simple=( [a]="one" [b]="two" [c]="three" )
	
	# execute groups
	local test_groups=( $(declare -F | grep test_cases_ | cut -d ' ' -f 3-) )
	variable_is_empty args[group] &&
	{
		echo_info "Executing ${#test_groups[@]} test groups(s)..."
		echo
	}
	
	for test_group in ${test_groups[@]}
	do
		
		TIMEFORMAT='#test_group# %3lR'
		local exit_code=-999
		variable_not_empty args[group] && [[ "test_cases_${args[group]}" != "${test_group}" ]] && continue;
		
		local running_text="Running test group ${RESET}${test_group}"
		running_text="${running_text//test_cases_/}"
		running_text="${running_text//test_cases_/}"
		
		echo_info "${running_text}..."
		local command_line="( set -o errexit; set -o errtrace; set -o functrace; set -o pipefail; time ${test_group} )"
			local opts="$-"
			set +o errexit
			set +o errtrace
			set +o functrace
			set +o pipefail
			local execution_output
			execution_output=$(eval "${command_line}" 2>&1)
			exit_code="$?"
			set -"$opts"
		#echo "$execution"
		local execution_duration="unknown"
		[[ "$execution_output" == *"#test_group#"* ]] &&
		{
			execution_duration="${execution_output##*#test_group# }"
			execution_output="$(trim "${execution_output%%#test_group#*}")"
		}
		if [[ "${SCRIPT_ARGS[verbose]}" == "true" ]]
		then
			echo "$execution_output"
		else
			#echo "$execution_output"
			echo "${execution_output//]/]|~|}" | column -t -s '|~|'
		fi
		if [[ "${execution_output}" == *"Test Status:${RESET} Failed!"* ]]
		then
			echo_error "${running_text}${COLOR_TEXT_ERROR} completed with failures in ${RESET}${execution_duration}"
		else
			echo_success "${running_text}${COLOR_TEXT_SUCCESS} completed successfully in ${RESET}${execution_duration}"
		fi
		echo ""
	done
	
	# exit after running tests...
	exit
}

where()
{
	local condition="$1"
	shift
	local args_array=()
	args_from_anywhere args_array "$@"
	local output=()
	
	local key value x test
	for key in "${!args_array[@]}"
	do
		value="${args_array[$key]}"
		test="${condition//'$i'/$key}"
		test="${condition//'$x'/$value}"
		#local test_result="$($test &>/dev/null && echo $? || echo $?)"
		#[[ "$test_result" == "0" ]] && output+=("$value")
		condition "$test" && output+=("$value")
	done
	
	echo "${output[@]}"
}

condition()
{
	local test="$*"
	local test_result=$(eval $test &>/dev/null && echo $? || echo $?)
	[[ "$test_result" == "0" ]]
}

is_number()
{
	[[ "$1" =~ ^[0-9]+$ ]]
}

is_even()
{
	{ is_number "$1" || throw "\"$1\" is not a number."; } && ! (( "$1" % 2 ))
}

is_odd()
{
	{ is_number "$1" || throw "\"$1\" is not a number."; } && (( "$1" % 2 ))
}

quote()
{
	local -n quote_array_input="$1"
	echo "${quote_array_input[@]@Q}"
}

args_from_anywhere()
{
	local -n output_array="$1"
	shift
	output_array=( "$@" )
	[[ "${#output_array[@]}" == "0" ]] &&
	{
		args_from_pipe
		output_array=( "${PIPEARGS[@]}" )
	}
	return 0
}

args_from_string()
{
	local input=( "$@" )
	declare -ag STRINGARGS
	mapfile -t STRINGARGS < <(xargs -n 1 printf '%s\n' <<<"${input[@]}")
}

args_from_pipe()
{
	local arguments
	read -rt 0.001 input || true
	if [[ "${input:-}" ]]
	then
		unset PIPEARGS
		args_from_string "$input"
		declare -ag PIPEARGS
		PIPEARGS=( "${STRINGARGS[@]}" )
		unset STRINGARGS
		return 0
	fi
	echo_warning "No input received from pipe (stdin)"
}

#######################################
# Script Init
#######################################
set -o errexit
set -o errtrace
set -o functrace
set -o pipefail
shopt -s inherit_errexit

config_colors
trap_handler "ENABLE"
	
#######################################
# Common Variables
#######################################
LF=$'\n'
TAB=$'\t'

#######################################
# Main
#######################################
# todo
# echo_debug
# help text via args
# positional params
# todo: param dependancies (maybe)
# args performance
# duplicate short key test
# special handling for boolean in args, allow optional "true/false" value
# allow multiple values (array) per argument
# -h, --help should be reserved
# process args ref type
# prompt password
# copy wpa_supplicant for debian build
# shanespace OS for raspbian

params_declare --short "n" --name "new-config" --type "bool" --explanation "Create a new saved configuration."
params_declare --short "c" --name "config"                   --explanation "The name of a previously saved configuration."
params_declare --short "d" --name "distro"                   --explanation "The name of the core distrobution you want to build."
params_declare --short "t" --name "test"       --type "bool" --explanation "Run test collections."
params_declare --short "a" --name "verbose"    --type "bool" --explanation "Include additional details in output."

declare -A SCRIPT_ARGS
args_process SCRIPT_ARGS "$@"

${SCRIPT_ARGS[test]} && test_cases

config "$@"
build