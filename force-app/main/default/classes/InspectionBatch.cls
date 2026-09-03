/**
 * @description Batch de génération récurrente des inspections
 * Exécuté périodiquement pour créer les inspections manquantes
 */
public class InspectionBatch implements Database.Batchable<sObject> {
    
    private Date asOfDate;
    
    /**
     * @description Constructeur avec date personnalisée
     */
    public InspectionBatch(Date asOfDate) {
        this.asOfDate = asOfDate != null ? asOfDate : Date.today();
    }
    
    /**
     * @description Constructeur par défaut (date du jour)
     */
    public InspectionBatch() {
        this(Date.today());
    }
    
    /**
     * @description Start : récupère tous les sites éligibles
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, 
                   CreatedDate, 
                   Operating_Site__c, 
                   Inspection_Frequency__c
            FROM Site__c
            WHERE Operating_Site__c = true
              AND Inspection_Frequency__c != null
              AND Inspection_Frequency__c != 'Not applicable'
        ]);
    }
    
    /**
     * @description Execute : génère les inspections pour chaque site
     */
    public void execute(Database.BatchableContext bc, List<Site__c> sites) {
        
        // Récupérer les IDs des sites
        Set<Id> siteIds = new Set<Id>();
        for (Site__c site : sites) {
            siteIds.add(site.Id);
        }
        
        // Récupérer toutes les inspections existantes
        Map<Id, List<Inspection_Performance__c>> inspectionsBySite = new Map<Id, List<Inspection_Performance__c>>();
        
        for (Inspection_Performance__c inspection : [
            SELECT Site__c, Date__c 
            FROM Inspection_Performance__c 
            WHERE Site__c IN :siteIds
            ORDER BY Date__c ASC
        ]) {
            if (!inspectionsBySite.containsKey(inspection.Site__c)) {
                inspectionsBySite.put(inspection.Site__c, new List<Inspection_Performance__c>());
            }
            inspectionsBySite.get(inspection.Site__c).add(inspection);
        }
        
        // Générer les inspections manquantes
        List<Inspection_Performance__c> inspectionsToInsert = new List<Inspection_Performance__c>();
        
        for (Site__c site : sites) {
            List<Inspection_Performance__c> existingInspections = inspectionsBySite.get(site.Id);
            
            List<Inspection_Performance__c> newInspections = 
                InspectionService.generateRecurringInspections(site, asOfDate, existingInspections);
            
            inspectionsToInsert.addAll(newInspections);
        }
        
        // Insertion des nouvelles inspections
        if (!inspectionsToInsert.isEmpty()) {
            insert inspectionsToInsert;
        }
    }
    
    /**
     * @description Finish : actions post-batch si nécessaire
     */
    public void finish(Database.BatchableContext bc) {
        // Log ou notification si besoin
        System.debug('InspectionBatch terminé avec succès');
    }
}