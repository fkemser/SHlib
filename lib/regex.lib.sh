#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2025 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/regex.lib.sh
#
#        USAGE:   . regex.lib.sh
#
#  DESCRIPTION:   Shell library providing regular expression tests, such as
#
#                   - data types (boolean, float, hexadecimal, integer),
#                   - network-related (DNS, ICMP, IPv4/6, MAC, TCP, UDP), and
#                   - application-specific (CUPS, IPset, LUKS, etc.) tests.
#
#                 For a full list please have a look at the function
#                 <lib_regex()> below.
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
if lib_regex_loaded 2>/dev/null; then return; fi

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
#-------------------------------------------------------------------------------
#  RFC 2234 (Augmented BNF for Syntax Specifications: ABNF)
#-------------------------------------------------------------------------------
# See also: https://datatracker.ietf.org/doc/html/rfc2234
readonly LIB_REGEX_RFC2234_ALPHA="([A-Za-z])"
readonly LIB_REGEX_RFC2234_BIT="([01])"
# readonly LIB_REGEX_RFC2234_CHAR="([\x01-\x7F])"
readonly LIB_REGEX_RFC2234_CR="([\r])"
readonly LIB_REGEX_RFC2234_CRLF="([\r\n])"
readonly LIB_REGEX_RFC2234_CTL="([[:cntrl:]])"
readonly LIB_REGEX_RFC2234_DIGIT="([0-9])"
readonly LIB_REGEX_RFC2234_DQUOTE="([\"])"
readonly LIB_REGEX_RFC2234_HEXDIG="([0-9A-Fa-f])"
readonly LIB_REGEX_RFC2234_HTAB="([\t])"
readonly LIB_REGEX_RFC2234_LF="([\n])"
readonly LIB_REGEX_RFC2234_LWSP="(([ \t]|([\r\n][ \t]))*)"
# readonly LIB_REGEX_RFC2234_OCTET="([\x00-\xFF])"
readonly LIB_REGEX_RFC2234_SP="([ ])"
readonly LIB_REGEX_RFC2234_VCHAR="([[:graph:]])"
readonly LIB_REGEX_RFC2234_WSP="([ \t])"

#-------------------------------------------------------------------------------
#  RFC 3986 (Uniform Resource Identifier (URI): Generic Syntax)
#-------------------------------------------------------------------------------
# See also: https://datatracker.ietf.org/doc/html/rfc3986
readonly LIB_REGEX_RFC3986_SUB_DELIMS="([!$&'()*+,;=])"
readonly LIB_REGEX_RFC3986_GEN_DELIMS="([:/?#@]|[][])"
readonly LIB_REGEX_RFC3986_RESERVED="(${LIB_REGEX_RFC3986_GEN_DELIMS}|${LIB_REGEX_RFC3986_SUB_DELIMS})"
readonly LIB_REGEX_RFC3986_UNRESERVED="(${LIB_REGEX_RFC2234_ALPHA}|${LIB_REGEX_RFC2234_DIGIT}|[._~-])"

readonly LIB_REGEX_RFC3986_PCT_ENCODED="(%${LIB_REGEX_RFC2234_HEXDIG}{2})"

readonly LIB_REGEX_RFC3986_PCHAR="(${LIB_REGEX_RFC3986_UNRESERVED}|${LIB_REGEX_RFC3986_PCT_ENCODED}|${LIB_REGEX_RFC3986_SUB_DELIMS}|[:@])"

readonly LIB_REGEX_RFC3986_FRAGMENT="((${LIB_REGEX_RFC3986_PCHAR}|[/?])*)"

readonly LIB_REGEX_RFC3986_QUERY="${LIB_REGEX_RFC3986_FRAGMENT}"

readonly LIB_REGEX_RFC3986_SEGMENT_NZ_NC="((${LIB_REGEX_RFC3986_UNRESERVED}|${LIB_REGEX_RFC3986_PCT_ENCODED}|${LIB_REGEX_RFC3986_SUB_DELIMS}|@){1,})"
readonly LIB_REGEX_RFC3986_SEGMENT_NZ="(${LIB_REGEX_RFC3986_PCHAR}{1,})"
readonly LIB_REGEX_RFC3986_SEGMENT="(${LIB_REGEX_RFC3986_PCHAR}*)"

readonly LIB_REGEX_RFC3986_PATH_EMPTY="()"
readonly LIB_REGEX_RFC3986_PATH_ROOTLESS="(${LIB_REGEX_RFC3986_SEGMENT_NZ}(/${LIB_REGEX_RFC3986_SEGMENT})*)"
readonly LIB_REGEX_RFC3986_PATH_NOSCHEME="(${LIB_REGEX_RFC3986_SEGMENT_NZ_NC}(/${LIB_REGEX_RFC3986_SEGMENT})*)"
readonly LIB_REGEX_RFC3986_PATH_ABSOLUTE="(/(${LIB_REGEX_RFC3986_SEGMENT_NZ}(/${LIB_REGEX_RFC3986_SEGMENT})*){0,1})"
readonly LIB_REGEX_RFC3986_PATH_ABEMPTY="(/${LIB_REGEX_RFC3986_SEGMENT})*"

