@isTest
private class InspectionService_Test {
    
    @testSetup
    static void setup() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
    }
    
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
    static void testGetFrequencyInterval() {
        System.assertEquals(1, InspectionService.getFrequencyInterval('Every month'));
        System.assertEquals(2, InspectionService.getFrequencyInterval('Every 2 months'));
        System.assertEquals(3, InspectionService.getFrequencyInterval('Every 3 months'));
        System.assertEquals(4, InspectionService.getFrequencyInterval('Every 4 months'));
        System.assertEquals(6, InspectionService.getFrequencyInterval('Every 6 months'));
        System.assertEquals(12, InspectionService.getFrequencyInterval('Every year'));
        System.assertEquals(0, InspectionService.getFrequencyInterval('Not applicable'));
        System.assertEquals(0, InspectionService.getFrequencyInterval(null));
        System.assertEquals(0, InspectionService.getFrequencyInterval(''));
    }
    
    @isTest
    static void testNormalizeToFirstDayOfMonth() {
        Date testDate = Date.newInstance(2026, 1, 23);
        Date normalized = InspectionService.normalizeToFirstDayOfMonth(testDate);
        
        System.assertEquals(Date.newInstance(2026, 1, 1), normalized);
        System.assertEquals(null, InspectionService.normalizeToFirstDayOfMonth(null));
        
        Date lastDay = Date.newInstance(2026, 2, 28);
        Date normalizedLastDay = InspectionService.normalizeToFirstDayOfMonth(lastDay);
        System.assertEquals(Date.newInstance(2026, 2, 1), normalizedLastDay);
    }
    
    @isTest
    static void testCreateInitialInspectionOnInsert() {
        Site__c site = createTestSite('Test Site', true, 'Every month');
        
        Test.startTest();
        insert site;
        Test.stopTest();
        
        site = [SELECT Id, CreatedDate FROM Site__c WHERE Id = :site.Id];
        
        List<Inspection_Performance__c> inspections = [
            SELECT Date__c FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(1, inspections.size());
        
        Date expectedDate = InspectionService.normalizeToFirstDayOfMonth(site.CreatedDate.date());
        System.assertEquals(expectedDate, inspections[0].Date__c);
    }
    
    @isTest
    static void testNoInspectionWhenNotOperating() {
        Site__c site = createTestSite('Test Site Inactive', false, 'Every month');
        
        Test.startTest();
        insert site;
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(0, inspections.size());
    }
    
    @isTest
    static void testNoInspectionWhenNotApplicable() {
        Site__c site = createTestSite('Test Site N/A', true, 'Not applicable');
        
        Test.startTest();
        insert site;
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(0, inspections.size());
    }
    
    @isTest
    static void testActivationCreatesInitialInspection() {
        Site__c site = createTestSite('Test Site', false, 'Every month');
        insert site;
        
        List<Inspection_Performance__c> before = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        System.assertEquals(0, before.size());
        
        Test.startTest();
        site.Operating_Site__c = true;
        update site;
        Test.stopTest();
        
        List<Inspection_Performance__c> after = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(1, after.size());
    }
    
    @isTest
    static void testFrequencyActivationCreatesInitialInspection() {
        Site__c site = createTestSite('Test Site', true, 'Not applicable');
        insert site;
        
        List<Inspection_Performance__c> before = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        System.assertEquals(0, before.size());
        
        Test.startTest();
        site.Inspection_Frequency__c = 'Every 3 months';
        update site;
        Test.stopTest();
        
        List<Inspection_Performance__c> after = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(1, after.size());
    }
    
    @isTest
    static void testFrequencyChangeFromNullToActive() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Site__c site = new Site__c(
            Name = 'Test Site',
            Account__c = acc.Id,
            Country2__c = 'FR',
            Operating_Site__c = true,
            Inspection_Frequency__c = 'Not applicable'
        );
        insert site;
        
        Test.startTest();
        site.Inspection_Frequency__c = 'Every 6 months';
        update site;
        Test.stopTest();
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(1, inspections.size());
    }
    
    @isTest
    static void testNoDuplicateInspection() {
        Site__c site = createTestSite('Test Site', true, 'Every month');
        insert site;
        
        List<Inspection_Performance__c> inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        Integer initialCount = inspections.size();
        System.assertEquals(1, initialCount);
        
        Test.startTest();
        site.Operating_Site__c = false;
        update site;
        
        site.Operating_Site__c = true;
        update site;
        Test.stopTest();
        
        inspections = [
            SELECT Id FROM Inspection_Performance__c WHERE Site__c = :site.Id
        ];
        
        System.assertEquals(initialCount, inspections.size());
    }
    
    @isTest
    static void testIsSiteEligible() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Site__c eligible = new Site__c(
            Name = 'Eligible',
            Account__c = acc.Id,
            Country2__c = 'FR',
            Operating_Site__c = true,
            Inspection_Frequency__c = 'Every month'
        );
        
        Site__c notOperating = new Site__c(
            Name = 'Not Operating',
            Account__c = acc.Id,
            Country2__c = 'FR',
            Operating_Site__c = false,
            Inspection_Frequency__c = 'Every month'
        );
        
        Site__c notApplicable = new Site__c(
            Name = 'Not Applicable',
            Account__c = acc.Id,
            Country2__c = 'FR',
            Operating_Site__c = true,
            Inspection_Frequency__c = 'Not applicable'
        );
        
        System.assertEquals(true, InspectionService.isSiteEligible(eligible));
        System.assertEquals(false, InspectionService.isSiteEligible(notOperating));
        System.assertEquals(false, InspectionService.isSiteEligible(notApplicable));
    }
    
    @isTest
    static void testGetExistingInspectionsBySite() {
        Site__c site1 = createTestSite('Site 1', true, 'Every month');
        Site__c site2 = createTestSite('Site 2', true, 'Every month');
        insert new List<Site__c>{site1, site2};
        
        // Rechargement pour récupérer CreatedDate
        site1 = [SELECT Id, CreatedDate FROM Site__c WHERE Id = :site1.Id];
        
        Date initialDate = InspectionService.normalizeToFirstDayOfMonth(site1.CreatedDate.date());
        
        // Ajout d'une inspection sur un mois différent (correction)
        Inspection_Performance__c insp1 = new Inspection_Performance__c(
            Site__c = site1.Id,
            Date__c = initialDate.addMonths(1)
        );
        insert insp1;
        
        Test.startTest();
        Map<Id, Set<Date>> result = InspectionService.getExistingInspectionsBySite(
            new Set<Id>{site1.Id, site2.Id}
        );
        Test.stopTest();
        
        System.assertEquals(2, result.get(site1.Id).size(), 'Site1 doit avoir 2 inspections');
        System.assertEquals(1, result.get(site2.Id).size(), 'Site2 doit avoir 1 inspection');
    }
}