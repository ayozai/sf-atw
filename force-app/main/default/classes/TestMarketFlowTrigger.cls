@isTest
private class TestMarketFlowTrigger {

    @isTest static void TestMarketFlowDeletion() {
        // Test data setup
        // 
        // run as sysadmin
        // 
    Agency__c agency;
        Accounting_System_Site__c osr;
        Market_Flow__c mfr;

        // Create an agency and an operations site record
        agency = new Agency__c(Name='Test Agency',
                               Agency_Name__c='Test Agency',
                               Country__c='FR');
        insert agency;
        
        osr = new Accounting_System_Site__c(Agency__c = agency.Id,
                                            Site__c = 'Test Operations Site',
                                            Country__c = 'FR',
                                            Public_Private__c = 'Private');
        insert osr;
        
        // Create a market flow record, and then try to delete it
        mfr = new Market_Flow__c(Effective_Date__c = Date.newInstance(2100, 3, 1),
                                 Gross_Margin_2__c = 15,
                                 Monthly_Revenue__c = 1234,
                                 Type__c = 'Win',
                                 Competitor_Name__c = 'ONET',
                                 Contract_Duration__c = 12,
                                 Operations_Site__c = osr.Id,
                                 Status__c = 'Approved_country');
        insert mfr;
        
        // Perform test
        Test.startTest();
        Database.DeleteResult result = Database.delete(mfr, false);
        Test.stopTest();
        
        // Verify 
        System.assert(result.isSuccess());
        System.assert(result.getErrors().size() == 0);
    }
    
     @isTest static void TestMarketFlowStoppedDeletion() {
        // Test data setup
        
        // Create a Global Controlling User Country Approver
        Profile p = [SELECT Id FROM Profile WHERE Name='Global Controlling User'];
        UserRole r = [SELECT Id FROM UserRole WHERE Name='France'];
        User u1 = new User(Alias = 'count',
                           Email='countryUser@testorg.com',
                           EmailEncodingKey='UTF-8',
                           LastName='Testing',
                           LanguageLocaleKey='fr',
                           LocaleSidKey='fr_FR',
                           ProfileId = p.Id,
                           UserRoleId = r.Id,
                           TimeZoneSidKey='Europe/Paris',
                           UserName='countryUser@atalianworld.com',
                           Country = 'France',
                           Controlling_Approver__c = 'Country Approver',
                           Recharge__c = 'Corporate',
                           Division = 'Test');
        insert u1;
        
        //Add market flow permission set to u1 Market_Flow_Standard
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name='Market_Flow_Standard'];
        PermissionSetAssignment psa1 = new PermissionSetAssignment(PermissionSetId = ps.Id,
                                                                  AssigneeId = u1.Id);
    insert psa1;  
        
        // Create a Global Controlling User Local Approver
        UserRole r2 = [SELECT Id FROM UserRole WHERE Name='France'];
        User u2 = new User(Alias = 'local',
                           Email='localUser@testorg.com',
                           EmailEncodingKey='UTF-8',
                           LastName='Testing',
                           LanguageLocaleKey='fr',
                           LocaleSidKey='fr_FR',
                           ProfileId = p.Id,
                           UserRoleId = r2.Id,
                           TimeZoneSidKey='Europe/Paris',
                           UserName='localUser@atalianworld.com',
                           Country = 'France',
                           Controlling_Approver__c = 'Local Approver',
                           Recharge__c = 'Corporate',
                           Division = 'Test');
        insert u2;
         
        //Add market flow permission set to u2 Market_Flow_Standard
        PermissionSetAssignment psa2 = new PermissionSetAssignment(PermissionSetId = ps.Id,
                                                                  AssigneeId = u2.Id);
    insert psa2;  
        
        Agency__c agency;
        Accounting_System_Site__c osr;
        Market_Flow__c mfr;
        
        System.runAs(u2)
        {
            // Create an agency and an operations site record
          agency = new Agency__c(Name='Test Agency',
                                   Agency_Name__c='Test Agency',
                                   Country__c='FR');
            insert agency;

          osr = new Accounting_System_Site__c(Agency__c = agency.Id,
                                                Site__c = 'Test Operations Site',
                                                Country__c = 'FR',
                                                Public_Private__c = 'Private');
            insert osr; 
        
          // Create a market flow record, and then try to delete it
          mfr = new Market_Flow__c(Effective_Date__c = Date.newInstance(2100, 3, 1),
                                                Gross_Margin_2__c = 15,
                                                Monthly_Revenue__c = 1234,
                                                Type__c = 'Win',
                                                Competitor_Name__c = 'ONET',
                                                Contract_Duration__c = 12,
                                                Operations_Site__c = osr.Id,
                                                Status__c = 'Approved_locally');
            insert mfr;
        }
         
        System.runAs(u1)
        {
            mfr.Status__c = 'Approved_country';
            update mfr;
        }
        
        System.runAs(u2)
        { 
            // Perform test
            Test.startTest();
            Database.DeleteResult result = Database.delete(mfr, false);
            Test.stopTest();
            
            // Verify 
            // In this case the deletion should have been stopped by the trigger,
            // so verify that we got back an error.
            System.assert(!result.isSuccess());
            System.assert(result.getErrors().size() > 0);
            /*System.assertEquals('Cannot delete market flow.',
                                 result.getErrors()[0].getMessage());*/
        }
    }
}