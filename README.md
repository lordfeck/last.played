Last.Played
============
No-frills PSGI application that will generate an embeddable widget card for any Last.FM user. It also offers a clean JSON API to fetch the last played track, the user's top played track of all time, last week or last 12 months. The [sample javascript](samples/fetch.js) demonstrates usage of the API.

Requires a Last.FM API key and a few common Perl modules to work.

The Last::Played library also works standalone. The methods will be documented in POD, or just refer to `last.test.pl` for an example.

# USING
Use the makefile to install all dependencies (Plack, LWP, Starman, JSON):

```
make init
```

Alternative: Run `apt install libplack-perl libwww-perl libjson-perl starman` to install the packages globally on Debian.

NOTE: The widget maker needs HTTPS to fetch album art images, thus it is better with `Mozilla::CA` installed. This module isn't always available; in such a case the module will ignore SSL verification as a fallback.

Set the env var `LASTFM_API_KEY=<your_key>` as an export in your shell somewhere. If you don't already have a Last.fm API key, [you can obtain one here](https://www.last.fm/api/account/create).

Optional: set the env var `LASTFM_USER_ID` to a default user ID in your shell. The psgi script will fallback to this user ID if none is specified in the request.

## Running it
`make run` will start the PSGI script and bind to port 5010 as a default. In production you'll want to host it behind a reverse proxy.

Make requests as follows:

### Now Playing

```
http://localhost:5010/?user=foo
OR
http://localhost:5010/now?user=foo
```

and you will see cleaner responses like this:

```
{
  "url": "https://www.last.fm/music/Lush/_/Sweetness+and+Light",
  "album": "Sweetness And Light - Single",
  "artist": "Lush",
  "image": {
      "small": "https://lastfm.freetls.fastly.net/i/u/34s/28721e8f6088e0583ee45e6313816f7c.jpg",
      "medium": "https://lastfm.freetls.fastly.net/i/u/64s/28721e8f6088e0583ee45e6313816f7c.jpg"
      "large": "https://lastfm.freetls.fastly.net/i/u/174s/28721e8f6088e0583ee45e6313816f7c.jpg",
      "extralarge": "https://lastfm.freetls.fastly.net/i/u/300x300/28721e8f6088e0583ee45e6313816f7c.jpg"
  },
  "name": "Sweetness and Light",
  "date": "24 Dec 2024, 10:20",
  "nowplaying": "false"
}
```

Now it is up to you how to embed it on your website. Some sample JS code has been provided.

### Top Tracks 
You can also request the most played track over the following time periods: week, year and month.

```
http://localhost:5010/top-week?user=foo
http://localhost:5010/top-year?user=foo
http://localhost:5010/top-alltime?user=foo
```

The response will always be as follows. Note there is less detail than the 'now playing' route, but the playcount is included.

```
{
  "name": "Bulls",
  "url": "https://www.last.fm/music/All+Them+Witches/_/Bulls",
  "playcount": "5",
  "artist": "All Them Witches",
  "image": {
      "small": "https://lastfm.freetls.fastly.net/i/u/34s/2a96cbd8b46e442fc41c2b86b821562f.png"
      "medium": "https://lastfm.freetls.fastly.net/i/u/64s/2a96cbd8b46e442fc41c2b86b821562f.png"
      "large": "https://lastfm.freetls.fastly.net/i/u/174s/2a96cbd8b46e442fc41c2b86b821562f.png",
      "extralarge": "https://lastfm.freetls.fastly.net/i/u/300x300/2a96cbd8b46e442fc41c2b86b821562f.png"
    }
}

```

### Widget card
Finally you may generate a widget card which shows the user name, total scrobbles, current track and the current track's album art. This is a WIP - the current version is rough!


```
http://localhost:5010/widget?user=<USERNAME>
```

## Installing on Linux (Debian and derivatives)
`make install` should take care of that. It will copy and enable the service, as well as creating a blank logfile. It assumes you have a user `www-data` who will be granted privileges to run the script.

Reminder: you'll need to specify the `LASTFM_API_KEY` in the user's environment. You may wish to modify the systemd unitfile to achieve this.
