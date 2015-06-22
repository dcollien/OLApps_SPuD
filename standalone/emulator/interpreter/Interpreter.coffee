if module?.exports
	SyntaxError = require './SyntaxError'
	Symbol      = require './Symbol'
	Token       = require './Token'

class Interpreter
	constructor: (@tokens, @state, @context) ->
		@tokenPos = 0
		@acceptedToken = null
		@pendingToken = null
		@internalAccessible = false
		@getToken( )
	
	getToken: ->
		if @tokenPos != @tokens.length
			@pendingToken = @tokens[@tokenPos]
			@tokenPos += 1
		else
			@pendingToken = null
	
	accept: (tokenType) ->
		accepted = false
		
		if @pendingToken != null and @pendingToken.type == tokenType
			@acceptedToken = @pendingToken
			@getToken( )
			accepted = true
		
		return accepted
	
	expect: (tokenType) ->
		if not @accept( tokenType )
			throw new SyntaxError( "Expected " + Token.typeString( tokenType ) )
	
	isValidRegister: (registerName) ->
		return (registerName in @state.processor.registerNames)
	
	
	## Recursive Descent Parsing
	
	bitExpression: ->
		value = @addExpression( )
		
		while @accept( Token.OpBitwise )
			switch @acceptedToken.value
				when Symbol.bitXor
					value ^= @addExpression( )
				when Symbol.bitAnd
					value &= @addExpression( )
				when Symbol.bitOr
					value |= @addExpression( )
				when Symbol.bitRShift
					value >>= @addExpression( )
				when Symbol.bitLShift
					value <<= @addExpression( )
				else
					throw new SyntaxError( "Unknown bitwise operator: " + @acceptedToken.value )
		
		return value
	
	addExpression: ->
		value = @mulExpression( )
		
		while @accept( Token.OpTerm )
			switch @acceptedToken.value
				when Symbol.add
					value += @mulExpression( )
				when Symbol.sub
					value -= @mulExpression( )
				else
					throw new SyntaxError( "Unknown additive operator: " + @acceptedToken.value )
					
		return value
		
	mulExpression: ->
		value = @unaryExpression( )
		
		while @accept( Token.OpFactor )
			switch @acceptedToken.value
				when Symbol.mul
					value *= @unaryExpression( )
				when Symbol.div
					value /= @unaryExpression( )
				when Symbol.mod
					value %= @unaryExpression( )
				else
					throw new SyntaxError( "Unknown multiplicative operator: " + @acceptedToken.value )
		
		return value
		
	unaryExpression: ->
		isUnary = @accept( Token.OpUnary )
		
		value = @simpleExpression( )
		
		if isUnary
			if @acceptedToken.value == Symbol.bitInvert
				value = ~value
			else
				throw new SyntaxInterpreterError( "Unknown unary operator: " + @acceptedToken.value )
		
		return value
		
	simpleExpression: ->
		value = -1
		
		if @accept( Token.GroupOpen )
			value = @intExpression( )
			@expect( Token.GroupClose )
		else if @accept( Token.Integer )
			value = parseInt( @acceptedToken.value )
		else if @accept( Token.Hex )
			value = parseInt( @acceptedToken.value, 16 )
		else
			switch @pendingToken.type
				when Token.RegisterName, Token.DerefOpen, Token.RegRefOpen
					value = @identifier( )
				else
					throw new SyntaxError( "Unable to parse expression at: " + @pendingToken.value )
		
		return value
		
	identifier: ->
		value = 0
		identifierName = Symbol.unknown
		
		if @accept( Token.RegisterName )
			identifierName = @acceptedToken.value
			
			if @isValidRegister( identifierName )
				value = @state.getRegister( identifierName )
			else if @context[identifierName]
				value = Interpreter.interpretExpression( @context[identifierName], @state, @context )
			else
				throw new SyntaxError( "Unknown register or identifier: " + identifierName )
		
		else if @accept( Token.DerefOpen )
			address = @intExpression( )
			@expect( Token.DerefClose )
			
			value = @state.getMemory( address )
		
		else if @accept( Token.RegRefOpen )
			registerNumber = @intExpression( )
			@expect( Token.RegRefClose )
			
			if (registerNumber < @state.processor.numRegisters)
				registerName = @state.processor.registerNames[registerNumber]
				value = @state.getRegister( registerName )
			else
				throw new SyntaxError( "Register index out of bounds: " + registerNumber )
		
		else if @accept( Token.Internal )
			if @internalAccessible
				switch @acceptedToken.value
					when Symbol.bellState
						value = @state.numBellRings
					when Symbol.cycleState
						value = @state.executionStep
					else
						throw new SyntaxError( "Unknown internal value: " + @acceptedToken.value )
			
			else
				throw new SyntaxError( "Unrecognised identifier: " + @pendingToken.value )
		
		return value
	
	intExpression: ->
		return @bitExpression( )
	
	stringComparison: ->
		value = false
		
		if @internalAccessible
			@expect( Token.Internal )
			
			if @acceptedToken.value != Symbol.outputState
				throw new SyntaxError( "Unknown internal string identifier: " + @acceptedToken.value )
			
			@expect( Token.OpComparison )
			
			if @acceptedToken.value == Symbol.compareEq
				@expect( Token.StringLiteral )
				value = (@state.output == @acceptedToken.value)
			else if @acceptedToken.value == Symbol.compareNe
				@expect( Token.StringLiteral )
				value = (@state.output != @acceptedToken.value)
			else
				throw new SyntaxError( "Unknown string comparison operator: " + @acceptedToken.value )
			
		else
			throw new SyntaxError( "Internal information inaccessible." )
		
		return value
	
	boolExpression: ->
		value = false
		
		if @accept( Token.BoolLiteral )
			switch @acceptedToken.value
				when Symbol.boolTrue, Symbol.otherwise
					value = true
				when Symbol.boolFalse
					value = false
				else
					throw new SyntaxError( "Unknown boolean literal: " + @acceptedToken.value )
		else if @accept( Token.GroupOpen )
				value = @condition( )
				@expect( Token.GroupClose )
		else if @pendingToken.type == Token.Internal and pendingToken.value == "output" 
			value = @stringComparison( )
		else
			leftSide = @intExpression( )
			@expect( Token.OpComparison )
			operator = @acceptedToken.value
			rightSide = @intExpression( )
			
			switch operator
				when Symbol.compareGT
					value = (leftSide > rightSide)
				when Symbol.compareLT
					value = (leftSide < rightSide)
				when Symbol.compareGE
					value = (leftSide >= rightSide)
				when Symbol.compareLE
					value = (leftSide <= rightSide)
				when Symbol.compareEq
					value = (leftSide == rightSide)
				when Symbol.compareNe
					value = (leftSide != rightSide)
				else
					throw new Error( "Unknown comparison operator: " + operator )
		
		return value
	
	condition: ->
		value = @boolExpression( )
		

		while @accept( Token.OpLogic )
			switch @acceptedToken.value
				when Symbol.boolAnd
					value = (value && @boolExpression( ))
				when Symbol.boolOr
					value = (value || @boolExpression( ))
				else
					throw new SyntaxError( "Unknown boolean operator: " + @acceptedToken.value )
		
		return value
		
	assignment: (oldValue)->
		if @accept( Token.OpAssign )
			operator = @acceptedToken.value
			
			newValue = @intExpression( )
			
			switch operator
				when Symbol.addAssign
					newValue = oldValue + newValue
				when Symbol.subAssign
					newValue = oldValue - newValue
				when Symbol.assign
					# already OK
				else
					throw new SyntaxError( "Unknown assignment operator: " + operator )
		else if @accept( Token.OpIncAssign )
			newValue = oldValue
			
			switch @acceptedToken.value
				when Symbol.incAssign then newValue += 1
				when Symbol.decAssign then newValue -= 1
				else
					throw new SyntaxError( "Unknown increment operator: " + @acceptedToken.value )
		else
			throw new SyntaxError( "Unknown assignment: " + @pendingToken.value )
		
		return newValue
	
	statement: ->
		value = 0
		if @accept( Token.RegisterName )
			registerName = @acceptedToken.value
			
			if @isValidRegister( registerName )
				value = @assignment( @state.getRegister( registerName ) )
				@state.setRegister( registerName, value )
			else
				throw new SyntaxError( "Unknown register name: " + registerName )
		else if @accept( Token.DerefOpen )
			memoryAddress = @intExpression( )
			
			@expect( Token.DerefClose )
			
			value = @assignment( @state.getMemory( memoryAddress ) )
			@state.setMemory( memoryAddress, value )
		else if @accept( Token.RegRefOpen )
			registerNumber = @intExpression( )
			
			@expect( Token.RegRefClose )
			
			if (registerNumber < @state.processor.numRegisters)
				registerName = @state.processor.registerNames[registerNumber]
				value = @assignment( @state.getRegister( registerName ) )
				@state.setRegister( registerName, value )
			else
				throw new SyntaxError( "Register reference out of bounds evaluating statement" )
		else if @accept( Token.Keyword )
			argumentValue = 0

			switch @acceptedToken.value
				when Symbol.commandPrint, Symbol.commandPrintASCII
					commandValue = @acceptedToken.value

					@expect( Token.GroupOpen )
					argumentValue = @intExpression( )
					@expect( Token.GroupClose )

					if commandValue is Symbol.commandPrint
						@state.print( argumentValue )
					else
						@state.printASCII( argumentValue )
				when Symbol.commandBell
					@state.ringBell( )
				when Symbol.commandHalt
					@state.halt( )
				when Symbol.commandNop
					# twiddle thumbs
				else
					throw new SyntaxError( "Unknown command: " + @acceptedToken.value )
		else
			throw new SyntaxError( "Unable to parse statement" )

Interpreter.interpretStatement = (statementTokens, state, context) ->
	interpreter = new Interpreter( statementTokens, state, context )
	return interpreter.statement( )

Interpreter.interpretCondition = (conditionTokens, state, context) ->
	interpreter = new Interpreter( conditionTokens, state, context )
	return interpreter.condition( )
	
Interpreter.interpretExpression = (expressionTokens, state, context) ->
	interpreter = new Interpreter( expressionTokens, state, context )
	return interpreter.intExpression( )

module?.exports = Interpreter
