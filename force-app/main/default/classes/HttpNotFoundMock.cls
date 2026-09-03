@isTest
public class HttpNotFoundMock implements HttpCalloutMock{

    public HttpNotFoundMock() {       
    }

    public HTTPResponse respond(HTTPRequest req) {
        String authenticationDetailsJson = '{}';

        System.assertEquals('https://linkage-test-api.dqbox.com/v1/token', req.getEndpoint());
        System.assertEquals('POST', req.getMethod());

        HTTPResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(authenticationDetailsJson);
        res.setStatusCode(401);

        return res;
    }
}