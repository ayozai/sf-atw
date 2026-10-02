@isTest
private class RequalificationBatch_Test {

    // ── Test data helpers ─────────────────────────────────────────────────────

    static Account createAccount() {
        Account acc = new Account(Name = 'Test Account Requalif');
        insert acc;
        return acc;
    }

    static Contract__c createFrameworkContract(Id accountId) {
        Contract__c c = new Contract__c(
            Status__c          = 'Active',
            Account__c         = accountId,
            Primary_Service__c = 'Catering',
            Type__c            = 'Framework Agreement',
            Reference__c       = 'REF-TEST-001'
        );
        insert c;
        return c;
    }

    static Contract__c createAppContract(Id accountId, Id parentContractId) {
        Contract__c c = new Contract__c(
            Status__c          = 'Active',
            Account__c         = accountId,
            Primary_Service__c = 'Catering',
            Parent_Contract__c = parentContractId
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

    /**
     * Scenario 1 — No application contracts.
     * Expects: origin opp closed (Requalification), old framework contract → Réalloti,
     * no new contract created, N new opps linked to the SAME (now Réalloti) contract,
     * Is_Requalification_Opp__c = true on all new opps.
     */
    @isTest
    static void test_scenario1_closesOldContractAndLinksToRealloti() {
        Account     acc      = createAccount();
        Contract__c contract = createFrameworkContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, 3, UserInfo.getUserId(), null),
            1
        );
        Test.stopTest();

        // Origin opp → Requalification / 6.1 Closed Lost
        Opportunity updatedOrigin = [SELECT StageName, Sub_Stage__c FROM Opportunity WHERE Id = :origin.Id];
        System.assertEquals('Requalification', updatedOrigin.StageName,
            'Origin StageName should be Requalification.');
        System.assertEquals('6.1 Closed Lost', updatedOrigin.Sub_Stage__c,
            'Origin Sub_Stage__c should be 6.1 Closed Lost.');

        // Old framework contract → Réalloti (no new contract created)
        Contract__c oldContract = [SELECT Status__c FROM Contract__c WHERE Id = :contract.Id];
        System.assertEquals('Réalloti', oldContract.Status__c,
            'Old framework contract should be marked Réalloti.');

        List<Contract__c> allContracts = [SELECT Id FROM Contract__c WHERE Account__c = :acc.Id];
        System.assertEquals(1, allContracts.size(), 'No new contract should be created in Scenario 1.');

        // 3 new opps linked to the RÉALLOTI contract with Is_Requalification_Opp__c = true
        List<Opportunity> newOpps = [
            SELECT Id, StageName, Sub_Stage__c, Contract_Custom__c,
                   RecordType.DeveloperName, Is_Requalification_Opp__c
            FROM   Opportunity
            WHERE  AccountId = :acc.Id
              AND  StageName = '2. Prospect'
        ];
        System.assertEquals(3, newOpps.size(), '3 new renewal opportunities should be created.');
        for (Opportunity o : newOpps) {
            System.assertEquals('2. Prospect', o.StageName,
                'New opp StageName should be 2. Prospect.');
            System.assertEquals('2.1 Future Opportunity', o.Sub_Stage__c,
                'New opp Sub_Stage__c should be 2.1 Future Opportunity.');
            System.assertEquals('Global_Renewal', o.RecordType.DeveloperName,
                'New opp RecordType should be Global_Renewal.');
            System.assertEquals(contract.Id, o.Contract_Custom__c,
                'New opp should be linked to the original (now Réalloti) framework contract.');
            System.assertEquals(true, o.Is_Requalification_Opp__c,
                'New opp Is_Requalification_Opp__c should be true.');
        }
    }

