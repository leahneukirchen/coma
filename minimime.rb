# MiniMime - half-assed RFC2822 and MIME parser
#
# This is not really nice, but it should be half-way robust and quick.

require 'iconv'

class MiniMime
  attr_reader :raw, :header

  def initialize(msg)
    @raw = msg
    @header, @body = @raw.split(/\A\r\n|\r\n\r\n/m, 2)
    @body ||= ""

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
      if word =~ /=\?(.+)\?[Bb]\?(.*)\?=/m
        Iconv.conv("#{encoding}//IGNORE", $1, $2.unpack("m*").first)
      elsif word =~ /=\?(.+)\?[Qq]\?(.*)\?=/m
        Iconv.conv("#{encoding}//IGNORE", $1, $2.unpack("M*").first).tr('_', ' ')
      else
        word
      end
    }.join(" ")
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
      MiniMime.new(part.sub("\r\n", "").sub(/\r\n$/, ""))
    }
  end

  def render
    %w{from subject to cc date}.map { |field|
      "#{field.capitalize}: #{self[field].strip}\n"  if self[field]
    }.join + "\n" + render_body
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
    parse_ct(get("content-type")) || ["text", "plain", {}]
  end

  def extract(n, count=[0])
    main, sub, opts = content_type

    count[0] += 1

    if count[0] == n
      return opts["name"], body
    end
  
    case main
    when "text", "image", "audio", "video", "application"
      nil
    when "multipart"
      parse_parts.each { |mp|
        x = mp.extract(n, count)
        if x
          return x
        end
      }
    when "message"
      case sub
      when "rfc822"
        MiniMime.new(body).extract(n, count)
      else
        raise "unhandled type #{self["content-type"]}"
      end
    else
      raise "can't deal with #{self["content-type"]}"
    end

    nil
  end

  def render_tree(n=nil, depth=0, count=[0])
    main, sub, opts = content_type

    count[0] += 1

    if count[0] == n
      return body
    end

    ("%1d %s %s/%s %dB%s\n" % [count[0], "  "*depth,
                               main, sub, body.size,
                               opts["name"] ? " #{opts["name"].dump}" : ""]) +
  
    case main
    when "text", "image", "audio", "video", "application"
      ""
    when "multipart"
      parse_parts.map { |mp|
        mp.render_tree(n, depth+1, count)
      }.join("")
    when "message"
      case sub
      when "rfc822"
        MiniMime.new(body).render_tree(n, depth+1, count)
      else
        "--unhandled type #{self["content-type"]}--\n"
      end
    else
      "--unhandled type #{self["content-type"]}--\n"
    end
  end

  def render_body(encoding="utf-8", count=[0])
    main, sub, opts = content_type

    count[0] += 1

    case main
    when "text"
      case sub
      when "plain"
        if opts["format"] == "flowed"
          output = wrap_text body
        else
          output = body
        end

        if opts["charset"]
          output = Iconv.conv(encoding + "//IGNORE", opts["charset"], output)
        end

        output
      when "html"
        IO.popen("w3m -dump -T text/html", "w+") { |pipe|
          pipe.write body
          pipe.close_write
          pipe.read
        }
      else
        "#{count[0]} --unhandled type #{self["content-type"]}--\n" + body
      end
    when "image"
      IO.popen("identify -format '%b %m %wx%h' -", "w+") { |pipe|
        pipe.write body
        pipe.close_write
        "#{count[0]} --image #{pipe.read.strip} #{opts["name"]}--"
      }
    when "audio", "video", "application"
      "#{count[0]} --#{main}/#{sub} #{body.size}B #{opts["name"]}--"
    when "multipart"
      case sub
      when "mixed", "related", "digest", "report", "signed", "appledouble"
        parse_parts.map { |mp|
          mp.render_body(encoding, count)
        }.join("\n")
      when "alternative"
        sparts = parse_parts.sort_by { |mp|
          m, s, _ = mp.content_type
          [{ "text" => 1,
             "multipart" => 1}[m] || 0,
           { "plain" => 10,
             "html" => 5 }[s] || 0]
        }

        sparts.last.render_body(encoding, count) + "\n\n--Alternatives:\n" +
        sparts[0..-2].map { |mp|
          count[0] += 1
          "#{count[0]} --#{mp.get("content-type")}--"
        }.join("\n")
      else  # XXX encrypted, 
        "#{count[0]} --unhandled type #{self["content-type"]}--\n"
      end
    when "message"
      case sub
      when "rfc822"
        "#{count[0]} --#{get("content-type")} #{body.size}B--\n" +
          MiniMime.new(body).render_body(encoding, count)
      else
        "--unhandled type #{self["content-type"]}--\n" + body
      end
    else
      "--unhandled type #{self["content-type"]}--\n"
    end
  end
end


