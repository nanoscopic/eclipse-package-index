#!/usr/bin/perl -w

# Copyright (C) 2014 David Helkowski
# License: CC0 1.0 Universal - http://creativecommons.org/publicdomain/zero/1.0/

use strict;
use XML::Bare qw/forcearray xval/;
use LWP::Simple;
use Archive::Zip qw/ :ERROR_CODES :CONSTANTS /;
use Data::Dumper;
#use vars qw/AZ_OK/;

my ( $ob, $xml ) = XML::Bare->new( file => 'bookmarks.xml' );

if( ! -e 'cache' ) {
    mkdir( 'cache' );
}

my $bookmarks = $xml->{'bookmarks'};
my $sites = forcearray( $bookmarks->{'site'} );

for my $site ( @$sites ) {
    my $selected = xval $site->{'selected'};
    next if( $selected eq 'false' );
    my $url = xval $site->{'url'};
    cache_site( $url );
}

sub cache_site {
    my $url = shift;
    if( $url =~ m|/$| ) {
        chop $url;
    }
    print "URL: $url\n";
    my $folder;
    my $type = '';
    #my $fullzip;
    my $data;
    
    if( $url =~ m/^http/ ) {
        $folder = $url;
        $folder =~ s/[^a-zA-Z0-9-]/_/g;
        $folder =~ s/_+/_/g;
    
        #my $p2file = "$url/p2.index";
        print "  Folder: $folder\n";
        
        $type = 'http';
        $data = $url;
    }
    elsif( $url =~ m|^jar:file:/(.+)!| ) {
        my $fullzip = $1;
        print "  Zip: $fullzip\n";
        $fullzip =~ m|.+/(.+)$|;
        my $zipname = $1;
        print "  Zipname: $zipname\n";
        $folder = $zipname;
        $folder =~ s/[^a-zA-Z0-9-]/_/g;
        $folder =~ s/_+/_/g;
        print "  Folder: $folder\n";
        
        $type = 'zip';
        $data = $fullzip;
    }
    
    if( ! -e "cache/$folder" ) {
        mkdir "cache/$folder";
    }
    
    if( ! -e "cache/$folder/url" ) {
        open( URL, ">cache/$folder/url" );
        print URL $url;
        close( URL );
    }
    
    if( -e "cache/$folder/redirect" ) {
        # previously discovered site that is ultimately a redirect... just run the redirect
        open( RED, "cache/$folder/redirect" );
        while( <RED> ) {
            my $loc = $_;
            chomp $loc;
            cache_site( $loc );
        }
        close( RED );
        
        return;
    }
    
    if( ! -e "cache/$folder/siteok" ) {
        my $p2 = get_from( $type, "cache/$folder", "p2.index", $data );
        #if( $p2 ) {
        #    process_p2_index( $type, "cache/$folder", $data );
        #}
        my $site;
        if( !$p2 ) { $site = get_from( $type, "cache/$folder", "site.xml", $data ); }
        
        my $content    = get_from( $type, "cache/$folder", "content.jar", $data );
        my $artifacts  = get_from( $type, "cache/$folder", "artifacts.jar", $data );
        my $ccontent   = get_from( $type, "cache/$folder", "compositeContent.jar", $data );
        my $cartifacts = get_from( $type, "cache/$folder", "compositeArtifacts.jar", $data );
        
        if( $content || $artifacts || $ccontent || $cartifacts || $p2 || $site ) {
            `touch cache/$folder/siteok`;
        }
        else {
            my $contentx    = get_from( $type, "cache/$folder", "content.xml", $data );
            my $artifactsx  = get_from( $type, "cache/$folder", "artifacts.xml", $data );
            if( !$contentx && !$artifactsx ) {
                print "  :(\n";
            }
        }
    }
    if( -e "cache/$folder/p2.index" ) {
        process_p2_index( $type, "cache/$folder", $data );
    }
    if( -e "cache/$folder/compositeContent.jar" ) {
        extract_composite( $type, "cache/$folder", $data, "compositeContent.jar" );
    }
    if( -e "cache/$folder/compositeArtifacts.jar" ) {
        extract_composite( $type, "cache/$folder", $data, "compositeArtifacts.jar" );
    }
    if( -e "cache/$folder/compositeContent.xml" ) {
        process_c_content( $type, "cache/$folder", $data, "compositeContent.xml" );
    }
    if( -e "cache/$folder/compositeArtifacts.xml" ) {
        process_c_artifacts( $type, "cache/$folder", $data, "compositeArtifacts.xml" );
    }
    if( -e "cache/$folder/content.jar" ) {
        unjar( "cache/$folder", "cache/$folder/content.jar" );
    }
    if( -e "cache/$folder/artifacts.jar" ) {
        unjar( "cache/$folder", "cache/$folder/artifacts.jar" );
    }
    
    print "\n";
}