    /**
     * Scenario 2 — Framework contract has application contracts.
     * Expects: framework contract unchanged, app contracts → Réalloti,
     * existing renewal opps linked to app contracts → Requalification stage,
     * N new opps linked to the existing framework contract.
     */
    @isTest
    static void test_scenario2_closesAppContractsAndOldRenewalOpps() {
        Account     acc         = createAccount();
        Contract__c framework   = createFrameworkContract(acc.Id);
        Contract__c appContract = createAppContract(acc.Id, framework.Id);
        // Old renewal opp linked to the app contract (should be closed by batch)
        Opportunity oldAppOpp   = createRenewalOpp(acc, appContract);
        // Origin renewal opp linked to the framework contract
        Opportunity origin      = createRenewalOpp(acc, framework);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, 2, UserInfo.getUserId(), null),
            1
        );
        Test.stopTest();

        // Framework contract → unchanged (still Active in Scenario 2)
        Contract__c fw = [SELECT Status__c FROM Contract__c WHERE Id = :framework.Id];
        System.assertEquals('Active', fw.Status__c,
            'Framework contract should remain Active in Scenario 2.');

        // App contract → Réalloti
        Contract__c app = [SELECT Status__c FROM Contract__c WHERE Id = :appContract.Id];
        System.assertEquals('Réalloti', app.Status__c,
            'Application contract should be marked Réalloti.');

        // Old renewal opp linked to app contract → closed as Requalification
        Opportunity closed = [SELECT StageName FROM Opportunity WHERE Id = :oldAppOpp.Id];
        System.assertEquals('Requalification', closed.StageName,
            'Old app renewal opp should be moved to Requalification stage.');

        // 2 new opps linked to the existing framework contract
        List<Opportunity> newOpps = [
            SELECT Id, Contract_Custom__c
            FROM   Opportunity
            WHERE  AccountId = :acc.Id
              AND  StageName = '2. Prospect'
        ];
        System.assertEquals(2, newOpps.size(), '2 new renewal opportunities should be created.');
        for (Opportunity o : newOpps) {
            System.assertEquals(framework.Id, o.Contract_Custom__c,
                'New opps should link to the existing framework contract in Scenario 2.');
        }
    }

    /**
     * Verifies the naming formula: <Account> - <Service> - <Reference> - REQUALIFICATION N
     * aligned with the AvenantOpportunityCreator convention.
     */
    @isTest
    static void test_buildOppName_followsNamingConvention() {
        Account     acc      = createAccount();
        Contract__c contract = createFrameworkContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        // Re-query with relationship fields as the batch does in start()
        Opportunity originWithRels = [
            SELECT Id, Name, AccountId,
                   Contract_Custom__r.Reference__c,
                   Contract_Custom__r.Primary_Service__c,
                   Contract_Custom__r.Account__r.Name
            FROM   Opportunity
            WHERE  Id = :origin.Id
        ];

        String name1 = RequalificationBatch.buildOppName(originWithRels, 1, null);
        String name2 = RequalificationBatch.buildOppName(originWithRels, 2, 'SITE-A');

        System.assert(name1.endsWith('REQUALIFICATION 1'),
            'Name should end with REQUALIFICATION 1. Got: ' + name1);
        System.assert(name2.endsWith('REQUALIFICATION 2'),
            'Name should end with REQUALIFICATION 2. Got: ' + name2);
        System.assert(name1.contains('Catering'),
            'Name should contain the primary service. Got: ' + name1);
        System.assert(name1.contains('REF-TEST-001'),
            'Name should contain the contract reference. Got: ' + name1);
        System.assert(name2.contains('SITE-A'),
            'Name should contain the site reference. Got: ' + name2);
        System.assert(name1.length() <= 120, 'Name should not exceed 120 characters.');
    }

    /**
     * Error path: null numberOfNewOpps → NullPointerException in the for-loop →
     * catch block sets errorMessage → no new opps created → error notification sent.
     */
    @isTest
    static void test_batch_executeException_noNewOppsCreated() {
        Account     acc      = createAccount();
        Contract__c contract = createFrameworkContract(acc.Id);
        Opportunity origin   = createRenewalOpp(acc, contract);

        Test.startTest();
        Database.executeBatch(
            new RequalificationBatch(origin.Id, null, UserInfo.getUserId(), null),
            1
        );
        Test.stopTest();

        // No new opportunities should have been inserted
        List<Opportunity> newOpps = [
            SELECT Id FROM Opportunity
            WHERE  AccountId = :acc.Id
              AND  StageName = '2. Prospect'
        ];
        System.assertEquals(0, newOpps.size(),
            'No new opportunities should be created when execute() throws an exception.');
    }
}
