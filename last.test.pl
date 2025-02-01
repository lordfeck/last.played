#!/usr/bin/perl

use v5.20;
use strict;
use warnings;

use lib 'lib';
use Last::Played;

# Test missing API key
eval { my $lfm1 = Last::Played->new(); };

if ($@ =~ /key required/) {
    say "missing api key failed successfully";
} else {
    die "missing api key was not caught!";
}

my $key = $ENV{LASTFM_API_KEY};
my $USER = $ENV{LASTFM_USER_ID};

my $lfm = Last::Played->new(api_key => $key);

# test regex
my $img = "foo.png";
if ($img =~ /png$/) {
    say eval { return "PNG Match!"; };
} 

$img = "foo.jpg";
if ($img =~ /png$/) {
    say eval { return "PNG Match! this should not be."; };
} else { say "png mismatch, as expected"; }

if ($img =~ /jpg$|jpeg$/) {
    say eval { return "JPEG match!" };
}
$img = "foo.jpeg";
if ($img =~ /jpg$|jpeg$/) {
    say eval { return "JPEG match!" };
}

# Test missing user 
my $nouser = $lfm->get_last_played();
if ($nouser =~ /username required/) {
    say "missing user id failed successfully";
} else {
    die "missing user ID was not caught!";
}

# test fetches
say $lfm->get_last_played($USER);
say $lfm->get_top_track_alltime($USER);
say $lfm->get_top_track_year($USER);
say $lfm->get_top_track_week($USER);

# test widgets
mkdir 'widgets' unless -d 'widgets';
$lfm->make_widget($USER);
