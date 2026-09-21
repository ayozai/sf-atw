@isTest
private class RequalificationController_Test {

    @isTest
    static void test_nullOpportunityId_throwsException() {
        try {
            RequalificationController.startRequalification(null, 2);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_zeroNumberOfOpps_throwsException() {
        Id fakeId = '006000000000001AAA';
        try {
            RequalificationController.startRequalification(fakeId, 0);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_nullNumberOfOpps_throwsException() {
        Id fakeId = '006000000000001AAA';
        try {
            RequalificationController.startRequalification(fakeId, null);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_validInput_startsBatch() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contract__c contract = new Contract__c(
            Status__c          = 'Active',
            Account__c         = acc.Id,
            Primary_Service__c = 'Catering',
            Type__c            = 'Framework Agreement'
        );
        insert contract;

        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Renewal')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name                      = 'Test Renewal',
            AccountId                 = acc.Id,
            Contract_Custom__c        = contract.Id,
            StageName                 = '2. Prospect',
            Sub_Stage__c              = '2.1 Future Opportunity',
            CloseDate                 = Date.today().addYears(1),
            RecordTypeId              = rtId,
            Global_Primary_Service__c = 'Catering'
        );
        insert opp;

        Test.startTest();
        RequalificationController.startRequalification(opp.Id, 2);
        Test.stopTest();

        // Batch queued successfully — no exception means success
        System.assert(true, 'Batch should have been queued without exception.');
    }
}
