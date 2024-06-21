#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/net.lib.sh
#
#        USAGE:   . net.lib.sh
#
#  DESCRIPTION:   Shell library containing network related functions, such as
#                   - checking an interface's status,
#                   - changing an interface's IP address,
#                   - retrieving interface statistics,
#                   - creating/removing bridges,
#                   - performing DNS lookups.
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
if lib_net 2>/dev/null; then return; fi

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
#         NAME:  lib_net
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_net() {
  return 0
}

#===============================================================================
#  FUNCTIONS (BRIDGES)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_net_bridge_create
#  DESCRIPTION:  Create a network bridge and attach one or more physical
#                interfaces to it
# PARAMETER  1:  Bridge name
#            2:  Physical interface(s) that will be attached to the bridge
#                (multiple interfaces separated by space ' ')
#            3:  (Optional) Transfer interface's ip address to bridge?
#                (true|false) (default: 'true')
#            4:  (Optional) Disable STP on bridge? (true|false)
#                (default: 'false')
#   RETURNS  0:  Bridge created
#            1:  Bridge already exists or could not be created
#===============================================================================
lib_net_bridge_create() {
  local arg_bridge="$1"
  local arg_interfaces="$2"
  local arg_move_addr="${3:-true}"
  local arg_disable_stp="${4:-false}"

  lib_core_is --cmd ip bridge                                 && \
  lib_core_is --not-empty "${arg_bridge}"                     && \
  ! lib_core_is --bridge "${arg_bridge}"                      && \
  lib_core_is --iface ${arg_interfaces}                       && \
  lib_core_is --bool "${arg_move_addr}" "${arg_disable_stp}"  || \
  return

  __lib_net_bridge_create "$@"
}

