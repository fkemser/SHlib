#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2025 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/os.lib.sh
#
#        USAGE:   . os.lib.sh
#
#  DESCRIPTION:   Shell library containing OS-related functions, such as
#                   - retrieving CPU/RAM information,
#                   - process-related tasks,
#                   - modifying bootloader settings, or
#                   - SSH/SCP wrapper.
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
if lib_os 2>/dev/null; then return; fi

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
#  Current init system
readonly LIB_OS_INIT_SYSTEMD="systemd"
readonly LIB_OS_INIT_SYSVINIT="init"
readonly LIB_OS_INIT="$(ps -eo pid=,comm= | sed -ne "s/^[[:space:]]*1[[:space:]]\{1,\}\([^[:space:]]\{1,\}\)[[:space:]]*$/\1/ p")"

#  Only used within <lib_os_ps_pidlock()>
LIB_OS_PS_PIDLOCK_FILE="/var/run/$(basename "$0").pid" # PID file
LIB_OS_PS_PIDLOCK_LOCKED="false" # PID file created by <lib_os_ps_pidlock()>?

#  Get procfs path if available
LIB_OS_DIR_PROCFS="$(mount -t proc 2>/dev/null | sed -ne "s/^.*\(\/[^[:space:]]\{1,\}\).*$/\1/ p")"

#===============================================================================
#  FUNCTIONS
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_os
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_os() {
  return 0
}

#===============================================================================
#  FUNCTIONS (CGROUPS)
#===============================================================================
#  See: https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1/index.html
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_os_cgroup_parse_cpuacct
#  DESCRIPTION:  Parse cgroup CPU accounting controller statistics
# PARAMETER  1:  Output of </sys/fs/cgroup/.../cpuacct.usage_percpu>
#      OUTPUTS:  CPU time (in ns) per core,
#                as semicolon <;> separated values to <stdout>
#===============================================================================
lib_os_cgroup_parse_cpuacct() {
  #-----------------------------------------------------------------------------
  #  See:  https://www.kernel.org/doc/Documentation/cgroup-v1/cpuacct.txt
  #-----------------------------------------------------------------------------
  local arg_string="$1"
  arg_string="$(printf "%s" "${arg_string}" | tr ' ' ';')"
  printf "%s" "${arg_string%%[^[:digit:]]}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_cgroup_parse_mem
#  DESCRIPTION:  Parse cgroup memory statistics
# PARAMETER  1:  Output of </sys/fs/cgroup/.../memory.stat>
#      OUTPUTS:  RAM usage in bytes (just number, no unit) to <stdout>
#===============================================================================
lib_os_cgroup_parse_mem() {
  #-----------------------------------------------------------------------------
  #  See:  https://www.kernel.org/doc/Documentation/cgroup-v1/memory.txt
  #        https://docs.docker.com/config/containers/runmetrics/#metrics-from-cgroups-memory-cpu-block-io
  #-----------------------------------------------------------------------------
  local arg_string="$1"

  local mem_cache
  local mem_rss

  mem_cache="$(                 \
    printf "%s" "${arg_string}" \
      | grep 'total_cache '     \
      | cut -d ' ' -f2          \
  )"
  mem_rss="$(                   \
    printf "%s" "${arg_string}" \
      | grep 'total_rss '       \
      | cut -d ' ' -f2          \
  )"

  printf "%s" "$(( mem_cache + mem_rss ))"
}

#===============================================================================
#  FUNCTIONS (MISCELLANEOUS)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_os_boot_configure
#  DESCRIPTION:  Modify bootloader settings
#    PARAMETER:  (See wrapped functions, e.g. <lib_os_boot_configure_grub>)
#===============================================================================
lib_os_boot_configure() {
  lib_core_echo "true" "false" "Configuring bootloader..."

  #-----------------------------------------------------------------------------
  #  Detect current bootloader and continue with the according function
  #-----------------------------------------------------------------------------
  #   TODO: Support other bootloaders
  #-----------------------------------------------------------------------------
  lib_core_is --cmd "update-grub" && lib_os_boot_configure_grub "$@" || \
  { lib_core_echo "true" "false" \
      "Bootloader could not be detected. Currently, only GRUB is supported." >&2
    return 1
  }
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_boot_configure_grub
#  DESCRIPTION:  !!! CAUTION - PLEASE USE THIS FUNCTION CAREFULLY !!!
#                Modify "GRUB_CMDLINE_LINUX_DEFAULT" in GRUB settings
#
# PARAMETER  1:  CPU range for "arg_isolcpus", e.g. 1-7
#                (optional, default: <option is removed>)
#            2:  Enable memory cgroups (true|false) (default: 'true')
#            3:  Disable security modules (AppArmor/SELinux)
#                (true|false) (default: 'false')
#===============================================================================
lib_os_boot_configure_grub() {
  lib_core_echo "true" "false" "GRUB detected."
  lib_core_is --cmd "sed" || return

  #-----------------------------------------------------------------------------
  #  TODO:
  #  Make sure that <arg_isolcpus> is either a core range, e.g. "0-7", or
  #  multiple cores separated only by commas (no space in between), e.g. "1,2,4".
  #-----------------------------------------------------------------------------
  local arg_isolcpus="$1"
  local arg_memcgroup_enable="${2:-true}"
  local arg_secmodule_disable="${3:-false}"

  lib_core_is --bool "${arg_memcgroup_enable}" "${arg_secmodule_disable}" || \
  return

  #-----------------------------------------------------------------------------
  #  Get current options of GRUB_CMDLINE_LINUX_DEFAULT and remove
  #  "isolcpus=...", "cgroup_enable=memory", and "swapaccount=...".
  #-----------------------------------------------------------------------------
  local options
  options="$(                                                   \
    sed                                                         \
      -ne "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\([^\"]*\)\"/\1/ p"  \
      /etc/default/grub                                         \
      | sed -e "s/ *isolcpus=[^ \"]*//"                         \
            -e "s/ *swapaccount=[^ \"]*//"                      \
            -e "s/ *cgroup_enable=memory//"                     \
            -e "s/ *enforcing=[^ \"]*//"                        \
            -e "s/ *apparmor=[^ \"]*//"                         \
      | sed -e "s/^ *\(.*[^ ]\)/\1/"                            \
  )"

  #-----------------------------------------------------------------------------
  #  If a CPU range is given, re-add "isolcpus" parameter.
  #-----------------------------------------------------------------------------
  if [ -n "${arg_isolcpus}" ]; then
    options="${options:+${options} }isolcpus=${arg_isolcpus}"
  fi

  #-----------------------------------------------------------------------------
  #  If memory cgroup is enabled, re-add memory cgroup parameter.
  #-----------------------------------------------------------------------------
  #   see also: https://docs.docker.com/config/containers/runmetrics/#metrics-from-cgroups-memory-cpu-block-io
  #-----------------------------------------------------------------------------
  if ${arg_memcgroup_enable}; then
    options="${options:+${options} }cgroup_enable=memory swapaccount=1"
  fi

  #-----------------------------------------------------------------------------
  #  (Optionally) disabling Linux Security Modules (LSM).
  #-----------------------------------------------------------------------------
  if ${arg_secmodule_disable}; then
    #---------------------------------------------------------------------------
    #  SELinux
    #---------------------------------------------------------------------------
    if lib_core_is --cmd "getenforce" >/dev/null; then
      options="${options:+${options} }enforcing=0"
    fi

    #---------------------------------------------------------------------------
    #  AppArmor
    #---------------------------------------------------------------------------
    if lib_core_is --cmd "aa-status" >/dev/null; then
      options="${options:+${options} }apparmor=0"
    fi
  fi

  #-----------------------------------------------------------------------------
  #  Finally write modified GRUB_CMDLINE_LINUX_DEFAULT back and update GRUB.
  #-----------------------------------------------------------------------------
  lib_core_echo                                                               \
    "true" "true" "Modifying and updating </etc/default/grub> ..."            \
    "GRUB_CMDLINE_LINUX_DEFAULT" "${options}"
  lib_core_sudo sed                                                           \
      -i "s/\(^GRUB_CMDLINE_LINUX_DEFAULT=\"\).*\(\".*\$\)/\1${options}\2/"   \
      /etc/default/grub                                                    && \
  lib_core_sudo update-grub                                                && \
  lib_core_echo "true" "true" "GRUB successfully updated. Rebooting..."
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_cpu_get
#  DESCRIPTION:  Get CPU statistics
# PARAMETER  1:  Selector, see 'case' statement below
#      OUTPUTS:  CPU statistics to <stdout>
#===============================================================================
lib_os_cpu_get() {
  lib_core_is --cmd "nproc" || return
  __lib_os_cpu_get "$@"
}

__lib_os_cpu_get() {
  local arg_select="$1"

  case "${arg_select}" in
    --cores|--cores-available) nproc ;;
    --cores-installed|--cores-total) nproc --all ;;
    *) return 1 ;;
  esac
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_cpu_has_feature
#  DESCRIPTION:  Check if (all) installed CPU(s) support(s) a given feature
# PARAMETER  1:  Feature flag to check, e.g. 'aes' for AES-NI support
#                See also: https://unix.stackexchange.com/a/43540
#===============================================================================
lib_os_cpu_has_feature() {
  local arg_flag="$1"

  [ -n "${LIB_OS_DIR_PROCFS}" ]                       && \
  lib_core_is --file "${LIB_OS_DIR_PROCFS}/cpuinfo"   && \
  lib_core_is --not-empty "${arg_flag}"               || \
  return

  __lib_os_cpu_has_feature "$@"
}

__lib_os_cpu_has_feature() {
  local arg_flag="$1"

  local num="$(\
    grep -E "^(Features|flags)\s*:\s*(\S+\s+)*${arg_flag}(\s+\S+)*\s*$" \
      "${LIB_OS_DIR_PROCFS}/cpuinfo" | wc -l                            \
  )"

  [ ${num} -ge 1 ] && \
  [ ${num} -eq $(lib_os_cpu_get --cores-total) ]
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_bus_usb_list
#  DESCRIPTION:  List all currently connected USB devices with their
#                corresponding device path (/dev/...), their manufacturer
#                and their product name
# PARAMETER  1:  Device pattern to include, e.g. 'tty' to only list
#                '/dev/tty...' devices
#            2:  Device pattern to exclude, e.g. 'input' to list all but
#                '/dev/input...' devices
#            3:  Field delimiter (default: ';')
#      OUTPUTS:  Sorted list to <stdout> in the following form
#                (/dev/...)(delimiter)(manufacturer)(delimiter)(product name)
#===============================================================================
lib_os_dev_bus_usb_list() {
  local arg_include="$1"
  local arg_exclude="$2"
  local arg_delim="${3:-;}"

  local syspath
  local devpath
  local sysport
  local manufacturer
  local product

  # See:  https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-usb
  find /sys/bus/usb/devices/*:*/ -name "dev" -type f  \
    | __lib_os_dev_bus_usb_list_by_dev                \
        "${arg_include}" "${arg_exclude}" "${arg_delim}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_bus_usb_list_by_busdev
#
#  DESCRIPTION:  List device paths (/dev/...) of USB devices matching
#                (one or more) given bus and device numbers
# PARAMETER
#         1...:  USB bus and/or device number in the following form
#                  001[/]   Bus number only
#                  001/012  Bus/Device number pair
#
#      OUTPUTS:  Device paths (/dev/...) to <stdout> (separated by newline)
#===============================================================================
lib_os_dev_bus_usb_list_by_busdev() {
  lib_core_args_passed "$@" || return

  local regex
  local busnum
  local devnum
  local busdev
  for busdev in "$@"; do
    case "${busdev}" in
      */*/*) continue ;;
      ???/???) busnum="${busdev%/*}"; devnum="${busdev#*/}" ;;
      ???|???/) busnum="${busdev%/*}"; devnum="" ;;
      *) continue ;;
    esac
    regex="${regex}${busnum}\/${devnum}\|"
  done

  [ -n "${regex}" ]                                       && \
  regex="^DEVNAME=bus\/usb\/\(${regex%\\|}\)"             && \
  grep -il -e "${regex}" /sys/bus/usb/devices/*.*/uevent  \
    | __lib_os_dev_list_by_uevent "" "bus/usb"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_bus_usb_list_by_vidpid
#
#  DESCRIPTION:  List device paths (/dev/...) of USB devices matching
#                (one or more) given vendor and/or product IDs
#
# PARAMETER
#         1...:  Vendor ID (VID) and/or product ID (PID) in the following form
#                  045e[:]    VID only
#                  045e:0039  VID:PID pair
#
#      OUTPUTS:  Device path(s) (/dev/...) to <stdout> (separated by newline)
#
#       SOURCE:  Adapted from "https://unix.stackexchange.com/a/566685"
#                by "user313992"
#                licensed under "CC BY-SA 4.0" (https://creativecommons.org/licenses/by-sa/4.0/)
#===============================================================================
lib_os_dev_bus_usb_list_by_vidpid() {
  lib_core_args_passed "$@" || return

  local regex
  local vid
  local pid
  local vidpid
  for vidpid in "$@"; do
    case "${vidpid}" in
      *:*:*) continue ;;
      ????:????) vid="${vidpid%:*}"; pid="${vidpid#*:}" ;;
      ????|????:) vid="${vidpid%:*}"; pid="" ;;
      *) continue ;;
    esac

    vid="$(lib_core_str_remove_leading "0" "${vid}")"
    pid="$(lib_core_str_remove_leading "0" "${pid}")"
    regex="${regex}${vid}\/${pid}\|"
  done

  [ -n "${regex}" ]                                       && \
  regex="^PRODUCT=\(${regex%\\|}\)"                       && \
  grep -il -e "${regex}" /sys/bus/usb/devices/*:*/uevent  \
    | __lib_os_dev_list_by_uevent
}

