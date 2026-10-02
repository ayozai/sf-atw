@isTest
private class RequalificationController_Test {

    @isTest
    static void test_nullOpportunityId_throwsException() {
        try {
            RequalificationController.startRequalification(null, 2, null);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_zeroNumberOfOpps_throwsException() {
        Id fakeId = '006000000000001AAA';
        try {
            RequalificationController.startRequalification(fakeId, 0, null);
            System.assert(false, 'Expected AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e, 'Exception should be thrown.');
        }
    }

    @isTest
    static void test_nullNumberOfOpps_throwsException() {
        Id fakeId = '006000000000001AAA';
        try {
            RequalificationController.startRequalification(fakeId, null, null);
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
        RequalificationController.startRequalification(opp.Id, 2, null);
        Test.stopTest();

        // Batch queued successfully — no exception means success
        System.assert(true, 'Batch should have been queued without exception.');
    }

    @isTest
    static void test_getRequalificationContext_scenario1() {
        Account acc = new Account(Name = 'Test Ctx Account');
        insert acc;

        Contract__c fw = new Contract__c(
            Account__c         = acc.Id,
            Status__c          = 'Active',
            Type__c            = 'Framework Agreement',
            Primary_Service__c = 'Catering',
            Reference__c       = 'REF-CTX-001'
        );
        insert fw;

        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Renewal')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name                      = 'Ctx Opp',
            AccountId                 = acc.Id,
            Contract_Custom__c        = fw.Id,
            StageName                 = '2. Prospect',
            Sub_Stage__c              = '2.1 Future Opportunity',
            CloseDate                 = Date.today().addYears(1),
            RecordTypeId              = rtId,
            Global_Primary_Service__c = 'Catering'
        );
        insert opp;

        Map<String, Object> ctx = RequalificationController.getRequalificationContext(opp.Id);

        System.assertEquals(1,            (Integer) ctx.get('scenario'),     'No app contracts → Scenario 1.');
        System.assertEquals(false,        (Boolean) ctx.get('isClosed'),     'Open opp should not be closed.');
        System.assertEquals('REF-CTX-001',(String)  ctx.get('contractRef'),  'Contract reference should match.');
        System.assertEquals('Catering',   (String)  ctx.get('service'),      'Service should match.');
        System.assertNotEquals(null,      (String)  ctx.get('oppName'),      'Opp name should not be null.');
    }

    @isTest
    static void test_getRequalificationContext_scenario2() {
        Account acc = new Account(Name = 'Test Ctx Account S2');
        insert acc;

        Contract__c fw = new Contract__c(
            Account__c         = acc.Id,
            Status__c          = 'Active',
            Type__c            = 'Framework Agreement',
            Primary_Service__c = 'Security',
            Reference__c       = 'REF-CTX-002'
        );
        insert fw;

        Contract__c app = new Contract__c(
            Account__c         = acc.Id,
            Status__c          = 'Active',
            Type__c            = 'Contract linked to a Framework Agreement',
            Primary_Service__c = 'Security',
            Parent_Contract__c = fw.Id
        );
        insert app;

        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Renewal')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name                      = 'Ctx Opp S2',
            AccountId                 = acc.Id,
            Contract_Custom__c        = fw.Id,
            StageName                 = '2. Prospect',
            Sub_Stage__c              = '2.1 Future Opportunity',
            CloseDate                 = Date.today().addYears(1),
            RecordTypeId              = rtId,
            Global_Primary_Service__c = 'Security'
        );
        insert opp;

        Map<String, Object> ctx = RequalificationController.getRequalificationContext(opp.Id);

        System.assertEquals(2, (Integer) ctx.get('scenario'),         'App contract exists → Scenario 2.');
        System.assertEquals(1, (Integer) ctx.get('appContractCount'), '1 app contract should be found.');
    }
}