__lib_net_bridge_create() {
  local arg_bridge="$1"
  local arg_interfaces="$2"
  local arg_move_addr="${3:-true}"
  local arg_disable_stp="${4:-false}"

  # Create network bridge
  lib_core_sudo ip link add name "${arg_bridge}" type bridge  && \
  lib_core_sudo ip link set "${arg_bridge}" up                && \

  # Add physical interfaces
  local addr                                                  && \
  local interface                                             && \
  for interface in ${arg_interfaces}; do
    lib_core_sudo ip link set "${interface}" up
    addr="$(lib_net_iface_get_ip "${interface}")"
    lib_core_sudo ip link set "${interface}" master "${arg_bridge}"

    # (Optionally) disable STP
    if ${arg_disable_stp}; then
      lib_core_sudo ip link set "${interface}" type bridge_slave state 0
    fi

    # (Optionally) transfer IP address to bridge
    if ${arg_move_addr} && lib_core_is --not-empty "${addr}"; then
      # First remove address from the physical interface ...
      [ "$(lib_net_iface_get_ip "${interface}")" = "${addr}" ] && \
        lib_net_iface_ip --del "${interface}" "${addr}"

      # ... then add address to the bridge
      lib_net_iface_ip --add "${arg_bridge}" "${addr}"
    fi
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_bridge_get_members
#  DESCRIPTION:  Get network bridge members
# PARAMETER  1:  Bridge name
#      OUTPUTS:  Bridge members, one entry per line to <stdout>
#===============================================================================
lib_net_bridge_get_members() {
  local arg_bridge="$1"

  lib_core_is --bridge "${arg_bridge}" && \
  ls -1 "/sys/class/net/${arg_bridge}/brif"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_bridge_remove
#  DESCRIPTION:  Remove a network bridge
# PARAMETER  1:  Bridge name
#            2:  (Optional) Transfer bridge's ip address to interface?
#                (true|false) (default: 'true')
#   RETURNS  0:  Bridge removed
#            1:  Bridge does not exist or could not be removed
#===============================================================================
lib_net_bridge_remove() {
  local arg_bridge="$1"
  local arg_move_addr="${2:-true}"

  #-----------------------------------------------------------------------------
  #  Check requirements
  #-----------------------------------------------------------------------------
  lib_core_is --cmd "ip"              && \
  lib_core_is --bridge "${arg_bridge}"  && \
  lib_core_is --bool "${arg_move_addr}" || \
  return

  if ${arg_move_addr}; then
    #---------------------------------------------------------------------------
    #  Get first bridge member and bridge's IP address
    #---------------------------------------------------------------------------
    local addr
    local member_first
    addr="$(lib_net_iface_get_ip "${arg_bridge}")"
    member_first="$(lib_net_bridge_get_members "${arg_bridge}" | head -n 1)"
  fi

  #-----------------------------------------------------------------------------
  #  Remove bridge
  #-----------------------------------------------------------------------------
  lib_core_sudo ip link delete "${arg_bridge}" type bridge  && \

  #-----------------------------------------------------------------------------
  #  (Optionally) re-transfer IP address to first bridge member
  #-----------------------------------------------------------------------------
  if ${arg_move_addr} && lib_core_is --not-empty "${addr}"; then
    lib_net_iface_is --up "${member_first}" && \
    lib_net_iface_ip --add "${member_first}" "${addr}"
  fi
}

#===============================================================================
#  FUNCTIONS (DNS)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_net_dns_resolve
#  DESCRIPTION:  Resolve a given hostname, FQDN, SRV record, into IP address(es)
#                (automatically detect the type of the input string)
# PARAMETER  1:  IP protocol version
#                  --ip4|--inet  IPv4 (default)
#                  --ip6|--inet6 IPv6
#            2:  String to resolve, can be a ...
#                  - hostname, e.g. 'host1'
#                    (will be expanded by using 'domain' and 'search' option
#                     in '/etc/resolv.conf')
#                  - FQDN (A), e.g. 'www.example.com'
#                  - FQDN (SRV), e.g. '_ldap._tcp.example.com'
#            3:  DNS (dig) query timeout (in s, default: '2')
#            4:  DNS (dig) query tries (default: '2')
#      OUTPUTS:  Resolved IP address(es) separated by newline
#   RETURNS  0:  OK
#            1:  Input string could not be resolved
#===============================================================================
lib_net_dns_resolve() {
  local arg_ipv="${1:---ip4}"
  local arg_resolve="$2"
  local arg_time="${3:-2}"
  local arg_tries="${4:-2}"

  lib_core_is --cmd "dig" || return

  if lib_core_regex --fqdn "${arg_resolve}"; then
    __lib_net_dns_resolve \
      --fqdn "${arg_ipv}" "${arg_resolve}" "${arg_time}" "${arg_tries}"
  elif lib_core_regex --dns-srv "${arg_resolve}"; then
    __lib_net_dns_resolve \
      --srv "${arg_ipv}" "${arg_resolve}" "${arg_time}" "${arg_tries}"
  elif lib_core_regex --hostname "${arg_resolve}"; then
    __lib_net_dns_resolve \
      --hostname "${arg_ipv}" "${arg_resolve}" "${arg_time}" "${arg_tries}"
  else
    return 1
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  __lib_net_dns_resolve
#  DESCRIPTION:  Resolve a given hostname, FQDN, SRV record, into IP address(es)
# PARAMETER  1:  Input type
#                  --fqdn        FQDN, e.g. 'www.example.com' (default)
#                  --hostname    hostname, e.g. 'host1' (will be expanded
#                               by using 'domain' and 'search' option in
#                               '/etc/resolv.conf')
#                  --srv         SRV record FQDN, e.g. '_ldap._tcp.example.com'
#            2:  IP protocol version
#                  --ip4|--inet  IPv4 (default)
#                  --ip6|--inet6 IPv6
#            3:  String to resolve
#            4:  DNS (dig) query timeout (in s, default: '5')
#            5:  DNS (dig) query tries (default: '3')
#      OUTPUTS:  All resolved IP address(es) separate by newline
#   RETURNS  0:  OK
#            1:  String could not be resolved
#===============================================================================
__lib_net_dns_resolve() {
  local arg_type_input="${1:---fqdn}"
  local arg_type_output="${2:---ip4}"
  local arg_resolve="$3"
  local arg_time="${4:-5}"
  local arg_tries="${5:-3}"

  local list_ip=""
  local queryopts="+search +short +time=${arg_time} +tries=${arg_tries}"

  case "${arg_type_input}" in
    --fqdn|--hostname)
      local record
      case "${arg_type_output}" in
        --ip4|--inet) record="A" ;;
        --ip6|--inet6) record="AAAA" ;;
        *) return 1 ;;
      esac

      #-------------------------------------------------------------------------
      #  'result' can contain also CNAMEs (FQDNs) => filter for IPs only
      #-------------------------------------------------------------------------
      local result
      for result in $(dig "${arg_resolve}" "${record}" ${queryopts}); do
        lib_core_regex "${arg_type_output}" "${result}" && \
        list_ip="${list_ip}${result}\n"
      done
      ;;

    --srv)
      #-------------------------------------------------------------------------
      #  SRV record contains only FQDNs => recursively resolve
      #-------------------------------------------------------------------------
      local fqdn
      local result
      for fqdn in $(dig "${arg_resolve}" SRV ${queryopts} | cut -d " " -f 4); do
        result="$(__lib_net_dns_resolve --fqdn "${arg_type_output}" "${fqdn}" "${arg_time}" "${arg_tries}")" && \
        list_ip="${list_ip}${result}\n"
      done
      ;;

    *)
      return 1
      ;;
  esac

  lib_core_is --not-empty "${list_ip}" && printf "${list_ip}"
}