#===  FUNCTION  ================================================================
#         NAME:  __lib_os_dev_bus_usb_list_by_dev
#  DESCRIPTION:  Helper function for all <lib_os_dev_bus_usb_list_...>
#                functions that grep <dev> files
# PARAMETER
#     <stdin> :  List (newline separated) of <dev> filepaths (/sys/.../dev)
#            1:  Device pattern to include, e.g. 'tty' to only list
#                '/dev/tty...' devices
#            2:  Device pattern to exclude, e.g. 'input' to list all but
#                '/dev/input...' devices
#            3:  Field delimiter (default: ';')
#
#      OUTPUTS:  Sorted list to <stdout> in the following form
#                (/dev/...)(delimiter)(manufacturer)(delimiter)(product name)
#===============================================================================
__lib_os_dev_bus_usb_list_by_dev() {
  local arg_include="$1"
  local arg_exclude="$2"
  local arg_delim="${3:-;}"

  local syspath
  local devpath
  local sysport
  local manufacturer
  local product

  # See:  https://www.kernel.org/doc/Documentation/ABI/stable/sysfs-bus-usb
  #       https://www.kernel.org/doc/Documentation/ABI/testing/sysfs-bus-usb
  local sysdev
  while IFS= read -r sysdev || [ -n "${sysdev}" ]; do
    syspath="${sysdev%/dev}"
    devpath="$(\
      sed -ne "s/^DEVNAME=\(.*\)$/\/dev\/\1/ p" "${syspath}/uevent")" && \
    [ -n "${devpath}" ]                                               && \
    sysport="${syspath%%:*}"                                          && \
    manufacturer="$(cat "${sysport}/manufacturer")"                   && \
    product="$(cat "${sysport}/product")"                             && \
    printf "%s%s%s%s%s\n" \
      "${devpath}" "${arg_delim}" "${manufacturer}" "${arg_delim}" "${product}"
  done 2>/dev/null                            \
  | lib_core_str_filter_and_sort              \
      "${arg_include:+^/dev/${arg_include}}"  \
      "${arg_exclude:+^/dev/${arg_exclude}}"
}

