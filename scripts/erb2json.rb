#!/usr/bin/env ruby

require 'erb'
require 'json'

def deepcopy(data)
  Marshal.load(Marshal.dump(data))
end

def to_array(data)
  unless data.is_a? Array
    data = [data]
  end
  data
end

def make_data(data, as_json=true)
  if as_json
    JSON.generate(data)
  else
    data
  end
end

def key(data, key, lazy=false)
  if key == "any"
    data['any'] = "key_code"
  elsif key.start_with? "button"
    data['pointing_button'] = key
  else
    data['key_code'] = key
  end
  data['lazy'] = true if lazy
end

# @return [Hash] { "key_code": ".", "modifiers": { "mandatory": [ "..." ], "optional": [ "..." ] } }
# @example
#   <%= from("e", ["command"], ["any"]) %>
#   <%= from("delete_forward", [], ["any"]) %>
#   <%= from("keypad_period") %>
def from(key_code, mandatory_modifiers=[], optional_modifiers=[], as_json=true)
  mandatory_modifiers = to_array(mandatory_modifiers)
  optional_modifiers = to_array(optional_modifiers)

  data = {}
  key(data, key_code)
  mandatory_modifiers.each do |m|
    data['modifiers'] = {} if data['modifiers'].nil?
    data['modifiers']['mandatory'] = [] if data['modifiers']['mandatory'].nil?
    data['modifiers']['mandatory'] << m
  end
  optional_modifiers.each do |m|
    data['modifiers'] = {} if data['modifiers'].nil?
    data['modifiers']['optional'] = [] if data['modifiers']['optional'].nil?
    data['modifiers']['optional'] << m
  end
  make_data(data, as_json)
end

def hash_from(key_code, mandatory_modifiers=[], optional_modifiers=[])
  from(key_code, mandatory_modifiers, optional_modifiers, false)
end

# @return [Array] [ { "key_code": ..., "lazy": true or false } ]
# @example
#   <%= to(["escape"]) %> "Escape" only
#   <%= to([["tab", ["control"]]]) %> "control-tab"
#   <%= to([["f2"], ["t", ["option"]]]) %> "f2", "option-t"
#   <%= to([["t", ["control"], true]]) %> "control-t" with "lazy: true"
#   <%= to([["t", nil, true]]) %> "t" only , with "lazy: true"
def to(events, as_json=true, repeat=1)
  data = []
  events.each do |e|
    d = {}
    if e.is_a? Array
      key(d, e[0])
      unless e[1].nil?
        d['modifiers'] = e[1]
      end
      unless e[2].nil?
        d['lazy'] = true
      end
    elsif e.is_a? String
      key(d, e)
    else
      d = deepcopy(e)
    end
    data << d
  end
  data_total = []
  repeat.times do |i|
    data_total += data
  end
  make_data(data_total, as_json)
end

def hash_to(events, repeat=1)
  to(events, false, repeat)
end

# @return [Array] [ { "shell_command": ... } ] 
# @example
#   <%= set_shell_command(["open -a 'finder'"]) %>
def set_shell_command(commands, as_json=true)
  data =[]
  unless commands.empty?
    commands.each do |command|
      data << { "shell_command" => command }
    end
  else
    $stderr << "name empty.\n"
  end
  make_data(data, as_json)
end

