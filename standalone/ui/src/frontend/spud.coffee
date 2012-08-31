$.fn.extend
	spud: ->
		self = $.fn.spud

		switch arguments[0]
			when 'setDefinition'
				definition = arguments[1]
				return $(@)

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
		circuitBoard = new CircuitBoard( element, options.definition, options.workerScript, options.startingState, options.audio )
		$(element).data 'spud', circuitBoard