#===============================================================================
#  FUNCTIONS (INTERFACE)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_net_iface_get_sysfs / lib_net_iface_get_sysfs_statistics
#
#  DESCRIPTION:  Get information about network interface using
#                Linux kernel's <sysfs-class-net> / <sysfs-class-net-statistics>
#
# PARAMETER  1:  Sysfs file within </sys/class/net/<parameter 2>/> or
#                </sys/class/net/<parameter 2>/statistics>
#
#                For possible values, please have a look at:
#                  https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-net
#                  https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-net-statistics
#
#                You can either use the file names as they are, e.g. 'address'
#                or use them with the prefix '--', e.g. '--address'.
#                You are allowed to use '-' instead of '_' meaning you can use
#                '--tx-queue-len' instead of 'tx_queue_len'.
#
#            2:  Network interface
#
#      OUTPUTS:  Sysfs file content to <stdout>. For more information on how
#                to interpret the content please have a look at the links above.
#
#   RETURNS  0:  OK
#            1:  Interface or file does not exist
#===============================================================================
lib_net_iface_get_sysfs() {
  lib_core_sysfs_get "/sys/class/net/$2" "$1"
}

lib_net_iface_get_sysfs_statistics() {
  lib_core_sysfs_get "/sys/class/net/$2/statistics" "$1"
}
lib_net_iface_get_stats() {
  lib_net_iface_get_sysfs_statistics "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_iface_get_ip
#  DESCRIPTION:  Get the current IP address of a network interface
#      OUTPUTS:  IP + netmask (CIDR), e.g. '10.0.0.1/24'
# PARAMETER  1:  Interface/bridge/... name
#            2:  IP family (see <man ip>, default: '4')
#===============================================================================
lib_net_iface_get_ip() {
  local arg_iface="$1"
  local arg_family="${2:-4}"

  lib_core_is --cmd "ip"                            && \
  ip -${arg_family} -oneline addr show ${arg_iface} \
    | tr -s " "                                     \
    | cut -d" " -f4
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_iface_get_master
#  DESCRIPTION:  Get master bridge that a (slave) device is attached to
#      OUTPUTS:  Bridge (master)
# PARAMETER  1:  (Slave) interface name
#===============================================================================
lib_net_iface_get_master() {
  local arg_iface="$1"

  lib_core_is --cmd "readlink"              && \
  lib_core_is --bridge-slave "${arg_iface}" && \
  basename "$(readlink "/sys/class/net/${arg_iface}/master")"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_iface_ip
#  DESCRIPTION:  Add/Remove an IP address to/from a network device
#   RETURNS  0:  Address added/removed
#            1:  Error, e.g. device does not exist
# PARAMETER  1:  add|--add|del|--del
#            2:  Interface name
#            3:  IP + netmask (CIDR), e.g. 10.0.0.1/24
#===============================================================================
lib_net_iface_ip() {
  local arg_option="$1"
  local arg_iface="$2"
  local arg_ip_netmask="$3"

  lib_core_is --cmd "ip" && \
  case "${arg_option}" in
    add|--add) lib_core_sudo ip addr add "${arg_ip_netmask}" dev "${arg_iface}" ;;
    del|--del) lib_core_sudo ip addr del "${arg_ip_netmask}" dev "${arg_iface}" ;;
    *) return 1 ;;
  esac
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_iface_is
#  DESCRIPTION:  Check if one or interfaces are in a certain state (up|down|...)
#   RETURNS  0:  All interfaces are in the specified state
#            1:  At least one interface is not in the given state or
#                is not a valid interface
# PARAMETER  1:  Interface state, please use one of the values described in:
#                https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-class-net
#                ('/sys/class/net/<iface>/operstate')
#         2...:  Interface(s) to check
#===============================================================================
lib_net_iface_is() {
  local arg_state="$1"
  shift

  arg_state="$(lib_core_str_remove_leading "-" "${arg_state}")"

  case "${arg_state}" in
    unknown|notpresent|down|lowerlayerdown|testing|dormant|up) ;;
    *) false ;;
  esac                                                                && \
  lib_core_args_passed "$@"                                           || \
  return

  local iface
  for iface in "$@"; do
    lib_core_is --iface "${iface}"                                    || \
    return
  done

  __lib_net_iface_is "${arg_state}" "$@"
}

