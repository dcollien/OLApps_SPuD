class Emu
	constructor: (@connection) ->
		@maxCycles = 524288
		@bufferSize = 32768
		@eventCounter = 0
		@isRunning = false
	
	defineProcessor: (definition) ->
		changeHandler = (event) => 
			if @isRunning

				@eventCounter += 1
				if @eventCounter > @bufferSize
					@connection.send 'runUpdate', event.state
					@eventCounter = 0

			else
				@connection.send 'update', event

		@processor = new InterpretedProcessor( definition, changeHandler )

	handleMessage: (method, data) ->
		switch method
			when 'init'
				@processor = null
				@defineProcessor data

				instructions = []
				for instruction in @processor.instructions
					instructions.push
						description: instruction.description
						ipIncrement: instruction.ipIncrement

				@connection.send 'ready', {
					name: @processor.name
					memoryBitSize: @processor.memoryBitSize
					numMemoryAddresses: @processor.numMemoryAddresses
					registerBitSize: @processor.registerBitSize
					registerNames: @processor.registerNames
					registerIndexLookup: @processor.registerIndexLookup
					numRegisters: @processor.numRegisters
					instructions: instructions
				}

			when 'updateRegister'
				name = data.registerName
				value = data.value
				@processor.state.setRegister name, value

			when 'updateMemory'
				address = data.memoryAddress
				value = data.value
				@processor.state.setMemory address, value

			when 'updateState'
				@processor.state.fromObject data

			when 'reset'
				if @processor?
					@processor.state.reset()

			when 'step'
				if @processor?
					@processor.step()

			when 'run'
				if @processor?
					@isRunning = true
					@processor.run @maxCycles
					if not @processor.state.isHalted
						@connection.send 'report', { message: 'Maximum number of execution cycles exceeded. Execution paused.', reason: 'runPaused' }
					@isRunning = false
					@connection.send 'runUpdate', @processor.state.toObject()
