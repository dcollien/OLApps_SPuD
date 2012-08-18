class CircuitBoard
	constructor: (@selector, @definition) ->
		@isOn = false
		@chip = new Chip( @definition )

		@isReady = false
		@build()

		@chip.onReady (event) =>
			@updateUI event
			@isReady = true
			@togglePower()

		@chip.onUpdate (state, action, args) =>
			switch action
				when 'ringBell'
					@ringBell()
				when 'print', 'printASCII'
					@output.text state.output
				when 'setRegister'
					[register, value] = args

					if register is 'IP'
						@highlightCell value

					console.log action, args
				when 'setMemory'
					console.log action, args
				when 'nextStep'
					[pipelineStep, executionStep] = args
					
					@updateLEDs pipelineStep, executionStep
				when 'halt'
					console.log action
				else
					@updateAll state

	highlightCell: (cell) ->
		$('.highlighted-cell').removeClass('highlighted-cell')
		console.log $('#memory-' + cell).addClass('highlighted-cell')

	updateLEDs: (pipelineStep, executionStep) ->
		if not @isOn then return

		$('.ledOn').removeClass( 'ledOn' )
		@ledOverlay
			.show()
			.removeClass('fetch')
			.removeClass('increment')
			.removeClass('execute')

		switch pipelineStep
			when 0
				@fetchLED.addClass 'ledOn'
				@ledOverlay.addClass 'fetch'
			when 1
				@incrementLED.addClass 'ledOn'
				@ledOverlay.addClass 'increment'
			when 2
				@executeLED.addClass 'ledOn'
				@ledOverlay.addClass 'execute'

	updateAll: (state) ->
		@updateLEDs state.pipelineStep, state.executionStep
		console.log state

	togglePower: ->
		if not @isReady then return

		if @isOn
			@background.removeClass 'on'
			@isOn = false

			@chipBox.fadeOut()
			$('.ledOn').removeClass( 'ledOn' )
			@ledOverlay.hide()
		else
			@background.addClass 'on'
			@isOn = true
			@reset()

		# TODO: humming

	reset: -> @chip.reset() if @isOn

	run: -> @chip.run() if @isOn

	step: -> @chip.step() if @isOn

	ringBell: ->
		@bell.stop true, true
		@bell.addClass 'ringing'
		@bell.fadeOut 800, =>
			@bell.removeClass 'ringing'
			@bell.show()

	updateUI: (properties) ->
		@chipName.append $('<span>').text( properties.name )

		$memoryContainer = $('<div class="board-memory-container">')

		$table = $('<table class="table table-bordered table-striped board-memory-table">')

		numAddresses = properties.numMemoryAddresses
		numRows = Math.min 8, (Math.floor (Math.sqrt numAddresses))
		numCols = Math.min 8, (numAddresses/numRows)
		
		cellNum = 0
		for i in [0...numRows]

			$row = $('<tr>')
			for j in [0...(numCols+1)]
				if j is 0
					$cell = $('<th>')
					$cell.text cellNum
				else
					$cell = $('<td>')
					$cellInput = $('<input class="board-memory-input">')
					$cellInput.attr 'id', ('memory-' + cellNum)
					$cell.append $cellInput
					$cell.tooltip {
						placement: 'left'
						title: ""+cellNum
					}
					cellNum += 1
				
				$row.append $cell

			$table.append $row

		$memoryContainer.append $('<center>').append( $table )

		@chipBox.append $memoryContainer

		$registerContainer = $('<div class="board-register-container">')

		$table = $('<table class="table table-bordered table-striped board-register-table">')
		$headers = $('<tr>')
		$registers = $('<tr>')

		for registerName in properties.registerNames
			$headers.append $('<th>').text( registerName )
			$cell = $('<td>')
			$registerInput = $('<input class="board-register-input">')
			$registerInput.attr 'id', 'register-' + registerName
			$cell.append $registerInput
			$registers.append $cell

		$table.append $headers
		$table.append $registers

		$registerContainer.append $('<center>').append( $table )

		@chipBox.append $registerContainer






	build: ->
		@board = $(@selector)

		@background   = $('<div class="board-bg">')
		
		@powerSwitch  = $('<div class="board-power">')
		
		@bell         = $('<div class="board-bell">')
		
		@fetchLED     = $('<div class="board-fetch">')
		@incrementLED = $('<div class="board-increment">')
		@executeLED   = $('<div class="board-execute">')

		@ledOverlay   = $('<div class="board-ledOverlay">')

		@resetButton = $('<div class="board-reset">')
		@runButton   = $('<div class="board-run">')
		@stepButton  = $('<div class="board-step">')

		@output = $('<div class="board-output">')

		@chipName = $('<div class="board-chip">')

		@chipBox = $('<div class="board-chipbox arrow_box">')
		@chipBox.hide()

		@chipName.tooltip {
			placement: 'bottom'
			title: 'View Memory and Registers'
		}

		@ledOverlay.tooltip {
			placement: 'top'
			title: 'Next step to perform'
		}

		@resetButton.tooltip {
			placement: 'left'
			title: 'Reset to starting state'
		}

		@runButton.tooltip {
			placement: 'left'
			title: 'Run until halted'
		}

		@stepButton.tooltip {
			placement: 'bottom'
			title: 'Perform a single step'
		}

		@powerSwitch.click => @togglePower()

		@resetButton.click => @reset()
		@runButton.click   => @run()
		@stepButton.click  => @step()

		@chipName.click => @chipBox.fadeToggle()

		#@bell.click => @ringBell()

		@board.html @background
		@background
			.append( @powerSwitch )
			.append( @bell )
			.append( @fetchLED )
			.append( @incrementLED )
			.append( @executeLED )
			.append( @resetButton )
			.append( @runButton )
			.append( @stepButton )
			.append( @chipName )
			.append( @output )
			.append( @ledOverlay )
			.append( @chipBox )









		