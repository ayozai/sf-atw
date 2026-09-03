trigger AgencyTrigger on Agency__c (after update) {

    Map < Id,  Agency__c > mapAgency = new Map < Id, Agency__c >();
    List<Accounting_System_Site__c> listASSite = new List<Accounting_System_Site__c>();

    for(Agency__c agency : trigger.new){
        Agency__c oldAgency = Trigger.oldMap.get(agency.Id);
        if(agency.OwnerId != oldAgency.OwnerId)
            mapAgency.put(agency.Id, agency);
    }
    
    listASSite = [ SELECT Id,Process_Technical_Field__c  FROM Accounting_System_Site__c WHERE Agency__c IN : mapAgency.keySet() ];

    if ( listASSite.size() > 0 ) {
        for ( Accounting_System_Site__c assite : listASSite) {
            assite.Process_Technical_Field__c = System.now();
        }
        update listASSite;
    }
}