@IsTest
global class RES_Proposal_Studio_Get_Proposals_Mock implements HttpCalloutMock
{
    global HTTPResponse respond(HTTPRequest req) 
    {   
        System.assertEquals('https://api.proposalstudio.com/proposal/proposal', req.getEndpoint());
        System.assertEquals('application/json', req.getHeader('Accept'));
        System.assertEquals('application/json', req.getHeader('Content-Type'));
        System.assertNotEquals(null, req.getHeader('Authorization'));
        System.assertNotEquals(null, req.getHeader('x-api-key'));
        System.assertEquals('GET', req.getMethod());

        HTTPResponse res = new HTTPResponse();
        res.setBody(TestData.getProposalsResponseMockJson());
        return res;
    }
}