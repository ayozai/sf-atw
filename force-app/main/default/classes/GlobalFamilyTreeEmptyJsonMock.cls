@isTest
public class GlobalFamilyTreeEmptyJsonMock implements HttpCalloutMock{
    public GlobalFamilyTreeEmptyJsonMock() {
        
    }

    public HTTPResponse respond(HTTPRequest req) {
        String authenticationDetailsJson = '{}';

            System.assertEquals('https://linkage-test-api.dqbox.com/v1/token', req.getEndpoint());
            System.assertEquals('POST', req.getMethod());

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(authenticationDetailsJson);
            res.setStatusCode(200);

        return res;
    }
}