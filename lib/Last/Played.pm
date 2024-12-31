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

# API Routes
our $GET_RECENT_TRACKS = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&nowplaying=\"true\"&format=json&limit=1";
our $GET_TOP_TRACKS = "http://ws.audioscrobbler.com/2.0/?method=user.gettoptracks&format=json&limit=1";

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
        api_key => $opts{api_key}
    );
    return bless \%self, $class;
}

sub get_last_played {
    my ($self, $user) = @_;
    return error ("username required") unless ($user and ($user =~ /^\w+$/));

    # build url string - append user name query param
    my $res = do_req ("$GET_RECENT_TRACKS&user=$user&api_key=$self->{api_key}");

    if ($res->is_success) {
        my $json = decode_json($res->content);
        
        my $recent = $json->{recenttracks}->{track}[0];
        return error ("missing recent track data") unless $recent;
        return encode_json(format_track($recent));

    } elsif ($res->code eq 401 or $res->code eq 403) {
        return error ("could not authenticate with last.fm");
    } else {
        return $res->content, "\n";
    }
}

sub get_top_track_alltime {
    my ($self, $user) = @_;
    return error ("username required") unless ($user and ($user =~ /^\w+$/));
    return get_top_track_period ($self, $user, "overall");
}

sub get_top_track_year {
    my ($self, $user) = @_;
    return error ("username required") unless ($user and ($user =~ /^\w+$/));
    return get_top_track_period ($self, $user, "12month");
}

sub get_top_track_week {
    my ($self, $user) = @_;
    return error ("username required") unless ($user and ($user =~ /^\w+$/));
    return get_top_track_period ($self, $user, "7day");
}

sub get_top_track_period {
    my ($self, $user, $period) = @_;

    my $res = do_req ("$GET_TOP_TRACKS&period=$period&user=$user&api_key=$self->{api_key}");

    if ($res->is_success) {
        my $json = decode_json($res->content);

        my $top = $json->{toptracks}->{track}[0];
        return error ("missing top track data") unless $top;
        return encode_json(format_top_track($top));
        
    } elsif ($res->code eq 401 or $res->code eq 403) {
        return error ("could not authenticate with last.fm");
    } else {
        return $res->content, "\n";
    }
}

# static methods - internal use only
sub error {
    my ($msg) = @_;
    return "{\"message\": \"$msg\", \"status\": \"error\"}";
}

sub do_req {
    my ($reqUrl) = @_;
    return $AGENT->request(HTTP::Request->new(GET => $reqUrl));
}

sub format_track {
    my ($track) = @_;
    # splice it down, we don't need the boilerplate
    my $date = $track->{date}->{'#text'} ?  $track->{date}->{'#text'} : "";
    return {artist => "$track->{artist}->{'#text'}", album => "$track->{album}->{'#text'}", url => "$track->{url}", name => "$track->{name}", image => $track->{image}, date => $date, nowplaying => $track->{'@attr'}->{nowplaying}};
}

sub format_top_track {
    my ($track) = @_;
    return {artist => "$track->{artist}->{'name'}", playcount => "$track->{playcount}", url => "$track->{url}", name => "$track->{name}", image => $track->{image}};
}

1;
