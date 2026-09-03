@isTest
public class OlbicoAccountRepositoryTest {
    
    private static OlbicoGlobalFamilyTreeSettings settings = null;
    private static final Integer listSize = 100;
    
    private static String globalId = null;
    private static List<String> dunsNumbers = new List<String>();

    static void createDefaultSettings() {
        
        if (settings != null)
            return;

        OnBoardSettings__c n_settings = new OnBoardSettings__c();
        n_settings.Host__c = 'https://linkage-test-api.dqbox.com';
        n_settings.Version__c = 'v1';    
        n_settings.Username__c = 'your_user_name';
        n_settings.Password__c = 'your_password';
        n_settings.DunsFieldName__c = 'AccountNumber';
        n_settings.GlobalUltimateDunsFieldName__c = 'Site';
        n_settings.SearchMappingDunsField__c = 'companyDuns';
        n_settings.SearchMappingNameField__c = 'companyName';
        n_settings.SearchMappingCountryNameField__c = 'Netherlands';
        n_settings.SearchMappingCountryIsoCodeField__c = 'countryisocode';
        n_settings.SearchPageUrl__c = '/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.SearchPageUrlLightning__c = '/one/one.app#/alohaRedirect/apex/OlbicoCdpNewAccount?doInitialSearch=true';
        n_settings.CacheNamespace__c = '';

        settings = new OlbicoGlobalFamilyTreeSettings(n_settings);
 
        dunsNumbers = new List<String>();
        globalId = generateRandomId();
        
        List<Account> accounts = new List<Account>{};
        
        for(Integer i = 0; i < listSize; i++){

            String dunsNumber = generateRandomId();
            Account a = new Account(Name = 'Test Account ' + i);
            
            a.put('BillingCity', 'TestCity ' + i);
            a.put('BillingCountry','Netherlands');
            a.put(settings.DunsFieldName, dunsNumber);
            a.put(settings.GlobalUltimateDunsFieldName, globalId);

            accounts.add(a);
            dunsNumbers.add(dunsNumber);
        }

        insert accounts;
    }

    @isTest
    public static void test_GetAccountsByDunsNumbers_NoGlobalUltimate_Success(){        
        createDefaultSettings();
        OlbicoAccountRepository target = new OlbicoAccountRepository(settings);

        Test.startTest();
        Map<String,List<Account>> actual = target.getAccountsByDunsNumbers(dunsNumbers);        
        Test.stopTest();

        System.assertEquals(actual.size(), listSize);
    }

    @isTest
    public static void test_GetAccountsByGlobalUltimate_WithGlobalUltimate_Success(){
        createDefaultSettings();
        OlbicoAccountRepository target = new OlbicoAccountRepository(settings);

        List<Account> accounts = new List<Account>{};
        String globalUltiId = generateRandomId();

        for(Integer i = 0; i < listSize; i++){
            Account a = new Account(Name = 'TESTING ACCOUNT ' + i);

            a.put('BillingCity', 'TestCity ' + i);
            a.put('BillingCountry','Netherlands');
            a.put(settings.DunsFieldName, generateRandomId());
            a.put(settings.GlobalUltimateDunsFieldName, globalUltiId);

            accounts.add(a);
        }

        Test.startTest();
        
        insert accounts;

        Pattern accNameRegex = Pattern.compile('^TESTING\\sACCOUNT\\s\\d{1,3}$');
        Map<String,List<Account>> db_accounts = target.getAccountsByGlobalUltimate(globalUltiId);

        Test.stopTest();

        Integer validGlobalUltimateIdCount = 0;
        for(String key : db_accounts.keySet()){
            Account c_acc = db_accounts.get(key).get(0);

            Matcher matcher = accNameRegex.matcher(c_acc.Name);
            Boolean valid = (matcher.matches() && (String)c_acc.get(settings.GlobalUltimateDunsFieldName)== globalUltiId);

            System.assert(valid);

            if(valid) validGlobalUltimateIdCount++;
        }

        System.assert(validGlobalUltimateIdCount >= listSize);
        System.assert(db_accounts.size() >= listSize);        
    }

    @isTest
    public static void test_GetById_Success(){
        createDefaultSettings();
        OlbicoAccountRepository target = new OlbicoAccountRepository(settings);

        Account acc = new Account();
        acc.Name = 'TEST ACCOUNT 123456';
        acc.BillingCity = 'Test1';
        acc.BillingCountry = 'Netherlands';
        insert acc;

        acc = [SELECT Id, Name FROM Account WHERE Name=:acc.Name LIMIT 1];

        acc = target.getById(acc.Id);

        System.assert(acc != null);
        System.assertEquals('TEST ACCOUNT 123456', acc.Name);
    }

    @isTest
    public static void test_slice(){

        createDefaultSettings();
        OlbicoAccountRepository target = new OlbicoAccountRepository(settings);

        List<String> vals = new List<String>();
        for (Integer i=0; i<10; i++) {
            vals.add('Test-' + i);
        }

        List<string> actual = OlbicoAccountRepository.slice(vals, 2, 3);
        // assert
        System.assertEquals(3, actual.size());
    }

    @isTest
    public static void test_GetById_NullAccount_Success(){
        createDefaultSettings();
        OlbicoAccountRepository target = new OlbicoAccountRepository(settings);

        Account acc = target.getById(null);

        System.assert(acc == null);
    }

    @isTest
    public static void test_GetById_NonExistingAccount_Success(){
        createDefaultSettings();
        OlbicoAccountRepository target = new OlbicoAccountRepository(settings);

        Account acc = target.getById('XXX');

        System.assert(acc == null);
    }

    private static String generateRandomId(){
        Integer len = 32;
        Blob blobKey = crypto.generateAesKey(128);
        String key = EncodingUtil.convertToHex(blobKey);
        
        return key.substring(0, len);
    }
}