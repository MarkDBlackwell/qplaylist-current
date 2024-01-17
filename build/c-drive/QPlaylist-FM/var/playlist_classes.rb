require 'cgi'
require 'json'
require 'mustache'
require 'pp'
require 'time'
require 'xmlsimple'
# require 'yaml'

module Playlist
# Per:
#  http://www.ruby-doc.org/core-2.5.2/IO.html#method-c-new
# 'a+' is "Read-write; each write call appends data at end of file. Creates a new file if necessary":
  RW_APPEND = 'a+'
# 'r+' is "Read-write; starts at beginning of file":
  RW_BEGIN = 'r+'
# 'w' is "Write-only; truncates existing file to zero length or creates new file":
  W_BEGIN = 'w'
  NON_XML_KEYS = %i[ current_time ]
      XML_KEYS = %i[ artist  title ]
  KEYS = NON_XML_KEYS + XML_KEYS

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

  class Snapshot
    def initialize
      set_non_xml_values
      set_xml_values
    end

    def blacklisted
      return @@blacklisted_value if defined? @@blacklisted_value
#  Allow blacklisting of these categories of NowPlaying.XML data:
# UWR - Underwriting Announcement
# PRO - House Promotional Spot
      blacklist = %w[ PRO UWR ]
      @@blacklisted_value = blacklist.include? category
    end

    def channel_main
      return @@channel_main_value if defined? @@channel_main_value
      main_sign = '-FM'
      channel = xml_tree['Call'].first.strip
      @@channel_main_value = channel.end_with? main_sign
    end

    def prerecorded
      return @@prerecorded_value if defined? @@prerecorded_value
#  Allow additional handling of this category of NowPlaying.XML data:
# SPL - Special Program
      @@prerecorded_value = 'SPL' == category
    end

    def song_automatic
      return @@song_automatic_value if defined? @@song_automatic_value
#  Allow additional handling of this category of NowPlaying.XML data:
# MUS - Music
      @@song_automatic_value = 'MUS' == category
    end

    def values
      @@non_xml_values + @@xml_values
    end

    protected

    def category
      @@category_value ||= relevant_hash['CatId'].first.strip
    end

    def relevant_hash
      @@relevant_hash_value ||= xml_tree['Events'].first['SS32Event'].first
    end

    def set_non_xml_values
      @@non_xml_values = NON_XML_KEYS.map do |k|
        case k
        when :current_time
# "%-l" means unpadded hour; "%M" means zero-padded minute; "%p" means uppercase meridian.
          Time.now.localtime.round.strftime '%-l:%M %p'
        else
          "(Error: key '#{k}' unknown)"
        end
      end
      nil # Return nothing.
    end

    def set_xml_values
      @@xml_values ||= XML_KEYS.map(&:capitalize).map(&:to_s).map{|k| relevant_hash[k].first.strip}
      nil # Return nothing.
    end

    def xml_tree
# See http://xml-simple.rubyforge.org/
      @@xml_tree_value ||= XmlSimple.xml_in 'now_playing.xml', { KeyAttr: 'name' }
    end
  end #class

  class Run
    def compare_recent
      @@compare_recent_value ||= begin
      currently_playing = now_playing_values
      remembered, artist_title, same = nil, nil, nil # Define in scope.
      File.open 'current-song.txt', RW_APPEND do |f_current_song|
        remembered = f_current_song.readlines.map(&:chomp)
        artist_title = currently_playing.drop 1
        same = remembered == artist_title
        unless same
          f_current_song.rewind
          f_current_song.truncate 0
          artist_title.each{|e| f_current_song.print "#{e}\n"}
        end
      end
      same ? 'same' : nil
      end
    end

    def create_output(keys, values, input_template_file, output_file)
      view = mustache input_template_file
      keys.zip values do |key, value|
        view[key] = value
      end
      File.open output_file, W_BEGIN do |f_output|
        f_output.print view.render
      end
      MyFile.make_gzipped output_file
      nil # Return nothing.
    end

    def create_output_recent_songs
      dates, times, artists, titles = recent_songs_get
      songs = dates.zip(times,artists,titles).map do |date, time, artist, title|
        year, month, day = date.split ' '
        clock, meridian = time.split ' '
        hour, minute = clock.split ':'
        {
          artist:   artist,
          title:    title,
          time:     time,
          year:     year,
          month:    month,
          day:      day,
          hour:     hour,
          minute:   minute,
          meridian: meridian, # 'AM' or 'PM'.
        }
      end
      view = mustache './recent_songs.mustache'
# Fill the {{#songs}} tag.
      view[:songs] = songs.reverse
      File.open 'recent_songs.html', W_BEGIN do |f_output|
# The mustache gem (version 1.0.3) is escaping the HTML.
        f_output.print view.render
      end
      MyFile.make_gzipped 'recent_songs.html'
      nil # Return nothing.
    end

    def directory_runner
# Convert Windows backslashes to forward slashes:
      ::File.absolute_path ENV['qplaylist-runner-location']
    end

    def latest_five_songs_get
      @@latest_five_songs_get_value ||= begin
