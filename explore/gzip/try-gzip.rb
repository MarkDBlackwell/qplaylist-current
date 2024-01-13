# For all of QPlaylist's output files, QPlaylist should write both
# plain-text and gzipped versions, and then let the FTP command file
# determine which to upload.

module Playlist
  module MyFile
    require 'zlib'

    extend self

    def make_gzipped(filename_plain)
      fn_compressed = "#{filename_plain}.gz"
      begin
        stat = ::File::Stat.new filename_plain
        contents = ::IO.binread filename_plain
        ::Zlib::GzipWriter.open fn_compressed do |gz|
          gz.mtime = stat.mtime
          gz.orig_name = filename_plain
          gz.write contents
        end
      rescue ::Errno::ENOENT
        print "File #{filename_plain} not found.\n"
      end
      nil # Return nothing.
    end
  end
end

include Playlist

airstream = 'HD2'

filenames_radio  = %w{NowPlaying LatestFive RecentSongs}.map{|e|   "radio/#{e}#{airstream}.html"}
filenames_player = %w{           LatestFive            }.map{|e|  "player/#{e}#{airstream}.html"}
filenames_app    = %w{           LatestFive            }.map{|e| "wtmdapp/#{e}#{airstream}.json"}

filenames = filenames_radio + filenames_player + filenames_app

filenames.each{|e| MyFile.make_gzipped e}
