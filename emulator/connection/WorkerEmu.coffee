# worker for talking to the processor
class WorkerEmu
	constructor: ->
		@emu = new Emu(@)

	receive: (method, data) ->
		@emu.handleMessage method, data

	send: (method, data) ->
		payload = JSON.stringify( {
			method: method,
			data: data
		} )

		self.postMessage payload

if not window? or not window.document?
	board = new WorkerEmu()

	messageListener = (event) ->
		try
			payload = JSON.parse event.data
		catch e
			payload =
				method: event.data
		board.receive payload.method, payload.data

	self.addEventListener 'message', messageListener, false






