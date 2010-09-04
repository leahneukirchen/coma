# MiniMime - half-assed RFC2822 and MIME parser
#
# This is not really nice, but it should be half-way robust and quick.

require 'iconv'

class MiniMime
  attr_reader :raw, :header

  def initialize(msg)
    @raw = msg
    @header, @body = @raw.split(/\r\n[\t ]*\r\n/m, 2)

    @fields = {}

    @header.to_s.gsub(/[\t ]*\r\n[\t ]+/, ' ').split("\r\n").each { |line|
      field, value = line.split(":", 2)
      if @fields[field.downcase.strip]
        @fields[field.downcase.strip] << "\n" << value.strip
      else
        @fields[field.downcase.strip] = value.strip
      end
    }
  end

  def [](field, encoding="utf-8")
    f = get(field)
    decode(f, encoding)  if f
  end

  def decode(str, encoding)
    return str  unless str.index("=?")
    str = str.gsub(/\?=(\s*)=\?/, '?==?')
    str.gsub!(/\?\=\=\?.+?\?[Qq]\?/m, '')  if str =~ /\?==\?/
    str.gsub!(/\?\=\=\?/, '?= =?')

    str.split(" ").map { |word|
      if word =~ /=\?(.+)\?([BbQq])\?/m
        word = $'.unpack({"B" => "m*", "Q" => "M*"}[$2.upcase]).first
        Iconv.conv(encoding, $1, word)
      else
        word
      end
    }.join("")
  end

  def get(field)
    @fields[field.to_s.downcase.strip]
  end

  def body
    case (get("content-transfer-encoding") || "").downcase
    when "7bit", "8bit", "binary", ""
      @body
    when "quoted-printable"
      @body.unpack("M*").first
    when "base64"
      @body.unpack("m*").first
    end
  end

  def parse_parts
    _, _, opts = content_type

    @body.split("--#{opts["boundary"]}")[1...-1].map { |part|
      MiniMime.new(part.sub("\r\n", ""))
    }
  end

  def render
    %w{from subject to cc date}.map { |field|
      "#{field.capitalize}: #{self[field].strip}\n"  if self[field]
    }.join + "\n\n" + render_body
  end

  def wrap_text(txt, col = 80)
    txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/, "\\1\\3\n") 
  end
  
  TOKEN = "[-#!$%&'*+.^_{}|\\w]+"
  
  def parse_ct(ct)
    if ct =~ /\A(#{TOKEN})\/(#{TOKEN})/
      main, sub = $1.downcase, $2.downcase
      opts = {}
      ct.split(";", 2)[1].to_s.
        scan(/(#{TOKEN})\s*=\s*(?:"([^"]*)"|(#{TOKEN}))/) {
        opts[$1.downcase] = $2 || $3
      }
      [main, sub, opts]
    end
  end

  def content_type
    parse_ct(get("content-type"))
  end

  def render_body
    main, sub, opts = content_type

    case main
    when "text"
      case sub
      when "plain"
        if opts["format"] == "flowed"
          wrap_text body
        else
          body
        end
      when "html"
        IO.popen("w3m -dump -T text/html", "w+") { |pipe|
          pipe.write body
          pipe.close_write
          pipe.read
        }
      else
        "--unhandled type #{part["content-type"]}--\n" + body
      end
    when "image"
      IO.popen("identify -format '%b %m %wx%h' -", "w+") { |pipe|
        pipe.write body
        pipe.close_write
        "--image #{pipe.read.strip} #{opts["name"]}--"
      }
    when "audio", "video", "application"
      "--#{main}/#{sub} #{body.size}B #{opts["name"]}--"
    when "multipart"
      case sub
      when "mixed", "related", "digest", "report", "signed", "appledouble"
        parse_parts.map { |mp|
          mp.render_body
        }.join("\n")
      when "alternative"
        sparts = parse_parts.sort_by { |mp|
          m, s, _ = mp.content_type
          [{ "text" => 1,
             "multipart" => 1}[m] || 0,
           { "plain" => 10,
             "html" => 5 }[s] || 0]
        }

        sparts.last.render_body + "\n\n--Alternatives:\n" +
        sparts[0..-2].map { |mp|
          "  --#{mp.get("content-type")}--"
        }.join("\n")
      else  # XXX encrypted, 
        "--unhandled type #{self["content-type"]}--\n"
      end
    when "message"
      case sub
      when "rfc822"
        "--#{get("content-type")} #{body.size}B--\n" +
          MiniMime.new(body).render_body
      else
        "--unhandled type #{self["content-type"]}--\n" + body
      end
    else
      raise "can't deal with #{self["content-type"]}"
    end
  end
end


