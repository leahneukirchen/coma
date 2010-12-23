require 'rum'

Webcoma = Rum.new {
  on path('scan'), segment do |_, folder|
    res.write '<meta charset="utf-8">'
    
    res.write('<a href="/folders">^</a> ')
    res.write('<a href="?sort=date">date</a> ')
    res.write('<a href="?sort=from">from</a> ')
    res.write('<a href="?sort=thread">thread</a> ')
    res.write('<a href="?">all</a> ')
    res.write('<a href="?unseen=unseen">unseen</a> ')

    res.write "<pre>"
    content = Rack::Utils.escape_html(`coma read #{folder} #{req['sort']} #{req['unseen']} -width 132 2>&1`)
    content.gsub!(/^(\s*)(\d+)/, '\1<a href="/show/\2">\2</a>')
    res.write content
    res.write "</pre>"
  end

  on path('folders') do 
    puts "<pre>"

    content = `coma folders`

    content.each { |line|
      line.chomp!
      folder = nil
      line.gsub!(/^(\S+)/) {
        folder = $1
        "<a href='/scan/#{folder}'>#{folder}</a>"
      }
      line.gsub!(/(?!0 )(\d+) unread/,
                 "<a href='/scan/#{folder}?unseen=unseen'>\\1 unread</a>")
      
      puts line
    }

    puts "</pre>"
  end

  on path('show'), segment do |_, args|
    content = Rack::Utils.escape_html(`coma show #{args}`)

    atts = Rack::Utils.escape_html(`coma att`)
    idx = `coma show . -idx`
    atts.gsub!(/^(\d+)/, "<a href='/att/#{idx}/\\1'>\\1</a>")

    prv = "<a href='/show/#{`coma show prev -idx -keep`}'>&lt;&lt;</a> "
    up = "<a href='/scan'>^</a>"
    nxt = "<a href='/show/#{`coma show next -idx -keep`}'>&gt;&gt;</a>"

    res.write '<meta charset="utf-8">'
    res.write "#{prv} #{up} #{nxt}"
    res.write "<pre>#{content}</pre>"
    res.write "<hr><pre>#{atts}</pre>"
    res.write "#{prv} #{up} #{nxt}"
  end

  on path('att'), segment, segment do |_, idx, n|
    `coma show #{idx} -idx`   # make current
    
    line = `coma att`.split("\n").find { |line|
      line.split.first == n
    }

    unless line
      res.not_found
    else
      res['Content-Type'] = line.split[1]
      res.write `coma att #{n} -`
    end
  end

  on default do
    res.redirect('/folders')
  end
}
