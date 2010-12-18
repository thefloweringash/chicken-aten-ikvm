/* Keymap.m
 * Copyright (C) 2010 Dustin Cartwright
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "Keymap.h"
#define XK_3270
#import "X11/keysym.h"

/* Tables mapping from Unicode characters to X11 keysyms. Unicode characters
 * which have not been assigned a legacy keysym can use the Unicode value plus
 * 0x01000000. For the others, we use the following tables. A value of 0
 * means that the keysym will be 0x0100000 plus the Unicode character, except in
 * page0, pagef6, and pagef7, where it means that the key will be ignored.
 * References:
 *   Unicode code pages: http://www.unicode.org/charts/
 *   keysyms to Unicode table: http://www.cl.cam.ac.uk/~mgk25/ucs/keysyms.txt
 *   keysym definitions: /usr/include/X11/keysymdef.h
 */

// Mappings to X keysyms for Unicode code points less than U+0100:
// ASCII characters, Latin-I supplement
const unsigned int page0[256] = {
    0,      0,      0,      XK_KP_Enter, 0, 0,      0,      0, // U+000*
    0,      XK_Tab, XK_Return, 0,   0,  XK_Return,  0,      0,
    0,      0,      0,      0,      0,      0,      0,      0, // U+001*
    0,      XK_Tab, 0,      XK_Escape, 0,   0,      0,      0,
    XK_space,       XK_exclam,      XK_quotedbl,    XK_numbersign, // U+002*
    XK_dollar,      XK_percent,     XK_ampersand,   XK_apostrophe,
    XK_parenleft,   XK_parenright,  XK_asterisk,    XK_plus,
    XK_comma,       XK_minus,       XK_period,      XK_slash,
    XK_0,   XK_1,   XK_2,   XK_3,   XK_4,   XK_5,   XK_6,   XK_7, // U+003*
    XK_8,           XK_9,           XK_colon,       XK_semicolon,
    XK_less,        XK_equal,       XK_greater,     XK_question,
    XK_at,  XK_A,   XK_B,   XK_C,   XK_D,   XK_E,   XK_F,   XK_G, // U+004*
    XK_H,   XK_I,   XK_J,   XK_K,   XK_L,   XK_M,   XK_N,   XK_O,
    XK_P,   XK_Q,   XK_R,   XK_S,   XK_T,   XK_U,   XK_V,   XK_W, // U+005*
    XK_X,           XK_Y,           XK_Z,           XK_bracketleft,
    XK_backslash,   XK_bracketright,XK_asciicircum, XK_underscore,
    XK_grave, XK_a, XK_b,   XK_c,   XK_d,   XK_e,   XK_f,   XK_g, // U+006*
    XK_h,   XK_i,   XK_j,   XK_k,   XK_l,   XK_m,   XK_n,   XK_o,
    XK_p,   XK_q,   XK_r,   XK_s,   XK_t,   XK_u,   XK_v,   XK_w, // U+007*
    XK_x,           XK_y,           XK_z,           XK_braceleft,
    XK_bar,         XK_braceright,  XK_asciitilde,  XK_BackSpace,

    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+008* 
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+009* 
    XK_nobreakspace,XK_exclamdown,  XK_cent,        XK_sterling, // U+00a*
    XK_currency,    XK_backslash,   XK_brokenbar,   XK_section,
    XK_diaeresis,   XK_copyright,   XK_ordfeminine, XK_guillemotleft,
    XK_notsign,     XK_hyphen,      XK_registered,  XK_macron,
    XK_degree,      XK_plusminus,   XK_twosuperior, XK_threesuperior, // U+00b*
    XK_acute,       XK_mu,          XK_paragraph,   XK_periodcentered,
    XK_cedilla,     XK_onesuperior, XK_masculine,   XK_guillemotright,
    XK_onequarter,  XK_onehalf,     XK_threequarters, XK_questiondown,
    XK_Agrave,      XK_Aacute,      XK_Acircumflex, XK_Atilde, // U+00c*
    XK_Adiaeresis,  XK_Aring,       XK_AE,          XK_Ccedilla,
    XK_Egrave,      XK_Eacute,      XK_Ecircumflex, XK_Ediaeresis,
    XK_Igrave,      XK_Iacute,      XK_Icircumflex, XK_Idiaeresis,
    XK_ETH,         XK_Ntilde,      XK_Ograve,      XK_Oacute, // U+00d*
    XK_Ocircumflex, XK_Otilde,      XK_Odiaeresis,  XK_multiply,
    XK_Oslash,      XK_Ugrave,      XK_Uacute,      XK_Ucircumflex,
    XK_Udiaeresis,  XK_Yacute,      XK_THORN,       XK_ssharp,
    XK_agrave,      XK_aacute,      XK_acircumflex, XK_atilde, // U+00e*
    XK_adiaeresis,  XK_aring,       XK_ae,          XK_ccedilla,
    XK_egrave,      XK_eacute,      XK_ecircumflex, XK_ediaeresis,
    XK_igrave,      XK_iacute,      XK_icircumflex, XK_idiaeresis,
    XK_eth,         XK_ntilde,      XK_ograve,      XK_oacute, // U+00f*
    XK_ocircumflex, XK_otilde,      XK_odiaeresis,  XK_division,
    XK_oslash,      XK_ugrave,      XK_uacute,      XK_ucircumflex,
    XK_udiaeresis,  XK_yacute,      XK_thorn,       XK_ydiaeresis,
};

