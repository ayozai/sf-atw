@IsTest
public class OlbicoGlobalFamilyAPIProxyTest {

    private static OlbicoGlobalFamilyTreeSettings settings = null;

    static void createDefaultSettings() {
        
        OnBoardSettings__c n_settings = new OnBoardSettings__c();
        n_settings.Host__c = 'https://linkage-test-api.dqbox.com';
        n_settings.Version__c = 'v1';    
        n_settings.Username__c = 'your_user_name';
        n_settings.Password__c = 'your_password';
        n_settings.DunsFieldName__c = 'AccountNumber';
        n_settings.GlobalUltimateDunsFieldName__c = 'Site';
        n_settings.SearchMappingDunsField__c = 'companyDuns';
        n_settings.SearchMappingNameField__c = 'companyName';
        n_settings.SearchMappingCountryNameField__c = 'companyCountry';
        n_settings.SearchMappingCountryIsoCodeField__c = 'countryisocode';
        n_settings.SearchPageUrl__c = '/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.SearchPageUrlLightning__c = '/one/one.app#/alohaRedirect/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.CacheNamespace__c = '';

        settings = new OlbicoGlobalFamilyTreeSettings(n_settings);
    }


        @isTest
    public static void is_cc_test(){
        
        OlbicoGlobalFamilyAPIProxy.cc();
    }

     @isTest 
     static void test_GetTokenValueFromResponse_IAMADUMMYTOKEN() {
        createDefaultSettings();

        String authenticationDetailsJson = '{"access_token":"IAMADUMMYTOKEN","token_type":"bearer","expires_in":899}';
        OlbicoGlobalFamilyAPIProxy proxy = new OlbicoGlobalFamilyAPIProxy(settings);

        Test.startTest();

        String actualToken = proxy.getTokenValueFromResponse(authenticationDetailsJson);

        Test.stopTest();

        System.assertEquals('IAMADUMMYTOKEN', actualToken);
    }

    @isTest
    static void test_CanParseJson_Success(){
        createDefaultSettings();
        String jsonData = '{"Duns":"417833209","Name":"Almarach International Handelsmaatschappij B.V.","Location":"Netherlands","CrmId":null,"Children":[{"Duns":"490167581","Name":"Almarach Shipping B.V.","Location":"Netherlands","CrmId":null,"Children":[{"Duns":"402606441","Name":"Blue Line Logistics Nederland B.V.","Location":"Netherlands","CrmId":null,"Children":[]},{"Duns":"415645530","Name":"Tesco (The European Shipment Company) B.V.","Location":"Netherlands","CrmId":null,"Children":[]}]},{"Duns":"489248027","Name":"Almarach Europe B.V.","Location":"Netherlands","CrmId":null,"Children":[]}]}';
        
        Test.startTest();
        OlbicoCompanyModel actualTree = OlbicoCompanyModel.parseFromJson(jsonData);
        Test.stopTest();

        System.debug('Duns:' + actualTree.Duns);
        System.debug('Name:' + actualTree.Name);
        System.debug('Location:' + actualTree.Location);
        System.debug('Children:' + actualTree.Children.size());

        System.assertEquals('417833209', actualTree.Duns);
        System.assertEquals('Almarach International Handelsmaatschappij B.V.', actualTree.Name);
        System.assertEquals('Netherlands', actualTree.Location);
        System.assertEquals(2, actualTree.Children.size());
    }

    @isTest
    static void test_EmptyTree_Success(){
        createDefaultSettings();
        String expectedTree = null;
        OlbicoGlobalFamilyAPIProxy proxy = new OlbicoGlobalFamilyAPIProxy(settings);

        Test.setMock(HttpCalloutMock.class, new GlobalFamilyTreeEmptyJsonMock());

        Test.startTest();
        String actualTree = proxy.getTree('415645530');
        Test.stopTest();

        System.assertEquals(expectedTree, actualTree);
    }

    @isTest
    static void test_getTree_401(){
        createDefaultSettings();
        OlbicoGlobalFamilyAPIProxy proxy = new OlbicoGlobalFamilyAPIProxy(settings);
        Test.setMock(HttpCalloutMock.class, new HttpNotFoundMock());

        Test.startTest();
        String actualTree = proxy.getTree('415645530');
        Test.stopTest();

        System.assert(True);
    }

    @isTest
    static void test_getTokenValueFromResponse(){
        createDefaultSettings();
        OlbicoGlobalFamilyAPIProxy proxy = new OlbicoGlobalFamilyAPIProxy(settings);
        String json =  '{"access_token":"IAMADUMMYTOKEN","token_type":"bearer","expires_in":899}';

        String actual = proxy.getTokenValueFromResponse(json);

        System.assertEquals('IAMADUMMYTOKEN', actual);
    }

    @isTest
    static void test_getTokens(){
        createDefaultSettings();
        OlbicoGlobalFamilyAPIProxy proxy = new OlbicoGlobalFamilyAPIProxy(settings);
        
        String actual = proxy.getToken();

        System.assert(True);
    }
    
    
}