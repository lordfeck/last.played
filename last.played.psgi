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

my $lfm = Last::Played->new(api_key => $key);

sub get_last_played {
    my $last_played = $lfm->get_last_played(shift);
    my $status = ($last_played =~ /error/) ? 500 : 200;
    say $status;

    return [
        $status,
        [ 'Content-Type' => 'application/json' ],
        [ $last_played ]
    ];

}

my $app = sub {
    my $env = shift;
 
    my $req = Plack::Request->new($env);
 
    if ($req->param('user')) {
        get_last_played($req->param('user'));
    } elsif ($user) {
        get_last_played($user);
    } else {
        return [
            '500',
            [ 'Content-Type' => 'application/json' ],
            [ "{ message: \"UserID is required.\", status: \"error\"}" ]
        ];
    }
    
 
}; 
