if module?.exports
	Instruction = require '../Instruction'

class DelegateInstruction extends Instruction
	constructor: (description, ipIncrement, @delegate) ->
		super description, ipIncrement
	
	execute: (state) ->
		@delegate state

module?.exports = DelegateInstruction
