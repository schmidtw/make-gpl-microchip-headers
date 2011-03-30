#!/usr/bin/perl
use warnings;
use strict;

my %rows = ();
my %name_address_map = ();

my $page = 0;
my $page_temp = 0;

my $name_address_cols = 0;

# Pairs of name/address colums to process, if needed
if( 0 < scalar(@ARGV) ) {
    $name_address_cols = $ARGV[0];
}

while( <STDIN> ) {
    s/<a.*?>(.*?)<\/a>/$1/g;
    s/<b.*?>(.*?)<\/b>/$1/g;

    if( m/<page number=\"([0-9]+)\".*?height=\"([0-9]+)\".*?>/ ) {
        $page_temp = $2;
    }

    if( m/<\/page>/ ) {
        $page += $page_temp;
    }

    if( m/<text top=\"([0-9]+)\" left=\"([0-9]+)\".*?height=\"([0-9]+)\".*?>(.*?)<\/text>/ ) {
        add_item( $1+$page, $2, $3, $4 );
    }
}

foreach my $key (sort({$a <=> $b} keys(%rows))) {
    my $out = "";
    my $trailing_slash = "";
    my $tmp = $rows{$key};
    my %row = %$tmp;
    foreach my $order (sort({$a <=> $b} keys(%row))) {
        $tmp = $row{$order};
        my %item = %$tmp;
        if( $item{'text'} =~ m/\(.\)/ ) {
            $out .= $item{'text'};
        } else {
            $out .= "|".$item{'text'};
        }
    }
    $out .= "|";

    unless( $out =~ m/^[|A-Z0-9()_\/h -]+$/ ) {
        $out =~ s/\|[^|]*?[:a-gi-z].*$/\|/g;
        $out =~ s/^\s*\|\s*$//;
    }
    $out =~ s/\|[x01-]{4} [x01-]{4}\|.*/\|/;
    $out =~ s/\s\|/\|/g;
    $out =~ s/\s/\|/g;
    if( $out =~ m/\/\|/ ) {
        $trailing_slash = " -----Parameter probably wrong - trailing slash-----";
        print STDERR "Trailing slash on line: '$out.'\n";
    }
    unless( $out =~ m/^\s*\|[0-9]+\|\s*$/ ) {
        unless( $out =~ m/^\s*$/ ) {
            unless( $out =~ m/family/i ) {
                unless( $out =~ m/special.*function.*registers/i ) {
                    if( 0 < $name_address_cols ) {
                        my @tmp = split( /\|/, $out );
                        my $na_row = 1;
                        for( my $i = 1; $i < scalar(@tmp); $i += 2 ) {
                            unless( $tmp[$i] =~ m/^([0-9A-F]+h|[-])\(?[0-9]?\)?$/ ) {
                                $na_row = 0;
                            }
                        }

                        if( 1 == $na_row ) {
                            for( my $i = 1; $i < scalar(@tmp); $i += 2 ) {
                                unless( $tmp[$i+1] =~ m/[-]/ ) {
                                    my $name = $tmp[$i+1];
                                    $name =~ s/\(.*\)//;
                                    $name_address_map{$name} = $tmp[$i];
                                }
                            }
                            #print $out."\n";
                        } else {
                            @tmp = split( /\|/, $out );
                            my $name = $tmp[1];
                            $name =~ s/\(.*\)//;
                            unless( exists $name_address_map{$name} ) {
                                print STDERR "Missing the address for: '".$name."'\n";
                                print "||$out-----Address Missing-----$trailing_slash\n";
                            } else {
                                print "|".$name_address_map{$name}.$out."$trailing_slash\n";
                            }
                        }
                    } else {
                        print "$out$trailing_slash\n";
                    }
                }
            }
        }
    }
}

################################################################################
################################################################################
################################################################################

sub add_item()
{
    my ($top, $left, $height, $text) = @_;

    my %item = ();

    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/—/-/g;

    $item{'top'}    = $top;
    $item{'left'}   = $left;
    $item{'height'} = $height;
    $item{'text'}   = $text;

    my $found = 0;
    foreach my $key (keys(%rows)) {
        if( 0 == $found ) {
            if( (($top - ($height/2)) <= $key) && ($key < ($top + ($height/2))) ) {
                my $tmp = $rows{$key};
                my %row = %$tmp;
                $row{$left} = \%item;
                $found = 1;
                $rows{$key} = \%row;
            } 
        }
    }

    if( 0 == $found ) {
        my %row = ();
        $row{$left} = \%item;
        $rows{$top} = \%row;
    }
}
