#!/usr/bin/env ruby

require 'json'
require 'pp'
require 'fileutils'

def data_directory
  myfile = __FILE__
  if File.symlink? myfile
    myfile = File.readlink myfile
  end
  File.dirname(myfile)
end

def data_file_path(filename)
  mydir = data_directory
  if File.split(filename).first == "data"
    File.join(mydir, filename)
  else
    File.join(mydir, "data", filename)
  end
end

def bits_packing_rule(bits)
  case bits
  when 32; [4, "L>"]
  when 16; [2, "S>"]
  when 8; [1, "C"]
  when :s32; [4, "l>"]
  when :s16; [2, "s>"]
  when :s16be; [2, "s>"]
  when :s16le; [2, "s<"]
  end
end
def read_word(context, bits)
  len, format = bits_packing_rule bits
  bytes = context.read(len)
  if bytes.nil? or bytes.length != len
    actual = !bytes.nil? && bytes.length || 0
    raise "short read in read_word, trying to read #{len} bytes, got #{actual}"
  end
  bytes.unpack(format).first
end

def repeated_get(context, count, format)
  count.times do
    format.get(context)
  end
end

class SerializeContext
  def initialize(root, stream)
    @nodes = root
    @path = []
    @current = root
    @stream = stream
    @warnings = []

    @indexes = {}
  end

  def warn(str)
    raise str
    @warnings << str
  end

  def focus_node(name)
    parent = @current
    @path << name
    path_str = @path.join('/')
    @current = @current[name]

    @indexes[path_str] ||= 0

    if @current.nil?
      raise "entered invalid node by key #{name}, path=#{path_str}"
    end

    handling_array = @current.is_a? Array
    if handling_array
      @current = @current[@indexes[path_str]]
      @path << @indexes[path_str]
      @indexes[path_str] += 1
    end

    result = yield

    @path.pop if handling_array
    @current = parent
    @path.pop

    result
  end

  def get_value_length(name)
    x = @current[name]
    if x.is_a? Array
      return x.length
    elsif x.nil?
      return 0
    else
      return 1
    end
  end

  def get_value(name = nil)
    if name.nil?
      @current
    else
      if @current.has_key? name
        focus_node name do
          @current
        end
      end
    end
  end
  alias :get_relative :get_value

  def write(bytes)
    @stream.write(bytes)
  end
  def ensure_value(name, type)
    v = get_value name
    if v.nil?
      warn "missing key #{name}"
      return nil
    elsif !v.is_a? type
      actual_type = v.class
      pp v
      warn "invalid type for key #{name} expected #{type.to_s} got #{actual_type.to_s}"
      return nil
    else
      return v
    end
  end
end

class ParseContext
  attr_reader :result

  def initialize(stream)
    @stream = stream
    @parents = []
    @result = @current = {}
  end

  def read(n)
    @stream.read(n)
  end
  def skip(n)
    @stream.seek(n, IO::SEEK_CUR)
  end
  def eof?
    @stream.eof?
  end

  def get_relative(path)
    node = @current
    path.split("/").each do |x|
      node = node[x]
    end
    node
  end

  def push_node(name)
    @parents << @current
    # need to enusre that current is new or a collection
    if !@current.has_key? name
      @current = @current[name] = {}
    else
      if @current[name].is_a? Hash
        @current[name] = [@current[name]]
      end
      new_node = {}
      @current[name] << new_node
      @current = new_node
    end
  end

  def append_value(name, value)
    if @current.has_key? name
      if !@current[name].is_a? Array
        @current[name] = [@current[name]]
      end
      @current[name] << value
    else
      @current[name] = value
    end
  end

  def pop_node
    @current = @parents.pop
  end
end

class UntilEOF
  attr_accessor :child
  def initialize(child)
    self.child = child
  end
  def get(context)
    until context.eof?
      child.get(context)
    end
  end
end

class FormatPrimitive
  attr_accessor :name
  def initialize(name)
    self.name = name
  end
  def get(context)
    raise "FormatPrimitive #{self.class} does not support get"
  end
  def put(context)
    raise "FormatPrimitive #{self.class} does not support put"
  end
end

class Word < FormatPrimitive
  attr_accessor :bits
  def initialize(name, bits)
    super(name)
    self.bits = bits
  end
  def get(context)
    context.append_value(name, read_word(context, self.bits))
  end
  def put(context)
    if (value = context.ensure_value(name, Fixnum)) != nil
      _, format = bits_packing_rule self.bits
      context.write [value].pack(format)
    end
  end
end

