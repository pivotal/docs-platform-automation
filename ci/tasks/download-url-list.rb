require 'tempfile'
require 'toml-rb'
require "open-uri"
require "fileutils"
require 'tmpdir'
require 'yaml'

require_relative 'package.rb'

# From a file!
path = ARGV[0]
interaction_type = ARGV[1]
manifest_path = ARGV[2]

def get_packages(path)
  # whitelist Date as a possible class to load because it exists inside other parts of manifest.yml

  if Pathname(path).extname.include?('toml')
    manifest = TomlRB.load_file(path)['metadata']
    id_property_name = 'id'
  else
    manifest = YAML.safe_load(File.open(path), permitted_classes: [Date, Symbol])
    id_property_name = 'name'
  end

  return [] unless manifest.key?('dependencies')

  manifest['dependencies'].map do |dependency|
    ::UrlList::Package.new(
      name: dependency[id_property_name],
      version: dependency['version'],
      source_url: dependency['source']
    )
  end
end

def download(url, path)
  case io = URI.open(url)
  when StringIO then File.open(path, 'w') { |f| f.write(io.read) }
  when Tempfile then io.close; FileUtils.mv(io.path, path)
  end
end

puts "URL list: #{path}"
puts "Interaction type: #{interaction_type}"
puts "Manifest path: #{manifest_path}"

packages = get_packages(path)

manifest = {}

packages.each do |package|
  dir = Dir.mktmpdir

  package_key = "other:#{package.name}:#{package.version}"
  manifest[package_key] = {
    "name"=>package.name,
    "version"=>package.version,
    "repository"=>"Other",
    "interactions"=>[interaction_type]
  }

  if package.source_url.nil?
    puts "Warning: #{package.name} #{package.version} has empty source field. This script will leave out the 'other-distribution' field in the resulting manifest. But that means you have to set OSSTP_LOAD_FORCE_LOAD to true and upload the source code for this pacakge at some later time."
  else
    uri = URI.parse(package.source_url)
    basename = File.basename(uri.path)
  
    filepath = File.join(dir, basename)
  
    puts "Download to: #{filepath}"
    download(package.source_url, filepath)
  
    manifest[package_key]["other-distribution"] = filepath
  end
end

puts "Output path: #{manifest_path}"

if manifest.size == 0
  puts "Warning: No packages, outputting empty manifest"
  File.write(manifest_path, '')
else
  puts
  puts "Generated manifest:"
  puts manifest.to_yaml
  puts
  
  File.write(manifest_path, manifest.to_yaml)
end
