#!/usr/bin/perl
use strict;
use warnings;

my %rows = ();
my %limits = ();

my $in_file = $ARGV[0];
my $name = $ARGV[1];

my $document;
my $sfr_start;
my $sfr_end;
my $sfr_register_size;
my $config_start;
my $config_end;
my $config_register_size;

my $state = 0;
my $out_file = "$name.xml";
my $name_uc = uc $name;

open( IN, "<".$in_file ) or die "Unable to open: '".$in_file."'\n";
open( OUT, ">".$out_file ) or die "Unable to open: '".$out_file."'\n";

print OUT "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
print OUT <<END_LICENSE;
<!--
    Copyright (C) 2011, Joe User <joe.user\@gmail.com>

    This XML document is based on the datasheet for the $name_uc part.

    This library is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation; either version 2.1, or (at your option) any
    later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License 
    along with this library; see the file COPYING. If not, write to the
    Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
    MA 02110-1301, USA.

    As a special exception, if you link this library with other files,
    some of which are compiled with SDCC, to produce an executable,
    this library does not by itself cause the resulting executable to
    be covered by the GNU General Public License. This exception does
    not however invalidate any other reasons why the executable file
    might be covered by the GNU General Public License.
-->
END_LICENSE

while( <IN> ) {
    if( m/\(.+?\)/ ) {
        my @tmp = split( /\|/, $_ );
        foreach $_ (@tmp) {
            if( m/\((.+?)\)/ ) {
                $limits{$1} = "limit_$1";
            }
        }
    }
}

# Start processing the file over
close( IN );
open( IN, "<".$in_file ) or die "Unable to open: '".$in_file."'\n";

while( <IN> ) {
    if( 0 == $state ) {
        # --info-- Mode
        if( m/^\s*document:\s*(.+?)\s*$/ ) {
            $document = $1;
        } elsif( m/^\s*sfr-pages:\s*([0-9]+?)\s*-\s*([0-9]+?)\s*$/ ) {
            $sfr_start = $1;
            $sfr_end = $2;
        } elsif( m/^\s*config-pages:\s*([0-9]+?)\s*-\s*([0-9]+?)\s*$/ ) {
            $config_start = $1;
            $config_end = $2;
        } elsif( m/^\s*sfr-register-size:\s*([0-9]+?)\s*$/ ) {
            $sfr_register_size = $1;
        } elsif( m/^\s*config-register-size:\s*([0-9]+?)\s*$/ ) {
            $config_register_size = $1;
        } elsif( m/^\s*--sfr--\s*$/ ) {
            unless( defined($document) )             { die "Missing document:\n"; }
            unless( defined($sfr_start) )            { die "Missing sfr-pages:1-2\n"; }
            unless( defined($sfr_end) )              { die "Missing sfr-pages:1-2\n"; }
            unless( defined($sfr_register_size) )    { die "Missing sfr-register-size:8\n"; }
            unless( defined($config_start) )         { die "Missing config-pages:1-2\n"; }
            unless( defined($config_end) )           { die "Missing config-pages:1-2\n"; }
            unless( defined($config_register_size) ) { die "Missing config-register-size:8\n"; }

            print OUT "<family name=\"$name\" document-name=\"$document\">\n";
            print OUT "    <devices>\n";
            print OUT "        <device>\n";
            print OUT "            <name>$name</name>\n";
            print OUT "            <class>PROC_CLASS_PIC1x</class>\n";
            print OUT "            <pin-count>64</pin-count>\n";
            print OUT "            <coff-type>64</coff-type>\n";
            print OUT "            <num-pages>0</num-pages>\n";
            print OUT "            <num-banks>0x60</num-banks>\n";
            print OUT "            <max-rom>64</max-rom>\n";
            print OUT "            <memory-size>64</memory-size>\n";
            print OUT "        </device>\n";
            print OUT "    </devices>\n";
            print OUT "    <limits>\n";
            foreach my $limit (keys(%limits)) {
                print OUT "        <limit name=\"".$limits{$limit}."\">\n";
                print OUT "            <only>$name</only>\n";
                print OUT "        </limit>\n";
            }
            print OUT "    </limits>\n";
            print OUT "    <sfrs starting-page=\"$sfr_start\" ending-page=\"$sfr_end\" register-size=\"$sfr_register_size\">\n";
            $state = 1;
        }
    } elsif( 1 == $state ) {
        # --sfr-- Mode
        if( m/^\s*--config--\s*$/ ) {
            print OUT "    </sfrs>\n";
            print OUT "    <configs starting-page=\"$config_start\" ending-page=\"$config_end\" register-size=\"$config_register_size\">\n";
            $state = 2;
        } else {
            common_row( $_, "sfr" );
        }
    } elsif( 2 == $state ) {
        # --config-- Mode
        common_row( $_, "config" );
    } else {
    }
}
print OUT "    </configs>\n";
print OUT "</family>\n";

