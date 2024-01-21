#!/bin/sh
#
# SPDX-FileCopyrightText: 2020-2024 Florian Kemser and the SHlib contributors
# SPDX-License-Identifier: LGPL-3.0-or-later
#
#===============================================================================
#
#         FILE:   /lib/c.lib.sh
#
#        USAGE:   . c.lib.sh
#
#  DESCRIPTION:   Shell library containing constants used by other library
#                 files and shell projects
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
#         TODO:   See 'TODO:'-tagged lines below.
#===============================================================================

#===============================================================================
#  CHECK IF ALREADY LOADED
#===============================================================================
if lib_c 2>/dev/null; then return; fi

#===============================================================================
#  IDs & SPECIAL STRINGS
#===============================================================================
#-------------------------------------------------------------------------------
#  Distribution Identifier Strings (see <lib_os_get --id>)
#-------------------------------------------------------------------------------
readonly LIB_C_ID_DIST_ALPINE="alpine"     # Alpine
readonly LIB_C_ID_DIST_OPENWRT="openwrt"   # OpenWRT
readonly LIB_C_ID_DIST_RASPBIAN="raspbian" # Raspbian OS
readonly LIB_C_ID_DIST_UBUNTU="ubuntu"     # Ubuntu

#-------------------------------------------------------------------------------
#  Language IDs (ISO 639-1 two-letter)
#-------------------------------------------------------------------------------
readonly LIB_C_ID_L_AA="AA" # Afar
readonly LIB_C_ID_L_AB="AB" # Abkhazian
readonly LIB_C_ID_L_AE="AE" # Avestan
readonly LIB_C_ID_L_AF="AF" # Afrikaans
readonly LIB_C_ID_L_AK="AK" # Akan
readonly LIB_C_ID_L_AM="AM" # Amharic
readonly LIB_C_ID_L_AN="AN" # Aragonese
readonly LIB_C_ID_L_AR="AR" # Arabic
readonly LIB_C_ID_L_AS="AS" # Assamese
readonly LIB_C_ID_L_AV="AV" # Avaric
readonly LIB_C_ID_L_AY="AY" # Aymara
readonly LIB_C_ID_L_AZ="AZ" # Azerbaijani
readonly LIB_C_ID_L_BA="BA" # Bashkir
readonly LIB_C_ID_L_BE="BE" # Belarusian
readonly LIB_C_ID_L_BG="BG" # Bulgarian
readonly LIB_C_ID_L_BH="BH" # Bihari languages
readonly LIB_C_ID_L_BI="BI" # Bislama
readonly LIB_C_ID_L_BM="BM" # Bambara
readonly LIB_C_ID_L_BN="BN" # Bengali
readonly LIB_C_ID_L_BO="BO" # Tibetan
readonly LIB_C_ID_L_BR="BR" # Breton
readonly LIB_C_ID_L_BS="BS" # Bosnian
readonly LIB_C_ID_L_CA="CA" # Catalan; Valencian
readonly LIB_C_ID_L_CE="CE" # Chechen
readonly LIB_C_ID_L_CH="CH" # Chamorro
readonly LIB_C_ID_L_CO="CO" # Corsican
readonly LIB_C_ID_L_CR="CR" # Cree
readonly LIB_C_ID_L_CS="CS" # Czech
readonly LIB_C_ID_L_CU="CU" # Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic
readonly LIB_C_ID_L_CV="CV" # Chuvash
readonly LIB_C_ID_L_CY="CY" # Welsh
readonly LIB_C_ID_L_DA="DA" # Danish
readonly LIB_C_ID_L_DE="DE" # German
readonly LIB_C_ID_L_DV="DV" # Divehi; Dhivehi; Maldivian
readonly LIB_C_ID_L_DZ="DZ" # Dzongkha
readonly LIB_C_ID_L_EE="EE" # Ewe
readonly LIB_C_ID_L_EL="EL" # Greek,  Modern (1453-)"
readonly LIB_C_ID_L_EN="EN" # English
readonly LIB_C_ID_L_EO="EO" # Esperanto
readonly LIB_C_ID_L_ES="ES" # Spanish; Castilian
readonly LIB_C_ID_L_ET="ET" # Estonian
readonly LIB_C_ID_L_EU="EU" # Basque
readonly LIB_C_ID_L_FA="FA" # Persian
readonly LIB_C_ID_L_FF="FF" # Fulah
readonly LIB_C_ID_L_FI="FI" # Finnish
readonly LIB_C_ID_L_FJ="FJ" # Fijian
readonly LIB_C_ID_L_FO="FO" # Faroese
readonly LIB_C_ID_L_FR="FR" # French
readonly LIB_C_ID_L_FY="FY" # Western Frisian
readonly LIB_C_ID_L_GA="GA" # Irish
readonly LIB_C_ID_L_GD="GD" # Gaelic; Scottish Gaelic
readonly LIB_C_ID_L_GL="GL" # Galician
readonly LIB_C_ID_L_GN="GN" # Guarani
readonly LIB_C_ID_L_GU="GU" # Gujarati
readonly LIB_C_ID_L_GV="GV" # Manx
readonly LIB_C_ID_L_HA="HA" # Hausa
readonly LIB_C_ID_L_HE="HE" # Hebrew
readonly LIB_C_ID_L_HI="HI" # Hindi
readonly LIB_C_ID_L_HO="HO" # Hiri Motu
readonly LIB_C_ID_L_HR="HR" # Croatian
readonly LIB_C_ID_L_HT="HT" # Haitian; Haitian Creole
readonly LIB_C_ID_L_HU="HU" # Hungarian
readonly LIB_C_ID_L_HY="HY" # Armenian
readonly LIB_C_ID_L_HZ="HZ" # Herero
readonly LIB_C_ID_L_IA="IA" # Interlingua (International Auxiliary Language Association)
readonly LIB_C_ID_L_ID="ID" # Indonesian
readonly LIB_C_ID_L_IE="IE" # Interlingue; Occidental
readonly LIB_C_ID_L_IG="IG" # Igbo
readonly LIB_C_ID_L_II="II" # Sichuan Yi; Nuosu
readonly LIB_C_ID_L_IK="IK" # Inupiaq
readonly LIB_C_ID_L_IO="IO" # Ido
readonly LIB_C_ID_L_IS="IS" # Icelandic
readonly LIB_C_ID_L_IT="IT" # Italian
readonly LIB_C_ID_L_IU="IU" # Inuktitut
readonly LIB_C_ID_L_JA="JA" # Japanese
readonly LIB_C_ID_L_JV="JV" # Javanese
readonly LIB_C_ID_L_KA="KA" # Georgian
readonly LIB_C_ID_L_KG="KG" # Kongo
readonly LIB_C_ID_L_KI="KI" # Kikuyu; Gikuyu
readonly LIB_C_ID_L_KJ="KJ" # Kuanyama; Kwanyama
readonly LIB_C_ID_L_KK="KK" # Kazakh
readonly LIB_C_ID_L_KL="KL" # Kalaallisut; Greenlandic
readonly LIB_C_ID_L_KM="KM" # Central Khmer
readonly LIB_C_ID_L_KN="KN" # Kannada
readonly LIB_C_ID_L_KO="KO" # Korean
readonly LIB_C_ID_L_KR="KR" # Kanuri
readonly LIB_C_ID_L_KS="KS" # Kashmiri
readonly LIB_C_ID_L_KU="KU" # Kurdish
readonly LIB_C_ID_L_KV="KV" # Komi
readonly LIB_C_ID_L_KW="KW" # Cornish
readonly LIB_C_ID_L_KY="KY" # Kirghiz; Kyrgyz
readonly LIB_C_ID_L_LA="LA" # Latin
readonly LIB_C_ID_L_LB="LB" # Luxembourgish; Letzeburgesch
readonly LIB_C_ID_L_LG="LG" # Ganda
readonly LIB_C_ID_L_LI="LI" # Limburgan; Limburger; Limburgish
readonly LIB_C_ID_L_LN="LN" # Lingala
readonly LIB_C_ID_L_LO="LO" # Lao
readonly LIB_C_ID_L_LT="LT" # Lithuanian
readonly LIB_C_ID_L_LU="LU" # Luba-Katanga
readonly LIB_C_ID_L_LV="LV" # Latvian
readonly LIB_C_ID_L_MG="MG" # Malagasy
readonly LIB_C_ID_L_MH="MH" # Marshallese
readonly LIB_C_ID_L_MI="MI" # Maori
readonly LIB_C_ID_L_MK="MK" # Macedonian
readonly LIB_C_ID_L_ML="ML" # Malayalam
readonly LIB_C_ID_L_MN="MN" # Mongolian
readonly LIB_C_ID_L_MR="MR" # Marathi
readonly LIB_C_ID_L_MS="MS" # Malay
readonly LIB_C_ID_L_MT="MT" # Maltese
readonly LIB_C_ID_L_MY="MY" # Burmese
readonly LIB_C_ID_L_NA="NA" # Nauru
readonly LIB_C_ID_L_NB="NB" # Bokmål, Norwegian; Norwegian Bokmål
readonly LIB_C_ID_L_ND="ND" # Ndebele, North; North Ndebele
readonly LIB_C_ID_L_NE="NE" # Nepali
readonly LIB_C_ID_L_NG="NG" # Ndonga
readonly LIB_C_ID_L_NL="NL" # Dutch; Flemish
readonly LIB_C_ID_L_NN="NN" # Norwegian Nynorsk; Nynorsk, Norwegian
readonly LIB_C_ID_L_NO="NO" # Norwegian
readonly LIB_C_ID_L_NR="NR" # Ndebele, South; South Ndebele
readonly LIB_C_ID_L_NV="NV" # Navajo; Navaho
readonly LIB_C_ID_L_NY="NY" # Chichewa; Chewa; Nyanja
readonly LIB_C_ID_L_OC="OC" # Occitan (post 1500)
readonly LIB_C_ID_L_OJ="OJ" # Ojibwa
readonly LIB_C_ID_L_OM="OM" # Oromo
readonly LIB_C_ID_L_OR="OR" # Oriya
readonly LIB_C_ID_L_OS="OS" # Ossetian; Ossetic
readonly LIB_C_ID_L_PA="PA" # Panjabi; Punjabi
readonly LIB_C_ID_L_PI="PI" # Pali
readonly LIB_C_ID_L_PL="PL" # Polish
readonly LIB_C_ID_L_PS="PS" # Pushto; Pashto
readonly LIB_C_ID_L_PT="PT" # Portuguese
readonly LIB_C_ID_L_QU="QU" # Quechua
readonly LIB_C_ID_L_RM="RM" # Romansh
readonly LIB_C_ID_L_RN="RN" # Rundi
readonly LIB_C_ID_L_RO="RO" # Romanian; Moldavian; Moldovan
readonly LIB_C_ID_L_RU="RU" # Russian
readonly LIB_C_ID_L_RW="RW" # Kinyarwanda
readonly LIB_C_ID_L_SA="SA" # Sanskrit
readonly LIB_C_ID_L_SC="SC" # Sardinian
readonly LIB_C_ID_L_SD="SD" # Sindhi
readonly LIB_C_ID_L_SE="SE" # Northern Sami
readonly LIB_C_ID_L_SG="SG" # Sango
readonly LIB_C_ID_L_SI="SI" # Sinhala; Sinhalese
readonly LIB_C_ID_L_SK="SK" # Slovak
readonly LIB_C_ID_L_SL="SL" # Slovenian
readonly LIB_C_ID_L_SM="SM" # Samoan
readonly LIB_C_ID_L_SN="SN" # Shona
readonly LIB_C_ID_L_SO="SO" # Somali
readonly LIB_C_ID_L_SQ="SQ" # Albanian
readonly LIB_C_ID_L_SR="SR" # Serbian
readonly LIB_C_ID_L_SS="SS" # Swati
readonly LIB_C_ID_L_ST="ST" # Sotho, Southern
readonly LIB_C_ID_L_SU="SU" # Sundanese
readonly LIB_C_ID_L_SV="SV" # Swedish
readonly LIB_C_ID_L_SW="SW" # Swahili
readonly LIB_C_ID_L_TA="TA" # Tamil
readonly LIB_C_ID_L_TE="TE" # Telugu
readonly LIB_C_ID_L_TG="TG" # Tajik
readonly LIB_C_ID_L_TH="TH" # Thai
readonly LIB_C_ID_L_TI="TI" # Tigrinya
readonly LIB_C_ID_L_TK="TK" # Turkmen
readonly LIB_C_ID_L_TL="TL" # Tagalog
readonly LIB_C_ID_L_TN="TN" # Tswana
readonly LIB_C_ID_L_TO="TO" # Tonga (Tonga Islands)
readonly LIB_C_ID_L_TR="TR" # Turkish
readonly LIB_C_ID_L_TS="TS" # Tsonga
readonly LIB_C_ID_L_TT="TT" # Tatar
readonly LIB_C_ID_L_TW="TW" # Twi
readonly LIB_C_ID_L_TY="TY" # Tahitian
readonly LIB_C_ID_L_UG="UG" # Uighur; Uyghur
readonly LIB_C_ID_L_UK="UK" # Ukrainian
readonly LIB_C_ID_L_UR="UR" # Urdu
readonly LIB_C_ID_L_UZ="UZ" # Uzbek
readonly LIB_C_ID_L_VE="VE" # Venda
readonly LIB_C_ID_L_VI="VI" # Vietnamese
readonly LIB_C_ID_L_VO="VO" # Volapük
readonly LIB_C_ID_L_WA="WA" # Walloon
readonly LIB_C_ID_L_WO="WO" # Wolof
readonly LIB_C_ID_L_XH="XH" # Xhosa
readonly LIB_C_ID_L_YI="YI" # Yiddish
readonly LIB_C_ID_L_YO="YO" # Yoruba
readonly LIB_C_ID_L_ZA="ZA" # Zhuang; Chuang
readonly LIB_C_ID_L_ZH="ZH" # Chinese
readonly LIB_C_ID_L_ZU="ZU" # Zulu