readonly LIB_REGEX_RFC3986_PATH="(${LIB_REGEX_RFC3986_PATH_ABEMPTY}|${LIB_REGEX_RFC3986_PATH_ABSOLUTE}|${LIB_REGEX_RFC3986_PATH_NOSCHEME}|${LIB_REGEX_RFC3986_PATH_ROOTLESS}|${LIB_REGEX_RFC3986_PATH_EMPTY})"

readonly LIB_REGEX_RFC3986_REG_NAME="(${LIB_REGEX_RFC3986_UNRESERVED}|${LIB_REGEX_RFC3986_PCT_ENCODED}|${LIB_REGEX_RFC3986_SUB_DELIMS})*"

readonly LIB_REGEX_RFC3986_DEC_OCTET="([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])"

readonly LIB_REGEX_RFC3986_IPV4ADDRESS="((${LIB_REGEX_RFC3986_DEC_OCTET}\.){3}${LIB_REGEX_RFC3986_DEC_OCTET})"
readonly LIB_REGEX_RFC3986_H16="(${LIB_REGEX_RFC2234_HEXDIG}{1,4})"
readonly LIB_REGEX_RFC3986_LS32="((${LIB_REGEX_RFC3986_H16}:${LIB_REGEX_RFC3986_H16})|${LIB_REGEX_RFC3986_IPV4ADDRESS})"

readonly LIB_REGEX_RFC3986_IPV6ADDRESS="(\
((${LIB_REGEX_RFC3986_H16}:){6}${LIB_REGEX_RFC3986_LS32})|\
(::(${LIB_REGEX_RFC3986_H16}:){5}${LIB_REGEX_RFC3986_LS32})|\
((${LIB_REGEX_RFC3986_H16}){0,1}::(${LIB_REGEX_RFC3986_H16}:){4}${LIB_REGEX_RFC3986_LS32})|\
(((${LIB_REGEX_RFC3986_H16}:){0,1}${LIB_REGEX_RFC3986_H16}){0,1}::(${LIB_REGEX_RFC3986_H16}:){3}${LIB_REGEX_RFC3986_LS32})|\
(((${LIB_REGEX_RFC3986_H16}:){0,2}${LIB_REGEX_RFC3986_H16}){0,1}::(${LIB_REGEX_RFC3986_H16}:){2}${LIB_REGEX_RFC3986_LS32})|\
(((${LIB_REGEX_RFC3986_H16}:){0,3}${LIB_REGEX_RFC3986_H16}){0,1}::${LIB_REGEX_RFC3986_H16}:${LIB_REGEX_RFC3986_LS32})|\
(((${LIB_REGEX_RFC3986_H16}:){0,4}${LIB_REGEX_RFC3986_H16}){0,1}::${LIB_REGEX_RFC3986_LS32})|\
(((${LIB_REGEX_RFC3986_H16}:){0,5}${LIB_REGEX_RFC3986_H16}){0,1}::${LIB_REGEX_RFC3986_H16})|\
(((${LIB_REGEX_RFC3986_H16}:){0,6}${LIB_REGEX_RFC3986_H16}){0,1}::)\
)"

readonly LIB_REGEX_RFC3986_IPVFUTURE="(v${LIB_REGEX_RFC2234_HEXDIG}{1,}\.(${LIB_REGEX_RFC3986_UNRESERVED}|${LIB_REGEX_RFC3986_SUB_DELIMS}|:){1,})"

readonly LIB_REGEX_RFC3986_IP_LITERAL="\[(${LIB_REGEX_RFC3986_IPV6ADDRESS}|${LIB_REGEX_RFC3986_IPVFUTURE})\]"

readonly LIB_REGEX_RFC3986_PORT="(${LIB_REGEX_RFC2234_DIGIT}*)"
readonly LIB_REGEX_RFC3986_HOST="(${LIB_REGEX_RFC3986_IP_LITERAL}|${LIB_REGEX_RFC3986_IPV4ADDRESS}|${LIB_REGEX_RFC3986_REG_NAME})"
readonly LIB_REGEX_RFC3986_USERINFO="((${LIB_REGEX_RFC3986_UNRESERVED}|${LIB_REGEX_RFC3986_PCT_ENCODED}|${LIB_REGEX_RFC3986_SUB_DELIMS}|:)*)"
readonly LIB_REGEX_RFC3986_AUTHORITY="((${LIB_REGEX_RFC3986_USERINFO}@){0,1}${LIB_REGEX_RFC3986_HOST}(:${LIB_REGEX_RFC3986_PORT}){0,1})"

readonly LIB_REGEX_RFC3986_SCHEME="(${LIB_REGEX_RFC2234_ALPHA}(${LIB_REGEX_RFC2234_ALPHA}|${LIB_REGEX_RFC2234_DIGIT}|[+.-])*)"

readonly LIB_REGEX_RFC3986_RELATIVE_PART="((//${LIB_REGEX_RFC3986_AUTHORITY}${LIB_REGEX_RFC3986_PATH_ABEMPTY})|${LIB_REGEX_RFC3986_PATH_ABSOLUTE}|${LIB_REGEX_RFC3986_PATH_NOSCHEME}|${LIB_REGEX_RFC3986_PATH_EMPTY})"

