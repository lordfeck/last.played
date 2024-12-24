#!/usr/bin/perl

use v5.20;
use strict;
use warnings;

use lib 'lib';
use Last::Played;

# Test missing API key
#my $lfm = Last::Played->new();

my $key = $ENV{LASTFM_API_KEY};

my $lfm = Last::Played->new(api_key => $key);

#say $lfm->get_last_played();
say $lfm->get_last_played("foo");

