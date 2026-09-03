@IsTest
public class BATCH_Sync_Opp_Proposals_Test 
{
    @TestSetup
    static void setup()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'etsaddSGRs24SDFsdf344r223',
            Base_Url__c = 'https://api.proposalstudio.com',
            Password__c = 'MY_PASSWORD_1234',
            Username__c = 'user@atalian.com'
        );

        // Create Account and Opportunity
        Account acc = TestData.createAccount();
        insert acc;

        Opportunity opp1 = testData.createOpportunity(acc);
        opp1.PS111_Folder_ID__c = 'FOLDER1';
        Opportunity opp2 = testData.createOpportunity(acc);
        opp2.PS111_Folder_ID__c = 'FOLDER2';
        update new List<Opportunity>{opp1, opp2};
    }

    @IsTest
    static void TestLogin()
    {
        Test.setMock(HttpCalloutMock.class, new RES_Proposal_Studio_Login_Mock());

        Test.startTest();
            BATCH_Sync_Opp_Proposals batch = new BATCH_Sync_Opp_Proposals();
            String accessToken = batch.loginAndGetAccessToken();
            System.assertNotEquals(null, accessToken, 'No access token was returned');
            System.assertEquals('eyJhbGciOiJIU.eyJ1c2VybmFtZ.O3ZSIA8Z1dRnp', accessToken, 'Access token is incorrect');
        Test.stopTest();
    }

    @IsTest
    static void TestGetOpportunityIdsByFolderId()
    {
        List<Opportunity> opps = [SELECT Id, PS111_Folder_ID__c FROM Opportunity WHERE PS111_Folder_ID__c != NULL];
        System.assertEquals(2, opps.size(), 'Should have 2 opportunities with PS111_Folder_ID__c populated');

        Test.startTest();
            BATCH_Sync_Opp_Proposals batch = new BATCH_Sync_Opp_Proposals();
            Map<String, Id> oppIdsByFolderId = batch.getOpportunityIdsByFolderId(opps);
            System.assert(oppIdsByFolderId.containsKey('FOLDER1'), 'Should have an opportunity Id mapped to Folder1');
            System.assert(oppIdsByFolderId.containsKey('FOLDER2'), 'Should have an opportunity Id mapped to Folder2');
        Test.stopTest();
    }

    @IsTest
    static void TestCreateProposal()
    {
        Test.setMock(HttpCalloutMock.class, new RES_Proposal_Studio_Get_Proposals_Mock());

        List<Opportunity> opps = [SELECT Id, PS111_Folder_ID__c FROM Opportunity WHERE PS111_Folder_ID__c != NULL];
        System.assertEquals(2, opps.size(), 'Should have 2 opportunities with PS111_Folder_ID__c populated');

        Test.startTest();
            BATCH_Sync_Opp_Proposals batch = new BATCH_Sync_Opp_Proposals();
            
            Map<String, List<RES_All_Proposals.Proposal>> proposalsByFolderId = batch.getProposalsByFolderId('ACCESS.TOKEN.MOCK');
            System.assertEquals(1, proposalsByFolderId.get('FOLDER2').size(), 'Should be 1 proposals for folder Id "FOLDER2"');
            RES_All_Proposals.Proposal proposalResponse = proposalsByFolderId.get('FOLDER2')[0];
            
            Map<String, Id> oppIdsByFolderId = batch.getOpportunityIdsByFolderId(opps);
            Proposal__c proposalResult1 = batch.createProposalFromProposalResponse(oppIdsByFolderId, proposalResponse);

            //Asert proposal result is set correctly 
            System.assertEquals(oppIdsByFolderId.get('FOLDER2'), proposalResult1.Opportunity__c, 'Opportunity__c result does not match proposal response');
            System.assertEquals(proposalResponse.description, proposalResult1.Description__c, 'Description__c result does not match proposal response');
            System.assertEquals(proposalResponse.draft, proposalResult1.Is_Draft__c, 'Is_Draft__c result does not match proposal response');
            System.assertEquals(proposalResponse.masterName, proposalResult1.Master_Template__c, 'Master_Template__c result does not match proposal response');
            System.assertEquals(proposalResponse.name, proposalResult1.Name__c, 'Name result does not match proposal response');
            System.assertEquals(proposalResponse.proposalId, proposalResult1.Proposal_Id__c, 'Proposal_Id__c result does not match proposal response');
            System.assertEquals(proposalResponse.createdAt, proposalResult1.PS111_Created_At__c, 'PS111_Created_At__c result does not match proposal response');
            System.assertEquals(proposalResponse.folderId, proposalResult1.PS111_Folder_Id__c, 'PS111_Folder_Id__c result does not match proposal response');
            System.assertEquals(proposalResponse.owner, proposalResult1.PS111_Owner__c, 'PS111_Owner__c result does not match proposal response');
            System.assertEquals(proposalResponse.updatedAt, proposalResult1.PS111_Updated_At__c, 'PS111_Updated_At__c result does not match proposal response');
        Test.stopTest();
    }

    @IsTest
    static void TestGetProposals()
    {
        Test.setMock(HttpCalloutMock.class, new RES_Proposal_Studio_Get_Proposals_Mock());

        Test.startTest();
            BATCH_Sync_Opp_Proposals batch = new BATCH_Sync_Opp_Proposals();
            Map<String, List<RES_All_Proposals.Proposal>> proposalsByFolderId = batch.getProposalsByFolderId('ACCESS.TOKEN.MOCK');
            System.assertEquals(2, proposalsByFolderId.keySet().size(), 'Should be 2 folder Ids returned');
            System.assertEquals(2, proposalsByFolderId.get('FOLDER1').size(), 'Should be 2 proposals for folder Id "FOLDER1"');
            System.assertEquals(1, proposalsByFolderId.get('FOLDER2').size(), 'Should be 1 proposals for folder Id "FOLDER2"');
        Test.stopTest();
    }

    @IsTest
    static void TestBatchExecute()
    {
        Test.setMock(HttpCalloutMock.class, new RES_Proposal_Studio_Get_Proposals_Mock());

        Account testAccount = TestData.createAccount();
        insert testAccount;

        List<Proposal__c> results = [SELECT Id FROM Proposal__c];
        System.assert(results.isEmpty(), 'There should be no Proposal records currently');

        Test.startTest();
            BATCH_Sync_Opp_Proposals batch = new BATCH_Sync_Opp_Proposals();
            Database.executeBatch(batch);
        Test.stopTest();

        results = [SELECT Id FROM Proposal__c];
        System.assertEquals(3, results.size(), 'Should have created 3 proposals');
    }

    @IsTest
    static void TestBatchSchedule()
    {
        Test.setMock(HttpCalloutMock.class, new RES_Proposal_Studio_Get_Proposals_Mock());

        Account testAccount = TestData.createAccount();
        insert testAccount;

        List<Proposal__c> results = [SELECT Id FROM Proposal__c];
        System.assert(results.isEmpty(), 'There should be no Proposal records currently');

        Test.startTest();
            new SCHEDULE_Sync_Opp_Proposals().execute(null);
        Test.stopTest();

        results = [SELECT Id FROM Proposal__c];
        System.assertEquals(3, results.size(), 'Should have created 3 proposals');
    }
}