readonly LIB_REGEX_RFC3986_RELATIVE_REF="(${LIB_REGEX_RFC3986_RELATIVE_PART}(\?${LIB_REGEX_RFC3986_QUERY}){0,1}(#${LIB_REGEX_RFC3986_FRAGMENT}){0,1})"

readonly LIB_REGEX_RFC3986_HIER_PART="((//${LIB_REGEX_RFC3986_AUTHORITY}${LIB_REGEX_RFC3986_PATH_ABEMPTY})|${LIB_REGEX_RFC3986_PATH_ABSOLUTE}|${LIB_REGEX_RFC3986_PATH_ROOTLESS}|${LIB_REGEX_RFC3986_PATH_EMPTY})"

readonly LIB_REGEX_RFC3986_ABSOLUTE_URI="(${LIB_REGEX_RFC3986_SCHEME}:${LIB_REGEX_RFC3986_HIER_PART}(\?${LIB_REGEX_RFC3986_QUERY}){0,1})"

readonly LIB_REGEX_RFC3986_URI="(${LIB_REGEX_RFC3986_SCHEME}:${LIB_REGEX_RFC3986_HIER_PART}(\?${LIB_REGEX_RFC3986_QUERY}){0,1}(#${LIB_REGEX_RFC3986_FRAGMENT}){0,1})"

readonly LIB_REGEX_RFC3986_URI_REFERENCE="(${LIB_REGEX_RFC3986_URI}|${LIB_REGEX_RFC3986_RELATIVE_REF})"

#-------------------------------------------------------------------------------
#  NETWORK (DNS)
#-------------------------------------------------------------------------------
readonly LIB_REGEX_NET_DNS_FQDN_TLD="[A-Za-z-]{2,}" # top-level domain

# Adapted from: R. Sabourin, http://regexlib.com/REDetails.aspx?regexp_id=391
readonly LIB_REGEX_NET_DNS_FQDN_SEG="[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9]){0,1}"
readonly LIB_REGEX_NET_DNS_FQDN="((${LIB_REGEX_NET_DNS_FQDN_SEG})\.){1,}(${LIB_REGEX_NET_DNS_FQDN_TLD})"
readonly LIB_REGEX_NET_DNS_FQDN_OR_WILDCARD="(\*\.){0,1}(${LIB_REGEX_NET_DNS_FQDN})"
readonly LIB_REGEX_NET_DNS_FQDN_WILDCARD="\*\.(${LIB_REGEX_NET_DNS_FQDN})"
readonly LIB_REGEX_NET_DNS_SRV="_(${LIB_REGEX_NET_DNS_FQDN_SEG})\._(TCP|tcp|UDP|udp)\.(${LIB_REGEX_NET_DNS_FQDN})\.{0,1}"

#-------------------------------------------------------------------------------
#  NETWORK (IPv4)
#-------------------------------------------------------------------------------
# Adapted from: J. Goyvaerts, S. Levithan, https://www.oreilly.com/library/view/regular-expressions-cookbook/9780596802837/ch07s16.html
readonly LIB_REGEX_NET_IPV4_ADDR_SEG="25[0-5]|2[0-4][0-9]|[01]{0,1}[0-9][0-9]{0,1}"
readonly LIB_REGEX_NET_IPV4_ADDR="((${LIB_REGEX_NET_IPV4_ADDR_SEG})\.){3,3}(${LIB_REGEX_NET_IPV4_ADDR_SEG})"
readonly LIB_REGEX_NET_IPV4_CIDR="(${LIB_REGEX_NET_IPV4_ADDR})\/(3[0-2]|[1-2][0-9]|[0-9])"
readonly LIB_REGEX_NET_IPV4_RANGE="(${LIB_REGEX_NET_IPV4_ADDR})-(${LIB_REGEX_NET_IPV4_ADDR})"

#-------------------------------------------------------------------------------
#  NETWORK (IPv6)
#-------------------------------------------------------------------------------
# Adapted from: S. Ryan, https://community.helpsystems.com/forums/intermapper/miscellaneous-topics/5acc4fcf-fa83-e511-80cf-0050568460e4
readonly LIB_REGEX_NET_IPV6_ADDR="((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4}){0,1}:((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])(\.(25[0-5]|2[0-4][[0-9]]|1[[0-9]][[0-9]]|[1-9]{0,1}[[0-9]])){3}))|:)))(%.{1,}){0,1}"
readonly LIB_REGEX_NET_IPV6_CIDR="(${LIB_REGEX_NET_IPV6_ADDR})\/(12[0-8]|1[0-1][0-9]|[1-9][0-9]|[0-9])"

#-------------------------------------------------------------------------------
#  NETWORK (ICMP/TCP/UDP)
#-------------------------------------------------------------------------------
readonly LIB_REGEX_NET_ICMP_TYPE="[0-9]{1,2}|1[0-9]{2}|2[0-4][0-9]|25[0-5]|ping"

# Adapted from: A. Gusarov, http://regexlib.com/REDetails.aspx?regexp_id=4958
readonly LIB_REGEX_NET_TCPUDP_PORT="([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])"
readonly LIB_REGEX_NET_TCPUDP_PORT_RANGE="${LIB_REGEX_NET_TCPUDP_PORT}-${LIB_REGEX_NET_TCPUDP_PORT}"