#===  FUNCTION  ================================================================
#         NAME:  __lib_os_dev_bus_usb_list_by_uevent
#  DESCRIPTION:  Like <__lib_os_dev_list_by_uevent>
#                but with an advanced output for USB devices
# PARAMETER
#     <stdin> :  List (newline separated) of <uevent> filepaths (/sys/.../uevent)
#         1...:  See <__lib_os_dev_bus_usb_list_by_dev>
#      OUTPUTS:  See <__lib_os_dev_bus_usb_list_by_dev>
#===============================================================================
__lib_os_dev_bus_usb_list_by_uevent() {
  sed -e "s/\/uevent$//"                      \
  | xargs -I[] find -H "[]" -name dev -type f \
  | __lib_os_dev_bus_usb_list_by_dev "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  __lib_os_dev_list_by_dev
#  DESCRIPTION:  Helper function for all <lib_os_dev_..._list_...> functions
#                functions that grep <dev> files
# PARAMETER
#     <stdin> :  List (newline separated) of <uevent> files
#            1:  Device pattern to include, e.g. 'tty' to only list
#                '/dev/tty...' devices
#            2:  Device pattern to exclude, e.g. 'input' to list all but
#                '/dev/input...' devices
#
#      OUTPUTS:  Device path(s) (/dev/...) to <stdout> (separated by newline)
#===============================================================================
__lib_os_dev_list_by_dev() {
  local arg_include="$1"
  local arg_exclude="$2"

  sed -e "s/\/dev$/\/uevent/"                                   \
  | xargs sed -ne "s/^DEVNAME=\(.*\)$/\/dev\/\1/ p" 2>/dev/null \
  | lib_core_str_filter_and_sort              \
      "${arg_include:+^/dev/${arg_include}}"  \
      "${arg_exclude:+^/dev/${arg_exclude}}"
}

#===  FUNCTION  ================================================================
#         NAME:  __lib_os_dev_list_by_dev_udevadm
#  DESCRIPTION:  Like <__lib_os_dev_list_by_dev> but additionally
#                outputs a device ID (requires 'udevadm')
#
# PARAMETER
#     <stdin> :  List (newline separated) of <dev> filepaths (/sys/.../dev)
#            1:  Device pattern to include, e.g. 'tty' to only list
#                '/dev/tty...' devices
#            2:  Device pattern to exclude, e.g. 'input' to list all but
#                '/dev/input...' devices
#            3:  Field delimiter (default: ';')
#
#      OUTPUTS:  Sorted list to <stdout> in the following form
#                (/dev/...)(delimiter)(device id)
#
# EXAMPLE
#            1:  devicepath="$(udevadm info -q path               \
#                  "/dev/bus/usb/<busnum>/<devnum>" 2>/dev/null)" && \
#                find "/sys${devicepath}" -name "dev" -type f     \
#                  | __lib_os_dev_list_by_dev_udevadm "" "bus/usb"
#
#            2:  find /sys/bus/usb/devices/usb*/ -name dev -type f \
#                  | __lib_os_dev_list_by_dev_udevadm "" "bus/usb"
#
#       SOURCE:  Adapted from "https://unix.stackexchange.com/a/144735"
#                by "phemmer" (https://unix.stackexchange.com/users/4358/phemmer)
#                licensed under "CC BY-SA 4.0" (https://creativecommons.org/licenses/by-sa/4.0/)
#===============================================================================
__lib_os_dev_list_by_dev_udevadm() {
  local arg_include="$1"
  local arg_exclude="$2"
  local arg_delim="${3:-;}"

  lib_core_is --cmd "udevadm" || \
  return

  local sysdev
  while IFS= read -r sysdev || [ -n "${sysdev}" ]; do
    (
      syspath="${sysdev%/dev}"
      devname="$(udevadm info -q name -p ${syspath})"
      #case "${devname}" in
        #"bus/"*) exit ;;
      #esac
      eval "$(udevadm info -q property --export -p "${syspath}")"
      [ -z "${ID_SERIAL}" ] && exit
      printf "%s%s%s\n" "/dev/${devname}" "${arg_delim}" "${ID_SERIAL}"
    )
  done 2>/dev/null                            \
  | lib_core_str_filter_and_sort              \
      "${arg_include:+^/dev/${arg_include}}"  \
      "${arg_exclude:+^/dev/${arg_exclude}}"
}

#===  FUNCTION  ================================================================
#         NAME:  __lib_os_dev_list_by_uevent
#  DESCRIPTION:  Helper function for all <lib_os_dev_..._list_...> functions
#                that grep <uevent> files
# PARAMETER
#     <stdin> :  List (newline separated) of <uevent> files
#            1:  Device pattern to include, e.g. 'tty' to only list
#                '/dev/tty...' devices
#            2:  Device pattern to exclude, e.g. 'input' to list all but
#                '/dev/input...' devices
#      OUTPUTS:  Device path(s) (/dev/...) to <stdout> (separated by newline)
#===============================================================================
__lib_os_dev_list_by_uevent() {
  local arg_include="$1"
  local arg_exclude="$2"

  sed -e "s/\/uevent$//"                                        \
  | xargs -I[] find -H "[]" -name dev -type f                   \
  | sed -e "s/\/dev$/\/uevent/"                                 \
  | xargs sed -ne "s/^DEVNAME=\(.*\)$/\/dev\/\1/ p" 2>/dev/null \
  | lib_core_str_filter_and_sort              \
      "${arg_include:+^/dev/${arg_include}}"  \
      "${arg_exclude:+^/dev/${arg_exclude}}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_class_list
#  DESCRIPTION:  List device paths (/dev/...) and corresponding IDs/names
#                of a certain class
# PARAMETER  1:  Device class, see <ARG_CLASS_...> constants below for
#                supported classes
#            2:  Field delimiter (default: ';')
#      OUTPUTS:  Sorted list to <stdout> in the following form
#                (/dev/...)(delimiter)(device name)
#===============================================================================
lib_os_dev_class_list() {
  local ARG_CLASS_HIDRAW="hidraw"
  local ARG_CLASS_INPUT="input"
  local ARG_CLASS_TPMRM="tpmrm"
  local arg_class="$1"

  local arg_delim="${2:-;}"

  local id_property
  case "${arg_class}" in
    ${ARG_CLASS_HIDRAW}) id_property="HID_NAME" ;;
    ${ARG_CLASS_INPUT}) id_property="NAME" ;;
    ${ARG_CLASS_TPMRM}) id_property="MODALIAS" ;;
    *) return 1 ;;
  esac

  local syspath
  local devpath
  local id_value
  local sysdev
  for sysdev in /sys/class/"${arg_class}"/*/dev; do
    syspath="${sysdev%/dev}"
    devpath="$(\
      sed -ne "s/^DEVNAME=\(.*\)$/\/dev\/\1/ p" "${syspath}/uevent")"   && \
    [ -n "${devpath}" ]                                                 && \
    id_value="$(sed -ne                                                 \
      "s/^${id_property}=\(.*\)$/\1/ p" "${syspath}/device/uevent")"    && \
    printf "%s%s%s\n" "${devpath}" "${arg_delim}" "${id_value}"
  done 2>/dev/null \
  | lib_core_str_filter_and_sort
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_is_mounted
#  DESCRIPTION:  Check if (one or more) block devices are mounted
# PARAMETER
#         1...:  Device(s) to check
#===============================================================================
#lib_os_dev_is_mounted() {
  #lib_core_is --blockdevice "$@"                   && \
  #[ -n "${LIB_OS_DIR_PROCFS}" ]                    && \
  #lib_core_is --file "${LIB_OS_DIR_PROCFS}/mounts" || \
  #return

  #__lib_os_dev_is_mounted "$@"
#}

#__lib_os_dev_is_mounted() {
  #local dev
  #for dev in "$@"; do
    #grep -qs "${dev} " "${LIB_OS_DIR_PROCFS}/mounts" || return
  #done
#}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_is_mounted
#  DESCRIPTION:  Check if (one or more) block devices are mounted
# PARAMETER  1:  (Optional) Also check slave devices, e.g. 'sda1, sda2, ...'
#                for device 'sda' (true|false) (default: 'false')
#                Please note: In case one of the slave devices is mounted then
#                             the "whole device" is considered to be mounted.
#         2...:  Device(s) to check - has to be an absolute path, e.g.
#                '/dev/sda', '/dev/disk/by-id/...',
#                '/dev/sda1','/dev/disk/by-uuid/...', ...
#   RETURNS  0:  All devices are mounted
#            1:  At least one device is not mounted
#===============================================================================
lib_os_dev_is_mounted() {
  local arg_deps
  if lib_core_is --bool "$1"; then
    arg_deps="$1"; shift
  else
    arg_deps="false"
  fi

  [ $# -ge 1 ]                            && \
  lib_core_is --cmd "lsblk"               && \
  __lib_os_dev_is_mounted "${arg_deps}" "$@"
}

__lib_os_dev_is_mounted() {
  local arg_deps="$1"
  shift

  local OLDIFS="$IFS"
  local exitcode
  local dev
  local list_slave
  local slave
  for dev in "$@"; do
    exitcode="1"
    list_slave="$(__lib_os_dev_get "MOUNTPOINT" "${arg_deps}" "${dev}")"

    IFS="${LIB_C_STR_NEWLINE}"
    for slave in ${list_slave}; do
      lib_core_is --not-empty "${slave}"  && \
      exitcode="0"                        && \
      break
    done
    IFS="$OLDIFS"

    [ "${exitcode}" -eq "0" ] || return
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_umount
#  DESCRIPTION:  Unmount (one or more) block devices including slave devices
# PARAMETER
#         1...:  Device(s) to unmount - has to be an absolute path, e.g.
#                '/dev/sda', '/dev/disk/by-id/...',
#                '/dev/sda1','/dev/disk/by-uuid/...', ...
#   RETURNS  0:  All devices successfully unmounted
#            1:  At least one device (or its slave device) is still mounted
#                and could not be unmounted
#===============================================================================
lib_os_dev_umount() {
  lib_core_is --cmd "lsblk" && \
  __lib_os_dev_umount "$@"
}

__lib_os_dev_umount() {
  local OLDIFS="$IFS"
  local exitcode="0"
  local dev
  local list_slave
  local slave
  for dev in "$@"; do
    list_slave="$(__lib_os_dev_get "MOUNTPOINT" "true" "${dev}")"
    IFS="${LIB_C_STR_NEWLINE}"
    for slave in ${list_slave}; do
      lib_core_is --not-empty "${slave}"        && \
      { lib_core_sudo umount "${slave}" || \
        exitcode="$?"
      }
    done
    IFS="$OLDIFS"
  done

  return ${exitcode}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_dev_lsblk
#  DESCRIPTION:  Get information about (one or more) block device using 'lsblk'
# PARAMETER  1:  'lsblk' column(s) to output (multiple separated by comma (,))
#                (Run 'lsblk --help' for available columns)
#            2:  (Optional) Get information also for slave devices? (true|false)
#                (Default: 'false')
#            3:  (Optional) Show header line and dependencies (└─) (true|false)
#                (Default: 'false')
#         4...:  (Optional) Particular device(s) to check - has to be an
#                absolute path, e.g.
#                  '/dev/sda', '/dev/disk/by-id/...',
#                  '/dev/sda1','/dev/disk/by-uuid/...', ...
#      OUTPUTS:  'lsblk' information to <stdout>
#===============================================================================
lib_os_dev_lsblk() {
  local arg_columns="$1"

  lib_core_is --cmd "lsblk"                 && \
  lib_core_is --not-empty "${arg_columns}"  && \
  __lib_os_dev_get "$@"
}

__lib_os_dev_get() {
  local arg_columns="$1"; shift

  if lib_core_is --boolean "$1"; then
    arg_deps="$1"; shift;
  else
    arg_deps="false"
  fi

  if lib_core_is --boolean "$1"; then
    arg_headings="$1"; shift;
  else
    arg_headings="false"
  fi

  if ${arg_deps}; then arg_deps=""; else arg_deps="--nodeps"; fi
  if ${arg_headings}; then arg_headings=""; else arg_headings="--list --noheadings"; fi

  if [ "$#" -eq "0" ]; then
    lsblk ${arg_deps} ${arg_headings} --output "${arg_columns}" 2>/dev/null \
      | if [ -z "${arg_headings}" ]; then cat; else tr -s ' '; fi
  else
    local dev
    for dev in "$@"; do
      lib_core_is --blockdevice "${dev}"                                    && \
      lsblk ${arg_deps} ${arg_headings} --output "${arg_columns}" "${dev}"  \
        2>/dev/null | if [ -z "${arg_headings}" ]; then cat; else tr -s ' '; fi || \
      printf "\n"
    done
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_get
#  DESCRIPTION:  Get statistics about current distribution (ID, version, etc.)
# PARAMETER  1:  Information selector, see 'case' statement below
#      OUTPUTS:  Statistics to <stdout>
#===============================================================================
lib_os_get() {
  local arg_type="$1"

  local var
  case "${arg_type}" in
    --id|--dist) var="ID" ;;
    --version-codename) var="VERSION_CODENAME" ;;
    --version-id) var="VERSION_ID" ;;
    --lang)
        if [ -n "${LANG}" ]; then echo "${LANG}"; else echo "${LC_ALL}"; fi
        return
        ;;
    *) return 1 ;;
  esac

  sed -ne "s/^${var}=\"\{0,1\}\([^\"]*\)\"\{0,1\}/\1/ p" /etc/*release 2>/dev/null
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_is_subshell
#  DESCRIPTION:  Check if the function that calls this function
#                is running in a subshell
#   RETURNS  0:  Subshell
#            1:  No subshell
#===============================================================================
lib_os_is_subshell() {
  local pid
  lib_os_ps_get_ownpid pid
  [ "$$" -ne "${pid}" ]
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_lib
#  DESCRIPTION:  Check existence or get absolute path of a given library (.so)
#                file
# PARAMETER  1:  -d|--dir     Directory path
#                -e|--exists  Do not return any path, just check for existence
#                -f|--file    Full filepath
#         2...:  Library file(s), e.g. 'opensc-pkcs11.so'
#      OUTPUTS:  Writes library path(s) separated by <newline> to <stdout>
#                (if library exists)
#                or an error message to <stderr> (if library is missing)
#   RETURNS  0:  All libraries exist
#            1:  At least one library was not found
#===============================================================================
lib_os_lib() {
  local arg_type="${1:---file}"

  [ $# -ge 2 ]                        && \
  lib_core_is --cmd "ldconfig"        && \
  case "${arg_type}" in
    -d|--dir|-e|--exists|-f|--file) ;;
    *) false ;;
  esac                                && \

  __lib_os_lib "$@"
}

__lib_os_lib() {
  local arg_type="${1:---file}"; shift

  local exitcode="0"
  local result
  local var
  for var in "$@"; do
    [ -n "$var" ]                                                           && \

    result="$(ldconfig -p | sed -ne                                             \
      "s/^[[:space:]]*${var}[[:space:]]\{1,\}.\{1,\}=>[[:space:]]*\(.*\)$/\1/p" \
    )"                                                                      && \

    # ldconfig only supports certain file name patterns, see 'man ldconfig'
    if lib_core_is --empty "${result}"; then
      result="$(find "/lib/" -name "${var}" | head -1)"
    fi                                                                      && \

    lib_core_is --not-empty "${result}"                                     && \

    case "${arg_type}" in
      -d|--dir) __lib_core_file_get --dir "${result}" ;;
      -f|--file) printf "%s\n" "${result}" ;;
    esac                                                                    || \

    { lib_core_msg --error "Library <${var}> not found."
      exitcode="1"
    }
  done

  return ${exitcode}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_proc_meminfo / lib_os_mem_get
#  DESCRIPTION:  Get memory statistics
# PARAMETER  1:  Meminfo field, see:
#                  https://man7.org/linux/man-pages/man5/proc.5.html
#            2:  Output unit (default: 'B'), in
#                  Bits (b|kb|Mb|Gb|Tb|Pb|Eb|Zb|Yb), or
#                  Bytes (B|kB|MB|GB|TB|PB|EB|ZB|YB)
#      OUTPUTS:  Memory statistics to <stdout>
#===============================================================================
lib_os_proc_meminfo() {
  [ -n "${LIB_OS_DIR_PROCFS}" ]                       && \
  lib_core_is --file "${LIB_OS_DIR_PROCFS}/meminfo"   || \
  return

  local arg_select="$1"
  local arg_unit="${2:-B}"

  lib_core_is --unit "${arg_unit}" || \
  return

  __lib_os_proc_meminfo "$@"
}

__lib_os_proc_meminfo() {
  local arg_select="$1"
  local arg_unit="${2:-B}"

  local field
  case "${arg_select}" in
    --total|MemTotal) field="MemTotal" ;;
    --free|MemFree) field="MemFree" ;;
    --available|MemAvailable) field="MemAvailable" ;;
    --buffers|Buffers) field="Buffers" ;;
    --cached|Cached) field="Cached" ;;
    --swap-cached|SwapCached) field="SwapCached" ;;
    --active|Active) field="Active" ;;
    --inactive|Inactive) field="Inactive" ;;
    --active-anon|"Active(anon)") field="Active(anon)" ;;
    --inactive-anon|"Inactive(anon)") field="Inactive(anon)" ;;
    --active-file|"Active(file)") field="Active(file)" ;;
    --inactive-file|"Inactive(file)") field="Inactive(file)" ;;
    --unevictable|"Unevictable") field="Unevictable" ;;
    --mlocked|Mlocked) field="Mlocked" ;;
    --high-total|HighTotal) field="HighTotal" ;;
    --high-free|HighFree) field="HighFree" ;;
    --low-total|LowTotal) field="LowTotal" ;;
    --low-free|LowFree) field="LowFree" ;;
    --swap-total|SwapTotal) field="SwapTotal" ;;
    --swap-free|SwapFree) field="SwapFree" ;;
    --dirty|Dirty) field="Dirty" ;;
    --writeback|Writeback) field="Writeback" ;;
    --anon-pages|AnonPages) field="AnonPages" ;;
    --mapped|Mapped) field="Mapped" ;;
    --shmem|Shmem) field="Shmem" ;;
    --k-reclaimable|KReclaimable) field="KReclaimable" ;;
    --slab|Slab) field="Slab" ;;
    --s-reclaimable|SReclaimable) field="SReclaimable" ;;
    --s-unreclaim|SUnreclaim) field="SUnreclaim" ;;
    --kernel-stack|KernelStack) field="KernelStack" ;;
    --page-tables|PageTables) field="PageTables" ;;
    --quicklists|Quicklists) field="Quicklists" ;;
    --nfs-unstable|NFS_Unstable) field="NFS_Unstable" ;;
    --bounce|Bounce) field="Bounce" ;;
    --writeback-tmp|WritebackTmp) field="WritebackTmp" ;;
    --commit-limit|CommitLimit) field="CommitLimit" ;;
    --committed-as|Committed_AS) field="Committed_AS" ;;
    --vmalloc-total|VmallocTotal) field="VmallocTotal" ;;
    --vmalloc-used|VmallocUsed) field="VmallocUsed" ;;
    --vmalloc-chunk|VmallocChunk) field="VmallocChunk" ;;
    --hardware-corrupted|HardwareCorrupted) field="HardwareCorrupted" ;;
    --lazy-free|LazyFree) field="LazyFree" ;;
    --anon-huge-pages|AnonHugePages) field="AnonHugePages" ;;
    --shmem-huge-pages|ShmemHugePages) field="ShmemHugePages" ;;
    --shmem-pmd-mapped|ShmemPmdMapped) field="ShmemPmdMapped" ;;
    --cma-total|CmaTotal) field="CmaTotal" ;;
    --cma-free|CmaFree) field="CmaFree" ;;
    --huge-pages-total|HugePages_Total) field="HugePages_Total" ;;
    --huge-pages-free|HugePages_Free) field="HugePages_Free" ;;
    --huge-pages-rsvd|HugePages_Rsvd) field="HugePages_Rsvd" ;;
    --huge-pages-surp|HugePages_Surp) field="HugePages_Surp" ;;
    --hugepagesize|Hugepagesize) field="Hugepagesize" ;;
    --direct-map-4k|DirectMap4k) field="DirectMap4k" ;;
    --direct-map-4M|DirectMap4M) field="DirectMap4M" ;;
    --direct-map-2M|DirectMap2M) field="DirectMap2M" ;;
    --direct-map-1G|DirectMap1G) field="DirectMap1G" ;;
    *) return 1 ;;
  esac

  local res
  local res_val
  local res_unit
  res="$(cat "${LIB_OS_DIR_PROCFS}/meminfo" | grep -e "^${field}:" | tr -s " ")"

  if lib_core_is --not-empty "${res}"; then
    res_val="$(printf "%s" "${res}" | cut -d " " -f2)"
    res_unit="$(printf "%s" "${res}" | cut -d " " -f3)"
    lib_math_convert_unit "${res_val}" "${res_unit}" "${arg_unit}"
  else
    return 1
  fi
}

lib_os_mem_get() {
  lib_os_proc_meminfo "$@"
}

__lib_os_mem_get() {
  __lib_os_proc_meminfo "$@"
}

#===============================================================================
#  FUNCTIONS (PROCESS HANDLING)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_exists
#  DESCRIPTION:  Check if a process with a given PID exists
# PARAMETER  1:  Process PID
#===============================================================================
lib_os_ps_exists() {
  local arg_pid="$1"
  lib_core_is --int-pos "${arg_pid}" || return

  __lib_os_ps_exists "$@"
}

__lib_os_ps_exists() {
  local arg_pid="$1"
  ps -eo pid | grep -q -e "^[[:space:]]*${arg_pid}\$"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_get_descendants
#  DESCRIPTION:  Look for sub-processes
# PARAMETER  1:  Variable (name) where list of PIDs will be stored
#                (must not be 'pid', 'result', 'sub', 'subsub', or 'tid')
#            2:  Process ID (PID) of root process
#            3:  Recursively look for sub-sub-...-processes?
#                (true|false) (default: 'true')
#      OUTPUTS:  Stores PID(s) of sub-process(es) (separated by space) in the
#                variable defined in param <1>
#===============================================================================
lib_os_ps_get_descendants() {
  local arg_varname="$1"
  local arg_pid="$2"
  local arg_recursive="${3:-true}"

  case "${arg_varname}" in
    pid|result|sub|subsub|tid) false ;;
    *) lib_core_is --varname "${arg_varname}" ;;
  esac                                            && \
  lib_os_ps_exists "${arg_pid}"                   && \
  lib_core_is --bool    "${arg_recursive}"        && \

  if [ -n "${LIB_OS_DIR_PROCFS}" ]; then
    __lib_os_ps_get_descendants_procfs "$@"
  else
    __lib_os_ps_get_descendants_ps "$@"
  fi
}

__lib_os_ps_get_descendants_procfs() {
  local arg_varname="$1"
  local arg_pid="$2"
  local arg_recursive="${3:-true}"

  local pid       # PID loop variable
  local sub       # PIDs of each task's sub-processes
                  # (content of '/proc/<pid>/task/<tid>/children')
  local subsub    # PIDs of sub-sub-...-processes (recursive lookup)
  local tid       # Loop variable directing at the process's threads
                  # (/proc/<pid>/task/<tid>)
  local result    # PID return list containing all sub-processes and
                  # (optionally) sub-sub-...-processes

  # Look for threads (thread ids) related to the given process
  # (/proc/<pid>/task/<tid>)
  for tid in "${LIB_OS_DIR_PROCFS}"/${arg_pid}/task/*; do
    [ -f "${tid}/children" ] || continue

    # Get sub-processes (/proc/<pid>/task/<tid>/children)
    sub="$(cat "${tid}/children")"

    # Optionally do a recursive lookup (sub-sub-...-processes)
    if ${arg_recursive}; then
      for pid in ${sub}; do
        __lib_os_ps_get_descendants_procfs subsub "${pid}"
        result="${result}${result:+ }${subsub}${subsub:+ }${pid}"
      done
    else
      result="${result}${result:+ }${sub}"
    fi
  done

  # Store temporary list (<result>) in user-defined variable (<arg_varname>)
  eval "${arg_varname}=\${result}"
}

__lib_os_ps_get_descendants_ps() {
  local arg_varname="$1"
  local arg_pid="$2"
  local arg_recursive="${3:-true}"

  local pid       # PID loop variable
  local sub       # PIDs of each task's sub-processes
  local subsub    # PIDs of sub-sub-...-processes (recursive lookup)
  local result    # PID return list containing all sub-processes and
                  # (optionally) sub-sub-...-processes

  # Get sub-processes
  sub="$(ps -eo ppid=,pid= | sed -ne "s/^[[:space:]]*${arg_pid}[[:space:]]\{1,\}\([^[:space:]]\{1,\}\)[[:space:]]*$/\1/ p" | xargs)"

  # Optionally do a recursive lookup (sub-sub-...-processes)
  if ${arg_recursive}; then
    for pid in ${sub}; do
      __lib_os_ps_get_descendants_ps subsub "${pid}"
      result="${result}${result:+ }${subsub}${subsub:+ }${pid}"
    done
  else
    result="${sub}"
  fi

  # Store temporary list (<result>) in user-defined variable (<arg_varname>)
  eval "${arg_varname}=\${result}"
}


#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_get_mem
#  DESCRIPTION:  Retrieve a process's memory (RAM) usage
# PARAMETER  1:  Process ID (PID)
#            2:  Output unit (default: 'B'), in
#                  Bits (b|kb|Mb|Gb|Tb|Pb|Eb|Zb|Yb), or
#                  Bytes (B|kB|MB|GB|TB|PB|EB|ZB|YB)
#      OUTPUTS:  Memory (RAM) usage (<memory.stat>) to <stdout>
#===============================================================================
lib_os_ps_get_mem() {
  local arg_pid="$1"
  local arg_unit="${2:-B}"

  lib_core_is --cmd "getconf"                                 && \
  [ -n "${LIB_OS_DIR_PROCFS}" ]                               && \
  lib_core_is --file "${LIB_OS_DIR_PROCFS}/${arg_pid}/statm"  || \
  return

  __lib_os_ps_get_mem "$@"
}

__lib_os_ps_get_mem() {
  local arg_pid="$1"
  local arg_unit="${2:-B}"

  local mem_pages       # Memory usage in pages
  local mem_bytes       # Memory usage in bytes
  local pagesize_bytes  # Size of a page in bytes

  # Get page size as "/proc/<pid>/statm" output is always in pages
  pagesize_bytes="$(getconf PAGESIZE)"

  mem_pages="$(cut -d" " -f2 < "${LIB_OS_DIR_PROCFS}/${arg_pid}/statm")"
  mem_bytes="$(( mem_pages * pagesize_bytes ))"
  lib_math_convert_unit "${mem_bytes}" "B" "${arg_unit}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_get_ownpid
#  DESCRIPTION:  Get current shell's process ID
# PARAMETER  1:  Variable (name) where PID will be stored (must not be 'p')
#      OUTPUTS:  Saves current shell's PID in the variable defined in param <1>
#===============================================================================
lib_os_ps_get_ownpid() {
  local arg_varname="$1"
  local p

  case "${arg_varname}" in
    p) return 1 ;;
    *) lib_core_is --varname "${arg_varname}" || return ;;
  esac

  p="$(exec sh -c 'echo "$PPID"')" && \
  eval "${arg_varname}=\$p"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_get_pid
#  DESCRIPTION:  Retrieve process ID(s) from a process defined via its name
# PARAMETER  1:  Process name
#      OUTPUTS:  Process ID(s) to <stdout> (separated by <newline>)
#===============================================================================
lib_os_ps_get_pid() {
  local arg_procname="$1"
  lib_core_is --not-empty "${arg_procname}" || return

  __lib_os_ps_get_pid "$@"
}

__lib_os_ps_get_pid() {
  local arg_procname="$1"

  local line
  ps -eo pid,args             \
    | grep "${arg_procname}"  \
    | grep -v grep            \
    | while read line; do
      line="$(lib_core_str_remove_leading_spaces "${line}")"
      printf "%s\n" "${line}" | cut -d " " -f 1
    done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_kill_by_name
#  DESCRIPTION:  Kill a process by its name
# PARAMETER  1:  Process name
#            2:  (Optional) Kill signal number (default: '15' (SIGTERM))
#===============================================================================
lib_os_ps_kill_by_name() {
  local arg_procname="$1"
  local arg_signal="${2:-15}"

  lib_core_is --not-empty "${arg_procname}" && \
  lib_core_is --signal "${arg_signal}"      || \
  return

  __lib_os_ps_kill_by_name "$@"
}

__lib_os_ps_kill_by_name() {
  local arg_procname="$1"
  local arg_signal="${2:-15}"

  local pids
  pids="$(lib_os_ps_get_pid "${arg_procname}" | xargs)"

  lib_core_is --not-empty "${pids}" && lib_core_sudo kill -${arg_signal} ${pids}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_kill_by_pid
#  DESCRIPTION:  Kill one or several processes by their PIDs
# PARAMETER  1:  PID(s)
#            2:  (Optional) Kill signal number (default: '15' (SIGTERM))
#            3:  (Optional) Also children processes?
#                (true|false) (default: 'false')
#            4:  (Optional) Wait for processes until they got killed?
#                (true|false) (default: 'false')
#            5:  (Optional)  Kill with root privileges? (true|false)
#                (default: 'false')
#===============================================================================
lib_os_ps_kill_by_pid() {
  local arg_pids="$1"
  local arg_signal="${2:-15}"
  local arg_children="${3:-false}"
  local arg_wait="${4:-false}"
  local arg_su="${5:-false}"

  lib_core_is --int-pos ${arg_pids}                               && \
  lib_core_is --signal "${arg_signal}"                            && \
  lib_core_is --bool "${arg_children}" "${arg_wait}" "${arg_su}"  || \
  return

  __lib_os_ps_kill_by_pid "$@"
}

__lib_os_ps_kill_by_pid() {
  local arg_pids="$1"
  local arg_signal="${2:-15}"
  local arg_children="${3:-false}"
  local arg_wait="${4:-false}"
  local arg_su="${5:-false}"

  local kill_pids                             # the PIDs that will be killed
  local pid                                   # for-loop variable

  #-----------------------------------------------------------------------------
  #  Kill sub-processes, too?
  #-----------------------------------------------------------------------------
  if ${arg_children}; then
    local children_pids
    for pid in ${arg_pids}; do
      #------------------------------------------------------------------------
      #  For each parent PID: first add sub PIDs to the list, then the parent
      #------------------------------------------------------------------------
      lib_os_ps_get_descendants children_pids "${pid}"
      kill_pids="${kill_pids:+${kill_pids} }${children_pids:+${children_pids} }${pid}"
    done
  else
    kill_pids="${arg_pids}"
  fi

  #-----------------------------------------------------------------------------
  #  Kill and optionally wait for termination
  #-----------------------------------------------------------------------------
  for pid in ${kill_pids}; do
    # Before killing check if process is still running
    lib_os_ps_exists "${pid}"                                       && \
    if ${arg_su}; then
      lib_core_sudo kill -${arg_signal} ${pid}
    else
      kill -${arg_signal} ${pid}
    fi                                                              && \

    # <|| true> : 'wait' could fail if process is killed immediately
    if ${arg_wait}; then wait "${pid}" 2>/dev/null || true; fi
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_kill_by_pidfile
#  DESCRIPTION:  Kill a process by a PID file
# PARAMETER  1:  PID file
#            2:  (Optional) Kill signal number (default: '15' (SIGTERM))
#            3:  (Optional) Also children processes? (true|false)
#                (default: 'true')
#            4:  (Optional) Wait for processes until they got killed?
#                (true|false) (default: 'false')
#            5:  (Optional) Kill with root privileges? (true|false)
#                (default: 'true')
#            6:  (Optional) Remove PID file? (true|false, default: 'true')
#===============================================================================
lib_os_ps_kill_by_pidfile() {
  local arg_pidfile="$1"
  local arg_signal="${2:-15}"
  local arg_children="${3:-true}"
  local arg_wait="${4:-false}"
  local arg_su="${5:-true}"
  local arg_remove="${6:-true}"

  lib_core_is --file "${arg_pidfile}"                           && \
  lib_core_is --signal "${arg_signal}"                          && \
  lib_core_is --bool                                            \
    "${arg_children}" "${arg_wait}" "${arg_su}" "${arg_remove}" || \
  return

  __lib_os_ps_kill_by_pidfile "$@"
}

__lib_os_ps_kill_by_pidfile() {
  local arg_pidfile="$1"
  local arg_signal="${2:-15}"
  local arg_children="${3:-true}"
  local arg_wait="${4:-false}"
  local arg_su="${5:-true}"
  local arg_remove="${6:-true}"

  lib_os_ps_kill_by_pid                                                 \
    "$(xargs < "${arg_pidfile}")"   "${arg_signal}"   "${arg_children}" \
    "${arg_wait}"                   "${arg_su}"

  if ${arg_remove}; then
    if ${arg_su}; then
      lib_core_sudo rm -f "${arg_pidfile}"
    else
      rm -f "${arg_pidfile}"
    fi
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ps_pidlock
#
#  DESCRIPTION:  Enable a script to lock itself (prevent further instances)
#                by using a PID file
#
#      GLOBALS:  LIB_OS_PS_PIDLOCK_FILE  LIB_OS_PS_PIDLOCK_LOCKED
#
# PARAMETER  1:  --lock     Lock script
#                           If PID file exists then check if another instance
#                           is really running or if the file is just orphaned.
#                           If it is orphaned, delete it and create a new file,
#                           otherwise exit.
#                           If PID file does not exist try to create it.
#
#                           !!! IMPORTANT !!!
#                           This will also install a trap handler to unlock your
#                           script (= remove the PID file) on EXIT.
#                           If you install your own trap handler for EXIT
#                           "signal" please make sure to remove the PID file
#                           by using the '--unlock' option.
#
#                --getpid   Print PID from PID file to <stdout>,
#                           e.g. for usage within your script's trap handler.
#
#                --unlock   Unlock script
#                           Remove PID file but only if it was previously
#                           created by this function, e.g. for usage within
#                           your script's trap handler.
#
#                --reset    Reset <LIB_OS_PS_PIDLOCK_FILE> to 'false', allowing
#                           '--lock' to run again, e.g. for locking subshells.
#
#            2:  (Optional) PID filepath (default: see <LIB_OS_PS_PIDLOCK_FILE>)
#                (only with '--lock')
#
#            3:  Exit? (true|false) (default: 'false')
#
#            4:  Print a message in case another instance is already running
#                (true|false) (default: 'true')
#
#      OUTPUTS:  In case an error occurs a message is printed to
#                <stderr> and <syslog>.
#
#   RETURNS  0:  OK
#            1:  Another instance is already running, could not create PID file
#                PID file does not exist, script is already locked, etc.
#            2:  At least one of the parameters contains an invalid argument.
#===============================================================================
lib_os_ps_pidlock() {
  local arg_select="$1"
  local arg_pidfile="${2:-${LIB_OS_PS_PIDLOCK_FILE}}"
  local arg_exit="${3:-false}"
  local arg_msg_existing="${4:-true}"

  lib_core_is --bool "${arg_exit}" "${arg_msg_existing}" || \
  return 2

  local pid
  case "${arg_select}" in
    --lock)
      #-------------------------------------------------------------------------
      #  Lock mode
      #-------------------------------------------------------------------------
      #  Can be run only once (except when using '--reset' before)
      ! ${LIB_OS_PS_PIDLOCK_LOCKED}                                         && \

      #  Check for existing PID file
      if lib_core_is --file "${arg_pidfile}"; then
        pid="$(cat "${arg_pidfile}")" && \
        if lib_core_sudo kill -0 "${pid}" 2>/dev/null; then
          # Process is really running
          if ${arg_msg_existing}; then
            lib_msg_message --auto --error                                                      \
              "Another instance of this script is already running (PID <${pid}>). Aborting..."
          fi

          if ${arg_exit}; then exit 1; else return 1; fi
        else
          # Orphaned PID file
          lib_core_sudo rm -f "${arg_pidfile}"
        fi
      fi                                                                    && \

      #  Create new PID file ...
      # echo $$ | lib_core_sudo tee "${arg_pidfile}" >/dev/null               && \
      lib_os_ps_get_ownpid pid                                              && \
      echo ${pid} | lib_core_sudo tee "${arg_pidfile}" >/dev/null           && \

      #  ... and install trap handler to remove PID file on exit
      trap "lib_core_sudo rm -f \"${arg_pidfile}\"" EXIT                    && \
      trap "exit 1" HUP INT QUIT TERM                                       && \

      #  Global variables ensure that '--getpid|--reset|--unlock'
      #  work without any further arguments
      LIB_OS_PS_PIDLOCK_FILE="${arg_pidfile}"                               && \
      LIB_OS_PS_PIDLOCK_LOCKED="true"                                       || \

      { lib_msg_message --auto --error                                  \
          "Could not create PID file at <${arg_pidfile}>. Aborting..."  \
          "" "${arg_exit}" "1"
        return $?
      }
      ;;

    --getpid)
      #-------------------------------------------------------------------------
      #  GetPID mode
      #-------------------------------------------------------------------------
      lib_core_is --file "${LIB_OS_PS_PIDLOCK_FILE}"  && \
      ${LIB_OS_PS_PIDLOCK_LOCKED}                     && \
      pid="$(cat "${LIB_OS_PS_PIDLOCK_FILE}")"        && \
      lib_core_sudo kill -0 "${pid}" 2>/dev/null      && \
      printf "%s" "${pid}"
      ;;

    --unlock)
      #-------------------------------------------------------------------------
      #  Unlock mode
      #-------------------------------------------------------------------------
      ${LIB_OS_PS_PIDLOCK_LOCKED} && \
      lib_core_sudo rm -f "${LIB_OS_PS_PIDLOCK_FILE}"
      ;;

    --reset)
      #-------------------------------------------------------------------------
      #  Reset mode
      #-------------------------------------------------------------------------
      LIB_OS_PS_PIDLOCK_LOCKED="false"
      ;;

    *)
      return 2
      ;;
  esac
}

#===============================================================================
#  FUNCTIONS (SCP/SSH)
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_os_scp_no_host_key_check
#  DESCRIPTION:  !!! CAUTION - PLEASE USE THIS FUNCTION CAREFULLY !!!
#                SCP wrapper (SSH's host key binding check disabled)
# PARAMETER  1:  Source URI, e.g. 'username@host.fqdn:/tmp/app.log'
#            2:  Destination URI, e.g. '/home/ubuntu'
#         3...:  SCP options, e.g. '-r'
#===============================================================================
lib_os_scp_no_host_key_check() {
  local arg_src="$1"
  local arg_dest="$2"
  shift;shift

  scp                               \
    -o StrictHostKeyChecking=no     \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=error               \
    $@                              \
    "${arg_src}"                    \
    "${arg_dest}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ssh_no_host_key_check
#  DESCRIPTION:  !!! CAUTION - PLEASE USE THIS FUNCTION CAREFULLY !!!
#                SSH command wrapper (SSH's host key binding check disabled)
# PARAMETER  1:  SSH URI, e.g. username@host.fqdn
#                (multiple URIs separated by space)
#       2 ... :  Command(s) to execute - please make sure ...
#                 - to escape (\) the following characters when using them
#                   " & | ; $ (escape $ only for remote variables)
#                 - to use \; in for/if/while/... constructs, e.g.
#                   for ...\; do      \
#                     (first command) \
#                     ...             \
#                     (last command)  \;\
#                   done
#===============================================================================
lib_os_ssh_no_host_key_check() {
  local arg_ssh_uris="$1"
  shift

  local ssh
  for ssh in ${arg_ssh_uris}; do
    ssh "${ssh}"                      \
      -o StrictHostKeyChecking=no     \
      -o UserKnownHostsFile=/dev/null \
      -o LogLevel=error               \
      /bin/sh <<CMD
        $@
CMD
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ssh_test
#  DESCRIPTION:  Check if one or more hosts are accessible via SSH (batch mode)
# PARAMETER  1:  SSH URI host, e.g. username@host.fqdn
#                (multiple hosts separated by space)
#            2:  SSH port (optional, default '22')
#            3:  Timeout in s (optional, default '1')
#            4:  Print error message if test fails (true|false)
#                (default: 'true')
#   RETURNS  0:  All commands exist
#            1:  At least one command does not exist
#===============================================================================
lib_os_ssh_test() {
  lib_core_args_passed "$@" || return
  local arg_ssh_uris="$1"
  local arg_ssh_port="${2:-22}"
  local arg_timeout="${3:-1}"
  local arg_print_error="${4:-true}"

  lib_core_is --bool "${arg_print_error}" || return

  #  Check for password-free (no prompt) SSH access
  local result="0"
  local ssh
  for ssh in ${arg_ssh_uris}; do
    if ! timeout "${arg_timeout}"       \
      ssh                               \
        -q                              \
        -o   "BatchMode=yes"            \
        -o   "StrictHostKeyChecking=no" \
        -p   "${arg_ssh_port}"          \
        "${ssh}"                        \
        "exit"
    then
      result="1"
      if ${arg_print_error}; then
        lib_core_echo "true" "false"                          \
          "ERROR: Key-based SSH authentication test failed."  \
          "source"      "$(id -u -n)@$(uname -n)"             \
          "destination" "${ssh}"                              \
          "port"        "${arg_ssh_port}"                     \
          "timeout"     "${arg_timeout}s"
      fi
    fi
  done

  return "${result}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_ssh_wrapper
#
#  DESCRIPTION:  !!! CAUTION - PLEASE USE THIS FUNCTION CAREFULLY !!!
#                SSH command wrapper
# PARAMETER
#        1 ...:  (Optional) SSH command line option(s), see 'man ssh'
#                (each option must be separately quoted) (*)
#
#          ...:  SSH URI(s) in the form of 'username@host.fqdn'
#                (each URI must be separately quoted)
#
#          ...:  Command(s) to execute (*)
#
#           (*)  Please make sure ...
#                 - to put a semicolon (;) behind each command,
#                   see EXAMPLE section below
#                 - to escape (\) the following characters when using them
#                   " & | ; $ (escape $ only for remote variables)
#                 - to use \; in for/if/while/... constructs, e.g.
#                   for ...\; do      \
#                     (first command) \
#                     ...             \
#                     (last command)  \;\
#                   done
# EXAMPLE
#            1:  lib_os_ssh_wrapper "" "username@host.fqdn" "echo Test"
#            2:  lib_os_ssh_wrapper "-i \"/path/with spaces/id_rsa\"" "username@host.fqdn" ""
#            3:  lib_os_ssh_wrapper "" "username@host.fqdn" "echo \"Current date/time:\"; date"
#===============================================================================
lib_os_ssh_wrapper() {
  local arg_ssh_params
  while ! lib_core_is --ssh-uri-short "$1"; do
    arg_ssh_params="${arg_ssh_params} $1"
    shift
  done

  local arg_ssh_uris
  while lib_core_is --ssh-uri-short "$1"; do
    arg_ssh_uris="${arg_ssh_uris} $1"
    shift
  done

  lib_core_is --cmd "ssh"                           && \
  eval lib_core_is --ssh-uri-short ${arg_ssh_uris}  || \
  return

  local ssh
  for ssh in ${arg_ssh_uris}; do
    eval ssh ${arg_ssh_params} ${ssh} /bin/sh <<CMD
      $@
CMD
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_os_user_is_member_of
#  DESCRIPTION:  Check if current (or another) user is a member of a certain
#                group
# PARAMETER  1:  Group
#            2:  User (optional, default: <current user>)
#      OUTPUTS:  A message to <stderr> in case user is not a member
#   RETURNS  0:  User is a member
#            1:  User is NO member
#       SOURCE:  Adapted from "https://stackoverflow.com/a/57770610"
#                by "Anthony Geoghegan" (https://stackoverflow.com/users/1640661/anthony-geoghegan)
#                licensed under "CC BY-SA 4.0" (https://creativecommons.org/licenses/by-sa/4.0/)
#===============================================================================
lib_os_user_is_member_of() {
  local arg_group="$1"
  local arg_user="${2:-$(id -un)}"

  local group
  for group in $(id -Gn "${arg_user}") ; do
    if [ "${group}" = "${arg_group}" ]; then
      # User is a member
      return 0
    fi
  done

  # User is not a member
  lib_core_echo "User <${arg_user}> is not a member of <${arg_group}> group." >&2
  return 1
}