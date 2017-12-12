/**
 * @singleton
 * @presideservice
 *
 */
component {

	/**
	 * @emailServiceProviderService.inject emailServiceProviderService
	 * @emailLoggingService.inject         emailLoggingService
	 *
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
	public boolean function processNotification( required string messageId, required string messageEvent, struct postData={} ){
		var loggingService = _getEmailLoggingService();

		switch( arguments.messageEvent ) {
			case "opened":
				loggingService.markAsOpened( id=arguments.messageId );
			break;
			case "delivered":
				loggingService.markAsDelivered( id=arguments.messageId );
			break;
			case "dropped":
				loggingService.markAsFailed(
					  id     = arguments.messageId
					, reason = arguments.postData.description ?: ""
					, code   = arguments.postData.code        ?: ""
				);
			break;
			case "bounced":
				loggingService.markAsHardBounced(
					  id     = arguments.messageId
					, reason = arguments.postData.error ?: ""
					, code   = arguments.postData.code  ?: ""
				);
			break;
			case "unsubscribed":
				loggingService.markAsUnsubscribed( id=arguments.messageId );
			break;
			case "complained":
				loggingService.markAsMarkedAsSpam( id=arguments.messageId );
			break;
			case "clicked":
				loggingService.recordClick( id=arguments.messageId, link=arguments.postData.url ?: "" );
			break;
		}
		return true;
	}

	public boolean function validatePostHookSignature(
		  required numeric timestamp
		, required string  token
		, required string  signature
	) {
		var encryptionKey       = _getApiKey();

		if ( !encryptionKey.len() ) {
			throw( type="mailgun.api.key.not.configured", message="No API key is configured for the mailgun extension. This prevents the validation of Mailgun POST hooks." );
		}

		var encryptionData      = arguments.timestamp & arguments.token;
		var calculatedSignature = _hexEncodedSha256( encryptionData, encryptionKey );

		return arguments.signature == calculatedSignature;
	}

	public string function getPresideMessageIdForNotification( required struct postData ) {
		var messageId = postData.presideMessageId ?: "";

		if ( Len( Trim( messageId ) ) ) {
			return messageId;
		}

		var messageHeaders = parseMessageHeaders( arguments.postData[ "message-headers" ] ?: "" );
		return messageHeaders[ "X-Message-ID" ] ?: "";
	}

	public struct function parseMessageHeaders( required string headers ) {
		var parsed = {};
		var deserializedHeaders = [];
		var parseItemValue = function( value ) {
			if ( IsSimpleValue( value ) ) {
				return value;
			}
			if ( IsArray( value ) && value.len() == 2 ) {
				return {
					"#value[1]#" = parseItemValue( value[2] )
				};
			}

			return value;
		}

		try {
			deserializedHeaders = DeserializeJson( arguments.headers )
			for( var item in deserializedHeaders ) {
				parsed[ item[1] ] = parseItemValue( item[ 2 ] );
			}
		} catch( any e ) {
			deserializedHeaders = [];
		}

		return parsed;
	}

// PRIVATE HELPERS
	private string function _getApiKey(){
		return _getSettings().mailgun_api_key;
	}

	private struct function _getSettings(){
		if ( !request.keyExists( "_mailgunServiceProviderSettings" ) ) {
			var settings = _getEmailServiceProviderService().getProviderSettings( "mailgun" );

			request._mailgunServiceProviderSettings = {
				  mailgun_api_key        = settings.mailgun_api_key        ?: ""
				, mailgun_api_public_key = settings.mailgun_api_public_key ?: ""
				, mailgun_default_domain = settings.mailgun_default_domain ?: ""
				, mailgun_test_mode      = settings.mailgun_test_mode      ?: ""
			};
		}

		return request._mailgunServiceProviderSettings;
	}

	public string function _hexEncodedSha256( required string data, required string key ) {
		var secret = CreateObject( "java", "javax.crypto.spec.SecretKeySpec" ).Init( arguments.key.GetBytes(), "HmacSHA256" );
		var mac    = createObject( "java", "javax.crypto.Mac" ).getInstance( "HmacSHA256" );

		mac.init( secret );

		return _byteArrayToHex( mac.doFinal( arguments.data.GetBytes() ) );

	}

	public string function _byteArrayToHex( required any byteArray ) {
		var hexBytes = [];
		for( var byte in arguments.byteArray ) {
			var unsignedByte = bitAnd( byte, 255 );
			var hexChar      = FormatBaseN( unsignedByte, 16 );

			if ( unsignedByte < 16 ) {
				hexChar = "0" & hexChar;
			}
			hexBytes.append( hexChar );
		}

		return hexBytes.toList( "" );
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