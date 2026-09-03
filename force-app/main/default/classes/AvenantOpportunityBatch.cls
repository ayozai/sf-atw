/**
 * AvenantOpportunityBatch
 *
 * Version asynchrone (par lots) de AvenantOpportunityCreator, pour traiter des
 * contrats cadres comportant de nombreux contrats liés sans dépasser la limite CPU.
 *
 * Chaque lot (batchSize contrats) est traité dans sa propre transaction via
 * AvenantOpportunityCreator.processChildContracts — mapping, exclusion des contrats
 * expirés et bascule Closed Won sont donc strictement identiques au mode synchrone.
 *
 * La classe est Stateful : elle cumule les compteurs (créés / ignorés / erreurs)
 * sur tous les lots, et envoie un récapitulatif par email au lanceur dans finish().
 *
 * Lancement (Apex anonyme) :
 *   // 3 mois d'extension, 15 contrats par lot :
 *   AvenantOpportunityBatch.run('a0j4G00000ebpTjQAI', 3, 15);
 */
public with sharing class AvenantOpportunityBatch
    implements Database.Batchable<SObject>, Database.Stateful
{
    private final Id frameworkContractId;
    private final Integer extensionMonths;

    // État cumulé sur tous les lots
    private Integer createdCount = 0;
    private List<String> skipped = new List<String>();
    private List<String> errors = new List<String>();

    /** Taille de lot par défaut (conservatrice au vu du poids des flows de clôture). */
    public static final Integer DEFAULT_BATCH_SIZE = 15;

    public AvenantOpportunityBatch(Id frameworkContractId, Integer extensionMonths)
    {
        this.frameworkContractId = frameworkContractId;
        this.extensionMonths = extensionMonths;
    }

    /**
     * Valide le contrat cadre (de façon synchrone, pour remonter l'erreur tout de
     * suite) puis lance le batch. Retourne l'Id du job Apex.
     *
     * @param frameworkContractId Id du contrat cadre
     * @param extensionMonths     Mois d'extension (null/0 = pas d'extension)
     * @param batchSize           Taille de lot (null => DEFAULT_BATCH_SIZE)
     */
    public static Id run(Id frameworkContractId, Integer extensionMonths, Integer batchSize)
    {
        if (frameworkContractId == null)
        {
            throw new AvenantOpportunityCreator.AvenantException(
                'L\'Id du contrat cadre est obligatoire.');
        }
        AvenantOpportunityCreator.assertIsFramework(frameworkContractId);
        Integer size = (batchSize != null && batchSize > 0) ? batchSize : DEFAULT_BATCH_SIZE;
        return Database.executeBatch(
            new AvenantOpportunityBatch(frameworkContractId, extensionMonths), size);
    }

    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        return Database.getQueryLocator(
            AvenantOpportunityCreator.childContractQuery(frameworkContractId));
    }

    public void execute(Database.BatchableContext bc, List<Contract__c> scope)
    {
        try
        {
            AvenantOpportunityCreator.Outcome o =
                AvenantOpportunityCreator.processChildContracts(scope, extensionMonths);
            createdCount += o.created.size();
            skipped.addAll(o.skipped);
            errors.addAll(o.errors);
        }
        catch (Exception e)
        {
            // Un lot en échec ne doit pas arrêter les autres.
            errors.add('Lot en échec : ' + e.getMessage());
        }
    }

    public void finish(Database.BatchableContext bc)
    {
        String body =
            'Création des avenants terminée pour le contrat cadre ' + frameworkContractId + '.\n\n'
            + 'Avenants créés (Closed Won) : ' + createdCount + '\n'
            + 'Contrats ignorés            : ' + skipped.size() + '\n'
            + 'Erreurs                     : ' + errors.size() + '\n';
        if (!skipped.isEmpty())
        {
            body += '\n--- Ignorés ---\n - ' + String.join(skipped, '\n - ');
        }
        if (!errors.isEmpty())
        {
            body += '\n\n--- Erreurs ---\n - ' + String.join(errors, '\n - ');
        }

        System.debug(body);
        sendSummaryEmail(body);
    }

    /** Envoi best-effort du récapitulatif au lanceur (silencieux si l'email est indisponible). */
    private void sendSummaryEmail(String body)
    {
        try
        {
            String toAddress = UserInfo.getUserEmail();
            if (String.isBlank(toAddress)) { return; }
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toAddress });
            mail.setSubject('Avenants créés — contrat cadre ' + frameworkContractId);
            mail.setPlainTextBody(body);
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        }
        catch (Exception e)
        {
            System.debug('Récapitulatif email non envoyé : ' + e.getMessage());
        }
    }
}