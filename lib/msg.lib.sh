#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/msg.lib.sh
#
#        USAGE:   . msg.lib.sh
#
#  DESCRIPTION:   Shell library containing logging and output formatting
#                 functions such as
#                   - logging,
#                   - formatting terminal messages,
#                   - providing message templates (e.g. license notification).
#
#         BUGS:   ---
#
#        NOTES:   - This library tries to be as POSIX-compliant as possible.
#                   However, there may be some functions that require non-POSIX
#                   commands or further packages.
#
#                 - Function names starting with a double underscore <__>
#                   indicate that those functions do not check their
#                   arguments (values).
#
#         TODO:   ---
#===============================================================================

#===============================================================================
#  CHECK IF ALREADY LOADED
#===============================================================================
if lib_msg 2>/dev/null; then return; fi

#===============================================================================
#  IMPORT
#===============================================================================
#-------------------------------------------------------------------------------
#  Load libraries
#-------------------------------------------------------------------------------
for lib in core math; do
  eval lib_$lib 2>/dev/null                                                 || \
  . "./$lib.lib.sh"                                                         || \
  {
    printf "%s\n\n"                                                         \
      "ERROR: Library '$lib.lib.sh' could not be loaded. Aborting..." >&2
    return 1
  }
done

#===============================================================================
#  CONSTANTS & GLOBAL VARIABLES
#===============================================================================

#===============================================================================
#  FUNCTIONS
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_msg
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_msg() {
  return 0
}

#===============================================================================
#  FUNCTIONS (MISCELLANEOUS)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_msg_dialog_autosize
#  DESCRIPTION:  Calculate the size of dialog boxes (see 'man dialog')
# PARAMETER  1:  Selector, must be one of the following values:
#                  [-h|--height]  : output height as a number of lines
#                  [-w|--width]   : output width as a number of columns
#                  ""             : output both values, in the form of
#                                   '[height] [width]' (separated by space),
#                                   e.g. '30 100'
#            2:  Aspect ratio 'width : height' (default: '4')
#            3:  (Optional) Fixed height as a number of lines (minimum: '20')
#            4:  (Optional) Fixed width as a number of columns (minimum: '80')
#      OUTPUTS:  Write dialog height and/or size to <stdout>
#===============================================================================
lib_msg_dialog_autosize() {
  local arg_select="${1}"
  local arg_ratio="${2:-4}"
  local arg_height="${3}"
  local arg_width="${4}"

  # Set a dummy terminal in case the script is run in batchmode via SSH
  # Otherwise the following error occurs:
  # "tput: No value for $TERM and no -T specified"
  [ -z "${TERM}" ] && export TERM="dumb"

  local lines
  local cols
  lines="$(lib_msg_term_get --lines)"
  cols="$(lib_msg_term_get --cols)"

  # minimum is 24x80 but lots of dialog menus require greater values
  [ "${lines}" -ge "30" ] 2>/dev/null   && \
  [ "${cols}" -ge "100" ] 2>/dev/null   || \
  { lib_msg_echo --error "Terminal window is too small, minimum size is <100x30>."
    return 1
  }

  lines="$((lines - 10))"
  cols="$((cols - 2))"

  case "${arg_select}" in
    ""|-h|--height|-w|--width) ;;
    *) false ;;
  esac                                    && \
  [ "${arg_ratio}" -ge "1" ] 2>/dev/null  && \
  if lib_core_is --set "${arg_height}"; then
    [ "${arg_height}" -ge "20" ] 2>/dev/null
  fi                                      && \
  if lib_core_is --set "${arg_width}"; then
    [ "${arg_width}" -ge "80" ] 2>/dev/null
  fi                                      || \
  return

  if [ -n "${arg_width}" ]; then
    if [ "${arg_width}" -gt "${cols}" ] 2>/dev/null; then
      arg_width="${cols}"
    fi

    arg_height="$(( arg_width / arg_ratio  ))"
    if [ "${arg_height}" -gt "${lines}" ]; then
      arg_height="${lines}"
      arg_width="$(( arg_height * arg_ratio ))"
    fi
  else
    if  [ -z "${arg_height}" ] || \
        [ "${arg_height}" -gt "${lines}" ] 2>/dev/null; then
      arg_height="${lines}"
    fi

    arg_width="$(( arg_height * arg_ratio  ))"
    if [ "${arg_width}" -gt "${cols}" ]; then
      arg_width="${cols}"
      arg_height="$(( arg_width / arg_ratio ))"
    fi
  fi

  case "${arg_select}" in
    "") printf "%s %s" "${arg_height}" "${arg_width}" ;;
    -h|--height) printf "%s" "${arg_height}" ;;
    -w|--width) printf "%s" "${arg_width}" ;;
  esac
}

