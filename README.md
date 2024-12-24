Last.Played
============
No-frills PSGI application that will fetch the last played track of any Last.FM user.

Requires a Last.FM API key and a few common Perl modules to work.

The Last::Played library also works standalone.

# USING
Use the makefile to install all dependencies (Plack, LWP):

```
make init
```

Set the env var `LASTFM_API_KEY=<your_key>` as an export in your shell somewhere. If you don't already have a Last.fm API key, [you can obtain one here](https://www.last.fm/api/account/create).

Optional: set the env var `LASTFM_USER_ID` to a default user ID in your shell. The psgi script will fallback to this user ID if none is specified in the request.

## Running it
`make run` will start the PSGI script and bind to port 5000 as a default. In production you'll want to host it behind a reverse proxy.

Make requests as follows:

```
http://localhost:5000/?user=foo
```

and you you should see responses like this:

```
{
  "url": "https://www.last.fm/music/Lush/_/Sweetness+and+Light",
  "album": "Sweetness And Light - Single",
  "artist": "Lush",
  "image": [
    {
      "#text": "https://lastfm.freetls.fastly.net/i/u/34s/28721e8f6088e0583ee45e6313816f7c.jpg",
      "size": "small"
    },
    {
      "size": "medium",
      "#text": "https://lastfm.freetls.fastly.net/i/u/64s/28721e8f6088e0583ee45e6313816f7c.jpg"
    },
    {
      "#text": "https://lastfm.freetls.fastly.net/i/u/174s/28721e8f6088e0583ee45e6313816f7c.jpg",
      "size": "large"
    },
    {
      "size": "extralarge",
      "#text": "https://lastfm.freetls.fastly.net/i/u/300x300/28721e8f6088e0583ee45e6313816f7c.jpg"
    }
  ],
  "name": "Sweetness and Light"
}
```

Now its up to you how to embed it in your website. Some sample JS code has been provided.