#-------------------------------------------------------------------------------
#  NETWORK (SFTP/SSH)
#-------------------------------------------------------------------------------
# See also: https://datatracker.ietf.org/doc/html/draft-ietf-secsh-scp-sftp-ssh-uri-04

# Secure Shell (SSH) URI
readonly LIB_REGEX_NET_SSH_PARAMVALUE="((${LIB_REGEX_RFC2234_ALPHA}|${LIB_REGEX_RFC2234_DIGIT}|-)*)"
readonly LIB_REGEX_NET_SSH_PARAMNAME="${LIB_REGEX_NET_SSH_PARAMVALUE}"
readonly LIB_REGEX_NET_SSH_C_PARAM="(${LIB_REGEX_NET_SSH_PARAMNAME}=${LIB_REGEX_NET_SSH_PARAMVALUE})"
readonly LIB_REGEX_NET_SSH_USERINFO="${LIB_REGEX_RFC3986_USERINFO}"
readonly LIB_REGEX_NET_SSH_SSH_INFO="(${LIB_REGEX_NET_SSH_USERINFO}{0,1}(;${LIB_REGEX_NET_SSH_C_PARAM}(,${LIB_REGEX_NET_SSH_C_PARAM})*){0,1})"
readonly LIB_REGEX_NET_SSH_PATH_ABEMPTY="${LIB_REGEX_RFC3986_PATH_ABEMPTY}"
readonly LIB_REGEX_NET_SSH_PORT="${LIB_REGEX_RFC3986_PORT}"
readonly LIB_REGEX_NET_SSH_HOST="${LIB_REGEX_RFC3986_HOST}"
readonly LIB_REGEX_NET_SSH_AUTHORITY="((${LIB_REGEX_NET_SSH_SSH_INFO}{0,1}@){0,1}${LIB_REGEX_NET_SSH_HOST}(:${LIB_REGEX_NET_SSH_PORT}){0,1})"
readonly LIB_REGEX_NET_SSH_HIER_PART="(//${LIB_REGEX_NET_SSH_AUTHORITY}${LIB_REGEX_NET_SSH_PATH_ABEMPTY})"
readonly LIB_REGEX_NET_SSH_SSHURI="ssh:${LIB_REGEX_NET_SSH_HIER_PART}"

# Secure Shell (SSH) URI Short Version (user@hostname.fqdn)
readonly LIB_REGEX_NET_SSH_SSHURI_SHORT="${LIB_REGEX_NET_SSH_SSH_INFO}@${LIB_REGEX_NET_SSH_HOST}(:${LIB_REGEX_NET_SSH_PORT}){0,1}${LIB_REGEX_NET_SSH_PATH_ABEMPTY}"

# Secure File Transfer Protocol (SFTP) URI
readonly LIB_REGEX_NET_SFTP_PARAMVALUE="((${LIB_REGEX_RFC2234_ALPHA}|${LIB_REGEX_RFC2234_DIGIT}|-)*)"
readonly LIB_REGEX_NET_SFTP_PARAMNAME="${LIB_REGEX_NET_SFTP_PARAMVALUE}"
readonly LIB_REGEX_NET_SFTP_S_PARAM="(${LIB_REGEX_NET_SFTP_PARAMNAME}=${LIB_REGEX_NET_SFTP_PARAMVALUE})"
readonly LIB_REGEX_NET_SFTP_C_PARAM="${LIB_REGEX_NET_SFTP_S_PARAM}"
readonly LIB_REGEX_NET_SFTP_USERINFO="${LIB_REGEX_RFC3986_USERINFO}"
readonly LIB_REGEX_NET_SFTP_SSH_INFO="(${LIB_REGEX_NET_SFTP_USERINFO}{0,1}(;${LIB_REGEX_NET_SFTP_C_PARAM}(,${LIB_REGEX_NET_SFTP_C_PARAM})*){0,1})"
readonly LIB_REGEX_NET_SFTP_PORT="${LIB_REGEX_RFC3986_PORT}"
readonly LIB_REGEX_NET_SFTP_HOST="${LIB_REGEX_RFC3986_HOST}"
readonly LIB_REGEX_NET_SFTP_AUTHORITY="((${LIB_REGEX_NET_SFTP_SSH_INFO}@){0,1}${LIB_REGEX_NET_SFTP_HOST}(:${LIB_REGEX_NET_SFTP_PORT}){0,1})"
readonly LIB_REGEX_NET_SFTP_PATH_ABEMPTY="${LIB_REGEX_RFC3986_PATH_ABEMPTY}"
readonly LIB_REGEX_NET_SFTP_PATH="${LIB_REGEX_NET_SFTP_PATH_ABEMPTY}"
readonly LIB_REGEX_NET_SFTP_HIER_PART="(//${LIB_REGEX_NET_SFTP_AUTHORITY}${LIB_REGEX_NET_SFTP_PATH}(;${LIB_REGEX_NET_SFTP_S_PARAM}(,${LIB_REGEX_NET_SFTP_S_PARAM})*){0,1})"
readonly LIB_REGEX_NET_SFTP_SFTPURI="sftp:${LIB_REGEX_NET_SFTP_HIER_PART}"

