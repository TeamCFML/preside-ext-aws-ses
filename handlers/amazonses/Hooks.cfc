component {

	property name="amazonSesNotificationsService" inject="amazonSesNotificationsService";

	public void function index( event, rc, prc ) {

		var data = getHTTPRequestData();
		var content = data.content ?: "";
		var headers = data.headers ?: {};

		var messageType = headers[ "x-amz-sns-message-type" ] ?: "";

		if ( isEmpty( messageType ) ) {
		//	return;
		}

		if ( messageType == "SubscriptionConfirmation" ) {

			//return;
		}

		if ( messageType == "Notification" ) {

		}

		content = replaceList( content, "&lt;,&gt;,&amp;,&quot", '<,>,&,"' );
		content = replace( content, "}=", "}", "all" );
		content = replace( content, "{=", "{", "all" );
		content = replace( content, '",=', '",', "all" );
		content = replace( content, '"=', '"', "all" );

		var deserializedContent = "";

		if ( isJSON( content ) ) {
			deserializedContent = deserializeJSON( content );
		}

		//var decodedData = amazonSesNotificationsService.decodeMessage( getPageContext() );
		dumplog( amazonses="hooks", content=content, headers=headers, messageType=messageType, deserializedContent=deserializedContent );

		event.renderData( type="text", data="Notification of event received and processed", statuscode=200 );

		// TODO: also deal with subscribe notification

		// deliberate use of form scope here. DO NOT CHANGE.
		// this is because 'event' is overridden in rc scope by coldbox
		/*
		var validRequest = amazonSesNotificationsService.validatePostHookSignature(
			  timestamp = Val( form.timestamp ?: "" )
			, token     = form.token     ?: ""
			, signature = form.signature ?: ""
		);

		if ( validRequest ) {
			var presideMessageId = amazonSesNotificationsService.getPresideMessageIdForNotification( form );

			if ( presideMessageId.trim().len() ) {
				var messageEvent = form.event ?: "";
				amazonSesNotificationsService.processNotification(
					  messageId    = presideMessageId
					, messageEvent = messageEvent
					, postData     = form
				);
				event.renderData( type="text", data="Notification of [#messageEvent#] event received and processed for preside message [#presideMessageId#]", statuscode=200 );
			} else {
				event.renderData( type="text", data="Not acceptable: could not identify source preside message", statusCode=406 );
			}
		} else {
			event.renderData( type="text", data="Not acceptable: invalid request signature", statusCode=406 );
		}*/



	}

}