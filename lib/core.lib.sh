#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2025 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/core.lib.sh
#
#        USAGE:   . core.lib.sh
#
#  DESCRIPTION:   Shell library containing essential functions such as
#                   - checking the existence of a command/directory/file,
#                   - performing regular expression checks,
#                   - converting and modifying variables,
#                   - string manipulation.
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
if lib_core 2>/dev/null; then return; fi

#===============================================================================
#  IMPORT
#===============================================================================
#-------------------------------------------------------------------------------
#  Load libraries
#-------------------------------------------------------------------------------
for lib in c; do
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
# Indicates if the parent shell (the shell that sources this library)
# is a terminal ('true') or not ('false')
LIB_CORE_PARENT_SHELL_IS_TERMINAL=""

#===============================================================================
#  REGULAR EXPRESSIONS (see lib_core_regex()>)
#===============================================================================
#-------------------------------------------------------------------------------
#  RFC 2234
#-------------------------------------------------------------------------------
# See also: https://datatracker.ietf.org/doc/html/rfc2234
readonly LIB_CORE_REGEX_RFC2234_ALPHA="([A-Za-z])"
readonly LIB_CORE_REGEX_RFC2234_BIT="([01])"
readonly LIB_CORE_REGEX_RFC2234_CHAR="([\x01-\x7F])"
readonly LIB_CORE_REGEX_RFC2234_CR="([\r])"
readonly LIB_CORE_REGEX_RFC2234_CRLF="([\r\n])"
readonly LIB_CORE_REGEX_RFC2234_CTL="([\x00-\x1F\x7F])"
readonly LIB_CORE_REGEX_RFC2234_DIGIT="([0-9])"
readonly LIB_CORE_REGEX_RFC2234_DQUOTE="([\"])"
readonly LIB_CORE_REGEX_RFC2234_HEXDIG="([0-9A-Fa-f])"
readonly LIB_CORE_REGEX_RFC2234_HTAB="([\t])"
readonly LIB_CORE_REGEX_RFC2234_LF="([\n])"
readonly LIB_CORE_REGEX_RFC2234_LWSP="(([ \t]|([\r\n][ \t]))*)"
readonly LIB_CORE_REGEX_RFC2234_OCTET="([\x00-\xFF])"
readonly LIB_CORE_REGEX_RFC2234_SP="([ ])"
readonly LIB_CORE_REGEX_RFC2234_VCHAR="([\x21-\x7E])"
readonly LIB_CORE_REGEX_RFC2234_WSP="([ \t])"

#-------------------------------------------------------------------------------
#  RFC 3986
#-------------------------------------------------------------------------------
# See also: https://datatracker.ietf.org/doc/html/rfc3986
readonly LIB_CORE_REGEX_RFC3986_SUB_DELIMS="([!$&'()*+,;=])"
readonly LIB_CORE_REGEX_RFC3986_GEN_DELIMS="([:/?#@]|[][])"
readonly LIB_CORE_REGEX_RFC3986_RESERVED="(${LIB_CORE_REGEX_RFC3986_GEN_DELIMS}|${LIB_CORE_REGEX_RFC3986_SUB_DELIMS})"
readonly LIB_CORE_REGEX_RFC3986_UNRESERVED="(${LIB_CORE_REGEX_RFC2234_ALPHA}|${LIB_CORE_REGEX_RFC2234_DIGIT}|[._~-])"

readonly LIB_CORE_REGEX_RFC3986_PCT_ENCODED="(%${LIB_CORE_REGEX_RFC2234_HEXDIG}{2})"

readonly LIB_CORE_REGEX_RFC3986_PCHAR="(${LIB_CORE_REGEX_RFC3986_UNRESERVED}|${LIB_CORE_REGEX_RFC3986_PCT_ENCODED}|${LIB_CORE_REGEX_RFC3986_SUB_DELIMS}|[:@])"

readonly LIB_CORE_REGEX_RFC3986_FRAGMENT="((${LIB_CORE_REGEX_RFC3986_PCHAR}|[/?])*)"

readonly LIB_CORE_REGEX_RFC3986_QUERY="${LIB_CORE_REGEX_RFC3986_FRAGMENT}"

readonly LIB_CORE_REGEX_RFC3986_SEGMENT_NZ_NC="((${LIB_CORE_REGEX_RFC3986_UNRESERVED}|${LIB_CORE_REGEX_RFC3986_PCT_ENCODED}|${LIB_CORE_REGEX_RFC3986_SUB_DELIMS}|@){1,})"
readonly LIB_CORE_REGEX_RFC3986_SEGMENT_NZ="(${LIB_CORE_REGEX_RFC3986_PCHAR}{1,})"
readonly LIB_CORE_REGEX_RFC3986_SEGMENT="(${LIB_CORE_REGEX_RFC3986_PCHAR}*)"

readonly LIB_CORE_REGEX_RFC3986_PATH_EMPTY="()"
readonly LIB_CORE_REGEX_RFC3986_PATH_ROOTLESS="(${LIB_CORE_REGEX_RFC3986_SEGMENT_NZ}(/${LIB_CORE_REGEX_RFC3986_SEGMENT})*)"
readonly LIB_CORE_REGEX_RFC3986_PATH_NOSCHEME="(${LIB_CORE_REGEX_RFC3986_SEGMENT_NZ_NC}(/${LIB_CORE_REGEX_RFC3986_SEGMENT})*)"
readonly LIB_CORE_REGEX_RFC3986_PATH_ABSOLUTE="(/(${LIB_CORE_REGEX_RFC3986_SEGMENT_NZ}(/${LIB_CORE_REGEX_RFC3986_SEGMENT})*){0,1})"
readonly LIB_CORE_REGEX_RFC3986_PATH_ABEMPTY="(/${LIB_CORE_REGEX_RFC3986_SEGMENT})*"

readonly LIB_CORE_REGEX_RFC3986_PATH="(${LIB_CORE_REGEX_RFC3986_PATH_ABEMPTY}|${LIB_CORE_REGEX_RFC3986_PATH_ABSOLUTE}|${LIB_CORE_REGEX_RFC3986_PATH_NOSCHEME}|${LIB_CORE_REGEX_RFC3986_PATH_ROOTLESS}|${LIB_CORE_REGEX_RFC3986_PATH_EMPTY})"

readonly LIB_CORE_REGEX_RFC3986_REG_NAME="(${LIB_CORE_REGEX_RFC3986_UNRESERVED}|${LIB_CORE_REGEX_RFC3986_PCT_ENCODED}|${LIB_CORE_REGEX_RFC3986_SUB_DELIMS})*"

readonly LIB_CORE_REGEX_RFC3986_DEC_OCTET="([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"

readonly LIB_CORE_REGEX_RFC3986_IPV4ADDRESS="((${LIB_CORE_REGEX_RFC3986_DEC_OCTET}\.){3}${LIB_CORE_REGEX_RFC3986_DEC_OCTET})"
readonly LIB_CORE_REGEX_RFC3986_H16="(${LIB_CORE_REGEX_RFC2234_HEXDIG}{1,4})"
readonly LIB_CORE_REGEX_RFC3986_LS32="((${LIB_CORE_REGEX_RFC3986_H16}:${LIB_CORE_REGEX_RFC3986_H16})|${LIB_CORE_REGEX_RFC3986_IPV4ADDRESS})"

readonly LIB_CORE_REGEX_RFC3986_IPV6ADDRESS="(\
((${LIB_CORE_REGEX_RFC3986_H16}:){6}${LIB_CORE_REGEX_RFC3986_LS32})|\
(::(${LIB_CORE_REGEX_RFC3986_H16}:){5}${LIB_CORE_REGEX_RFC3986_LS32})|\
((${LIB_CORE_REGEX_RFC3986_H16}){0,1}::(${LIB_CORE_REGEX_RFC3986_H16}:){4}${LIB_CORE_REGEX_RFC3986_LS32})|\
(((${LIB_CORE_REGEX_RFC3986_H16}:){0,1}${LIB_CORE_REGEX_RFC3986_H16}){0,1}::(${LIB_CORE_REGEX_RFC3986_H16}:){3}${LIB_CORE_REGEX_RFC3986_LS32})|\
(((${LIB_CORE_REGEX_RFC3986_H16}:){0,2}${LIB_CORE_REGEX_RFC3986_H16}){0,1}::(${LIB_CORE_REGEX_RFC3986_H16}:){2}${LIB_CORE_REGEX_RFC3986_LS32})|\
(((${LIB_CORE_REGEX_RFC3986_H16}:){0,3}${LIB_CORE_REGEX_RFC3986_H16}){0,1}::${LIB_CORE_REGEX_RFC3986_H16}:${LIB_CORE_REGEX_RFC3986_LS32})|\
(((${LIB_CORE_REGEX_RFC3986_H16}:){0,4}${LIB_CORE_REGEX_RFC3986_H16}){0,1}::${LIB_CORE_REGEX_RFC3986_LS32})|\
(((${LIB_CORE_REGEX_RFC3986_H16}:){0,5}${LIB_CORE_REGEX_RFC3986_H16}){0,1}::${LIB_CORE_REGEX_RFC3986_H16})|\
(((${LIB_CORE_REGEX_RFC3986_H16}:){0,6}${LIB_CORE_REGEX_RFC3986_H16}){0,1}::)\
)"

readonly LIB_CORE_REGEX_RFC3986_IPVFUTURE="(v${LIB_CORE_REGEX_RFC2234_HEXDIG}{1,}\.(${LIB_CORE_REGEX_RFC3986_UNRESERVED}|${LIB_CORE_REGEX_RFC3986_SUB_DELIMS}|:){1,})"

readonly LIB_CORE_REGEX_RFC3986_IP_LITERAL="\[(${LIB_CORE_REGEX_RFC3986_IPV6ADDRESS}|${LIB_CORE_REGEX_RFC3986_IPVFUTURE})\]"

readonly LIB_CORE_REGEX_RFC3986_PORT="(${LIB_CORE_REGEX_RFC2234_DIGIT}*)"
readonly LIB_CORE_REGEX_RFC3986_HOST="(${LIB_CORE_REGEX_RFC3986_IP_LITERAL}|${LIB_CORE_REGEX_RFC3986_IPV4ADDRESS}|${LIB_CORE_REGEX_RFC3986_REG_NAME})"
readonly LIB_CORE_REGEX_RFC3986_USERINFO="((${LIB_CORE_REGEX_RFC3986_UNRESERVED}|${LIB_CORE_REGEX_RFC3986_PCT_ENCODED}|${LIB_CORE_REGEX_RFC3986_SUB_DELIMS}|:)*)"
readonly LIB_CORE_REGEX_RFC3986_AUTHORITY="((${LIB_CORE_REGEX_RFC3986_USERINFO}@){0,1}${LIB_CORE_REGEX_RFC3986_HOST}(:${LIB_CORE_REGEX_RFC3986_PORT}){0,1})"

readonly LIB_CORE_REGEX_RFC3986_SCHEME="(${LIB_CORE_REGEX_RFC2234_ALPHA}(${LIB_CORE_REGEX_RFC2234_ALPHA}|${LIB_CORE_REGEX_RFC2234_DIGIT}|[+.-])*)"

