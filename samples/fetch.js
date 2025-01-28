window.addEventListener('load', function() {
    const widget = document.getElementById("nowPlayingWidget");  // your element here
    const req = new XMLHttpRequest();

    const callback = function() {

        const resp = req.response;

        if (req.status == 200) {
            let nowPlaying = "<div class=\"trackinfo\"> <span><b>" + resp.name + "</b> by " + resp.artist + "<br></span>";
            if (resp.nowplaying) {
                nowPlaying += "<i>Listening now!</i>";
            } else {
                nowPlaying += "<i>Played: " + resp.date + "</i>";
            }
            nowPlaying += "</div>";
            if (resp.image.medium) nowPlaying += "<img src=\"" + resp.image.medium + "\" alt=\"album art\" />";
            widget.innerHTML = nowPlaying;
        } else {
            widget.innerHTML = "Problem contacting Last.fm";
        }
    }

    req.addEventListener("load", callback);
    req.responseType = "json";
    req.open("GET", "https://www.ballix.net/whatsplaying"); // your URL here
    req.send();
});
