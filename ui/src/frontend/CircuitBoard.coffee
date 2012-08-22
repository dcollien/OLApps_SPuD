class CircuitBoard
	constructor: (@selector, @definition) ->
		@isOn = false
		@chip = new Chip( @definition )

		@isReady = false
		@isHalted = false
		@effectsEnabled = true

		@build()

		@chip.onReady (event) =>
			@buildInspector event
			@isReady = true
			@togglePower()

		@chip.onUpdate (state, action, args) =>
			if not @isOn then return

			@currentState = state

			switch action
				when 'ringBell'
					@ringBell()
					@updateRings state.numBellRings
				when 'print', 'printASCII'
					@output.text state.output
					#console.log state.output

				when 'setRegister'
					[register, value] = args

					if register is 'IP'
						@highlightCell value

					$('#register-' + register).val @formatValue(value)
				when 'setMemory'
					[address, value] = args
					
					$('#memory-' + address).val @formatValue(value)
				when 'nextStep'
					[pipelineStep, executionStep] = args
					
					@updateIP state
					@updateLEDs pipelineStep, executionStep

					@animateStep pipelineStep

					cycleText = executionStep + ' execution cycle'
					cycleText += 's' if (executionStep != 1)
					@cycleLabel.text cycleText

				when 'halt'
					@isHalted = true
					@haltedStatus.text 'Halted'

					# all LEDs on when halted
					$('.ledOn').removeClass( 'ledOn' )
					@ledOverlay.hide()
					$('.board-led').hide().stop true, true

					@fetchLED.addClass 'ledOn'
					@incrementLED.addClass 'ledOn'
					@executeLED.addClass 'ledOn'
					
					self = @
					flash = (led) ->
						$(led).fadeOut 'slow', ->
							if self.isHalted
								$(this).fadeIn 'fast', -> flash $(this)

					$('.board-led').fadeIn 'fast', -> flash this

					console.log 'halted'

				else
					@updateAll state

	updateRings: (bellRings) ->
		if bellRings is 1
			plural = ''
		else
			plural = 's'

		@bellOverlay.tooltip 'destroy'
		@bellOverlay.tooltip {
			placement: 'top'
			title: bellRings + ' bell ring' + plural
		}

	highlightCell: (cell) ->
		$('.highlighted-cell').removeClass('highlighted-cell')
		$('#memory-' + cell).addClass('highlighted-cell')

	updateIP: (state) ->
		if @properties?
			ip = @properties.registerIndexLookup['IP']
			@highlightCell state.registers[ip]

	clearHighlights: ->
		$('.fetch-highlight').removeClass 'fetch-highlight'
		$('.execute-highlight').removeClass 'execute-highlight'
		$('.increment-highlight').removeClass 'increment-highlight'

	animateStep: (pipelineStep) ->
		if !@effectsEnabled then return

		@clearHighlights()

		if @movingValue
			@movingValue.stop(true, true).remove()

		switch pipelineStep
			when 0
				$('#register-IS').addClass 'execute-highlight'
			when 1
				currentCell = $('.highlighted-cell')

				if currentCell.is(':visible')
					@movingValue = $('<span class="board-moving-value">').text currentCell.val()
					@chipBox.append @movingValue
					pos = currentCell.position()
					@movingValue.css {
						left: pos.left + 'px'
						top: pos.top + 'px'
						width: currentCell.width() + 'px'
						padding: currentCell.css('padding')
					}


					targetCell = $('#register-IS')
					targetValue = targetCell.val()
					targetCell.val ''
					targetPos = targetCell.position()

					@movingValue.animate {
						left: targetPos.left + 'px'
						top: targetPos.top + 'px'
						width: targetCell.width() + 'px'
						padding: targetCell.css('padding')
					}, 'slow', =>
						if @movingValue
							@movingValue.remove()
						@clearHighlights()
						targetCell.val targetValue
						targetCell.addClass 'fetch-highlight'
				else
					$('#register-IS').addClass 'fetch-highlight'

			when 2
				$('#register-IP').addClass 'increment-highlight'



	updateLEDs: (pipelineStep, executionStep) ->
		if @isHalted then return

		$('.board-led').hide().stop true, true

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

		$('.board-led').fadeIn 'fast'

	formatValue: (value) -> parseInt(value).toString(16).toUpperCase()

	updateAll: (state) ->
		@updateLEDs state.pipelineStep, state.executionStep
		@updateIP state

		for cell in [0...state.memory.length]
			memoryValue = state.memory[cell]
			$('#memory-' + cell).val @formatValue(memoryValue)

		if @properties?
			for reg in @properties.registerNames
				regIndex = @properties.registerIndexLookup[reg]
				regValue = state.registers[regIndex]
				$('#register-' + reg).val @formatValue(regValue)

		@output.text state.output

		@updateRings state.numBellRings

		cycleText = state.executionStep + ' execution cycle'
		cycleText += 's' if (state.executionStep != 1)
		@cycleLabel.text cycleText

		console.log state

	togglePower: ->
		if not @isReady then return

		if @isOn
			@background.removeClass 'on'
			@isOn = false

			@chipBox.fadeOut()
			$('.ledOn').removeClass( 'ledOn' )
			@ledOverlay.hide()
			@chipBox.fadeOut()

		else
			@background.addClass 'on'
			@isOn = true
			@chipBox.fadeIn()
			@reset()

		# TODO: humming

	reset: ->
		if @isOn
			@isHalted = false
			@haltedStatus.text ''
			@clearHighlights()
			@chip.reset()

	run: -> 
		if @isOn and not @isHalted
			@effectsEnabled = false
			@clearHighlights()
			@chip.run()

	step: ->
		if @isOn and not @isHalted
			@effectsEnabled = true
			@chip.step()

	ringBell: ->
		@bell.stop true, true
		@bell.addClass 'ringing'
		@bell.fadeOut 800, =>
			@bell.removeClass 'ringing'
			@bell.show()

	buildMemoryTable: (pageNum, numRows, numCols, properties) ->
		changeMemory   = (address, value) => @chip.updateMemory address, parseInt(value, 16)
		hoverCell = (cell) =>
			address = (cell.attr 'id').replace 'memory-', ''
			instruction = properties.instructions[parseInt(cell.val(), 16)]

			if instruction?
				@instructionHelp.text '[' + address + '] ' + cell.val() + ': ' + instruction.description

		unhoverCell = (cell) =>
			@instructionHelp.text ''

		$table = $('<table class="table table-bordered table-striped board-memory-table">')
		$table.attr 'id', ('memory-table-page-' + pageNum)

		cellNum = (numRows*numCols) * pageNum
		for i in [0...numRows]

			$row = $('<tr>')
			for j in [0...(numCols+1)]
				if j is 0
					$cell = $('<th>')
					$cell.text '0x' + @formatValue(cellNum)
				else
					$cell = $('<td>')

					if (cellNum < properties.numMemoryAddresses)
						$cellInput = $('<input type="text" class="board-memory-input">')
						$cellInput.attr 'maxlength', properties.memoryBitSize/4 # bits to hex
						$cellInput.attr 'id', ('memory-' + cellNum)
						$cellInput.change -> 
							cell = $(this)
							address = (cell.attr 'id').replace 'memory-', ''
							value = cell.val()
							changeMemory address, value
						$cellInput.click -> $(this).select()

						$cell.append $cellInput
						###
						$cell.tooltip {
							placement: 'left'
							title: ""+cellNum
						}
						###
						$cellInput.mouseout -> unhoverCell $(this)
						$cellInput.bind 'mouseover keyup change', -> hoverCell $(this)

					cellNum += 1
				
				$row.append $cell

			$table.append $row

		return $table

	buildMemoryPages: (properties, $memoryContainer) ->
		clickPagination = (link) =>
			page = $(link).data 'page'
			@hiddenTables.append @visibleTable
			@visibleTable = $('#memory-table-page-' + page)
			@tableBox.html @visibleTable
			$('.board-memory-pagination').find('.active').removeClass 'active'
			$('#memory-page-' + page).parent('li').addClass 'active'

			return false

		numAddresses = properties.numMemoryAddresses

		numRows = Math.min 8, (Math.floor (Math.sqrt numAddresses))
		numCols = Math.min 8, (numAddresses/numRows)
		
		pages = numAddresses / (numRows*numCols)

		@visibleTable = @buildMemoryTable 0, numRows, numCols, properties
		@hiddenTables = $('<div class="hide">')

		$paginationList = $('<ul>')
		$pagination = $('<center>').append $('<div class="well board-memory-pagination">').append( $paginationList )

		$pageLink = $('<a href="#">').text(0)
		$pageLink.attr 'id', 'memory-page-' + 0
		$pageLink.data 'page', 0
		$pageLink.click -> clickPagination this

		$paginationList.append $('<li class="active">').append( $pageLink )

		for pageNum in [1...pages]
			$table = @buildMemoryTable pageNum, numRows, numCols, properties
			@hiddenTables.append $table

			$pageLink = $('<a href="#">').text(pageNum)
			$pageLink.attr 'id', 'memory-page-' + pageNum
			$pageLink.data 'page', pageNum
			$pageLink.click -> clickPagination this
			$paginationList.append $('<li>').append( $pageLink )

		@tableBox = $('<center>')

		@tableBox.html @visibleTable

		$memoryContainer.append @tableBox

		if (pages > 1)
			$memoryContainer.append $pagination

	buildInspector: (properties) ->
		@properties = properties

		#properties.numMemoryAddresses = 1024

		changeRegister = (name, value) => @chip.updateRegister name, parseInt(value, 16)

		hoverRegister = (regInput) =>
			if (regInput.attr 'id') is 'register-IP'
				console.log val

				val = parseInt regInput.val(), 16

				$('#memory-' + val).addClass 'increment-highlight'
				@instructionHelp.text 'Instruction Pointer at Address: ' + val + ' (0x' + val.toString(16).toUpperCase() + ')'

			else if (regInput.attr 'id') is 'register-IS'
				instruction = @properties.instructions[parseInt(regInput.val(), 16)]

				if instruction?
					@instructionHelp.text regInput.val() + ': ' + instruction.description


		unhoverRegister = (regInput) =>
			$('.board-memory-input').removeClass 'increment-highlight'
			@instructionHelp.text ''


		$refTable = $('<table class="table table-bordered">')

		$reference = $('<div class="board-reference">').append $refTable

		$refTable.append(
			$('<tr>')
				.append($('<th>').text('#'))
				.append($('<th>').text('Hex'))
				.append($('<th>').text('Inc'))
				.append($('<th>').text('Description'))
		)

		i = 0
		for instruction in @properties.instructions
			row = $('<tr>')
			row.append( $('<td>').text i )
			row.append( $('<td>').text '0x' + i.toString(16).toUpperCase() )
			row.append( $('<td>').text instruction.ipIncrement )
			row.append $('<td>').text( instruction.description )
			$refTable.append row

			i += 1

		@instructionReference.html $reference

		@chipName.append $('<span>').text( properties.name )


		@toolbar = $('<div class="btn-toolbar board-toolbar">')

		$groupA = $('<div class="btn-group">')
		$groupB = $('<div class="btn-group">')
		$groupC = $('<div class="btn-group">')

		$saveBtn = $('<div class="btn btn-small">').html( $('<i class="icon-download">') ).tooltip
			title: 'Save Current State'
			placement: 'bottom'

		$saveBtn.click =>
			@savedState = @currentState

		$restoreBtn = $('<div class="btn btn-small">').html( $('<i class="icon-upload">') ).tooltip
			title: 'Restore State'
			placement: 'bottom'

		$restoreBtn.click =>
			if @savedState?
				console.log @savedState
				@chip.setState @savedState

		$uploadBtn = $('<div class="btn btn-small">').html( $('<i class="icon-download-alt"> ') ).tooltip
			title: 'Upload Program'
			placement: 'bottom'

		$uploadBtn.click =>
			@editor.dialog "open"

		$resetBtn = $('<div class="btn btn-small">').html( $('<i class="icon-off">') ).tooltip
			title: 'Reset'
			placement: 'bottom'

		$resetBtn.click =>
			@reset()

		###
		$helpBtn = $('<div class="btn btn-small">').html( $('<i class="icon-question-sign">') ).tooltip
			title: 'Instruction Set Reference'
			placement: 'bottom'

		$helpBtn.click =>
		###

		$groupA
			.append( $saveBtn )
			.append( $restoreBtn )
			.append( $uploadBtn )

		$groupB
			.append( $resetBtn )

		###
		$groupC
			.append( $helpBtn )
		###

		@toolbar
			.append( $groupA )
			.append( $groupB )

		###
			.append( $groupC )
		###

		@chipBox.append @toolbar

		$memoryContainer = $('<div class="board-memory-container">')

		@buildMemoryPages properties, $memoryContainer

		@chipBox.append $memoryContainer

		$registerContainer = $('<div class="board-register-container">')

		$table = $('<table class="table table-bordered table-striped board-register-table">')
		$headers = $('<tr>')
		$registers = $('<tr>')

		# maximum length of register rows
		maxRowLength = 6

		maxRowLength = Math.min maxRowLength, properties.registerNames.length
		rowLength = 0
		for registerName in properties.registerNames
			if (rowLength >= maxRowLength)
				rowLength = 0
				$table.append $headers
				$table.append $registers
				$headers = $('<tr>')
				$registers = $('<tr>')

			$headers.append $('<th>').text( registerName )
			$cell = $('<td>')
			$registerInput = $('<input type="text" class="board-register-input">')
			$registerInput.attr 'maxlength', properties.registerBitSize/4 # bits to hex
			$registerInput.attr 'id', 'register-' + registerName
			$registerInput.change -> 
				cell = $(this)
				name = (cell.attr 'id').replace 'register-', ''
				value = cell.val()
				changeRegister name, value
			$registerInput.mouseover -> hoverRegister $(this)
			$registerInput.mouseout -> unhoverRegister $(this)
			$registerInput.click -> $(this).select()

			$cell.append $registerInput
			$registers.append $cell

			rowLength += 1

		if rowLength isnt 0
			for i in [0...(maxRowLength-rowLength)]
				$headers.append $('<td>')
				$registers.append $('<td>')

			$table.append $headers
			$table.append $registers



		$registerContainer.append $('<center>').append( $table )

		@haltedStatus = $('<span class="board-halted-status">')
		@cycleLabel = $('<span class="board-cycle-status">')
		@cycleLabel.text '0 execution cycles'

		@instructionHelp = $('<div class="well board-instruction-help">')

		@status = $('<div class="board-status">')
		@status.append(@cycleLabel).append(@haltedStatus)


		@chipBox.append $registerContainer
		@chipBox.append @instructionHelp
		@chipBox.append @status
		@chipBox.append @hiddenTables

	uploadCode: ->
		code = @codeBox.val()

		instructions = (code.replace /\s+/g, ',').split ','

		memory = []
		for instruction in instructions
			instruction = instruction.replace /\s+/g, ''
			
			if @hexOption.prop 'checked'
				val = parseInt instruction, 16 # hex
			else
				val = parseInt instruction

			if instruction isnt '' and not (isNaN val)
				memory.push val

		@currentState = {
			memory: memory
			registers: []
			isHalted: false
			output: ''
			numBellRings: 0
			pipelineStep: 0
			executionStep: 0
		}

		console.log memory
		@chip.setState @currentState



	build: ->
		@board = $(@selector)

		$codeTab = $('<li class="active"><a href="#code" class="editor-tab">Code</a></li>')
		$refTab = $('<li><a href="#reference" class="editor-tab">Reference</a></li>')

		$tabs = $('<ul class="nav nav-tabs">')
			.append( $codeTab )
			.append( $refTab)

		@codeBox = $('<textarea class="board-code">')

		@hexOption = $('<input name="use-hex" type="checkbox" checked="checked">')
		@editor = $('<div class="board-editor" title="Upload Code">')


		$editorTab = $('<div class="tab-pane active" id="code">')
		$editorTab
			.append( @codeBox )
			.append( '<br/>' )
			.append( $('<label for="use-hex">').append(@hexOption).append( $('<span>').text ' Use Hexadecimal' ) )

		@instructionReference = $('<div class="tab-pane" id="reference">')

		$tabContent = $('<div class="tab-content">')
		$tabContent
			.append( $editorTab )
			.append( @instructionReference )


		@editor.append $tabs
		@editor.append $tabContent

		@background   = $('<div class="board-bg">')
		
		@powerSwitch  = $('<div class="board-power">')
		
		@bell         = $('<div class="board-bell">')

		@bellOverlay  = $('<div class="board-bell-overlay">')
		
		@fetchLED     = $('<div class="board-fetch board-led">')
		@incrementLED = $('<div class="board-increment board-led">')
		@executeLED   = $('<div class="board-execute board-led">')

		@output    = $('<div class="board-output-lcd">')

		@ledOverlay   = $('<div class="board-ledOverlay">')

		@resetButton = $('<div class="board-reset">')
		@runButton   = $('<div class="board-run">')
		@stepButton  = $('<div class="board-step">')

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
			title: 'Reset to zero'
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

		@chipName.click =>
			if @isOn
				@chipBox.fadeToggle()

		#@bell.click => @ringBell()

		@board.html @background
		@board.append @editor

		@background
			.append( @powerSwitch )
			.append( @bell )
			.append( @bellOverlay )
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

		uploadCode = => @uploadCode()
		@editor.dialog
			autoOpen: false
			width: 540
			buttons: {
				"Close": ->
					$(this).dialog "close"

				"Upload": ->
					uploadCode()
					$(this).dialog "close"
			}
			position: [20, 13]

		$('button').addClass 'btn'

		$('.editor-tab').click -> 
			$(this).tab( 'show' )
			return false








		