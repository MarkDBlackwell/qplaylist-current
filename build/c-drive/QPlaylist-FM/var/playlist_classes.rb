require 'fileutils'
require 'json'
require 'mustache'
require 'pp'
require 'time'
require 'xmlsimple'
require 'zlib'

module Playlist
  NON_XML_KEYS = %i[ current_time ]
      XML_KEYS = %i[ artist  title ]
  KEYS = NON_XML_KEYS + XML_KEYS
# Per:
#  https://ruby-doc.org/core-2.2.5/IO.html#method-c-new-label-IO+Open+Mode
  RW_APPEND = 'a+' # Read-write; each write call appends data at end of file; creates a new file if necessary.
  W_BEGIN   = 'w'  # Write-only; truncates existing file to zero length or creates new file.

  module MyFile
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

  class Snapshot
    def blacklisted
      @@blacklisted_value ||= begin
#  Allow blacklisting of these categories of NowPlaying.XML data:
# PRO - House Promotional Spot
# UWR - Underwriting Announcement
        blacklist = %w[ PRO UWR ]
        blacklist.include? category
      end
    end

    def channel_main
      @@channel_main_value ||= begin
        main_sign = '-FM'
        channel = xml_tree['Call'].first.strip
        channel.end_with? main_sign
      end
    end

    def prerecorded
#  Allow additional handling of this category of NowPlaying.XML data:
# SPL - Special Program
      @@prerecorded_value ||= 'SPL' == category
    end

    def song_automatic
#  Allow additional handling of this category of NowPlaying.XML data:
# MUS - Music
      @@song_automatic_value ||= 'MUS' == category
    end

    def values
      @@values_value ||= non_xml_values + xml_values
    end

    protected

    def category
      @@category_value ||= relevant_hash['CatId'].first.strip
    end

    def non_xml_values
      @@non_xml_values_value ||= begin
        NON_XML_KEYS.map do |k|
          case k
          when :current_time
# "%-l" means unpadded hour; "%M" means zero-padded minute; "%p" means uppercase meridian.
            ::Time.now.localtime.round.strftime '%-l:%M %p'
          else
            "(Error: key '#{k}' unknown)"
          end
        end
      end
    end

    def relevant_hash
      @@relevant_hash_value ||= xml_tree['Events'].first['SS32Event'].first
    end

    def xml_tree
# See http://xml-simple.rubyforge.org/
      @@xml_tree_value ||= ::XmlSimple.xml_in 'now_playing.xml', { KeyAttr: 'name' }
    end

    def xml_values
      @@xml_values_value ||= XML_KEYS.map(&:capitalize).map(&:to_s).map{|k| relevant_hash[k].first.strip}
    end
  end #class

  class Run
    def compare_recent
      @@compare_recent_value ||= begin
        currently_playing = now_playing_values
        same = nil # Define in scope.
        ::File.open 'current-song.txt', RW_APPEND do |f_current_song|
          remembered = f_current_song.readlines.map(&:chomp)
          artist_title = currently_playing.drop 1
          same = remembered == artist_title
          unless same
            f_current_song.rewind
            f_current_song.truncate 0
            f_current_song.puts artist_title
          end
        end
        same ? 'same' : nil
      end
    end

    def create_output(keys, values, input_template_file, output_file)
      view = mustache input_template_file
      keys.zip(values).each do |key, value|
        view[key] = value
      end
      ::File.open output_file, W_BEGIN do |f_output|
        f_output.print view.render
      end
      MyFile.make_gzipped output_file
      nil # Return nothing.
    end

    def create_output_recent_songs
      dates, times, artists, titles = recent_songs_get
      songs = dates.zip(times, artists, titles).map do |date, time, artist, title|
        _, month, day = date.split ' '
        clock, meridian = time.split ' '
        hour, minute = clock.split ':'
        {
          artist:   artist,
          day:      day,
          hour:     hour,
          meridian: meridian, # 'AM' or 'PM'.
          minute:   minute,
          month:    month,
          title:    title,
        }
      end
      view = mustache 'recent_songs.mustache'
# Fill the {{#songs}} tag.
      view[:songs] = songs.reverse
      ::File.open 'recent_songs.html', W_BEGIN do |f_output|
# The mustache gem (version 1.0.3) is escaping the HTML.
        f_output.print view.render
      end
      MyFile.make_gzipped 'recent_songs.html'
      nil # Return nothing.
    end

    def day_check
      n = ::Time.now.localtime.round
      year_month_day = ::Time.new n.year, n.month, n.day
# All of "%4Y", "%2m", "%2d" are zero-padded.
      return if day_processed? year_month_day.strftime '%4Y %2m %2d'
      year_month_day
    end

    def day_processed?(current)
      filename = 'today.txt'
      ::FileUtils.touch filename
      result = current == (::IO.read filename)
      ::IO.write filename, current unless result
      result
    end

    def directory_runner
