@isTest
private class InspectionService_Test {

    @testSetup
    static void setup() {
        insert new Account(Name = 'Test Account');
    }

    private static Site__c createTestSite(String name, Boolean operating, String freq, String enabled) {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        return new Site__c(Name=name, Account__c=acc.Id, Country2__c='FR',
            Operating_Site__c=operating, Inspection_Frequency__c=freq, Inspection_Enabled__c=enabled);
    }

    // ─── getNextFixedMonth ───────────────────────────────────────────────────

    @isTest static void testGetNextFixedMonth_Every3Months() {
        System.assertEquals(Date.newInstance(2026,4,1),  InspectionService.getNextFixedMonth(Date.newInstance(2026,1,1),  'Every 3 months'));
        System.assertEquals(Date.newInstance(2026,7,1),  InspectionService.getNextFixedMonth(Date.newInstance(2026,4,1),  'Every 3 months'));
        System.assertEquals(Date.newInstance(2027,1,1),  InspectionService.getNextFixedMonth(Date.newInstance(2026,12,1), 'Every 3 months'));
    }

    @isTest static void testGetNextFixedMonth_Every6Months() {
        System.assertEquals(Date.newInstance(2026,1,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,1,1),  'Every 6 months'), 'Jan -> Jan');
        System.assertEquals(Date.newInstance(2026,1,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,3,15), 'Every 6 months'), 'Mar -> Jan');
        System.assertEquals(Date.newInstance(2026,1,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,6,30), 'Every 6 months'), 'Jun -> Jan');
        System.assertEquals(Date.newInstance(2026,7,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,7,1),  'Every 6 months'), 'Jul -> Jul');
        System.assertEquals(Date.newInstance(2026,7,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,9,1),  'Every 6 months'), 'Sep -> Jul');
        System.assertEquals(Date.newInstance(2026,7,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,12,1), 'Every 6 months'), 'Dec -> Jul');
    }

    @isTest static void testGetNextFixedMonth_EveryYear() {
        System.assertEquals(Date.newInstance(2027,1,1), InspectionService.getNextFixedMonth(Date.newInstance(2026,6,15), 'Every year'));
    }

    // ─── Insert : generation annuelle ────────────────────────────────────────

    @isTest static void testInsert_GeneratesFullYear_Every3Months() {
        Site__c site = createTestSite('Site 3M', true, 'Every 3 months', 'Active');
        Test.startTest(); insert site; Test.stopTest();
        site = [SELECT Id, CreatedDate FROM Site__c WHERE Id = :site.Id];

        List<Inspection_Performance__c> insp = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        System.assert(insp.size() >= 1, 'Au moins une inspection doit etre creee');
        Date expectedAnchor = InspectionService.getNextFixedMonth(site.CreatedDate.date(), 'Every 3 months');
        System.assertEquals(expectedAnchor, insp[0].Date__c, 'Premiere inspection = ancre');
        for (Inspection_Performance__c ip : insp) {
            System.assert(ip.Date__c <= InspectionService.endOfCurrentYear(), 'Date <= 31/12 annee courante');
        }
    }

    /**
     * FIX validation rule : Reason__c obligatoire quand Enabled = Inactive
     */
    @isTest static void testInsert_NoInspectionWhenDisabled() {
        Site__c site = createTestSite('Disabled', true, 'Every month', 'Inactive - Closed site');
        // FIX : renseigner Reason__c pour satisfaire la validation rule
        site.Reason__c = 'Test - site desactive';
        Test.startTest(); insert site; Test.stopTest();
        System.assertEquals(0, [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size());
    }

    // ─── Update : desactivation supprime les futures ──────────────────────────

    /**
     * FIX validation rule : Reason__c obligatoire quand Enabled passe a Inactive
     */
    @isTest static void testDeactivation_Enabled_DeletesFutures() {
        Site__c site = createTestSite('Deact Enabled', true, 'Every 3 months', 'Active');
        insert site;
        Integer totalBefore = [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size();
        System.assert(totalBefore >= 1, 'Des inspections doivent exister apres insert');

        Test.startTest();
        site.Inspection_Enabled__c = 'Inactive - Closed site';
        // FIX : renseigner Reason__c pour satisfaire la validation rule
        site.Reason__c = 'Test - desactivation closed site';
        update site;
        Test.stopTest();

        List<Inspection_Performance__c> remaining = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        for (Inspection_Performance__c ip : remaining) {
            System.assert(ip.Date__c <= Date.today(), 'Seules les inspections passees/presentes doivent rester');
        }
    }

    @isTest static void testDeactivation_Operating_DeletesFutures() {
        Site__c site = createTestSite('Deact Op', true, 'Every 3 months', 'Active');
        insert site;

        Test.startTest();
        site.Operating_Site__c = false;
        update site;
        Test.stopTest();

        List<Inspection_Performance__c> remaining = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        for (Inspection_Performance__c ip : remaining) {
            System.assert(ip.Date__c <= Date.today(), 'Seules les inspections passees/presentes doivent rester');
        }
    }

    // ─── Update : reactivation genere les inspections restantes ──────────────

    /**
     * FIX validation rule : Reason__c obligatoire lors de la desactivation intermediaire
     */
    @isTest static void testReactivation_GeneratesRemainingYear() {
        Site__c site = createTestSite('Reactiv', true, 'Every 3 months', 'Active');
        insert site;

        // FIX : renseigner Reason__c pour la desactivation
        site.Inspection_Enabled__c = 'Inactive - Closed site';
        site.Reason__c = 'Test - desactivation temporaire';
        update site;
        Integer countAfterDeact = [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size();

        Test.startTest();
        site.Inspection_Enabled__c = 'Active';
        site.Reason__c = null; // on remet a null lors de la reactivation
        update site;
        Test.stopTest();

        Integer countAfterReact = [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size();
        System.assert(countAfterReact >= countAfterDeact, 'La reactivation doit recreer des inspections');

        for (Inspection_Performance__c ip : [SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id]) {
            System.assert(ip.Date__c <= InspectionService.endOfCurrentYear());
        }
    }

    // ─── FIX v4.3 : reactivation site ancien part de Today ───────────────────

    @isTest static void testReactivation_OldSite_StartsFromToday() {
        Site__c site = createTestSite('Old Site', false, 'Every 3 months', 'Active');
        insert site;
        Test.setCreatedDate(site.Id, DateTime.newInstance(2024, 1, 1, 0, 0, 0));
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];

        Test.startTest();
        site.Operating_Site__c = true;
        update site;
        Test.stopTest();

        List<Inspection_Performance__c> insp = [
            SELECT Date__c FROM Inspection_Performance__c
            WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        System.assert(insp.size() >= 1, 'Au moins une inspection doit etre creee');
        for (Inspection_Performance__c ip : insp) {
            System.assert(ip.Date__c >= Date.today(),
                'Reactivation site ancien -> inspections depuis aujourd\'hui uniquement');
        }
        for (Inspection_Performance__c ip : insp) {
            System.assert(ip.Date__c <= InspectionService.endOfCurrentYear());
        }
    }

    // ─── Update : changement de frequence active->active ─────────────────────

    @isTest static void testFrequencyChange_ActiveToActive() {
        Site__c site = createTestSite('FreqChange', true, 'Every month', 'Active');
        insert site;

        Integer countEveryMonth = [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size();
        System.assert(countEveryMonth >= 1);

        Test.startTest();
        site.Inspection_Frequency__c = 'Every 3 months';
        update site;
        Test.stopTest();

        List<Inspection_Performance__c> afterChange = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        System.assert(afterChange.size() < countEveryMonth,
            'Changement vers frequence moins dense -> moins d\'inspections');
        for (Inspection_Performance__c ip : afterChange) {
            System.assert(ip.Date__c <= InspectionService.endOfCurrentYear());
        }
    }

    // ─── Anti-doublon ────────────────────────────────────────────────────────

    @isTest static void testNoDuplicate_SameMonthTarget() {
        Site__c site = createTestSite('NoDup', true, 'Every 3 months', 'Active');
        insert site;
        Integer before = [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size();

        Test.startTest();
        site.Operating_Site__c = false; update site;
        site.Operating_Site__c = true;  update site;
        Test.stopTest();

        System.assert(
            [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size() <= before + 1,
            'Pas de doublons massifs apres desact/react');
    }

    // ─── Unique_Key__c ─────────────────────────────────────────────────────

    @isTest static void testUniqueKeyPopulated() {
        Site__c site = createTestSite('UK', true, 'Every 3 months', 'Active');
        Test.startTest(); insert site; Test.stopTest();
        for (Inspection_Performance__c ip : [SELECT Unique_Key__c FROM Inspection_Performance__c WHERE Site__c = :site.Id]) {
            System.assertNotEquals(null, ip.Unique_Key__c);
            System.assert(ip.Unique_Key__c.contains('_'));
        }
    }

    // ─── endOfCurrentYear ────────────────────────────────────────────────────

    @isTest static void testEndOfCurrentYear() {
        Date eoy = InspectionService.endOfCurrentYear();
        System.assertEquals(12, eoy.month());
        System.assertEquals(31, eoy.day());
        System.assertEquals(Date.today().year(), eoy.year());
    }

    // ─── isSiteEligible ──────────────────────────────────────────────────────

    @isTest static void testIsSiteEligible() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        System.assertEquals(true,  InspectionService.isSiteEligible(new Site__c(Operating_Site__c=true,  Inspection_Frequency__c='Every month',    Inspection_Enabled__c='Active',                 Account__c=acc.Id, Country2__c='FR', Name='E')));
        System.assertEquals(false, InspectionService.isSiteEligible(new Site__c(Operating_Site__c=false, Inspection_Frequency__c='Every month',    Inspection_Enabled__c='Active',                 Account__c=acc.Id, Country2__c='FR', Name='NO')));
        System.assertEquals(false, InspectionService.isSiteEligible(new Site__c(Operating_Site__c=true,  Inspection_Frequency__c='Not applicable', Inspection_Enabled__c='Active',                 Account__c=acc.Id, Country2__c='FR', Name='NA')));
        System.assertEquals(false, InspectionService.isSiteEligible(new Site__c(Operating_Site__c=true,  Inspection_Frequency__c='Every month',    Inspection_Enabled__c='Inactive - Closed site', Account__c=acc.Id, Country2__c='FR', Name='CS')));
    }
}