readonly LIB_CORE_REGEX_RFC3986_RELATIVE_PART="((//${LIB_CORE_REGEX_RFC3986_AUTHORITY}${LIB_CORE_REGEX_RFC3986_PATH_ABEMPTY})|${LIB_CORE_REGEX_RFC3986_PATH_ABSOLUTE}|${LIB_CORE_REGEX_RFC3986_PATH_NOSCHEME}|${LIB_CORE_REGEX_RFC3986_PATH_EMPTY})"

readonly LIB_CORE_REGEX_RFC3986_RELATIVE_REF="(${LIB_CORE_REGEX_RFC3986_RELATIVE_PART}(\?${LIB_CORE_REGEX_RFC3986_QUERY}){0,1}(#${LIB_CORE_REGEX_RFC3986_FRAGMENT}){0,1})"

readonly LIB_CORE_REGEX_RFC3986_HIER_PART="((//${LIB_CORE_REGEX_RFC3986_AUTHORITY}${LIB_CORE_REGEX_RFC3986_PATH_ABEMPTY})|${LIB_CORE_REGEX_RFC3986_PATH_ABSOLUTE}|${LIB_CORE_REGEX_RFC3986_PATH_ROOTLESS}|${LIB_CORE_REGEX_RFC3986_PATH_EMPTY})"

readonly LIB_CORE_REGEX_RFC3986_ABSOLUTE_URI="(${LIB_CORE_REGEX_RFC3986_SCHEME}:${LIB_CORE_REGEX_RFC3986_HIER_PART}(\?${LIB_CORE_REGEX_RFC3986_QUERY}){0,1})"

readonly LIB_CORE_REGEX_RFC3986_URI="(${LIB_CORE_REGEX_RFC3986_SCHEME}:${LIB_CORE_REGEX_RFC3986_HIER_PART}(\?${LIB_CORE_REGEX_RFC3986_QUERY}){0,1}(#${LIB_CORE_REGEX_RFC3986_FRAGMENT}){0,1})"

readonly LIB_CORE_REGEX_RFC3986_URI_REFERENCE="(${LIB_CORE_REGEX_RFC3986_URI}|${LIB_CORE_REGEX_RFC3986_RELATIVE_REF})"

#-------------------------------------------------------------------------------
#  NETWORK (DNS)
#-------------------------------------------------------------------------------
readonly LIB_CORE_REGEX_NET_DNS_FQDN_TLD="[a-zA-Z-]{2,}" # top-level domain

# Adapted from: R. Sabourin, http://regexlib.com/REDetails.aspx?regexp_id=391
readonly LIB_CORE_REGEX_NET_DNS_FQDN_SEG="[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9]){0,1}"
readonly LIB_CORE_REGEX_NET_DNS_FQDN="((${LIB_CORE_REGEX_NET_DNS_FQDN_SEG})\.){1,}(${LIB_CORE_REGEX_NET_DNS_FQDN_TLD})"
readonly LIB_CORE_REGEX_NET_DNS_FQDN_OR_WILDCARD="(\*\.){0,1}(${LIB_CORE_REGEX_NET_DNS_FQDN})"
readonly LIB_CORE_REGEX_NET_DNS_FQDN_WILDCARD="\*\.(${LIB_CORE_REGEX_NET_DNS_FQDN})"
readonly LIB_CORE_REGEX_NET_DNS_SRV="_(${LIB_CORE_REGEX_NET_DNS_FQDN_SEG})\._(TCP|tcp|UDP|udp)\.(${LIB_CORE_REGEX_NET_DNS_FQDN})\.{0,1}"

#-------------------------------------------------------------------------------
#  NETWORK (IPv4)
#-------------------------------------------------------------------------------
# Adapted from: J. Goyvaerts, S. Levithan, https://www.oreilly.com/library/view/regular-expressions-cookbook/9780596802837/ch07s16.html
readonly LIB_CORE_REGEX_NET_IPV4_ADDR_SEG="25[0-5]|2[0-4][0-9]|[01]{0,1}[0-9][0-9]{0,1}"
readonly LIB_CORE_REGEX_NET_IPV4_ADDR="((${LIB_CORE_REGEX_NET_IPV4_ADDR_SEG})\.){3,3}(${LIB_CORE_REGEX_NET_IPV4_ADDR_SEG})"
readonly LIB_CORE_REGEX_NET_IPV4_CIDR="(${LIB_CORE_REGEX_NET_IPV4_ADDR})\/(3[0-2]|[1-2][0-9]|[0-9])"
readonly LIB_CORE_REGEX_NET_IPV4_RANGE="(${LIB_CORE_REGEX_NET_IPV4_ADDR})-(${LIB_CORE_REGEX_NET_IPV4_ADDR})"

#-------------------------------------------------------------------------------
#  NETWORK (IPv6)
#-------------------------------------------------------------------------------
# Adapted from: S. Ryan, https://community.helpsystems.com/forums/intermapper/miscellaneous-topics/5acc4fcf-fa83-e511-80cf-0050568460e4
readonly LIB_CORE_REGEX_NET_IPV6_ADDR="((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4}){0,1}:((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])(\.(25[0-5]|2[0-4][[:digit:]]|1[[:digit:]][[:digit:]]|[1-9]{0,1}[[:digit:]])){3}))|:)))(%.{1,}){0,1}"
readonly LIB_CORE_REGEX_NET_IPV6_CIDR="(${LIB_CORE_REGEX_NET_IPV6_ADDR})\/(12[0-8]|1[0-1][0-9]|[1-9][0-9]|[0-9])"

#-------------------------------------------------------------------------------
#  NETWORK (FQDN/IPv4/IPv6)
#-------------------------------------------------------------------------------
readonly LIB_CORE_REGEX_NET_HOST="${LIB_CORE_REGEX_NET_DNS_FQDN}|${LIB_CORE_REGEX_NET_IPV4_ADDR}|${LIB_CORE_REGEX_NET_IPV6_ADDR}"

#-------------------------------------------------------------------------------
#  NETWORK (MAC)
#-------------------------------------------------------------------------------
# Adapted from: T. Rudyk, http://regexlib.com/REDetails.aspx?regexp_id=154
readonly LIB_CORE_REGEX_NET_MAC="([0-9a-fA-F][0-9a-fA-F]:){5}([0-9a-fA-F][0-9a-fA-F])"

#-------------------------------------------------------------------------------
#  NETWORK (ICMP/TCP/UDP)
#-------------------------------------------------------------------------------
readonly LIB_CORE_REGEX_NET_ICMP_TYPE="[0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5]|ping"

# Adapted from: A. Gusarov, http://regexlib.com/REDetails.aspx?regexp_id=4958
readonly LIB_CORE_REGEX_NET_TCPUDP_PORT="([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])"
readonly LIB_CORE_REGEX_NET_TCPUDP_PORT_RANGE="${LIB_CORE_REGEX_NET_TCPUDP_PORT}-${LIB_CORE_REGEX_NET_TCPUDP_PORT}"

#-------------------------------------------------------------------------------
#  NETWORK (SFTP/SSH)
#-------------------------------------------------------------------------------
# See also: https://datatracker.ietf.org/doc/html/draft-ietf-secsh-scp-sftp-ssh-uri-04

# Secure Shell (SSH) URI
readonly LIB_CORE_REGEX_NET_SSH_PARAMVALUE="((${LIB_CORE_REGEX_RFC2234_ALPHA}|${LIB_CORE_REGEX_RFC2234_DIGIT}|-)*)"
readonly LIB_CORE_REGEX_NET_SSH_PARAMNAME="${LIB_CORE_REGEX_NET_SSH_PARAMVALUE}"
readonly LIB_CORE_REGEX_NET_SSH_C_PARAM="(${LIB_CORE_REGEX_NET_SSH_PARAMNAME}=${LIB_CORE_REGEX_NET_SSH_PARAMVALUE})"
readonly LIB_CORE_REGEX_NET_SSH_USERINFO="${LIB_CORE_REGEX_RFC3986_USERINFO}"
readonly LIB_CORE_REGEX_NET_SSH_SSH_INFO="(${LIB_CORE_REGEX_NET_SSH_USERINFO}{0,1}(;${LIB_CORE_REGEX_NET_SSH_C_PARAM}(,${LIB_CORE_REGEX_NET_SSH_C_PARAM})*){0,1})"
readonly LIB_CORE_REGEX_NET_SSH_PATH_ABEMPTY="${LIB_CORE_REGEX_RFC3986_PATH_ABEMPTY}"
readonly LIB_CORE_REGEX_NET_SSH_PORT="${LIB_CORE_REGEX_RFC3986_PORT}"
readonly LIB_CORE_REGEX_NET_SSH_HOST="${LIB_CORE_REGEX_RFC3986_HOST}"
readonly LIB_CORE_REGEX_NET_SSH_AUTHORITY="((${LIB_CORE_REGEX_NET_SSH_SSH_INFO}{0,1}@){0,1}${LIB_CORE_REGEX_NET_SSH_HOST}(:${LIB_CORE_REGEX_NET_SSH_PORT}){0,1})"
readonly LIB_CORE_REGEX_NET_SSH_HIER_PART="(//${LIB_CORE_REGEX_NET_SSH_AUTHORITY}${LIB_CORE_REGEX_NET_SSH_PATH_ABEMPTY})"
readonly LIB_CORE_REGEX_NET_SSH_SSHURI="ssh:${LIB_CORE_REGEX_NET_SSH_HIER_PART}"

# Secure Shell (SSH) URI Short Version (user@hostname.fqdn)
readonly LIB_CORE_REGEX_NET_SSH_SSHURI_SHORT="${LIB_CORE_REGEX_NET_SSH_SSH_INFO}@${LIB_CORE_REGEX_NET_SSH_HOST}(:${LIB_CORE_REGEX_NET_SSH_PORT}){0,1}${LIB_CORE_REGEX_NET_SSH_PATH_ABEMPTY}"

# Secure File Transfer Protocol (SFTP) URI
readonly LIB_CORE_REGEX_NET_SFTP_PARAMVALUE="((${LIB_CORE_REGEX_RFC2234_ALPHA}|${LIB_CORE_REGEX_RFC2234_DIGIT}|-)*)"
readonly LIB_CORE_REGEX_NET_SFTP_PARAMNAME="${LIB_CORE_REGEX_NET_SFTP_PARAMVALUE}"
readonly LIB_CORE_REGEX_NET_SFTP_S_PARAM="(${LIB_CORE_REGEX_NET_SFTP_PARAMNAME}=${LIB_CORE_REGEX_NET_SFTP_PARAMVALUE})"
readonly LIB_CORE_REGEX_NET_SFTP_C_PARAM="${LIB_CORE_REGEX_NET_SFTP_S_PARAM}"
readonly LIB_CORE_REGEX_NET_SFTP_USERINFO="${LIB_CORE_REGEX_RFC3986_USERINFO}"
readonly LIB_CORE_REGEX_NET_SFTP_SSH_INFO="(${LIB_CORE_REGEX_NET_SFTP_USERINFO}{0,1}(;${LIB_CORE_REGEX_NET_SFTP_C_PARAM}(,${LIB_CORE_REGEX_NET_SFTP_C_PARAM})*){0,1})"
readonly LIB_CORE_REGEX_NET_SFTP_PORT="${LIB_CORE_REGEX_RFC3986_PORT}"
readonly LIB_CORE_REGEX_NET_SFTP_HOST="${LIB_CORE_REGEX_RFC3986_HOST}"
readonly LIB_CORE_REGEX_NET_SFTP_AUTHORITY="((${LIB_CORE_REGEX_NET_SFTP_SSH_INFO}@){0,1}${LIB_CORE_REGEX_NET_SFTP_HOST}(:${LIB_CORE_REGEX_NET_SFTP_PORT}){0,1})"
readonly LIB_CORE_REGEX_NET_SFTP_PATH_ABEMPTY="${LIB_CORE_REGEX_RFC3986_PATH_ABEMPTY}"
readonly LIB_CORE_REGEX_NET_SFTP_PATH="${LIB_CORE_REGEX_NET_SFTP_PATH_ABEMPTY}"
readonly LIB_CORE_REGEX_NET_SFTP_HIER_PART="(//${LIB_CORE_REGEX_NET_SFTP_AUTHORITY}${LIB_CORE_REGEX_NET_SFTP_PATH}(;${LIB_CORE_REGEX_NET_SFTP_S_PARAM}(,${LIB_CORE_REGEX_NET_SFTP_S_PARAM})*){0,1})"
readonly LIB_CORE_REGEX_NET_SFTP_SFTPURI="sftp:${LIB_CORE_REGEX_NET_SFTP_HIER_PART}"

