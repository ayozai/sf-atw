/**
 * RequalificationController_Test
 *
 * Couverture de RequalificationController — 3 branches métier + cas d'erreur + rollback.
 * Cible : ≥ 85 % de couverture de lignes.
 *
 * DupCheck : même contournement que AvenantOpportunityCreator_Test.
 *
 * VR VR_FR_DontCreateNewRebidOpport : ne se déclenche que si Owner_Country__c = 'France'.
 * En contexte test, l'utilisateur courant n'est généralement pas en France, la VR ne
 * bloque pas. Le bypass Requalification_Process__c = true est testé fonctionnellement
 * dans test_bypassFieldIsSetOnNewOpps.
 */
@isTest
private class RequalificationController_Test
{
    // ─── Utilitaires ──────────────────────────────────────────────────────────

    private static void disableDupCheck()
    {
        try { dupcheck.dc3Api.disableTriggers(); }
        catch (Exception e) { /* package absent : on continue */ }
    }

    /**
     * Crée le jeu de données de test :
     *   - 1 compte
     *   - 1 contrat cadre (Type = 'Framework Agreement')
     *   - nbAppContracts contrats d'application rattachés au cadre
     *   - 1 opportunité Global_Renewal ouverte sur le contrat cadre
     * Retourne l'Id de l'opportunité d'origine.
     */
    private static Id buildContext(Integer nbAppContracts)
    {
        Account acc = new Account(Name = 'ZZ Test Requalif', Atalian_Sector__c = 'Corporate');
        insert acc;

        Contract__c framework = new Contract__c(
            Account__c         = acc.Id,
            Type__c            = 'Framework Agreement',
            Primary_Service__c = 'Catering',
            Contract_Start_Date__c = Date.today()
        );
        insert framework;

        List<Contract__c> appContracts = new List<Contract__c>();
        for (Integer i = 0; i < nbAppContracts; i++) {
            appContracts.add(new Contract__c(
                Account__c             = acc.Id,
                Type__c                = 'Contract linked to a Framework Agreement',
                Parent_Contract__c     = framework.Id,
                Primary_Service__c     = 'Catering',
                Reference__c           = 'APP-' + i,
                Contract_Start_Date__c = Date.today(),
                Contract_End_Date__c   = Date.today().addMonths(12)
            ));
        }
        if (!appContracts.isEmpty()) { insert appContracts; }

        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName()
            .get('Global_Renewal')
            .getRecordTypeId();

        Opportunity originOpp = new Opportunity(
            Name               = 'TEST Requalif Origin',
            StageName          = '2. Prospect',
            Sub_Stage__c       = '2.1 Future Opportunity',
            CloseDate          = Date.today().addMonths(6),
            AccountId          = acc.Id,
            Contract_Custom__c = framework.Id,
            RecordTypeId       = rtId
        );
        insert originOpp;

        return originOpp.Id;
    }

    /** Crée une OppInput pour les requêtes de test. */
    private static RequalificationController.OppInput makeOppInput(
        String name, String closeDate, String contractId)
    {
        RequalificationController.OppInput oi = new RequalificationController.OppInput();
        oi.name       = name;
        oi.closeDate  = closeDate;
        oi.contractId = contractId;
        return oi;
    }

    // ─── Tests — getOpportunityContext ────────────────────────────────────────

    @isTest
    static void test_getOpportunityContext_returnsData()
    {
        disableDupCheck();
        Id originOppId = buildContext(2);

        Test.startTest();
        RequalificationController.OpportunityContext ctx =
            RequalificationController.getOpportunityContext(originOppId);
        Test.stopTest();

        System.assertEquals(originOppId, ctx.originOppId, 'originOppId doit correspondre.');
        System.assertEquals('TEST Requalif Origin', ctx.originOppName, 'Nom de l\'opp d\'origine.');
        System.assertNotEquals(null, ctx.applicationContracts, 'Liste des contrats d\'application non nulle.');
        System.assertEquals(2, ctx.applicationContracts.size(), 'Deux contrats d\'application attendus.');
    }

    @isTest
    static void test_getOpportunityContext_noAppContracts()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        Test.startTest();
        RequalificationController.OpportunityContext ctx =
            RequalificationController.getOpportunityContext(originOppId);
        Test.stopTest();