#-------------------------------------------------------------------------------
#  Language ID patterns (see <lib_os_get --lang>)
#-------------------------------------------------------------------------------
readonly LIB_C_ID_LANG_AA="aa_*" # Afar
readonly LIB_C_ID_LANG_AB="ab_*" # Abkhazian
readonly LIB_C_ID_LANG_AE="ae_*" # Avestan
readonly LIB_C_ID_LANG_AF="af_*" # Afrikaans
readonly LIB_C_ID_LANG_AK="ak_*" # Akan
readonly LIB_C_ID_LANG_AM="am_*" # Amharic
readonly LIB_C_ID_LANG_AN="an_*" # Aragonese
readonly LIB_C_ID_LANG_AR="ar_*" # Arabic
readonly LIB_C_ID_LANG_AS="as_*" # Assamese
readonly LIB_C_ID_LANG_AV="av_*" # Avaric
readonly LIB_C_ID_LANG_AY="ay_*" # Aymara
readonly LIB_C_ID_LANG_AZ="az_*" # Azerbaijani
readonly LIB_C_ID_LANG_BA="ba_*" # Bashkir
readonly LIB_C_ID_LANG_BE="be_*" # Belarusian
readonly LIB_C_ID_LANG_BG="bg_*" # Bulgarian
readonly LIB_C_ID_LANG_BH="bh_*" # Bihari languages
readonly LIB_C_ID_LANG_BI="bi_*" # Bislama
readonly LIB_C_ID_LANG_BM="bm_*" # Bambara
readonly LIB_C_ID_LANG_BN="bn_*" # Bengali
readonly LIB_C_ID_LANG_BO="bo_*" # Tibetan
readonly LIB_C_ID_LANG_BR="br_*" # Breton
readonly LIB_C_ID_LANG_BS="bs_*" # Bosnian
readonly LIB_C_ID_LANG_CA="ca_*" # Catalan   Valencian
readonly LIB_C_ID_LANG_CE="ce_*" # Chechen
readonly LIB_C_ID_LANG_CH="ch_*" # Chamorro
readonly LIB_C_ID_LANG_CO="co_*" # Corsican
readonly LIB_C_ID_LANG_CR="cr_*" # Cree
readonly LIB_C_ID_LANG_CS="cs_*" # Czech
readonly LIB_C_ID_LANG_CU="cu_*" # Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic
readonly LIB_C_ID_LANG_CV="cv_*" # Chuvash
readonly LIB_C_ID_LANG_CY="cy_*" # Welsh
readonly LIB_C_ID_LANG_DA="da_*" # Danish
readonly LIB_C_ID_LANG_DE="de_*" # German
readonly LIB_C_ID_LANG_DV="dv_*" # Divehi; Dhivehi; Maldivian
readonly LIB_C_ID_LANG_DZ="dz_*" # Dzongkha
readonly LIB_C_ID_LANG_EE="ee_*" # Ewe
readonly LIB_C_ID_LANG_EL="el_*" # Greek,  Modern (1453-)"
readonly LIB_C_ID_LANG_EN="en_*" # English
readonly LIB_C_ID_LANG_EO="eo_*" # Esperanto
readonly LIB_C_ID_LANG_ES="es_*" # Spanish; Castilian
readonly LIB_C_ID_LANG_ET="et_*" # Estonian
readonly LIB_C_ID_LANG_EU="eu_*" # Basque
readonly LIB_C_ID_LANG_FA="fa_*" # Persian
readonly LIB_C_ID_LANG_FF="ff_*" # Fulah
readonly LIB_C_ID_LANG_FI="fi_*" # Finnish
readonly LIB_C_ID_LANG_FJ="fj_*" # Fijian
readonly LIB_C_ID_LANG_FO="fo_*" # Faroese
readonly LIB_C_ID_LANG_FR="fr_*" # French
readonly LIB_C_ID_LANG_FY="fy_*" # Western Frisian
readonly LIB_C_ID_LANG_GA="ga_*" # Irish
readonly LIB_C_ID_LANG_GD="gd_*" # Gaelic; Scottish Gaelic
readonly LIB_C_ID_LANG_GL="gl_*" # Galician
readonly LIB_C_ID_LANG_GN="gn_*" # Guarani
readonly LIB_C_ID_LANG_GU="gu_*" # Gujarati
readonly LIB_C_ID_LANG_GV="gv_*" # Manx
readonly LIB_C_ID_LANG_HA="ha_*" # Hausa
readonly LIB_C_ID_LANG_HE="he_*" # Hebrew
readonly LIB_C_ID_LANG_HI="hi_*" # Hindi
readonly LIB_C_ID_LANG_HO="ho_*" # Hiri Motu
readonly LIB_C_ID_LANG_HR="hr_*" # Croatian
readonly LIB_C_ID_LANG_HT="ht_*" # Haitian; Haitian Creole
readonly LIB_C_ID_LANG_HU="hu_*" # Hungarian
readonly LIB_C_ID_LANG_HY="hy_*" # Armenian
readonly LIB_C_ID_LANG_HZ="hz_*" # Herero
readonly LIB_C_ID_LANG_IA="ia_*" # Interlingua (International Auxiliary Language Association)
readonly LIB_C_ID_LANG_ID="id_*" # Indonesian
readonly LIB_C_ID_LANG_IE="ie_*" # Interlingue; Occidental
readonly LIB_C_ID_LANG_IG="ig_*" # Igbo
readonly LIB_C_ID_LANG_II="ii_*" # Sichuan Yi; Nuosu
readonly LIB_C_ID_LANG_IK="ik_*" # Inupiaq
readonly LIB_C_ID_LANG_IO="io_*" # Ido
readonly LIB_C_ID_LANG_IS="is_*" # Icelandic
readonly LIB_C_ID_LANG_IT="it_*" # Italian
readonly LIB_C_ID_LANG_IU="iu_*" # Inuktitut
readonly LIB_C_ID_LANG_JA="ja_*" # Japanese
readonly LIB_C_ID_LANG_JV="jv_*" # Javanese
readonly LIB_C_ID_LANG_KA="ka_*" # Georgian
readonly LIB_C_ID_LANG_KG="kg_*" # Kongo
readonly LIB_C_ID_LANG_KI="ki_*" # Kikuyu; Gikuyu
readonly LIB_C_ID_LANG_KJ="kj_*" # Kuanyama; Kwanyama
readonly LIB_C_ID_LANG_KK="kk_*" # Kazakh
readonly LIB_C_ID_LANG_KL="kl_*" # Kalaallisut; Greenlandic
readonly LIB_C_ID_LANG_KM="km_*" # Central Khmer
readonly LIB_C_ID_LANG_KN="kn_*" # Kannada
readonly LIB_C_ID_LANG_KO="ko_*" # Korean
readonly LIB_C_ID_LANG_KR="kr_*" # Kanuri
readonly LIB_C_ID_LANG_KS="ks_*" # Kashmiri
readonly LIB_C_ID_LANG_KU="ku_*" # Kurdish
readonly LIB_C_ID_LANG_KV="kv_*" # Komi
readonly LIB_C_ID_LANG_KW="kw_*" # Cornish
readonly LIB_C_ID_LANG_KY="ky_*" # Kirghiz; Kyrgyz
readonly LIB_C_ID_LANG_LA="la_*" # Latin
readonly LIB_C_ID_LANG_LB="lb_*" # Luxembourgish; Letzeburgesch
readonly LIB_C_ID_LANG_LG="lg_*" # Ganda
readonly LIB_C_ID_LANG_LI="li_*" # Limburgan; Limburger; Limburgish
readonly LIB_C_ID_LANG_LN="ln_*" # Lingala
readonly LIB_C_ID_LANG_LO="lo_*" # Lao
readonly LIB_C_ID_LANG_LT="lt_*" # Lithuanian
readonly LIB_C_ID_LANG_LU="lu_*" # Luba-Katanga
readonly LIB_C_ID_LANG_LV="lv_*" # Latvian
readonly LIB_C_ID_LANG_MG="mg_*" # Malagasy
readonly LIB_C_ID_LANG_MH="mh_*" # Marshallese
readonly LIB_C_ID_LANG_MI="mi_*" # Maori
readonly LIB_C_ID_LANG_MK="mk_*" # Macedonian
readonly LIB_C_ID_LANG_ML="ml_*" # Malayalam
readonly LIB_C_ID_LANG_MN="mn_*" # Mongolian
readonly LIB_C_ID_LANG_MR="mr_*" # Marathi
readonly LIB_C_ID_LANG_MS="ms_*" # Malay
readonly LIB_C_ID_LANG_MT="mt_*" # Maltese
readonly LIB_C_ID_LANG_MY="my_*" # Burmese
readonly LIB_C_ID_LANG_NA="na_*" # Nauru
readonly LIB_C_ID_LANG_NB="nb_*" # Bokmål, Norwegian; Norwegian Bokmål
readonly LIB_C_ID_LANG_ND="nd_*" # Ndebele, North; North Ndebele
readonly LIB_C_ID_LANG_NE="ne_*" # Nepali
readonly LIB_C_ID_LANG_NG="ng_*" # Ndonga
readonly LIB_C_ID_LANG_NL="nl_*" # Dutch; Flemish
readonly LIB_C_ID_LANG_NN="nn_*" # Norwegian Nynorsk; Nynorsk, Norwegian
readonly LIB_C_ID_LANG_NO="no_*" # Norwegian
readonly LIB_C_ID_LANG_NR="nr_*" # Ndebele, South; South Ndebele
readonly LIB_C_ID_LANG_NV="nv_*" # Navajo; Navaho
readonly LIB_C_ID_LANG_NY="ny_*" # Chichewa; Chewa; Nyanja
readonly LIB_C_ID_LANG_OC="oc_*" # Occitan (post 1500)
readonly LIB_C_ID_LANG_OJ="oj_*" # Ojibwa
readonly LIB_C_ID_LANG_OM="om_*" # Oromo
readonly LIB_C_ID_LANG_OR="or_*" # Oriya
readonly LIB_C_ID_LANG_OS="os_*" # Ossetian; Ossetic
readonly LIB_C_ID_LANG_PA="pa_*" # Panjabi; Punjabi
readonly LIB_C_ID_LANG_PI="pi_*" # Pali
readonly LIB_C_ID_LANG_PL="pl_*" # Polish
readonly LIB_C_ID_LANG_PS="ps_*" # Pushto; Pashto
readonly LIB_C_ID_LANG_PT="pt_*" # Portuguese
readonly LIB_C_ID_LANG_QU="qu_*" # Quechua
readonly LIB_C_ID_LANG_RM="rm_*" # Romansh
readonly LIB_C_ID_LANG_RN="rn_*" # Rundi
readonly LIB_C_ID_LANG_RO="ro_*" # Romanian; Moldavian; Moldovan
readonly LIB_C_ID_LANG_RU="ru_*" # Russian
readonly LIB_C_ID_LANG_RW="rw_*" # Kinyarwanda
readonly LIB_C_ID_LANG_SA="sa_*" # Sanskrit
readonly LIB_C_ID_LANG_SC="sc_*" # Sardinian
readonly LIB_C_ID_LANG_SD="sd_*" # Sindhi
readonly LIB_C_ID_LANG_SE="se_*" # Northern Sami
readonly LIB_C_ID_LANG_SG="sg_*" # Sango
readonly LIB_C_ID_LANG_SI="si_*" # Sinhala; Sinhalese
readonly LIB_C_ID_LANG_SK="sk_*" # Slovak
readonly LIB_C_ID_LANG_SL="sl_*" # Slovenian
readonly LIB_C_ID_LANG_SM="sm_*" # Samoan
readonly LIB_C_ID_LANG_SN="sn_*" # Shona
readonly LIB_C_ID_LANG_SO="so_*" # Somali
readonly LIB_C_ID_LANG_SQ="sq_*" # Albanian
readonly LIB_C_ID_LANG_SR="sr_*" # Serbian
readonly LIB_C_ID_LANG_SS="ss_*" # Swati
readonly LIB_C_ID_LANG_ST="st_*" # Sotho, Southern
readonly LIB_C_ID_LANG_SU="su_*" # Sundanese
readonly LIB_C_ID_LANG_SV="sv_*" # Swedish
readonly LIB_C_ID_LANG_SW="sw_*" # Swahili
readonly LIB_C_ID_LANG_TA="ta_*" # Tamil
readonly LIB_C_ID_LANG_TE="te_*" # Telugu
readonly LIB_C_ID_LANG_TG="tg_*" # Tajik
readonly LIB_C_ID_LANG_TH="th_*" # Thai
readonly LIB_C_ID_LANG_TI="ti_*" # Tigrinya
readonly LIB_C_ID_LANG_TK="tk_*" # Turkmen
readonly LIB_C_ID_LANG_TL="tl_*" # Tagalog
readonly LIB_C_ID_LANG_TN="tn_*" # Tswana
readonly LIB_C_ID_LANG_TO="to_*" # Tonga (Tonga Islands)
readonly LIB_C_ID_LANG_TR="tr_*" # Turkish
readonly LIB_C_ID_LANG_TS="ts_*" # Tsonga
readonly LIB_C_ID_LANG_TT="tt_*" # Tatar
readonly LIB_C_ID_LANG_TW="tw_*" # Twi
readonly LIB_C_ID_LANG_TY="ty_*" # Tahitian
readonly LIB_C_ID_LANG_UG="ug_*" # Uighur; Uyghur
readonly LIB_C_ID_LANG_UK="uk_*" # Ukrainian
readonly LIB_C_ID_LANG_UR="ur_*" # Urdu
readonly LIB_C_ID_LANG_UZ="uz_*" # Uzbek
readonly LIB_C_ID_LANG_VE="ve_*" # Venda
readonly LIB_C_ID_LANG_VI="vi_*" # Vietnamese
readonly LIB_C_ID_LANG_VO="vo_*" # Volapük
readonly LIB_C_ID_LANG_WA="wa_*" # Walloon
readonly LIB_C_ID_LANG_WO="wo_*" # Wolof
readonly LIB_C_ID_LANG_XH="xh_*" # Xhosa
readonly LIB_C_ID_LANG_YI="yi_*" # Yiddish
readonly LIB_C_ID_LANG_YO="yo_*" # Yoruba
readonly LIB_C_ID_LANG_ZA="za_*" # Zhuang; Chuang
readonly LIB_C_ID_LANG_ZH="zh_*" # Chinese
readonly LIB_C_ID_LANG_ZU="zu_*" # Zulu

#-------------------------------------------------------------------------------
#  Virtualisation IDs
#-------------------------------------------------------------------------------
readonly LIB_C_ID_VIRT_DOCKER="docker" # Docker
readonly LIB_C_ID_VIRT_KVM="kvm"       # KVM
readonly LIB_C_ID_VIRT_NONE="hostonly" # no virtualisation

#-------------------------------------------------------------------------------
#  Strings
#-------------------------------------------------------------------------------
readonly LIB_C_STR_NEWLINE="
"

#===============================================================================
#  FUNCTIONS
#===============================================================================
#===  FUNCTION  ================================================================
#         NAME:  lib_c
#  DESCRIPTION:  Dummy function to check whether this lib is sourced or not
#===============================================================================
lib_c() {
  return 0
}
