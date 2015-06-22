if module?.exports
	Processor   = require '../Processor'
	Symbol      = require '../interpreter/Symbol'
	SyntaxError = require '../interpreter/SyntaxError'
	InterpretedInstruction = require '../instructions/InterpretedInstruction'

class InterpretedProcessor extends Processor
	constructor: (definition, changeHandler) ->
		super '', changeHandler

		@updateDefinition definition

	isTitleLine: (line) -> line.trim()[0] is Symbol.titleStart

	addLineToDict: (dict, line) ->
		line = line.trim()

		if line isnt ''
			property = line.split Symbol.conditionTerminator
			key = property[0].trim()
			value = property[1..].join(Symbol.conditionTerminator).trim()
			dict[key] = value

	isDigit: (c) ->
		return ( c >= '0' and c <= '9' )

	extractHeader: (code) ->
		header = []

		i = 0
		start = i

		# move along until instruction separator
		while (i isnt code.length) and (code[i] isnt Symbol.instructionSeparator)
			i += 1

		end = i
		header.push (parseInt (code.substring start, end))

		i += 1 # skip over separator

		start = i
		
		# move along until all digits collected
		while (i isnt code.length) and @isDigit( code[i] )
			i += 1

		end = i

		header.push (parseInt (code.substring start, end))

		return header

	extractCodeSection: (code) ->
		codeStart = 0
		for i in [0...code.length]
			# find condition terminator or guard
			if (code[i] is Symbol.conditionTerminator) or ((code.substring i, i+Symbol.guard.length) is Symbol.guard)
				break

		return code[i..]

	addInstructionCode: (code, descriptions) ->
		[instrNum, ipInc] = @extractHeader code
		instrCode = @extractCodeSection code
		@instructions[instrNum] = new InterpretedInstruction( descriptions[instrNum], ipInc, instrCode )

	updateDefinition: (definition) ->
		properties = {}
		descriptions = {}

		@instructions = []
		lines = definition.split '\n'
		lineNum = 0

		while not (@isTitleLine lines[lineNum])
			@addLineToDict properties, lines[lineNum]
			lineNum += 1

		@name = properties.name
		@memoryBitSize = parseInt (properties.memoryBitSize)
		@numMemoryAddresses = parseInt (properties.numMemoryAddresses)
		@registerBitSize = parseInt (properties.registerBitSize)

		regNames = properties.registerNames.split Symbol.instructionSeparator
		@setRegisterNames (regName.trim() for regName in regNames)

		if lines[lineNum].trim() is Symbol.descriptionsHeader
			lineNum += 1

			while not (@isTitleLine lines[lineNum])
				@addLineToDict descriptions, lines[lineNum]
				lineNum += 1
			
		else
			throw new SyntaxError( 'Descriptions must be listed before instructions.' )

		code = ''

		if lines[lineNum].trim() is Symbol.instructionsHeader
			lineNum += 1

			code = lines[lineNum..].join ''
			code = code.replace /\s+/g, '' # remove whitespace
		else
			throw new SyntaxError( 'No Instruction Set Defined' )

		instructionCodes = code.split Symbol.instructionTerminator

		for instructionCode in instructionCodes
			@addInstructionCode instructionCode, descriptions
		
module?.exports = InterpretedProcessor