# Yank the single xml file out of a artifacts or content jar file
sub unjar {
    my ( $folder, $full ) = @_;
    my $zipob = Archive::Zip->new();
    if( $zipob->read( $full ) == AZ_OK ) {
        my @members = $zipob->members();
        for my $member ( @members ) {
            #if( $member->{'fileName'} eq $file ) {
                my $dest = "$folder/".$member->{'fileName'};
                if( ! -e $dest ) {
                    $zipob->extractMember( $member, $dest );
                }
                return 1;
            #}
            #print Dumper( $member );
        }
    }
}

# Process site.xml file
sub process_site_xml {
}

# Process p2.index file
sub process_p2_index {
    my ( $type, $folder, $data ) = @_;
    my $fname = "$folder/p2.index";
    open( P2, "$fname" );
    while( <P2> ) {
        my $line = $_;
        if( $line =~ m/metadata.repository.factory.order=(.+).xml/ ) {
            my $compcont = "$1.xml";
            print "  Composite Content: $compcont\n";
            get_from( $type, $folder, $compcont, $data, "$folder/compositeContent.xml" );
        }
        if( $line =~ m/artifact.repository.factory.order=(.+).xml/ ) {
            my $compart = "$1.xml";
            print "  Composite Artifacts: $compart\n";
            get_from( $type, $folder, $compart, $data, "$folder/compositeArtifacts.xml" );
        }
    }
    close( P2 );
    #version=1
    #metadata.repository.factory.order=compositeContent.xml,\!
    #artifact.repository.factory.order=compositeArtifacts.xml,\!
}

sub process_c_content_old {
    my ( $type, $folder, $data, $file ) = @_;
    my $full = "$folder/$file";
    my ( $ob, $xml ) = XML::Bare->new( file => $full );
    my $repo = $xml->{'repository'};
    my $children = $repo->{'children'};
    my $childs = forcearray( $children->{'child'} );
    my $ok = 0;
    my $max = 0;
    my $omax = '';
    for my $child ( @$childs ) {
        my $location = xval $child->{'location'};
        if( $location =~ m/4\.3\.2/ ) {
            print "  Content Location: $location\n";
            my $content = get_from( $type, "$location", "$location/content.jar", $data, "$folder/content.jar" );
            $ok = 1;
        }
        if( $location =~ m/\.\./ ) {
            # bah stupid site....
            
            my $site = get_from( $type, "$folder/$location", "$location/site.xml", $data, "$folder/site.xml" );
            my $content    = get_from( $type, "$folder/$location", "$location/content.jar", $data, "$folder/content.jar" );
            my $artifacts  = get_from( $type, "$folder/$location", "$location/artifacts.jar", $data, "$folder/artifacts.jar" );
            $ok = 1;
        }
        # 20140329045715
        if( $location =~ m/(20[0-9]{12})/ ) {
            my $short = $1;
            if( $short > $max ) { 
                $omax = $location;
                $max = $short;
            }
        }
    }
    if( !$ok && $max ) {
        #my $site = get_from( $type, "$folder/$omax", "$omax/site.xml", $data, "$folder/site.xml" );
        #my $content    = get_from( $type, "$folder/$omax", "$omax/content.jar", $data, "$folder/content.jar" );
        #my $artifacts  = get_from( $type, "$folder/$omax", "$omax/artifacts.jar", $data, "$folder/artifacts.jar" );
        
        # This happens in some case... basically locations are just a bounce to another entire repo
        my $ccontent    = get_from( $type, "$folder/recurse", "$omax/compositeContent.jar", $data, "$folder/recurse/compositeContent.jar" );
        if( $ccontent ) {
            # f it... just treat it as a new site at this point
            open(RED,">$folder/redirect");
            print RED "$omax";
            close(RED);
            cache_site( $omax );
        }
        #my $artifacts  = get_from( $type, "$folder/$omax", "$omax/compositeArtifacts.jar", $data, "$folder/compositeArtifacts.jar" );
        $ok = 1;
    }
    if( !$ok ) {
        # ... just use the first location
        my $child = $childs->[0];
        my $location = xval $child->{'location'};
        if( $location =~ m/^http:/ ) {
        }
        else {
            $location = "$data/$location";
        }
        open(RED,">$folder/redirect");
        print RED "$location";
        close(RED);
        print "  Redirecting to $location\n";
        cache_site( $location );
    }
}

