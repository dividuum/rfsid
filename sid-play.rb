#!/usr/bin/env ruby
require 'rfid'
require 'zlib'

$stdout.sync = true
playerpid    = nil
playinglabel = nil

RFID::Device.new(0) do |rfid|
    loop do 
        labels = rfid.readSerials

        if playinglabel
            unless labels.include?(playinglabel)
                Process.kill("TERM", playerpid)
                Process.wait
                playinglabel = nil
            end
        else
            next if labels.empty?

            # Wenn mehrere Labels in Reichweite, so wird nur
            # das erste gelesen
            label  = labels[0]

            # Nur Infinieon Labels mit 1000byte Speicher
            next unless label.trType    == 3 
            next unless label.blockSize == 8 

            print "Using label #{label.snrHex}. Loading "

            header, numBlocks, blockSize = rfid.read(label.snr, 3, 1) 
            unless header
                puts "cannot read header"
                next
            end

            uncompressed = header.unpack("n")[0]
            print "(size = #{uncompressed})"
            
            # Labels sind erst ab Block 3 beschrieben
            offset     = 3
            blocksLeft = uncompressed / 8 + 1
            data  = ""
            begin
                blocksToRead = [blocksLeft, 16].min
                blockdata, numBlocks, blockSize = rfid.read(label.snr, offset, blocksToRead) 
                if blockdata
                    print "."
                    data << blockdata
                else
                    print "?"
                    break
                end
                offset     += blocksToRead
                blocksLeft -= blocksToRead
            end while blocksLeft > 0

            uncompressed, siddata = data.unpack("n a*")
            begin
                siddata = Zlib::Inflate.inflate(siddata.slice(0...uncompressed))
            rescue
                puts "error uncompressing song"
                next
            end

            begin
                File.open("/tmp/sidplay.sid", "w") do |o|
                    o.write(siddata)
                end
            rescue
                puts "error writing file"
                next
            end

            puts "OK"
            playerpid = fork do 
                null = File.open("/dev/null")
                $stdout.reopen(null)
                $stderr.reopen(null)
                exec("sidplay2", "/tmp/sidplay.sid")
            end

            playinglabel = label
        end
    end
end
