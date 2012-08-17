class BrowserEmu
	# pretending to be a Web Worker, but runs in a browser window
	
	constructor: ->
		@messageCallbacks = []
		@maxCycles = 2048
	
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
				@send 'ready', {
					name: @processor.name
					memoryBitSize: @processor.memoryBitSize
					numMemoryAddresses: @processor.numMemoryAddresses
					registerBitSize: @processor.registerBitSize
					registerNames: @processor.registerNames
					registerIndexLookup: @processor.registerIndexLookup
					numRegisters: @processor.numRegisters
				}

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
