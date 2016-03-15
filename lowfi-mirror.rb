require 'fileutils'

COPY_TYPES = ['mp3', 'mpc', 'ogg', 'wma'].freeze
CONVERT_TYPES = {
  flac: :convert_flac_to_mpc,
  m4a:  :convert_alac_to_mpc,
  wav:  :convert_wav_to_mpc
}
MPCENC = 'mpcenc --silent --extreme'.freeze

def flac_bitrate(path)
  s = `file "#{path}"`
  s[s.rindex(':')..-1].scan(/.*, ([0-9]*\.?[0-9]+) kHz,.*/).first.last.to_i
end

def convert_flac_to_mpc(source, destination)
  sox = flac_bitrate(source) > 48 ? 'sox -twav - -twavpcm - rate -v 48000 |' : ''
  `flac -c -d "#{source}" | #{sox} #{MPCENC} - "#{destination}"`
end

def convert_alac_to_mpc(source, destination)
  `ffmpeg -i "#{source}" -f wav - | #{MPCENC} - "#{destination}"`
end

def convert_wav_to_mpc(source, destination)
  `#{MPCENC} "#{source}" "#{destination}"`
end

def file_tree(path)
  Dir["#{path}/**/*.{#{COPY_TYPES.join(',')},#{CONVERT_TYPES.keys.join(',')}}"]
end

def destination_file(origin, destination, file)
  "#{destination}#{file[origin.length..-1]}"
end

def lossy_mirror(origin, destination)
  origin_files = file_tree(origin)
  existing_destination_files = file_tree(destination)

  origin_files.each do |f|
    df = destination_file(origin, destination, f)
    FileUtils.mkdir_p df[0..df.rindex('/')]
    if COPY_TYPES.reduce(false) { |a, b| a || f.end_with?(b) }
      next if existing_destination_files.include?(df)
      FileUtils.cp(f, df)
    else
      df = "#{df[0..df.rindex('.')]}mpc"
      puts "Covnerting to #{df}"
      next if existing_destination_files.include?(df)
      puts "still here"
      convert_func = CONVERT_TYPES[f[f.rindex('.') + 1..-1].to_sym]
      puts "Conver func: #{convert_func}"
      send(convert_func, f, df) if convert_func
      puts "Done converting"
    end
  end
end

lossy_mirror(ARGV[0], ARGV[1]) if __FILE__ == $0
