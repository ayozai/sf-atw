@isTest
private class RequalificationBatch_Test {

    // ── Test data helpers ─────────────────────────────────────────────────────

    static Account createAccount() {
        Account acc = new Account(Name = 'Test Account Requalif');
        insert acc;
        return acc;
    }

    static Contract__c createContract(Id accountId) {
        Contract__c c = new Contract__c(
            Status__c          = 'Active',
            Account__c         = accountId,
            Primary_Service__c = 'Catering',
            Type__c            = 'Framework Agreement'
        );
        insert c;
        return c;
    }

    static Contract__c createAppContract(Id accountId, Id parentContractId) {
        Contract__c c = new Contract__c(
            Status__c           = 'Active',
            Account__c          = accountId,
            Primary_Service__c  = 'Catering',
            Parent_Contract__c  = parentContractId
        );
        insert c;
        return c;
    }

    static Opportunity createRenewalOpp(Account acc, Contract__c contract) {
        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Renewal')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name                      = 'Test Renewal Opp',
            AccountId                 = acc.Id,
            Contract_Custom__c        = contract.Id,
            StageName                 = '2. Prospect',
            Sub_Stage__c              = '2.1 Future Opportunity',
            CloseDate                 = Date.today().addYears(1),
            RecordTypeId              = rtId,
            Global_Primary_Service__c = 'Catering'
        );
        insert opp;
        return opp;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @isTest
    static void test_batch_updatesOriginAndCreatesNewOpps() {
        Account     acc      = createAccount();
        Contract__c contract = createContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, 3, UserInfo.getUserId()),
            1
        );
        Test.stopTest();

        // Origin opp should be Requalification / 6.1 Closed Lost
        Opportunity updatedOrigin = [
            SELECT StageName, Sub_Stage__c
            FROM   Opportunity
            WHERE  Id = :origin.Id
        ];
        System.assertEquals('Requalification', updatedOrigin.StageName,
            'Origin StageName should be Requalification.');
        System.assertEquals('6.1 Closed Lost', updatedOrigin.Sub_Stage__c,
            'Origin Sub_Stage__c should be 6.1 Closed Lost.');

        // 3 new Global_Renewal opportunities should be created on the same contract
        List<Opportunity> newOpps = [
            SELECT Id, StageName, Sub_Stage__c, Contract_Custom__c, RecordType.DeveloperName
            FROM   Opportunity
            WHERE  Id != :origin.Id
              AND  Contract_Custom__c = :contract.Id
        ];
        System.assertEquals(3, newOpps.size(), '3 new opportunities should be created.');
        for (Opportunity o : newOpps) {
            System.assertEquals('2. Prospect',          o.StageName,
                'New opp StageName should be 2. Prospect.');
            System.assertEquals('2.1 Future Opportunity', o.Sub_Stage__c,
                'New opp Sub_Stage__c should be 2.1 Future Opportunity.');
            System.assertEquals('Global_Renewal',       o.RecordType.DeveloperName,
                'New opp RecordType should be Global_Renewal.');
            System.assertEquals(contract.Id,            o.Contract_Custom__c,
                'New opp should be linked to the same framework contract.');
        }
    }

    @isTest
    static void test_batch_withAppContracts_closesThemAsReallocated() {
        Account     acc            = createAccount();
        Contract__c framework      = createContract(acc.Id);
        Contract__c appContract1   = createAppContract(acc.Id, framework.Id);
        Contract__c appContract2   = createAppContract(acc.Id, framework.Id);
        Opportunity origin         = createRenewalOpp(acc, framework);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, 1, UserInfo.getUserId()),
            1
        );
        Test.stopTest();

        // Application contracts should be closed as Reallocated
        for (Contract__c c : [
            SELECT Status__c FROM Contract__c
            WHERE Parent_Contract__c = :framework.Id
        ]) {
            System.assertEquals('Reallocated', c.Status__c,
                'Application contracts should be closed as Reallocated.');
        }
    }

    @isTest
    static void test_batch_noAppContracts_contractUnchanged() {
        Account     acc      = createAccount();
        Contract__c contract = createContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, 2, UserInfo.getUserId()),
            1
        );
        Test.stopTest();

        // Contract status should remain unchanged (Active)
        Contract__c unchanged = [SELECT Status__c FROM Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Active', unchanged.Status__c,
            'Contract without app contracts should not be modified.');
    }

    @isTest
    static void test_batch_newOppsLinkedToSameFrameworkContract() {
        Account     acc      = createAccount();
        Contract__c contract = createContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, 2, UserInfo.getUserId()),
            1
        );
        Test.stopTest();

        List<Opportunity> newOpps = [
            SELECT Contract_Custom__c
            FROM   Opportunity
            WHERE  Id != :origin.Id
              AND  AccountId = :acc.Id
        ];
        System.assertEquals(2, newOpps.size(), '2 new opportunities expected.');
        for (Opportunity o : newOpps) {
            System.assertEquals(contract.Id, o.Contract_Custom__c,
                'New opp must be linked to the same framework contract.');
        }
    }

    @isTest
    static void test_batch_executeException_noNewOppsCreated() {
        Account     acc      = createAccount();
        Contract__c contract = createContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        // numberOfNewOpps = null causes NullPointerException at "i < null" in the
        // for-loop, covering the execute() catch block and the error branch in finish()
        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, null, UserInfo.getUserId()),
            1
        );
        Test.stopTest();

        // The insert was never reached, so only the origin opportunity exists
        List<Opportunity> allOpps = [
            SELECT Id FROM Opportunity WHERE AccountId = :acc.Id
        ];
        System.assertEquals(1, allOpps.size(),
            'No new opportunities should be created when execute() throws an exception.');
    }
}
