/**
 * @description Service centralisé pour la gestion des inspections
 * Gère la création initiale et récurrente des Inspection_Performance__c
 */
public with sharing class InspectionService {
    
    // Constantes pour les fréquences (VALEURS EN ANGLAIS)
    private static final String FREQ_MONTHLY = 'Every month';
    private static final String FREQ_2_MONTHS = 'Every 2 months';
    private static final String FREQ_3_MONTHS = 'Every 3 months';
    private static final String FREQ_4_MONTHS = 'Every 4 months';
    private static final String FREQ_6_MONTHS = 'Every 6 months';
    private static final String FREQ_YEARLY = 'Every year';
    private static final String FREQ_NOT_APPLICABLE = 'Not applicable';
    
    /**
     * @description Retourne l'intervalle en mois selon la fréquence
     */
    public static Integer getFrequencyInterval(String frequency) {
        if (String.isBlank(frequency)) return 0;
        
        switch on frequency {
            when 'Every month' { return 1; }
            when 'Every 2 months' { return 2; }
            when 'Every 3 months' { return 3; }
            when 'Every 4 months' { return 4; }
            when 'Every 6 months' { return 6; }
            when 'Every year' { return 12; }
            when 'Not applicable' { return 0; }
            when else { return 0; }
        }
    }
    
    /**
     * @description Normalise une date au 1er jour du mois
     */
    public static Date normalizeToFirstDayOfMonth(Date inputDate) {
        if (inputDate == null) return null;
        return Date.newInstance(inputDate.year(), inputDate.month(), 1);
    }
    
    /**
     * @description Vérifie si un site est éligible pour les inspections
     */
    public static Boolean isSiteEligible(Site__c site) {
        return site.Operating_Site__c == true 
            && String.isNotBlank(site.Inspection_Frequency__c)
            && site.Inspection_Frequency__c != FREQ_NOT_APPLICABLE;
    }
    
    /**
     * @description Crée les inspections initiales pour les sites nouvellement éligibles
     * @param newSites Liste des nouveaux sites (after insert)
     */
    public static void createInitialInspectionsOnInsert(List<Site__c> newSites) {
        List<Site__c> eligibleSites = new List<Site__c>();
        
        for (Site__c site : newSites) {
            if (isSiteEligible(site)) {
                eligibleSites.add(site);
            }
        }
        
        if (!eligibleSites.isEmpty()) {
            createInitialInspections(eligibleSites);
        }
    }
    
    /**
     * @description Crée les inspections initiales pour les sites réactivés ou avec fréquence activée
     * @param newSites Map des nouveaux sites (after update)
     * @param oldSites Map des anciens sites (before update)
     */
    public static void createInitialInspectionsOnUpdate(Map<Id, Site__c> newSites, Map<Id, Site__c> oldSites) {
        List<Site__c> eligibleSites = new List<Site__c>();
        
        for (Id siteId : newSites.keySet()) {
            Site__c newSite = newSites.get(siteId);
            Site__c oldSite = oldSites.get(siteId);
            
            // Vérifier si le site vient d'être activé
            Boolean justActivated = (newSite.Operating_Site__c == true && oldSite.Operating_Site__c == false);
            
            // Vérifier si la fréquence vient d'être activée
            Boolean frequencyJustActivated = (
                String.isNotBlank(newSite.Inspection_Frequency__c) &&
                newSite.Inspection_Frequency__c != FREQ_NOT_APPLICABLE &&
                (String.isBlank(oldSite.Inspection_Frequency__c) || 
                 oldSite.Inspection_Frequency__c == FREQ_NOT_APPLICABLE)
            );
            
            // Si activation ET éligibilité
            if ((justActivated || frequencyJustActivated) && isSiteEligible(newSite)) {
                eligibleSites.add(newSite);
            }
        }
        
        if (!eligibleSites.isEmpty()) {
            createInitialInspections(eligibleSites);
        }
    }
    
    /**
     * @description Crée les inspections initiales pour une liste de sites
     */
    private static void createInitialInspections(List<Site__c> sites) {
        Set<Id> siteIds = new Set<Id>();
        Map<Id, Date> siteToInitialDate = new Map<Id, Date>();
        
        for (Site__c site : sites) {
            siteIds.add(site.Id);
            // Date initiale = 1er jour du mois de création
            Date initialDate = normalizeToFirstDayOfMonth(site.CreatedDate.date());
            siteToInitialDate.put(site.Id, initialDate);
        }
        
        // Récupérer les inspections existantes pour éviter les doublons
        Map<Id, Set<Date>> existingInspections = getExistingInspectionsBySite(siteIds);
        
        // Créer les inspections initiales
        List<Inspection_Performance__c> inspectionsToInsert = new List<Inspection_Performance__c>();
        
        for (Site__c site : sites) {
            Date initialDate = siteToInitialDate.get(site.Id);
            Set<Date> existingDates = existingInspections.get(site.Id);
            
            // Vérifier qu'il n'existe pas déjà une inspection ce mois-là
            if (existingDates == null || !existingDates.contains(initialDate)) {
                Inspection_Performance__c inspection = new Inspection_Performance__c(
                    Site__c = site.Id,
                    Date__c = initialDate
                );
                inspectionsToInsert.add(inspection);
            }
        }
        
        if (!inspectionsToInsert.isEmpty()) {
            insert inspectionsToInsert;
        }
    }
    
    /**
     * @description Récupère les inspections existantes groupées par site
     * @return Map<SiteId, Set<Date>>
     */
    public static Map<Id, Set<Date>> getExistingInspectionsBySite(Set<Id> siteIds) {
        Map<Id, Set<Date>> result = new Map<Id, Set<Date>>();
        
        for (Inspection_Performance__c inspection : [
            SELECT Site__c, Date__c 
            FROM Inspection_Performance__c 
            WHERE Site__c IN :siteIds
        ]) {
            if (!result.containsKey(inspection.Site__c)) {
                result.put(inspection.Site__c, new Set<Date>());
            }
            result.get(inspection.Site__c).add(inspection.Date__c);
        }
        
        return result;
    }
    
    /**
     * @description Récupère la date d'ancrage pour un site
     * Si inspection existante : date de la plus ancienne
     * Sinon : 1er jour du mois de création
     */
    public static Date getAnchorDate(Site__c site, List<Inspection_Performance__c> existingInspections) {
        if (existingInspections != null && !existingInspections.isEmpty()) {
            // Trier par date croissante et prendre la première
            existingInspections.sort();
            return existingInspections[0].Date__c;
        }
        
        // Pas d'inspection existante : utiliser la date de création
        return normalizeToFirstDayOfMonth(site.CreatedDate.date());
    }
    
    /**
     * @description Génère les inspections récurrentes pour un site jusqu'à une date donnée
     * @param site Le site concerné
     * @param asOfDate Date jusqu'à laquelle générer les inspections
     * @param existingInspections Inspections déjà existantes pour ce site
     * @return Liste des inspections à créer
     */
    public static List<Inspection_Performance__c> generateRecurringInspections(
        Site__c site, 
        Date asOfDate, 
        List<Inspection_Performance__c> existingInspections
    ) {
        List<Inspection_Performance__c> inspectionsToCreate = new List<Inspection_Performance__c>();
        
        // Vérifier l'éligibilité
        if (!isSiteEligible(site)) {
            return inspectionsToCreate;
        }
        
        // Récupérer l'intervalle
        Integer intervalMonths = getFrequencyInterval(site.Inspection_Frequency__c);
        if (intervalMonths == 0) {
            return inspectionsToCreate;
        }
        
        // Déterminer la date d'ancrage
        Date anchorDate = getAnchorDate(site, existingInspections);
        
        // Construire un Set des dates existantes pour éviter les doublons
        Set<Date> existingDates = new Set<Date>();
        if (existingInspections != null) {
            for (Inspection_Performance__c inspection : existingInspections) {
                existingDates.add(inspection.Date__c);
            }
        }
        
        // Générer les inspections récurrentes
        Date currentDate = anchorDate;
        
        while (currentDate <= asOfDate) {
            // Vérifier qu'elle n'existe pas déjà
            if (!existingDates.contains(currentDate)) {
                Inspection_Performance__c inspection = new Inspection_Performance__c(
                    Site__c = site.Id,
                    Date__c = currentDate
                );
                inspectionsToCreate.add(inspection);
            }
            
            // Avancer selon la fréquence
            currentDate = currentDate.addMonths(intervalMonths);
            currentDate = normalizeToFirstDayOfMonth(currentDate);
        }
        
        return inspectionsToCreate;
    }
}