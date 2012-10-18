Automarker =
	###
	[
		{
			type: 'setMemory' or 'setRegister' or 'clearRegisters'
			key: registerName or memoryAddress,
			value: value to store
		}
	]
	###
	loadPreconditions: (preConditions, chip, processor) ->
		for preCondition in preConditions
			#console.log "setting", preCondition
			if preCondition.type is 'setMemory'
				chip.updateMemory preCondition.key, preCondition.value
			else if preCondition.type is 'setRegister'
				chip.updateRegister preCondition.key, preCondition.value
			else if preCondition.type is 'clearRegisters'
				for reg in processor.registerNames
					val = 0
					if preCondition.value?
						val = preCondition.value

					chip.updateRegister reg, val

	###
	[
		{
			type: 'function' or 'register' or 'memory' or 'output' or 'numRings'
			parameter: registerName or memoryAddress
			match: value
			check: function(state) ...
			correctComment: "Test passed",
			incorrectComment: "You didn't pass this test",
			optional: true
		}
	]
	###
	checkPostConditions: (postConditions, state, processor) ->
		isCompleted = true
		numCorrect = 0
		comment = ""
		for postCondition in postConditions
			#console.log 'checking', postCondition
			switch postCondition.type
				when 'function'
					correct = (postCondition.check state)
				when 'register'
					registerIndex = processor.registerIndexLookup[postCondition.parameter]
					correct = state.registers[registerIndex] is postCondition.match
				when 'memory'
					correct = state.memory[postCondition.parameter] is postCondition.match

				when 'output'
					match = postCondition.match.trim()
					output = (""+state.output).trim()
					if postCondition.parameter is "startswith"
						correct = output[0...match.length] is match
					else if postCondition.parameter is "endswith"
						correct = output[-match.length..] is match
					else if postCondition.parameter is "rstartswith"
						correct = match[0...output.length] is output
					else if postCondition.parameter is "rendswith"
						correct = match[-output.length..] is output
					else
						correct = output is match

				when 'numRings'
					correct = state.numBellRings is postCondition.match

			if correct
				comment += (postCondition.correctComment) + '\n'
				numCorrect += 1
			else
				comment += (postCondition.incorrectComment) + '\n'
				if postCondition.optional
					continue
				else
					isCompleted = false
					break

		return { completed: isCompleted, comment: comment, mark: numCorrect }

	mark: (definition, workerScript, program, preConditions, postConditions, callback) ->
		chip = new Chip( definition, workerScript )
		chip.onReady (processor) =>
			done = false
			#console.log 'ready'
			chip.setState program

			Automarker.loadPreconditions preConditions, chip, processor

			chip.onReport (report) =>
				if report.reason is 'runPaused'
					callback { completed: false, comment: "Execution timed out" }
					done = true

			chip.onRunUpdate (state) =>
				if state.isHalted and not done
					result = Automarker.checkPostConditions postConditions, state, processor
					#console.log state
					callback result

			#console.log "running"
			chip.speedRun()



			

