require 'fileutils'
require 'json'
require 'mustache'
require 'pp'
require 'time'
require 'xmlsimple'
require 'zlib'

module Playlist
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
    DUPLICATION_WHITELIST = [['with Paul Hartman', 'Detour']] # Artist, Title.
    NON_XML_KEYS = %i[ current_time ]
        XML_KEYS = %i[ artist  title ]
    KEYS = NON_XML_KEYS + XML_KEYS

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

    def song_current
      @@song_current_value ||= begin
        artist, title, cut_id = %w[Artist Title CutId].map {|k| relevant_hash[k].first.strip}
        fields = if DUPLICATION_WHITELIST.include? [artist, title]
          [artist, title, cut_id]
        else
          [artist, title]
        end
        fields.map {|e| "#{e}\n"}.join ''
      end
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
      @@xml_values_value ||= XML_KEYS.map(&:capitalize).map(&:to_s).map {|k| relevant_hash[k].first.strip}
    end
  end #class

  class Run
# Convert Windows backslashes to forward slashes:
    DIRECTORY_RUNNER = ::File.absolute_path ::ENV['qplaylist_runner_location']

    NOW_PLAYING_KEYS = Snapshot::KEYS
    SONG_KEYS        = %i[date   start_time artist     title] # Keep order.
    SONG_LATEST_KEYS = %i[artist start_time time_stamp title] # Keep order.
    LATEST_FEW_COUNT = 5
    LATEST_FEW_KEYS = LATEST_FEW_COUNT.times.to_a.product(SONG_LATEST_KEYS).map {|digit, key| "#{key}#{digit.succ}".to_sym}

    Song       = ::Struct.new *SONG_KEYS
    SongLatest = ::Struct.new *SONG_LATEST_KEYS

    SONG_LATEST_BLANK = SongLatest.new *([''] * SONG_LATEST_KEYS.length)

    def compare_recent
      @@compare_recent_value ||= begin
        filename = 'current-song.txt'
        ::FileUtils.touch filename
        current = snapshot.song_current
        same = current == ::IO.read(filename)
        ::IO.write filename, current unless same
        same ? 'same' : nil
      end
    end

    def create_output(keys, values, input_template_file, output_file)
      pairs = keys.zip values
      view = mustache input_template_file
      ::IO.write output_file, view.render(pairs.to_h)
      MyFile.make_gzipped output_file
      nil # Return nothing.
    end

    def create_output_recent_songs
      view = mustache 'recent_songs.mustache'
# Fill the {{#songs}} tag.
      view[:songs] = recent_songs_get.reverse.map do |song|
        _, month, day = song[:date].split ' '
        clock, meridian = song[:start_time].split ' '
        hour, minute = clock.split ':'
        {
          artist:   song[:artist],
          day:      day,
          hour:     hour,
          meridian: meridian, # 'AM' or 'PM'.
          minute:   minute,
          month:    month,
          title:    song[:title],
        }
      end
# The mustache gem (version 1.0.3) is escaping the HTML.
      ::IO.write 'recent_songs.html', view.render
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
      result = current == ::IO.read(filename)
      ::IO.write filename, current unless result
      result
    end

    def latest_few_songs_get
      @@latest_few_songs_get_value ||= begin
        songs = recent_songs_get.last LATEST_FEW_COUNT
        keys_common = SONG_KEYS & SONG_LATEST_KEYS
        latest = songs.map do |song|
          one = SongLatest.new
          keys_common.each {|k| one[k] = song[k]}
# "%H" means hour (on 24-hour clock), "%M" means minute.
          hour_minute = ::Time.parse(song[:start_time]).strftime '%H %M'
          one[:time_stamp] = "#{song[:date]} #{hour_minute}"
          one
        end
        latest + ::Array.new(LATEST_FEW_COUNT - latest.length) {SONG_LATEST_BLANK}
      end
    end

    def latest_few_values
      @@latest_few_values_value ||= latest_few_songs_get.reverse.map(&:values).flatten
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
        n = ::Time.now.localtime.round
# All of "%4Y", "%2m" and "%2d" are zero-padded.
        year_month_day = ::Time.new(n.year, n.month, n.day).strftime '%4Y %2m %2d'
        fields = [year_month_day] + now_playing_values
        ::File.open 'recent-songs.txt', RW_APPEND do |f_recent_songs|
          songs = recent_songs_parse f_recent_songs.readlines
          f_recent_songs.puts fields
          songs.push Song.new *fields
        end
      end
    end

    def recent_songs_parse(lines_raw)
      @@recent_songs_parse_value ||= begin
        lines_per_song = SONG_KEYS.length
        lines = lines_raw.map &:chomp
        safe = lines.length - lines.length % lines_per_song
        safe.times.each_slice(lines_per_song).map do |indices|
          fields = indices.map {|i| lines.at i}
          Song.new *fields
        end
      end
    end

    def recent_songs_reduce
      year_month_day = day_check
      return unless year_month_day

      days_ago = snapshot.channel_main ? 7 : 2 # One week; or two days.
      seconds_per_day = 24 * 60 * 60
      comparison_time = year_month_day - days_ago * seconds_per_day

      songs = recent_songs_get.select do |song|
        year, month, day = song[:date].split(' ').map &:to_i
        song_time = ::Time.new year, month, day
        song_time >= comparison_time
      end
      ::File.open 'recent-songs.txt', W_BEGIN do |f_recent_songs|
        f_recent_songs.puts songs.map(&:values).flatten
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

      json_values = latest_few_values.map &:to_json
      create_output  LATEST_FEW_KEYS,        json_values, 'latest_five.json.mustache', 'latest_five.json'

      create_output  LATEST_FEW_KEYS,  latest_few_values, 'latest_five.mustache',      'latest_five.html'
      create_output  LATEST_FEW_KEYS,  latest_few_values, 'latest_five_new.mustache',  'latest_five_new.html'

      create_output NOW_PLAYING_KEYS, now_playing_values, 'now_playing.mustache',      'now_playing.html'

      recent_songs_reduce
      nil # Return nothing.
    end

    def snapshot
      @@snapshot_value ||= ::Playlist::Snapshot.new
    end

    def start_and_return_immediately(basename)
      filename = ::File.join DIRECTORY_RUNNER, 'lib', basename
      command = "start %COMSPEC% /C ruby #{filename}"
      ::Kernel.system command
      nil # Return nothing.
    end
  end #class
end #module
