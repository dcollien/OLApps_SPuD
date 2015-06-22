if module?.exports
	State = require './State'

class Processor
	constructor: (@name, changeHandler) ->
		# some defaults
		@memoryBitSize = 4
		@registerBitSize = 4
		@numMemoryAddresses = 16
		
		@instructions = []
		console.log @
		@setRegisterNames ['IP', 'IS']
		
		@state = new State( this, changeHandler )

		# default pipeline
		fetch = (state) ->
			instruction = state.getMemory (state.getRegister 'IP')
			state.setRegister 'IS', instruction
	
		inc = (state) ->
			ip = state.getRegister 'IP'
			instructionNum = state.getRegister 'IS'

			instruction = null

			if (instructionNum < state.processor.instructions.length)
				instruction = state.processor.instructions[instructionNum]

			ipIncrement = 1
			
			if instruction
				ipIncrement = instruction.ipIncrement

			state.setRegister 'IP', ip + ipIncrement
	
		exec = (state) ->
			instructionNum = state.getRegister 'IS'

			instruction = null

			if (instructionNum < state.processor.instructions.length)
				instruction = state.processor.instructions[instructionNum]

			if instruction
				instruction.execute state
			
		@pipeline = [fetch, inc, exec]
		
	step: ->
		if @state.isHalted then return

		@pipeline[@state.pipelineStep] @state
		@state.nextStep @pipeline.length

	run: (maxCycles) ->
		cycle = 0
		maxSteps = maxCycles * @state.processor.pipeline.length
		while (cycle < maxSteps) and !@state.isHalted
			@step()
			cycle += 1
	
	setRegisterNames: (names) ->
		@registerIndexLookup = { }
		@registerNames = names
		@numRegisters = names.length
		
		hasIS = false
		hasIP = false
		
		for i in [0...@numRegisters]
			name = names[i]
			@registerIndexLookup[name] = i
			
			hasIP = true if name is 'IP'
			hasIS = true if name is 'IS'
			
		unless hasIS and hasIP
			throw new Error( "Processor must have both IP and IS registers" )
	
module?.exports = Processor
