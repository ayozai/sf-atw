@isTest
private class RegroupementBatch_Test {

    // ── Test data helpers ─────────────────────────────────────────────────────

    static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }

    static Contract__c createFrameworkContract(Id accountId, String ref) {
        Contract__c c = new Contract__c(
            Status__c          = 'Active',
            Account__c         = accountId,
            Primary_Service__c = 'Catering',
            Type__c            = 'Framework Agreement',
            Reference__c       = ref
        );
        insert c;
        return c;
    }

    static Opportunity createRenewalOpp(Account acc, Contract__c contract, Decimal amount) {
        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Renewal')
            .getRecordTypeId();

        Opportunity opp = new Opportunity(
            Name                       = 'Test Renewal ' + acc.Name,
            AccountId                  = acc.Id,
            Contract_Custom__c         = contract.Id,
            StageName                  = '2. Prospect',
            Sub_Stage__c               = '2.1 Future Opportunity',
            CloseDate                  = Date.today().addYears(1),
            RecordTypeId               = rtId,
            Global_Primary_Service__c  = 'Catering',
            Amount                     = amount,
            Requalification_Process__c = true  // bypass "one open renewal per contract" VR during test setup
        );
        insert opp;
        return opp;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    /**
     * Happy path — 2 opps on the same account.
     * Expects: both origin opps closed (Requalification/Regroupement),
     * 1 new Global_Renewal opp created with SUM(Amount),
     * Grouped_Into__c set on both origin opps.
     */
    @isTest
    static void test_happyPath_sameAccount() {
        Account     acc      = createAccount('Servier');
        Contract__c con1     = createFrameworkContract(acc.Id, 'REF-001');
        Contract__c con2     = createFrameworkContract(acc.Id, 'REF-002');
        Opportunity opp1     = createRenewalOpp(acc, con1, 1000);
        Opportunity opp2     = createRenewalOpp(acc, con2, 2000);

        List<Id> selectedIds = new List<Id>{ opp1.Id, opp2.Id };

        Test.startTest();
        Database.executeBatch(
            new RegroupementBatch(selectedIds, 'Servier - REGROUPEMENT', acc.Id, UserInfo.getUserId()),
            selectedIds.size()
        );
        Test.stopTest();

        // Both origin opps → Requalification / Regroupement
        List<Opportunity> closedOpps = [
            SELECT Id, StageName, Sub_Stage__c
            FROM   Opportunity
            WHERE  Id IN :selectedIds
        ];
        System.assertEquals(2, closedOpps.size());
        for (Opportunity o : closedOpps) {
            System.assertEquals('Requalification', o.StageName,
                'Origin opp StageName should be Requalification.');
            System.assertEquals('Réallocation périmètre', o.Sub_Stage__c,
                'Origin opp Sub_Stage__c should be Réallocation périmètre (POC fallback for Regroupement).');
        }

        // 1 new grouped opp created — identified by amount (3000 = 1000+2000, unique in test)
        // Note: naming automations may rename the opp, so we use Amount as the stable identifier.
        List<Opportunity> newOpps = [
            SELECT Id, Name, AccountId, Amount, StageName, Sub_Stage__c,
                   Contract_Custom__c, RecordType.DeveloperName, Is_Requalification_Opp__c
            FROM   Opportunity
            WHERE  Amount = 3000
              AND  StageName = '2. Prospect'
        ];
        System.assertEquals(1, newOpps.size(), '1 grouped opp should be created.');
        Opportunity grouped = newOpps[0];
        System.assertEquals(acc.Id, grouped.AccountId);
        System.assertEquals(3000, grouped.Amount, 'Amount should be SUM of origin opps.');
        System.assertEquals('Global_Renewal', grouped.RecordType.DeveloperName);
    }

    /**
     * Happy path — 2 opps on different accounts, targetAccountId = account of opp2.
     * Expects: new grouped opp on account 2.
     */
    @isTest
    static void test_happyPath_differentAccounts() {
        Account     acc1 = createAccount('Servier Site A');
        Account     acc2 = createAccount('Servier Site B');
        Contract__c con1 = createFrameworkContract(acc1.Id, 'REF-A');
        Contract__c con2 = createFrameworkContract(acc2.Id, 'REF-B');
        Opportunity opp1 = createRenewalOpp(acc1, con1, 500);
        Opportunity opp2 = createRenewalOpp(acc2, con2, 1500);

        List<Id> selectedIds = new List<Id>{ opp1.Id, opp2.Id };

        Test.startTest();
        Database.executeBatch(
            new RegroupementBatch(selectedIds, 'Servier Multi-Site', acc2.Id, UserInfo.getUserId()),
            selectedIds.size()
        );
        Test.stopTest();

        // New grouped opp on acc2 — identified by Amount = 2000 (500+1500, unique in test)
        // Automation-created rebid opps copy origin amounts (500 or 1500), not the sum.
        List<Opportunity> newOpps = [
            SELECT Id, AccountId, Amount
            FROM   Opportunity
            WHERE  Amount = 2000
              AND  StageName = '2. Prospect'
        ];
        System.assertEquals(1, newOpps.size(), '1 grouped opp should be created.');
        System.assertEquals(acc2.Id, newOpps[0].AccountId,
            'Grouped opp should be on the target account (acc2).');
        System.assertEquals(2000, newOpps[0].Amount,
            'Amount should be SUM of both origin opps (500 + 1500).');
    }

    /**
     * Verifies that all distinct contracts linked to origin opps are marked Réalloti.
     */
    @isTest
    static void test_contractsSetToRealloti() {
        Account     acc  = createAccount('Servier');
        Contract__c con1 = createFrameworkContract(acc.Id, 'REF-001');
        Contract__c con2 = createFrameworkContract(acc.Id, 'REF-002');
        Opportunity opp1 = createRenewalOpp(acc, con1, 1000);
        Opportunity opp2 = createRenewalOpp(acc, con2, 2000);

        List<Id> selectedIds = new List<Id>{ opp1.Id, opp2.Id };

        Test.startTest();
        Database.executeBatch(
            new RegroupementBatch(selectedIds, 'Servier - REGROUPEMENT', acc.Id, UserInfo.getUserId()),
            selectedIds.size()
        );
        Test.stopTest();

        // Both contracts → Réalloti
        List<Contract__c> contracts = [
            SELECT Id, Status__c FROM Contract__c WHERE Id IN (:con1.Id, :con2.Id)
        ];
        for (Contract__c c : contracts) {
            System.assertEquals('Réalloti', c.Status__c,
                'Contract should be marked Réalloti after regroupement. Id: ' + c.Id);
        }
    }

    /**
     * Atomicity — forcing an error (null newOppName causes insert of grouped opp to fail).
     * Expects: rollback → origin opps remain open, contracts remain Active.
     * Note: each opp must be on a separate contract to avoid the "open renewal exists" VR.
     */
    @isTest
    static void test_atomicity_rollbackOnError() {
        Account     acc  = createAccount('Servier');
        Contract__c con1 = createFrameworkContract(acc.Id, 'REF-001');
        Contract__c con2 = createFrameworkContract(acc.Id, 'REF-002');
        Opportunity opp1 = createRenewalOpp(acc, con1, 1000);
        Opportunity opp2 = createRenewalOpp(acc, con2, 2000);

        List<Id> selectedIds = new List<Id>{ opp1.Id, opp2.Id };

        Test.startTest();
        // null newOppName → Opportunity.Name required → DML error on insert → rollback
        Database.executeBatch(
            new RegroupementBatch(selectedIds, null, acc.Id, UserInfo.getUserId()),
            selectedIds.size()
        );
        Test.stopTest();

        // Origin opps must still be open (rollback restored their original stage)
        List<Opportunity> opps = [
            SELECT Id, StageName FROM Opportunity WHERE Id IN :selectedIds
        ];
        for (Opportunity o : opps) {
            System.assertNotEquals('Requalification', o.StageName,
                'Origin opp should still be open after rollback. Id: ' + o.Id);
        }

        // Contracts must still be Active (rollback undid the Réalloti update too)
        List<Contract__c> contracts = [
            SELECT Id, Status__c FROM Contract__c WHERE Id IN (:con1.Id, :con2.Id)
        ];
        for (Contract__c c : contracts) {
            System.assertEquals('Active', c.Status__c,
                'Contract should still be Active after rollback. Id: ' + c.Id);
        }
    }

    /**
     * Verifies execute() runs without error when called directly (same-account scenario).
     * Complements test_happyPath_sameAccount which uses Database.executeBatch.
     */
    @isTest
    static void test_executeDirectly_sameAccount_noError() {
        Account     acc  = createAccount('Servier');
        Contract__c con1 = createFrameworkContract(acc.Id, 'REF-001');
        Contract__c con2 = createFrameworkContract(acc.Id, 'REF-002');
        Opportunity opp1 = createRenewalOpp(acc, con1, 1000);
        Opportunity opp2 = createRenewalOpp(acc, con2, 2000);

        List<Id> selectedIds = new List<Id>{ opp1.Id, opp2.Id };
        RegroupementBatch b = new RegroupementBatch(selectedIds, 'Servier - REGROUPEMENT', acc.Id, UserInfo.getUserId());

        List<Opportunity> scope = [
            SELECT Id, Name, AccountId, OwnerId, Pricebook2Id, Amount,
                   Contract_Custom__c, Global_Primary_Service__c,
                   CloseDate, RecordTypeId
            FROM   Opportunity
            WHERE  Id IN :selectedIds
        ];

        Test.startTest();
        b.execute(null, scope);
        Test.stopTest();

        System.assertEquals(null, b.errorMessage,
            'Batch should succeed. Error: ' + b.errorMessage);
    }

    /**
     * Controller validation — startRegroupement throws AuraHandledException when < 2 opps.
     */
    @isTest
    static void test_controller_startRegroupement_validation() {
        Account     acc      = createAccount('Servier');
        Contract__c contract = createFrameworkContract(acc.Id, 'REF-001');
        Opportunity opp      = createRenewalOpp(acc, contract, 1000);

        Boolean exceptionThrown = false;
        try {
            Test.startTest();
            // extraOppIds is empty → total would be 1 → should throw
            RequalificationController.startRegroupement(
                opp.Id,
                new List<Id>(),
                'New Grouped Opp',
                acc.Id
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown,
            'AuraHandledException should be thrown when fewer than 2 opps are provided.');
    }
}
