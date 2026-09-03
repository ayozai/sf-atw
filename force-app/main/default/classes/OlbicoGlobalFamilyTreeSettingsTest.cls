@isTest
public class OlbicoGlobalFamilyTreeSettingsTest {

    private static OlbicoGlobalFamilyTreeSettings settings = null;
    
    static void createDefaultSettings() {
        
        OnBoardSettings__c n_settings = new OnBoardSettings__c();
        n_settings.Host__c = 'https://linkage-test-api.dqbox.com';
        n_settings.Version__c = 'v1';    
        n_settings.Username__c = 'your_user_name';
        n_settings.Password__c = 'your_password';
        n_settings.DunsFieldName__c = 'your_duns';
        n_settings.GlobalUltimateDunsFieldName__c = 'globo';
        n_settings.SearchMappingDunsField__c = 'companyDuns';
        n_settings.SearchMappingNameField__c = 'companyName';
        n_settings.SearchMappingCountryNameField__c = 'companyCountry';
        n_settings.SearchMappingCountryIsoCodeField__c = 'countryisocode';
        n_settings.SearchPageUrl__c = '/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.SearchPageUrlLightning__c = '/one/one.app#/alohaRedirect/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.CacheNamespace__c = 'KAAS';
        
        settings = new OlbicoGlobalFamilyTreeSettings(n_settings);
    }

    @isTest
    public static void testSettingsHostIsValid(){
        
        createDefaultSettings();
        System.assertEquals('https://linkage-test-api.dqbox.com', settings.Host);
    }

    @isTest
    public static void testSettingsUserNameIsValid(){
        
        createDefaultSettings();
        System.assertEquals('your_user_name', settings.UserName);
    }

    @isTest
    public static void test_Version(){
        
        createDefaultSettings();
        System.assertEquals('v1', settings.Version);
    }

    @isTest
    public static void testSettingsPasswordIsValid(){
     
        createDefaultSettings();
        System.assertEquals('your_password', settings.Password);
    }

    @isTest
    public static void testSettingsDunsFieldIsValid(){

        createDefaultSettings();
        System.assertEquals('your_duns', settings.DunsFieldName);
    }

    
    @isTest
    public static void test_GlobalUltimateDunsFieldName(){

        createDefaultSettings();
        System.assertEquals('globo', settings.GlobalUltimateDunsFieldName);
    }
    
    @isTest
    public static void testSettingsSearchMappingDunsFieldIsValid(){

        createDefaultSettings();
        System.assertEquals('companyDuns', settings.SearchMappingDunsField);
    }
    
    @isTest
    public static void testSettingsSearchMappingNameFieldIsValid(){

        createDefaultSettings();
        System.assertEquals('companyName', settings.SearchMappingNameField);
    }

    @isTest
    public static void testSettingsSearchMappingCountryNameFieldIsValid(){

        createDefaultSettings();
        System.assertEquals('companyCountry', settings.SearchMappingCountryNameField);
    }

    @isTest
    public static void test_SearchPageUrlLightning(){

        createDefaultSettings();
        System.assertEquals('/one/one.app#/alohaRedirect/apex/OlbicoCdpNewAccount?doInitialSearch=true', settings.SearchPageUrlLightning);
    }
    
    @isTest
    public static void test_SearchPageUrl(){

        createDefaultSettings();
        System.assertEquals('/apex/OlbicoCdpNewAccount?doInitialSearch=true', settings.SearchPageUrl);
    }

    @isTest
    public static void test_CacheNamespace(){

        createDefaultSettings();
        System.assertEquals('KAAS', settings.CacheNamespace);
    }
    
    @isTest
    public static void test_SearchMappingCountryIsoCodeField(){

        createDefaultSettings();
        System.assertEquals('countryisocode', settings.SearchMappingCountryIsoCodeField);
    }
    
    @isTest
    public static void testGetInstance(){
        
        // arrange
        OnBoardSettings__c n_settings = new OnBoardSettings__c();
        n_settings.Host__c = 'https://linkage-test-api.dqbox.com';
        n_settings.Version__c = 'v1';    
        n_settings.Username__c = 'abc';
        n_settings.Password__c = 'def';
        n_settings.DunsFieldName__c = 'nono';
        n_settings.GlobalUltimateDunsFieldName__c = 'kanarie-die-piepo';
        n_settings.SearchMappingDunsField__c = 'companyDuns';
        n_settings.SearchMappingNameField__c = 'companyName';
        n_settings.SearchMappingCountryNameField__c = 'companyCountry';
        n_settings.SearchMappingCountryIsoCodeField__c = 'countryisocode';
        n_settings.SearchPageUrl__c = '/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.SearchPageUrlLightning__c = '/one/one.app#/alohaRedirect/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.CacheNamespace__c = '';
        insert n_settings;
        
        // act
        OlbicoGlobalFamilyTreeSettings my_settings = OlbicoGlobalFamilyTreeSettings.getInstance();

        // assert
        System.assertEquals('https://linkage-test-api.dqbox.com', my_settings.Host);
        System.assertEquals('abc', my_settings.UserName);
        System.assertEquals('def', my_settings.Password);
        System.assertEquals('nono', my_settings.DunsFieldName);
        System.assertEquals('kanarie-die-piepo', my_settings.GlobalUltimateDunsFieldName);
        System.assertEquals('companyDuns', my_settings.SearchMappingDunsField);
        System.assertEquals('companyName', my_settings.SearchMappingNameField);
        System.assertEquals('companyCountry', my_settings.SearchMappingCountryNameField);
    }
}