# Secure File Transfer Protocol (SFTP) URI Short Version (user@hostname.fqdn)
readonly LIB_CORE_REGEX_NET_SFTP_SFTPURI_SHORT="${LIB_CORE_REGEX_NET_SFTP_SSH_INFO}@${LIB_CORE_REGEX_NET_SFTP_HOST}(:${LIB_CORE_REGEX_NET_SFTP_PORT}){0,1}${LIB_CORE_REGEX_NET_SFTP_PATH}(;${LIB_CORE_REGEX_NET_SFTP_S_PARAM}(,${LIB_CORE_REGEX_NET_SFTP_S_PARAM})*){0,1}"

#-------------------------------------------------------------------------------
#  IPSET
#-------------------------------------------------------------------------------
readonly LIB_CORE_REGEX_IPSET_IPADDR_4="(${LIB_CORE_REGEX_NET_IPV4_ADDR})|(${LIB_CORE_REGEX_NET_IPV4_CIDR})|(${LIB_CORE_REGEX_NET_IPV4_RANGE})"
readonly LIB_CORE_REGEX_IPSET_IPADDR_6="(${LIB_CORE_REGEX_NET_IPV6_ADDR})|(${LIB_CORE_REGEX_NET_IPV6_CIDR})"
readonly LIB_CORE_REGEX_IPSET_PORT_BITMAP="(${LIB_CORE_REGEX_NET_TCPUDP_PORT}(-${LIB_CORE_REGEX_NET_TCPUDP_PORT}){0,1})"
readonly LIB_CORE_REGEX_IPSET_PORT_HASH_4_6="((tcp|sctp|udp|udplite|tcpudp):${LIB_CORE_REGEX_IPSET_PORT_BITMAP})"
readonly LIB_CORE_REGEX_IPSET_PORT_HASH_4="${LIB_CORE_REGEX_IPSET_PORT_HASH_4_6}|(icmp:${LIB_CORE_REGEX_NET_ICMP_TYPE})"
readonly LIB_CORE_REGEX_IPSET_PORT_HASH_6="${LIB_CORE_REGEX_IPSET_PORT_HASH_4_6}|(icmpv6:${LIB_CORE_REGEX_NET_ICMP_TYPE})"
readonly LIB_CORE_REGEX_IPSET_SETNAME="[a-zA-Z0-9]([a-zA-Z0-9_]{0,1}[a-zA-Z0-9])*"

#-------------------------------------------------------------------------------
#  LUKS2
#-------------------------------------------------------------------------------
# See also: https://man7.org/linux/man-pages/man1/systemd-cryptenroll.1.html
readonly LIB_CORE_REGEX_LUKS2_TPM2_PCRS="(1?[0-9]|2[0-3])(\+(1?[0-9]|2[0-3]))*"

#-------------------------------------------------------------------------------
#  DATA TYPES
#-------------------------------------------------------------------------------
readonly LIB_CORE_REGEX_TYPE_BOOLEAN="true|false"

# Adapted from: J. Goyvaerts, S. Levithan, https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch06s10.html
readonly LIB_CORE_REGEX_TYPE_FLOAT="([-+]?[0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)"
readonly LIB_CORE_REGEX_TYPE_FLOAT_NEG="([-][0-9]*\.[0-9]*[1-9]([eE][-+]?[0-9]+)?)"
readonly LIB_CORE_REGEX_TYPE_FLOAT_NEG0="([-][0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)"
readonly LIB_CORE_REGEX_TYPE_FLOAT_POS="([+]?[0-9]*\.[0-9]*[1-9]([eE][-+]?[0-9]+)?)"
readonly LIB_CORE_REGEX_TYPE_FLOAT_POS0="([+]?[0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)"

readonly LIB_CORE_REGEX_TYPE_HEX="[0-9A-Fa-f]+"
readonly LIB_CORE_REGEX_TYPE_INTEGER="([-+]?(0|[1-9][0-9]*))"
readonly LIB_CORE_REGEX_TYPE_INTEGER_NEG="([-][1-9][0-9]*)"
readonly LIB_CORE_REGEX_TYPE_INTEGER_NEG0="(([-+]?0)|${LIB_CORE_REGEX_TYPE_INTEGER_NEG})"
readonly LIB_CORE_REGEX_TYPE_INTEGER_POS="([+]?[1-9][0-9]*)"
readonly LIB_CORE_REGEX_TYPE_INTEGER_POS0="(([-+]?0)|${LIB_CORE_REGEX_TYPE_INTEGER_POS})"
readonly LIB_CORE_REGEX_TYPE_NUM_DEC="${LIB_CORE_REGEX_TYPE_INTEGER}|${LIB_CORE_REGEX_TYPE_FLOAT}"
readonly LIB_CORE_REGEX_TYPE_NUM_DEC_NEG="${LIB_CORE_REGEX_TYPE_INTEGER_NEG}|${LIB_CORE_REGEX_TYPE_FLOAT_NEG}"
readonly LIB_CORE_REGEX_TYPE_NUM_DEC_NEG0="${LIB_CORE_REGEX_TYPE_INTEGER_NEG0}|${LIB_CORE_REGEX_TYPE_FLOAT_NEG0}"
readonly LIB_CORE_REGEX_TYPE_NUM_DEC_POS="${LIB_CORE_REGEX_TYPE_INTEGER_POS}|${LIB_CORE_REGEX_TYPE_FLOAT_POS}"
readonly LIB_CORE_REGEX_TYPE_NUM_DEC_POS0="${LIB_CORE_REGEX_TYPE_INTEGER_POS0}|${LIB_CORE_REGEX_TYPE_FLOAT_POS0}"
readonly LIB_CORE_REGEX_TYPE_OID="[0-2]((\.0)|(\.[1-9][0-9]*))*" # Adapted from: https://regexr.com/38m0v
readonly LIB_CORE_REGEX_TYPE_UUID="(${LIB_CORE_REGEX_TYPE_HEX}{8}(-${LIB_CORE_REGEX_TYPE_HEX}{4}){3}-${LIB_CORE_REGEX_TYPE_HEX}{12})"
readonly LIB_CORE_REGEX_TYPE_YESNO="yes|no"

readonly LIB_CORE_REGEX_TYPE_YY_DE="J|j"
readonly LIB_CORE_REGEX_TYPE_YY_EN="Y|y"
readonly LIB_CORE_REGEX_TYPE_NN_DE="N|n"
readonly LIB_CORE_REGEX_TYPE_NN_EN="N|n"

#-------------------------------------------------------------------------------
#  CUPS
#-------------------------------------------------------------------------------
readonly LIB_CORE_REGEX_CUPS_HOSTPORT="((${LIB_CORE_REGEX_NET_IPV4_ADDR}|${LIB_CORE_REGEX_NET_DNS_FQDN_SEG}|${LIB_CORE_REGEX_NET_DNS_FQDN})(:${LIB_CORE_REGEX_NET_TCPUDP_PORT}){0,1})"
readonly LIB_CORE_REGEX_CUPS_QUEUE="([a-zA-Z0-9_%-]{1,})"

# See also: https://www.cups.org/doc/network.html
readonly LIB_CORE_REGEX_CUPS_DEVURI_DNSSD_ADDR="([a-zA-Z0-9]([a-zA-Z0-9_%-]{0,61}[a-zA-Z0-9]){0,1}\._(ipp|ipps|pdl-datastream|printer)\._tcp\.(local|${LIB_CORE_REGEX_NET_DNS_FQDN}))"
readonly LIB_CORE_REGEX_CUPS_DEVURI_DNSSD="(dnssd:\/\/${LIB_CORE_REGEX_CUPS_DEVURI_DNSSD_ADDR}\/(cups){0,1}\?uuid\=${LIB_CORE_REGEX_TYPE_UUID})"

# See also: https://www.cups.org/doc/network.html#IPP
readonly LIB_CORE_REGEX_CUPS_DEVURI_IPP_OPTS="((contimeout\=[0-9]{1,})|(encryption\=(always|ifrequested|never|required))|(version\=(1\.0|1\.1|2\.1))|(waitjob\=false)|(waitprinter\=false))"
readonly LIB_CORE_REGEX_CUPS_DEVURI_IPP_PATH="((ipp\/print)|(printers\/${LIB_CORE_REGEX_CUPS_QUEUE}(\/.printer){0,1}))"
readonly LIB_CORE_REGEX_CUPS_DEVURI_IPP_PROTO="(http|ipp|ipps)"
readonly LIB_CORE_REGEX_CUPS_DEVURI_IPP_IPP="(${LIB_CORE_REGEX_CUPS_DEVURI_IPP_PROTO}:\/\/${LIB_CORE_REGEX_CUPS_HOSTPORT}\/${LIB_CORE_REGEX_CUPS_DEVURI_IPP_PATH}(\?${LIB_CORE_REGEX_CUPS_DEVURI_IPP_OPTS}(\&${LIB_CORE_REGEX_CUPS_DEVURI_IPP_OPTS})*){0,1})"

# See also: https://wiki.debian.org/CUPSPrintQueues#The_device-uri_for_a_Networked_Printer
readonly LIB_CORE_REGEX_CUPS_DEVURI_IPP_DNSSD="(${LIB_CORE_REGEX_CUPS_DEVURI_IPP_PROTO}:\/\/${LIB_CORE_REGEX_CUPS_DEVURI_DNSSD_ADDR}\/)"

# See also: https://www.cups.org/doc/network.html#TABLE3
#           https://opensource.apple.com/source/cups/cups-136/cups/doc/help/network.html#TABLE3
readonly LIB_CORE_REGEX_CUPS_DEVURI_LPD_OPTS="((banner\=on)|(contimeout\=[0-9]{1,})|(format\=(c|d|f|g|l|n|o|p|r|t|v))|(mode\=stream)|(order\=data\,control)|(reserve\=(none|rfc1179))|(sanitize_title\=(no|yes))|(timeout\=[0-9]{1,}))"
readonly LIB_CORE_REGEX_CUPS_DEVURI_LPD="(lpd:\/\/${LIB_CORE_REGEX_CUPS_HOSTPORT}\/${LIB_CORE_REGEX_CUPS_QUEUE}(\?${LIB_CORE_REGEX_CUPS_DEVURI_LPD_OPTS}(\&${LIB_CORE_REGEX_CUPS_DEVURI_LPD_OPTS})*){0,1})"

