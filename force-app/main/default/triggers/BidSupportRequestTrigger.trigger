trigger BidSupportRequestTrigger on Bid_Support_Request__c (before insert, before update, after insert) {
    
    if (trigger.isUpdate) {
        if (trigger.isBefore) {
            TriggerHelperBidSupportRequest.checkBeforeUpdate(Trigger.oldMap, Trigger.newMap, Trigger.new);            
        }
    }
    
    if (trigger.isInsert) {
        if (trigger.isBefore) {
            TriggerHelperBidSupportRequest.checkBeforeInsert(Trigger.oldMap, Trigger.newMap, Trigger.new);            
        }
        if (trigger.isAfter) {
            TriggerHelperBidSupportRequest.checkAfterInsert(Trigger.oldMap, Trigger.newMap, Trigger.new);            
        }
    }
}