class LIterate
  attr_accessor :bits, :child
  def initialize(bits, child)
    self.bits = bits
    self.child = child
  end
  def get(context)
    count = read_word(context, self.bits)
    repeated_get(context, count, child)
  end
  def put(context)
    collection_name = self.child.name # FIXME: hmmmmmmm
    _, format = bits_packing_rule self.bits
    len = context.get_value_length(collection_name)
    context.write [len].pack(format)
    len.times do |x|
      self.child.put context
    end
  end
end

class HideBytes < FormatPrimitive
  attr_accessor :length, :keep
  def initialize(name, length, keep = false)
    super(name)
    self.length = length
    self.keep = keep
  end
  def get(context)
    @@idx = (@@idx || 0) + 1
    if self.keep && self.length > 10
      data = context.read(self.length)
      filename = "keep-bytes-#{@@idx}"
      File.open(filename, "w") { |f| f.write data }
      context.append_value(name, "saved #{self.length} bytes to #{filename}")
    else
      context.skip(self.length)
      context.append_value(name, "hid #{self.length} bytes")
    end
  end
  @@idx = 0
end

class LString < FormatPrimitive
  attr_accessor :bits
  def initialize(name, bits)
    super(name)
    self.bits = bits
  end
  def get(context)
    len = read_word(context, 32)
    string = context.read(len)
    context.append_value(name, string)
  end
  def put(context)
    if (value = context.ensure_value(name, String)) != nil
      _, format = bits_packing_rule self.bits
      context.write [value.length, value].pack(format + "a*")
    end
  end
end