# Secure File Transfer Protocol (SFTP) URI Short Version (user@hostname.fqdn)
readonly LIB_REGEX_NET_SFTP_SFTPURI_SHORT="${LIB_REGEX_NET_SFTP_SSH_INFO}@${LIB_REGEX_NET_SFTP_HOST}(:${LIB_REGEX_NET_SFTP_PORT}){0,1}${LIB_REGEX_NET_SFTP_PATH}(;${LIB_REGEX_NET_SFTP_S_PARAM}(,${LIB_REGEX_NET_SFTP_S_PARAM})*){0,1}"

#-------------------------------------------------------------------------------
#  NETWORK (OTHER)
#-------------------------------------------------------------------------------
# Email address
readonly LIB_REGEX_NET_EMAIL_ADDRESS="[A-Za-z0-9_%+-]+(\.[A-Za-z0-9_%+-]+)*@${LIB_REGEX_NET_DNS_FQDN}"

# Host address (FQDN/IPv4/IPv6)
readonly LIB_REGEX_NET_HOST="${LIB_REGEX_NET_DNS_FQDN}|${LIB_REGEX_NET_IPV4_ADDR}|${LIB_REGEX_NET_IPV6_ADDR}"

# MAC address
# Adapted from: T. Rudyk, http://regexlib.com/REDetails.aspx?regexp_id=154
readonly LIB_REGEX_NET_MAC="([0-9A-Fa-f][0-9A-Fa-f]:){5}([0-9A-Fa-f][0-9A-Fa-f])"

#-------------------------------------------------------------------------------
#  DATA TYPES
#-------------------------------------------------------------------------------
readonly LIB_REGEX_TYPE_BOOLEAN="true|false"

# Adapted from: J. Goyvaerts, S. Levithan, https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch06s10.html
readonly LIB_REGEX_TYPE_FLOAT="([-+]?[0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)"
readonly LIB_REGEX_TYPE_FLOAT_NEG="([-][0-9]*\.[0-9]*[1-9]([eE][-+]?[0-9]+)?)"
readonly LIB_REGEX_TYPE_FLOAT_NEG0="([-][0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)"
readonly LIB_REGEX_TYPE_FLOAT_POS="([+]?[0-9]*\.[0-9]*[1-9]([eE][-+]?[0-9]+)?)"
readonly LIB_REGEX_TYPE_FLOAT_POS0="([+]?[0-9]*\.[0-9]+([eE][-+]?[0-9]+)?)"

readonly LIB_REGEX_TYPE_GUID="((\{)?([0-9A-Fa-f]{32}|[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})(\})?)"
readonly LIB_REGEX_TYPE_HEX="[0-9A-Fa-f]+"
readonly LIB_REGEX_TYPE_INTEGER="([-+]?(0|[1-9][0-9]*))"
readonly LIB_REGEX_TYPE_INTEGER_NEG="([-][1-9][0-9]*)"
readonly LIB_REGEX_TYPE_INTEGER_NEG0="(([-+]?0)|${LIB_REGEX_TYPE_INTEGER_NEG})"
readonly LIB_REGEX_TYPE_INTEGER_POS="([+]?[1-9][0-9]*)"
readonly LIB_REGEX_TYPE_INTEGER_POS0="(([-+]?0)|${LIB_REGEX_TYPE_INTEGER_POS})"
readonly LIB_REGEX_TYPE_NUM_DEC="${LIB_REGEX_TYPE_INTEGER}|${LIB_REGEX_TYPE_FLOAT}"
readonly LIB_REGEX_TYPE_NUM_DEC_NEG="${LIB_REGEX_TYPE_INTEGER_NEG}|${LIB_REGEX_TYPE_FLOAT_NEG}"
readonly LIB_REGEX_TYPE_NUM_DEC_NEG0="${LIB_REGEX_TYPE_INTEGER_NEG0}|${LIB_REGEX_TYPE_FLOAT_NEG0}"
readonly LIB_REGEX_TYPE_NUM_DEC_POS="${LIB_REGEX_TYPE_INTEGER_POS}|${LIB_REGEX_TYPE_FLOAT_POS}"
readonly LIB_REGEX_TYPE_NUM_DEC_POS0="${LIB_REGEX_TYPE_INTEGER_POS0}|${LIB_REGEX_TYPE_FLOAT_POS0}"
readonly LIB_REGEX_TYPE_OID="[0-2]((\.0)|(\.[1-9][0-9]*))*" # Adapted from: https://regexr.com/38m0v
readonly LIB_REGEX_TYPE_UUID="([0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12})"
readonly LIB_REGEX_TYPE_YESNO="yes|no"

readonly LIB_REGEX_TYPE_YY_DE="J|j"
readonly LIB_REGEX_TYPE_YY_EN="Y|y"
readonly LIB_REGEX_TYPE_NN_DE="N|n"
readonly LIB_REGEX_TYPE_NN_EN="N|n"

#-------------------------------------------------------------------------------
#  CUPS
#-------------------------------------------------------------------------------
readonly LIB_REGEX_CUPS_HOSTPORT="((${LIB_REGEX_NET_IPV4_ADDR}|${LIB_REGEX_NET_DNS_FQDN_SEG}|${LIB_REGEX_NET_DNS_FQDN})(:${LIB_REGEX_NET_TCPUDP_PORT}){0,1})"
readonly LIB_REGEX_CUPS_QUEUE="([A-Za-z0-9_%-]{1,})"

