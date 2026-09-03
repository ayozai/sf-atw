@IsTest
public class CreateOppProposalController_Test
{
    @TestSetup
    static void setup()
    {
        TestData.createAll();
    }

    @IsTest
    static void TestGetSettings()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'API_KEY',
            Base_Url__c = 'https://test-url.com',
            Password__c = 'PASSWORD',
            Username__c = 'Test@Test.com'
        );

        Proposal_Studio_Settings__c res = CreateOppProposalController.GetProposalStudioSettings();
        System.assertNotEquals(null, res.API_Key__c);
        System.assertNotEquals(null, res.Base_Url__c);
        System.assertNotEquals(null, res.Password__c);
        System.assertNotEquals(null, res.Username__c);
    }

    @IsTest
    static void TestGetSettingsWhenNoSetting()
    {
        Proposal_Studio_Settings__c res = CreateOppProposalController.GetProposalStudioSettings();
        System.assertNotEquals(null, res, 'Should expect a default value just with SetupOwnerId');
    }

    @IsTest
    static void TestGetOpportunity()
    {
        Opportunity expectedOpp = [SELECT Id, Name FROM Opportunity LIMIT 1];
        Opportunity resultOpp = CreateOppProposalController.GetOpportunity(expectedOpp.Id, new List<String>{'Id, Name'});
        System.assertEquals(expectedOpp.Id, resultOpp.Id);
        System.assertEquals(expectedOpp.Name, resultOpp.Name);
    }

    @IsTest
    static void TestGetGroupOptions()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'API_KEY',
            Base_Url__c = 'https://test-url.com',
            Password__c = 'PASSWORD',
            Username__c = 'Test@Test.com'
        );

        Test.setMock(HttpCalloutMock.class, new PS111MultiCalloutMock());

        Test.startTest();
        List<Map<String, Object>> result = CreateOppProposalController.GetGroupOptions();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(2, result.size(), 'Should return 2 units');
        System.assertEquals('unit-1', result[0].get('unitId'));
        System.assertEquals('Unit A', result[0].get('name'));
    }

    @IsTest
    static void TestGetGroupOptions_LoginFails()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'API_KEY',
            Base_Url__c = 'https://test-url.com',
            Password__c = 'PASSWORD',
            Username__c = 'Test@Test.com'
        );

        Test.setMock(HttpCalloutMock.class, new PS111LoginFailMock());

        Test.startTest();
        try {
            CreateOppProposalController.GetGroupOptions();
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().containsIgnoreCase('Login failed'), 'Expected login failure message, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void TestCreateProposalFolder()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'API_KEY',
            Base_Url__c = 'https://test-url.com',
            Password__c = 'PASSWORD',
            Username__c = 'Test@Test.com'
        );

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new PS111MultiCalloutMock());

        Test.startTest();
        String folderId = CreateOppProposalController.CreateProposalFolder(
            'unit-1', opp.Id, 'Test Opportunity', 'Test Account'
        );
        Test.stopTest();

        System.assertEquals('folder-456', folderId, 'Should return the folderId from PS111');
    }

    @IsTest
    static void TestCreateProposalFolder_LoginFails()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'API_KEY',
            Base_Url__c = 'https://test-url.com',
            Password__c = 'PASSWORD',
            Username__c = 'Test@Test.com'
        );

        Test.setMock(HttpCalloutMock.class, new PS111LoginFailMock());

        Test.startTest();
        try {
            CreateOppProposalController.CreateProposalFolder('unit-1', 'oppId', 'Test Opp', 'Test Account');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().containsIgnoreCase('Login failed'), 'Expected login failure message, got: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void TestCreateProposalFolder_CreateReturnsError()
    {
        insert new Proposal_Studio_Settings__c(
            API_Key__c = 'API_KEY',
            Base_Url__c = 'https://test-url.com',
            Password__c = 'PASSWORD',
            Username__c = 'Test@Test.com'
        );

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new PS111CreateFolderErrorMock());

        Test.startTest();
        try {
            CreateOppProposalController.CreateProposalFolder('unit-1', opp.Id, 'Test Opp', 'Test Account');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Expected error message from PS111');
        }
        Test.stopTest();
    }

    // ─── Mock Classes ────────────────────────────────────────────────────────────

    private class PS111MultiCalloutMock implements HttpCalloutMock
    {
        public HttpResponse respond(HttpRequest req)
        {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();

            if (endpoint.endsWith('/login')) {
                res.setStatusCode(200);
                res.setBody('{"accessToken":"mock-token-123"}');
            } else if (endpoint.endsWith('/organization/unit')) {
                res.setStatusCode(200);
                res.setBody('[{"unitId":"unit-1","name":"Unit A","parentUnitId":null},{"unitId":"unit-2","name":"Unit B","parentUnitId":"unit-1"}]');
            } else if (endpoint.contains('/organization/folder?unitId=')) {
                res.setStatusCode(200);
                res.setBody('[{"folderId":"parent-folder-123"}]');
            } else if (endpoint.endsWith('/organization/folder')) {
                res.setStatusCode(200);
                res.setBody('{"folderId":"folder-456"}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":"Not found"}');
            }
            return res;
        }
    }

    private class PS111LoginFailMock implements HttpCalloutMock
    {
        public HttpResponse respond(HttpRequest req)
        {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(401);
            res.setBody('{"error":"Unauthorized"}');
            return res;
        }
    }

    private class PS111CreateFolderErrorMock implements HttpCalloutMock
    {
        public HttpResponse respond(HttpRequest req)
        {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            String endpoint = req.getEndpoint();

            if (endpoint.endsWith('/login')) {
                res.setStatusCode(200);
                res.setBody('{"accessToken":"mock-token-123"}');
            } else if (endpoint.contains('/organization/folder?unitId=')) {
                res.setStatusCode(200);
                res.setBody('[{"folderId":"parent-folder-123"}]');
            } else if (endpoint.endsWith('/organization/folder')) {
                res.setStatusCode(200);
                res.setBody('{"error":"FOLDER_EXISTS","message":"A folder with this name already exists"}');
            } else {
                res.setStatusCode(404);
                res.setBody('{"error":"Not found"}');
            }
            return res;
        }
    }
}