// U+0100 through U+17f: Latin Extended-A
const unsigned int page1[128] = {
    XK_Amacron,     XK_amacron,     XK_Abreve,      XK_abreve, // U+010*
    XK_Aogonek,     XK_aogonek,     XK_Cacute,      XK_cacute,
    XK_Ccircumflex, XK_ccircumflex, XK_Cabovedot,   XK_cabovedot,
    XK_Ccaron,      XK_ccaron,      XK_Dcaron,      XK_dcaron,
    XK_Dstroke,     XK_dstroke,     XK_Emacron,     XK_emacron, // U+011*
    0,              0,              XK_Eabovedot,   XK_eabovedot,
    XK_Eogonek,     XK_eogonek,     XK_Ecaron,      XK_ecaron,
    XK_Gcircumflex, XK_gcircumflex, XK_Gbreve,      XK_gbreve,
    XK_Gabovedot,   XK_gabovedot,   XK_Gcedilla,    XK_gcedilla, // U+012*
    XK_Hcircumflex, XK_hcircumflex, XK_Hstroke,     XK_hstroke,
    XK_Itilde,      XK_itilde,      XK_Imacron,     XK_imacron,
    XK_Ibreve,      XK_ibreve,      XK_Iogonek,     XK_iogonek,
    XK_Iabovedot,   XK_idotless,    0,              0,      // U+013*
    XK_Jcircumflex, XK_jcircumflex, XK_Kcedilla,    XK_kcedilla,
    XK_kra,         XK_Lacute,      XK_lacute,      XK_Lcedilla,
    XK_lcedilla,    XK_Lcaron,      XK_lcaron,      0,
    0,              XK_Lstroke,     XK_lstroke,     XK_Nacute, // U+014*
    XK_nacute,      XK_Ncedilla,    XK_ncedilla,    XK_Ncaron,
    XK_ncaron,      0,              XK_ENG,         XK_eng,
    XK_Omacron,     XK_omacron,     0,              0,
    XK_Odoubleacute,XK_odoubleacute,XK_OE,          XK_oe, // U+015*
    XK_Racute,      XK_racute,      XK_Rcedilla,    XK_rcedilla,
    XK_Rcaron,      XK_rcaron,      XK_Sacute,      XK_sacute,
    XK_Scircumflex, XK_scircumflex, XK_Scedilla,    XK_scedilla,
    XK_Scaron,      XK_scaron,      XK_Tcedilla,    XK_tcedilla, // U+016*
    XK_Tcaron,      XK_tcaron,      XK_Tslash,      XK_tslash,
    XK_Utilde,      XK_utilde,      XK_Umacron,     XK_umacron,
    XK_Ubreve,      XK_ubreve,      XK_Uring,       XK_uring,
    XK_Udoubleacute,XK_udoubleacute,XK_Uogonek,     XK_uogonek, // U+017*
    XK_Wcircumflex, XK_wcircumflex, XK_Ycircumflex, XK_ycircumflex,
    XK_Ydiaeresis,  XK_Zacute,      XK_zacute,      XK_Zabovedot,
    XK_zabovedot,   XK_Zcaron,      XK_zcaron,      0,
};