close( IN );
close( OUT );

################################################################################
################################################################################
################################################################################
sub common_row()
{
    my ($row, $mode) = @_;

    if( m/^\s*\|([0-9a-fA-F]*?)h\|([A-Z0-9_]*?)\|\s*$/ ) {
        # Only the register name is present
        print OUT "        <$mode name=\"$2\" address=\"0x$1\"/>\n";
    } elsif( m/^\s*\|([0-9a-fA-F]+)h\|([A-Z0-9_\/\!()-]+?\|){2,}\s*$/ ) {
        my @bit_list = split( /\|/, $_ );
        my $mode_limit = "";

        shift( @bit_list );
        my $sfr_addr = shift( @bit_list );
        my $sfr_name = shift( @bit_list );
        pop( @bit_list );

        @bit_list = reverse( @bit_list );

        $sfr_addr =~ s/h//;

        if( $sfr_name =~ m/\((.+?)\)/ ) {
            $mode_limit = ' limit="'.$limits{$1}.'"';
            $sfr_name =~ s/\(.+?\)//;
        }
        print OUT "        <$mode name=\"$sfr_name\" address=\"0x$sfr_addr\"$mode_limit>\n";

        my $bit_number = 0;
        foreach my $bit (@bit_list) {
            unless( $bit =~ m/[-]/ ) {
                my $bit_limit = "";

                if( $bit =~ m/\((.+?)\)/ ) {
                    $bit_limit = ' limit="'.$limits{$1}.'"';
                    $bit =~ s/\(.+?\)//;
                }
                my @list_of_names = common_srf_substitutions( $bit );

                if( $mode =~ m/config/ ) {
                    foreach my $bit_name (@list_of_names) {
                        print OUT "            <bit num=\"$bit_number\" name=\"$bit_name\"$bit_limit>\n";
                        print OUT "                <choice name=\"ON\" >1</choice>\n";
                        print OUT "                <choice name=\"OFF\">0</choice>\n";
                        print OUT "            </bit>\n";
                    }
                } else {
                    foreach my $bit_name (@list_of_names) {
                        print OUT "            <bit num=\"$bit_number\" name=\"$bit_name\"$bit_limit/>\n";
                    }
                }
            }
            $bit_number++;
        }
        print OUT "        </$mode>\n";
    } elsif( m/^\s*--config--\s*$/ ) {
        print OUT "    </sfrs>\n";
        print OUT "    <configs>\n";
        $state = 2;
    } else {
        print "Error: '".$_."'\n";
    }
}

sub common_srf_substitutions()
{
    my ($in) = @_;
    my @out = ();

    if( $in =~ m/^(.*?)\/!(.*?)$/ ) {
        push( @out, $1 );
        push( @out, "NOT_".$2 );
        push( @out, $1."_NOT_".$2 );
        push( @out, $1."_".$2 );

        # Add common special rules for a/!b here
        if( $in =~ m/^D\/!A$/ ) {
            push( @out, "NOT_ADDRESS" );
            push( @out, "DATA_ADDRESS" );
        }
        if( $in =~ m/^R\/!W$/ ) {
            push( @out, "NOT_WRITE" );
            push( @out, "READ_WRITE" );
        }
    } elsif( $in =~ m/^!(.*?)$/ ) {
        push( @out, "NOT_".$1 );
    } elsif( $in =~ m/^(.*?)\/(.*?)$/ ) {
        push( @out, $1 );
        push( @out, $2 );
        push( @out, $1."_".$2 );
    } else {
        push( @out, $in );
    }


    return @out;
}
