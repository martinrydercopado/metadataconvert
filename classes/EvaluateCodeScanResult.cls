global with sharing class EvaluateCodeScanResult implements copado.MCCallback{

    global void execute(copado__Function__c function, copado__Result__c result, String status) {
        try {
            // If there are other intermediary statuses passed into this class ignore them
            if (status == 'Success' || status == 'Failed') {
                Set<Id> resultIdsToUpdate = getResultIdsFrom(result.Id);
                updateResults(resultIdsToUpdate,status);
            }
        } catch (Exception ex) {
            throw new EvaluateCodeScanResultException(ex.getMessage() + '' + ex.getStackTraceString());
        }
    }

    //PRIVATE

    private Set<Id> getResultIdsFrom(Id resultId) {
        Set<Id> result = new Set<Id>();

        String jobExecutionPayload = [SELECT copado__JobStep__r.copado__JobExecution__r.copado__DataJson__c 
                                      FROM copado__Result__c 
                                      WHERE Id= :resultId LIMIT 1][0].copado__JobStep__r.copado__JobExecution__r.copado__DataJson__c;
        JobExecutionPayload jobPayload = (JobExecutionPayload) System.JSON.deserialize(jobExecutionPayload, JobExecutionPayload.class);
		
        if (jobPayload.resultId != null) { // Consolidated result is not null
            result.add((Id) jobPayload.resultId);
        } else if (jobPayload.resultIds != null) { // Consolidated result is null but there are individual results
            result.addAll((List<Id>) jobPayload.resultIds);
        }

        return result;
    }

    private void updateResults(Set<Id> resultIdsToUpdate, String status){
        List<copado__Result__c> results = [SELECT copado__Status__c, copado__Progress_Status__c
                                              FROM copado__Result__c 
                                              WHERE Id IN :resultIdsToUpdate];

        for (copado__Result__c result : results) {
            String finalStatus = status == 'Success' ? 'Success' : 'Failed';

            result.copado__Status__c = finalStatus;
            result.copado__Progress_Status__c = finalStatus;
        }
        if (Schema.sObjectType.copado__Result__c.isUpdateable()) {
            update results;
        }

    }
    public with sharing class EvaluateCodeScanResultException extends Exception{}
    // INNER CLASS
	
    private class JobExecutionPayload {
        private String resultId;
        private List<String> resultIds;
    }
}