#!/usr/bin/env ruby

puts "getting the stemcell version..."
stemcellFile=Dir["pas-windows-stemcell-pivnet/*windows*"]
version=stemcellFile[0].scan(/\d+\.\d+/).last

puts "renaming the stemcell file..."
file = File.basename(stemcellFile[0]).prepend("[stemcells-windows-server,#{version}]")

puts("mv #{stemcellFile[0]} stemcell/#{file}")
system("mv #{stemcellFile[0]} stemcell/#{file}")
