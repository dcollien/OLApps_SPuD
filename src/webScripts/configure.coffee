include "mustache.js"
include "util.js"

template = include "adminTemplate.html"
accessDeniedTemplate = include "accessDeniedTemplate.html"

fields = ["definition", "startingState", "tests"]

# POST and GET controllers
post = ->
	# grab data from POST
	view = {}

	for field in fields
		view[field] = request.data[field]

	view.isEmbedded = true
	view.isFullWidth = true
	
	# set activity page data
	try
		OpenLearning.page.setData view, request.user
	catch err
		view.error = 'Something went wrong: Unable to save data'
	
	return view

get = ->
	view = {}

	# get activity page data
	try
		data = OpenLearning.page.getData( request.user ).data
	catch err
		view.error = 'Something went wrong: Unable to load data'
	
	if not view.error?
		# build view from page data
		for field in fields
			view[field] = data[field]

	return view


checkPermission 'write', accessDeniedTemplate, ->
	if request.method is 'POST'
		render template, post()
	else
		render template, get()

