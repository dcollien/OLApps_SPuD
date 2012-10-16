var render = function( template, view ) {
	view.app_init_js = request.appInitScript;
	view.csrf_token  = request.csrfFormInput;
	
	response.writeData( Mustache.render( template, view ) );
};

var checkPermission = function( permission, deniedTemplate, controller ) {
	var view;
	if ( !request.sessionData || !request.sessionData.permissions ) {
		// no cookie
		response.setStatusCode( 403 );
		view = {
			app_init_js: request.appInitScript,
			redirect: true
		};
		response.writeData( Mustache.render( deniedTemplate ) );
	} else if ( request.sessionData.permissions.indexOf(permission) != -1 ) {
		// works
		controller( );
	} else {
		// access denied
		response.setStatusCode( 403 );
		view = { app_init_js: request.appInitScript };
		response.writeData( Mustache.render( deniedTemplate, view ) );
	}
};
