#!/usr/bin/perl

use Text::CSV;
use LWP::Simple;
use URI;
use threads;
use threads::shared;

use strict;
use warnings;

my $max_thread_count = 10;
my $stagger_delay = 1;
my $periodic_delay = 0;

my @error_list = ();

my %part_url_map = ();
my %pdf_url_map = ();

my @files = <input/*>;

foreach my $file (@files) {
    print "Processing: $file\n";

    my $csv = Text::CSV->new({ allow_whitespace => 1 } ) or
        die "Cannot use CSV: ".Text::CSV->error_diag();

    open( my $fh_in, "<".$file ) or die "Unable to open: '".$file."'\n";
    while( my $row = $csv->getline($fh_in) ) {
        my @cols = $csv->fields();

        if( $cols[1] =~ m/In Production/ ) {
            if( $cols[0] =~ m/PIC/ ) {
                $part_url_map{$cols[0]} = $cols[2];
            }
        }
    }
    $csv->eof or $csv->error_diag();
    close( $fh_in );

    $csv->eol( "\r\n" );
}

my $current_thread_count = 0;
my @threads = ();
foreach my $key (keys(%part_url_map)) {
    my $thread = threads->create( 'harvest', $key );
    $current_thread_count++;
    push( @threads, $thread );

    if( 0 < $stagger_delay ) {
        sleep $stagger_delay;
    }

    if( $max_thread_count <= $current_thread_count ) {
        foreach my $t (@threads) {
            my $temp = $t->join();
            my @rv = @$temp;
            process_harvest_results( $rv[0], $rv[1] );
        }
        @threads = ();
        $current_thread_count = 0;
        if( 0 < $periodic_delay ) {
            sleep $periodic_delay;
        }
    }
}

foreach my $t (@threads) {
    my $temp = $t->join();
    my @rv = @$temp;
    process_harvest_results( $rv[0], $rv[1] );
}
@threads = ();

if( 0 < scalar(@error_list) ) {
    print "Parts with issues:\n----------------------------------------\n";
    foreach my $key (@error_list) {
        print "$key  '".$part_url_map{$key}."'\n";
    }
}

open( MAKEFILE, ">Makefile" ) or die "Unable to open: 'Makefile'\n";

print MAKEFILE "all : cache \\\n";

foreach my $key (keys(%pdf_url_map)) {
    my $url = URI->new( $pdf_url_map{$key} );
    print MAKEFILE "      cache/".get_filename($url)."\\\n";
}
print MAKEFILE "\n";
print MAKEFILE "\n";
foreach my $key (keys(%pdf_url_map)) {
    my $url = URI->new( $pdf_url_map{$key} );
    print MAKEFILE "cache/".get_filename($url)." :\n";
    print MAKEFILE "\twget $url -O \$\@\n";
    print MAKEFILE "\n";
}

print MAKEFILE "cache :\n\t-mkdir cache\n";
print MAKEFILE "\n";
print MAKEFILE "clean :\n\trm -rf cache\n";
close( MAKEFILE );

open( PARTMAP, ">part-map.xml" ) or die "Unable to open: 'part-map.xml'\n";
print PARTMAP "<part-map>\n";
foreach my $key (keys(%pdf_url_map)) {
    my $url = URI->new( $pdf_url_map{$key} );
    print PARTMAP "    <part name=\"$key\" datasheet=\"cache/".get_filename($url)."\"/>\n";
}
print PARTMAP "</part-map>\n";


################################################################################
################################################################################
################################################################################
sub get_filename()
{
    my ($uri) = @_;

    my $path = $uri->path;
    my @dirs = split( /\//, $path );

    return $dirs[scalar(@dirs)-1];
}

sub harvest()
{
    my ($name) = @_;

    print "Processing: $name\n";
    my $url = URI->new( $part_url_map{$name} );
    my $page_1_raw = get( $url->as_string ) or die "Couldn't get content from: ".$url->as_string."\n";
    my $pdf = "invalid";
    my $url2;

    my @page_1 = split( //, $page_1_raw );

    foreach my $line (@page_1) {
        if( $line =~ m/<META\s+HTTP-EQUIV\s*=\s*"REFRESH"\s+CONTENT\s*=\s*".*URL=(.*?)"\s*>/ ) {
            $url2 = URI->new_abs( $1, $url );
        }
    }

    my $page_2_raw = get( $url2->as_string );

    # Optimize the search so the HTML is split across lines
    $page_2_raw =~ s///g;
    $page_2_raw =~ s/></></g;
    my @page_2 = split( //, $page_2_raw );

    # Find the pdf of the datasheet since this isn't valid XML or xhtml...
    my $state = 0;

    foreach my $line (@page_2) {
        if( 0 == $state ) {
            if( $line =~ m/<[Tt][Aa][Bb][Ll][Ee].*?\s+id\s*=\s*['"]tblDocumentation['"].*?>/ ) {
                $state = 1;
            }
        }

        if( 1 == $state ) {
            if( $line =~ m/<[tT][Dd].*?>.*?Data Sheets.*?<\/[Tt][Dd]>/ ) {
                $state = 2;
            }
        }

        if( 2 == $state ) {
            if( $line =~ m/<[Aa].*?href\s*=\s*['"](.*?)['"].*?>\s*PIC.*?<\/\s*[Aa]\s*>/ ) {
                $state = 3;
                $pdf = $1;
            }
        }
    }

    if( $pdf =~ m/invalid/ ) {
        print "Processing: $name - Done - Error\n";
    } else {
        print "Processing: $name - Done\n";
    }

    my @rv = ();

    $rv[0] = $name;
    $rv[1] = $pdf;

    return \@rv;
}

sub process_harvest_results
{
    (my $name, my $results) = @_;

    if( $results =~ m/invalid/ ) {
        push( @error_list, $name );
    } else {
        $pdf_url_map{$name} = $results;
    }
}

