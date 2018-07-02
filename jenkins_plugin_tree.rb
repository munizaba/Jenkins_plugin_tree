require 'net/http'
require 'zip'
require 'fileutils'

pluginName = { 'git' => '3.6.4', 'credentials' => '2.1.16', 'ant' => '1.7' }
# pluginName = {'swarm' =>  '3.10'}

def download(name, version)
  Net::HTTP.start('ftp-nyc.osuosl.org') do |http|
    resp = http.get("/pub/jenkins/plugins/#{name}/#{version}/#{name}.hpi")
    open("#{name}.hpi", 'wb') do |file|
      file.write(resp.body)
    end
  end
  puts "#{name}.hpi_#{version}"
#  destination = "/tmp/bo_plugins/#{name}/#{version}"
#  FileUtils.mkdir_p(destination)
#  FileUtils.copy("/var/lib/jenkins/plugins/#{name}.hpi", destination.to_s)
end

def extract_zip(file, destination)
  FileUtils.mkdir_p(destination)
  Zip::File.open(file) do |zip_file|
    zip_file.each do |f|
      fpath = File.join(destination, f.name)
      zip_file.extract(f, fpath) unless File.exist?(fpath)
    end
  end
  puts "Destination: #{destination}"
end

def listDependencies(dep_name)
  puts "#{dep_name}_unzip/META-INF/MANIFEST.MF"
  f = IO.read("#{dep_name}_unzip/META-INF/MANIFEST.MF")
  #Delete unzip folder
  FileUtils.rm_rf("#{dep_name}_unzip")
  if f.include? 'Plugin-Dependencies: '
    array = (f.split('Plugin-Dependencies: ')[1].split('Plugin-Developers: ')[0]).delete("\r\n ").split(',')
    return array
  else
    return []
  end
end

def listAllDependencies(theseDep)
  @test += 1
  puts "step 3 loop :#{@test}"
  return if @test == 5

  theseDep.each do |child|
    puts 'step 1'
    next if @processedAlready.include?(child)
    puts "step 2 #{child}"
    # values = child.split(":")
    values = child.split(/;/).first.split(':')
    depName = values[0]
    depVersion = values[1]
    download(depName, depVersion)
    extract_zip("#{depName}.hpi", "#{depName}_unzip")
    theseDep = listDependencies(depName.to_s)

    @processedAlready.push child

    if !@hashOfFinalDependences.key?(depName)

      @hashOfFinalDependences[depName] = depVersion
    else

      currentVersion = @hashOfFinalDependences[depName]

      # if (currentVersion < depVersion)
      if Gem::Version.new(currentVersion) < Gem::Version.new(depVersion)

        puts "updating version of #{depName} from #{currentVersion} to #{depVersion}"
        @hashOfFinalDependences[depName] = depVersion
      else
        puts "Old Version detected #{depName}:#{depVersion} keeping #{currentVersion}"
      end
    end

    listAllDependencies(theseDep)
  end
end

# main
@processedAlready = []
@test = 0
@hashOfFinalDependences = {}

pluginName.each do |key, value|
  @hashOfFinalDependences[key] = value

  download(key.to_s, value.to_s)
  extract_zip("#{key}.hpi", "#{key}_unzip/")
  theseDep = listDependencies key.to_s

  puts '========================================='

  theseDep.each do |depPair|
    puts depPair
  end

  puts '=========================================='

  listAllDependencies(theseDep)
end

puts '======================= finished =================='
@hashOfFinalDependences.each do |dpName, dpVersion|
  puts "#{dpName}:#{dpVersion}"
end
puts '======================= finished =================='

#      if array.nil? || array.empty? == true
