class InterpretedInstruction extends Instruction
	constructor: (description, ipIncrement, code) ->
		super description, ipIncrement
		@updateCode code

	addCondition: (conditionCode, statements, fallThrough=false) ->
		condition = Tokeniser.tokenise conditionCode
		statementTokens = []

		for statement in (statements.split Symbol.statementSeparator)
			statementTokens.push (Tokeniser.tokenise statement)

		@conditions.push
			condition: condition
			statements: statementTokens
			fallThrough: fallThrough

	updateCode: (code) ->
		code = code.replace /\s+/g, ' ' # compress whitespace
		@conditions = []

		# TODO: put in parser
		startingSymbol = code[0]

		if startingSymbol is Symbol.guard[0]
			# strip off guard symbol
			code = code[Symbol.guard.length..]
			startingSymbol = Symbol.guard
		else
			code = code[1..]

		# extract context clause
		parts = code.split Symbol.context
		code = parts[0]

		if (parts.length > 1)
			contextClause = parts[1]

			contextStatements = contextClause.split Symbol.statementSeparator
			@context = {}

			for contextStatement in contextStatements
				if (contextStatement.length > 0)
					[key, value] = contextStatement.split Symbol.assign
					@context[key] = Tokeniser.tokenise value

		if startingSymbol is Symbol.conditionTerminator
			# single command, always execute
			@addCondition Symbol.boolTrue, code
		else if startingSymbol is Symbol.guard
			# conditional command
			cases = code.split Symbol.guard

			for caseBlock in cases
				blocks = caseBlock.split( Symbol.conditionTerminator )
				fallThrough = false

				if blocks.length is 1
					# didn't end in a condition terminator,
					# split by fallThrough symbol
					blocks = caseBlock.split( Symbol.fallThrough )
					fallThrough = true

				[condition, statements] = blocks

				if (condition.length > 0)
					@addCondition condition, statements, fallThrough

	execute: (state) ->
		for condition in @conditions
			conditionValue = Interpreter.interpretCondition condition.condition, state, @context

			if conditionValue
				for statement in condition.statements
					Interpreter.interpretStatement statement, state, @context

				if not condition.fallThrough
					break



