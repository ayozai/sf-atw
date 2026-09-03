public class TriggerHelperBidSupportRequest {

    public static void checkBeforeUpdate(Map<Id, Bid_Support_Request__c> oldMap, Map<Id, Bid_Support_Request__c> newMap, List<Bid_Support_Request__c> requests) {
        for (Bid_Support_Request__c bid : requests) {
            if (oldmap.get(bid.id).Type__c <> bid.Type__c) {
                bid.Type__c.addError('Cannot change Request Type once created');
            }

            if (bid.Allocated__c && oldmap.get(bid.id).Allocated__c <> bid.Allocated__c ) {
                bid.Allocated_Date__c = System.today();
                bid.Complete__c = true;
            }
            if (bid.Approval__c <> null && oldmap.get(bid.id).Approval__c <> bid.Approval__c) {
                bid.Approval_Date__c = System.today();
                if (bid.Approval__c == 'Denied') {
                    bid.Complete__c = true;
                } else {
                    bid.Complete__c = false;
                }
            }
        }
    }
    
    public static void checkBeforeInsert(Map<Id, Bid_Support_Request__c> oldMap, Map<Id, Bid_Support_Request__c> newMap, List<Bid_Support_Request__c> requests) {
        
        // Get the list of Opportunity Ids and User Ids
        Set<Id> OppIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        for (Bid_Support_request__c req : requests) {
            OppIds.add(req.Opportunity__c);
        }

        // Get all the requests for the Opportunities we're impacting
        List<Bid_Support_Request__c> allRequests = [SELECT Id, Complete__c, Type__c, Opportunity__c FROM Bid_Support_Request__c WHERE Opportunity__c IN :OppIds];        

        // Add the requests to an Opp map        
        Map<Id, List<Bid_Support_Request__c>> OppIdToRequests = new Map<Id, List<Bid_Support_Request__c>>();
        for (Bid_Support_Request__c request: allRequests) {
            if (!OppIdToRequests.containsKey(request.Opportunity__c)) {
                OppIdToRequests.put(request.Opportunity__c,new List<Bid_Support_Request__c>());
            }
            OppIdToRequests.get(request.Opportunity__c).add(request);
        }
        
        for (Bid_Support_Request__c bid: requests) {
            // Check type has not already been requested
            if (OppIdToRequests.containsKey(bid.Opportunity__c)) {
            
                // Removing as should allow multiple requests of the same type
                // 15/07/2018
                /*
                    for (Bid_Support_Request__c oldRequest: OppIdToRequests.get(bid.Opportunity__c)) {
                        if (oldRequest.type__c == bid.Type__c) {
                            bid.Type__c.addError('Duplicate request for Type:' + bid.Type__c);
                            break;
                        }
                    }
                */
    
                // Check no other open requests exist
                for (Bid_Support_Request__c oldRequest: OppIdToRequests.get(bid.Opportunity__c)) {
                    if (!oldRequest.Complete__c) {
                        bid.addError('Open Support request in progress');
                        break;
                    }
                }
            }
            
            if (bid.Allocated__c) {
                bid.Allocated_Date__c = System.today();
                bid.Complete__c = true;
            }
            if (bid.Approval__c <> null) {
                bid.Approval_Date__c = System.today();
                if (bid.Approval__c == 'Denied') {
                    bid.Complete__c = true;
                }
            }
        }
    }

    public static void checkAfterInsert(Map<Id, Bid_Support_Request__c> oldMap, Map<Id, Bid_Support_Request__c> newMap, List<Bid_Support_Request__c> requests) {
        System.debug('**** checkAfterInsert');
        List<Messaging.SingleEmailMessage> theMessages = new List<Messaging.SingleEmailMessage> ();
        
        // Get the list of Opportunity Ids and User Ids
        Set<Id> userIds = new Set<Id>();
        for (Bid_Support_request__c req : requests) {
            userIds.add(req.CreatedById);
        }

        // Get all the users for the requests we're creating
        List<User> allUsers = [SELECT Id, ManagerId FROM User WHERE Id IN :userIds];
        // Get Manager map       
        Map<Id,Id> managerIds = new Map<Id,Id>();
        for (User u: allUsers) {
            if (u.ManagerId == null) { // Add users own email if not assigned a manager
                u.managerId = u.Id;
            } 
            managerIds.put(u.id, u.managerId);
        }
        Map<Id, User> managerEmails = new Map<Id, User>([SELECT Id, Email FROM User WHERE Id IN :managerIds.values()]);

        List<EmailTemplate> templateList = [SELECT Id FROM EmailTemplate WHERE ID = :Label.Bid_Support_Request_Email_Id LIMIT 1];        
        
        for (Bid_Support_Request__c bid: requests) {
            if (!bid.Complete__c && templateList.size() > 0) { // Only send the email if we have a valid template
                Messaging.SingleEmailMessage message;
                message = Messaging.renderStoredEmailTemplate(templateList[0].Id, managerIds.get(bid.CreatedById), bid.Opportunity__c);
                message.setSaveAsActivity(false);
                message.setSubject('Bid Support Request ('+bid.Name+') Requires Approval');
                message.toAddresses = new String[]{managerEmails.get(managerIds.get(bid.CreatedById)).Email};
                message.bccAddresses = new String[]{'solutions@servest.co.uk'};
                theMessages.add(message);
                system.debug(message);
            }
        }

        if (theMessages.size() > 0 && !Test.isRunningTest()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(theMessages);

            if (results[0].success) {
                System.debug('The email was sent successfully.');
            } else {
                System.debug('The email failed to send: ' + results[0].errors[0].message);
            }
        }
    }
}