Automarker =
	###
	[
		{
			type: 'memoryUpdate' or 'registerUpdate' or 'clearRegisters'
			key: registerName or memoryAddress,
			value: value to store
		}
	]
	###
	loadPreconditions: (preConditions, chip, processor) ->
		for preCondition in preConditions
			console.log "setting", preCondition
			if preCondition.type is 'memoryUpdate'
				chip.updateMemory preCondition.key, preCondition.value
			else if preCondition.type is 'registerUpdate'
				chip.updateRegister preCondition.key, preCondition.value
			else if preCondition.type is 'clearRegisters'
				for reg in processor.registerNames
					chip.updateRegister reg, 0

	###
	[
		{
			type: 'function' or 'register' or 'memory' or 'output' or 'numRings'
			parameter: registerName or memoryAddress
			match: value
			check: function(state) ...
			correctComment: "Test passed",
			incorrectComment: "You didn't pass this test"
		}
	]
	###
	checkPostConditions: (postConditions, state, processor) ->
		correct = true
		comment = ""
		for postCondition in postConditions
			console.log 'checking', postCondition
			switch postCondition.type
				when 'function'
					correct = (postCondition.check state)
				when 'register'
					registerIndex = processor.registerIndexLookup[postCondition.parameter]
					correct = state.registers[registerIndex] is postCondition.match
				when 'memory'
					correct = state.memory[postCondition.parameter] is postCondition.match
				when 'output'
					correct = (""+state.output).trim() is (""+postCondition.match).trim()
				when 'numRings'
					correct = state.numBellRings is postCondition.match

			if correct
				comment += (postCondition.correctComment) + '\n'
			else
				comment += (postCondition.incorrectComment) + '\n'
				break


		return { completed: correct, comment: comment }

	mark: (definition, workerScript, program, preConditions, postConditions, callback) ->
		chip = new Chip( definition, workerScript )
		chip.onReady (processor) =>
			done = false
			console.log 'ready'
			chip.setState program

			Automarker.loadPreconditions preConditions, chip, processor

			chip.onReport (report) =>
				if report.reason is 'runPaused'
					callback { completed: false, comment: "Execution timed out" }
					done = true

			chip.onRunUpdate (state) =>
				if state.isHalted and not done
					result = Automarker.checkPostConditions postConditions, state, processor
					callback result

			console.log "running"
			chip.speedRun()



			

