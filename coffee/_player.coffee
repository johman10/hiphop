request = require('request')
ytdl = require('ytdl')

itag_priorities = [ # http://en.wikipedia.org/wiki/YouTube > Comparison of YouTube media encoding options
    171, # audio only, WebM/Vorbis/128
    43, # video, VP8/Vorbis/128 (0.6 mbps total)
    140, # audio only, MP4/AAC/128
    172, # audio only, WebM/Vorbis/192
    141, # audio only, MP4/AAC/256
]

video_error_codes = {
    1: 'MEDIA_ERR_ABORTED',
    2: 'MEDIA_ERR_NETWORK',
    3: 'MEDIA_ERR_DECODE',
    4: 'MEDIA_ERR_SRC_NOT_SUPPORTED'
}

__LastSelectedTrack = null

__currentTrack = {}

__playerTracklist = []

spinner_cover = null

PlayNext = (artist, title, success) ->
    $.each __playerTracklist, (i, track) ->
        if track.artist == artist and track.title == title
            if i < __playerTracklist.length - 1
                t = __playerTracklist[i+1]
            else
                t = __playerTracklist[0]
            PlayTrack(t.artist, t.title, t.cover_url_medium, t.cover_url_large)

PlayPrev = (artist, title, success) ->
    $.each __playerTracklist, (i, track) ->
        if track.artist == artist and track.title == title
            if i > 0
                t = __playerTracklist[i-1]
            else
                t = __playerTracklist[__playerTracklist.length - 1]
            PlayTrack(t.artist, t.title, t.cover_url_medium, t.cover_url_large)


PlayTrack = (artist, title, cover_url_medium, cover_url_large) ->

    userTracking.event("Player", "Play", artist + ' - ' + title).send()

    __currentTrack =
        artist: artist
        title: title

    __playerTracklist = __currentTracklist

    __CurrentSelectedTrack = Math.random()
    __LastSelectedTrack = __CurrentSelectedTrack

    videojs('video_player').pause().currentTime(0)

    History.addTrack(artist, title, cover_url_medium, cover_url_large)

    if spinner_cover
        $('#player-container #cover #loading-overlay').hide()
        spinner_cover.stop()

    $('#player-container #info #video-info').html('► Loading...')
    $('#player-container #info #track-info #artist, #title').empty()
    $('#player-container #duration, #current-time').text('0:00')
    $('#player-container #cover').css({'background-image': 'url(' + cover_url_large + ')'})

    $('#player-container #cover #loading-overlay').show()
    spinner_cover = new Spinner(spinner_cover_opts).spin($('#player-container #cover')[0])

    $('#player-container #progress-current').css({'width': '0px'}) # not working ?

    $('#player-container #info #track-info #artist').html(artist)
    $('#player-container #info #track-info #title').html(title)

    request
        url: 'http://gdata.youtube.com/feeds/api/videos?alt=json&max-results=1&q=' + encodeURIComponent(artist + ' - ' + title)
        json: true
    , (error, response, data) ->
        if not data.feed.entry # no results
            PlayNext(__currentTrack.artist, __currentTrack.title)
        else
            $('#player-container #info #video-info').html('► ' + data.feed.entry[0].title['$t'] + ' (' + data.feed.entry[0].author[0].name['$t'] + ')')

            ytdl.getInfo data.feed.entry[0].link[0].href, {downloadURL: true}, (err, info) ->
                if err
                    console.log err
                else
                    stream_urls = []
                    $.each info.formats, (i, format) ->
                        stream_urls[format.itag] = format.url

                    $.each itag_priorities, (i, itag) ->
                        if stream_urls[itag]
                            if __CurrentSelectedTrack == __LastSelectedTrack
                                videojs('video_player').src(stream_urls[itag]).play()
                                userTracking.event("Playback Info", "itag", itag).send()
                            return false



videojs('video_player')

# Pause/Play with Space key
$(document).keydown (e) ->
    if e.keyCode is 32 and e.target.tagName != 'INPUT'
        if videojs('video_player').paused()
            videojs('video_player').play()
        else
            videojs('video_player').pause()
        return false

$('#player-container #info #track-info #action i').click ->
    if $(@).hasClass('play')
        videojs('video_player').play()
    else if $(@).hasClass('pause')
        videojs('video_player').pause()
    else if $(@).hasClass('next')
        PlayNext(__currentTrack.artist, __currentTrack.title)
    else if $(@).hasClass('prev')
        PlayPrev(__currentTrack.artist, __currentTrack.title)

videojs('video_player').ready ->
    @.on 'loadedmetadata', ->
        $('#player-container #duration').text(moment(this.duration()*1000).format('m:ss'))

    @.on 'timeupdate', ->
        $('#player-container #progress-current').css({'width': (this.currentTime() / this.duration()) * 100 + '%'})
        $('#player-container #current-time').text(moment(this.currentTime()*1000).format('m:ss'))

    @.on 'ended', ->
        PlayNext(__currentTrack.artist, __currentTrack.title)

    @.on 'play', ->
        if spinner_cover
            $('#player-container #cover #loading-overlay').hide()
            spinner_cover.stop()
        $('#player-container #info #track-info #action i.play').hide()
        $('#player-container #info #track-info #action i.pause').show()
    @.on 'pause', ->
        $('#player-container #info #track-info #action i.pause').hide()
        $('#player-container #info #track-info #action i.play').show()

    @.on 'error', (e) ->
        code = if e.target.error then e.target.error.code else e.code
        userTracking.event("Playback Error", video_error_codes[code], __currentTrack.artist + ' - ' + __currentTrack.title).send()
        alert 'Playback Error (' + video_error_codes[code] + ')'


$('#player-container #progress-bg').on 'click', (e) ->
    percentage = (e.pageX - $(this).offset().left) / $(this).width()
    videojs('video_player').currentTime(percentage * videojs('video_player').duration())
    $('#player-container #progress-current').css({'width': (percentage) * 100 + '%'})