#===============================================================================
#  FUNCTIONS (LOGGING + TERMINAL MESSAGES)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  __lib_msg_log
#  DESCRIPTION:  Log a message to <syslog> by using 'logger'
# PARAMETER  1:  Logger priority (see 'man logger')
#            2:  Message to log
#            3:  Return code (optional, default: '0')
#      RETURNS:  Either '0' (default) or the return code defined in param <3>
#===============================================================================
__lib_msg_log() {
  local arg_pri="$1"
  local arg_msg="$2"
  local arg_code="${3:-0}"

  logger -t "$0" -p "${arg_pri}" "${arg_msg}"
  return ${arg_code}
}

__lib_msg_log_error() {
  local arg_msg="$1"
  local arg_code="${2:-1}"

  __lib_msg_log "err" "[ERROR] ${arg_msg}" "${arg_code}"
}

__lib_msg_log_info() {
  local arg_msg="$1"

  __lib_msg_log "info" "[INFO] ${arg_msg}"
}

__lib_msg_log_warning() {
  local arg_msg="$1"

  __lib_msg_log "warning" "[WARNING] ${arg_msg}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_msg_message
#  DESCRIPTION:  Log/Print error/info/warning message and optionally exit
# PARAMETER  1:  Log destination
#                   --auto      Auto detection
#                   --both      System Log + Terminal
#                   --syslog    System Log
#                   --terminal  Terminal
#                (default: '--auto')
#            2:  Message type (--error|--info|--warning) (default: '--info')
#            3:  Message (terminal version)
#            4:  Message (syslog version) (default: parameter <3>)
#            5:  Exit? (true|false) (default: 'false')
#            6:  Exit/Return code
#                (Default value depends on messages type,
#                See switch-case statement below)
#      OUTPUTS:  Writes to <stdout|stderr|syslog>
#                (see switch-case statement below)
#      RETURNS
#       0 | 1 :  Depends on parameter <6>
#           2 :  Error: Parameter <1> not supported
#===============================================================================
lib_msg_message() {
  local arg_logdest="${1:---auto}"
  local arg_type="${2:---info}"
  local arg_msg_std="$3"
  local arg_msg_syslog="${4:-$3}"
  local arg_exit="${5:-false}"
  local arg_code="$6"

  case "${arg_logdest}" in
    --auto|auto)
      local std
      case "${arg_type}" in
        --error|error)  std="stderr" ;;
        *)              std="stdout" ;;
      esac
      if lib_core_is --terminal-${std}; then
        arg_logdest="--terminal"
      else
        arg_logdest="--syslog"
      fi
      ;;
    --both|both) ;;
    --syslog|syslog) ;;
    --terminal|terminal) ;;
    *) return 2 ;;
  esac

  case "${arg_type}" in
    --error|error)
      arg_code="${arg_code:-1}"
      case "${arg_logdest}" in
        --both|both)
          lib_msg_print_heading -e "${arg_msg_std}" >&2
          __lib_msg_log_error "${arg_msg_syslog}"
          ;;
        --syslog|syslog) __lib_msg_log_error "${arg_msg_syslog}" ;;
        --terminal|terminal) lib_msg_print_heading -e "${arg_msg_std}" >&2 ;;
      esac
      ;;

    --info|info)
      arg_code="${arg_code:-0}"
      case "${arg_logdest}" in
        --both|both)
          lib_core_echo "false" "false" "${arg_msg_std}"
          __lib_msg_log_info "${arg_msg_syslog}"
          ;;
        --syslog|syslog) __lib_msg_log_info "${arg_msg_syslog}" ;;
        --terminal|terminal) lib_core_echo "false" "false" "${arg_msg_std}" ;;
      esac
      ;;

    --warning|warning)
      arg_code="${arg_code:-0}"
      case "${arg_logdest}" in
        --both|both)
          lib_msg_print_heading -w "${arg_msg_std}"
          __lib_msg_log_warning "${arg_msg_syslog}"
          ;;
        --syslog|syslog) __lib_msg_log_warning "${arg_msg_syslog}" ;;
        --terminal|terminal) lib_msg_print_heading -w "${arg_msg_std}" ;;
      esac
      ;;

    *) return 2 ;;
  esac

  if ${arg_exit}; then exit ${arg_code}; else return ${arg_code}; fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_msg_echo
