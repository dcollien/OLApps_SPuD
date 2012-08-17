class Processor4917 extends Processor
	constructor: (changeHandler) ->
		super "4917", changeHandler
		
		@memoryBitSize = 4
		@registerBitSize = 4
		@numMemoryAddresses = 16
		
		@setRegisterNames ['IP', 'IS', 'R0', 'R1']
		
		
		halt = (state) ->
			state.isHalted = true
		
		add = (state) ->
			r0 = state.getRegister "R0"
			r1 = state.getRegister "R1"
			
			state.setRegister "R0", r0+r1
		
		subtract = (state) ->
			r0 = state.getRegister "R0"
			r1 = state.getRegister "R1"
			
			state.setRegister "R0", r0-r1			
			
		incrementR0 = (state) ->
			r0 = state.getRegister "R0"
			state.setRegister "R0", r0+1
		
		incrementR1 = (state) ->
			r1 = state.getRegister "R1"
			state.setRegister "R1", r1+1
		
		decrementR0 = (state) ->
			r0 = state.getRegister "R0"
			state.setRegister "R0", r0-1

		decrementR1 = (state) ->
			r1 = state.getRegister "R1"
			state.setRegister "R1", r1-1
			
		ringBell = (state) ->
			state.ringBell( )
		
		print = (state) ->
			ip = state.getRegister "IP"
			data = state.getMemory (ip-1)
			state.print data
		
		loadR0 = (state) ->
			ip = state.getRegister "IP"
			address = state.getMemory (ip-1)
			
			state.setRegister "R0", (state.getMemory address)
		
		loadR1 = (state) ->
			ip = state.getRegister "IP"
			address = state.getMemory (ip-1)
			
			state.setRegister "R1", (state.getMemory address)
		
		storeR0 = (state) ->
			ip = state.getRegister "IP"
			address = state.getMemory (ip-1)
			
			state.setMemory address, (state.getRegister "R0")
		
		storeR1 = (state) ->
			ip = state.getRegister "IP"
			address = state.getMemory (ip-1)
			
			state.setMemory address, (state.getRegister "R1")
		
		jump = (state) ->
			ip = state.getRegister "IP"
			address = state.getMemory (ip-1)
			
			state.setRegister "IP", address
		
		jumpIfR0is0 = (state) ->
			if (state.getRegister "R0") == 0
				ip = state.getRegister "IP"
				address = state.getMemory (ip-1)
				state.setRegister "IP", address
		
		jumpIfR0not0 = (state) ->
			if (state.getRegister "R0") != 0
				ip = state.getRegister "IP"
				address = state.getMemory (ip-1)
				state.setRegister "IP", address
		
		ins = (description, ipIncrement, delegate) ->
			new DelegateInstruction( description, ipIncrement, delegate )
		
		@instructions = [
			ins( "Halt",                       1, halt ),
			ins( "Add (R0 = R0 + R1)",         1, add ),
			ins( "Subtract (R0 = R0 - R1)",    1, subtract ),
			ins( "Increment R0 (R0 = R0 + 1)", 1, incrementR0 ),
			ins( "Increment R1 (R1 = R1 + 1)", 1, incrementR1 ),
			ins( "Decrement R0 (R0 = R0 - 1)", 1, decrementR0 ),
			ins( "Decrement R1 (R1 = R1 - 1)", 1, decrementR1 ),
			ins( "Ring Bell",                  1, ringBell ),
			
			ins( "Print <data> (numerical value is printed)", 2, print ),
			ins( "Load value at address <data> into R0",      2, loadR0 ),
			ins( "Load value at address <data> into R1",      2, loadR1 ),
			ins( "Store R0 into address <data>",              2, storeR0 ),
			ins( "Store R1 into address <data>",              2, storeR1 ),
			ins( "Jump to address <data>",                    2, jump ),
			ins( "Jump to address <data> if R0 == 0",         2, jumpIfR0is0 ),
			ins( "Jump to address <data> if R0 != 0",         2, jumpIfR0not0 ),
		]
		
		