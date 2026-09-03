trigger AccountTrigger on Account (before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
    if (Trigger.isBefore)
    {
        if (Trigger.isInsert)
        {
            TriggerHelperAccount.HandleBeforeInsert(Trigger.new);
        }
        else if (Trigger.isUpdate)
        {
            TriggerHelperAccount.HandleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
    else if (Trigger.isAfter)
    {
        if (Trigger.isInsert)
        {
            TriggerHelperAccount.HandleAfterInsert(Trigger.new);
        }
        else if (Trigger.isUpdate)
        {
            TriggerHelperAccount.HandleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
        else if (Trigger.isDelete)
        {
            TriggerHelperAccount.HandleAfterDelete(Trigger.oldMap);
        }
        else if (Trigger.isUndelete)
        {
            TriggerHelperAccount.HandleAfterUndelete(Trigger.new);
        }
    }
}