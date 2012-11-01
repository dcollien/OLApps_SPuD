Automarker =
	nextUpdate: ''
	###
	[
		{
			type: 'setMemory' or 'setRegister' or 'clearRegisters'
			key: registerName or memoryAddress,
			value: value to store
		}
	]
	###
	loadPrecondition: (preConditions, chip, processor, i) ->
		preCondition = preConditions[i]

		if preCondition.type is 'setMemory'
			Automarker.nextUpdate = 'setMemory'
			chip.updateMemory preCondition.key, preCondition.value
			
		else if preCondition.type is 'setRegister'
			Automarker.nextUpdate = 'setRegister'
			chip.updateRegister preCondition.key, preCondition.value
			
		else if preCondition.type is 'clearRegisters'
			registerValues = []
			for reg in processor.registerNames
				val = 0
				if preCondition.value?
					val = preCondition.value

				registerValues.push val
			Automarker.nextUpdate = 'setAllRegisters'
			chip.updateAllRegisters registerValues
		return (i+1)

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
					if console
						console.log output, match
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
		Automarker.nextUpdate = 'fromObject'
		chip = new Chip( definition, workerScript )
		chip.onReady (processor) =>
			done = false
			#console.log 'ready'
			preConditionIndex = 0

			chip.onReport (report) =>
				if report.reason is 'runPaused'
					callback { completed: false, comment: "Execution timed out" }
					done = true

			chip.onUpdate (state, action, args) =>
				if action is Automarker.nextUpdate
					if (preConditionIndex < preConditions.length)
						preConditionIndex = Automarker.loadPrecondition preConditions, chip, processor, preConditionIndex
					else
						chip.speedRun()

			chip.onRunUpdate (state) =>
				if state.isHalted and not done
					result = Automarker.checkPostConditions postConditions, state, processor
					#console.log state
					callback result

			chip.setState program

			



			