#  DESCRIPTION:  Print error/info/warning message to terminal
# PARAMETER  1:  Message type (--error|--info|--warning) (default: '--info')
#            2:  Message
#            3:  (Optional) Exit? (true|false) (default: 'false')
#            4:  (Optional) Exit/return code
#                (Default: Depends on param <1>, see <lib_msg_message()>)
#          5..:  (Optional) Parameter/Value pairs, e.g. "var1" "1" "var2" "2"
#                           will be appended to the message
#      RETURNS:  Depends on parameter <4>, see <lib_msg_message()>
#===============================================================================
lib_msg_echo() {
  local arg_type="$1"
  local arg_msg="$2"
  local arg_exit="$3"
  local arg_code="$4"

  if [ $# -ge 5 ]; then
    shift;shift;shift;shift
    arg_msg="$(printf "%s\n\n%s"                                            \
      "${arg_msg}"                                                          \
      "$(lib_msg_print_propvalue                                          \
        --center --center "2" "$(($(lib_msg_term_get --cols) - 12))" ":"  \
        "$@")")"
  fi

  lib_msg_message --terminal "${arg_type}" "${arg_msg}" "" "${arg_exit}" "${arg_code}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_msg_log
#  DESCRIPTION:  Log error/info/warning message to <syslog>
# PARAMETER  1:  Message type (--error|--info|--warning) (default: '--info')
#            2:  Message
#            3:  Exit? (true|false) (default: 'false')
#            4:  (Optional) Exit/return code
#                (Default: Depends on param <1>, see <lib_msg_message()>)
#      RETURNS:  Depends on parameter <4>, see <lib_msg_message()>
#===============================================================================
lib_msg_log() {
  lib_msg_message --syslog "$1" "" "$2" "$3" "$4"
}

#===============================================================================
#  FUNCTIONS (PRINT)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_msg_print_borderstring
#  DESCRIPTION:  Print a string surrounded by border characters
#      OUTPUTS:  Writes formatted string to <stdout>
# PARAMETER  1:  String to format (optional)
#            2:  (Single) border character (optional, default '-')
#            3:  Padding in number of spaces (optional, default '1')
#            4:  Line width (optional, default is the terminal's window width)
#===============================================================================
lib_msg_print_borderstring() {
  #-----------------------------------------------------------------------------
  #  Read arguments
  #-----------------------------------------------------------------------------
  local arg_string="$1"
  local arg_border="${2:--}"
  local arg_padding="$3"
  local arg_width="$4"

  local border_len      # How many characters the left/right border should have
  local border_str      # Complete left/right border string
  local padding_str     # Complete left/right padding string
  local string_len      # String length
  local string_len_max  # Maximum string length per line

  #-----------------------------------------------------------------------------
  #  Determine line width
  #-----------------------------------------------------------------------------
  # Set a dummy terminal in case the script is run in batchmode via SSH
  # Otherwise the following error occurs:
  # "tput: No value for $TERM and no -T specified"
  [ -z "${TERM}" ] && export TERM="dumb"

  arg_width="${arg_width:-$(lib_msg_term_get --cols)}"

  #-----------------------------------------------------------------------------
  #  Split multiline string if necessary (recursive call)
  #-----------------------------------------------------------------------------
  if lib_core_str_is_multiline "${arg_string}"; then
    printf "${arg_string}" | while IFS= read -r line || [ -n "${line}" ]; do
      lib_msg_print_borderstring "${line}" "${arg_border}" "${arg_padding}" "${arg_width}"
    done
    return
  fi

  #-----------------------------------------------------------------------------
  #  Get string length
  #-----------------------------------------------------------------------------
  string_len="$(lib_core_str_get_length "${arg_string}")"

  #-----------------------------------------------------------------------------
  #  In case of an empty string do not set any padding
  #-----------------------------------------------------------------------------
  local add
  if [ "${string_len}" -eq 0 ]; then
    arg_padding="0"
    add="0"
  else
    arg_padding="${arg_padding:-1}"
    add="1"
  fi

  #-----------------------------------------------------------------------------
  #  Check requirements
  #-----------------------------------------------------------------------------
  #  Minimum line width: 2 border char (l+r) + 2x padding (l+r) + (1 char)
  #-----------------------------------------------------------------------------
  [ ${#arg_border} -eq 1 ]                                                  && \
  [ ${arg_padding} -ge 0 ] 2>/dev/null                                      && \
  [ ${arg_width} -ge $(( 2 + (arg_padding * 2) + add )) ] 2>/dev/null       || \
  return 1

  #-----------------------------------------------------------------------------
  #  Split the string if it does not find one line
  #-----------------------------------------------------------------------------
  #  Max str length per line = line width - padding (l+r) - border char (l+r)
  #-----------------------------------------------------------------------------
  string_len_max="$(( arg_width - (arg_padding * 2) - 2 ))"
  if [ ${string_len} -gt ${string_len_max} ]; then
    printf "%s" "${arg_string}" | fold -w ${string_len_max} -s | while IFS= read -r line || [ -n "${line}" ]; do
      line="$(lib_core_str_remove_trailing " " "${line}")"
      lib_msg_print_borderstring "${line}" "${arg_border}" "${arg_padding}" "${arg_width}"
    done
    return
  fi

  #-----------------------------------------------------------------------------
  #  Create left/right border string
  #-----------------------------------------------------------------------------
  #  Border length = ( line width - ( string length + padding (l+r) ) / 2
  #-----------------------------------------------------------------------------
  border_len="$(( (arg_width - ( string_len + (arg_padding * 2) )) / 2 ))"

  local i=1
  while [ $i -le ${border_len} ]; do
    border_str="${border_str}${arg_border}"
    i="$(( i + 1 ))"
  done

  #-----------------------------------------------------------------------------
  #  Create padding string
  #-----------------------------------------------------------------------------
  i=1
  while [ $i -le ${arg_padding} ]; do
    padding_str="${padding_str} "
    i="$(( i + 1 ))"
  done

  #-----------------------------------------------------------------------------
  #  Check if the text fits symmetrically into the line
  #-----------------------------------------------------------------------------
  if [ "$(( (string_len + arg_width) % 2 ))" -eq 0 ]; then
    # Yes
    printf "%s\n" "${border_str}${padding_str}${arg_string}${padding_str}\
${border_str}"
  else
    # No -> expand the right border by one additional border character
    printf "%s\n" \
      "${border_str}${padding_str}${arg_string}${padding_str}${border_str}\
${arg_border}"
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_msg_print_heading
#  DESCRIPTION:  Format a string as a heading
#      OUTPUTS:  Write formatted string to <stdout>
# PARAMETER  1:  Heading type (see case statement below)
#            2:  String to format
#            3:  Line width (optional, default is the terminal's window width)
#===============================================================================
lib_msg_print_heading() {
  local arg_type="$1"
  local arg_string="$2"
  local arg_width="$3"

  arg_type="${arg_type:---heading1}"

  local char_border       # Border character
  local padding_string    # Padding length (in spaces)
  local top_bottom_line   # Additional top and bottom line
  local padding_top       # Padding (in lines) from top to previous output
  local padding_bottom    # Padding (in lines) from bottom to next output

  case "${arg_type}" in
    -1|--heading1)
      char_border="="
      padding_string="5"
      top_bottom_line="1"
      padding_top="2"
      padding_bottom="1"
      ;;
    -100|--heading100)
      char_border="="
      padding_string="5"
      top_bottom_line="1"
      padding_top="0"
      padding_bottom="0"
      ;;
    -101|--heading101)
      char_border="="
      padding_string="5"
      top_bottom_line="1"
      padding_top="0"
      padding_bottom="1"
      ;;
    -110|--heading110)
      char_border="="
      padding_string="5"
      top_bottom_line="1"
      padding_top="1"
      padding_bottom="0"
      ;;
    -111|--heading111)
      char_border="="
      padding_string="5"
      top_bottom_line="1"
      padding_top="1"
      padding_bottom="1"
      ;;
    -120|--heading120)
      char_border="="
      padding_string="5"
      top_bottom_line="1"
      padding_top="2"
      padding_bottom="0"
      ;;
    -2|--heading2)
      char_border="-"
      padding_string="5"
      top_bottom_line="1"
      padding_top="1"
      padding_bottom="0"
      ;;
    -200|--heading200)
      char_border="-"
      padding_string="5"
      top_bottom_line="1"
      padding_top="0"
      padding_bottom="0"
      ;;
    -201|--heading201)
      char_border="-"
      padding_string="5"
      top_bottom_line="1"
      padding_top="0"
      padding_bottom="1"
      ;;
    -210|--heading210)
      char_border="-"
      padding_string="5"
      top_bottom_line="1"
      padding_top="1"
      padding_bottom="0"
      ;;
    -211|--heading211)
      char_border="-"
      padding_string="5"
      top_bottom_line="1"
      padding_top="1"
      padding_bottom="1"
      ;;
    -3|--heading3)
      char_border="_"
      padding_string="1"
      padding_top="1"
      padding_bottom="0"
      ;;
    -300|--heading300)
      char_border="_"
      padding_string="1"
      padding_top="0"
      padding_bottom="0"
      ;;
    -301|--heading301)
      char_border="_"
      padding_string="1"
      padding_top="0"
      padding_bottom="1"
      ;;
    -310|--heading310)
      char_border="_"
      padding_string="1"
      padding_top="1"
      padding_bottom="0"
      ;;
    -311|--heading311)
      char_border="_"
      padding_string="1"
      padding_top="1"
      padding_bottom="1"
      ;;
    -w|--warn)
      char_border="^"
      padding_string="1"
      top_bottom_line="1"
      arg_string="[WARNING] ${arg_string}"
      padding_top="1"
      padding_bottom="1"
      ;;
    -e|--error)
      char_border="!"
      padding_string="1"
      top_bottom_line="1"
      arg_string="[ERROR] ${arg_string}"
      padding_top="1"
      padding_bottom="1"
      ;;
    *)
      return 1
      ;;
  esac

  #-----------------------------------------------------------------------------
  #  Top padding
  #-----------------------------------------------------------------------------
  local i=1
  while [ $i -le ${padding_top} ]; do
    printf "\n"
    i="$(( i + 1 ))"
  done

  #-----------------------------------------------------------------------------
  #  Format and print string
  #-----------------------------------------------------------------------------
  if [ -n "${top_bottom_line}" ]; then
    lib_msg_print_borderstring "" "${char_border}" "" "${arg_width}"
  fi                                                                        && \

  lib_msg_print_borderstring                                                \
    "${arg_string}" "${char_border}" "${padding_string}" "${arg_width}"     && \

  if [ -n "${top_bottom_line}" ]; then
    lib_msg_print_borderstring "" "${char_border}" "" "${arg_width}"
  fi                                                                        && \

  #-----------------------------------------------------------------------------
  #  Bottom padding
  #-----------------------------------------------------------------------------
  i=1                                                                       && \
  while [ $i -le ${padding_bottom} ]; do
    printf "\n"
    i="$(( i + 1))"
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_msg_print_list
#  DESCRIPTION:  Format and print values from a list
# PARAMETER  1:  Mode, decides how the values listed in <3> are processed
#                  --ptr  list contains pointers
#                  --val  list contains values
#            2:  List containing pointers or values
#            3:  (Optional) Variable name prefix (only with '--ptr')
#            4:  Separator string between each value
#                (default: ' | ')
#            5:  (Optional) Surround each value by '[]'? (true|false)
#                (default: 'false')
#            6:  (Optional) Surround whole string by '{ }'? (true|false)
#                (default: 'true')
#      OUTPUTS:  Value list to <stdout>
#      EXAMPLE:  > PAR_VAL1="1"; PAR_VAL2="2"; PAR_VAL3="3"
#                > PAR_VAL_LIST="VAL1 VAL2 VAL3"
#                > lib_msg_print_list --ptr "${PAR_VAL_LIST}" "PAR_"
#                >> 1 | 2 | 3
#                > lib_msg_print_list --val "${PAR_VAL_LIST}"
#                >> VAL1 | VAL2 | VAL3
#===============================================================================
lib_msg_print_list() {
  local ARG_MODE_POINTER="--ptr"
  local ARG_MODE_VALUE="--val"
  local arg_mode="$1"

  local arg_list="$2"
  local arg_prefix="$3"
  local arg_str_separator="${4:- | }"
  local arg_br_val="${5:-false}"
  local arg_br_str="${6:-true}"

  lib_core_is --set "${arg_list}"                     && \
  lib_core_is --bool "${arg_br_val}" "${arg_br_str}"  && \
  __lib_msg_print_list "$@"
}