# See also: https://www.cups.org/doc/network.html
readonly LIB_REGEX_CUPS_DEVURI_DNSSD_ADDR="([A-Za-z0-9]([A-Za-z0-9_%-]{0,61}[A-Za-z0-9]){0,1}\._(ipp|ipps|pdl-datastream|printer)\._tcp\.(local|${LIB_REGEX_NET_DNS_FQDN}))"
readonly LIB_REGEX_CUPS_DEVURI_DNSSD="(dnssd:\/\/${LIB_REGEX_CUPS_DEVURI_DNSSD_ADDR}\/(cups){0,1}\?uuid\=${LIB_REGEX_TYPE_UUID})"

# See also: https://www.cups.org/doc/network.html#IPP
readonly LIB_REGEX_CUPS_DEVURI_IPP_OPTS="((contimeout\=[0-9]{1,})|(encryption\=(always|ifrequested|never|required))|(version\=(1\.0|1\.1|2\.1))|(waitjob\=false)|(waitprinter\=false))"
readonly LIB_REGEX_CUPS_DEVURI_IPP_PATH="((ipp\/print)|(printers\/${LIB_REGEX_CUPS_QUEUE}(\/.printer){0,1}))"
readonly LIB_REGEX_CUPS_DEVURI_IPP_PROTO="(http|ipp|ipps)"
readonly LIB_REGEX_CUPS_DEVURI_IPP_IPP="(${LIB_REGEX_CUPS_DEVURI_IPP_PROTO}:\/\/${LIB_REGEX_CUPS_HOSTPORT}\/${LIB_REGEX_CUPS_DEVURI_IPP_PATH}(\?${LIB_REGEX_CUPS_DEVURI_IPP_OPTS}(\&${LIB_REGEX_CUPS_DEVURI_IPP_OPTS})*){0,1})"

# See also: https://wiki.debian.org/CUPSPrintQueues#The_device-uri_for_a_Networked_Printer
readonly LIB_REGEX_CUPS_DEVURI_IPP_DNSSD="(${LIB_REGEX_CUPS_DEVURI_IPP_PROTO}:\/\/${LIB_REGEX_CUPS_DEVURI_DNSSD_ADDR}\/)"

# See also: https://www.cups.org/doc/network.html#TABLE3
#           https://opensource.apple.com/source/cups/cups-136/cups/doc/help/network.html#TABLE3
readonly LIB_REGEX_CUPS_DEVURI_LPD_OPTS="((banner\=on)|(contimeout\=[0-9]{1,})|(format\=(c|d|f|g|l|n|o|p|r|t|v))|(mode\=stream)|(order\=data\,control)|(reserve\=(none|rfc1179))|(sanitize_title\=(no|yes))|(timeout\=[0-9]{1,}))"
readonly LIB_REGEX_CUPS_DEVURI_LPD="(lpd:\/\/${LIB_REGEX_CUPS_HOSTPORT}\/${LIB_REGEX_CUPS_QUEUE}(\?${LIB_REGEX_CUPS_DEVURI_LPD_OPTS}(\&${LIB_REGEX_CUPS_DEVURI_LPD_OPTS})*){0,1})"

# See also: https://opensource.apple.com/source/cups/cups-86/doc/sdd.shtml
readonly LIB_REGEX_CUPS_DEVURI_PARALLEL="(parallel:\/dev(\/[A-Za-z0-9_-]{1,}){1,})"

# See also: https://opensource.apple.com/source/cups/cups-86/doc/sdd.shtml
#           https://www.cups.org/doc/spec-ipp.html
readonly LIB_REGEX_CUPS_DEVURI_SERIAL_OPTS="((baud\=[0-9]{1,})|(bits\=(7|8))|(parity\=(even|odd|none))|(flow\=(dtrdsr|hard|none|rtscts|xonxoff)))"
readonly LIB_REGEX_CUPS_DEVURI_SERIAL="(serial:\/dev(\/[A-Za-z0-9_-]{1,}){1,}\?${LIB_REGEX_CUPS_DEVURI_SERIAL_OPTS}(\+${LIB_REGEX_CUPS_DEVURI_SERIAL_OPTS})*)"

# See also: https://www.cups.org/doc/network.html
readonly LIB_REGEX_CUPS_DEVURI_SOCKET_OPTS="((contimeout\=[0-9]{1,})|(waiteof\=(true|false)))"
readonly LIB_REGEX_CUPS_DEVURI_SOCKET="(socket:\/\/${LIB_REGEX_CUPS_HOSTPORT}(\/\?${LIB_REGEX_CUPS_DEVURI_SOCKET_OPTS}(\&${LIB_REGEX_CUPS_DEVURI_SOCKET_OPTS})*){0,1})"

# See also: https://wiki.debian.org/CUPSPrintQueues#deviceuri
readonly LIB_REGEX_CUPS_DEVURI_USB_OPTS="([A-Za-z0-9_]{1,}\=[A-Za-z0-9_]{1,})"
readonly LIB_REGEX_CUPS_DEVURI_USB="(usb:\/\/[A-Za-z0-9]{1,}(\/${LIB_REGEX_CUPS_QUEUE}){1,}(\?${LIB_REGEX_CUPS_DEVURI_USB_OPTS}(\&${LIB_REGEX_CUPS_DEVURI_USB_OPTS})*){0,1})"

