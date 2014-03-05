class Emu
	constructor: (@connection) ->
		@maxCycles = 524288
		@bufferSize = 32768
		@eventCounter = 0
		@isRunning = false
	
	defineProcessor: (definition) ->
		changeHandler = (event) => 
			if @isRunning

				@eventCounter += 1
				if @eventCounter > @bufferSize
					@connection.send 'runUpdate', event.state
					@eventCounter = 0

			else
				@connection.send 'update', event

		testProcessorChangeHandler = (event) =>


		@processor = new InterpretedProcessor( definition, changeHandler )
		@testProcessor = new InterpretedProcessor( definition, testProcessorChangeHandler )

	handleMessage: (method, data) ->
		switch method
			when 'init'
				@processor = null
				@defineProcessor data

				instructions = []
				for instruction in @processor.instructions
					instructions.push
						description: instruction.description
						ipIncrement: instruction.ipIncrement

				@connection.send 'ready', {
					name: @processor.name
					memoryBitSize: @processor.memoryBitSize
					numMemoryAddresses: @processor.numMemoryAddresses
					registerBitSize: @processor.registerBitSize
					registerNames: @processor.registerNames
					registerIndexLookup: @processor.registerIndexLookup
					numRegisters: @processor.numRegisters
					instructions: instructions
				}

			when 'updateRegister'
				name = data.registerName
				value = data.value
				@processor.state.setRegister name, value

			when 'updateMemory'
				address = data.memoryAddress
				value = data.value
				@processor.state.setMemory address, value

			when 'updateAllRegisters'
				@processor.state.setAllRegisters data.values

			when 'updateState'
				@processor.state.fromObject data

			when 'reset'
				if @processor?
					@processor.state.reset()

			when 'step'
				if @processor?
					@processor.step()

			when 'run'
				if @processor?
					@isRunning = true
					@processor.run @maxCycles
					if not @processor.state.isHalted
						@connection.send 'report', { message: 'Maximum number of execution cycles exceeded. Execution paused.', reason: 'runPaused' }
					@isRunning = false
					@connection.send 'runUpdate', @processor.state.toObject()

			when 'test'
				if @testProcessor?
					testName = data.testName # e.g. 'check all the things'
					registers = data.registers # e.g. { 'IP': 0, 'IS': 0, 'R0': 0 }
					memory = data.memory # e.g. [0, 0, 0, 0 ....]
					setup = data.setup
					checks = data.checks

					maxCycles = @maxCycles
					if data.maxCycles?
						maxCycles = data.maxCycles

					@testProcessor.state.reset()
					
					# load in the initial state
					for register, value of registers
						@testProcessor.state.setRegister register, value

					for i in [0...memory.length]
						@testProcessor.state.setMemory i, memory[i]

					# make any setup modifications
					for step in setup
						switch step.type
							when 'setMemory'
								@testProcessor.state.setMemory step.key, step.value
							when 'setRegister'
								@testProcessor.state.setRegister step.key, step.value
							when 'clearRegisters'
								val = 0
								if step.value?
									val = step.value

								regValues = []
								for register in @testProcessor.registerNames
									regValues.push val

								@testProcessor.state.setAllRegisters regValues

					# run the testProcessor
					@testProcessor.run maxCycles
					isHalted = @testProcessor.state.isHalted

					isSuccess = false
					numCorrect = 0
					feedback = ''

					if isHalted
						# it's halted properly, let's check if it was correct
						isSuccess = true
						state = @testProcessor.state.toObject()

						for check in checks
							correct = false

							switch check.type
								when 'register'
									registerIndex = @testProcessor.registerIndexLookup[check.parameter]
									correct = state.registers[registerIndex] is check.match

								when 'memory'
									correct = state.memory[check.parameter] is check.match

								when 'output'
									match = check.match.trim()
									output = (''+state.output).trim()

									if check.parameter is "startswith"
										correct = output[0...match.length] is match
									else if check.parameter is "endswith"
										correct = output[-match.length..] is match
									else if check.parameter is "rstartswith"
										correct = match[0...output.length] is output
									else if check.parameter is "rendswith"
										correct = match[-output.length..] is output
									else if check.parameter is "not"
										correct = output isnt match
									else
										correct = output is match

								when 'numRings'
									correct = state.numBellRings is check.match

							if correct
								feedback += (check.correctComment) + '\n'
								numCorrect += 1
							else
								feedback += (check.incorrectComment) + '\n'
								if check.optional
									# go onto the next check
									continue
								else
									# stop checking, it's broken
									isSuccess = false
									break
					else
						# didn't halt
						feedback += 'Did not halt!\n'
						isSuccess = false

					@connection.send 'test-complete', {
						'name': testName
						'isSuccess': isSuccess
						'feedback': feedback
						'numCorrect': numCorrect
					}

