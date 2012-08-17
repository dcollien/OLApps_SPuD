class Chip
	constructor: (definition) ->
		@readyCallbacks = []
		@updateCallbacks = []

		if @supportsWorkers()
			# init web worker script
			@worker = new Worker( './src/spudEmu.js' )
			@init definition
		else
			# no web worker support, run in browser window
			$.getScript './src/spudEmu.js', =>
				@worker = new BrowserEmu()
				@init definition

	init: (definition) ->
		@worker.onmessage (event) => 
			receivedData = (JSON.parse event.data)
			@receive receivedData.method, receivedData.data

		@worker.postMessage JSON.stringify( {
				method: 'init'
				data: definition
			} )

	supportsWorkers: -> false #(typeof window.Worker) is 'function'

	onReady: (callback) ->
		@readyCallbacks.push callback

	onUpdate: (callback) ->
		@updateCallbacks.push callback

	reset: -> @worker.postMessage 'reset'

	step: -> @worker.postMessage 'step'

	run: -> @worker.postMessage 'run'

	receive: (method, data) ->
		switch method
			when 'ready'
				for callback in @readyCallbacks
					callback data
			when 'update'
				state = data.state
				action = data.action
				args = data.arguments

				for callback in @updateCallbacks
					callback state, action, args
			when 'report'
				alert data
			else
				# no idea

