#!/usr/bin/env ruby
require 'rfid'
require 'zlib'

$stdout.sync = true
playerpid    = nil
playinglabel = nil


RFID::Device.new(0) do |rfid|
    # ONT: 0: all transponders in the field will sent to the host
    rfid.setConfig(5, 11, 0x00)

    rfid.setLED(:green)
    loop do 
        begin
            labels = rfid.readSerials
        rescue => e
            puts e
            sleep 0.5
            next
        end

        if playinglabel
            unless labels.include?(playinglabel)
                print "label disappeared. stopping player..."
                Process.kill("TERM", playerpid)
                Process.wait
                puts "OK"
                playinglabel = nil
            end
        else
            rfid.setLED(:green)
            next if labels.empty?
            rfid.setLED(:orange)

            # Wenn mehrere Labels in Reichweite, so wird nur
            # das erste gelesen
            label  = labels[0]

            # Nur Infinieon Labels mit 1000byte Speicher
            next unless label.trType    == 3 
            next unless label.blockSize == 8 

            print "#{labels.size} labels. using #{label.snrHex} "

            begin
                header, numBlocks, blockSize = rfid.read(label.snr, 3, 1) 
            rescue => e
                puts "error reading header: #{e}"
                next
            end

            unless header
                puts "cannot read header"
                next
            end

            compressed = header.unpack("n")[0]
            print "(size = #{compressed}) "
            
            # Labels sind erst ab Block 3 beschrieben
            offset     = 3
            blocksLeft = compressed / 8 + 1
            data  = ""
            begin
                blocksToRead = [blocksLeft, 16].min
                begin
                    blockdata, numBlocks, blockSize = rfid.read(label.snr, offset, blocksToRead) 
                rescue => e
                    print e
                    break
                end

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

            compressed, siddata = data.unpack("n a*")
            begin
                siddata = Zlib::Inflate.inflate(siddata.slice(0...compressed))
            rescue
                puts "error uncompressing song"
                next
            end

            print " (uncompressed size = #{siddata.size}) "

            begin
                File.open("/tmp/sidplay.sid", "w") do |o|
                    o.write(siddata)
                end
            rescue
                puts "error writing file"
                next
            end

            print "(starting player) "

            playerpid = fork do 
                null = File.open("/dev/null")
                $stdout.reopen(null)
                $stderr.reopen(null)
                exec("sidplay2", "/tmp/sidplay.sid")
            end


            puts "OK"

            playinglabel = label
            rfid.setLED(:red)
        end
    end
end
