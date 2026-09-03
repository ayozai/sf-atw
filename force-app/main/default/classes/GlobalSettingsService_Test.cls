@isTest
public with sharing class GlobalSettingsService_Test {

    @IsTest
	static void testGetTranscoMappings(){
	    List<global_settings__c> globalSettings = new List<global_settings__c>();
		globalSettings.add(new global_settings__c( name ='batch_ws_report_mail_receiver' ,key__c = 'batch_ws_report_mail_receiver',value__c = 'boussad.chalal.ext@atalianworld.com'));
		
		insert globalSettings;

		Test.startTest();

        GlobalSettingsService.loadMappingService();

        System.debug('========================== GlobalSettingsService_Test 1 START');
        String mailString = GlobalSettingsService.getValueSetting('batch_ws_report_mail_receiver');
		System.assertEquals(mailString, 'boussad.chalal.ext@atalianworld.com');        
        System.debug('========================== GlobalSettingsService_Test 1 END');

        String errorString = GlobalSettingsService.getValueSetting('ERROR');
		System.assertEquals(errorString, 'No Mapping');        


		Test.stopTest();

	}
}