# See also: https://opensource.apple.com/source/cups/cups-86/doc/sdd.shtml
readonly LIB_CORE_REGEX_CUPS_DEVURI_PARALLEL="(parallel:\/dev(\/[a-zA-Z0-9_-]{1,}){1,})"

# See also: https://opensource.apple.com/source/cups/cups-86/doc/sdd.shtml
#           https://www.cups.org/doc/spec-ipp.html
readonly LIB_CORE_REGEX_CUPS_DEVURI_SERIAL_OPTS="((baud\=[0-9]{1,})|(bits\=(7|8))|(parity\=(even|odd|none))|(flow\=(dtrdsr|hard|none|rtscts|xonxoff)))"
readonly LIB_CORE_REGEX_CUPS_DEVURI_SERIAL="(serial:\/dev(\/[a-zA-Z0-9_-]{1,}){1,}\?${LIB_CORE_REGEX_CUPS_DEVURI_SERIAL_OPTS}(\+${LIB_CORE_REGEX_CUPS_DEVURI_SERIAL_OPTS})*)"

# See also: https://www.cups.org/doc/network.html
readonly LIB_CORE_REGEX_CUPS_DEVURI_SOCKET_OPTS="((contimeout\=[0-9]{1,})|(waiteof\=(true|false)))"
readonly LIB_CORE_REGEX_CUPS_DEVURI_SOCKET="(socket:\/\/${LIB_CORE_REGEX_CUPS_HOSTPORT}(\/\?${LIB_CORE_REGEX_CUPS_DEVURI_SOCKET_OPTS}(\&${LIB_CORE_REGEX_CUPS_DEVURI_SOCKET_OPTS})*){0,1})"

# See also: https://wiki.debian.org/CUPSPrintQueues#deviceuri
readonly LIB_CORE_REGEX_CUPS_DEVURI_USB_OPTS="([a-zA-Z0-9_]{1,}\=[a-zA-Z0-9_]{1,})"
readonly LIB_CORE_REGEX_CUPS_DEVURI_USB="(usb:\/\/[a-zA-Z0-9]{1,}(\/${LIB_CORE_REGEX_CUPS_QUEUE}){1,}(\?${LIB_CORE_REGEX_CUPS_DEVURI_USB_OPTS}(\&${LIB_CORE_REGEX_CUPS_DEVURI_USB_OPTS})*){0,1})"

readonly LIB_CORE_REGEX_CUPS_DEVURI="${LIB_CORE_REGEX_CUPS_DEVURI_DNSSD}|${LIB_CORE_REGEX_CUPS_DEVURI_IPP_IPP}|${LIB_CORE_REGEX_CUPS_DEVURI_IPP_DNSSD}|${LIB_CORE_REGEX_CUPS_DEVURI_LPD}|${LIB_CORE_REGEX_CUPS_DEVURI_PARALLEL}|${LIB_CORE_REGEX_CUPS_DEVURI_SERIAL}|${LIB_CORE_REGEX_CUPS_DEVURI_SOCKET}|${LIB_CORE_REGEX_CUPS_DEVURI_USB}"

#-------------------------------------------------------------------------------
#  OpenSC
#-------------------------------------------------------------------------------
# See also 'man pkcs15-init' ('--profile')
readonly LIB_CORE_REGEX_OPENSC_P15_PROFILE="[a-zA-Z_0-9]+(\+[a-zA-Z_0-9]+)*"

#-------------------------------------------------------------------------------
#  POSIX
#-------------------------------------------------------------------------------
# See also: https://stackoverflow.com/a/2821183
readonly LIB_CORE_REGEX_POSIX_NAME="[a-zA-Z_][a-zA-Z_0-9]*"

# See also: https://www.ibm.com/docs/en/zos/2.1.0?topic=locales-posix-portable-file-name-character-set
readonly LIB_CORE_REGEX_POSIX_FILENAME="[A-Za-z0-9._-]+"