__lib_msg_print_list() {
  local ARG_MODE_POINTER="--ptr"
  local ARG_MODE_VALUE="--val"
  local arg_mode="$1"

  local arg_list="$2"
  local arg_prefix="$3"
  local arg_str_separator="${4:- | }"
  local arg_br_val="${5:-false}"
  local arg_br_str="${6:-true}"

  local br_val_l
  local br_val_r
  if ${arg_br_val}; then br_val_l="["; br_val_r="]"; fi

  local ptr
  local str
  case "${arg_mode}" in
    ${ARG_MODE_POINTER})
      for a in ${arg_list}; do
        ptr="${arg_prefix}${a}"
        if lib_core_is --varname "${ptr}"; then
          eval str=\"${str}${str:+${arg_str_separator}}${br_val_l}\${${ptr}}${br_val_r}\"
        fi
      done
      ;;

    ${ARG_MODE_VALUE})
      for a in ${arg_list}; do
        str="${str}${str:+${arg_str_separator}}${br_val_l}${a}${br_val_r}"
      done
      ;;

    *)
      return 1
      ;;
  esac

  local br_str_l
  local br_str_r
  if ${arg_br_str}; then br_str_l="{ "; br_str_r=" }"; fi
  printf "%s" "${br_str_l}${str}${br_str_r}"
}

