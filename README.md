
<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a name="readme-top"></a>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![GNU GPL v3.0 License][license-shield]][license-url]
<!-- [![LinkedIn][linkedin-shield]][linkedin-url] -->



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <!-- <a href="https://github.com/fkemser/SHlib">
    <img src="images/logo.png" alt="Logo" width="80" height="80">
  </a> -->

<h3 align="center">SHlib</h3>

  <p align="center">
    A collection of (mostly) POSIX-compliant functions to extend Bourne-Shell (sh) functionality.
    <br />
    <a href="https://github.com/fkemser/SHlib"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/fkemser/SHlib">View Demo</a>
    ·
    <a href="https://github.com/fkemser/SHlib/issues">Report Bug</a>
    ·
    <a href="https://github.com/fkemser/SHlib/issues">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#built-with">Built With</a></li>
        <li><a href="#testing-environment">Testing Environment</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li>
          <a href="#prerequisites">Prerequisites</a>
          <ul>
            <li><a href="#debian">Debian</a></li>
          </ul>
        </li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li>
      <a href="#documentation">Documentation</a>
      <ul>
        <li><a href="#clibsh">c.lib.sh</a></li>
        <li><a href="#corelibsh">core.lib.sh</a></li>
        <li><a href="#iperf3libsh">iperf3.lib.sh</a></li>
        <li><a href="#mathlibsh">math.lib.sh</a></li>
        <li><a href="#msglibsh">msg.lib.sh</a></li>
        <li><a href="#netlibsh">net.lib.sh</a></li>
        <li><a href="#nmlibsh">nm.lib.sh</a></li>
        <li><a href="#openwrtlibsh">openwrt.lib.sh</a></li>
        <li><a href="#oslibsh">os.lib.sh</a></li>
        <li><a href="#tcpdumplibsh">tcpdump.lib.sh</a></li>
      </ul>
    </li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

After developing several shell scripts it was time to gather recurring code patterns and store them in a library. The goal of this project is to provide a (mostly) POSIX-/Bourne-Shell(sh)-compliant library that provides

- essential functions, such as
  - checking the existence of a command/directory/file,
  - performing regular expression checks,
  - converting/modifying variables,
  - string manipulation,

- mathematical functions and operations, such as
  - advanced calculation using 'bc'
    (supporting floating point numbers),
  - converting units, e.g. from 'MB' into 'GB',
  - checking if a number is within a specified range,
  - functions like 'abs' or 'sign',

- logging and output formatting functions, such as
  - system logging,
  - formatting terminal messages,
  - providing message templates, e.g. license notification,

- network related functions, such as
  - changing an interface's IP address,
  - retrieving interface statistics,
  - creating/removing bridges,
  - performing DNS lookups,

- OS-related functions, such as
  - retrieving CPU/RAM information,
  - process-related tasks,
  - modifying bootloader settings, or
  - SSH/SCP wrapper,

- special tool-related functions, e.g. for
  - iperf3,
  - NetworkManager,
  - OpenWRT,
  - Tcpdump,

- and much more.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Built With