#===============================================================================
#  FUNCTIONS
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_core
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_core() {
  return 0
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_main
#  DESCRIPTION:  Main function (executed once when the library is sourced)
#      GLOBALS:  LIB_CORE_PARENT_SHELL_IS_TERMINAL
# PARAMETER  1:  Should be "$@" to get all arguments passed
#===============================================================================
lib_core_main() {
  if lib_core_is --terminal-stdin; then
    readonly LIB_CORE_PARENT_SHELL_IS_TERMINAL="true"
  else
    readonly LIB_CORE_PARENT_SHELL_IS_TERMINAL="false"
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_args_passed
#  DESCRIPTION:  Check if at least one argument has been passed
# PARAMETER  1:  Should always be "$@" to pass the arguments of the calling f.
#===============================================================================
lib_core_args_passed() {
  [ $# -gt 0 ] || return
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_bool2int
#  DESCRIPTION:  Convert one or more boolean values to integer values
# PARAMETER
#         1...:  Boolean (true|false)
#      OUTPUTS:  Integer value(s) (separated by <newline>)
#                where '0' equals 'false' and '1' equals 'true'
#                (empty line if parameter is not a boolean)
#===============================================================================
lib_core_bool2int() {
  local args
  lib_core_args_passed "$@" && args="$*" || args="$(xargs)"

  local var
  for var in ${args}; do
    if lib_core_is --bool "${var}"; then
      if "${var}"; then echo "1"; else echo "0"; fi
    else
      printf "\n"
    fi
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_can_sudo_nopasswd
#  DESCRIPTION:  Check if current user can sudo without password prompt
#      OUTPUTS:  A message to <stderr> or <syslog> in case sudo failed
#===============================================================================
lib_core_can_sudo_nopasswd() {
  # Either user is already root ...
  lib_core_is --su && return

  # ... or sudo command must exist.
  lib_core_is --cmd sudo && \
  __lib_core_can_sudo_nopasswd
}

__lib_core_can_sudo_nopasswd() {
  sudo -n true 2>/dev/null                                                  || \
  { lib_core_msg --error "Current user <$(id -u -n)> cannot get root \
privileges. Either it is not a member of the 'sudo' group or <NOPASSWD> \
is disabled."
    return 1
  }
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_char_repeat
#  DESCRIPTION:  Repeat a given character for a certain number of times
# PARAMETER  1:  Character (exactly one)
#            2:  Number of copies (>=1)
#      OUTPUTS:  A message to <stderr> in case one of the commands was not found
#===============================================================================
lib_core_char_repeat() {
  local arg_char="$1"
  local arg_num="$2"

  [ "${#arg_char}" -eq "1" ]          && \
  lib_core_is --int-pos0 "${arg_num}" || \
  return

  __lib_core_char_repeat "$@"
}

__lib_core_char_repeat() {
  local arg_char="$1"
  local arg_num="$2"

  printf %${arg_num}s | tr " " "${arg_char}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_cmd_exists
#  DESCRIPTION:  Check if (one or more) commands exist on the host
# PARAMETER
#         1...:  Command(s) to check
#      OUTPUTS:  A message to <stderr> in case one of the commands was not found
#   RETURNS  0:  All commands exist
#            1:  At least one command does not exist
#===============================================================================
lib_core_cmd_exists() {
  lib_core_args_passed "$@" || return
  local result="0"

  local cmd
  for cmd in "$@"; do
    if ! command -v "${cmd}" >/dev/null; then
      result="1"
      lib_core_msg --error "Command <$cmd> not found."
    fi
  done

  return "${result}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_cmd_exists_su
#  DESCRIPTION:  Check if (one or more) commands exist when using root
# PARAMETER
#         1...:  Command(s) to check
#      OUTPUTS:  A message to <stderr> in case one of the commands was not found
#   RETURNS  0:  All commands exist
#            1:  At least one command does not exist
#===============================================================================
lib_core_cmd_exists_su() {
  lib_core_args_passed "$@" || return

  local result="0"
  local cmd

  if lib_core_is --su; then
    for cmd in "$@"; do
      if ! command -v "${cmd}" >/dev/null; then
        result="1"
        lib_core_msg --error "Command <$cmd> (with su privileges) not found."
      fi
    done
  else
    lib_core_cmd_exists sudo || return
    for cmd in "$@"; do
      if ! sudo -i command -v "${cmd}" >/dev/null; then
        result="1"
        lib_core_msg --error "Command <$cmd> (with su privileges) not found."
      fi
    done
  fi

  return "${result}"
}

lib_core_cmd_exists_sudo() {
  lib_core_cmd_exists_su "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_echo
#  DESCRIPTION:  Print a message
# PARAMETER  1:  (Optional) Print '<user>@<hostname>' part? (true|false)
#                (Default: 'false')
#            2:  (Optional) Print an additional empty line after the message?
#                (true|false) (Default: 'false')
#            3:  Message string
#         4...:  Value pairs, e.g. "var1" "1" "var2" "2"
#      OUTPUTS:  Writes a string in the following format to stdout
#                <user>@<hostname>     <message string>
#                   (optional)           var1 : 1
#                                        var2 : 2
#                <empty line (optional)>
#===============================================================================
lib_core_echo() {
  local print_userhost
  local print_emptyline
  local msg

  # Some parameters are optional
  local i=0
  if lib_core_is --bool "$1"; then
    print_userhost="$1"; i=$((i+1)); shift
  else
    print_userhost="false"
  fi

  if lib_core_is --bool "$1"; then
    print_emptyline="$1"; i=$((i+1)); shift
  else
    print_emptyline="false"
  fi

  [ "$(( $# % 2 ))" -eq "1" ] || \
  { echo "ERROR: Expected $(($#+i+1)) arguments but only $(($#+i)) were submitted. Aborting..." >&2
    return 1
  }

  msg="$1"; shift

  # Print message
  local p1
  local p2
  if ${print_userhost}; then
    p1=20; p2=2
    printf "%-${p1}s%-${p2}s%s\n" "$(id -u -n)@$(uname -n)" "" "${msg}"
  else
    p1=0; p2=0
    printf "%-${p1}s%-${p2}s%s\n" "" "" "${msg}"
  fi

  # Print value pairs
  local save
  local i=1
  local var
  for var in "$@"; do
    if [ $(( i % 2 )) -eq 0 ]; then
      printf "%-${p1}s%-$(( p2 + 2 ))s%15s : %s\n" "" "" "${save}" "${var}"
    else
      save="$var"
    fi
    i=$(( i+1 ))
  done

  # (Optionally) print empty line
  if ${print_emptyline}; then printf "\n"; fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_env_append
#  DESCRIPTION:  Append one or more values to an environment variable
# PARAMETER  1:  Variable to modify, e.g. 'PATH' (see 'case' statement below)
#         2...:  Value(s) to append
#   RETURNS  0:  All values successfully appended or already existing
#            1:  Error: At least one value could not be appended
#            2:  Error: Environment variable not supported
#         TODO:  At the moment only "$PATH" is supported
#===============================================================================
lib_core_env_append() {
  local arg_var="$1"; shift
  lib_core_args_passed "$@" || return

  local exitcode="0"
  local val
  for val in "$@"; do
    case "${arg_var}" in
      PATH)
        val="$(lib_core_path_get_abs "${val}")" && \
        case ":$PATH:" in
          *:"${val}":*)
            # Value already in 'PATH'
            ;;
          *)
            # Value missing
            PATH="${PATH}${PATH:+:}${val}"
            export PATH
            ;;
        esac                                    || \
        exitcode="1"
        ;;

      *) exitcode="2"; break ;;
    esac
  done

  return ${exitcode}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_env_remove
#  DESCRIPTION:  Remove one or more values from an environment variable
# PARAMETER  1:  Variable to modify, e.g. 'PATH' (see 'case' statement below)
#         2...:  Value(s) to remove
#   RETURNS  0:  All Values successfully removed or not in variable
#            1:  Error: At least one value could not be removed
#            2:  Error: Environment variable not supported
#         TODO:  At the moment only "$PATH" is supported
#===============================================================================
lib_core_env_remove() {
  local arg_var="$1"; shift
  lib_core_args_passed "$@" || return

  local exitcode="0"
  local val
  for val in "$@"; do
    case "${arg_var}" in
      PATH)
        val="$(lib_core_path_get_abs "${val}")"                         && \
        case ":$PATH:" in
          *:"${val}":*)
            # Value in 'PATH'
            val="$(printf "%s" "${val}" | sed -e "s/\//\\\\\//g")"  && \
            PATH="$(printf ":%s:" "$PATH" \
              | sed -e "s/:${val}:/:/"    \
              | sed -e "s/^:\(.*\):$/\1/" \
            )"                                                      && \
            export PATH
            ;;
          *)
            # Value NOT in 'PATH'
            ;;
        esac                                                            || \
        exitcode="1"
        ;;

      *) exitcode="2"; break ;;
    esac
  done

  return ${exitcode}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_expand_tilde
#  DESCRIPTION:  Expand '~' to the user's home directory '$HOME' in a given path
# PARAMETER  1:  File/Folder path
#      OUTPUTS:  File/Folder path with '~' replaced by '$HOME' (expanded)
#
#      SOURCES:  Adapted from "https://stackoverflow.com/a/39152966"
#                by "go2null" (https://stackoverflow.com/users/3366962/go2null)
#                licensed under "CC BY-SA 3.0" (https://creativecommons.org/licenses/by-sa/3.0/)
#===============================================================================
lib_core_expand_tilde() {
  local tilde_less="${1#\~/}"
  [ "$1" != "$tilde_less" ] && tilde_less="$HOME/$tilde_less"
  printf '%s' "$tilde_less"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_file_get
#  DESCRIPTION:  Get file information
# PARAMETER  1:  Information selector, see 'case' statement below
#            2:  File
#      OUTPUTS:  File information to <stdout>
#
#      SOURCES:  (1)  https://unix.stackexchange.com/a/253753
#                     by "Gilles 'SO- stop being evil'" (https://unix.stackexchange.com/users/885/gilles-so-stop-being-evil)
#                     licensed under "CC BY-SA 4.0" (https://creativecommons.org/licenses/by-sa/4.0/)
#
#                (2)  Adapted from "https://stackoverflow.com/a/14703709"
#                     by "sotapme" (https://stackoverflow.com/users/1481060/sotapme)
#                     by "tripleee" (https://stackoverflow.com/users/874188/tripleee)
#                     licensed under "CC BY-SA 4.0" (https://creativecommons.org/licenses/by-sa/4.0/)
#===============================================================================
lib_core_file_get() {
  local arg_select="$1"
  local arg_file="$(lib_core_expand_tilde "$2")"

  # TODO: Temporarily disabled as this can fail on read-only filesystems
  # # Check if it can be a valid filepath
  # touch -c "${arg_file}" 2>/dev/null && \
  __lib_core_file_get "$@"
}

__lib_core_file_get() {
  local arg_select="$1"
  local arg_file="$(lib_core_expand_tilde "$2")"

  local base
  local dir
  base=$(basename -- "${arg_file}"; echo .); base=${base%.}
  dir=$(dirname -- "${arg_file}"; echo .); dir=${dir%.}

  case "${arg_select}" in
    -a|--absolute) lib_core_path_get_abs "${arg_file}" ;;
    -d|--dir) printf "%s" "${dir}" ;;
    -e|--extension)
      case "${base}" in
        *.*) printf "%s" "${base##*.}" ;;
        *)   ;;
      esac
      ;;
    -f|--file) printf "%s" "${base}" ;;
    -n|--name) printf "%s" "${base%.*}" ;;
    *) return 1 ;;
  esac
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_file_touch
#  DESCRIPTION:  Create one or more files and (if needed) their parent folders
# PARAMETER
#         1...:  File(s) to create
#   RETURNS  0:  All files successfully created
#            1:  At least one file could not be created
#            2:  At least one file already exists
#===============================================================================
lib_core_file_touch() {
  local exitcode="0"

  local file
  for file in "$@"; do
    file="$(lib_core_expand_tilde "${file}")"

    if lib_core_is --file "${file}"; then
      exitcode="2"
    else
      if mkdir --parents "$(dirname -- "${file}")" 2>/dev/null; then
        touch "${file}"
      else
        exitcode="1"
      fi
    fi
  done

  return "${exitcode}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_float2int
#  DESCRIPTION:  Convert one or more floating point numbers to integer
# PARAMETER
#         1...:  Floating point number, e.g. '3.05'
#      OUTPUTS:  Integer value(s) (separated by <newline>)
#                (empty line if parameter is not a floating point number)
#===============================================================================
lib_core_float2int() {
  local args
  lib_core_args_passed "$@" && args="$*" || args="$(xargs)"

  local i=1
  local var
  for var in ${args}; do
    if [ $i -gt 1 ]; then printf "\n"; fi

    if lib_core_is --float "${var}"; then
      var="${var%%.*}"
      printf "%s" "${var:-0}"
    elif lib_core_is --int "${var}"; then
      printf "%s" "${var}"
    fi

    i="$(( i + 1 ))"
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_int_is_within_range
#  DESCRIPTION:  Check if an integer number is between a given range.
#                This function is only intended for integer numbers. To process
#                floating point numbers please use <lib_math_is_within_range>.
# PARAMETER  1:  Minimum (optional)
#            2:  Value
#            3:  Maximum (optional)
#   RETURNS  0:  Value between range
#            1:  Value below minimum
#            2:  Value above maximum
#            3:  Parameters not defined or no integer values
#===============================================================================
lib_core_int_is_within_range() {
  local arg_min="$1"
  local arg_value="$2"
  local arg_max="$3"

  lib_core_is --not-empty "${arg_value}"  && \
  lib_core_is --int "${arg_value}"        || \
  return 3

  local arg
  for arg in "${arg_min}" "${arg_max}"; do
    lib_core_is --empty "${arg}"  || \
    lib_core_is --int "${arg}"    || \
    return 3
  done

  __lib_core_int_is_within_range "$@"
}

__lib_core_int_is_within_range() {
  local arg_min="$1"
  local arg_value="$2"
  local arg_max="$3"

  lib_core_is --empty "${arg_min}"                || \
  [ "${arg_value}" -ge "${arg_min}" ] 2>/dev/null || \
  return 1

  lib_core_is --empty "${arg_max}"                || \
  [ "${arg_value}" -le "${arg_max}" ] 2>/dev/null || \
  return 2
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_int_max
#  DESCRIPTION:  Return maximum of a list of integer values
# PARAMETER
#         1...:  Integer values
#      OUTPUTS:  Maximum to <stdout>
#===============================================================================
lib_core_int_max() {
  local args
  lib_core_args_passed "$@" && args="$*" || args="$(xargs)"
  lib_core_is --int ${args} || return

  local var
  for var in ${args}; do printf "%s\n" "$var"; done | sort -n | tail -n 1
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_int_min
#  DESCRIPTION:  Return minimum of a list of integer values
# PARAMETER
#         1...:  Integer values
#      OUTPUTS:  Minimum to <stdout>
#===============================================================================
lib_core_int_min() {
  local args
  lib_core_args_passed "$@" && args="$*" || args="$(xargs)"
  lib_core_is --int ${args} || return

  local var
  for var in ${args}; do printf "%s\n" "$var"; done | sort -n | head -n 1
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_is (lib_core_test)
#
#  DESCRIPTION:  Perform checks on current environment (root, interactive
#                shell, etc.) and arguments (bool, file, integer, etc.)
#
#                (I)  Environment
#                     Check environment, e.g. if current shell is interactive
#
#                (II) Arguments
#                     Check if one or more arguments are of a certain 'type'
#                     (bool, file, integer, etc.)
#
# PARAMETER  1:  Test selector ("type of test")
#                For a list of selectors please have a look at the 'case'
#                statements in sections 'I' and 'II' below.
#
#         2...:  Argument(s) to check (only in case 'II')
#
#   RETURNS  0:  All arguments passed the test
#            1:  At least one argument failed the test
#===============================================================================
lib_core_is() {
  local arg_select="$1"; shift

  # Check if arguments, beside the test selector, have been passed
  # (only for argument checks)
  case "${arg_select}" in
    --interactive) ;;
    --non-interactive) ;;
    --root|--su|--superuser) ;;
    --terminal|--terminal-stderr|--terminal-stdin|--terminal-stdout) ;;
    *)
      lib_core_args_passed "$@" || return
      ;;
  esac

  # Adapted from: J. Goyvaerts, S. Levithan, https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch06s10.html
  local R_FLOAT="[-+]?[0-9]*\.[0-9]+([eE][-+]?[0-9]+)?"

  # Only needed for some tests, e.g. '--cmd' when we want the for-loop
  # fully finish instead of breaking on the first mismatch
  local exitcode="0"

  #-----------------------------------------------------------------------------
  #  (I) Environment checks (function does not need/take further arguments)
  #-----------------------------------------------------------------------------
  case "${arg_select}" in
    --interactive)
      case $- in
        *i*) true ;;
        *)   false ;;
      esac
      ;;
    --non-interactive)
      case $- in
        *i*) false ;;
        *)   true ;;
      esac
      ;;
    --root|--su|--superuser)  [ "$(id -u)" -eq 0 ] ;;
    --terminal)               [ -t 0 ] && [ -t 1 ] && [ -t 2 ] ;;
    --terminal-stderr)        [ -t 2 ] ;;
    --terminal-stdin)         [ -t 0 ] ;;
    --terminal-stdout)        [ -t 1 ] ;;
  esac                                                                      || \
  exitcode="$?"

  #-----------------------------------------------------------------------------
  #  (II) Argument checks (checks additional arguments for their validity)
  #-----------------------------------------------------------------------------
  local var
  for var in "$@"; do
    case "${arg_select}" in
      --empty)  [ -z "${var}" ] && continue || return ;;
      *) ;;
    esac

    # For the following tests <var> must not be empty
    [ -n "${var}" ]                                                         && \
    case "${arg_select}" in
      #-------------------------------------------------------------------------
      #  test commands
      #-------------------------------------------------------------------------
      #  See: https://pubs.opengroup.org/onlinepubs/9699919799/utilities/test.html
      #-------------------------------------------------------------------------
      --blockdevice)    [ -b "${var}" ] ;;
      --dir)            [ -d "${var}" ] ;;
      --exists)         [ -e "${var}" ] ;;
      --file)           [ -f "${var}" ] ;;
      --symlink)        [ -h "${var}" ] ;;
      --not-empty)      true ;;
      --readable)       [ -r "${var}" ] ;;
      --writeable)      [ -w "${var}" ] ;;
      --executable)     [ -x "${var}" ] ;;
      --empty)          [ -z "${var}" ] ;;

      #-------------------------------------------------------------------------
      #  other tests
      #-------------------------------------------------------------------------
      --bool|--boolean)
        case "${var}" in
          true|false) ;;
          *) false ;;
        esac
        ;;

      --bridge|--bridge-master) [ -d "/sys/class/net/${var}/bridge" ] ;;
      --bridge-member|--bridge-slave) [ -e "/sys/class/net/${var}/master" ] ;;

      --cmd|--command) lib_core_cmd_exists "${var}" || exitcode="1" ;;
      --cmd-su|--command-su) lib_core_cmd_exists_su "${var}" || exitcode="1" ;;

      --float) printf "%s" "${var}" | grep -q -E "^(${R_FLOAT})\$" ;;

      --iface|--interface) [ -d "/sys/class/net/${var}" ] ;;

      --int|--integer)
        { [ "${var}" -le 0 ] || [ "${var}" -gt 0 ]; } 2>/dev/null
        ;;

      --int-neg)  [ "${var}" -lt 0 ] 2>/dev/null ;;
      --int-neg0) [ "${var}" -le 0 ] 2>/dev/null ;;
      --int-pos)  [ "${var}" -gt 0 ] 2>/dev/null ;;
      --int-pos0) [ "${var}" -ge 0 ] 2>/dev/null ;;

      --number)
        { [ "${var}" -le 0 ] || [ "${var}" -gt 0 ]; } 2>/dev/null || \
        printf "%s" "${var}" | grep -q -E "^(${R_FLOAT})\$"
        ;;

      --sig|--signal|--SIG)
        kill -l "${var}" >/dev/null 2>&1 || \

        # Some implementations do not support signal names,
        # e.g. 'kill -l INT' does not work
        kill -l | grep -q -E "^${var}\$"
        ;;

      --unit)
        case "${var}" in
          [kMGTPEZY][bB]|[bB]) ;;
          *) false ;;
        esac
        ;;

      #-------------------------------------------------------------------------
      #  finally check if there are any regex tests matching <arg_select>
      #-------------------------------------------------------------------------
      *) lib_core_regex "${arg_select}" "${var}" ;;
    esac                                                                    || \

    return

  done

  return ${exitcode}
}

