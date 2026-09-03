trigger MarketFlowTrigger on Market_Flow__c (before insert, before update, before delete, after insert, after update, after delete, after undelete)
{
    if (Trigger.isBefore)
    {
        if (Trigger.isDelete)
        {    
            //
            //prevent record deletion in some cases
            //
            Id profileId= userinfo.getProfileId();
            String profileName=[Select Id,Name from Profile where Id=:profileId].Name;
            
            String controllingApprover = [Select Controlling_Approver__c From User Where Id = :UserInfo.getUserId()][0].Controlling_Approver__c;
        
            for(Market_Flow__c obj : trigger.old){
                if(
                    profileName<>'System Administrator' &&
                    profileName<>'Global Delegated Admin' &&
                    controllingApprover <> 'Country Approver' &&
                    (controllingApprover <> 'Local Approver' || obj.Status__c <> 'Approved_locally') &&
                    obj.Status__c <> 'New'
                ){
                    obj.addError(System.Label.Market_Flow_Trigger_Error_Msg);
                }
            }
        }
    }
}