class DelegateInstruction extends Instruction
	constructor: (description, ipIncrement, @delegate) ->
		super description, ipIncrement
	
	execute: (state) ->
		@delegate state
