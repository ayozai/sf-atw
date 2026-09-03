/**
 * @description Handler pour le trigger sur Site__c
 */
public with sharing class InspectionTriggerHandler {
    
    /**
     * @description Logique After Insert
     */
    public static void handleAfterInsert(List<Site__c> newSites) {
        InspectionService.createInitialInspectionsOnInsert(newSites);
    }
    
    /**
     * @description Logique After Update
     */
    public static void handleAfterUpdate(Map<Id, Site__c> newSitesMap, Map<Id, Site__c> oldSitesMap) {
        InspectionService.createInitialInspectionsOnUpdate(newSitesMap, oldSitesMap);
    }
}