// U+0380 through U+3ff: Greek
const unsigned int page3[128] = {
    0,              0,              0,              0, // U+038*
    XK_Greek_accentdieresis, XK_Greek_ALPHAaccent, 0, 0,
    XK_Greek_EPSILONaccent, XK_Greek_ETAaccent, XK_Greek_IOTAaccent, 0,
    XK_Greek_OMICRONaccent, 0, XK_Greek_UPSILONaccent, XK_Greek_OMEGAaccent,
    XK_Greek_iotaaccentdieresis,    XK_Greek_ALPHA, // U+039*
    XK_Greek_BETA,                  XK_Greek_GAMMA,
    XK_Greek_DELTA, XK_Greek_EPSILON,XK_Greek_ZETA, XK_Greek_ETA,
    XK_Greek_THETA, XK_Greek_IOTA,  XK_Greek_KAPPA, XK_Greek_LAMBDA,
    XK_Greek_MU,    XK_Greek_NU,    XK_Greek_XI,    XK_Greek_OMICRON,
    XK_Greek_PI,    XK_Greek_RHO,   0,              XK_Greek_SIGMA, // U+03a*
    XK_Greek_TAU,   XK_Greek_UPSILON,XK_Greek_PHI,  XK_Greek_CHI,
    XK_Greek_PSI,                   XK_Greek_OMEGA,
    XK_Greek_IOTAdiaeresis,         XK_Greek_UPSILONdieresis,
    XK_Greek_alphaaccent,           XK_Greek_epsilonaccent,
    XK_Greek_etaaccent,             XK_Greek_iotaaccent,
    XK_Greek_upsilonaccentdieresis, XK_Greek_alpha, // U+03b*
    XK_Greek_beta,                  XK_Greek_gamma,
    XK_Greek_delta, XK_Greek_epsilon,XK_Greek_zeta, XK_Greek_eta,
    XK_Greek_theta, XK_Greek_iota,  XK_Greek_kappa, XK_Greek_lambda,
    XK_Greek_mu,    XK_Greek_nu,    XK_Greek_xi,    XK_Greek_omicron,
    XK_Greek_pi,                    XK_Greek_rho, // U+03c*
    XK_Greek_finalsmallsigma,       XK_Greek_sigma,
    XK_Greek_tau,   XK_Greek_upsilon,XK_Greek_phi,  XK_Greek_chi,
    XK_Greek_psi,                   XK_Greek_omega,
    XK_Greek_iotadieresis,          XK_Greek_upsilondieresis,
    XK_Greek_omicronaccent,         XK_Greek_upsilonaccent,
    XK_Greek_omegaaccent,           0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+03d* 
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+03e* 
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+03f* 
};

// U+0400 through U+047f: Cyrillic
const unsigned int page4[128] = {
    0,              XK_Cyrillic_IO, XK_Serbian_DJE, XK_Macedonia_GJE, // U+040*
    XK_Ukrainian_IE,XK_Macedonia_DSE,XK_Ukrainian_I,XK_Ukrainian_YI,
    XK_Cyrillic_JE, XK_Cyrillic_LJE,XK_Cyrillic_NJE,XK_Serbian_TSHE,
    XK_Macedonia_KJE,0,             XK_Byelorussian_SHORTU, XK_Cyrillic_DZHE,
    XK_Cyrillic_A,  XK_Cyrillic_BE, XK_Cyrillic_VE, XK_Cyrillic_GHE, // U+041*
    XK_Cyrillic_DE, XK_Cyrillic_IE, XK_Cyrillic_ZHE,XK_Cyrillic_ZE,
    XK_Cyrillic_I,  XK_Cyrillic_SHORTI, XK_Cyrillic_KA, XK_Cyrillic_EL,
    XK_Cyrillic_EM, XK_Cyrillic_EN, XK_Cyrillic_O,  XK_Cyrillic_PE,
    XK_Cyrillic_ER, XK_Cyrillic_ES, XK_Cyrillic_TE, XK_Cyrillic_U, // U+042*
    XK_Cyrillic_EF, XK_Cyrillic_HA, XK_Cyrillic_TSE,XK_Cyrillic_CHE,
    XK_Cyrillic_SHA,XK_Cyrillic_SHCHA, XK_Cyrillic_HARDSIGN, XK_Cyrillic_YERU,
    XK_Cyrillic_SOFTSIGN, XK_Cyrillic_E, XK_Cyrillic_YU, XK_Cyrillic_YA,
    XK_Cyrillic_a,  XK_Cyrillic_be, XK_Cyrillic_ve, XK_Cyrillic_ghe, // U+043*
    XK_Cyrillic_de, XK_Cyrillic_ie, XK_Cyrillic_zhe,XK_Cyrillic_ze,
    XK_Cyrillic_i,  XK_Cyrillic_shorti, XK_Cyrillic_ka, XK_Cyrillic_el,
    XK_Cyrillic_em, XK_Cyrillic_en, XK_Cyrillic_o,  XK_Cyrillic_pe,
    XK_Cyrillic_er, XK_Cyrillic_es, XK_Cyrillic_te, XK_Cyrillic_u, // U+044*
    XK_Cyrillic_ef, XK_Cyrillic_ha, XK_Cyrillic_tse,XK_Cyrillic_che,
    XK_Cyrillic_sha,                XK_Cyrillic_shcha,
    XK_Cyrillic_hardsign,           XK_Cyrillic_yeru,
    XK_Cyrillic_softsign,           XK_Cyrillic_e,
    XK_Cyrillic_yu,                 XK_Cyrillic_ya,
    0,              XK_Cyrillic_io, XK_Serbian_dje, XK_Macedonia_gje, // U+045*
    XK_Ukrainian_ie,XK_Macedonia_dse, XK_Ukrainian_i, XK_Ukrainian_yi,
    XK_Cyrillic_je, XK_Cyrillic_lje,XK_Cyrillic_nje,XK_Serbian_tshe,
    XK_Macedonia_kje, 0,            XK_Byelorussian_shortu, XK_Cyrillic_dzhe,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+046* 
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+047* 
};

