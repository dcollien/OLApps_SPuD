class Token
	constructor: (@type, @value) ->
	toString: ->
		return '(' + @typeToString( ) + ', "' + @value + '")'
	typeToString: ->
		return Token.typeString( @type )

Token.OpAssign        = 0
Token.OpLogic         = 1
Token.OpComparison    = 2
Token.BoolLiteral     = 3
Token.GroupOpen       = 4
Token.GroupClose      = 5
Token.OpTerm          = 6
Token.OpFactor        = 7
Token.Integer         = 8
Token.Keyword         = 9
Token.RegisterName    = 10
Token.DerefOpen       = 11
Token.DerefClose      = 12
Token.OpIncAssign     = 13
Token.OpBitwise       = 14
Token.OpUnary         = 15
Token.RegRefOpen      = 16
Token.RegRefClose     = 17
Token.Hex             = 18
Token.Internal        = 19
Token.StringLiteral   = 20

Token.typeString = (type) ->
	typeNames = [
		"assignment",
		"logical operator",
		"logical comparison",
		"boolean literal",
		"open group",
		"close group",
		"term operator",
		"factor operator",
		"integer",
		"keyword",
		"register name",
		"open dereference",
		"close dereference",
		"modifying assignment",
		"bitwise operator",
		"unary operator",
		"register reference open",
		"register reference close",
		"hex hash",
		"internal keyword",
		"string literal"
	]

	