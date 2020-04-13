require 'cgi'
require 'json'
require 'mustache'
require 'pp'
require 'time'
require 'xmlsimple'
# require 'yaml'

module Playlist
  NON_XML_KEYS = %w[ current_time ]
      XML_KEYS = %w[ artist title ]
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
        when 'current_time'
# "%-l" means unpadded hour; "%M" means zero-padded minute; "%p" means uppercase meridian.
          Time.now.localtime.round.strftime '%-l:%M %p'
        else
          "(Error: key '#{k}' unknown)"
        end
      end
    end

    def set_xml_values
      @@xml_values ||= XML_KEYS.map(&:capitalize).map{|k| relevant_hash[k].first.strip}
    end

    def xml_tree
# See http://xml-simple.rubyforge.org/
      @@xml_tree_value ||= XmlSimple.xml_in 'now_playing.xml', { KeyAttr: 'name' }
    end
  end #class

  class Substitutions
    def initialize(fields, current_values)
      @substitutions = fields.zip current_values
    end

    def run(s, for_json = false)
      trim_quotes = 1...-1
      backslash = "\\" # A single, backslash character.
      @substitutions.each do |input,output_raw|
#print '[input,output_raw]='; pp [input,output_raw]
        output = if for_json
          (output_raw.delete backslash).to_json.slice trim_quotes
        else
          CGI.escape_html output_raw
        end
        s = s.gsub input, output
      end
      s
    end
  end #class

  class NowPlayingSubstitutions < Substitutions
    def initialize(current_values)
      fields = KEYS.map{|e| "{{#{e}}}"}
      super fields, current_values
    end
  end #class

  class LatestFiveSubstitutions < Substitutions
    def initialize(current_values)
      key_types = %w[ artist  start_time  time_stamp  title ]
      count = 5
      fields = (1..count).map(&:to_s).product(key_types).map{|digit,key| "{{#{key}#{digit}}}"}
#print 'fields='; pp fields
      super fields, current_values
    end
  end #class

  class Songs < Mustache
    def initialize(a)
      @array_of_hashed_songs = a
    end

    def songs
      @array_of_hashed_songs
    end
  end #class

  class Run
    def compare_recent(currently_playing)
      remembered, artist_title, same = nil, nil, nil # Define in scope.
      File.open 'current-song.txt', 'a+' do |f_current_song|
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

    def create_output(substitutions, input_template_file, output_file, for_json = false)
      File.open input_template_file, 'r' do |f_template|
        lines = f_template.readlines
        File.open output_file, 'w' do |f_out|
          lines.each{|e| f_out.print substitutions.run e, for_json}
        end
      end
    end

    def create_output_recent_songs(dates, times, artists, titles)
      songs = dates.zip(times,artists,titles).map do |date,time,artist,title|
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
# Songs.template_extension = 'moustache' # Allow for my error in the naming.
      Songs.template_file = './recent_songs.mustache'
      File.open 'recent_songs.html', 'w' do |f_output|
        f_output.print Songs.new(songs.reverse).render
      end
    end

    def latest_five_songs_get(dates_org, start_times_org, artists_org, titles_org)
# "_org" means original.
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

    def recent_songs_get(currently_playing)
# 'r+' is "Read-write, starts at beginning of file", per:
# http://www.ruby-doc.org/core-2.0.0/IO.html#method-c-new
      n = Time.now.localtime.round
# All of "%4Y", "%2m" and "%2d" are zero-padded.
      year_month_day = Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'
      dates, times, artists, titles = nil, nil, nil, nil # Define in scope.
      File.open 'recent-songs.txt', 'r+' do |f_recent_songs|
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

    def recent_songs_read(f_recent_songs)
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

    def recent_songs_reduce(year_month_day, old_dates, old_times, old_artists, old_titles)
      comparison_date = year_month_day - 60 * 60 * 24 * 14 # Two weeks ago.
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
      File.open 'recent-songs.txt', 'w' do |f_recent_songs|
        big_array.each{|e| f_recent_songs.print "#{e}\n"}
      end
    end

    def run
      snapshot = Playlist::Snapshot.new
      now_playing_tall = snapshot.values
# print 'now_playing_tall='; pp now_playing_tall
      now_playing = now_playing_tall.flatten

# If the category is Blacklisted, then indicate so, and stop:
      ::Kernel::exit 2 if snapshot.blacklisted

# If the song is unchanged, then indicate so, and stop:
      ::Kernel::exit 1 if 'same' == (compare_recent now_playing)

# If the category is Prerecorded, and this is the main channel, then start the prerecorded-show runner:
      if snapshot.prerecorded && snapshot.channel_main
        filename = 'Z:/QPlaylist-runner/lib/runner.rb'
        command = "start %COMSPEC% /C ruby #{filename}"
        ::Kernel.system command
      end

# If the category is Song-Automatic, and this is the main channel, then stop all running prerecorded-show runners:
      if snapshot.song_automatic && snapshot.channel_main
        filename = 'Z:/QPlaylist-runner/lib/killer.rb'
        command = "start %COMSPEC% /C ruby #{filename}"
        ::Kernel.system command
      end

# Else
      now_playing_substitutions = Playlist::NowPlayingSubstitutions.new now_playing
      create_output now_playing_substitutions, 'now_playing.mustache', 'now_playing.html'
      MyFile.make_gzipped 'now_playing.html'
      dates, times, artists, titles = recent_songs_get now_playing
      latest_five_tall = latest_five_songs_get dates, times, artists, titles
# print 'latest_five_tall='; pp latest_five_tall
      latest_five = latest_five_tall.flatten
      latest_five_substitutions = Playlist::LatestFiveSubstitutions.new latest_five
# print 'latest_five_substitutions='; pp latest_five_substitutions
      create_output latest_five_substitutions, 'latest_five.mustache', 'latest_five.html'
      MyFile.make_gzipped 'latest_five.html'
      create_output latest_five_substitutions, 'latest_five.json.mustache', 'latest_five.json', true
      MyFile.make_gzipped 'latest_five.json'

      create_output_recent_songs dates, times, artists, titles
      MyFile.make_gzipped 'recent_songs.html'
      n = Time.now.localtime.round
# All of "%4Y", "%2m", "%2d" and "%2H" are zero-padded; "%2H" means hour (of 24-hour clock).
      year_month_day_hour_string = Time.new(n.year, n.month, n.day, n.hour).strftime '%4Y %2m %2d %2H'
      year_month_day             = Time.new n.year, n.month, n.day
      File.open 'current-hour.txt', 'a+' do |f_current_hour|
        unless f_current_hour.readlines.push('').first.chomp == year_month_day_hour_string
          recent_songs_reduce year_month_day, dates, times, artists, titles
          f_current_hour.rewind
          f_current_hour.truncate 0
          f_current_hour.print "#{year_month_day_hour_string}\n"
        end
      end
    end
  end #class
end #module
