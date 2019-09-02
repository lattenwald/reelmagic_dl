# Reelmagic Downloader

**Download and recode videos you already have access to as a legitimate Reelmagic subscriber**

Prior to a 40 hour flight (with a 20 hours of layovers included) I wanted to have some Reelmagic magic to watch. Thus Reelmagic Downloader was created.

## Usage

```bash
reelmagic_dl.ex --playlist <playlist_id> --to <directory>
```

This application downloads videos from playlist and recodes them to something:720 video, as reelmagic videos quality is not high enough to justify 1080 or 4k.

All availale options:

```bash
$ reelmagic_dl.ex -h
Usage: `reelmagic_dl.ex --playlist 78hpp7h24y --to 'Focus on Rings' --concurrency 3`

Options:

  --help -h -- show this help
  --playlist -p [string] -- required, Wistia playlist ID
  --to -t [path] -- required, directory to save videos into
  --concurrency -c [int] -- optional, number of videos to be downloaded simultaneously, default 3
  --keep -k -- keep original files, which by default are removed after recoding
  --no-recode -- optional, don't recode, just download videos
  --ffmpeg or --mencoder -- choose one of mencoder (with x264 & ac3) or ffmpeg (with xvid & ac3), default is ffmpeg

```

## Installation

Copy `reelmagic_dl.ex` to somewhere in `$PATH`, or install compile from source.

## Compiling

This application uses `mencoder` for recoding, with `libavformat`, `libavcodec` (these are part of `ffmpeg` installation) and `libx264` being used for encoding and packaging. Have these installed.

This application was tested with Elixir 1.9 on GNU/Linux, specifically Arch. You are encouraged to test and fix if you want to use it on another platforms.

```bash
git clone https://github.com/lattenwald/reelmagic_dl
cd reelmagic_dl
mix deps.get
mix escript.build
```

These commands will leave you with a `reelmagic_dl.ex` escript binary in your working directory. Run it without options or with `--help`.

## Companion userscript

Having [this script](https://github.com/lattenwald/user.js/blob/master/reelmagic.user.js) installed, you can press `q` at a reelmagicmagazine page and an
alert window with command to download this playlist pops up.