sub process_c_content {
    my ( $type, $folder, $data, $file ) = @_;
    my $full = "$folder/$file";
    my ( $ob, $xml ) = XML::Bare->new( file => $full );
    my $repo = $xml->{'repository'};
    my $children = $repo->{'children'};
    my $childs = forcearray( $children->{'child'} );
    my $ok = 0;
    my $max = 0;
    my $omax = '';
    open(RED,">$folder/redirect");
    for my $child ( @$childs ) {
        my $location = xval $child->{'location'};
        if( $location =~ m/^http:/ ) {
        }
        else {
            $location = "$data/$location";
        }
        $location =~ s|([^:])//|$1/|g;
        $location =~ s|[^/]+/../||g;
        $location =~ s|emf/emf|emf|g;
        
        print RED "$location\n";
        
        print "  Redirecting to $location\n";
        cache_site( $location );
    }
    close(RED);
}

sub process_c_artifacts {
    my ( $type, $folder, $data, $file ) = @_;
    my $full = "$folder/$file";
    my ( $ob, $xml ) = XML::Bare->new( file => $full );
    my $repo = $xml->{'repository'};
    my $children = $repo->{'children'};
    my $childs = forcearray( $children->{'child'} );
    for my $child ( @$childs ) {
        my $location = xval $child->{'location'};
        if( $location =~ m/4\.3\.2/ ) {
            print "  Artifacts Location: $location\n";
            my $content = get_from( $type, "$location", "$location/artifacts.jar", $data, "$folder/artifacts.jar" );
        }
    }
}

# Process composite file ( either compositeArtifacts.xml or compositeContent.xml )
sub extract_composite {
    my ( $type, $folder, $data, $file ) = @_;
    my $full = "$folder/$file";
    unjar( $folder, $full );
}

# Process content or artifacts xml files
sub process_content {
}

sub get_from {
    my ( $type, $folder, $file, $data, $dest ) = @_;
    if( !$dest ) { $dest = ''; }
    if( $type eq 'http' ) {
        return get_from_site( $folder, $file, $data, $dest );
    }
    if( $type eq 'zip' ) {
        return get_from_zip( $folder, $file, $data, $dest );
    }
}

sub get_from_site {
    my ( $folder, $file, $url, $dest ) = @_;
    if( ! -e $folder ) { mkdir $folder; }
    my $full = $dest || "$folder/$file";
    
    if( -e $full ) {
        print "  $full exists\n";
        return 1;
    }
    if( -e "$full.404" ) {
        print "  $full previous 404\n";
        return 0;
    }
    
    my $fullurl;
    if( $file =~ m/^http:/ ){
        $fullurl = $file;
    }
    else {
        $fullurl = "$url/$file";
    }
    $fullurl =~ s|([^:])//|$1/|g;
    $fullurl =~ s|[^/]+/../||g;
    $fullurl =~ s|emf/emf|emf|g;
    
    print "  Storing $fullurl at $full\n";
    
    my $res = getstore( $fullurl, $full );
    print "  HTTP res: $res\n";
    if( $res == 404 ) { 
        `touch $full.404`;
        return 0;
    }
    return 1;
}

sub get_from_zip {
    my ( $folder, $file, $zip, $dest ) = @_;
    if( ! -e $folder ) { mkdir $folder; }
    my $full = $dest || "$folder/$file";
    if( -e $full ) {
        print "  $full exists\n";
        return;
    }
    my $zipob = Archive::Zip->new();
    if( $zipob->read( $zip ) == AZ_OK ) {
        my @members = $zipob->members();
        for my $member ( @members ) {
            if( $member->{'fileName'} eq $file ) {
                $zipob->extractMember( $member, $full );
                return 1;
            }
            #print Dumper( $member );
        }
    }
    return 0;
}