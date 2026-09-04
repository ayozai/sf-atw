/**
 * @description Batch de génération annuelle des inspections
 * Version 4.2 — génère toutes les inspections jusqu'au 31/12 de l'année en cours
 *
 * Comportement :
 *   - asOfDate par défaut = 31/12 de l'année courante
 *   - Crée toutes les inspections manquantes sur les mois fixes du cycle
 *   - Anti-doublon : clé AAAA-MM (existantes filtrées avant insertion)
 */
public class InspectionBatch implements Database.Batchable<sObject> {

    private Date asOfDate;

    public InspectionBatch() {
        // Génération annuelle en masse : couvre toute l'année courante
        this.asOfDate = InspectionService.endOfCurrentYear();
    }

    public InspectionBatch(Date asOfDate) {
        this.asOfDate = asOfDate != null ? asOfDate : InspectionService.endOfCurrentYear();
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, CreatedDate, Operating_Site__c,
                   Inspection_Frequency__c, Inspection_Enabled__c
            FROM Site__c
            WHERE Operating_Site__c = true
              AND Inspection_Frequency__c != null
              AND Inspection_Frequency__c != 'Not applicable'
              AND Inspection_Enabled__c = 'Active'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Site__c> sites) {
        Set<Id> siteIds = new Set<Id>();
        for (Site__c site : sites) siteIds.add(site.Id);

        Map<Id, List<Inspection_Performance__c>> inspectionsBySite =
            new Map<Id, List<Inspection_Performance__c>>();

        for (Inspection_Performance__c ip : [
            SELECT Site__c, Date__c FROM Inspection_Performance__c
            WHERE Site__c IN :siteIds ORDER BY Date__c ASC
        ]) {
            if (!inspectionsBySite.containsKey(ip.Site__c))
                inspectionsBySite.put(ip.Site__c, new List<Inspection_Performance__c>());
            inspectionsBySite.get(ip.Site__c).add(ip);
        }

        List<Inspection_Performance__c> toInsert = new List<Inspection_Performance__c>();
        for (Site__c site : sites) {
            toInsert.addAll(
                InspectionService.generateRecurringInspections(
                    site, asOfDate, inspectionsBySite.get(site.Id)
                )
            );
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('InspectionBatch terminé — asOfDate : ' + asOfDate);
    }
}