public with sharing class OpenAiApiService {

    public class OpenAiWrapper {
        @AuraEnabled
        public Boolean isSuccess { get; set; }

        @AuraEnabled
        public Integer statusCode { get; set; }

        @AuraEnabled
        public String status { get; set; }

        @AuraEnabled
        public String message { get; set; }

        @AuraEnabled
        public String response { get; set; }
    }

    @AuraEnabled
    public static String getAuthToken(String body) {
        // NOTE: unit-test mocks do not reach managed packages, so we need to rely on a Test.isRunningTest()
        HttpResponse res;
        if(Test.isRunningTest()) {
            res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"auth_token": "yyy"}');
        }else{
            res = copado.ApiProxy.getAISession('{}');
        }
        if (res.getStatusCode() == 200) {
            Map<String, Object> resp = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            return (String)resp.get('auth_token');
        } else {
            throw new CalloutException('Could not contact the API. Details: ' + res.getStatus() + ' ' + res.getBody());
        }
    }

    public static Copado_AI_Companion_Configuration__mdt getConfig() {
        // for test only, we will ignore the configuration. It cannot be created by the tests
        if(Test.isRunningTest()) {
            return new Copado_AI_Companion_Configuration__mdt();
        }

        Map<String, Copado_AI_Companion_Configuration__mdt> confs = Copado_AI_Companion_Configuration__mdt.getAll();
        for(Copado_AI_Companion_Configuration__mdt c : confs.values()) {
            if(c.DeveloperName!='Default') {
                return c;
            }
        }
        if(!confs.isEmpty()) {
            // returns the default record, since there was no non-default named one.
            return confs.values()[0];
        }
        // not having any record should never happen, but just in case.
        return new Copado_AI_Companion_Configuration__mdt();
    }
}