# @return [Array] [ { "type": ... } ]
# @example
#   each_key(
#             source_keys_list: ["1", "2", "3"],
#             dest_keys_list: ["f1", "f2", "f3"],
#             from_mandatory_modifiers: ["fn"]
#             from_optional_modifiers: ["caps_lock"],
#             to_if_alone: ["1", "2", "3"],
#             as_json: true
#           )
def each_key(source_keys_list: :source_keys_list, dest_keys_list: :dest_keys_list, from_mandatory_modifiers: [], from_optional_modifiers: [], to_pre_events: [], to_modifiers: [], to_post_events: [], to_if_alone: [], to_if_alone_modifiers: [], to_after_key_up: [], conditions: [], as_lazy: false, as_json: false)
  unless source_keys_list.is_a? Array
    source_keys_list = [source_keys_list]
    dest_keys_list = [dest_keys_list]
    to_if_alone = [to_array(to_if_alone)]
  end
  data = []
  source_keys_list.each_with_index do |from_key, index|
    to_key = dest_keys_list[index]
    d = {}
    d['type'] = 'basic'
    if from_key.is_a? String
      d['from'] = from(from_key, from_mandatory_modifiers, from_optional_modifiers, false)
    else
      d['from'] = from_key
    end

    # Compile list of events to add to "to" section
    events = []
    to_pre_events.each do |e|
      events << e
    end
    if to_key.is_a? String
      if to_modifiers[0].nil?
        unless as_lazy
          events << [to_key]
        else
          events << [to_key, nil, as_lazy]
        end
      else
        unless as_lazy
          events << [to_key, to_modifiers]
        else
          events << [to_key, to_modifiers, as_lazy]
        end
      end
    elsif to_key.is_a? Array
      to_key.each do |e|
        events << e
      end
    else
      events << to_key
    end
    to_post_events.each do |e|
      events << e
    end
    d['to'] = hash_to(events)

    # Compile list of events to add to "to_if_alone" section
    unless to_if_alone.empty?
      to_if_alone_key = to_if_alone[index]
      to_if_alone_events = []
      if to_if_alone_key.is_a? String
        if to_if_alone_modifiers[0].nil?
          to_if_alone_events << [to_if_alone_key]
        else
          to_if_alone_events << [to_if_alone_key, to_if_alone_modifiers]
        end
      elsif to_if_alone_key.is_a? Array
        to_if_alone_key.each do |e|
          to_if_alone_events << e
        end
      else
        to_if_alone_events << to_if_alone_key
      end
      d['to_if_alone'] = hash_to(to_if_alone_events)
    end
    
    # d['to_if_alone'] = to_if_alone[index] if (to_if_alone[index] and to_if_alone[index].size != 0)
    d['to_after_key_up'] = to_after_key_up unless to_after_key_up.size == 0

    if conditions.any?
      d['conditions'] = []
      conditions.each do |c|
        d['conditions'] << c
      end
    end
    data << d
  end

  make_data(data, as_json)
end

