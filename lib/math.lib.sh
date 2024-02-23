#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/math.lib.sh
#
#        USAGE:   . math.lib.sh
#
#  DESCRIPTION:   Shell library providing mathematical functions and operations,
#                 such as
#                   - advanced calculation using 'bc'
#                     (supporting floating point numbers),
#                   - converting units, e.g. from 'MB' into 'GB',
#                   - checking if a number is within a specified range,
#                   - functions like 'abs' or 'sign'.
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
if lib_math 2>/dev/null; then return; fi

#===============================================================================
#  IMPORT
#===============================================================================
#-------------------------------------------------------------------------------
#  Load libraries
#-------------------------------------------------------------------------------
for lib in core; do
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
#         NAME:  lib_math
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_math() {
  return 0
}

#===  FUNCTION  ================================================================
#         NAME:  lib_math_abs
#  DESCRIPTION:  Calculate absolute value of one or more given values (abs(x))
# PARAMETER
#         1...:  Number (positive/negative integer or floating point)
#      OUTPUTS:  Absolute number(s) to <stdout> (separated by newline)
#                (empty line if parameter is not a number)
#===============================================================================
lib_math_abs() {
  local args
  lib_core_args_passed "$@" && args="$*" || args="$(xargs)"

  for var in ${args}; do
    if lib_core_is --number "${var}"; then
      printf "%s\n" "${var#-}"
    else
      printf "\n"
    fi
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_math_calc
#  DESCRIPTION:  Perform a calculation supporting decimal places by using <bc>
# PARAMETER  1:  Mathematical operation, e.g. "2 * 4.3"
#                (For more information please run 'man bc')
#            2:  (Optional) Number of decimal places  (default: '6')
#      OUTPUTS:  Result to <stdout>
#===============================================================================
lib_math_calc() {
  lib_core_is --cmd "bc" || return

  local arg_op="$1"
  local arg_scale="${2:-6}"

  lib_core_is --set "${arg_op}"         && \
  lib_core_is --int-pos0 "${arg_scale}" || \
  return

  __lib_math_calc "$@"
}

__lib_math_calc() {
  local arg_op="$1"
  local arg_scale="${2:-6}"

  # "/1" needed, otherwise "scale=0" will not work
  echo "scale=${arg_scale} ; (${arg_op}) / 1" | bc  2>/dev/null
}

#===  FUNCTION  ================================================================
#         NAME:  lib_math_convert_unit
#  DESCRIPTION:  Convert a given value (integer/float) from one unit to another
# PARAMETER  1:  Integer or float number
#            2:  Source unit (*)
#            3:  Destination unit (*)
#           (*)  In Bits (b|kb|Mb|Gb|Tb|Pb|Eb|Zb|Yb), or
#                Bytes (B|kB|MB|GB|TB|PB|EB|ZB|YB)
#      OUTPUTS:  Writes converted value to <stdout> (only the number, no unit)
#===============================================================================
lib_math_convert_unit() {
  local arg_value="$1"
  local arg_unit_source="$2"
  local arg_unit_dest="$3"

  local fact                                # factor
  local div                                 # divisor

  local unit_b="1"                          # bit
  local unit_kb="1000"                      # kilobit
  local unit_Mb="1000000"                   # megabit
  local unit_Gb="1000000000"                # gigabit
  local unit_Tb="1000000000000"             # terabit
  local unit_Pb="1000000000000000"          # petabit
  local unit_Eb="1000000000000000000"       # exabit
  local unit_Zb="1000000000000000000000"    # zettabit
  local unit_Yb="1000000000000000000000000" # yottabit

  local unit_B="8"                          # byte
  local unit_kB="8000"                      # kilobyte
  local unit_MB="8000000"                   # megabyte
  local unit_GB="8000000000"                # gigabyte
  local unit_TB="8000000000000"             # terabyte
  local unit_PB="8000000000000000"          # petabyte
  local unit_EB="8000000000000000000"       # exabyte
  local unit_ZB="8000000000000000000000"    # zettabyte
  local unit_YB="8000000000000000000000000" # yottabyte

  lib_core_is --unit "${arg_unit_source}" "${arg_unit_dest}"  || \
  return

  # Set factor/divisor depending on passed argument
  eval fact="\${unit_${arg_unit_source}}"
  eval div="\${unit_${arg_unit_dest}}"

  local result=""
  if lib_core_is --int "${arg_value}"; then
    result="$(( arg_value * fact / div ))"
  elif lib_core_is --float "${arg_value}"; then
    result="$(lib_math_calc "${arg_value} * ${fact} / ${div}")" || \
    return
  else
    return 1
  fi

  printf "%s\n" "${result}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_math_is_within_range
#  DESCRIPTION:  Check if an (integer or float) number is between a given range
# PARAMETER  1:  Minimum (optional)
#            2:  Value
#            3:  Maximum (optional)
#   RETURNS  0:  Value is between range
#            1:  Value is NOT between range
#===============================================================================
lib_math_is_within_range() {
  local arg_min="$1"
  local arg_value="$2"
  local arg_max="$3"

  lib_core_is --set "${arg_value}" || \
  return

  local float="false"
  local arg
  for arg in "${arg_min}" "${arg_value}" "${arg_max}"; do
    lib_core_is --empty "${arg}"    || \
    lib_core_is --int "${arg}"      || \
    { lib_core_is --float "${arg}"  && \
      float="true"
    }                               || \
    return
  done

  if ${float}; then
    lib_core_is --empty "${arg_min}"                                              || \
    [ "$(lib_math_sign "$(lib_math_calc "${arg_value} - ${arg_min}")")" -ge "0" ] || \
    return

    lib_core_is --empty "${arg_max}"                                              || \
    [ "$(lib_math_sign "$(lib_math_calc "${arg_max} - ${arg_value}")")" -ge "0" ] || \
    return

  else
    lib_core_is --empty "${arg_min}"                || \
    [ "${arg_value}" -ge "${arg_min}" ] 2>/dev/null || \
    return

    lib_core_is --empty "${arg_max}"                || \
    [ "${arg_value}" -le "${arg_max}" ] 2>/dev/null || \
    return
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_math_is_within_range_u
#  DESCRIPTION:  Like <lib_math_is_within_range()> but with units. Please have
#                a look at <lib_math_convert_unit()> for the list of available
#                units.
# PARAMETER  1:  Minimum (optional)
#            2:  Value
#            3:  Maximum (optional)
#   RETURNS  0:  Value is between range
#            1:  Value is NOT between range
#===============================================================================
lib_math_is_within_range_u() {
  local arg_min="$1"
  local arg_value="$2"
  local arg_max="$3"

  local num    # Value only
  local unit   # Unit only

  if lib_core_is --set "${arg_min}" && ! lib_core_is --number "${arg_min}"; then
    num="${arg_min%%[^[:digit:].e+-]*}"
    unit="${arg_min##*[[:space:][:digit:]]}"
    arg_min="$(lib_math_convert_unit "${num}" "${unit}" "b")" || return
  fi

  if lib_core_is --set "${arg_value}" && ! lib_core_is --number "${arg_value}"
  then
    num="${arg_min%%[^[:digit:].e+-]*}"
    unit="${arg_value##*[[:space:][:digit:]]}"
    arg_value="$(lib_math_convert_unit "${num}" "${unit}" "b")" || return
  fi

  if lib_core_is --set "${arg_max}" && ! lib_core_is --number "${arg_max}"; then
    num="${arg_min%%[^[:digit:].e+-]*}"
    unit="${arg_max##*[[:space:][:digit:]]}"
    arg_max="$(lib_math_convert_unit "${num}" "${unit}" "b")" || return
  fi

  lib_math_is_within_range "${arg_min}" "${arg_value}" "${arg_max}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_math_sign
#  DESCRIPTION:  Get sign of one or more given values (sign(x))
# PARAMETER
#         1...:  Number (integer or floating point)
#      OUTPUTS:  One of the following results to <stdout>:
#                  '+1'   if  parameter > 0
#                  '0'    if  parameter = 0
#                  '-1'   if  parameter < 0
#                (multiple values separated by newline)
#                (empty line if parameter is not a number)
#===============================================================================
lib_math_sign() {
  local args
  lib_core_args_passed "$@" && args="$*" || args="$(xargs)"

  local var
  local i=1
  for var in ${args}; do
    if [ $i -gt 1 ]; then printf "\n"; fi

    lib_core_is --number "${var}" || \
    continue

    case "${var}" in
      [+-]0|0) printf "%s" "0" ;;
      -?*) printf "%s" "-1" ;;
      *) printf "%s" "+1" ;;
    esac

    i="$(( i + 1 ))"
  done
}
