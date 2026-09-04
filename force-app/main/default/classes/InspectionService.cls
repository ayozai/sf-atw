/**
 * @description Service centralisé pour la gestion des inspections
 * Version 4.3 — Fix ancre generateYearlyInspections (isUpdate)
 */
public with sharing class InspectionService {

    private static final String FREQ_MONTHLY        = 'Every month';
    private static final String FREQ_NOT_APPLICABLE = 'Not applicable';
    private static final String INSP_ACTIVE         = 'Active';

    private static final Map<String, List<Integer>> FIXED_CYCLES = new Map<String, List<Integer>>{
        'Every month'    => new List<Integer>{1,2,3,4,5,6,7,8,9,10,11,12},
        'Every 2 months' => new List<Integer>{1,3,5,7,9,11},
        'Every 3 months' => new List<Integer>{1,4,7,10},
        'Every 4 months' => new List<Integer>{1,5,9},
        'Every 6 months' => new List<Integer>{1,7},
        'Every year'     => new List<Integer>{1}
    };

    // ─────────────────────────────────────────────
    // Méthodes publiques utilitaires
    // ─────────────────────────────────────────────

    public static Integer getFrequencyInterval(String frequency) {
        if (String.isBlank(frequency)) return 0;
        switch on frequency {
            when 'Every month'    { return 1; }
            when 'Every 2 months' { return 2; }
            when 'Every 3 months' { return 3; }
            when 'Every 4 months' { return 4; }
            when 'Every 6 months' { return 6; }
            when 'Every year'     { return 12; }
            when else             { return 0; }
        }
    }

    public static Date normalizeToFirstDayOfMonth(Date inputDate) {
        if (inputDate == null) return null;
        return Date.newInstance(inputDate.year(), inputDate.month(), 1);
    }

    public static Date firstDayOfNextMonth(Date inputDate) {
        if (inputDate == null) return null;
        Date nextMonth = inputDate.addMonths(1);
        return Date.newInstance(nextMonth.year(), nextMonth.month(), 1);
    }

    public static Date endOfCurrentYear() {
        return Date.newInstance(Date.today().year(), 12, 31);
    }

    /**
     * @description Retourne la date fixe du cycle pour une date déclencheur donnée.
     * Every month     : mois suivant
     * Every 6 months  : semestre courant (Jan–Jun → Jan, Jul–Dec → Jul)
     * Autres          : premier mois fixe strictement > mois déclencheur
     */
    public static Date getNextFixedMonth(Date triggerDate, String frequency) {
        if (triggerDate == null || String.isBlank(frequency)) return null;

        Integer triggerMonth = triggerDate.month();
        Integer triggerYear  = triggerDate.year();

        if (frequency == FREQ_MONTHLY) return firstDayOfNextMonth(triggerDate);

        if (frequency == 'Every 6 months') {
            return triggerMonth <= 6
                ? Date.newInstance(triggerYear, 1, 1)
                : Date.newInstance(triggerYear, 7, 1);
        }

        List<Integer> cycle = FIXED_CYCLES.get(frequency);
        if (cycle == null) return null;

        for (Integer fixedMonth : cycle) {
            if (fixedMonth > triggerMonth) return Date.newInstance(triggerYear, fixedMonth, 1);
        }
        return Date.newInstance(triggerYear + 1, cycle[0], 1);
    }

    public static Boolean isActiveFrequency(String frequency) {
        return String.isNotBlank(frequency) && frequency != FREQ_NOT_APPLICABLE;
    }

    public static Boolean isSiteEligible(Site__c site) {
        return site.Operating_Site__c == true
            && site.Inspection_Enabled__c == INSP_ACTIVE
            && isActiveFrequency(site.Inspection_Frequency__c);
    }

    public static String buildUniqueKey(Id siteId, Date d) {
        return String.valueOf(siteId) + '_' + toMonthKey(d);
    }

    // ─────────────────────────────────────────────
    // Trigger : After Insert
    // ─────────────────────────────────────────────

    public static void createInitialInspectionsOnInsert(List<Site__c> newSites) {
        List<Site__c> eligibleSites = new List<Site__c>();
        for (Site__c site : newSites) {
            if (isSiteEligible(site)) eligibleSites.add(site);
        }
        if (!eligibleSites.isEmpty()) generateYearlyInspections(eligibleSites, false);
    }

    // ─────────────────────────────────────────────
    // Trigger : After Update
    // ─────────────────────────────────────────────

    /**
     * @description Gère les 4 cas de mise à jour :
     *   1. Désactivation → supprime les futures
     *   2. Réactivation / activation → génère depuis Today
     *   3. Activation fréquence (N/A→active) → génère depuis Today
     *   4. Changement fréquence active→active → supprime futures + régénère depuis Today
     */
    public static void handleAfterUpdate(Map<Id, Site__c> newSites, Map<Id, Site__c> oldSites) {
        List<Site__c> toGenerate      = new List<Site__c>();
        List<Site__c> toRegenerate    = new List<Site__c>();
        List<Id>      toDeleteFutures = new List<Id>();

        for (Id siteId : newSites.keySet()) {
            Site__c n = newSites.get(siteId);
            Site__c o = oldSites.get(siteId);

            Boolean isNowEligible = isSiteEligible(n);

            // ── Désactivation ──────────────────────────────────────────────
            Boolean justDeactivatedOperating = (o.Operating_Site__c == true  && n.Operating_Site__c == false);
            Boolean justDeactivatedEnabled   = (o.Inspection_Enabled__c == INSP_ACTIVE && n.Inspection_Enabled__c != INSP_ACTIVE);

            if (justDeactivatedOperating || justDeactivatedEnabled) {
                toDeleteFutures.add(siteId);
                continue;
            }

            // ── Réactivation / activation ──────────────────────────────────
            Boolean justActivatedOperating = (o.Operating_Site__c == false && n.Operating_Site__c == true);
            Boolean justActivatedEnabled   = (o.Inspection_Enabled__c != INSP_ACTIVE && n.Inspection_Enabled__c == INSP_ACTIVE);
            Boolean frequencyJustActivated = (
                !isActiveFrequency(o.Inspection_Frequency__c) &&
                isActiveFrequency(n.Inspection_Frequency__c)
            );

            if ((justActivatedOperating || justActivatedEnabled || frequencyJustActivated) && isNowEligible) {
                toGenerate.add(n);
                continue;
            }

            // ── Changement fréquence active → active différente ────────────
            Boolean freqChanged = (
                isActiveFrequency(o.Inspection_Frequency__c) &&
                isActiveFrequency(n.Inspection_Frequency__c) &&
                o.Inspection_Frequency__c != n.Inspection_Frequency__c &&
                isNowEligible
            );

            if (freqChanged) toRegenerate.add(n);
        }

        if (!toDeleteFutures.isEmpty()) deleteFutureInspections(toDeleteFutures);

        // FIX v4.3 : isUpdate = true → ancre depuis Today pour tous les cas after update
        if (!toGenerate.isEmpty())   generateYearlyInspections(toGenerate,   true);
        if (!toRegenerate.isEmpty()) {
            List<Id> regenIds = new List<Id>();
            for (Site__c s : toRegenerate) regenIds.add(s.Id);
            deleteFutureInspections(regenIds);
            generateYearlyInspections(toRegenerate, true);
        }
    }

    // ─────────────────────────────────────────────
    // Génération annuelle en masse
    // ─────────────────────────────────────────────

    /**
     * @description Génère toutes les inspections manquantes jusqu'au 31/12 de l'année courante.
     *
     * @param isUpdate  false = insert   → ancre depuis CreatedDate du site
     *                  true  = update   → ancre depuis Date.today()
     *                                     (réactivation, changement fréquence)
     *
     * FIX v4.3 : le paramètre isUpdate corrige le bug où une réactivation
     * d'un site ancien remontait à sa date de création au lieu de partir de Today.
     */
    public static void generateYearlyInspections(List<Site__c> sites, Boolean isUpdate) {
        if (sites == null || sites.isEmpty()) return;

        Set<Id> siteIds = new Set<Id>();
        for (Site__c s : sites) siteIds.add(s.Id);

        Map<Id, Set<String>> coveredMonths = getExistingMonthKeysBySite(siteIds);
        Date asOfDate = endOfCurrentYear();
        List<Inspection_Performance__c> toInsert = new List<Inspection_Performance__c>();

        for (Site__c site : sites) {
            if (!isSiteEligible(site)) continue;

            // FIX v4.3 : référence temporelle selon le contexte
            Date refDate    = isUpdate ? Date.today() : site.CreatedDate.date();
            Date anchorDate = getNextFixedMonth(refDate, site.Inspection_Frequency__c);
            if (anchorDate == null) continue;

            Set<String> covered = coveredMonths.containsKey(site.Id)
                ? coveredMonths.get(site.Id)
                : new Set<String>();

            toInsert.addAll(buildInspectionsFromAnchor(
                site.Id, site.Inspection_Frequency__c, anchorDate, asOfDate, covered));
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }

    /**
     * @description Génère les inspections d'un site depuis l'ancre jusqu'à asOfDate
     * Utilisé par le batch — ancre toujours depuis CreatedDate
     */
    public static List<Inspection_Performance__c> generateRecurringInspections(
        Site__c site, Date asOfDate, List<Inspection_Performance__c> existingInspections) {

        List<Inspection_Performance__c> toCreate = new List<Inspection_Performance__c>();
        if (!isSiteEligible(site)) return toCreate;

        String frequency = site.Inspection_Frequency__c;
        List<Integer> cycle = FIXED_CYCLES.get(frequency);
        if (cycle == null || cycle.isEmpty()) return toCreate;

        // Batch : ancre toujours depuis CreatedDate (rattrapage historique)
        Date anchorDate = getNextFixedMonth(site.CreatedDate.date(), frequency);
        if (anchorDate == null) return toCreate;

        Set<String> coveredMonths = new Set<String>();
        if (existingInspections != null) {
            for (Inspection_Performance__c ip : existingInspections) {
                coveredMonths.add(toMonthKey(ip.Date__c));
            }
        }

        return buildInspectionsFromAnchor(site.Id, frequency, anchorDate, asOfDate, coveredMonths);
    }

    // ─────────────────────────────────────────────
    // Suppression des inspections futures
    // ─────────────────────────────────────────────

    public static void deleteFutureInspections(List<Id> siteIds) {
        if (siteIds == null || siteIds.isEmpty()) return;
        List<Inspection_Performance__c> futures = [
            SELECT Id FROM Inspection_Performance__c
            WHERE Site__c IN :siteIds
              AND Date__c > :Date.today()
        ];
        if (!futures.isEmpty()) delete futures;
    }

    // ─────────────────────────────────────────────
    // Helpers privés
    // ─────────────────────────────────────────────

    private static List<Inspection_Performance__c> buildInspectionsFromAnchor(
        Id siteId, String frequency, Date anchorDate, Date asOfDate, Set<String> coveredMonths) {

        List<Inspection_Performance__c> toCreate = new List<Inspection_Performance__c>();
        List<Integer> cycle = FIXED_CYCLES.get(frequency);
        if (cycle == null) return toCreate;

        if (frequency == FREQ_MONTHLY) {
            Date current = anchorDate;
            while (current <= asOfDate) {
                String key = toMonthKey(current);
                if (!coveredMonths.contains(key)) {
                    toCreate.add(buildRecord(siteId, current));
                    coveredMonths.add(key);
                }
                current = firstDayOfNextMonth(current);
            }
            return toCreate;
        }

        for (Integer year = anchorDate.year(); year <= asOfDate.year(); year++) {
            for (Integer fixedMonth : cycle) {
                Date candidate = Date.newInstance(year, fixedMonth, 1);
                if (candidate < anchorDate) continue;
                if (candidate > asOfDate)  break;
                String key = toMonthKey(candidate);
                if (!coveredMonths.contains(key)) {
                    toCreate.add(buildRecord(siteId, candidate));
                    coveredMonths.add(key);
                }
            }
        }
        return toCreate;
    }

    private static Boolean isSiteEligibleStatic(Site__c site) {
        return site.Operating_Site__c == true
            && site.Inspection_Enabled__c == INSP_ACTIVE
            && isActiveFrequency(site.Inspection_Frequency__c);
    }

    private static Inspection_Performance__c buildRecord(Id siteId, Date d) {
        return new Inspection_Performance__c(
            Site__c         = siteId,
            Date__c         = d,
            Unique_Key__c = buildUniqueKey(siteId, d)
        );
    }

    public static Map<Id, Set<String>> getExistingMonthKeysBySite(Set<Id> siteIds) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (Inspection_Performance__c ip : [
            SELECT Site__c, Date__c FROM Inspection_Performance__c WHERE Site__c IN :siteIds
        ]) {
            if (!result.containsKey(ip.Site__c)) result.put(ip.Site__c, new Set<String>());
            result.get(ip.Site__c).add(toMonthKey(ip.Date__c));
        }
        return result;
    }

    public static Map<Id, Set<Date>> getExistingInspectionsBySite(Set<Id> siteIds) {
        Map<Id, Set<Date>> result = new Map<Id, Set<Date>>();
        for (Inspection_Performance__c ip : [
            SELECT Site__c, Date__c FROM Inspection_Performance__c WHERE Site__c IN :siteIds
        ]) {
            if (!result.containsKey(ip.Site__c)) result.put(ip.Site__c, new Set<Date>());
            result.get(ip.Site__c).add(ip.Date__c);
        }
        return result;
    }

    public static String toMonthKey(Date d) {
        return String.valueOf(d.year()) + '-' + String.valueOf(d.month()).leftPad(2, '0');
    }
}