def frontmost_application(type, app_aliases, as_json=true)
  finder_bundle_identifiers = [
    '^com\.apple\.finder$',
  ]

  browser_bundle_identifiers = [
    '^org\.mozilla\.firefox$',
    '^com\.google\.Chrome$',
    '^com\.apple\.Safari$',
  ]

  emacs_bundle_identifiers = [
    '^org\.gnu\.Emacs$',
    '^org\.gnu\.AquamacsEmacs$',
    '^org\.gnu\.Aquamacs$',
    '^org\.pqrs\.unknownapp.conkeror$',
  ]

  remote_desktop_bundle_identifiers = [
    '^com\.microsoft\.rdc$',
    '^com\.microsoft\.rdc\.mac$',
    '^com\.microsoft\.rdc\.osx\.beta$',
    '^net\.sf\.cord$',
    '^com\.thinomenon\.RemoteDesktopConnection$',
    '^com\.itap-mobile\.qmote$',
    '^com\.nulana\.remotixmac$',
    '^com\.p5sys\.jump\.mac\.viewer$',
    '^com\.p5sys\.jump\.mac\.viewer\.web$',
    '^com\.vmware\.horizon$',
    '^com\.2X\.Client\.Mac$',
  ]

  iterm2_bundle_identifiers = [
    '^com\.googlecode\.iterm2$',
  ]
  # TerminalとiTerm2で異なる扱いをしたいので、「ターミナル関係アプリ全部を一括まとめて設定」ではなく、
  # iTerm2以外のアプリを設定する。
  # terminal_bundle_identifiers = iterm2_bundle_identifiers + [
  #   '^com\.apple\.Terminal$',
  #   '^co\.zeit\.hyperterm$',
  #   '^co\.zeit\.hyper$',
  # ]
  terminal_bundle_identifiers = [
    '^com\.apple\.Terminal$',
    '^co\.zeit\.hyperterm$',
    '^co\.zeit\.hyper$',
  ]

  vi_bundle_identifiers = [
    '^org\.vim\.', # prefix
  ]

  virtual_machine_bundle_identifiers = [
    '^com\.vmware\.fusion$',
    '^com\.vmware\.horizon$',
    '^com\.vmware\.view$',
    '^com\.parallels\.desktop$',
    '^com\.parallels\.vm$',
    '^com\.parallels\.desktop\.console$',
    '^org\.virtualbox\.app\.VirtualBoxVM$',
    '^com\.vmware\.proxyApp\.', # prefix
    '^com\.parallels\.winapp\.', # prefix
  ]

  x11_bundle_identifiers = [
    '^org\.x\.X11$',
    '^com\.apple\.x11$',
    '^org\.macosforge\.xquartz\.X11$',
    '^org\.macports\.X11$',
  ]

  word_bundle_identifiers = [
    '^com\.microsoft\.Word$'
  ]
  powerpoint_bundle_identifiers = [
    '^com\.microsoft\.Powerpoint$'
  ]
  excel_bundle_identifiers = [
    '^com\.microsoft\.Excel$'
  ]

  # 自分が追加した。
  chrome_bundle_identifiers = [
    '^com\.google\.Chrome$'
  ]
  # 自分が追加した。
  safari_bundle_identifiers = [
    '^com\.apple\.Safari$'
  ]
  chrome_and_safari_bundle_identifiers = [
    '^com\.google\.Chrome$',
    '^com\.apple\.Safari$'
  ]

  # 自分が追加した。
  atom_bundle_identifiers = [
    '^com\.github\.atom$'
  ]
  
  # 自分が追加した。
  coteditor_bundle_identifiers = [
    'com\.coteditor\.CotEditor$'
  ]
  
  # 自分が追加した。
  cura_bundle_identifiers = [
    'nl\.ultimaker\.cura$'
  ]
  
  # 自分が追加した。
  meshmixer_bundle_identifiers = [
    'com\.meshmixer\.meshmixer09$'
  ]

  # ----------------------------------------

  bundle_identifiers = []

  to_array(app_aliases).each do |app_alias|
    case app_alias
    when 'finder'
      bundle_identifiers.concat(finder_bundle_identifiers)

    when 'iterm2'
      bundle_identifiers.concat(iterm2_bundle_identifiers)

    when 'terminal'
      bundle_identifiers.concat(terminal_bundle_identifiers)

    when 'emacs'
      bundle_identifiers.concat(emacs_bundle_identifiers)

    when 'emacs_key_bindings_exception'
      bundle_identifiers.concat(emacs_bundle_identifiers)
      bundle_identifiers.concat(remote_desktop_bundle_identifiers)
      bundle_identifiers.concat(terminal_bundle_identifiers)
      bundle_identifiers.concat(vi_bundle_identifiers)
      bundle_identifiers.concat(virtual_machine_bundle_identifiers)
      bundle_identifiers.concat(x11_bundle_identifiers)

    when 'remote_desktop'
      bundle_identifiers.concat(remote_desktop_bundle_identifiers)

    when 'vi'
      bundle_identifiers.concat(vi_bundle_identifiers)

    when 'virtual_machine'
      bundle_identifiers.concat(virtual_machine_bundle_identifiers)

    when 'browser'
      bundle_identifiers.concat(browser_bundle_identifiers)

    when 'word'
      bundle_identifiers.concat(word_bundle_identifiers)

    when 'powerpoint'
      bundle_identifiers.concat(powerpoint_bundle_identifiers)

    when 'excel'
      bundle_identifiers.concat(excel_bundle_identifiers)

    when 'office'
      bundle_identifiers.concat(word_bundle_identifiers)
      bundle_identifiers.concat(powerpoint_bundle_identifiers)
      bundle_identifiers.concat(excel_bundle_identifiers)

    when 'vim_emu'
      bundle_identifiers.concat(emacs_bundle_identifiers)
      bundle_identifiers.concat(remote_desktop_bundle_identifiers)
      bundle_identifiers.concat(terminal_bundle_identifiers)
      bundle_identifiers.concat(vi_bundle_identifiers)
      bundle_identifiers.concat(virtual_machine_bundle_identifiers)
      bundle_identifiers.concat(x11_bundle_identifiers)
      bundle_identifiers.concat(remote_desktop_bundle_identifiers)
      bundle_identifiers.concat(virtual_machine_bundle_identifiers)
      bundle_identifiers.concat(browser_bundle_identifiers)

    # 自分が追加した。
    when 'chrome'
      bundle_identifiers.concat(chrome_bundle_identifiers)

    # 自分が追加した。
    when 'safari'
      bundle_identifiers.concat(safari_bundle_identifiers)

    # 自分が追加した。
    when 'chrome_and_safari'
      bundle_identifiers.concat(chrome_and_safari_bundle_identifiers)

    # 自分が追加した。
    when 'atom'
      bundle_identifiers.concat(atom_bundle_identifiers)
    
    # 自分が追加した。
    when 'coteditor'  
      bundle_identifiers.concat(coteditor_bundle_identifiers)
    
    # 自分が追加した。
    when 'cura'  
      bundle_identifiers.concat(cura_bundle_identifiers)
    
    # 自分が追加した。
    when 'meshmixer'  
      bundle_identifiers.concat(meshmixer_bundle_identifiers)

    else
      $stderr << "unknown app_alias: #{app_alias}\n"
    end
  end

  unless bundle_identifiers.empty?
    data = {
      "type" => type,
      "bundle_identifiers" => bundle_identifiers
    }
    make_data(data, as_json)
  end
end

# @return [Hash] { "type": "frontmost_application_if", "bundle_identifiers": [ "..." ] }
# @example
#   <%= frontmost_application_if("remote_desktop") %>
def frontmost_application_if(app_aliases, as_json=true)
  frontmost_application('frontmost_application_if', app_aliases, as_json)