lib_core_test() {
  lib_core_is "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_list_contains_str
#  DESCRIPTION:  Looks for a string within a delimited list of strings
# PARAMETER  1:  Search string
#            2:  List of strings
#            3:  (Optional) List delimiter (default: ' ')
#   RETURNS  0:  String in list
#            1:  String not(!) in list
#            2:  Empty search string, empty list or invalid delimiter
#===============================================================================
lib_core_list_contains_str() {
  local arg_str="$1"
  local arg_list="$2"
  local arg_delim="${3:- }"

  lib_core_is --not-empty "${arg_str}" "${arg_list}"  && \
  [ "${#arg_delim}" -eq "1" ]                         || \
  return 2

  local IFS="${arg_delim}"

  local val
  for val in ${arg_list}; do
    if [ "${arg_str}" = "${val}" ]; then return; fi
  done

  return 1
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_list_contains_str_ptr
#  DESCRIPTION:  Looks for a string within a delimited list of strings where
#                the list does not(!) contain the strings themselves but their
#                variable pointers
# PARAMETER  1:  Search string
#            2:  List of string pointers
#            3:  (Optional) List delimiter (default: ' ')
#            4:  (Optional) Pointer prefix (will be prepended to each pointer)
#            5:  (Optional) Pointer suffix (will be appended to each pointer)
#   RETURNS  0:  String in list
#            1:  String not(!) in list
#            2:  Empty search string, empty pointer list or invalid delimiter
#===============================================================================
lib_core_list_contains_str_ptr() {
  local arg_str="$1"
  local arg_list="$2"
  local arg_delim="${3:- }"
  local arg_ptr_prefix="$4"
  local arg_ptr_suffix="$5"

  lib_core_is --not-empty "${arg_str}" "${arg_list}"  && \
  [ "${#arg_delim}" -eq "1" ]                         || \
  return 2

  local IFS="${arg_delim}"

  local ptr
  local val
  for ptr in ${arg_list}; do
    ptr="${arg_ptr_prefix}${ptr}${arg_ptr_suffix}"
    if lib_core_is --varname "${ptr}"; then
      eval val=\"\${${ptr}}\"
      if [ "${arg_str}" = "${val}" ]; then return; fi
    fi
  done

  return 1
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_msg
#  DESCRIPTION:  Log/Print error/info/warning message
# PARAMETER  1:  Message type (--error|--info|--warning) (default: '--info')
#            2:  Message
#      OUTPUTS:  Writes to <stdout|stderr> (terminal) or syslog (auto-detected)
#      RETURNS:  0 (--info|--warning) or 1 (--error)
#===============================================================================
lib_core_msg() {
  local exitcode="0"
  local prefix="[INFO]"
  local pri="info"
  local fd="1"
  local std="stdout"

  case "$1" in
    --error)
      exitcode="1"; prefix="[ERROR]"; pri="err"; fd="2"; std="stderr"; shift ;;
    --info)
      exitcode="0"; prefix="[INFO]"; pri="info"; fd="1"; std="stdout"; shift ;;
    --warning)
      exitcode="0"; prefix="[WARNING]"; pri="warning"; fd="1"; std="stdout"
      shift ;;
    *) ;;
  esac

  #  Determine message "destination"
  if lib_core_is --terminal-${std}; then
    printf "%s\n" "${prefix} $1" >&${fd}
  else
    logger -t "$0" -p "${pri}" "${prefix} $1"
  fi

  return ${exitcode}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_parse_credentials
#  DESCRIPTION:  Parse credentials that are provided via an environment
#                variable
# PARAMETER  1:  Credential, provided either
#                 - via an environment variable, in the form of 'ENV:<VAR>'
#                   (without '' <>) where <VAR> is the variable's name, or
#                 - directly, in clear-text form (not recommended).
#      OUTPUTS:  Credentials in clear-text form to <stdout>
#   RETURNS  0:  OK
#            1:  Error: An environment variable was provided but the name
#                       is not POSIX compliant ([a-zA-Z_][a-zA-Z_0-9]*)
#      EXAMPLE:  Via an environment variable
#                  > export mypwd="123456"
#                  > lib_core_parse_credentials "ENV:mypwd"
#                  >> 123456
#                Directly
#                  > lib_core_parse_credentials "123456"
#                  >> 123456
#===============================================================================
lib_core_parse_credentials() {
  local arg_input="$1"

  local str_cred
  case "${arg_input}" in
    ENV:*)
      # Via an environment variable (ENV:<VAR>)
      arg_input="${arg_input#"ENV:"}"
      if lib_core_is --posix-name "${arg_input}"; then
        eval str_cred=\"\$${arg_input}\"
      else
        # Error: <VAR> is not a POSIX-compliant name
        return 1
      fi
      ;;

    env:*)
      # Via an environment variable (env:<VAR>)
      arg_input="${arg_input#"env:"}"
      if lib_core_is --posix-name "${arg_input}"; then
        eval str_cred=\"\$${arg_input}\"
      else
        # Error: <VAR> is not a POSIX-compliant name
        return 1
      fi
      ;;

    *)
      # Directly, in clear-text form
      str_cred="${arg_input}"
      ;;
  esac

  printf "%s" "${str_cred}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_path_get_abs
