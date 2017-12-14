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
			event.renderData( type="text", data="Not acceptable: empty message type", statusCode=406 );
			dumplog( hookerror="Not acceptable: empty message type" );
		 	return;
		}

		if ( !VALID_MESSAGE_TYPES.findNoCase( messageType ) ) {
			event.renderData( type="text", data="Not acceptable: unknown message type '#messageType#'", statusCode=406 );
			dumplog( hookerror="Not acceptable: unknown message type '#messageType#'" );
		 	return;
		}

		var message = amazonSesNotificationsService.parseMessage( data.content ?: "" );

		dumplog( message=message );

		if ( isEmpty( message ) ) {
			event.renderData( type="text", data="Not acceptable: empty or not parsable message content", statusCode=406 );
			dumplog( hookerror="Not acceptable: empty or not parsable message content" );
		 	return;
		}

		if ( !amazonSesNotificationsService.isMessageSignatureValid( message ) ) {
			event.renderData( type="text", data="Not acceptable: invalid message signature", statusCode=406 );
			dumplog( hookerror="Not acceptable: invalid message signature" );
		 	return;
		}

		if ( messageType == "Notification" ) {
			var notification = amazonSesNotificationsService.parseNotification( message );
			dumplog( notification=notification );
			var presideMessageId = amazonSesNotificationsService.getPresideMessageId( notification );
			dumplog( presideMessageId=presideMessageId );

			if ( isEmpty( presideMessageId ) ) {
				event.renderData( type="text", data="Not acceptable: could not identify source preside message", statusCode=406 );
				dumplog( hookerror="Not acceptable: could not identify source preside message" );
				return;
			}

			amazonSesNotificationsService.processNotification(
				  messageId    = presideMessageId
				, notification = notification
			);

			event.renderData( type="text", data="Notification received and processed for preside message [#presideMessageId#]", statuscode=200 );
			dumplog( hooksuccess="Notification received and processed for preside message [#presideMessageId#]" );
		}
		else {
			// messageType == "SubscriptionConfirmation"
			amazonSesNotificationsService.confirmSubscription( message );
			event.renderData( type="text", data="Notification subscription confirmed.", statuscode=200 );
			dumplog( hooksuccess="Notification subscription confirmed." );
		}
	}
}