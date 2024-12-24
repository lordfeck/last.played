package Last::Played;

use strict;
use warnings;
use Carp;
use JSON;
use v5.16;

use LWP::UserAgent;
use HTTP::Request;

our $VERSION = '1.00';
our $AGENT = LWP::UserAgent->new(agent => "thransoft.last.played/$VERSION");

=head1 NAME
Last::Played

=head1 DESCRIPTION
Connects to the Last.FM API and fetches the most recently scrobbled track from the user.

=head1 SYNOPSIS
Connects to the Last.FM V2 API and fetches the most recently scrobbled track from the user.
I've written this with PSGI in mind, but it will work anywhere. It just requires its own
Last.fm API Key, obtainable at https://www.last.fm/api/account/create.

A callback URL is not necessary.

Depends on Carp and LWP.

=head1 METHODS
get_last_played

Requires the username as a string parameter. Will return a spliced JSON object detailing the track name, album name, artist name, url and a list of images. The JSON object is encoded as a string, intended to be served straight to the web server.
=over
=cut

sub new {
    my ($class, %opts) = @_;

    # Check that api key is a non empty string
    croak "Last.FM API key required." if !$opts{api_key} or !($opts{api_key} =~ /^\w+$/);
    my %self = (
        api_key => $opts{api_key},
        get_recent_tracks => "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&api_key=$opts{api_key}&nowplaying=\"true\"&format=json&limit=1"
    );
    return bless \%self, $class;
}

sub get_last_played {
    my ($self, $user) = @_;
    return "{message: \"username required\", status: \"error\"}" if !$user or !($user =~ /^\w+$/);

    # build url string - append user name query param
    my $reqUrl = "$self->{get_recent_tracks}&user=$user";

    my $req = HTTP::Request->new(GET => $reqUrl);
    my $res = $AGENT->request($req);

    if ($res->is_success) {
        my $json = decode_json($res->content);
        
        # splice it down, we don't need the boilerplate
        my $recent = $json->{recenttracks}->{track}[0];
        return "{message: \"missing recent track data\", status: \"error\"}" unless $recent;
        my %jsonHash = (artist => $recent->{artist}->{'#text'}, album => $recent->{album}->{'#text'}, url => $recent->{url}, name => $recent->{name}, image => $recent->{image}, date => $recent->{date}->{'#text'});
        return encode_json(\%jsonHash);
    } elsif ($res->code eq 401 or $res->code eq 403) {
        return "{message: \"could not authenticate with last.fm\", status: \"error\"}";
    } else {
        return $res->content, "\n";
    }
}

1;
