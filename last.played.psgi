#!/usr/bin/perl

use v5.16;
use strict;
use warnings;

use lib 'lib';
use Last::Played;
use Plack::Request;

my $key = $ENV{LASTFM_API_KEY};
my $user = $ENV{LASTFM_USER_ID};

die "FATAL: Please set an env var of LASTFM_API_KEY to store your API key!" unless $key;

my %routes = (
    '/' => \&get_last_played,
    '/now' => \&get_last_played,
    '/top-alltime' => \&get_top_alltime,
    '/top-week' => \&get_top_week,
    '/top-year' => \&get_top_year,
);

my $lfm = Last::Played->new(api_key => $key);

sub error {
    my ($msg, $code) = @_;

    return [ $code, [ 'Content-Type' => 'application/json' ],
            [ "{\"message\": \"$msg\", \"status\": \"error\"}" ] ];
}

sub get_last_played {
    my $last_played = $lfm->get_last_played(shift);
    my $status = ($last_played =~ /error/) ? 500 : 200;

    return [ $status, [ 'Content-Type' => 'application/json' ], [ $last_played ] ];
}

sub get_top_alltime {
    my $top = $lfm->get_top_track_alltime(shift);
    my $status = ($top =~ /error/) ? 500 : 200;

    return [ $status, [ 'Content-Type' => 'application/json' ], [ $top ] ];
}

sub get_top_year {
    my $top = $lfm->get_top_track_year(shift);
    my $status = ($top =~ /error/) ? 500 : 200;

    return [ $status, [ 'Content-Type' => 'application/json' ], [ $top ] ];
}
sub get_top_week {
    my $top = $lfm->get_top_track_week(shift);
    my $status = ($top =~ /error/) ? 500 : 200;

    return [ $status, [ 'Content-Type' => 'application/json' ], [ $top ] ];
}

my $app = sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $route = $routes{$req->path_info};

    return error("Not found", 404) unless $route;
 
    if ($req->param('user')) {
        &$route($req->param('user'));
    } elsif ($user) {
        &$route($user);
    } else {
        return error("UserID is required", 500);
    }
}; 
