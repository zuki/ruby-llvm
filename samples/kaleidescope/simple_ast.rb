#===----------------------------------------------------------------------===#
# Abstract Syntax Tree (aka Parse Tree)
#===----------------------------------------------------------------------===#

#todo  static FunctionPassManager *TheFPM

# ExprAST - すべての式(expression)ノードの基底クラス
class ExprAST
  @@named_values = {}  #オリジナルの定義   static std::map<std::string, AllocaInst*>

  # @operator_precedences - 定義される二項演算子の優先度を保持する
  @@operator_precedences = {}
  @@operator_precedences["="] = 2
  @@operator_precedences["<"] = 10
  @@operator_precedences["+"] = 20
  @@operator_precedences["-"] = 20
  @@operator_precedences["/"] = 40
  @@operator_precedences["*"] = 40  # highest.
  # precedence_for - 該当する二項演算子の優先度を取得する
  def self.precedence_for(token )
    return -1 if token.kind != :single
    return -1 if token.ascii?

    # Make sure it's a declared binop.
    @@operator_precedences[token.value] || -1
  end
  def self.set_precedence(name, int)
    @@operator_precedences[name] = int
  end
  def self.named_values
    @@named_values
  end
  def self.operator_precedences
    @@operator_precedences
  end

  attr_reader :from , :to
  def initialize from , to
    @from , @to = from , to
  end
  # for bracket expressions, need to make believe that the ) belongs to this
  def advance
    @to = @to.next
  end
  def code(the_module , builder)
    raise "abstract"
  end

  def error(str)
    puts "Error: #{str}"
    return nil
  end

  # createEntryBlockAlloca - 関数のentoryブロックのalloca命令を作成する。
  # mutable変数などで使用される。
  #static AllocaInst *
  def createEntryBlockAlloca(theFunction, varName)
#    IRBuilder<> TmpB(TheFunction.getEntryBlock, TheFunction.getEntryBlock.begin )
#    return TmpB.CreateAlloca(Type::getDoubleTy(getGlobalContext()), 0, VarName)
  end
end

# NumberExprAST - "1.0"などの数値リテラルの式クラス。
class NumberExprAST < ExprAST
  def initialize(val , from , to )
    super(from,to)
    @value = val.to_f
  end
  def code(the_module , builder)
    return LLVM.Double(@value)
  end
  def to_s
    @value.to_s
  end
end

# UnaryExprAST - 単項演算子の式クラス
class UnaryExprAST < ExprAST
  def initialize(opcod, operan , from)
    super(from , operan.to)
    @opcode = opcod
    @operand = operan
  end
  def code( the_module , builder )
    # value means an LLVM::Value
    value = @operand.code the_module , builder
    return nil unless value
    function = the_module.functions["unary#{@opcode}"]
    return error("Unknown unary operator #{@opcode}") unless function
    return builder.call(function, value, "unop")
  end
  def to_s
    "#{@opcode}#{@operand}"
  end
end

# BinaryExprAST - 二項演算子の式クラス
class BinaryExprAST < ExprAST
  def initialize(op, lhs, rhs )
    super(lhs.from , rhs.to)
    @op , @lhs ,  @rhs= op , lhs, rhs
  end

  def equals(the_module, builder)
    # Assignment requires the lhs to be an identifier.
    return error("destination of '=' must be a variable , not #{@lhs }") unless (@lhs .is_a? VariableExprAST)

    return nil unless value = @rhs.code(the_module , builder) # code the RHS.

    # Look up the name.
    return error("Unknown variable #{lhs.name}") unless variable = @@named_values[@lhs.name]

    builder.store(value, variable)
    return value
  end

  def code(the_module , builder)
    # Special case '=' because we don't want to emit the lhs as an expression.
    return equals(the_module, builder) if (@op == "=")

    left = @lhs.code(the_module , builder)
    right = @rhs.code(the_module , builder)
    return nil if (!left || !right)

    case (@op)
    when '+'
      return builder.fadd(left, right, "addtmp")
    when '-'
      return builder.fsub(left, right, "subtmp")
    when '*'
      return builder.fmul(left, right, "multmp")
    when '/'
      return builder.fdiv(left, right, "multmp")
    when '<'
       bool = builder.fcmp(:ule , left, right, "cmptmp")
      # Convert bool 0/1 to double 0.0 or 1.0
      return builder.ui2fp(bool, LLVM::Double, "booltmp")
    end

    # 演算子が組み込みの2項演算子ではない場合は、ユーザ定義の
    # 演算子であるので、それを呼び出す。
    function = the_module.functions["binary#{@op}"]
    raise "#{@op} binary operator not found!" unless function

    return builder.call(function, left, right , "binop")
  end
  def to_s
    "#{@lhs} #{@op} #{@rhs}"
  end
end

# CallExprAST - 関数呼び出しの式クラス
class CallExprAST < ExprAST
  def initialize(callee, args , from , to)
    super(from , to)
    @callee , @args = callee, args
  end
  def code(the_module , builder)
    # Look up the name in the global module table.
    callee = the_module.functions[@callee]
    return error("Unknown function referenced: #{@callee}") unless callee

    # If argument mismatch error.
    return error("Incorrect # arguments passed") if (callee.params.size != @args.length )

    argsV = @args.collect {|arg| arg.code(the_module , builder) }
    #puts "calling #{self} with #{argsV.first.class}"
    return builder.call(callee, *argsV, "calltmp")
  end
  def to_s
    "#{@callee}(#{@args.join(',')})"
  end
end
