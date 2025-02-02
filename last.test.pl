#!/usr/bin/perl

use v5.20;
use strict;
use warnings;

use lib 'lib';
use Last::Played;

my $WIDGET_WRITE_DIR = 'widgets';

sub make_image_write {
    my ($widget_canvas, $user) = @_;
    my $ts = time;
    die "Cannot find $WIDGET_WRITE_DIR" unless -d $WIDGET_WRITE_DIR;
    my $write_path = "$WIDGET_WRITE_DIR/lp_${user}_${ts}.png";
    open (my $TMPFILE, ">", "$write_path") 
        or die "Cannot open $write_path to write";

    binmode $TMPFILE;
    print $TMPFILE $widget_canvas;
    close $TMPFILE;
}

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
mkdir $WIDGET_WRITE_DIR unless -d $WIDGET_WRITE_DIR;
make_image_write($lfm->make_widget($USER), $USER);

