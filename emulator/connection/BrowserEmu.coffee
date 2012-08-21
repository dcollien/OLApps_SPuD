class BrowserEmu
	# pretending to be a Web Worker, but runs in a browser window
	
	constructor: ->
		@messageCallbacks = []
		@maxCycles = 100
	
	defineProcessor: (definition) ->
		changeHandler = (event) => @send 'update', event

		@processor = new InterpretedProcessor( definition, changeHandler )

	send: (method, data) ->
		for callback in @messageCallbacks
			callback
				data: JSON.stringify( {
					method: method,
					data: data
				} )

	onmessage: (callback) ->
		@messageCallbacks.push callback

	postMessage: (message) ->
		try
			dataObject = JSON.parse message

			method = dataObject.method
			data   = dataObject.data
		catch e
			method = message
			data = null

		switch method
			when 'init'
				@processor = null
				@defineProcessor data

				instructions = []
				for instruction in @processor.instructions
					instructions.push
						description: instruction.description
						ipIncrement: instruction.ipIncrement

				@send 'ready', {
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

			when 'reset'
				if @processor?
					@processor.state.reset()

			when 'step'
				if @processor?
					@processor.step()

			when 'run'
				if @processor?
					@processor.run @maxCycles
					if not @processor.state.isHalted
						@send 'report', 'Maximum number of execution cycles exceeded. Execution paused.'
