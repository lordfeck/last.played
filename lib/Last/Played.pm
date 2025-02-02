package Last::Played;

use strict;
use warnings;
use v5.16;
use Carp;
use JSON;
use GD;
#use GD::Font; # remove GD Font when we load in our own.

use LWP::UserAgent;
use HTTP::Request;
use Time::Piece;

our $VERSION = '1.00';
our $AGENT = LWP::UserAgent->new(agent => "thransoft.last.played/$VERSION");

# widget specific consts
our ($WIDGET_W, $WIDGET_H) = (300, 200);
our $WIDGET_WRITE_DIR = "./widgets"; # todo: use instance var??
our @COLOUR_BLACK = (0,0,0);
our @COLOUR_WHITE = (255,255,255);
our @COLOUR_RED = (180,0,0);
our @COLOUR_MED_RED = (200,60,60);

# API Routes
our $GET_RECENT_TRACKS = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&nowplaying=\"true\"&format=json&limit=1";
our $GET_TOP_TRACKS = "http://ws.audioscrobbler.com/2.0/?method=user.gettoptracks&format=json&limit=1";
our $GET_USER_INFO = "http://ws.audioscrobbler.com/2.0/?method=user.getInfo&format=json";

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

    eval { require Mozilla::CA; };
    if ($@ =~ /Can't locate Mozilla\/CA.pm/) {
        warn "Mozilla::CA should be installed to fetch images for widgets. Disabling verify_hostname instead.";
        $AGENT->ssl_opts('verify_hostname' => 0);
    }

    my %self = (
        api_key => $opts{api_key},
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

sub get_last_played_hash {
    my ($self, $user) = @_;
    return error ("username required") unless ($user and ($user =~ /^\w+$/));

    my $res = do_req ("$GET_RECENT_TRACKS&user=$user&api_key=$self->{api_key}");

    if ($res->is_success) {
        my $json = decode_json($res->content);
        my $recent = $json->{recenttracks}->{track}[0];
        carp "missing recent track data" unless $recent;
        return format_track($recent);

    } elsif ($res->code eq 401 or $res->code eq 403) {
        carp ("could not authenticate with last.fm");
    } else {
        carp $res->content, "\n";
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

sub get_user_info_hash {
    my ($self, $user) = @_;

    my $res = do_req ("$GET_USER_INFO&user=$user&api_key=$self->{api_key}");

    if ($res->is_success) {
        return decode_json($res->content)->{user};
    } elsif ($res->code eq 401 or $res->code eq 403) {
        return error ("could not authenticate with last.fm");
    } else {
        return $res->content, "\n";
    }
}


sub make_widget {
    my ($self, $user) = @_;
    my $imgGd = 0;
    my $userInfo = get_user_info_hash($self, $user);
    my $recent = get_last_played_hash($self, $user);
    my $img = $recent->{image}->{large};

    # some day we will pass in a template file
    my $widget_canvas = GD::Image->newTrueColor($WIDGET_W, $WIDGET_H, 1);
    my $req = do_req($img);

    # Note: we have done three fetches just to get here. This could appear slow to the user.

    if ($req->is_success && $img =~ /png$/) {
        $imgGd = eval { return GD::Image->newFromPngData($req->content); };
    } elsif ($req->is_success && $img =~ /jpg$|jpeg$/) {
        $imgGd = eval { return GD::Image->newFromJpegData($req->content); };
    } elsif ($req->is_success && $img =~ /gif$/) {
        $imgGd = eval { return GD::Image->newFromGifData($req->content); };
    }

    my $black = $widget_canvas->colorAllocate(@COLOUR_BLACK);
    my $white = $widget_canvas->colorAllocate(@COLOUR_WHITE);
    my $red = $widget_canvas->colorAllocate(@COLOUR_RED);
    my $medRed = $widget_canvas->colorAllocate(@COLOUR_MED_RED);

    my $regDate = Time::Piece->gmtime($userInfo->{registered}->{unixtime});

    $widget_canvas->fill(0,0,$red);

    $widget_canvas->string(gdMediumBoldFont,12,5,"Last.played",$white);
    $widget_canvas->filledRectangle(0,23,300,23.5,$white);
    $widget_canvas->filledRectangle(0,25,300,25.5,$white);
    $widget_canvas->filledRectangle(0,27,300,27.5,$white);
    $widget_canvas->string(gdMediumBoldFont,12,42,"Track:",$black);
    $widget_canvas->string(gdSmallFont,12,54,$recent->{name},$black);
    $widget_canvas->string(gdMediumBoldFont,12,86,"Artist:",$black);
    $widget_canvas->string(gdSmallFont,12,98,$recent->{artist},$black);
    $widget_canvas->filledRectangle(0,180,300,200,$medRed);
    $widget_canvas->string(gdTinyFont,12,185,"$user on Last.fm :: $userInfo->{playcount} scrobbles since ". $regDate->year,$black);

    $widget_canvas->copyResized($imgGd,166,42,0,0,120,120,$imgGd->getBounds()) if $imgGd;

    return $widget_canvas->png;
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

# ugh, this is necessary to get around Last.fm's poorly formatted JSON. maybe I should've just went with XML... haha no
sub clean_img_field {
    my ($img_field) = @_;
    my %imgs = ();
    foreach my $img (@$img_field) {
        $imgs{$img->{size}} = $img->{'#text'};
    }
    return \%imgs;
}

sub format_track {
    my ($track) = @_;
    # splice it down, we don't need the boilerplate
    my $date = $track->{date}->{'#text'} ?  $track->{date}->{'#text'} : "";
    return {artist => "$track->{artist}->{'#text'}", album => "$track->{album}->{'#text'}", url => "$track->{url}", name => "$track->{name}", image => clean_img_field($track->{image}), date => $date, nowplaying => $track->{'@attr'}->{nowplaying}};
}

sub format_top_track {
    my ($track) = @_;
    return {artist => "$track->{artist}->{'name'}", playcount => "$track->{playcount}", url => "$track->{url}", name => "$track->{name}", image => clean_img_field($track->{image})};
}

1;
