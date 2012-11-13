class BrowserEmu
	# pretending to be a Web Worker, but runs in the browser window
	
	constructor: ->
		@emu = new Emu(@)
		@emu.maxCycles = 32000
		@onmessage = ->
	
	send: (method, data) ->
		@onmessage
			data: JSON.stringify( {
				method: method,
				data: data
			} )

	postMessage: (message) ->
		try
			dataObject = JSON.parse message

			method = dataObject.method
			data   = dataObject.data
		catch e
			method = message
			data = null

		@emu.handleMessage method, data

