/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 05-19-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
@isTest
private class InspectionBatch_Test {
    
    @testSetup
    static void setup() {
        // Créer un Account pour les tests
        Account testAccount = new Account(Name = 'Test Account Batch');
        insert testAccount;
    }
    
    /**
     * @description Méthode utilitaire pour créer un Site de test
     */
    private static Site__c createTestSite(String siteName, Boolean operating, String frequency) {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        return new Site__c(
            Name = siteName,
            Account__c = acc.Id,
            Country2__c = 'FR',
            Operating_Site__c = operating,
            Inspection_Frequency__c = frequency
        );
    }
    
    @isTest
    static void testBatchGenerationMonthly() {
        Site__c site = createTestSite('Test Site Batch Monthly', true, 'Every month');
        insert site;

        // Supprimer l'inspection initiale créée automatiquement par le trigger
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];
        // Créer une inspection initiale au 01/01/2026
        Inspection_Performance__c initial = new Inspection_Performance__c(
            Site__c = site.Id,
            Date__c = Date.newInstance(2026, 1, 1)
        );
        insert initial;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch(Date.newInstance(2026, 4, 1));
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Date__c 
            FROM Inspection_Performance__c 
            WHERE Site__c = :site.Id
            ORDER BY Date__c ASC
        ];
        
        System.assertEquals(4, inspections.size());
        System.assertEquals(Date.newInstance(2026, 1, 1), inspections[0].Date__c);
        System.assertEquals(Date.newInstance(2026, 2, 1), inspections[1].Date__c);
        System.assertEquals(Date.newInstance(2026, 3, 1), inspections[2].Date__c);
        System.assertEquals(Date.newInstance(2026, 4, 1), inspections[3].Date__c);
    }
    
    @isTest
    static void testBatchEvery3Months() {
        Site__c site = createTestSite('Test Site 3M', true, 'Every 3 months');
        insert site;
        
        // 🔧 Correction : retirer l'inspection initiale créée automatiquement par le trigger
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];
        
        // Créer l’inspection initiale contrôlée (01/01/2026)
        Inspection_Performance__c initial = new Inspection_Performance__c(
            Site__c = site.Id,
            Date__c = Date.newInstance(2026, 1, 1)
        );
        insert initial;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch(Date.newInstance(2026, 10, 1));
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Date__c 
            FROM Inspection_Performance__c 
            WHERE Site__c = :site.Id
            ORDER BY Date__c ASC
        ];
        
        System.assertEquals(4, inspections.size(), 'Doit avoir 4 inspections tous les 3 mois');
        System.assertEquals(Date.newInstance(2026, 1, 1), inspections[0].Date__c);
        System.assertEquals(Date.newInstance(2026, 4, 1), inspections[1].Date__c);
        System.assertEquals(Date.newInstance(2026, 7, 1), inspections[2].Date__c);
        System.assertEquals(Date.newInstance(2026, 10, 1), inspections[3].Date__c);
    }
    
    @isTest
    static void testBatchEveryYear() {
        Site__c site = createTestSite('Test Site Yearly', true, 'Every year');
        insert site;
        
        // Supprimer l'inspection initiale créée par le trigger
        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];
        
        Inspection_Performance__c initial = new Inspection_Performance__c(
            Site__c = site.Id,
            Date__c = Date.newInstance(2024, 1, 1)
        );
        insert initial;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch(Date.newInstance(2026, 6, 1));
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Date__c 
            FROM Inspection_Performance__c 
            WHERE Site__c = :site.Id
            ORDER BY Date__c ASC
        ];
        
        System.assertEquals(3, inspections.size());
    }
    
    @isTest
    static void testBatchWithoutExistingInspection() {
        Site__c site = createTestSite('Test Site No Initial', true, 'Every 2 months');
        insert site;

        // Backdate the site so the anchor date (CreatedDate) is before asOfDate
        Test.setCreatedDate(site.Id, DateTime.newInstance(2026, 1, 1, 0, 0, 0));

        delete [SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id];

        Test.startTest();
        InspectionBatch batch = new InspectionBatch(Date.newInstance(2026, 6, 1));
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Date__c 
            FROM Inspection_Performance__c 
            WHERE Site__c = :site.Id
            ORDER BY Date__c ASC
        ];
        
        System.assert(inspections.size() > 0);
    }
    
    @isTest
    static void testBatchSkipsNotApplicable() {
        Site__c site = createTestSite('Test Site N/A', true, 'Not applicable');
        insert site;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(0, inspections.size());
    }
    
    @isTest
    static void testBatchSkipsNonOperatingSite() {
        Site__c site = createTestSite('Test Site Inactive', false, 'Every month');
        insert site;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(0, inspections.size());
    }
    
    @isTest
    static void testBatchDefaultConstructor() {
        Site__c site = createTestSite('Test Site Default', true, 'Every month');
        insert site;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assert(inspections.size() > 0);
    }
    
    @isTest
    static void testBatchMultipleSites() {
        List<Site__c> sites = new List<Site__c>{
            createTestSite('Site 1', true, 'Every month'),
            createTestSite('Site 2', true, 'Every 3 months'),
            createTestSite('Site 3', true, 'Every 6 months')
        };
        insert sites;
        
        Test.startTest();
        InspectionBatch batch = new InspectionBatch(Date.newInstance(2026, 12, 1));
        Database.executeBatch(batch);
        Test.stopTest();
        
        for (Site__c site : sites) {
            List<Inspection_Performance__c> inspections = [
                SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
            ];
            System.assert(inspections.size() > 0);
        }
    }
}