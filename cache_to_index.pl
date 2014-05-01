#!/usr/bin/perl -w

# Copyright (C) 2014 David Helkowski
# License: CC0 1.0 Universal - http://creativecommons.org/publicdomain/zero/1.0/

use strict;
use XML::Bare qw/xval forcearray/;

opendir( DIR, "cache" );
my @files = readdir( DIR );
closedir( DIR );

for my $file ( @files ) {
    next if( $file =~ m/^\.+$/ );
    folder( $file );
}

sub folder {
    my $site = shift;
    my $folder = "cache/$site";
    if( -e "$folder/content.xml" ) {
        my $url = slurp( "$folder/url" );
        print "<site url=\"$url\">\n";
        site( "$folder/content.xml" );
        print "</site>";
    }
}

sub site {
    my $file = shift;
    my ( $ob, $xml ) = XML::Bare->new( file => $file );
    my $repo = $xml->{'repository'};
    if( !$repo ) { return; }
    my $name = xval $repo->{'name'};
    print "  <repo name=\"$name\">\n";
    my $unitsnode = $repo->{'units'};
    my $units = forcearray( $unitsnode->{'unit'} );
    for my $unit ( @$units ) {
        my $props = forcearray( $unit->{'properties'}{'property'} );
        my %hash;
        my $id = xval $unit->{'id'};
        for my $prop ( @$props ) {
            my $name = xval $prop->{'name'};
            my $val = xval $prop->{'value'};
            $hash{ $name } = $val;
        }
        my $name = $hash{ 'org.eclipse.equinox.p2.name' };
        if( $name ) {
            if( $name =~ m/%(.+)/ ) {
                $name = $hash{ "df_LT.$1" };
            }
            if( $name ) {
                print "    <unit name=\"$name\" id=\"$id\">\n";
            }
            else {
                print "    <unit id=\"$id\">\n";
            }
        }
        else {
            print "    <unit id=\"$id\">\n";
        }
        
        my $provides = forcearray( $unit->{'provides'}{'provided'} );
        for my $provide ( @$provides ) {
            my $ns = xval $provide->{'namespace'};
            my $name = xval $provide->{'name'};
            my $v = xval $provide->{'version'};
            print "      <provides ns=\"$ns\" name=\"$name\" v=\"$v\"/>\n";
        }
        
        print "    </unit>\n";
    }
    print "  </repo>\n";
}

sub slurp {
    my $path = shift;
    local $/ = undef;
    open( F, $path );
    my $data = <F>;
    close( F );
    return $data;
}