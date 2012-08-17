# worker for talking to the processor

if not window.document?
	board = WorkerEmu()

	messageListener = (event) ->
		payload = JSON.parse event
		board.receive payload.method, payload.data

	self.addEventListener 'message', messageListener, false

class WorkerEmu
	constructor: ->

	receive: (method, data) ->

	send: (method, data) ->
		payload = JSON.stringify( {
			method: method,
			data: data
		} )

		self.postMessage payload




