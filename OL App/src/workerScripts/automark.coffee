activityData = OpenLearning.page.getData( )

markObject = {}
files = {}

# check if a single file upload, or multiple files
# and build the "files" object
if (data.submission instanceof Array)
	# multiple files
	for file in data.submission
		files[file.filename] = file.data
else
	# single file
	file = data.submission
	files[file.filename] = file.data

filename = activityData.filename
expectedData = activityData.expectedData

# check to see if the specified file has the expected data
if files[filename]? and (files[filename].trim() is expectedData)
		# matches, woohoo!
		markObject = { completed: true, comments: '**Well Done!**' }
	else
		# no match
		markObject = { completed: false, comments: "**Didn't Match**") }

# bundle this mark into a marks update object
marks = {}
marks[data.user] = markObject

# save marks on openlearning
OpenLearning.activity.setMarks marks