lib_msg_print_list_ptr() {
  lib_msg_print_list --ptr "$@"
}

lib_msg_print_list_val() {
  lib_msg_print_list --val "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_msg_print_propvalue
#  DESCRIPTION:  Print a formatted table of property/value pairs to <stdout>
#
# PARAMETER  1:  Body alignment (--left|--center|--right)
#                (Default: '--left')
#
#            2:  Content alignment (--left|--center |--right)
#                (Default: '--center')
#
#            3:  Padding between property/value and the separator
#                character defined via parameter <5>
#                (>= 1, default '2')
#
#            4:  Line width
#                (Default value is the terminal's window width)
#
#            5:  Separator character (exactly one (1) character)
#                (Default ':')
#
#          6..:  Property/value pairs in the form of "[property]" "[value]"
#                if "[property]" is ...
#
#                           "" (empty) : line will not be printed
#                " " (space character) : print an empty line (do not forget
#                                        to add an empty "" for [value])
#
#                In case [property]/[value] are multiline strings:
#                This function will respect linebreaks. In case you want
#                this function to dynamically split your strings please
#                remove the linebreaks before by using
#                <lib_core_str_remove_newline> function.
#
#    IMPORTANT:  Your terminal window (or the width set via parameter <4>)
#                must meet a minimum size. For more information please
#                have a look in the function's section
#                "determine maximum property/value width" below.
#
#      EXAMPLE: 'lib_msg_print_propvalue --center --center "4" "" "=" \
#                 "a" "A" "b" "BBB" " " "" "ccc" "multiline<newline>string"'
#
#               results in the following output:
#                                a    =    A
#                                b    =    BBB
#
#                              ccc    =    multiline
#                                          string
#===============================================================================
lib_msg_print_propvalue()  {
  local WIDTH_MIN="15"  # Minimum property/value column width (in num of chars)

  local arg_align_body="${1:---left}"
  local arg_align_content="${2:---left}"
  local arg_padding="${3:-2}"
  local arg_width="$4"
  local arg_separator="${5:-:}"
  shift;shift;shift;shift;shift

  #-----------------------------------------------------------------------------
  #  Check requirements + content alignment
  #-----------------------------------------------------------------------------
  local prop_align
  local val_align
  case "${arg_align_body}" in
    -l|--left|-c|--center|-r|--right) ;;
    *) false ;;
  esac                                                                     && \
  case "${arg_align_content}" in
    -l|--left) prop_align="-"; val_align="-" ;;
    -c|--center) prop_align=""; val_align="-" ;;
    -r|--right) prop_align=""; val_align="" ;;
    *) false ;;
  esac                                                                     && \
  [ ${arg_padding} -ge 1 ] 2>/dev/null                                     && \
  [ ${#arg_separator} -eq 1 ] 2>/dev/null                                  && \
  [ $(( $# % 2 )) -eq 0 ]                                                  || \
  return

  #-----------------------------------------------------------------------------
  #  Get/Set line width
  #-----------------------------------------------------------------------------
  #  Set a dummy terminal in case the script is run in batchmode via SSH
  #  Otherwise the following error occurs:
  #    "tput: No value for $TERM and no -T specified"
  #-----------------------------------------------------------------------------
  [ -z "${TERM}" ] && export TERM="dumb"
  arg_width="${arg_width:-$(lib_msg_term_get --cols)}"                          || \
  return

  #-----------------------------------------------------------------------------
  #  Determine maximum property/value width
  #-----------------------------------------------------------------------------
  #    (Terminal|User-defined) window width      <arg_width>
  #  - 2x Padding width                       -  2x <arg_padding>
  #  - 1 (Separator character)                -  1
  #  - Minimum (value|property) width         -  <WIDTH_MIN>
  #-----------------------------------------------------------------------------
  #  = Maximum (property|value) width         =  <width_max>
  #-----------------------------------------------------------------------------
  local width_max
  width_max="$(( arg_width - (arg_padding * 2) - 1 - WIDTH_MIN ))"

  #-----------------------------------------------------------------------------
  #  Ensure that terminal (or user-defined) width is big enough
  #-----------------------------------------------------------------------------
  [ ${width_max} -ge ${WIDTH_MIN} ]                                         || \
  {
    local arg_width_min
    arg_width_min="$(( arg_width + ( WIDTH_MIN - width_max ) ))"
    lib_msg_echo --error \
      "Terminal's (or individually set) width is too small, minimum is <${arg_width_min}>."
    return 1
  }

  #-----------------------------------------------------------------------------
  #  Body alignment
  #-----------------------------------------------------------------------------
  local i=1
  local prop_width="0"
  local val_width="0"
  local OLDIFS="$IFS"
  local var
  case "${arg_align_body}" in
    -l|--left)
      #-------------------------------------------------------------------------
      #  -l|--left
      #-------------------------------------------------------------------------
      for var in "$@"; do
        if [ "$(( i % 2 ))" -ne "0" ]; then
          IFS="${LIB_C_STR_NEWLINE}"

          for line in ${var}; do
            if [ "${#line}" -gt "${prop_width}" ]; then
              if [ "${#line}" -lt "${width_max}" ]; then
                prop_width="${#line}"
              else
                prop_width="${width_max}"
                break
              fi
            fi
          done

          IFS="$OLDIFS"
        fi

        i="$(( i + 1 ))"
      done
      val_width="$(( arg_width - prop_width - (arg_padding * 2) - 1 ))"
      ;;

    -c|--center)
      #-------------------------------------------------------------------------
      #  -c|--center
      #-------------------------------------------------------------------------
      local prop_width_max  # Maximum property width
      local val_width_max   # Maximum value width
      local break="false"

      prop_width_max="${width_max}"
      val_width_max="${width_max}"
      local line
      local subline

      # Loop through property/value pairs
      for var in "$@"; do

        # Take care of multiline properties/values
        IFS="${LIB_C_STR_NEWLINE}"

        if  [ "$(( i % 2 ))" -ne "0" ] && \
            [ "${prop_width}" -lt "${prop_width_max}" ]; then
          #---------------------------------------------------------------------
          #  property
          #---------------------------------------------------------------------
          #  Find longest property (for loop's purpose is to take care
          #  of multiline strings, see <IFS> definition above)
          #---------------------------------------------------------------------
          for line in ${var}; do
            if [ "${#line}" -gt "${prop_width}" ]; then
              if [ "${#line}" -lt "${prop_width_max}" ]; then
                # Property width is below its allowed maximum
                # so we found a new maximum
                prop_width="${#line}"
              else
                # Property width is bigger than its maximum,
                # so lets split the string
                for subline in $(printf "%s" "${line}" | fold -w ${prop_width_max} -s); do
                  if [ "${#subline}" -gt "${prop_width}" ]; then
                    prop_width="${#subline}"
                    # Ensure that property length is not above defined maximum
                    if [ "${prop_width}" -eq "${prop_width_max}" ]; then
                      break="true"
                      break
                    fi
                  fi
                done
              fi

              # As property maximum is bigger now we have to reduce value's maximum
              val_width_max="$(( arg_width - (arg_padding * 2) - 1 - prop_width ))"

              # With very low property widths it can happen that the calculate
              # maximum is below the defined minimum
              if [ "${val_width_max}" -gt "${width_max}" ]; then
                val_width_max="${width_max}"
              fi

              # In case property's maximum has been reached
              if ${break}; then break; fi
            fi
          done

        elif [ "${val_width}" -lt "${val_width_max}" ]; then
          #---------------------------------------------------------------------
          #  value
          #---------------------------------------------------------------------
          for line in ${var}; do
            if [ "${#line}" -gt "${val_width}" ] ; then
              if [ "${#line}" -lt "${val_width_max}" ]; then
                val_width="${#line}"
              else
                for subline in $(printf "%s" "${line}" | fold -w ${val_width_max} -s); do
                  if [ "${#subline}" -gt "${val_width}" ]; then
                    val_width="${#subline}"
                    if [ "${val_width}" -eq "${val_width_max}" ]; then
                      break="true"
                      break
                    fi
                  fi
                done
              fi

              prop_width_max="$(( arg_width - (arg_padding * 2) - 1 - val_width ))"
              if [ "${prop_width_max}" -gt "${width_max}" ]; then
                prop_width_max="${width_max}"
              fi

              if ${break}; then break; fi
            fi
          done

        fi

        # Final loop procedures
        IFS="$OLDIFS"
        i="$(( i + 1 ))"
        break="false"
      done

      # Calculcate the "natural" width for property and value
      # as if there were no strings
      local prop_width_central
      local val_width_central
      prop_width_central="$(( ( arg_width / 2 ) - arg_padding ))"
      val_width_central="${prop_width_central}"
      prop_width_central="$(( prop_width_central - ( 1 - arg_width % 2 ) ))"

      # Calculate the shift (from the center to the right)
      local diff
      local shift
      diff="$(( prop_width - val_width ))"
      shift="$(( diff / 2 + $(lib_math_sign "${diff}") * ( arg_width % 2 ) * ( diff % 2 ) ))"

      # In case of Left/right content alignment we have to add additional padding
      local buffer_left="0"
      local buffer_right="0"

      if [ "${prop_width}" -gt "${prop_width_central}" ]; then
        #-----------------------------------------------------------------------
        #  Property's width exceeded default value (= shift to the right)
        #-----------------------------------------------------------------------
        shift="$(( shift - ( prop_width - prop_width_central ) ))"

        # Proceed depending on the content's alignment
        case "${arg_align_content}" in
          -l|--left)
            buffer_left="$(( val_width_max - val_width - $(lib_math_abs "${shift}") ))"
            val_width="$(( val_width + $(lib_math_abs "${shift}") ))"
            ;;

          -c|--center)
            val_width="${val_width_max}"
            prop_width="$(( prop_width + shift ))"
            val_width="$(( val_width - shift ))"
            ;;

          -r|--right)
            prop_width="$(( prop_width + shift ))"
            buffer_right="$(lib_math_abs "${shift}")"
            ;;
        esac

      elif [ "${val_width}" -gt "${val_width_central}" ]; then
        #-----------------------------------------------------------------------
        #  Value's width exceeded default value (= shift to the left)
        #-----------------------------------------------------------------------
        shift="$(( shift + ( val_width - val_width_central ) ))"

        # Proceed depending on the content's alignment
        case "${arg_align_content}" in
          -l|--left)
            buffer_left="$(( prop_width_max - prop_width - $(lib_math_abs "${shift}") ))"
            val_width="$(( val_width + $(lib_math_abs "${shift}") ))"
            ;;

          -c|--center)
            prop_width="${prop_width_max}"
            prop_width="$(( prop_width + shift ))"
            val_width="$(( val_width - shift ))"
            ;;

          -r|--right)
            prop_width="$(( prop_width_max + shift ))"
            buffer_right="$(lib_math_abs "${shift}")"
            ;;
        esac

      else
        #-----------------------------------------------------------------------
        #  Property's and value's width lower than their default values
        #  (= shift to the left or to the right)
        #-----------------------------------------------------------------------
        # TODO: not working with e.g. '--left' '--center'
        prop_width="${prop_width_central}"
        val_width="${val_width_central}"

        prop_width="$(( prop_width + shift ))"
        val_width="$(( val_width - shift ))"
      fi
      ;;

    -r|--right)
      #-------------------------------------------------------------------------
      #  -r|--right
      #-------------------------------------------------------------------------
      for var in "$@"; do
        if [ "$(( i % 2 ))" -eq "0" ]; then
          IFS="${LIB_C_STR_NEWLINE}"

          for line in ${var}; do
            if [ "${#line}" -gt "${val_width}" ] ; then
              if [ "${#line}" -lt "${width_max}" ]; then
                val_width="${#line}"
              else
                val_width="${width_max}"
                break
              fi
            fi
          done

          IFS="$OLDIFS"
        fi

        i="$(( i + 1 ))"
      done

      prop_width="$(( arg_width - val_width - (arg_padding * 2) - 1 ))"
      ;;

  esac

  #-----------------------------------------------------------------------------
  #  Print property/value pairs to stdout
  #-----------------------------------------------------------------------------
  local str_prop
  local str_val
  while [ $# -ge 2 ]; do
    # Split property/value into multiline strings if they are too long
    str_prop="$(printf "%s" "$1" | fold -w ${prop_width} -s)"
    str_val="$(printf "%s" "$2" | fold -w ${val_width} -s)"

    # Only print property/value pair in case property is not empty ...
    if [ -n "${str_prop}" ]; then
      # ... but allow the user to add an empty line by setting property
      # setting property to just a space character ' '
      if [ "$(printf "%s" "${str_prop}" | tr -s " ")" = " " ];then
        printf "\n"
      else
        # Property+Value line

        # Variables for multiline property/value
        i=1
        local line_prop
        local line_val
        IFS="${LIB_C_STR_NEWLINE}"

        # Process multiline property
        printf "%s" "${str_prop}" | while IFS= read -r line_prop || [ -n "${line_prop}" ]; do
          line_val="$(printf "%s" "${str_val}" | tail -n+${i} | head -n1)"
          line_prop="$(lib_core_str_remove_trailing " " "${line_prop}")"
          line_val="$(lib_core_str_remove_trailing " " "${line_val}")"
          #printf "%${prop_align}${prop_width}s%-${arg_padding}s%s%-${arg_padding}s%${val_align}${val_width}s\n" "${line_prop}" " " "${arg_separator}" " " "${line_val}"
          printf "%${buffer_left}s%${prop_align}${prop_width}s%-${arg_padding}s%s%-${arg_padding}s%${val_align}${val_width}s%${buffer_right}s\n" "" "${line_prop}" " " "${arg_separator}" " " "${line_val}" ""
          i="$(( i + 1 ))"
        done

        # Process multiline value
        printf "%s" "${str_val}" | tail -n+$((i+1)) | while IFS= read -r line_val || [ -n "${line_val}" ]; do
          line_val="$(lib_core_str_remove_trailing " " "${line_val}")"
          #printf "%${prop_align}${prop_width}s%-${arg_padding}s%s%-${arg_padding}s%${val_align}${val_width}s\n" "" " " " " " " "${line_val}"
          printf "%${buffer_left}s%${prop_align}${prop_width}s%-${arg_padding}s%s%-${arg_padding}s%${val_align}${val_width}s%${buffer_right}s\n" "" "" " " " " " " "${line_val}" ""
        done

        IFS="$OLDIFS"
      fi
    fi
    shift;shift
  done
}

#===============================================================================
#  FUNCTIONS (MISCELLANEOUS)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_msg_term_get
#  DESCRIPTION:  Get current terminal window's settings
# PARAMETER  1:  --cols         Number of columns
#                --lines|--rows Number of rows
#===============================================================================
lib_msg_term_get() {
  local arg_select="$1"

  local result
  if command -v "tput" >/dev/null; then
    case "${arg_select}" in
      --cols) result="$(tput cols)" ;;
      --lines|--rows) result="$(tput lines)" ;;
      *) return 1 ;;
    esac
  elif command -v "stty" >/dev/null; then
    local size
    size=
    case "${arg_select}" in
      --cols) result="$(stty size 2>/dev/null | cut -d' ' -f2)" ;;
      --lines|--rows) result="$(stty size 2>/dev/null | cut -d' ' -f1)" ;;
      *) return 1 ;;
    esac
  else
    return 1
  fi

  # TODO: Temporarily decreased by one as in some cases the size
  #       may not be correct, e.g. when piping to 'less' under Alpine Linux v3.17
  case "${arg_select}" in
    --cols) [ -n "${result}" ] && result="$(( result - 1 ))" ;;
  esac

  [ -n "${result}" ] && printf "%s\n" "${result}"
}