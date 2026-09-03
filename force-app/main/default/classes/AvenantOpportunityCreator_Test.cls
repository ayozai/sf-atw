/**
 * AvenantOpportunityCreator_Test
 *
 * Couvre AvenantOpportunityCreator (synchrone + invocable) et AvenantOpportunityBatch.
 *
 * DupCheck : le package managé bloque l'insertion d'Account en contexte test
 * ("Access Blocked Requires Extra Verification"). On désactive ses triggers via
 * dupcheck.dc3Api.disableTriggers() au début de chaque test (best-effort si le
 * package est absent).
 *
 * Clôture Closed Won : selon la disponibilité email de l'org de test, la bascule
 * peut réussir ou non. Les assertions ne dépendent donc PAS du succès de la clôture :
 * on vérifie l'insertion des avenants, l'exclusion des expirés et le calcul de la
 * date de fin étendue (valeurs positionnées à l'insertion, avant la clôture).
 */
@isTest
private class AvenantOpportunityCreator_Test
{
    private static void disableDupCheck()
    {
        try { dupcheck.dc3Api.disableTriggers(); }
        catch (Exception e) { /* package non présent : on continue */ }
    }

    /** Crée un compte + un contrat cadre + N contrats liés valides (+ 1 expiré optionnel). */
    private static Id buildFramework(Integer nbValid, Boolean withExpired)
    {
        Account acc = new Account(Name = 'ZZ Test Avenant', Atalian_Sector__c = 'Corporate');
        insert acc;

        Contract__c fw = new Contract__c(
            Account__c = acc.Id, Type__c = 'Framework Agreement',
            Primary_Service__c = 'Catering', Contract_Start_Date__c = Date.today());
        insert fw;

        List<Contract__c> children = new List<Contract__c>();
        for (Integer i = 0; i < nbValid; i++)
        {
            children.add(new Contract__c(
                Account__c = acc.Id,
                Type__c = 'Contract linked to a Framework Agreement',
                Parent_Contract__c = fw.Id,
                Primary_Service__c = 'Catering',
                Reference__c = 'V-' + i,
                Contract_Start_Date__c = Date.today(),
                Contract_End_Date__c = Date.today().addMonths(6)));
        }
        if (withExpired)
        {
            children.add(new Contract__c(
                Account__c = acc.Id,
                Type__c = 'Contract linked to a Framework Agreement',
                Parent_Contract__c = fw.Id,
                Primary_Service__c = 'Catering',
                Reference__c = 'EXP',
                Contract_Start_Date__c = Date.newInstance(2015, 1, 1),
                Contract_End_Date__c = Date.newInstance(2020, 1, 1)));
        }
        insert children;
        return fw.Id;
    }

    @isTest
    static void syncCreatesAvenantsExtendsDateAndSkipsExpired()
    {
        disableDupCheck();
        Id fwId = buildFramework(2, true);   // 2 valides + 1 expiré

        Test.startTest();
        AvenantOpportunityCreator.Outcome o =
            AvenantOpportunityCreator.createForFrameworkContract(fwId, 3);
        Test.stopTest();

        // 1 contrat expiré ignoré et rapporté
        System.assertEquals(1, o.skipped.size(), 'Le contrat expiré doit être ignoré : ' + o.skipped);

        // 2 avenants insérés (indépendamment du succès de la clôture). Scopé sur le
        // RecordType Global_Upsell : le flow actif "Opportunity RTF - Global Upsell
        // Closed Won" crée lui-même, à la clôture, une Opportunity Global_Renewal
        // ("Rebid") de suivi quand aucun renouvellement n'existe déjà sur le contrat
        // -> comportement normal du flow, à exclure du comptage des avenants.
        List<Opportunity> opps = [
            SELECT Id, Contract_End_Date__c, Global_Business_Type_Opportunity__c,
                   RecordType.DeveloperName
            FROM Opportunity
            WHERE Contract_Custom__r.Parent_Contract__c = :fwId
              AND RecordType.DeveloperName = 'Global_Upsell'];
        System.assertEquals(2, opps.size(), 'Deux avenants attendus (les valides).');
        System.assertEquals(2, o.created.size() + o.errors.size(),
            'Chaque avenant inséré doit être soit clôturé, soit en erreur de clôture.');

        // Date de fin d'origine des contrats valides, fixée par buildFramework() —
        // ne PAS la relire via Contract_Custom__r après Test.stopTest() : si la
        // clôture réussit, le flow "Opportunity RTF - Global Upsell Closed Won" a
        // déjà recopié la nouvelle date (+3 mois) sur le contrat lié, ce qui fausserait
        // le calcul de la valeur attendue ci-dessous.
        Date expectedEndDate = Date.today().addMonths(6).addMonths(3);

        for (Opportunity op : opps)
        {
            System.assertEquals('Amendment on Existing Account',
                op.Global_Business_Type_Opportunity__c);
            System.assertEquals('Global_Upsell', op.RecordType.DeveloperName);
            System.assertEquals(expectedEndDate,
                op.Contract_End_Date__c, 'La date de fin de l\'avenant doit être +3 mois.');
        }
    }

