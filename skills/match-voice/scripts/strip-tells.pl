#!/usr/bin/env perl
# strip-tells.pl — normalize non-keyboard typography to ASCII.
#
# Purpose: make text read like it was typed on a keyboard. This is NOT about
# hiding that an agent wrote the text — it is purely about keyboard-native
# characters (no smart quotes, em-dashes, arrows, unicode spaces a person
# wouldn't type). Substitutions use explicit codepoints (\x{...}) so invisible
# characters are handled reliably; perl -CSD makes it portable (system perl).
#
# Usage:  perl strip-tells.pl < in.txt > out.txt
# Run the SKILL's verify grep afterward to catch anything not handled here.

use strict;
use warnings;
binmode(STDIN,  ':encoding(UTF-8)');
binmode(STDOUT, ':encoding(UTF-8)');

while (<>) {
    s/\x{2014}/ - /g;                    # em dash
    s/\x{2013}/-/g;                      # en dash
    s/\x{2026}/.../g;                    # ellipsis
    s/[\x{201C}\x{201D}]/"/g;            # double smart quotes
    s/[\x{2018}\x{2019}]/'/g;            # single smart quotes / apostrophe
    s/\x{2194}/<->/g;                    # left-right arrow (before single arrows)
    s/\x{2192}/->/g;                     # right arrow
    s/\x{21D2}/=>/g;                     # rightwards double arrow
    s/\x{2190}/<-/g;                     # left arrow
    s/[\x{2022}\x{00B7}\x{25AA}\x{25E6}]/-/g;  # bullets / middle dot
    s/[\x{00A0}\x{2009}\x{202F}]/ /g;    # nbsp, thin space, narrow nbsp -> space
    s/\x{200B}//g;                       # zero-width space -> removed
    s/\x{2265}/>=/g;
    s/\x{2264}/<=/g;
    s/\x{2260}/!=/g;
    s/\x{00D7}/x/g;                      # multiplication sign
    s/\x{2016}/||/g;                     # double vertical line
    s/\x{00A7}/section /g;
    s/\x{2122}/(tm)/g;
    s/\x{00A9}/(c)/g;
    s/\x{00AE}/(r)/g;
    print;
}
