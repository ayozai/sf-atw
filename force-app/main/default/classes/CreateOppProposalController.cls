/* Controller class used to return the server side values that LWC can't retrieve on it's own
 *
 * Author:  Simon Kaya
 * Date:    22/02/2022
 */
public without sharing class CreateOppProposalController
{
    private static final String TEMPLATE_QUERY = 'SELECT {0} FROM Opportunity WHERE Id = :recordId';

    @AuraEnabled(cacheable=true)
    public static Proposal_Studio_Settings__c GetProposalStudioSettings()
    {
        return Proposal_Studio_Settings__c.getInstance();
    }

    @AuraEnabled
    public static Opportunity GetOpportunity(String recordId, List<String> fields)
    {
        String query = String.format(TEMPLATE_QUERY, new List<String>{String.join(fields, ',')});
        try {
            return Database.query(query);
        } catch (QueryException e) {
            throw buildException('Opportunity not found for Id: ' + recordId);
        }
    }

    @AuraEnabled
    public static List<Map<String, Object>> GetGroupOptions()
    {
        Proposal_Studio_Settings__c settings = Proposal_Studio_Settings__c.getInstance();
        String accessToken = callLogin(settings);
        List<Object> units = callGetAllUnits(settings, accessToken);

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Object unit : units) {
            Map<String, Object> unitMap = (Map<String, Object>) unit;
            result.add(new Map<String, Object>{
                'unitId'       => unitMap.get('unitId'),
                'name'         => unitMap.get('name'),
                'parentUnitId' => unitMap.get('parentUnitId')
            });
        }
        return result;
    }

    @AuraEnabled
    public static String CreateProposalFolder(String unitId, String oppId, String oppName, String accountName)
    {
        Proposal_Studio_Settings__c settings = Proposal_Studio_Settings__c.getInstance();
        String accessToken    = callLogin(settings);
        String parentFolderId = callGetParentFolder(settings, accessToken, unitId);
        return callCreateFolder(settings, accessToken, parentFolderId, oppId, oppName, accountName);
    }

    private static AuraHandledException buildException(String message)
    {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    private static String callLogin(Proposal_Studio_Settings__c settings)
    {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.Base_Url__c + '/login');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('x-api-key', settings.API_Key__c);
        req.setBody(JSON.serialize(new Map<String, String>{
            'username' => settings.Username__c,
            'password' => settings.Password__c
        }));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw buildException('Login failed (' + res.getStatusCode() + '): ' + res.getBody());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken = (String) body.get('accessToken');
        if (String.isBlank(accessToken)) {
            throw buildException('Login did not return an accessToken');
        }
        return accessToken;
    }

    private static List<Object> callGetAllUnits(Proposal_Studio_Settings__c settings, String accessToken)
    {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.Base_Url__c + '/organization/unit');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', settings.API_Key__c);
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw buildException('Get units failed (' + res.getStatusCode() + '): ' + res.getBody());
        }

        Object parsed = JSON.deserializeUntyped(res.getBody());
        if (parsed instanceof List<Object>) {
            return (List<Object>) parsed;
        }
        Map<String, Object> bodyMap = (Map<String, Object>) parsed;
        if (bodyMap.containsKey('items')) return (List<Object>) bodyMap.get('items');
        if (bodyMap.containsKey('data'))  return (List<Object>) bodyMap.get('data');
        throw buildException('Units response is not an array');
    }

    private static String callGetParentFolder(Proposal_Studio_Settings__c settings, String accessToken, String unitId)
    {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.Base_Url__c + '/organization/folder?unitId=' + unitId);
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', settings.API_Key__c);
        req.setHeader('Authorization', 'Bearer ' + accessToken);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw buildException('Get parent folder failed (' + res.getStatusCode() + '): ' + res.getBody());
        }

        List<Object> folders = (List<Object>) JSON.deserializeUntyped(res.getBody());
        if (folders.isEmpty()) {
            throw buildException('No parent folder found for unitId: ' + unitId);
        }
        String parentFolderId = (String) ((Map<String, Object>) folders[0]).get('folderId');
        if (String.isBlank(parentFolderId)) {
            throw buildException('Parent folder response missing folderId');
        }
        return parentFolderId;
    }

    private static String callCreateFolder(Proposal_Studio_Settings__c settings, String accessToken, String parentFolderId, String oppId, String oppName, String accountName)
    {
        Map<String, Object> body = new Map<String, Object>{
            'parentFolderId' => parentFolderId,
            'name'           => oppName,
            'mergeFields'    => new List<Object>{
                new Map<String, String>{'name' => '{{opportunity}{id}}', 'type' => 'text', 'value' => oppId},
                new Map<String, String>{'name' => '{{company}{name}}',   'type' => 'text', 'value' => accountName}
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(settings.Base_Url__c + '/organization/folder');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('x-api-key', settings.API_Key__c);
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (result.containsKey('error')) {
            throw buildException((String) result.get('error') + ' ' + result.get('message'));
        }

        String folderId = (String) result.get('folderId');
        if (String.isBlank(folderId)) {
            throw buildException('Create folder response missing folderId. Response: ' + res.getBody());
        }
        return folderId;
    }
}