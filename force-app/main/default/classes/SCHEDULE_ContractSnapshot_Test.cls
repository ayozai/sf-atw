/**
 * SCHEDULE_ContractSnapshot_Test
 * 
 * Test class for SCHEDULE_ContractSnapshot
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-06-15
 * 
 * Changes:
 */
@isTest
public without sharing class SCHEDULE_ContractSnapshot_Test 
{
    @isTest
    public static void SCHEDULE_ContractSnapshot_Test() 
    {
        Contract_Snapshot_Settings__c settings = Contract_Snapshot_Settings__c.getInstance();
        if (settings == null)
        {
            settings = new Contract_Snapshot_Settings__c();
        }
        settings.Error_Email_Recipients__c = UserInfo.getUserEmail();
        settings.Batch_Size__c = 100;
        upsert settings;

        // Data setup - copied from ContractUtils.testProcessAtRiskContractsStartOfYear()
        List<Account> accounts = TestData.createAccounts(10);
        insert accounts;
        List<Contract__c> contracts = TestData.createCustomerContracts(10, accounts);
        // Set different Status__ces and dates - 0, 1, 8 are the only ones at risk this year
        contracts[0].Status__c = 'Active';
        contracts[0].Contract_Start_Date__c = Date.Today().addYears(-1);
        contracts[0].Contract_End_Date__c = Date.Today();
        contracts[0].Reference__c = 'Contract0';
        contracts[0].CurrencyIsoCode = 'GBP';
        contracts[0].Effective_Monthly_Revenue__c = 10000.00;
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

        Contract__c contract = [SELECT Id,OwnerId,Status__c,Contract_Start_Date__c,Account__r.Name,Effective_Monthly_Revenue__c FROM Contract__c WHERE Id = :contracts[0].Id];

        List<Contract_Snapshot__c> snapshots = [SELECT Id,Customer_Contract_ID__c,Account_Name__c,Owner_ID__c,Status__c,Contract_Start_Date__c,Effective_Monthly_Revenue__c FROM Contract_Snapshot__c];
        System.assertEquals(0, snapshots.size());

        Test.StartTest();

        SCHEDULE_ContractSnapshot scheduledJob = new SCHEDULE_ContractSnapshot();
        scheduledJob.execute(null);

        Test.StopTest();

        snapshots = [SELECT Id,Customer_Contract_ID__c,Account_Name__c,Owner_ID__c,Status__c,Contract_Start_Date__c,Effective_Monthly_Revenue__c,CurrencyIsoCode FROM Contract_Snapshot__c];
        System.assertEquals(10, snapshots.size());
        Boolean found = false;
        for (Contract_Snapshot__c snapshot : snapshots)
        {
            if (snapshot.Customer_Contract_ID__c == contract.Id)
            {
                System.assertEquals(contract.OwnerId, snapshot.Owner_ID__c);
                System.assertEquals(contract.Account__r.Name, snapshot.Account_Name__c);
                System.assertEquals(contract.Status__c, snapshot.Status__c);
                System.assertEquals(contract.Contract_Start_Date__c, snapshot.Contract_Start_Date__c);
                System.assertEquals('EUR', snapshot.CurrencyIsoCode, 'Snapshot should always be captured in Euros');
                System.assertNotEquals(contract.Effective_Monthly_Revenue__c, snapshot.Effective_Monthly_Revenue__c, 'Snapshot amount should be converted from contract amount/currency');
                System.assertEquals(true, snapshot.Effective_Monthly_Revenue__c > 0.00, 'Snapshot amount should be greater than zero');
                found = true;
            }
        }
        System.assertEquals(true, found, 'Could not find matching contract to check snapshot values');
    }
}