@isTest
public with sharing class OpenAiApiServiceTest {

  private class SingleRequestMock implements HttpCalloutMock {
    protected Integer code;
    protected String status;
    protected String bodyAsString;
    protected Blob bodyAsBlob;
    protected Map<String, String> responseHeaders;

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public SingleRequestMock(Integer code, String status, String body,
        Map<String, String> responseHeaders) {
      this.code = code;
      this.status = status;
      this.bodyAsString = body;
      this.bodyAsBlob = null;
      this.responseHeaders = responseHeaders;
    }
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse resp = new HttpResponse();
      resp.setStatusCode(code);
      resp.setStatus(status);
      if (bodyAsBlob != null) {
        resp.setBodyAsBlob(bodyAsBlob);
      } else {
        resp.setBody(bodyAsString);
      }

      if (responseHeaders != null) {
        for (String key : responseHeaders.keySet()) {
          resp.setHeader(key, responseHeaders.get(key));
        }
      }
      return resp;
    }
  }

  @isTest
  static void calloutSuccess() {
    SingleRequestMock errResponse = new SingleRequestMock(200, 'Success',
        '{ "auth_token": "dummy, not used"}',null);
        Test.setMock(HttpCalloutMock.class, errResponse);
        OpenAIApiService.getConfig();
        String auth_token = OpenAiApiService.getAuthToken('{}');
        System.assertEquals('yyy', auth_token, 'values do not match');
        
    }
}