[![Shell Script][Shell Script-shield]][Shell Script-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### Testing Environment

The project has been developed and tested on the following system:

| Info | Description
---: | ---
OS | Raspbian GNU/Linux 11 (bullseye)
Kernel | 5.15.61-v7l+
Packages | [bc (1.07.1-2 and others)](https://packages.debian.org/bullseye/bc)
|| [coreutils (8.32-4 und andere)](https://packages.debian.org/bullseye/coreutils)
|| [dash (0.5.11+git20200708+dd9ef66-5)](https://packages.debian.org/bullseye/dash)
|| [dialog (1.3-20201126-1)](https://packages.debian.org/bullseye/dialog)
|| [iproute2 (5.10.0-4)](https://packages.debian.org/bullseye/iproute2)
|| [libc-bin (2.31-13+deb11u6)](https://packages.debian.org/bullseye/libc-bin)
|| [netcat (1.10-46)](https://packages.debian.org/bullseye/netcat)
|| [network-manager (1.30.6-1+deb11u1)](https://packages.debian.org/bullseye/network-manager)
|| [sudo (1.9.5p2-3+deb11u1)](https://packages.debian.org/bullseye/sudo)
|| [udev (247.3-7+deb11u2)](https://packages.debian.org/bullseye/udev)

> :information_source: Most of the packages are optional and only needed for certain library functions.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- PREREQUISITES -->
## Prerequisites

Please make sure that the following dependencies are installed:

* POSIX-/Bourne-compliant shell
* Additional packages (only needed for certain functions, see [Testing Environment](#testing-environment))

Below you can find distribution-specifc installation instructions (only needed for additional packages).

### Debian

```sh
sudo apt install bc coreutils dash dialog iproute2 libc-bin netcat network-manager sudo udev
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- INSTALLATION-->
## Installation

1. Change into the root folder of a (local) repo that will use the library.
2. Add this repo as a submodule:
	```sh
   git submodule add https://github.com/fkemser/SHlib lib/SHlib
   ```
3. To source (use) the library within your project simply put the following code at the beginning of your script:

    ```sh
    # Get current working direcotry
    readonly CWD="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

    # Change to library directory
    # TODO: Adapt the path according to your repository structure
    cd "${CWD}/../lib/SHlib" >/dev/null 2>&1 || return

    # Source libraries
    for lib in ./*.lib.sh; do
      . "${lib}"                                                                || \
      {
        printf "%s\n\n"                                                         \
          "ERROR: Library '$lib' could not be loaded. Aborting..." >&2
        cd "${CWD}"
        return 1
      }
    done

    # Restore original directory
    cd "${CWD}"
    ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- DOCUMENTATION -->
## Documentation

> :warning: The following sections only give a brief overview. Before running any of these functions please have a look at the comments in the source files.

The library is separated in several files where each file stores a certain category of functions and/or constants:

| File (/lib/...) | Description
---: | ---
[`c.lib.sh`](#clibsh) | Constants used by other library files and shell projects
[`core.lib.sh`](#corelibsh) | Essential functions, e.g. type/regex checks, variable manipulation, etc.
[`iperf3.lib.sh`](#iperf3libsh) | `iperf3`-related functions
[`math.lib.sh`](#mathlibsh) | Mathematical functions and operations
[`msg.lib.sh`](#msglibsh) | Logging and output formatting functions
[`net.lib.sh`](#netlibsh) | Network-related functions
[`nm.lib.sh`](#nmlibsh) | `nmcli`-related functions (NetworkManager)
[`openwrt.lib.sh`](#openwrtlibsh) | `OpenWRT`-related functions
[`os.lib.sh`](#oslibsh) | OS-related functions
[`tcpdump.lib.sh`](#tcpdumplibsh) | `tcpdump`-related functions

<p align="right">(<a href="#readme-top">back to top</a>)</p>



### `c.lib.sh`
This file contains constans that are used by other library files and/or other projects, e.g.
  * Linux distribution IDs,
  * language IDs (ISO 639-1),
  * further text constants.

<p align="right">(<a href="#documentation">back to overview</a>)</p>



### `core.lib.sh`
Function | Description
:--- | :---
`lib_core_args_passed` | Check if at least one argument has been passed
`lib_core_bool2int` | Convert one or more boolean values to integer values
`lib_core_can_sudo_nopasswd` | Check if current user can sudo without password prompt
`lib_core_char_repeat` | Repeat a given character for a certain number of times
`lib_core_cmd_exists` | Check if (one or more) commands exist on the host
`lib_core_cmd_exists_su` | Check if (one or more) commands exist when using root
`lib_core_echo` | Print a message
`lib_core_env_append` | Append one or more values to an environmental variable
`lib_core_env_remove` | Remove one or more values from an environmental variable
`lib_core_expand_tilde` | Expand '~' to the user's home directory '$HOME' in a given path
`lib_core_file_get` | Get file information
`lib_core_file_touch` | Create one or more files and (if needed) their parent folders
`lib_core_float2int` | Convert one or more floating point numbers to integer
`lib_core_int_is_within_range` | Check if an integer number is between a given range. This function is only intended for integer numbers. To process floating point numbers please use `lib_math_is_within_range`.
`lib_core_int_max` | Return maximum of a list of integer values
`lib_core_int_min` | Return minimum of a list of integer values
`lib_core_is` | Perform checks on current environment (root, interactive shell, etc.) and arguments (bool, file, integer, etc.)
`lib_core_list_contains_str` | Looks for a string within a delimited list of strings
`lib_core_list_contains_str_ptr` | Looks for a string within a delimited list of strings where the list does not(!) contain the strings themselves but their variable pointers
`lib_core_parse_credentials` | Parse credentials that are provided via an environmental variable
`lib_core_path_get_abs` | Get absolute path to a directory or file (in case it contains relative paths or symlinks)
`lib_core_regex` | Check if a given string matches a regular expression
`lib_core_str_get_length` | Get length of a string
`lib_core_str_filter_and_sort` | Filter and sort a (multiline) string
`lib_core_str_get_substr` | Extract a substring from a given string
`lib_core_str_is_multiline` | Check if one or more strings contain more than one line
`lib_core_str_random` | Generate a random string
`lib_core_str_remove_leading` | Remove leading character(s) from one or multiple string(s)
`lib_core_str_remove_newline` | Replace line breaks from a string by a certain character
`lib_core_str_remove_trailing` | Remove trailing character(s) from one or multiple string(s)
`lib_core_str_replace_char` | Replace (or delete) all occurrences of a certain character in a string
`lib_core_str_split` | Split a given string into substrings (separated by `<newline>`) but preserve quoted (`"..."`) substrings even if they contain spaces
`lib_core_str_to` | Convert one or multiple string(s)
`lib_core_sudo` | Execute one or more commands with root privileges
`lib_core_sudo_background` | Execute one or more commands with root privileges and put them into background
`lib_core_sysfs_get` | Wrapper for accessing `sysfs`
`lib_core_time_timestamp` | Get current time in UNIX Epoch format

<p align="right">(<a href="#documentation">back to overview</a>)</p>




### `iperf3.lib.sh`
| Function | Description
:--- | :---
`lib_iperf3_log_parse_transfer_rate` | Extract transfer rate from an ipferf3 log

<p align="right">(<a href="#documentation">back to overview</a>)</p>

### `math.lib.sh`
| Function | Description
:--- | :---
`lib_math_abs` | Calculate absolute value of one or more given values (`abs(x)`)
`lib_math_calc` | Perform a calculation supporting decimal places by using `bc`
`lib_math_convert_unit` | Convert a given value (integer/float) from one unit to another
`lib_math_is_within_range` | Check if an (integer or float) number is between a given range
`lib_math_is_within_range_u` | Like `lib_math_is_within_range` but with units
`lib_math_sign` | Get sign of one or more given values (`sign(x)`)

<p align="right">(<a href="#documentation">back to overview</a>)</p>



### `msg.lib.sh`
| Function | Description
:--- | :---
`lib_msg_dialog_autosize` | Calculate the size of dialog boxes (see `man dialog`)
`lib_msg_echo` | Print error/info/warning message to `stdout`/`stderr`
`lib_msg_log` | Log error/info/warning message to `syslog`
`lib_msg_message` | Log/Print error/info/warning message and optionally exit
`lib_msg_print_borderstring` | Print a string surrounded by border characters
`lib_msg_print_heading` | Format a string as a heading
`lib_msg_print_list` | Format and print values from a list
`lib_msg_print_propvalue` | Print a formatted table of property/value pairs to `stdout`
`lib_msg_term_get` | Get current terminal window's settings

<p align="right">(<a href="#documentation">back to overview</a>)</p>



### `net.lib.sh`
| Function | Description
:--- | :---
`lib_net_bridge_create` | Create a network bridge and attach one or more physical interfaces to it
`lib_net_bridge_get_members` | Get network bridge members
`lib_net_bridge_remove` | Remove a network bridge
`lib_net_dns_resolve` | Resolve a given hostname, FQDN, SRV record, into IP address(es) (automatically detect the type of the input string)
`lib_net_host_is_up` | Check if a host is reachable on a given port
`lib_net_iface_get_sysfs / lib_net_iface_get_sysfs_statistics` | Get information about network interface using Linux kernel's <sysfs-class-net> / <sysfs-class-net-statistics>
`lib_net_iface_get_ip` | Get the current IP address of a network interface
`lib_net_iface_get_master` | Get master bridge that a (slave) device is attached to
`lib_net_iface_ip` | Add/Remove an IP address to/from a network device
`lib_net_iface_is` | Checks if one or interfaces are in a certain state (up|down|...)
`lib_net_ifconfig_parse_stats` | Parse <ifconfig> output

<p align="right">(<a href="#documentation">back to overview</a>)</p>



### `nm.lib.sh`
| Function | Description
:--- | :---
`lib_nm_con_exists` | Check if a a connection exists and optionally check if it's active
`lib_nm_con_get` | Get a certain connection setting/property
`lib_nm_con_list` | List connections (optionally filtered)
`lib_nm_con_modify` | Modify a certain connection setting/property

<p align="right">(<a href="#documentation">back to overview</a>)</p>



### `openwrt.lib.sh`
| Function | Description
:--- | :---
`lib_openwrt_procd_install` | Install and optionally enable/start procd init service

<p align="right">(<a href="#documentation">back to overview</a>)</p>




### `os.lib.sh`
| Function | Description
:--- | :---
`lib_os_cgroup_parse_cpuacct` | Parse `cgroup` CPU accounting controller statistics
`lib_os_cgroup_parse_mem` | Parse `cgroup` memory statistics
`lib_os_boot_configure` | Modify bootloader settings
`lib_os_boot_configure_grub` | Modify "GRUB_CMDLINE_LINUX_DEFAULT" in GRUB settings
`lib_os_cpu_get` | Get CPU statistics
`lib_os_cpu_has_feature` | Check if (all) installed CPU(s) support(s) a given feature
`lib_os_dev_bus_usb_list` | List all currently connected USB devices with their corresponding device path (`/dev/...`), their manufacturer and their product name
`lib_os_dev_bus_usb_list_by_busdev` | List device paths (`/dev/...`) of USB devices matching (one or more) given bus and device numbers
`lib_os_dev_bus_usb_list_by_vidpid` | List device paths (`/dev/...`) of USB devices matching (one or more) given vendor and/or product IDs
`lib_os_dev_class_list` | List device paths (`/dev/...`) and corresponding IDs/names of a certain class
`lib_os_dev_is_mounted` | Check if (one or more) block devices are mounted
`lib_os_dev_umount` | Unmount (one or more) block devices including slave devices
`lib_os_dev_lsblk` | Get information about (one or more) block device using `lsblk`
`lib_os_get` | Get statistics about current distribution (ID, version, etc.)
`lib_os_is_subshell` | Check if the function that calls this function is running in a subshell
`lib_os_lib` | Check existence or get absolute path of a given library (.so) file
`lib_os_proc_meminfo` | Get memory statistics
`lib_os_ps_exists` | Check if a process with a given PID exists
`lib_os_ps_get_descendants` | Look for sub-processes
`lib_os_ps_get_mem` | Retrieve a process's memory (RAM) usage
`lib_os_ps_get_ownpid` | Get current shell's process ID
`lib_os_ps_get_pid` | Retrieve process ID(s) from a process defined via its name
`lib_os_ps_kill_by_name` | Kill a process by its name
`lib_os_ps_kill_by_pid` | Kill one or several processes by their PIDs
`lib_os_ps_kill_by_pidfile` | Kill a process by a PID file
`lib_os_ps_pidlock`| Enable a script to lock itself (prevent further instances) by using a PID file
`lib_os_scp_no_host_key_check` | SCP wrapper (SSH's host key binding check disabled)
`lib_os_ssh_no_host_key_check` | SSH command wrapper (SSH's host key binding check disabled)
`lib_os_ssh_test` | Check if one or more hosts are accessible via SSH (batch mode)
`lib_os_ssh_wrapper` | SSH command wrapper
`lib_os_user_is_member_of` | Check if current (or another) user is a member of a certain group

<p align="right">(<a href="#documentation">back to overview</a>)</p>




### `tcpdump.lib.sh`
| Function | Description
:--- | :---
`lib_tcpdump_parse_logfile` | Parse tcpdump logfile

<p align="right">(<a href="#documentation">back to overview</a>)</p>



<!-- ROADMAP -->
## Roadmap

See the [open issues](https://github.com/fkemser/SHlib/issues) for a full list of proposed features (and known issues).

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement".
Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- LICENSE -->
## License

Distributed under the **GNU Lesser General Public License v3.0 (or later)**. See [`LICENSE`][license-url] for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Project Link: [https://github.com/fkemser/SHlib](https://github.com/fkemser/SHlib)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ACKNOWLEDGMENTS -->
## Acknowledgments
###
* [othneildrew/Best-README-Template](https://github.com/othneildrew/Best-README-Template)
* [Ileriayo/markdown-badges](https://github.com/Ileriayo/markdown-badges)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/fkemser/SHlib.svg?style=for-the-badge
[contributors-url]: https://github.com/fkemser/SHlib/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/fkemser/SHlib.svg?style=for-the-badge
[forks-url]: https://github.com/fkemser/SHlib/network/members
[stars-shield]: https://img.shields.io/github/stars/fkemser/SHlib.svg?style=for-the-badge
[stars-url]: https://github.com/fkemser/SHlib/stargazers
[issues-shield]: https://img.shields.io/github/issues/fkemser/SHlib.svg?style=for-the-badge
[issues-url]: https://github.com/fkemser/SHlib/issues
[license-shield]: https://img.shields.io/github/license/fkemser/SHlib.svg?style=for-the-badge
[license-url]: https://github.com/fkemser/SHlib/blob/main/LICENSE
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/linkedin_username
[screenshot1]: res/screenshot1.gif
[screenshot2]: res/screenshot2.gif
[screenshot3]: res/screenshot3.gif
[screenshot4]: res/screenshot4.gif

[LaTeX-shield]: https://img.shields.io/badge/latex-%23008080.svg?style=for-the-badge&logo=latex&logoColor=white
[LaTeX-url]: https://www.latex-project.org/
[Shell Script-shield]: https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white
[Shell Script-url]: https://pubs.opengroup.org/onlinepubs/9699919799/