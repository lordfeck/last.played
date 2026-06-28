package Last::Played;

use strict;
use warnings;
use v5.16;
use Carp;
use JSON;
use GD;

use LWP::UserAgent;
use HTTP::Request;
use Time::Piece;

my $VERSION = '1.00';
my $AGENT = LWP::UserAgent->new(agent => "thransoft.last.played/$VERSION");

# select correct method depending on whether the cache is available
sub get_user_info_hash;
sub get_user_info_cache;
sub get_widget_art_cache;
sub do_img_req;

my $GET_USER_INFO_METHOD = \&get_user_info_hash;
my $GET_WIDGET_ART_METHOD = \&do_img_req;

my $cache = 0;
my $albumArtCache = 0;
my $CACHE_MAX_ENTRIES = 500;
my $ART_CACHE_MAX_ENTRIES = 100;
my $CACHE_EXPIRY_TIME = 5 * 24 * 60 * 60; # 5 days
my $ART_CACHE_EXPIRY_TIME = 365 * 24 * 60 * 60; # 365 days

# widget specific consts
my ($WIDGET_W, $WIDGET_H) = (300, 200);
#my $WIDGET_WRITE_DIR = "./widgets"; # todo: use instance var??
my @COLOUR_BLACK = (0,0,0);
my @COLOUR_WHITE = (255,255,255);
my @COLOUR_RED = (180,0,0);
my @COLOUR_MED_RED = (200,60,60);

# API Routes
my $GET_RECENT_TRACKS = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&nowplaying=\"true\"&format=json&limit=1";
my $GET_TOP_TRACKS = "http://ws.audioscrobbler.com/2.0/?method=user.gettoptracks&format=json&limit=1";
my $GET_USER_INFO = "http://ws.audioscrobbler.com/2.0/?method=user.getInfo&format=json";

=head1 NAME
Last::Played

=head1 DESCRIPTION
Connects to the Last.FM API and fetches the most recently scrobbled track from the user.

=head1 SYNOPSIS
Connects to the Last.FM V2 API and fetches the most recently scrobbled track from the user.
I've written this with PSGI in mind, but it will work anywhere. It just requires its own
Last.fm API Key, obtainable at https://www.last.fm/api/account/create.

A callback URL is not necessary.

Depends on Carp and LWP. Cache::LRU should also be installed to avoid extraneous fetches.

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

    eval { require Cache::LRU; };
    if ($@ =~ /Can't locate Cache/) {
        warn "Cache::LRU should be installed for optimal performance.";
    } else {
        $cache = Cache::LRU->new( size => $CACHE_MAX_ENTRIES );
        $GET_USER_INFO_METHOD = \&get_user_info_cache;
        $albumArtCache = Cache::LRU->new( size => $ART_CACHE_MAX_ENTRIES );
        $GET_WIDGET_ART_METHOD = \&get_widget_art_cache;
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

sub get_user_info {
    return &$GET_USER_INFO_METHOD(@_);
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

sub get_user_info_cache {
    my ($self, $user) = @_;

    my $entry = $cache->get($user);
    return $entry->{userInfo} if ($entry && $entry->{expires_at} > time); 

    my $userInfo = get_user_info_hash($self, $user);

    $cache->set($user, {
        userInfo      => $userInfo,
        expires_at => time + $CACHE_EXPIRY_TIME
    });

    return $userInfo;
}

sub get_widget_art_cache {
    my ($self, $imgUrl) = @_;

    my $entry = $albumArtCache->get($imgUrl);
    return $entry->{art} if ($entry && $entry->{expires_at} > time); 

    my $imgGd = do_img_req($self, $imgUrl);

    $cache->set($imgUrl, {
        art      => $imgGd,
        expires_at => time + $ART_CACHE_EXPIRY_TIME
    });

    return $imgGd;
}

sub get_widget_art {
    return &$GET_WIDGET_ART_METHOD(@_);
}

sub do_img_req {
    my ($self, $imgUrl) = @_;
    my $req = do_req($imgUrl);

    if ($req->is_success && $imgUrl =~ /png$/) {
        return eval { GD::Image->newFromPngData($req->content); };
    } elsif ($req->is_success && $imgUrl =~ /jpg$|jpeg$/) {
        return eval { GD::Image->newFromJpegData($req->content); };
    } elsif ($req->is_success && $imgUrl =~ /gif$/) {
        return eval { GD::Image->newFromGifData($req->content); };
    }
}

sub make_widget {
    my ($self, $user) = @_;
    my $imgGd = 0;
    my $userInfo = get_user_info($self, $user);
    my $recent = get_last_played_hash($self, $user);
    my $imgUrl = $recent->{image}->{large};

    # some day we will pass in a template file
    my $widget_canvas = GD::Image->newTrueColor($WIDGET_W, $WIDGET_H, 1);

    $imgGd = get_widget_art($self, $imgUrl);

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
