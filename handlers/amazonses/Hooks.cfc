component {

	VALID_MESSAGE_TYPES = [ "Notification", "SubscriptionConfirmation" ];

	property name="amazonSesNotificationsService" inject="amazonSesNotificationsService";

	public void function index( event, rc, prc ) {

		var data = getHTTPRequestData();
		var content = data.content ?: "";
		var headers = data.headers ?: {};

		var messageType = headers[ "x-amz-sns-message-type" ] ?: "";

		dumplog( messageType=messageType );

		if ( isEmpty( messageType ) ) {
			dumplog( hookerror="Not acceptable: empty message type" );
			event.renderData( type="text", data="Not acceptable: empty message type", statusCode=406 );
		 	return;
		}

		if ( !VALID_MESSAGE_TYPES.findNoCase( messageType ) ) {
			dumplog( hookerror="Not acceptable: unknown message type '#messageType#'" );
			event.renderData( type="text", data="Not acceptable: unknown message type '#messageType#'", statusCode=406 );
		 	return;
		}

		var message = amazonSesNotificationsService.parseMessage( data.content ?: "" );

		dumplog( message=message );

		if ( isEmpty( message ) ) {
			dumplog( hookerror="Not acceptable: empty or not parsable message content" );
			event.renderData( type="text", data="Not acceptable: empty or not parsable message content", statusCode=406 );
		 	return;
		}

		if ( !amazonSesNotificationsService.isMessageSignatureValid( message ) ) {
			dumplog( hookerror="Not acceptable: invalid message signature" );
			event.renderData( type="text", data="Not acceptable: invalid message signature", statusCode=406 );
		 	return;
		}

		if ( messageType == "Notification" ) {
			var notification = amazonSesNotificationsService.parseNotification( message );
			dumplog( notification=notification );
			var presideMessageId = amazonSesNotificationsService.getPresideMessageId( notification );
			dumplog( presideMessageId=presideMessageId );

			if ( isEmpty( presideMessageId ) ) {
				dumplog( hookerror="Not acceptable: could not identify source preside message" );
				event.renderData( type="text", data="Not acceptable: could not identify source preside message", statusCode=406 );
				return;
			}

			amazonSesNotificationsService.processNotification(
				  messageId    = presideMessageId
				, notification = notification
			);

			dumplog( hooksuccess="Notification received and processed for preside message [#presideMessageId#]" );
			event.renderData( type="text", data="Notification received and processed for preside message [#presideMessageId#]", statuscode=200 );
		}
		else {
			// messageType == "SubscriptionConfirmation"
			amazonSesNotificationsService.confirmSubscription( message );
			dumplog( hooksuccess="Notification subscription confirmed." );
			event.renderData( type="text", data="Notification subscription confirmed.", statuscode=200 );
		}
	}
}