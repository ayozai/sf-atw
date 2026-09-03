trigger OpportunityTrigger on Opportunity (before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
    if (Trigger.isBefore)
    {
        if (Trigger.isInsert)
        {
            TriggerHelperOpportunity.HandleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate)
        {
            TriggerHelperOpportunity.HandleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter)
    {
        if (Trigger.isInsert)
        {
            TriggerHelperOpportunity.HandleAfterInsert(Trigger.new);
        }
        else if (Trigger.isUpdate)
        {
            TriggerHelperOpportunity.HandleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        else if (Trigger.isDelete)
        {
            TriggerHelperOpportunity.HandleAfterDelete(Trigger.oldMap);
        }
        else if (Trigger.isUndelete)
        {
            TriggerHelperOpportunity.HandleAfterUndelete(Trigger.new);
        }
    }
}