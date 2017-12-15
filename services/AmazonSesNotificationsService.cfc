/**
 * @singleton
 * @presideservice
 *
 */
component {

	property name="dumplogservice" inject="dumplogservice";

	NL = server.separator.line;

	/**
	 * @emailServiceProviderService.inject emailServiceProviderService
	 * @emailLoggingService.inject         emailLoggingService
	 */
	public any function init(
		  required any emailServiceProviderService
		, required any emailLoggingService
	) {
		_setEmailServiceProviderService( arguments.emailServiceProviderService );
		_setEmailLoggingService( arguments.emailLoggingService );
		
		return this;
	}

// PUBLIC API METHODS
	public struct function parseMessage( required string messageContent ) {

		var content = arguments.messageContent;

		if ( isEmpty( content ) ) {
			return {};
		}

		// replacement needed as for whatever reason some weird chars are returned from SNS
		content = replace( content, "}=", "}", "all" );
		content = replace( content, "{=", "{", "all" );
		content = replace( content, '",=', '",', "all" );
		content = replace( content, '"=', '"', "all" );

		if ( !isJSON( content ) ) {
			return {};
		}

		var deserializedContent = deserializeJSON( content );

		if ( !isStruct( deserializedContent ) ) {
			return {};
		}

		return deserializedContent;
	}

	public boolean function isMessageSignatureValid( required struct message ) {

		var signatureVersion = arguments.message.SignatureVersion ?: "";
		var signingCertURL   = arguments.message.SigningCertURL   ?: "";
		var signature        = arguments.message.Signature        ?: "";

		dumplogservice.dumplog( ses="isMessageSignatureValid", signatureVersion=signatureVersion, signingCertURL=signingCertURL, signature=signature );

		if ( signatureVersion != "1" || isEmpty( signingCertURL ) || isEmpty( signature ) ) {
			return false;
		}

	    try {
	    	signingCertURL = _fixEncodedString( signingCertURL );
			
			dumplogservice.dumplog( ses="isMessageSignatureValid", signatureVersion=signatureVersion, signingCertURL=signingCertURL, signature=signature );

	        var javaUrl = createObject( "java", "java.net.URL" ).init( signingCertURL );

	        var inStream           = javaUrl.openStream();
	        var CertificateFactory = createObject( "java", "java.security.cert.CertificateFactory" );
	        var cf                 = CertificateFactory.getInstance( "X.509" );
	        var cert               = cf.generateCertificate( inStream );

	        inStream.close();

	        var Signature = createObject( "java", "java.security.Signature" );
	        var sig       = Signature.getInstance( "SHA1withRSA" );

	        sig.initVerify( cert.getPublicKey() );

	        var messageBytesToSign = _getMessageBytesToSign( arguments.message );

	        sig.update( messageBytesToSign );

	        //var Base64 = createObject( "java", "java.util.Base64" );
	        var base64Signature = toBase64( signature );
	        
			var result = sig.verify( base64Signature );

			dumplogservice.dumplog( ses="isMessageSignatureValid", base64Signature=base64Signature, result=result, messageBytesToSign=messageBytesToSign );

	        return result;
	    }
	    catch ( any e ) {
	    	dumplogservice.dumplog(ses="isMessageSignatureValid", error=e);
	    	rethrow;
	    }
	    return false;
	}

	public struct function parseNotification( required struct message ) {

		// the message content within the SNS wrapper message is again JSON serialized
		if ( arguments.message.keyExists( "Message" ) && isJSON( arguments.message.Message ) ) {
			arguments.message.Message = _fixEncodedString( arguments.message.Message );
			return deserializeJSON( arguments.message.Message );
		}

		return {};
	}

	public string function getPresideMessageIdForNotification( required struct notification ) {

		var mailHeaders = _parseMailHeaders( arguments.notification );

		return mailHeaders[ "X-Message-ID" ] ?: "";
	}

	public boolean function processNotification( required string messageId, required struct notification ) {

		var loggingService = _getEmailLoggingService();

		var notificationType = notification.notificationType ?: "";

		switch( notificationType ) {
			case "Delivery":
				loggingService.markAsDelivered( id=arguments.messageId );
			break;
			case "Bounce":
				loggingService.markAsHardBounced(
					  id     = arguments.messageId
					, reason = arguments.notification.bounce.bounceType ?: ""
				);
			break;
			case "Complaint":
				loggingService.markAsMarkedAsSpam( id=arguments.messageId );
			break;
		}
		return true;
	}

	public void function confirmSubscription( required struct message ) {

		var subscribeURL = trim( arguments.message.SubscribeURL ?: "" );

		if ( len( subscribeURL ) ) {
			var httpService = new http(
	              method  = "get"
	            , url     = _fixEncodedString( subscribeURL )
	            , timeout = 60
	        ); 

	        var httpResult = httpService.send().getPrefix();
        }
	}

// PRIVATE HELPERS
    private struct function _parseMailHeaders( required struct notification ) {
		
		var mail    = notification.mail ?: {};
		var headers = mail.headers      ?: [];
		var result  = {};

		for ( var header in headers ) {
			result[ header.name ] = header.value;
		}

		return result;
	}

	private any function _getMessageBytesToSign( required struct message ) {

	    if ( arguments.message.Type == "Notification" ) {
	        return _buildNotificationStringToSign( arguments.message ).getBytes();
	    }

	    if ( arguments.message.Type == "SubscriptionConfirmation" ) {
	        return _buildSubscriptionStringToSign( arguments.message ).getBytes();
	    }

	    return nullValue();
	}

	//Build the string to sign for Notification messages.
	private string function _buildNotificationStringToSign( required struct message ) {

	    //Build the string to sign from the values in the message.
	    //Name and values separated by newline characters
	    //The name value pairs are sorted by name 
	    //in byte sort order.
	    var stringToSign = "";

	    stringToSign &= "Message"                   & NL;
        stringToSign &= arguments.message.Message   & NL;
        stringToSign &= "MessageId"                 & NL;
        stringToSign &= arguments.message.MessageId & NL;

	    if ( arguments.message.keyExists( "Subject" ) && !isNull( arguments.message.Subject ) ) {
	        stringToSign &= "Subject"                 & NL;
	        stringToSign &= arguments.message.Subject & NL;
	    }

        stringToSign &= "Timestamp"                 & NL;
        stringToSign &= arguments.message.Timestamp & NL;
        stringToSign &= "TopicArn"                  & NL;
        stringToSign &= arguments.message.TopicArn  & NL;
        stringToSign &= "Type"                      & NL;
        stringToSign &= arguments.message.Type      & NL;

	    return stringToSign;
	}

	//Build the string to sign for SubscriptionConfirmation 
	//and UnsubscribeConfirmation messages.
	private string function _buildSubscriptionStringToSign( required struct message ) {
	    //Build the string to sign from the values in the message.
	    //Name and values separated by newline characters
	    //The name value pairs are sorted by name 
	    //in byte sort order.
	    var stringToSign = "";

	    stringToSign &= "Message"                      & NL;
	    stringToSign &= arguments.message.Message      & NL;
	    stringToSign &= "MessageId"                    & NL;
	    stringToSign &= arguments.message.MessageId    & NL;
	    stringToSign &= "SubscribeURL"                 & NL;
	    stringToSign &= arguments.message.SubscribeURL & NL;
	    stringToSign &= "Timestamp"                    & NL;
	    stringToSign &= arguments.message.Timestamp    & NL;
	    stringToSign &= "Token"                        & NL;
	    stringToSign &= arguments.message.Token        & NL;
	    stringToSign &= "TopicArn"                     & NL;
	    stringToSign &= arguments.message.TopicArn     & NL;
	    stringToSign &= "Type"                         & NL;
	    stringToSign &= arguments.message.Type         & NL;

	    return stringToSign;
	}

	private string function _fixEncodedString( required string s ) {
		return replaceList( arguments.s, "&lt;,&gt;,&amp;,&quot", '<,>,&,"' );
	}

	private any function _getEmailServiceProviderService() {
		return _emailServiceProviderService;
	}
	private void function _setEmailServiceProviderService( required any emailServiceProviderService ) {
		_emailServiceProviderService = arguments.emailServiceProviderService;
	}

	private any function _getEmailLoggingService() {
		return _emailLoggingService;
	}
	private void function _setEmailLoggingService( required any emailLoggingService ) {
		_emailLoggingService = arguments.emailLoggingService;
	}
}