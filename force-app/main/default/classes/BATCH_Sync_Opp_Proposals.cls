/* Batch class used to make callouts to PS111 and sync opportunity proposals 
 * to an opportunity.
 * 
 * Class is marked as without sharing to ensure that all opportunities can be referenced and 
 * synced. This class does not look to update any opportunity values but associated 
 * and update proposals for an opportunity.
 * 
 * Author:  Simon Kaya
 * Date:    07/04/2021
 * 
 * MA: createProposalFromProposalResponse - custom Name__c field created, populated instead of the standard Name field
 */
public without sharing class BATCH_Sync_Opp_Proposals implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful
{
    //HTTP constants
    private final String HTTP_HEADER_ACCEPT = 'Accept';
    private final String HTTP_HEADER_API_KEY = 'x-api-key';
    private final String HTTP_HEADER_CONTENT_TYPE = 'Content-Type';
    private final String HTTP_AUTHORIZATION = 'Authorization';
    private final String HTTP_ACCESS_TOKEN = 'accessToken';
    private final String HTTP_APPLICATION_JSON = 'application/json';
    private final String HTTP_POST = 'POST';
    private final String HTTP_GET = 'GET';

    private final String QUERY = 'SELECT Id, PS111_Folder_ID__c FROM Opportunity WHERE PS111_Folder_ID__c != NULL';

    @TestVisible
    private Proposal_Studio_Settings__c settings;

    public BATCH_Sync_Opp_Proposals()
    {
        this.settings = Proposal_Studio_Settings__c.getInstance();
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC)
    {
        return Database.getQueryLocator(this.QUERY);
    }
    
    public void execute(Database.BatchableContext BC, List<Opportunity> scope)
    {
        //Get the access token here each iteration to ensure this doesn't expire.
        String accessToken = Test.isRunningTest() ? null : loginAndGetAccessToken();
        Map<String, List<RES_All_Proposals.Proposal>> proposalsByFolderId = getProposalsByFolderId(accessToken);

        //Map Opportunities by folderId
        Map<String, Id> oppIdsByFolderId = getOpportunityIdsByFolderId(scope);

        //Safegaurd and ensure that we don't get dupes in the same record to insert
        Map<String, Proposal__c> proposalsToUpsert = new Map<String, Proposal__c>();
        for(Opportunity opp : scope)
        {   
            String folderId = opp.PS111_Folder_Id__c;
            if(proposalsByFolderId.containsKey(folderId))
            {
                for(RES_All_Proposals.Proposal proposalRes : proposalsByFolderId.get(folderId))
                {
                    Proposal__c proposal = createProposalFromProposalResponse(oppIdsByFolderId, proposalRes);
                    proposalsToUpsert.put(proposal.Proposal_Id__c, proposal);
                }
            }
        }

        upsert proposalsToUpsert.values() Proposal_Id__c;
    }

    @TestVisible 
    private Map<String, Id> getOpportunityIdsByFolderId(List<Opportunity> scope)
    {
        Map<String, Id> oppIdsByFolderId = new Map<String, Id>();
        for(Opportunity opp : scope)
        {
            oppIdsByFolderId.put(opp.PS111_Folder_ID__c, opp.Id);
        }

        return oppIdsByFolderId;
    }

    /* Method that converts a proposal response into a Proposal__c object record we can commit
     * to the database. */
    @TestVisible
    private Proposal__c createProposalFromProposalResponse(Map<String, Id> oppIdsByFolderId, RES_All_Proposals.Proposal proposalRespone)
    {
        String folderId = proposalRespone.folderId;
        return new Proposal__c(
            Description__c = proposalRespone.description,
            Is_Draft__c = proposalRespone.draft,
            Master_Template__c = proposalRespone.masterName,
            Name__c = proposalRespone.name,
            Opportunity__c = oppIdsByFolderId.get(folderId),
            Proposal_Id__c = proposalRespone.proposalId,
            PS111_Created_At__c = proposalRespone.createdAt,
            PS111_Folder_Id__c = folderId,
            PS111_Owner__c = proposalRespone.owner,
            PS111_Updated_At__c = proposalRespone.updatedAt
        );
    }

    /* Makes the callout to retrieve all the proposals and map them by their folder id */
    @TestVisible
    private Map<String, List<RES_All_Proposals.Proposal>> getProposalsByFolderId(String acessToken)
    {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(this.settings.Base_Url__c + '/proposal/proposal');
        req.setHeader(this.HTTP_AUTHORIZATION, 'Bearer ' + acessToken);
        req.setHeader(this.HTTP_HEADER_ACCEPT, this.HTTP_APPLICATION_JSON);
        req.setHeader(this.HTTP_HEADER_API_KEY, this.settings.API_Key__c);
        req.setHeader(this.HTTP_HEADER_CONTENT_TYPE, this.HTTP_APPLICATION_JSON);
        req.setMethod(this.HTTP_GET);
        req.setTimeout(120000);

        // Make callout and parse the response using streaming approach
        Http http = new Http();
        HttpResponse res = http.send(req);

        Map<String, List<RES_All_Proposals.Proposal>> proposalsByFolderId = new Map<String, List<RES_All_Proposals.Proposal>>();

        JSONParser parser = JSON.createParser(res.getBody());
        while (parser.nextToken() != null) {
            if (parser.getCurrentToken() == JSONToken.START_OBJECT) {
                RES_All_Proposals.Proposal proposal = (RES_All_Proposals.Proposal) parser.readValueAs(RES_All_Proposals.Proposal.class);

                String folderIdKey = proposal.folderId;
                if (proposalsByFolderId.containsKey(folderIdKey)) {
                    proposalsByFolderId.get(folderIdKey).add(proposal);
                } else {
                    proposalsByFolderId.put(folderIdKey, new List<RES_All_Proposals.Proposal>{proposal});
                }
            }
        }

        return proposalsByFolderId;
    }

    /* Authenticates with PS111 and returns the api key to be used in further
     * requests. */
    @TestVisible
    private String loginAndGetAccessToken()
    {
        String username = this.settings.Username__c;
        String password = this.settings.Password__c;
        String jsonBody = '{ "username": "' + username + '", "password": "' + password + '" }';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(this.settings.Base_Url__c + '/login');
        req.setHeader(this.HTTP_HEADER_ACCEPT, this.HTTP_APPLICATION_JSON);
        req.setHeader(this.HTTP_HEADER_API_KEY, this.settings.API_Key__c);
        req.setHeader(this.HTTP_HEADER_CONTENT_TYPE, this.HTTP_APPLICATION_JSON);
        req.setMethod(this.HTTP_POST);
        req.setBody(jsonBody);

        HTTPResponse res = new Http().send(req);
        Map<String, Object> bodyParams =  (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if(res.getStatusCode() != 201)
        {
            throw new ProposalStudioException('Failed to login to proposal Studio:\n' + res.getBody());
        }
        return (String) bodyParams.get(this.HTTP_ACCESS_TOKEN);
    }

    public void finish(Database.BatchableContext BC)
    {
    }
}