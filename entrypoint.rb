#!/usr/bin/env ruby

require "md_to_pdf"
require "yaml"
require "optparse"
require "tempfile"
require "net/http"
require "uri"
require "open-uri"

options = {
  root_dir: ENV.fetch("MD2PDF_WORK_DIR", Dir.pwd),
  config: ENV.fetch("MD2PDF_CONFIG_FILE", nil),
  styling_dir: ENV.fetch("MD2PDF_STYLING_DIR", nil),
  nc_user: ENV.fetch("NEXTCLOUD_USERNAME", nil),
  nc_key: ENV.fetch("NEXTCLOUD_APP_ACCESS_KEY", nil),
  nc_path: ENV.fetch("NEXTCLOUD_UPLOAD_PATH", nil),
  skip_upload: ENV.fetch("MD2PDF_SKIP_UPLOAD", nil),
}
op = OptionParser.new
op.banner = "Usage: entrypoint.rb [options]"
op.on("-r", "--root WORKING_DIR", "the root folder for relative paths") { |o| options[:root_dir] = o }
op.on("-c", "--config CONFIG_FILENAME", "the config file for the action (relative path)") { |o| options[:config] = o }
op.on("-s", "--styling STYLING_DIRECTORY", "the folder from where styling files are loaded (relative path)") { |o| options[:styling_dir] = o }
op.on("-t", "--skip_upload", "the skip the upload for testing") { |o| options[:skip_upload] = "true" }
op.on("-u", "--nc_user", "the Nextcloud user to upload with") { |o| options[:nc_user] = o }
op.on("-u", "--nc_key", "the Nextcloud app access key to upload with") { |o| options[:nc_key] = o }
op.on("-u", "--nc_path", "the full url and path to Nextcloud folder to upload to") { |o| options[:nc_path] = o }
op.on("-h", "--help") do
  puts op.to_s
  exit
end
op.on("-v", "--version") do
  puts MarkdownToPDF::VERSION
  exit
end

class Uploader
  MIMETYPE = "application/pdf"

  def initialize(options)
    @options = options
  end

  def upload(entry)
    filename = File.join(@options[:destination_root], entry)
    destination = "#{@options[:nc_path]}#{entry}"
    puts "Uploading"
    puts "   from: #{filename}"
    puts "   to: #{destination}"
    uri = URI.parse(URI.encode(destination))
    header = { "Content-Type": MIMETYPE }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Put.new(uri.request_uri, header)
    request.content_type = MIMETYPE
    request.basic_auth(@options[:nc_user], @options[:nc_key])
    request.body = open(filename).read
    response = http.request(request)
    if response.code.to_i >= 400
      raise Exception.new "Upload failed: #{response.code} #{response.message}"
    end
    puts "   => Response: #{response.code} #{response.message}"
  end

  def run(uploads)
    uploads.each { |entry| upload(entry) }
  end
end

class Generator
  def initialize(options)
    @options = options
    @generated = []
  end

  def convert_doc(source_filename, dest_filename, styling_filename, data)
    puts "Generating pdf"
    puts "   from: #{source_filename}"
    puts "   with: #{styling_filename}"
    puts "   to:   #{dest_filename}"
    markdown = File.read(source_filename).to_s
    parsed = FrontMatterParser::Parser.new(:md).call(markdown)
    matter = (parsed.front_matter || {}).merge(data)
    content = "#{matter.to_yaml({ line_width: -1 })}---\n\n#{parsed.content}"
    MarkdownToPDF.generate_markdown_string_pdf(content, styling_filename, File.dirname(source_filename), dest_filename)
  end

  def convert_entry(entry, default_data)
    doc = {}.merge(default_data).merge(entry)
    styling = doc.delete("styling")
    raise Exception, "no styling for entry #{doc}" if styling.nil?

    styling_file = File.join(@options[:root_dir], @options[:styling_dir], "#{styling}.yml")
    raise Exception.new "styling file not found #{styling_file} for entry #{entry}" unless File.exist?(styling_file)

    source = doc.delete("source")
    raise Exception.new "no source for entry #{entry}" if source.nil?
    source_file = File.join(@options[:root_dir], source)
    raise Exception.new "source file not found #{source_file} for entry #{entry}" unless File.exist?(source_file)

    destination = doc.delete("destination")
    raise Exception.new "no destination for entry #{entry}" if destination.nil?
    destination_file = File.join(@options[:destination_root], destination)
    FileUtils.mkdir_p File.dirname(destination_file)

    convert_doc(source_file, destination_file, styling_file, doc)
    @generated << destination
  end

  def convert_group(group)
    default_data = group["default"] || {}
    docs = group["documents"] || []
    docs.each do |doc|
      convert_entry(doc, default_data)
    end
  end

  def run
    config = YAML.load_file(File.join(@options[:root_dir], @options[:config]))
    config = [config] unless config.is_a?(Array)
    config.each { |group| convert_group(group) }
    @generated
  end
end

begin
  op.parse!(ARGV)

  raise OptionParser::MissingArgument, "ENV:MD2PDF_CONFIG_FILE is required" if options[:config].nil? || options[:config].empty?
  raise OptionParser::InvalidArgument, "File in ENV:MD2PDF_CONFIG_FILE must exist" unless File.exist?(File.join(options[:root_dir], options[:config]))
  raise OptionParser::MissingArgument, "ENV:MD2PDF_STYLING_DIR is required" if options[:styling_dir].nil? || options[:styling_dir].empty?
  raise OptionParser::InvalidArgument, "Dir in ENV:MD2PDF_STYLING_DIR must exist" unless Dir.exist?(File.join(options[:root_dir], options[:styling_dir]))
  unless options[:skip_upload] == "true" || options[:skip_upload] == "1"
    raise OptionParser::MissingArgument, "ENV:NEXTCLOUD_USERNAME is required for uploading" if options[:nc_user].nil? || options[:nc_user].empty?
    raise OptionParser::MissingArgument, "ENV:NEXTCLOUD_UPLOAD_PATH is required for uploading" if options[:nc_path].nil? || options[:nc_path].empty?
    raise OptionParser::MissingArgument, "ENV:NEXTCLOUD_APP_ACCESS_KEY is required for uploading" if options[:nc_key].nil? || options[:nc_key].empty?
  end

  options[:destination_root] = Dir.mktmpdir("md2pdf-generated")
  generated = Generator.new(options).run
  Uploader.new(options).run(generated) unless options[:skip_upload] || generated.empty?
rescue Exception => ex
  puts ex.message
  exit 1
end

