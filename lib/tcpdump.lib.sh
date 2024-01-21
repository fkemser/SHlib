#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/tcpdump.lib.sh
#
#        USAGE:   . tcpdump.lib.sh
#
#  DESCRIPTION:   Shell library containg 'tcpdump'-related functions
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
if lib_tcpdump 2>/dev/null; then return; fi

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
#         NAME:  lib_tcpdump
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_tcpdump() {
  return 0
}

#===  FUNCTION  ================================================================
#         NAME:  lib_tcpdump_parse_logfile
#  DESCRIPTION:  Parse tcpdump logfile
# PARAMETER  1:  --data     total amount of recorded data (in bytes)
#                --duration duration (in s) of the transmission
#                --start    timestamp (UNIX Epoch) of first recorded package
#                --stop     timestamp (UNIX Epoch) of last recorded package
#            2:  tcpdump file
#===============================================================================
lib_tcpdump_parse_logfile() {
  local arg_select="$1"
  local arg_file="$2"

  lib_core_is --file "${arg_file}"  && \
  lib_core_is --cmd "awk"           || \
  return

  local t_start
  local t_stop
  local duration
  local data_transferred

  t_start="$(head -3 "${arg_file}" | tail -1 | cut -d" " -f1)"
  t_stop="$(tail -5 "${arg_file}" | head -1 | cut -d" " -f1)"

  duration="$(lib_math_calc "${t_stop} - ${t_start}" "6")"      && \
  data_transferred="$(                          \
    tail -n +3 "${arg_file}"                    \
      | head -n -4                              \
      | awk '{ sum += $7 } END { print sum }')"                 && \

  case "${arg_select}" in
    --data) printf "%s" "${data_transferred}" ;;
    --duration) printf "%s" "${duration}" ;;
    --start) printf "%s" "${t_start}" ;;
    --stop) printf "%s" "${t_stop}" ;;
    *) return 1 ;;
  esac
}
