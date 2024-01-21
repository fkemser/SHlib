#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/nm.lib.sh
#
#        USAGE:   . nm.lib.sh
#
#  DESCRIPTION:   Shell library containg 'NetworkManager (NM)' related functions
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
#         NAME:  lib_nm
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_nm() {
  return 0
}

#===  FUNCTION  ================================================================
#         NAME:  lib_nm_con_exists
#  DESCRIPTION:  Check if a a connection exists and optionally
#                check if it's active
# PARAMETER  1:  Connection ID
#            2:  Connection type alias (optional, can be used as a "filter")
#                (see 'man nm-settings-nmcli' or
#                https://developer-old.gnome.org/NetworkManager/stable/nm-settings-nmcli.html)
#            3:  Check if connection is active? (true|false)
#   RETURNS  0:  Connection exists
#                (and is active, in case param <3> is set to 'true')
#            1:  Connection does not exist
#            2:  Connection does exist but is not active
#                (in case param <3> is set to 'true')
#===============================================================================
lib_nm_con_exists() {
  local arg_connid="$1"
  local arg_type="${2:-.*}"
  local arg_active="${3:-false}"

  lib_core_is --cmd "nmcli"           && \
  lib_core_is --set "${arg_connid}"   && \
  lib_core_is --bool "${arg_active}"  || \
  return

  if nmcli -g type,name con show \
      | grep -q -e "^${arg_type}\:${arg_connid}\$"; then
    if ${arg_active}; then
      if ! nmcli -g type,name con show --active \
          | grep -q -e "^${arg_type}\:${arg_connid}\$"; then
        return 2
      fi
    fi
  else
    return 1
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_nm_con_get
#  DESCRIPTION:  Get a certain connection setting/property
# PARAMETER  1:  Connection ID
#            2:  Property (see 'man nm-settings-nmcli' or
#                https://developer-old.gnome.org/NetworkManager/stable/nm-settings-nmcli.html)
#            3:  Dictionary key (optional, only in case arg <2> consists of
#                key/value pairs and you would like to extract a specific value,
#                e.g. 'user' from 'vpn.data')
#      OUTPUTS:  Setting/Property
#===============================================================================
lib_nm_con_get() {
  local arg_connid="$1"
  local arg_property="$2"
  local arg_key="$3"

  lib_core_is --cmd "nmcli"           && \
  lib_core_is --set "${arg_connid}"   && \
  lib_core_is --set "${arg_property}" && \

  if lib_core_is --empty "${arg_key}"; then
    nmcli -g "${arg_property}" con show "${arg_connid}" 2>/dev/null
  else
    nmcli -g "${arg_property}" con show "${arg_connid}" 2>/dev/null \
      | sed -ne "s/^\(.\{1,\},[[:space:]]\{1,\}\)\{0,1\}${arg_key}[[:space:]]\{1,\}=[[:space:]]\{1,\}\([^,]*\)\(,.\{1,\}\)\{0,1\}\$/\2/p"
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_nm_con_list
#  DESCRIPTION:  List connections (optionally filtered)
# PARAMETER  1:  Connection type alias (optional, can be used as a "filter")
#                (see 'man nm-settings-nmcli' or
#                https://developer-old.gnome.org/NetworkManager/stable/nm-settings-nmcli.html)
#            2:  Only show active connections? (true|false)
#      OUTPUTS:  Connection name(s) separated by newline
#===============================================================================
lib_nm_con_list() {
  local arg_type="${1:-.*}"
  local arg_active="${2:-false}"

  lib_core_is --cmd "nmcli"           && \
  lib_core_is --bool "${arg_active}"  || \
  return

  local nm_active
  if ${arg_active}; then nm_active="--active"; fi

  nmcli -g type,name con show ${nm_active}  \
    | grep -e "^${arg_type}:"               \
    | cut -d":" -f2-
}

#===  FUNCTION  ================================================================
#         NAME:  lib_nm_con_modify
#  DESCRIPTION:  Modify a certain connection setting/property
# PARAMETER  1:  Connection ID
#            2:  Property (see 'man nm-settings-nmcli' or
#                https://developer-old.gnome.org/NetworkManager/stable/nm-settings-nmcli.html)
#            3:  Dictionary key (optional, only in case arg <2> consists of
#                key/value pairs and you would like to change a specific value,
#                e.g. key 'user' from property 'vpn.data')
#            4:  New (property or key) value
#   RETURNS  0:  OK
#         1...:  Connection could not be modified (see nmcli's output)
#===============================================================================
lib_nm_con_modify() {
  local arg_connid="$1"
  local arg_property="$2"
  local arg_key="$3"
  local arg_newval="$4"

  lib_core_is --cmd "nmcli"           && \
  lib_core_is --set "${arg_connid}"   && \
  lib_core_is --set "${arg_property}" && \
  lib_core_is --set "${arg_newval}"   || \
  return

  if lib_core_is --empty "${arg_key}"; then
    nmcli con modify "${arg_connid}" "${arg_property}" "${arg_newval}"
  else
    nmcli con modify "${arg_connid}" +${arg_property} "${arg_key}"="${arg_newval}"
  fi
}
