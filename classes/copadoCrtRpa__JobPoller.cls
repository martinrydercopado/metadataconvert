public inherited sharing class JobPoller Implements Schedulable, Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts {
   
    // keep this LOW (5-20), to reduce the chance of concurrent downloads of job logs
    private static final integer MAX_CONCURRENT_POLLS = 10;
    private static final STRING SCHEDULED_PROCESS_NAME = 'RPAJobPoller';
    private integer currentlyActiveJobs = 0;

    @InvocableMethod
    public static void startPolling() {
        try {
            System.scheduleBatch(new JobPoller(), SCHEDULED_PROCESS_NAME, 1, MAX_CONCURRENT_POLLS);
        } catch(System.AsyncException e) {
            System.debug('startPolling() Expected exception (the class can be sheduled only once):' + e);
        }
    }
   
    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, MAX_CONCURRENT_POLLS);
    }
   
    public database.queryLocator start(Database.BatchableContext BC) {
        currentlyActiveJobs = 0;
        return Database.getQueryLocator([SELECT copado__Status__c, copado__Result__c, copado__ConfigJson__c, copado__ResultDataJson__c
                FROM copado__JobStep__c
                WHERE copado__CustomType__c='Salesforce Flow'
                AND copado__JobExecution__c != NULL
                AND copado__Status__c NOT IN ('Failed', 'Success')
                AND SystemModStamp >= LAST_N_DAYS:1]);
    }
   
    public void execute(Database.BatchableContext BC, List<copado__JobStep__c> flowSteps) {
        currentlyActiveJobs = 0;
        for (copado__JobStep__c flow : flowSteps) {
            String namespace = JobPoller.class.getName().contains('.') ? JobPoller.class.getName().substringBefore('.') + '.' :'';

            if (flow.copado__ConfigJson__c.contains('"flowName":"'+ namespace + 'Run_CRT"')) {
                Boolean isRunning = AutomationResult.execute(flow);

                if (isRunning) {
                    currentlyActiveJobs++;
                }
            }
        }
    }
   
    public void finish(Database.BatchableContext BC) {
        if(currentlyActiveJobs > 0) {
            startPolling();
        }
    }
}