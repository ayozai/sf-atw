@isTest
public without sharing class SCHEDULE_ContractAtRiskFYUpdate_Test 
{
    @isTest
    public static void SCHEDULE_ContractAtRiskFYUpdate_Test() 
    {
        // Data setup - copied from ContractUtils.testProcessAtRiskContractsStartOfYear()
        List<Account> accounts = TestData.createAccounts(10);
        insert accounts;
        List<Contract__c> contracts = TestData.createCustomerContracts(10, accounts);
        // Set different Status__ces and dates - 0, 1, 8 are the only ones at risk this year
        contracts[0].Status__c = 'Active';
        contracts[0].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[0].Contract_End_Date__c = Date.Today();
        contracts[0].Reference__c = 'Contract0';
        contracts[1].Status__c = 'Active';
        contracts[1].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[1].Contract_End_Date__c = Date.Today();
        contracts[1].Reference__c = 'Contract1';
        contracts[2].Status__c = 'Ended';
        contracts[2].Contract_Start_Date__c = Date.Today().addYears(-2);
        contracts[2].Contract_End_Date__c = Date.Today().addYears(-1);
        contracts[2].Reference__c = 'Contract2';
        contracts[3].Status__c = 'Ended';
        contracts[3].Contract_Start_Date__c = Date.Today().addYears(-2);
        contracts[3].Contract_End_Date__c = Date.Today().addYears(-1);
        contracts[3].Reference__c = 'Contract3';
        contracts[4].Status__c = 'Active';
        contracts[4].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[4].Contract_End_Date__c = Date.Today().addYears(1);
        contracts[4].Reference__c = 'Contract4';
        contracts[5].Status__c = 'Active';
        contracts[5].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[5].Contract_End_Date__c = Date.Today().addYears(1);
        contracts[5].Reference__c = 'Contract5';
        contracts[6].Status__c = 'Active';
        contracts[6].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[6].Contract_End_Date__c = Date.Today().addYears(2);
        contracts[6].Reference__c = 'Contract6';
        contracts[7].Status__c = 'Active';
        contracts[7].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[7].Contract_End_Date__c = Date.Today().addYears(2);
        contracts[7].Reference__c = 'Contract7';
        contracts[8].Status__c = 'Active';
        contracts[8].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[8].Contract_End_Date__c = Date.newInstance(Date.Today().year(), 12, 31);
        contracts[8].Reference__c = 'Contract8';
        contracts[9].Status__c = 'Active';
        contracts[9].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[9].Contract_End_Date__c = Date.newInstance(Date.Today().year() + 1, 1, 1);
        contracts[9].Reference__c = 'Contract9';
        insert contracts;

        Test.StartTest();

        SCHEDULE_ContractAtRiskFYUpdate scheduledJob = new SCHEDULE_ContractAtRiskFYUpdate();
        scheduledJob.execute(null);

        Test.StopTest();

        contracts = [SELECT Id,At_Risk_This_FY__c,At_Risk_Start_of_Year_Date__c,Contract_Start_Date__c,Contract_End_Date__c,Status__c FROM Contract__c WHERE Id IN :contracts AND At_Risk_This_FY__c = true];
        System.assertEquals(3, contracts.size());
        for (Contract__c contract : contracts)
        {
            System.assertEquals(Date.newInstance(Date.Today().year(), 1, 1), contract.At_Risk_Start_of_Year_Date__c, 'Current year should be populated on this at risk contract!');
        }
    }
}