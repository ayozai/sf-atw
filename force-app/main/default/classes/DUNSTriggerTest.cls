@isTest 
public class DUNSTriggerTest 
{   
    private static Account createAcc3() 
    {
        Account acc = new Account(
            Name='Test Account3',BillingCountry='Belgium',
            Global_Ultimate_Account__c='TestingaccGlob',Domestic_Ultimate_Account__c='TestingAccDom',
            DUNS__c='123456789',D_B_Parent_Account_D_U_N_S__c=null
        );
        insert acc;
        return acc;
    }

    private static Account createAcc2()
    {
        Account acc2 = new Account(
            Name='Test Account2',CurrencyIsoCode='EUR',BillingCountry='Belgium',
            Global_Ultimate_Account__c='TestingaccGlob',Domestic_Ultimate_Account__c='TestingAccDom',
            DUNS__c='123456789',Domestic_Ultimate_D_U_N_S__c='0123456',Global_Ultimate_D_U_N_S__c='0123456',HeadQuarter_D_U_N_S__c='s123456',D_B_Parent_Account_D_U_N_S__c='12345678'
        );
        insert acc2;
        return acc2;
    }

    private static Account createAcc()
    {
        Account acc = new Account(
            Name='Test Account1',CurrencyIsoCode='EUR',BillingCountry='Belgium',
            Global_Ultimate_Account__c='TestingaccGlob',Domestic_Ultimate_Account__c='TestingAccDom',
            Domestic_Ultimate_D_U_N_S__c='123456666',Global_Ultimate_D_U_N_S__c='123456666',DUNS__c='123456789',HeadQuarter_D_U_N_S__c='123456666',D_B_Parent_Account_D_U_N_S__c='123456161'
        );
        insert acc; 
        return acc;
    }
    
    private static Account createAccNoDomestic()
    {
        Account acc = new Account(
            Name='TestAccountforTest',CurrencyIsoCode='EUR',BillingCountry='Belgium',
            Global_Ultimate_Account__c='TestingaccGlob',Domestic_Ultimate_Account__c='TestingAccDom',
            DUNS__c='121345767',Domestic_Ultimate_D_U_N_S__c='123456000',Global_Ultimate_D_U_N_S__c='123456666',HeadQuarter_D_U_N_S__c='123456666',D_B_Parent_Account_D_U_N_S__c='123456666'
        );
        insert acc;
        return acc;
    }

    @isTest
    static void test_DUNSTriggerEmptyParent()
    {
       Account testAcc = createAcc3();
    }

    @isTest
    static void test_DUNSTrigger()
    {
        Account testAcc = createAcc();//normal account
    }

    @isTest
    static void test_DUNSTriggerNoDomesticCase()
    {
        Account testAcc3 = createAccNoDomestic();
    }
      
    @isTest
    static void test_DUNSTriggerUpdate()
    {
        Account testAcc = createAcc();

        // Reset transactional flag for second DML in test
        TriggerHelperAccount.DUNSAccountHierarchyUpdated = false;

        testAcc.name ='newName';
        update testAcc;
    }
        
}