readonly LIB_REGEX_CUPS_DEVURI="${LIB_REGEX_CUPS_DEVURI_DNSSD}|${LIB_REGEX_CUPS_DEVURI_IPP_IPP}|${LIB_REGEX_CUPS_DEVURI_IPP_DNSSD}|${LIB_REGEX_CUPS_DEVURI_LPD}|${LIB_REGEX_CUPS_DEVURI_PARALLEL}|${LIB_REGEX_CUPS_DEVURI_SERIAL}|${LIB_REGEX_CUPS_DEVURI_SOCKET}|${LIB_REGEX_CUPS_DEVURI_USB}"

#-------------------------------------------------------------------------------
#  IPSET
#-------------------------------------------------------------------------------
readonly LIB_REGEX_IPSET_IPADDR_4="(${LIB_REGEX_NET_IPV4_ADDR})|(${LIB_REGEX_NET_IPV4_CIDR})|(${LIB_REGEX_NET_IPV4_RANGE})"
readonly LIB_REGEX_IPSET_IPADDR_6="(${LIB_REGEX_NET_IPV6_ADDR})|(${LIB_REGEX_NET_IPV6_CIDR})"
readonly LIB_REGEX_IPSET_PORT_BITMAP="(${LIB_REGEX_NET_TCPUDP_PORT}(-${LIB_REGEX_NET_TCPUDP_PORT}){0,1})"
readonly LIB_REGEX_IPSET_PORT_HASH_4_6="((tcp|sctp|udp|udplite|tcpudp):${LIB_REGEX_IPSET_PORT_BITMAP})"
readonly LIB_REGEX_IPSET_PORT_HASH_4="${LIB_REGEX_IPSET_PORT_HASH_4_6}|(icmp:${LIB_REGEX_NET_ICMP_TYPE})"
readonly LIB_REGEX_IPSET_PORT_HASH_6="${LIB_REGEX_IPSET_PORT_HASH_4_6}|(icmpv6:${LIB_REGEX_NET_ICMP_TYPE})"
readonly LIB_REGEX_IPSET_SETNAME="[A-Za-z0-9]([A-Za-z0-9_]{0,1}[A-Za-z0-9])*"

#-------------------------------------------------------------------------------
#  LUKS2
#-------------------------------------------------------------------------------
# See also: https://man7.org/linux/man-pages/man1/systemd-cryptenroll.1.html
readonly LIB_REGEX_LUKS2_TPM2_PCRS="(1?[0-9]|2[0-3])(\+(1?[0-9]|2[0-3]))*"

#-------------------------------------------------------------------------------
#  OpenSC
#-------------------------------------------------------------------------------
# See also 'man pkcs15-init' ('--profile')
readonly LIB_REGEX_OPENSC_P15_PROFILE="[A-Za-z_0-9]+(\+[A-Za-z_0-9]+)*"

#-------------------------------------------------------------------------------
#  POSIX
#-------------------------------------------------------------------------------
# See also: https://www.ibm.com/docs/en/zos/2.1.0?topic=locales-posix-portable-file-name-character-set
readonly LIB_REGEX_POSIX_FILENAME="[A-Za-z0-9._-]+"

# See also: https://stackoverflow.com/a/2821183
readonly LIB_REGEX_POSIX_NAME="[A-Za-z_][A-Za-z_0-9]*"

