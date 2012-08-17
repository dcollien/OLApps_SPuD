class SyntaxError extends Error
	constructor: (syntax) ->
		@.name = 'Syntax Error'

		if syntax
			Error.call @, "Invalid syntax: " + syntax
		else
			Error.call @, "Invalid syntax"

		Error.captureStackTrace @, arguments.callee