class Bytes < FormatPrimitive
  attr_accessor :len
  def initialize(name, len)
    super(name)
    self.len = len
  end
  def get(context)
    data = context.read(len)
    hex_data = data.gsub(/./m) { |x| "%.2x " % x.ord }
    data = data.encode('utf-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
    context.append_value(name, hex_data + " | " + data)
  end
end

class Collection < FormatPrimitive
  attr_accessor :children

  def initialize(name = nil, &block)
    super(name)
    self.children = []
    if block_given?
      if block.arity == 1
        yield self
      else
        instance_eval &block
      end
    end
  end

  def get(context)
    context.push_node(name) unless name.nil?
    self.children.each do |c|
      c.get(context)
    end
    context.pop_node unless name.nil?
  end

  def put(context)
    if !name.nil?
      context.focus_node(name) do
        self.children.each { |c| c.put context }
      end
    else
      self.children.each { |c| c.put context }
    end
  end

  def push_child(c)
    self.children << c
    c
  end

  def u8(name)
    push_child Word.new(name, 8)
  end
  def u16(name)
    push_child Word.new(name, 16)
  end
  def u32(*names)
    c = nil
    names.each do |name|
      c = push_child Word.new(name, 32)
    end
    c
  end
  def collection(name, &block)
    push_child Collection.new(name, &block)
  end
  def l_iterate(bits = 32, &block)
    push_child  LIterate.new(bits, yield)
  end
  def l_string(name, bits = 32)
    push_child LString.new(name, bits)
  end
  def l_bytes(name, bits = 32)
    push_child LBytes.new(name, bits)
  end
  def bytes(name, len)
    push_child Bytes.new(name, len)
  end
  def expand(&block)
    push_child Expand.new(block)
  end
  def until_eof
    push_child UntilEOF.new(yield)
  end
end

def parse(format, stream)
  ctx = ParseContext.new(stream)
  begin
    format.get(ctx)
  rescue
    pp ctx
    raise
  end
  ctx
end

def serialize(format, data, stream)
  ctx = SerializeContext.new(data, stream)
  format.put(ctx)
  ctx
end

class Expand
  attr_accessor :expansion_method
  def initialize(expansion_method)
    self.expansion_method = expansion_method
  end
  def get(context)
    format = expansion_method.call context
    format.get context unless format.nil?
  end
  def put(context)
    format = expansion_method.call context
    format.put context unless format.nil?
  end
end

def client_format
  Collection.new "client" do
    bytes "version", 12
    bytes "auth-type", 1
    bytes "username", 24
    bytes "password", 24
    collection "client-init" do
      u8 "shared-session"
    end
    until_eof do
      Collection.new "message" do
        u8 "id"
        expand do |ctx|
          tag = ctx.get_relative("id")
          Collection.new do
            case tag
            when 0x0
              bytes "padding", 3
              collection "client-pixel-format" do
                u8 "bits-per-pixel"
                u8 "depth"
                u8 "big-endian-flag"
                u8 "true-color-flag"
                u16 "red-max"
                u16 "blue-max"
                u16 "green-max"
                u8 "red-shift"
                u8 "blue-shift"
                u8 "green-shift"
                bytes "padding", 3
              end
            when 0x2
              bytes "padding", 1
              collection "encoding-list" do
                l_iterate 16 do
                  Word.new "encoding", 32
                end
              end
            when 0x3
              collection "frame-update-request" do
                u8 "incremental"
                u16 "x-pos"
                u16 "y-pos"
                u16 "width"
                u16 "height"
              end
            when 0x4
              collection "key-event" do
                bytes "padding1", 1
                u8 "down-flag"
                bytes "padding2", 2
                u32 "key"
                bytes "padding3", 9
              end
            when 0x5
              collection "mouse-event" do
                u8 "padding1"
                u8 "button"
                u16 "x"
                u16 "y"
                bytes "padding2", 11
              end
            when 0x07
              u16 "resync-mouse-event"
            when 0x16
              bytes "keep-alive-event/sync-kb-led", 1
            when 0x19 # "front-ground-event"
            when 0x37 # "mouse-get-info"
            when 0x3c # "get-viewer-lang"
            else
              raise "Unknown tag '#{tag}'"
            end
          end
        end
      end
    end
  end
end

def server_format
  Collection.new "server" do
    bytes "version", 12
    l_iterate 8 do
      Word.new "security-type", 8
    end
    bytes "aten-unknown-1", 24
    u32 "security-result"
    u16 "framebuffer-width"
    u16 "framebuffer-height"
    collection "server-pixel-format" do
      u8 "bits-per-pixel"
      u8 "depth"
      u8 "big-endian-flag"
      u8 "true-color-flag"
      u16 "red-max"
      u16 "blue-max"
      u16 "green-max"
      u8 "red-shift"
      u8 "blue-shift"
      u8 "green-shift"
      bytes "padding", 3
    end
    l_string "server-name", 32
    bytes "aten-unknown-2", 8
    collection "server-init" do
      u8 "IKVMVideoEnable"
      u8 "IKVMKMEnable"
      u8 "IKVMKickEnable"
      u8 "VUSBEnable"
    end
    until_eof do
      Collection.new "message" do
        u8 "id"
        expand do |ctx|
          tag = ctx.get_relative("id")
          Collection.new do
            case tag
            when 0
              bytes "padding", 1
              l_iterate 16 do
                Collection.new do
                  u16 "x"
                  u16 "y"
                  u16 "width"
                  u16 "height"
                  u32 "encoding-type" # TODO s32
                  collection "aten-unknown" do
                    bytes "unknown1", 4
                    u32 "data-len"
                  end
                  expand do |c|
                    # todo bpp can't use any kind of get_relative,
                    # since server-pixel-format.bpp = 32, not 16 as
                    # actually present
                    encoding = c.get_relative("encoding-type")
                    case encoding
                    when 0
                    when 89
                    else
                      raise "Unknown encoding '#{encoding}'"
                    end
                    data_len = c.get_relative("aten-unknown/data-len")
                    Collection.new "frame-data" do
                      push_child frame_format
                    end
                  end
                end
              end
            when 0x04
              bytes "front-ground-event", 20
            when 0x16
              bytes "keep-alive-event", 1
            when 0x33
              bytes "video-get-info", 4
            when 0x37
              bytes "mouse-get-info", 2
            when 0x39
              u32 "get-session-msg-1"
              u32 "get-session-msg-2"
              bytes "get-session-msg", 0x100
            when 0x3c
              bytes "get-viewer-lang", 8
            else
              raise "Unknown tag '#{tag}'"
            end
          end
        end
      end
    end
  end
end

def frame_format
  Collection.new "frame" do
    u8 "type"
    bytes "padding", 1
    expand do |ctx|
      type = ctx.get_relative("type")
      case type
      when 0
        # subrects
        Collection.new "blocks" do
          u32 "total-segments"
          u32 "total-len"
          expand do |ctx|
            segments = ctx.get_relative("total-segments")
            Collection.new "blocks" do
              segments.times do
                collection "block" do
                  push_child Word.new("a", :s16le)
                  push_child Word.new("b", :s16le)
                  u8 "y"
                  u8 "x"
                  push_child HideBytes.new("block", 16 * 32, false)
                end
              end
            end
          end
        end
      when 1
        # raw
        Collection.new "raw" do
          bytes "unknown", 4
          u32 "total-len"
          expand do |ctx|
            len = ctx.get_relative("total-len")
            HideBytes.new("raw-data", len - 10, false)
          end
        end
      else
        raise "Unknown type '#{type}'"
      end
    end
  end
end

def format_to_json(format)
  pcontext = parse(format, STDIN)
  puts JSON.pretty_generate(pcontext.result)
end

def json_to_format(format)
  json = JSON.load(STDIN)
  serialize(format, json, STDOUT)
end

def main
  command = ARGV[0]
  case command
  when "read-client"
    format_to_json(client_format)
  when "read-server"
    format_to_json(server_format)
  when "read-frame"
    format_to_json(frame_format)
  else
    raise "No command, saw #{command}"
  end
end

main