end

# @return [Hash] { "type": "frontmost_application_unless", "bundle_identifiers": [ "..." ] }
# @example
#   <%= frontmost_application_unless("remote_desktop") %>
def frontmost_application_unless(app_aliases, as_json=true)
  frontmost_application('frontmost_application_unless', app_aliases, as_json)
end

# @return [Hash] { "set_variable": { "name": "...", "value": @ } }
# @example
#   <%= set_variable(["press_period_key"], [0]) %>
def set_variable(names, values, as_json=true)
  data =[]
  unless names.empty?
    names.each_with_index do |name, index|
      data = {
        "set_variable" => {
          "name" => name,
          "value" => values[index]
        }
      }
    end
  else
    $stderr << "name empty.\n"
  end
  make_data(data, as_json)
end

def variable(type, names, values, as_json=true)
  data =[]
  unless names.empty?
    names.each_with_index do |name, index|
      data = {
        "type" => type,
        "name" => name,
        "value" => values[index]
      }
    end
  else
    $stderr << "name empty.\n"
  end
  make_data(data, as_json)
end

# @return [Hash] { "type": "variable_if", "name": "...", "value": @ }
# @example
#   <%= variable_if(["press_period_key"], [1]) %>
def variable_if(names, values, as_json=true)
  variable('variable_if', names, values, as_json)
end

# @return [Hash] { "type": "variable_unless", "name": "...", "value": @ }
# @example
#   <%= variable_unless(["press_period_key"], [0]) %>
def variable_unless(names, values, as_json=true)
  variable('variable_unless', names, values, as_json)
end

def device(type, device_aliases, as_json=true)
  hhkb_id = {"vendor_id": 2131}

  # ----------------------------------------

  ids = []

  to_array(device_aliases).each do |device_alias|
    case device_alias
    when 'hhkb'
      ids << hhkb_id

    else
      $stderr << "unknown hhkb_alias: #{device_aliases}\n"
    end
  end

  unless ids.empty?
    data = {
      "type" => type,
      "identifiers" => ids
    }
    make_data(data, as_json)
  end
end

def device_if(device_aliases, as_json=true)
  device('device_if', device_aliases, as_json)
end

def device_unless(app_aliases, as_json=true)
  device('device_unless', device_aliases, as_json)
end

# https://github.com/rcmdnk/KE-complex_modifications/blob/df08afdaa9d28ad3c6d3dfd3d0b6c2924f195069/scripts/erb2json.rb#L347-L377
def input_source(type, input_source_aliases, as_json=true)
  input_sources = []
  to_array(input_source_aliases).each do |input_source_alias|
    if input_source_alias.is_a? Hash
      input_sources << input_source_alias
    end
    if input_source_alias.include?("keylayout")
      input_sources << { "input_source_id": input_source_alias}
    elsif input_source_alias.include?("inputmethod")
      input_sources << { "input_mode_id": input_source_alias}
    else
      input_sources << { "language": input_source_alias}
    end
  end

  unless input_sources.empty?
    data = {
      "type" => type,
      "input_sources" => input_sources
    }
    make_data(data, as_json)
  end
end

# @return [Hash] { "type": "input_source_if", "input_sources": [ { "language": ".." } ] }
# @example
#   <%= input_source_if("ja") %>
def input_source_if(input_source_aliases, as_json=true)
  input_source('input_source_if', input_source_aliases, as_json)
end

# @return [Hash] { "type": "input_source_unless", "input_sources": [ { "language": ".." } ] }
# @example
#   <%= input_source_unless("en") %>
def input_source_unless(input_source_aliases, as_json=true)
  input_source('input_source_unless', input_source_aliases, as_json)
end

# @return [Hash] { "mouse_key": { "...":  "..."  } }
# @example
#   <%= mouse_key("horizontal_wheel", 128) %>
#   <%= mouse_key("x", 956) %>
def mouse_key(type, value, as_json=true)
  unless type.empty?
    data = {
      "mouse_key" => {
        type => value
      }
    }
  else
    $stderr << "type empty.\n"
  end
  make_data(data, as_json)
end

number_letters = ("1".."9").to_a
alphabet_letters = ("a".."z").to_a
other_letters = ["spacebar", "hyphen", "equal_sign", "open_bracket", "close_bracket", "backslash", "non_us_pound", "semicolon", "quote", "grave_accent_and_tilde", "comma", "period", "slash"]
all_letters = number_letters + alphabet_letters + other_letters
all_letters_array = []
all_letters.each do |l|
  all_letters_array.push([l])
end

template = ERB.new $stdin.read
puts JSON.pretty_generate(JSON.parse(template.result))
# puts template.result