#===============================================================================
#  FUNCTIONS
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_regex
#  DESCRIPTION:  Check if a given string matches a regular expression
# PARAMETER  1:  Regex pattern selector (see switch-case statement below)
#            2:  String to check
#   RETURNS  0:  String matches regular expression
#            1:  String does not match regular expression
#===============================================================================
lib_regex() {
  local arg_option="$1"
  local arg_str="$2"

  #-----------------------------------------------------------------------------
  #  SELECT REGEX
  #-----------------------------------------------------------------------------
  local regex=""
  case "${arg_option}" in
    --bool|--boolean)     regex="${LIB_REGEX_TYPE_BOOLEAN}"              ;;
    --cups-devuri)        regex="${LIB_REGEX_CUPS_DEVURI}"               ;;
    --cups-queue)         regex="${LIB_REGEX_CUPS_QUEUE}"                ;;
    --dns-srv)            regex="${LIB_REGEX_NET_DNS_SRV}"               ;;
    --email-address|--upn)  regex="${LIB_REGEX_NET_EMAIL_ADDRESS}"       ;;
    --float)              regex="${LIB_REGEX_TYPE_FLOAT}"                ;;
    --float-neg)          regex="${LIB_REGEX_TYPE_FLOAT_NEG}"            ;;
    --float-neg0)         regex="${LIB_REGEX_TYPE_FLOAT_NEG0}"           ;;
    --float-pos)          regex="${LIB_REGEX_TYPE_FLOAT_POS}"            ;;
    --float-pos0)         regex="${LIB_REGEX_TYPE_FLOAT_POS0}"           ;;
    --fqdn)               regex="${LIB_REGEX_NET_DNS_FQDN}"              ;;
    --fqdn-or-wildcard)   regex="${LIB_REGEX_NET_DNS_FQDN_OR_WILDCARD}"  ;;
    --fqdn-wildcard)      regex="${LIB_REGEX_NET_DNS_FQDN_WILDCARD}"     ;;
    --guid)               regex="${LIB_REGEX_TYPE_GUID}"                 ;;
    --hex)                regex="${LIB_REGEX_TYPE_HEX}"                  ;;
    --host)               regex="${LIB_REGEX_NET_HOST}"                  ;;
    --hostname)           regex="${LIB_REGEX_NET_DNS_FQDN_SEG}"          ;;
    --icmp)               regex="${LIB_REGEX_NET_ICMP_TYPE}"             ;;
    --int|--integer)      regex="${LIB_REGEX_TYPE_INTEGER}"              ;;
    --int-neg)            regex="${LIB_REGEX_TYPE_INTEGER_NEG}"          ;;
    --int-neg0)           regex="${LIB_REGEX_TYPE_INTEGER_NEG0}"         ;;
    --int-pos)            regex="${LIB_REGEX_TYPE_INTEGER_POS}"          ;;
    --int-pos0)           regex="${LIB_REGEX_TYPE_INTEGER_POS0}"         ;;
    --ip4|--ipv4|--inet)  regex="${LIB_REGEX_NET_IPV4_ADDR}"             ;;
    --ip4-cidr)           regex="${LIB_REGEX_NET_IPV4_CIDR}"             ;;
    --ip4-range)          regex="${LIB_REGEX_NET_IPV4_RANGE}"            ;;
    --ip6|--ipv6|--inet6) regex="${LIB_REGEX_NET_IPV6_ADDR}"             ;;
    --ip6-cidr)           regex="${LIB_REGEX_NET_IPV6_CIDR}"             ;;
    --ipset-ip4)          regex="${LIB_REGEX_IPSET_IPADDR_4}"            ;;
    --ipset-ip6)          regex="${LIB_REGEX_IPSET_IPADDR_6}"            ;;
    --ipset-setname)      regex="${LIB_REGEX_IPSET_SETNAME}"             ;;
    --ipset-port-bitmap)  regex="${LIB_REGEX_IPSET_PORT_BITMAP}"         ;;
    --ipset-port-hash4)   regex="${LIB_REGEX_IPSET_PORT_HASH_4}"         ;;
    --ipset-port-hash6)   regex="${LIB_REGEX_IPSET_PORT_HASH_6}"         ;;
    --luks2-tpm2-pcrs)    regex="${LIB_REGEX_LUKS2_TPM2_PCRS}"           ;;
    --mac)                regex="${LIB_REGEX_NET_MAC}"                   ;;
    --num|--number)       regex="${LIB_REGEX_TYPE_NUM_DEC}"              ;;
    --num-neg)            regex="${LIB_REGEX_TYPE_NUM_DEC_NEG}"          ;;
    --num-neg0)           regex="${LIB_REGEX_TYPE_NUM_DEC_NEG0}"         ;;
    --num-pos)            regex="${LIB_REGEX_TYPE_NUM_DEC_POS}"          ;;
    --num-pos0)           regex="${LIB_REGEX_TYPE_NUM_DEC_POS0}"         ;;
    --oid)                regex="${LIB_REGEX_TYPE_OID}"                  ;;
    --opensc-p15-profile) regex="${LIB_REGEX_OPENSC_P15_PROFILE}"        ;;
    --posix-name|--funcname|--varname) regex="${LIB_REGEX_POSIX_NAME}"   ;;
    --sftp-uri)           regex="${LIB_REGEX_NET_SFTP_SFTPURI}"          ;;
    --sftp-uri-short)     regex="${LIB_REGEX_NET_SFTP_SFTPURI_SHORT}"    ;;
    --ssh-uri)            regex="${LIB_REGEX_NET_SSH_SSHURI}"            ;;
    --ssh-uri-short)      regex="${LIB_REGEX_NET_SSH_SSHURI_SHORT}"      ;;
    --tcpudp|--port)      regex="${LIB_REGEX_NET_TCPUDP_PORT}"           ;;
    --tcpudp-range|--portrange) regex="${LIB_REGEX_NET_TCPUDP_PORT_RANGE}"  ;;
    --uri|--rfc3986)      regex="${LIB_REGEX_RFC3986_URI}"               ;;
    --uuid)               regex="${LIB_REGEX_TYPE_UUID}"                 ;;
    --yesno)              regex="${LIB_REGEX_TYPE_YESNO}"                ;;
    --Yy-${LIB_C_ID_L_DE}) regex="${LIB_REGEX_TYPE_YY_DE}"               ;;
    --Yy-${LIB_C_ID_L_EN}) regex="${LIB_REGEX_TYPE_YY_EN}"               ;;
    --Nn-${LIB_C_ID_L_DE}) regex="${LIB_REGEX_TYPE_NN_DE}"               ;;
    --Nn-${LIB_C_ID_L_EN}) regex="${LIB_REGEX_TYPE_NN_EN}"               ;;
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
#         NAME:  lib_regex_loaded
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_regex_loaded() {
  return 0
}