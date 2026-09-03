@isTest
private class TestAgencyTrigger {
    @isTest static void TestAgencyTrigger() {
        // Test data setup
        // Create an agency with an assite, and then try to update it
        Agency__c agency = new Agency__c(Agency_Name__c='Test Agency', OwnerId='005D000000AWfkAIAT',Country__c='FR');
        insert agency;
        Accounting_System_Site__c assite = new Accounting_System_Site__c (Name='Test Agency Assite', Site__c='Test Agency Assite',
                                        Agency__c=agency.Id, OwnerId='005D000000AWfkAIAT');
        insert assite ;
        // Perform test
        Test.startTest();
        agency.OwnerId = '0054G000008yNg8QAE';
        update agency;
        Test.stopTest();
    }
}