#!/usr/bin/perl -w

# Copyright (C) 2014 David Helkowski
# License: CC0 1.0 Universal - http://creativecommons.org/publicdomain/zero/1.0/

use strict;
use XML::Bare qw/xval forcearray/;

my $fid = $ARGV[0];

my ( $ob, $xml ) = XML::Bare->new( file => 'full.xml' );

my $sites = forcearray( $xml->{'site'} );

for my $site ( @$sites ) {
    my $repos = forcearray( $site->{'repo'} );
    for my $repo ( @$repos ) {
        my $units = forcearray( $repo->{'unit'} );
        for my $unit ( @$units ) {
            my $id = xval $unit->{'id'};
            if( $id =~ m/$fid/ ) {
                my $name = xval $unit->{'name'};
                #my $v = xval $unit->{'v'};
                print "Unit name: $name\n";
                #print "  Version: $v\n";
                my $reponame = xval $repo->{'name'};
                print "  Repo name: $reponame\n";
                my $siteurl = xval $site->{'url'};
                print "  Site url: $siteurl\n";
                print "\n";
            }
        }
    }
}