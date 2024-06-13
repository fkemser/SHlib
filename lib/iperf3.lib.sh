#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/iperf3.lib.sh
#
#        USAGE:   . iperf3.lib.sh
#
#  DESCRIPTION:   Shell library containing 'iperf3'-related functions
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
#         NAME:  lib_iperf3
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_iperf3() {
  return 0
}

#===  FUNCTION  ================================================================
#         NAME:  lib_iperf3_log_parse_transfer_rate
#  DESCRIPTION:  Extract transfer rate from an ipferf3 log
# PARAMETER  1:  Selector (-r|-rx|--receiver||-s|-tx|--sender)
#            2:  iperf3 file
#            3:  Output unit (default: 'Mb'), in
#                Bits (b|kb|Mb|Gb|Tb|Pb|Eb|Zb|Yb)
#      OUTPUTS:  Write transfer rate to <stdout>
#===============================================================================
lib_iperf3_log_parse_transfer_rate() {
  local arg_select="$1"
  local arg_file="$2"
  local arg_unit="${3:-Mb}"

  lib_core_is --file "${arg_file}" || return

  local str
  case "${arg_select}" in
    -r|--rx|--receiver)
      str="$(\
        sed -n '/^\(- \)\{1,\}-$/{n;n;p;n;p}' "${arg_file}" \
          | grep "receiver"                                 \
          | tr -s " ")"
      ;;

    -s|--tx|--sender)
      str="$(\
        sed -n '/^\(- \)\{1,\}-$/{n;n;p;n;p}' "${arg_file}" \
          | grep "sender"                                   \
          | tr -s " ")"
      ;;

    *)
      return 1
      ;;
  esac

  local num
  local unit
  num="$(printf "%s" "${str}" | cut -d " " -f7)"
  unit="$(printf "%s" "${str}" | cut -d " " -f8)"

  case "${unit}" in
    Kbits/sec) unit="kb" ;;
    Mbits/sec) unit="Mb" ;;
    *) return 1 ;;
  esac

  lib_math_convert_unit "${num}" "${unit}" "${arg_unit}"
}
