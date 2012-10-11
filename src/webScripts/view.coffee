include "mustache.js"
include "util.js"

template = include "view.html"
accessDeniedTemplate = include "accessDeniedTemplate.html"

data = OpenLearning.page.getData( request.user ).data

definition = """
name: 4004
memoryBitSize: 4
numMemoryAddresses: 16
registerBitSize: 4
registerNames: IP, IS, R0, R1, SW

[descriptions]
0: Halt
1: Increment R0 (R0 = R0 + 1)
2: Decrement R0 (R0 = R0 - 1)
3: Increment R1 (R1 = R1 + 1)
4: Decrement R1 (R1 = R1 - 1)
5: Add (R0 = R0 + R1)	         				
6: Subtract (R0 = R0 - R1)
7: Print R0; Ring Bell
8: Jump to address <data> if R0 != 0
9: Jump to address <data> if R0 == 0
10: Load <data> in to R0
11: Load <data> in to R1
12: Store R0 into address <data>
13: Store R1 into address <data>
14: Swap R0 and address <data>
15: Swap R1 and address <data>

[instructions]
0, 1: halt.
1, 1: R0++.
2, 1: R0--.
3, 1: R1++.
4, 1: R1--.
5, 1: R0 = R0 + R1.
6, 1: R0 = R0 - R1.
7, 1: print(R0); bell.
8, 2 case R0 != 0: IP = [IP-1].
9, 2 case R0 == 0: IP = [IP-1].
10, 2: R0 = [IP-1].
11, 2: R1 = [IP-1].
12, 2: [[IP-1]] = R0.
13, 2: [[IP-1]] = R1.
14, 2: SW = [[IP-1]]; [[IP-1]] = R0; R0 = SW.
15, 2: SW = [[IP-1]]; [[IP-1]] = R1; R1 = SW.
"""

startingState = """
[memory]

7 0 0 0
0 0 0 0
0 0 0 0
0 0 0 0

[registers]

IP=0
IS=1
R0=0
R1=2
"""

tests = """
[
	{
		"name": "First Test",
		"setup": [ { "type": "clearRegisters" } ],
		"test": [
			{
				"type": "output",
				"match": "00",
				"correctComment": "Output Matches!",
				"incorrectComment": "Output Doesn't Match"
			},
			{
				"type": "register",
				"parameter": "R0",
				"match": 0,
				"correctComment": "Register Matches!",
				"incorrectComment": "Register Doesn't Match"
			}
		]
	}
]
"""

try
	tests = JSON.parse data.tests
	automarked = (tests instanceof Array) and (tests.length > 0)
catch err
	tests = []
	automarked = false

view =
	definition: data.definition
	startingState: data.startingState
	tests: data.tests
	automarked: automarked

checkPermission 'read', accessDeniedTemplate, ->
	render template, view