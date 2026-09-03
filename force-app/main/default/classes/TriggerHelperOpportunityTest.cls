/*********************************************************************
 * Test class for TriggerHelperOpportunity
 * 
 * Written By:  ???
 * Date:        ???
 * Modified:
 *              24-March-2018   Tony Clarke
 *              Add rule to ensure at least 1 contact role has been
 *              assigned before an opty can be closed.
 *
 * *******************************************************************/
@isTest
public class TriggerHelperOpportunityTest 
{
    @isTest
    public static void OpportunityUpdateWithContactRole_Test() 
    {
        TestData.createAll();

        Contact c = TestData.cont;
        Opportunity o = TestData.opp;

        insert new OpportunityContactRole (OpportunityId = o.Id, ContactId = c.Id);
        
        Test.startTest();
        update o;
        Test.stopTest();
        
        o = [select id, Number_of_Contacts_Roles_Assigned__c from opportunity where id = :o.id];
        system.assertEquals(1, o.Number_of_Contacts_Roles_Assigned__c);
    }

    @isTest
    public static void OpportunityUpdateWithoutContact_Test() 
    {
        TestData.createAll();

        Opportunity o = TestData.opp;

        Test.startTest();
        update o;
        Test.stopTest();

        o = [select id, Number_of_Contacts_Roles_Assigned__c from opportunity where id = :o.id];
        system.assertEquals(0, o.Number_of_Contacts_Roles_Assigned__c);
    }
}