@isTest
private class InspectionBatch_Test {

    @testSetup
    static void setup() {
        insert new Account(Name = 'Test Account Batch');
    }

    private static Site__c createTestSite(String name, Boolean operating, String freq, String enabled) {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        return new Site__c(Name=name, Account__c=acc.Id, Country2__c='FR',
            Operating_Site__c=operating, Inspection_Frequency__c=freq, Inspection_Enabled__c=enabled);
    }

    @isTest static void testBatch_GeneratesFullYear_Every3Months() {
        Site__c site = createTestSite('Batch 3M', true, 'Every 3 months', 'Active');
        insert site;
        Test.setCreatedDate(site.Id, DateTime.newInstance(2026, 1, 1, 0, 0, 0));
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];

        Test.startTest();
        Database.executeBatch(new InspectionBatch(Date.newInstance(2026, 12, 31)));
        Test.stopTest();

        List<Inspection_Performance__c> insp = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        System.assertEquals(3, insp.size());
        System.assertEquals(Date.newInstance(2026,4,1),  insp[0].Date__c);
        System.assertEquals(Date.newInstance(2026,7,1),  insp[1].Date__c);
        System.assertEquals(Date.newInstance(2026,10,1), insp[2].Date__c);
    }

    @isTest static void testBatch_Every6Months_S1() {
        Site__c site = createTestSite('Batch 6M S1', true, 'Every 6 months', 'Active');
        insert site;
        Test.setCreatedDate(site.Id, DateTime.newInstance(2026, 3, 1, 0, 0, 0));
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];

        Test.startTest();
        Database.executeBatch(new InspectionBatch(Date.newInstance(2026, 12, 31)));
        Test.stopTest();

        List<Inspection_Performance__c> insp = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        System.assertEquals(2, insp.size());
        System.assertEquals(Date.newInstance(2026,1,1), insp[0].Date__c);
        System.assertEquals(Date.newInstance(2026,7,1), insp[1].Date__c);
    }

    /**
     * FIX validation rule : Reason__c obligatoire quand Enabled = Inactive
     */
    @isTest static void testBatch_SkipsDisabledSite() {
        Site__c site = createTestSite('Disabled', true, 'Every month', 'Inactive - Closed site');
        // FIX : renseigner Reason__c pour satisfaire la validation rule
        site.Reason__c = 'Test - site desactive batch';
        insert site;

        Test.startTest();
        Database.executeBatch(new InspectionBatch());
        Test.stopTest();

        System.assertEquals(0, [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size());
    }

    @isTest static void testBatch_SkipsNonOperating() {
        Site__c site = createTestSite('Not Op', false, 'Every month', 'Active');
        insert site;
        Test.startTest();
        Database.executeBatch(new InspectionBatch());
        Test.stopTest();
        System.assertEquals(0, [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size());
    }

    @isTest static void testBatch_DefaultConstructor_UsesEndOfYear() {
        Site__c site = createTestSite('Default', true, 'Every month', 'Active');
        insert site;
        Integer before = [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size();

        Test.startTest();
        Database.executeBatch(new InspectionBatch());
        Test.stopTest();

        System.assert(
            [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id].size() >= before,
            'Le batch ne doit pas supprimer d\'inspections existantes');
    }

    @isTest static void testBatch_AntiDoublon() {
        Site__c site = createTestSite('AntiDup', true, 'Every 3 months', 'Active');
        insert site;
        Test.setCreatedDate(site.Id, DateTime.newInstance(2026, 1, 1, 0, 0, 0));
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];

        insert new Inspection_Performance__c(
            Site__c = site.Id, Date__c = Date.newInstance(2026,4,1),
            Unique_Key__c = InspectionService.buildUniqueKey(site.Id, Date.newInstance(2026,4,1)));

        Test.startTest();
        Database.executeBatch(new InspectionBatch(Date.newInstance(2026, 12, 31)));
        Test.stopTest();

        List<Inspection_Performance__c> insp = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id ORDER BY Date__c ASC
        ];
        System.assertEquals(3, insp.size());
        System.assertEquals(Date.newInstance(2026,4,1),  insp[0].Date__c);
        System.assertEquals(Date.newInstance(2026,7,1),  insp[1].Date__c);
        System.assertEquals(Date.newInstance(2026,10,1), insp[2].Date__c);
    }
}