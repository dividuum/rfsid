require 'find'
require 'zlib'

Find.find(ARGV[0] || ".") do |path|
    if FileTest.file?(path)
        File.open(path) do |f|
            raw     = f.read
            siddata = Zlib::Deflate.deflate(raw)
            data    = [siddata.size + 2, siddata].pack("n a*")
            unless data.size > 1000 
                puts "%3d %4d %s" % [data.size, raw.size, path]
            end
        end
    end
end

