require "simple_ast"

# VariableExprAST - 変数参照（"a"など）の式クラス
class VariableExprAST < ExprAST
  attr_accessor :name
  def initialize(name , from , to)
    super(from , to)
    @name = name
  end
  def to_s
    "#{@name}"
  end
  def code the_module, builder, the_fpm
    # Look this variable up in the function.
    value = @@named_values[@name]
    return error("Variable unknown #{@name}") if value == nil
    # Load the value.
    return builder.load(value, @name)
  end
end


# VarExprAST - Expression class for var/in
class VarExprAST < ExprAST
  #std::vector<std::pair<std::string, ExprAST*> >   varNames
  def initialize(varnames, body , from , to)
    super(from , to)
    @varNames , @body = varnames , body
  end
  def to_s
    "#{@varNames} #{@body}"
  end
  def code(the_module, builder, the_fpm)
    # std::vector<AllocaInst *> OldBindings;
    oldBindings = {}

    theFunction = builder.insert_block.parent
    # Register all variables and emit their initializer.
    @varNames.each do |varName, init|
      # Emit the initializer before adding the variable to scope, this prevents
      # the initializer from referencing the variable itself, and permits stuff
      # like this:
      #  var a = 1 in
      #    var a = a in ...   # refers to outer 'a'.
      initVal = nil
      if (init)
        initVal = init.code(the_module, builder, the_fpm)
        return nil unless initVal
      else # If not specified, use 0.0.
        initVal = LLVM.Double(0)
      end

      #alloca = createEntryBlockalloca(theFunction, varName)
      alloca = builder.alloca LLVM::Double
      builder.store(initVal, alloca)

      # Remember the old variable binding so that we can restore the binding when
      # we unrecurse.
      oldBindings[varName] = @@named_values[varName]

      # Remember this binding.
      @@named_values[varName] = alloca
    end

    # code the body, now that all vars are in scope.
    return nil unless bodyVal = @body.code(the_module, builder, the_fpm)

    # Pop all our variables from scope.
    @varNames.each do |varName, second|
     @@named_values[varName] = oldBindings[varName]
    end
    # Return the body computation.
    return bodyVal
  end
end
