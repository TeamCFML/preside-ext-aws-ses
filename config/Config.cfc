component {

	public void function configure( required struct config ) {
		var settings = arguments.config.settings ?: {};

		settings.email.serviceProviders.amazonses = {};
	}

}
