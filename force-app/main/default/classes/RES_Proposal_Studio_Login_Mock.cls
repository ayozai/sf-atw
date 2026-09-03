@IsTest
global class RES_Proposal_Studio_Login_Mock implements HttpCalloutMock
{
    global HTTPResponse respond(HTTPRequest req) 
    {   
        System.assertEquals('https://api.proposalstudio.com/login', req.getEndpoint());
        System.assertEquals('POST', req.getMethod());
        System.assertEquals('application/json', req.getHeader('Content-Type'));
        System.assertEquals('application/json', req.getHeader('Accept'));

        HTTPResponse res = new HTTPResponse();
        res.setStatusCode(201);
        res.setBody('{"accessToken": "eyJhbGciOiJIU.eyJ1c2VybmFtZ.O3ZSIA8Z1dRnp"}');
        return res;
    }
}