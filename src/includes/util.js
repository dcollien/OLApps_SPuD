var render = function( template, view ) {
	view.app_init_js = request.appInitScript;
	view.csrf_token  = request.csrfFormInput;
	
	response.writeData( Mustache.render( template, view ) );
};

var checkPermission = function( permission, deniedTemplate, controller ) {
	var view;
	if ( request.sessionData.permissions.indexOf(permission) != -1 ) {
		controller( );
	} else {
		response.setStatusCode( 403 );
		view = { app_init_js: request.appInitScript };
		response.writeData( Mustache.render( deniedTemplate, view) );
	}
};
