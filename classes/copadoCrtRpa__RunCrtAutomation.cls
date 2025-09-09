public with sharing class RunCrtAutomation {

    // PUBLIC
    @InvocableMethod(label='Run CRT Automation' category='Run CRT Automation')
    public static void execute(List<Parameters> params) {
        Parameters param = params[0];

        AutomationDetails details = new AutomationDetails(
            param.projectId,
            param.suiteId
        );
        copado__Result__c res = [SELECT Id, copado__JobStep__c FROM copado__Result__c WHERE Id = :param.resultId];
        copado__JobStep__c step = [SELECT Id, copado__Result__c FROM copado__JobStep__c WHERE Id = :res.copado__JobStep__c];

        copado.Jobs.DynamicExpressionEvaluateRequest req = new copado.Jobs.DynamicExpressionEvaluateRequest(step.Id, new String[]{'{$Destination.Credential.SessionId}', '{$Destination.Credential.Endpoint}'});
        List<copado.Jobs.DynamicExpressionEvaluateResult> variables = copado.Jobs.DynamicExpression.evaluate(req);
        System.debug(variables[0]);
        String sessionId = variables[0].value;
        String endpoint = variables[1].value;

        if (endpoint != null && sessionId != null) {
            details = details.loginUrl(endpoint, sessionId);
        }

        HttpRequest request = createRequest(details);
        HttpResponse response = new Http().send(request);
        Id userId = UserInfo.getUserId();

        System.debug(response.getBody());
        HttpResponseInfo body = (HttpResponseInfo) JSON.deserialize(response.getBody(), HttpResponseInfo.class);
        Boolean result = isSuccessfullyEnqueued(body);
        // TODO: handle tokenless response

        if (result) {
            String jsonString = JSON.serialize(details.executionId(body.data.id));
            step.copado__ResultDataJson__c = jsonString;
            update step;

            if (!Test.isRunningTest()) {
                JobPoller.startPolling();
            }
        }
    }

    private static HttpRequest createRequest(AutomationDetails details) {
        HttpRequest request = new HttpRequest();
        String projectId = details.projectId;
        String suiteId = details.suiteId;

        request.setEndpoint(
            'callout:.__CRT/pace/v4/projects/' + projectId + '/jobs/' + suiteId + '/builds'
        );

        String body = crtBody(details);
        System.debug(body);
        request.setBody(body);

        request.setHeader('X-AUTHORIZATION', '{!$Credential.CRT.Authorization}');
        request.setHeader('Content-Type', 'application/json');
        request.setMethod('POST');

        return request;
    }

    private static String crtBody(AutomationDetails details) {
        Map<String, Object> result = new Map<String, Object>();

        result.put('record', 'all');
        result.put('runType', 'normal');
        result.put('stream', false);

        List<Map<String, Object>> parameters = new List<Map<String, Object>>();

        if (String.isNotBlank(details.loginUrl)) {
            Map<String, Object> block = new Map<String, Object>();
            block.put('key', 'loginUrl');
            block.put('value', details.loginUrl);
            block.put('sensitive', true);

            // @Note: add to parameter list
            parameters.add(block);
        }

        result.put('inputParameters', parameters);

        return JSON.serialize(result);
    }

    private static Boolean isSuccessfullyEnqueued(HttpResponseInfo response) {
        return response != null &&
            response.data != null &&
            response.data.id != null &&
            response.message != null &&
            !response.message.contains('already queued');
    }

    public class Parameters {
        @InvocableVariable(required=true label='Suite ID')
        public String suiteId;

        @InvocableVariable(required=true label='Project ID')
        public String projectId;

        @InvocableVariable(required=true label='Result ID')
        public String resultId;
    }

    private class HttpResponseInfo {
        public String message;
        public HttpResponseDetails data;
    }

    private class HttpResponseDetails {
        public String id;
        public String status;
    }
}