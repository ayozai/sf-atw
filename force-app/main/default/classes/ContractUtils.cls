/**
 * ContractUtils
 * 
 * Utility class for automation around the custom Contract object
 * 
 * Author : Bernard Price (Brightgen)
 * Created: 2021-12-20
 * 
 * Changes:
 *          2022-06-15 BJP Added monthly snapshot methods
 */
public inherited sharing class ContractUtils 
{
    private static Set<String> customLookupsOnContract = new Set<String>();

    /**
     * buildQueryStringForAtRiskContractsStartOfYear
     * 
     * Query for all Contract__c records that have been flagged as "at risk" in this FY
     */
    public static String buildQueryStringForAtRiskContractsStartOfYear()
    {
        String queryString = 'SELECT Id,At_Risk_This_FY__c,At_Risk_Start_of_Year_Date__c,Contract_Start_Date__c,Contract_End_Date__c,Status__c ';
        queryString += 'FROM Contract__c ';
        queryString += +'WHERE Contract_End_Date__c = THIS_YEAR ';
        queryString += +'AND At_Risk_This_FY__c = true ';
        queryString += +'ORDER BY Account__c';
        return queryString;
    }

    /**
     * buildQueryStringForAtRiskContractsMonthlySnapshot
     * 
     * Query for all Contract__c records except those that ended before the start of last year
     */
    public static String buildQueryStringForAtRiskContractsMonthlySnapshot()
    {
        String queryString = 'SELECT  ';
        queryString += String.Join(new List<String>(getAllFieldsForContractSOQL(true)), ',');
        queryString += ' FROM Contract__c';
        queryString += +' WHERE Contract_End_Date__c >= LAST_YEAR';
        queryString += +' ORDER BY Account__c';
        return queryString;
    }

    /**
     * processAtRiskContractsStartOfYear
     * 
     * Flag all the Contract__c records provided as "at risk" using the start date of the current year
     */
    public static List<Contract__c> processAtRiskContractsStartOfYear(List<Contract__c> contracts)
    {
        Date startOfYear = Date.newInstance(Date.Today().year(), 1, 1);
        List<Contract__c> contractsToUpdate = new List<Contract__c>();
        for (Contract__c contract : contracts)
        {
            if (contract.At_Risk_This_FY__c && contract.At_Risk_Start_of_Year_Date__c != startOfYear)
            {
                contract.At_Risk_Start_of_Year_Date__c = startOfYear;
                contractsToUpdate.add(contract);
            }
        }
        return contractsToUpdate;
    }

    /**
     * updateContracts
     * 
     * Attempt to a perform DML update on the Contract__c records provided, and handle any errors
     */
    public static Boolean updateContracts(List<Contract__c> contracts, Map<Id, SObject> triggerRecordsByContractId)
    {
        Boolean success = true;
        List<Database.SaveResult> srs = Database.update(contracts, false);
        Integer index = 0;
        for (Database.SaveResult sr : srs)
        {
            if (!sr.isSuccess())
            {
                if (triggerRecordsByContractId != null)
                {
                    // Only add errors to the record if in trigger context
                    SObject triggerRecord = triggerRecordsByContractId.get(contracts[index].Id);
                    if (triggerRecord != null)
                    {
                        triggerRecord.addError('' + sr.getErrors());
                    }
                }
                success = false;
            }
            index++;
        }
        return success;
    }

    /**
     * processContractsMonthlySnapshot
     * 
     * Generate Contract_Snapshot__c records based on the Contract__c records provided
     */
    public static Map<Id, Contract_Snapshot__c> processContractsMonthlySnapshot(List<Contract__c> contracts)
    {
        Map<Id, Contract_Snapshot__c> snapshotsToInsertByContractId = new Map<Id, Contract_Snapshot__c>();
        // Get all of the relevant fields and map them between the objects
        Set<String> fieldApiNames = getAllFieldsForContractSOQL(false);
        Map<String, String> snapshotFieldsByContractField = getFieldMappingsForContractSnapshots(fieldApiNames);
        for (Contract__c contract : contracts)
        {
            // Create a new snapshot for each contract
            Contract_Snapshot__c snapshot = new Contract_Snapshot__c();
            snapshot.Snapshot_Date__c = Date.Today();
            // Dynamicaly map all field values where a match is found
            for (String fieldApiName : fieldApiNames)
            {
                String targetFieldApiName = snapshotFieldsByContractField.get(fieldApiName);
                if (targetFieldApiName != null)
                {
                    snapshot.put(targetFieldApiName, getValue(contract, fieldApiName));
                }
            }
            System.Debug(LoggingLevel.ERROR, '### Snapshot to Insert: '+snapshot);
            snapshotsToInsertByContractId.put(contract.Id, snapshot);
        }
        return snapshotsToInsertByContractId;
    }

    /**
     * getFieldMappingsForContractSnapshots
     * 
     * Map from the Contract__c field names provided, to fields on Contract_Snapshot__c
     */
    private static Map<String, String> getFieldMappingsForContractSnapshots(Set<String> fieldApiNames)
    {
        Map<String, String> snapshotFieldsByContractField = new Map<String, String>();
        // Get all fields for the target object
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Contract_Snapshot__c');
        Map<String, Schema.SObjectField> snapshotFieldMap = targetType.getDescribe().fields.getMap();
        for (String fieldApiName : fieldApiNames)
        {
            // Add anything that matches to the map
            String targetFieldApiName = getSnapshotFieldApiName(fieldApiName, snapshotFieldMap);
            if (targetFieldApiName != null)
            {
                snapshotFieldsByContractField.put(fieldApiName, targetFieldApiName);
            }
        }
        return snapshotFieldsByContractField;
    }

    /**
     * getSnapshotFieldApiName
     * 
     * Attempt to find a matching field on the target snapshot object, for the contract field provided
     */
    private static String getSnapshotFieldApiName(String contractFieldApiName, Map<String, Schema.SObjectField> snapshotFieldMap)
    {
        String expectedSnapshotFieldApiName = contractFieldApiName;
        // Some special cases - shift original record ID into another field
        if (expectedSnapshotFieldApiName == 'Id')
        {
            expectedSnapshotFieldApiName = 'Customer_Contract_ID__c';
        }
        // Ignore the original contract currency, we want to create these in the corporate currency (running user, expected to be EUR)
        else if (expectedSnapshotFieldApiName == 'CurrencyIsoCode')
        {
            expectedSnapshotFieldApiName = null;
        }
        // Expect standard and custom lookups to be in the form e.g. Account_ID__c
        else if (expectedSnapshotFieldApiName.endsWith('Id'))
        {
            expectedSnapshotFieldApiName = expectedSnapshotFieldApiName.replaceAll('Id$', '_ID__c');
        }
        else if (customLookupsOnContract.contains(expectedSnapshotFieldApiName))
        {
            expectedSnapshotFieldApiName = expectedSnapshotFieldApiName.replaceAll('__c', '_ID__c');
        }  
        // Cope with cross-objects references like Owner.Name, expect the target field to be in the form e.g. Owner_Name__c
        else if (expectedSnapshotFieldApiName.contains('.'))
        {
            List<String> fieldPathParts = expectedSnapshotFieldApiName.split('\\.');
            String parentObjectName = fieldPathParts[0];
            parentObjectName = parentObjectName.replace('__r', '');
            String fieldName = fieldPathParts[fieldPathParts.size() - 1];
            expectedSnapshotFieldApiName = parentObjectName + '_' + fieldName;
            if (!expectedSnapshotFieldApiName.endsWith('__c'))
            {
                expectedSnapshotFieldApiName += '__c';
            }
        }
        if (snapshotFieldMap.containsKey(expectedSnapshotFieldApiName))
        {
            Schema.DescribeFieldResult describe = snapshotFieldMap.get(expectedSnapshotFieldApiName).getDescribe();
            // Skip the field if it not writeable on the target object e.g. formula or system field
            if (describe.isUpdateable())
            {
                return describe.getName();
            }
        }
        else
        {
            // If not found that value will just not be mapped, record will be created with as many fields populated as possible
            System.Debug(LoggingLevel.Error, '### Could not resolve target field on Contract_Snapshot__c for: '+expectedSnapshotFieldApiName);
        }
        return null;
    }

    /**
     * getAllFieldsForContractSOQL
     * 
     * Returns a full list of field API names for the Contract__c object, including cross-object names
     * and converted currency values if applicable
     */
    private static Set<String> getAllFieldsForContractSOQL(Boolean convertCurrencyFields)
    {
        Set<String> apiNames = new Set<String>();
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Contract__c');
        Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
        for (Schema.SObjectField field : fieldMap.values()) 
        {
            String apiName = field.getDescribe().getName();
            // Add the conversion function so that we get the EUR values from the query regardless of the original contract currency
            if (convertCurrencyFields && (field.getDescribe().getType() == DisplayType.Currency))
            {
                apiName = 'convertCurrency(' + apiName + ')';
            }
            apiNames.add(apiName);
            // If the field is a lookup add an additional "field" to the set for the name of the parent
            if (field.getDescribe().getReferenceTo() != null && !field.getDescribe().getReferenceTo().isEmpty())
            {
                String parentNameApiName = apiName.replace('__c', '__r').replaceAll('Id$', '') + '.Name';
                apiNames.add(parentNameApiName);
                customLookupsOnContract.add(apiName);
            }
        }
        return apiNames;
    }

    /**
     * getValue
     * 
     * Returns the value stored in the record based on the path
     */
    private static Object getValue(SObject obj, String fieldPath)
    {
        String stringVal = '';
        Object fieldValue = null;
        SObject fieldObj = obj;
        String fieldName = fieldPath;
        if (fieldName.contains('.'))
        {
            // Traverse across relationships...
            List<String> fieldPathParts = fieldName.split('\\.');
            fieldName = fieldPathParts[fieldPathParts.size() - 1];
            for (Integer i = 0; i < fieldPathParts.size() - 1; i++)
            {
                if (fieldObj == null)
                {
                    // Cope with i.e. non-mandatory lookup
                    continue;
                }
                String parentObjName = fieldPathParts[i];
                parentObjName.replace('__r', '__c');
                fieldObj = fieldObj.getSObject(parentObjName);
            }
        }
        if (fieldObj != null)
        {
            // ...in order to do dynamic get on correct object
            fieldValue = fieldObj.get(fieldName);
        }
        return fieldValue;
    }
}