# Convert Windows backslashes to forward slashes:
      ::File.absolute_path ENV['qplaylist-runner-location']
    end

    def latest_five_keys
      @@latest_five_keys_value ||= begin
        key_types = %i[ artist  start_time  time_stamp  title ]
        count = 5
        count.times.to_a.product(key_types).map{|digit, key| "#{key}#{digit.succ}".to_sym}
      end
    end

    def latest_five_songs_get
      @@latest_five_songs_get_value ||= begin
        old_dates, old_start_times, old_artists, old_titles = recent_songs_get
        songs_to_keep = 5
        near_end = -1 * [songs_to_keep, old_titles.length].min
        range_to_keep = near_end...old_titles.length
        dates,              start_times,     artists,     titles =
            [old_dates, old_start_times, old_artists, old_titles].map{|e| e.slice range_to_keep}
# "%H" means hour (on 24-hour clock), "%M" means minute.
        time_stamps = start_times.map{|e| ::Time.parse e}.map{|e| e.strftime '%H %M'}.zip(dates).map{|e| e.reverse.join ' '}
        a = [artists, start_times, time_stamps, titles]
        song_blank = [''] * a.length
        a.transpose.reverse + ::Array.new(songs_to_keep - titles.length){song_blank}
      end
    end

    def latest_five_values
      @@latest_five_values_value ||= latest_five_songs_get.flatten
    end

    def mustache(filename)
      klass = ::Class.new(::Mustache)
      klass.template_file = filename
      klass.new
    end

    def now_playing_values
      @@now_playing_values_value ||= snapshot.values
    end

    def recent_songs_get
      @@recent_songs_get_value ||= begin
        currently_playing = now_playing_values
        n = ::Time.now.localtime.round
# All of "%4Y", "%2m" and "%2d" are zero-padded.
        year_month_day = ::Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'
        dates, times, artists, titles = nil, nil, nil, nil # Define in scope.
        ::File.open 'recent-songs.txt', RW_APPEND do |f_recent_songs|
          dates, times, artists, titles = recent_songs_parse f_recent_songs.readlines
# Push current song:
          dates.  push         year_month_day
          times.  push currently_playing.at 0
          artists.push currently_playing.at 1
          titles. push currently_playing.at 2
          f_recent_songs.puts [year_month_day] + currently_playing
        end
        [dates, times, artists, titles]
      end
    end

    def recent_songs_parse(lines)
      @@recent_songs_parse_value ||= begin
        dates, times, artists, titles = [], [], [], []
        lines_per_song = 4
        a = lines.map(&:chomp)
        song_count = a.length.div lines_per_song
        song_count.times do |i|
          dates.  push a.at i * lines_per_song + 0
          times.  push a.at i * lines_per_song + 1
          artists.push a.at i * lines_per_song + 2
          titles. push a.at i * lines_per_song + 3
        end
        [dates, times, artists, titles]
      end
    end

    def recent_songs_reduce
      year_month_day = day_check
      return unless year_month_day

      dates, times, artists, titles = recent_songs_get
      seconds_per_day = 24 * 60 * 60
      days_ago = snapshot.channel_main ? 7 : 2 # One week; or two days.
      comparison_date = year_month_day - days_ago * seconds_per_day
      big_array = []
      dates.length.times do |i|
        year, month, day = dates.at(i).split(' ').map(&:to_i)
        song_time = ::Time.new year, month, day
        unless song_time < comparison_date
          big_array.push dates.  at i
          big_array.push times.  at i
          big_array.push artists.at i
          big_array.push titles. at i
        end
      end
      ::File.open 'recent-songs.txt', W_BEGIN do |f_recent_songs|
        f_recent_songs.puts big_array
      end
      nil # Return nothing.
    end

    def run
# If the category is Blacklisted, then indicate so, and stop:
      ::Kernel::exit 2 if snapshot.blacklisted

# If the song is unchanged, then indicate so, and stop:
      ::Kernel::exit 1 if 'same' == compare_recent

# If the category is Prerecorded, and this is the main channel, then start the prerecorded-show runner:
      if snapshot.prerecorded && snapshot.channel_main
        start_and_return_immediately 'runner.rb'
      end

# If the category is Song-Automatic, and this is the main channel, then stop all running prerecorded-show runners:
      if snapshot.song_automatic && snapshot.channel_main
        start_and_return_immediately 'killer.rb'
      end

# Fall through.
      create_output_recent_songs

      json_values = latest_five_values.map(&:to_json)
      create_output latest_five_keys, json_values, 'latest_five.json.mustache', 'latest_five.json'

      create_output latest_five_keys, latest_five_values, 'latest_five.mustache',     'latest_five.html'
      create_output latest_five_keys, latest_five_values, 'latest_five_new.mustache', 'latest_five_new.html'

      create_output KEYS, now_playing_values, 'now_playing.mustache', 'now_playing.html'

      recent_songs_reduce
      nil # Return nothing.
    end

    def snapshot
      @@snapshot_value ||= ::Playlist::Snapshot.new
    end

    def start_and_return_immediately(basename)
      filename = ::File.join directory_runner, 'lib', basename
      command = "start %COMSPEC% /C ruby #{filename}"
      ::Kernel.system command
      nil # Return nothing.
    end
  end #class
end #module
