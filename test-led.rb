#!/usr/bin/env ruby
require 'rfid'
require 'pp'

RFID::Device.new(0) do |rfid|
    50.times do 
        rfid.setLED(:off)
        sleep 0.05
        rfid.setLED(:red)
        sleep 0.05
    end

    rfid.setLED(:green,  10, 8)
    sleep 1
    rfid.setLED(:orange, 10, 8)
    sleep 1
    rfid.setLED(:red,    10, 8)
    sleep 1
    
    rfid.setLED(:off)
    sleep 0.5
    rfid.setLED(:green)
    sleep 0.5
    rfid.setLED(:orange)
    sleep 0.5
    rfid.setLED(:red, 5)
end