#  DESCRIPTION:  Get absolute path to a directory or file
#                (in case it contains relative paths or symlinks)
# PARAMETER  1:  (Directory or file) path
#      OUTPUTS:  Absolute path to <stdout>
#
#      SOURCES:  Adapted from "https://stackoverflow.com/a/39873717"
#                by "A. Geoghegan" (https://stackoverflow.com/users/1640661/anthony-geoghegan)
#                licensed under "CC BY-SA 4.0" (https://creativecommons.org/licenses/by-sa/4.0/)
#===============================================================================
lib_core_path_get_abs() {
  local arg_path="$1"

  [ -e "${arg_path}" ] || return

  local path_abs
  if command -v readlink >/dev/null ; then
    path_abs="$(readlink -f "${arg_path}")"
  elif command -v realpath >/dev/null ; then
    path_abs="$(realpath "${arg_path}")"
  else
    case "${arg_path}" in
      /*)
        # The path of the provided directory is already absolute.
        path_abs="${arg_path}"
      ;;
      *)
        # Prepend the path of the current directory.
        path_abs="$PWD/${arg_path}"
      ;;
    esac
  fi

  printf "%s" "${path_abs}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_regex
#  DESCRIPTION:  Check if a given string matches a regular expression
# PARAMETER  1:  Regex pattern selector (see switch-case statement below)
#            2:  String to check
#===============================================================================
lib_core_regex() {
  local arg_option="$1"
  local arg_str="$2"

  #-----------------------------------------------------------------------------
  #  SELECT REGEX
  #-----------------------------------------------------------------------------
  local regex=""
  case "${arg_option}" in
    --bool|--boolean)     regex="${LIB_CORE_REGEX_TYPE_BOOLEAN}"              ;;
    --cups-devuri)        regex="${LIB_CORE_REGEX_CUPS_DEVURI}"               ;;
    --cups-queue)         regex="${LIB_CORE_REGEX_CUPS_QUEUE}"                ;;
    --dns-srv)            regex="${LIB_CORE_REGEX_NET_DNS_SRV}"               ;;
    --float)              regex="${LIB_CORE_REGEX_TYPE_FLOAT}"                ;;
    --float-neg)          regex="${LIB_CORE_REGEX_TYPE_FLOAT_NEG}"            ;;
    --float-neg0)         regex="${LIB_CORE_REGEX_TYPE_FLOAT_NEG0}"           ;;
    --float-pos)          regex="${LIB_CORE_REGEX_TYPE_FLOAT_POS}"            ;;
    --float-pos0)         regex="${LIB_CORE_REGEX_TYPE_FLOAT_POS0}"           ;;
    --fqdn)               regex="${LIB_CORE_REGEX_NET_DNS_FQDN}"              ;;
    --fqdn-or-wildcard)   regex="${LIB_CORE_REGEX_NET_DNS_FQDN_OR_WILDCARD}"  ;;
    --fqdn-wildcard)      regex="${LIB_CORE_REGEX_NET_DNS_FQDN_WILDCARD}"     ;;
    --hex)                regex="${LIB_CORE_REGEX_TYPE_HEX}"                  ;;
    --host)               regex="${LIB_CORE_REGEX_NET_HOST}"                  ;;
    --hostname)           regex="${LIB_CORE_REGEX_NET_DNS_FQDN_SEG}"          ;;
    --icmp)               regex="${LIB_CORE_REGEX_NET_ICMP_TYPE}"             ;;
    --int|--integer)      regex="${LIB_CORE_REGEX_TYPE_INTEGER}"              ;;
    --int-neg)            regex="${LIB_CORE_REGEX_TYPE_INTEGER_NEG}"          ;;
    --int-neg0)           regex="${LIB_CORE_REGEX_TYPE_INTEGER_NEG0}"         ;;
    --int-pos)            regex="${LIB_CORE_REGEX_TYPE_INTEGER_POS}"          ;;
    --int-pos0)           regex="${LIB_CORE_REGEX_TYPE_INTEGER_POS0}"         ;;
    --ip4|--ipv4|--inet)  regex="${LIB_CORE_REGEX_NET_IPV4_ADDR}"             ;;
    --ip4-cidr)           regex="${LIB_CORE_REGEX_NET_IPV4_CIDR}"             ;;
    --ip4-range)          regex="${LIB_CORE_REGEX_NET_IPV4_RANGE}"            ;;
    --ip6|--ipv6|--inet6) regex="${LIB_CORE_REGEX_NET_IPV6_ADDR}"             ;;
    --ip6-cidr)           regex="${LIB_CORE_REGEX_NET_IPV6_CIDR}"             ;;
    --ipset-ip4)          regex="${LIB_CORE_REGEX_IPSET_IPADDR_4}"            ;;
    --ipset-ip6)          regex="${LIB_CORE_REGEX_IPSET_IPADDR_6}"            ;;
    --ipset-setname)      regex="${LIB_CORE_REGEX_IPSET_SETNAME}"             ;;
    --ipset-port-bitmap)  regex="${LIB_CORE_REGEX_IPSET_PORT_BITMAP}"         ;;
    --ipset-port-hash4)   regex="${LIB_CORE_REGEX_IPSET_PORT_HASH_4}"         ;;
    --ipset-port-hash6)   regex="${LIB_CORE_REGEX_IPSET_PORT_HASH_6}"         ;;
    --luks2-tpm2-pcrs)    regex="${LIB_CORE_REGEX_LUKS2_TPM2_PCRS}"           ;;
    --mac)                regex="${LIB_CORE_REGEX_NET_MAC}"                   ;;
    --num|--number)       regex="${LIB_CORE_REGEX_TYPE_NUM_DEC}"              ;;
    --num-neg)            regex="${LIB_CORE_REGEX_TYPE_NUM_DEC_NEG}"          ;;
    --num-neg0)           regex="${LIB_CORE_REGEX_TYPE_NUM_DEC_NEG0}"         ;;
    --num-pos)            regex="${LIB_CORE_REGEX_TYPE_NUM_DEC_POS}"          ;;
    --num-pos0)           regex="${LIB_CORE_REGEX_TYPE_NUM_DEC_POS0}"         ;;
    --oid)                regex="${LIB_CORE_REGEX_TYPE_OID}"                  ;;
    --opensc-p15-profile) regex="${LIB_CORE_REGEX_OPENSC_P15_PROFILE}"        ;;
    --posix-name|--funcname|--varname) regex="${LIB_CORE_REGEX_POSIX_NAME}"   ;;
    --sftp-uri)           regex="${LIB_CORE_REGEX_NET_SFTP_SFTPURI}"          ;;
    --sftp-uri-short)     regex="${LIB_CORE_REGEX_NET_SFTP_SFTPURI_SHORT}"    ;;
    --ssh-uri)            regex="${LIB_CORE_REGEX_NET_SSH_SSHURI}"            ;;
    --ssh-uri-short)      regex="${LIB_CORE_REGEX_NET_SSH_SSHURI_SHORT}"      ;;
    --tcpudp|--port)      regex="${LIB_CORE_REGEX_NET_TCPUDP_PORT}"           ;;
    --tcpudp-range|--portrange) regex="${LIB_CORE_REGEX_NET_TCPUDP_PORT_RANGE}"  ;;
    --uri|--rfc3986)      regex="${LIB_CORE_REGEX_RFC3986_URI}"               ;;
    --yesno)              regex="${LIB_CORE_REGEX_TYPE_YESNO}"                ;;
    --Yy-${LIB_C_ID_L_DE}) regex="${LIB_CORE_REGEX_TYPE_YY_DE}"               ;;
    --Yy-${LIB_C_ID_L_EN}) regex="${LIB_CORE_REGEX_TYPE_YY_EN}"               ;;
    --Nn-${LIB_C_ID_L_DE}) regex="${LIB_CORE_REGEX_TYPE_NN_DE}"               ;;
    --Nn-${LIB_C_ID_L_EN}) regex="${LIB_CORE_REGEX_TYPE_NN_EN}"               ;;
    *)
      # Besides the predefined patterns you can also use your own one. Please
      # note that the pattern must follow POSIX's extended regular expression
      # (ERE) notation, see also:
      #   https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap09.html#tag_09_04
      regex="${arg_option}"
      ;;
  esac

  #-----------------------------------------------------------------------------
  #  PERFORM CHECK
  #-----------------------------------------------------------------------------
  # Better 'echo' than 'printf', e.g. if <arg_str> is empty ('')
  # and <regex> is '.*' the return value would be '1' with 'printf'
  # printf "%s" "${arg_str}" | grep -q -E "^(${regex})\$"
  echo "${arg_str}" | grep -q -E "^(${regex})\$"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_get_length
#  DESCRIPTION:  Get length of a string
# PARAMETER  1:  String
#      OUTPUTS:  Length to <stdout>
#===============================================================================
lib_core_str_get_length() {
  #echo ${#1}
  expr "$1" : '.*'
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_filter_and_sort
#  DESCRIPTION:  Filter and sort a (multiline) string
# PARAMETER
#     <stdin> :  (Multiline) string
#            1:  Include pattern (must be a basic regular expression (BRE))
#            2:  Exclude pattern (must be a BRE)
#            3:  Remove duplicate lines (true|false) (default: 'false')
#      OUTPUTS:  Selected substring to <stdout>
#===============================================================================
lib_core_str_filter_and_sort() {
  local arg_include="$1"
  local arg_exclude="$2"
  local arg_rm_duplicate="${3:-false}"

  lib_core_is --bool "${arg_rm_duplicate}" || return

  local arg_sort
  if "${arg_rm_duplicate}"; then
    arg_sort="-u"
  fi

  if [ -n "${arg_include}" ]; then grep -e "${arg_include}"; else cat; fi      \
  | if [ -n "${arg_exclude}" ]; then grep -v -e "${arg_exclude}"; else cat; fi \
  | sort${arg_sort:+ ${arg_sort}}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_get_substr
#  DESCRIPTION:  Extract a substring from a given string
# PARAMETER  1:  String
#            2:  (Optional) Start index (>=1) (default: '1')
#            3:  (Optional) End index (default: <string's length>)
#      OUTPUTS:  Selected substring to <stdout>
#===============================================================================
lib_core_str_get_substr() {
  local arg_str="$1"
  local arg_start="$2"
  local arg_end="$3"

  lib_core_is --not-empty "${arg_str}" || \
  return

  lib_core_int_is_within_range "1" "${arg_start}" "${#arg_str}"          || \
  arg_start="1"

  lib_core_int_is_within_range "${arg_start}" "${arg_end}" "${#arg_str}" || \
  arg_end="${#arg_str}"

  __lib_core_str_get_substr "${arg_str}" "${arg_start}" "${arg_end}"
}
__lib_core_str_get_substr() {
  local arg_str="$1"
  local arg_start="$2"
  local arg_end="$3"

  printf "%s" "${arg_str}" | cut -c${arg_start}-${arg_end}
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_is_multiline
#  DESCRIPTION:  Check if one or more strings contain more than one line
# PARAMETER
#         1...:  String(s) to check
#   RETURNS  0:  All strings are multiline strings
#            1:  At least one string is a single-line string
#===============================================================================
lib_core_str_is_multiline() {
  lib_core_args_passed "$@" || return

  local str
  for str in "$@"; do
    case "${str}" in
      *"${LIB_C_STR_NEWLINE}"*) ;;
      *) return 1 ;;
    esac
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_random
#  DESCRIPTION:  Generate a random string
# PARAMETER  1:  Length of the string (>0)
#            2:  Allowed characters, specified either
#                  - as a range, e.g. 'a-zA-Z0-9', or
#                  - as a class, e.g. '[:alnum:]'
#                See also:
#                  https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tr.html
#      OUTPUTS:  Print random string to <stdout>
#
#      SOURCES:  Adapted from
#                  https://developers.yubico.com/yubico-piv-tool/YubiKey_PIV_introduction.html
#===============================================================================
lib_core_str_random() {
  local arg_len="${1:-10}"
  local arg_regex_chars="${2:-[:alnum:]}"

  lib_core_is --int-pos "${arg_len}" && \
  __lib_core_str_random "$@"
}

__lib_core_str_random() {
  local arg_len="${1:-10}"
  local arg_regex_chars="${2:-[:alnum:]}"

  local str
  { str="$(export LC_CTYPE=C; dd if=/dev/urandom  \
      | tr -cd "${arg_regex_chars}"               \
      | fold -w${arg_len} | head -1               \
    )"
  } 2>/dev/null

  [ -n "${str}" ] && printf "%s" "${str}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_remove_leading
#  DESCRIPTION:  Remove leading character(s) from one or multiple string(s)
# PARAMETER  1:  Character or matching pattern to remove,
#                e.g. ' ' or '[:digit:]' (default: '[:space:]')
#         2...:  String(s) to trim
#      OUTPUTS:  Trimmed string(s) separated by <newline> to <stdout>
#
#      SOURCES:  https://mywiki.wooledge.org/BashFAQ/067
#                https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#                https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_13
#===============================================================================
lib_core_str_remove_leading() {
  lib_core_args_passed "$@" || return
  __lib_core_str_remove_leading "$@"
}

__lib_core_str_remove_leading() {
  local arg_pattern="${1:-[:space:]}"
  shift

  local str_remove
  local str_return
  local var
  for var in "$@"; do
    str_remove="${var%%[!${arg_pattern}]*}"
    str_return="${var#"${str_remove}"}"
    printf "%s\n" "${str_return}"
  done
}

lib_core_str_remove_leading_spaces() {
  __lib_core_str_remove_leading " " "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_remove_newline
#  DESCRIPTION:  Replace linebreaks from a string by a certain character
# PARAMETER  1:  String to modify
#            2:  (Optional) Replacement character(s) (default: ' ')
#            3:  (Optional) Keep empty lines (true|false) (default: 'false')
#            4:  (Optional) Trim spaces (true|false) (default: 'false')
#      OUTPUTS:  Modified string to <stdout>
#===============================================================================
lib_core_str_remove_newline() {
  local arg_str="$1"
  local arg_delim="${2:- }"
  local arg_keep_blankline="$(lib_core_bool2int "${3:-false}")"
  local arg_trim_spaces="$(lib_core_bool2int "${4:-false}")"

  lib_core_is --not-empty                                     \
    "${arg_str}" "${arg_keep_blankline}" "${arg_trim_spaces}" && \
  [ ${#arg_delim} -ge 1 ] 2>/dev/null                         || \
  return

  printf "%s" "${arg_str}" | awk                  \
    -v "arg_delim=${arg_delim}"                   \
    -v "arg_keep_blankline=${arg_keep_blankline}" \
    -v "arg_trim_spaces=${arg_trim_spaces}"       \
    '
    BEGIN {
      ORS=""
      delim=""
    }

    {
      if (arg_trim_spaces) {
        gsub(/^[ \t]+|[ \t]+$/, "");
        gsub(/[ ]+/," ");
      }

      if ($0 ~ /^[[:space:]]*$/) {
          if (arg_keep_blankline) {
            printf "\n\n"; delim="";
          }
      } else {
          printf("%s%s", delim, $0); delim=arg_delim;
      }
    }'
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_remove_trailing
#  DESCRIPTION:  Remove trailing character(s) from one or multiple string(s)
# PARAMETER  1:  Character or matching pattern to remove,
#                e.g. ' ', '[:digit:]', ... (default: '[:space:]')
#         2...:  String(s) to trim
#      OUTPUTS:  Trimmed string(s) separated by <newline> to <stdout>
#
#      SOURCES:  https://mywiki.wooledge.org/BashFAQ/067
#                https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
#                https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_13
#===============================================================================
lib_core_str_remove_trailing() {
  lib_core_args_passed "$@" || return
  __lib_core_str_remove_trailing "$@"
}

__lib_core_str_remove_trailing() {
  local arg_pattern="${1:-[:space:]}"
  shift

  local str_remove
  local str_return
  local var
  for var in "$@"; do
    str_remove="${var##*[!${arg_pattern}]}"
    str_return="${var%"${str_remove}"}"
    printf "%s\n" "${str_return}"
  done
}

lib_core_str_remove_trailing_spaces() {
  __lib_core_str_remove_trailing " " "$@"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_replace_char
#  DESCRIPTION:  Replace (or delete) all occurrences of one or multiple
#                characters in a string by using 'tr' command
# PARAMETER  1:  String to modify
#            2:  Character(s) to replace or delete, specified either as a
#                  - single character, e.g. 'a',
#                  - range, e.g. 'a-zA-Z0-9', or
#                  - character class, e.g. '[:alnum:]'.
#                See also:
#                  https://pubs.opengroup.org/onlinepubs/9699919799/utilities/tr.html
#            3:  (Optional) Replacement character - if not defined
#                then the character defined in parameter <2> just gets removed
#      OUTPUTS:  Modified string to <stdout>
#===============================================================================
lib_core_str_replace_char() {
  local arg_string="$1"
  local arg_char_old="$2"
  local arg_char_new="$3"

  printf "%s" "${arg_string}" | case "${#arg_char_new}" in
    0) tr -d "${arg_char_old}" ;;
    *) tr "${arg_char_old}" "${arg_char_new}" ;;
  esac
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_replace_substr
#
#  DESCRIPTION:  Replace (or delete) all occurrences of a substring by using
#                'sed' command. See also:
#                  https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sed.html
#
# PARAMETER  1:  String to modify
#
#            2:  Substring to replace or delete, as a basic regular expression
#                (BRE). The following characters must be escaped with '\':
#                  . [ \ * ^ $ /
#                See also:
#                  https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html#tag_09_03
#
#                You may use capture groups '\(...\)' to reuse matched
#                substrings in parameter <3>.
#
#            3:  (Optional) Replacement substring - if not defined
#                then the substring defined in parameter <2> just gets removed.
#                In case you have defined capture groups '\(...\)' in
#                parameter <2> you can insert them by using '\1' for the first
#                capture group, '\2' for the second, ...
#
#      OUTPUTS:  Modified string to <stdout>
#===============================================================================
lib_core_str_replace_substr() {
  local arg_str="$1"
  local arg_substr_old="$2"
  local arg_substr_new="$3"

  printf "%s" "${arg_str}" | sed -e "s/${arg_substr_old}/${arg_substr_new}/g"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_split
#  DESCRIPTION:  Split a given string into substrings (separated by <newline>)
#                but preserve quoted <"..."> substrings even if they contain
#                spaces
# PARAMETER $@:  String
#      OUTPUTS:  Writes one line per parameter per value to <stdout>
#      EXAMPLE:  'lib_core_str_split 'a "b c" d' results in:
#                  a
#                  b c
#                  d
#===============================================================================
lib_core_str_split() {
  local input="$*"
  local teststr='"'

  # Check if input contains quotes ("). This can happen if the
  # string is not given directly via the command line, like
  #   __lib_core_str_split "123" "this should be in one line" "abc"
  # but inside a variable, like
  #   string='"123" "this should be in one line" "abc"'
  #   __lib_core_str_split "${string}"
  OLDIFS="$IFS"
  IFS='"'

  local str
  if test "${input#*${teststr}}" != "${input}"; then
    # String contains quotes
    for str in "$@"; do
      # Ignore blank lines
      case "$str" in
        *[![:blank:]]*)
          str="$(lib_core_str_remove_leading_spaces "$str")"
          str="$(lib_core_str_remove_trailing_spaces "$str")"
          printf "%s\n" "$str"
          ;;
        *) continue ;;
      esac
    done
  else
    # String does not contain quotes
    for str in $@; do printf "%s\n" "$str";done
  fi

  IFS="$OLDIFS"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_str_to
#  DESCRIPTION:  Convert one or multiple string(s)
# PARAMETER  1:  Conversion selector (see 'case' statement below)
#         2...:  String(s) to convert
#      OUTPUTS:  Converted string(s) separated by <newline> to <stdout>
#===============================================================================
lib_core_str_to() {
  lib_core_args_passed "$@" || return
  __lib_core_str_to "$@"
}

__lib_core_str_to() {
  local arg_select="${1:---upper}"
  shift

  local regex_src
  local regex_dst
  case "${arg_select}" in
    --const) regex_src="[[:lower:]-]"; regex_dst="[[:upper:]_]" ;;
    --lower) regex_src="[:upper:]"; regex_dst="[:lower:]" ;;
    --upper) regex_src="[:lower:]"; regex_dst="[:upper:]" ;;
    *) return 1 ;;
  esac

  local var
  for var in "$@"; do
    printf "%s\n" "${var}" | tr "${regex_src}" "${regex_dst}"
  done
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_sudo
#  DESCRIPTION:  !!! CAUTION - PLEASE USE THIS FUNCTION CAREFULLY !!!
#                Execute one or more commands with root privileges
# PARAMETER
#         1...:  Command(s) to execute
#===============================================================================
lib_core_sudo() {
  lib_core_args_passed "$@" || return

  if lib_core_is --su; then
    "$@"
  else
    lib_core_is --cmd sudo || return
    # sudo -n -- "$@" throws errors when "$@" contains variable sets
    # e.g. sudo -n -- a=2 ...
    if ${LIB_CORE_PARENT_SHELL_IS_TERMINAL}; then
      sudo "$@"
    else
      __lib_core_can_sudo_nopasswd && \
      sudo -n "$@"
    fi
  fi
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_sudo_background
#  DESCRIPTION:  Execute one or more commands with root privileges and
#                put them into background
# PARAMETER  1:  File where stdout/stderr should be logged to
#                (default: '/dev/null')
#         2...:  Command(s) to execute
#      OUTPUTS:  Prints the command's PID to <stdout>
#===============================================================================
lib_core_sudo_background() {
  local arg_log="${1:-/dev/null}"
  shift

  lib_core_args_passed "$@" || return

  if lib_core_is --su; then
    nohup "$@" >"${arg_log}" 2>&1 &
  else
    lib_core_is --cmd sudo || return
    # sudo -n -- "$@" throws errors when "$@" contains variable sets
    # e.g. sudo -n -- a=2 ...
    if ${LIB_CORE_PARENT_SHELL_IS_TERMINAL}; then
      nohup sudo "$@" >"${arg_log}" 2>&1 &
    else
      nohup sudo -n "$@" >"${arg_log}" 2>&1 &
    fi
  fi

  printf "%s\n" "$!"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_sysfs_get
#
#  DESCRIPTION:  Wrapper for accessing 'sysfs' - For more information on 'sysfs'
#                folder/file structure please have a look at:
#
#                  https://www.kernel.org/doc/Documentation/ABI/testing
#
# PARAMETER  1:  Sysfs directory, e.g. '/sys/class/net/eth0'
#
#            2:  Sysfs file
#                You can either use the file names as they are, e.g. 'address'
#                or use them with the prefix '--', e.g. '--address'.
#                You are allowed to use '-' instead of '_' meaning you can use
#                '--tx-queue-len' instead of 'tx_queue_len'.
#
#      OUTPUTS:  Sysfs file content. For more information on how to interpret
#                the content please have a look at the link above.
#
#   RETURNS  0:  OK
#            1:  Sysfs file could not be found
#===============================================================================
lib_core_sysfs_get() {
  local arg_dir="$1"
  local arg_file="$2"

  case "${arg_file}" in
    --[!-]*)  arg_file="$(printf "%s" "${arg_file}" | cut -d "-" -f3-)" ;;
    [!-]*)    ;;
    *)        return 1 ;;
  esac

  arg_file="$(lib_core_str_replace_char "${arg_file}" "-" "_" )"  && \
  arg_file="${arg_dir}/${arg_file}"                               && \
  lib_core_is --file "${arg_file}"                                && \
  cat "${arg_file}"                                               || \
  return
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_time_timestamp
#  DESCRIPTION:  Get current time in UNIX Epoch format
# PARAMETER  1:  Accuracy, in seconds (-s|--s|s), milliseconds (-m|--ms|ms),
#                microseconds (-µ|--µs|µs) or nanoseconds (-n|--ns|ns)
#===============================================================================
lib_core_time_timestamp() {
  local arg_unit="${1:-s}"  # destination unit

  local timestamp    # current time as Epoch timestamp (in ns)
  timestamp="$(date +%s%N)"

  case "${arg_unit}" in
    -s|--s|s)
      timestamp=${timestamp%?????????}
      ;;
    -m|--ms|ms)
      timestamp=${timestamp%??????}
      ;;
    -µ|--µs|µs)
      timestamp=${timestamp%???}
      ;;
    -n|--ns|ns)
      ;;
    *)
      return 1
      ;;
  esac

  printf "%s" "${timestamp}"
}

#===  FUNCTION  ================================================================
#         NAME:  lib_core_var_is
#
#  DESCRIPTION:  Perform general checks (defined, null, etc.) and
#                type checks (bool, file, integer, etc.) on variables
#
#                (I)  Variable Checks (defined, null, etc.)
#                (II) Type Checks (is bool, file, integer, etc.)
#
# PARAMETER  1:  Test selector ("type of test")
#                For a list of selectors please have a look at the 'case'
#                statement below and in <lib_core_is()>
#
#         2...:  Variable(s) to check (identifier(s)/name(s))
#
#                !!! This function expects the variables' identifiers/names
#                (var1 var2 ...) and not their values ($var1 $var2 ...) !!!
#
#   RETURNS  0:  All variables passed the test
#            1:  At least one variable failed the test
#
#      EXAMPLE:  lib_core_var_is --defined var1
#                lib_core_var_is --file var1 var2
#===============================================================================
lib_core_var_is() {
  local arg_select="$1"; shift

  # Check if variables have been passed (beside the test selector)
  lib_core_args_passed "$@" || return

  # Check all variables and break with the first one that fails
  local var
  for var in "$@"; do
    lib_core_is --varname "${var}" && \
    case "${arg_select}" in
      #-------------------------------------------------------------------------
      #  (I) Variable checks
      #-------------------------------------------------------------------------
      #  See: http://pubs.opengroup.org/onlinepubs/009695399/utilities/xcu_chap02.html#tag_02_06_02
      #-------------------------------------------------------------------------
      --not-empty|--not-null)
        #  Set and Not Null
        eval [ -n \"\${$var}\" ]
        ;;

      --empty|--null)
        #  Set But Null (returns 1 in case the variable is not defined)
        eval [ -z \"\${$var-x}\" ]
        ;;

      --defined|--set)
        #  Set (variable is defined, can be either null or have value)
        eval [ -n \"\${$var+x}\" ]
        ;;

      --not-defined|--unset)
        #  Unset (variable is not defined)
        eval [ -z \"\${$var+x}\" ]
        ;;

      #-------------------------------------------------------------------------
      #  (II) Type checks
      #-------------------------------------------------------------------------
      *)
        # All other checks are performed within <lib_core_is()>
        eval lib_core_is \"\${arg_select}\" \"\${$var}\"
        ;;
    esac || \

    return
  done
}

#===============================================================================
#  MAIN
#===============================================================================
lib_core_main "$@"