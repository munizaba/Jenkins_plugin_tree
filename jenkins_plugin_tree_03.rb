require 'net/http'
require 'zip'
require 'fileutils'

#@pluginName = { 'git' => '3.6.4', 'credentials' => '2.1.16', 'ant' => '1.7', 'xlrelease-plugin' => '7.5.1' }
@pluginName = { 'xlrelease-plugin' => '7.5.1' }
@generate_nexus_structure = true
@jenkins_plugin_dir = "/Users/dusanmunizaba/tmp/"

def generate_nexus_structure(name, version)
  tree_destination = "#{@jenkins_plugin_dir}nexus_tree/#{name}/#{version}"
  FileUtils.mkdir_p(tree_destination)
  FileUtils.copy("#{@jenkins_plugin_dir}#{name}.hpi", tree_destination.to_s)
end

def download(name, version)
  Net::HTTP.start('ftp-nyc.osuosl.org') do |http|
    resp = http.get("/pub/jenkins/plugins/#{name}/#{version}/#{name}.hpi")
    open("#{@jenkins_plugin_dir}#{name}.hpi", 'wb') do |file|
      file.write(resp.body)
    end
  end
  puts "#{@jenkins_plugin_dir}#{name}.hpi_#{version}"
  generate_nexus_structure(name, version) if @generate_nexus_structure
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
  file_content = ''
  separator = ' '

  begin
    manifest = File.open("#{@jenkins_plugin_dir}#{dep_name}_unzip/META-INF/MANIFEST.MF", 'r')
    manifest.each_line do |line|
      if line.start_with?(separator)
        file_content = file_content[0...-2]
        line = line[1...line.size]
        puts line
      end
      file_content << line
    end
  ensure
    FileUtils.rm_rf("#{@jenkins_plugin_dir}#{dep_name}_unzip")
    manifest.close
  end
  puts file_content
  return [] unless file_content.include? 'Plugin-Dependencies:'
  (file_content.split('Plugin-Dependencies: ')[1].split("\n")[0]).delete("\r\n ").split(',')
end

def listAllDependencies(theseDep)

  theseDep.each do |child|
    puts 'step 1'

    values = (child.split(/;/).first).split(":")
    depName = values[0]
    depVersion = values[1]

    if Gem::Version.new(@pluginName[depName]) > Gem::Version.new(depVersion)
      puts "Requested version is higher than dependency version, No need to download again!"
      puts "Upgradgin from #{depVersion} to #{@pluginName[depName]}"
      depVersion = @pluginName[depName]
    end

    currentVersion = @hashOfFinalDependences[depName]

    puts "IN FINAL #{currentVersion}"
    puts Gem::Version.new(currentVersion) < Gem::Version.new(depVersion)

    if ((not @processedAlready.include?(child) and currentVersion == nil) or Gem::Version.new(currentVersion) < Gem::Version.new(depVersion))

      puts "step 2 #{child}"
      download(depName, depVersion)
      extract_zip("#{@jenkins_plugin_dir}#{depName}.hpi", "#{@jenkins_plugin_dir}#{depName}_unzip")
      theseDep = listDependencies(depName.to_s)

      @processedAlready.push child

      if not (@hashOfFinalDependences.key?(depName))
        @hashOfFinalDependences[depName] = depVersion
      else

        currentVersion = @hashOfFinalDependences[depName]

        # Get latest version
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
end

# main
@processedAlready = []
@hashOfFinalDependences = {}

@pluginName.each do |key, value|
  @hashOfFinalDependences[key] = value

  download(key.to_s, value.to_s)
  extract_zip("#{@jenkins_plugin_dir}#{key}.hpi", "#{@jenkins_plugin_dir}#{key}_unzip/")
  puts 'before listDependencies'
  theseDep = listDependencies key.to_s
  puts theseDep.to_s
  puts 'after listDependencies'

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