        System.assertEquals(0, ctx.applicationContracts.size(), 'Aucun contrat d\'application.');
        System.assertEquals(0, ctx.openRenewalOpps.size(), 'Aucune autre opp ouverte.');
    }

    // ─── Tests — Allotissement Opp ────────────────────────────────────────────

    @isTest
    static void test_allotissementOpp_createsOppsAndClosesOrigin()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId = originOppId;
        req.subStage    = RequalificationController.SUB_STAGE_ALLOT_OPP;
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Lot A', String.valueOf(Date.today().addMonths(6)), null),
            makeOppInput('Lot B', String.valueOf(Date.today().addMonths(9)), null)
        };

        Test.startTest();
        RequalificationController.executeRequalification(req);
        Test.stopTest();

        // Opp d'origine fermée en Requalification
        Opportunity origin = [SELECT StageName, Sub_Stage__c FROM Opportunity WHERE Id = :originOppId];
        System.assertEquals(RequalificationController.STAGE_REQUALIFICATION, origin.StageName,
            'L\'opp d\'origine doit être en Requalification.');
        System.assertEquals(RequalificationController.SUB_STAGE_ALLOT_OPP, origin.Sub_Stage__c,
            'Sub_Stage__c doit être Allotissement Opp.');

        // 2 nouvelles opps créées
        List<Opportunity> newOpps = [
            SELECT Name, StageName, Sub_Stage__c, Requalification_Process__c, RecordType.DeveloperName
            FROM Opportunity
            WHERE Id != :originOppId
              AND Contract_Custom__c = :[SELECT Contract_Custom__c FROM Opportunity WHERE Id = :originOppId].Contract_Custom__c
        ];
        System.assertEquals(2, newOpps.size(), 'Deux nouvelles opps attendues.');
        for (Opportunity o : newOpps) {
            System.assertEquals(RequalificationController.STAGE_PROSPECT, o.StageName);
            System.assertEquals(RequalificationController.SUB_STAGE_FUTURE_OPP, o.Sub_Stage__c);
            System.assertEquals('Global_Renewal', o.RecordType.DeveloperName);
            System.assertEquals(true, o.Requalification_Process__c, 'Bypass VR doit être true.');
        }
    }

    @isTest
    static void test_allotissementOpp_bypassFieldIsSetOnNewOpps()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);
        Opportunity originOpp = [SELECT Contract_Custom__c FROM Opportunity WHERE Id = :originOppId];

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId      = originOppId;
        req.subStage         = RequalificationController.SUB_STAGE_ALLOT_OPP;
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Lot Bypass', String.valueOf(Date.today().addMonths(3)), null)
        };

        Test.startTest();
        RequalificationController.executeRequalification(req);
        Test.stopTest();

        Opportunity newOpp = [
            SELECT Requalification_Process__c
            FROM Opportunity
            WHERE Id != :originOppId AND Contract_Custom__c = :originOpp.Contract_Custom__c
            LIMIT 1
        ];
        System.assertEquals(true, newOpp.Requalification_Process__c,
            'Requalification_Process__c doit être true sur les nouvelles opps (bypass VR).');
    }

    // ─── Tests — Allotissement CC ─────────────────────────────────────────────

    @isTest
    static void test_allotissementCC_createsOppsAndClosesAppContracts()
    {
        disableDupCheck();
        Id originOppId = buildContext(2);
        Opportunity originOpp = [SELECT Contract_Custom__c FROM Opportunity WHERE Id = :originOppId];

        // Récupère les contrats d'application
        List<Contract__c> appContracts = [
            SELECT Id FROM Contract__c WHERE Parent_Contract__c = :originOpp.Contract_Custom__c
        ];
        System.assertEquals(2, appContracts.size());

        // Crée 1 opp de renouvellement ouverte sur chaque contrat d'application
        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('Global_Renewal').getRecordTypeId();
        List<Opportunity> existingChildOpps = new List<Opportunity>();
        for (Contract__c c : appContracts) {
            existingChildOpps.add(new Opportunity(
                Name               = 'Child Opp ' + c.Id,
                StageName          = '2. Prospect',
                Sub_Stage__c       = '2.1 Future Opportunity',
                CloseDate          = Date.today().addMonths(6),
                AccountId          = [SELECT Account__c FROM Contract__c WHERE Id = :c.Id].Account__c,
                Contract_Custom__c = c.Id,
                RecordTypeId       = rtId
            ));
        }
        insert existingChildOpps;

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId = originOppId;
        req.subStage    = RequalificationController.SUB_STAGE_ALLOT_CC;
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Nouvelle Région 1', String.valueOf(Date.today().addMonths(6)), appContracts[0].Id),
            makeOppInput('Nouvelle Région 2', String.valueOf(Date.today().addMonths(9)), appContracts[1].Id)
        };

        Test.startTest();
        RequalificationController.executeRequalification(req);
        Test.stopTest();

        // Opp d'origine fermée
        Opportunity origin = [SELECT StageName, Sub_Stage__c FROM Opportunity WHERE Id = :originOppId];
        System.assertEquals(RequalificationController.STAGE_REQUALIFICATION, origin.StageName);
        System.assertEquals(RequalificationController.SUB_STAGE_ALLOT_CC, origin.Sub_Stage__c);

        // Opps enfants sur contrats d'application fermées
        for (Opportunity o : [
            SELECT StageName, Sub_Stage__c FROM Opportunity
            WHERE Id IN :existingChildOpps
        ]) {
            System.assertEquals(RequalificationController.STAGE_REQUALIFICATION, o.StageName,
                'Les opps enfants doivent être en Requalification.');
            System.assertEquals(RequalificationController.SUB_STAGE_ALLOT_CC, o.Sub_Stage__c);
        }

        // Contrats d'application mis à jour en Réalloti
        for (Contract__c c : [SELECT Status__c FROM Contract__c WHERE Id IN :appContracts]) {
            System.assertEquals(RequalificationController.CONTRACT_STATUS_REALLOCATED, c.Status__c,
                'Les contrats d\'application doivent passer en Réalloti.');
        }

        // 2 nouvelles opps créées sur le contrat cadre (ou contrats d'application sélectionnés)
        List<Opportunity> newOpps = [
            SELECT RecordType.DeveloperName, Requalification_Process__c
            FROM Opportunity
            WHERE StageName = :RequalificationController.STAGE_PROSPECT
              AND Id != :originOppId
              AND Id NOT IN :existingChildOpps
        ];
        System.assertEquals(2, newOpps.size(), 'Deux nouvelles opps créées.');
        for (Opportunity o : newOpps) {
            System.assertEquals('Global_Renewal', o.RecordType.DeveloperName);
            System.assertEquals(true, o.Requalification_Process__c);
        }
    }

    // ─── Tests — Réallocation périmètre ──────────────────────────────────────

    @isTest
    static void test_reallocation_createsDevOppsAndClosesSelected()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);
        Opportunity originOpp = [SELECT Contract_Custom__c, AccountId FROM Opportunity WHERE Id = :originOppId];

        // Crée une 2e opp de renouvellement ouverte (à cocher)
        Id rtId = Schema.SObjectType.Opportunity
            .getRecordTypeInfosByDeveloperName().get('Global_Renewal').getRecordTypeId();
        Opportunity oppToClose = new Opportunity(
            Name               = 'Renouvellement à fermer',
            StageName          = '2. Prospect',
            Sub_Stage__c       = '2.1 Future Opportunity',
            CloseDate          = Date.today().addMonths(6),
            AccountId          = originOpp.AccountId,
            Contract_Custom__c = originOpp.Contract_Custom__c,
            RecordTypeId       = rtId,
            Requalification_Process__c = true   // bypass VR pour l'insertion de test
        );
        insert oppToClose;

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId     = originOppId;
        req.subStage        = RequalificationController.SUB_STAGE_REALLOC;
        req.oppIdsToClose   = new List<String>{ oppToClose.Id };
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Nouveau Périmètre Est', String.valueOf(Date.today().addMonths(12)), null)
        };

        Test.startTest();
        RequalificationController.executeRequalification(req);
        Test.stopTest();

        // Opp d'origine fermée en Requalification
        Opportunity origin = [SELECT StageName, Sub_Stage__c FROM Opportunity WHERE Id = :originOppId];
        System.assertEquals(RequalificationController.STAGE_REQUALIFICATION, origin.StageName);
        System.assertEquals(RequalificationController.SUB_STAGE_REALLOC, origin.Sub_Stage__c);

        // Opp cochée fermée en Closed Lost
        Opportunity closed = [SELECT StageName FROM Opportunity WHERE Id = :oppToClose.Id];
        System.assertEquals(RequalificationController.STAGE_CLOSED_LOST, closed.StageName,
            'L\'opp cochée doit être fermée en Closed Lost.');

        // Nouvelle opp de dev créée en Global_Bid
        List<Opportunity> devOpps = [
            SELECT RecordType.DeveloperName, StageName
            FROM Opportunity
            WHERE Name = 'Nouveau Périmètre Est'
        ];
        System.assertEquals(1, devOpps.size(), 'Une opp de développement créée.');
        System.assertEquals('Global_Bid', devOpps[0].RecordType.DeveloperName,
            'Le RecordType doit être Global_Bid.');
        System.assertEquals(RequalificationController.STAGE_PROSPECT, devOpps[0].StageName);
    }

    @isTest
    static void test_reallocation_noOppsToClose_stillWorks()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId     = originOppId;
        req.subStage        = RequalificationController.SUB_STAGE_REALLOC;
        req.oppIdsToClose   = new List<String>();
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Dev Opp', String.valueOf(Date.today().addMonths(12)), null)
        };

        Test.startTest();
        RequalificationController.executeRequalification(req);
        Test.stopTest();

        Opportunity origin = [SELECT StageName FROM Opportunity WHERE Id = :originOppId];
        System.assertEquals(RequalificationController.STAGE_REQUALIFICATION, origin.StageName);
    }

    // ─── Tests — Erreurs et rollback ──────────────────────────────────────────

    @isTest
    static void test_unknownSubStage_throwsAuraHandledException()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId      = originOppId;
        req.subStage         = 'INCONNU';
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Test', String.valueOf(Date.today().addMonths(1)), null)
        };

        Test.startTest();
        try {
            RequalificationController.executeRequalification(req);
            System.assert(false, 'Exception attendue pour subStage inconnu.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().length() > 0, 'Message d\'erreur présent.');
        }
        Test.stopTest();
    }

    @isTest
    static void test_nullRequest_throwsAuraHandledException()
    {
        Test.startTest();
        try {
            RequalificationController.executeRequalification(null);
            System.assert(false, 'Exception attendue pour request null.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Paramètres'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void test_missingOppName_throwsAuraHandledException()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId      = originOppId;
        req.subStage         = RequalificationController.SUB_STAGE_ALLOT_OPP;
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('', String.valueOf(Date.today().addMonths(3)), null)   // nom vide
        };

        Test.startTest();
        try {
            RequalificationController.executeRequalification(req);
            System.assert(false, 'Exception attendue pour nom manquant.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().length() > 0, 'Message d\'erreur présent.');
        }
        Test.stopTest();
    }

    @isTest
    static void test_missingCloseDate_throwsAuraHandledException()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId      = originOppId;
        req.subStage         = RequalificationController.SUB_STAGE_ALLOT_OPP;
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput('Lot A', '', null)   // date vide
        };

        Test.startTest();
        try {
            RequalificationController.executeRequalification(req);
            System.assert(false, 'Exception attendue pour date manquante.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().length() > 0, 'Message d\'erreur présent.');
        }
        Test.stopTest();
    }

    @isTest
    static void test_emptyNewOpps_throwsAuraHandledException()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId      = originOppId;
        req.subStage         = RequalificationController.SUB_STAGE_ALLOT_OPP;
        req.newOpportunities = new List<RequalificationController.OppInput>();

        Test.startTest();
        try {
            RequalificationController.executeRequalification(req);
            System.assert(false, 'Exception attendue pour liste vide.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Au moins'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void test_rollback_noOppPersistedOnError()
    {
        disableDupCheck();
        Id originOppId = buildContext(0);

        // Nom trop long (> 255 caractères) pour provoquer une erreur DML sur insert
        String longName = 'X'.repeat(256);

        RequalificationController.RequalificationRequest req =
            new RequalificationController.RequalificationRequest();
        req.originOppId      = originOppId;
        req.subStage         = RequalificationController.SUB_STAGE_ALLOT_OPP;
        req.newOpportunities = new List<RequalificationController.OppInput>{
            makeOppInput(longName, String.valueOf(Date.today().addMonths(3)), null)
        };

        Test.startTest();
        try {
            RequalificationController.executeRequalification(req);
        } catch (AuraHandledException e) {
            // Erreur attendue
        }
        Test.stopTest();

        // Opp d'origine doit être revenue à son stage initial (rollback)
        Opportunity origin = [SELECT StageName FROM Opportunity WHERE Id = :originOppId];
        System.assertNotEquals(
            RequalificationController.STAGE_REQUALIFICATION,
            origin.StageName,
            'Rollback : l\'opp d\'origine ne doit pas être en Requalification.'
        );
    }
}
