BusyBeaver =
	getProgramSize: (program) ->
		lastCell = program.memory.length - 1
		(lastCell--) while program.memory[lastCell] is 0

		return lastCell + 1

	run: (definition, workerScript, program, callback)  ->
		programSize = BusyBeaver.getProgramSize program
		chip = new Chip( definition, workerScript )
		chip.onReady (processor) =>
			done = false
			#console.log 'ready'
			preConditionIndex = 0

			chip.onReport (report) =>
				if report.reason is 'runPaused'
					callback { terminated: false, state: null, status: 'Maximum Execution Exceeded' }
					done = true

			chip.onRunUpdate (state) =>
				if state.isHalted and not done
					callback { terminated: state.isHalted, state: state, status: 'Done', size: programSize }
					done = true

			chip.onUpdate (state, action, args) =>
				if action == 'fromObject'
					chip.speedRun()

			registers = program.registers.slice(0)

			# clear registers
			for i in [0...registers.length]
				registers[i] = 0

			newProgram = {
				output: '',
				isHalted: 0,
				executionStep: 0,
				numBellRings: 0,
				pipelineStep: 0,
				memory: program.memory.slice(0),
				registers: registers
			}
			
			chip.setState newProgram