# "_org" means original:
      dates_org, start_times_org, artists_org, titles_org = recent_songs_get
      songs_to_keep = 5
      near_end = -1 * [songs_to_keep, titles_org.length].min
      range = near_end...titles_org.length
      dates,          start_times,     artists,     titles =
          [dates_org, start_times_org, artists_org, titles_org].map{|e| e.slice range}
# "%H" means hour (on 24-hour clock), "%M" means minute.
      time_stamps = start_times.map{|e| Time.parse e}.map{|e| e.strftime '%H %M'}.zip(dates).map{|e| e.reverse.join ' '}
      a = [artists, start_times, time_stamps, titles]
      song_blank = [''] * a.length
      a.transpose.reverse + Array.new(songs_to_keep - titles.length){song_blank}
      end
    end

    def latest_five_keys
      @@latest_five_keys_value ||= begin
        key_types = %i[ artist  start_time  time_stamp  title ]
        count = 5
        count.times.to_a.product(key_types).map{|digit, key| "#{key}#{digit.succ}".to_sym}
      end
    end

    def latest_five_values
      @@latest_five_values_value ||= latest_five_songs_get.flatten
    end

    def mustache(filename)
      klass = Class.new(Mustache)
      klass.template_file = filename
      klass.new
    end

    def recent_songs_get
      @@recent_songs_get_value ||= begin
      currently_playing = now_playing_values
      n = Time.now.localtime.round
# All of "%4Y", "%2m" and "%2d" are zero-padded.
      year_month_day = Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'
      dates, times, artists, titles = nil, nil, nil, nil # Define in scope.
      File.open 'recent-songs.txt', RW_BEGIN do |f_recent_songs|
        dates, times, artists, titles = recent_songs_read f_recent_songs
# Push current song:
        times.  push currently_playing.at 0
        artists.push currently_playing.at 1
        titles. push currently_playing.at 2
        dates.  push        year_month_day
        f_recent_songs.puts year_month_day
        currently_playing.each{|e| f_recent_songs.print "#{e}\n"}
      end
      [dates, times, artists, titles]
      end
    end

    def recent_songs_read(f_recent_songs)
      @@recent_songs_read_value ||= begin
      dates, times, artists, titles = [], [], [], []
      lines_per_song = 4
      a = f_recent_songs.readlines.map(&:chomp)
      song_count = a.length.div lines_per_song
      (0...song_count).each do |i|
        dates.  push a.at i * lines_per_song + 0
        times.  push a.at i * lines_per_song + 1
        artists.push a.at i * lines_per_song + 2
        titles. push a.at i * lines_per_song + 3
      end
      [dates, times, artists, titles]
      end
    end

    def recent_songs_reduce(year_month_day, old_dates, old_times, old_artists, old_titles, days_ago)
      comparison_date = year_month_day - 60 * 60 * 24 * days_ago
      big_array = []
      (0...old_dates.length).each do |i|
        year, month, day = old_dates.at(i).split(' ').map(&:to_i)
        song_time = Time.new year, month, day
        unless song_time < comparison_date
          big_array.push old_dates.  at i
          big_array.push old_times.  at i
          big_array.push old_artists.at i
          big_array.push old_titles. at i
        end
      end
      File.open 'recent-songs.txt', W_BEGIN do |f_recent_songs|
        big_array.each{|e| f_recent_songs.print "#{e}\n"}
      end
      nil # Return nothing.
    end

    def now_playing_values
      @@now_playing_values_value ||= begin
      now_playing_tall = snapshot.values
# print 'now_playing_tall='; pp now_playing_tall
      now_playing_tall.flatten
      end
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

      json_values = latest_five_values.map{|e| JSON.generate e}
      create_output latest_five_keys, json_values, 'latest_five.json.mustache', 'latest_five.json'

      create_output latest_five_keys, latest_five_values, 'latest_five.mustache',     'latest_five.html'
      create_output latest_five_keys, latest_five_values, 'latest_five_new.mustache', 'latest_five_new.html'

      create_output KEYS, now_playing_values, 'now_playing.mustache', 'now_playing.html'

      n = Time.now.localtime.round
# All of "%4Y", "%2m", "%2d" and "%2H" are zero-padded; "%2H" means hour (of 24-hour clock).
      year_month_day_hour_string = Time.new(n.year, n.month, n.day, n.hour).strftime '%4Y %2m %2d %2H'
      year_month_day             = Time.new n.year, n.month, n.day
      File.open 'current-hour.txt', RW_APPEND do |f_current_hour|
        unless f_current_hour.readlines.push('').first.chomp == year_month_day_hour_string
          days_ago = snapshot.channel_main ? 7 : 2 # One week; or two days.
          recent_songs_reduce year_month_day, *recent_songs_get, days_ago
          f_current_hour.rewind
          f_current_hour.truncate 0
          f_current_hour.print "#{year_month_day_hour_string}\n"
        end
      end
      nil # Return nothing.
    end

    def snapshot
      @@snapshot_value ||= Playlist::Snapshot.new
    end

    def start_and_return_immediately(basename)
      filename = ::File.join directory_runner, 'lib', basename
      command = "start %COMSPEC% /C ruby #{filename}"
      ::Kernel.system command
      nil # Return nothing.
    end
  end #class
end #module
