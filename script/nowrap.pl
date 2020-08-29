#!/usr/bin/env perl
# Takes input on stdin and copies it to stdout, truncating to the width of the
# terminal as needed.  This is very similar to cut -c1-${COLUMNS} except that
# this script attempts to understand a limited set of terminal escape sequences
# so that colorized output isn't prematurely truncated.
#
# See the bottom of this file for license information (MIT License).
#
# Author: Dave Goodell <davidjgoodell@gmail.com>
#
# DO NOT MODIFY THE 'nowrap' SCRIPT DIRECTLY, IT IS GENERATED BY
# 'fatpack-simple' FROM 'script/nowrap.pl'.
#
# TODO:
# - add support for determining the terminal size via Term::ReadKey
# - possibly support a broader set of escape sequences
# - consider including a reset sequence when truncating lines with escapes

# __FATPACK__

use strict;
use warnings;

use Getopt::Long;
use Text::CharWidth::PurePerl qw(mbwidth);

# guess the encoding of STDIN/STDOUT based on the locale specified in
# the environment
use open ':locale';

my $TABSTOP = 8;
my $ESCAPE_SEQUENCE_PATTERN = qr/(\e\[\d*(;\d+)*m)/;

my $columns = `tput cols`;
chomp($columns);
my $isWrap = 0;
my $indentString = '';
my $indentLength = 0;

if ($columns and $ENV{TERM} eq "cygwin") {
    # use one less than the number of columns when running on Windows under
    # cygwin.  Thanks to Ingo Karkat: https://github.com/goodell/nowrap/issues/2
    --$columns;
}

$columns = 80 unless $columns;

GetOptions(
    "help" => \&print_usage_and_exit,
    "unbuffered" => sub {
        use IO::Handle qw();
        STDOUT->autoflush(1);
    },
    "columns=i" => \$columns,
    "wrap" => \$isWrap,
    "indent-string=s" => sub {
        use List::Util qw(sum0);
        use Encode qw(decode_utf8);
        $indentString = decode_utf8($_[1], 1);
        (my $indentStringWithoutEscapeSequences = $indentString) =~ s/$ESCAPE_SEQUENCE_PATTERN//g;
        $indentLength = sum0 map { $_ eq "\t" ? $TABSTOP : char_to_columns($_) } split //, $indentStringWithoutEscapeSequences;
    },
) or die "unable to parse options, stopped";

if ($columns < $indentLength + 1) {
    die "--columns too small to accommodate --indent-string and any characters, stopped";
}

if ($columns < $TABSTOP) {
    die "--columns too small to accommodate tabs, stopped";
}

# there's probably a better way to do all of this, but this is the first
# approach that came to mind when trying to support all of: TABs,
# variable-width characters, and ANSI escape sequences
while (my $line = <>) {
    chomp $line;

    my $cursor = 0;
    my $nchars = 0;

    my @chars = split //, $line;

    my $output = '';

    for (my $i = 0; $i < scalar(@chars); ++$i) {
        my $c = $chars[$i];
        my $append = $c;

        if ($c eq "\t") {
            # TAB-handling logic
            $cursor += $TABSTOP - ($cursor % $TABSTOP);
            ++$nchars;
        }
        elsif ($c eq "\e") {
            if (substr($line, $i, length($line) - $i) =~ m/$ESCAPE_SEQUENCE_PATTERN/) {
              # handle escape sequences
              die "\$` should be empty, stopped" if $`;
              my $esc_seq = $1;
              # skip over the sequence
              $i      += length($esc_seq) - 1; # -1 b/c of ++$i at loop top
              $nchars += length($esc_seq);
              # $cursor is unchanged

              $append = $esc_seq;
            }
            elsif ($i + 1 < scalar(@chars) && $chars[$i + 1] ne "\e") {
              $nchars += 2;
              $append .= "${chars[++$i]}";
              # $cursor is unchanged
            }
            else {
              ++$nchars;
              # $cursor is unchanged
            }
        }
        else {
            # handle regular characters, including possible multicolumn
            # unicode characters
            ++$nchars;
            $cursor += char_to_columns($c);
        }

        if ($cursor > $columns) {
            if ($isWrap) {
                print "$output", "\n";
                $output = $indentString;
                $cursor = $indentLength;
                redo;
            } else {
                last;
            }
        }
        else {
            $output .= $append;
        }
    }
    print $output, "\n";
}

sub char_to_columns {
    my $c = shift;
    my $width = mbwidth($c);
    return 0 if $width < 0;
    return $width;
}

sub print_usage_and_exit {
    print <<EOT;
Usage: $0 [--unbuffered] [--columns=N] [--wrap [--indent=INDENT-STRING]] [FILE]...

Takes data on standard input or in any specified files and dumps it to
standard output similar to cat or cut.  However, all output will be
truncated to the current terminal width (according to `tput cols') to
prevent long output lines from wrapping.  This is very similar to
`cut -c1-\${COLUMNS}' but it should work better to interpret terminal
color attributes.
EOT
    exit 1;
}

# Copyright (c) 2009 Dave Goodell
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
