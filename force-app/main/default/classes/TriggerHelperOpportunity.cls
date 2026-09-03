/*********************************************************************
 * Helper class for Opportunity object
 * 
 * Test Class: TriggerHelperOpportunityTest
 * 
 * Written By:	???
 * Date:		???
 * Modified:
 *				24-March-2018	Tony Clarke
 *				Add rule to ensure at least 1 contact role has been
 *				assigned before an opty can be closed.
 *
 * *******************************************************************/
public class TriggerHelperOpportunity 
{
    public static void HandleBeforeInsert(List<Opportunity> newOpps) 
    {
        CheckForContactRoles(newOpps);
    }

    public static void HandleBeforeUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldOpps) 
    {
        CheckForContactRoles(newOpps);
    }
    
    public static void HandleAfterInsert(List<Opportunity> newOpps) 
    {
        dlrs.RollupService.triggerHandler(Opportunity.SObjectType);
    }

    public static void HandleAfterUpdate(List<Opportunity> newOpps, Map<Id, Opportunity> oldOpps) 
    {
        dlrs.RollupService.triggerHandler(Opportunity.SObjectType);
    }

    public static void HandleAfterDelete(Map<Id, Opportunity> oldOpps) 
    {
        dlrs.RollupService.triggerHandler(Opportunity.SObjectType);
    }

    public static void HandleAfterUndelete(List<Opportunity> newOpps) 
    {
        dlrs.RollupService.triggerHandler(Opportunity.SObjectType);
    }

    private static void CheckForContactRoles(List<Opportunity> oppList)
    {
        Map<Id, List<OpportunityContactRole>> contactsByOppId = new Map<Id, List<OpportunityContactRole>>();
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : oppList)
        {
            oppIds.add(opp.Id);
        }
        for (OpportunityContactRole ocr : [SELECT Id, OpportunityId, IsPrimary FROM OpportunityContactRole WHERE OpportunityId IN :oppIds])
        {
            if (!contactsByOppId.containsKey(ocr.OpportunityId))
            {
                contactsByOppId.put(ocr.OpportunityId, new List<OpportunityContactRole>());
            }
            contactsByOppId.get(ocr.OpportunityId).add(ocr);
        }
        for (Opportunity opp : oppList)
        {
            Boolean isPrimary = false;
            Integer count = 0;
            List<OpportunityContactRole> ocrs = contactsByOppId.get(opp.Id);
            if (ocrs != null)
            {
                for (OpportunityContactRole ocr : ocrs)
                {
                    if (ocr.IsPrimary)
                    {
                        isPrimary = true;
                        break;
                    }
                }
                count = ocrs.size();
            }
            opp.Primary_Contact_Assigned__c = isPrimary;
            opp.Number_of_Contacts_Roles_Assigned__c = count;
        }
    }
}