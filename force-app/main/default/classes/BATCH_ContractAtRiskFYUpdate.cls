public without sharing class BATCH_ContractAtRiskFYUpdate implements Database.Batchable<sObject>
{
    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        String query = ContractUtils.buildQueryStringForAtRiskContractsStartOfYear();
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope)
    {
        List<Contract__c> contractsToUpdate = ContractUtils.processAtRiskContractsStartOfYear((List<Contract__c>) scope);
        Boolean success = ContractUtils.updateContracts(contractsToUpdate, null);
    }

    public void finish(Database.BatchableContext BC)
    {

    }
}