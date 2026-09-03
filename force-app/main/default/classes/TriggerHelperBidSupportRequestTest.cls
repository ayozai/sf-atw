@isTest
public class TriggerHelperBidSupportRequestTest {

    @testSetup
    public static void setupTestData()
    {
        //create account
        Account acc = new Account(Name = 'Test Acc');
        insert acc;
        
        //create Opp
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            AccountId = acc.Id,
            contract_start_date__c= Date.today().addDays(1),
            contract_end_date__c= Date.today().addYears(1),
            CloseDate = Date.today(),
            StageName = '2. Prospect',
            Global_Primary_Service__c = 'Technical Services'
        );
        insert opp;
    }
    
    @isTest
    public static void createBidRequest_Test()
    {
        List<Opportunity> Opps = [SELECT Id FROM Opportunity];

        Test.startTest();
            Bid_Support_Request__c bsr2 = new Bid_Support_Request__c(
                Type__c = 'Brochure',
                Opportunity__c = Opps[0].Id,
                Approval__c = 'Approved',
                Approval_Reason__c = 'blablablabla',
                Allocated__c = True
            );
            insert bsr2;

            Bid_Support_Request__c bsr = new Bid_Support_Request__c(
                Type__c = 'PQQ',
                Opportunity__c = Opps[0].Id,
                Approval_Reason__c = 'blablablabla'
            );
            insert bsr;

        test.stopTest();
        
        List<Bid_Support_Request__c> BSRs = [SELECT Id FROM Bid_Support_Request__c];
        
        system.assertEquals(2,BSRs.size(),'Unexpected number of Requests returned!');
    }

    // approve request
    @isTest
    public static void approveBidRequest_Test()
    {
        List<Opportunity> Opps = [SELECT Id FROM Opportunity];

        Bid_Support_Request__c bsr = new Bid_Support_Request__c(
            Type__c = 'PQQ',
            Opportunity__c = Opps[0].Id,
            Approval_Reason__c = 'blablablabla'
        );
        insert bsr;

        Test.startTest();
            bsr.Approval__c = 'Approved';
            bsr.Approval_Reason__c = 'blablablabla';
            update bsr;
        Test.stopTest();
        
        List<Bid_Support_Request__c> BSRs = [SELECT Id, Approval_Date__c, Complete__c FROM Bid_Support_Request__c];
        
        system.assertEquals(Date.today(),BSRs[0].Approval_Date__c,'BSR should be approved today!');
        system.assertEquals(false,BSRs[0].Complete__c,'BSR should not be Complete!');
    }

    // allocate request
    @isTest
    public static void allocateBidRequest_Test()
    {
        List<Opportunity> Opps = [SELECT Id FROM Opportunity];

        Bid_Support_Request__c bsr = new Bid_Support_Request__c(
            Type__c = 'PQQ',
            Opportunity__c = Opps[0].Id,
            Approval__c = 'Approved',
            Approval_Reason__c = 'blablablabla'
        );
        insert bsr;

        Test.startTest();
            bsr.Allocated__c = true;
            bsr.Approval_Reason__c = 'blablablabla';
            update bsr;
        Test.stopTest();
        
        List<Bid_Support_Request__c> BSRs = [SELECT Id, Allocated_Date__c, Complete__c FROM Bid_Support_Request__c];
        
        system.assertEquals(Date.today(), BSRs[0].Allocated_Date__c,'BSR should be allocated today!');
        system.assertEquals(true, BSRs[0].Complete__c,'BSR should be Complete!');
    }

}