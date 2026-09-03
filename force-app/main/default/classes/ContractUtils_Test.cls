@isTest
public without sharing class ContractUtils_Test 
{
    @isTest
    private static void testBuildQueryStringForAtRiskContractsStartOfYear()
    {
        String queryString = ContractUtils.buildQueryStringForAtRiskContractsStartOfYear();
        System.assertNotEquals(null, queryString, 'Query string is missing!');
        List<Contract__c> contracts = Database.query(queryString); // SOQL compiles and runs
    }

    @isTest
    private static void testProcessAtRiskContractsStartOfYear()
    {
        List<Account> accounts = TestData.createAccounts(10);
        insert accounts;
        List<Contract__c> contracts = TestData.createCustomerContracts(10, accounts);
        // Set different Status__ces and dates - 0, 1, 8 are the only ones at risk this year
        contracts[0].Status__c = 'Active';
        contracts[0].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[0].Contract_End_Date__c = Date.Today();
        contracts[0].Reference__c = 'Contract0';
        contracts[0].Primary_Service__c = 'Technical Services';
        contracts[1].Status__c = 'Active';
        contracts[1].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[1].Contract_End_Date__c = Date.Today();
        contracts[1].Reference__c = 'Contract1';
        contracts[1].Primary_Service__c = 'Technical Services';
        contracts[2].Status__c = 'Ended';
        contracts[2].Contract_Start_Date__c = Date.Today().addYears(-2);
        contracts[2].Contract_End_Date__c = Date.Today().addYears(-1);
        contracts[2].Reference__c = 'Contract2';
        contracts[2].Primary_Service__c = 'Technical Services';
        contracts[3].Status__c = 'Ended';
        contracts[3].Contract_Start_Date__c = Date.Today().addYears(-2);
        contracts[3].Contract_End_Date__c = Date.Today().addYears(-1);
        contracts[3].Reference__c = 'Contract3';
        contracts[3].Primary_Service__c = 'Technical Services';
        contracts[4].Status__c = 'Active';
        contracts[4].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[4].Contract_End_Date__c = Date.Today().addYears(1);
        contracts[4].Reference__c = 'Contract4';
        contracts[4].Primary_Service__c = 'Technical Services';
        contracts[5].Status__c = 'Active';
        contracts[5].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[5].Contract_End_Date__c = Date.Today().addYears(1);
        contracts[5].Reference__c = 'Contract5';
        contracts[5].Primary_Service__c = 'Technical Services';
        contracts[6].Status__c = 'Active';
        contracts[6].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[6].Contract_End_Date__c = Date.Today().addYears(2);
        contracts[6].Reference__c = 'Contract6';
        contracts[6].Primary_Service__c = 'Technical Services';
        contracts[7].Status__c = 'Active';
        contracts[7].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[7].Contract_End_Date__c = Date.Today().addYears(2);
        contracts[7].Reference__c = 'Contract7';
        contracts[7].Primary_Service__c = 'Technical Services';
        contracts[8].Status__c = 'Active';
        contracts[8].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[8].Contract_End_Date__c = Date.newInstance(Date.Today().year(), 12, 31);
        contracts[8].Reference__c = 'Contract8';
        contracts[8].Primary_Service__c = 'Technical Services';
        contracts[9].Status__c = 'Active';
        contracts[9].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[9].Contract_End_Date__c = Date.newInstance(Date.Today().year() + 1, 1, 1);
        contracts[9].Reference__c = 'Contract9';
        contracts[9].Primary_Service__c = 'Technical Services';
        insert contracts;

        contracts = [SELECT Id,At_Risk_This_FY__c,At_Risk_Start_of_Year_Date__c,Contract_Start_Date__c,Contract_End_Date__c,Status__c FROM Contract__c WHERE Id IN :contracts];

        List<Contract__c> processedContracts;

        Test.StartTest();
        
        processedContracts = ContractUtils.processAtRiskContractsStartOfYear(contracts);
        
        Test.StopTest();

        system.assertEquals(3, processedContracts.size());
    }

    @isTest
    private static void testUpdateContracts()
    {
        List<Account> accounts = TestData.createAccounts(10);
        insert accounts;
        List<Contract__c> contracts = TestData.createCustomerContracts(10, accounts);
        for (Integer i= 0; i < contracts.size(); i++)
        {
            contracts[i].Reference__c = 'Contract'+i;
        }
        insert contracts;

        Boolean success;

        Test.StartTest();
        
        success = ContractUtils.updateContracts(contracts, null);
        
        Test.StopTest();

        system.assertEquals(true, success, 'Failed to blank update contract records!');
    }
}