    @isTest
    static void syncWithoutExtensionKeepsEndDate()
    {
        disableDupCheck();
        Id fwId = buildFramework(1, false);

        Test.startTest();
        AvenantOpportunityCreator.Outcome o =
            AvenantOpportunityCreator.createForFrameworkContract(fwId);   // pas d'extension
        Test.stopTest();

        List<Opportunity> opps = [
            SELECT Contract_End_Date__c, Contract_Custom__r.Contract_End_Date__c
            FROM Opportunity
            WHERE Contract_Custom__r.Parent_Contract__c = :fwId
              AND RecordType.DeveloperName = 'Global_Upsell'];
        System.assertEquals(1, opps.size());
        System.assertEquals(opps[0].Contract_Custom__r.Contract_End_Date__c,
            opps[0].Contract_End_Date__c, 'Sans extension, la date de fin est inchangée.');
    }

    @isTest
    static void throwsWhenNoChildContract()
    {
        disableDupCheck();
        Id fwId = buildFramework(0, false);
        Test.startTest();
        try
        {
            AvenantOpportunityCreator.createForFrameworkContract(fwId, 3);
            System.assert(false, 'Exception attendue (aucun contrat lié).');
        }
        catch (AvenantOpportunityCreator.AvenantException e)
        {
            System.assert(e.getMessage().contains('Aucun contrat'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void throwsWhenNotAFramework()
    {
        disableDupCheck();
        Account acc = new Account(Name = 'ZZ Acc', Atalian_Sector__c = 'Corporate');
        insert acc;
        Contract__c c = new Contract__c(
            Account__c = acc.Id, Type__c = 'Single-Site Contract',
            Primary_Service__c = 'Catering', Contract_Start_Date__c = Date.today());
        insert c;

        Test.startTest();
        try
        {
            AvenantOpportunityCreator.createForFrameworkContract(c.Id, 3);
            System.assert(false, 'Exception attendue (pas un contrat cadre).');
        }
        catch (AvenantOpportunityCreator.AvenantException e)
        {
            System.assert(e.getMessage().contains('pas un contrat cadre'), e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void throwsWhenIdNull()
    {
        try
        {
            AvenantOpportunityCreator.createForFrameworkContract(null, 3);
            System.assert(false, 'Exception attendue (Id null).');
        }
        catch (AvenantOpportunityCreator.AvenantException e)
        {
            System.assert(e.getMessage().contains('obligatoire'), e.getMessage());
        }
    }

    @isTest
    static void invocableEntryPointWorks()
    {
        disableDupCheck();
        Id fwId = buildFramework(2, false);

        AvenantOpportunityCreator.Request req = new AvenantOpportunityCreator.Request();
        req.frameworkContractId = fwId;
        req.extensionMonths = 6;

        Test.startTest();
        List<AvenantOpportunityCreator.Result> results =
            AvenantOpportunityCreator.createAvenants(
                new List<AvenantOpportunityCreator.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(2,
            [SELECT COUNT() FROM Opportunity
             WHERE Contract_Custom__r.Parent_Contract__c = :fwId
               AND RecordType.DeveloperName = 'Global_Upsell'],
            'Deux avenants insérés.');
    }

    @isTest
    static void batchProcessesAllChildren()
    {
        disableDupCheck();
        Id fwId = buildFramework(3, true);   // 3 valides + 1 expiré

        // En contexte test, un seul execute() est autorisé : la taille de lot doit
        // couvrir tous les enregistrements (une seule invocation executeBatch).
        Test.startTest();
        Id jobId = AvenantOpportunityBatch.run(fwId, 3, 200);
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Le batch doit démarrer.');
        System.assertEquals(3,
            [SELECT COUNT() FROM Opportunity
             WHERE Contract_Custom__r.Parent_Contract__c = :fwId
               AND RecordType.DeveloperName = 'Global_Upsell'],
            'Trois avenants insérés (l\'expiré est ignoré).');
    }

    @isTest
    static void batchRunValidatesInput()
    {
        try
        {
            AvenantOpportunityBatch.run(null, 3, 2);
            System.assert(false, 'Exception attendue (Id null).');
        }
        catch (AvenantOpportunityCreator.AvenantException e)
        {
            System.assert(e.getMessage().contains('obligatoire'), e.getMessage());
        }
    }
}