__lib_net_iface_is() {
  local arg_state="$1"
  shift

  local iface
  for iface in "$@"; do
    [ "$(cat "/sys/class/net/${iface}/operstate")" = "${arg_state}" ] || \
    return
  done
}

#===============================================================================
#  FUNCTIONS (MISCELLANEOUS)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_net_host_is_up
#  DESCRIPTION:  Check if a host is reachable on a given port
# PARAMETER  1:  Host (IP/FQDN) to check, e.g. '10.0.0.101'
#            2:  Port to check, e.g. '22'
#            3:  (Optional) Timeout (floating point number) in secs (def: '1')
#            4:  (Optional) Wait for host to come up (true|false)
#                (Default: 'false')
#===============================================================================
lib_net_host_is_up() {
  local arg_host="$1"
  local arg_port="$2"
  local arg_timeout="${3:-1}"
  local arg_wait="${4:-false}"

  lib_core_is --cmd "nc"                    && \
  lib_core_regex --host "${arg_host}"       && \
  lib_core_regex --port "${arg_port}"       && \
  lib_core_regex --num-pos "${arg_timeout}" && \
  lib_core_is --bool "${arg_wait}"          || \
  return

  __lib_net_host_is_up "$@"
}

__lib_net_host_is_up() {
  local arg_host="$1"
  local arg_port="$2"
  local arg_timeout="${3:-1}"
  local arg_wait="${4:-false}"

  if ${arg_wait}; then
    # Infinite mode: wait for server to be up (again)
    while ! timeout ${arg_timeout} nc -z ${arg_host} ${arg_port} > /dev/null 2>&1; do
      sleep 1
    done
  else
    # Simply check if server is reachable
    timeout ${arg_timeout} nc -z ${arg_host} ${arg_port} > /dev/null 2>&1
    return $?
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_net_ifconfig_parse_stats
#  DESCRIPTION:  Parse <ifconfig> output
#
#         TODO:  Not very portable at the moment, as <ifconfig>'s output
#                differs between different distributions
#
# PARAMETER  1:  --rx-bytes | --rx-errors | --rx-dropped |
#                --tx-bytes | --tx-errors | --tx-dropped
#            2:  <ifconfig>'s output
#
#      OUTPUTS:  Packet statistics (in packets or bytes) to <stdout>
#===============================================================================
lib_net_ifconfig_parse_stats() {
  local arg_select
  local arg_string
  case "$#" in
    0) return 1 ;;
    1) arg_select="$1"; arg_string="$(xargs)" ;;
    *) arg_select="$1"; shift; arg_string="$*" ;;
  esac

  local rx_tx_bytes="$(                                           \
    printf "%s" "${arg_string}" | grep 'RX bytes:' | tr -s ' '    \
  )"
  local rx_packets="$(                                            \
    printf "%s" "${arg_string}" | grep 'RX packets:' | tr -s ' '  \
  )"
  local tx_packets="$(                                            \
    printf "%s" "${arg_string}" | grep 'TX packets:' | tr -s ' '  \
  )"

  case "${arg_select}" in
    --rx-bytes)
      printf "%s" "${rx_tx_bytes}" | cut -d ' ' -f3 | cut -d ':' -f2
      ;;
    --rx-errors)
      printf "%s" "${rx_packets}" | cut -d ' ' -f4 | cut -d ':' -f2
      ;;
    --rx-dropped)
      printf "%s" "${rx_packets}" | cut -d ' ' -f5 | cut -d ':' -f2
      ;;
    --tx-bytes)
      printf "%s" "${rx_tx_bytes}" | cut -d ' ' -f7 | cut -d ':' -f2
      ;;
    --tx-errors)
      printf "%s" "${tx_packets}" | cut -d ' ' -f4 | cut -d ':' -f2
      ;;
    --tx-dropped)
      printf "%s" "${tx_packets}" | cut -d ' ' -f5 | cut -d ':' -f2
      ;;
    *)
      return 1
      ;;
  esac
}