// U+05c0 thorugh U+05ff: Hebrew
const unsigned int page5[64] = {
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+05c* 
    XK_hebrew_aleph,XK_hebrew_bet,  XK_hebrew_gimel,XK_hebrew_dalet, // U+05d*
    XK_hebrew_he,   XK_hebrew_waw,  XK_hebrew_zain, XK_hebrew_chet,
    XK_hebrew_tet,  XK_hebrew_yod,  XK_hebrew_finalkaph, XK_hebrew_kaph,
    XK_hebrew_lamed,XK_hebrew_finalmem, XK_hebrew_mem, XK_hebrew_finalnun,
    XK_hebrew_nun,  XK_hebrew_samech,XK_hebrew_ayin,XK_hebrew_finalpe, // U+5e*
    XK_hebrew_pe,   XK_hebrew_finalzade, XK_hebrew_zade, XK_hebrew_qoph,
    XK_hebrew_resh, XK_hebrew_shin, XK_hebrew_taw,  0,
    0,              0,              0,              0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, // U+05f* 
};

// U+0600 through U+067f: Arabic
const unsigned int page6[128] = {
    0,      0,      0,      0,      0,      0,      0,      0, // U+060* 
    0,      0,      0,      0,XK_Arabic_comma,0,    0,      0, 
    0,      0,      0,      0,      0,      0,      0,      0, // U+061* 
    0,              0,              0,              XK_Arabic_semicolon,
    0,              0,              0,              XK_Arabic_question_mark,
    0,                              XK_Arabic_hamza, // U+062*
    XK_Arabic_maddaonalef,          XK_Arabic_hamzaonalef, 
    XK_Arabic_hamzaonwaw,           XK_Arabic_hamzaunderalef,
    XK_Arabic_hamzaonyeh,           XK_Arabic_alef,
    XK_Arabic_beh, XK_Arabic_tehmarbuta, XK_Arabic_teh, XK_Arabic_theh,
    XK_Arabic_jeem, XK_Arabic_hah,  XK_Arabic_khah, XK_Arabic_dal,
    XK_Arabic_thal, XK_Arabic_ra,   XK_Arabic_zain, XK_Arabic_seen, // U+063*
    XK_Arabic_sheen,XK_Arabic_sad,  XK_Arabic_dad,  XK_Arabic_tah,
    XK_Arabic_zah,  XK_Arabic_ain,  XK_Arabic_ghain,0,
    0,              0,              0,              0,
    XK_Arabic_tatweel, XK_Arabic_feh,XK_Arabic_qaf, XK_Arabic_kaf, // U+064*
    XK_Arabic_lam,  XK_Arabic_meem, XK_Arabic_noon, XK_Arabic_ha,
    XK_Arabic_waw,  XK_Arabic_alefmaksura, XK_Arabic_yeh, XK_Arabic_fathatan,
    XK_Arabic_dammatan, XK_Arabic_kasratan, XK_Arabic_fatha, XK_Arabic_damma,
    XK_Arabic_kasra,                XK_Arabic_shadda, // U+065*
    XK_Arabic_sukun,                XK_Arabic_madda_above, 
    XK_Arabic_hamza_above, XK_Arabic_hamza_below, 0,0,        
    0,      0,      0,      0,      0,      0,      0,      0,
    XK_Arabic_0,    XK_Arabic_1,    XK_Arabic_2,    XK_Arabic_3, // U+066*
    XK_Arabic_4,    XK_Arabic_5,    XK_Arabic_6,    XK_Arabic_7,
    XK_Arabic_8,    XK_Arabic_9,    XK_Arabic_percent,  0,
    0,              0,              0,              0,
    XK_Arabic_superscript_alef, 0,  0,              0, // U+067*
    0,              0,              0,              0,
    0, XK_Arabic_tteh, 0,   0,      0,      0,      XK_Arabic_peh,  0,
};

