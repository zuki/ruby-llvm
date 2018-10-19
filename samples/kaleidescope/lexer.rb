require "token"

# レキサはioストリームからトークンの連結リスト（ストリーム）を作成する。
# トークンは連結されており、レキサにより遅延生成されるので、レキサは
# 実際には開始時にしか使用されない。
#
# このレキサは一度に全行を読み込む。行の終わりはトークンの終わりを意味する。
# レキサはレキサトークンから新しいトークンを処理するパーサの存在を前提と
# している。
class Lexer
  @@kinds = {
    :identifier => /^([a-z][_a-zA-Z0-9]*)/  ,
    :number => /^(\d*[\.\d]+)/
  }
  #can be file or stdin
  def initialize stream
    @stream = stream
    @line = 0
  end

  def readline before
    if @stream.eof?
      tok = Token.new( @line , nil , :eof , nil)
    else
      @line += 1
      line = @stream.readline
      tok = from(line , @line , before)
    end
    before.next = tok
  end

  def from line , number , before
    #remove whitespace from start and end
    line = line.strip
    return readline(before) if line.empty?
    return readline(before) if line.start_with? "#"
    # any regexp kind
    @@kinds.each do |kind , regex |
      next unless regex.match line
      value = $1
      token = Token.new( number , value , kind , self)
      before.next = token if token
      from(line.sub(value , "") , number , token)
      return token
    end
    # currently just single character types
    token = Token.new( number , line[0] , :single , self)
    from(line[1 .. -1] , number , token)
    before.next = token
    token
  end

end
