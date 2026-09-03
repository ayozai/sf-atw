trigger ContentDocumentLinkTrigger on ContentDocumentLink (before insert) {

    for (ContentDocumentLink item : Trigger.new) {

        //get object type
		String sObjName = item.LinkedEntityId.getSObjectType().getDescribe().getName();  
        
        if(sObjName == 'Inspection__c')
        {
            //update item
            item.Visibility = 'AllUsers';
        }
    }
}