// U+0e00 through U+0e7f: Thai
const unsigned int pagee[128] = {
    0,              XK_Thai_kokai,  XK_Thai_khokhai,XK_Thai_khokhuat, // U+0e0*
    XK_Thai_khokhwai, XK_Thai_khokhon, XK_Thai_khorakhang, XK_Thai_ngongu,
    XK_Thai_chochan,XK_Thai_choching, XK_Thai_chochang, XK_Thai_soso,
    XK_Thai_chochoe,XK_Thai_yoying, XK_Thai_dochada,XK_Thai_topatak,
    XK_Thai_thothan,                XK_Thai_thonangmontho, // U+0e1*
    XK_Thai_thophuthao,             XK_Thai_nonen, 
    XK_Thai_dodek,  XK_Thai_totao,  XK_Thai_thothung, XK_Thai_thothahan,
    XK_Thai_thothong, XK_Thai_nonu, XK_Thai_bobaimai, XK_Thai_popla,
    XK_Thai_phophung, XK_Thai_fofa, XK_Thai_phophan,XK_Thai_fofan,
    XK_Thai_phosamphao,XK_Thai_moma,XK_Thai_yoyak,  XK_Thai_rorua, // U+0e2*
    XK_Thai_ru,     XK_Thai_loling, XK_Thai_lu,     XK_Thai_wowaen,
    XK_Thai_sosala, XK_Thai_sorusi, XK_Thai_sosua,  XK_Thai_hohip,
    XK_Thai_lochula, XK_Thai_oang,  XK_Thai_honokhuk, XK_Thai_paiyannoi,
    XK_Thai_saraa,  XK_Thai_maihanakat, XK_Thai_saraaa, XK_Thai_saraam, //U+0e3*
    XK_Thai_sarai,  XK_Thai_saraii, XK_Thai_saraue, XK_Thai_sarauee,
    XK_Thai_sarau,  XK_Thai_sarauu, XK_Thai_phinthu, 0,
    0,              0,              0,              XK_Thai_baht,
    XK_Thai_sarae,                  XK_Thai_saraae, // U+0e4*
    XK_Thai_sarao,                  XK_Thai_saraaimaimuan,
    XK_Thai_saraaimaimalai,         XK_Thai_lakkhangyao,
    XK_Thai_maiyamok,               XK_Thai_maitaikhu,
    XK_Thai_maiek,  XK_Thai_maitho, XK_Thai_maitri, XK_Thai_maichattawa,
    XK_Thai_thanthakhat, XK_Thai_nikhahit, 0,       0,
    XK_Thai_leksun, XK_Thai_leknung,XK_Thai_leksong,XK_Thai_leksam, // U+0e5*
    XK_Thai_leksi,  XK_Thai_lekha,  XK_Thai_lekhok, XK_Thai_lekchet,
    XK_Thai_lekpaet,XK_Thai_lekkao, 0,              0,
    0,              0,              0,              0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  // U+0e6*
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  // U+0e7*
};

