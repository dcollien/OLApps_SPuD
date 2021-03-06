class Chip
	constructor: (definition, workerScript) ->
		@runSpeed = 50
		@isRunning = false
		@isSpeedRunning = false

		@readyCallbacks = []
		@updateCallbacks = []
		@runUpdateCallbacks = []
		@reportCallbacks = []
		@testCompleteCallbacks = []

		if @supportsWorkers()
			# init web worker script

			if console?
				console.log 'Using Worker'

			@worker = new Worker( workerScript )
			@init definition
		else
			# no web worker support, run in browser window
			$.getScript workerScript, =>
				@worker = new BrowserEmu()
				@init definition

	init: (definition) ->
		@worker.onmessage = (event) =>
			receivedData = (JSON.parse event.data)
			@receive receivedData.method, receivedData.data
		
		@worker.postMessage JSON.stringify( {
				method: 'init'
				data: definition
			} )

	supportsWorkers: -> (typeof window.Worker) is 'function'

	onReady: (callback) ->
		@readyCallbacks.push callback

	onUpdate: (callback) ->
		@updateCallbacks.push callback

	onRunUpdate: (callback) ->
		@runUpdateCallbacks.push callback

	onTestComplete: (callback) ->
		@testCompleteCallbacks.push callback

	onReport: (callback) ->
		@reportCallbacks.push callback

	reset: -> @worker.postMessage 'reset'

	step: -> @worker.postMessage 'step'

	run: -> 
		if @isRunning
			@isRunning = false
		else
			@isRunning = true
			@runUpdate()

	runUpdate: ->
		@step()
		if @isRunning
			setTimeout (=> @runUpdate()), @runSpeed

	speedRun: -> 
		@isSpeedRunning = true
		@worker.postMessage 'run'

	setState: (state) ->
		@worker.postMessage JSON.stringify( {
			method: 'updateState'
			data: state
		} )

	updateRegister: (registerName, value) ->
		@worker.postMessage JSON.stringify( {
				method: 'updateRegister'
				data: {
					'registerName': registerName
					'value': value
				}
			} )

	updateMemory: (memoryAddress, value) ->
		@worker.postMessage JSON.stringify( {
				method: 'updateMemory'
				data: {
					'memoryAddress': memoryAddress
					'value': value
				}
			} )

	updateAllRegisters: (values) ->
		@worker.postMessage JSON.stringify( {
				method: 'updateAllRegisters'
				data: {
					'values': values
				}
			} )

	runTest: (testName, setup, checks, registers, memory, maxCycles=null) ->
		dataObj = {
			'testName': testName
			'setup': setup
			'checks': checks
			'registers': registers
			'memory': memory
		}

		if maxCycles
			dataObj.maxCycles = maxCycles

		@worker.postMessage JSON.stringify( {
				method: 'test'
				data: dataObj
			} )

	receive: (method, data) ->
		switch method
			when 'ready'
				for callback in @readyCallbacks
					callback data
			when 'runUpdate'
				for callback in @runUpdateCallbacks
					callback data
			when 'update'
				state = data.state
				action = data.action
				args = data.arguments

				if data.state.isHalted
					@isRunning = false
					@isSpeedRunning = false

				for callback in @updateCallbacks
					callback state, action, args
			when 'report'
				if data.reason is 'runPaused'
					@isSpeedRunning = false
				
				for callback in @reportCallbacks
					callback data

			when 'test-complete'
				for callback in @testCompleteCallbacks
					callback data
			else
				# no idea

