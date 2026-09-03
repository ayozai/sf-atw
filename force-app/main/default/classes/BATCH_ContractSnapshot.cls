/**
 * BATCH_ContractSnapshot
 * 
 * Batch class to generate Contract Snapshot records from custom Contracts
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2022-06-15
 * 
 * Changes:
 */
public without sharing class BATCH_ContractSnapshot implements Database.Batchable<sObject>,Database.Stateful
{
    private Integer totalProcessed = 0;
    private List<Id> failedContractIds = new List<Id>();
    private List<String> exceptionRows = new List<String>();

    /**
     * start
     * 
     * Implementation of Batchable method - query for all Contracts with all fields
     */
    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        String query = ContractUtils.buildQueryStringForAtRiskContractsMonthlySnapshot();
        return Database.getQueryLocator(query);
    }

    /**
     * execute
     * 
     * Implementation of Batchable method - map Contracts into Contract Snapshots and insert them
     */
    public void execute(Database.BatchableContext BC, List<sObject> scope)
    {
        // Capture all contract IDs
        Set<Id> contractIdsInScope = new Set<Id>();
        for (sObject contract : scope)
        {
            contractIdsInScope.add(contract.Id);
        }
        try
        {
            // Create all of the new snapshots based on the contracts in scope
            Map<Id, Contract_Snapshot__c> contractSnapshotsToInsertByContractId = ContractUtils.processContractsMonthlySnapshot((List<Contract__c>) scope);
            // Add the IDs of any contracts missing from the snapshot data, to the failed list
            Set<Id> failedIdsThisChunk = new Set<Id>();
            failedIdsThisChunk.addAll(contractIdsInScope);
            failedIdsThisChunk.removeAll(contractSnapshotsToInsertByContractId.keySet());
            failedContractIds.addAll(failedIdsThisChunk);
            // Attempt to insert the snapshots
            List<Contract_Snapshot__c> snapshotsToInsert = contractSnapshotsToInsertByContractId.values();
            List<Database.SaveResult> srs = Database.insert(snapshotsToInsert, false);
            for (Integer index = 0; index < srs.size(); index++)
            {
                Database.SaveResult sr = srs[index];
                if (!sr.isSuccess())
                {
                    // If an individual snapshot insert failed, add to the failed list with the error detail
                    Id contractId = snapshotsToInsert[index].Customer_Contract_ID__c;
                    failedContractIds.add(contractId);
                    exceptionRows.add('Snapshot failed for Contract [' + contractId + ']: ' + sr.getErrors());
                }
            }
        }
        catch (Exception e)
        {
            // If there is an unexpected error, treat all contracts in scope as failed and add capture the erroe detail
            failedContractIds.addAll(contractIdsInScope);
            exceptionRows.add('Chunk failed with thrown exception: ' + e.getMessage());
        }
        finally
        {
            totalProcessed += scope.size();
        }
    }

    /**
     * finish
     * 
     * Implementation of Batchable method - error handling via email if necessary
     */
    public void finish(Database.BatchableContext BC)
    {
        if (failedContractIds.size() > 0 || exceptionRows.size() > 0)
        {
            // Take the recipients from the setting
            Contract_Snapshot_Settings__c settings = Contract_Snapshot_Settings__c.getInstance();
            List<String> toAddresses = settings.Error_Email_Recipients__c.split(',');
            // Build an email message
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(toAddresses);
            email.setSubject('Atalian Contract Snapshot Job Completed - with some errors');
            String body = 'Records processed: ' + totalProcessed;
            body += '\r\nTotal number of failed records: ' + failedContractIds.size();
            body += '\r\n\r\nError details:';
            for (String errorRow : exceptionRows)
            {
                body += '\r\n' + errorRow;
            }
            email.setPlainTextBody(body);
            emails.add(email);
            // Only send outside test context
            if (!Test.isRunningTest())
            {
                Messaging.sendEmail(emails);
            }
        }
    }
}