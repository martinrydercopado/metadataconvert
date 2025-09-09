public with sharing class JobStartAndTrack {
    private static final String TEMPLATE_NAME = 'copado_sfcc_export_1';

    // get the latest result, status and progress messages
    @AuraEnabled
    public static copado__Result__c[] jobProgress(String[] jobExecutionIds) {
        return [
            SELECT
            Id,
            CreatedDate,
            copado__JobStep__r.Name,
            copado__JobStep__r.copado__JobExecution__r.Id,
            copado__JobStep__r.copado__JobExecution__r.Name,
            copado__JobStep__r.copado__JobExecution__r.CreatedDate,
            copado__JobStep__r.copado__JobExecution__r.copado__Template__r.Name,
            copado__JobStep__r.copado__JobExecution__r.copado__Status__c,
            copado__JobStep__r.copado__JobExecution__r.copado__ErrorMessage__c,
            (SELECT CreatedDate, NewValue FROM Histories ORDER BY CreatedDate DESC LIMIT 10),
            (SELECT Id, ContentDocumentId FROM ContentDocumentLinks WHERE ContentDocument.Title like 'Function Logs for %.txt' ORDER By ContentDocument.ContentModifiedDate DESC LIMIT 1)
            FROM copado__Result__c
            WHERE copado__JobStep__r.copado__JobExecution__c IN :jobExecutionIds
            WITH USER_MODE ORDER BY CreatedDate DESC LIMIT 10
        ];
    }

    // Start a Job Execution and return the Job Execution Id
    @AuraEnabled
    public static String executeJob(String userStoryId) {
        try {
            copado__User_Story__c userStory = [
                SELECT
                    Id,
                    copado__Environment__c,
                    copado__Project__r.copado__Deployment_Flow__c
                FROM
                    copado__User_Story__c
                WHERE
                    Id = :userStoryId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            copado.CreateExecution.Request request = new copado.CreateExecution.Request();
            request.runAfterInstantiation = true;
            request.templateName = TEMPLATE_NAME;
            request.parentId = userStory.Id;
            request.sourceId = userStory.copado__Environment__c;
            request.pipelineId = userStory.copado__Project__r.copado__Deployment_Flow__c;

            if (!Test.isRunningTest()) {
                List<copado__JobExecution__c> jobExecution = copado.CreateExecution.execute(new List<copado.CreateExecution.Request>{ request });
                return jobExecution[0].Id;
            }

            return '';
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, e);
            throw new AuraHandledException(e.getMessage());
        }
    }
}