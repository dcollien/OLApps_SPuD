class State
	constructor: (@processor, @changeHandler) ->
		@reset()

		if not @changeHandler
			@changeHandler = (event) ->
				if console.log
					console.log event
		
	eventFor: ->
		args = Array.prototype.slice.call arguments
		{
			state: @toObject()
			action: args[0]
			arguments: args[1..]
		}

	reset: ->
		@memory = []
		@registers = []

		@memory.push 0 for i in [0...@processor.numMemoryAddresses]
		@registers.push 0 for i in [0...@processor.numRegisters]

		@isHalted = false
		@output = ""
		@numBellRings = 0
		@pipelineStep = 0
		@executionStep = 0

		@changeHandler (@eventFor 'reset')
		
	constrainRegister: (value) ->
		mask = (1 << @processor.registerBitSize) - 1
		return (value & mask)

	constrainMemory: (value) ->
		mask = (1 << @processor.memoryBitSize) - 1
		return (value & mask)
		
	constrainAddress: (value) ->
		newValue = value % @processor.numMemoryAddresses
	    # wrap around negative addresses
		newValue += @processor.numMemoryAddresses if newValue < 0
		return newValue
	
	getRegister: (registerName) ->
		registerIndex = @processor.registerIndexLookup[registerName]
		return (@constrainRegister @registers[registerIndex])
		
	setRegister: (registerName, value) ->
		registerIndex = @processor.registerIndexLookup[registerName]
		newValue = @constrainRegister value

		if registerName is 'IP'
			newValue = @constrainAddress newValue
		
		@registers[registerIndex] = newValue

		@changeHandler (@eventFor 'setRegister', registerName, newValue)
		
	getMemory: (address) ->
		address = @constrainAddress address
		return @memory[address]
		
	setMemory: (address, value) ->
		address = @constrainAddress address
		newValue = @constrainMemory value
		@memory[address] = newValue

		@changeHandler (@eventFor 'setMemory', address, newValue)
		
	getAllMemory: ->
		return @memory.slice()
	
	setAllMemory: (values) ->
		for i in [0...@processor.numMemoryAddresses]
			if i < values.length
				@memory[i] = @constrainMemory values[i]
			else
				@memory[i] = 0

		@changeHandler (@eventFor 'setAllMemory', values)

	setAllRegisters: (values) ->
		for i in [0...@processor.numRegisters]
			if i < values.length
				@registers[i] = @constrainRegister values[i]
			else
				@registers[i] = 0

		@changeHandler (@eventFor 'setAllRegisters', values)

	nextStep: (pipelineLength) ->
		@pipelineStep = (@pipelineStep + 1) % pipelineLength

		# next pipeline step is the start of the cycle
		# a full step has been completed
		if @pipelineStep is 0 then @executionStep += 1

		@changeHandler (@eventFor 'nextStep', @pipelineStep, @executionStep)

	## Side effects
	
	print: (value) ->
		@output += value + ""
		@changeHandler (@eventFor 'print', value)
	
	printASCII: (value) ->
		@output += String.fromCharCode value
		@changeHandler (@eventFor 'printASCII', value)
	
	ringBell: ->
		@numBellRings += 1
		@changeHandler (@eventFor 'ringBell')
	
	halt: ->
		@isHalted = true
		@changeHandler (@eventFor 'halt')

	duplicate: ->
		newState = new State( processor )
		newState.fromObject @toObject()

		return newState

	## Serialisation

	fromObject: (state) ->
		@setAllMemory state.memory
		@setAllRegisters state.registers
		
		@isHalted = state.isHalted
		@output = state.output
		@numBellRings = state.numBellRings
		
		@pipelineStep = state.pipelineStep
		@executionStep = state.executionStep

		@changeHandler (@eventFor 'fromObject')

	toObject: ->
		{
			memory: @memory
			registers: @registers
			isHalted: @isHalted
			output: @output
			numBellRings: @numBellRings
			pipelineStep: @pipelineStep
			executionStep: @executionStep
		}

module?.exports = State
