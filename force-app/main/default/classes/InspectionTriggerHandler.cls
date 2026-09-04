/**
 * @description Handler pour le trigger sur Site__c
 * Version 4.2 — délègue handleAfterUpdate à InspectionService
 */
public with sharing class InspectionTriggerHandler {

    public static void handleAfterInsert(List<Site__c> newSites) {
        InspectionService.createInitialInspectionsOnInsert(newSites);
    }

    public static void handleAfterUpdate(Map<Id, Site__c> newSitesMap, Map<Id, Site__c> oldSitesMap) {
        InspectionService.handleAfterUpdate(newSitesMap, oldSitesMap);
    }
}