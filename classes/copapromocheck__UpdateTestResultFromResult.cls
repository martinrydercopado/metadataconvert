/*
 * Necessary workaround when running a Test tool as a Test, not as a Quality Gate
 */
global with sharing class UpdateTestResultFromResult implements copado.MCCallback {

    // Entrypoint of a Flow Action to update test results
    @InvocableMethod(label='Update Test Result From Result' category='Copado')
    public static void execute(List<Request> requests) {
        for(Request request : requests) {
            // NOTE: this is not bulkified, but since it is a temporary workaround, it should not matter
            updateTestResult(request.resultId, request.status, request.resultData, request.errorMessage);
        }
    }

    // Entrypoint of a Function callback
    global void execute(copado__Function__c function, copado__Result__c result, String status) {
        updateTestResult(result.Id, status, null, null);
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    global static void updateTestResult(Id resultId, String status, String resultData, String errorMessage) {
        String jobExecutionPayload = [SELECT copado__JobStep__r.copado__JobExecution__r.copado__DataJson__c 
                                      FROM copado__Result__c 
                                      WHERE Id= :resultId LIMIT 1
                                      ][0].copado__JobStep__r.copado__JobExecution__r.copado__DataJson__c;
        Map<String,Object> jobPayload = (Map<String,Object>) System.JSON.deserializeUntyped(jobExecutionPayload);
        Set<Id> resultIds = new Set<Id>();
        if(jobPayload.get('resultId')!=null) {
            // Consolidated result is not null
            resultIds.add( (String)jobPayload.get('resultId') );
        } else if(jobPayload.get('resultIds')!=null) {
            // Consolidated result is null but there are individual results
            for(Object rid : (List<Object>)jobPayload.get('resultIds')) {
                resultIds.add( (String)rid );
            }
        }
        System.debug('looking for resultIds='+resultIds);
        List<copado__Result__c> results = [SELECT copado__Status__c, copado__Progress_Status__c
            FROM copado__Result__c WHERE Id IN :resultIds];
        for(copado__Result__c result : results) {
            String finalStatus = status == 'Success' ? 'Success' : 'Failed';
            result.copado__Status__c = finalStatus;
            result.copado__Progress_Status__c = errorMessage;
            result.copado__Error_Message__c = errorMessage;
        }
        System.debug('updating results='+results);
        if(Schema.sObjectType.copado__Result__c.isUpdateable()) {
            update results;
        }
    }

    global with sharing class CustomException extends Exception {}

    global with sharing class Request {
        @InvocableVariable
        public Id resultId;
        @InvocableVariable
        public String status;
        @InvocableVariable
        public String resultData;
        @InvocableVariable
        public String errorMessage;
    }
}