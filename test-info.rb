#!/usr/bin/env ruby
require 'rfid'
require 'pp'

RFID::Device.new(0) do |rfid|
    loop do 
        rfid.readSerials.each do |label|
            pp label
        end
    end
end
