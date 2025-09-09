public with sharing class AutomationResult {

    private static final String SUCCESS = 'Success';
    private static final String FAILED = 'Failed';
    private static final String CANCELLED = 'Cancelled';
    private static final String NOT_STARTED = 'Not Started';

    public static Boolean execute(copado__JobStep__c step) {
        AutomationDetails details = (AutomationDetails) Json.deserialize(step.copado__ResultDataJson__c, AutomationDetails.class);
        String status = 'Not Started';

        HttpResponse response = new Http().send(createRequest(details));
        System.debug(response.getBody());
        ResultWrapper result = (ResultWrapper) JSON.deserialize(response.getBody(), ResultWrapper.class);

        if (result.data != null && result.data.status == 'aborted') {
            status = CANCELLED;
        } else if (result.data != null && result.data.status != 'executing' && result.data.jsonObjReport != null && result.data.logReportUrl != null) {
            switch on result.data.status {
                when 'succeeded' {
                    status = SUCCESS;
                }
                when else {
                    status = FAILED;
                }
            }
        }

        if (status != NOT_STARTED) {
            copado__Result__c res = [SELECT Id, copado__Job_Id__c, copado__Link__c, copado__JobStep__c FROM copado__Result__c WHERE copado__JobStep__c = :step.Id LIMIT 1];
            res.copado__Job_Id__c = String.valueOf(result.data.id);
            res.copado__Link__c = result.data.logReportUrl;
            res.copado__Result_Data__c = result.data.logReportUrl;
            res.copado__Status__c = status;
            update res;

            publishComplete(res, step);

            return false;
        } else {
            return true;
        }
    }

    public static void publishComplete(copado__Result__c result, copado__JobStep__c flow) {
        copado__Event__e stepCompleted = new copado__Event__e();
        stepCompleted.copado__Payload__c = JSON.serialize(new EventPayload(result.copado__Status__c == 'Success', ''));
        String topic = '/events/copado/v1/step-result/' + flow.copado__Result__c;
        stepCompleted.copado__Topic_Uri__c = topic;
        EventBus.publish(stepCompleted);
    }

    private static HttpRequest createRequest(AutomationDetails details) {
        HttpRequest result = new HttpRequest();
        String projectId = details.projectId;
        String suiteId = details.suiteId;
        String executionId = details.executionId;

        // TODO: double check callout id name
        result.setEndpoint(
            'callout:.__CRT/pace/v4/projects/' + projectId + '/jobs/' + suiteId + '/builds/' + executionId + '?polling=true'
        );
        result.setHeader('X-AUTHORIZATION', '{!$Credential.CRT.Authorization}');
        result.setHeader('Content-Type', 'application/json');
        result.setMethod('GET');

        return result;
    }

    private class ResultWrapper {
        public String message;
        public ResultData data;
    }

    private class ResultData {
        public Integer id;
        public String status;
        public String logReportUrl;
        public JsonReport jsonObjReport;
    }

    private class JsonReport {
        public String status;
    }

    private with sharing class EventPayload {
        public Boolean isSuccess;
        public String errorMessage;

        public EventPayload(Boolean isSuccess, String errorMessage) {
            this.isSuccess = isSuccess;
            this.errorMessage = errorMessage;
        }
    }
}