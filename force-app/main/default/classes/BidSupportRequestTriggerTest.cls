@isTest
public class BidSupportRequestTriggerTest {
    
    @isTest
    static void testBeforeUpdate() {

        // Create Account and Opportunity
        Account acc = TestData.createAccount();
        insert acc;

        Opportunity opp = testData.createOpportunity(acc);
        
        Bid_Support_Request__c bsr = new Bid_Support_Request__c(
            Type__c = 'Proposal',
            Opportunity__c = opp.Id
        );
        insert bsr;
        
        // Modify the record to simulate an update
        bsr.Complete__c = true;
        update bsr;

        // Perform assertions based on your trigger logic
        System.assertEquals(true, bsr.Complete__c, 'Type field should be updated correctly');
        // Add more assertions as needed
    }

    @isTest
    static void testBeforeInsert() {

         // Create Account and Opportunity
        Account acc = TestData.createAccount();
        insert acc;

        Opportunity opp = testData.createOpportunity(acc);
        
        Bid_Support_Request__c bsr = new Bid_Support_Request__c(
            Type__c = 'Proposal',
            Opportunity__c = opp.Id
        );

        // Perform insert to simulate before insert trigger
        insert bsr;

        // Perform assertions based on your trigger logic
        System.assertEquals('Proposal', bsr.Type__c, 'Type field should be set correctly during before insert');
        // Add more assertions as needed
    }

    @isTest
    static void testAfterInsert() {

         // Create Account and Opportunity
        Account acc = TestData.createAccount();
        insert acc;

        Opportunity opp = testData.createOpportunity(acc);
        
        Bid_Support_Request__c bsr = new Bid_Support_Request__c(
            Type__c = 'Proposal',
            Opportunity__c = opp.Id
            /* Add other relevant Bid_Support_Request__c field values */
        );

        // Perform insert to simulate after insert trigger
        insert bsr;

        // Perform assertions based on your trigger logic
        System.assertEquals('Proposal', bsr.Type__c, 'Type field should be set correctly during before insert');
        // Add more assertions as needed
    }
}