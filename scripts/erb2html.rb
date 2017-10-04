#!/usr/bin/env ruby

require 'erb'
require 'json'

include ERB::Util

def file_import_panel(json_file)
  if json_file =~ /^docs\/json\/[^\/]+.json/
    json_file_path = json_file
    json_file = json_file_path.split("/")[-1]
  else
    json_file_path = "docs/json/#{json_file}"
  end
  json_name = json_file.gsub(/.json$/, '')
  title = ''
  rule_descriptions = ''
  make_extra_description = false

  File.open(json_file_path) do |f|
    data = JSON.parse(f.read)
    title = h(data['title'])
    make_extra_description = data['make_extra_description'] if data.key?('make_extra_description')
    rule_list = data.key?('rule_list') ? data['rule_list'] : true
    if rule_list
      data['rules'].each do |rule|
        rule_descriptions += '<div class="list-group-item">' + h(rule['description']) + '</div>'
      end
    end
  end

  extra_description_file_path = "src/extra_descriptions/#{json_file}.html"

  if make_extra_description
    make = true
    if FileTest.exist?(extra_description_file_path) and File.mtime(extra_description_file_path) - File.mtime(json_file_path) > 0
      make = false
    end
    if make
      cmd = "scripts/json2exhtml.rb < #{json_file_path} > #{extra_description_file_path}"
      unless system(cmd)
        raise "Error at: #{cmd}"
      end
    end
  end

  if FileTest.exist?(extra_description_file_path)
    File.open(extra_description_file_path) do |f|
      rule_descriptions += '<div class="list-group-item">' + f.read + '</div>'
    end
  end

  <<-EOS
    <div class="panel panel-default">
      <div class="panel-heading">
        <a class="panel-title btn btn-link" role="button" data-toggle="collapse" href="##{json_name}" aria-expanded="false" aria-controls="#{json_name}">#{title}</a>
        <a class=\"btn btn-primary btn-sm pull-right\" data-json-path=\"json/#{json_file}\">Import</a>
      </div>
      <div class="list-group collapse" id="#{json_name}">
          #{rule_descriptions}
      </div>
    </div>
  EOS
end

def add_group(title,id,json_files)

  $toc << "<li class=\"list-group-item\"><span class=\"badge\">#{json_files.length}</span><a href=\"##{id}\">#{title}</a></li>"

  group_content = ""
  json_files.each do |json|
    group_content += file_import_panel(json)
  end
  $groups += <<-EOS
      <div class="panel panel-primary" id="#{id}">
        <div class="panel-heading">
          <h3 class="panel-title">#{title}</h3>
        </div>
        <div class="panel-body">
          #{group_content}
        </div>
      </div>
  EOS
end

def render_toc()
  toc_content = "<ul class=\"toc list-group\">"
  toc_content += "<li class=\"list-group-item list-group-item-info\">Table of Contents</li>"
  $toc.each do |toc_item|
    toc_content += toc_item
  end
  toc_content += "</ul>"
  toc_content
end

template = ERB.new $stdin.read
puts template.result
