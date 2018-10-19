# 「無限の」（ただし遅延の）先読みを提供するコールスタックが逆方向を
# 提供するので、tokensは一方向の連結リストである。
# kindは種類（識別子や数など）を示すシンボルである。(lexerを参照）
class Token
  attr_reader  :line_number , :value , :kind
  def initialize line_number , value , kind , lexer
    @line_number , @value , @kind = line_number , value , kind
    @next = lexer
  end
  # nextの解決を遅延する。行の最後でnextにlexerをセットして、必要に応じて
  # そこを使って解決する。
  def next
    if @next.is_a? Lexer  #this changes the next variable
      #puts "READLINE"
      @next.readline(self)
    end
    @next
  end
  # can be used to "collapse" several successicve lexer tokens to parser token without too much shuffeling
  def next= n
    @next = n
  end
  def ascii?
    @value.match(/[a-zA-Z]/)
  end
  def to_s
    "#{value}:#{kind}"
  end
  def all
    "#{value} #{self.next.all if self.next}"
  end
end
