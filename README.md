# PlexGet

**NOTE** This is a pretty dumb script. Expect errors.  It has only been tested on Linux (Debian).

Simple script to download files from remote Plex servers, including friends Plex server.

The following perl modules are required.  Make sure you have them installed.  Google if you don't know how.

  * HTTP::Tiny
  * XML::LibXML
  * XML::Simple
  * File::Path
  * LWP::UserAgent
  * Encode
  * File::HomeDir

This script creates a configuration file, which you can manually edit if you wish.  The file is located in the users home directory and called .plex.ini.  Adjust the file name in the script if you don't like it.

The configuration file has the following format:
```
token = <script token. This is automatically generated during the first run of the script>
Movielibrary = <directory to store downloaded movies>
TVlibrary = <directory to store downloaded tv shows>
```
**NOTE** This is a pretty dumb script. Expect errors.  It has only been tested on Linux (Debian).
