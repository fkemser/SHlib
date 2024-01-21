#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/openwrt.lib.sh
#
#        USAGE:   . openwrt.lib.sh
#
#  DESCRIPTION:   Shell library containing OpenWRT-related functions, such as
#                   - installing procd init services
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
#  FUNCTIONS
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_openwrt_procd_install
#  DESCRIPTION:  Install and optionally enable/start procd init service.
#                See also:
#                  - https://openwrt.org/docs/guide-developer/procd-init-scripts
#                  - https://openwrt.org/docs/guide-developer/procd-init-script-example
#
#         TODO:  A lot of the parameters below are not implemented yet
#
# PARAMETER  1:  Service (name), will be used for
#                </etc/init.d/<service>> and </etc/config/<service>>
#            2:  UCI (config file) option(s) (= service's parameters)
#                (multiple options separated by space ' ')
#            3:  Start priority (1...99) (default: 99)
#            4:  Stop priority (1...99) (default: 99)
#            5:  boot() command(s)
#            6:  start_service() command(s)
#            7:  stop_service() command(s)
#            8:  service_stopped() command(s)
#            9:  reload_service() command(s)
#
#           10:  'env' (procd service parameter)
#           11:  'data' (procd service parameter)
#           12:  'limits' (procd service parameter)
#           13:  'netdev' (procd service parameter)
#           14:  'file' (procd service parameter)
#           15:  respawn process? (true|false) (default: false)
#           16:  'respawn threshold' (procd service parameter)
#           17:  'respawn timeout' (procd service parameter)
#           18:  'respawn retry' (procd service parameter)
#           19:  'watch' (procd service parameter)
#
#           20:  'error' (procd service parameter)
#           21:  'nice' (procd service parameter)
#           22:  'term_timeout' (procd service parameter)
#           23:  'reload_signal' (procd service parameter)
#           24:  'pidfile' (procd service parameter)
#           25:  'user' (procd service parameter)
#           26:  'seccomp' (procd service parameter)
#           27:  'capabilities' (procd service parameter)
#           28:  'stdout' (procd service parameter)
#           29:  'stderr' (procd service parameter)
#
#           30:  'no_new_privs' (procd service parameter)
#           31:  'procd_add_reload_trigger' (procd service trigger)
#           32:  'procd_add_reload_interface_trigger' (procd service trigger)
#           33:  'procd_add_reload_mount_trigger' (procd service trigger)
#           34:  'procd_add_restart_mount_trigger' (procd service trigger)
#           35:  'procd_add_jail' (procd service jail)
#           36:  'procd_add_jail_mount' (procd service jail)
#           37:  'procd_add_jail_mount_rw' (procd service jail)
#           38:  Enable service (true|false) (default: true)
#           39:  Start service after setup (true|false) (default: false)
#
#   RETURNS  0:  OK
#            1:  Error: procd service could not be installed
#===============================================================================
lib_openwrt_procd_install() {
  [ $# -eq 39 ] || return

  local arg_service="${1:-$(basename "$0")}"
  local arg_uci_options="$2"
  local arg_start="${3:-99}"
  local arg_stop="${4:-99}"
  local arg_cmd_boot="$5"
  local arg_cmd_start="$6"
  local arg_cmd_stop="$7"
  local arg_cmd_stopped="$8"
  local arg_cmd_reload="$9"
  local i=1; while [ $i -le 9 ]; do shift; i=$(( i+1 )); done

  local arg_procd_env="$1"
  local arg_procd_data="$2"
  local arg_procd_limits="$3"
  local arg_procd_netdev="$4"
  local arg_procd_file="$5"
  local arg_procd_respawn="${6:-false}"
  local arg_procd_respawn_threshold="${7:-3600}"
  local arg_procd_respawn_timeout="${8:-5}"
  local arg_procd_respawn_retry="${9:-5}"
  i=1; while [ $i -le 9 ]; do shift; i=$(( i+1 )); done

  local arg_procd_watch="$1"
  local arg_procd_error="$2"
  local arg_procd_nice="$3"
  local arg_procd_term_timeout="$4"
  local arg_procd_reload_signal="$5"
  local arg_procd_pidfile="$6"
  local arg_procd_user="$7"
  local arg_procd_seccomp="$8"
  local arg_procd_capabilities="$9"
  i=1; while [ $i -le 9 ]; do shift; i=$(( i+1 )); done

  local arg_procd_stdout="${1:-1}"
  local arg_procd_stderr="${2:-1}"
  local arg_procd_no_new_privs="$3"
  local arg_trig_reload_uci="$4"
  local arg_trig_reload_interface="$5"
  local arg_trig_reload_mount="$6"
  local arg_trig_restart_mount="$7"
  local arg_jail="$8"
  local arg_jail_mount="$9"
  i=1; while [ $i -le 9 ]; do shift; i=$(( i+1 )); done

  local arg_jail_mount_rw="$1"
  local arg_enable="${2:-true}"
  local arg_run="${3:-false}"

  local initfile
  initfile="/etc/init.d/${arg_service}"

  #-----------------------------------------------------------------------------
  #  check arguments
  #-----------------------------------------------------------------------------
  [ "$(lib_os_get --id)" = "${LIB_C_ID_DIST_OPENWRT}" ]                     && \
  lib_core_int_is_within_range "1" "${arg_start}" "99"                      && \
  lib_core_int_is_within_range "1" "${arg_stop}" "99"                       && \
  lib_core_is --set "${arg_cmd_start}"                                      && \
  lib_core_is --bool "${arg_procd_respawn}" "${arg_enable}" "${arg_run}"    && \
  lib_core_int_is_within_range "1" "${arg_procd_respawn_threshold}" ""      && \
  lib_core_int_is_within_range "1" "${arg_procd_respawn_timeout}" ""        && \
  lib_core_int_is_within_range "1" "${arg_procd_respawn_retry}" ""          && \

  if lib_core_is --file "${initfile}"; then
    lib_core_sudo "${initfile}" stop 2>/dev/null
    lib_core_sudo "${initfile}" disable
    lib_core_sudo rm -fv "${initfile}"
  else
    lib_core_sudo touch "${initfile}"
  fi                                                                        || \

  return

  #-----------------------------------------------------------------------------
  #  header
  #-----------------------------------------------------------------------------
  { lib_core_sudo tee "${initfile}" >/dev/null <<EOF
#!/bin/sh /etc/rc.common
USE_PROCD=1

START=${arg_start}
STOP=${arg_stop}

CONFIGURATION=${arg_service}

EOF
  }                                                                         && \

  #-----------------------------------------------------------------------------
  #  boot()
  #-----------------------------------------------------------------------------
  if lib_core_is --set "${arg_cmd_boot}"; then
    { lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
boot() {
  config_load \${CONFIGURATION}

EOF
    }                                                                       && \

  for opt in ${arg_uci_options}; do
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  local ${opt}
  config_get ${opt} \${CONFIGURATION} ${opt}

EOF
  done                                                                      && \

  lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  ${arg_cmd_boot}
}

EOF
  fi                                                                        && \

  #-----------------------------------------------------------------------------
  #  start_service()
  #-----------------------------------------------------------------------------
  { lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
start_service() {
  config_load \${CONFIGURATION}

EOF
  }                                                                         && \

  local opt                                                                 && \
  for opt in ${arg_uci_options}; do
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  local ${opt}
  config_get ${opt} \${CONFIGURATION} ${opt}

EOF
  done                                                                      && \

  { lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  procd_open_instance
  procd_set_param command ${arg_cmd_start}
EOF
  }                                                                         && \

  if lib_core_is --set "${arg_uci_options}"; then
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  procd_set_param file "/etc/config/\${CONFIGURATION}"
EOF
  fi                                                                        && \

  if ${arg_procd_respawn}; then
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  procd_set_param respawn ${arg_procd_respawn_threshold} ${arg_procd_respawn_timeout} ${arg_procd_respawn_retry}
EOF
  fi                                                                        && \

  if lib_core_is --set "${arg_procd_term_timeout}"; then
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  procd_set_param term_timeout ${arg_procd_term_timeout}
EOF
  fi                                                                        && \

  { lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
  procd_set_param stdout ${arg_procd_stdout}
  procd_set_param stderr ${arg_procd_stderr}
  procd_close_instance
}
EOF
  }                                                                         && \

  #-----------------------------------------------------------------------------
  #  stop_service()
  #-----------------------------------------------------------------------------
  if lib_core_is --set "${arg_cmd_stop}"; then
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
stop_service() {
  ${arg_cmd_stop}
}
EOF
  fi                                                                        && \

  #-----------------------------------------------------------------------------
  #  service_stopped()
  #-----------------------------------------------------------------------------
  if lib_core_is --set "${arg_cmd_stopped}"; then
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
service_stopped() {
  ${arg_cmd_stopped}
}
EOF
  fi                                                                        && \

  #-----------------------------------------------------------------------------
  #  reload_service()
  #-----------------------------------------------------------------------------
  if lib_core_is --set "${arg_cmd_reload}"; then
    lib_core_sudo tee -a "${initfile}" >/dev/null <<EOF
reload_service() {
  ${arg_cmd_reload}
}
EOF
  fi                                                                        && \

  #-----------------------------------------------------------------------------
  #  final steps
  #-----------------------------------------------------------------------------
  lib_core_sudo chmod +x "${initfile}"                                      && \

  if ${arg_enable}; then
    lib_core_sudo "${initfile}" enable
  fi                                                                        && \

  if ${arg_run}; then
    lib_core_sudo "${initfile}" start
  fi                                                                        || \

  #-----------------------------------------------------------------------------
  #  error handling
  #-----------------------------------------------------------------------------
  {
    lib_core_sudo "${initfile}" disable
    lib_core_sudo rm -fv "${initfile}"
    return 1
  }
}
