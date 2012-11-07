$.fn.extend
	spud: ->
		self = $.fn.spud

		switch arguments[0]
			when 'setDefinition'
				definition = arguments[1]
				return $(@)
			when 'automark'
				preConditions = arguments[1]
				postConditions = arguments[2]
				callback = arguments[3]

				return $(@).each (index, element) ->
					self.automark element, preConditions, postConditions, callback
			when 'enableSound'
				return $(@).each (index, element) ->
					self.enableSound element

			when 'disableSound'
				return $(@).each (index, element) ->
					self.disableSound element

			when 'toggleSound'
				return $(@).each (index, element) ->
					self.toggleSound element

			when 'busybeaver'
				callback = arguments[1]
				return $(@).each (index, element) ->
					self.busybeaver element, callback

			else
				options = arguments[0]

				if (typeof options is 'string')
					options = {
						definition: options
					}

				opts = $.extend {}, self.defaultOptions, options

				return $(@).each (index, element) ->
					self.init element, opts

$.extend $.fn.spud,
	defaultOptions: {}

	init: (element, options) ->
		circuitBoard = new CircuitBoard( element, options.definition, options.workerScript, options.startingState, options.soundEnabled, options.onSave, options.onLoad )
		$(element).data 'spud', circuitBoard
	
	enableSound: (element) ->
		circuitBoard = $(element).data 'spud'
		circuitBoard.enableSound()

	disableSound: (element) ->
		circuitBoard = $(element).data 'spud'
		circuitBoard.disableSound()

	toggleSound: (element) ->
		circuitBoard = $(element).data 'spud'
		if circuitBoard.soundEnabled
			circuitBoard.disableSound()
		else
			circuitBoard.enableSound()

	automark: (element, preConditions, postConditions, callback) ->
		circuitBoard = $(element).data 'spud'
		circuitBoard.automark preConditions, postConditions, callback

	busybeaver: (callback) ->
		circuitBoard = $(element).data 'spud'
		circuitBoard.busybeaver callback