// U+3080 through U+309f: part of Hiragana (mostly without special keysyms)
// U+30a0 through U+30ff: Katakana
const unsigned int page30[128] = {
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  // U+308*
    0,      0,      0,      0,      0,      0,      0,      0, // U+309* 
    0,      XK_dead_voiced_sound,   XK_dead_semivoiced_sound, XK_voicedsound,
    XK_semivoicedsound, 0,          0,              0,
    0,              XK_kana_a,      XK_kana_A,      XK_kana_i, // U+30a*
    XK_kana_I,      XK_kana_u,      XK_kana_U,      XK_kana_e,
    XK_kana_E,      XK_kana_o,      XK_kana_O,      XK_kana_KA,
    0,              XK_kana_KI,     0,              XK_kana_KU,
    0,              XK_kana_KE,     0,              XK_kana_KO, // U+30b*
    0,              XK_kana_SA,     0,              XK_kana_SHI,
    0,              XK_kana_SU,     0,              XK_kana_SE,
    0,              XK_kana_SO,     0,              XK_kana_TA,
    0,              XK_kana_CHI,    0,              XK_kana_tsu, // U+30c*
    XK_kana_TSU,    0,              XK_kana_TE,     0,
    XK_kana_TO,     0,              XK_kana_NA,     XK_kana_NI,
    XK_kana_NU,     XK_kana_NE,     XK_kana_NO,     XK_kana_HA,
    0,              0,              XK_kana_HI,     0, // U+30d*
    0,              XK_kana_FU,     0,              0,
    XK_kana_HE,     0,              0,              XK_kana_HO,
    0,              0,              XK_kana_MA,     XK_kana_MI,
    XK_kana_MU,     XK_kana_ME,     XK_kana_MO,     XK_kana_ya, // U+30e*
    XK_kana_YA,     XK_kana_yu,     XK_kana_YU,     XK_kana_yo,
    XK_kana_YO,     XK_kana_RA,     XK_kana_RI,     XK_kana_RU,
    XK_kana_RE,     XK_kana_RO,     0,              XK_kana_WA,
    0,              0,              XK_kana_WO,     XK_kana_N, // U+30f*
    0,              0,              0,              0,
    0,              0,              0,              XK_kana_conjunctive,
    XK_prolongedsound,  0,          0,              0,
};

/* U+f600 through U+f63f: private use codes, generated internally for characters
 * U+0000 through U+003f when NSNumericPadKeyMask is set.
 * Note that OSXvnc 3.11 doesn't seem to support XK_KP_Equal, so we don't send
 * that. */
const unsigned int pagef6[64] = {
    0,      0,      0,      XK_KP_Enter, 0, 0,      0,      0, // U+f60*
    0,      XK_KP_Tab,XK_Return, 0, 0,  XK_Return,  0,      0,
    0,      0,      0,      0,      0,      0,      0,      0, // U+f61*
    0,      XK_KP_Tab,0,    XK_Escape, 0,   0,      0,      0,
    XK_KP_Space,    XK_exclam,      XK_quotedbl,    XK_numbersign, // U+f62*
    XK_dollar,      XK_percent,     XK_ampersand,   XK_apostrophe,
    XK_parenleft,   XK_parenright,  XK_KP_Multiply, XK_KP_Add,
    XK_comma,       XK_KP_Subtract, XK_KP_Decimal,  XK_KP_Divide,
    XK_KP_0,        XK_KP_1,        XK_KP_2,        XK_KP_3, // U+f63*
    XK_KP_4,        XK_KP_5,        XK_KP_6,        XK_KP_7,
    XK_KP_8,        XK_KP_9,        XK_colon,       XK_semicolon,
    XK_less,        XK_equal,       XK_greater,     XK_question,
};

/* U+f700 through U+f77f: private use area, used by Apple for function keys.
 * See http://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/CORPCHAR.TXT
 * Also listed in NSEvent.h and the documentation for NSEvent class */
const unsigned int pagef7[128] = {
    XK_Up,          XK_Down,        XK_Left,        XK_Right, // U+f70*
    XK_F1,          XK_F2,          XK_F3,          XK_F4,
    XK_F5,  XK_F6,  XK_F7,  XK_F8,  XK_F9,  XK_F10, XK_F11, XK_F12,
    XK_F13, XK_F14, XK_F15, XK_F16, XK_F17, XK_F18, XK_F19, XK_F20, // U+f71*
    XK_F21, XK_F22, XK_F23, XK_F24, XK_F25, XK_F26, XK_F27, XK_F28,
    XK_F29, XK_F30, XK_F31, XK_F32, XK_F33, XK_F34, XK_F35, XK_Insert, // U+f72*
    XK_Delete,      XK_Home,        XK_Begin,       XK_End,
    XK_Page_Up,     XK_Page_Down,   XK_Print,       XK_Scroll_Lock,
    XK_Pause,       XK_Sys_Req,     XK_Break,       XK_3270_Reset, // U+f73*
    0,              XK_Menu,        0,              0,
    XK_Print,       XK_Clear,       XK_Clear,       XK_Insert,
    XK_Delete,      XK_Insert,      XK_Delete,      0,
    0,              XK_Select,      XK_Execute,     XK_Undo, // U+f74*
    XK_Redo,        XK_Find,        XK_Help,        0,
    0,      0,      0,      0,      0,      0,      0,      0,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  // U+f75*
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  // U+f76*
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  // U+f77*
};
