class Tokeniser
	constructor: () ->
		@position = 0
		@tokens = []
		@code = ""
		
	addToken: (type, value) ->
		@tokens.push( new Token( type, value ) )
		@position += value.length

	throwError: ->
		console.log 'Error'
		throw new SyntaxError( @code[@position] )
	
	tokeniseComparison: ->
		couplet = @code.substring( @position, @position+2 )
		c = @code[@position]
		
		if couplet is Symbol.compareLE or couplet is Symbol.compareGE or couplet is Symbol.compareNe or couplet is Symbol.compareEq
			@addToken( Token.OpComparison, couplet )
		else if c is Symbol.compareLT or c is Symbol.compareGT
			@addToken( Token.OpComparison, c )
	
	tokeniseEqualsSign: ->
		couplet = @code.substring( @position, @position+2 )
		
		if couplet is Symbol.compareEq
			@addToken( Token.OpComparison, couplet )
		else
			@addToken( Token.OpAssign, Symbol.assign )
	
	tokeniseLogicOp: ->
		couplet = @code.substring( @position, @position+2 )
		c = @code[@position]
		
		if couplet is Symbol.boolAnd or couplet is Symbol.boolOr
			@addToken( Token.OpLogic, couplet )
		else
			@addToken( Token.OpBitwise, c )
		
	tokeniseBitshift: ->
		String couplet = code.substring( @position, @position+2 );
		
		if couplet is Symbol.bitLShift or couplet is Symbol.bitRShift
			@addToken( Token.OpBitwise, couplet )
		else
			@throwError( )
			
	tokeniseAddOp: ->
		couplet = @code.substring( @position, @position+2 )
		c = @code[@position]
		
		if couplet is Symbol.addAssign or couplet is Symbol.subAssign
			@addToken( Token.OpAssign, couplet )
		else if couplet is Symbol.incAssign or couplet is Symbol.decAssign
			@addToken( Token.OpIncAssign, couplet )
		else
			@addToken( Token.OpTerm, c )
			
	isDigit: (c) ->
		c >= '0' and c <= '9'
	
	isHexDigit: (c) ->
		@isDigit( c ) or (c >= 'A' and c <= 'F')
		
	isLetter: (c) ->
		c == '_' or (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')
		
	isAlphanumeric: (c) ->
		@isDigit( c ) or @isLetter( c )
		
	tokeniseInteger: ->
		digitStr = ""
		i = @position
		
		while (i < @code.length) and @isDigit( @code[i] )
			digitStr += @code[i]
			i += 1
		
		@addToken( Token.Integer, digitStr )
	
	tokeniseHex: ->
		digitStr = ""
		@position++ # ignore leading '#'
		i = @position
		
		while (i < @code.length) and @isHexDigit( @code[i] )
			digitStr += @code[i]
			i += 1
		
		@addToken( Token.Hex, digitStr )
		
	tokeniseStringLiteral: ->
		i = @position
		stringVal = ""
		i += 1 # skip initial "
		
		while (i < @code.length) and @code[i] != '"'
			# TODO: escaping
			stringVal += @code[i]
			i += 1
		
		@addToken( Token.StringLiteral, stringVal )
		@position += 2 # skip opening and closing quotes (not included by addToken)
	
	tokeniseKeyword: ->
		keywordStr = ""
		i = @position
		
		while (i < @code.length) and @isAlphanumeric( @code[i] )
			keywordStr += @code[i]
			i += 1
		
		booleanLiterals = [Symbol.boolTrue, Symbol.boolFalse, Symbol.otherwise]
		commands = [
			Symbol.commandPrint,
			Symbol.commandPrintASCII,
			Symbol.commandBell,
			Symbol.commandHalt,
			Symbol.commandNop
		]
		internalKeywords = [
			Symbol.bellState,
			Symbol.outputState,
			Symbol.cycleState
		]
		
		if (keywordStr in booleanLiterals)
			@addToken( Token.BoolLiteral, keywordStr )
		else if (keywordStr in commands)
			@addToken( Token.Keyword, keywordStr )
		else if (keywordStr in internalKeywords)
			@addToken( Token.Internal, keywordStr )
		else
			@addToken( Token.RegisterName, keywordStr )
			
	
	tokenise: (code) ->
		@code = code
		@tokens = []
		
		@position = 0
		while @position isnt @code.length
			c = @code[@position]
			switch c
				when '('
					@addToken Token.GroupOpen, c
				when ')'
					@addToken Token.GroupClose, c
				when '['
					@addToken Token.DerefOpen, c
				when ']'
					@addToken Token.DerefClose, c
				when '{'
					@addToken Token.RegRefOpen, c
				when '}'
					@addToken Token.RegRefClose, c
				when '*', '/', '%'
					@addToken Token.OpFactor, c
				when '~'
					@addToken Token.OpUnary, c
				when '+', '-'
					@tokeniseAddOp( )
				when '<', '>', '!'
					if @code[@position + 1] is c
						# two of the same
						@tokeniseBitshift( )
					else
						@tokeniseComparison( )
				when '='
					@tokeniseEqualsSign( )
				when '#'
					@tokeniseHex( )
				when '&', '|', '^'
					@tokeniseLogicOp( )
				when '"'
					@tokeniseStringLiteral( )
				else
					if @isDigit( c )
						@tokeniseInteger( )
					else if @isLetter( c )
						@tokeniseKeyword( )
					else
						@throwError( )
		return @tokens
				
Tokeniser.tokenise = (code) -> (new Tokeniser()).tokenise code
