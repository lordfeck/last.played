#!/usr/bin/perl

use v5.20;
use strict;
use warnings;

use lib 'lib';
use Last::Played;
use Plack::Request;

# Test missing API key
#my $lfm = Last::Played->new();

my $key = $ENV{LASTFM_API_KEY};
my $user = $ENV{LASTFM_USER_ID};

my $lfm = Last::Played->new(api_key => $key);

my $app = sub {
    my $env = shift;
 
    my $req = Plack::Request->new($env);
 
    if ($req->param('user')) {
        # todo: handle error response from API, should not be a 200
        return [
            '200',
            [ 'Content-Type' => 'application/json' ],
            [ $lfm->get_last_played($req->param('user')) ]
        ];
    } elsif ($user) {
        # todo: handle error response from API, should not be a 200
        return [
            '200',
            [ 'Content-Type' => 'application/json' ],
            [ $lfm->get_last_played($user) ]
        ];
    } else {
        return [
            '500',
            [ 'Content-Type' => 'text/plain' ],
            [ "UserID is required." ]
        ];
    }
    
 
}; 
